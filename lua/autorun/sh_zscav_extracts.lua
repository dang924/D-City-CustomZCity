-- ZScav named extracts - shared library.
-- Persisted per-map list of named raid extracts. Each extract stores a
-- position, display name, and optional linked spawn-group ids.

if SERVER then
    AddCSLuaFile()
end

ZScavExtracts = ZScavExtracts or {}
local lib = ZScavExtracts

lib.DEFAULT_DURATION = math.Clamp(math.floor(tonumber(lib.DEFAULT_DURATION) or 8), 1, 255)

lib.Net = lib.Net or {
    Sync = "ZScavExtracts_Sync",
    Action = "ZScavExtracts_Action",
}

lib.DataDir = "zcity"
lib.DataSubDir = "zcity/zscav_extract_points"

lib.ACTION_UPSERT = 1
lib.ACTION_REMOVE = 2
lib.ACTION_CLEAR = 3

local function round(value)
    return math.Round(tonumber(value) or 0, 3)
end

local function normalizeDuration(value)
    return math.Clamp(math.floor(tonumber(value) or lib.DEFAULT_DURATION), 1, 255)
end

local function normalizeGroupRefs(refs)
    local normalized = {}
    local seen = {}

    if isstring(refs) then
        refs = { refs }
    end

    for _, ref in ipairs(istable(refs) and refs or {}) do
        ref = string.Trim(tostring(ref or ""))
        if ref ~= "" and not seen[ref] then
            seen[ref] = true
            normalized[#normalized + 1] = ref
        end
    end

    return normalized
end

function lib.NormalizeGroupRefs(refs)
    return normalizeGroupRefs(refs)
end

function lib.GetSavePath()
    return string.format("%s/%s.json", lib.DataSubDir, string.lower(game.GetMap() or "unknown"))
end

function lib.EncodeExtract(extract)
    if not (istable(extract) and isvector(extract.pos)) then return nil end

    return {
        x = round(extract.pos.x),
        y = round(extract.pos.y),
        z = round(extract.pos.z),
        yaw = round(extract.yaw),
        name = string.Trim(tostring(extract.name or "")),
        id = tostring(extract.id or ""),
        duration = normalizeDuration(extract.duration),
        groups = normalizeGroupRefs(extract.groups),
    }
end

function lib.DecodeExtract(raw)
    if not istable(raw) then return nil end

    return {
        pos = Vector(tonumber(raw.x) or 0, tonumber(raw.y) or 0, tonumber(raw.z) or 0),
        yaw = tonumber(raw.yaw) or 0,
        name = string.Trim(tostring(raw.name or "")),
        id = tostring(raw.id or ""),
        duration = normalizeDuration(raw.duration),
        groups = normalizeGroupRefs(raw.groups),
    }
end

function lib.NearestExtractIndex(pos, extracts, maxDistSq)
    if not (isvector(pos) and istable(extracts)) then return nil end

    local bestIndex
    local bestDist = tonumber(maxDistSq) or math.huge

    for index, extract in ipairs(extracts) do
        if isvector(extract.pos) then
            local dist = extract.pos:DistToSqr(pos)
            if dist < bestDist then
                bestDist = dist
                bestIndex = index
            end
        end
    end

    return bestIndex
end

if CLIENT then
    lib.ClientExtracts = lib.ClientExtracts or {}

    function lib.GetExtracts()
        return lib.ClientExtracts
    end

    net.Receive(lib.Net.Sync, function()
        local raw = net.ReadString() or "[]"
        local decoded = util.JSONToTable(raw) or {}
        local extracts = {}

        for _, entry in ipairs(decoded) do
            local extract = lib.DecodeExtract(entry)
            if extract then
                extracts[#extracts + 1] = extract
            end
        end

        lib.ClientExtracts = extracts
        hook.Run("ZScavExtracts_ClientUpdated", extracts)
    end)
end