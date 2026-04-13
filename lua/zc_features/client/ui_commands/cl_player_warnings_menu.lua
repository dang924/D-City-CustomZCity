if SERVER then return end

local warnFrame
local warnSearch
local warnList
local statusLabel
local queuedQuery = ""

local function ensureMenu()
    if IsValid(warnFrame) then return end

    warnFrame = vgui.Create("DFrame")
    warnFrame:SetSize(math.min(1100, ScrW() - 80), math.min(700, ScrH() - 80))
    warnFrame:Center()
    warnFrame:SetTitle("Player Warnings")
    warnFrame:MakePopup()

    local top = vgui.Create("DPanel", warnFrame)
    top:Dock(TOP)
    top:SetTall(58)
    top:DockMargin(8, 8, 8, 6)
    top.Paint = function() end

    warnSearch = vgui.Create("DTextEntry", top)
    warnSearch:Dock(FILL)
    warnSearch:DockMargin(0, 4, 8, 4)
    warnSearch:SetPlaceholderText("Search by Steam name, SteamID64, staff, or reason...")

    local refreshBtn = vgui.Create("DButton", top)
    refreshBtn:Dock(RIGHT)
    refreshBtn:SetWide(130)
    refreshBtn:SetText("Refresh")

    statusLabel = vgui.Create("DLabel", top)
    statusLabel:Dock(BOTTOM)
    statusLabel:SetTall(20)
    statusLabel:SetTextColor(Color(180, 200, 230))
    statusLabel:SetText("Type in the search bar and press Enter.")

    warnList = vgui.Create("DListView", warnFrame)
    warnList:Dock(FILL)
    warnList:DockMargin(8, 0, 8, 8)
    warnList:SetMultiSelect(false)
    warnList:AddColumn("Time"):SetFixedWidth(160)
    warnList:AddColumn("Target")
    warnList:AddColumn("SteamID64"):SetFixedWidth(180)
    warnList:AddColumn("Staff"):SetFixedWidth(150)
    warnList:AddColumn("Reason")

    local function requestData()
        if not IsValid(warnSearch) then return end
        queuedQuery = tostring(warnSearch:GetValue() or "")
        statusLabel:SetText("Loading warnings...")

        net.Start("ZC_WarnMenu_Request")
            net.WriteString(queuedQuery)
        net.SendToServer()
    end

    warnSearch.OnEnter = requestData
    refreshBtn.DoClick = requestData

    warnFrame.OnClose = function()
        warnFrame = nil
        warnSearch = nil
        warnList = nil
        statusLabel = nil
    end
end

net.Receive("ZC_WarnMenu_Open", function()
    ensureMenu()

    local seed = net.ReadString() or ""
    if IsValid(warnFrame) then
        warnFrame:Show()
        warnFrame:MakePopup()
    end

    if IsValid(warnSearch) then
        warnSearch:SetText(seed)
        warnSearch:RequestFocus()
    end

    net.Start("ZC_WarnMenu_Request")
        net.WriteString(seed)
    net.SendToServer()

    if IsValid(statusLabel) then
        statusLabel:SetText("Loading warnings...")
    end
end)

net.Receive("ZC_WarnMenu_Data", function()
    if not IsValid(warnList) then return end

    local count = net.ReadUInt(9)
    warnList:Clear()

    for _ = 1, count do
        local atText = net.ReadString()
        local targetName = net.ReadString()
        local sid64 = net.ReadString()
        local staff = net.ReadString()
        local reason = net.ReadString()

        warnList:AddLine(atText, targetName, sid64, staff, reason)
    end

    if IsValid(statusLabel) then
        statusLabel:SetText(string.format("Showing %d warning entries.", count))
    end
end)
