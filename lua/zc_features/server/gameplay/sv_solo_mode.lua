-- Solo mode: allows a single player to play coop effectively.
--
-- Fixes:
--   1. Round never starts with 1 player — ZCity's EndRoundThink requires
--      #player_GetAll() > 1. We wrap zb.EndRoundThink to bypass this check
--      when only one human is connected. No bot needed.
--
--   2. Gordon exclusion — handled in sv_coop_respawn.lua.
--
--   3. Solo death = round restart.

if CLIENT then return end

local SOLO_SPAWN_HOOKS = {
    "PlayerGiveSWEP",
    "PlayerSpawnEffect",
    "PlayerSpawnNPC",
    "PlayerSpawnObject",
    "PlayerSpawnProp",
    "PlayerSpawnRagdoll",
    "PlayerSpawnSENT",
    "PlayerSpawnSWEP",
    "PlayerSpawnVehicle"
}

local function DefaultBlockSpawn(ply)
    if game.SinglePlayer() or ply:IsAdmin() then return true end

    return false
end

local function SetSandboxAccess(enabled)
    for _, eventName in ipairs(SOLO_SPAWN_HOOKS) do
        if enabled then
            hook.Remove(eventName, "BlockSpawn")
        else
            hook.Add(eventName, "BlockSpawn", DefaultBlockSpawn)
        end
    end
end

local function GetCurrentRoundSafe()
    if not CurrentRound then return nil end

    local ok, round = pcall(CurrentRound)
    if not ok or not istable(round) then return nil end

    return round
end

local function CanonicalMapName(name)
    if not isstring(name) or name == "" then return "" end
    if ZC_MapRoute and ZC_MapRoute.GetCanonicalMap then
        return tostring(ZC_MapRoute.GetCanonicalMap(name) or name)
    end
    return string.lower(name)
end

local function ShouldUseManagedGordonLoadoutLocal()
    local currentMap = CanonicalMapName(game.GetMap())
    if currentMap == "" then return false end
    if string.match(currentMap, "^d1_") then return true end
    if string.match(currentMap, "^d2_") then return true end
    return false
end

local function GetNativeGordonClassData()
    local useManaged = ShouldUseManagedGordonLoadoutLocal()
    if ZC_ShouldUseManagedGordonLoadout then
        useManaged = ZC_ShouldUseManagedGordonLoadout() == true
    end

    if useManaged then
        return nil
    end

    local round = GetCurrentRoundSafe()
    local mapData = round and round.Maps and round.Maps[game.GetMap()]
    local equipmentMode = tostring((mapData and mapData.PlayerEqipment) or "rebel")
    return { equipment = equipmentMode }
end

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    util.AddNetworkString("ZC_SoloMode")

    local soloMode = false

    local function IsSoloMode()
        return #player.GetHumans() <= 1
    end

    local function BroadcastSoloMode(enabled)
        net.Start("ZC_SoloMode")
            net.WriteBool(enabled)
        net.Broadcast()
    end

    local function UpdateSoloMode(enabled)
        if soloMode == enabled then return end

        soloMode = enabled
        SetSandboxAccess(enabled)
        BroadcastSoloMode(enabled)
    end

    SetSandboxAccess(false)

    -- ── Wrap EndRoundThink to bypass player count check ───────────────────────────

    local function PatchEndRoundThink()
        if not zb or not zb.EndRoundThink then return false end

        local origEndRoundThink = zb.EndRoundThink

        zb.EndRoundThink = function(self)
            -- In solo mode, temporarily fake the player count check
            -- by making the round start condition pass
            if IsSoloMode() and zb.ROUND_STATE == 0 then
                -- Ensure round is initialized before attempting to start it
                if not GetCurrentRoundSafe() then
                    if NextRound then
                        NextRound()
                    end
                    return
                end

                local round = GetCurrentRoundSafe()
                zb.START_TIME = zb.START_TIME or CurTime() + ((round and round.start_time) or 5)
                if zb.START_TIME < CurTime() then
                    zb:RoundStart()
                    -- Return immediately — RoundStart flipped ROUND_STATE to 1.
                    -- Falling through would let origEndRoundThink run state-1 logic
                    -- in the same tick, causing a double-advance.
                end
                return
            end
            origEndRoundThink(self)
        end

        print("[ZC Solo] EndRoundThink patched for solo mode")
        return true
    end

    if not PatchEndRoundThink() then
        hook.Add("InitPostEntity", "ZCity_SoloMode_Init", function()
            timer.Simple(2, function()
                PatchEndRoundThink()
            end)
        end)
    end

    -- ── Solo mode detection ───────────────────────────────────────────────────────

    hook.Add("PlayerInitialSpawn", "ZCity_SoloMode", function(ply)
        if ply:IsBot() then return end

        timer.Simple(1, function()
            if not IsValid(ply) then return end
            if IsSoloMode() then
                UpdateSoloMode(true)
                print("[ZC Solo] Solo mode active for " .. ply:Nick())
            else
                -- Second+ player joined
                if soloMode then
                    UpdateSoloMode(false)
                    print("[ZC Solo] Solo mode disabled — multiple players")
                end
            end
        end)
    end)

    hook.Add("PlayerDisconnected", "ZCity_SoloMode", function(ply)
        if ply:IsBot() then return end
        timer.Simple(1, function()
            if IsSoloMode() and #player.GetHumans() == 1 then
                UpdateSoloMode(true)
                print("[ZC Solo] Back to solo mode")
            elseif #player.GetHumans() == 0 then
                UpdateSoloMode(false)
            end
        end)
    end)

    -- ── Solo: pre-assign self as Gordon before ZCity hands out equipment ─────────
    -- ZB_PreRoundStart fires before GiveEquipment/RoundStart class assignment.
    -- By flagging the player here, ZCity's own Gordon path picks it up natively
    -- and we don't fight with it at ZB_StartRound timing.

    hook.Add("ZB_PreRoundStart", "ZCity_SoloMode_PreAssignGordon", function()
        if not IsSoloMode() then return end
        if not CurrentRound or CurrentRound().name ~= "coop" then return end

        local ply = player.GetAll()[1]
        if not IsValid(ply) then return end

        -- Clear any stale class so ZCity's coop path treats this player as unassigned
        -- and will slot them into Gordon normally.
        ply.ZC_ForceGordon = true
        ply.ZCPreferredSubClass = nil
        ply.subClass = nil
        print("[ZC Solo] Pre-round: flagging " .. ply:Nick() .. " for Gordon assignment")
    end)

    hook.Add("ZB_StartRound", "ZCity_SoloMode_AssignGordon", function()
        if not IsSoloMode() then return end
        if not CurrentRound or CurrentRound().name ~= "coop" then return end

        -- Check if already assigned by ZCity's own path
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply.PlayerClassName == "Gordon" then
                print("[ZC Solo] Gordon already assigned by ZCity: " .. ply:Nick())
                return
            end
        end

        -- ZCity didn't assign Gordon (no eligible player in its logic) — force it
        local ply = player.GetAll()[1]
        if not IsValid(ply) then return end

        print("[ZC Solo] ZB_StartRound: force-assigning Gordon to " .. ply:Nick())
        ply.gottarespawn = true
        ply:Spawn()

        timer.Simple(0, function()
            if not IsValid(ply) then return end
            ply:SetPlayerClass("Gordon", GetNativeGordonClassData())
            ply.ZC_ForceGordon = nil
            ply:ChatPrint("[ZCity] Solo mode — you are Gordon Freeman.")
        end)
    end)

    -- ── Death = round restart ─────────────────────────────────────────────────────

    hook.Add("PlayerDeath", "ZCity_SoloMode_Death", function(ply)
        if not IsSoloMode() then return end
        if ply:IsBot() then return end
        if ply:Team() == TEAM_SPECTATOR then return end
        local round = GetCurrentRoundSafe()
        if not round or round.name ~= "coop" then return end
        if not zb or zb.ROUND_STATE ~= 1 then return end

        print("[ZC Solo] Solo player died — restarting round")
        ply:ChatPrint("[ZCity] You died. Restarting round...")

        timer.Simple(3, function()
            if zb and zb.EndRound then
                zb:EndRound()
            end
        end)
    end)
end

hook.Add("InitPostEntity", "ZC_CoopInit_svsolomode", function()
    local round = GetCurrentRoundSafe()
    print("[ZC Solo] sv_solo_mode InitPostEntity fired; CurrentRound=" .. tostring(round and round.name))
    Initialize()
end)

hook.Add("Think", "ZC_CoopInit_svsolomode_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svsolomode_Late")
        return
    end
    local round = GetCurrentRoundSafe()
    print("[ZC Solo] sv_solo_mode Think check; CurrentRound=" .. tostring(round and round.name))
    Initialize()
end)

