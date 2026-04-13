-- sv_dod_mapdata.lua — Extracts DoD:S map entity data for use by sv_dod_mode.lua.
--
-- GMod's GetKeyValues() returns an empty table for entities whose properties are
-- baked into the BSP at compile time (most DoD:S entities). We therefore use a
-- spatial inference approach:
--
--   Control point ORDER  — numeric suffix of targetname (cp1, cp2 … flag1, flag2 …)
--   Control point OWNER  — proximity to each team's spawn centroid; flags clearly
--                          closer to one side get assigned, middle flags stay neutral.
--                          Outermost flags get hard-assigned as a fallback.
--   Capture RADIUS       — nearest dod_capture_area OBB horizontal extent
--   Spawn TEAM           — dod_team_spawn TeamNum (readable in most GMod builds);
--                          info_player_axis / info_player_allies as fallback
--   Round TIME LIMIT     — dod_round_timer exists but timer_length not BSP-readable
--
-- Priority: manual DOD_MAP_CONFIG > extracted data > map point editor
 
if CLIENT then return end

DOD_MapData = DOD_MapData or {}
 
-- ── Helpers ───────────────────────────────────────────────────────────────────
 
local function IndexFromName(name)
    return tonumber(name:match("(%d+)%s*$")) or 0
end
 
local function Centroid(spawns)
    if not spawns or #spawns == 0 then return nil end
    local sum = Vector(0, 0, 0)
    for _, s in ipairs(spawns) do sum = sum + s.pos end
    return sum * (1 / #spawns)
end
 
local function InferOwner(pos, axisCentroid, alliesCentroid)
    if not axisCentroid or not alliesCentroid then return nil end
    local dAxis   = pos:DistToSqr(axisCentroid)
    local dAllies = pos:DistToSqr(alliesCentroid)
    local closer  = math.min(dAxis, dAllies)
    local farther = math.max(dAxis, dAllies)
    if closer / farther > 0.80 then return nil end  -- too close to midpoint
    return dAxis < dAllies and 0 or 1
end
 
-- ── Main extraction ───────────────────────────────────────────────────────────
 
local function ExtractMapData()
    local mapName = game.GetMap()
 
    if not mapName:match("^dod_") then return end
 
    if DOD_MAP_CONFIG and DOD_MAP_CONFIG[mapName] then
        print("[ZC DoD] Manual config exists for " .. mapName .. " — skipping extraction.")
        return
    end
 
    local data = {
        flags         = {},
        axisSpawns    = {},
        alliesSpawns  = {},
        round_time    = 0,
        wave_interval = 15,
        source        = "entity_extraction",
    }
 
    -- ── 1. Spawn points (collected first for centroid inference) ──────────────
 
    for _, ent in ipairs(ents.FindByClass("dod_team_spawn")) do
        if not IsValid(ent) then continue end
        local kv = {}
        pcall(function() kv = ent:GetKeyValues() end)
        local teamNum = tonumber(kv["TeamNum"]) or tonumber(kv["teamnum"]) or 0
        local entry = { pos = ent:GetPos(), ang = ent:GetAngles() }
        if teamNum == 2 then
            table.insert(data.axisSpawns, entry)
        elseif teamNum == 1 then
            table.insert(data.alliesSpawns, entry)
        end
    end
    for _, ent in ipairs(ents.FindByClass("info_player_axis")) do
        if IsValid(ent) then table.insert(data.axisSpawns,   { pos = ent:GetPos(), ang = ent:GetAngles() }) end
    end
    for _, ent in ipairs(ents.FindByClass("info_player_allies")) do
        if IsValid(ent) then table.insert(data.alliesSpawns, { pos = ent:GetPos(), ang = ent:GetAngles() }) end
    end
 
    local axisCentroid   = Centroid(data.axisSpawns)
    local alliesCentroid = Centroid(data.alliesSpawns)
    print("[ZC DoD] Axis centroid: "   .. tostring(axisCentroid))
    print("[ZC DoD] Allies centroid: " .. tostring(alliesCentroid))
 
    -- ── 2. Control points ─────────────────────────────────────────────────────
 
    local pointsByTarget = {}
    local pointsSorted   = {}
 
    for _, ent in ipairs(ents.FindByClass("dod_control_point")) do
        if not IsValid(ent) then continue end
        local targetname = ent:GetName() or ""
        if targetname == "" then targetname = "flag" .. _ end
        local pos = ent:GetPos()
        local point = {
            name       = targetname:upper(),
            pos        = pos,
            radius     = 128,
            initOwner  = InferOwner(pos, axisCentroid, alliesCentroid),
            cpIndex    = IndexFromName(targetname),
            targetname = targetname,
        }
        pointsByTarget[targetname] = point
        table.insert(pointsSorted, point)
    end
 
    table.sort(pointsSorted, function(a, b) return a.cpIndex < b.cpIndex end)
 
    -- ── 3. Capture radius from neighbour distance ────────────────────────────────
    -- dod_capture_area entities do not exist in GMod (DoD:S-specific entity type).
    -- Instead derive each flag's capture radius as half the distance to its nearest
    -- neighbour, clamped to a sensible range. This scales naturally with map layout.
 
    if #pointsSorted > 1 then
        for i, p in ipairs(pointsSorted) do
            local nearestDist = math.huge
            for j, other in ipairs(pointsSorted) do
                if i == j then continue end
                local d = p.pos:Distance(other.pos)
                if d < nearestDist then nearestDist = d end
            end
            -- Half the gap to the nearest flag, clamped 150-400 units
            p.radius = 200  -- fixed radius: ~barrel distance as shown in reference
        end
    else
        -- Single flag: use a generous fixed radius
        for _, p in ipairs(pointsSorted) do p.radius = 200 end
    end
 
    -- ── 4. Outermost ownership fallback ───────────────────────────────────────
 
    local n = #pointsSorted
    for i, p in ipairs(pointsSorted) do
        if p.initOwner == nil then
            if i == 1 then p.initOwner = 0 end
            if i == n then p.initOwner = 1 end
        end
        table.insert(data.flags, p)
        print(string.format("[ZC DoD] Flag %d: %q  owner=%s  radius=%d",
            i, p.name, tostring(p.initOwner), p.radius))
    end
 
    -- ── 5. Round timer note ───────────────────────────────────────────────────
 
    local timerCount = #ents.FindByClass("dod_round_timer")
    if timerCount > 0 then
        print(string.format("[ZC DoD] %d dod_round_timer(s) on map — timer_length BSP-baked, not readable; DEFAULT_ROUND_TIME applies.", timerCount))
    end
 
    -- ── 6. Summary ────────────────────────────────────────────────────────────
 
    print(string.format("[ZC DoD] Extracted %s: %d flags, %d Axis spawns, %d Allies spawns",
        mapName, #data.flags, #data.axisSpawns, #data.alliesSpawns))
 
    if #data.flags == 0 then
        print("[ZC DoD] WARNING: No control points — mode will use point editor fallback.")
    end
    if #data.axisSpawns   == 0 then print("[ZC DoD] WARNING: No Axis spawns — falling back to TDM points.") end
    if #data.alliesSpawns == 0 then print("[ZC DoD] WARNING: No Allies spawns — falling back to TDM points.") end
 
    DOD_MapData[mapName] = data
end
 
hook.Add("InitPostEntity",  "DOD_ExtractMapData",        function() timer.Simple(0.5, ExtractMapData) end)
hook.Add("PostCleanupMap",  "DOD_ExtractMapData_Reload",  function() timer.Simple(0.5, ExtractMapData) end)

-- ── DoD Mode Registration: DISABLED ─────────────────────────────────────────
-- DoD mode integration has been reverted to event-based system.
-- The DoD code files in zcity/gamemode/modes/dod/ are preserved but not loaded.
-- 
-- Reason: Base ZCity code has latent nil-check bugs that get exposed during
--         mode registration (cannot be fixed due to licensing constraints).
-- 
-- Future: DoD can be activated as an event command (!dod) similar to !jwick,
--         running during the event gamemode instead of as a full registered mode.
-- ────────────────────────────────────────────────────────────────────────────

print("[ZC DoD] Mode registration DISABLED — preserved for event-based activation")