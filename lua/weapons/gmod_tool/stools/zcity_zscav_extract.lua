-- ZScav Extract Tool.
-- Left click  : add/update named extract at trace, yaw = your facing
-- Right click : remove nearest named extract within 128u of trace
-- Reload      : clear all named extracts on this map

TOOL.Category = "ZCity"
TOOL.Tab = "Utilities"
TOOL.Name = "#tool.zcity_zscav_extract.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = {
    name = "",
    duration = tostring(ZScavExtracts and ZScavExtracts.DEFAULT_DURATION or 8),
    groups = "",
}

TOOL.Information = {
    { name = "left" },
    { name = "right" },
    { name = "reload" },
}

if CLIENT then
    language.Add("tool.zcity_zscav_extract.name", "ZScav Extract Tool")
    language.Add("tool.zcity_zscav_extract.desc", "Place named raid extracts, configure hold time, and link them to ZScav spawn groups on this map.")
    language.Add("tool.zcity_zscav_extract.left", "Add or update a named extract using the current name, extraction time, and linked spawn-group list")
    language.Add("tool.zcity_zscav_extract.right", "Remove the nearest named extract within 128 units")
    language.Add("tool.zcity_zscav_extract.reload", "Clear all named extracts on this map")
end

local MARKER_RADIUS = 220

local function canEdit(ply)
    if not IsValid(ply) then return false end
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function netSend(action, writer)
    net.Start(ZScavExtracts.Net.Action)
        net.WriteUInt(action, 3)
        if writer then writer() end
    net.SendToServer()
end

function TOOL:LeftClick(trace)
    if SERVER then return false end

    local owner = self:GetOwner()
    if not canEdit(owner) then return false end
    if not trace.Hit then return false end

    local yaw = owner:EyeAngles().y
    local name = self:GetClientInfo("name")
    local duration = math.Clamp(math.floor(tonumber(self:GetClientInfo("duration")) or (ZScavExtracts and ZScavExtracts.DEFAULT_DURATION) or 8), 1, 255)
    local groups = self:GetClientInfo("groups")

    netSend(ZScavExtracts.ACTION_UPSERT, function()
        net.WriteVector(trace.HitPos)
        net.WriteFloat(yaw)
        net.WriteString(name or "")
        net.WriteUInt(duration, 8)
        net.WriteString(groups or "")
    end)
    return true
end

function TOOL:RightClick(trace)
    if SERVER then return false end

    local owner = self:GetOwner()
    if not canEdit(owner) then return false end
    if not trace.Hit then return false end

    netSend(ZScavExtracts.ACTION_REMOVE, function()
        net.WriteVector(trace.HitPos)
    end)
    return true
end

function TOOL:Reload(_trace)
    if SERVER then return false end

    local owner = self:GetOwner()
    if not canEdit(owner) then return false end

    local now = CurTime()
    if (self._lastReloadAt or 0) + 1.5 < now then
        self._lastReloadAt = now
        chat.AddText(Color(255, 200, 60), "[ZScav] Press Reload again within 1.5s to clear ALL named extracts.")
        return false
    end

    self._lastReloadAt = 0
    netSend(ZScavExtracts.ACTION_CLEAR)
    return true
end

if CLIENT then
    local function getFormattedGroupRefs(groups)
        if not (istable(groups) and #groups > 0) then
            return "Groups: ANY"
        end

        local groupIndexByID = {}
        local spawnGroups = ZScavSpawnPoints and ZScavSpawnPoints.GetGroups and ZScavSpawnPoints.GetGroups() or {}
        for index, group in ipairs(spawnGroups) do
            local groupID = tostring(group.id or "")
            if groupID ~= "" then
                groupIndexByID[groupID] = index
            end
        end

        local labels = {}
        for _, groupID in ipairs(groups) do
            groupID = tostring(groupID or "")
            local index = groupIndexByID[groupID]
            labels[#labels + 1] = index and ((ZScavSpawnPoints.GetGroupRef and ZScavSpawnPoints.GetGroupRef(index)) or ("G" .. tostring(index))) or groupID
        end

        return "Groups: " .. table.concat(labels, ", ")
    end

    local function drawExtractMarker(extract, index)
        if not (istable(extract) and isvector(extract.pos)) then return end

        local pos = extract.pos
        local label = string.Trim(tostring(extract.name or ""))
        if label == "" then
            label = "Extract #" .. tostring(index)
        end
        local duration = math.Clamp(math.floor(tonumber(extract.duration) or (ZScavExtracts and ZScavExtracts.DEFAULT_DURATION) or 8), 1, 255)

        cam.Start3D2D(pos + Vector(0, 0, 1), Angle(0, 0, 0), 1)
            surface.SetDrawColor(245, 188, 72, 110)
            for segment = 0, 47 do
                local a1 = (segment / 48) * math.pi * 2
                local a2 = ((segment + 1) / 48) * math.pi * 2
                surface.DrawLine(
                    math.cos(a1) * MARKER_RADIUS, math.sin(a1) * MARKER_RADIUS,
                    math.cos(a2) * MARKER_RADIUS, math.sin(a2) * MARKER_RADIUS
                )
            end
        cam.End3D2D()

        local yawToCam = (EyePos() - pos):Angle().y
        cam.Start3D2D(pos + Vector(0, 0, 40), Angle(0, yawToCam - 90, 90), 0.18)
            draw.SimpleText(label, "DermaDefaultBold", 0, -14, Color(245, 188, 72), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.format("Hold: %ds", duration), "DermaDefault", 0, 10, Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(getFormattedGroupRefs(extract.groups), "DermaDefault", 0, 30, Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end

    hook.Add("PostDrawTranslucentRenderables", "ZScavExtracts_ToolMarkers", function(_drawingDepth, skybox, skybox3D)
        if skybox or skybox3D then return end

        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local weapon = lp:GetActiveWeapon()
        if not (IsValid(weapon) and weapon:GetClass() == "gmod_tool") then return end
        if lp:GetInfo("gmod_toolmode") ~= "zcity_zscav_extract" then return end

        local extracts = ZScavExtracts.GetExtracts and ZScavExtracts.GetExtracts() or {}
        for index, extract in ipairs(extracts) do
            drawExtractMarker(extract, index)
        end
    end)

    function TOOL.BuildCPanel(panel)
        panel:Help("Named raid extracts. Link them to spawn groups with comma-separated refs like G1,G3 or plain numbers like 1,3.")

        local nameEntry = panel:TextEntry("Extract Name", "zcity_zscav_extract_name")
        if IsValid(nameEntry) and nameEntry.SetTooltip then
            nameEntry:SetTooltip("Displayed to players when this extract is assigned.")
        end

        local durationSlider = panel:NumSlider("Extract Time (seconds)", "zcity_zscav_extract_duration", 1, 60, 0)
        if IsValid(durationSlider) and durationSlider.SetTooltip then
            durationSlider:SetTooltip("How long a player must stay inside this extract before leaving the raid.")
        end

        local groupEntry = panel:TextEntry("Spawn Group Links", "zcity_zscav_extract_groups")
        if IsValid(groupEntry) and groupEntry.SetTooltip then
            groupEntry:SetTooltip("Comma-separated spawn group refs like G1,G2 or saved ids. Leave blank to allow any spawn group.")
        end

        panel:Help("Left click adds or updates the nearest named extract. Right click removes the nearest named extract. Leave links blank for a global extract.")

        local groupSummary = vgui.Create("DLabel")
        groupSummary:SetWrap(true)
        groupSummary:SetAutoStretchVertical(true)
        groupSummary:SetTextColor(color_white)
        groupSummary:SetFont("DermaDefault")
        groupSummary:SetWide(240)
        panel:AddItem(groupSummary)

        local hookID = "ZScavExtractTool_GroupSummary_" .. tostring(panel)
        local function rebuildGroupSummary()
            local groups = ZScavSpawnPoints and ZScavSpawnPoints.GetGroups and ZScavSpawnPoints.GetGroups() or {}
            local lines = {}

            if #groups <= 0 then
                lines[1] = "Current map spawn groups: none. Place spawn groups first with the ZScav Spawn Point Tool."
            else
                lines[1] = "Current map spawn groups:"
                for index, group in ipairs(groups) do
                    lines[#lines + 1] = string.format("%s  (%d slots, %du radius)",
                        (ZScavSpawnPoints.GetGroupLabel and ZScavSpawnPoints.GetGroupLabel(group, index)) or ("G" .. tostring(index)),
                        math.max(math.floor(tonumber(group.count) or 0), 0),
                        math.max(math.floor(tonumber(group.radius) or 0), 0))
                end
            end

            groupSummary:SetText(table.concat(lines, "\n"))
            groupSummary:SizeToContentsY()
            if IsValid(panel) and panel.InvalidateLayout then
                panel:InvalidateLayout(true)
            end
        end

        rebuildGroupSummary()
        hook.Add("ZScavSpawnPoints_ClientUpdated", hookID, rebuildGroupSummary)

        local oldOnRemove = panel.OnRemove
        panel.OnRemove = function(self)
            hook.Remove("ZScavSpawnPoints_ClientUpdated", hookID)
            if isfunction(oldOnRemove) then
                oldOnRemove(self)
            end
        end
    end
end