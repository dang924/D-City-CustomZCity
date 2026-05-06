-- ZScav Spawn Point Tool.
-- Left click  : add spawn point at trace, yaw = your facing
-- Right click : remove nearest spawn point within 96u of trace
-- Reload      : clear all spawn points (on this map)

TOOL.Category   = "ZCity"
TOOL.Tab        = "Utilities"
TOOL.Name       = "#tool.zcity_zscav_spawnpoint.name"
TOOL.Command    = nil
TOOL.ConfigName = ""

TOOL.Information = {
    { name = "left" },
    { name = "right" },
    { name = "reload" },
}

if CLIENT then
    language.Add("tool.zcity_zscav_spawnpoint.name", "ZScav Spawn Point Tool")
    language.Add("tool.zcity_zscav_spawnpoint.desc", "Place battlefield spawn groups used by the ZScav spawn-pad raid trigger.")
    language.Add("tool.zcity_zscav_spawnpoint.left", "Add a spawn group center (yaw = your facing)")
    language.Add("tool.zcity_zscav_spawnpoint.right", "Remove the nearest spawn group within 96 units")
    language.Add("tool.zcity_zscav_spawnpoint.reload", "Clear all spawn groups on this map")
end

local function canEdit(ply)
    if not IsValid(ply) then return false end
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function netSend(action, writer)
    net.Start(ZScavSpawnPoints.Net.Action)
        net.WriteUInt(action, 3)
        if writer then writer() end
    net.SendToServer()
end

function TOOL:LeftClick(trace)
    if SERVER then return false end  -- networked from client
    local owner = self:GetOwner()
    if not canEdit(owner) then return false end
    if not trace.Hit then return false end

    local yaw = owner:EyeAngles().y
    netSend(ZScavSpawnPoints.ACTION_ADD, function()
        net.WriteVector(trace.HitPos)
        net.WriteFloat(yaw)
    end)
    return true
end

function TOOL:RightClick(trace)
    if SERVER then return false end
    local owner = self:GetOwner()
    if not canEdit(owner) then return false end
    if not trace.Hit then return false end

    netSend(ZScavSpawnPoints.ACTION_REMOVE, function()
        net.WriteVector(trace.HitPos)
    end)
    return true
end

function TOOL:Reload(_trace)
    if SERVER then return false end
    local owner = self:GetOwner()
    if not canEdit(owner) then return false end

    -- Confirmation: only clear after a 2nd reload within 1.5s
    local now = CurTime()
    if (self._lastReloadAt or 0) + 1.5 < now then
        self._lastReloadAt = now
        chat.AddText(Color(255, 200, 60), "[ZScav] Press Reload again within 1.5s to clear ALL spawn points.")
        return false
    end
    self._lastReloadAt = 0

    netSend(ZScavSpawnPoints.ACTION_CLEAR, function() end)
    return true
end

if CLIENT then
    local selectedGroupID = nil

    local function notify(text, color)
        chat.AddText(color or Color(120, 220, 255), "[ZScav] ", color_white, tostring(text or ""))
    end

    local function sendGroupIDAction(action, groupID, extraWriter)
        groupID = string.Trim(tostring(groupID or ""))
        if groupID == "" then
            notify("Select a spawn group first.", Color(255, 200, 60))
            return false
        end

        netSend(action, function()
            net.WriteString(groupID)
            if extraWriter then
                extraWriter()
            end
        end)

        return true
    end

    -- Render markers in 3D when holding this tool. Each group draws as a
    -- depth-tested 3D2D ring on the floor with N labeled dots around it,
    -- one per spawn position in that group.
    local function drawGroupMarker(group, idx)
        local center = group.center
        if not isvector(center) then return end
        local positions = ZScavSpawnPoints.ExpandGroup(group)
        local isSelected = string.Trim(tostring(group.id or "")) ~= "" and string.Trim(tostring(group.id or "")) == selectedGroupID
        local ringColor = isSelected and Color(120, 255, 160, 130) or Color(120, 220, 255, 100)
        local pointColor = isSelected and Color(120, 255, 160, 240) or Color(80, 200, 255, 220)
        local textColor = isSelected and Color(160, 255, 190) or Color(120, 220, 255)

        -- Floor ring outlining the group's radius.
        cam.Start3D2D(center + Vector(0, 0, 1), Angle(0, 0, 0), 1)
            surface.SetDrawColor(ringColor)
            local segs = 48
            for s = 0, segs - 1 do
                local a1 = (s       / segs) * math.pi * 2
                local a2 = ((s + 1) / segs) * math.pi * 2
                surface.DrawLine(
                    math.cos(a1) * group.radius, math.sin(a1) * group.radius,
                    math.cos(a2) * group.radius, math.sin(a2) * group.radius
                )
            end
        cam.End3D2D()

        -- Each member position: a small ring + a facing arrow.
        for memberIdx, pt in ipairs(positions) do
            local p = pt.pos + Vector(0, 0, 1)
            cam.Start3D2D(p, Angle(0, 0, 0), 1)
                surface.SetDrawColor(pointColor)
                local segs2, r = 16, 10
                for s = 0, segs2 - 1 do
                    local a1 = (s       / segs2) * math.pi * 2
                    local a2 = ((s + 1) / segs2) * math.pi * 2
                    surface.DrawLine(
                        math.cos(a1) * r, math.sin(a1) * r,
                        math.cos(a2) * r, math.sin(a2) * r
                    )
                end
                -- Facing tick: a short line from center toward member yaw.
                local fwdRad = math.rad(pt.yaw or 0)
                surface.DrawLine(0, 0, math.cos(fwdRad) * 22, math.sin(fwdRad) * 22)
            cam.End3D2D()
        end

        -- Group label, billboarded toward player. Rotated so it stands upright.
        local yawToCam = (EyePos() - center):Angle().y
        cam.Start3D2D(center + Vector(0, 0, 36), Angle(0, yawToCam - 90, 90), 0.18)
            draw.SimpleText(
                string.format("%s (%d)",
                    (ZScavSpawnPoints.GetGroupLabel and ZScavSpawnPoints.GetGroupLabel(group, idx)) or ("G" .. tostring(idx)),
                    #positions),
                "DermaDefaultBold", 0, 0,
                textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
            )
        cam.End3D2D()
    end

    hook.Add("PostDrawTranslucentRenderables", "ZScavSpawnPoints_ToolMarkers", function(_d, sky, sky3d)
        if sky or sky3d then return end
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local wep = lp:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return end
        local mode = lp:GetInfo("gmod_toolmode")
        if mode ~= "zcity_zscav_spawnpoint" then return end

        local groups = ZScavSpawnPoints.GetGroups and ZScavSpawnPoints.GetGroups() or {}
        for i, g in ipairs(groups) do
            drawGroupMarker(g, i)
        end
    end)

    function TOOL.BuildCPanel(panel)
        panel:Help("Battlefield spawn groups used by the ZScav raid pads. Left click adds a new group at your trace; right click removes the nearest group.")

        local groupList = vgui.Create("DListView")
        groupList:SetTall(220)
        groupList:SetMultiSelect(false)
        groupList:AddColumn("Ref")
        groupList:AddColumn("Name")
        groupList:AddColumn("Slots")
        groupList:AddColumn("Radius")
        groupList:AddColumn("ID")
        panel:AddItem(groupList)

        local renameEntry = vgui.Create("DTextEntry")
        renameEntry:SetTall(24)
        if renameEntry.SetPlaceholderText then
            renameEntry:SetPlaceholderText("Selected group name")
        end
        panel:AddItem(renameEntry)

        local selectedHelp = vgui.Create("DLabel")
        selectedHelp:SetWrap(true)
        selectedHelp:SetAutoStretchVertical(true)
        selectedHelp:SetFont("DermaDefault")
        selectedHelp:SetTextColor(color_white)
        selectedHelp:SetText("Select a spawn group to teleport, rename, or delete it.")
        panel:AddItem(selectedHelp)

        local function updateSelectedHelp(group, index)
            if not IsValid(selectedHelp) then return end

            if not istable(group) then
                selectedHelp:SetText("Select a spawn group to teleport, rename, or delete it.")
                selectedHelp:SizeToContentsY()
                return
            end

            local label = (ZScavSpawnPoints.GetGroupLabel and ZScavSpawnPoints.GetGroupLabel(group, index)) or ("G" .. tostring(index))
            local groupID = string.Trim(tostring(group.id or ""))
            selectedHelp:SetText(string.format("Selected: %s\nID: %s", label, groupID ~= "" and groupID or "no-id"))
            selectedHelp:SizeToContentsY()
        end

        local function getSelectedGroup()
            local groups = ZScavSpawnPoints.GetGroups and ZScavSpawnPoints.GetGroups() or {}
            for index, group in ipairs(groups) do
                if string.Trim(tostring(group.id or "")) == string.Trim(tostring(selectedGroupID or "")) then
                    return group, index
                end
            end

            return nil
        end

        local function refreshGroupList()
            if not IsValid(groupList) then return end

            local groups = ZScavSpawnPoints.GetGroups and ZScavSpawnPoints.GetGroups() or {}
            local nextSelectedLine
            local nextSelectedGroup
            local nextSelectedIndex

            groupList:Clear()

            for index, group in ipairs(groups) do
                local ref = (ZScavSpawnPoints.GetGroupRef and ZScavSpawnPoints.GetGroupRef(index)) or ("G" .. tostring(index))
                local displayName = (ZScavSpawnPoints.GetGroupDisplayName and ZScavSpawnPoints.GetGroupDisplayName(group, index)) or ref
                local line = groupList:AddLine(
                    ref,
                    displayName ~= ref and displayName or "",
                    math.max(math.floor(tonumber(group.count) or 0), 0),
                    math.max(math.floor(tonumber(group.radius) or 0), 0),
                    tostring(group.id or "")
                )
                line._groupID = tostring(group.id or "")
                line._groupName = tostring(group.name or "")

                if line._groupID ~= "" and line._groupID == string.Trim(tostring(selectedGroupID or "")) then
                    nextSelectedLine = line
                    nextSelectedGroup = group
                    nextSelectedIndex = index
                end
            end

            if IsValid(nextSelectedLine) then
                groupList:SelectItem(nextSelectedLine)
                if IsValid(renameEntry) then
                    renameEntry:SetValue(nextSelectedLine._groupName or "")
                end
                updateSelectedHelp(nextSelectedGroup, nextSelectedIndex)
            else
                selectedGroupID = nil
                if IsValid(renameEntry) then
                    renameEntry:SetValue("")
                end
                updateSelectedHelp(nil)
            end
        end

        groupList.OnRowSelected = function(_, _, line)
            selectedGroupID = string.Trim(tostring(line and line._groupID or ""))
            if IsValid(renameEntry) then
                renameEntry:SetValue(line and line._groupName or "")
            end

            local group, index = getSelectedGroup()
            updateSelectedHelp(group, index)
        end

        renameEntry.OnEnter = function(self)
            if not sendGroupIDAction(ZScavSpawnPoints.ACTION_RENAME, selectedGroupID, function()
                net.WriteString(self:GetValue() or "")
            end) then
                return
            end
        end

        local teleportButton = vgui.Create("DButton")
        teleportButton:SetText("Teleport To Selected Group")
        teleportButton:SetTall(24)
        teleportButton.DoClick = function()
            sendGroupIDAction(ZScavSpawnPoints.ACTION_TELEPORT, selectedGroupID)
        end
        panel:AddItem(teleportButton)

        local renameButton = vgui.Create("DButton")
        renameButton:SetText("Rename Selected Group")
        renameButton:SetTall(24)
        renameButton.DoClick = function()
            sendGroupIDAction(ZScavSpawnPoints.ACTION_RENAME, selectedGroupID, function()
                net.WriteString(IsValid(renameEntry) and renameEntry:GetValue() or "")
            end)
        end
        panel:AddItem(renameButton)

        local deleteButton = vgui.Create("DButton")
        deleteButton:SetText("Delete Selected Group")
        deleteButton:SetTall(24)
        deleteButton.DoClick = function()
            if sendGroupIDAction(ZScavSpawnPoints.ACTION_REMOVE_ID, selectedGroupID) then
                selectedGroupID = nil
            end
        end
        panel:AddItem(deleteButton)

        panel:Help("Selections stay synced with the active map data. Group names are saved and also shown in the extract-linking tools.")

        local hookID = "ZScavSpawnPoints_ToolPanel_" .. tostring(panel)
        hook.Add("ZScavSpawnPoints_ClientUpdated", hookID, refreshGroupList)

        refreshGroupList()

        local oldOnRemove = panel.OnRemove
        panel.OnRemove = function(self)
            hook.Remove("ZScavSpawnPoints_ClientUpdated", hookID)
            if isfunction(oldOnRemove) then
                oldOnRemove(self)
            end
        end
    end
end
