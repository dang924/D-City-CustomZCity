-- sv_coop_skip_exit.lua
-- Custom exit trigger for d2_town_02a that detects players touching the exit
-- and marks them as "skip returners" before calling changelevel to d2_town_02

if CLIENT then return end

if not ZC_MapRoute then
    include("autorun/sh_zc_map_route.lua")
end

local MapRoute = ZC_MapRoute or {}

local function CanonicalMapName(name)
    if MapRoute.GetCanonicalMap then return MapRoute.GetCanonicalMap(name) end
    return isstring(name) and string.lower(name) or ""
end

local function ResolveNextMapName(currentMap, fallbackTarget)
    if not MapRoute.ResolveNextMap then return "" end
    return MapRoute.ResolveNextMap(currentMap, fallbackTarget)
end

local function TargetMatchesExpected(currentMap, candidateTarget)
    if not MapRoute.TargetMatchesExpected then return false end
    return MapRoute.TargetMatchesExpected(currentMap, candidateTarget)
end

local function IsTownSkipReturnTarget(sourceMap, targetMap)
    local sourceCanonical = CanonicalMapName(sourceMap)
    local targetCanonical = CanonicalMapName(targetMap)
    if sourceCanonical == "" or targetCanonical == "" then return false end
    if not string.match(sourceCanonical, "_town_02a$") then return false end
    return string.match(targetCanonical, "_town_02$") ~= nil
end

local function ResolveTownSkipReturnTarget(sourceMap, fallbackTarget)
    local sourceCanonical = CanonicalMapName(sourceMap)
    if sourceCanonical == "" then return "" end
    local expectedCanonical = string.gsub(sourceCanonical, "a$", "")
    if MapRoute.GetActualMap then
        return MapRoute.GetActualMap(expectedCanonical)
    end
    return expectedCanonical
end

local DATA_FILE = "zcity_skip_return.json"

local function ReadSkipData()
    if not file.Exists(DATA_FILE, "DATA") then return {} end
    local raw = file.Read(DATA_FILE, "DATA")
    if not raw or raw == "" then return {} end
    local parsed = util.JSONToTable(raw)
    return istable(parsed) and parsed or {}
end

local function WriteSkipData(tbl)
    file.Write(DATA_FILE, util.TableToJSON(tbl or {}, true) or "{}")
end

local function PointInAABB(pos, mins, maxs)
    return pos.x >= mins.x and pos.x <= maxs.x
        and pos.y >= mins.y and pos.y <= maxs.y
        and pos.z >= mins.z and pos.z <= maxs.z
end

-- Create a custom exit trigger entity in d2_town_02a
local function SetupSkipExit()
    local map = game.GetMap()
    local canonicalMap = CanonicalMapName(map)
    if not string.match(canonicalMap, "_town_02a$") then return end
    
    -- Find the trigger_changelevel that points back to *_town_02.
    local triggers = ents.FindByClass("trigger_changelevel")
    local exitTrigger = nil
    local targetMap = ""
    for _, ent in ipairs(triggers) do
        if isstring(ent.map) and IsTownSkipReturnTarget(map, ent.map) then
            exitTrigger = ent
            targetMap = ResolveTownSkipReturnTarget(map, ent.map)
            break
        end
    end
    
    if not IsValid(exitTrigger) then
        return
    end
    
    -- Get the trigger's bounds; we will monitor this area ourselves.
    local min, max = exitTrigger:WorldSpaceAABB()
    local transitionLandmark = exitTrigger.landmark or exitTrigger.LandmarkName or exitTrigger:GetInternalVariable("landmark") or ""
    
    -- Disable the original trigger so it cannot call changelevel2.
    exitTrigger:SetSolid(SOLID_NONE)
    exitTrigger.StartTouch = function(self, toucher) end

    -- Track who has touched the exit and persist it for the next map.
    local touchedPlayers = {}

    local changing = false
    local nextTouchCheck = 0
    local TOUCH_CHECK_INTERVAL = 0.05
    hook.Add("Think", "ZC_SkipExitThink", function()
        local now = CurTime()
        if now < nextTouchCheck then return end
        nextTouchCheck = now + TOUCH_CHECK_INTERVAL

        if not string.match(CanonicalMapName(game.GetMap()), "_town_02a$") then return end
        if changing then return end

        local changedThisTick = false
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if not ply:Alive() then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end

            local sid64 = ply:SteamID64()
            if touchedPlayers[sid64] then continue end

            local pos = ply:GetPos()
            if not PointInAABB(pos, min, max) then continue end

            touchedPlayers[sid64] = true
            changedThisTick = true

            if hg.CoopPersistence and hg.CoopPersistence.SavePlayerData then
                hg.CoopPersistence.SavePlayerData(ply)
            end
            ply:KillSilent()
        end

        if not changedThisTick then return end

        local payload = ReadSkipData()
        payload.mode = "skip"
        payload.targetMap = (isstring(targetMap) and targetMap ~= "") and targetMap or ResolveTownSkipReturnTarget(game.GetMap(), exitTrigger.map)
        payload.sourceMap = game.GetMap()
        payload.canonicalSourceMap = CanonicalMapName(game.GetMap())
        payload.canonicalTargetMap = CanonicalMapName(payload.targetMap)
        payload.landmark = transitionLandmark
        payload.players = payload.players or {}
        for sid64, _ in pairs(touchedPlayers) do
            payload.players[sid64] = true
        end
        payload.timestamp = os.time()
        WriteSkipData(payload)

        if next(payload.players) and isstring(payload.targetMap) and payload.targetMap ~= "" then
            changing = true
            timer.Simple(0.5, function()
                if isstring(payload.targetMap) and payload.targetMap ~= "" then
                    RunConsoleCommand("changelevel", payload.targetMap)
                end
            end)
        end
    end)

end

-- Set up the exit trigger once the map loads
hook.Add("InitPostEntity", "ZC_SetupSkipExit", function()
    timer.Simple(0, function()
        SetupSkipExit()
        hook.Remove("InitPostEntity", "ZC_SetupSkipExit")
    end)
end)
