MODE.name = "event"

local MODE = MODE

local radius = nil
local mapsize = 7500

local EventersList = {}

ZonePos = ZonePos or Vector(0,0,0)

local roundend = false

net.Receive("event_start",function()
    roundend = false
    zb.RemoveFade()
end)


net.Receive("event_eventers_update", function()
    EventersList = {}
    local data = net.ReadTable()
    for _, id in ipairs(data) do
        EventersList[id] = true
    end
end)

local fighter = {
    color1 = Color(0,120,190)
}

local eventer = {
    color1 = Color(50,200,50)
}

local mat = Material("hmcd_dmzone")

local mapsize = 7500

function MODE:RenderScreenspaceEffects()
	
    if zb.ROUND_START + 7.5 < CurTime() then return end
	
    local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(),0,1)

    surface.SetDrawColor(0,0,0,255 * fade)
    surface.DrawRect(-1,-1,ScrW() + 1,ScrH() + 1)
end

function MODE:HUDPaint()
	 
	if not lply:Alive() then return end
    if zb.ROUND_START + 8.5 < CurTime() then return end
	zb.RemoveFade()
    local fade = math.Clamp(zb.ROUND_START + 8 - CurTime(),0,1)

    local eventname = GetGlobalString("ZB_EventName","Event")
    draw.SimpleText("ZCity | "..eventname, "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0,162,255, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    

    local isEventer = EventersList[LocalPlayer():SteamID()]
    local Rolename = isEventer and "Eventer" or GetGlobalString("ZB_EventRole","Player")
    local ColorRole = isEventer and eventer.color1 or fighter.color1
    ColorRole.a = 255 * fade
    draw.SimpleText("You are a "..Rolename , "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local Objective = GetGlobalString("ZB_EventObjective","")
    local ColorObj = isEventer and eventer.color1 or fighter.color1
    ColorObj.a = 255 * fade
    draw.SimpleText( Objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local CreateEndMenu = nil
local wonply = nil

net.Receive("event_end",function()
	local ent = net.ReadEntity()
	wonply = nil
	if IsValid(ent) then
		ent.won = true
		wonply = ent
	end
	
	roundend = CurTime()
	
    CreateEndMenu()
end)

local colGray = Color(85,85,85,255)
local colRed = Color(217,201,99)
local colRedUp = Color(207,181,59)

local colBlue = Color(10,10,160)
local colBlueUp = Color(40,40,160)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(255,255,255)

local colorBG = Color(55,55,55,255)
local colorBGBlacky = Color(40,40,40,255)

local blurMat = Material("pp/blurscreen")
local Dynamic = 0

BlurBackground = BlurBackground or hg.DrawBlur

if IsValid(hmcdEndMenu) then
    hmcdEndMenu:Remove()
    hmcdEndMenu = nil
end

CreateEndMenu = function()
	if IsValid(hmcdEndMenu) then
		hmcdEndMenu:Remove()
		hmcdEndMenu = nil
	end
	Dynamic = 0
	hmcdEndMenu = vgui.Create("ZFrame")

    surface.PlaySound("ambient/alarms/warningbell1.wav")

	local sizeX,sizeY = ScrW() / 2.5 ,ScrH() / 1.2
	local posX,posY = ScrW() / 1.3 - sizeX / 2,ScrH() / 2 - sizeY / 2

	hmcdEndMenu:SetPos(posX,posY)
	hmcdEndMenu:SetSize(sizeX,sizeY)
	--hmcdEndMenu:SetBackgroundColor(colGray)
	hmcdEndMenu:MakePopup()
	hmcdEndMenu:SetKeyboardInputEnabled(false)
	hmcdEndMenu:ShowCloseButton(false)

	local closebutton = vgui.Create("DButton",hmcdEndMenu)
	closebutton:SetPos(5,5)
	closebutton:SetSize(ScrW() / 20,ScrH() / 30)
	closebutton:SetText("")
	
	closebutton.DoClick = function()
		if IsValid(hmcdEndMenu) then
			hmcdEndMenu:Close()
			hmcdEndMenu = nil
		end
	end

	closebutton.Paint = function(self,w,h)
		surface.SetDrawColor( 122, 122, 122, 255)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
		surface.SetFont( "ZB_InterfaceMedium" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Close")
		surface.SetTextPos( lengthX - lengthX/1.1, 4)
		surface.DrawText("Close")
	end

    hmcdEndMenu.PaintOver = function(self,w,h)

		local txt = (wonply and wonply:GetPlayerName() or "Nobody").." won!"
		surface.SetFont( "ZB_InterfaceMediumLarge" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize(txt)
		surface.SetTextPos(w / 2 - lengthX/2,20)
		surface.DrawText(txt)
	end
	
	local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
	DScrollPanel:SetPos(10, 80)
	DScrollPanel:SetSize(sizeX - 20, sizeY - 90)

	for i, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		local but = vgui.Create("DButton",DScrollPanel)
		but:SetSize(100,50)
		but:Dock(TOP)
		but:DockMargin( 8, 6, 8, -1 )
		but:SetText("")
		but.Paint = function(self,w,h)
			local col1 = (ply.won and colRed) or (ply:Alive() and colBlue) or colGray
            local col2 = (ply.won and colRedUp) or (ply:Alive() and colBlueUp) or colSpect1
			
			surface.SetDrawColor(col1.r,col1.g,col1.b,col1.a)
			surface.DrawRect(0,0,w,h)
			surface.SetDrawColor(col2.r,col2.g,col2.b,col2.a)
			surface.DrawRect(0,h/2,w,h/2)

            local col = ply:GetPlayerColor():ToColor()
			surface.SetFont( "ZB_InterfaceMediumLarge" )
			local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
			
			surface.SetTextColor(0,0,0,255)
			surface.SetTextPos(w / 2 + 1,h/2 - lengthY/2 + 1)
			surface.DrawText(ply:GetPlayerName() or "He quited...")

			surface.SetTextColor(col.r,col.g,col.b,col.a)
			surface.SetTextPos(w / 2,h/2 - lengthY/2)
			surface.DrawText(ply:GetPlayerName() or "He quited...")

            
			local col = colSpect2
			surface.SetFont( "ZB_InterfaceMediumLarge" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
			surface.SetTextPos(15,h/2 - lengthY/2)
			surface.DrawText((ply:Name() .. (not ply:Alive() and " - died" or "")) or "He quited...")

			surface.SetFont( "ZB_InterfaceMediumLarge" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize( ply:Frags() or "He quited..." )
			surface.SetTextPos(w - lengthX -15,h/2 - lengthY/2)
			surface.DrawText(ply:Frags() or "He quited...")
		end

		function but:DoClick()
			if ply:IsBot() then chat.AddText(Color(255,0,0), "no, you can't") return end
			gui.OpenURL("https://steamcommunity.com/profiles/"..ply:SteamID64())
		end

		DScrollPanel:AddItem(but)
	end

	return true
end

function MODE:RoundStart()
    for i, ply in player.Iterator() do
		ply.won = nil
    end

    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end


local eventLootTable = {}
local eventLootSettings = {
    autoRefill = false,
    interval = 300,
}
local eventContainerList = {}
local eventModelLootProfiles = {}
local eventModelLootCaps = {}
local eventModelLootMins = {}
local eventContainerWhitelist = {}
-- Per-class blacklist / whitelist mirrors (ZRP LootEditor parity).
local eventLootBlacklist = {}
local eventLootWhitelist = {}

local EVENT_LOOT_GROUP_TOKENS = {
    -- Only tokens that have real built-in runtime expansion are listed here.
    -- All other category wildcards (snipers/pistols/medicine/etc.) must be
    -- created by admins via right-click "Create Wildcard From Selected" so
    -- they aren't shown as empty placeholders.
    "*ammo*", "*attachments*", "*sight*", "*barrel*",
}

local LootRegistryCache = nil
local eventCustomWildcardGroups = {}

local function GetAllWildcardTokens()
    local out = {}
    local seen = {}

    local function addToken(token)
        token = string.lower(string.Trim(tostring(token or "")))
        if not string.match(token, "^%*[%w_]+%*$") then return end
        if seen[token] then return end
        seen[token] = true
        out[#out + 1] = token
    end

    for _, token in ipairs(EVENT_LOOT_GROUP_TOKENS) do
        addToken(token)
    end

    for token, _ in pairs(eventCustomWildcardGroups or {}) do
        addToken(token)
    end

    table.sort(out)
    return out
end

local function ResolveLootClassMeta(className)
    className = string.lower(string.Trim(tostring(className or "")))
    if className == "" then return "", "" end

    -- 1. SWEPs (weapons.GetStored / weapons.Get)
    local wep = (weapons.GetStored and weapons.GetStored(className)) or (weapons.Get and weapons.Get(className))
    if wep then
        local printName = wep.PrintName or wep.Printname or ""
        local subCat = wep.Category or wep.SpawnMenuCategory or wep.Subcategory or ""
        if printName ~= "" or subCat ~= "" then
            return tostring(printName or ""), tostring(subCat or "")
        end
    end

    -- 2. Scripted entities
    local sent = scripted_ents.GetStored and scripted_ents.GetStored(className) or nil
    local sentT = sent and (sent.t or sent) or nil
    if sentT then
        local printName = sentT.PrintName or sentT.Printname or ""
        local subCat = sentT.Category or sentT.SpawnMenuCategory or sentT.Subcategory or ""
        if printName ~= "" or subCat ~= "" then
            return tostring(printName or ""), tostring(subCat or "")
        end
    end

    -- 3. list.Get("Weapon") / list.Get("SpawnableEntities") entries
    local function scanList(listName)
        local entries = list.Get(listName) or {}
        local entry = entries[className]
        if not entry then
            for k, v in pairs(entries) do
                local cls = string.lower(tostring(v.ClassName or v.class or k or ""))
                if cls == className then entry = v; break end
            end
        end
        if entry then
            return tostring(entry.PrintName or entry.Printname or ""),
                tostring(entry.Category or entry.SpawnMenuCategory or "")
        end
        return nil, nil
    end

    local pn, sc = scanList("Weapon")
    if pn or sc then return pn or "", sc or "" end
    pn, sc = scanList("SpawnableEntities")
    if pn or sc then return pn or "", sc or "" end

    return "", ""
end

local function ClassifyLootClass(className)
    className = string.lower(tostring(className or ""))

    if string.match(className, "^%*[%w_]+%*$") then
        if className == "*ammo*" then return "Ammo" end
        return "Groups"
    end
    if string.find(className, "armor") or string.find(className, "helmet") or string.find(className, "vest") then
        return "Armor"
    end
    if string.find(className, "ammo") then return "Ammo" end
    if string.find(className, "med") or string.find(className, "bandage") or string.find(className, "morphine")
        or string.find(className, "fentanyl") or string.find(className, "adrenaline")
        or string.find(className, "tourniquet") or string.find(className, "painkiller") then
        return "Medicine"
    end
    if string.sub(className, 1, 7) == "weapon_" then return "Weapons" end
    if string.sub(className, 1, 4) == "ent_" then return "Entities" end
    return "Other"
end

local function BuildLootRegistry()
    local seen = {}
    local out = {}

    local function addClass(className, source)
        className = string.Trim(tostring(className or ""))
        if className == "" or seen[className] then return end
        seen[className] = true
        local printName, subCat = ResolveLootClassMeta(className)
        out[#out + 1] = {
            class = className,
            category = ClassifyLootClass(className),
            subcategory = subCat,
            printName = printName,
            source = source,
        }
    end

    for _, token in ipairs(GetAllWildcardTokens()) do
        addClass(token, "wildcard-group")
    end

    for _, wep in ipairs(weapons.GetList() or {}) do
        addClass(wep.ClassName or wep.Classname, "weapons.GetList")
    end

    for className, _ in pairs(scripted_ents.GetList() or {}) do
        addClass(className, "scripted_ents.GetList")
    end

    for _, entry in pairs(list.Get("Weapon") or {}) do
        addClass(entry.ClassName or entry.class or entry.PrintName, "list.Weapon")
    end

    for _, entry in pairs(list.Get("SpawnableEntities") or {}) do
        addClass(entry.ClassName or entry.class or entry.PrintName, "list.SpawnableEntities")
    end

    table.sort(out, function(a, b)
        if a.category == b.category then
            return string.lower(a.class) < string.lower(b.class)
        end
        return a.category < b.category
    end)

    LootRegistryCache = out
    return out
end

local function GetLootRegistry()
    return LootRegistryCache or BuildLootRegistry()
end

local function OpenLootRegistryPicker(classEntry)
    local picker = vgui.Create("Nexus:Frame")
    picker:SetTitle("Registered Loot Class Picker", "")
    picker:SetSize(960, 620)
    picker:Center()
    picker:MakePopup()

    local toolbar = picker:Add("DPanel")
    toolbar:Dock(TOP)
    toolbar:DockMargin(10, 8, 10, 0)
    toolbar:SetTall(40)
    toolbar.Paint = nil

    local search = toolbar:Add("Nexus:TextEntry")
    search:Dock(LEFT)
    search:DockMargin(0, 0, 6, 0)
    search:SetWide(360)
    search:SetPlaceholder("Search classname, name or subcategory...")

    local category = toolbar:Add("Nexus:ComboBox")
    category:Dock(LEFT)
    category:DockMargin(0, 0, 6, 0)
    category:SetWide(240)
    category:SetText("All Subcategories")
    category:SetDontSort(true)

    local add = toolbar:Add("Nexus:Button")
    add:Dock(RIGHT)
    add:DockMargin(6, 0, 0, 0)
    add:SetWide(140)
    add:SetText("Use Selected")

    local refresh = toolbar:Add("Nexus:Button")
    refresh:Dock(RIGHT)
    refresh:DockMargin(0, 0, 0, 0)
    refresh:SetWide(120)
    refresh:SetText("Rebuild List")
    refresh:SetSecondary(true)

    local hint = picker:Add("DLabel")
    hint:Dock(BOTTOM)
    hint:DockMargin(12, 4, 12, 6)
    hint:SetTall(18)
    hint:SetText("Double-click a row to use it. Right-click for wildcard actions. Ctrl/Shift to multi-select.")
    hint:SetTextColor(Color(180, 180, 180))

    local listView = picker:Add("Nexus:ListView")
    listView:Dock(FILL)
    listView:DockMargin(10, 8, 10, 4)
    listView:SetMultiSelect(true)
    listView:AddColumn("Class"):SetWide(220)
    listView:AddColumn("Print Name"):SetWide(200)
    listView:AddColumn("Subcategory"):SetWide(160)
    listView:AddColumn("Category"):SetWide(90)
    listView:AddColumn("Source"):SetWide(180)

    local function rebuildCategoryChoices()
        category.Options = {}
        category:AddChoice("All Subcategories", function() category:SetValue("All Subcategories") end)

        local seen = {}
        local subs = {}
        for _, item in ipairs(GetLootRegistry()) do
            local s = item.subcategory ~= "" and item.subcategory or item.category
            if s and s ~= "" and not seen[s] then
                seen[s] = true
                subs[#subs + 1] = s
            end
        end
        table.sort(subs)
        for _, s in ipairs(subs) do
            local label = s
            category:AddChoice(label, function() category:SetValue(label) end)
        end
    end

    local function refill()
        listView:Clear()
        local needle = string.lower(string.Trim(search:GetValue() or ""))
        local selectedSub = category:GetValue() or "All Subcategories"

        for _, item in ipairs(GetLootRegistry()) do
            local sub = item.subcategory ~= "" and item.subcategory or item.category
            local subOk = (selectedSub == "All Subcategories") or (sub == selectedSub)
            local searchOk = needle == ""
                or string.find(string.lower(item.class), needle, 1, true)
                or string.find(string.lower(item.printName or ""), needle, 1, true)
                or string.find(string.lower(item.subcategory or ""), needle, 1, true)

            if subOk and searchOk then
                local line = listView:AddLine(
                    item.class,
                    item.printName ~= "" and item.printName or "-",
                    item.subcategory ~= "" and item.subcategory or "-",
                    item.category,
                    item.source
                )
                line.LootClass = item.class
            end
        end
    end

    function listView:DoubleClicked(_, line)
        if not IsValid(classEntry) or not line or not line.LootClass then return end
        classEntry:SetValue(line.LootClass)
        picker:Remove()
    end

    local function GetSelectedNonWildcardClasses()
        local selected = listView:GetSelected() or {}
        local classes = {}
        local seen = {}

        for _, line in ipairs(selected) do
            local className = string.lower(string.Trim(tostring(line.LootClass or "")))
            if className ~= "" and not string.match(className, "^%*[%w_]+%*$") and not seen[className] then
                seen[className] = true
                classes[#classes + 1] = className
            end
        end

        table.sort(classes)
        return classes
    end

    listView.OnRowRightClick = function()
        local menu = DermaMenu()

        menu:AddOption("Create Wildcard From Selected", function()
            local classes = GetSelectedNonWildcardClasses()
            if #classes == 0 then
                notification.AddLegacy("Select one or more non-wildcard classes first.", NOTIFY_ERROR, 2)
                return
            end

            Derma_StringRequest(
                "New Wildcard Group",
                "Enter wildcard name (letters/numbers/underscore only).",
                "",
                function(input)
                    local token = string.lower(string.Trim(tostring(input or "")))
                    token = string.gsub(token, "^%*", "")
                    token = string.gsub(token, "%*$", "")
                    token = string.gsub(token, "[^%w_]", "")
                    if token == "" then
                        notification.AddLegacy("Invalid wildcard name.", NOTIFY_ERROR, 2)
                        return
                    end

                    net.Start("event_loot_wildcard_set")
                    net.WriteString("*" .. token .. "*")
                    net.WriteTable(classes)
                    net.SendToServer()
                end
            )
        end)

        menu:AddOption("Edit Wildcard Contents...", function()
            local selected = listView:GetSelected() or {}
            for _, line in ipairs(selected) do
                local token = string.lower(string.Trim(tostring(line.LootClass or "")))
                if string.match(token, "^%*[%w_]+%*$") then
                    net.Start("event_loot_wildcard_contents_request")
                    net.WriteString(token)
                    net.SendToServer()
                    return
                end
            end
            notification.AddLegacy("Select a wildcard entry to edit.", NOTIFY_HINT, 2)
        end)

        menu:AddOption("Remove Selected Wildcard", function()
            local selected = listView:GetSelected() or {}
            for _, line in ipairs(selected) do
                local token = string.lower(string.Trim(tostring(line.LootClass or "")))
                if string.match(token, "^%*[%w_]+%*$") and eventCustomWildcardGroups[token] then
                    net.Start("event_loot_wildcard_remove")
                    net.WriteString(token)
                    net.SendToServer()
                    return
                end
            end

            notification.AddLegacy("Select a custom wildcard entry to remove.", NOTIFY_HINT, 2)
        end)

        menu:Open()
    end

    add.DoClick = function()
        local selected = listView:GetSelected() or {}
        if #selected == 0 then return end

        table.sort(selected, function(a, b)
            return (a.GetID and a:GetID() or 0) < (b.GetID and b:GetID() or 0)
        end)

        local line = selected[1]
        if not IsValid(classEntry) or not line or not line.LootClass then return end
        classEntry:SetValue(line.LootClass)

        if #selected > 1 then
            notification.AddLegacy("Selected " .. tostring(#selected) .. " entries; using first selected entry.", NOTIFY_HINT, 2)
        end

        picker:Remove()
    end

    refresh.DoClick = function()
        LootRegistryCache = nil
        BuildLootRegistry()
        rebuildCategoryChoices()
        refill()
    end

    function search:OnChange()
        refill()
    end

    function category:OnSelect()
        refill()
    end

    BuildLootRegistry()
    rebuildCategoryChoices()
    refill()
end

local function OpenLootTableEditor(title, seedItems, onSave)
    local frame = vgui.Create("DFrame")
    frame:SetTitle(title or "Loot Table Editor")
    frame:SetSize(760, 560)
    frame:Center()
    frame:MakePopup()

    local items = {}
    for _, row in ipairs(seedItems or {}) do
        local w = tonumber(row[1]) or tonumber(row.weight) or 0
        local c = string.Trim(tostring(row[2] or row.class or ""))
        if w > 0 and c ~= "" then
            items[#items + 1] = {w, c}
        end
    end

    local list = vgui.Create("DListView", frame)
    list:SetPos(10, 35)
    list:SetSize(740, 360)
    list:SetMultiSelect(true)
    list:AddColumn("Weight"):SetFixedWidth(100)
    list:AddColumn("Class")

    local function refresh()
        list:Clear()
        for i, row in ipairs(items) do
            local line = list:AddLine(row[1], row[2])
            line.RowIndex = i
        end
    end

    local controls = vgui.Create("DPanel", frame)
    controls:SetPos(10, 405)
    controls:SetSize(740, 110)
    controls.Paint = nil

    local weight = vgui.Create("DNumberWang", controls)
    weight:SetPos(0, 22)
    weight:SetSize(70, 24)
    weight:SetMinMax(1, 100)
    weight:SetValue(5)

    local classEntry = vgui.Create("DTextEntry", controls)
    classEntry:SetPos(80, 22)
    classEntry:SetSize(430, 24)
    classEntry:SetPlaceholderText("Class")

    local browse = vgui.Create("DButton", controls)
    browse:SetPos(520, 22)
    browse:SetSize(90, 24)
    browse:SetText("Browse")
    browse.DoClick = function()
        OpenLootRegistryPicker(classEntry)
    end

    local add = vgui.Create("DButton", controls)
    add:SetPos(620, 22)
    add:SetSize(120, 24)
    add:SetText("Add")
    add.DoClick = function()
        local w = tonumber(weight:GetValue()) or 0
        local c = string.Trim(tostring(classEntry:GetValue() or ""))
        if w <= 0 or c == "" then return end
        items[#items + 1] = {w, c}
        refresh()
    end

    local remove = vgui.Create("DButton", controls)
    remove:SetPos(0, 55)
    remove:SetSize(180, 24)
    remove:SetText("Remove Selected")
    remove.DoClick = function()
        local selected = list:GetSelected() or {}
        local idx = {}
        for _, line in ipairs(selected) do
            if line.RowIndex then
                idx[#idx + 1] = tonumber(line.RowIndex)
            end
        end
        table.sort(idx, function(a, b) return a > b end)
        for _, i in ipairs(idx) do
            table.remove(items, i)
        end
        refresh()
    end

    local clear = vgui.Create("DButton", controls)
    clear:SetPos(190, 55)
    clear:SetSize(180, 24)
    clear:SetText("Clear")
    clear.DoClick = function()
        items = {}
        refresh()
    end

    local save = vgui.Create("DButton", frame)
    save:SetPos(560, 520)
    save:SetSize(90, 30)
    save:SetText("Save")
    save.DoClick = function()
        if onSave then
            onSave(items)
        end
        frame:Close()
    end

    local cancel = vgui.Create("DButton", frame)
    cancel:SetPos(660, 520)
    cancel:SetSize(90, 30)
    cancel:SetText("Cancel")
    cancel.DoClick = function()
        frame:Close()
    end

    refresh()
    return frame
end

local ContainerManagerMenu = nil

local function OpenContainerManagerMenu()
    if IsValid(ContainerManagerMenu) then
        ContainerManagerMenu:Remove()
    end

    local frame = vgui.Create("Nexus:Frame")
    ContainerManagerMenu = frame
    frame:SetTitle("Event Container Manager", "")
    frame:SetSize(1180, 880)
    frame:Center()
    frame:MakePopup()

    -- Helper to build a labelled section header so users can scan groups quickly.
    local function makeSection(parent, label, tall)
        local row = parent:Add("DPanel")
        row:Dock(TOP)
        row:DockMargin(10, 8, 10, 0)
        row:SetTall(tall or 22)
        row.Paint = nil

        local lbl = row:Add("DLabel")
        lbl:Dock(FILL)
        lbl:SetText(label)
        lbl:SetFont(Nexus:GetFont(20, nil, true))
        lbl:SetTextColor(Nexus.Colors.Text)
        return row
    end

    local function makeButtonRow(parent)
        local row = parent:Add("DPanel")
        row:Dock(TOP)
        row:DockMargin(10, 6, 10, 0)
        row:SetTall(34)
        row.Paint = nil
        return row
    end

    local function dockBtn(parent, text, color, onClick, tooltip)
        local btn = parent:Add("Nexus:Button")
        btn:Dock(LEFT)
        btn:DockMargin(0, 0, 6, 0)
        btn:SetWide(180)
        btn:SetText(text)
        if color then btn:SetColor(color) end
        if tooltip then
            btn:SetTooltip(tooltip)
            btn:SetTooltipDelay(0)
        end
        btn.DoClick = function() onClick(btn) end
        return btn
    end

    -- ============ CONTAINERS SECTION ============
    makeSection(frame, "Spawned Containers")

    local containerList = frame:Add("Nexus:ListView")
    containerList:Dock(TOP)
    containerList:DockMargin(10, 4, 10, 0)
    containerList:SetTall(330)
    containerList:SetMultiSelect(false)
    containerList:AddColumn("Key"):SetWide(80)
    containerList:AddColumn("Type"):SetWide(80)
    containerList:AddColumn("Model"):SetWide(420)
    containerList:AddColumn("Pos"):SetWide(220)
    containerList:AddColumn("Ent"):SetWide(40)
    containerList:AddColumn("Custom"):SetWide(60)

    local function GetSelectedContainerRow()
        local selected = containerList:GetSelected() or {}
        local line = selected[1]
        return line and line.RowData or nil
    end

    local containerRow = makeButtonRow(frame)

    dockBtn(containerRow, "Refresh List", nil, function()
        net.Start("event_container_list_request")
        net.SendToServer()
    end, "Re-request the live container list from the server.")

    dockBtn(containerRow, "Goto Selected", nil, function()
        local row = GetSelectedContainerRow()
        if not row or not row.key then
            notification.AddLegacy("Select a container first.", NOTIFY_HINT, 2)
            return
        end
        net.Start("event_container_action")
        net.WriteString(row.key)
        net.WriteString("goto")
        net.SendToServer()
    end)

    dockBtn(containerRow, "Refill Selected", nil, function()
        local row = GetSelectedContainerRow()
        if not row or not row.key then
            notification.AddLegacy("Select a container first.", NOTIFY_HINT, 2)
            return
        end
        net.Start("event_container_action")
        net.WriteString(row.key)
        net.WriteString("refill")
        net.SendToServer()
    end)

    dockBtn(containerRow, "Edit Container Loot", nil, function()
        local row = GetSelectedContainerRow()
        if not row or not row.key then
            notification.AddLegacy("Select a container first.", NOTIFY_HINT, 2)
            return
        end
        OpenLootTableEditor("Container Loot: " .. row.key, row.lootOverride or {}, function(items)
            net.Start("event_container_set_loot")
            net.WriteString(row.key)
            net.WriteTable(items)
            net.SendToServer()
        end)
    end, "Override loot table for just this single container.")

    dockBtn(containerRow, "Delete Container", Nexus.Colors.Red, function()
        local row = GetSelectedContainerRow()
        if not row or not row.key then
            notification.AddLegacy("Select a container first.", NOTIFY_HINT, 2)
            return
        end
        Derma_Query(
            "Delete selected container?",
            "Confirm",
            "Delete", function()
                net.Start("event_container_action")
                net.WriteString(row.key)
                net.WriteString("delete")
                net.SendToServer()
            end,
            "Cancel", function() end
        )
    end)

    -- ============ MODELS SECTION ============
    makeSection(frame, "Container Models (whitelist, loot profile, min/max items)")

    local modelList = frame:Add("Nexus:ListView")
    modelList:Dock(TOP)
    modelList:DockMargin(10, 4, 10, 0)
    modelList:SetTall(160)
    modelList:SetMultiSelect(false)
    modelList:AddColumn("Model"):SetWide(560)
    modelList:AddColumn("WL"):SetWide(40)
    modelList:AddColumn("Entries"):SetWide(70)
    modelList:AddColumn("Min"):SetWide(50)
    modelList:AddColumn("Max"):SetWide(50)

    local function GetSelectedModelKey()
        local id = modelList:GetSelectedLine()
        local line = id and modelList:GetLine(id) or nil
        return line and line.ModelKey or nil
    end

    local modelRow1 = makeButtonRow(frame)
    dockBtn(modelRow1, "Edit Model Loot", nil, function()
        local modelKey = GetSelectedModelKey()
        if not modelKey then
            notification.AddLegacy("Select a model first.", NOTIFY_HINT, 2)
            return
        end
        OpenLootTableEditor("Model Loot: " .. modelKey, eventModelLootProfiles[modelKey] or {}, function(items)
            net.Start("event_model_loot_profile_set")
            net.WriteString(modelKey)
            net.WriteTable(items)
            net.SendToServer()
        end)
    end, "Edit the per-model loot table used when this model spawns/refills.")

    dockBtn(modelRow1, "Remove Model Loot", nil, function()
        local modelKey = GetSelectedModelKey()
        if not modelKey then return end
        net.Start("event_model_loot_profile_remove")
        net.WriteString(modelKey)
        net.SendToServer()
    end)

    dockBtn(modelRow1, "Set Max Items", nil, function()
        local modelKey = GetSelectedModelKey()
        if not modelKey then
            notification.AddLegacy("Select a model first.", NOTIFY_HINT, 2)
            return
        end
        local current = tonumber(eventModelLootCaps[modelKey]) or 0
        Derma_StringRequest(
            "Max items for model",
            modelKey .. "\n\nMaximum items per spawn (1-64). Use 0 to clear and use defaults.",
            tostring(current),
            function(text)
                net.Start("event_model_loot_cap_set")
                net.WriteString(modelKey)
                net.WriteFloat(tonumber(text) or 0)
                net.SendToServer()
            end
        )
    end, "Caps how many items spawn in this model. 0 = use defaults.")

    dockBtn(modelRow1, "Set Min Items", nil, function()
        local modelKey = GetSelectedModelKey()
        if not modelKey then
            notification.AddLegacy("Select a model first.", NOTIFY_HINT, 2)
            return
        end
        local current = tonumber(eventModelLootMins[modelKey]) or 0
        Derma_StringRequest(
            "Min items for model",
            modelKey .. "\n\nMinimum items per spawn (1-64). Use 0 to default to half the Max.",
            tostring(current),
            function(text)
                net.Start("event_model_loot_min_set")
                net.WriteString(modelKey)
                net.WriteFloat(tonumber(text) or 0)
                net.SendToServer()
            end
        )
    end, "Forces at least this many items per spawn (when a Max is set). 0 = half of Max.")

    local modelRow2 = makeButtonRow(frame)
    dockBtn(modelRow2, "Toggle Whitelist (Sel)", nil, function()
        local modelKey = GetSelectedModelKey()
        if not modelKey then
            notification.AddLegacy("Select a model first.", NOTIFY_HINT, 2)
            return
        end
        net.Start("event_container_whitelist_set")
        net.WriteString(modelKey)
        net.WriteBool(not eventContainerWhitelist[modelKey])
        net.SendToServer()
    end, "Add/remove this model from the container whitelist.")

    dockBtn(modelRow2, "Add Model To Whitelist", nil, function()
        Derma_StringRequest(
            "Add container model",
            "Full model path (e.g. models/props_junk/wood_crate001a.mdl):",
            "models/",
            function(text)
                text = string.lower(string.Trim(tostring(text or "")))
                if text == "" or not string.match(text, "%.mdl$") then
                    notification.AddLegacy("Invalid model path.", NOTIFY_ERROR, 3)
                    return
                end
                net.Start("event_container_whitelist_set")
                net.WriteString(text)
                net.WriteBool(true)
                net.SendToServer()
            end
        )
    end, "Type a full model path (models/...) to add to the container whitelist.")

    -- ============ WORLD PROPS SECTION (parity with ZRP LootEditor) ============
    -- Surfaces lootable map props that match hg.loot_boxes but have NOT been
    -- adopted as ZRP world containers yet. Right-click "Adopt" turns them into
    -- a ZRP world container that the event mode (and ZRP mode) will refill.
    -- Data is supplied by ZRP's existing ZRP_WorldPropSync net message.
    makeSection(frame, "Unadopted Lootable Map Props (right-click to adopt)")

    local worldList = frame:Add("Nexus:ListView")
    worldList:Dock(TOP)
    worldList:DockMargin(10, 4, 10, 0)
    worldList:SetTall(120)
    worldList:SetMultiSelect(false)
    worldList:AddColumn("EntIdx"):SetWide(60)
    worldList:AddColumn("Model"):SetWide(560)
    worldList:AddColumn("Position"):SetWide(220)

    local worldRow = makeButtonRow(frame)
    dockBtn(worldRow, "Refresh Scan", nil, function()
        net.Start("ZRP_ContainerRequestSync")
        net.SendToServer()
    end, "Re-scan the map for unadopted lootable props.")

    dockBtn(worldRow, "Adopt Selected", Color(60, 130, 60), function()
        local id = worldList:GetSelectedLine()
        local line = id and worldList:GetLine(id) or nil
        local entIdx = line and line.EntIdx or nil
        if not entIdx then
            notification.AddLegacy("Select a scanned prop first.", NOTIFY_HINT, 2)
            return
        end
        net.Start("event_container_action")
        net.WriteString("w:0")  -- key kind/idx unused for "adopt"
        net.WriteString("adopt")
        net.WriteString(tostring(entIdx))
        net.SendToServer()
    end, "Adopt the selected map prop as a ZRP world container.")

    -- ============ DATA REFRESH ============
    local function refreshContainerRows()
        if not IsValid(containerList) then return end
        containerList:Clear()
        for _, row in ipairs(eventContainerList or {}) do
            local pos = row.pos or vector_origin
            local posStr = string.format("%.0f %.0f %.0f", pos.x or 0, pos.y or 0, pos.z or 0)
            local line = containerList:AddLine(
                row.key or "",
                row.kind or "",
                row.model or "",
                posStr,
                row.hasEntity and "Y" or "N",
                (istable(row.lootOverride) and #row.lootOverride > 0) and "Y" or "N"
            )
            line.RowData = row
        end
    end

    local function refreshModelRows()
        if not IsValid(modelList) then return end
        modelList:Clear()
        local models = {}
        local seen = {}

        for _, row in ipairs(eventContainerList or {}) do
            local mdl = string.lower(string.Trim(tostring(row.model or "")))
            if mdl ~= "" and not seen[mdl] then
                seen[mdl] = true
                models[#models + 1] = mdl
            end
        end

        for mdl, _ in pairs(eventModelLootProfiles or {}) do
            mdl = string.lower(string.Trim(tostring(mdl or "")))
            if mdl ~= "" and not seen[mdl] then
                seen[mdl] = true
                models[#models + 1] = mdl
            end
        end

        for mdl, _ in pairs(eventContainerWhitelist or {}) do
            mdl = string.lower(string.Trim(tostring(mdl or "")))
            if mdl ~= "" and not seen[mdl] then
                seen[mdl] = true
                models[#models + 1] = mdl
            end
        end

        table.sort(models)
        for _, mdl in ipairs(models) do
            local count = #(eventModelLootProfiles[mdl] or {})
            local capVal = tonumber(eventModelLootCaps[mdl])
            local minVal = tonumber(eventModelLootMins[mdl])
            local capStr = (capVal and capVal > 0) and tostring(capVal) or "-"
            local minStr
            if minVal and minVal > 0 then
                minStr = tostring(minVal)
            elseif capVal and capVal > 0 then
                minStr = tostring(math.ceil(capVal / 2)) .. "*"
            else
                minStr = "-"
            end
            local wlStr = eventContainerWhitelist[mdl] and "Y" or "N"
            local line = modelList:AddLine(mdl, wlStr, tostring(count), minStr, capStr)
            line.ModelKey = mdl
        end
    end

    local function refreshWorldRows()
        if not IsValid(worldList) then return end
        worldList:Clear()
        local data = (ZRP_GetWorldData and ZRP_GetWorldData()) or { scanned = {}, adopted = {} }
        if not istable(data.scanned) then return end
        for _, entry in ipairs(data.scanned) do
            local p = entry.pos
            local posStr
            if istable(p) then
                posStr = string.format("%.0f, %.0f, %.0f", p[1] or 0, p[2] or 0, p[3] or 0)
            elseif isvector(p) then
                posStr = string.format("%.0f, %.0f, %.0f", p.x, p.y, p.z)
            else
                posStr = "?"
            end
            local line = worldList:AddLine(
                tostring(entry.entindex or "?"),
                tostring(entry.model or "?"),
                posStr
            )
            line.EntIdx = tonumber(entry.entindex)
        end
    end

    -- Right-click on a scanned prop → adopt menu (parity with ZRP editor).
    worldList.OnRowRightClick = function(_, _, row)
        if not row.EntIdx then return end
        local menu = DermaMenu()
        menu:AddOption("Adopt as ZRP World Container", function()
            net.Start("event_container_action")
            net.WriteString("w:0")
            net.WriteString("adopt")
            net.WriteString(tostring(row.EntIdx))
            net.SendToServer()
        end)
        menu:Open()
    end

    -- Right-click on an active container → quick actions menu (parity with ZRP).
    containerList.OnRowRightClick = function(_, _, row)
        local rd = row and row.RowData
        if not rd or not rd.key then return end
        local menu = DermaMenu()

        menu:AddOption("Goto", function()
            net.Start("event_container_action")
            net.WriteString(rd.key)
            net.WriteString("goto")
            net.SendToServer()
        end)

        menu:AddOption("Activate / Refill Now", function()
            net.Start("event_container_action")
            net.WriteString(rd.key)
            net.WriteString("refill")
            net.SendToServer()
        end)

        menu:AddOption("Edit Container Loot…", function()
            OpenLootTableEditor("Container Loot: " .. rd.key, rd.lootOverride or {}, function(items)
                net.Start("event_container_set_loot")
                net.WriteString(rd.key)
                net.WriteTable(items)
                net.SendToServer()
            end)
        end)

        menu:AddOption("Set Respawn Delay…", function()
            Derma_StringRequest(
                "Set Respawn Delay",
                "Seconds for container " .. rd.key .. ":",
                "300",
                function(txt)
                    local d = tonumber(txt)
                    if not d then return end
                    net.Start("event_container_action")
                    net.WriteString(rd.key)
                    net.WriteString("setdelay")
                    net.WriteString(tostring(math.max(1, d)))
                    net.SendToServer()
                end
            )
        end)

        menu:AddSpacer()

        menu:AddOption("Delete Container", function()
            Derma_Query(
                "Delete container " .. rd.key .. "?",
                "Confirm",
                "Delete", function()
                    net.Start("event_container_action")
                    net.WriteString(rd.key)
                    net.WriteString("delete")
                    net.SendToServer()
                end,
                "Cancel", function() end
            )
        end)

        menu:Open()
    end

    frame.RefreshData = function()
        refreshContainerRows()
        refreshModelRows()
        refreshWorldRows()
    end
    frame.RefreshWorldData = refreshWorldRows

    frame:RefreshData()
    net.Start("event_container_list_request")
    net.SendToServer()
    -- Pull fresh ZRP world-prop scan (scanned + adopted) so the new World Props
    -- section is populated. Triggers ZRP_WorldPropSync below.
    net.Start("ZRP_ContainerRequestSync")
    net.SendToServer()
end



local function CreateLootPollingMenu()
    if IsValid(LootPollingMenu) then
        LootPollingMenu:Remove()
    end
    
    local serverName = GetHostName()
    local themeColor = Color(10, 10, 160)
    local accentColor = Color(40, 40, 160)
    local textColor = Color(255, 255, 255)
    
    Dynamic = 0
    LootPollingMenu = vgui.Create("ZFrame")
    LootPollingMenu:SetTitle("Event Loot Manager")
    LootPollingMenu:SetSize(700, 550)
    LootPollingMenu:Center()
    LootPollingMenu:MakePopup()
    LootPollingMenu:SetKeyboardInputEnabled(true)
    LootPollingMenu:ShowCloseButton(true)
    
    LootPollingMenu.Paint= function(self, w, h)
        
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(0, 0, w, h)
        
        surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        
        surface.SetFont("ZB_InterfaceMedium")
        surface.SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a)
        local text = "Event Loot Settings - " .. serverName
        local textW, textH = surface.GetTextSize(text)
        surface.SetTextPos(w/2 - textW/2, 10)
        surface.DrawText(text)
    end
    
    local itemList = vgui.Create("DListView", LootPollingMenu)
    itemList:SetPos(20, 50)
    itemList:SetSize(660, 300)
    itemList:SetMultiSelect(true)
    itemList:AddColumn("Weight").Width = 60
    itemList:AddColumn("Item Class").Width = 480
    itemList:AddColumn("BL").Width = 40
    itemList:AddColumn("WL").Width = 40
    
    itemList.Paint = function(self, w, h)
        surface.SetDrawColor(30, 30, 40, 200)
        surface.DrawRect(0, 0, w, h)
        
        surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 100)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    function LootPollingMenu:RefreshItems()
        itemList:Clear()
        
        for i, item in ipairs(eventLootTable) do
            local weight = item[1]
            local class = item[2]
            local cls = string.lower(string.Trim(tostring(class or "")))
            local bl = (eventLootBlacklist[cls] and "X") or ""
            local wl = (eventLootWhitelist[cls] and "X") or ""

            local line = itemList:AddLine(weight, class, bl, wl)
            line.ItemIndex = i
            line.ItemClass = cls
            
            line.Paint = function(self, w, h)
                if self:IsSelected() then
                    surface.SetDrawColor(themeColor.r, themeColor.g, themeColor.b, 150)
                    surface.DrawRect(0, 0, w, h)
                elseif self:IsHovered() then
                    surface.SetDrawColor(themeColor.r, themeColor.g, themeColor.b, 50)
                    surface.DrawRect(0, 0, w, h)
                else
                    if i % 2 == 0 then
                        surface.SetDrawColor(30, 30, 40, 100)
                    else
                        surface.SetDrawColor(40, 40, 50, 100)
                    end
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end
    end

    -- Right-click context menu: per-class blacklist/whitelist toggles
    -- (mirrors ZRP LootEditor functionality).
    itemList.OnRowRightClick = function(_, _, line)
        local cls = line and line.ItemClass
        if not cls or cls == "" then return end

        local menu = DermaMenu()
        local isBL = eventLootBlacklist[cls] and true or false
        local isWL = eventLootWhitelist[cls] and true or false

        menu:AddOption(isBL and "Remove from Blacklist" or "Add to Blacklist", function()
            net.Start("event_loot_blacklist_set")
                net.WriteString(cls)
                net.WriteBool(not isBL)
            net.SendToServer()
        end):SetIcon(isBL and "icon16/cross.png" or "icon16/delete.png")

        menu:AddOption(isWL and "Remove from Whitelist" or "Add to Whitelist", function()
            net.Start("event_loot_whitelist_set")
                net.WriteString(cls)
                net.WriteBool(not isWL)
            net.SendToServer()
        end):SetIcon(isWL and "icon16/cross.png" or "icon16/tick.png")

        menu:AddSpacer()

        menu:AddOption("Copy Class to Clipboard", function()
            SetClipboardText(cls)
        end):SetIcon("icon16/page_copy.png")

        menu:Open()
    end
    
    local controlPanel = vgui.Create("DPanel", LootPollingMenu)
    controlPanel:SetPos(20, 370)
    controlPanel:SetSize(660, 70)
    controlPanel.Paint = function(self, w, h)
        surface.SetDrawColor(30, 30, 40, 200)
        surface.DrawRect(0, 0, w, h)
        
        surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 100)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    local weightLabel = vgui.Create("DLabel", controlPanel)
    weightLabel:SetPos(15, 10)
    weightLabel:SetText("Weight (Chance):")
    weightLabel:SetTextColor(textColor)
    weightLabel:SizeToContents()
    
    local weightEntry = vgui.Create("DNumberWang", controlPanel)
    weightEntry:SetPos(15, 35)
    weightEntry:SetSize(60, 25)
    weightEntry:SetMinMax(1, 100)
    weightEntry:SetValue(5)
    
    local classLabel = vgui.Create("DLabel", controlPanel)
    classLabel:SetPos(90, 10)
    classLabel:SetText("Item Class:")
    classLabel:SetTextColor(textColor)
    classLabel:SizeToContents()
    
    local classEntry = vgui.Create("DTextEntry", controlPanel)
    classEntry:SetPos(90, 35)
    classEntry:SetSize(380, 25)
    classEntry:SetPlaceholderText("Select from browser or type any registered class")
    
    local addButton = vgui.Create("DButton", controlPanel)
    addButton:SetPos(480, 35)
    addButton:SetSize(100, 25)
    addButton:SetText("Add Item")
    addButton:SetTextColor(textColor)
    addButton.Paint = function(self, w, h)
        if self:IsHovered() then
            surface.SetDrawColor(themeColor.r, themeColor.g, themeColor.b, 200)
        else
            surface.SetDrawColor(themeColor.r, themeColor.g, themeColor.b, 150)
        end
        surface.DrawRect(0, 0, w, h)
        
        surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 200)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    addButton.DoClick = function()
        local weight = weightEntry:GetValue()
        local class = classEntry:GetValue()
        
        if weight <= 0 or class == "" then
            notification.AddLegacy("Please specify weight and item class", NOTIFY_ERROR, 3)
            return
        end
        
        net.Start("event_loot_add")
        net.WriteTable({
            weight = weight,
            class = class
        })
        net.SendToServer()
        
        surface.PlaySound("buttons/button14.wav")
    end
    
    local buttonPanel = vgui.Create("DPanel", LootPollingMenu)
    buttonPanel:SetPos(20, 460)
    buttonPanel:SetSize(660, 70)
    buttonPanel.Paint = function(self, w, h)
        surface.SetDrawColor(30, 30, 40, 200)
        surface.DrawRect(0, 0, w, h)
        
        surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 100)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    local createButton = function(parent, x, y, w, h, text, color, hoverColor, clickFunc)
        local btn = vgui.Create("DButton", parent)
        btn:SetPos(x, y)
        btn:SetSize(w, h)
        btn:SetText(text)
        btn:SetTextColor(textColor)
        btn.Paint = function(self, width, height)
            if self:IsHovered() then
                surface.SetDrawColor(hoverColor.r, hoverColor.g, hoverColor.b, 200)
            else
                surface.SetDrawColor(color.r, color.g, color.b, 150)
            end
            surface.DrawRect(0, 0, width, height)
            
            surface.SetDrawColor(hoverColor.r, hoverColor.g, hoverColor.b, 200)
            surface.DrawOutlinedRect(0, 0, width, height, 1)
        end
        btn.DoClick = function()
            clickFunc()
            surface.PlaySound("buttons/button14.wav")
        end
        return btn
    end
    
    local removeButton = createButton(buttonPanel, 15, 20, 140, 30, "Remove Selected", 
        Color(180, 10, 10), Color(220, 30, 30),
        function()
            local selected = itemList:GetSelected() or {}
            if #selected == 0 then return end

            local indices = {}
            for _, line in ipairs(selected) do
                if line and line.ItemIndex then
                    indices[#indices + 1] = tonumber(line.ItemIndex)
                end
            end

            if #indices == 0 then return end
            table.sort(indices, function(a, b) return a > b end)

            for _, idx in ipairs(indices) do
                net.Start("event_loot_remove")
                net.WriteUInt(idx, 16)
                net.SendToServer()
            end
        end
    )
    
    local resetButton = createButton(buttonPanel, 505, 20, 140, 30, "Reset All", 
        Color(180, 10, 10), Color(220, 30, 30),
        function()
            if not LocalPlayer():IsAdmin() and not EventersList[LocalPlayer():SteamID()] then return end
            
            Derma_Query(
                "Are you sure you want to reset the entire loot table?",
                "Confirmation",
                "Yes", function()
                    RunConsoleCommand("zb_event_loot_reset")
                end,
                "No", function() end
            )
        end
    )
    
    local browseButton = createButton(buttonPanel, 165, 20, 235, 30, "Browse Registered Classes", 
        Color(80, 80, 160), Color(100, 100, 190),
        function()
            OpenLootRegistryPicker(classEntry)
        end
    )

    local containerMgrButton = createButton(buttonPanel, 405, 20, 95, 30, "Containers", 
        Color(80, 120, 80), Color(100, 150, 100),
        function()
            OpenContainerManagerMenu()
        end
    )

    local autoRefillCheck = vgui.Create("DCheckBoxLabel", buttonPanel)
    autoRefillCheck:SetPos(15, 2)
    autoRefillCheck:SetText("Auto-refill containers every 5 minutes")
    autoRefillCheck:SetTextColor(textColor)
    autoRefillCheck:SetValue(eventLootSettings.autoRefill and 1 or 0)
    autoRefillCheck:SizeToContents()

    local applySettingsButton = vgui.Create("DButton", buttonPanel)
    applySettingsButton:SetPos(505, 2)
    applySettingsButton:SetSize(140, 16)
    applySettingsButton:SetText("Apply Refill Setting")
    applySettingsButton:SetTextColor(textColor)
    applySettingsButton.Paint = function(self, w, h)
        if self:IsHovered() then
            surface.SetDrawColor(100, 120, 60, 200)
        else
            surface.SetDrawColor(80, 100, 40, 150)
        end
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(120, 150, 70, 200)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    applySettingsButton.DoClick = function()
        net.Start("event_loot_settings_set")
        net.WriteBool(autoRefillCheck:GetChecked())
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end
    
    local infoLabel = vgui.Create("DLabel", LootPollingMenu)
    infoLabel:SetPos(210, 535)
    infoLabel:SetText("Container loot table is automatically saved. Auto-refill rerolls on reset.")
    infoLabel:SetTextColor(Color(180, 180, 180))
    infoLabel:SizeToContents()

    -- Help button (parity with ZRP LootEditor's Help tab). Compact ? button at
    -- top-right that pops a Derma_Message style window with documentation.
    local helpButton = vgui.Create("DButton", LootPollingMenu)
    helpButton:SetPos(660, 8)
    helpButton:SetSize(28, 22)
    helpButton:SetText("?")
    helpButton:SetTextColor(textColor)
    helpButton:SetTooltip("Help / Documentation")
    helpButton.Paint = function(self, w, h)
        local c = self:IsHovered() and 200 or 150
        surface.SetDrawColor(themeColor.r, themeColor.g, themeColor.b, c)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 200)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    helpButton.DoClick = function()
        local hf = vgui.Create("DFrame")
        hf:SetTitle("Event Loot Manager - Help")
        hf:SetSize(640, 520)
        hf:Center()
        hf:MakePopup()
        local txt = vgui.Create("DTextEntry", hf)
        txt:Dock(FILL)
        txt:DockMargin(6, 6, 6, 6)
        txt:SetMultiline(true)
        txt:SetEditable(false)
        txt:SetFont("DermaDefaultBold")
        txt:SetValue([[
EVENT LOOT MANAGER
==================

LOOT TABLE
  This is the global loot pool used by every event-mode container that
  does not have its own per-model or per-container override. Add classes
  (or wildcards like *ammo*, *attachments*, *sight*, *barrel*) with a
  spawn weight (1 = rare, 100 = common). Wildcards expand at refill time.

CONTAINERS  (Containers button)
  Spawned Containers list = every ZRP container (toolgun-placed) and
  every adopted world prop currently tracked. Right-click a row for:
    Goto                    - teleport to container
    Activate / Refill Now   - regenerate loot immediately
    Edit Container Loot     - per-container override (replaces global pool)
    Set Respawn Delay       - custom seconds for THIS container only
    Delete Container        - remove permanently

CONTAINER MODELS (whitelist / loot profile / min-max)
  Per-MODEL settings apply to every container that uses that mdl path.
    Edit Model Loot     - override pool used by all containers of this model
    Min / Max Items     - cap how many items roll per refill
    Toggle Whitelist    - if a model is whitelisted, staff-spawned props of
                          that model will auto-adopt as event containers.

UNADOPTED LOOTABLE MAP PROPS
  Map props whose model matches hg.loot_boxes but have not yet been adopted
  as ZRP containers. Right-click Adopt (or use the button) to convert a
  prop into a persistent ZRP world container that refills on both ZRP and
  Event mode. Use "Refresh Scan" to re-poll the server.

ZRP CONTAINER PARITY
  Containers placed via the ZRP LootEditor toolgun (LMB) and props adopted
  via toolgun (RMB) are stored in ZRP.Containers / ZRP.WorldContainerData
  and refill identically on ZRP mode and Event mode. Per-container/
  per-model overrides edited here are applied during event refills only.

KEYBINDS
  !eventloot  - open this menu (admins / eventers)
  zb_event_loot_menu - same, via console
]])
    end

    LootPollingMenu:RefreshItems()
    
    return LootPollingMenu
end


net.Receive("event_loot_sync", function()
    eventLootTable = net.ReadTable()

    if IsValid(LootPollingMenu) then
        LootPollingMenu:RefreshItems()
    end
end)

-- Per-class blacklist / whitelist sync (ZRP LootEditor parity).
net.Receive("event_loot_bw_sync", function()
    eventLootBlacklist = net.ReadTable() or {}
    eventLootWhitelist = net.ReadTable() or {}

    if IsValid(LootPollingMenu) and LootPollingMenu.RefreshItems then
        LootPollingMenu:RefreshItems()
    end
end)

net.Receive("event_loot_settings_sync", function()
    eventLootSettings.autoRefill = net.ReadBool()
    eventLootSettings.interval = net.ReadFloat()
end)

net.Receive("event_loot_wildcards_sync", function()
    eventCustomWildcardGroups = net.ReadTable() or {}
    LootRegistryCache = nil
    if IsValid(LootPollingMenu) and LootPollingMenu.RefreshItems then
        LootPollingMenu:RefreshItems()
    end
end)

local eventWildcardOverrides = {}

net.Receive("event_loot_wildcard_overrides_sync", function()
    eventWildcardOverrides = net.ReadTable() or {}
end)

local function OpenWildcardContentsEditor(token, isBuiltIn, isCustom, defaults, current)
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Edit Wildcard: " .. token
        .. (isBuiltIn and " (built-in)" or "")
        .. (isCustom and " (custom)" or ""))
    frame:SetSize(720, 540)
    frame:Center()
    frame:MakePopup()

    local entries = {}
    local seen = {}
    for _, c in ipairs(current or {}) do
        c = string.lower(string.Trim(tostring(c or "")))
        if c ~= "" and not seen[c] then
            seen[c] = true
            entries[#entries + 1] = c
        end
    end

    local helpText = vgui.Create("DLabel", frame)
    helpText:SetPos(10, 30)
    helpText:SetSize(700, 36)
    helpText:SetWrap(true)
    helpText:SetText(isBuiltIn
        and "Editing this list overrides the built-in expansion. Empty list = restore defaults."
        or "Editing this list rewrites the custom wildcard. Empty list = remove the wildcard.")

    local list = vgui.Create("DListView", frame)
    list:SetPos(10, 70)
    list:SetSize(700, 350)
    list:SetMultiSelect(true)
    list:AddColumn("Class")

    local function refresh()
        list:Clear()
        table.sort(entries)
        for i, c in ipairs(entries) do
            local line = list:AddLine(c)
            line.RowIndex = i
            line.LootClass = c
        end
    end

    list.OnRowRightClick = function(_, _, line)
        if not line or not line.LootClass then return end
        local menu = DermaMenu()
        menu:AddOption("Remove " .. line.LootClass, function()
            for i, c in ipairs(entries) do
                if c == line.LootClass then
                    table.remove(entries, i)
                    refresh()
                    return
                end
            end
        end)
        menu:Open()
    end

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(10, 430)
    entry:SetSize(420, 24)
    entry:SetPlaceholderText("Class name (e.g. weapon_glock18)")

    local browse = vgui.Create("DButton", frame)
    browse:SetPos(440, 430)
    browse:SetSize(80, 24)
    browse:SetText("Browse")
    browse.DoClick = function() OpenLootRegistryPicker(entry) end

    local addBtn = vgui.Create("DButton", frame)
    addBtn:SetPos(530, 430)
    addBtn:SetSize(80, 24)
    addBtn:SetText("Add")
    addBtn.DoClick = function()
        local v = string.lower(string.Trim(tostring(entry:GetValue() or "")))
        if v == "" then return end
        if string.match(v, "^%*[%w_]+%*$") then
            notification.AddLegacy("Cannot nest wildcards.", NOTIFY_ERROR, 2)
            return
        end
        for _, c in ipairs(entries) do if c == v then return end end
        entries[#entries + 1] = v
        entry:SetValue("")
        refresh()
    end

    local removeBtn = vgui.Create("DButton", frame)
    removeBtn:SetPos(620, 430)
    removeBtn:SetSize(90, 24)
    removeBtn:SetText("Remove Sel")
    removeBtn.DoClick = function()
        local sel = list:GetSelected() or {}
        local kill = {}
        for _, line in ipairs(sel) do
            if line.LootClass then kill[line.LootClass] = true end
        end
        local kept = {}
        for _, c in ipairs(entries) do
            if not kill[c] then kept[#kept + 1] = c end
        end
        entries = kept
        refresh()
    end

    if isBuiltIn and #defaults > 0 then
        local resetBtn = vgui.Create("DButton", frame)
        resetBtn:SetPos(10, 465)
        resetBtn:SetSize(160, 24)
        resetBtn:SetText("Load Defaults")
        resetBtn.DoClick = function()
            entries = {}
            seen = {}
            for _, c in ipairs(defaults) do
                if not seen[c] then
                    seen[c] = true
                    entries[#entries + 1] = c
                end
            end
            refresh()
        end

        local clearBtn = vgui.Create("DButton", frame)
        clearBtn:SetPos(180, 465)
        clearBtn:SetSize(160, 24)
        clearBtn:SetText("Clear All")
        clearBtn.DoClick = function()
            entries = {}
            refresh()
        end
    else
        local clearBtn = vgui.Create("DButton", frame)
        clearBtn:SetPos(10, 465)
        clearBtn:SetSize(160, 24)
        clearBtn:SetText("Clear All")
        clearBtn.DoClick = function()
            entries = {}
            refresh()
        end
    end

    local save = vgui.Create("DButton", frame)
    save:SetPos(530, 500)
    save:SetSize(85, 30)
    save:SetText("Save")
    save.DoClick = function()
        net.Start("event_loot_wildcard_contents_set")
        net.WriteString(token)
        net.WriteTable(entries)
        net.SendToServer()
        frame:Close()
    end

    local cancel = vgui.Create("DButton", frame)
    cancel:SetPos(625, 500)
    cancel:SetSize(85, 30)
    cancel:SetText("Cancel")
    cancel.DoClick = function() frame:Close() end

    refresh()
    return frame
end

net.Receive("event_loot_wildcard_contents_sync", function()
    local token = net.ReadString()
    local isBuiltIn = net.ReadBool()
    local isCustom = net.ReadBool()
    local defaults = net.ReadTable() or {}
    local current = net.ReadTable() or {}
    OpenWildcardContentsEditor(token, isBuiltIn, isCustom, defaults, current)
end)



concommand.Add("zb_event_loot_menu", function()
    RunConsoleCommand("zb_event_lootpoll")
end)


net.Receive("event_loot_request", function()
    CreateLootPollingMenu()
end)

-- ── Event respawn countdown HUD ───────────────────────────────────────────────
local eventRespawnEndTime  = nil
local eventRespawnTotalTime = nil

net.Receive("ZC_EventRespawnTimer", function()
    local t = net.ReadFloat()
    if t < 0 then
        eventRespawnEndTime  = nil
        eventRespawnTotalTime = nil
    else
        eventRespawnEndTime  = CurTime() + t
        eventRespawnTotalTime = t
    end
end)

local COL_EVENT_TEXT = Color(255, 165,  50, 220)
local COL_EVENT_BAR  = Color(255, 120,  20, 200)
local COL_EVENT_BG   = Color(  0,   0,   0, 140)

hook.Add("HUDPaint", "ZCity_EventRespawnHUD", function()
    if not eventRespawnEndTime then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:Alive() then
        eventRespawnEndTime  = nil
        eventRespawnTotalTime = nil
        return
    end

    local remaining = math.max(0, eventRespawnEndTime - CurTime())

    -- Auto-clear 3s after hitting zero in case the server message is lost
    if remaining == 0 and CurTime() > eventRespawnEndTime + 3 then
        eventRespawnEndTime  = nil
        eventRespawnTotalTime = nil
        return
    end

    local fraction = eventRespawnTotalTime and eventRespawnTotalTime > 0
        and (1 - remaining / eventRespawnTotalTime)
        or 1

    local sw, sh = ScrW(), ScrH()
    local barW = 300
    local barH = 6
    local x    = sw / 2 - barW / 2
    local y    = sh * 0.72

    draw.RoundedBox(4, x - 10, y - 30, barW + 20, barH + 44, COL_EVENT_BG)

    draw.SimpleText(
        "Respawning in " .. math.ceil(remaining) .. "s",
        "HomigradFontMedium", sw / 2, y - 18,
        COL_EVENT_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )

    draw.RoundedBox(3, x, y, barW, barH, Color(40, 40, 40, 180))
    draw.RoundedBox(3, x, y, barW * fraction, barH, COL_EVENT_BAR)
end)

net.Receive("event_container_list_sync", function()
    eventContainerList = net.ReadTable() or {}
    if IsValid(ContainerManagerMenu) and ContainerManagerMenu.RefreshData then
        ContainerManagerMenu:RefreshData()
    end
end)

-- Refresh the World Props section whenever ZRP pushes new scanned/adopted
-- data (own RMB adopt, toolgun adopt, or the periodic sync). The data itself
-- lives in cl_zrp_loot_editor's ZRP_CL table; we read it via ZRP_GetWorldData.
hook.Add("ZRP_WorldDataUpdated", "ZC_Event_RefreshWorldList", function()
    if IsValid(ContainerManagerMenu) and ContainerManagerMenu.RefreshWorldData then
        ContainerManagerMenu:RefreshWorldData()
    end
end)

net.Receive("event_model_loot_profiles_sync", function()
    eventModelLootProfiles = net.ReadTable() or {}
    eventModelLootCaps = net.ReadTable() or {}
    eventContainerWhitelist = net.ReadTable() or {}
    eventModelLootMins = net.ReadTable() or {}
    if IsValid(ContainerManagerMenu) and ContainerManagerMenu.RefreshData then
        ContainerManagerMenu:RefreshData()
    end
end)