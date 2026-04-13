-- cl_dod_classes.lua — DoD class picker panel (loads on demand)

if SERVER then return end

-- ── Fonts ─────────────────────────────────────────────────────────────────────

surface.CreateFont("DOD_ClassTitle",  { font = "Roboto", size = 20, weight = 700 })
surface.CreateFont("DOD_ClassBody",   { font = "Roboto", size = 14, weight = 400 })
surface.CreateFont("DOD_ClassSmall",  { font = "Roboto", size = 12, weight = 400 })
surface.CreateFont("DOD_ClassHeader", { font = "Roboto", size = 16, weight = 600 })

-- ── Colors ────────────────────────────────────────────────────────────────────

local CLR_BG       = Color(20,  22,  28,  240)
local CLR_HEADER   = Color(30,  34,  42,  255)
local CLR_ROW      = Color(35,  38,  48,  255)
local CLR_ROW_HOV  = Color(50,  55,  68,  255)
local CLR_SEL      = Color(60,  100, 160, 255)
local CLR_SEL_HOV  = Color(75,  120, 185, 255)
local CLR_CONFIRM  = Color(55,  140, 75,  255)
local CLR_CONF_HOV = Color(70,  165, 90,  255)
local CLR_FULL     = Color(160, 55,  55,  255)
local CLR_TEXT     = Color(220, 220, 220, 255)
local CLR_MUTED    = Color(140, 140, 150, 255)
local CLR_AXIS     = Color(180, 60,  60,  255)
local CLR_ALLIES   = Color(60,  100, 180, 255)
local CLR_BORDER   = Color(60,  65,  80,  255)

-- ── State ─────────────────────────────────────────────────────────────────────

local classState   = {}
local selectedId   = nil
local confirmedId  = nil

-- ── Panel ─────────────────────────────────────────────────────────────────────

local picker = nil

local function ClosePicker()
    if IsValid(picker) then picker:Remove() end
    picker = nil
end

local function TeamColor(teamIdx)
    if teamIdx == 0 then return CLR_AXIS
    else return CLR_ALLIES end
end

local function BuildPicker()
    if IsValid(picker) then picker:Remove() end

    local myTeam = LocalPlayer():Team()
    local W, H   = 680, 480
    local sx      = (ScrW() - W) / 2
    local sy      = (ScrH() - H) / 2

    picker = vgui.Create("DPanel")
    picker:SetPos(sx, sy)
    picker:SetSize(W, H)
    picker:SetZPos(500)
    picker:MakePopup()
    picker:SetKeyboardInputEnabled(false)

    local dragging, dragX, dragY = false, 0, 0
    picker.OnMousePressed = function(self, mc)
        if mc ~= MOUSE_LEFT then return end
        local mx, my = gui.MousePos()
        local px, py = self:GetPos()
        if (my - py) < 36 then
            dragging = true
            dragX, dragY = mx - px, my - py
        end
    end
    picker.Think = function(self)
        if dragging then
            if not input.IsMouseDown(MOUSE_LEFT) then dragging = false return end
            local mx, my = gui.MousePos()
            self:SetPos(mx - dragX, my - dragY)
        end
    end

    picker.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, CLR_BG)
        draw.RoundedBoxEx(6, 0, 0, w, 36, CLR_HEADER, true, true, false, false)
        surface.SetDrawColor(CLR_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Select Class", "DOD_ClassTitle", 12, 18, CLR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local td = DOD_TEAM and DOD_TEAM[myTeam]
        if td then
            draw.SimpleText(td.name, "DOD_ClassHeader", w - 12, 18, TeamColor(myTeam), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    local closeBtn = vgui.Create("DButton", picker)
    closeBtn:SetPos(W - 32, 4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetText("✕")
    closeBtn:SetFont("DOD_ClassBody")
    closeBtn:SetTextColor(CLR_MUTED)
    closeBtn.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, Color(80, 40, 40, 200))
        end
    end
    closeBtn.DoClick = ClosePicker

    local LIST_W = 220
    local listY  = 44

    for i, cls in ipairs(DOD_CLASSES) do
        local ry  = listY + (i - 1) * 58
        local row = vgui.Create("DPanel", picker)
        row:SetPos(8, ry)
        row:SetSize(LIST_W, 54)

        local isSel      = selectedId  == cls.id
        local isConfirmed = confirmedId == cls.id
        local counts     = classState[cls.id]
        local myCount    = counts and (counts[tostring(myTeam)] or counts[myTeam]) or 0
        local isFull     = cls.maxPerTeam and myCount >= cls.maxPerTeam and not isConfirmed

        row.Paint = function(self, w, h)
            local hov = self:IsHovered()
            local bg  = isFull and CLR_FULL
                or (isSel and (hov and CLR_SEL_HOV or CLR_SEL))
                or (hov and CLR_ROW_HOV or CLR_ROW)
            draw.RoundedBox(4, 0, 0, w, h, bg)
            if isConfirmed then
                surface.SetDrawColor(Color(80, 160, 80, 200))
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end
        end

        row.OnMousePressed = function(self, mc)
            if mc ~= MOUSE_LEFT then return end
            if isFull then return end
            selectedId = cls.id
            BuildPicker()
        end
        row:SetCursor("hand")

        local nameLabel = vgui.Create("DLabel", row)
        nameLabel:SetPos(8, 6)
        nameLabel:SetSize(LIST_W - 16, 20)
        nameLabel:SetText(cls.name .. (isConfirmed and "  ✓" or ""))
        nameLabel:SetFont("DOD_ClassHeader")
        nameLabel:SetTextColor(isFull and Color(200, 130, 130) or CLR_TEXT)

        local capStr
        if cls.maxPerTeam then
            capStr = myCount .. "/" .. cls.maxPerTeam .. " on team"
        else
            capStr = myCount .. " on team"
        end
        local countLabel = vgui.Create("DLabel", row)
        countLabel:SetPos(8, 28)
        countLabel:SetSize(LIST_W - 16, 16)
        countLabel:SetText(capStr)
        countLabel:SetFont("DOD_ClassSmall")
        countLabel:SetTextColor(isFull and Color(200, 130, 130) or CLR_MUTED)
    end

    local DX = LIST_W + 16
    local DW = W - DX - 8

    local detailPanel = vgui.Create("DPanel", picker)
    detailPanel:SetPos(DX, 44)
    detailPanel:SetSize(DW, H - 52)
    detailPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, CLR_ROW)
        surface.SetDrawColor(CLR_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local cls = selectedId and DOD_CLASS_BY_ID[selectedId]
    if not cls then cls = DOD_CLASSES[1] end

    if cls then
        local nameL = vgui.Create("DLabel", detailPanel)
        nameL:SetPos(12, 12)
        nameL:SetSize(DW - 24, 24)
        nameL:SetText(cls.name)
        nameL:SetFont("DOD_ClassTitle")
        nameL:SetTextColor(CLR_TEXT)

        local descL = vgui.Create("DLabel", detailPanel)
        descL:SetPos(12, 42)
        descL:SetSize(DW - 24, 50)
        descL:SetText(cls.desc)
        descL:SetFont("DOD_ClassBody")
        descL:SetTextColor(CLR_MUTED)
        descL:SetWrap(true)
        descL:SetAutoStretchVertical(true)

        local wepHeader = vgui.Create("DLabel", detailPanel)
        wepHeader:SetPos(12, 100)
        wepHeader:SetSize(DW - 24, 18)
        wepHeader:SetText("Loadout:")
        wepHeader:SetFont("DOD_ClassHeader")
        wepHeader:SetTextColor(CLR_TEXT)

        local wepList = cls.weapons[myTeam] or cls.weapons[0] or {}
        local wy = 122
        for _, wclass in ipairs(wepList) do
            local wl = vgui.Create("DLabel", detailPanel)
            wl:SetPos(20, wy)
            wl:SetSize(DW - 32, 16)
            wl:SetText("• " .. wclass)
            wl:SetFont("DOD_ClassSmall")
            wl:SetTextColor(CLR_MUTED)
            wy = wy + 18
        end

        if cls.armor and #cls.armor > 0 then
            local aHeader = vgui.Create("DLabel", detailPanel)
            aHeader:SetPos(12, wy + 4)
            aHeader:SetSize(DW - 24, 18)
            aHeader:SetText("Armor:")
            aHeader:SetFont("DOD_ClassHeader")
            aHeader:SetTextColor(CLR_TEXT)
            wy = wy + 26

            local al = vgui.Create("DLabel", detailPanel)
            al:SetPos(20, wy)
            al:SetSize(DW - 32, 16)
            al:SetText("• " .. table.concat(cls.armor, ", "))
            al:SetFont("DOD_ClassSmall")
            al:SetTextColor(CLR_MUTED)
            wy = wy + 18
        end

        if cls.maxPerTeam then
            local capNote = vgui.Create("DLabel", detailPanel)
            capNote:SetPos(12, wy + 8)
            capNote:SetSize(DW - 24, 16)
            capNote:SetText("⚠ Max " .. cls.maxPerTeam .. " per team")
            capNote:SetFont("DOD_ClassSmall")
            capNote:SetTextColor(Color(220, 180, 80))
        end

        local counts   = classState[cls.id]
        local myCount2 = counts and (counts[tostring(myTeam)] or counts[myTeam]) or 0
        local isFull2  = cls.maxPerTeam and myCount2 >= cls.maxPerTeam and confirmedId ~= cls.id

        local confirmBtn = vgui.Create("DButton", detailPanel)
        confirmBtn:SetPos(12, detailPanel:GetTall() - 48)
        confirmBtn:SetSize(DW - 24, 36)
        confirmBtn:SetText(isFull2 and "Class Full" or "Select " .. cls.name)
        confirmBtn:SetFont("DOD_ClassHeader")
        confirmBtn:SetTextColor(color_white)
        confirmBtn:SetEnabled(not isFull2)
        confirmBtn.Paint = function(self, w, h)
            local clr = isFull2 and CLR_FULL
                or (self:IsHovered() and CLR_CONF_HOV or CLR_CONFIRM)
            draw.RoundedBox(4, 0, 0, w, h, clr)
        end
        confirmBtn.DoClick = function()
            if isFull2 then return end
            local chosen = selectedId or cls.id
            net.Start("DOD_SelectClass")
                net.WriteString(chosen)
            net.SendToServer()
            confirmedId = chosen
            LocalPlayer():ChatPrint("[DoD] Class set to " .. (DOD_CLASS_BY_ID[chosen] and DOD_CLASS_BY_ID[chosen].name or chosen) .. ".")
            ClosePicker()
        end
    end
end

net.Receive("DOD_ClassState", function()
    classState  = net.ReadTable()
    confirmedId = net.ReadString()
    selectedId  = confirmedId
end)

net.Receive("DOD_OpenClassPicker", function()
    BuildPicker()
end)

hook.Add("PlayerButtonDown", "DOD_ClassPickerKey", function(ply, btn)
    if ply ~= LocalPlayer() then return end
    if btn ~= KEY_C then return end
    if not (zb and zb.CROUND == "dod") then return end
    if IsValid(picker) then ClosePicker() return end
    net.Start("DOD_SelectClass")
        net.WriteString("__request_state__")
    net.SendToServer()
end)

hook.Add("InitPostEntity", "DOD_ClassPickerCleanup", function()
    confirmedId = nil
    selectedId  = nil
    classState  = {}
end)

print("[DoD] Client class picker loaded")
