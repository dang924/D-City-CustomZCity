-- ZScav Bodycam System - client consent popup + remembered choice.
-- Default behavior: closing the popup or letting it time out = DENY.

local BC = ZSCAV.Bodycam

local COOKIE_REMEMBER = "zscav_bodycam_remember"  -- "1" if we should auto-reply
local COOKIE_CHOICE   = "zscav_bodycam_choice"    -- "1" allow, "0" deny

local function readRememberedChoice()
    if cookie.GetString(COOKIE_REMEMBER, "0") ~= "1" then return nil end
    return cookie.GetString(COOKIE_CHOICE, "0") == "1"
end

local function setRememberedChoice(allow)
    cookie.Set(COOKIE_REMEMBER, "1")
    cookie.Set(COOKIE_CHOICE, allow and "1" or "0")
end

local function reply(allow)
    net.Start("ZScav_Bodycam_ConsentReply")
    net.WriteBool(allow == true)
    net.SendToServer()
end

-- ----- Popup -----
local function buildPopup()
    if IsValid(BC._popup) then BC._popup:Remove() end

    local frame = vgui.Create("DFrame")
    frame:SetSize(380, 240)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(true)
    frame:MakePopup()

    frame.replied = false

    local function answer(allow, remember)
        if frame.replied then return end
        frame.replied = true
        if remember then setRememberedChoice(allow) end
        reply(allow)
        frame:Close()
    end

    frame.OnClose = function()
        if frame.replied then return end
        frame.replied = true
        reply(false)
    end

    frame.Paint = function(_, w, h)
        surface.SetDrawColor(26, 31, 43, 250)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(58, 63, 75)
        surface.DrawOutlinedRect(0, 0, w, h)

        -- Header
        surface.SetDrawColor(220, 38, 38)
        surface.DrawRect(20, 22, 8, 8)
        draw.SimpleText("BODYCAM CONSENT", "DermaDefaultBold", 36, 18, color_white)
        surface.SetDrawColor(42, 47, 59)
        surface.DrawRect(0, 44, w, 1)
    end

    -- Body
    local body = vgui.Create("DLabel", frame)
    body:SetPos(20, 56)
    body:SetSize(340, 70)
    body:SetWrap(true)
    body:SetTextColor(Color(209, 213, 219))
    body:SetFont("DermaDefault")
    body:SetText("Allow your bodycam feed (voice and weapon sounds, with static effects) to be broadcast to safe zone monitors this raid?\n\nSpectators and dead players will be able to hear you.")

    -- Remember checkbox
    local cbWrap = vgui.Create("DPanel", frame)
    cbWrap:SetPos(20, 138)
    cbWrap:SetSize(340, 20)
    cbWrap.Paint = function() end

    local cb = vgui.Create("DCheckBoxLabel", cbWrap)
    cb:SetPos(0, 0)
    cb:SetText("Remember my choice")
    cb:SetTextColor(Color(156, 163, 175))
    cb:SetValue(false)
    cb:SizeToContents()

    -- Buttons
    local denyBtn = vgui.Create("DButton", frame)
    denyBtn:SetText("DENY")
    denyBtn:SetPos(20, 170)
    denyBtn:SetSize(165, 32)
    denyBtn.DoClick = function() answer(false, cb:GetChecked()) end

    local allowBtn = vgui.Create("DButton", frame)
    allowBtn:SetText("ALLOW THIS RAID")
    allowBtn:SetPos(195, 170)
    allowBtn:SetSize(165, 32)
    allowBtn.DoClick = function() answer(true, cb:GetChecked()) end
    allowBtn.Paint = function(s, w, h)
        local col = s:IsHovered() and Color(124, 58, 237) or Color(109, 40, 217)
        surface.SetDrawColor(col)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText(s:GetText() or "", "DermaDefaultBold", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    allowBtn:SetText("ALLOW THIS RAID")  -- ensure GetText returns it after Paint override

    -- Footer
    local foot = vgui.Create("DLabel", frame)
    foot:SetPos(20, 210)
    foot:SetSize(340, 14)
    foot:SetTextColor(Color(107, 114, 128))
    foot:SetText("Closing or no response = DENY (default)")
    foot:SetContentAlignment(5)

    BC._popup = frame
    return frame
end

-- ----- Net handlers -----
net.Receive("ZScav_Bodycam_RequestConsent", function()
    local remembered = readRememberedChoice()
    if remembered ~= nil then
        reply(remembered)
        return
    end
    buildPopup()
end)

net.Receive("ZScav_Bodycam_HUDState", function()
    BC._localRecording = net.ReadBool()
end)

-- ----- Console for the inventory button to call -----
function BC:LocalSetConsent(allow)
    setRememberedChoice(allow)
    net.Start("ZScav_Bodycam_ToggleConsent")
    net.WriteBool(allow and true or false)
    net.SendToServer()
end

function BC:LocalGetConsent()
    return readRememberedChoice() == true
end

function BC:LocalIsRecording()
    return self._localRecording == true
end

-- ----- "REC" indicator HUD -----
hook.Add("HUDPaint", "ZScav_Bodycam_RecHUD", function()
    if not BC:LocalIsRecording() then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end

    local sw, sh = ScrW(), ScrH()
    local x, y = sw - 130, 20
    local pulse = (math.sin(CurTime() * 4) + 1) * 0.5
    local alpha = math.floor(180 + 60 * pulse)
    surface.SetDrawColor(220, 38, 38, alpha)
    surface.DrawRect(x, y + 4, 10, 10)
    draw.SimpleText("REC", "DermaDefaultBold", x + 18, y, Color(255, 255, 255, alpha))
    draw.SimpleText("BODYCAM", "DermaDefault", x + 18, y + 14, Color(180, 180, 180, alpha))
end)
