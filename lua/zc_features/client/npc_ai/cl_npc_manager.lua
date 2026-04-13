-- cl_npc_manager.lua — Client side of the NPC Manager panel.
-- Lists all active NPCs with health, state, schedule, godmode status,
-- and scripted sequence association. Allows teleport, godmode toggle,
-- sequence browsing and forcing, kill, and remove.

if SERVER then return end

-- ── Theme (reuses event menu colours) ────────────────────────────────────────

local COL_BG         = Color(18,  20,  26)
local COL_PANEL      = Color(26,  29,  38)
local COL_PANEL_DARK = Color(14,  16,  22)
local COL_BORDER     = Color(45,  50,  65)
local COL_ACCENT     = Color(80,  160, 255)
local COL_ACCENT_DIM = Color(40,  80,  140)
local COL_DANGER     = Color(200, 60,  60)
local COL_WARN       = Color(200, 140, 40)
local COL_SUCCESS    = Color(60,  180, 80)
local COL_TEXT       = Color(220, 225, 235)
local COL_TEXT_DIM   = Color(120, 130, 150)
local COL_SEL        = Color(40,  80,  160, 180)
local COL_HOV        = Color(35,  40,  55)
local COL_GODMODE    = Color(255, 220, 50)
local COL_SCRIPTED   = Color(180, 80,  255)

local FONT_TITLE = "ZCNPCMgr_Title"
local FONT_LABEL = "ZCNPCMgr_Label"
local FONT_SMALL = "ZCNPCMgr_Small"
local FONT_MONO  = "ZCNPCMgr_Mono"

surface.CreateFont(FONT_TITLE, { font = "Tahoma", size = 17, weight = 700 })
surface.CreateFont(FONT_LABEL, { font = "Tahoma", size = 13, weight = 600 })
surface.CreateFont(FONT_SMALL, { font = "Tahoma", size = 11, weight = 400 })
surface.CreateFont(FONT_MONO,  { font = "Courier New", size = 11, weight = 400 })

-- ── State ─────────────────────────────────────────────────────────────────────

local npcData      = {}   -- array of NPC info tables from server
local selectedIdx  = nil  -- entIndex of selected NPC
local seqData      = {}   -- { [entIndex] = { "seq1", "seq2", ... } }
local seqTargets   = {}   -- { { target="guard01", seqEnt="ss_guard" }, ... }
local feedback     = ""
local feedbackTimer = 0
local aiEnabled    = true  -- mirrors server game.GetAIEnabled()

net.Receive("ZC_NPCManager_AIState", function()
    aiEnabled = net.ReadBool()
    if IsValid(ZC_NPCManagerPanel) then
        ZC_NPCManagerPanel:_UpdateAIButton()
    end
end)

local NPC_STATE_LABELS = {
    [0] = "None",   [1] = "Idle",    [2] = "Alert",
    [3] = "Combat", [4] = "Script",  [5] = "PlayDead",
    [6] = "Prone",  [7] = "Dead",
}

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
    btn.OnCursorEntered = function(s) s._hov = true  end
    btn.OnCursorExited  = function(s) s._hov = false end
    btn.DoClick = callback
    return btn
end

local function SendAction(action, entIndex, arg)
    net.Start("ZC_NPCManager_Action")
        net.WriteString(action)
        net.WriteUInt(entIndex or 0, 16)
        net.WriteString(arg or "")
    net.SendToServer()
end

local function GetSelected()
    if not selectedIdx then return nil end
    for _, n in ipairs(npcData) do
        if n.entIndex == selectedIdx then return n end
    end
    return nil
end

-- ── Net receives ──────────────────────────────────────────────────────────────

net.Receive("ZC_NPCManager_NPCList", function()
    npcData = {}
    local count = net.ReadUInt(16)
    for i = 1, count do
        table.insert(npcData, {
            entIndex  = net.ReadUInt(16),
            class     = net.ReadString(),
            name      = net.ReadString(),
            health    = net.ReadInt(16),
            maxHealth = net.ReadInt(16),
            state     = net.ReadUInt(4),
            schedule  = net.ReadInt(16),
            godmode   = net.ReadBool(),
            seqName   = net.ReadString(),
            pos       = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()),
        })
    end
    -- Keep selection valid
    local found = false
    for _, n in ipairs(npcData) do if n.entIndex == selectedIdx then found = true break end end
    if not found then selectedIdx = nil end

    if IsValid(ZC_NPCManagerPanel) then ZC_NPCManagerPanel:Rebuild() end
end)

net.Receive("ZC_NPCManager_SequenceList", function()
    local entIndex = net.ReadUInt(16)
    local count    = net.ReadUInt(16)
    local seqs     = {}
    for i = 1, count do table.insert(seqs, net.ReadString()) end
    seqData[entIndex] = seqs
    if IsValid(ZC_NPCManagerPanel) then ZC_NPCManagerPanel:RebuildDetail() end
end)

net.Receive("ZC_NPCManager_SeqTargets", function()
    seqTargets = {}
    local count = net.ReadUInt(8)
    for i = 1, count do
        table.insert(seqTargets, {
            target = net.ReadString(),
            seqEnt = net.ReadString(),
        })
    end
    if IsValid(ZC_NPCManagerPanel) then ZC_NPCManagerPanel:RebuildDetail() end
end)

net.Receive("ZC_NPCManager_Feedback", function()
    feedback      = net.ReadString()
    feedbackTimer = CurTime() + 4
    if IsValid(ZC_NPCManagerPanel) then ZC_NPCManagerPanel:UpdateFeedback() end
end)

net.Receive("ZC_NPCManager_Open", function()
    if not IsValid(ZC_NPCManagerPanel) then
        ZC_NPCManagerPanel = vgui.Create("ZC_NPCManager")
    else
        ZC_NPCManagerPanel:SetVisible(true)
        ZC_NPCManagerPanel:MakePopup()
    end
end)

-- ── Main panel ────────────────────────────────────────────────────────────────

local PANEL = {}

function PANEL:Init()
    self:SetSize(900, 600)
    self:Center()
    self:SetTitle("")
    self:SetDraggable(true)
    self:SetSizable(false)
    self:MakePopup()

    -- Header
    self._header = vgui.Create("DPanel", self)
    self._header:SetPos(0, 0)
    self._header:SetSize(900, 38)
    self._header.Paint = function(_, w, h)
        draw.RoundedBoxEx(6, 0, 0, w, h, COL_PANEL_DARK, true, true, false, false)
        draw.SimpleText("NPC Manager", FONT_TITLE, 12, h/2, COL_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = MakeButton(self._header, "✕", COL_DANGER, function() self:SetVisible(false) end)
    closeBtn:SetSize(28, 28)
    closeBtn:SetPos(900 - 32, 5)

    local refreshBtn = MakeButton(self._header, "↺ Refresh", COL_ACCENT_DIM, function()
        SendAction("refresh", 0, "")
    end)
    refreshBtn:SetSize(80, 28)
    refreshBtn:SetPos(900 - 116, 5)

    self._aiToggleBtn = MakeButton(self._header, "AI: ???", COL_ACCENT_DIM, function()
        Derma_Query(
            aiEnabled and "Disable AI? NPCs will freeze in place." or "Enable AI? NPCs will resume behaviour.",
            "Toggle AI",
            "Confirm", function() SendAction("ai_toggle", 0, "") end,
            "Cancel",  function() end
        )
    end)
    self._aiToggleBtn:SetSize(96, 28)
    self._aiToggleBtn:SetPos(900 - 116 - 100, 5)
    self:_UpdateAIButton()

    -- Column headers
    self._colHdr = vgui.Create("DPanel", self)
    self._colHdr:SetPos(0, 38)
    self._colHdr:SetSize(540, 20)
    self._colHdr.Paint = function(_, w, h)
        draw.SimpleText("CLASS",    FONT_SMALL, 8,   h/2, COL_TEXT_DIM, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
        draw.SimpleText("NAME",     FONT_SMALL, 170, h/2, COL_TEXT_DIM, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
        draw.SimpleText("HP",       FONT_SMALL, 290, h/2, COL_TEXT_DIM, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
        draw.SimpleText("STATE",    FONT_SMALL, 340, h/2, COL_TEXT_DIM, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
        draw.SimpleText("FLAGS",    FONT_SMALL, 420, h/2, COL_TEXT_DIM, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
    end

    -- NPC scroll list (left)
    self._scroll = vgui.Create("DScrollPanel", self)
    self._scroll:SetPos(0, 58)
    self._scroll:SetSize(540, 530)
    local sb = self._scroll:GetVBar()
    sb:SetWide(4)
    sb.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, COL_BORDER) end
    sb.btnUp.Paint   = function() end
    sb.btnDown.Paint = function() end
    sb.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, COL_ACCENT_DIM) end

    self._list = vgui.Create("DListLayout", self._scroll)
    self._list:SetWide(536)

    -- Detail panel (right)
    self._detail = vgui.Create("DPanel", self)
    self._detail:SetPos(544, 38)
    self._detail:SetSize(356, 550)
    self._detail.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, COL_PANEL_DARK)
    end

    self._detailTitle = vgui.Create("DLabel", self._detail)
    self._detailTitle:SetPos(8, 8)
    self._detailTitle:SetSize(340, 16)
    self._detailTitle:SetFont(FONT_SMALL)
    self._detailTitle:SetTextColor(COL_TEXT_DIM)
    self._detailTitle:SetText("SELECT AN NPC")

    -- Action buttons
    local bY = 30
    self._btnGod = MakeButton(self._detail, "Toggle Godmode", COL_WARN, function()
        local sel = GetSelected()
        if not sel then return end
        SendAction("godmode", sel.entIndex, "")
    end)
    self._btnGod:SetSize(160, 28)
    self._btnGod:SetPos(8, bY)

    self._btnTpTo = MakeButton(self._detail, "TP NPC to Me", COL_ACCENT_DIM, function()
        local sel = GetSelected()
        if not sel then return end
        SendAction("teleport", sel.entIndex, "")
    end)
    self._btnTpTo:SetSize(160, 28)
    self._btnTpTo:SetPos(8, bY + 32)

    self._btnTpHere = MakeButton(self._detail, "Go to NPC", COL_ACCENT_DIM, function()
        local sel = GetSelected()
        if not sel then return end
        SendAction("tphere", sel.entIndex, "")
    end)
    self._btnTpHere:SetSize(160, 28)
    self._btnTpHere:SetPos(8, bY + 64)

    self._btnKill = MakeButton(self._detail, "Kill", COL_DANGER, function()
        local sel = GetSelected()
        if not sel then return end
        SendAction("kill", sel.entIndex, "")
    end)
    self._btnKill:SetSize(76, 28)
    self._btnKill:SetPos(8, bY + 96)

    self._btnRemove = MakeButton(self._detail, "Remove", Color(140, 40, 40), function()
        local sel = GetSelected()
        if not sel then return end
        Derma_Query("Remove " .. sel.class .. "?", "Confirm",
            "Remove", function() SendAction("remove", sel.entIndex, "") end,
            "Cancel",  function() end)
    end)
    self._btnRemove:SetSize(76, 28)
    self._btnRemove:SetPos(88, bY + 96)

    -- Info labels
    self._infoPanel = vgui.Create("DPanel", self._detail)
    self._infoPanel:SetPos(8, bY + 132)
    self._infoPanel:SetSize(340, 80)
    self._infoPanel.Paint = function(_, w, h)
        draw.RoundedBox(3, 0, 0, w, h, COL_PANEL)
    end

    self._infoText = vgui.Create("DLabel", self._infoPanel)
    self._infoText:SetPos(6, 4)
    self._infoText:SetSize(328, 72)
    self._infoText:SetFont(FONT_MONO)
    self._infoText:SetTextColor(COL_TEXT_DIM)
    self._infoText:SetWrap(true)
    self._infoText:SetAutoStretchVertical(true)
    self._infoText:SetText("")

    -- Name assignment section
    local nameLbl = vgui.Create("DLabel", self._detail)
    nameLbl:SetPos(8, bY + 218)
    nameLbl:SetSize(340, 14)
    nameLbl:SetFont(FONT_SMALL)
    nameLbl:SetTextColor(COL_TEXT_DIM)
    nameLbl:SetText("SET TARGETNAME")

    local nameDiv = vgui.Create("DPanel", self._detail)
    nameDiv:SetPos(8, bY + 233)
    nameDiv:SetSize(340, 1)
    nameDiv.Paint = function(_, w, h) surface.SetDrawColor(COL_BORDER) surface.DrawRect(0,0,w,h) end

    self._nameEntry = vgui.Create("DTextEntry", self._detail)
    self._nameEntry:SetPos(8, bY + 238)
    self._nameEntry:SetSize(238, 24)
    self._nameEntry:SetFont(FONT_MONO)
    self._nameEntry:SetPlaceholderText("targetname…")
    self._nameEntry:SetTextColor(COL_TEXT)
    self._nameEntry.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, COL_PANEL)
        s:DrawTextEntryText(COL_TEXT, COL_ACCENT, COL_TEXT)
    end

    local setNameBtn = MakeButton(self._detail, "Set", COL_ACCENT, function()
        local sel = GetSelected()
        if not sel then return end
        SendAction("setname", sel.entIndex, self._nameEntry:GetValue())
    end)
    setNameBtn:SetSize(46, 24)
    setNameBtn:SetPos(250, bY + 238)

    local clearNameBtn = MakeButton(self._detail, "Clear", COL_DANGER, function()
        local sel = GetSelected()
        if not sel then return end
        self._nameEntry:SetValue("")
        SendAction("setname", sel.entIndex, "")
    end)
    clearNameBtn:SetSize(46, 24)
    clearNameBtn:SetPos(300, bY + 238)

    -- Available scripted_sequence targets — shown as clickable chips to auto-fill
    self._nameTargetContainer = vgui.Create("DPanel", self._detail)
    self._nameTargetContainer:SetPos(8, bY + 266)
    self._nameTargetContainer:SetSize(340, 24)
    self._nameTargetContainer.Paint = function() end

    -- Sequence section
    local seqLbl = vgui.Create("DLabel", self._detail)
    seqLbl:SetPos(8, bY + 296)
    seqLbl:SetSize(340, 14)
    seqLbl:SetFont(FONT_SMALL)
    seqLbl:SetTextColor(COL_TEXT_DIM)
    seqLbl:SetText("SEQUENCES")

    local seqDiv = vgui.Create("DPanel", self._detail)
    seqDiv:SetPos(8, bY + 311)
    seqDiv:SetSize(340, 1)
    seqDiv.Paint = function(_, w, h) surface.SetDrawColor(COL_BORDER) surface.DrawRect(0,0,w,h) end

    local loadSeqBtn = MakeButton(self._detail, "Load Sequences", COL_ACCENT_DIM, function()
        local sel = GetSelected()
        if not sel then return end
        SendAction("getseqs", sel.entIndex, "")
    end)
    loadSeqBtn:SetSize(140, 24)
    loadSeqBtn:SetPos(8, bY + 316)

    -- Sequence search + play entry
    self._seqEntry = vgui.Create("DTextEntry", self._detail)
    self._seqEntry:SetPos(8, bY + 346)
    self._seqEntry:SetSize(260, 24)
    self._seqEntry:SetFont(FONT_MONO)
    self._seqEntry:SetPlaceholderText("sequence name…")
    self._seqEntry:SetTextColor(COL_TEXT)
    self._seqEntry.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, COL_PANEL)
        s:DrawTextEntryText(COL_TEXT, COL_ACCENT, COL_TEXT)
    end

    local playBtn = MakeButton(self._detail, "▶ Play", COL_SUCCESS, function()
        local sel = GetSelected()
        if not sel then return end
        local name = string.Trim(self._seqEntry:GetValue())
        if name == "" then return end
        SendAction("playseq", sel.entIndex, name)
    end)
    playBtn:SetSize(72, 24)
    playBtn:SetPos(274, bY + 346)

    -- Sequence browser button
    local browseSeqBtn = MakeButton(self._detail, "🔍 Browse", COL_ACCENT_DIM, function()
        local sel = GetSelected()
        if not sel then return end
        local seqs = seqData[sel.entIndex]
        if not seqs or #seqs == 0 then
            feedback = "Load sequences first."
            feedbackTimer = CurTime() + 3
            self:UpdateFeedback()
            return
        end
        ZC_OpenSequenceBrowser(seqs, function(name)
            self._seqEntry:SetValue(name)
        end)
    end)
    browseSeqBtn:SetSize(340, 24)
    browseSeqBtn:SetPos(8, bY + 374)

    -- Sequence list (scrollable, small)
    self._seqScroll = vgui.Create("DScrollPanel", self._detail)
    self._seqScroll:SetPos(8, bY + 402)
    self._seqScroll:SetSize(340, 120)
    local sb2 = self._seqScroll:GetVBar()
    sb2:SetWide(4)
    sb2.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, COL_BORDER) end
    sb2.btnUp.Paint   = function() end
    sb2.btnDown.Paint = function() end
    sb2.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, COL_ACCENT_DIM) end

    self._seqList = vgui.Create("DListLayout", self._seqScroll)
    self._seqList:SetWide(336)

    -- Feedback bar
    self._feedbackLabel = vgui.Create("DLabel", self)
    self._feedbackLabel:SetPos(4, 584)
    self._feedbackLabel:SetSize(540, 14)
    self._feedbackLabel:SetFont(FONT_SMALL)
    self._feedbackLabel:SetTextColor(COL_SUCCESS)
    self._feedbackLabel:SetText("")
end

function PANEL:_UpdateAIButton()
    if not IsValid(self._aiToggleBtn) then return end
    if aiEnabled then
        self._aiToggleBtn._text = "AI: ON"
        self._aiToggleBtn._col  = Color(40, 130, 60)
    else
        self._aiToggleBtn._text = "AI: OFF"
        self._aiToggleBtn._col  = Color(130, 50, 50)
    end
end

function PANEL:Rebuild()
    if not IsValid(self._list) then return end
    self._list:Clear()

    local lp = LocalPlayer()

    for _, n in ipairs(npcData) do
        local nd  = n
        local sel = selectedIdx == nd.entIndex
        local row = vgui.Create("DButton", self._list)
        row:SetSize(536, 36)
        row:SetText("")
        row._hov = false

        local hpFrac = nd.maxHealth > 0 and math.Clamp(nd.health / nd.maxHealth, 0, 1) or 0
        local hpCol  = Color(
            Lerp(hpFrac, 200, 60),
            Lerp(hpFrac, 60, 180),
            60
        )
        local stateLabel = NPC_STATE_LABELS[nd.state] or "?"
        local dist = math.floor(nd.pos:Distance(lp:GetPos()))

        row.Paint = function(_, w, h)
            local bg = sel and COL_SEL or (row._hov and COL_HOV or Color(0,0,0,0))
            draw.RoundedBox(3, 1, 1, w-2, h-2, bg)

            -- Class
            draw.SimpleText(nd.class, FONT_MONO, 8, h/2, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Name (dim if empty)
            local nameStr = nd.name ~= "" and nd.name or "—"
            draw.SimpleText(nameStr, FONT_SMALL, 170, h/2, nd.name ~= "" and COL_TEXT or COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- HP bar
            local bW = 40
            surface.SetDrawColor(COL_BORDER)
            surface.DrawRect(290, h/2 - 4, bW, 8)
            surface.SetDrawColor(hpCol)
            surface.DrawRect(290, h/2 - 4, math.floor(bW * hpFrac), 8)

            -- State
            draw.SimpleText(stateLabel, FONT_SMALL, 340, h/2, nd.state == 3 and COL_DANGER or COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Flags
            local fx = 420
            if nd.godmode then
                draw.SimpleText("GOD", FONT_SMALL, fx, h/2, COL_GODMODE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                fx = fx + 32
            end
            if nd.seqName ~= "" then
                draw.SimpleText("SCR", FONT_SMALL, fx, h/2, COL_SCRIPTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                fx = fx + 32
            end

            -- Distance
            draw.SimpleText(dist .. "u", FONT_SMALL, 526, h/2, COL_TEXT_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        row.OnCursorEntered = function(s) s._hov = true  end
        row.OnCursorExited  = function(s) s._hov = false end
        row.DoClick = function()
            selectedIdx = nd.entIndex
            self:Rebuild()
            self:RebuildDetail()
        end

        self._list:Add(row)
    end

    self:RebuildDetail()
end

function PANEL:RebuildDetail()
    local sel = GetSelected()
    if not sel then
        if IsValid(self._detailTitle) then self._detailTitle:SetText("SELECT AN NPC") end
        if IsValid(self._infoText)    then self._infoText:SetText("") end
        if IsValid(self._seqList)     then self._seqList:Clear() end
        return
    end

    if IsValid(self._detailTitle) then
        self._detailTitle:SetText(string.upper(sel.class) .. (sel.name ~= "" and ("  [" .. sel.name .. "]") or ""))
    end

    -- Populate name entry with current name
    if IsValid(self._nameEntry) then
        self._nameEntry:SetValue(sel.name or "")
    end

    -- Rebuild target chips — available scripted_sequence targetnames
    if IsValid(self._nameTargetContainer) then
        self._nameTargetContainer:Clear()
        local x = 0
        for _, t in ipairs(seqTargets) do
            local tname = t.target
            local ssname = t.seqEnt
            surface.SetFont(FONT_SMALL)
            local tw = surface.GetTextSize(tname)
            local chipW = tw + 16
            local chip = vgui.Create("DButton", self._nameTargetContainer)
            chip:SetSize(chipW, 22)
            chip:SetPos(x, 1)
            chip:SetText("")
            chip._hov = false
            chip.Paint = function(_, w, h)
                draw.RoundedBox(3, 0, 0, w, h, chip._hov and COL_SCRIPTED or Color(80, 40, 120))
                draw.SimpleText(tname, FONT_SMALL, w/2, h/2, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            chip.OnCursorEntered = function(s) s._hov = true  end
            chip.OnCursorExited  = function(s) s._hov = false end
            chip:SetTooltip("From: " .. ssname)
            chip.DoClick = function()
                if IsValid(self._nameEntry) then self._nameEntry:SetValue(tname) end
            end
            self._nameTargetContainer:Add(chip)
            x = x + chipW + 4
        end
        if #seqTargets == 0 then
            local lbl = vgui.Create("DLabel", self._nameTargetContainer)
            lbl:SetSize(340, 22)
            lbl:SetFont(FONT_SMALL)
            lbl:SetTextColor(COL_TEXT_DIM)
            lbl:SetText("No scripted_sequence entities on this map.")
            self._nameTargetContainer:Add(lbl)
        end
    end

    -- Info block
    local stateStr = NPC_STATE_LABELS[sel.state] or "?"
    local info = string.format(
        "HP: %d / %d\nState: %s\nSchedule: %d\nGodmode: %s\nScript: %s",
        sel.health, sel.maxHealth,
        stateStr,
        sel.schedule,
        sel.godmode and "ON" or "off",
        sel.seqName ~= "" and sel.seqName or "none"
    )
    if IsValid(self._infoText) then self._infoText:SetText(info) end

    -- Sequence list (if loaded)
    if IsValid(self._seqList) then
        self._seqList:Clear()
        local seqs = seqData[sel.entIndex]
        if seqs then
            local query = IsValid(self._seqEntry) and string.lower(self._seqEntry:GetValue()) or ""
            for _, name in ipairs(seqs) do
                if query ~= "" and not string.find(string.lower(name), query, 1, true) then continue end
                local sn = name
                local btn = vgui.Create("DButton", self._seqList)
                btn:SetSize(336, 20)
                btn:SetText("")
                btn._hov = false
                btn.Paint = function(_, w, h)
                    if btn._hov then draw.RoundedBox(2, 0, 0, w, h, COL_HOV) end
                    draw.SimpleText(sn, FONT_MONO, 4, h/2, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
                btn.OnCursorEntered = function(s) s._hov = true  end
                btn.OnCursorExited  = function(s) s._hov = false end
                btn.DoClick = function()
                    if IsValid(self._seqEntry) then self._seqEntry:SetValue(sn) end
                end
                self._seqList:Add(btn)
            end
        end
    end
end

function PANEL:UpdateFeedback()
    if IsValid(self._feedbackLabel) then
        self._feedbackLabel:SetText(feedback)
    end
end

function PANEL:Think()
    if feedbackTimer > 0 and CurTime() > feedbackTimer then
        feedback = ""
        feedbackTimer = 0
        if IsValid(self._feedbackLabel) then self._feedbackLabel:SetText("") end
    end
    -- Live-filter sequence list as user types
    if IsValid(self._seqEntry) then
        local q = self._seqEntry:GetValue()
        if q ~= (self._lastSeqQuery or "") then
            self._lastSeqQuery = q
            self:RebuildDetail()
        end
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, COL_BG)
    surface.SetDrawColor(COL_BORDER)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

vgui.Register("ZC_NPCManager", PANEL, "DFrame")

-- ── Sequence browser popup ────────────────────────────────────────────────────

function ZC_OpenSequenceBrowser(seqs, callback)
    if IsValid(ZC_SeqBrowserPanel) then ZC_SeqBrowserPanel:Remove() end

    local W, H = 400, 520
    local frame = vgui.Create("DFrame")
    frame:SetSize(W, H)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:MakePopup()
    ZC_SeqBrowserPanel = frame

    frame.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL_BG)
        surface.SetDrawColor(COL_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local hdr = vgui.Create("DPanel", frame)
    hdr:SetPos(0, 0)
    hdr:SetSize(W, 36)
    hdr.Paint = function(_, w, h)
        draw.RoundedBoxEx(6, 0, 0, w, h, COL_PANEL_DARK, true, true, false, false)
        draw.SimpleText("Sequence Browser  (" .. #seqs .. " sequences)", FONT_TITLE, 12, h/2, COL_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = MakeButton(hdr, "✕", COL_DANGER, function() frame:Remove() end)
    closeBtn:SetSize(28, 26)
    closeBtn:SetPos(W - 32, 5)

    local searchEntry = vgui.Create("DTextEntry", frame)
    searchEntry:SetPos(6, 42)
    searchEntry:SetSize(W - 12, 26)
    searchEntry:SetFont(FONT_MONO)
    searchEntry:SetPlaceholderText("Search sequences…")
    searchEntry:SetTextColor(COL_TEXT)
    searchEntry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, COL_PANEL)
        s:DrawTextEntryText(COL_TEXT, COL_ACCENT, COL_TEXT)
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(6, 74)
    scroll:SetSize(W - 12, H - 80)
    local sb = scroll:GetVBar()
    sb:SetWide(4)
    sb.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, COL_BORDER) end
    sb.btnUp.Paint   = function() end
    sb.btnDown.Paint = function() end
    sb.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, COL_ACCENT_DIM) end

    local resultList = vgui.Create("DListLayout", scroll)
    resultList:SetWide(W - 20)

    local function Populate(query)
        resultList:Clear()
        query = string.lower(string.Trim(query or ""))
        for _, name in ipairs(seqs) do
            if query ~= "" and not string.find(string.lower(name), query, 1, true) then continue end
            local sn = name
            local btn = vgui.Create("DButton", resultList)
            btn:SetSize(W - 20, 24)
            btn:SetText("")
            btn._hov = false
            btn.Paint = function(_, w, h)
                if btn._hov then draw.RoundedBox(2, 0, 0, w, h, COL_HOV) end
                draw.SimpleText(sn, FONT_MONO, 6, h/2, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            btn.OnCursorEntered = function(s) s._hov = true  end
            btn.OnCursorExited  = function(s) s._hov = false end
            btn.DoClick = function()
                callback(sn)
                frame:Remove()
            end
            resultList:Add(btn)
        end
    end

    searchEntry.OnChange = function(s) Populate(s:GetValue()) end
    Populate("")
end
