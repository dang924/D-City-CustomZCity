local MODE = MODE

util.AddNetworkString("hidden_start")
util.AddNetworkString("hidden_roundend")
util.AddNetworkString("hidden_ready_toggle")
util.AddNetworkString("hidden_ready_sync")
util.AddNetworkString("hidden_extract_sync")
util.AddNetworkString("hidden_extract_ping")

local HIDDEN_PREP_SYNC_TIMER = "ZBHiddenPrepSync"
local HIDDEN_PREP_END_TIMER = "ZBHiddenPrepEnd"
local HIDDEN_INTEL_SPAWN_TIMER = "ZBHiddenIntelSpawn"
local hiddenReadyBySteamID64 = {}

local function clearHiddenReadyStatus()
    table.Empty(hiddenReadyBySteamID64)
end

local function countHiddenReadyStatus()
    local readyCount = 0
    local totalCount = 0

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() != 1 then continue end

        totalCount = totalCount + 1

        local steamID64 = ply:SteamID64()
        if steamID64 and hiddenReadyBySteamID64[steamID64] then
            readyCount = readyCount + 1
        end
    end

    return readyCount, totalCount
end

local function syncHiddenReadyStatus(target)
    if util.NetworkStringToID("hidden_ready_sync") == 0 then return end

    local readyCount, totalCount = countHiddenReadyStatus()

    net.Start("hidden_ready_sync")
    net.WriteUInt(math.Clamp(readyCount, 0, 255), 8)
    net.WriteUInt(math.Clamp(totalCount, 0, 255), 8)

    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

local function setHiddenReadyStatusForPlayer(ply, isReady)
    if not IsValid(ply) then return false end
    if ply:Team() != 1 then return false end

    local steamID64 = ply:SteamID64()
    if not steamID64 or steamID64 == "" then return false end

    local oldState = hiddenReadyBySteamID64[steamID64] and true or false
    local newState = isReady and true or false

    if newState then
        hiddenReadyBySteamID64[steamID64] = true
    else
        hiddenReadyBySteamID64[steamID64] = nil
    end

    return oldState != newState
end

local function areAllHiddenIrisReady()
    local readyCount, totalCount = countHiddenReadyStatus()
    return totalCount > 0 and readyCount >= totalCount
end

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
    return 1, true
end

local function getPlayingPlayers()
    local players = {}

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        players[#players + 1] = ply
    end

    return players
end

local function getRoundCandidatePlayers()
    local players = {}
    local humans = {}

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        players[#players + 1] = ply

        if not ply:IsBot() then
            humans[#humans + 1] = ply
        end
    end

    if #humans > 0 then
        return humans
    end

    return players
end

local function clearHiddenVipFlags()
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        ply.HiddenIsVIP = false
    end
end

local function assignHiddenVipForRound(mode, players)
    if not mode then return nil end

    clearHiddenVipFlags()
    mode.HiddenVipSteamID64 = nil
    mode.HiddenVipDied = false

    local irisCandidates = {}

    for _, ply in ipairs(players or {}) do
        if not IsValid(ply) then continue end
        if ply:Team() != 1 then continue end
        irisCandidates[#irisCandidates + 1] = ply
    end

    if not mode.HiddenUseVip then
        return nil
    end

    if #irisCandidates <= 0 then
        return nil
    end

    local chosen = irisCandidates[math.random(1, #irisCandidates)]
    if not IsValid(chosen) then return nil end

    chosen.HiddenIsVIP = true
    mode.HiddenVipSteamID64 = chosen:SteamID64()
    return chosen
end

local function getTeamAlive(teamId)
    local players = {}

    for _, ply in player.Iterator() do
        if ply:Team() ~= teamId then continue end
        if not ply:Alive() then continue end
        if ply.organism and ply.organism.incapacitated then continue end
        players[#players + 1] = ply
    end

    return players
end

local function getHiddenMajority(count)
    count = math.max(math.floor(tonumber(count) or 0), 0)
    if count <= 0 then return 0 end
    return math.floor(count / 2) + 1
end

local function getHiddenExtractionPoints()
    return zb.TranslatePointsToVectors(zb.GetMapPoints("HDN_EXTRACT"))
end

local function getHiddenExtractionRadius(mode)
    local cfg = mode and mode.HiddenConfig or nil
    return math.max(tonumber(cfg and cfg.ExtractRadius) or 220, 64)
end

local function getHiddenIntelPoints()
    return zb.TranslatePointsToVectors(zb.GetMapPoints("HDN_INTEL"))
end

local function getHiddenIntelSpawnDelay(mode)
    local cfg = mode and mode.HiddenConfig or nil
    return math.max(tonumber(cfg and cfg.IntelSpawnDelay) or 60, 1)
end

local function countIrisInsideExtraction(mode, irisAlive)
    if not mode or not isvector(mode.HiddenExtractionPoint) then return 0 end

    local radius = getHiddenExtractionRadius(mode)
    local radiusSqr = radius * radius
    local count = 0

    for _, ply in ipairs(irisAlive or {}) do
        if not IsValid(ply) then continue end
        if ply:GetPos():DistToSqr(mode.HiddenExtractionPoint) <= radiusSqr then
            count = count + 1
        end
    end

    return count
end

local function getHiddenVipPlayer(mode)
    if not mode then return nil end
    local vipSteamID64 = mode.HiddenVipSteamID64
    if not vipSteamID64 or vipSteamID64 == "" then return nil end

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() != 1 then continue end
        if ply:SteamID64() == vipSteamID64 then
            return ply
        end
    end
end

local function isVipInsideExtraction(mode, vip)
    if not mode or not isvector(mode.HiddenExtractionPoint) then return false end
    if not IsValid(vip) then return false end
    if not vip:Alive() then return false end

    local radius = getHiddenExtractionRadius(mode)
    local radiusSqr = radius * radius
    return vip:GetPos():DistToSqr(mode.HiddenExtractionPoint) <= radiusSqr
end

local function isVipCarryingIntel(mode, vip)
    if not mode or not IsValid(vip) then return false end

    local intel = mode.HiddenIntelEntity
    if not IsValid(intel) then return false end

    return vip:GetNetVar("carryent") == intel or vip:GetNetVar("carryent2") == intel
end

local function cleanupHiddenIntelEntity(mode)
    if not mode then return end
    if IsValid(mode.HiddenIntelEntity) then
        mode.HiddenIntelEntity:Remove()
    end

    mode.HiddenIntelEntity = nil
    mode.HiddenIntelSpawned = false
    mode.HiddenVipHasIntel = false
end

local function spawnHiddenIntelBriefcase(mode)
    if not mode then return false end
    if not mode.HiddenIntelRequired then return false end
    if IsValid(mode.HiddenIntelEntity) then return true end

    local points = getHiddenIntelPoints()
    if #points <= 0 then
        mode.HiddenExtractionEligible = false

        if not mode.HiddenExtractionWarningSent then
            mode.HiddenExtractionWarningSent = true
            PrintMessage(HUD_PRINTTALK, "[HIDDEN] Intel objective failed: no HDN_INTEL points available.")
            PrintMessage(HUD_PRINTTALK, "[HIDDEN] Kill Subject 617 before timer runs out or IRIS will lose.")
        end
        return false
    end

    local spawnPos = points[math.random(#points)]
    local intel = ents.Create("prop_physics")
    if not IsValid(intel) then return false end

    intel:SetModel("models/props_c17/BriefCase001a.mdl")
    intel:SetPos(spawnPos + Vector(0, 0, 16))
    intel:SetAngles(Angle(0, math.random(0, 359), 0))
    intel:Spawn()
    intel:Activate()
    intel.HiddenIntelObjective = true

    local phys = intel:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    mode.HiddenIntelEntity = intel
    mode.HiddenIntelSpawned = true

    PrintMessage(HUD_PRINTTALK, "[HIDDEN] Intel briefcase has spawned at HDN_INTEL. VIP must carry it to extraction.")
    return true
end

local function syncHiddenExtractionState(mode, target)
    if util.NetworkStringToID("hidden_extract_sync") == 0 then return end

    local point = mode and mode.HiddenExtractionPoint
    local hasPoint = isvector(point)

    net.Start("hidden_extract_sync")
    net.WriteBool(mode and mode.HiddenExtractionActive and true or false)
    net.WriteBool(mode and mode.HiddenExtractionEligible ~= false or false)
    net.WriteVector(hasPoint and point or vector_origin)
    net.WriteUInt(math.Clamp(tonumber(mode and mode.HiddenExtractionRequired) or 0, 0, 255), 8)
    net.WriteUInt(math.Clamp(tonumber(mode and mode.HiddenExtractionCurrent) or 0, 0, 255), 8)
    net.WriteBool(mode and mode.HiddenUseVip and true or false)
    net.WriteBool(mode and mode.HiddenIntelRequired and true or false)
    net.WriteBool(mode and mode.HiddenVipAtExtraction and true or false)
    net.WriteBool(mode and mode.HiddenVipHasIntel and true or false)

    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

local function pingHiddenExtractionPoint(mode)
    if util.NetworkStringToID("hidden_extract_ping") == 0 then return end
    if not mode or not isvector(mode.HiddenExtractionPoint) then return end

    net.Start("hidden_extract_ping")
    net.WriteVector(mode.HiddenExtractionPoint)
    net.Broadcast()
end

local function beginHiddenExtraction(mode, irisAlive)
    if not mode then return false end
    if mode.HiddenExtractionActive then return true end

    local points = getHiddenExtractionPoints()
    if #points <= 0 then
        mode.HiddenExtractionEligible = false
        return false
    end

    mode.HiddenExtractionPoint = points[math.random(#points)]
    mode.HiddenExtractionActive = true
    mode.HiddenExtractionRequired = mode.HiddenUseVip and 1 or getHiddenMajority(#irisAlive)
    mode.HiddenExtractionCurrent = mode.HiddenUseVip and 0 or countIrisInsideExtraction(mode, irisAlive)
    mode.HiddenExtractionNextSync = CurTime() + 1
    mode.HiddenVipAtExtraction = false
    mode.HiddenVipHasIntel = false

    local p = mode.HiddenExtractionPoint
    PrintMessage(HUD_PRINTTALK, string.format("[HIDDEN] Extraction active at HDN_EXTRACT point (%.0f %.0f %.0f).", p.x, p.y, p.z))

    if mode.HiddenUseVip then
        if mode.HiddenIntelRequired then
            PrintMessage(HUD_PRINTTALK, "[HIDDEN] IRIS VIP must extract while carrying the intel briefcase.")
        else
            PrintMessage(HUD_PRINTTALK, "[HIDDEN] IRIS VIP must reach extraction to win.")
        end
    else
        PrintMessage(HUD_PRINTTALK, "[HIDDEN] Majority of living IRIS must reach extraction to win.")
    end

    syncHiddenExtractionState(mode)
    pingHiddenExtractionPoint(mode)

    return true
end

local function isHiddenRoundActive()
    local round = CurrentRound and CurrentRound()
    return round and round.name == MODE.name
end

local function isHiddenPrepActive(mode)
    if not mode then return false end
    if mode.HiddenPrepActive ~= nil then
        return mode.HiddenPrepActive and true or false
    end

    return mode.IsHiddenPreparationPhase and mode:IsHiddenPreparationPhase() or false
end

local function getIrisPrepHoldingPosition()
    local groups = {"HDN_IRIS", "HDN_IRISSPAWN", "HMCD_TDM_CT"}

    for _, groupName in ipairs(groups) do
        if not isstring(groupName) or groupName == "" then continue end

        local points = zb.TranslatePointsToVectors(zb.GetMapPoints(groupName))
        if #points > 0 then
            return points[math.random(#points)]
        end
    end
end

local function clearIrisPrepSpectatorArtifacts(ply)
    if not IsValid(ply) then return end

    local fakeRagdoll = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply:GetNWEntity("FakeRagdoll")
    if IsValid(fakeRagdoll) then
        fakeRagdoll:SetNWEntity("ply", NULL)
        fakeRagdoll:Remove()
    end

    ply.FakeRagdoll = nil
    ply:SetNWEntity("FakeRagdoll", NULL)

    local corpse = ply:GetNWEntity("RagdollDeath")
    if IsValid(corpse) then
        corpse:SetNWEntity("ply", NULL)
        corpse:Remove()
    end

    if IsValid(ply.RagdollDeath) then
        ply.RagdollDeath:Remove()
    end

    ply.RagdollDeath = nil
    ply:SetNWEntity("RagdollDeath", NULL)
end

local function setIrisPrepSpectator(ply)
    if not IsValid(ply) then return end
    if ply:Alive() then return end

    clearIrisPrepSpectatorArtifacts(ply)

    if ply:Team() == 1 then
        ply.HiddenPrepHoldingPos = isvector(ply.HiddenPrepHoldingPos) and ply.HiddenPrepHoldingPos or getIrisPrepHoldingPosition()
        if isvector(ply.HiddenPrepHoldingPos) then
            ply:SetPos(ply.HiddenPrepHoldingPos)
            ply:SetLocalVelocity(vector_origin)
        end
    end

    ply.viewmode = 0
    ply:Spectate(OBS_MODE_NONE)
    ply:SetMoveType(MOVETYPE_NONE)
end

local function queueHiddenLoadoutMenu(mode, ply)
    if not mode or not mode.SendHiddenLoadoutData then return end
    if not IsValid(ply) then return end

    for _, delay in ipairs({0, 0.2, 0.75}) do
        timer.Simple(delay, function()
            if not isHiddenRoundActive() then return end
            if not IsValid(ply) then return end
            if ply:Team() != 1 then return end
            if not isHiddenPrepActive(mode) then return end

            mode:SendHiddenLoadoutData(ply, true)
        end)
    end
end

local function restoreHiddenCombatSpawnState(ply)
    if not IsValid(ply) then return end

    ply.HiddenPrepHoldingPos = nil
    ply:UnSpectate()
    ply:SetMoveType(MOVETYPE_WALK)
    ply.lastSpectTarget = nil
    ply.chosenSpectEntity = nil
end

local function forceHiddenTeamSpawnPosition(ply)
    if not IsValid(ply) then return end
    if not ply:Alive() then return end

    local spawnPos = zb.GetTeamSpawn and zb:GetTeamSpawn(ply) or nil
    if not isvector(spawnPos) then return end

    ply:SetPos(spawnPos)
    ply:SetLocalVelocity(vector_origin)
end

local function setHiddenPrepState(active, combatStart, combatDuration)
    if util.NetworkStringToID("hidden_prep_state") == 0 then return end

    net.Start("hidden_prep_state")
    net.WriteBool(active and true or false)
    net.WriteFloat(tonumber(combatStart) or 0)
    net.WriteFloat(tonumber(combatDuration) or 0)
    net.Broadcast()
end

local function clearHiddenPrepTimers()
    timer.Remove(HIDDEN_PREP_SYNC_TIMER)
    timer.Remove(HIDDEN_PREP_END_TIMER)
end

local function clearHiddenLeapImpactProtection(ply, force)
    if not IsValid(ply) then return end
    if not force and (ply.HiddenLeapImpactProtectUntil or 0) > CurTime() then return end
    ply.HiddenLeapImpactProtectUntil = 0
end

local function resetHiddenRoundPlayerState(ply)
    if not IsValid(ply) then return end

    ply.HiddenLeapEndsAt = 0
    ply.HiddenLeapHit = false
    clearHiddenLeapImpactProtection(ply, true)
    ply:SetNWFloat("HiddenNextLeap", 0)
end

local function killSubject617ForRoundEnd(ply)
    if not IsValid(ply) then return end
    if ply:Team() != 0 then return end
    if not ply:Alive() then return end

    -- Only un-fake the player if a fake ragdoll is currently attached, otherwise
    -- we can fall through to Kill() which drops the real ragdoll. Avoid spawning
    -- a SECOND ragdoll when a fake one already exists — doubled ragdolls plus a
    -- pending game.CleanUpMap() in Intermission has been a long-time engine
    -- crash trigger.
    if hg and hg.FakeUp and IsValid(ply.FakeRagdoll) then
        hg.FakeUp(ply, true, true)
        resetHiddenRoundPlayerState(ply)
        return
    end

    if not ply:Alive() then return end

    resetHiddenRoundPlayerState(ply)
    ply:SetNoTarget(false)
    ply:SetRenderMode(RENDERMODE_NORMAL)
    ply:SetColor(color_white)
    ply:KillSilent() -- KillSilent avoids a visible ragdoll that would be force-removed by CleanUpMap a few seconds later
end

local function applyHiddenLeapImpactProtection(mode, ply)
    if not IsValid(ply) then return end

    local untilTime = CurTime() + (mode.HiddenConfig.LeapDuration or 0) + (mode.HiddenConfig.LeapImpactGrace or 0)
    ply.HiddenLeapImpactProtectUntil = math.max(ply.HiddenLeapImpactProtectUntil or 0, untilTime)
end

local function queueHiddenCombatEquipment(mode, ply)
    if not mode or not mode.ApplyHiddenCombatEquipment then return end
    if not IsValid(ply) or ply.HiddenCombatEquipPending then return end

    ply.HiddenCombatEquipPending = true

    timer.Simple(0, function()
        if not IsValid(ply) then return end

        ply.HiddenCombatEquipPending = nil

        if not isHiddenRoundActive() then return end
        if not ply:Alive() then return end
        if ply:Team() != 0 then return end

        mode:ApplyHiddenCombatEquipment(ply)
    end)
end

local function applyHiddenPlayerSpawnState(mode, ply)
    if not mode then return end
    if not IsValid(ply) then return end
    if ply:Team() == TEAM_SPECTATOR then return end

    local cfg = mode.HiddenConfig
    clearHiddenLeapImpactProtection(ply, true)

    local prepActive = isHiddenPrepActive(mode)
    if prepActive and ply:Team() == 1 then
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            if ply:Alive() then
                ply:KillSilent()
            end

            setIrisPrepSpectator(ply)
        end)

        return
    end

    restoreHiddenCombatSpawnState(ply)

    if ply:Team() == 0 then
        ply:SetHealth(cfg.HiddenHealth)
        ply:SetMaxHealth(cfg.HiddenHealth)
        ply:SetRunSpeed(cfg.HiddenRunSpeed)
        ply:SetWalkSpeed(cfg.HiddenWalkSpeed)
        ply:SetJumpPower(cfg.HiddenJumpPower)
        ply:SetGravity(cfg.HiddenGravity)
        ply:SetNoTarget(true)
        queueHiddenCombatEquipment(mode, ply)
    else
        ply:SetHealth(cfg.IrisHealth)
        ply:SetMaxHealth(cfg.IrisHealth)
        ply:SetRunSpeed(cfg.IrisRunSpeed)
        ply:SetWalkSpeed(cfg.IrisWalkSpeed)
        ply:SetJumpPower(cfg.IrisJumpPower)
        ply:SetGravity(cfg.IrisGravity)
        ply:SetNoTarget(false)
        ply:SetRenderMode(RENDERMODE_NORMAL)
        ply:SetColor(color_white)
    end
end

local function startHiddenCombat(mode)
    if not mode then return end

    if mode.HiddenCombatStarted then
        mode.HiddenPrepActive = false
        clearHiddenPrepTimers()
        return
    end

    local combatDuration = math.max(tonumber(mode.HiddenConfig and mode.HiddenConfig.CombatDuration) or 240, 1)
    local combatStart = CurTime()

    -- Reset the round clock so HUD shows the full combat duration (e.g. 4:00),
    -- regardless of whether prep ended via the ready system or the timer expiring.
    zb.ROUND_START = combatStart
    zb.ROUND_TIME = combatDuration
    zb.ROUND_BEGIN = combatStart

    mode.HiddenPrepActive = false
    clearHiddenPrepTimers()
    setHiddenPrepState(false, combatStart, combatDuration)
    clearHiddenReadyStatus()
    syncHiddenReadyStatus()

    PrintMessage(HUD_PRINTTALK, "[HIDDEN] Prep phase has ended. Combat begins now!")

    mode.HiddenCombatStarted = true
    mode.HiddenCombatStartedAt = combatStart
    mode.HiddenCombatEndsAt = combatStart + combatDuration
    mode.HiddenExtractionActive = false
    mode.HiddenExtractionEligible = true
    mode.HiddenExtractionPoint = nil
    mode.HiddenExtractionRequired = 0
    mode.HiddenExtractionCurrent = 0
    mode.HiddenExtractionWarningSent = false
    mode.HiddenExtractionNextSync = 0
    mode.HiddenIrisStartingCount = 0

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if ply:Team() != 1 then continue end
        if ply:Alive() then continue end

        restoreHiddenCombatSpawnState(ply)
        ply:Spawn()

        timer.Simple(0, function()
            if not IsValid(ply) then return end

            restoreHiddenCombatSpawnState(ply)
            forceHiddenTeamSpawnPosition(ply)
        end)
    end

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end

        resetHiddenRoundPlayerState(ply)

        if not ply:Alive() then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if ply:Team() == 0 then continue end -- 617 keeps their position
        if not mode.ApplyHiddenCombatEquipment then continue end

        restoreHiddenCombatSpawnState(ply)
        forceHiddenTeamSpawnPosition(ply)
        mode:ApplyHiddenCombatEquipment(ply)
    end

    local irisStartingCount = 0
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() != 1 then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        irisStartingCount = irisStartingCount + 1
    end
    mode.HiddenIrisStartingCount = irisStartingCount

    syncHiddenExtractionState(mode)

end

local function beginHiddenPreparation(mode)
    if not mode then return end

    mode.HiddenPrepActive = true
    clearHiddenPrepTimers()
    setHiddenPrepState(true)
    clearHiddenReadyStatus()
    syncHiddenReadyStatus()

    -- Send loadout menu exactly once per IRIS player at prep start.
    -- PlayerDeath handles re-sending if a player dies mid-prep.
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() != 1 then continue end
        queueHiddenLoadoutMenu(mode, ply)
    end

    timer.Create(HIDDEN_PREP_SYNC_TIMER, 0.5, 0, function()
        if not isHiddenRoundActive() then
            clearHiddenPrepTimers()
            return
        end

        if not isHiddenPrepActive(mode) then
            timer.Remove(HIDDEN_PREP_SYNC_TIMER)
            return
        end

        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end
            if ply:Team() != 1 then continue end

            if ply:Alive() then
                ply:KillSilent()
            end

            setIrisPrepSpectator(ply)
        end

        syncHiddenReadyStatus()

        if areAllHiddenIrisReady() then
            -- startHiddenCombat now centralises the round-clock reset + chat broadcast,
            -- so both the ready-system path and the prep-timer-expiry path stay consistent.
            startHiddenCombat(mode)
            return
        end
    end)

    local prepDuration = math.max((zb.ROUND_BEGIN or CurTime()) - CurTime(), 0)
    timer.Create(HIDDEN_PREP_END_TIMER, prepDuration + 0.05, 1, function()
        if not isHiddenRoundActive() then return end
        startHiddenCombat(mode)
    end)
end

hook.Add("EntityTakeDamage", "HiddenLeapImpactProtection", function(ent, dmgInfo)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    if ent:Team() != 0 then return end
    if (ent.HiddenLeapImpactProtectUntil or 0) <= CurTime() then return end
    if not isHiddenRoundActive() then return end
    if not dmgInfo:IsDamageType(DMG_FALL + DMG_CRUSH) then return end

    dmgInfo:SetDamage(0)
    dmgInfo:ScaleDamage(0)
end)

function MODE:CanLaunch()
    return true
end

function MODE:PickHiddenPlayer(players, previousHiddenSteamID64)
    if #players == 0 then return nil, nil end

    local eligible = {}

    for index, ply in ipairs(players) do
        if not IsValid(ply) then continue end

        if #players > 1 and previousHiddenSteamID64 and ply:SteamID64() == previousHiddenSteamID64 then
            continue
        end

        eligible[#eligible + 1] = {
            ply = ply,
            index = index,
        }
    end

    if #eligible == 0 then
        for index, ply in ipairs(players) do
            if not IsValid(ply) then continue end
            eligible[#eligible + 1] = {
                ply = ply,
                index = index,
            }
        end
    end

    if #eligible == 0 then return nil, nil end

    local pick = eligible[math.random(1, #eligible)]
    return pick.ply, pick.index
end

-- Drop networked entity references and detach players from spectate/ragdoll state
-- BEFORE game.CleanUpMap() so cleanup doesn't tear down entities the player is
-- still bound to (one of the most common engine-crash paths on Hidden round
-- restart, since IRIS players sit in OBS_MODE_NONE + MOVETYPE_NONE during prep).
local function prepareHiddenPlayersForCleanup()
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end

        clearIrisPrepSpectatorArtifacts(ply)
        ply.HiddenPrepHoldingPos = nil
        ply.HiddenCombatEquipPending = nil

        if ply:GetObserverMode() ~= OBS_MODE_NONE or ply.viewmode == 0 then
            pcall(function() ply:UnSpectate() end)
        end

        if ply:GetMoveType() == MOVETYPE_NONE then
            pcall(function() ply:SetMoveType(MOVETYPE_WALK) end)
        end

        -- Drop any lingering ragdoll the engine might double-free during CleanUpMap.
        if IsValid(ply.FakeRagdoll) then ply.FakeRagdoll:Remove() end
        if IsValid(ply.RagdollDeath) then ply.RagdollDeath:Remove() end
        ply.FakeRagdoll = nil
        ply.RagdollDeath = nil
    end
end

function MODE:Intermission()
    prepareHiddenPlayersForCleanup()

    game.CleanUpMap()

    clearHiddenReadyStatus()
    syncHiddenReadyStatus()

    local players = getPlayingPlayers()
    if #players < 2 then
        players = getRoundCandidatePlayers()
    end

    local previousHiddenSteamID64 = self.HiddenSteamID64
    local hidden, hiddenIndex = self:PickHiddenPlayer(players, previousHiddenSteamID64)
    local hiddenAssigned = false

    self.HiddenSteamID64 = IsValid(hidden) and hidden:SteamID64() or nil
    self.HiddenVipSteamID64 = nil
    self.HiddenVipDied = false
    self.HiddenRoundPlayerCount = #players
    self.HiddenUseVip = self.HiddenRoundPlayerCount > 5
    self.HiddenIntelRequired = self.HiddenRoundPlayerCount > 10
    self.HiddenIntelSpawned = false
    self.HiddenIntelEntity = nil
    self.HiddenVipAtExtraction = false
    self.HiddenVipHasIntel = false
    self.RoundWinner = nil
    self.RoundWinnerText = nil

    -- Hidden mode manages spawning itself; suppress the base PlayerSelectSpawn
    -- during SetupTeam calls to prevent a crash when no zb spawn points are registered.
    -- pcall every SetupTeam so an error in one player can't leave PlayerSelectSpawn
    -- permanently nil-functioned (which would silently spawn future players at the
    -- world origin and crash any weapon SWEP that initializes off the player pos).
    local _savedPSS = PlayerSelectSpawn
    PlayerSelectSpawn = function() end

    local ok, err = pcall(function()
        for index, ply in ipairs(players) do
            if not IsValid(ply) then continue end

            local teamId = (hiddenIndex and index == hiddenIndex) and 0 or 1
            ply:SetupTeam(teamId)

            if teamId == 0 then
                hiddenAssigned = true
                self.HiddenSteamID64 = ply:SteamID64()
            end
        end

        if not hiddenAssigned then
            for _, ply in ipairs(players) do
                if not IsValid(ply) then continue end

                ply:SetupTeam(0)
                hiddenAssigned = true
                self.HiddenSteamID64 = ply:SteamID64()
                break
            end
        end
    end)

    PlayerSelectSpawn = _savedPSS

    if not ok then
        ErrorNoHaltWithStack("[Hidden] Intermission SetupTeam failed: " .. tostring(err) .. "\n")
    end

    assignHiddenVipForRound(self, players)

    net.Start("hidden_start")
    net.Broadcast()
end

function MODE:CheckAlivePlayers()
    return {
        [0] = getTeamAlive(0),
        [1] = getTeamAlive(1),
    }
end

function MODE:ShouldRoundEnd()
    -- Never end the round during prep; IRIS are intentionally dead/spectating.
    if isHiddenPrepActive(self) then return false end

    -- Don't end before combat has actually started (covers the prep->combat transition frame).
    if not self.HiddenCombatStarted then return false end

    -- Give IRIS 3 seconds to fully spawn before counting them as dead.
    if CurTime() < (self.HiddenCombatStartedAt or 0) + 3 then return false end

    if self.HiddenUseVip and self.HiddenVipDied then
        self.RoundWinner = 0
        self.RoundWinnerText = "Subject 617 eliminated the VIP."
        return true
    end

    local hiddenAlive = getTeamAlive(0)
    local irisAlive = getTeamAlive(1)

    if #hiddenAlive <= 0 then
        self.RoundWinner = 1
        self.RoundWinnerText = "IRIS contained Subject 617."
        return true
    end

    if #irisAlive <= 0 then
        self.RoundWinner = 0
        self.RoundWinnerText = "Subject 617 wiped out IRIS."
        return true
    end

    if not self.HiddenUseVip then
        local combatEndAt = tonumber(self.HiddenCombatEndsAt) or ((self.HiddenCombatStartedAt or CurTime()) + math.max(tonumber(self.HiddenConfig and self.HiddenConfig.CombatDuration) or 240, 1))
        if CurTime() >= combatEndAt then
            self.RoundWinner = 1
            self.RoundWinnerText = "Time expired. IRIS survived Subject 617."
            return true
        end

        return false
    end

    if not self.HiddenExtractionActive then
        local startCount = math.max(tonumber(self.HiddenIrisStartingCount) or 0, 0)
        if self.HiddenExtractionEligible ~= false and startCount > 0 then
            local minAliveForExtraction = getHiddenMajority(startCount)
            if #irisAlive < minAliveForExtraction then
                self.HiddenExtractionEligible = false
                if not self.HiddenExtractionWarningSent then
                    self.HiddenExtractionWarningSent = true
                    PrintMessage(HUD_PRINTTALK, "[HIDDEN] Extraction is no longer available: IRIS losses exceeded majority.")
                    PrintMessage(HUD_PRINTTALK, "[HIDDEN] Kill Subject 617 before timer runs out or IRIS will lose.")
                end
                syncHiddenExtractionState(self)
            end
        end

        local combatEndAt = tonumber(self.HiddenCombatEndsAt) or ((self.HiddenCombatStartedAt or CurTime()) + math.max(tonumber(self.HiddenConfig and self.HiddenConfig.CombatDuration) or 240, 1))
        if CurTime() >= combatEndAt then
            if self.HiddenExtractionEligible == false then
                self.RoundWinner = 0
                self.RoundWinnerText = "Time expired. IRIS failed to eliminate Subject 617."
                return true
            end

            if not beginHiddenExtraction(self, irisAlive) then
                self.RoundWinner = 0
                self.RoundWinnerText = "Time expired. No HDN_EXTRACT points available; Subject 617 wins."
                return true
            end

            return false
        end

        return false
    end

    local vip = getHiddenVipPlayer(self)
    local vipAtExtraction = isVipInsideExtraction(self, vip)
    local vipHasIntel = self.HiddenIntelRequired and isVipCarryingIntel(self, vip) or false

    self.HiddenVipAtExtraction = vipAtExtraction
    self.HiddenVipHasIntel = vipHasIntel
    self.HiddenExtractionRequired = 1
    self.HiddenExtractionCurrent = vipAtExtraction and 1 or 0

    if CurTime() >= (self.HiddenExtractionNextSync or 0) then
        self.HiddenExtractionNextSync = CurTime() + 1
        syncHiddenExtractionState(self)
    end

    if vipAtExtraction then
        if not self.HiddenIntelRequired then
            self.RoundWinner = 1
            self.RoundWinnerText = "IRIS VIP extracted successfully."
            return true
        end

        if vipHasIntel then
            self.RoundWinner = 1
            self.RoundWinnerText = "IRIS VIP extracted with the intel briefcase."
            return true
        end
    end

    return false
end

function MODE:BoringRoundFunction()
    -- Hidden now controls timeout transitions in ShouldRoundEnd.
end

function MODE:RoundStart()
    self.HiddenCombatStarted = false
    self.HiddenCombatStartedAt = 0
    self.HiddenCombatEndsAt = 0
    self.Hidden617WarnedMotion = false
    self.Hidden617WarnedThermal = false
    self.HiddenPrepActive = false
    self.HiddenVipDied = false
    self.HiddenExtractionActive = false
    self.HiddenExtractionEligible = true
    self.HiddenExtractionPoint = nil
    self.HiddenExtractionRequired = 0
    self.HiddenExtractionCurrent = 0
    self.HiddenExtractionWarningSent = false
    self.HiddenExtractionNextSync = 0
    self.HiddenIrisStartingCount = 0
    self.HiddenRoundPlayerCount = math.max(tonumber(self.HiddenRoundPlayerCount) or 0, 0)
    self.HiddenUseVip = self.HiddenRoundPlayerCount > 5
    self.HiddenIntelRequired = self.HiddenRoundPlayerCount > 10
    self.HiddenIntelSpawned = false
    self.HiddenIntelEntity = nil
    self.HiddenVipAtExtraction = false
    self.HiddenVipHasIntel = false
    timer.Remove(HIDDEN_INTEL_SPAWN_TIMER)
    cleanupHiddenIntelEntity(self)
    clearHiddenReadyStatus()
    syncHiddenReadyStatus()
    syncHiddenExtractionState(self)

    local prepDuration = self.HiddenConfig.PrepDuration or 60
    zb.ROUND_BEGIN = CurTime() + prepDuration

    local prepActive = prepDuration > 0
    self.HiddenPrepActive = prepActive

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end

        resetHiddenRoundPlayerState(ply)

        if prepActive and ply:Team() == 0 and ply:Alive() then
            queueHiddenCombatEquipment(self, ply)
        end
    end

    if prepActive then
        if self.HiddenUseVip and self.HiddenIntelRequired then
            local intelSpawnDelay = getHiddenIntelSpawnDelay(self)
            timer.Create(HIDDEN_INTEL_SPAWN_TIMER, intelSpawnDelay, 1, function()
                local round = CurrentRound and CurrentRound()
                if round != self then return end
                if not isHiddenRoundActive() then return end
                if not self.HiddenCombatStarted and not isHiddenPrepActive(self) then return end

                spawnHiddenIntelBriefcase(self)
                syncHiddenExtractionState(self)
            end)
        end

        beginHiddenPreparation(self)
        return
    end

    if self.HiddenUseVip and self.HiddenIntelRequired then
        local intelSpawnDelay = getHiddenIntelSpawnDelay(self)
        timer.Create(HIDDEN_INTEL_SPAWN_TIMER, intelSpawnDelay, 1, function()
            local round = CurrentRound and CurrentRound()
            if round != self then return end
            if not isHiddenRoundActive() then return end

            spawnHiddenIntelBriefcase(self)
            syncHiddenExtractionState(self)
        end)
    end

    startHiddenCombat(self)
end

function MODE:GiveEquipment()
    timer.Simple(0, function()
        self.HiddenCombatStarted = false

        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end

            if not ply:Alive() then
                ply:Spawn()
            end
        end

        timer.Simple(0.1, function()
            for _, ply in player.Iterator() do
                if not IsValid(ply) then continue end
                if not ply:Alive() then continue end
                if ply:Team() == TEAM_SPECTATOR then continue end

                ply:StripWeapons()
                ply:StripAmmo()
                ply:SetSuppressPickupNotices(true)
                ply.noSound = true

                local hands = ply:Give("weapon_hands_sh")

                if ply:Team() == 0 then
                    ply:SetPlayerClass("subject617")
                    zb.GiveRole(ply, "Subject 617", Color(170, 30, 30))
                    ply:SetNetVar("CurPluv", "pluvboss")
                    queueHiddenCombatEquipment(self, ply)
                else
                    local isVip = self.HiddenUseVip and self.HiddenVipSteamID64 and ply:SteamID64() == self.HiddenVipSteamID64
                    ply.HiddenIsVIP = isVip and true or false

                    if isVip then
                        ply:SetPlayerClass("hiddenvip")
                        zb.GiveRole(ply, "IRIS VIP", Color(230, 205, 80))
                    else
                        ply:SetPlayerClass("swat")
                        zb.GiveRole(ply, "IRIS Operative", Color(25, 110, 210))
                    end

                    ply:SetNetVar("CurPluv", "pluvberet")

                    if self.EnsureHiddenSling then
                        self:EnsureHiddenSling(ply)
                    end

                    if self.ClearHiddenArmor then
                        self:ClearHiddenArmor(ply)
                    end

                    ply:KillSilent()
                    timer.Simple(0, function()
                        if not IsValid(ply) then return end
                        setIrisPrepSpectator(ply)
                    end)
                end

                if IsValid(hands) then
                    ply:SelectWeapon(hands:GetClass())
                end

                resetHiddenRoundPlayerState(ply)

                timer.Simple(0.1, function()
                    if not IsValid(ply) then return end
                    ply.noSound = false
                end)

                ply:SetSuppressPickupNotices(false)
            end

            clearHiddenPrepTimers()
            setHiddenPrepState(false)
        end)
    end)
end

function MODE:CanSpawn()
    return false
end

local function getPreferredSpawnVectors(...)
    for index = 1, select("#", ...) do
        local pointGroup = select(index, ...)
        if not isstring(pointGroup) or pointGroup == "" then continue end

        local points = zb.TranslatePointsToVectors(zb.GetMapPoints(pointGroup))
        if #points > 0 then
            return points
        end
    end

    return {}
end

function MODE:GetTeamSpawn()
    local hiddenSpawns = getPreferredSpawnVectors("HDN_SUBSPAWN", "HDN_HIDDEN", "HMCD_TDM_T")
    local irisSpawns = getPreferredSpawnVectors("HDN_IRISSPAWN", "HDN_IRIS", "HMCD_TDM_CT")

    return hiddenSpawns, irisSpawns
end

function MODE:PlayerSpawn(ply)
    applyHiddenPlayerSpawnState(self, ply)
end

function MODE:KeyPress(ply, key)
    -- Subject 617 leap is handled by the subject617 playerclass to work in and outside Hidden mode.
    return
end

function MODE:RoundThink()
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if (ply.HiddenLeapImpactProtectUntil or 0) <= 0 then continue end
        if (ply.HiddenLeapImpactProtectUntil or 0) > CurTime() then continue end

        clearHiddenLeapImpactProtection(ply, true)
    end

    if isHiddenPrepActive(self) then
        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end
            if ply:Team() != 1 then continue end

            if ply:Alive() then
                ply:KillSilent()
            end

            setIrisPrepSpectator(ply)
        end
    elseif not self.HiddenCombatStarted then
        startHiddenCombat(self)
    end

end

function MODE:EndRound()
    self.HiddenPrepActive = false
    clearHiddenPrepTimers()
    timer.Remove(HIDDEN_INTEL_SPAWN_TIMER)
    cleanupHiddenIntelEntity(self)
    setHiddenPrepState(false)
    clearHiddenReadyStatus()
    syncHiddenReadyStatus()

    local winner = self.RoundWinner
    local winnerText = tostring(self.RoundWinnerText or "")

    if winnerText == "" then
        winnerText = (winner == 0 and "Subject 617 wiped out IRIS.") or "IRIS contained Subject 617."
    end

    PrintMessage(HUD_PRINTTALK, winnerText)

    -- Only hard-kill Subject 617 when they lose so the body remains visible.
    if winner == 1 then
        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end
            if ply:Team() != 0 then continue end
            if not ply:Alive() then continue end

            resetHiddenRoundPlayerState(ply)
            ply:SetNoTarget(false)
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:SetColor(color_white)
            ply:Kill()
        end
    end

    timer.Simple(2, function()
        net.Start("hidden_roundend")
        net.WriteInt(winner or 1, 4)
        net.Broadcast()
    end)

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end

        if winner and ply:Team() == winner then
            ply:GiveExp(math.random(18, 32))
            ply:GiveSkill(math.Rand(0.1, 0.16))
        else
            ply:GiveSkill(-math.Rand(0.04, 0.08))
        end
    end
end

function MODE:PlayerDeath(ply)
    ply:SetNoTarget(false)
    ply.HiddenLeapEndsAt = 0
    ply.HiddenLeapHit = false
    clearHiddenLeapImpactProtection(ply, true)

    if isHiddenPrepActive(self) and IsValid(ply) and ply:Team() == 1 then
        setHiddenReadyStatusForPlayer(ply, false)
        syncHiddenReadyStatus()

        timer.Simple(0, function()
            if not IsValid(ply) then return end
            setIrisPrepSpectator(ply)
            queueHiddenLoadoutMenu(self, ply)
        end)
    end

    if self.HiddenUseVip and not isHiddenPrepActive(self) and self.HiddenCombatStarted and IsValid(ply) and ply:Team() == 1 then
        if self.HiddenVipSteamID64 and ply:SteamID64() == self.HiddenVipSteamID64 then
            self.HiddenVipDied = true
        end
    end
end

net.Receive("hidden_ready_toggle", function(_, ply)
    if not isHiddenRoundActive() then return end
    if not IsValid(ply) then return end
    if ply:Team() != 1 then return end

    local round = CurrentRound and CurrentRound()
    if not round or round.name != MODE.name then return end
    if not isHiddenPrepActive(round) then return end

    local steamID64 = ply:SteamID64()
    if not steamID64 or steamID64 == "" then return end

    local currentState = hiddenReadyBySteamID64[steamID64] and true or false
    setHiddenReadyStatusForPlayer(ply, not currentState)
    syncHiddenReadyStatus()

    if areAllHiddenIrisReady() then
        zb.ROUND_BEGIN = CurTime()
        startHiddenCombat(round)
    end
end)

hook.Add("PlayerSpawn", "HiddenRoundPlayerSpawn", function(ply)
    if zb.ROUND_STATE != 1 then return end
    if not isHiddenRoundActive() then return end

    local round = CurrentRound and CurrentRound()
    if not round or round.name != MODE.name or not round.PlayerSpawn then return end

    round:PlayerSpawn(ply)
end)