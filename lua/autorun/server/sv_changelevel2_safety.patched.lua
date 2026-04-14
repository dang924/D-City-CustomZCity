if CLIENT then return end

if not ZC_MapRoute then
    include("autorun/sh_zc_map_route.lua")
end

local MapRoute = ZC_MapRoute or {}

local function CanonicalMapName(name)
    if MapRoute.GetCanonicalMap then return MapRoute.GetCanonicalMap(name) end
    return isstring(name) and string.lower(name) or ""
end

local TOWN_ALLOWED_ROUTE = {
    d1_town_02 = "d1_town_03",
    d1_town_03 = "d1_town_02",
    d2_town_02 = "d2_town_03",
    d2_town_03 = "d2_town_02",
}

local MANAGED_SOURCE_MAPS = {
    d1_town_02 = true,
    d1_town_03 = true,
    d2_town_02 = true,
    d2_town_03 = true,
}

local PINNED_TRIGGER_MINS = {
    d1_town_02 = Vector(-3648, -448, -3528),
    d1_town_03 = Vector(-3764, -68, -3408),
}

local PINNED_TRIGGER_POINTS = {
    d1_town_02 = Vector(-3648, -448, -3528),
}

local SYNTHETIC_PROXY_BOUNDS = {
    d1_town_02 = {
        center = Vector(-3648, -448, -3528),
        halfExtents = Vector(192, 192, 160),
    },
    d1_town_03 = {
        -- forward exit out of Ravenholm (PINNED_TRIGGER_MINS position)
        center = Vector(-3764, -68, -3408),
        halfExtents = Vector(192, 192, 160),
    },
}

local ALWAYS_DISABLED_TRIGGER_MINS = {
    d1_town_02 = {
        Vector(-3916, -680, -3288),
    },
}

local ALWAYS_DISABLED_TRIGGER_POINTS = {
    d1_town_02 = {
        Vector(-3916, -680, -3288),
    },
}

local NEEDS_RETURN_SPAWN = {
    d1_town_02 = true,
    d2_town_02 = true,
}

local DATA_FILE = "zcity_skip_return.json"
local transitionLocked = false
local triggerProxies = {}
local triggersDisabledThisMap = false
local nextProxyRetryAt = 0

local crossedPlayers = {}
local gordonCrossed = false
local majorityTimerStarted = false
local majorityTimerName = "ZC_TownProxy_Majority"
local pendingTargetMap = ""
local pendingLandmark = ""

local debugEnabled = false
local nextNoProxyDebugAt = 0

local function Dbg(msg)
    if not debugEnabled then return end
    print("[ZC TownDbg] " .. tostring(msg))
end

local function VecApproxEqual(a, b, tolerance)
    tolerance = tolerance or 2
    return math.abs(a.x - b.x) <= tolerance
        and math.abs(a.y - b.y) <= tolerance
        and math.abs(a.z - b.z) <= tolerance
end

local function PointInAABB(pos, mins, maxs)
    return pos.x >= mins.x and pos.x <= maxs.x
        and pos.y >= mins.y and pos.y <= maxs.y
        and pos.z >= mins.z and pos.z <= maxs.z
end

local function IsManagedSourceMap(map)
    return isstring(map) and MANAGED_SOURCE_MAPS[CanonicalMapName(map)] == true
end

local function GetExpectedTownTargetCanonical(sourceCanonical)
    local expected = TOWN_ALLOWED_ROUTE[sourceCanonical]
    if sourceCanonical ~= "d1_town_02" then
        return expected
    end

    -- On the return pass (town_03 -> town_02), route town_02 to town_02a.
    local raw = file.Exists(DATA_FILE, "DATA") and file.Read(DATA_FILE, "DATA") or ""
    local parsed = (raw ~= "") and util.JSONToTable(raw) or nil
    if not istable(parsed) then
        return expected
    end

    local fromCanonical = CanonicalMapName(parsed.canonicalSourceMap or parsed.sourceMap)
    local toCanonical = CanonicalMapName(parsed.canonicalTargetMap or parsed.targetMap)
    if fromCanonical == "d1_town_03" and (toCanonical == "" or toCanonical == "d1_town_02") then
        return "d1_town_02a"
    end

    return expected
end

local function IsManagedTransition(sourceMap, targetMap)
    local sourceCanonical = CanonicalMapName(sourceMap)
    local targetCanonical = CanonicalMapName(targetMap)
    if sourceCanonical == "" or targetCanonical == "" then return false end
    return GetExpectedTownTargetCanonical(sourceCanonical) == targetCanonical
end

local function IsTown02aMap(mapName)
    local canonical = CanonicalMapName(mapName)
    if string.match(canonical, "_town_02a$") then
        return true
    end

    local raw = isstring(mapName) and string.lower(mapName) or ""
    return string.match(raw, "_town_02a_d$") ~= nil
end

local function IsTown02Map(mapName)
    return string.match(CanonicalMapName(mapName), "_town_02$") ~= nil
end

local function ResolveManagedTownTarget(sourceMap)
    local sourceCanonical = CanonicalMapName(sourceMap)
    local expectedCanonical = GetExpectedTownTargetCanonical(sourceCanonical)
    if not expectedCanonical or expectedCanonical == "" then return "" end
    if MapRoute.GetActualMap then
        return MapRoute.GetActualMap(expectedCanonical)
    end
    return expectedCanonical
end

local function IsCoopLikeMap()
    if not IsManagedSourceMap(game.GetMap()) then return false end

    if CurrentRound then
        local round = CurrentRound()
        if istable(round) and round.name == "coop" then return true end
    end

    return IsValid(ents.FindByClass("trigger_changelevel")[1])
end

local function ReadTransitionData()
    if not file.Exists(DATA_FILE, "DATA") then return {} end
    local raw = file.Read(DATA_FILE, "DATA")
    if not raw or raw == "" then return {} end
    local parsed = util.JSONToTable(raw)
    return istable(parsed) and parsed or {}
end

local function WriteTransitionData(tbl)
    file.Write(DATA_FILE, util.TableToJSON(tbl or {}, true) or "{}")
end

local function GetLandmark(ent)
    if not IsValid(ent) then return "" end
    local ok, kv = pcall(function() return ent:GetKeyValues() end)
    if ok and istable(kv) then
        local lm = kv["landmark"] or kv["LandmarkName"] or kv["landmarkname"]
        if isstring(lm) and lm ~= "" then return lm end
    end
    return ent.landmark or ent.LandmarkName or ent:GetInternalVariable("landmark") or ""
end

local function getspawnpos()
    local tbl = ents.FindByClass("info_player_start")
    for _, v in pairs(tbl) do
        if not v:HasSpawnFlags(1) then continue end
        return v:GetPos()
    end
    if #tbl > 0 then return tbl[1]:GetPos() end
    return Vector(0, 0, 0)
end

local function BuildTransitionLandmarkSet()
    local set = {}
    for _, tr in ipairs(ents.FindByClass("trigger_transition")) do
        if not IsValid(tr) then continue end
        local lm = GetLandmark(tr)
        if isstring(lm) and lm ~= "" then
            set[lm] = true
        end
    end
    return set
end

local function ResetTransitionState()
    transitionLocked = false
    triggersDisabledThisMap = false
    nextProxyRetryAt = 0
    crossedPlayers = {}
    gordonCrossed = false
    majorityTimerStarted = false
    pendingTargetMap = ""
    pendingLandmark = ""
    timer.Remove(majorityTimerName)
end

local function DisableNativeMapEnds()
    for _, existing in ipairs(ents.FindByClass("coop_mapend")) do
        if not IsValid(existing) then continue end
        if existing.SetNotSolid then existing:SetNotSolid(true) end
        if existing.SetSolid then existing:SetSolid(SOLID_NONE) end
        if existing.SetTrigger then existing:SetTrigger(false) end
        existing.StartTouch = function(self, toucher) end
        existing.Touch = function(self, toucher) end
    end
end

local function DisableNativeChangelevelTriggers()
    if triggersDisabledThisMap then return end
    triggersDisabledThisMap = true

    local sourceMap = game.GetMap()
    if not IsManagedSourceMap(sourceMap) then return end

    local sourceCanonical = CanonicalMapName(sourceMap)
    local alwaysDisabledMins = ALWAYS_DISABLED_TRIGGER_MINS[sourceCanonical] or {}
    local alwaysDisabledPoints = ALWAYS_DISABLED_TRIGGER_POINTS[sourceCanonical] or {}
    local disabledCount = 0

    for _, tr in ipairs(ents.FindByClass("trigger_changelevel")) do
        if not IsValid(tr) then continue end

        local trMins, trMaxs = tr:WorldSpaceAABB()

        local forceDisable = false
        for _, forcedMins in ipairs(alwaysDisabledMins) do
            if VecApproxEqual(trMins, forcedMins) then
                forceDisable = true
                break
            end
        end

        if not forceDisable then
            for _, forcedPoint in ipairs(alwaysDisabledPoints) do
                if PointInAABB(forcedPoint, trMins, trMaxs) then
                    forceDisable = true
                    break
                end
            end
        end

        if not forceDisable and not IsManagedTransition(sourceMap, tr.map) then
            -- On managed source maps we still disable all native triggers.
        end

        if tr.SetNotSolid then tr:SetNotSolid(true) end
        if tr.SetSolid then tr:SetSolid(SOLID_NONE) end
        if tr.SetTrigger then tr:SetTrigger(false) end
        tr.StartTouch = function(self, toucher) end
        tr.Touch = function(self, toucher) end
        disabledCount = disabledCount + 1
    end

    Dbg("Disabled native trigger_changelevel count=" .. tostring(disabledCount))
end

local function PickBestChangelevelTrigger()
    local sourceMap = game.GetMap()
    if not IsManagedSourceMap(sourceMap) then return nil end

    local sourceCanonical = CanonicalMapName(sourceMap)

    local pinnedPoint = PINNED_TRIGGER_POINTS[sourceCanonical]
    if pinnedPoint then
        local bestByPoint, bestByPointDist = nil, math.huge
        for _, ent in ipairs(ents.FindByClass("trigger_changelevel")) do
            if not IsValid(ent) then continue end
            if not IsManagedTransition(sourceMap, ent.map) then continue end

            local trMins, trMaxs = ent:WorldSpaceAABB()
            if not PointInAABB(pinnedPoint, trMins, trMaxs) then continue end

            local center = trMaxs - ((trMaxs - trMins) / 2)
            local dist = center:Distance(pinnedPoint)
            if dist < bestByPointDist then
                bestByPoint = ent
                bestByPointDist = dist
            end
        end
        if IsValid(bestByPoint) then
            Dbg("Selected pinned-point trigger ent=" .. tostring(bestByPoint:EntIndex()))
            return bestByPoint
        end
        Dbg("Pinned-point trigger not found for " .. tostring(sourceCanonical))
    end

    local pinnedMins = PINNED_TRIGGER_MINS[sourceCanonical]
    if pinnedMins then
        for _, ent in ipairs(ents.FindByClass("trigger_changelevel")) do
            if not IsValid(ent) then continue end
            if not IsManagedTransition(sourceMap, ent.map) then continue end
            local trMins, _ = ent:WorldSpaceAABB()
            if VecApproxEqual(trMins, pinnedMins) then
                Dbg("Selected pinned-mins trigger ent=" .. tostring(ent:EntIndex()))
                return ent
            end
        end
        Dbg("Pinned-mins trigger not found for " .. tostring(sourceCanonical) .. ", falling back to scored selection")
    end

    local playerPos = getspawnpos()
    local landmarkSet = BuildTransitionLandmarkSet()
    local best, bestScore = nil, -math.huge

    for _, ent in ipairs(ents.FindByClass("trigger_changelevel")) do
        if not IsValid(ent) then continue end
        if not IsManagedTransition(sourceMap, ent.map) then continue end

        local min, max = ent:WorldSpaceAABB()
        local pos = max - ((max - min) / 2)
        local score = pos:Distance(playerPos)

        local lm = GetLandmark(ent)
        if isstring(lm) and lm ~= "" then
            if landmarkSet[lm] then score = score + 1000000000 end
            local canonicalTarget = CanonicalMapName(ResolveManagedTownTarget(sourceMap))
            if string.find(lm, CanonicalMapName(sourceMap), 1, true) and string.find(lm, canonicalTarget, 1, true) then
                score = score + 2000000000
            end
        end

        if score > bestScore then
            best = ent
            bestScore = score
        end
    end

    return IsValid(best) and best or nil
end

local function GetSyntheticProxyBounds(sourceMap)
    local cfg = SYNTHETIC_PROXY_BOUNDS[CanonicalMapName(sourceMap)]
    if not istable(cfg) then return nil, nil end
    if not cfg.center or not cfg.halfExtents then return nil, nil end
    return cfg.center - cfg.halfExtents, cfg.center + cfg.halfExtents
end

local function RebuildTriggerProxies()
    triggerProxies = {}
    local map = game.GetMap()
    if not IsManagedSourceMap(map) then
        Dbg("Rebuild skipped: unmanaged map " .. tostring(map))
        return false
    end

    local targetMap = ResolveManagedTownTarget(map)
    if targetMap == "" then
        Dbg("Rebuild failed: empty managed target")
        return false
    end

    local tr = PickBestChangelevelTrigger()
    local mins, maxs = GetSyntheticProxyBounds(map)
    local landmark = ""

    if mins and maxs then
        if IsValid(tr) then
            landmark = GetLandmark(tr)
        end
        Dbg("Using synthetic proxy bounds for " .. tostring(CanonicalMapName(map)))
    elseif IsValid(tr) then
        local trMins, trMaxs = tr:WorldSpaceAABB()
        local pad = Vector(20, 20, 20)
        mins = trMins - pad
        maxs = trMaxs + pad
        landmark = GetLandmark(tr)
    else
        Dbg("Rebuild failed: no valid trigger selected and no synthetic bounds")
        return false
    end

    triggerProxies[1] = {
        ent = tr,
        target = targetMap,
        landmark = landmark,
        mins = mins,
        maxs = maxs,
    }

    Dbg("Proxy rebuilt: " .. tostring(map) .. " -> " .. tostring(targetMap)
        .. " mins=" .. tostring(triggerProxies[1].mins)
        .. " maxs=" .. tostring(triggerProxies[1].maxs))

    return true
end

local function EnsureLuaMapEndAndDisableNative(reason)
    if not IsCoopLikeMap() then return end

    local bestTarget = ResolveManagedTownTarget(game.GetMap())
    if bestTarget == "" then
        Dbg("Ensure failed: target empty")
        return
    end

    if not RebuildTriggerProxies() then
        Dbg("Ensure failed: proxy rebuild failed")
        return
    end

    DisableNativeMapEnds()
    DisableNativeChangelevelTriggers()

    Dbg("Ensure done reason=" .. tostring(reason or "n/a") .. " target=" .. tostring(bestTarget))
end

local function CountEligibleAndThrough()
    local total, through = 0, 0
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if ply:IsBot() then continue end
        total = total + 1
        if crossedPlayers[ply:SteamID64()] then through = through + 1 end
    end
    return total, through
end

local function IsInVehicleContext(ply)
    if not IsValid(ply) then return false end
    if ply:InVehicle() then return true end

    if ply.IsDrivingSimfphys and ply.GetSimfphys then
        local sim = ply:GetSimfphys()
        if IsValid(sim) then return true end
    end

    if ply.GlideGetVehicle then
        local glideVeh = ply:GlideGetVehicle()
        if IsValid(glideVeh) then return true end
    end

    return false
end

local function FinalizeTownTransition(targetMap, landmark)
    if transitionLocked then return end
    if not isstring(targetMap) or targetMap == "" then return end

    transitionLocked = true
    timer.Remove(majorityTimerName)
    majorityTimerStarted = false

    local sourceMap = game.GetMap()
    local shouldWriteReturn = IsTown02Map(targetMap)
    local shouldClearReturn = IsTown02aMap(targetMap)

    if shouldWriteReturn then
        local data = ReadTransitionData()
        data.mode = "global"
        data.sourceMap = sourceMap
        data.targetMap = targetMap
        data.canonicalSourceMap = CanonicalMapName(sourceMap)
        data.canonicalTargetMap = CanonicalMapName(targetMap)
        data.landmark = landmark or ""
        data.timestamp = os.time()
        WriteTransitionData(data)
        Dbg("Wrote return payload source=" .. tostring(sourceMap) .. " target=" .. tostring(targetMap) .. " canonicalTarget=" .. tostring(data.canonicalTargetMap))
    elseif shouldClearReturn then
        WriteTransitionData({})
        Dbg("Cleared return payload source=" .. tostring(sourceMap) .. " target=" .. tostring(targetMap))
        RunConsoleCommand("zc_town_clear_return_data", "1")
        Dbg("Triggered zc_town_clear_return_data for target=" .. tostring(targetMap))
    else
        Dbg("Return payload unchanged source=" .. tostring(sourceMap) .. " target=" .. tostring(targetMap))
    end

    timer.Simple(0.2, function()
        if not isstring(targetMap) or targetMap == "" then return end
        Dbg("RunConsoleCommand changelevel " .. tostring(targetMap))
        RunConsoleCommand("changelevel", targetMap)
    end)
end

hook.Add("InitPostEntity", "ZC_Changelevel2Safety_Init", function()
    ResetTransitionState()
    timer.Simple(0, function()
        EnsureLuaMapEndAndDisableNative("init")
    end)
end)

hook.Add("PostCleanupMap", "ZC_Changelevel2Safety_PostCleanup", function()
    ResetTransitionState()
    EnsureLuaMapEndAndDisableNative("postcleanup")
end)

hook.Add("Think", "ZC_Changelevel2Safety_ProxyTouch", function()
    ZC_Changelevel2Safety_NextProxyThink = ZC_Changelevel2Safety_NextProxyThink or 0
    local now = CurTime()
    if now < ZC_Changelevel2Safety_NextProxyThink then return end
    ZC_Changelevel2Safety_NextProxyThink = now + 0.05

    if transitionLocked then return end
    if not IsCoopLikeMap() then return end
    if not IsManagedSourceMap(game.GetMap()) then return end

    if #triggerProxies == 0 then
        if now >= nextProxyRetryAt then
            nextProxyRetryAt = now + 1
            EnsureLuaMapEndAndDisableNative("retry_no_proxy")
        end
        if debugEnabled and CurTime() >= nextNoProxyDebugAt then
            Dbg("No trigger proxy active on " .. tostring(game.GetMap()))
            nextNoProxyDebugAt = CurTime() + 3
        end
        return
    end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive() then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if IsInVehicleContext(ply) then continue end

        local pos = ply:GetPos()
        for _, proxy in ipairs(triggerProxies) do
            if debugEnabled then
                local center = proxy.mins + ((proxy.maxs - proxy.mins) / 2)
                local dist = pos:Distance(center)
                if dist <= 180 then
                    Dbg("Near proxy: " .. ply:Nick() .. " dist=" .. tostring(math.floor(dist)) .. " target=" .. tostring(proxy.target))
                end
            end

            if not PointInAABB(pos, proxy.mins, proxy.maxs) then continue end

            local sid64 = ply:SteamID64()
            if crossedPlayers[sid64] then continue end

            crossedPlayers[sid64] = true
            if ply.PlayerClassName == "Gordon" then
                gordonCrossed = true
            end

            if hg.CoopPersistence and hg.CoopPersistence.SavePlayerData then
                hg.CoopPersistence.SavePlayerData(ply)
            end
            ply:KillSilent()

            local total, through = CountEligibleAndThrough()
            Dbg("Proxy touch counted: " .. ply:Nick() .. " through=" .. tostring(through) .. "/" .. tostring(total))

            if gordonCrossed then
                Dbg("Gordon crossed; finalizing transition")
                FinalizeTownTransition(proxy.target, proxy.landmark)
                return
            end

            local majority = total > 0 and (through / total) > 0.5
            if majority then
                pendingTargetMap = proxy.target
                pendingLandmark = proxy.landmark
                if not majorityTimerStarted then
                    majorityTimerStarted = true
                    PrintMessage(HUD_PRINTTALK, string.format(
                        "[ZCity] %d/%d players at the exit. Map changes in 15 seconds.",
                        through,
                        total
                    ))
                    timer.Create(majorityTimerName, 15, 1, function()
                        FinalizeTownTransition(pendingTargetMap, pendingLandmark)
                    end)
                else
                    PrintMessage(HUD_PRINTTALK, string.format(
                        "[ZCity] %d/%d players at the exit.",
                        through,
                        total
                    ))
                end
            else
                ply:ChatPrint("[ZCity] Waiting for more players or Gordon to reach the exit.")
            end

            return
        end
    end
end)

concommand.Add("zc_town_debug", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local arg = tonumber(args[1] or "1") or 1
    debugEnabled = arg ~= 0
    print("[ZC TownDbg] debug " .. (debugEnabled and "ENABLED" or "DISABLED"))
end)

concommand.Add("zc_town_rebuild", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    ResetTransitionState()
    EnsureLuaMapEndAndDisableNative("manual_rebuild")
    print("[ZC TownDbg] rebuild invoked on " .. tostring(game.GetMap()))
end)
