-- Map Voting System - Client Side

if SERVER then return end

local COL_BG = Color(18, 20, 26)
local COL_PANEL = Color(26, 29, 38)
local COL_BORDER = Color(45, 50, 65)
local COL_ACCENT = Color(100, 180, 255)
local COL_ACCENT_DIM = Color(40, 80, 140)
local COL_TEXT = Color(220, 225, 235)
local COL_TEXT_DIM = Color(120, 130, 150)

local FONT_TITLE = "MapVote_Title"
local FONT_LABEL = "MapVote_Label"
local FONT_SMALL = "MapVote_Small"

surface.CreateFont(FONT_TITLE, { font = "Tahoma", size = 18, weight = 700 })
surface.CreateFont(FONT_LABEL, { font = "Tahoma", size = 13, weight = 600 })
surface.CreateFont(FONT_SMALL, { font = "Tahoma", size = 11, weight = 400 })

local PAD = 12
local HDR_H = 48
local ROW_GAP = 8
local ROW_H = 52
local ICON_SIZE = 32

local MapVotingFrame = nil
local AvailableMaps = {}
local VoteCounts = {}
local TotalPlayers = 0
local PlayerVotedFor = nil

local MAP_ICON_PRESETS = {
    ["gm_construct"] = "maps/thumb/gm_construct.png",
    ["gm_flatgrass"] = "maps/thumb/gm_flatgrass.png",
    ["gm_flatgrass_fxp"] = "maps/thumb/gm_flatgrass_fxp.png"
}

local function GetMapIconPath(mapname)
    return MAP_ICON_PRESETS[mapname] or "icon16/world.png"
end

local function CastVote(mapname)
    if not mapname or mapname == "" then return end
    if PlayerVotedFor == mapname then return end

    net.Start("MapVote_Cast")
    net.WriteString(mapname)
    net.SendToServer()
end

local function CalculatePercent(votes)
    if TotalPlayers <= 0 then
        return 0
    end

    return math.floor((votes / TotalPlayers) * 100)
end

local function UpdateVoteCounts()
    if not IsValid(MapVotingFrame) then return end

    local list = MapVotingFrame.MapList
    if not IsValid(list) then return end

    for _, row in ipairs(list:GetChildren()) do
        if IsValid(row) and row.MapName then
            local votes = VoteCounts[row.MapName] or 0
            local pct = CalculatePercent(votes)

            if IsValid(row.VoteLabel) then
                row.VoteLabel:SetText(votes .. " votes")
            end

            if IsValid(row.PctLabel) then
                row.PctLabel:SetText(pct .. "%")
            end

            if IsValid(row.VoteBtn) then
                local votedForThis = PlayerVotedFor == row.MapName
                row.VoteBtn:SetText(votedForThis and "SELECTED" or (PlayerVotedFor and "CHANGE" or "VOTE"))
            end
        end
    end
end

local function CreateVotingMenu()
    if IsValid(MapVotingFrame) then
        MapVotingFrame:Remove()
    end

    MapVotingFrame = vgui.Create("DFrame")
    MapVotingFrame:SetSize(560, 620)
    MapVotingFrame:Center()
    MapVotingFrame:SetDraggable(true)
    MapVotingFrame:ShowCloseButton(true)
    MapVotingFrame:SetTitle("")
    MapVotingFrame:SetDeleteOnClose(true)
    MapVotingFrame:MakePopup()
    MapVotingFrame:SetMouseInputEnabled(true)
    MapVotingFrame:SetKeyboardInputEnabled(false)

    function MapVotingFrame:OnRemove()
        gui.EnableScreenClicker(false)
    end

    function MapVotingFrame:Think()
        if self:IsKeyboardInputEnabled() then
            self:SetKeyboardInputEnabled(false)
        end

        if not vgui.CursorVisible() then
            gui.EnableScreenClicker(true)
        end
    end

    gui.EnableScreenClicker(true)

    function MapVotingFrame:Paint(w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL_BG)
        draw.RoundedBoxEx(4, 0, 0, w, HDR_H, COL_ACCENT, true, true, false, false)
        draw.SimpleText("MAP VOTE", FONT_TITLE, w / 2, 10, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("Vote can be changed any time. Type !mapvote to reopen", FONT_SMALL, w / 2, 30, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local Scroll = vgui.Create("DScrollPanel", MapVotingFrame)
    Scroll:Dock(FILL)
    Scroll:DockMargin(0, HDR_H, 0, 0)
    Scroll.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL_BG)
    end

    local VBar = Scroll:GetVBar()
    VBar:SetWidth(6)
    VBar.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, COL_BORDER)
    end
    VBar.btnUp.Paint = function() end
    VBar.btnDown.Paint = function() end
    VBar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, COL_ACCENT)
    end

    local List = vgui.Create("DListLayout", Scroll)
    List:Dock(FILL)
    List:DockMargin(PAD, PAD, PAD, PAD)
    if List.SetSpacing then
        List:SetSpacing(ROW_GAP)
    end
    MapVotingFrame.MapList = List

    for _, mapname in ipairs(AvailableMaps) do
        local row = vgui.Create("DPanel", List)
        row:SetHeight(ROW_H)
        row:DockMargin(0, 0, 0, ROW_GAP)
        row.MapName = mapname

        function row:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, COL_PANEL)
            surface.SetDrawColor(COL_BORDER)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local icon = vgui.Create("DImage", row)
        icon:Dock(LEFT)
        icon:DockMargin(PAD, (ROW_H - ICON_SIZE) / 2, PAD, (ROW_H - ICON_SIZE) / 2)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetImage(GetMapIconPath(mapname))

        local nameLabel = vgui.Create("DLabel", row)
        nameLabel:SetFont(FONT_LABEL)
        nameLabel:SetText(mapname)
        nameLabel:SetTextColor(COL_TEXT)
        nameLabel:Dock(LEFT)
        nameLabel:SetWide(220)

        local voteLabel = vgui.Create("DLabel", row)
        voteLabel:SetFont(FONT_SMALL)
        voteLabel:SetText("0 votes")
        voteLabel:SetTextColor(COL_TEXT_DIM)
        voteLabel:Dock(LEFT)
        voteLabel:SetWide(80)
        row.VoteLabel = voteLabel

        local pctLabel = vgui.Create("DLabel", row)
        pctLabel:SetFont(FONT_SMALL)
        pctLabel:SetText("0%")
        pctLabel:SetTextColor(COL_TEXT_DIM)
        pctLabel:Dock(LEFT)
        pctLabel:SetWide(48)
        row.PctLabel = pctLabel

        local voteBtn = vgui.Create("DButton", row)
        voteBtn:SetText("VOTE")
        voteBtn:SetFont(FONT_SMALL)
        voteBtn:Dock(RIGHT)
        voteBtn:DockMargin(0, 10, PAD, 10)
        voteBtn:SetWide(84)
        row.VoteBtn = voteBtn

        function voteBtn:Paint(w, h)
            local isSelected = PlayerVotedFor == mapname
            local col = isSelected and Color(70, 145, 90) or COL_ACCENT_DIM
            if self:IsHovered() then
                col = isSelected and Color(90, 175, 110) or COL_ACCENT
            end

            draw.RoundedBox(4, 0, 0, w, h, col)
            draw.SimpleText(self:GetText(), FONT_SMALL, w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return true
        end

        voteBtn.DoClick = function()
            CastVote(mapname)
        end
    end

    UpdateVoteCounts()
end

net.Receive("MapVote_StartVote", function()
    AvailableMaps = net.ReadTable() or {}
    VoteCounts = {}
    TotalPlayers = #player.GetAll()
    PlayerVotedFor = nil

    for _, mapname in ipairs(AvailableMaps) do
        VoteCounts[mapname] = 0
    end

    CreateVotingMenu()
end)

net.Receive("MapVote_OpenMenu", function()
    AvailableMaps = net.ReadTable() or {}
    VoteCounts = net.ReadTable() or {}
    TotalPlayers = net.ReadInt(32)
    PlayerVotedFor = net.ReadString()

    if PlayerVotedFor == "" then
        PlayerVotedFor = nil
    end

    CreateVotingMenu()
end)

net.Receive("MapVote_UpdateCounts", function()
    VoteCounts = net.ReadTable() or {}
    TotalPlayers = net.ReadInt(32)
    UpdateVoteCounts()
end)

net.Receive("MapVote_CastSuccess", function()
    PlayerVotedFor = net.ReadString()
    UpdateVoteCounts()
end)

concommand.Add("mapvote", function()
    net.Start("MapVote_OpenMenu")
    net.SendToServer()
end)

print("[MapVote] Client map voting loaded")
