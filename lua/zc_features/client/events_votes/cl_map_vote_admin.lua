-- Map Voting System - Admin Menu (Client)

if SERVER then return end

local AdminFrame

local function CanUseAdminMenu()
    local ply = LocalPlayer()
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function OpenMapVoteAdminMenu()
    if not CanUseAdminMenu() then
        chat.AddText(Color(255, 120, 120), "[MapVote] ", color_white, "Admin access required.")
        return
    end

    if IsValid(AdminFrame) then
        AdminFrame:Remove()
    end

    AdminFrame = vgui.Create("DFrame")
    AdminFrame:SetSize(520, 270)
    AdminFrame:Center()
    AdminFrame:SetTitle("Map Vote Admin")
    AdminFrame:MakePopup()

    local info = vgui.Create("DLabel", AdminFrame)
    info:Dock(TOP)
    info:SetTall(38)
    info:SetWrap(true)
    info:SetText("Use this menu to manage the vote list and control a running vote.\nMap icons are set in cl_map_voting.lua via MAP_ICON_PRESETS.")
    info:DockMargin(10, 8, 10, 0)

    local mapEntry = vgui.Create("DTextEntry", AdminFrame)
    mapEntry:Dock(TOP)
    mapEntry:SetTall(30)
    mapEntry:SetPlaceholderText("Map name, for example: gm_construct")
    mapEntry:DockMargin(10, 8, 10, 0)

    local addBtn = vgui.Create("DButton", AdminFrame)
    addBtn:Dock(TOP)
    addBtn:SetTall(30)
    addBtn:SetText("Add Map To Vote List")
    addBtn:DockMargin(10, 8, 10, 0)
    addBtn.DoClick = function()
        local mapname = string.Trim(mapEntry:GetValue() or "")
        if mapname == "" then return end
        RunConsoleCommand("mapvote_add", mapname)
    end

    local removeBtn = vgui.Create("DButton", AdminFrame)
    removeBtn:Dock(TOP)
    removeBtn:SetTall(30)
    removeBtn:SetText("Remove Map From Vote List")
    removeBtn:DockMargin(10, 6, 10, 0)
    removeBtn.DoClick = function()
        local mapname = string.Trim(mapEntry:GetValue() or "")
        if mapname == "" then return end
        RunConsoleCommand("mapvote_remove", mapname)
    end

    local row = vgui.Create("DPanel", AdminFrame)
    row:Dock(BOTTOM)
    row:SetTall(42)
    row:DockMargin(10, 10, 10, 10)
    row.Paint = function() end

    local startBtn = vgui.Create("DButton", row)
    startBtn:Dock(LEFT)
    startBtn:SetWide(160)
    startBtn:SetText("Start Vote")
    startBtn.DoClick = function()
        RunConsoleCommand("mapvote_start")
    end

    local endBtn = vgui.Create("DButton", row)
    endBtn:Dock(LEFT)
    endBtn:SetWide(160)
    endBtn:DockMargin(8, 0, 0, 0)
    endBtn:SetText("End Vote")
    endBtn.DoClick = function()
        RunConsoleCommand("mapvote_end")
    end

    local listBtn = vgui.Create("DButton", row)
    listBtn:Dock(RIGHT)
    listBtn:SetWide(160)
    listBtn:SetText("Print Vote List")
    listBtn.DoClick = function()
        RunConsoleCommand("mapvote_list")
    end
end

concommand.Add("mapvote_admin", OpenMapVoteAdminMenu)
