
-- sv_coop_respawn.lua
-- Rebel wave respawning. Dead rebels are queued and spawned together after
-- RESPAWN_TIME seconds, teleporting directly to Gordon's position.
-- All other logic (Gordon tracking/exclusion, fallback assignment, spectator
-- handling, wave queueing) is unchanged from the original.

print("[ZC Coop] sv_coop_respawn loaded")

if not ZC_MapRoute then
    include("autorun/sh_zc_map_route.lua")
end
if not ZC_IsPatchRebelPlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

local MapRoute = ZC_MapRoute or {}

local TOWN_ALLOWED_ROUTE = {
    d1_town_02 = "d1_town_03",
    d1_town_03 = "d1_town_02",
    d2_town_02 = "d2_town_03",
    d2_town_03 = "d2_town_02",
}


local function CanonicalMapName(name)
    if not isstring(name) or name == "" then return "" end
    if MapRoute.GetCanonicalMap then return MapRoute.GetCanonicalMap(name) end
    return string.lower(name)
end

local function ShouldUseManagedGordonLoadoutLocal()
    local currentMap = CanonicalMapName(game.GetMap())
    if currentMap == "" then return true end
    if string.match(currentMap, "^d1_") then return false end
    if string.match(currentMap, "^d2_") then return false end
    return true
end

local function ResolveNextMapName(currentMap, fallbackTarget)
    local currentCanonical = CanonicalMapName(currentMap)
    local fallbackCanonical = CanonicalMapName(fallbackTarget)

    if currentCanonical == "d1_town_02" and (fallbackCanonical == "d1_town_03" or fallbackCanonical == "d1_town_02a") then
        if MapRoute.GetActualMap then
            return MapRoute.GetActualMap(fallbackCanonical)
        end
        return fallbackCanonical
    end

    -- Preserve explicit town reverse transitions handled by town safety script.
    if TOWN_ALLOWED_ROUTE[currentCanonical] == fallbackCanonical then
        if MapRoute.GetActualMap then
            return MapRoute.GetActualMap(fallbackCanonical)
        end
        return fallbackCanonical
    end

    if not MapRoute.ResolveNextMap then return "" end
    return MapRoute.ResolveNextMap(currentMap, fallbackTarget)
end

local START_SPAWN_DATA_FILE = "zcity_coop_start_spawns.json"
local startSpawnDataCache = nil

local function CopyVector(vec)
    if not vec then return nil end
    return Vector(vec.x or 0, vec.y or 0, vec.z or 0)
end

local function CopyAngle(ang)
    if not ang then return nil end
    return Angle(ang.p or 0, ang.y or 0, ang.r or 0)
end

local function SerializeVector(vec)
    if not vec then return nil end
    return { x = vec.x, y = vec.y, z = vec.z }
end

local function SerializeAngle(ang)
    if not ang then return nil end
    return { p = ang.p, y = ang.y, r = ang.r }
end

local function DeserializeVector(data)
    if not istable(data) then return nil end
    return Vector(tonumber(data.x) or 0, tonumber(data.y) or 0, tonumber(data.z) or 0)
end

local function DeserializeAngle(data)
    if not istable(data) then return nil end
    return Angle(tonumber(data.p) or 0, tonumber(data.y) or 0, tonumber(data.r) or 0)
end

local function GetStartSpawnMapKey(mapName)
    mapName = tostring(mapName or game.GetMap() or "")
    if mapName == "" then return "" end
    return string.lower(mapName)
end

local function ReadStartSpawnData()
    if not file.Exists(START_SPAWN_DATA_FILE, "DATA") then return {} end

    local raw = file.Read(START_SPAWN_DATA_FILE, "DATA")
    if not isstring(raw) or raw == "" then return {} end

    local parsed = util.JSONToTable(raw)
    return istable(parsed) and parsed or {}
end

local function GetStartSpawnData()
    if not istable(startSpawnDataCache) then
        startSpawnDataCache = ReadStartSpawnData()
    end

    return startSpawnDataCache
end

local function WriteStartSpawnData(tbl)
    startSpawnDataCache = istable(tbl) and tbl or {}
    file.Write(START_SPAWN_DATA_FILE, util.TableToJSON(startSpawnDataCache, true) or "{}")
end

local function GetSavedStartSpawn(mapName)
    local key = GetStartSpawnMapKey(mapName)
    if key == "" then return nil end

    local data = GetStartSpawnData()
    local entry = data[key]
    if not istable(entry) then
        local canonicalKey = CanonicalMapName(key)
        if canonicalKey ~= "" then
            entry = data[canonicalKey]
        end
    end
    if not istable(entry) then return nil end

    local pos = DeserializeVector(entry.pos)
    local ang = DeserializeAngle(entry.ang)
    if not pos then return nil end

    return pos, ang, entry
end
_G.ZC_GetSavedStartSpawn = GetSavedStartSpawn

local function SetSavedStartSpawn(mapName, pos, ang, author)
    local key = GetStartSpawnMapKey(mapName)
    if key == "" or not pos then return false end

    local data = GetStartSpawnData()
    data[key] = {
        pos = SerializeVector(pos),
        ang = SerializeAngle(ang),
        savedBy = tostring(author or "Console"),
        savedAt = os.time(),
        canonicalMap = CanonicalMapName(mapName),
    }

    WriteStartSpawnData(data)
    return true
end

local function ClearSavedStartSpawn(mapName)
    local key = GetStartSpawnMapKey(mapName)
    if key == "" then return false end

    local data = GetStartSpawnData()
    if data[key] == nil then return false end

    data[key] = nil
    WriteStartSpawnData(data)
    return true
end

local function GetMapPointPositions(pointName)
    local positions = {}
    if not zb or not zb.GetMapPoints then return positions end

    local points = zb.GetMapPoints(pointName) or {}
    for _, point in pairs(points) do
        if point and point.pos then
            positions[#positions + 1] = CopyVector(point.pos)
        end
    end

    return positions
end

local function GetAveragePosition(positions)
    if not istable(positions) or #positions == 0 then return nil end

    local total = Vector(0, 0, 0)
    for _, pos in ipairs(positions) do
        total:Add(pos)
    end

    return total / #positions
end

local function GetNearestDistanceScore(pos, positions)
    if not pos or not istable(positions) or #positions == 0 then return nil end

    local best = math.huge
    for _, refPos in ipairs(positions) do
        local dist = pos:DistToSqr(refPos)
        if dist < best then
            best = dist
        end
    end

    return best
end

local function GetPreferredInfoPlayerStartEntity()
    local starts = ents.FindByClass("info_player_start")
    if not starts or #starts == 0 then return nil end

    local masterCandidates = {}
    local nonMasterCandidates = {}
    local allCandidates = {}
    local candidatePositions = {}

    for _, ent in ipairs(starts) do
        if not IsValid(ent) then continue end
        allCandidates[#allCandidates + 1] = ent
        if ent:HasSpawnFlags(1) then
            masterCandidates[#masterCandidates + 1] = ent
        else
            nonMasterCandidates[#nonMasterCandidates + 1] = ent
        end
    end

    if #allCandidates == 0 then return nil end

    -- Prefer mapper-designated master start when present; this avoids sudden
    -- fallback picks to alternate starts on maps with multiple info_player_starts.
    local candidates = (#masterCandidates > 0) and masterCandidates or nonMasterCandidates
    if #candidates == 0 then
        candidates = allCandidates
    end

    for _, ent in ipairs(candidates) do
        candidatePositions[#candidatePositions + 1] = ent:GetPos()
    end

    local referencePoints = GetMapPointPositions("HMCD_TDM_CT")
    local centroid = GetAveragePosition(candidatePositions)

    table.sort(candidates, function(a, b)
        local function score(ent)
            local entPos = ent:GetPos()
            local value = 0

            local refScore = GetNearestDistanceScore(entPos, referencePoints)
            if refScore then
                value = value + refScore
            elseif centroid then
                value = value + entPos:DistToSqr(centroid)
            end

            return value
        end

        local sa, sb = score(a), score(b)
        if sa == sb then
            return a:EntIndex() < b:EntIndex()
        end
        return sa < sb
    end)

    return candidates[1]
end

local function FormatSpawnPoint(pos, ang)
    if not pos then return "<none>" end

    local yaw = ang and ang.y or 0
    return string.format("pos=(%.1f %.1f %.1f) ang=(0.0 %.1f 0.0)", pos.x, pos.y, pos.z, yaw)
end

local function ReplySpawnCommand(ply, msg)
    msg = tostring(msg or "")
    if IsValid(ply) then
        ply:ChatPrint(msg)
        ply:PrintMessage(HUD_PRINTCONSOLE, msg .. "\n")
        return
    end

    print(msg)
end

local function CanManageSpawnCommands(ply)
    if not IsValid(ply) then return true end
    return ply:IsAdmin()
end

-- Returns the position of the best info_player_start entity on the current map.
-- Skips master spawns (spawnflag 1) the same way sv_coop_skip_spawn does.
-- Used to guarantee Gordon and rebel fallback spawns land at the correct start.
local function GetInfoPlayerStartPos()
    local savedPos, savedAng = GetSavedStartSpawn(game.GetMap())
    if savedPos then
        return savedPos, savedAng, "saved override"
    end

    local ent = GetPreferredInfoPlayerStartEntity()
    if IsValid(ent) then
        return ent:GetPos(), ent:GetAngles(), "heuristic info_player_start", ent
    end

    return nil
end

local ApplyManagedSpawn

concommand.Add("zc_spawn_setstart", function(ply, _, args)
    if not CanManageSpawnCommands(ply) then
        ReplySpawnCommand(ply, "[ZC Spawn] Admin access required.")
        return
    end

    if not IsValid(ply) then
        ReplySpawnCommand(nil, "[ZC Spawn] zc_spawn_setstart must be run by an in-game admin.")
        return
    end

    local mapKey = game.GetMap()
    if args and args[1] and args[1] ~= "" then
        mapKey = mapKey .. "_" .. string.lower(args[1])
    end

    local eyeAng = ply:EyeAngles()
    local spawnAng = Angle(0, eyeAng.y, 0)
    if not SetSavedStartSpawn(mapKey, ply:GetPos(), spawnAng, ply:Nick()) then
        ReplySpawnCommand(ply, "[ZC Spawn] Failed to save start spawn override.")
        return
    end

    ReplySpawnCommand(ply, "[ZC Spawn] Saved start spawn for " .. mapKey .. ": " .. FormatSpawnPoint(ply:GetPos(), spawnAng))
end)

concommand.Add("zc_spawn_clearstart", function(ply, _, args)
    if not CanManageSpawnCommands(ply) then
        ReplySpawnCommand(ply, "[ZC Spawn] Admin access required.")
        return
    end

    local targetMap = GetStartSpawnMapKey(args and args[1] or game.GetMap())
    if targetMap == "" then
        ReplySpawnCommand(ply, "[ZC Spawn] No map name was provided.")
        return
    end

    if not ClearSavedStartSpawn(targetMap) then
        ReplySpawnCommand(ply, "[ZC Spawn] No saved start spawn override exists for " .. targetMap .. ".")
        return
    end

    ReplySpawnCommand(ply, "[ZC Spawn] Cleared saved start spawn override for " .. targetMap .. ".")
end)

concommand.Add("zc_spawn_printstart", function(ply, _, args)
    if not CanManageSpawnCommands(ply) then
        ReplySpawnCommand(ply, "[ZC Spawn] Admin access required.")
        return
    end

    local targetMap = GetStartSpawnMapKey(args and args[1] or game.GetMap())
    local savedPos, savedAng, savedEntry = GetSavedStartSpawn(targetMap)
    if savedPos then
        ReplySpawnCommand(ply, "[ZC Spawn] Saved override for " .. targetMap .. ": " .. FormatSpawnPoint(savedPos, savedAng) .. " by " .. tostring(savedEntry.savedBy or "unknown"))
    else
        ReplySpawnCommand(ply, "[ZC Spawn] No saved override for " .. targetMap .. ".")
    end

    if targetMap ~= GetStartSpawnMapKey(game.GetMap()) then return end

    local resolvedPos, resolvedAng, source = GetInfoPlayerStartPos()
    ReplySpawnCommand(ply, "[ZC Spawn] Active resolver on " .. targetMap .. ": " .. tostring(source or "none") .. " " .. FormatSpawnPoint(resolvedPos, resolvedAng))
end)

concommand.Add("zc_spawn_teststart", function(ply)
    if not CanManageSpawnCommands(ply) then
        ReplySpawnCommand(ply, "[ZC Spawn] Admin access required.")
        return
    end

    if not IsValid(ply) then
        ReplySpawnCommand(nil, "[ZC Spawn] zc_spawn_teststart must be run by an in-game admin.")
        return
    end

    local pos, ang, source = GetInfoPlayerStartPos()
    if not pos then
        ReplySpawnCommand(ply, "[ZC Spawn] No start spawn could be resolved on this map.")
        return
    end

    ApplyManagedSpawn(ply, pos, ang, 1.5)
    ReplySpawnCommand(ply, "[ZC Spawn] Teleported to " .. tostring(source or "resolved") .. ": " .. FormatSpawnPoint(pos, ang))
end)

-- Rebel fallback spawn pool:
-- 1) info_player_start (master preferred)
-- 2) PointEditor HMCD_TDM_CT (deterministic fallback)
-- Intentionally does NOT use generic HMCD_COOP_SPAWN / CurrentRound:GetPlySpawn,
-- so rebel respawns do not overlap combine flank pools.
local function GetRebelSpawnEntry()
    local startPos, startAng = GetInfoPlayerStartPos()
    if startPos then
        return { pos = startPos, ang = startAng }
    end

    local pts = {}
    if zb and zb.GetMapPoints then
        local ctPts = zb.GetMapPoints("HMCD_TDM_CT") or {}
        for _, v in pairs(ctPts) do
            if v and v.pos then
                pts[#pts + 1] = { pos = v.pos, ang = v.ang }
            end
        end
    end

    if #pts > 0 then
        table.sort(pts, function(a, b)
            if a.pos.x ~= b.pos.x then return a.pos.x < b.pos.x end
            if a.pos.y ~= b.pos.y then return a.pos.y < b.pos.y end
            return a.pos.z < b.pos.z
        end)
        return pts[1]
    end

    return nil
end

    _G.ZC_GetRebelSpawnEntry = GetRebelSpawnEntry

    local function GetStaggeredSpawnOffset(index, yaw)
        index = math.max(tonumber(index) or 0, 0)
        if index <= 0 then
            return Vector(0, 0, 0)
        end

        local ring = 1
        local ringStart = 1
        while index >= ringStart + (ring * 6) do
            ringStart = ringStart + (ring * 6)
            ring = ring + 1
        end

        local slotInRing = index - ringStart
        local slotCount = ring * 6
        local angleDeg = (slotInRing / slotCount) * 360 + (yaw or 0)
        local radius = 72 * ring
        local angleRad = math.rad(angleDeg)

        return Vector(math.cos(angleRad) * radius, math.sin(angleRad) * radius, 0)
    end

    local function GetStaggeredSpawnPos(anchorPos, anchorAng, index)
        if not anchorPos then return nil, anchorAng end

        local yaw = anchorAng and anchorAng.y or 0
        local offset = GetStaggeredSpawnOffset(index, yaw)
        return anchorPos + offset, anchorAng
    end

ApplyManagedSpawn = function(ply, pos, ang, duration)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not pos then return end

    duration = duration or 2
    ply.ZC_ManagedSpawnUntil = CurTime() + duration
    ply.ZC_ManagedSpawnPos = Vector(pos.x, pos.y, pos.z)
    ply.ZC_ManagedSpawnAng = ang and Angle(ang.p, ang.y, ang.r) or nil

    local function place()
        if not IsValid(ply) or not ply:Alive() then return end
        if (ply.ZC_ManagedSpawnUntil or 0) < CurTime() then return end

        -- If the player is already in a vehicle, do NOT teleport them: the homigrad
        -- Ragdoll_Create for EnterVehicleRag reads ply:GetPos() as the ragdoll origin.
        -- Corrupting that position (to the spawn point) builds the weld constraint with
        -- a massive offset and causes the vehicle to fling toward the spawn point.
        if ply:InVehicle() then
            ply.ZC_ManagedSpawnUntil = nil
            ply.ZC_ManagedSpawnPos   = nil
            ply.ZC_ManagedSpawnAng   = nil
            return
        end

        ply:SetPos(ply.ZC_ManagedSpawnPos)
        if ply.ZC_ManagedSpawnAng then
            ply:SetEyeAngles(ply.ZC_ManagedSpawnAng)
        end
        ply:SetLocalVelocity(Vector(0, 0, 0))
    end

    place()
    timer.Simple(0, place)
    timer.Simple(0.15, place)
    timer.Simple(0.6, place)
    timer.Simple(duration + 0.1, function()
        if not IsValid(ply) then return end
        if (ply.ZC_ManagedSpawnUntil or 0) > CurTime() then return end

        ply.ZC_ManagedSpawnUntil = nil
        ply.ZC_ManagedSpawnPos = nil
        ply.ZC_ManagedSpawnAng = nil
    end)
end

_G.ZC_ApplyManagedSpawn = ApplyManagedSpawn

local initialized = false
local function IsCoopRoundActiveSafe()
    if not CurrentRound then return false end
    local ok, round = pcall(CurrentRound)
    return ok and istable(round) and round.name == "coop"
end

local function Initialize()
    if initialized then return end
    initialized = true
    local clr_rebel     = Color(255, 155, 0)
    local clr_medic     = Color(190, 0, 0)
    local clr_grenadier = Color(190, 90, 0)

    -- ── Tunables ─────────────────────────────────────────────────────────────────

    local RESPAWN_TIME            = 25    -- wave countdown in seconds
    local GORDON_EXCLUSION_ROUNDS = 2     -- rounds before last-Gordon can be Gordon again

    -- ── Gordon helpers ────────────────────────────────────────────────────────────

    function GetGordon()
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            if not ply:Alive() then continue end
            if ply.PlayerClassName == "Gordon" then return ply end
        end
    end

    local function GetNativeGordonClassData()
        local useManaged = ShouldUseManagedGordonLoadoutLocal()
        if ZC_ShouldUseManagedGordonLoadout then
            useManaged = ZC_ShouldUseManagedGordonLoadout() == true
        end

        if useManaged then
            return nil
        end

        return { equipment = tostring(GetPlayerClass() or "rebel") }
    end

    local lastGordonSteamID   = nil
    local gordonExclusionRounds = 0

    -- Declare wave state BEFORE any closure so all hook callbacks in Initialize()
    -- capture the same upvalues.  Lua closures see locals from their declaration
    -- point; these MUST come before the first hook.Add that references them.
    local rebelWaveQueue  = {}
    local waveTimerActive = false
    local waveEndTime     = 0
    local CancelWave  -- forward-declared; assigned in Wave system section below
    local RetryDeadRebelWaveQueue

    local fallbackGordonPending = false

    local function SetFallbackGordonPending(active, reason)
        active = active == true
        if fallbackGordonPending == active then return end

        fallbackGordonPending = active
        print("[ZC Coop] Fallback Gordon " .. (active and "pending" or "resolved") ..
              (reason and (" (" .. tostring(reason) .. ")") or ""))
    end

    function ZC_IsFallbackGordonRunning()
        return fallbackGordonPending == true
    end

    hook.Add("PlayerDeath", "ZCity_CancelWaveOnGordonDeath", function(ply)
        if ply.PlayerClassName ~= "Gordon" then return end
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        if waveTimerActive and CancelWave then CancelWave("Gordon died — flank system taking over") end
    end)

    hook.Add("PlayerDeath", "ZCity_TrackLastGordon", function(ply)
        if ply.PlayerClassName ~= "Gordon" then return end
        if #player.GetHumans() <= 1 then return end
        lastGordonSteamID     = ply:SteamID64()
        gordonExclusionRounds = GORDON_EXCLUSION_ROUNDS
        print("[ZC Coop] Gordon died — " .. ply:Nick() ..
              " excluded for " .. GORDON_EXCLUSION_ROUNDS .. " rounds")
    end)

    hook.Add("PlayerDisconnected", "ZCity_TrackLastGordon", function(ply)
        if ply.PlayerClassName ~= "Gordon" then return end
        if #player.GetHumans() <= 1 then return end
        lastGordonSteamID     = ply:SteamID64()
        gordonExclusionRounds = GORDON_EXCLUSION_ROUNDS
        print("[ZC Coop] Gordon disconnected — " .. ply:Nick() ..
              " excluded for " .. GORDON_EXCLUSION_ROUNDS .. " rounds")
    end)

    hook.Add("ZB_StartRound", "ZCity_TrackLastGordon", function()
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        if not lastGordonSteamID then return end
        gordonExclusionRounds = gordonExclusionRounds - 1
        print("[ZC Coop] Gordon exclusion countdown: " .. gordonExclusionRounds .. " rounds remaining")
        if gordonExclusionRounds <= 0 then
            print("[ZC Coop] Gordon exclusion expired — " .. lastGordonSteamID .. " is eligible again")
            lastGordonSteamID   = nil
            gordonExclusionRounds = 0
        end
    end)

    hook.Add("ZB_EndRound", "ZCity_TrackLastGordon", function()
        if hg and hg.MapCompleted then
            lastGordonSteamID   = nil
            gordonExclusionRounds = 0
            print("[ZC Coop] Map completed — Gordon exclusion cleared")
        end
    end)

    local function IsExcludedFromGordon(ply)
        if not lastGordonSteamID then return false end
        if #player.GetHumans() <= 1 then return false end
        return ply:SteamID64() == lastGordonSteamID
    end

    local function CountAliveNonGordonPlayers(exclude)
        local total = 0
        for _, other in ipairs(player.GetAll()) do
            if other == exclude then continue end
            if other:Team() == TEAM_SPECTATOR then continue end
            if not other:Alive() then continue end
            if other.PlayerClassName == "Gordon" then continue end
            total = total + 1
        end
        return total
    end

    -- ── Fallback Gordon assignment ────────────────────────────────────────────────

    local function ClearStaleGordonPersistence()
        if not hg or not hg.CoopPersistence then return end

        local function clearTable(tbl, source)
            if not tbl then return end
            for steamid, data in pairs(tbl) do
                if data.PlayerClass == "Gordon" or data.Role == "Freeman" then
                    print("[ZC Coop] Clearing stale saved Gordon from " .. source .. " (steamid: " .. steamid .. ")")
                    tbl[steamid] = nil
                end
            end
        end

        clearTable(hg.CoopPersistence.LoadedData, "LoadedData")
        clearTable(hg.CoopPersistence.PendingSave, "PendingSave")
    end

    local function AssignFallbackGordon()
        if IsValid(GetGordon()) then
            SetFallbackGordonPending(false, "Gordon already alive")
            if RetryDeadRebelWaveQueue then
                timer.Simple(0, function()
                    if RetryDeadRebelWaveQueue then
                        RetryDeadRebelWaveQueue("Gordon already alive")
                    end
                end)
            end
            return
        end

        SetFallbackGordonPending(true, "assigning fallback")

        ClearStaleGordonPersistence()

        local candidates = {}
        local fallbackCandidates = {}
        local alivePlayers = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() ~= TEAM_SPECTATOR and ply:Alive() then
                alivePlayers = alivePlayers + 1
            end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if not ply:Alive() then continue end
            if ZC_IsPatchRebelPlayer(ply) then
                if IsExcludedFromGordon(ply) then
                    table.insert(fallbackCandidates, ply)
                else
                    table.insert(candidates, ply)
                end
            end
        end
        print("[ZC Coop] AssignFallbackGordon: alivePlayers=" .. alivePlayers ..
              " candidates=" .. #candidates ..
              " fallbackCandidates=" .. #fallbackCandidates)
        if #candidates == 0 and #fallbackCandidates == 0 then
            print("[ZC Coop] AssignFallbackGordon: no rebel-aligned candidates; checking unassigned alive players")
            for _, ply in ipairs(player.GetAll()) do
                if ply:Team() == TEAM_SPECTATOR then continue end
                if not ply:Alive() then continue end
                if not ply.PlayerClassName or ply.PlayerClassName == "" then
                    table.insert(candidates, ply)
                end
            end
            print("[ZC Coop] AssignFallbackGordon: unassigned candidates=" .. #candidates)
        end
        if #candidates == 0 then candidates = fallbackCandidates end
        if #candidates == 0 then
            print("[ZC Coop] Fallback Gordon: no eligible rebels found.")
            return
        end

        local pick = candidates[math.random(#candidates)]
        print("[ZC Coop] No Gordon found at round start — assigning " .. pick:Nick())

        pick.gottarespawn = true
        pick:Spawn()

        -- Place Gordon at info_player_start and keep that spawn sticky long enough
        -- to outlast base coop persistence's mid-round spawn override timer.
        local startPos, startAng = GetInfoPlayerStartPos()
        if startPos then
            ApplyManagedSpawn(pick, startPos, startAng, 2.5)
        end

        timer.Simple(0, function()
            if not IsValid(pick) then return end
            local inv = pick:GetNetVar("Inventory", {})
            inv["Weapons"] = inv["Weapons"] or {}
            inv["Weapons"]["hg_sling"]      = true
            inv["Weapons"]["hg_flashlight"] = true
            pick:SetNetVar("Inventory", inv)

            -- Gordon must never inherit Rebel subclass/class preferences.
            pick.ZCPreferredSubClass = nil
            pick.subClass = nil
            pick.ZC_PickedRebelClass = nil

            if ZC_ApplyCoopClassLoadout then
                ZC_ApplyCoopClassLoadout(pick, {
                    className = "Gordon",
                    playerEquipment = tostring(GetPlayerClass() or "rebel"),
                    queueManagedRetry = true,
                    retryDelay = 0.1,
                    maxAttempts = 12,
                })
            else
                pick:SetPlayerClass("Gordon", GetNativeGordonClassData())
                if ZC_ShouldUseManagedGordonLoadout and ZC_ShouldUseManagedGordonLoadout() == true and ZC_EnsureManagedGordonLoadout then
                    ZC_EnsureManagedGordonLoadout(pick, 0.1, 12)
                end
            end

            if pick.ZC_ManagedSpawnPos then
                ApplyManagedSpawn(pick, pick.ZC_ManagedSpawnPos, pick.ZC_ManagedSpawnAng, 2.5)
            end

            if ZC_RefreshWeaponInvLimits then
                ZC_RefreshWeaponInvLimits(pick)
            end

            SetFallbackGordonPending(false, "assigned " .. pick:Nick())
            if RetryDeadRebelWaveQueue then
                RetryDeadRebelWaveQueue("fallback Gordon assigned")
            end

            print("[ZC Coop] Assigned Gordon to " .. pick:Nick() .. " on " .. tostring(game.GetMap()))

            timer.Simple(0.1, function()
                if IsValid(pick) then
                    pick:ChatPrint("[ZCity] You have been assigned as Gordon Freeman.")
                end
            end)
        end)
    end

    hook.Add("ZB_StartRound", "ZCity_EnsureGordon", function()
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        SetFallbackGordonPending(true, "round start")
        timer.Simple(5, AssignFallbackGordon)
        timer.Simple(30, function()
            if not CurrentRound or CurrentRound().name ~= "coop" then return end
            if IsValid(GetGordon()) then
                SetFallbackGordonPending(false, "Gordon alive before 30s retry")
                if RetryDeadRebelWaveQueue then
                    RetryDeadRebelWaveQueue("Gordon alive before 30s retry")
                end
                return
            end
            print("[ZC Coop] No Gordon assigned after 30s — assigning fallback Gordon now.")
            AssignFallbackGordon()
        end)
    end)

    -- At the start of each coop round, force everyone to normal start spawn.
    -- This prevents random Gordon-relative offsets during round bootstrap.
    hook.Add("ZB_StartRound", "ZCity_ForceRoundStartSpawn", function()
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        -- Do not force players to the map start when they are returning from a
        -- Ravenholm detour; sv_coop_skip_spawn will reposition them instead.
        if _G.ZC_IsReturnSpawnActive and _G.ZC_IsReturnSpawnActive() then return end
        local startPos, startAng = GetInfoPlayerStartPos()
        if not startPos then return end

        local untilTime = CurTime() + 8
        local orderedPlayers = {}
        local gordon = GetGordon()

        if IsValid(gordon) and gordon:Alive() then
            orderedPlayers[#orderedPlayers + 1] = gordon
        end

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            ply.ZC_ForceStartSpawnUntil = untilTime
            if ply:Team() == TEAM_SPECTATOR then continue end
            if not ply:Alive() then continue end
            if ply ~= gordon then
                orderedPlayers[#orderedPlayers + 1] = ply
            end
        end

        local formationIndex = 0
        for _, ply in ipairs(orderedPlayers) do
            -- Do not apply spawn anchors to players already in vehicles: the deferred
            -- place() calls would corrupt ply:GetPos() during homigrad Ragdoll_Create
            -- and cause weld constraints to fling the vehicle to the spawn point.
            if ply:InVehicle() then continue end
            local spawnPos, spawnAng = GetStaggeredSpawnPos(startPos, startAng, formationIndex)
            ApplyManagedSpawn(ply, spawnPos, spawnAng, 2.5)
            formationIndex = formationIndex + 1
        end

        timer.Simple(8.1, function()
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and (ply.ZC_ForceStartSpawnUntil or 0) <= CurTime() then
                    ply.ZC_ForceStartSpawnUntil = nil
                end
            end
        end)
    end)

    hook.Add("ZB_PreRoundStart", "ZCity_ExcludeLastGordon", function()
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        if not lastGordonSteamID then return end

        local mode = CurrentRound()
        local origGiveDefault = mode.GiveDefaultEquipment

        mode.GiveDefaultEquipment = function(self, ply, ...)
            if ply:SteamID64() == lastGordonSteamID then
                local othersAvailable = false
                for _, p in ipairs(player.GetAll()) do
                    if p == ply then continue end
                    if p:Team() == TEAM_SPECTATOR then continue end
                    if not p:Alive() then continue end
                    if p:IsBot() then continue end
                    othersAvailable = true
                    break
                end
                if othersAvailable then
                    local args = {...}
                    args[2] = true
                    return origGiveDefault(self, ply, unpack(args))
                end
            end
            return origGiveDefault(self, ply, ...)
        end

        timer.Simple(0.5, function()
            if IsValid(mode) or type(mode) == "table" then
                mode.GiveDefaultEquipment = origGiveDefault
            end
        end)
    end)

    -- ── Spectator tracking ────────────────────────────────────────────────────────

    local spectatorsBefore = {}

    hook.Add("ZB_EndRound", "ZCity_MapCompletedChangelevel", function()
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        if not hg or not hg.MapCompleted then return end
        if not hg.NextMap or hg.NextMap == "" then return end
        local nextMap = ResolveNextMapName(game.GetMap(), hg.NextMap)
        if nextMap == "" then
            timer.Remove("ZC_MapCompleted_Changelevel")
            hg.MapCompleted = false
            hg.NextMap = ""
            return
        end
        hg.NextMap = nextMap
        print("[ZC Coop] Map completed — scheduling changelevel to " .. nextMap)
        timer.Create("ZC_MapCompleted_Changelevel", 5, 1, function()
            local safeNextMap = ResolveNextMapName(game.GetMap(), nextMap)
            if safeNextMap == "" then return end
            print("[ZC Coop] Changing level to " .. safeNextMap)
            RunConsoleCommand("changelevel", safeNextMap)
        end)
    end)

    hook.Add("ZB_PreRoundStart", "ZCity_ResetMapCompleted", function()
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        if hg and not hg.MapCompleted then
            timer.Remove("ZC_MapCompleted_Changelevel")
        end
        if hg then
            hg.MapCompleted = false
            hg.NextMap      = ""
        end
    end)

    hook.Add("ZB_PreRoundStart", "ZCity_TrackSpectators", function()
        spectatorsBefore = {}
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then
                spectatorsBefore[ply:SteamID64()] = true
                print("[ZC Coop] Tracking spectator: " .. ply:Nick())
            end
        end
    end)

    hook.Add("ZB_StartRound", "ZCity_RestoreSpectators", function()
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        timer.Simple(0.5, function()
            local gordonStripped = false
            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) then continue end
                if not spectatorsBefore[ply:SteamID64()] then continue end
                ply:SetTeam(TEAM_SPECTATOR)
                local cls = ply.PlayerClassName
                if cls and cls ~= "" then
                    if cls == "Gordon" then gordonStripped = true end
                    print("[ZC Coop] Restoring spectator " .. ply:Nick() .. " (had class: " .. cls .. ")")
                    ply:SetPlayerClass()
                end
                timer.Remove("ZC_RESPAWN_" .. ply:SteamID64())
                ply.ZCityRespawning = nil
                SendRespawnTimer(ply, -1)
                if ply:Alive() then ply:KillSilent() end
                ply:Spectate(OBS_MODE_ROAMING)
            end
            spectatorsBefore = {}
            if gordonStripped then timer.Simple(0.5, AssignFallbackGordon) end
        end)
    end)

    -- ── Network strings ───────────────────────────────────────────────────────────

    util.AddNetworkString("ZC_RespawnTimer")
    util.AddNetworkString("ZC_WaveSync")

    -- ── Wave system ───────────────────────────────────────────────────────────────
    -- NOTE: rebelWaveQueue, waveTimerActive, waveEndTime are declared earlier
    -- in Initialize() so closures above can reference them as proper upvalues.

    local function SendRespawnTimer(ply, timeRemaining)
        net.Start("ZC_RespawnTimer")
            net.WriteFloat(timeRemaining)
        net.Send(ply)
    end

    local function CancelCombineWave(reason) end  -- Combine handled by sv_coop_flank

    local function BroadcastWave(active, endTime)
        net.Start("ZC_WaveSync")
            net.WriteBool(active)
            net.WriteFloat(endTime or 0)
        net.Broadcast()
    end

    CancelWave = function(reason)
        print("[ZC Respawn] Wave cancelled: " .. tostring(reason))
        timer.Remove("ZC_REBEL_WAVE")
        for _, ply in ipairs(rebelWaveQueue) do
            if IsValid(ply) then
                if not ply:Alive() and ZC_IsPatchRebelPlayer(ply) then
                    ply.ZC_PendingWaveRetry = true
                end
                ply.ZCityRespawning = nil
                ply.ZC_InWaveQueue  = nil
                SendRespawnTimer(ply, -1)
            end
        end
        rebelWaveQueue  = {}
        waveTimerActive = false
        waveEndTime     = 0
        BroadcastWave(false, 0)
        CancelCombineWave(reason)
    end

    local function FullWaveReset(reason)
        SetFallbackGordonPending(false, reason)
        CancelWave(reason)
        local COMBINE_SUBCLASSES = { default=true, shotgunner=true, sniper=true, elite=true }
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            ply.ZCityRespawning = nil
            ply.ZC_InWaveQueue  = nil
            ply.ZC_PendingWaveRetry = nil
            ply.gottarespawn    = nil
            if COMBINE_SUBCLASSES[ply.subClass] then ply.subClass = nil end
        end
    end

    hook.Add("ZB_PreRoundStart", "ZCity_WaveReset", function() FullWaveReset("pre-round") end)
    hook.Add("ZB_EndRound",      "ZCity_WaveReset", function() FullWaveReset("end-round") end)
    hook.Add("PostCleanupMap",   "ZCity_WaveReset", function() FullWaveReset("map-cleanup") end)

    -- ── Spectator-join tracking ───────────────────────────────────────────────────

    local joiningSpectator = {}

    hook.Add("ZB_JoinSpectators", "ZCity_TrackJoiningSpectator", function(ply)
        joiningSpectator[ply:SteamID64()] = true
        timer.Simple(1, function() joiningSpectator[ply:SteamID64()] = nil end)
    end)

    local function StartRebelWaveTimer()
        if waveTimerActive then return end

        waveTimerActive = true
        waveEndTime     = CurTime() + RESPAWN_TIME
        BroadcastWave(true, waveEndTime)
        print("[ZC Respawn]   -> Rebel wave started (" .. RESPAWN_TIME .. "s)")

        timer.Create("ZC_REBEL_WAVE", RESPAWN_TIME, 1, function()
            local g = GetGordon()
            if not IsValid(g) or not g:Alive() then
                CancelWave("Gordon not alive at wave spawn")
                return
            end

            print("[ZC Respawn] Rebel wave firing — spawning " .. #rebelWaveQueue .. " player(s)")
            local baseFormationIndex = CountAliveNonGordonPlayers()
            local waveSpawnCount = 0
            for _, ply in ipairs(rebelWaveQueue) do
                if not IsValid(ply) then continue end
                if ply:Alive() then continue end
                waveSpawnCount = waveSpawnCount + 1
                ply.ZCityRespawning = nil
                ply.ZC_InWaveQueue  = nil
                ply.ZC_PendingWaveRetry = nil
                SendRespawnTimer(ply, -1)
                SpawnAsRebel(ply, g, baseFormationIndex + waveSpawnCount)
                print("[ZC Respawn]   -> Spawned: " .. ply:Nick())
            end

            rebelWaveQueue  = {}
            waveTimerActive = false
            waveEndTime     = 0
            BroadcastWave(false, 0)
        end)
    end

    local function QueueRebelForWave(victim, source)
        if not IsValid(victim) then return false, "invalid player" end
        if victim:Team() == TEAM_SPECTATOR then return false, "spectator team" end
        if joiningSpectator[victim:SteamID64()] then return false, "joining spectator" end
        if victim.PlayerClassName == "Gordon" then return false, "Gordon" end
        if not CurrentRound or CurrentRound().name ~= "coop" then return false, "not coop" end
        if zb and zb.ROUND_STATE ~= 1 then return false, "not mid-round" end
        if not ZC_RespawnsEnabled then return false, "respawns not enabled" end
        if victim:Alive() then return false, "alive" end
        if victim.ZC_InWaveQueue then return false, "already queued" end
        if not ZC_IsPatchRebelPlayer(victim) then return false, "non-rebel class" end

        local gordon = GetGordon()
        if not IsValid(gordon) or not gordon:Alive() then
            victim.ZC_PendingWaveRetry = true
            return false, "no alive Gordon"
        end

        victim.ZCityRespawning = true
        victim.ZC_PendingWaveRetry = nil
        victim.ZC_InWaveQueue = true
        table.insert(rebelWaveQueue, victim)
        print("[ZC Respawn]   -> Rebel queued for wave (" .. #rebelWaveQueue .. " in queue): " .. victim:Nick() ..
              (source and (" [" .. tostring(source) .. "]") or ""))

        SendRespawnTimer(victim, waveTimerActive and (waveEndTime - CurTime()) or RESPAWN_TIME)
        StartRebelWaveTimer()
        return true
    end

    RetryDeadRebelWaveQueue = function(source)
        if not CurrentRound or CurrentRound().name ~= "coop" then return 0 end
        if not ZC_RespawnsEnabled then return 0 end

        local gordon = GetGordon()
        if not IsValid(gordon) or not gordon:Alive() then return 0 end

        local queuedCount = 0
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if ply:Alive() then continue end
            if ply.ZC_InWaveQueue then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if not ZC_IsPatchRebelPlayer(ply) then continue end

            local queued = QueueRebelForWave(ply, source or "auto-retry")
            if queued then
                queuedCount = queuedCount + 1
            end
        end

        if queuedCount > 0 then
            print("[ZC Respawn] Auto-requeued " .. queuedCount .. " dead rebel(s) after " .. tostring(source or "auto-retry"))
        end

        return queuedCount
    end

    -- ── Class/subclass helpers ────────────────────────────────────────────────────

    function GetPlayerClass()
        if not CurrentRound then return "rebel" end

        local ok, roundData = pcall(CurrentRound)
        if not ok or not istable(roundData) then return "rebel" end

        local maps = roundData.Maps
        if not istable(maps) then return "rebel" end

        local mapName = game.GetMap()
        local canonicalMap = CanonicalMapName(mapName)

        local mapData = maps[mapName] or maps[canonicalMap]

        if not mapData and canonicalMap ~= "" then
            local familyPrefix = canonicalMap:match("^(d%d_)")
            if familyPrefix then
                mapData = maps[familyPrefix .. "*"]
            end
        end

        local equipment = string.lower(tostring((mapData and mapData.PlayerEqipment) or "rebel"))
        if equipment == "citizen" then return "citizen" end
        if equipment == "refugee" then return "refugee" end
        return "rebel"
    end

    hook.Add("EntityTakeDamage", "ZCity_SpawnInvincible", function(ent, dmgInfo)
        if not IsValid(ent) or not ent:IsPlayer() then return end
        if ent.ZC_SpawnInvincible then
            dmgInfo:SetDamage(0)
            return true
        end
    end)

    -- ZCity routes damage through HomigradDamage and the organism, bypassing
    -- EntityTakeDamage. Block it the same way sv_godmode.lua does.
    hook.Add("HomigradDamage", "ZCity_SpawnInvincible", function(ent, dmgInfo)
        if not IsValid(ent) or not ent:IsPlayer() then return end
        if ent.ZC_SpawnInvincible then
            dmgInfo:SetDamage(0)
            return true
        end
    end)

    -- Normalize the organism each tick while invincible so bleed/shock/pain
    -- from anything that slips through (gas, fire, environmental) can't accumulate.
    hook.Add("Org Think", "ZCity_SpawnInvincible", function(owner, org)
        if not IsValid(owner) or not owner:IsPlayer() then return end
        if not owner.ZC_SpawnInvincible then return end

        org.alive         = true
        org.otrub         = false
        org.needotrub     = false
        org.needfake      = false
        org.bleed         = 0
        org.internalBleed = 0
        org.pain          = 0
        org.painadd       = 0
        org.shock         = 0
        org.immobilization = 0
        org.blood         = math.max(org.blood, 4500)
        org.consciousness = 1

        if owner:Health() < 100 then owner:SetHealth(100) end
    end)

    -- homigrad-damage can queue ragdoll/amputation side effects before late
    -- damage hooks run. Wrap it so spawn-invincible players are short-circuited
    -- at the earliest damage entry point.
    local function IsSpawnInvincible(ent)
        return IsValid(ent) and ent:IsPlayer() and ent.ZC_SpawnInvincible
    end

    local function WrapSpawnInvincibleDamage()
        local dmgHooks = hook.GetTable()["EntityTakeDamage"]
        local origDmg = dmgHooks and dmgHooks["homigrad-damage"]
        if not origDmg then return false end

        hook.Remove("EntityTakeDamage", "homigrad-damage")
        hook.Add("EntityTakeDamage", "homigrad-damage", function(ent, dmgInfo)
            if IsSpawnInvincible(ent) then
                dmgInfo:SetDamage(0)
                return true
            end
            return origDmg(ent, dmgInfo)
        end)

        return true
    end

    local function TryWrapSpawnInvincibleDamage()
        if WrapSpawnInvincibleDamage() then
            hook.Remove("InitPostEntity", "ZCity_SpawnInvincible_WrapHooks")
            timer.Remove("ZCity_SpawnInvincible_WrapRetry")
            return true
        end
    end

    if not TryWrapSpawnInvincibleDamage() then
        hook.Add("InitPostEntity", "ZCity_SpawnInvincible_WrapHooks", TryWrapSpawnInvincibleDamage)
        timer.Create("ZCity_SpawnInvincible_WrapRetry", 1, 10, TryWrapSpawnInvincibleDamage)
    end

    -- Tracks subclass assignments that are pending (player spawning but not yet
    -- alive/counted by GetTeamComposition). Keyed by SteamID64, cleared on death
    -- or disconnect. This prevents wave-spawned players all seeing 0 medics.
    local pendingSubClass = {}

    hook.Add("PlayerDisconnected", "ZCity_PendingSubClassCleanup", function(ply)
        pendingSubClass[ply:SteamID64()] = nil
    end)
    hook.Add("DoPlayerDeath", "ZCity_PendingSubClassCleanup", function(ply)
        pendingSubClass[ply:SteamID64()] = nil
    end)

    local function GetTeamComposition()
        local total, medics, grenadiers = 0, 0, 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ply.PlayerClassName == "Gordon" then continue end
            -- Count alive players with assigned subclass
            if ply:Alive() then
                total = total + 1
                if ply.subClass == "medic"     then medics     = medics + 1 end
                if ply.subClass == "grenadier" then grenadiers = grenadiers + 1 end
            end
            -- Also count pending assignments for players spawning this wave
            local pending = pendingSubClass[ply:SteamID64()]
            if pending and not ply:Alive() then
                total = total + 1
                if pending == "medic"     then medics     = medics + 1 end
                if pending == "grenadier" then grenadiers = grenadiers + 1 end
            end
        end
        return total, medics, grenadiers
    end

    local function AssignSubClass(ply)
        local total, medics, grenadiers = GetTeamComposition()
        local playerCount   = total + 1
        local maxMedicsBase = math.Clamp(math.floor(playerCount / 4), 1, 8)
        local maxGrenBase = math.min(3, math.floor(playerCount / 6))
        local maxMedics = ZC_GetSubclassSlotMultiplier and math.Clamp(math.floor(maxMedicsBase * math.max(ZC_GetSubclassSlotMultiplier("rebel", "medic", 1), 0) + 0.5), 0, 16) or maxMedicsBase
        local maxGrenadiers = ZC_GetSubclassSlotMultiplier and math.Clamp(math.floor(maxGrenBase * math.max(ZC_GetSubclassSlotMultiplier("rebel", "grenadier", 1), 0) + 0.5), 0, 12) or maxGrenBase

        local preferred = ply.ZCPreferredSubClass
        if preferred and preferred ~= "default" then
            if preferred == "medic" and medics >= maxMedics then
                ply.subClass = nil
                pendingSubClass[ply:SteamID64()] = "default"
                return "default"
            end

            if preferred == "grenadier" and grenadiers >= maxGrenadiers then
                ply.subClass = nil
                pendingSubClass[ply:SteamID64()] = "default"
                return "default"
            end

            ply.subClass = preferred
            pendingSubClass[ply:SteamID64()] = preferred
            return preferred
        end

        -- No explicit preference: assign randomly while respecting capped subclasses.
        local candidates = {"default", "default", "sniper"}

        if medics < maxMedics then
            candidates[#candidates + 1] = "medic"
        end

        if grenadiers < maxGrenadiers then
            candidates[#candidates + 1] = "grenadier"
        end

        local chosen = candidates[math.random(#candidates)] or "default"

        if chosen == "default" then
            ply.subClass = nil
            pendingSubClass[ply:SteamID64()] = "default"
            return "default"
        end

        ply.subClass = chosen
        pendingSubClass[ply:SteamID64()] = chosen
        return chosen
    end

    -- ── SpawnAsRebel ─────────────────────────────────────────────────────────────
    -- Spawns the player and teleports them to Gordon's position with a small
    -- random offset. Falls back to ZCity's GetPlySpawn if Gordon is invalid.

    function SpawnAsRebel(ply, gordon, formationIndex)
        -- Capture Gordon's position BEFORE Spawn() so it is available immediately.
        local gordonPos = IsValid(gordon) and gordon:GetPos() or nil
        local gordonAng = IsValid(gordon) and gordon:GetAngles() or nil
        local rebelSpawnEntry = (not gordonPos) and GetRebelSpawnEntry() or nil
        formationIndex = math.max(tonumber(formationIndex) or (CountAliveNonGordonPlayers(ply) + 1), 0)
        
        -- If gottarespawn is true, it means this is a respawn (not initial spawn).
        -- Clear any picked class to assign map-determined class again. Otherwise keep picked class.
        local isRespawn = ply.gottarespawn ~= nil and ply.gottarespawn ~= false
        if isRespawn then
            ply.ZC_PickedRebelClass = nil
        end
        
        -- Determine base class from map config via GetPlayerClass().
        -- Players can override with !rebelclass rebel or !rebelclass refugee (stored in ZC_PickedRebelClass).
        local mapClass = tostring(GetPlayerClass() or "rebel")
        local preSpawnClass = ply.ZC_PickedRebelClass or (((mapClass == "refugee") or (mapClass == "citizen")) and "Refugee" or "Rebel")
        
        print("[ZC DEBUG] SpawnAsRebel start: " .. ply:Nick() .. " assigned class='" .. tostring(preSpawnClass) .. "' (respawn=" .. tostring(isRespawn) .. ", mapClass=" .. tostring(mapClass) .. ")")

        ply.gottarespawn = true
        ply:Spawn()
        print("[ZC DEBUG]   -> after Spawn(), class=" .. tostring(ply.PlayerClassName or "") .. "")

        local managedSpawnPos = nil
        local managedSpawnAng = nil

        -- Apply position synchronously right after Spawn() so the engine does not
        -- send the spectator eye position to the client as the spawn origin.
        if (ply.ZC_ForceStartSpawnUntil or 0) > CurTime() then
            local startPos, startAng = GetInfoPlayerStartPos()
            if startPos then
                managedSpawnPos, managedSpawnAng = GetStaggeredSpawnPos(startPos, startAng, formationIndex)
                ApplyManagedSpawn(ply, managedSpawnPos, managedSpawnAng, 2.5)
            end
        elseif gordonPos then
            managedSpawnPos, managedSpawnAng = GetStaggeredSpawnPos(gordonPos, gordonAng, formationIndex)
            ApplyManagedSpawn(ply, managedSpawnPos, managedSpawnAng, 1.5)
        elseif rebelSpawnEntry and rebelSpawnEntry.pos then
            managedSpawnPos, managedSpawnAng = GetStaggeredSpawnPos(rebelSpawnEntry.pos, rebelSpawnEntry.ang, formationIndex)
            ApplyManagedSpawn(ply, managedSpawnPos, managedSpawnAng, 1.5)
        end

        timer.Simple(0, function()
            if not IsValid(ply) then return end

            ply:SetSuppressPickupNotices(true)
            ply.noSound = true

            local inv = ply:GetNetVar("Inventory", {})
            inv["Weapons"] = inv["Weapons"] or {}
            inv["Weapons"]["hg_sling"]      = true
            inv["Weapons"]["hg_flashlight"] = true
            ply:SetNetVar("Inventory", inv)

            local classToSet = preSpawnClass
            if classToSet == "" or classToSet == "Default" then
                classToSet = math.random() < 0.5 and "Rebel" or "Refugee"
            end

            local subClass = AssignSubClass(ply)
            ply.subClass = (subClass == "default") and nil or subClass

            print("[ZC DEBUG]   timer.Simple(0): Setting class to '" .. classToSet .. "' subClass='" .. tostring(subClass) .. "'")
            if ZC_ApplyCoopClassLoadout then
                ZC_ApplyCoopClassLoadout(ply, {
                    className = classToSet,
                    subClass = (subClass == "default") and nil or subClass,
                    skipNativeEquipment = mapClass == "citizen" and classToSet == "Refugee",
                })
            else
                -- Set subClass BEFORE SetPlayerClass so ZCity's CLASS.On() reads it
                -- and GiveEquipment runs the correct subclass loadout natively.
                -- Never use bNoEquipment here in the fallback path.
                ply:SetPlayerClass(classToSet)
            end
            local currentClassName = tostring(ply.PlayerClassName or "")
            print("[ZC DEBUG]   -> after SetPlayerClass, class='" .. currentClassName .. "'")

            if managedSpawnPos then
                ApplyManagedSpawn(ply, managedSpawnPos, managedSpawnAng, 1.5)
            end

            -- CLASS.On() clears self.subClass after reading it; restore for downstream hooks
            ply.subClass = (subClass == "default") and nil or subClass

            if ZC_RefreshCoopClassAppearance then
                ZC_RefreshCoopClassAppearance(ply, currentClassName, subClass)
                currentClassName = tostring(ply.PlayerClassName or currentClassName or "")
            end

            if ZC_RefreshWeaponInvLimits then
                ZC_RefreshWeaponInvLimits(ply)
            end

            local isRefugeeClass = currentClassName == "Refugee" or currentClassName == "Citizen"

            if subClass == "medic" then
                zb.GiveRole(ply, "Medic", clr_medic)
            elseif subClass == "grenadier" then
                zb.GiveRole(ply, "Grenadier", clr_grenadier)
            elseif isRefugeeClass then
                zb.GiveRole(ply, "Refugee", clr_rebel)
            else
                zb.GiveRole(ply, "Rebel", clr_rebel)
            end

            ply:Give("weapon_hands_sh")
            ply:SelectWeapon("weapon_hands_sh")

            local baseClass = isRefugeeClass and "Refugee" or "Rebel"
            print("[ZC DEBUG] SpawnAsRebel final: " .. ply:Nick() .. " subClass=" .. subClass .. ", class=" .. currentClassName .. ", baseClass=" .. baseClass)

            -- Position was already applied synchronously right after Spawn().
            -- Re-apply here only as a fallback if Gordon was invalid at spawn time.
            if not managedSpawnPos then
                local spawnEntry = GetRebelSpawnEntry()
                if spawnEntry and spawnEntry.pos then
                    managedSpawnPos, managedSpawnAng = GetStaggeredSpawnPos(spawnEntry.pos, spawnEntry.ang, formationIndex)
                    ApplyManagedSpawn(ply, managedSpawnPos, managedSpawnAng, 1.5)
                end
            end

            timer.Simple(0.1, function()
                if IsValid(ply) then
                    ply.noSound = false
                    ply:SetSuppressPickupNotices(false)
                end
            end)

            -- 5-second spawn invincibility: blocks EntityTakeDamage, HomigradDamage,
            -- and normalizes the organism each tick so nothing slips through.
            ply.ZC_SpawnInvincible = true
            -- Clear pending tracking now that player is alive with subClass set
            pendingSubClass[ply:SteamID64()] = nil
            timer.Simple(5, function()
                if IsValid(ply) then ply.ZC_SpawnInvincible = nil end
            end)
        end)
    end

    -- ── Initial spawn (mid-round joiners) ────────────────────────────────────────

    hook.Add("PlayerInitialSpawn", "ZCity_CoopInitialSpawn", function(ply)
        timer.Simple(2, function()
            if not IsValid(ply) then return end
            if not IsCoopRoundActiveSafe() then return end
            if ply:Team() == TEAM_SPECTATOR then return end
            if ply:Alive() then return end
            if not ZC_RespawnsEnabled then return end
            if ply.PlayerClassName and ply.PlayerClassName ~= "" then return end

            -- Mid-round joiners (including bots): spawn via SpawnAsRebel regardless
            -- of ROUND_STATE so they receive a proper playerclass and equipment.
            local gordon = GetGordon()
            print("[ZC DEBUG] PlayerInitialSpawn: " .. ply:Nick() .. " class=" .. tostring(ply.PlayerClassName or "<empty>"))
            print("[ZC DEBUG]   -> triggering SpawnAsRebel (" .. (IsValid(gordon) and "near Gordon" or "default position") .. ")")
            SpawnAsRebel(ply, gordon)
        end)
    end)

    -- ── Death / wave queue ────────────────────────────────────────────────────────

    hook.Add("PlayerDeath", "ZCity_CoopRespawn", function(victim)
        if not IsCoopRoundActiveSafe() then return end

        print("[ZC Respawn] PlayerDeath: " .. victim:Nick() ..
            " | Team="            .. tostring(victim:Team()) ..
            " | TEAM_SPECTATOR="  .. tostring(TEAM_SPECTATOR) ..
            " | viewmode="        .. tostring(victim.viewmode) ..
            " | PlayerClassName=" .. tostring(victim.PlayerClassName) ..
            " | RespawnsEnabled=" .. tostring(ZC_RespawnsEnabled) ..
            " | Round="           .. tostring(CurrentRound and (function() local ok,r=pcall(CurrentRound); return ok and r and r.name or "nil" end)()))

        if victim:Team() == TEAM_SPECTATOR then
            print("[ZC Respawn]   -> SKIP: spectator team")
            return
        end
        if joiningSpectator[victim:SteamID64()] then
            print("[ZC Respawn]   -> SKIP: joining spectator")
            return
        end
        if victim.PlayerClassName == "Gordon" then return end

        if zb and zb.ROUND_STATE ~= 1 then
            print("[ZC Respawn]   -> SKIP: not mid-round (ROUND_STATE=" .. tostring(zb and zb.ROUND_STATE) .. ")")
            return
        end

        victim.ZCityRespawning = true

        if not ZC_RespawnsEnabled then
            print("[ZC Respawn]   -> SKIP: respawns not enabled")
            return
        end

        if victim.ZC_InWaveQueue then
            print("[ZC Respawn]   -> already in wave queue: " .. victim:Nick())
            return
        end

        if not ZC_IsPatchRebelPlayer(victim) then
            print("[ZC Respawn]   -> SKIP: non-rebel class not handled by rebel respawns")
            return
        end

        local queued, reason = QueueRebelForWave(victim, "death")
        if not queued then
            if reason == "no alive Gordon" then
                print("[ZC Respawn]   -> DEFER: no alive Gordon; will retry when queue re-opens")
            else
                print("[ZC Respawn]   -> SKIP: " .. tostring(reason))
            end
        end
    end)

    -- ── PlayerSpawn cleanup ───────────────────────────────────────────────────────

    local function ShouldSkipCoopRespawnSpawnHandling(ply)
        return (tonumber(ply.ZC_CoopRespawnSkipSpawnUntil) or 0) > CurTime()
    end

    hook.Add("Fake Up", "ZCity_CoopRespawn_MarkUnragdoll", function(ply)
        if not IsValid(ply) then return end
        if not IsCoopRoundActiveSafe() then return end
        ply.ZC_CoopRespawnSkipSpawnUntil = CurTime() + 1
    end)

    hook.Add("PlayerSpawn", "ZCity_CoopRespawn_ReopenQueue", function(ply)
        if not IsCoopRoundActiveSafe() then return end
        if not IsValid(ply) then return end
        if ply:Team() == TEAM_SPECTATOR then return end
        if ShouldSkipCoopRespawnSpawnHandling(ply) then return end

        timer.Simple(0.1, function()
            if not IsCoopRoundActiveSafe() then return end
            if not IsValid(ply) then return end
            if ply:Team() == TEAM_SPECTATOR then return end
            if ShouldSkipCoopRespawnSpawnHandling(ply) then return end
            if not ply:Alive() then return end
            if ply.PlayerClassName ~= "Gordon" then return end

            SetFallbackGordonPending(false, "Gordon spawned")
            if RetryDeadRebelWaveQueue then
                RetryDeadRebelWaveQueue("Gordon spawned")
            end
        end)
    end)

    hook.Add("PlayerSpawn", "ZCity_CoopRespawn_Cleanup", function(ply)
        local timerName = "ZC_RESPAWN_" .. ply:SteamID64()
        local coopActive = IsCoopRoundActiveSafe()

        if not coopActive and not timer.Exists(timerName) and not ply.ZCityRespawning and not ply.ZC_PendingWaveRetry then
            return
        end

        if ply:Team() == TEAM_SPECTATOR then
            if timer.Exists(timerName) then
                timer.Remove(timerName)
                ply.ZCityRespawning = nil
                ply.ZC_PendingWaveRetry = nil
                SendRespawnTimer(ply, -1)
            end
            return
        end

        if ShouldSkipCoopRespawnSpawnHandling(ply) then
            print("[ZC Respawn] PlayerSpawn cleanup SKIPPED for " .. ply:Nick() .. " (FakeUp/unragdoll)")
            return
        end

        if not ply:Alive() and not ply.gottarespawn then
            print("[ZC Respawn] PlayerSpawn cleanup SKIPPED for " .. ply:Nick() .. " (dead, not gottarespawn)")
            return
        end

        print("[ZC Respawn] PlayerSpawn cleanup CLEARING for " .. ply:Nick() ..
            " | Alive="           .. tostring(ply:Alive()) ..
            " | gottarespawn="    .. tostring(ply.gottarespawn) ..
            " | ZCityRespawning=" .. tostring(ply.ZCityRespawning))

        if timer.Exists(timerName) then timer.Remove(timerName) end
        ply.ZCityRespawning = nil
        ply.ZC_PendingWaveRetry = nil
        SendRespawnTimer(ply, -1)
    end)

end

local function GetCurrentRoundSafe()
    if not CurrentRound then return nil end

    local ok, round = pcall(CurrentRound)
    if not ok or not istable(round) then return nil end

    return round
end

hook.Add("InitPostEntity", "ZC_CoopInit_svcooprespawn", function()
    local round = GetCurrentRoundSafe()
    print("[ZC Coop] sv_coop_respawn InitPostEntity fired; CurrentRound=" .. tostring(round and round.name))
    Initialize()
end)
hook.Add("Think", "ZC_CoopInit_svcooprespawn_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svcooprespawn_Late")
        return
    end
    local round = GetCurrentRoundSafe()
    print("[ZC Coop] sv_coop_respawn Think check; CurrentRound=" .. tostring(round and round.name))
    Initialize()
end)
hook.Add("ZB_PreRoundStart", "ZC_CoopInit_svcooprespawn_ForceInit", function()
    if initialized then return end
    print("[ZC Coop] ZB_PreRoundStart fired before sv_coop_respawn initialized; forcing Initialize()")
    Initialize()
end)
hook.Add("ZB_StartRound", "ZC_CoopInit_svcooprespawn_ForceInitStart", function()
    if initialized then return end
    print("[ZC Coop] ZB_StartRound fired before sv_coop_respawn initialized; forcing Initialize()")
    Initialize()
end)
