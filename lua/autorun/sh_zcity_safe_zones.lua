if SERVER then
    AddCSLuaFile()
end

ZCitySafeZones = ZCitySafeZones or {}

local lib = ZCitySafeZones

lib.Net = lib.Net or {
    RequestState = "ZCitySafeZones_RequestState",
    SyncZones = "ZCitySafeZones_SyncZones",
    SyncEditor = "ZCitySafeZones_SyncEditor",
    Action = "ZCitySafeZones_Action",
}

lib.DataDir = "zcity"
lib.DataSubDir = "zcity/safe_zones"
lib.DefaultHeight = 160
lib.MinHeight = 32
lib.MaxHeight = 1024
lib.DefaultName = "Safe Zone"

local function roundCoord(value)
    return math.Round(tonumber(value) or 0, 3)
end

function lib.VectorToData(vec)
    if not isvector(vec) then
        return { x = 0, y = 0, z = 0 }
    end

    return {
        x = roundCoord(vec.x),
        y = roundCoord(vec.y),
        z = roundCoord(vec.z),
    }
end

function lib.DataToVector(data)
    if isvector(data) then return data end
    if not istable(data) then return Vector(0, 0, 0) end

    return Vector(
        tonumber(data.x) or tonumber(data[1]) or 0,
        tonumber(data.y) or tonumber(data[2]) or 0,
        tonumber(data.z) or tonumber(data[3]) or 0
    )
end

function lib.SanitizeName(name)
    local clean = string.Trim(tostring(name or ""))
    clean = string.gsub(clean, "[\r\n\t]+", " ")
    clean = string.gsub(clean, "%s%s+", " ")

    if clean == "" then
        clean = lib.DefaultName
    end

    return string.sub(clean, 1, 64)
end

function lib.GetSavePath()
    return string.format("%s/%s.json", lib.DataSubDir, string.lower(game.GetMap() or "unknown"))
end

function lib.GetZoneBounds(zone)
    local mins = lib.DataToVector(zone and zone.mins)
    local maxs = lib.DataToVector(zone and zone.maxs)

    return Vector(
        math.min(mins.x, maxs.x),
        math.min(mins.y, maxs.y),
        math.min(mins.z, maxs.z)
    ), Vector(
        math.max(mins.x, maxs.x),
        math.max(mins.y, maxs.y),
        math.max(mins.z, maxs.z)
    )
end

function lib.GetZoneCenter(zone)
    local mins, maxs = lib.GetZoneBounds(zone)
    return mins + (maxs - mins) * 0.5
end

function lib.GetZoneSize(zone)
    local mins, maxs = lib.GetZoneBounds(zone)
    return maxs - mins
end

function lib.PointInZone(pos, zone, padding)
    if not isvector(pos) or not istable(zone) then return false end

    local mins, maxs = lib.GetZoneBounds(zone)
    local inset = tonumber(padding) or 0

    return pos.x >= (mins.x - inset)
        and pos.y >= (mins.y - inset)
        and pos.z >= (mins.z - inset)
        and pos.x <= (maxs.x + inset)
        and pos.y <= (maxs.y + inset)
        and pos.z <= (maxs.z + inset)
end

function lib.NormalizeZone(zone)
    if not istable(zone) then return nil end

    local mins, maxs = lib.GetZoneBounds(zone)
    if math.abs(maxs.x - mins.x) < 1 then return nil end
    if math.abs(maxs.y - mins.y) < 1 then return nil end
    if math.abs(maxs.z - mins.z) < 1 then return nil end

    local clean = {
        id = tostring(zone.id or ""),
        name = lib.SanitizeName(zone.name),
        mins = lib.VectorToData(mins),
        maxs = lib.VectorToData(maxs),
    }

    if clean.id == "" then
        clean.id = string.format("zone_%d_%d", os.time(), math.random(1000, 9999))
    end

    return clean
end

function lib.MakeZoneFromCorners(name, cornerA, cornerB, height)
    local first = lib.DataToVector(cornerA)
    local second = lib.DataToVector(cornerB)
    local zoneHeight = math.Clamp(tonumber(height) or lib.DefaultHeight, lib.MinHeight, lib.MaxHeight)

    local mins = Vector(
        math.min(first.x, second.x),
        math.min(first.y, second.y),
        math.min(first.z, second.z)
    )
    local maxs = Vector(
        math.max(first.x, second.x),
        math.max(first.y, second.y),
        math.min(first.z, second.z) + zoneHeight
    )

    local zone = {
        id = string.format(
            "%s_%d_%d",
            string.lower(string.gsub(lib.SanitizeName(name), "[^%w]+", "_")),
            os.time(),
            math.random(1000, 9999)
        ),
        name = lib.SanitizeName(name),
        mins = lib.VectorToData(mins),
        maxs = lib.VectorToData(maxs),
    }

    return lib.NormalizeZone(zone)
end

function lib.FindZoneAtPos(pos, zones, padding)
    if not isvector(pos) then return nil end

    zones = zones or (SERVER and lib.ServerZones or lib.ClientZones) or {}
    for _, zone in ipairs(zones) do
        if lib.PointInZone(pos, zone, padding) then
            return zone
        end
    end

    return nil
end

if CLIENT then
    lib.ClientZones = lib.ClientZones or {}
    lib.ClientEditorState = lib.ClientEditorState or {
        selectedZoneID = "",
        hasStart = false,
        startCorner = nil,
    }

    function lib.GetZones()
        return lib.ClientZones or {}
    end

    function lib.GetEditorState()
        return lib.ClientEditorState or {}
    end

    function lib.GetSelectedZoneID()
        return tostring((lib.ClientEditorState and lib.ClientEditorState.selectedZoneID) or "")
    end

    function lib.GetSelectedZone()
        local selectedID = lib.GetSelectedZoneID()
        if selectedID == "" then return nil end

        for _, zone in ipairs(lib.GetZones()) do
            if zone.id == selectedID then
                return zone
            end
        end
    end

    net.Receive(lib.Net.SyncZones, function()
        local raw = net.ReadString() or "[]"
        local decoded = util.JSONToTable(raw) or {}
        local zones = {}

        for _, zone in ipairs(decoded) do
            local clean = lib.NormalizeZone(zone)
            if clean then
                zones[#zones + 1] = clean
            end
        end

        lib.ClientZones = zones
        hook.Run("ZCitySafeZones_ClientZonesUpdated", zones)
    end)

    net.Receive(lib.Net.SyncEditor, function()
        local hasStart = net.ReadBool()
        local state = {
            selectedZoneID = net.ReadString() or "",
            hasStart = hasStart,
            startCorner = hasStart and net.ReadVector() or nil,
        }

        lib.ClientEditorState = state
        hook.Run("ZCitySafeZones_ClientEditorUpdated", state)
    end)
end