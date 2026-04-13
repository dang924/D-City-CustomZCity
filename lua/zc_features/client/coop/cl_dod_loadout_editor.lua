-- cl_dod_loadout_editor.lua — Admin editor for DoD class loadouts.

if SERVER then return end

local COL_BG         = Color(18, 20, 26)
local COL_PANEL      = Color(26, 29, 38)
local COL_PANEL_DARK = Color(14, 16, 22)
local COL_BORDER     = Color(45, 50, 65)
local COL_ACCENT     = Color(80, 160, 255)
local COL_ACCENT_DIM = Color(40, 80, 140)
local COL_DANGER     = Color(200, 60, 60)
local COL_WARN       = Color(200, 140, 40)
local COL_SUCCESS    = Color(60, 180, 80)
local COL_TEXT       = Color(220, 225, 235)
local COL_TEXT_DIM   = Color(120, 130, 150)
local COL_SEL        = Color(40, 80, 160, 180)
local COL_HOV        = Color(35, 40, 55)
local COL_AXIS       = Color(140, 60, 60)
local COL_ALLIES     = Color(60, 100, 160)

local FONT_TITLE = "DODLoadout_Title"
local FONT_LABEL = "DODLoadout_Label"
local FONT_SMALL = "DODLoadout_Small"
local FONT_MONO  = "DODLoadout_Mono"

surface.CreateFont(FONT_TITLE, { font = "Tahoma", size = 17, weight = 700 })
surface.CreateFont(FONT_LABEL, { font = "Tahoma", size = 13, weight = 600 })
surface.CreateFont(FONT_SMALL, { font = "Tahoma", size = 11, weight = 400 })
surface.CreateFont(FONT_MONO,  { font = "Courier New", size = 11, weight = 400 })

local PAD = 8
local BTN_H = 28

local loadoutData = {}
local editor = nil

local function MakeButton(parent, text, col, callback)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn._col = col or COL_ACCENT
    btn._text = text
    btn._hov = false
    btn.Paint = function(self, w, h)
        local c = self._hov and Color(math.min(self._col.r + 20, 255), math.min(self._col.g + 20, 255), math.min(self._col.b + 20, 255)) or self._col
        draw.RoundedBox(4, 0, 0, w, h, c)
        draw.SimpleText(self._text, FONT_LABEL, w / 2, h / 2, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.OnCursorEntered = function(self) self._hov = true end
    btn.OnCursorExited = function(self) self._hov = false end
    btn.DoClick = callback
    return btn
end

local function SendEdit(op, classId, teamIdx, arg)
    net.Start("DOD_LoadoutEditor_Edit")
        net.WriteString(op or "")
        net.WriteString(classId or "")
        net.WriteInt(teamIdx or -1, 3)
        net.WriteString(arg or "")
    net.SendToServer()
end

local PANEL = {}

function PANEL:Init()
    local W, H = 900, math.min(760, ScrH() - 60)
    self:SetSize(W, H)
    self:Center()
    self:MakePopup()
    self._selectedClass = nil
    self._teamIdx = 0

    local closeBtn = MakeButton(self, "X", COL_DANGER, function() self:SetVisible(false) end)
    closeBtn:SetSize(30, 30)
    closeBtn:SetPos(W - 36, 6)

    local leftW = 220
    self._left = vgui.Create("DPanel", self)
    self._left:SetPos(PAD, 44)
    self._left:SetSize(leftW, H - 52)
    self._left.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, COL_PANEL_DARK) end

    self._leftScroll = vgui.Create("DScrollPanel", self._left)
    self._leftScroll:SetPos(0, 24)
    self._leftScroll:SetSize(leftW, H - 76)
    self._classList = vgui.Create("DListLayout", self._leftScroll)
    self._classList:SetWide(leftW - 6)

    self._right = vgui.Create("DPanel", self)
    self._right:SetPos(leftW + PAD * 2, 44)
    self._right:SetSize(W - leftW - PAD * 3, H - 52)
    self._right.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, COL_PANEL) end

    self._title = vgui.Create("DLabel", self._right)
    self._title:SetPos(12, 10)
    self._title:SetSize(self._right:GetWide() - 24, 24)
    self._title:SetFont(FONT_TITLE)
    self._title:SetTextColor(COL_TEXT)

    self._desc = vgui.Create("DLabel", self._right)
    self._desc:SetPos(12, 36)
    self._desc:SetSize(self._right:GetWide() - 24, 36)
    self._desc:SetFont(FONT_SMALL)
    self._desc:SetTextColor(COL_TEXT_DIM)
    self._desc:SetWrap(true)
    self._desc:SetAutoStretchVertical(true)

    self._resetBtn = MakeButton(self._right, "Reset Class", COL_WARN, function()
        if not self._selectedClass then return end
        SendEdit("reset", self._selectedClass.id, -1, "")
    end)
    self._resetBtn:SetSize(110, 26)
    self._resetBtn:SetPos(self._right:GetWide() - 122, 10)

    self._axisBtn = MakeButton(self._right, "Axis", COL_AXIS, function()
        self._teamIdx = 0
        self:RefreshDetails()
    end)
    self._axisBtn:SetSize(90, 26)
    self._axisBtn:SetPos(12, 84)

    self._alliesBtn = MakeButton(self._right, "Allies", COL_ALLIES, function()
        self._teamIdx = 1
        self:RefreshDetails()
    end)
    self._alliesBtn:SetSize(90, 26)
    self._alliesBtn:SetPos(108, 84)

    local rightW = self._right:GetWide()

    self._weaponsLabel = vgui.Create("DLabel", self._right)
    self._weaponsLabel:SetPos(12, 122)
    self._weaponsLabel:SetSize(rightW - 24, 16)
    self._weaponsLabel:SetFont(FONT_SMALL)
    self._weaponsLabel:SetTextColor(COL_TEXT_DIM)
    self._weaponsLabel:SetText("WEAPONS")

    self._weaponScroll = vgui.Create("DScrollPanel", self._right)
    self._weaponScroll:SetPos(12, 142)
    self._weaponScroll:SetSize(rightW - 24, 180)
    self._weaponList = vgui.Create("DListLayout", self._weaponScroll)
    self._weaponList:SetWide(rightW - 34)

    self._weaponEntry = vgui.Create("DTextEntry", self._right)
    self._weaponEntry:SetPos(12, 328)
    self._weaponEntry:SetSize(rightW - 96, 26)
    self._weaponEntry:SetFont(FONT_MONO)
    self._weaponEntry:SetPlaceholderText("weapon_classname")
    self._weaponEntry:SetTextColor(COL_TEXT)
    self._weaponEntry.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, COL_PANEL_DARK)
        s:DrawTextEntryText(COL_TEXT, COL_ACCENT, COL_TEXT)
    end

    self._weaponAddBtn = MakeButton(self._right, "+", COL_SUCCESS, function()
        if not self._selectedClass then return end
        local text = string.Trim(self._weaponEntry:GetValue())
        if text == "" then return end
        SendEdit("addweapon", self._selectedClass.id, self._teamIdx, text)
        self._weaponEntry:SetValue("")
    end)
    self._weaponAddBtn:SetSize(70, 26)
    self._weaponAddBtn:SetPos(rightW - 82, 328)

    self._attLabel = vgui.Create("DLabel", self._right)
    self._attLabel:SetPos(12, 366)
    self._attLabel:SetSize(rightW - 24, 16)
    self._attLabel:SetFont(FONT_SMALL)
    self._attLabel:SetTextColor(COL_TEXT_DIM)
    self._attLabel:SetText("ATTACHMENTS")

    self._attScroll = vgui.Create("DScrollPanel", self._right)
    self._attScroll:SetPos(12, 386)
    self._attScroll:SetSize(rightW - 24, 120)
    self._attList = vgui.Create("DListLayout", self._attScroll)
    self._attList:SetWide(rightW - 34)

    self._attEntry = vgui.Create("DTextEntry", self._right)
    self._attEntry:SetPos(12, 512)
    self._attEntry:SetSize(rightW - 96, 26)
    self._attEntry:SetFont(FONT_MONO)
    self._attEntry:SetPlaceholderText("optic12 or ent_att_optic12")
    self._attEntry:SetTextColor(COL_TEXT)
    self._attEntry.Paint = self._weaponEntry.Paint

    self._attAddBtn = MakeButton(self._right, "+", COL_SUCCESS, function()
        if not self._selectedClass then return end
        local text = string.Trim(self._attEntry:GetValue())
        if text == "" then return end
        SendEdit("addattachment", self._selectedClass.id, self._teamIdx, text)
        self._attEntry:SetValue("")
    end)
    self._attAddBtn:SetSize(70, 26)
    self._attAddBtn:SetPos(rightW - 82, 512)

    self._armorLabel = vgui.Create("DLabel", self._right)
    self._armorLabel:SetPos(12, 550)
    self._armorLabel:SetSize(rightW - 24, 16)
    self._armorLabel:SetFont(FONT_SMALL)
    self._armorLabel:SetTextColor(COL_TEXT_DIM)
    self._armorLabel:SetText("ARMOR")

    self._armorScroll = vgui.Create("DScrollPanel", self._right)
    self._armorScroll:SetPos(12, 570)
    self._armorScroll:SetSize(rightW - 24, 92)
    self._armorList = vgui.Create("DListLayout", self._armorScroll)
    self._armorList:SetWide(rightW - 34)

    self._armorEntry = vgui.Create("DTextEntry", self._right)
    self._armorEntry:SetPos(12, 668)
    self._armorEntry:SetSize(rightW - 96, 26)
    self._armorEntry:SetFont(FONT_MONO)
    self._armorEntry:SetPlaceholderText("vest1, helmet1, etc")
    self._armorEntry:SetTextColor(COL_TEXT)
    self._armorEntry.Paint = self._weaponEntry.Paint

    self._armorAddBtn = MakeButton(self._right, "+", COL_SUCCESS, function()
        if not self._selectedClass then return end
        local text = string.Trim(self._armorEntry:GetValue())
        if text == "" then return end
        SendEdit("addarmor", self._selectedClass.id, -1, text)
        self._armorEntry:SetValue("")
    end)
    self._armorAddBtn:SetSize(70, 26)
    self._armorAddBtn:SetPos(rightW - 82, 668)

    self:RefreshClassList()
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, COL_BG)
    surface.SetDrawColor(COL_BORDER)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
    draw.RoundedBoxEx(6, 0, 0, w, 40, COL_PANEL_DARK, true, true, false, false)
    draw.SimpleText("DoD Loadout Editor", FONT_TITLE, 12, 20, COL_WARN, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function PANEL:RefreshClassList()
    if not IsValid(self._classList) then return end
    self._classList:Clear()

    if not self._selectedClass and loadoutData[1] then
        self._selectedClass = loadoutData[1]
    else
        for _, cls in ipairs(loadoutData) do
            if self._selectedClass and cls.id == self._selectedClass.id then
                self._selectedClass = cls
                break
            end
        end
    end

    for _, cls in ipairs(loadoutData) do
        local item = cls
        local row = vgui.Create("DButton", self._classList)
        row:SetSize(self._classList:GetWide(), 34)
        row:SetText("")
        row._hov = false
        row.Paint = function(_, w, h)
            local sel = self._selectedClass and self._selectedClass.id == item.id
            draw.RoundedBox(3, 1, 1, w - 2, h - 2, sel and COL_SEL or (row._hov and COL_HOV or Color(0, 0, 0, 0)))
            draw.SimpleText(item.name, FONT_LABEL, 8, h / 2, sel and COL_ACCENT or COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        row.OnCursorEntered = function() row._hov = true end
        row.OnCursorExited = function() row._hov = false end
        row.DoClick = function()
            self._selectedClass = item
            self:RefreshClassList()
            self:RefreshDetails()
        end
        self._classList:Add(row)
    end

    self:RefreshDetails()
end

function PANEL:RefreshSimpleList(listPanel, entries, removeCallback)
    listPanel:Clear()
    local rowW = listPanel:GetWide()

    if #entries == 0 then
        local empty = vgui.Create("DLabel", listPanel)
        empty:SetSize(rowW, 24)
        empty:SetFont(FONT_SMALL)
        empty:SetTextColor(COL_TEXT_DIM)
        empty:SetText("  (empty)")
        listPanel:Add(empty)
        return
    end

    for index, value in ipairs(entries) do
        local row = vgui.Create("DPanel", listPanel)
        row:SetSize(rowW, 28)
        row._hov = false
        row.Paint = function(_, w, h)
            if row._hov then draw.RoundedBox(3, 0, 0, w, h, COL_HOV) end
            draw.SimpleText(index .. ".  " .. value, FONT_MONO, 8, h / 2, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        row.OnCursorEntered = function() row._hov = true end
        row.OnCursorExited = function() row._hov = false end

        local delBtn = MakeButton(row, "X", COL_DANGER, function() removeCallback(index) end)
        delBtn:SetSize(24, 22)
        delBtn:SetPos(rowW - 28, 3)
        listPanel:Add(row)
    end
end

function PANEL:RefreshDetails()
    local cls = self._selectedClass
    if not cls then
        self._title:SetText("Select a class")
        self._desc:SetText("")
        return
    end

    self._title:SetText(cls.name .. (cls.maxPerTeam and ("  |  max " .. cls.maxPerTeam .. " per team") or ""))
    self._desc:SetText(cls.desc or "")

    self._axisBtn._col = self._teamIdx == 0 and COL_ACCENT or COL_AXIS
    self._alliesBtn._col = self._teamIdx == 1 and COL_ACCENT or COL_ALLIES

    self:RefreshSimpleList(self._weaponList, cls.weapons[self._teamIdx] or {}, function(index)
        SendEdit("removeweapon", cls.id, self._teamIdx, tostring(index))
    end)

    self:RefreshSimpleList(self._attList, cls.attachments[self._teamIdx] or {}, function(index)
        SendEdit("removeattachment", cls.id, self._teamIdx, tostring(index))
    end)

    self:RefreshSimpleList(self._armorList, cls.armor or {}, function(index)
        SendEdit("removearmor", cls.id, -1, tostring(index))
    end)
end

vgui.Register("DOD_LoadoutEditor", PANEL, "DPanel")

net.Receive("DOD_LoadoutEditor_List", function()
    loadoutData = {}

    local count = net.ReadUInt(8)
    for _ = 1, count do
        local cls = {
            id = net.ReadString(),
            name = net.ReadString(),
            desc = net.ReadString(),
            maxPerTeam = net.ReadUInt(8),
            weapons = { [0] = {}, [1] = {} },
            attachments = { [0] = {}, [1] = {} },
            armor = {},
        }

        for _, teamIdx in ipairs({ 0, 1 }) do
            local wcount = net.ReadUInt(8)
            for _i = 1, wcount do
                cls.weapons[teamIdx][#cls.weapons[teamIdx] + 1] = net.ReadString()
            end
        end

        for _, teamIdx in ipairs({ 0, 1 }) do
            local acount = net.ReadUInt(8)
            for _i = 1, acount do
                cls.attachments[teamIdx][#cls.attachments[teamIdx] + 1] = net.ReadString()
            end
        end

        local armorCount = net.ReadUInt(8)
        for _i = 1, armorCount do
            cls.armor[#cls.armor + 1] = net.ReadString()
        end

        loadoutData[#loadoutData + 1] = cls
    end

    if IsValid(editor) then
        editor:RefreshClassList()
    end
end)

net.Receive("DOD_LoadoutEditor_Open", function()
    if not IsValid(editor) then
        editor = vgui.Create("DOD_LoadoutEditor")
    else
        editor:SetVisible(true)
        editor:MakePopup()
        editor:RefreshClassList()
    end
end)

net.Receive("DOD_LoadoutEditor_Saved", function()
    if IsValid(editor) then
        editor:RefreshClassList()
    end
end)

print("[DoD] Client loadout editor loaded")