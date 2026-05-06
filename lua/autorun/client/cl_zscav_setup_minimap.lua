if SERVER then return end

local enabledCvar = CreateClientConVar("zscav_setup_minimap", "0", true, false,
    "Admin-only schematic minimap for ZScav spawn/extract setup.")

local POINT_SYNC_INTERVAL = 8
local SAFE_SPAWN_SOURCE_ORDER = {
    "ZSCAV_SAFESPAWN",
    "SAFE_SPAWN",
    "Spawnpoint",
}

local COLORS = {
    panel = Color(18, 24, 31, 228),
    panelBorder = Color(104, 126, 147, 180),
    mapFill = Color(9, 14, 20, 230),
    mapBorder = Color(89, 110, 130, 220),
    grid = Color(70, 92, 112, 42),
    text = Color(232, 238, 244),
    textMuted = Color(164, 178, 192),
    safeSpawn = Color(108, 218, 199),
    spawnGroup = Color(119, 184, 255),
    spawnGroupMember = Color(78, 149, 228),
    rawExtract = Color(255, 166, 77),
    namedExtract = Color(255, 214, 102),
    player = Color(255, 255, 255),
}

local nextPointSyncAt = 0

local function isLocalAdmin()
    local ply = LocalPlayer()
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function notify(text, color)
    chat.AddText(color or COLORS.textMuted, "[ZScav] ", color_white, tostring(text or ""))
end

local function hudScale(value)
    local scale = math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.85, 1.25)
    return math.max(10, math.floor(value * scale + 0.5))
end

local function rebuildFonts()
    surface.CreateFont("ZScavSetupMinimapTitle", {
        font = "Roboto",
        size = hudScale(23),
        weight = 900,
    })

    surface.CreateFont("ZScavSetupMinimapBody", {
        font = "Roboto",
        size = hudScale(15),
        weight = 500,
    })

    surface.CreateFont("ZScavSetupMinimapSmall", {
        font = "Roboto",
        size = hudScale(13),
        weight = 500,
    })

    surface.CreateFont("ZScavSetupMinimapTiny", {
        font = "Roboto",
        size = hudScale(11),
        weight = 500,
    })
end

rebuildFonts()

hook.Add("OnScreenSizeChanged", "ZScavSetupMinimap_Fonts", rebuildFonts)

local function requestPointSync(force)
    if not isLocalAdmin() then return end
    if not (zb and isfunction(zb.GetAllPoints)) then return end

    local now = CurTime()
    if not force and now < nextPointSyncAt then return end

    nextPointSyncAt = now + POINT_SYNC_INTERVAL
    zb.GetAllPoints()
end

local function setMinimapEnabled(enabled, silent)
    if not isLocalAdmin() then return end

    enabled = tobool(enabled)
    RunConsoleCommand("zscav_setup_minimap", enabled and "1" or "0")

    if enabled then
        requestPointSync(true)
    end

    if not silent then
        notify(enabled and "Setup minimap enabled." or "Setup minimap disabled.",
            enabled and COLORS.spawnGroup or COLORS.textMuted)
    end
end

concommand.Add("zscav_setup_minimap_toggle", function()
    if not isLocalAdmin() then return end
    setMinimapEnabled(not enabledCvar:GetBool())
end)

concommand.Add("zscav_setup_minimap_refresh", function()
    if not isLocalAdmin() then return end
    requestPointSync(true)
    notify("Setup minimap refreshed.", COLORS.namedExtract)
end)

cvars.AddChangeCallback("zscav_setup_minimap", function(_name, _oldValue, newValue)
    if tobool(newValue) then
        requestPointSync(true)
    end
end, "ZScavSetupMinimap_Toggle")

hook.Add("InitPostEntity", "ZScavSetupMinimap_RequestInitialPoints", function()
    timer.Simple(1, function()
        if enabledCvar:GetBool() then
            requestPointSync(true)
        end
    end)
end)

hook.Add("Think", "ZScavSetupMinimap_PointSync", function()
    if not enabledCvar:GetBool() then return end
    requestPointSync(false)
end)

local function trimLabel(text)
    return string.Trim(tostring(text or ""))
end

local function abbreviateLabel(text, limit)
    text = trimLabel(text)
    limit = math.max(math.floor(tonumber(limit) or 0), 1)
    if utf8 and utf8.len and utf8.len(text) and utf8.len(text) > limit then
        return string.sub(text, 1, math.max(limit - 1, 1)) .. "~"
    end

    if #text > limit then
        return string.sub(text, 1, math.max(limit - 1, 1)) .. "~"
    end

    return text
end

local function getPointGroup(groupName)
    if not (zb and istable(zb.ClPoints)) then return {} end
    local points = zb.ClPoints[groupName]
    return istable(points) and points or {}
end

local function getSafeSpawnPoints()
    for _, groupName in ipairs(SAFE_SPAWN_SOURCE_ORDER) do
        local points = getPointGroup(groupName)
        if #points > 0 then
            return points, groupName
        end
    end

    return {}, SAFE_SPAWN_SOURCE_ORDER[#SAFE_SPAWN_SOURCE_ORDER]
end

local function resolvePointPos(point)
    if isvector(point) then return point end
    if istable(point) and isvector(point.pos) then return point.pos end
    return nil
end

local function makeBounds()
    return {
        any = false,
        minX = math.huge,
        maxX = -math.huge,
        minY = math.huge,
        maxY = -math.huge,
    }
end

local function extendBounds(bounds, pos)
    if not (istable(bounds) and isvector(pos)) then return end

    bounds.any = true
    bounds.minX = math.min(bounds.minX, pos.x)
    bounds.maxX = math.max(bounds.maxX, pos.x)
    bounds.minY = math.min(bounds.minY, pos.y)
    bounds.maxY = math.max(bounds.maxY, pos.y)
end

local function normalizeBounds(bounds)
    if not (istable(bounds) and bounds.any) then
        return {
            minX = -1024,
            maxX = 1024,
            minY = -1024,
            maxY = 1024,
            span = 2048,
        }
    end

    local spanX = math.max(bounds.maxX - bounds.minX, 512)
    local spanY = math.max(bounds.maxY - bounds.minY, 512)
    local span = math.max(spanX, spanY) + 512
    local centerX = (bounds.minX + bounds.maxX) * 0.5
    local centerY = (bounds.minY + bounds.maxY) * 0.5
    local half = span * 0.5

    return {
        minX = centerX - half,
        maxX = centerX + half,
        minY = centerY - half,
        maxY = centerY + half,
        span = span,
    }
end

local function worldToMap(pos, mapX, mapY, mapW, mapH, bounds, clampToEdge)
    local fracX = (pos.x - bounds.minX) / math.max(bounds.maxX - bounds.minX, 1)
    local fracY = (pos.y - bounds.minY) / math.max(bounds.maxY - bounds.minY, 1)
    local outside = fracX < 0 or fracX > 1 or fracY < 0 or fracY > 1

    if clampToEdge then
        fracX = math.Clamp(fracX, 0, 1)
        fracY = math.Clamp(fracY, 0, 1)
    end

    return mapX + fracX * mapW, mapY + (1 - fracY) * mapH, outside
end

local function addMarker(markers, bounds, marker)
    if not (istable(marker) and isvector(marker.pos)) then return end

    markers[#markers + 1] = marker
    if marker.includeInBounds ~= false then
        extendBounds(bounds, marker.pos)
    end
end

local function collectSetupData()
    local markers = {}
    local bounds = makeBounds()
    local summary = {
        safeCount = 0,
        groupCenters = 0,
        groupSlots = 0,
        rawExtracts = 0,
        namedExtracts = 0,
        safeSource = "",
    }

    local safePoints, safeSource = getSafeSpawnPoints()
    summary.safeSource = safeSource or ""
    local drawSafeLabels = #safePoints <= 14
    for index, point in ipairs(safePoints) do
        addMarker(markers, bounds, {
            kind = "safe_spawn",
            pos = resolvePointPos(point),
            label = drawSafeLabels and ("S" .. tostring(index)) or nil,
            color = COLORS.safeSpawn,
            size = 6,
        })
        summary.safeCount = summary.safeCount + 1
    end

    local groups = ZScavSpawnPoints and ZScavSpawnPoints.GetGroups and (ZScavSpawnPoints.GetGroups() or {}) or {}
    for index, group in ipairs(groups) do
        if isvector(group.center) then
            local groupRef = ZScavSpawnPoints.GetGroupRef and ZScavSpawnPoints.GetGroupRef(index) or ("G" .. tostring(index))
            addMarker(markers, bounds, {
                kind = "spawn_group_center",
                pos = group.center,
                label = groupRef,
                color = COLORS.spawnGroup,
                size = 8,
                radius = math.max(tonumber(group.radius) or 0, 0),
            })
            summary.groupCenters = summary.groupCenters + 1
        end

        local expanded = ZScavSpawnPoints and ZScavSpawnPoints.ExpandGroup and ZScavSpawnPoints.ExpandGroup(group) or {}
        for _, member in ipairs(expanded) do
            addMarker(markers, bounds, {
                kind = "spawn_group_member",
                pos = member.pos,
                color = COLORS.spawnGroupMember,
                size = 4,
            })
            summary.groupSlots = summary.groupSlots + 1
        end
    end

    local rawExtracts = getPointGroup("ZSCAV_EXTRACT")
    for index, point in ipairs(rawExtracts) do
        addMarker(markers, bounds, {
            kind = "raw_extract",
            pos = resolvePointPos(point),
            label = "X" .. tostring(index),
            color = COLORS.rawExtract,
            size = 8,
        })
        summary.rawExtracts = summary.rawExtracts + 1
    end

    local namedExtracts = ZScavExtracts and ZScavExtracts.GetExtracts and (ZScavExtracts.GetExtracts() or {}) or {}
    for index, extract in ipairs(namedExtracts) do
        local label = trimLabel(extract.name)
        if label == "" then
            label = "Extract " .. tostring(index)
        end

        addMarker(markers, bounds, {
            kind = "named_extract",
            pos = extract.pos,
            label = abbreviateLabel(label, 16),
            color = COLORS.namedExtract,
            size = 10,
            radius = 220,
        })
        summary.namedExtracts = summary.namedExtracts + 1
    end

    local lp = LocalPlayer()
    if IsValid(lp) then
        addMarker(markers, bounds, {
            kind = "player",
            pos = lp:GetPos(),
            color = COLORS.player,
            size = 8,
            includeInBounds = false,
            yaw = lp:EyeAngles().y,
        })
    end

    return markers, normalizeBounds(bounds), summary
end

local function drawCircleOutline(centerX, centerY, radius, color, segments)
    if radius <= 1 then return end

    surface.SetDrawColor(color)
    local lastX, lastY
    for step = 0, segments do
        local angle = (step / segments) * math.pi * 2
        local px = centerX + math.cos(angle) * radius
        local py = centerY + math.sin(angle) * radius
        if lastX then
            surface.DrawLine(lastX, lastY, px, py)
        end
        lastX, lastY = px, py
    end
end

local function drawSquare(centerX, centerY, size, color)
    surface.SetDrawColor(color)
    surface.DrawRect(centerX - size, centerY - size, size * 2, size * 2)
end

local function drawCross(centerX, centerY, size, color)
    surface.SetDrawColor(color)
    surface.DrawLine(centerX - size, centerY - size, centerX + size, centerY + size)
    surface.DrawLine(centerX - size, centerY + size, centerX + size, centerY - size)
end

local function drawDiamond(centerX, centerY, size, color)
    draw.NoTexture()
    surface.SetDrawColor(color)
    surface.DrawPoly({
        { x = centerX, y = centerY - size },
        { x = centerX + size, y = centerY },
        { x = centerX, y = centerY + size },
        { x = centerX - size, y = centerY },
    })
end

local function drawPlayerArrow(centerX, centerY, yaw, size, color)
    local radians = math.rad(tonumber(yaw) or 0)
    local fwdX = math.cos(radians)
    local fwdY = -math.sin(radians)
    local rightX = -fwdY
    local rightY = fwdX

    draw.NoTexture()
    surface.SetDrawColor(color)
    surface.DrawPoly({
        { x = centerX + fwdX * size * 1.6, y = centerY + fwdY * size * 1.6 },
        { x = centerX - fwdX * size * 0.6 - rightX * size, y = centerY - fwdY * size * 0.6 - rightY * size },
        { x = centerX - fwdX * size * 0.15, y = centerY - fwdY * size * 0.15 },
        { x = centerX - fwdX * size * 0.6 + rightX * size, y = centerY - fwdY * size * 0.6 + rightY * size },
    })
end

local function drawLegendLine(x, y, color, text)
    surface.SetDrawColor(color)
    surface.DrawRect(x, y + 4, 10, 10)
    draw.SimpleText(text, "ZScavSetupMinimapTiny", x + 16, y + 9, COLORS.textMuted,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "ZScavSetupMinimap_Draw", function()
    if not enabledCvar:GetBool() then return end
    if not isLocalAdmin() then return end

    local markers, bounds, summary = collectSetupData()

    local panelPad = hudScale(14)
    local headerH = hudScale(48)
    local footerH = hudScale(106)
    local panelW = math.min(math.max(math.floor(ScrW() * 0.23), hudScale(360)), hudScale(460))
    local mapSize = panelW - panelPad * 2
    local panelH = headerH + footerH + mapSize + panelPad * 2
    local panelX = ScrW() - panelW - hudScale(22)
    local panelY = hudScale(22)
    local mapX = panelX + panelPad
    local mapY = panelY + headerH
    local mapW = mapSize
    local mapH = mapSize

    draw.RoundedBox(12, panelX, panelY, panelW, panelH, COLORS.panel)
    surface.SetDrawColor(COLORS.panelBorder)
    surface.DrawOutlinedRect(panelX, panelY, panelW, panelH, 1)

    draw.SimpleText("ZScav Setup Minimap", "ZScavSetupMinimapTitle",
        panelX + panelPad, panelY + hudScale(12), COLORS.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("toggle: zscav_setup_minimap_toggle", "ZScavSetupMinimapTiny",
        panelX + panelPad, panelY + hudScale(32), COLORS.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    draw.RoundedBox(10, mapX, mapY, mapW, mapH, COLORS.mapFill)
    surface.SetDrawColor(COLORS.mapBorder)
    surface.DrawOutlinedRect(mapX, mapY, mapW, mapH, 1)

    for step = 1, 3 do
        local frac = step / 4
        local lineX = mapX + mapW * frac
        local lineY = mapY + mapH * frac
        surface.SetDrawColor(COLORS.grid)
        surface.DrawLine(lineX, mapY, lineX, mapY + mapH)
        surface.DrawLine(mapX, lineY, mapX + mapW, lineY)
    end

    local centerX = mapX + mapW * 0.5
    local centerY = mapY + mapH * 0.5
    surface.SetDrawColor(Color(COLORS.grid.r, COLORS.grid.g, COLORS.grid.b, 70))
    surface.DrawLine(centerX, mapY, centerX, mapY + mapH)
    surface.DrawLine(mapX, centerY, mapX + mapW, centerY)

    local worldSpan = math.max(bounds.span, 1)
    local scale = math.min(mapW, mapH) / worldSpan

    for _, marker in ipairs(markers) do
        if marker.radius and marker.radius > 0 and marker.kind ~= "player" then
            local px, py = worldToMap(marker.pos, mapX, mapY, mapW, mapH, bounds, false)
            drawCircleOutline(px, py, marker.radius * scale, ColorAlpha(marker.color, 80), 48)
        end
    end

    for _, marker in ipairs(markers) do
        local px, py, outside = worldToMap(marker.pos, mapX, mapY, mapW, mapH, bounds, marker.kind == "player")

        if marker.kind == "spawn_group_member" then
            drawSquare(px, py, marker.size or 4, marker.color)
        elseif marker.kind == "spawn_group_center" then
            drawCircleOutline(px, py, marker.size or 8, marker.color, 24)
            if marker.label then
                draw.SimpleTextOutlined(marker.label, "ZScavSetupMinimapTiny", px, py - hudScale(10), marker.color,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
            end
        elseif marker.kind == "safe_spawn" then
            drawSquare(px, py, marker.size or 6, marker.color)
            if marker.label then
                draw.SimpleTextOutlined(marker.label, "ZScavSetupMinimapTiny", px, py - hudScale(9), marker.color,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
            end
        elseif marker.kind == "raw_extract" then
            drawCross(px, py, marker.size or 8, marker.color)
            if marker.label then
                draw.SimpleTextOutlined(marker.label, "ZScavSetupMinimapTiny", px, py - hudScale(9), marker.color,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
            end
        elseif marker.kind == "named_extract" then
            drawDiamond(px, py, marker.size or 10, marker.color)
            if marker.label then
                draw.SimpleTextOutlined(marker.label, "ZScavSetupMinimapTiny", px, py + hudScale(12), marker.color,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
            end
        elseif marker.kind == "player" then
            drawPlayerArrow(px, py, marker.yaw, marker.size or 8, outside and Color(255, 128, 128) or marker.color)
        end
    end

    local footerX = panelX + panelPad
    local footerY = mapY + mapH + hudScale(12)
    local safeSourceLabel = summary.safeCount > 0 and abbreviateLabel(summary.safeSource, 14) or "none"

    draw.SimpleText(
        string.format("Safe spawns: %d (%s)", summary.safeCount, safeSourceLabel),
        "ZScavSetupMinimapSmall", footerX, footerY, COLORS.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(
        string.format("Spawn groups: %d centers / %d slots", summary.groupCenters, summary.groupSlots),
        "ZScavSetupMinimapSmall", footerX, footerY + hudScale(18), COLORS.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(
        string.format("Extracts: %d named / %d raw", summary.namedExtracts, summary.rawExtracts),
        "ZScavSetupMinimapSmall", footerX, footerY + hudScale(36), COLORS.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local legendX = footerX
    local legendY = footerY + hudScale(56)
    drawLegendLine(legendX, legendY, COLORS.safeSpawn, "safe spawn")
    drawLegendLine(legendX + hudScale(140), legendY, COLORS.spawnGroup, "group / slots")
    drawLegendLine(legendX, legendY + hudScale(18), COLORS.namedExtract, "named extract")
    drawLegendLine(legendX + hudScale(140), legendY + hudScale(18), COLORS.rawExtract, "raw extract")

    if #markers <= 1 then
        draw.SimpleText("No ZScav setup markers synced yet.", "ZScavSetupMinimapBody",
            mapX + mapW * 0.5, mapY + mapH * 0.5 - hudScale(10), COLORS.textMuted,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Run zscav_setup_minimap_refresh after placing points.", "ZScavSetupMinimapTiny",
            mapX + mapW * 0.5, mapY + mapH * 0.5 + hudScale(10), COLORS.textMuted,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)