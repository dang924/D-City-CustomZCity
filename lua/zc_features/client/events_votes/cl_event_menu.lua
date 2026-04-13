-- cl_event_menu.lua — Client side of the Event Admin Menu
-- Opens a VGUI panel with a player list and action buttons.
-- Only renders for Admin+ players.

if SERVER then return end

-- ── Theme ─────────────────────────────────────────────────────────────────────

local COL_BG          = Color(18,  20,  26)
local COL_PANEL       = Color(26,  29,  38)
local COL_PANEL_DARK  = Color(14,  16,  22)
local COL_BORDER      = Color(45,  50,  65)
local COL_ACCENT      = Color(80,  160, 255)
local COL_ACCENT_DIM  = Color(40,  80,  140)
local COL_DANGER      = Color(200, 60,  60)
local COL_WARN        = Color(200, 140, 40)
local COL_SUCCESS     = Color(60,  180, 80)
local COL_TEXT        = Color(220, 225, 235)
local COL_TEXT_DIM    = Color(120, 130, 150)
local COL_SEL         = Color(40,  80,  160, 180)
local COL_HOV         = Color(35,  40,  55)

local FONT_TITLE  = "ZCEvent_Title"
local FONT_LABEL  = "ZCEvent_Label"
local FONT_SMALL  = "ZCEvent_Small"
local FONT_MONO   = "ZCEvent_Mono"

surface.CreateFont(FONT_TITLE, { font = "Tahoma", size = 17, weight = 700 })
surface.CreateFont(FONT_LABEL, { font = "Tahoma", size = 13, weight = 600 })
surface.CreateFont(FONT_SMALL, { font = "Tahoma", size = 11, weight = 400 })
surface.CreateFont(FONT_MONO,  { font = "Courier New", size = 11, weight = 400 })

-- ── State ─────────────────────────────────────────────────────────────────────

local playerData    = {}
local loadoutData   = {}
local selectedID    = nil
local feedback      = ""
local feedbackTimer = 0

local CLASS_OPTIONS = { "Rebel", "Refugee", "Gordon", "Combine", "Metrocop" }
local NEXT_EDITOR_REBEL_ONLY = false

local TEAM_COLORS = {
    Alpha   = Color(220, 60,  60),
    Bravo   = Color(60,  120, 220),
    Charlie = Color(60,  200, 60),
    Delta   = Color(220, 160, 0),
}

local eventRunning = false   -- kept for _UpdateEventButtons compat
local eventState   = 0       -- 0=standby, 1=prep, 2=live

local function IsRebelGroupName(group)
    local clean = string.lower(string.Trim(tostring(group or "")))
    if clean == "" then return true end -- universal preset
    if clean == "combine" then return false end
    if clean == "metrocop" then return false end
    if clean == "headcrabzombie" then return false end
    return true
end

local function GetEditorClassChoices(rebelOnly)
    local choices = {
        { label = "— Universal (all classes) —", value = "" }
    }

    for _, cls in ipairs(CLASS_OPTIONS) do
        if (not rebelOnly) or IsRebelGroupName(cls) then
            table.insert(choices, { label = cls, value = cls })
        end
    end

    return choices
end

net.Receive("ZC_EventMenu_EventState", function()
    eventState   = net.ReadUInt(2)
    eventRunning = (eventState == 2)
    if IsValid(ZC_EventMenuPanel) then
        ZC_EventMenuPanel:_UpdateEventButtons()
    end
end)

-- ── Net receives ──────────────────────────────────────────────────────────────

net.Receive("ZC_EventMenu_PlayerList", function()
    playerData = {}
    local count = net.ReadUInt(8)
    for i = 1, count do
        table.insert(playerData, {
            nick      = net.ReadString(),
            steamid   = net.ReadString(),
            class     = net.ReadString(),
            team      = net.ReadString(),
            alive     = net.ReadBool(),
            spectator = net.ReadBool(),
        })
    end
    local stillHere = false
    for _, p in ipairs(playerData) do if p.steamid == selectedID then stillHere = true break end end
    if not stillHere then selectedID = nil end
    if IsValid(ZC_EventMenuPanel) then ZC_EventMenuPanel:RebuildPlayerList() end
end)

net.Receive("ZC_EventMenu_LoadoutList", function()
    loadoutData = {}
    local count = net.ReadUInt(8)
    for i = 1, count do
        local name   = net.ReadString()
        local group  = net.ReadString()
        local wcount = net.ReadUInt(8)
        local weapons = {}
        for j = 1, wcount do
            local raw = net.ReadString()
            if string.sub(raw, 1, 8) == "$random:" then
                table.insert(weapons, { type = "random", choices = string.Explode(",", string.sub(raw, 9)) })
            else
                table.insert(weapons, { type = "weapon", class = raw })
            end
        end
        local armor = {}
        local SLOTS = { "torso", "head", "ears", "face" }
        for _, slot in ipairs(SLOTS) do
            local raw = net.ReadString()
            if raw ~= "" then
                if string.sub(raw, 1, 8) == "$random:" then
                    armor[slot] = { type = "random", choices = string.Explode(",", string.sub(raw, 9)) }
                else
                    armor[slot] = { type = "plain", key = raw }
                end
            end
        end
        table.insert(loadoutData, { name = name, group = group, weapons = weapons, armor = armor })
    end
    if IsValid(ZC_EventMenuPanel) then ZC_EventMenuPanel:_RebuildContent() end
end)

net.Receive("ZC_EventMenu_Feedback", function()
    feedback      = net.ReadString()
    feedbackTimer = CurTime() + 4
    if IsValid(ZC_EventMenuPanel) then ZC_EventMenuPanel:UpdateFeedback() end
end)

local function EnsureInteractivePopup(panel)
    if not IsValid(panel) then return end
    panel:SetVisible(true)
    panel:SetMouseInputEnabled(true)
    panel:SetKeyboardInputEnabled(true)
    panel:MakePopup()
end

net.Receive("ZC_EventMenu_Open", function()
    if not IsValid(ZC_EventMenuPanel) then
        ZC_EventMenuPanel = vgui.Create("ZC_EventMenu")
    end
    EnsureInteractivePopup(ZC_EventMenuPanel)
    -- No bounce back to server — data is pushed before this signal arrives
end)

local function OpenEventLoadoutEditor(rebelOnly)
    NEXT_EDITOR_REBEL_ONLY = rebelOnly == true

    if not IsValid(ZC_EventLoadoutEditor) then
        ZC_EventLoadoutEditor = vgui.Create("ZC_EventLoadoutEditor")
    else
        ZC_EventLoadoutEditor:SetRebelOnlyMode(NEXT_EDITOR_REBEL_ONLY)
        EnsureInteractivePopup(ZC_EventLoadoutEditor)
        ZC_EventLoadoutEditor:Refresh()
    end

    NEXT_EDITOR_REBEL_ONLY = false
end

net.Receive("ZC_EventMenu_OpenRebelLoadoutEditor", function()
    OpenEventLoadoutEditor(true)
end)

-- ── Senders ───────────────────────────────────────────────────────────────────

local function SendAction(action, steamid, arg)
    net.Start("ZC_EventMenu_Action")
        net.WriteString(action)
        net.WriteString(steamid or "")
        net.WriteString(arg or "")
    net.SendToServer()
end

local function Refresh() SendAction("refresh", "", "") end

net.Receive("ZC_EventMenu_ClassList", function()
    CLASS_OPTIONS = {}
    local count = net.ReadUInt(8)
    for i = 1, count do table.insert(CLASS_OPTIONS, net.ReadString()) end
    if IsValid(ZC_EventMenuPanel) then
        -- Rebuild the whole content area so class buttons, chips, and team combo all refresh
        ZC_EventMenuPanel:_RebuildContent()
    end
    if IsValid(ZC_EventLoadoutEditor) then ZC_EventLoadoutEditor:RefreshClassList() end
end)

local function SendClassEdit(op, arg)
    net.Start("ZC_EventMenu_ClassEdit")
        net.WriteString(op)
        net.WriteString(arg or "")
    net.SendToServer()
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function MakeButton(parent, text, col, callback)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn._col  = col or COL_ACCENT
    btn._text = text
    btn._hov  = false
    btn.Paint = function(self, w, h)
        local c = self._hov and Color(self._col.r+20, self._col.g+20, self._col.b+20) or self._col
        draw.RoundedBox(4, 0, 0, w, h, c)
        draw.SimpleText(self._text, FONT_LABEL, w/2, h/2, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.OnCursorEntered = function(self) self._hov = true  end
    btn.OnCursorExited  = function(self) self._hov = false end
    btn.DoClick = callback
    return btn
end

local function SectionHeader(parent, title, x, y, w)
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetPos(x, y); lbl:SetSize(w, 16)
    lbl:SetFont(FONT_SMALL); lbl:SetTextColor(COL_TEXT_DIM); lbl:SetText(title)
    local div = vgui.Create("DPanel", parent)
    div:SetPos(x, y+17); div:SetSize(w, 1)
    div.Paint = function(_, dw, dh) surface.SetDrawColor(COL_BORDER) surface.DrawRect(0,0,dw,dh) end
    return y + 22
end

-- ── Layout constants ──────────────────────────────────────────────────────────

local HDR_H      = 44
local PAD        = 8
local BTN_H      = 28
local ROW_GAP    = 5
local SEC_GAP    = 16

-- ── Main panel ────────────────────────────────────────────────────────────────

local PANEL = {}

function PANEL:Init()
    local sw, sh = ScrW(), ScrH()
    local W = math.max(1060, math.min(1300, math.floor(sw * 0.82)))
    local H = math.max(700,  math.min(880,  math.floor(sh * 0.80)))
    self:SetSize(W, H); self:Center()
    EnsureInteractivePopup(self)
    self._W = W; self._H = H
    self._drag = false  -- true while dragging

    self.OnKeyCodePressed = function(self, key)
        if key == KEY_ESCAPE then self:SetVisible(false) end
    end

    -- Capture drag start when mouse is pressed in the header zone
    -- (any unoccupied area of the top HDR_H pixels)
    self.OnMousePressed = function(self, mc)
        if mc ~= MOUSE_LEFT then return end
        local mx, my = self:CursorPos()
        if my > HDR_H then return end  -- below header — ignore
        self._drag  = true
        self._dragMX, self._dragMY = gui.MousePos()
        self._dragFX, self._dragFY = self:GetPos()
    end

    local bY = math.floor((HDR_H - 30) / 2)

    local closeBtn = MakeButton(self, "✕", COL_DANGER, function() self:SetVisible(false) end)
    closeBtn:SetSize(30, 30); closeBtn:SetPos(W - 36, bY)

    local refreshBtn = MakeButton(self, "↺ Refresh", COL_ACCENT_DIM, Refresh)
    refreshBtn:SetSize(90, 30); refreshBtn:SetPos(W - 132, bY)

    self._eventStartBtn = MakeButton(self, "▶ Event Start", COL_SUCCESS, function()
        Derma_Query("Start event? Godmode OFF, AI enabled.", "Confirm",
            "Start", function() SendAction("event_start","","") end, "Cancel", function() end)
    end)
    self._eventStartBtn:SetSize(120, 30); self._eventStartBtn:SetPos(W - 258, bY)

    self._eventStopBtn = MakeButton(self, "■ Event Stop", COL_DANGER, function()
        Derma_Query("Stop event? Godmode ON, AI disabled, server cleaned up.", "Confirm",
            "Stop", function() SendAction("event_stop","","") end, "Cancel", function() end)
    end)
    self._eventStopBtn:SetSize(112, 30); self._eventStopBtn:SetPos(W - 376, bY)

    self:_UpdateEventButtons()

    -- Left: player list
    local LEFT_W = 268
    local contY  = HDR_H + PAD
    local contH  = H - HDR_H - PAD * 2

    self._leftPanel = vgui.Create("DPanel", self)
    self._leftPanel:SetPos(PAD, contY); self._leftPanel:SetSize(LEFT_W, contH)
    self._leftPanel.Paint = function(_, w, h) draw.RoundedBox(4,0,0,w,h,COL_PANEL_DARK) end

    local plbl = vgui.Create("DLabel", self._leftPanel)
    plbl:SetPos(10,8); plbl:SetSize(LEFT_W-20,16)
    plbl:SetFont(FONT_SMALL); plbl:SetTextColor(COL_TEXT_DIM); plbl:SetText("PLAYERS")

    self._playerScroll = vgui.Create("DScrollPanel", self._leftPanel)
    self._playerScroll:SetPos(0,28); self._playerScroll:SetSize(LEFT_W, contH-28)
    local sb = self._playerScroll:GetVBar(); sb:SetWide(4)
    sb.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_BORDER) end
    sb.btnUp.Paint=function() end; sb.btnDown.Paint=function() end
    sb.btnGrip.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_ACCENT_DIM) end

    self._playerList = vgui.Create("DListLayout", self._playerScroll)
    self._playerList:SetWide(LEFT_W - 4)

    -- Right: scrollable content
    local rightX = PAD + LEFT_W + PAD
    local rightW = W - rightX - PAD
    local innerW = rightW - PAD * 2 - 8

    self._rightPanel = vgui.Create("DPanel", self)
    self._rightPanel:SetPos(rightX, contY); self._rightPanel:SetSize(rightW, contH)
    self._rightPanel.Paint = function(_,w,h) draw.RoundedBox(4,0,0,w,h,COL_PANEL) end

    self._targetLabel = vgui.Create("DLabel", self._rightPanel)
    self._targetLabel:SetPos(PAD,8); self._targetLabel:SetSize(rightW-PAD*2,22)
    self._targetLabel:SetFont(FONT_LABEL); self._targetLabel:SetTextColor(COL_ACCENT)
    self._targetLabel:SetText("Target: All Players")

    self._feedbackLabel = vgui.Create("DLabel", self._rightPanel)
    self._feedbackLabel:SetPos(PAD, contH-20); self._feedbackLabel:SetSize(rightW-PAD*2,16)
    self._feedbackLabel:SetFont(FONT_SMALL); self._feedbackLabel:SetTextColor(COL_SUCCESS)
    self._feedbackLabel:SetText("")

    local scrollY = 34
    local scrollH = contH - scrollY - 24

    self._contentScroll = vgui.Create("DScrollPanel", self._rightPanel)
    self._contentScroll:SetPos(0, scrollY); self._contentScroll:SetSize(rightW, scrollH)
    local sb2 = self._contentScroll:GetVBar(); sb2:SetWide(4)
    sb2.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_BORDER) end
    sb2.btnUp.Paint=function() end; sb2.btnDown.Paint=function() end
    sb2.btnGrip.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_ACCENT_DIM) end

    self._content = vgui.Create("DPanel", self._contentScroll)
    self._content:SetWide(rightW - 8)
    self._content.Paint = function() end
    self._innerW = innerW

    self:_RebuildContent()
    self:RebuildPlayerList()
end

function PANEL:_RebuildContent()
    if not IsValid(self._content) then return end
    self._content:Clear()
    local parent = self._content
    local innerW = self._innerW or 700
    local y = PAD

    local function Sec(title)
        y = SectionHeader(parent, title, PAD, y, innerW)
    end

    -- CLASS ASSIGNMENT
    Sec("CLASS ASSIGNMENT")
    self._classContainer = vgui.Create("DPanel", parent)
    self._classContainer:SetPos(PAD, y); self._classContainer:SetSize(innerW, BTN_H)
    self._classContainer.Paint = function() end
    self:_RebuildClassButtons()
    y = y + self._classContainer:GetTall() + SEC_GAP

    -- CLASS LIST (admin-editable inline)
    Sec("CLASS LIST  —  click × to remove")
    self._clsChipPanel = vgui.Create("DPanel", parent)
    self._clsChipPanel:SetPos(PAD, y); self._clsChipPanel:SetSize(innerW, 28)
    self._clsChipPanel.Paint = function() end
    self:_RebuildClassChips()
    y = y + self._clsChipPanel:GetTall() + ROW_GAP + 2

    local clsAddEntry = vgui.Create("DTextEntry", parent)
    clsAddEntry:SetPos(PAD, y); clsAddEntry:SetSize(innerW - 80, 26)
    clsAddEntry:SetFont(FONT_SMALL); clsAddEntry:SetPlaceholderText("Add class name…")
    clsAddEntry:SetTextColor(COL_TEXT)
    clsAddEntry.Paint=function(s,w,h) draw.RoundedBox(3,0,0,w,h,COL_PANEL_DARK) s:DrawTextEntryText(COL_TEXT,COL_ACCENT,COL_TEXT) end
    self._clsAddEntry = clsAddEntry

    local clsAddBtn = MakeButton(parent, "+ Add", COL_SUCCESS, function()
        local name = string.Trim(clsAddEntry:GetValue())
        if name == "" then return end
        SendClassEdit("add", name); clsAddEntry:SetValue("")
    end)
    clsAddBtn:SetSize(72, 26); clsAddBtn:SetPos(PAD + innerW - 72, y)
    y = y + 26 + SEC_GAP

    -- LOADOUT PRESETS
    Sec("LOADOUT PRESETS")
    self._loadoutContainer = vgui.Create("DPanel", parent)
    self._loadoutContainer:SetPos(PAD, y); self._loadoutContainer:SetSize(innerW, BTN_H)
    self._loadoutContainer.Paint = function() end
    self:RebuildLoadoutList()
    y = y + self._loadoutContainer:GetTall() + SEC_GAP

    -- TEAM TOOLS
    Sec("TEAM TOOLS")
    local lbl1 = vgui.Create("DLabel", parent)
    lbl1:SetPos(PAD,y+5); lbl1:SetSize(80,20); lbl1:SetFont(FONT_SMALL)
    lbl1:SetTextColor(COL_TEXT_DIM); lbl1:SetText("Split into:")
    local x = PAD + 86
    for n = 2, 4 do
        local nn = n
        local btn = MakeButton(parent, n.." Teams", COL_WARN, function()
            Derma_Query("Split all non-spectators into "..nn.." teams?","Confirm Split",
                "Split",function() SendAction("split","",tostring(nn)) end,"Cancel",function() end)
        end)
        btn:SetSize(96,BTN_H); btn:SetPos(x,y); x = x + 100
    end
    y = y + BTN_H + ROW_GAP + 4

    local lbl2 = vgui.Create("DLabel", parent)
    lbl2:SetPos(PAD,y+5); lbl2:SetSize(80,20); lbl2:SetFont(FONT_SMALL)
    lbl2:SetTextColor(COL_TEXT_DIM); lbl2:SetText("TP team to me:")
    local tx = PAD + 86
    for _, td in ipairs({{name="Alpha",col=TEAM_COLORS.Alpha},{name="Bravo",col=TEAM_COLORS.Bravo},{name="Charlie",col=TEAM_COLORS.Charlie},{name="Delta",col=TEAM_COLORS.Delta}}) do
        local tname,tcol = td.name, Color(td.col.r*0.5,td.col.g*0.5,td.col.b*0.5)
        local btn = MakeButton(parent, tname, tcol, function() SendAction("tpteam","",tname) end)
        btn:SetSize(88,BTN_H); btn:SetPos(tx,y); tx = tx + 92
    end
    y = y + BTN_H + ROW_GAP + 4

    local lbl3 = vgui.Create("DLabel", parent)
    lbl3:SetPos(PAD,y+5); lbl3:SetSize(80,20); lbl3:SetFont(FONT_SMALL)
    lbl3:SetTextColor(COL_TEXT_DIM); lbl3:SetText("Team class:")
    self._teamClassTeam  = "Alpha"
    self._teamClassClass = CLASS_OPTIONS[1] or ""

    local teamCombo = vgui.Create("DComboBox", parent)
    teamCombo:SetPos(PAD+86,y); teamCombo:SetSize(96,BTN_H); teamCombo:SetFont(FONT_SMALL)
    for _,t in ipairs({"Alpha","Bravo","Charlie","Delta"}) do teamCombo:AddChoice(t) end
    teamCombo:ChooseOptionID(1)
    teamCombo.OnSelect=function(_,_,val) self._teamClassTeam=val end

    self._teamClsCombo = vgui.Create("DComboBox", parent)
    self._teamClsCombo:SetPos(PAD+188,y); self._teamClsCombo:SetSize(114,BTN_H); self._teamClsCombo:SetFont(FONT_SMALL)
    for _,cls in ipairs(CLASS_OPTIONS) do self._teamClsCombo:AddChoice(cls) end
    if #CLASS_OPTIONS > 0 then self._teamClsCombo:ChooseOptionID(1) end
    self._teamClsCombo.OnSelect=function(_,_,val) self._teamClassClass=val end

    local applyBtn = MakeButton(parent,"Apply",COL_ACCENT,function()
        SendAction("setclass_team","",self._teamClassTeam.."|"..self._teamClassClass)
    end)
    applyBtn:SetSize(72,BTN_H); applyBtn:SetPos(PAD+308,y)
    y = y + BTN_H + SEC_GAP

    -- UTILITIES
    Sec("UTILITIES  —  applies to selected player, or all if none selected")

    local function util_btn(text, col, single, all)
        return MakeButton(parent, text, col, function()
            if selectedID then SendAction(single,selectedID,"")
            elseif all then
                Derma_Query(text.." for ALL players?","Confirm","Yes",function() SendAction(all,"","") end,"Cancel",function() end)
            end
        end)
    end

    local healBtn = util_btn("Heal",COL_SUCCESS,"healplayer","healall")
    healBtn:SetSize(110,BTN_H); healBtn:SetPos(PAD,y)

    local resetBtn = util_btn("Full Reset",COL_WARN,"resetplayer","resetall")
    resetBtn:SetSize(110,BTN_H); resetBtn:SetPos(PAD+114,y)

    local tpBtn = MakeButton(parent,"TP to Me",COL_ACCENT_DIM,function()
        if selectedID then SendAction("tphere",selectedID,"")
        else feedback="Select a player to teleport."; feedbackTimer=CurTime()+3; self:UpdateFeedback() end
    end)
    tpBtn:SetSize(110,BTN_H); tpBtn:SetPos(PAD+228,y)

    local frBtn = MakeButton(parent,"Force Respawn",Color(60,100,160),function()
        if selectedID then SendAction("frespawn",selectedID,"")
        else Derma_Query("Force respawn ALL players?","Confirm","Yes",function() SendAction("frespawn","","") end,"Cancel",function() end) end
    end)
    frBtn:SetSize(120,BTN_H); frBtn:SetPos(PAD+342,y)

    local unragBtn = MakeButton(parent,"Un-Ragdoll",Color(80,60,140),function()
        if selectedID then
            SendAction("unragdoll",selectedID,"")
        else
            Derma_Query("Force un-ragdoll ALL players?","Confirm","Yes",function() SendAction("unragdoll","","") end,"Cancel",function() end)
        end
    end)
    unragBtn:SetSize(100,BTN_H); unragBtn:SetPos(PAD+466,y)
    y = y + BTN_H + ROW_GAP + 4

    local rlbl=vgui.Create("DLabel",parent); rlbl:SetPos(PAD,y+5); rlbl:SetSize(80,18)
    rlbl:SetFont(FONT_SMALL); rlbl:SetTextColor(COL_TEXT_DIM); rlbl:SetText("Set role:")

    local roleEntry=vgui.Create("DTextEntry",parent)
    roleEntry:SetPos(PAD+86,y); roleEntry:SetSize(190,BTN_H)
    roleEntry:SetFont(FONT_SMALL); roleEntry:SetPlaceholderText("Role name..."); roleEntry:SetTextColor(COL_TEXT)
    roleEntry.Paint=function(s,w,h) draw.RoundedBox(4,0,0,w,h,COL_PANEL_DARK) s:DrawTextEntryText(COL_TEXT,COL_ACCENT,COL_TEXT) end

    local roleBtn=MakeButton(parent,"Apply Role",COL_ACCENT_DIM,function()
        local txt=roleEntry:GetValue(); if txt=="" then return end
        if selectedID then SendAction("setrole",selectedID,txt)
        else feedback="Select a player to set role."; feedbackTimer=CurTime()+3; self:UpdateFeedback() end
    end)
    roleBtn:SetSize(100,BTN_H); roleBtn:SetPos(PAD+282,y)
    y = y + BTN_H + PAD

    self._content:SetTall(y)
end

function PANEL:_RebuildClassChips()
    if not IsValid(self._clsChipPanel) then return end
    self._clsChipPanel:Clear()
    local innerW = self._innerW or 700
    local x, rowH = 0, 28
    for i, cls in ipairs(CLASS_OPTIONS) do
        local idx=i; local c=cls
        surface.SetFont(FONT_SMALL)
        local tw = surface.GetTextSize(c)
        local chipW = tw + 36
        if x + chipW > innerW then x=0; rowH=rowH+30 end
        local chip=vgui.Create("DPanel",self._clsChipPanel)
        chip:SetSize(chipW,26); chip:SetPos(x,rowH-28); chip._hov=false
        chip.Paint=function(_,w,h)
            draw.RoundedBox(3,0,0,w,h,chip._hov and COL_HOV or COL_ACCENT_DIM)
            draw.SimpleText(c,FONT_SMALL,6,h/2,COL_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        end
        chip.OnCursorEntered=function() chip._hov=true end
        chip.OnCursorExited=function() chip._hov=false end
        local delBtn=MakeButton(chip,"✕",Color(100,35,35),function() SendClassEdit("remove",tostring(idx)) end)
        delBtn:SetSize(20,20); delBtn:SetPos(chipW-22,3)
        x = x + chipW + 4
    end
    self._clsChipPanel:SetTall(rowH)
end

function PANEL:_UpdateEventButtons()
    if not IsValid(self._eventStartBtn) then return end
    -- Start: bright green when in PREP (ready to go), dimmed when already LIVE
    self._eventStartBtn._col = (eventState == 2) and Color(30,70,30) or COL_SUCCESS
    -- Stop: bright red when LIVE, dimmed otherwise
    self._eventStopBtn._col  = (eventState == 2) and COL_DANGER or Color(80,30,30)
end

function PANEL:Think()
    if feedbackTimer>0 and CurTime()>feedbackTimer then
        feedback=""; feedbackTimer=0
        if IsValid(self._feedbackLabel) then self._feedbackLabel:SetText("") end
    end
    if self._drag then
        if not input.IsMouseDown(MOUSE_LEFT) then
            self._drag = false
        else
            local mx, my = gui.MousePos()
            self:SetPos(self._dragFX + mx - self._dragMX, self._dragFY + my - self._dragMY)
        end
    end
end

function PANEL:_RebuildClassButtons()
    if not IsValid(self._classContainer) then return end
    self._classContainer:Clear()
    local innerW=self._innerW or 700; local btnW,gap=96,4; local x,y=0,0
    for _,cls in ipairs(CLASS_OPTIONS) do
        local c=cls
        local btn=MakeButton(self._classContainer,c,COL_ACCENT_DIM,function()
            if not selectedID then
                feedback="Select a player first, or use Team → Set Class."
                feedbackTimer=CurTime()+3; self:UpdateFeedback(); return
            end
            SendAction("setclass",selectedID,c)
        end)
        btn:SetSize(btnW,BTN_H); btn:SetPos(x,y)
        x=x+btnW+gap
        if x+btnW>innerW then x=0; y=y+BTN_H+gap end
    end
    self._classContainer:SetTall(math.max(BTN_H,y+BTN_H))
end

function PANEL:RebuildLoadoutList()
    if not IsValid(self._loadoutContainer) then return end
    self._loadoutContainer:Clear()
    local innerW=self._innerW or 700
    local sorted={}; for _,e in ipairs(loadoutData) do table.insert(sorted,e) end
    table.sort(sorted,function(a,b)
        local ag=a.group~="" and a.group or "~"; local bg=b.group~="" and b.group or "~"
        if ag~=bg then return ag<bg end; return a.name<b.name
    end)
    local y,x,lastGroup=0,0,nil; local btnW,gap=138,4
    local function Tip(e)
        local lines={}
        for _,w in ipairs(e.weapons) do table.insert(lines,w.type=="random" and ("[random: "..table.concat(w.choices," / ").."]") or w.class) end
        return #lines>0 and table.concat(lines,"\n") or "(empty)"
    end
    for _,entry in ipairs(sorted) do
        local e=entry; local group=e.group~="" and e.group or nil
        if group~=lastGroup then
            if x>0 then y=y+BTN_H+gap; x=0 end; lastGroup=group
            local hdr=vgui.Create("DLabel",self._loadoutContainer); hdr:SetPos(0,y); hdr:SetSize(innerW,16)
            hdr:SetFont(FONT_SMALL); hdr:SetTextColor(COL_TEXT_DIM); hdr:SetText(group and string.upper(group) or "GENERAL")
            y=y+18
            local div=vgui.Create("DPanel",self._loadoutContainer); div:SetPos(0,y); div:SetSize(innerW,1)
            div.Paint=function(_,w,h) surface.SetDrawColor(COL_BORDER) surface.DrawRect(0,0,w,h) end
            y=y+4; x=0
        end
        local col=group and Color(50,80,50) or Color(50,60,80)
        local btn=MakeButton(self._loadoutContainer,e.name,col,function()
            local sid=selectedID
            if not sid then
                Derma_Query("Apply '"..e.name.."' to:","Loadout Target",
                    "All Players",function() SendAction("loadout_all","",e.name) end,"Cancel",function() end); return
            end
            local td; for _,p in ipairs(playerData) do if p.steamid==sid then td=p break end end
            if td and td.team~="" then
                Derma_Query("Apply '"..e.name.."' to "..td.nick.."?","Loadout Target",
                    "This Player",              function() SendAction("loadout",sid,e.name) end,
                    "Their Team ("..td.team..")",function() SendAction("loadout_team","",td.team.."|"..e.name) end,
                    "All Players",              function() SendAction("loadout_all","",e.name) end)
            else SendAction("loadout",sid,e.name) end
        end)
        btn:SetSize(btnW,BTN_H); btn:SetPos(x,y); btn:SetTooltip(Tip(e))
        x=x+btnW+gap; if x+btnW>innerW then x=0; y=y+BTN_H+gap end
    end
    self._loadoutContainer:SetTall(math.max(BTN_H,y+BTN_H))
end

function PANEL:RebuildPlayerList()
    if not IsValid(self._playerList) then return end
    self._playerList:Clear()
    local listW=self._playerList:GetWide()
    local allRow=vgui.Create("DButton",self._playerList)
    allRow:SetSize(listW,36); allRow:SetText(""); allRow._hov=false
    allRow.Paint=function(_,w,h)
        draw.RoundedBox(3,0,0,w,h,selectedID==nil and COL_SEL or (allRow._hov and COL_HOV or Color(0,0,0,0)))
        draw.SimpleText("— All Players —",FONT_LABEL,12,h/2,COL_TEXT_DIM,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end
    allRow.OnCursorEntered=function(s) s._hov=true end; allRow.OnCursorExited=function(s) s._hov=false end
    allRow.DoClick=function()
        selectedID=nil; self._targetLabel:SetText("Target: All Players"); self:RebuildPlayerList()
    end
    self._playerList:Add(allRow)
    for _,p in ipairs(playerData) do
        local pd=p; local row=vgui.Create("DButton",self._playerList)
        row:SetSize(listW,44); row:SetText(""); row._hov=false
        local teamCol=TEAM_COLORS[pd.team] or COL_TEXT_DIM
        local statusCol=pd.spectator and COL_TEXT_DIM or (pd.alive and COL_SUCCESS or COL_DANGER)
        row.Paint=function(_,w,h)
            local sel=selectedID==pd.steamid
            draw.RoundedBox(3,1,1,w-2,h-2,sel and COL_SEL or (row._hov and COL_HOV or Color(0,0,0,0)))
            if pd.team~="" then surface.SetDrawColor(teamCol); surface.DrawRect(0,0,3,h) end
            surface.SetDrawColor(statusCol); surface.DrawRect(w-13,h/2-4,8,8)
            draw.SimpleText(pd.nick, FONT_LABEL,10,11,COL_TEXT,    TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP)
            draw.SimpleText((pd.class~="" and pd.class or "?")..(pd.team~="" and "  ·  "..pd.team or ""),
                FONT_SMALL,10,27,COL_TEXT_DIM,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP)
        end
        row.OnCursorEntered=function(s) s._hov=true end; row.OnCursorExited=function(s) s._hov=false end
        row.DoClick=function()
            selectedID=pd.steamid
            self._targetLabel:SetText("Target: "..pd.nick.."  ["..(pd.class~="" and pd.class or "?").."]"..(pd.team~="" and "  Team "..pd.team or ""))
            self:RebuildPlayerList()
        end
        self._playerList:Add(row)
    end
end

function PANEL:UpdateFeedback()
    if IsValid(self._feedbackLabel) then self._feedbackLabel:SetText(feedback) end
end

function PANEL:Paint(w,h)
    draw.RoundedBox(6,0,0,w,h,COL_BG)
    surface.SetDrawColor(COL_BORDER); surface.DrawOutlinedRect(0,0,w,h,1)
    -- Header band
    draw.RoundedBoxEx(6,0,0,w,HDR_H,COL_PANEL_DARK,true,true,false,false)
    draw.SimpleText("Event Admin Menu",FONT_TITLE,14,HDR_H/2,COL_ACCENT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    local dotCol, dotLabel
    if eventState == 2 then
        dotCol = Color(60, 220, 80);  dotLabel = "EVENT LIVE"
    elseif eventState == 1 then
        dotCol = Color(255, 180, 0);  dotLabel = "EVENT PREP"
    else
        dotCol = Color(160, 60, 60);  dotLabel = "STANDBY"
    end
    surface.SetDrawColor(dotCol); surface.DrawRect(200,HDR_H/2-4,8,8)
    draw.SimpleText(dotLabel,FONT_SMALL,213,HDR_H/2,dotCol,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
end

vgui.Register("ZC_EventMenu", PANEL, "EditablePanel")

-- ── Loadout editor ────────────────────────────────────────────────────────────

net.Receive("ZC_EventMenu_LoadoutSaved", function()
    if IsValid(ZC_EventLoadoutEditor) then ZC_EventLoadoutEditor:Refresh() end
end)

local function SendLoadoutEdit(op, arg)
    net.Start("ZC_EventMenu_LoadoutEdit")
        net.WriteString(op); net.WriteString(arg or "")
    net.SendToServer()
end

local EPANEL = {}

function EPANEL:Init()
    local panelH = math.min(820, ScrH()-60)
    local panelW = 640
    self:SetSize(panelW, panelH); self:Center()
    EnsureInteractivePopup(self)
    self._selectedPreset = nil; self._W = panelW; self._H = panelH
    self._rebelOnlyMode = NEXT_EDITOR_REBEL_ONLY == true
    self._drag = false

    self.OnMousePressed = function(self, mc)
        if mc ~= MOUSE_LEFT then return end
        local _, my = self:CursorPos()
        if my > 40 then return end
        self._drag  = true
        self._dragMX, self._dragMY = gui.MousePos()
        self._dragFX, self._dragFY = self:GetPos()
    end

    local closeBtn = MakeButton(self,"✕",COL_DANGER,function() self:SetVisible(false) end)
    closeBtn:SetSize(30,30); closeBtn:SetPos(panelW-34,5)

    local LEFT_W_E  = 216
    local RIGHT_X_E = LEFT_W_E + PAD*2
    local RIGHT_W_E = panelW - RIGHT_X_E - PAD
    local CONT_Y    = 46

    -- Left: preset list
    local leftBg = vgui.Create("DPanel", self)
    leftBg:SetPos(PAD,CONT_Y); leftBg:SetSize(LEFT_W_E, panelH-CONT_Y-PAD)
    leftBg.Paint = function(_,w,h) draw.RoundedBox(4,0,0,w,h,COL_PANEL_DARK) end

    local presetLbl = vgui.Create("DLabel", leftBg)
    presetLbl:SetPos(8,8); presetLbl:SetSize(LEFT_W_E-16,14)
    presetLbl:SetFont(FONT_SMALL); presetLbl:SetTextColor(COL_TEXT_DIM); presetLbl:SetText("PRESETS")

    local listH = panelH - CONT_Y - PAD - 120
    self._presetScroll = vgui.Create("DScrollPanel", leftBg)
    self._presetScroll:SetPos(0,26); self._presetScroll:SetSize(LEFT_W_E, listH)
    local sb = self._presetScroll:GetVBar(); sb:SetWide(4)
    sb.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_BORDER) end
    sb.btnUp.Paint=function() end; sb.btnDown.Paint=function() end
    sb.btnGrip.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_ACCENT_DIM) end

    self._presetList = vgui.Create("DListLayout", self._presetScroll)
    self._presetList:SetWide(LEFT_W_E-4)

    local bY = listH + 30

    local newEntry = vgui.Create("DTextEntry", leftBg)
    newEntry:SetPos(4,bY); newEntry:SetSize(LEFT_W_E-52,26)
    newEntry:SetFont(FONT_SMALL); newEntry:SetPlaceholderText("New preset name…"); newEntry:SetTextColor(COL_TEXT)
    newEntry.Paint=function(s,w,h) draw.RoundedBox(3,0,0,w,h,COL_PANEL) s:DrawTextEntryText(COL_TEXT,COL_ACCENT,COL_TEXT) end

    local createBtn = MakeButton(leftBg,"+",COL_SUCCESS,function()
        local name=string.Trim(newEntry:GetValue()); if name=="" then return end
        SendLoadoutEdit("create",name); newEntry:SetValue("")
    end)
    createBtn:SetSize(44,26); createBtn:SetPos(LEFT_W_E-46,bY); bY=bY+30

    local hw = math.floor((LEFT_W_E-12)/2)
    self._renameBtn = MakeButton(leftBg,"Rename",COL_ACCENT_DIM,function()
        if not self._selectedPreset then return end
        Derma_StringRequest("Rename Preset","New name:","",function(n)
            n=string.Trim(n); if n=="" or n==self._selectedPreset then return end
            SendLoadoutEdit("rename",self._selectedPreset.."|"..n); self._selectedPreset=n end)
    end); self._renameBtn:SetSize(hw,26); self._renameBtn:SetPos(4,bY)

    self._deleteBtn = MakeButton(leftBg,"Delete",COL_DANGER,function()
        if not self._selectedPreset then return end
        local name=self._selectedPreset
        Derma_Query("Delete '"..name.."'? Cannot be undone.","Confirm Delete",
            "Delete",function() SendLoadoutEdit("delete",name); self._selectedPreset=nil; self:RefreshWeaponList() end,
            "Cancel",function() end)
    end); self._deleteBtn:SetSize(hw,26); self._deleteBtn:SetPos(4+hw+4,bY); bY=bY+30

    local grpLbl=vgui.Create("DLabel",leftBg); grpLbl:SetPos(4,bY+2); grpLbl:SetSize(LEFT_W_E-8,14)
    grpLbl:SetFont(FONT_SMALL); grpLbl:SetTextColor(COL_TEXT_DIM); grpLbl:SetText("CLASS (loadout for)")
    bY=bY+18

    -- Dropdown of known classes + Universal option, replaces freetext
    self._groupCombo = vgui.Create("DComboBox", leftBg)
    self._groupCombo:SetPos(4, bY); self._groupCombo:SetSize(LEFT_W_E-52, 24)
    self._groupCombo:SetFont(FONT_SMALL)
    for _, choice in ipairs(GetEditorClassChoices(self._rebelOnlyMode)) do
        self._groupCombo:AddChoice(choice.label, choice.value)
    end
    self._groupCombo:ChooseOptionID(1)
    self._groupCombo.OnSelect = function(_, _, text, data)
        self._pendingGroup = data
    end
    self._groupCombo.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, COL_PANEL_DARK)
        draw.SimpleText(s:GetValue(), FONT_SMALL, 6, h/2, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("▾", FONT_SMALL, w-10, h/2, COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    self._pendingGroup = ""

    local setGrpBtn=MakeButton(leftBg,"Set",COL_ACCENT,function()
        if not self._selectedPreset then return end
        local grp = self._pendingGroup or ""
        SendLoadoutEdit("setgroup", self._selectedPreset .. "|" .. grp)
    end); setGrpBtn:SetSize(44,24); setGrpBtn:SetPos(LEFT_W_E-46,bY)

    -- Right: weapon list
    local rightBg=vgui.Create("DPanel",self)
    rightBg:SetPos(RIGHT_X_E,CONT_Y); rightBg:SetSize(RIGHT_W_E, panelH-CONT_Y-PAD)
    rightBg.Paint=function(_,w,h) draw.RoundedBox(4,0,0,w,h,COL_PANEL) end

    self._wepPresetLabel=vgui.Create("DLabel",rightBg); self._wepPresetLabel:SetPos(8,8); self._wepPresetLabel:SetSize(RIGHT_W_E-16,14)
    self._wepPresetLabel:SetFont(FONT_SMALL); self._wepPresetLabel:SetTextColor(COL_TEXT_DIM); self._wepPresetLabel:SetText("SELECT A PRESET")

    local wepListH=math.floor((panelH-CONT_Y-PAD-28)*0.44)
    self._wepScroll=vgui.Create("DScrollPanel",rightBg); self._wepScroll:SetPos(0,26); self._wepScroll:SetSize(RIGHT_W_E,wepListH)
    local sb2=self._wepScroll:GetVBar(); sb2:SetWide(4)
    sb2.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_BORDER) end
    sb2.btnUp.Paint=function() end; sb2.btnDown.Paint=function() end
    sb2.btnGrip.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_ACCENT_DIM) end

    self._wepList=vgui.Create("DListLayout",self._wepScroll); self._wepList:SetWide(RIGHT_W_E-8)

    local wy=wepListH+30

    self._wepEntry=vgui.Create("DTextEntry",rightBg); self._wepEntry:SetPos(4,wy); self._wepEntry:SetSize(RIGHT_W_E-148,26)
    self._wepEntry:SetFont(FONT_MONO); self._wepEntry:SetPlaceholderText("weapon_classname"); self._wepEntry:SetTextColor(COL_TEXT)
    self._wepEntry.Paint=function(s,w,h) draw.RoundedBox(3,0,0,w,h,COL_PANEL_DARK) s:DrawTextEntryText(COL_TEXT,COL_ACCENT,COL_TEXT) end

    local addWepBtn=MakeButton(rightBg,"+ Add",COL_SUCCESS,function()
        if not self._selectedPreset then return end
        local wc=string.Trim(self._wepEntry:GetValue()); if wc=="" then return end
        SendLoadoutEdit("addwep",self._selectedPreset.."|"..wc); self._wepEntry:SetValue("")
    end); addWepBtn:SetSize(56,26); addWepBtn:SetPos(RIGHT_W_E-140,wy)

    local browseBtn=MakeButton(rightBg,"🔍 Browse",COL_ACCENT_DIM,function()
        if not self._selectedPreset then return end
        ZC_OpenWeaponBrowser(function(cls) self._wepEntry:SetValue(cls) end)
    end); browseBtn:SetSize(78,26); browseBtn:SetPos(RIGHT_W_E-80,wy); wy=wy+30

    local addVarBtn=MakeButton(rightBg,"+ Variable",Color(40,80,60),function()
        if not self._selectedPreset then return end
        local preset=self._selectedPreset
        Derma_StringRequest("Add Random Variable","Enter choices separated by commas:","",function(input)
            input=string.Trim(input); if input=="" then return end
            local valid={}
            for _,p in ipairs(string.Explode(",",input)) do local t=string.Trim(p) if t~="" then table.insert(valid,t) end end
            if #valid==0 then return end
            SendLoadoutEdit("addvar",preset.."|"..table.concat(valid,"|"))
        end)
    end); addVarBtn:SetSize(94,26); addVarBtn:SetPos(4,wy); wy=wy+36

    -- Armor
    local armorLbl=vgui.Create("DLabel",rightBg); armorLbl:SetPos(4,wy); armorLbl:SetSize(RIGHT_W_E-8,14)
    armorLbl:SetFont(FONT_SMALL); armorLbl:SetTextColor(COL_TEXT_DIM); armorLbl:SetText("ARMOR")
    local armorDiv=vgui.Create("DPanel",rightBg); armorDiv:SetPos(4,wy+15); armorDiv:SetSize(RIGHT_W_E-8,1)
    armorDiv.Paint=function(_,w,h) surface.SetDrawColor(COL_BORDER) surface.DrawRect(0,0,w,h) end
    wy=wy+20

    local slotCombo=vgui.Create("DComboBox",rightBg); slotCombo:SetPos(4,wy); slotCombo:SetSize(78,26); slotCombo:SetFont(FONT_SMALL)
    for _,s in ipairs({"torso","head","ears","face"}) do slotCombo:AddChoice(s) end; slotCombo:ChooseOptionID(1)
    slotCombo.Paint=function(s,w,h)
        draw.RoundedBox(3,0,0,w,h,COL_PANEL_DARK)
        draw.SimpleText(s:GetValue(),FONT_SMALL,6,h/2,COL_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText("▾",FONT_SMALL,w-10,h/2,COL_TEXT_DIM,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end
    self._armorSlotCombo=slotCombo

    -- Entry + Add on the primary row (mirrors weapon row)
    local armorEntry=vgui.Create("DTextEntry",rightBg); armorEntry:SetPos(86,wy); armorEntry:SetSize(RIGHT_W_E-148,26)
    armorEntry:SetFont(FONT_MONO); armorEntry:SetPlaceholderText("vest1, helmet2…"); armorEntry:SetTextColor(COL_TEXT)
    armorEntry.Paint=function(s,w,h) draw.RoundedBox(3,0,0,w,h,COL_PANEL_DARK) s:DrawTextEntryText(COL_TEXT,COL_ACCENT,COL_TEXT) end
    self._armorEntry=armorEntry

    local addArmorBtn=MakeButton(rightBg,"+ Add",COL_ACCENT,function()
        if not self._selectedPreset then return end
        local slot=self._armorSlotCombo:GetValue(); local key=string.Trim(self._armorEntry:GetValue())
        if key=="" then return end
        SendLoadoutEdit("setarmor",self._selectedPreset.."|"..slot.."|"..key); self._armorEntry:SetValue("")
    end); addArmorBtn:SetSize(56,26); addArmorBtn:SetPos(RIGHT_W_E-58,wy)
    wy=wy+30

    -- Browse + Random on the second row
    local armorBrowseBtn=MakeButton(rightBg,"🔍 Browse",COL_ACCENT_DIM,function()
        if not self._selectedPreset then return end
        ZC_OpenArmorBrowser(function(key) self._armorEntry:SetValue(key) end)
    end); armorBrowseBtn:SetSize(90,24); armorBrowseBtn:SetPos(4,wy)

    local setArmorVarBtn=MakeButton(rightBg,"+ Random",Color(40,80,60),function()
        if not self._selectedPreset then return end
        local preset=self._selectedPreset; local slot=self._armorSlotCombo:GetValue()
        Derma_StringRequest("Random Armor — "..slot,"Enter choices (comma separated):","",function(input)
            input=string.Trim(input); if input=="" then return end
            local parts={}
            for _,p in ipairs(string.Explode(",",input)) do local t=string.Trim(p) if t~="" then table.insert(parts,t) end end
            if #parts==0 then return end
            SendLoadoutEdit("setarmorvar",preset.."|"..slot.."|"..table.concat(parts,"|"))
        end)
    end); setArmorVarBtn:SetSize(90,24); setArmorVarBtn:SetPos(98,wy); wy=wy+28

    local armorListH=math.floor((panelH-CONT_Y-PAD-28)*0.15)
    self._armorScroll=vgui.Create("DScrollPanel",rightBg); self._armorScroll:SetPos(4,wy); self._armorScroll:SetSize(RIGHT_W_E-8,armorListH)
    local sbA=self._armorScroll:GetVBar(); sbA:SetWide(4)
    sbA.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_BORDER) end
    sbA.btnUp.Paint=function() end; sbA.btnDown.Paint=function() end
    sbA.btnGrip.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_ACCENT_DIM) end
    self._armorList=vgui.Create("DListLayout",self._armorScroll); self._armorList:SetWide(RIGHT_W_E-16)
    wy=wy+armorListH+8

    -- Class strip
    local classStrip=vgui.Create("DPanel",rightBg)
    classStrip:SetPos(4,wy); classStrip:SetSize(RIGHT_W_E-8, panelH-CONT_Y-PAD-wy-4)
    classStrip.Paint=function(_,w,h) draw.RoundedBox(4,0,0,w,h,COL_PANEL_DARK) end

    local clsTitle=vgui.Create("DLabel",classStrip); clsTitle:SetPos(6,6); clsTitle:SetSize(RIGHT_W_E-20,14)
    clsTitle:SetFont(FONT_SMALL); clsTitle:SetTextColor(COL_TEXT_DIM); clsTitle:SetText("CLASS LIST  —  shown in the assignment buttons")

    self._clsList=vgui.Create("DHorizontalScroller",classStrip)
    self._clsList:SetPos(4,22); self._clsList:SetSize(RIGHT_W_E-16,30); self._clsList:SetOverlap(0)

    local clsEntry=vgui.Create("DTextEntry",classStrip); clsEntry:SetPos(4,56); clsEntry:SetSize(RIGHT_W_E-68,26)
    clsEntry:SetFont(FONT_SMALL); clsEntry:SetPlaceholderText("Add class name (e.g. John, pmc, gerww2)…"); clsEntry:SetTextColor(COL_TEXT)
    clsEntry.Paint=function(s,w,h) draw.RoundedBox(3,0,0,w,h,COL_PANEL) s:DrawTextEntryText(COL_TEXT,COL_ACCENT,COL_TEXT) end

    local addClsBtn=MakeButton(classStrip,"+ Add",COL_SUCCESS,function()
        local name=string.Trim(clsEntry:GetValue()); if name=="" then return end
        SendClassEdit("add",name); clsEntry:SetValue("")
    end); addClsBtn:SetSize(56,26); addClsBtn:SetPos(RIGHT_W_E-60,56)

    self._clsEntry=clsEntry; self._clsStrip=classStrip
    self:Refresh(); self:RefreshClassList()
end

function EPANEL:Think()
    if self._drag then
        if not input.IsMouseDown(MOUSE_LEFT) then
            self._drag = false
        else
            local mx, my = gui.MousePos()
            self:SetPos(self._dragFX + mx - self._dragMX, self._dragFY + my - self._dragMY)
        end
    end
end

function EPANEL:Refresh() self:RefreshPresetList() self:RefreshWeaponList() self:RefreshArmorList() end

function EPANEL:SetRebelOnlyMode(enabled)
    self._rebelOnlyMode = enabled == true
    self._selectedPreset = nil
    self:RefreshClassList()
    self:Refresh()
end

function EPANEL:IsPresetVisible(entry)
    if not self._rebelOnlyMode then return true end
    return IsRebelGroupName(entry and entry.group or "")
end

function EPANEL:GetVisiblePresets()
    local out = {}
    for _, entry in ipairs(loadoutData) do
        if self:IsPresetVisible(entry) then
            table.insert(out, entry)
        end
    end
    return out
end

function EPANEL:RefreshClassList()
    if not IsValid(self._clsList) then return end
    self._clsList:Remove()
    local stripW = IsValid(self._clsStrip) and (self._clsStrip:GetWide()-8) or 400
    self._clsList=vgui.Create("DHorizontalScroller",self._clsStrip)
    self._clsList:SetPos(4,22); self._clsList:SetSize(stripW,30); self._clsList:SetOverlap(0)
    for i,cls in ipairs(CLASS_OPTIONS) do
        local idx=i; local c=cls
        surface.SetFont(FONT_SMALL); local tw=surface.GetTextSize(c); local chipW=tw+36
        local row=vgui.Create("DPanel"); row:SetSize(chipW,26); row._hov=false
        row.Paint=function(_,w,h) draw.RoundedBox(3,0,0,w,h,row._hov and COL_HOV or COL_PANEL) draw.SimpleText(c,FONT_SMALL,6,h/2,COL_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
        row.OnCursorEntered=function() row._hov=true end; row.OnCursorExited=function() row._hov=false end
        local delBtn=MakeButton(row,"✕",Color(100,35,35),function() SendClassEdit("remove",tostring(idx)) end)
        delBtn:SetSize(20,20); delBtn:SetPos(chipW-22,3)
        self._clsList:AddPanel(row)
    end

    -- Rebuild group combo to reflect updated class list
    if IsValid(self._groupCombo) then
        local prev = self._pendingGroup or ""
        self._groupCombo:Clear()
        for _, choice in ipairs(GetEditorClassChoices(self._rebelOnlyMode)) do
            self._groupCombo:AddChoice(choice.label, choice.value)
        end
        -- Restore previous selection
        if prev == "" then
            self._groupCombo:ChooseOptionID(1)
        else
            local choices = self._groupCombo.Choices or {}
            for i, choice in ipairs(choices) do
                if choice == prev then self._groupCombo:ChooseOptionID(i) break end
            end
        end
    end
end

function EPANEL:RefreshPresetList()
    if not IsValid(self._presetList) then return end
    self._presetList:Clear()
    local visiblePresets = self:GetVisiblePresets()
    local names={}; for _,e in ipairs(visiblePresets) do table.insert(names,e.name) end

    if self._selectedPreset then
        local stillVisible = false
        for _, e in ipairs(visiblePresets) do
            if e.name == self._selectedPreset then
                stillVisible = true
                break
            end
        end
        if not stillVisible then
            self._selectedPreset = nil
        end
    end

    local rowW=self._presetList:GetWide()
    for _,name in ipairs(names) do
        local n=name
        local row=vgui.Create("DButton",self._presetList); row:SetSize(rowW,32); row:SetText(""); row._hov=false
        row.Paint=function(_,w,h)
            local sel=self._selectedPreset==n
            draw.RoundedBox(3,1,1,w-2,h-2,sel and COL_SEL or (row._hov and COL_HOV or Color(0,0,0,0)))
            draw.SimpleText(n,FONT_LABEL,8,h/2,sel and COL_ACCENT or COL_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        end
        row.OnCursorEntered=function(s) s._hov=true end; row.OnCursorExited=function(s) s._hov=false end
        row.DoClick=function()
            self._selectedPreset=n; self:RefreshPresetList(); self:RefreshWeaponList(); self:RefreshArmorList()
            -- Sync the class dropdown to the preset's current group
            if IsValid(self._groupCombo) then
                for _,e in ipairs(visiblePresets) do
                    if e.name==n then
                        local grp = e.group or ""
                        self._pendingGroup = grp
                        -- Find matching option ID
                        if grp == "" then
                            self._groupCombo:ChooseOptionID(1)
                        else
                            local choices = self._groupCombo.Choices or {}
                            for i, choice in ipairs(choices) do
                                if choice == grp then
                                    self._groupCombo:ChooseOptionID(i)
                                    break
                                end
                            end
                        end
                        break
                    end
                end
            end
        end
        self._presetList:Add(row)
    end
end

function EPANEL:RefreshWeaponList()
    if not IsValid(self._wepList) then return end
    self._wepList:Clear()
    local preset=self._selectedPreset
    if not preset then self._wepPresetLabel:SetText("SELECT A PRESET") return end
    self._wepPresetLabel:SetText("WEAPONS  —  "..string.upper(preset))
    local weapons={}
    for _,e in ipairs(loadoutData) do if e.name==preset then weapons=e.weapons break end end
    local rowW=self._wepList:GetWide()
    if #weapons==0 then
        local empty=vgui.Create("DLabel",self._wepList); empty:SetSize(rowW,28); empty:SetFont(FONT_SMALL)
        empty:SetTextColor(COL_TEXT_DIM); empty:SetText("  No weapons. Add one below."); self._wepList:Add(empty); return
    end
    local COL_VAR_BG=Color(30,50,30); local COL_VAR_TEXT=Color(120,220,120)
    for i,entry in ipairs(weapons) do
        local idx=i
        if entry.type=="random" then
            local rowH=22+#entry.choices*20+26
            local row=vgui.Create("DPanel",self._wepList); row:SetSize(rowW,rowH)
            row.Paint=function(_,w,h) draw.RoundedBox(3,0,0,w,h,COL_VAR_BG) draw.SimpleText(idx..".  [random — picks one]",FONT_SMALL,6,11,COL_VAR_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
            local delVar=MakeButton(row,"✕ remove",Color(120,40,40),function() SendLoadoutEdit("removewep",preset.."|"..idx) end)
            delVar:SetSize(78,18); delVar:SetPos(rowW-82,2)
            for ci,choice in ipairs(entry.choices) do
                local choiceIdx=ci; local ch=choice; local cy=22+(ci-1)*20
                local cr=vgui.Create("DPanel",row); cr:SetPos(8,cy); cr:SetSize(rowW-16,18)
                cr.Paint=function(_,w,h) draw.SimpleText("↳  "..ch,FONT_MONO,4,h/2,COL_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
                local dc=MakeButton(cr,"✕",Color(100,35,35),function() SendLoadoutEdit("removevaroption",preset.."|"..idx.."|"..choiceIdx) end)
                dc:SetSize(18,16); dc:SetPos(rowW-32,1)
            end
            local addY=22+#entry.choices*20+2
            local ce=vgui.Create("DTextEntry",row); ce:SetPos(8,addY); ce:SetSize(rowW-104,20)
            ce:SetFont(FONT_MONO); ce:SetPlaceholderText("weapon_classname…"); ce:SetTextColor(COL_TEXT)
            ce.Paint=function(s,w,h) draw.RoundedBox(3,0,0,w,h,COL_PANEL_DARK) s:DrawTextEntryText(COL_TEXT,COL_ACCENT,COL_TEXT) end
            local ac=MakeButton(row,"+ Option",COL_SUCCESS,function()
                local val=string.Trim(ce:GetValue()); if val=="" then return end
                SendLoadoutEdit("addvaroption",preset.."|"..idx.."|"..val); ce:SetValue("")
            end); ac:SetSize(86,20); ac:SetPos(rowW-92,addY)
            self._wepList:Add(row)
        else
            local wc=entry.class
            local row=vgui.Create("DPanel",self._wepList); row:SetSize(rowW,28); row._hov=false
            row.Paint=function(_,w,h)
                if row._hov then draw.RoundedBox(3,0,0,w,h,COL_HOV) end
                draw.SimpleText(idx..".  "..wc,FONT_MONO,8,h/2,COL_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            end
            row.OnCursorEntered=function() row._hov=true end; row.OnCursorExited=function() row._hov=false end
            local delBtn=MakeButton(row,"✕",Color(120,40,40),function() SendLoadoutEdit("removewep",preset.."|"..idx) end)
            delBtn:SetSize(24,22); delBtn:SetPos(rowW-28,3)
            self._wepList:Add(row)
        end
    end
end

function EPANEL:RefreshArmorList()
    if not IsValid(self._armorList) then return end
    self._armorList:Clear()
    local preset=self._selectedPreset; if not preset then return end
    local armorData={}
    for _,e in ipairs(loadoutData) do if e.name==preset then armorData=e.armor or {} break end end
    local SLOTS={"torso","head","ears","face"}
    local rowW=self._armorList:GetWide()
    local COL_VAR_BG   = Color(30,50,30)
    local COL_VAR_TEXT = Color(120,220,120)
    for _,slot in ipairs(SLOTS) do
        local s=slot; local data=armorData[slot]
        if data and data.type=="random" then
            -- Expanded variable block — mirrors weapon variable rows
            local rowH = 22 + #data.choices * 20 + 26
            local row=vgui.Create("DPanel",self._armorList); row:SetSize(rowW,rowH)
            row.Paint=function(_,w,h)
                draw.RoundedBox(3,0,0,w,h,COL_VAR_BG)
                draw.SimpleText("["..s.."]  random — picks one",FONT_SMALL,6,11,COL_VAR_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            end
            -- Clear whole slot
            local delVar=MakeButton(row,"✕ clear",Color(120,40,40),function()
                SendLoadoutEdit("cleararmor",preset.."|"..s)
            end); delVar:SetSize(64,18); delVar:SetPos(rowW-68,2)
            -- Per-choice rows
            for ci,choice in ipairs(data.choices) do
                local choiceIdx=ci; local ch=choice
                local cy=22+(ci-1)*20
                local cr=vgui.Create("DPanel",row); cr:SetPos(8,cy); cr:SetSize(rowW-16,18)
                cr.Paint=function(_,w,h)
                    draw.SimpleText("↳  "..ch,FONT_MONO,4,h/2,COL_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
                end
                local dc=MakeButton(cr,"✕",Color(100,35,35),function()
                    SendLoadoutEdit("removearmvaropt",preset.."|"..s.."|"..choiceIdx)
                end); dc:SetSize(18,16); dc:SetPos(rowW-32,1)
            end
            -- + Option entry row
            local addY=22+#data.choices*20+2
            local ce=vgui.Create("DTextEntry",row); ce:SetPos(8,addY); ce:SetSize(rowW-100,20)
            ce:SetFont(FONT_MONO); ce:SetPlaceholderText("armor key…"); ce:SetTextColor(COL_TEXT)
            ce.Paint=function(sv,w,h) draw.RoundedBox(3,0,0,w,h,COL_PANEL_DARK) sv:DrawTextEntryText(COL_TEXT,COL_ACCENT,COL_TEXT) end
            local ac=MakeButton(row,"+ Option",COL_SUCCESS,function()
                local val=string.Trim(ce:GetValue()); if val=="" then return end
                SendLoadoutEdit("addarmvaropt",preset.."|"..s.."|"..val); ce:SetValue("")
            end); ac:SetSize(84,20); ac:SetPos(rowW-92,addY)
            self._armorList:Add(row)
        else
            local row=vgui.Create("DPanel",self._armorList); row:SetSize(rowW,28); row._hov=false
            if data then
                -- Plain key row
                local label="["..s.."]  "..data.key
                row.Paint=function(_,w,h)
                    if row._hov then draw.RoundedBox(3,0,0,w,h,COL_HOV) end
                    draw.SimpleText(label,FONT_MONO,6,h/2,COL_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
                end
                local delBtn=MakeButton(row,"✕",Color(120,40,40),function()
                    SendLoadoutEdit("cleararmor",preset.."|"..s)
                end); delBtn:SetSize(24,22); delBtn:SetPos(rowW-28,3)
            else
                row.Paint=function(_,w,h)
                    draw.SimpleText("["..s.."]  —",FONT_MONO,6,h/2,COL_TEXT_DIM,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
                end
            end
            row.OnCursorEntered=function() row._hov=true end; row.OnCursorExited=function() row._hov=false end
            self._armorList:Add(row)
        end
    end
end

function EPANEL:Paint(w,h)
    draw.RoundedBox(6,0,0,w,h,COL_BG)
    surface.SetDrawColor(COL_BORDER); surface.DrawOutlinedRect(0,0,w,h,1)
    draw.RoundedBoxEx(6,0,0,w,40,COL_PANEL_DARK,true,true,false,false)
    local title = self._rebelOnlyMode and "Manage Rebel Loadouts" or "Edit Loadout Presets"
    draw.SimpleText(title,FONT_TITLE,12,20,COL_WARN,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
end

vgui.Register("ZC_EventLoadoutEditor", EPANEL, "EditablePanel")

-- ── Edit Loadouts button ──────────────────────────────────────────────────────

local origInit = PANEL.Init
PANEL.Init = function(self)
    origInit(self)
    local bY = math.floor((HDR_H - 30) / 2)
    self._editLoadoutsBtn = MakeButton(self, "✎ Loadouts", COL_WARN, function()
        if not LocalPlayer():IsSuperAdmin() then return end
        OpenEventLoadoutEditor(false)
    end)
    self._editLoadoutsBtn:SetSize(104, 30)
    self._editLoadoutsBtn:SetPos(self._W - 376 - 110, bY)  -- left of Event Stop
    self._editLoadoutsBtn:SetVisible(false)
end

local origThink = PANEL.Think
PANEL.Think = function(self)
    origThink(self)
    if IsValid(self._editLoadoutsBtn) then self._editLoadoutsBtn:SetVisible(LocalPlayer():IsSuperAdmin()) end
end

-- ── Weapon / Armor Browser ────────────────────────────────────────────────────

local function BuildWeaponList()
    local list={}
    for _,wep in pairs(weapons.GetList()) do
        if not wep.ClassName then continue end
        local cls=wep.ClassName
        if cls=="weapon_base" or cls=="base_weapon" then continue end
        table.insert(list,{class=cls,name=(wep.PrintName and wep.PrintName~="") and wep.PrintName or cls,category=wep.Category or ""})
    end
    table.sort(list,function(a,b) if a.category~=b.category then return a.category<b.category end return a.class<b.class end)
    return list
end

local function BuildArmorList()
    local seen={}; local armorList={}
    local function AddKey(key,name,category)
        if not key or key=="" or seen[key] then return end
        seen[key]=true; table.insert(armorList,{class=key,name=name or key,category=category or "Armor"})
    end
    local spawnables=list.Get("SpawnableEntities") or {}
    for key,data in pairs(spawnables) do
        if type(data)=="table" and data.Category then
            local cat=string.lower(data.Category)
            if string.find(cat,"armor",1,true) then AddKey(data.ClassName or key,data.PrintName or data.Name,data.Category) end
        end
    end
    for _,key in ipairs({"vest1","vest2","vest3","vest4","vest5","helmet1","helmet2","helmet3","helmet4"}) do AddKey(key) end
    for _,entry in ipairs(loadoutData) do
        local armor=entry.armor or {}
        for _,value in pairs(armor) do
            if type(value)=="string" then AddKey(value)
            elseif type(value)=="table" then for i=2,#value do AddKey(value[i]) end end
        end
    end
    table.sort(armorList,function(a,b) return a.class<b.class end)
    return armorList
end

local function OpenBrowser(title, items, callback)
    if IsValid(ZC_WeaponBrowserPanel) then ZC_WeaponBrowserPanel:Remove() end
    local W,H=540,620
    local frame=vgui.Create("DFrame"); frame:SetSize(W,H); frame:Center()
    frame:SetTitle(""); frame:SetDraggable(true); frame:SetSizable(false); frame:MakePopup()
    ZC_WeaponBrowserPanel=frame
    frame.Paint=function(_,w,h) draw.RoundedBox(6,0,0,w,h,COL_BG) surface.SetDrawColor(COL_BORDER) surface.DrawOutlinedRect(0,0,w,h,1) end

    local hdr=vgui.Create("DPanel",frame); hdr:SetPos(0,0); hdr:SetSize(W,36)
    hdr.Paint=function(_,w,h) draw.RoundedBoxEx(6,0,0,w,h,COL_PANEL_DARK,true,true,false,false) draw.SimpleText(title,FONT_TITLE,12,h/2,COL_ACCENT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
    local cb=MakeButton(hdr,"✕",COL_DANGER,function() frame:Remove() end); cb:SetSize(28,26); cb:SetPos(W-32,5)

    local se=vgui.Create("DTextEntry",frame); se:SetPos(6,42); se:SetSize(W-12,28)
    se:SetFont(FONT_MONO); se:SetPlaceholderText("Search…"); se:SetTextColor(COL_TEXT)
    se.Paint=function(s,w,h) draw.RoundedBox(4,0,0,w,h,COL_PANEL) s:DrawTextEntryText(COL_TEXT,COL_ACCENT,COL_TEXT) end

    local scroll=vgui.Create("DScrollPanel",frame); scroll:SetPos(6,76); scroll:SetSize(W-12,H-82)
    local sb=scroll:GetVBar(); sb:SetWide(4)
    sb.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_BORDER) end
    sb.btnUp.Paint=function() end; sb.btnDown.Paint=function() end
    sb.btnGrip.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_ACCENT_DIM) end

    local rl=vgui.Create("DListLayout",scroll); rl:SetWide(W-20)
    local lastCat=nil

    local function Populate(query)
        rl:Clear(); lastCat=nil
        query=string.lower(string.Trim(query or ""))
        for _,w in ipairs(items) do
            if query~="" then
                if not string.find(string.lower(w.class),query,1,true) and
                   not string.find(string.lower(w.name), query,1,true) then continue end
            end
            if w.category~=lastCat then
                lastCat=w.category
                local dl=vgui.Create("DLabel",rl); dl:SetSize(W-20,18)
                dl:SetFont(FONT_SMALL); dl:SetTextColor(COL_TEXT_DIM)
                dl:SetText("  "..(w.category~="" and string.upper(w.category) or "UNCATEGORISED")); dl:SetContentAlignment(4)
                rl:Add(dl)
            end
            local entry=vgui.Create("DButton",rl); entry:SetSize(W-20,34); entry:SetText(""); entry._hov=false
            local wname,wclass=w.name,w.class
            entry.Paint=function(_,ew,eh)
                if entry._hov then draw.RoundedBox(3,1,1,ew-2,eh-2,COL_HOV) end
                draw.SimpleText(wname, FONT_LABEL,8,eh/2-6,COL_TEXT,    TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
                draw.SimpleText(wclass,FONT_MONO, 8,eh/2+6,COL_TEXT_DIM,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            end
            entry.OnCursorEntered=function(s) s._hov=true end; entry.OnCursorExited=function(s) s._hov=false end
            entry.DoClick=function() callback(wclass); frame:Remove() end
            rl:Add(entry)
        end
    end
    se.OnChange=function(s) Populate(s:GetValue()) end; Populate("")
end

function ZC_OpenWeaponBrowser(cb) OpenBrowser("Weapon Browser", BuildWeaponList(), cb) end
function ZC_OpenArmorBrowser(cb)  OpenBrowser("Armor Browser",  BuildArmorList(),  cb) end

-- ── Player Loadout Menu (!loadout) ────────────────────────────────────────────

local playerLoadoutData = {}

net.Receive("ZC_PlayerLoadout_List", function()
    playerLoadoutData = {}
    local count = net.ReadUInt(8)
    for i = 1, count do
        table.insert(playerLoadoutData, { name=net.ReadString(), group=net.ReadString() })
    end
end)

net.Receive("ZC_PlayerLoadout_Open", function()
    if IsValid(ZC_PlayerLoadoutPanel) then ZC_PlayerLoadoutPanel:Remove() end
    local W,H=400,520
    local frame=vgui.Create("DFrame"); frame:SetSize(W,H); frame:Center()
    frame:SetTitle(""); frame:SetDraggable(true); frame:MakePopup()
    ZC_PlayerLoadoutPanel=frame
    frame.Paint=function(_,w,h) draw.RoundedBox(6,0,0,w,h,COL_BG) surface.SetDrawColor(COL_BORDER) surface.DrawOutlinedRect(0,0,w,h,1) end

    local hdr=vgui.Create("DPanel",frame); hdr:SetPos(0,0); hdr:SetSize(W,38)
    hdr.Paint=function(_,w,h) draw.RoundedBoxEx(6,0,0,w,h,COL_PANEL_DARK,true,true,false,false) draw.SimpleText("Select Loadout",FONT_TITLE,12,h/2,COL_ACCENT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
    hdr.OnMousePressed=function(_,mc) if mc==MOUSE_LEFT then frame:StartBoxSelection() frame:MouseCapture(true) end end
    hdr.OnMouseReleased=function(_,mc) if mc==MOUSE_LEFT then frame:MouseCapture(false) end end
    local closeBtn=MakeButton(hdr,"✕",COL_DANGER,function() frame:Remove() end); closeBtn:SetSize(30,30); closeBtn:SetPos(W-34,4)

    local scroll=vgui.Create("DScrollPanel",frame); scroll:SetPos(6,44); scroll:SetSize(W-12,H-50)
    local sb=scroll:GetVBar(); sb:SetWide(4)
    sb.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_BORDER) end
    sb.btnUp.Paint=function() end; sb.btnDown.Paint=function() end
    sb.btnGrip.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,COL_ACCENT_DIM) end

    local lp=vgui.Create("DListLayout",scroll); lp:SetWide(W-20)
    local lastGroup=nil
    for _,entry in ipairs(playerLoadoutData) do
        local e=entry; local group=e.group~="" and e.group or nil
        if group~=lastGroup then
            lastGroup=group
            local hl=vgui.Create("DLabel",lp); hl:SetSize(W-20,20); hl:SetFont(FONT_SMALL); hl:SetTextColor(COL_TEXT_DIM)
            hl:SetText("  "..(group and string.upper(group) or "UNIVERSAL")); hl:SetContentAlignment(4); lp:Add(hl)
        end
        local btn=vgui.Create("DButton",lp); btn:SetSize(W-20,34); btn:SetText(""); btn._hov=false
        btn.Paint=function(_,w,h)
            if btn._hov then draw.RoundedBox(3,1,1,w-2,h-2,COL_HOV) end
            draw.SimpleText(e.name,FONT_LABEL,12,h/2,COL_TEXT,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        end
        btn.OnCursorEntered=function(s) s._hov=true end; btn.OnCursorExited=function(s) s._hov=false end
        btn.DoClick=function()
            net.Start("ZC_PlayerLoadout_Apply") net.WriteString(e.name) net.SendToServer(); frame:Remove()
        end
        lp:Add(btn)
    end
    if #playerLoadoutData==0 then
        local empty=vgui.Create("DLabel",lp); empty:SetSize(W-20,40); empty:SetFont(FONT_SMALL)
        empty:SetTextColor(COL_TEXT_DIM); empty:SetText("  No loadouts available for your class."); empty:SetContentAlignment(4); lp:Add(empty)
    end
end)
