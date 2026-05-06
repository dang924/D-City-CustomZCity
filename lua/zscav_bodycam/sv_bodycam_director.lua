-- ZScav Bodycam System - director.
-- Tracks per-player activity score, picks top 12 cameras for monitor display,
-- and top BC.MAX_AUDIO_FEEDS cameras for audio relay. Networks the slot
-- assignment to safe-zone clients, who already have the camera entities in
-- their PVS via rtcam's existing visibility hook.

local BC = ZSCAV.Bodycam

BC.Scores  = BC.Scores  or {}   -- [sid64] = number
BC.Assigns = BC.Assigns or {}   -- [monitorIdx 1..N] = { sid64, lockedUntil, audio }

-- =========================================================================
-- Activity bumps - call these from anywhere
-- =========================================================================
function BC:Bump(ply, kind)
    if not self:IsConsenting(ply) then return end
    local w = self.SCORE_WEIGHTS[kind]
    if not w then return end
    local sid = ply:SteamID64()
    self.Scores[sid] = (self.Scores[sid] or 0) + w
end

-- =========================================================================
-- Activity event hooks
-- =========================================================================
hook.Add("EntityFireBullets", "ZScav_Bodycam_Fire", function(ent, _data)
    if not BC:IsActive() then return end
    if IsValid(ent) and ent:IsPlayer() then BC:Bump(ent, "fire") end
end)

hook.Add("EntityTakeDamage", "ZScav_Bodycam_Damage", function(target, dmg)
    if not BC:IsActive() then return end
    if IsValid(target) and target:IsPlayer() then BC:Bump(target, "damage") end
    if not dmg then return end
    local atk = dmg:GetAttacker()
    if IsValid(atk) and atk:IsPlayer() and target ~= atk then
        if not target:Alive() then BC:Bump(atk, "kill") end
    end
end)

hook.Add("HG_OnOtrub", "ZScav_Bodycam_Otrub", function(ply)
    if not BC:IsActive() then return end
    if IsValid(ply) then BC:Bump(ply, "otrub") end
end)

-- =========================================================================
-- Director tick
-- =========================================================================
local function buildCandidates()
    local cands = {}
    local incumbents = {}
    for idx, slot in pairs(BC.Assigns) do
        if slot and slot.sid64 then incumbents[slot.sid64] = idx end
    end

    for _, ply in ipairs(BC:IterConsentingPlayers()) do
        local sid = ply:SteamID64()
        local score = BC.Scores[sid] or 0
        if incumbents[sid] then score = score + BC.INCUMBENT_BONUS end
        cands[#cands + 1] = { ply = ply, sid = sid, score = score }
    end

    table.sort(cands, function(a, b) return a.score > b.score end)
    return cands
end

-- Cache of monitor full IDs keyed by the actualID we expect for each slot.
-- Refreshed every director tick. urtcam global mode prefixes IDs with "G_",
-- private with "P_<sid64>_", local with "CP_<sid64>_". By reading the live
-- monitor entity's :GetID() instead of assuming a prefix, the director works
-- with any IDMode the user placed monitors in.
local monitorFullIDByActualID = {}

local function refreshMonitorCache()
    for k in pairs(monitorFullIDByActualID) do monitorFullIDByActualID[k] = nil end
    for _, ent in ipairs(ents.FindByClass("gmod_ultimate_rttv")) do
        if IsValid(ent) then
            local actual = ent:GetActualID()
            if isstring(actual) and actual ~= "" then
                monitorFullIDByActualID[actual] = ent:GetID()
            end
        end
    end
end

function BC:GetMonitorFullID(idx)
    return monitorFullIDByActualID[self:MonitorActualID(idx)]
end

-- Apply newAssigns: rewrite chosen cameras' IDs to match the live monitor IDs.
--
-- IMPORTANT: rtcams' OnIDChanged callback nils urtcam.CamByID[old]. If we
-- reassigned slots in-place, swapping cameraA from slot1 to slot2 (where
-- cameraB lived) would clobber cameraB's freshly-set entry. To avoid that,
-- we first reset EVERY bodycam to its idle ID (clearing all slot entries),
-- then promote chosen cameras to the looked-up monitor IDs.
local function applyAssignments(newAssigns)
    refreshMonitorCache()

    -- Phase 1: reset everyone to idle. Clears all existing slot mappings.
    for sid, cam in pairs(BC.PlyCam) do
        if not IsValid(cam) then BC.PlyCam[sid] = nil continue end
        local ply = cam.zscav_bodycam_owner
        if IsValid(ply) then
            cam:SetID(BC:InactiveCamID(ply))
        end
    end

    -- Phase 2: promote chosen cameras using the monitor's live full ID. If
    -- the matching monitor doesn't exist on this map, leave the camera idle
    -- so it doesn't pollute urtcam.CamByID.
    for idx, slot in pairs(newAssigns) do
        local cam = BC.PlyCam[slot.sid64]
        if IsValid(cam) then
            local fullID = monitorFullIDByActualID[BC:MonitorActualID(idx)]
            if fullID and fullID ~= "" then
                cam:SetID(fullID)
            end
        end
    end
end

local function broadcastAssignments(newAssigns)
    -- Format: count(4 bits), then per-slot present(bool), and if present:
    -- camOwnerEnt, audio(bool), hp(0..1), otrub(bool)
    net.Start("ZScav_Bodycam_DirectorUpdate")
    net.WriteUInt(BC.MONITOR_COUNT, 5)
    for idx = 1, BC.MONITOR_COUNT do
        local slot = newAssigns[idx]
        if slot then
            local ply = player.GetBySteamID64(slot.sid64)
            if IsValid(ply) then
                net.WriteBool(true)
                net.WriteEntity(ply)
                net.WriteBool(slot.audio == true)
                local hp = math.Clamp((ply:Health() or 0) / math.max(ply:GetMaxHealth() or 100, 1), 0, 1)
                net.WriteFloat(hp)
                local otrub = (istable(ply.organism) and ply.organism.otrub) and true or false
                net.WriteBool(otrub)
            else
                net.WriteBool(false)
            end
        else
            net.WriteBool(false)
        end
    end
    net.Broadcast()
end

-- Director runs when ZScav is active OR when any player has been force-flagged
-- via zscav_bodycam_force (debug). This lets you test the feed without
-- starting a real raid.
local function anyForced()
    for _, p in ipairs(player.GetAll()) do
        if p.zscav_bodycam_force then return true end
    end
    return false
end

local function tick()
    if not BC:IsActive() and not anyForced() then
        if next(BC.Assigns) then
            BC.Assigns = {}
            applyAssignments({})
            broadcastAssignments({})
        end
        return
    end

    -- Decay all scores.
    for sid, s in pairs(BC.Scores) do
        local ns = s * BC.SCORE_DECAY
        if ns < 0.5 then BC.Scores[sid] = nil else BC.Scores[sid] = ns end
    end

    -- Sprint bumps for currently-sprinting consenting players.
    for _, ply in ipairs(BC:IterConsentingPlayers()) do
        if ply:KeyDown(IN_SPEED) and ply:GetVelocity():Length2D() > 200 then
            BC:Bump(ply, "sprint")
        end
    end

    local candidates = buildCandidates()
    local now = CurTime()

    -- Carry over still-locked slots, drop dead/disconnected players.
    local newAssigns = {}
    local taken = {}
    for idx = 1, BC.MONITOR_COUNT do
        local slot = BC.Assigns[idx]
        if slot and slot.lockedUntil and slot.lockedUntil > now then
            local ply = player.GetBySteamID64(slot.sid64)
            if IsValid(ply) and BC:IsConsenting(ply) then
                newAssigns[idx] = slot
                taken[slot.sid64] = true
            end
        end
    end

    -- Fill remaining slots from candidates above WAKE_THRESHOLD.
    local cIdx = 1
    for idx = 1, BC.MONITOR_COUNT do
        if newAssigns[idx] then continue end
        while cIdx <= #candidates and taken[candidates[cIdx].sid] do cIdx = cIdx + 1 end
        local cand = candidates[cIdx]
        if cand and cand.score >= BC.WAKE_THRESHOLD then
            newAssigns[idx] = {
                sid64       = cand.sid,
                lockedUntil = now + BC.MIN_LOCK_TIME,
                audio       = false,  -- decided below
            }
            taken[cand.sid] = true
            cIdx = cIdx + 1
        end
    end

    -- Audio: top MAX_AUDIO_FEEDS by score among the chosen slots.
    do
        local audioOrder = {}
        for idx, slot in pairs(newAssigns) do
            audioOrder[#audioOrder + 1] = { idx = idx, score = BC.Scores[slot.sid64] or 0 }
        end
        table.sort(audioOrder, function(a, b) return a.score > b.score end)
        for i = 1, math.min(BC.MAX_AUDIO_FEEDS, #audioOrder) do
            local idx = audioOrder[i].idx
            newAssigns[idx].audio = true
        end
    end

    BC.Assigns = newAssigns
    applyAssignments(newAssigns)
    broadcastAssignments(newAssigns)
end

timer.Create("ZScav_Bodycam_DirectorTick", BC.TICK_INTERVAL, 0, tick)

-- Returns the live assigns table so audio relay can ask "is sid64 X currently
-- on a monitor with audio enabled, and if so which monitor index?"
function BC:GetSlotForSID(sid64)
    for idx, slot in pairs(self.Assigns) do
        if slot and slot.sid64 == sid64 and slot.audio then
            return idx
        end
    end
    return nil
end

function BC:GetVisualSlotForSID(sid64)
    for idx, slot in pairs(self.Assigns) do
        if slot and slot.sid64 == sid64 then return idx end
    end
    return nil
end
