if SERVER then return end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool

TOOLMODULE.Menu = TOOLMODULE.Menu or {}

local Menu = TOOLMODULE.Menu

Menu.Actions = Menu.Actions or {}

function Menu.RegisterAction(id, definition)
    if not id or not istable(definition) then return end
    Menu.Actions[id] = definition
end

function Menu.GetActions()
    return Menu.Actions
end

function Menu.IsScaleToolsAvailable()
    return istable(hg.Appearance)
        and istable(hg.Appearance.Sliders)
        and isfunction(hg.Appearance.Sliders.AttachScaleBlock)
        and isfunction(hg.Appearance.Sliders.RefreshScaleBlock)
end

function Menu.IsCubAvailable()
    return istable(hg.Appearance)
        and isfunction(hg.Appearance.OpenClothesMenu)
        and isfunction(hg.Appearance.OpenFacemapMenu)
        and isfunction(hg.Appearance.OpenModelMenu)
end

function Menu.GetPreferredMode()
    return Menu.IsCubAvailable() and "cub" or "vanilla"
end

local function PaintDropdownButton(self, w, h)
    local bg = self:IsHovered() and Color(50, 50, 65, 240) or Color(35, 35, 45, 220)
    draw.RoundedBox(4, 0, 0, w, h, bg)
    surface.SetDrawColor(Color(100, 100, 120, 200))
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

function Menu.OpenActionsDropdown(panel, anchor, actionIDs)
    if not IsValid(panel) or not IsValid(anchor) then return nil end

    if IsValid(panel.AppearanceToolsMenu) then
        panel.AppearanceToolsMenu:Close()
    end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(math.floor(ScreenScale(70)), math.max(1, #actionIDs) * math.floor(ScreenScale(14)) + ScreenScale(4))
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()

    local ax, ay = anchor:LocalToScreen(0, anchor:GetTall())
    frame:SetPos(ax, ay + ScreenScale(2))

    function frame:Paint(w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(15, 15, 20, 250))
        surface.SetDrawColor(Color(100, 100, 120, 200))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local function IsPanelInside(panelToCheck)
        while IsValid(panelToCheck) do
            if panelToCheck == frame then return true end
            panelToCheck = panelToCheck:GetParent()
        end
        return false
    end

    function frame:OnFocusChanged(gained)
        if gained then return end
        timer.Simple(0, function()
            if not IsValid(self) then return end

            local focused = vgui.GetKeyboardFocus()
            local hovered = vgui.GetHoveredPanel()
            if IsPanelInside(focused) or IsPanelInside(hovered) then return end

            self:Close()
        end)
    end

    local y = ScreenScale(2)
    for _, id in ipairs(actionIDs or {}) do
        local definition = Menu.Actions[id]
        if not istable(definition) or not isfunction(definition.open) then continue end

        local button = vgui.Create("DButton", frame)
        button:SetText(definition.label or id)
        button:SetFont("ZCity_Tiny")
        button:SetTextColor(color_white)
        button:SetPos(ScreenScale(2), y)
        button:SetSize(frame:GetWide() - ScreenScale(4), ScreenScale(12))
        button.Paint = PaintDropdownButton

        function button:DoClick()
            definition.open(panel, anchor)
            frame:Close()
        end

        y = y + button:GetTall() + ScreenScale(2)
    end

    panel.AppearanceToolsMenu = frame
    return frame
end
