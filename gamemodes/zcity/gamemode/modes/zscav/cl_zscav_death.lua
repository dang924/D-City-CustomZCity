if SERVER then return end

local deathOverlayFrame
local deathSummary = {
    attacker = "",
    cause = "",
    recovery = "",
}
local deathFadeInDuration = 0.45

local function GetHUDScale()
    local sw, sh = ScrW(), ScrH()
    return math.Clamp(math.min(sw / 1920, sh / 1080), 0.9, 1.4)
end

local function RebuildDeathFonts()
    local scale = GetHUDScale()
    local function size(value)
        return math.max(12, math.floor(value * scale + 0.5))
    end

    surface.CreateFont("ZScavDeathTitle", {
        font = "Roboto",
        size = size(34),
        weight = 900,
    })

    surface.CreateFont("ZScavDeathSubtitle", {
        font = "Roboto",
        size = size(19),
        weight = 500,
    })

    surface.CreateFont("ZScavDeathLabel", {
        font = "Roboto",
        size = size(16),
        weight = 800,
    })

    surface.CreateFont("ZScavDeathBody", {
        font = "Roboto",
        size = size(16),
        weight = 500,
    })

    surface.CreateFont("ZScavDeathButton", {
        font = "Roboto",
        size = size(16),
        weight = 800,
    })
end

RebuildDeathFonts()

hook.Add("OnScreenSizeChanged", "ZScavDeath_Fonts", function()
    RebuildDeathFonts()
end)

local function CloseDeathOverlay()
    if IsValid(deathOverlayFrame) then
        deathOverlayFrame:Remove()
    end
    deathOverlayFrame = nil
end

local function CreateWrappedLabel(parent, text, font, color, x, y, width)
    local label = parent:Add("DLabel")
    label:SetFont(font)
    label:SetTextColor(color)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:SetText(text)
    label:SetPos(x, y)
    label:SetWide(math.max(width, 1))
    label:SizeToContentsY()
    return label
end

local function CreateHeaderLabel(parent, text, y)
    local label = parent:Add("DLabel")
    label:SetFont("ZScavDeathLabel")
    label:SetTextColor(Color(148, 154, 165))
    label:SetText(text)
    label:SetPos(24, y)
    label:SizeToContents()
    return label
end

local function CreateDetailLabel(parent, text, y, width)
    return CreateWrappedLabel(parent, text, "ZScavDeathBody", Color(230, 230, 232), 24, y, width or (parent:GetWide() - 48))
end

local function OpenDeathOverlay(showDetails)
    CloseDeathOverlay()

    local sw, sh = ScrW(), ScrH()
    local frame = vgui.Create("DFrame")
    frame:SetSize(sw, sh)
    frame:SetPos(0, 0)
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetSizable(false)
    frame:SetDeleteOnClose(true)
    frame:SetBackgroundBlur(false)
    frame:SetMouseInputEnabled(showDetails == true)
    if showDetails == true then
        frame:MakePopup()
    end
    frame:SetKeyboardInputEnabled(false)
    frame.OpenedAt = CurTime()
    frame.Paint = function(self, width, height)
        local fadeFrac = math.Clamp((CurTime() - self.OpenedAt) / math.max(deathFadeInDuration, 0.01), 0, 1)
        surface.SetDrawColor(0, 0, 0, math.floor(245 * fadeFrac))
        surface.DrawRect(0, 0, width, height)
    end
    deathOverlayFrame = frame

    if showDetails ~= true then
        return
    end

    local panelW = math.Clamp(sw * 0.34, 520, 660)
    local panelMinH = math.Clamp(sh * 0.34, 280, 360)
    local card = frame:Add("DPanel")
    card:SetSize(panelW, panelMinH)
    card:Center()
    card.Paint = function(_, width, height)
        draw.RoundedBox(10, 0, 0, width, height, Color(17, 21, 28, 240))
        surface.SetDrawColor(60, 66, 78, 255)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
    end

    local bodyX = 24
    local bodyY = 20
    local bodyW = panelW - 48
    local sectionGap = 14
    local lineGap = 6

    local title = card:Add("DLabel")
    title:SetFont("ZScavDeathTitle")
    title:SetTextColor(Color(236, 212, 153))
    title:SetText("You Died")
    title:SetPos(bodyX, bodyY)
    title:SizeToContents()

    local subtitle = CreateWrappedLabel(
        card,
        "Raid failed. Return to lobby when ready.",
        "ZScavDeathSubtitle",
        Color(194, 198, 205),
        bodyX,
        title:GetY() + title:GetTall() + lineGap,
        bodyW
    )

    local attackerHeader = CreateHeaderLabel(card, "KILLED BY", subtitle:GetY() + subtitle:GetTall() + 20)

    local attackerLine = CreateDetailLabel(card, deathSummary.attacker ~= "" and deathSummary.attacker or "Unknown", attackerHeader:GetY() + attackerHeader:GetTall() + lineGap, bodyW)

    local causeHeader = CreateHeaderLabel(card, "CAUSE", attackerLine:GetY() + attackerLine:GetTall() + sectionGap)

    local causeLine = CreateDetailLabel(card, deathSummary.cause ~= "" and deathSummary.cause or "Unknown", causeHeader:GetY() + causeHeader:GetTall() + lineGap, bodyW)

    local recoveryHeader = CreateHeaderLabel(card, "RECOVERY", causeLine:GetY() + causeLine:GetTall() + sectionGap)

    local recoveryLine = CreateDetailLabel(card, deathSummary.recovery ~= "" and deathSummary.recovery or "Return to lobby to respawn at safe spawn.", recoveryHeader:GetY() + recoveryHeader:GetTall() + lineGap, bodyW)

    local button = card:Add("DButton")
    button:SetSize(190, 40)

    local contentBottom = recoveryLine:GetY() + recoveryLine:GetTall()
    local panelH = math.max(panelMinH, contentBottom + 86)
    card:SetTall(panelH)
    card:Center()
    button:SetPos(panelW - 214, panelH - 62)
    button:SetText("")
    button.Busy = false
    button.Paint = function(self, width, height)
        local color = self.Busy and Color(78, 84, 94, 255)
            or (self:IsHovered() and Color(94, 119, 86, 255) or Color(71, 97, 63, 255))
        draw.RoundedBox(8, 0, 0, width, height, color)
        draw.SimpleText(self.Busy and "RETURNING..." or "RETURN TO LOBBY", "ZScavDeathButton", width - 18, height * 0.5, Color(245, 245, 245), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    button.DoClick = function(self)
        if self.Busy then return end
        self.Busy = true
        net.Start("ZScavDeathReturnLobby")
        net.SendToServer()
    end
end

net.Receive("ZScavDeathOpen", function()
    deathSummary.attacker = net.ReadString()
    deathSummary.cause = net.ReadString()
    deathSummary.recovery = net.ReadString()
    deathFadeInDuration = 0.45
    OpenDeathOverlay(true)
end)

net.Receive("ZScavDeathFade", function()
    deathFadeInDuration = math.max(net.ReadFloat(), 0.01)
    OpenDeathOverlay(false)
end)

net.Receive("ZScavDeathClose", function()
    CloseDeathOverlay()
end)

hook.Add("Think", "ZScavDeath_CloseOnRespawn", function()
    if not IsValid(deathOverlayFrame) then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:Alive() then
        CloseDeathOverlay()
    end
end)