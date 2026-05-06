local gradient = Material("vgui/gradient-d")
local PANEL = {}
function PANEL:Init()
    self.margin = Nexus:Scale(10)
    self.curBarPos = 0

    self.Buttons = {}
    self.ButtonDirect = {}

    self.lerp = 0
    self:SetTall(Nexus:Scale(50))

    self:DockPadding(self.margin, 0, 0, 0)
end

local col_zero = Color(0, 0, 0, 0)
function PANEL:AddItem(str, func, icon)
    func = func or function() end

    local white_col = Nexus:OffsetColor(Nexus.Colors.Header, 20)
    local font = Nexus:GetFont(25)

    local button = self:Add("Nexus:Button")
    button:Dock(TOP)
    button:DockMargin(0, self.margin, self.margin, 0)
    button:SetTall(Nexus:Scale(35))

    button.OnSelected = func
    button.str = str

    button.DoClick = function(s)
        func()
        self.Selected = str
    end

    button.Paint = function(s, w, h)
        local size = h*.7
        if s:IsHovered() or (self.Selected == str) then
            Nexus:DrawRoundedGradient(0, 0, w, w, col_zero, white_col, 0, -90)
        end

        if icon then
            Nexus:DrawImgur(icon, self.margin, (h/2) - (size/2), size, size, self.Selected == str and color_white or Nexus:OffsetColor(Nexus.Colors.Text, -100))
        end

        draw.SimpleText(str, Nexus:GetFont(25), icon and self.margin*2 + size or self.margin, h/2, s:IsHovered() and Nexus.Colors.Text or ((self.Selected == str) and Nexus.Colors.Text or Nexus:OffsetColor(Nexus.Colors.Text, -100)), 0, 1)
    end

    table.insert(self.Buttons, button)

    self.ButtonDirect[str] = #self.Buttons

    func()
    self.Selected = str
end

function PANEL:SelectItem(str)
    for _, v in ipairs(self.Buttons) do
        if str == v.str then
            self.Selected = str
            v.OnSelected()

            self.lerp = 0
            break
        end
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(self.margin, 0, 0, w, h, self.col)
end

function PANEL:PerformLayout(w, h) end
vgui.Register("Nexus:Sidebar", PANEL, "EditablePanel")