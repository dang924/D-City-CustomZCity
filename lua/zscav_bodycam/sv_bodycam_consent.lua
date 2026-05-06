-- ZScav Bodycam System - consent state.
-- Default: deny. Players opt in via the inventory button OR per-raid popup.
-- Consent state is keyed per-player (steamID64) and lives only in memory; the
-- *remembered* preference is persisted client-side via cookies and resent
-- whenever consent is requested.

local BC = ZSCAV.Bodycam

BC.Consent = BC.Consent or {}     -- [sid64] = BC.CONSENT_*  (server view of per-raid state)
BC.Pending = BC.Pending or {}     -- [sid64] = absolute deadline CurTime() at which we auto-deny

local POPUP_TIMEOUT = 30          -- seconds before unanswered popups auto-deny

-- =========================================================================
-- Internal helpers
-- =========================================================================
local function setState(ply, state)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if not sid then return end

    BC.Consent[sid] = state
    BC.Pending[sid] = nil

    if state == BC.CONSENT_ALLOW then
        BC:EnsureCamera(ply)
        ply:SetNWBool("ZSCAV_Bodycam_Recording", true)
        net.Start("ZScav_Bodycam_HUDState") net.WriteBool(true)  net.Send(ply)
    else
        BC:RemoveCamera(ply)
        ply:SetNWBool("ZSCAV_Bodycam_Recording", false)
        net.Start("ZScav_Bodycam_HUDState") net.WriteBool(false) net.Send(ply)
    end
end

local function isConsentingState(state)
    return state == BC.CONSENT_ALLOW
end

-- =========================================================================
-- Public API
-- =========================================================================

-- Are we currently broadcasting this player?
function BC:IsConsenting(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not ply:Alive() then return false end
    -- Force flag (set by zscav_bodycam_force admin command) bypasses safe-zone
    -- gating so we can test the feed without entering a raid.
    if ply.zscav_bodycam_force then
        return isConsentingState(self.Consent[ply:SteamID64()])
    end
    if BC:IsPlayerInSafeZone(ply) then return false end  -- safe-zone players don't broadcast
    return isConsentingState(self.Consent[ply:SteamID64()])
end

-- Iterate every currently-consenting alive player. Used by the director.
function BC:IterConsentingPlayers()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if self:IsConsenting(ply) then out[#out + 1] = ply end
    end
    return out
end

-- Force a state. Used by the inventory toggle and round/spawn-pad triggers.
function BC:SetConsent(ply, allow)
    setState(ply, allow and self.CONSENT_ALLOW or self.CONSENT_DENY)
end

-- Ask a single player for consent. Sends them a popup; their cookie may
-- short-circuit it client-side and reply immediately.
function BC:AskPlayer(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if not sid then return end
    self.Consent[sid] = self.CONSENT_PENDING
    self.Pending[sid] = CurTime() + POPUP_TIMEOUT
    net.Start("ZScav_Bodycam_RequestConsent")
    net.Send(ply)
end

-- Ask everyone (typical "round/raid start" call). External code calls this.
function BC:AskAll()
    for _, ply in ipairs(player.GetAll()) do
        if not BC:IsPlayerInSafeZone(ply) then continue end
        -- only ask players currently in the safe zone (gearing up). Players
        -- outside don't need a popup; they'll be denied by default.
        self:AskPlayer(ply)
    end
end

-- Reset all consent (e.g. between raids). Cameras get torn down.
function BC:ResetAll()
    for sid, _ in pairs(self.Consent) do
        local ply = player.GetBySteamID64(sid)
        if IsValid(ply) then setState(ply, self.CONSENT_DENY) end
    end
    self.Consent = {}
    self.Pending = {}
    self:ClearAllCameras()
end

-- =========================================================================
-- Net handlers
-- =========================================================================
net.Receive("ZScav_Bodycam_ConsentReply", function(_len, ply)
    if not IsValid(ply) then return end
    local allow = net.ReadBool()
    setState(ply, allow and BC.CONSENT_ALLOW or BC.CONSENT_DENY)
end)

net.Receive("ZScav_Bodycam_ToggleConsent", function(_len, ply)
    if not IsValid(ply) then return end
    local allow = net.ReadBool()
    setState(ply, allow and BC.CONSENT_ALLOW or BC.CONSENT_DENY)
    -- Also note the "next round default" so future round-start asks honour it.
    -- The client cookie already records "remembered choice" but we mirror it here.
    ply:SetNWBool("ZSCAV_Bodycam_RememberedChoice", allow)
end)

-- =========================================================================
-- Periodic timeout sweep
-- =========================================================================
timer.Create("ZScav_Bodycam_ConsentTimeoutSweep", 1, 0, function()
    local now = CurTime()
    for sid, deadline in pairs(BC.Pending) do
        if deadline and now >= deadline then
            local ply = player.GetBySteamID64(sid)
            if IsValid(ply) then setState(ply, BC.CONSENT_DENY)
            else BC.Pending[sid] = nil BC.Consent[sid] = nil end
        end
    end
end)

-- =========================================================================
-- Triggers - external systems call these
-- =========================================================================
-- Call when a raid starts. The placeholder spawn pad passes its occupants in;
-- when called with no arg, we fall back to asking everyone in any safe zone.
-- Per-team launches don't reset the global state - only the occupants get a
-- fresh prompt, so an in-progress raid on a different pad isn't disturbed.
hook.Add("ZScav_RaidStart", "ZScav_Bodycam_OnRaidStart", function(occupants)
    if istable(occupants) and #occupants > 0 then
        for _, ply in ipairs(occupants) do
            -- Tear down their previous bodycam state, then re-prompt.
            local sid = IsValid(ply) and ply:SteamID64() or nil
            if sid then
                BC.Consent[sid] = nil
                BC.Pending[sid] = nil
                BC:RemoveCamera(ply)
                if IsValid(ply) then ply:SetNWBool("ZSCAV_Bodycam_Recording", false) end
            end
            BC:AskPlayer(ply)
        end
        return
    end

    BC:ResetAll()
    BC:AskAll()
end)

-- Compat: many ZScav installs still drive the round through MODE:RoundStart
-- via zb. Pipe that into our raid-start signal so consent gets asked even
-- before the spawn-pad system exists. Safe to remove later.
hook.Add("PostGamemodeLoaded", "ZScav_Bodycam_HookRoundStart", function()
    if not zb or not zb.HookRoundStart then return end
    -- If your codebase already exposes a "round started" hook by another name,
    -- duplicate the call here. Otherwise this is a no-op.
end)

-- Disconnect: clear state.
hook.Add("PlayerDisconnected", "ZScav_Bodycam_ClearOnLeave", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if not sid then return end
    BC.Consent[sid] = nil
    BC.Pending[sid] = nil
end)

-- =========================================================================
-- Console command (admin diagnostic + manual trigger)
-- =========================================================================
concommand.Add("zscav_bodycam_ask", function(ply)
    if IsValid(ply) and not ply:IsAdmin() and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Bodycam] Admin only.")
        return
    end
    BC:ResetAll()
    BC:AskAll()
    if IsValid(ply) then ply:ChatPrint("[Bodycam] Consent prompt sent to all safe-zone players.") end
end)
