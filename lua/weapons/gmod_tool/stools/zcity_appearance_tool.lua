TOOL.Category = "ZCity"
TOOL.Name = "#tool.zcity_appearance_tool.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.Information = {
    { name = "left" },
    { name = "right" },
    { name = "reload" }
}

if CLIENT then
    language.Add("tool.zcity_appearance_tool.name", "ZCity Appearance Tool")
    language.Add("tool.zcity_appearance_tool.desc", "Temporarily applies a configured appearance to a selected player or supported ragdoll")
    language.Add("tool.zcity_appearance_tool.left", "Apply tool appearance to selected target")
    language.Add("tool.zcity_appearance_tool.right", "Select player or supported ragdoll under crosshair")
    language.Add("tool.zcity_appearance_tool.reload", "Select yourself")
    language.Add("tool.zcity_appearance_tool.open_config", "Open Appearance Configurator")
    language.Add("tool.zcity_appearance_tool.clear_target", "Clear Temporary Appearance")
end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool
local NET = TOOLMODULE.Net

function TOOL:RightClick(trace)
    if CLIENT then return true end

    local ent = trace.Entity
    if not TOOLMODULE.IsSupportedTarget(ent) then return false end

    TOOLMODULE.ToggleSelectedTarget(self:GetOwner(), ent)
    return true
end

function TOOL:Reload()
    if CLIENT then
        net.Start(NET.SelectSelf)
        net.SendToServer()
        return true
    end

    return true
end

function TOOL:LeftClick(trace)
    if CLIENT then
        net.Start(NET.ApplyAppearance)
            net.WriteTable(TOOLMODULE.GetClientConfig())
        net.SendToServer()
        return true
    end

    local owner = self:GetOwner()
    local selected = owner:GetNWEntity(TOOLMODULE.SelectionNWKey)
    if not TOOLMODULE.IsSupportedTarget(selected) and TOOLMODULE.IsSupportedTarget(trace.Entity) then
        TOOLMODULE.SetSelectedTarget(owner, trace.Entity)
    end

    local target = owner:GetNWEntity(TOOLMODULE.SelectionNWKey)
    if not TOOLMODULE.IsSupportedTarget(target) then return false end

    local appearance = TOOLMODULE.NormalizeAppearance(owner.HGAppearanceToolConfig or TOOLMODULE.GetDefaultAppearance())
    return TOOLMODULE.Runtime and TOOLMODULE.Runtime.ApplyOverlay(target, appearance, owner) or false
end

function TOOL.BuildCPanel(panel)
    panel:Help("#tool.zcity_appearance_tool.desc")

    if CLIENT then
        local statusLabel = vgui.Create("DLabel", panel)
        statusLabel:Dock(TOP)
        statusLabel:DockMargin(0, 0, 0, 6)
        statusLabel:SetFont("DermaDefaultBold")
        statusLabel:SetText("Selected: None")
        statusLabel:SetWrap(true)
        statusLabel:SetAutoStretchVertical(true)

        function statusLabel:Think()
            local lply = LocalPlayer()
            if not IsValid(lply) then
                self:SetText("Selected: None")
                return
            end

            local ent = lply:GetNWEntity(TOOLMODULE.SelectionNWKey)
            local text = "Selected: None"

            if IsValid(ent) then
                if ent == lply then
                    text = "Selected: You"
                elseif ent:IsPlayer() then
                    text = "Selected: Player"
                elseif ent:IsRagdoll() then
                    text = "Selected: Ragdoll"
                end
            end

            if self:GetText() ~= text then
                self:SetText(text)
                self:SizeToContentsY()
            end
        end
    end

    local configButton = panel:Button("#tool.zcity_appearance_tool.open_config")
    function configButton:DoClick()
        if not isfunction(TOOLMODULE.OpenConfigurator) then return end
        TOOLMODULE.OpenConfigurator()
    end

    local clearButton = panel:Button("#tool.zcity_appearance_tool.clear_target")
    function clearButton:DoClick()
        net.Start(NET.ClearAppearance)
        net.SendToServer()
    end
end
