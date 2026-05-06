-- ZScav Spawn Points - shared library.
-- Persisted per-map list of "spawn groups". Each group is a single click in
-- the editor and expands to N positions arranged in a circle around its
-- center. One pad-launch consumes one group, so an entire team spawns
-- together at slightly-separated points (no stacking, predictable layout).
--
-- Editable via the `zcity_zscav_spawnpoint` tool. Consumed by
-- ent_zscav_spawnpad to teleport players when a raid begins.

if SERVER then
    AddCSLuaFile()
end

ZScavSpawnPoints = ZScavSpawnPoints or {}
local lib = ZScavSpawnPoints

lib.Net = lib.Net or {
    Sync   = "ZScavSpawnPoints_Sync",   -- sv -> cl: full group list
    Action = "ZScavSpawnPoints_Action", -- cl -> sv: add/remove/clear/manage
}

lib.DataDir    = "zcity"
lib.DataSubDir = "zcity/zscav_spawn_points"

lib.ACTION_ADD    = 1
lib.ACTION_REMOVE = 2
lib.ACTION_CLEAR  = 3
lib.ACTION_RENAME = 4
lib.ACTION_REMOVE_ID = 5
lib.ACTION_TELEPORT = 6

-- Defaults for a new group. Tunable here for now; could be tool convars later.
lib.DEFAULT_GROUP_COUNT  = 5      -- points per group (max team size you support)
lib.DEFAULT_GROUP_RADIUS = 96     -- world units between center and each point

local function round(v) return math.Round(tonumber(v) or 0, 3) end
local function normalizeGroupID(value) return string.Trim(tostring(value or "")) end

function lib.NormalizeGroupName(value)
    return string.sub(string.Trim(tostring(value or "")), 1, 64)
end

function lib.GetGroupRef(index)
    index = math.max(math.floor(tonumber(index) or 0), 0)
    return index > 0 and ("G" .. tostring(index)) or "G?"
end

function lib.GetGroupDisplayName(group, index)
    local name = lib.NormalizeGroupName(istable(group) and group.name or "")
    if name ~= "" then
        return name
    end

    return lib.GetGroupRef(index)
end

function lib.GetGroupLabel(group, index)
    local ref = lib.GetGroupRef(index)
    local name = lib.NormalizeGroupName(istable(group) and group.name or "")
    if name == "" or string.lower(name) == string.lower(ref) then
        return ref
    end

    return string.format("%s - %s", ref, name)
end

function lib.GetSavePath()
    return string.format("%s/%s.json",
        lib.DataSubDir,
        string.lower(game.GetMap() or "unknown"))
end

-- Encode a group to JSON-friendly form.
function lib.EncodeGroup(g)
    if not istable(g) or not isvector(g.center) then return nil end
    return {
        x      = round(g.center.x),
        y      = round(g.center.y),
        z      = round(g.center.z),
        yaw    = round(tonumber(g.yaw) or 0),
        count  = math.Clamp(math.floor(tonumber(g.count) or lib.DEFAULT_GROUP_COUNT), 1, 16),
        radius = math.Clamp(round(tonumber(g.radius) or lib.DEFAULT_GROUP_RADIUS), 24, 1024),
        id     = normalizeGroupID(g.id),
        name   = lib.NormalizeGroupName(g.name),
    }
end

function lib.DecodeGroup(raw)
    if not istable(raw) then return nil end
    return {
        center = Vector(tonumber(raw.x) or 0, tonumber(raw.y) or 0, tonumber(raw.z) or 0),
        yaw    = tonumber(raw.yaw) or 0,
        count  = math.Clamp(math.floor(tonumber(raw.count) or lib.DEFAULT_GROUP_COUNT), 1, 16),
        radius = math.Clamp(tonumber(raw.radius) or lib.DEFAULT_GROUP_RADIUS, 24, 1024),
        id     = normalizeGroupID(raw.id),
        name   = lib.NormalizeGroupName(raw.name),
    }
end

-- Expand a group to its individual spawn positions. Each member gets their own
-- {pos, yaw}. The first position is at the group's facing direction; the rest
-- spread evenly around the circle, all facing outward (away from center).
function lib.ExpandGroup(group)
    if not istable(group) or not isvector(group.center) then return {} end
    local count = math.Clamp(math.floor(tonumber(group.count) or lib.DEFAULT_GROUP_COUNT), 1, 16)
    local radius = tonumber(group.radius) or lib.DEFAULT_GROUP_RADIUS
    local baseYaw = tonumber(group.yaw) or 0
    local out = {}
    for i = 0, count - 1 do
        local degOffset = (i / count) * 360
        local memberYaw = baseYaw + degOffset
        local rad = math.rad(memberYaw)
        out[#out + 1] = {
            pos = group.center + Vector(math.cos(rad) * radius, math.sin(rad) * radius, 0),
            yaw = memberYaw,  -- facing outward from group center
        }
    end
    return out
end

-- Distance helper for "find nearest group center".
function lib.NearestGroupIndex(pos, groups, maxDistSq)
    if not isvector(pos) or not istable(groups) then return nil end
    maxDistSq = maxDistSq or math.huge
    local best, bestDist = nil, maxDistSq
    for i, g in ipairs(groups) do
        if isvector(g.center) then
            local d = g.center:DistToSqr(pos)
            if d < bestDist then bestDist = d best = i end
        end
    end
    return best
end

if CLIENT then
    lib.ClientGroups = lib.ClientGroups or {}

    function lib.GetGroups() return lib.ClientGroups end

    net.Receive(lib.Net.Sync, function()
        local raw = net.ReadString() or "[]"
        local decoded = util.JSONToTable(raw) or {}
        local groups = {}
        for _, r in ipairs(decoded) do
            local g = lib.DecodeGroup(r)
            if g then groups[#groups + 1] = g end
        end
        lib.ClientGroups = groups
        hook.Run("ZScavSpawnPoints_ClientUpdated", groups)
    end)
end
