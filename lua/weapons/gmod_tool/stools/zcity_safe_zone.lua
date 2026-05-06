TOOL.Category = "ZCity"
TOOL.Name = "#tool.zcity_safe_zone.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
    name = "Safe Zone",
    height = tostring((ZCitySafeZones and ZCitySafeZones.DefaultHeight) or 160),
}

TOOL.Information = {
    { name = "left" },
    { name = "right" },
    { name = "reload" },
}

local lib = ZCitySafeZones or {}
local NET = lib.Net or {}

lib = setmetatable({}, {
    __index = function(_, key)
        local runtime = rawget(_G, "ZCitySafeZones")
        return runtime and runtime[key] or nil
    end,
})

NET = setmetatable({}, {
    __index = function(_, key)
        local runtime = rawget(_G, "ZCitySafeZones")
        local netNames = runtime and runtime.Net
        return netNames and netNames[key] or nil
    end,
})

if CLIENT then
    language.Add("tool.zcity_safe_zone.name", "ZCity Safe Zone Tool")
    language.Add("tool.zcity_safe_zone.desc", "Create and manage persisted safe-zone boxes for stashes, traders, team finding, and loadout staging.")
    language.Add("tool.zcity_safe_zone.left", "Set the first corner of a safe zone box")
    language.Add("tool.zcity_safe_zone.right", "Create a safe zone from the stored first corner to the point you are aiming at")
    language.Add("tool.zcity_safe_zone.reload", "Select the safe zone under your crosshair")
    language.Add("tool.zcity_safe_zone.name_label", "Zone Name")
    language.Add("tool.zcity_safe_zone.height", "Zone Height")
end

local function canEdit(ply)
    if not IsValid(ply) then return false end
    if not isfunction(lib.CanEdit) then return ply:IsAdmin() or ply:IsSuperAdmin() end
    return lib.CanEdit(ply)
end

if SERVER then
    local function notifyDenied(ply)
        if not IsValid(ply) then return end
        ply:ChatPrint("[ZCity] Admin+ only.")
    end

    function TOOL:LeftClick(trace)
        local owner = self:GetOwner()
        if not canEdit(owner) then
            notifyDenied(owner)
            return false
        end

        if not trace.Hit then return false end
        return lib.SetStartCorner(owner, trace.HitPos)
    end

    function TOOL:RightClick(trace)
        local owner = self:GetOwner()
        if not canEdit(owner) then
            notifyDenied(owner)
            return false
        end

        if not trace.Hit then return false end

        local firstCorner = isfunction(lib.GetStartCorner) and lib.GetStartCorner(owner) or nil
        if not isvector(firstCorner) then return false end

        local zone = isfunction(lib.CreateZone)
            and lib.CreateZone(
                owner,
                self:GetClientInfo("name"),
                firstCorner,
                trace.HitPos,
                self:GetClientNumber("height", lib.DefaultHeight or 160)
            )
            or nil

        return zone ~= nil
    end

    function TOOL:Reload(trace)
        local owner = self:GetOwner()
        if not canEdit(owner) then
            notifyDenied(owner)
            return false
        end

        if not trace.Hit then return false end
        if isfunction(lib.SelectZoneAtPos) then
            lib.SelectZoneAtPos(owner, trace.HitPos, 8)
        end
        return true
    end

    return
end

local function requestState(force)
    if not NET.RequestState then return end

    lib._nextStateRequest = lib._nextStateRequest or 0
    if not force and lib._nextStateRequest > CurTime() then return end

    lib._nextStateRequest = CurTime() + 0.75
    net.Start(NET.RequestState)
    net.SendToServer()
end

local function sendAction(action, payload)
    if not NET.Action then return end

    net.Start(NET.Action)
        net.WriteString(tostring(action or ""))
        if payload ~= nil then
            net.WriteString(tostring(payload))
        end
    net.SendToServer()
end

local function getZoneList()
    return (isfunction(lib.GetZones) and lib.GetZones()) or {}
end

local function getEditorState()
    return (isfunction(lib.GetEditorState) and lib.GetEditorState()) or {}
end

local function getSelectedZone()
    return isfunction(lib.GetSelectedZone) and lib.GetSelectedZone() or nil
end

local function getToolHeight(tool)
    local defaultHeight = tonumber(lib.DefaultHeight) or 160
    return math.Clamp(tool:GetClientNumber("height", defaultHeight), lib.MinHeight or 32, lib.MaxHeight or 1024)
end

local function formatVec(vec)
    if not isvector(vec) then return "None" end
    return string.format("%.0f %.0f %.0f", vec.x, vec.y, vec.z)
end

local function computeStateSignature()
    local state = getEditorState()
    local zones = getZoneList()
    local parts = {
        tostring(state.selectedZoneID or ""),
        tostring(state.hasStart or false),
        isvector(state.startCorner) and formatVec(state.startCorner) or "nostart",
        tostring(#zones),
    }

    for _, zone in ipairs(zones) do
        parts[#parts + 1] = table.concat({
            tostring(zone.id or ""),
            tostring(zone.name or ""),
            formatVec(lib.GetZoneCenter and lib.GetZoneCenter(zone) or vector_origin),
        }, "|")
    end

    return table.concat(parts, "||")
end

local function toolIsActive()
    local lply = LocalPlayer()
    if not IsValid(lply) then return nil, nil end

    local weapon = lply:GetActiveWeapon()
    if not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool" then return nil, nil end

    local tool = lply.GetTool and lply:GetTool() or nil
    if not tool or tool.Mode ~= "zcity_safe_zone" then return nil, nil end

    return lply, tool
end

local function drawZoneLabel(zone, color)
    local center = lib.GetZoneCenter and lib.GetZoneCenter(zone) or Vector(0, 0, 0)
    local size = lib.GetZoneSize and lib.GetZoneSize(zone) or Vector(0, 0, 0)
    local ang = Angle(0, EyeAngles().y - 90, 90)

    cam.Start3D2D(center + Vector(0, 0, size.z * 0.5 + 8), ang, 0.12)
        draw.SimpleTextOutlined(
            tostring(zone.name or zone.id or "Safe Zone"),
            "DermaDefaultBold",
            0,
            0,
            color,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            1,
            Color(0, 0, 0, 220)
        )
    cam.End3D2D()
end

local function drawZone(zone, color)
    local mins, maxs = lib.GetZoneBounds(zone)
    local center = lib.GetZoneCenter(zone)

    render.DrawWireframeBox(center, angle_zero, mins - center, maxs - center, color, true)
    drawZoneLabel(zone, color)
end

hook.Add("PostDrawTranslucentRenderables", "ZCitySafeZoneTool_DrawZones", function(_, skybox)
    if skybox then return end

    local lply, tool = toolIsActive()
    if not IsValid(lply) then return end

    requestState(false)

    local selectedID = isfunction(lib.GetSelectedZoneID) and lib.GetSelectedZoneID() or ""
    for _, zone in ipairs(getZoneList()) do
        local isSelected = selectedID ~= "" and zone.id == selectedID
        drawZone(zone, isSelected and Color(255, 220, 90) or Color(80, 180, 255))
    end

    local state = getEditorState()
    if state.hasStart and isvector(state.startCorner) then
        local preview = lib.MakeZoneFromCorners(
            tool:GetClientInfo("name"),
            state.startCorner,
            lply:GetEyeTrace().HitPos,
            getToolHeight(tool)
        )

        if preview then
            drawZone(preview, Color(120, 255, 120))
        end

        render.DrawWireframeSphere(state.startCorner, 4, 8, 8, Color(120, 255, 120), true)
    end
end)

function TOOL:LeftClick()
    requestState(false)
    return true
end

function TOOL:RightClick()
    requestState(false)
    return true
end

function TOOL:Reload()
    requestState(false)
    return true
end

function TOOL.BuildCPanel(panel)
    panel:Help("#tool.zcity_safe_zone.desc")
    panel:ControlHelp("Left click sets corner A. Right click creates the zone using the current height. Reload selects the zone under your crosshair.")
    panel:TextEntry("#tool.zcity_safe_zone.name_label", "zcity_safe_zone_name")
    panel:NumSlider("#tool.zcity_safe_zone.height", "zcity_safe_zone_height", lib.MinHeight or 32, lib.MaxHeight or 1024, 0)

    local statusLabel = vgui.Create("DLabel", panel)
    statusLabel:Dock(TOP)
    statusLabel:DockMargin(0, 0, 0, 8)
    statusLabel:SetWrap(true)
    statusLabel:SetAutoStretchVertical(true)
    panel:AddItem(statusLabel)

    function statusLabel:Think()
        local state = getEditorState()
        local selectedZone = getSelectedZone()
        local text = string.format(
            "Corner A: %s\nSelected Zone: %s",
            state.hasStart and formatVec(state.startCorner) or "Not set",
            selectedZone and tostring(selectedZone.name or selectedZone.id or "None") or "None"
        )

        if self:GetText() ~= text then
            self:SetText(text)
            self:SizeToContentsY()
        end
    end

    local zoneList = vgui.Create("DListView", panel)
    zoneList:SetTall(220)
    zoneList:AddColumn("Zone")
    zoneList:AddColumn("Size")
    zoneList:AddColumn("Center")
    panel:AddItem(zoneList)

    function zoneList:RefreshRows()
        self._syncing = true
        self:Clear()

        local selectedID = isfunction(lib.GetSelectedZoneID) and lib.GetSelectedZoneID() or ""
        for _, zone in ipairs(getZoneList()) do
            local size = lib.GetZoneSize(zone)
            local center = lib.GetZoneCenter(zone)
            local line = self:AddLine(
                tostring(zone.name or zone.id or "Zone"),
                string.format("%.0f x %.0f x %.0f", size.x, size.y, size.z),
                formatVec(center)
            )
            line.ZoneID = zone.id

            if selectedID ~= "" and selectedID == zone.id then
                self:SelectItem(line)
            end
        end

        self._syncing = false
    end

    function zoneList:OnRowSelected(_, row)
        if self._syncing or not row or not row.ZoneID then return end
        sendAction("select_zone", row.ZoneID)
    end

    function zoneList:Think()
        local signature = computeStateSignature()
        if self._stateSignature ~= signature then
            self._stateSignature = signature
            self:RefreshRows()
        end
    end

    local refreshButton = panel:Button("Refresh Zones")
    function refreshButton:DoClick()
        requestState(true)
    end

    local useNameButton = panel:Button("Use Selected Zone Name")
    function useNameButton:DoClick()
        local zone = getSelectedZone()
        if not zone then return end
        RunConsoleCommand("zcity_safe_zone_name", tostring(zone.name or lib.DefaultName or "Safe Zone"))
    end

    local renameButton = panel:Button("Rename Selected")
    function renameButton:DoClick()
        local zone = getSelectedZone()
        if not zone then return end
        sendAction("rename_selected", GetConVarString("zcity_safe_zone_name"))
    end

    local deleteButton = panel:Button("Delete Selected")
    function deleteButton:DoClick()
        local zone = getSelectedZone()
        if not zone then return end
        sendAction("delete_selected")
    end

    local clearCornerButton = panel:Button("Clear First Corner")
    function clearCornerButton:DoClick()
        sendAction("clear_start")
    end

    requestState(true)
end