-- Map Voting System - Client Side
-- Nexus-library styled. Vote menu + admin map manager.

if SERVER then return end

-- ─────────────────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────────────────

local VoteFrame        = nil
local AdminFrame       = nil
local AvailableMaps    = {}
local VoteCounts       = {}
local TotalPlayers     = 0
local PlayerVotedFor   = nil
local VoteEndTime      = 0    -- CurTime() when the vote expires
local EarlyWinMap      = nil  -- set when server broadcasts 70% countdown msg
local IsTiebreaker     = false -- true during secondary tiebreaker round

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function NexusReady()
    return Nexus and Nexus.Colors and Nexus.Colors.Background
end

local function C(key) return NexusReady() and Nexus.Colors[key] or Color(0,0,0) end
local function Scale(v) return NexusReady() and Nexus:Scale(v) or v end
local function Font(sz, bold) return NexusReady() and Nexus:GetFont(sz, nil, bold) or "DermaDefault" end

local function CalcPct(votes)
    if TotalPlayers <= 0 then return 0 end
    return math.floor((votes / TotalPlayers) * 100)
end

local function CastVote(mapname)
    if not mapname or mapname == "" then return end
    if PlayerVotedFor == mapname then return end
    net.Start("MapVote_Cast")
    net.WriteString(mapname)
    net.SendToServer()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Vote menu: update live counts without rebuilding
-- ─────────────────────────────────────────────────────────────────────────────

local function UpdateVoteCounts()
    if not IsValid(VoteFrame) or not VoteFrame.Rows then return end
    for _, row in ipairs(VoteFrame.Rows) do
        if IsValid(row) and row.MapName then
            local votes = VoteCounts[row.MapName] or 0
            local pct   = CalcPct(votes)
            local needed = TotalPlayers > 0
                and math.ceil(TotalPlayers * (IsTiebreaker and 0.5 or 0.7))
                or 1
            if IsValid(row.VoteInfo) then
                row.VoteInfo:SetText(votes .. " / " .. needed .. "   (" .. pct .. "%)")
            end
            if IsValid(row.VoteBtn) then
                local sel = PlayerVotedFor == row.MapName
                row.VoteBtn:SetText(sel and "SELECTED" or (PlayerVotedFor and "CHANGE" or "VOTE"))
                row.VoteBtn:SetColor(sel and C("Green") or C("Primary"))
            end
            -- progress bar fill stored on row
            row.BarPct = pct / 100
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Vote menu: build
-- ─────────────────────────────────────────────────────────────────────────────

local function CreateVotingMenu()
    if IsValid(VoteFrame) then VoteFrame:Remove() end
    if not NexusReady() then
        print("[MapVote] Nexus not ready, cannot open menu")
        return
    end

    local W, H    = Scale(520), Scale(640)
    local PAD     = Scale(10)
    local ROW_H   = Scale(48)
    local BAR_H   = Scale(4)
    local TIMER_H = Scale(32)

    VoteFrame = vgui.Create("Nexus:Frame")
    VoteFrame:SetSize(W, H)
    VoteFrame:Center()
    VoteFrame.Title = IsTiebreaker and "TIEBREAKER VOTE" or "MAP VOTE"
    VoteFrame:MakePopup()
    VoteFrame.Rows = {}

    -- Timer bar at top (below header, above scroll)
    local timerPanel = vgui.Create("DPanel", VoteFrame)
    timerPanel:Dock(TOP)
    timerPanel:SetTall(TIMER_H)
    timerPanel:DockMargin(PAD, 0, PAD, PAD)
    timerPanel.Paint = function(s, w, h)
        draw.RoundedBox(Scale(4), 0, 0, w, h, C("Secondary"))
        local remaining = math.max(0, VoteEndTime - CurTime())
        local total     = MapVoting_Duration or 60
        local frac      = remaining / total
        -- progress bar
        local barCol = IsTiebreaker and C("Orange") or C("Primary")
        draw.RoundedBox(Scale(4), 0, 0, w * frac, h, barCol)
        -- text
        local threshold = IsTiebreaker and "50%" or "70%"
        local txt = EarlyWinMap
            and ("70% reached! Ending in " .. math.ceil(remaining) .. "s")
            or  (IsTiebreaker
                and ("TIEBREAKER — " .. threshold .. " required — " .. math.ceil(remaining) .. "s")
                or  ("Time remaining: " .. math.ceil(remaining) .. "s"))
        draw.SimpleText(txt, Font(14, true), w / 2, h / 2, C("Text"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local scroll = vgui.Create("Nexus:ScrollPanel", VoteFrame)
    scroll:Dock(FILL)
    scroll:DockMargin(PAD, 0, PAD, PAD)

    local list = vgui.Create("DListLayout", scroll)
    list:Dock(FILL)

    for _, mapname in ipairs(AvailableMaps) do
        local row = vgui.Create("DPanel", list)
        row:SetTall(ROW_H + BAR_H + Scale(4))
        row:DockMargin(0, 0, 0, Scale(4))
        row.MapName = mapname
        row.BarPct  = CalcPct(VoteCounts[mapname] or 0) / 100

        row.Paint = function(s, w, h)
            draw.RoundedBox(Scale(6), 0, 0, w, h, C("Secondary"))
            -- progress fill
            local fillW = math.max(Scale(6), w * (s.BarPct or 0))
            draw.RoundedBox(Scale(4), 0, h - BAR_H, fillW, BAR_H, C("Primary"))
        end

        local nameLabel = vgui.Create("DLabel", row)
        nameLabel:SetFont(Font(16, true))
        nameLabel:SetText(mapname)
        nameLabel:SetTextColor(C("Text"))
        nameLabel:Dock(LEFT)
        nameLabel:DockMargin(PAD, 0, 0, BAR_H)
        nameLabel:SetWide(Scale(200))
        nameLabel:SetTall(ROW_H)

        local voteInfo = vgui.Create("DLabel", row)
        voteInfo:SetFont(Font(13))
        voteInfo:SetText("0 / 1   (0%)")
        voteInfo:SetTextColor(C("Text"))
        voteInfo:Dock(LEFT)
        voteInfo:DockMargin(0, 0, 0, BAR_H)
        voteInfo:SetWide(Scale(140))
        voteInfo:SetTall(ROW_H)
        row.VoteInfo = voteInfo

        local btn = vgui.Create("Nexus:Button", row)
        btn:SetText("VOTE")
        btn:SetFont(Font(13, true))
        btn:SetColor(C("Primary"))
        btn:Dock(RIGHT)
        btn:DockMargin(0, Scale(8), PAD, Scale(8) + BAR_H)
        btn:SetWide(Scale(80))
        btn:SetTall(ROW_H - Scale(16))
        btn.DoClick = function() CastVote(mapname) end
        row.VoteBtn = btn

        table.insert(VoteFrame.Rows, row)
    end

    UpdateVoteCounts()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Admin map manager: side-by-side lists
-- ─────────────────────────────────────────────────────────────────────────────

local AllServerMaps = {}
local RTVMaps       = {}

local function RefreshAdminLists()
    if not IsValid(AdminFrame) then return end

    -- Left list: all server maps not on RTV
    local left = AdminFrame.LeftList
    if IsValid(left) then
        left:Clear()
        for _, m in ipairs(AllServerMaps) do
            if not table.HasValue(RTVMaps, m) then
                local line = left:AddLine(m)
                line.OnSelect = function()
                    AdminFrame.Selected = m
                    AdminFrame.SelectedSide = "left"
                end
            end
        end
    end

    -- Right list: maps currently on RTV
    local right = AdminFrame.RightList
    if IsValid(right) then
        right:Clear()
        for _, m in ipairs(RTVMaps) do
            local line = right:AddLine(m)
            line.OnSelect = function()
                AdminFrame.Selected = m
                AdminFrame.SelectedSide = "right"
            end
        end
    end
end

local function CreateAdminPanel(allMaps, rtvMaps)
    AllServerMaps = allMaps
    RTVMaps       = rtvMaps

    if IsValid(AdminFrame) then AdminFrame:Remove() end
    if not NexusReady() then return end

    local W, H  = Scale(700), Scale(540)
    local PAD   = Scale(10)
    local COL_W = (W - PAD * 3) / 2

    AdminFrame = vgui.Create("Nexus:Frame")
    AdminFrame:SetSize(W, H)
    AdminFrame:Center()
    AdminFrame.Title = "MAP MANAGER"
    AdminFrame:MakePopup()
    AdminFrame.Selected     = nil
    AdminFrame.SelectedSide = nil

    -- ── Header row: column titles + buttons ──────────────────────────────────
    local hdr = vgui.Create("DPanel", AdminFrame)
    hdr:Dock(TOP)
    hdr:SetTall(Scale(36))
    hdr:DockMargin(PAD, 0, PAD, Scale(4))
    hdr.Paint = function(s, w, h)
        draw.RoundedBox(Scale(4), 0, 0, w, h, C("Secondary"))
        draw.SimpleText("ALL SERVER MAPS", Font(13, true), COL_W / 2, h / 2, C("Text"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("RTV MAP POOL", Font(13, true), COL_W + PAD + COL_W / 2, h / 2, C("Text"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ── Lists ─────────────────────────────────────────────────────────────────
    local listArea = vgui.Create("DPanel", AdminFrame)
    listArea:Dock(FILL)
    listArea:DockMargin(PAD, 0, PAD, 0)
    listArea.Paint = function() end

    -- DListView has its own scrollbar; parent it directly so Dock(FILL) works.
    local leftList = vgui.Create("DListView", listArea)
    leftList:SetWide(COL_W)
    leftList:Dock(LEFT)
    leftList:AddColumn("Map")
    leftList:SetMultiSelect(false)
    AdminFrame.LeftList = leftList
    leftList.OnRowSelected = function(_, _, line)
        AdminFrame.Selected     = line:GetColumnText(1)
        AdminFrame.SelectedSide = "left"
    end

    local mid = vgui.Create("DPanel", listArea)
    mid:SetWide(Scale(80))
    mid:Dock(LEFT)
    mid:DockMargin(PAD, 0, PAD, 0)
    mid.Paint = function() end

    local addBtn = vgui.Create("Nexus:Button", mid)
    addBtn:SetText("ADD →")
    addBtn:SetFont(Font(12, true))
    addBtn:SetColor(C("Green"))
    addBtn:SetWide(Scale(80))
    addBtn:SetTall(Scale(36))
    addBtn:SetPos(0, Scale(160))
    addBtn.DoClick = function()
        if not AdminFrame.Selected or AdminFrame.SelectedSide ~= "left" then return end
        net.Start("MapVote_AdminAddMap")
        net.WriteString(AdminFrame.Selected)
        net.SendToServer()
        AdminFrame.Selected = nil
    end

    local remBtn = vgui.Create("Nexus:Button", mid)
    remBtn:SetText("← REM")
    remBtn:SetFont(Font(12, true))
    remBtn:SetColor(C("Red"))
    remBtn:SetWide(Scale(80))
    remBtn:SetTall(Scale(36))
    remBtn:SetPos(0, Scale(204))
    remBtn.DoClick = function()
        if not AdminFrame.Selected or AdminFrame.SelectedSide ~= "right" then return end
        net.Start("MapVote_AdminRemoveMap")
        net.WriteString(AdminFrame.Selected)
        net.SendToServer()
        AdminFrame.Selected = nil
    end

    local rightList = vgui.Create("DListView", listArea)
    rightList:Dock(FILL)
    rightList:AddColumn("Map")
    rightList:SetMultiSelect(false)
    AdminFrame.RightList = rightList
    rightList.OnRowSelected = function(_, _, line)
        AdminFrame.Selected     = line:GetColumnText(1)
        AdminFrame.SelectedSide = "right"
    end

    RefreshAdminLists()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Net receivers
-- ─────────────────────────────────────────────────────────────────────────────

MapVoting_Duration = 60  -- updated by StartVote message, used for timer bar

net.Receive("MapVote_StartVote", function()
    AvailableMaps  = net.ReadTable() or {}
    MapVoting_Duration = net.ReadInt(32)
    VoteEndTime    = CurTime() + MapVoting_Duration
    VoteCounts     = {}
    TotalPlayers   = #player.GetAll()
    PlayerVotedFor = nil
    EarlyWinMap    = nil
    IsTiebreaker   = false

    for _, m in ipairs(AvailableMaps) do VoteCounts[m] = 0 end
    CreateVotingMenu()
end)

net.Receive("MapVote_TiebreakerStart", function()
    AvailableMaps  = net.ReadTable() or {}
    MapVoting_Duration = net.ReadInt(32)
    VoteEndTime    = CurTime() + MapVoting_Duration
    VoteCounts     = {}
    TotalPlayers   = #player.GetAll()
    PlayerVotedFor = nil
    EarlyWinMap    = nil
    IsTiebreaker   = true

    for _, m in ipairs(AvailableMaps) do VoteCounts[m] = 0 end
    CreateVotingMenu()
end)

net.Receive("MapVote_OpenMenu", function()
    AvailableMaps  = net.ReadTable() or {}
    VoteCounts     = net.ReadTable() or {}
    TotalPlayers   = net.ReadInt(32)
    PlayerVotedFor = net.ReadString()
    local endTime  = net.ReadFloat()
    VoteEndTime    = endTime > 0 and endTime or (CurTime() + 60)

    if PlayerVotedFor == "" then PlayerVotedFor = nil end
    CreateVotingMenu()
end)

net.Receive("MapVote_UpdateCounts", function()
    VoteCounts   = net.ReadTable() or {}
    TotalPlayers = net.ReadInt(32)
    UpdateVoteCounts()
end)

net.Receive("MapVote_CastSuccess", function()
    PlayerVotedFor = net.ReadString()
    UpdateVoteCounts()
end)

net.Receive("MapVote_OpenAdminPanel", function()
    local allMaps = net.ReadTable() or {}
    local rtvMaps = net.ReadTable() or {}
    CreateAdminPanel(allMaps, rtvMaps)
end)

-- Server replies to add/remove with updated RTV list
net.Receive("MapVote_AdminResult", function()
    local ok  = net.ReadBool()
    local msg = net.ReadString()
    RTVMaps   = net.ReadTable() or {}
    chat.AddText(ok and Color(100,255,100) or Color(255,100,100), "[MapVote] " .. msg)
    RefreshAdminLists()
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Console commands
-- ─────────────────────────────────────────────────────────────────────────────

concommand.Add("mapvote", function()
    net.Start("MapVote_OpenMenu")
    net.SendToServer()
end)

concommand.Add("mapvote_admin", function()
    if not LocalPlayer():IsAdmin() then
        chat.AddText(Color(255,100,100), "[MapVote] Admins only.")
        return
    end
    net.Start("MapVote_OpenAdminPanel")
    net.SendToServer()
end)

print("[MapVote] Client map voting loaded")
