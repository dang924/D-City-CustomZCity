-- sv_coop_skip_spawn.lua
-- Handles alternate spawning for players returning from the skip (d2_town_02a)
-- Spawns skip returners at a different location than normal start

if CLIENT then return end

if not ZC_MapRoute then
    include("autorun/sh_zc_map_route.lua")
end

local MapRoute = ZC_MapRoute or {}

local function CanonicalMapName(name)
    if MapRoute.GetCanonicalMap then return MapRoute.GetCanonicalMap(name) end
    return isstring(name) and string.lower(name) or ""
end

local DATA_FILE = "zcity_skip_return.json"
local FALLBACK_POS = Vector(0, 0, 0)
local CLEAR_CVAR_NAME = "zc_town_clear_return_data"
local RETURN_DEBUG_CVAR_NAME = "zc_town_return_debug"
local PORTAL_REFRESH_ENABLE_CVAR = "zc_town_portal_refresh"
local PORTAL_REFRESH_INTERVAL_CVAR = "zc_town_portal_refresh_interval"

-- Hardcoded ground-node spawn positions for maps that have no info_player_start
-- near the return landmark. Only used when returning TO that map.
local RETURN_SPAWN_OVERRIDE = {
    d1_town_02 = Vector(-3873, -252, -3319), -- ground node near return landmark
}

-- In-memory cache of the active transition. Populated at InitPostEntity from the
-- file (which survives changelevel). Used for all spawn logic from then on so that
-- PostCleanupMap wiping the file doesn't break spawning mid-round-cycle.
local activeTransition = nil
local namedEntityPosCache = nil

-- Players who have already been repositioned this map load.
-- Cleared on InitPostEntity so each map load only repositions once per player.
local repositionedPlayers = {}

local returnDebug = ConVarExists(RETURN_DEBUG_CVAR_NAME)
    and GetConVar(RETURN_DEBUG_CVAR_NAME)
    or CreateConVar(RETURN_DEBUG_CVAR_NAME, "0", FCVAR_ARCHIVE, "Enable return payload debug prints for town_02 reposition flow.", 0, 1)

local function ReturnDbg(msg)
    if not returnDebug or not returnDebug:GetBool() then return end
    print("[ZC ReturnDbg] " .. tostring(msg))
end

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

local function IsTown02Map(mapName)
    return string.match(CanonicalMapName(mapName), "_town_02$") ~= nil
end

local function ActiveTransitionMatchesCurrentMap()
    if not activeTransition then return false end

    local currentMap = game.GetMap()
    local currentCanonical = CanonicalMapName(currentMap)

    return activeTransition.targetMap == currentMap
        or activeTransition.canonicalTargetMap == currentCanonical
end

local function IsReturnPayload(data)
    if not istable(data) then return false end
    if data.mode == "global" then return true end
    return istable(data.players) and next(data.players) ~= nil
end

local function SeedActiveTargetToCurrentMap()
    if not activeTransition then return end
    local currentMap = game.GetMap()
    activeTransition.targetMap = currentMap
    activeTransition.canonicalTargetMap = CanonicalMapName(currentMap)
end

-- Keep transition payload durable for the entire return phase on town_02.
-- It must only be cleared by the real progression transition (02 -> 02a).
local function PersistActiveTransition()
    if not IsTown02Map(game.GetMap()) then return end
    if not activeTransition then return end

    if not ActiveTransitionMatchesCurrentMap() then
        SeedActiveTargetToCurrentMap()
    end

    if not ActiveTransitionMatchesCurrentMap() then return end

    activeTransition.timestamp = os.time()
    WriteSkipData(activeTransition)
    ReturnDbg("rewrite payload map=" .. tostring(game.GetMap()) .. " mode=" .. tostring(activeTransition.mode) .. " source=" .. tostring(activeTransition.sourceMap) .. " target=" .. tostring(activeTransition.targetMap))
end

local function ClearReturnTransitionData()
    activeTransition = nil
    repositionedPlayers = {}
    WriteSkipData({})
    ReturnDbg("clear payload via cvar")
end

local function GetNamedEntityPos(name)
    if not isstring(name) or name == "" then return nil end
    if not istable(namedEntityPosCache) then
        namedEntityPosCache = {}
        for _, ent in ipairs(ents.GetAll()) do
            if not IsValid(ent) then continue end
            local entName = ent:GetName()
            if not isstring(entName) or entName == "" then continue end
            namedEntityPosCache[entName] = ent:GetPos()
        end
    end
    return namedEntityPosCache[name]
end

local function GetLandmarkPos(data)
    if not istable(data) then return nil end
    if isstring(data.landmark) and data.landmark ~= "" then
        local pos = GetNamedEntityPos(data.landmark)
        if pos then return pos end
    end

    -- Fallback: on HL2 maps, landmark often equals source map suffix.
    local sourceMap = data.canonicalSourceMap or CanonicalMapName(data.sourceMap)
    if isstring(sourceMap) and sourceMap ~= "" then
        local suffix = string.match(sourceMap, "[^_]+$")
        local prefix = string.match(sourceMap, "^(d%d)_")
        if suffix then
            if prefix then
                local guess = prefix .. "_town_" .. suffix
                local pos = GetNamedEntityPos(guess)
                if pos then return pos end
            end
            local guessD1 = "d1_town_" .. suffix
            local posD1 = GetNamedEntityPos(guessD1)
            if posD1 then return posD1 end
            local guessD2 = "d2_town_" .. suffix
            local posD2 = GetNamedEntityPos(guessD2)
            if posD2 then return posD2 end
        end
    end
    return nil
end

local function PickSpawnNearLandmark(landmarkPos)
    -- Check for a hardcoded ground-node override for this map first.
    local mapOverride = RETURN_SPAWN_OVERRIDE[CanonicalMapName(game.GetMap())]
    if mapOverride then
        return mapOverride
    end

    if landmarkPos then
        return landmarkPos + Vector(0, 0, 8)
    end

    local starts = ents.FindByClass("info_player_start")
    if #starts == 0 then return FALLBACK_POS end

    local bestNonMaster = nil
    for _, startEnt in ipairs(starts) do
        if not IsValid(startEnt) then continue end
        if startEnt:HasSpawnFlags(1) then continue end
        bestNonMaster = startEnt
        break
    end

    local picked = bestNonMaster or starts[1]
    return IsValid(picked) and picked:GetPos() or FALLBACK_POS
end

local portalRefreshEnable = ConVarExists(PORTAL_REFRESH_ENABLE_CVAR)
    and GetConVar(PORTAL_REFRESH_ENABLE_CVAR)
    or CreateConVar(PORTAL_REFRESH_ENABLE_CVAR, "1", FCVAR_ARCHIVE, "Enable periodic client portal refresh attempts.", 0, 1)

local portalRefreshInterval = ConVarExists(PORTAL_REFRESH_INTERVAL_CVAR)
    and GetConVar(PORTAL_REFRESH_INTERVAL_CVAR)
    or CreateConVar(PORTAL_REFRESH_INTERVAL_CVAR, "30", FCVAR_ARCHIVE, "Seconds between periodic portal refresh attempts.", 10, 300)

local function RequestClientPortalRefresh(ply)
    if not IsValid(ply) then return end

    -- Try r_updateareaportals only when available on the client.
    ply:SendLua([[
        local cmds = concommand.GetTable and concommand.GetTable() or {}

        if cmds["r_updateareaportals"] then
            RunConsoleCommand("r_updateareaportals", "1")
        end
    ]])
end

-- Use PlayerSpawn hook to override position for transition returners.
-- This fires after the gamemode sets the spawn position, so SetPos overrides it reliably.
hook.Add("PlayerSpawn", "ZC_TransitionReturnSpawn", function(ply)
    if not IsValid(ply) then return end
    local map = game.GetMap()
    local canonicalMap = CanonicalMapName(map)
    if not string.match(canonicalMap, "_town_0[23]$") then return end

    -- Use in-memory cache; file may have been wiped by PostCleanupMap already.
    local skipData = activeTransition or {}
    local steamid64 = ply:SteamID64()

    local targetMapMatches = skipData.targetMap == map or skipData.canonicalTargetMap == canonicalMap
    local isGlobalReturn = (skipData.mode == "global" and targetMapMatches)
    local isSkipReturn   = (istable(skipData.players) and skipData.players[steamid64] == true and targetMapMatches)

    if not isGlobalReturn and not isSkipReturn then return end

    -- Only reposition once per player per map load.
    if repositionedPlayers[steamid64] then return end
    repositionedPlayers[steamid64] = true

    local landmarkPos = GetLandmarkPos(skipData)
    local spawnPos = PickSpawnNearLandmark(landmarkPos)

    timer.Simple(0.15, function()
        if not IsValid(ply) then return end
        ply:SetPos(spawnPos)
        -- Force a client visibility refresh after delayed reposition.
        RequestClientPortalRefresh(ply)
        ReturnDbg("reposition " .. tostring(ply:Nick()) .. " to " .. tostring(spawnPos) .. " source=" .. tostring(skipData.sourceMap) .. " target=" .. tostring(skipData.targetMap))
    end)

    -- Intentionally do not clear skip payload per-player here.
    -- Data stays valid through round retries until town_02 actually exits to town_02a.
    PersistActiveTransition()
end)

-- Load transition data into memory when the map starts.
-- activeTransition is the sole source of truth for spawn logic.
-- ONLY cache if arriving at a NEEDS_RETURN_SPAWN map (_02 maps).
-- Clear stale data from the file if we're on any other map.
hook.Add("InitPostEntity", "ZC_SkipSpawn_InitCheck", function()
    namedEntityPosCache = nil

    local data = ReadSkipData()
    local map = game.GetMap()
    local canonicalMap = CanonicalMapName(map)
    local isReturnMap = IsTown02Map(canonicalMap)

    local targetMapMatches = data.targetMap == map or data.canonicalTargetMap == canonicalMap
    local hasReturnPayload = IsReturnPayload(data)

    ReturnDbg("init map=" .. tostring(map) .. " hasPayload=" .. tostring(hasReturnPayload) .. " mode=" .. tostring(data.mode) .. " source=" .. tostring(data.sourceMap) .. " target=" .. tostring(data.targetMap) .. " targetMatch=" .. tostring(targetMapMatches))

    if isReturnMap and hasReturnPayload and (targetMapMatches or not data.targetMap or data.targetMap == "") then
        activeTransition = data
        SeedActiveTargetToCurrentMap()
        repositionedPlayers = {}
        PersistActiveTransition()
        ReturnDbg("init activated return payload on " .. tostring(map))
    else
        activeTransition = nil
        repositionedPlayers = {}
        -- Clear stale file data so it doesn't linger into future map loads.
        if hasReturnPayload then
            WriteSkipData({})
            ReturnDbg("init cleared stale payload on " .. tostring(map))
        end
    end
end)

-- Rewrite file at every round start so data survives PostCleanupMap wipes during round cycling.
-- Also clear repositionedPlayers so players get repositioned fresh each round.
hook.Add("ZB_PreRoundStart", "ZC_SkipSpawn_RewriteOnRoundStart", function()
    if not activeTransition then return end
    if not ActiveTransitionMatchesCurrentMap() then
        activeTransition = nil
        return
    end
    repositionedPlayers = {}
    PersistActiveTransition()
    ReturnDbg("preround refresh on " .. tostring(game.GetMap()))
end)

-- PostCleanupMap can happen during round cycling; rewrite payload immediately
-- so return placement data survives until the real clear transition.
hook.Add("PostCleanupMap", "ZC_SkipSpawn_RewriteAfterCleanup", function()
    if not activeTransition then return end
    PersistActiveTransition()
    ReturnDbg("postcleanup refresh on " .. tostring(game.GetMap()))
end)

-- Safety net: if another init/cleanup path wipes the file while town_02 return
-- data is active, rewrite it back immediately.
timer.Create("ZC_SkipSpawn_ReturnWatchdog", 2, 0, function()
    if not IsTown02Map(game.GetMap()) then return end
    if not activeTransition then return end

    local data = ReadSkipData()
    if not IsReturnPayload(data) then
        ReturnDbg("watchdog detected missing payload; restoring")
        PersistActiveTransition()
    end
end)

timer.Create("ZC_TownPortalRefreshTick", 30, 0, function()
    if not portalRefreshEnable or not portalRefreshEnable:GetBool() then return end

    local interval = portalRefreshInterval and portalRefreshInterval:GetInt() or 30
    interval = math.max(10, interval)
    if timer.Exists("ZC_TownPortalRefreshTick") then
        timer.Adjust("ZC_TownPortalRefreshTick", interval, 0)
    end

    for _, ply in ipairs(player.GetHumans()) do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        RequestClientPortalRefresh(ply)
    end
end)

-- Explicit operator-controlled clear path.
local clearCvar = ConVarExists(CLEAR_CVAR_NAME)
    and GetConVar(CLEAR_CVAR_NAME)
    or CreateConVar(CLEAR_CVAR_NAME, "0", FCVAR_ARCHIVE, "Set to 1 to clear town return transition data immediately.", 0, 1)

cvars.AddChangeCallback(CLEAR_CVAR_NAME, function(_, _, newValue)
    if tonumber(newValue) ~= 1 then return end
    ClearReturnTransitionData()
    if clearCvar then
        RunConsoleCommand(CLEAR_CVAR_NAME, "0")
    end
end, "ZC_SkipSpawn_ClearReturnData")

concommand.Add("zc_town_return_dump", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local data = ReadSkipData()
    local map = game.GetMap()

    local function countPlayers(tbl)
        if not istable(tbl) then return 0 end
        local n = 0
        for _, v in pairs(tbl) do
            if v == true then n = n + 1 end
        end
        return n
    end

    print("[ZC ReturnDbg] dump map=" .. tostring(map)
        .. " file_mode=" .. tostring(data.mode)
        .. " file_source=" .. tostring(data.sourceMap)
        .. " file_target=" .. tostring(data.targetMap)
        .. " file_players=" .. tostring(countPlayers(data.players)))

    if activeTransition then
        print("[ZC ReturnDbg] dump active mode=" .. tostring(activeTransition.mode)
            .. " source=" .. tostring(activeTransition.sourceMap)
            .. " target=" .. tostring(activeTransition.targetMap)
            .. " players=" .. tostring(countPlayers(activeTransition.players))
            .. " targetMatch=" .. tostring(ActiveTransitionMatchesCurrentMap()))
    else
        print("[ZC ReturnDbg] dump active=nil")
    end
end)
