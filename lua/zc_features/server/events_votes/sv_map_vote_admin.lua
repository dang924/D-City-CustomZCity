-- Map Voting System - Admin Panel
-- Server-side admin menu and commands for managing maps

if not game.IsDedicated() and not CLIENT then return end

local AdminPanel = nil

-- Create admin panel
function CreateAdminPanel()
    if IsValid(AdminPanel) then
        AdminPanel:Remove()
    end
    
    local screenW, screenH = ScrW(), ScrH()
    local panelWidth = math.min(800, screenW - 40)
    local panelHeight = math.min(700, screenH - 60)
    
    AdminPanel = vgui.Create("DFrame")
    AdminPanel:SetSize(panelWidth, panelHeight)
    AdminPanel:Center()
    AdminPanel:SetTitle("⚙️ MAP VOTING ADMIN PANEL")
    AdminPanel:SetDraggable(true)
    AdminPanel:ShowCloseButton(true)
    AdminPanel:MakePopup()
    
    -- Styling
    AdminPanel:SetBackgroundBlur(true)
    function AdminPanel:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(35, 35, 40))
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, Color(45, 45, 50))
    end
    
    -- Control buttons panel
    local controlPanel = vgui.Create("DPanel", AdminPanel)
    controlPanel:Dock(TOP)
    controlPanel:SetHeight(50)
    controlPanel:DockMargin(10, 10, 10, 5)
    controlPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 70))
    end
    
    -- Button to start vote
    local startBtn = vgui.Create("DButton", controlPanel)
    startBtn:SetPos(10, 10)
    startBtn:SetSize(150, 30)
    startBtn:SetText("▶ START VOTE")
    startBtn:SetFont("DermaDefault")
    startBtn.DoClick = function()
        RunConsoleCommand("mapvote_start")
        chat.AddText(Color(100, 200, 100), "[MapVote] Vote started!")
    end
    
    -- Button to end vote
    local endBtn = vgui.Create("DButton", controlPanel)
    endBtn:SetPos(170, 10)
    endBtn:SetSize(150, 30)
    endBtn:SetText("⊠ END VOTE")
    endBtn:SetFont("DermaDefault")
    endBtn.DoClick = function()
        RunConsoleCommand("mapvote_end")
        chat.AddText(Color(100, 200, 100), "[MapVote] Vote ended!")
    end
    
    -- Current maps label
    local mapsLabel = vgui.Create("DLabel", AdminPanel)
    mapsLabel:Dock(TOP)
    mapsLabel:SetHeight(25)
    mapsLabel:SetText("📋 CURRENT MAPS (" .. #_G.MapVoting.AvailableMaps .. ")")
    mapsLabel:SetTextColor(Color(255, 200, 100))
    mapsLabel:SetFont("DermaLarge")
    mapsLabel:DockMargin(10, 5, 10, 5)
    
    -- Maps list with remove buttons
    local scroll = vgui.Create("DScrollPanel", AdminPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 0, 10, 10)
    scroll:SetHeight(250)
    
    local canvas = scroll:GetCanvas()
    canvas.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 35))
    end
    
    local function RefreshMapList()
        scroll:Clear()
        
        if #_G.MapVoting.AvailableMaps == 0 then
            local emptyLabel = vgui.Create("DLabel", scroll)
            emptyLabel:SetHeight(30)
            emptyLabel:Dock(TOP)
            emptyLabel:SetText("No maps added yet...")
            emptyLabel:SetTextColor(Color(150, 150, 150))
            emptyLabel:SetFont("DefaultSmall")
            emptyLabel:DockMargin(10, 10, 10, 10)
            return
        end
        
        for i, map in ipairs(_G.MapVoting.AvailableMaps) do
            local mapPanel = vgui.Create("DPanel", scroll)
            mapPanel:SetHeight(40)
            mapPanel:Dock(TOP)
            mapPanel:DockMargin(0, 0, 0, 6)
            mapPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 60))
                draw.RoundedBox(4, 1, 1, w - 2, h - 2, Color(55, 60, 70))
            end
            
            local mapLabel = vgui.Create("DLabel", mapPanel)
            mapLabel:Dock(FILL)
            mapLabel:SetText("  " .. i .. ". " .. map)
            mapLabel:SetTextColor(Color(200, 220, 255))
            mapLabel:SetFont("DermaDefault")
            
            local removeBtn = vgui.Create("DButton", mapPanel)
            removeBtn:Dock(RIGHT)
            removeBtn:SetWidth(80)
            removeBtn:DockMargin(5, 5, 0, 5)
            removeBtn:SetText("✕ REMOVE")
            removeBtn:SetFont("DermaSmall")
            removeBtn.DoClick = function()
                RunConsoleCommand("mapvote_remove", map)
                RefreshMapList()
            end
            removeBtn.Paint = function(self, w, h)
                local col = self:IsHovered() and Color(200, 80, 80) or Color(150, 60, 60)
                draw.RoundedBox(3, 0, 0, w, h, col)
                draw.RoundedBox(3, 1, 1, w - 2, h - 2, Color(180, 100, 100))
            end
        end
    end
    
    RefreshMapList()
    
    -- Add map section
    local addLabel = vgui.Create("DLabel", AdminPanel)
    addLabel:Dock(TOP)
    addLabel:SetHeight(25)
    addLabel:SetText("➕ ADD NEW MAP")
    addLabel:SetTextColor(Color(100, 200, 100))
    addLabel:SetFont("DermaLarge")
    addLabel:DockMargin(10, 5, 10, 5)
    
    local addPanel = vgui.Create("DPanel", AdminPanel)
    addPanel:Dock(TOP)
    addPanel:SetHeight(45)
    addPanel:DockMargin(10, 0, 10, 10)
    addPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 60))
    end
    
    local mapInput = vgui.Create("DTextEntry", addPanel)
    mapInput:Dock(FILL)
    mapInput:DockMargin(5, 5, 5, 5)
    mapInput:SetPlaceholderText("Enter map name (e.g., gm_flatgrass_fxp)")
    mapInput:SetFont("DermaDefault")
    
    local addBtn = vgui.Create("DButton", addPanel)
    addBtn:Dock(RIGHT)
    addBtn:SetWidth(110)
    addBtn:DockMargin(5, 0, 0, 0)
    addBtn:SetText("ADD MAP")
    addBtn:SetFont("DermaSmall")
    addBtn.DoClick = function()
        local mapname = mapInput:GetValue()
        if mapname == "" then
            chat.AddText(Color(255, 100, 100), "[MapVote] Please enter a map name.")
            return
        end
        
        RunConsoleCommand("mapvote_add", mapname)
        mapInput:SetValue("")
        RefreshMapList()
    end
    addBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(100, 180, 100) or Color(80, 150, 80)
        draw.RoundedBox(3, 0, 0, w, h, col)
        draw.RoundedBox(3, 1, 1, w - 2, h - 2, Color(120, 200, 120))
    end
    
    AdminPanel.RefreshMapList = RefreshMapList
end

-- Console command for admins
concommand.Add("mapvote_admin", function(ply, cmd, args)
    local ulxLib = rawget(_G, "ULX") or rawget(_G, "ulx")

    if IsValid(ply) and not ply:IsAdmin() and not (ulxLib and ulxLib.CheckAccess and ulxLib.CheckAccess(ply, "ulx mapvote")) then
        ply:PrintMessage(HUD_PRINTTALK, "Access denied.")
        return
    end
    
    if CLIENT then
        CreateAdminPanel()
    end
end)

-- Help command
concommand.Add("mapvote_help", function(ply, cmd, args)
    local help = [[
    Map Voting Commands:
    !rtv - Start a map vote (all players)
    !mapvote - Open voting menu
    mapvote_list - View all available maps
    mapvote_add <mapname> - Add a map (admin)
    mapvote_remove <mapname> - Remove a map (admin)
    mapvote_start - Start voting round (admin)
    mapvote_end - End voting round (admin)
    mapvote_admin - Open admin panel (admin)
    ]]
    
    if IsValid(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, help)
    else
        print(help)
    end
end)
