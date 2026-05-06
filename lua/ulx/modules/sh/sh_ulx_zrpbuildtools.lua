-- sh_ulx_zrpbuildtools.lua
-- ZRP build management:
--   - Admin whitelist/blacklist GUI and spawnmenu actions
--   - Batch model actions from multi-selection
--   - Player buddy menu for prop interaction permissions

if SERVER then
    AddCSLuaFile()
end

if not ulx or not ULib then return end

local CATEGORY_NAME = "ZCity"

local function NormalizeBuildValue(value)
    value = string.Trim(string.lower(tostring(value or "")))
    if value == "" then return nil end
    return value
end

if SERVER then
    util.AddNetworkString("ZRP_BuildWL_OpenMenu")
    util.AddNetworkString("ZRP_BuildWL_RequestSync")
    util.AddNetworkString("ZRP_BuildWL_Sync")
    util.AddNetworkString("ZRP_BuildWL_BatchSet")
    util.AddNetworkString("ZRP_BuildBuddy_OpenMenu")
    util.AddNetworkString("ZRP_BuildBuddy_RequestSync")
    util.AddNetworkString("ZRP_BuildBuddy_Sync")
    util.AddNetworkString("ZRP_BuildBuddy_Set")

    local function EnsureZRPReady(calling_ply)
        if ZRP
            and istable(ZRP.BuildPropWhitelist)
            and istable(ZRP.BuildPropBlacklist)
            and istable(ZRP.BuildToolWhitelist)
            and istable(ZRP.BuildBuddyLists)
        then
            return true
        end

        if IsValid(calling_ply) then
            calling_ply:ChatPrint("[ZRP Build] ZRP build system is not loaded.")
        end
        return false
    end

    local function SaveBuildDataIfAvailable()
        if ZRP and isfunction(ZRP.SaveBuildData) then
            ZRP.SaveBuildData()
        end
    end

    local function FindPlayerByBuildKey(key)
        key = string.Trim(tostring(key or ""))
        if key == "" then return nil end

        for _, ply in ipairs(player.GetAll()) do
            local sid = ply:SteamID64() or ply:SteamID()
            if sid == key then
                return ply
            end
        end

        return nil
    end

    local function SortedKeys(tbl)
        local out = {}
        for key, value in pairs(tbl or {}) do
            if value == true then
                out[#out + 1] = tostring(key)
            end
        end
        table.sort(out)
        return out
    end

    local function BuildBuddySyncPayload(ply)
        local ownKey = (ply:SteamID64() or ply:SteamID() or "")
        local current = ZRP.GetBuildBuddyList and ZRP.GetBuildBuddyList(ply) or {}
        local players = {}
        local buddies = {}

        for _, target in ipairs(player.GetAll()) do
            if target ~= ply then
                local key = target:SteamID64() or target:SteamID()
                players[#players + 1] = {
                    key = key,
                    name = target:Nick(),
                    isBuddy = istable(current) and current[key] == true or false,
                }
            end
        end

        table.sort(players, function(a, b)
            return a.name < b.name
        end)

        for key, state in pairs(current or {}) do
            if state == true then
                local target = FindPlayerByBuildKey(key)
                buddies[#buddies + 1] = {
                    key = key,
                    name = IsValid(target) and target:Nick() or key,
                }
            end
        end

        table.sort(buddies, function(a, b)
            return a.name < b.name
        end)

        return {
            ownKey = ownKey,
            players = players,
            buddies = buddies,
        }
    end

    local function SyncBuddyMenuTo(ply)
        if not IsValid(ply) or not EnsureZRPReady(ply) then return end
        net.Start("ZRP_BuildBuddy_Sync")
        net.WriteTable(BuildBuddySyncPayload(ply))
        net.Send(ply)
    end

    local function SyncWhitelistTo(ply)
        if not IsValid(ply) or not EnsureZRPReady(ply) then return end
        net.Start("ZRP_BuildWL_Sync")
        net.WriteTable({
            props = SortedKeys(ZRP.BuildPropWhitelist),
            propBlacklist = SortedKeys(ZRP.BuildPropBlacklist),
            tools = SortedKeys(ZRP.BuildToolWhitelist),
        })
        net.Send(ply)
    end

    local function SetWhitelistEntry(calling_ply, listName, value, enabled, options)
        if not EnsureZRPReady(calling_ply) then return false end

        local key = NormalizeBuildValue(value)
        if not key then
            if IsValid(calling_ply) then
                calling_ply:ChatPrint("[ZRP Build] Invalid value.")
            end
            return false
        end

        if listName == "prop_whitelist" or listName == "prop_blacklist" then
            if string.find(key, "%.%.", 1, true) or not string.EndsWith(key, ".mdl") then
                if IsValid(calling_ply) then
                    calling_ply:ChatPrint("[ZRP Build] Invalid prop model path.")
                end
                return false
            end

            if listName == "prop_whitelist" then
                if enabled then
                    ZRP.BuildPropWhitelist[key] = true
                    ZRP.BuildPropBlacklist[key] = nil
                else
                    ZRP.BuildPropWhitelist[key] = nil
                end
            else
                if enabled then
                    ZRP.BuildPropBlacklist[key] = true
                    ZRP.BuildPropWhitelist[key] = nil
                else
                    ZRP.BuildPropBlacklist[key] = nil
                end
            end
        elseif listName == "tool_whitelist" then
            if enabled then
                ZRP.BuildToolWhitelist[key] = true
            else
                ZRP.BuildToolWhitelist[key] = nil
            end
        else
            if IsValid(calling_ply) then
                calling_ply:ChatPrint("[ZRP Build] Unknown list target.")
            end
            return false
        end

        if not (options and options.deferSave) then
            SaveBuildDataIfAvailable()
        end

        return true, key
    end

    local function ApplyBatchWhitelist(calling_ply, listName, values, enabled)
        if not EnsureZRPReady(calling_ply) then return 0 end
        if not istable(values) then return 0 end

        local changed = 0
        local seen = {}
        for _, rawValue in ipairs(values) do
            local key = NormalizeBuildValue(rawValue)
            if key and not seen[key] then
                seen[key] = true
                local ok = SetWhitelistEntry(calling_ply, listName, key, enabled, { deferSave = true })
                if ok then
                    changed = changed + 1
                end
            end
        end

        if changed > 0 then
            SaveBuildDataIfAvailable()
        end

        return changed
    end

    local function ulxWhitelistPropAdd(calling_ply, model)
        local ok, key = SetWhitelistEntry(calling_ply, "prop_whitelist", model, true)
        if not ok then return end
        ulx.fancyLogAdmin(calling_ply, "#A added #s to ZRP prop whitelist", key)
        SyncWhitelistTo(calling_ply)
    end

    local function ulxWhitelistPropRemove(calling_ply, model)
        local ok, key = SetWhitelistEntry(calling_ply, "prop_whitelist", model, false)
        if not ok then return end
        ulx.fancyLogAdmin(calling_ply, "#A removed #s from ZRP prop whitelist", key)
        SyncWhitelistTo(calling_ply)
    end

    local function ulxBlacklistPropAdd(calling_ply, model)
        local ok, key = SetWhitelistEntry(calling_ply, "prop_blacklist", model, true)
        if not ok then return end
        ulx.fancyLogAdmin(calling_ply, "#A added #s to ZRP prop blacklist", key)
        SyncWhitelistTo(calling_ply)
    end

    local function ulxBlacklistPropRemove(calling_ply, model)
        local ok, key = SetWhitelistEntry(calling_ply, "prop_blacklist", model, false)
        if not ok then return end
        ulx.fancyLogAdmin(calling_ply, "#A removed #s from ZRP prop blacklist", key)
        SyncWhitelistTo(calling_ply)
    end

    local function ulxWhitelistToolAdd(calling_ply, tool)
        local ok, key = SetWhitelistEntry(calling_ply, "tool_whitelist", tool, true)
        if not ok then return end
        ulx.fancyLogAdmin(calling_ply, "#A added #s to ZRP tool whitelist", key)
        SyncWhitelistTo(calling_ply)
    end

    local function ulxWhitelistToolRemove(calling_ply, tool)
        local ok, key = SetWhitelistEntry(calling_ply, "tool_whitelist", tool, false)
        if not ok then return end
        ulx.fancyLogAdmin(calling_ply, "#A removed #s from ZRP tool whitelist", key)
        SyncWhitelistTo(calling_ply)
    end

    local function ulxWhitelistMenu(calling_ply)
        if not IsValid(calling_ply) or not EnsureZRPReady(calling_ply) then return end
        SyncWhitelistTo(calling_ply)
        net.Start("ZRP_BuildWL_OpenMenu")
        net.Send(calling_ply)
    end

    local propAddCmd = ulx.command(CATEGORY_NAME, "ulx zrpwlpropadd", ulxWhitelistPropAdd, "!zrpwlpropadd")
    propAddCmd:addParam{ type = ULib.cmds.StringArg, hint = "models/... .mdl" }
    propAddCmd:defaultAccess(ULib.ACCESS_ADMIN)
    propAddCmd:help("Add a model to the ZRP prop whitelist.")

    local propRemoveCmd = ulx.command(CATEGORY_NAME, "ulx zrpwlpropremove", ulxWhitelistPropRemove, "!zrpwlpropremove")
    propRemoveCmd:addParam{ type = ULib.cmds.StringArg, hint = "models/... .mdl" }
    propRemoveCmd:defaultAccess(ULib.ACCESS_ADMIN)
    propRemoveCmd:help("Remove a model from the ZRP prop whitelist.")

    local propBlacklistAddCmd = ulx.command(CATEGORY_NAME, "ulx zrpwlpropblacklistadd", ulxBlacklistPropAdd, "!zrpwlpropblacklistadd")
    propBlacklistAddCmd:addParam{ type = ULib.cmds.StringArg, hint = "models/... .mdl" }
    propBlacklistAddCmd:defaultAccess(ULib.ACCESS_ADMIN)
    propBlacklistAddCmd:help("Add a model to the ZRP prop blacklist.")

    local propBlacklistRemoveCmd = ulx.command(CATEGORY_NAME, "ulx zrpwlpropblacklistremove", ulxBlacklistPropRemove, "!zrpwlpropblacklistremove")
    propBlacklistRemoveCmd:addParam{ type = ULib.cmds.StringArg, hint = "models/... .mdl" }
    propBlacklistRemoveCmd:defaultAccess(ULib.ACCESS_ADMIN)
    propBlacklistRemoveCmd:help("Remove a model from the ZRP prop blacklist.")

    local toolAddCmd = ulx.command(CATEGORY_NAME, "ulx zrpwltooladd", ulxWhitelistToolAdd, "!zrpwltooladd")
    toolAddCmd:addParam{ type = ULib.cmds.StringArg, hint = "toolname" }
    toolAddCmd:defaultAccess(ULib.ACCESS_ADMIN)
    toolAddCmd:help("Add a tool to the ZRP tool whitelist.")

    local toolRemoveCmd = ulx.command(CATEGORY_NAME, "ulx zrpwltoolremove", ulxWhitelistToolRemove, "!zrpwltoolremove")
    toolRemoveCmd:addParam{ type = ULib.cmds.StringArg, hint = "toolname" }
    toolRemoveCmd:defaultAccess(ULib.ACCESS_ADMIN)
    toolRemoveCmd:help("Remove a tool from the ZRP tool whitelist.")

    local menuCmd = ulx.command(CATEGORY_NAME, "ulx zrpwlmenu", ulxWhitelistMenu, "!zrpwlmenu")
    menuCmd:defaultAccess(ULib.ACCESS_ADMIN)
    menuCmd:help("Open the ZRP build whitelist GUI.")

    concommand.Add("zrp_buddymenu", function(ply)
        if not IsValid(ply) or not EnsureZRPReady(ply) then return end
        SyncBuddyMenuTo(ply)
        net.Start("ZRP_BuildBuddy_OpenMenu")
        net.Send(ply)
    end)

    net.Receive("ZRP_BuildWL_RequestSync", function(_, ply)
        if not IsValid(ply) or not ply:IsAdmin() then return end
        SyncWhitelistTo(ply)
    end)

    net.Receive("ZRP_BuildWL_BatchSet", function(_, ply)
        if not IsValid(ply) or not ply:IsAdmin() then return end

        local listName = net.ReadString()
        local enabled = net.ReadBool()
        local values = net.ReadTable() or {}
        local changed = ApplyBatchWhitelist(ply, listName, values, enabled)
        if changed > 0 then
            ulx.fancyLogAdmin(ply, "#A updated #i ZRP build entries in #s", changed, listName)
        end
        SyncWhitelistTo(ply)
    end)

    net.Receive("ZRP_BuildBuddy_RequestSync", function(_, ply)
        if not IsValid(ply) then return end
        SyncBuddyMenuTo(ply)
    end)

    net.Receive("ZRP_BuildBuddy_Set", function(_, ply)
        if not IsValid(ply) or not EnsureZRPReady(ply) then return end

        local targetKey = string.Trim(net.ReadString() or "")
        local state = net.ReadBool()
        if targetKey == "" then return end

        local ok = ZRP.SetBuildBuddyState and ZRP.SetBuildBuddyState(ply, targetKey, state)
        if ok then
            SyncBuddyMenuTo(ply)
        else
            ply:ChatPrint("[ZRP Build] Failed to update buddy list.")
        end
    end)

    return
end

-- CLIENT

local function IsAdminLike()
    local lp = LocalPlayer()
    return IsValid(lp) and (lp:IsAdmin() or lp:IsSuperAdmin())
end

local function RunULXArgs(...)
    if not IsAdminLike() then return end
    RunConsoleCommand("ulx", ...)
end

local function RequestWhitelistSync()
    net.Start("ZRP_BuildWL_RequestSync")
    net.SendToServer()
end

local function RequestBuddySync()
    net.Start("ZRP_BuildBuddy_RequestSync")
    net.SendToServer()
end

local function SendBatchWhitelist(listName, enabled, values)
    if not IsAdminLike() then return end
    if not istable(values) or #values == 0 then return end
    net.Start("ZRP_BuildWL_BatchSet")
    net.WriteString(listName)
    net.WriteBool(enabled)
    net.WriteTable(values)
    net.SendToServer()
end

local function SendBuddySet(targetKey, enabled)
    if not IsValid(LocalPlayer()) then return end
    net.Start("ZRP_BuildBuddy_Set")
    net.WriteString(targetKey or "")
    net.WriteBool(enabled == true)
    net.SendToServer()
end

local function BuildListSection(parent, titleText, height)
    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:SetTall(height or 170)
    panel:DockMargin(0, 0, 0, 8)

    local title = vgui.Create("DLabel", panel)
    title:Dock(TOP)
    title:SetTall(20)
    title:SetText(titleText)

    local list = vgui.Create("DListView", panel)
    list:Dock(FILL)
    list:AddColumn("Value")

    return list
end

local function GetSelectedLineValue(list)
    if not IsValid(list) then return nil end
    local lineId = list:GetSelectedLine()
    if not lineId then return nil end
    local line = list:GetLine(lineId)
    if not IsValid(line) then return nil end
    return line:GetColumnText(1)
end

local function GatherSelectionModels(selectionCanvas)
    if not IsValid(selectionCanvas) then return {} end
    local out = {}
    local seen = {}
    for _, icon in ipairs(selectionCanvas:GetSelectedChildren() or {}) do
        if IsValid(icon) and icon.GetModelName then
            local model = NormalizeBuildValue(icon:GetModelName())
            if model and string.EndsWith(model, ".mdl") and not seen[model] then
                seen[model] = true
                out[#out + 1] = model
            end
        end
    end
    table.sort(out)
    return out
end

local function AddPropBatchOptions(menu, models)
    if not IsValid(menu) or not istable(models) or #models == 0 then return end

    local suffix = #models == 1 and "model" or (#models .. " selected models")
    menu:AddOption("ZRP: Add " .. suffix .. " to whitelist", function()
        SendBatchWhitelist("prop_whitelist", true, models)
    end)
    menu:AddOption("ZRP: Remove " .. suffix .. " from whitelist", function()
        SendBatchWhitelist("prop_whitelist", false, models)
    end)
    menu:AddOption("ZRP: Add " .. suffix .. " to blacklist", function()
        SendBatchWhitelist("prop_blacklist", true, models)
    end)
    menu:AddOption("ZRP: Remove " .. suffix .. " from blacklist", function()
        SendBatchWhitelist("prop_blacklist", false, models)
    end)
end

local function OpenBuddyMenu(sync)
    if IsValid(ZRP_BuildBuddyFrame) then
        ZRP_BuildBuddyFrame:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(760, 620)
    frame:Center()
    frame:SetTitle("ZRP Prop Buddies")
    frame:MakePopup()
    ZRP_BuildBuddyFrame = frame

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL)
    body:DockMargin(8, 8, 8, 8)

    local help = vgui.Create("DLabel", body)
    help:Dock(TOP)
    help:SetTall(28)
    help:SetWrap(true)
    help:SetText("Only you, admins, and players on your buddy list can interact with props you spawned in ZRP.")

    local playerList = vgui.Create("DListView", body)
    playerList:Dock(TOP)
    playerList:SetTall(260)
    playerList:AddColumn("Player")
    playerList:AddColumn("SteamID")
    playerList:AddColumn("Buddy")

    for _, row in ipairs(sync and sync.players or {}) do
        local line = playerList:AddLine(row.name or row.key, row.key or "", row.isBuddy and "YES" or "-")
        line.ZRP_TargetKey = row.key
    end

    local playerButtons = vgui.Create("DPanel", body)
    playerButtons:Dock(TOP)
    playerButtons:SetTall(28)
    playerButtons:DockMargin(0, 4, 0, 8)

    local addBuddy = vgui.Create("DButton", playerButtons)
    addBuddy:Dock(LEFT)
    addBuddy:SetWide(120)
    addBuddy:SetText("Add Buddy")
    addBuddy.DoClick = function()
        local lineId = playerList:GetSelectedLine()
        if not lineId then return end
        local line = playerList:GetLine(lineId)
        if not IsValid(line) or not line.ZRP_TargetKey then return end
        SendBuddySet(line.ZRP_TargetKey, true)
    end

    local removeBuddy = vgui.Create("DButton", playerButtons)
    removeBuddy:Dock(LEFT)
    removeBuddy:SetWide(120)
    removeBuddy:DockMargin(8, 0, 0, 0)
    removeBuddy:SetText("Remove Buddy")
    removeBuddy.DoClick = function()
        local lineId = playerList:GetSelectedLine()
        if not lineId then return end
        local line = playerList:GetLine(lineId)
        if not IsValid(line) or not line.ZRP_TargetKey then return end
        SendBuddySet(line.ZRP_TargetKey, false)
    end

    local currentList = vgui.Create("DListView", body)
    currentList:Dock(TOP)
    currentList:SetTall(180)
    currentList:AddColumn("Current Buddy")
    currentList:AddColumn("SteamID")

    for _, row in ipairs(sync and sync.buddies or {}) do
        local line = currentList:AddLine(row.name or row.key, row.key or "")
        line.ZRP_TargetKey = row.key
    end

    local currentButtons = vgui.Create("DPanel", body)
    currentButtons:Dock(TOP)
    currentButtons:SetTall(28)
    currentButtons:DockMargin(0, 4, 0, 8)

    local removeCurrent = vgui.Create("DButton", currentButtons)
    removeCurrent:Dock(LEFT)
    removeCurrent:SetWide(180)
    removeCurrent:SetText("Remove Selected Buddy")
    removeCurrent.DoClick = function()
        local lineId = currentList:GetSelectedLine()
        if not lineId then return end
        local line = currentList:GetLine(lineId)
        if not IsValid(line) or not line.ZRP_TargetKey then return end
        SendBuddySet(line.ZRP_TargetKey, false)
    end

    local refresh = vgui.Create("DButton", body)
    refresh:Dock(TOP)
    refresh:SetTall(28)
    refresh:SetText("Refresh Buddy List")
    refresh.DoClick = RequestBuddySync
end

local function OpenWhitelistMenu(sync)
    if not IsAdminLike() then return end

    if IsValid(ZRP_BuildWhitelistFrame) then
        ZRP_BuildWhitelistFrame:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(820, 760)
    frame:Center()
    frame:SetTitle("ZRP Build Whitelist / Blacklist")
    frame:MakePopup()
    ZRP_BuildWhitelistFrame = frame

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL)
    body:DockMargin(8, 8, 8, 8)

    local toolbar = vgui.Create("DPanel", body)
    toolbar:Dock(TOP)
    toolbar:SetTall(28)
    toolbar:DockMargin(0, 0, 0, 8)

    local openBuddyMenu = vgui.Create("DButton", toolbar)
    openBuddyMenu:Dock(LEFT)
    openBuddyMenu:SetWide(170)
    openBuddyMenu:SetText("Open Prop Buddy Menu")
    openBuddyMenu.DoClick = function()
        RunConsoleCommand("zrp_buddymenu")
    end

    local refreshAll = vgui.Create("DButton", toolbar)
    refreshAll:Dock(LEFT)
    refreshAll:SetWide(120)
    refreshAll:DockMargin(8, 0, 0, 0)
    refreshAll:SetText("Refresh")
    refreshAll.DoClick = RequestWhitelistSync

    local propList = BuildListSection(body, "Whitelisted Props", 180)
    local propBlacklistList = BuildListSection(body, "Blacklisted Props", 180)
    local toolList = BuildListSection(body, "Whitelisted Tools", 180)

    local function FillList(list, values)
        list:Clear()
        for _, value in ipairs(values or {}) do
            list:AddLine(value)
        end
    end

    FillList(propList, sync and sync.props or {})
    FillList(propBlacklistList, sync and sync.propBlacklist or {})
    FillList(toolList, sync and sync.tools or {})

    local propEntry = vgui.Create("DTextEntry", body)
    propEntry:Dock(TOP)
    propEntry:SetTall(24)
    propEntry:SetPlaceholderText("models/... .mdl")

    local propButtons = vgui.Create("DPanel", body)
    propButtons:Dock(TOP)
    propButtons:SetTall(28)
    propButtons:DockMargin(0, 4, 0, 8)

    local addProp = vgui.Create("DButton", propButtons)
    addProp:Dock(LEFT)
    addProp:SetWide(120)
    addProp:SetText("Whitelist Prop")
    addProp.DoClick = function()
        local value = string.Trim(propEntry:GetValue())
        if value == "" then return end
        RunULXArgs("zrpwlpropadd", value)
        timer.Simple(0.1, RequestWhitelistSync)
    end

    local removeProp = vgui.Create("DButton", propButtons)
    removeProp:Dock(LEFT)
    removeProp:SetWide(120)
    removeProp:DockMargin(8, 0, 0, 0)
    removeProp:SetText("Remove WL")
    removeProp.DoClick = function()
        local value = GetSelectedLineValue(propList)
        if not value then return end
        RunULXArgs("zrpwlpropremove", value)
        timer.Simple(0.1, RequestWhitelistSync)
    end

    local addBlacklist = vgui.Create("DButton", propButtons)
    addBlacklist:Dock(LEFT)
    addBlacklist:SetWide(120)
    addBlacklist:DockMargin(8, 0, 0, 0)
    addBlacklist:SetText("Blacklist Prop")
    addBlacklist.DoClick = function()
        local value = string.Trim(propEntry:GetValue())
        if value == "" then return end
        RunULXArgs("zrpwlpropblacklistadd", value)
        timer.Simple(0.1, RequestWhitelistSync)
    end

    local removeBlacklist = vgui.Create("DButton", propButtons)
    removeBlacklist:Dock(LEFT)
    removeBlacklist:SetWide(120)
    removeBlacklist:DockMargin(8, 0, 0, 0)
    removeBlacklist:SetText("Remove BL")
    removeBlacklist.DoClick = function()
        local value = GetSelectedLineValue(propBlacklistList)
        if not value then return end
        RunULXArgs("zrpwlpropblacklistremove", value)
        timer.Simple(0.1, RequestWhitelistSync)
    end

    local toolEntry = vgui.Create("DTextEntry", body)
    toolEntry:Dock(TOP)
    toolEntry:SetTall(24)
    toolEntry:SetPlaceholderText("toolname (e.g. weld)")

    local toolButtons = vgui.Create("DPanel", body)
    toolButtons:Dock(TOP)
    toolButtons:SetTall(28)
    toolButtons:DockMargin(0, 4, 0, 8)

    local addTool = vgui.Create("DButton", toolButtons)
    addTool:Dock(LEFT)
    addTool:SetWide(120)
    addTool:SetText("Add Tool")
    addTool.DoClick = function()
        local value = string.Trim(toolEntry:GetValue())
        if value == "" then return end
        RunULXArgs("zrpwltooladd", value)
        timer.Simple(0.1, RequestWhitelistSync)
    end

    local removeTool = vgui.Create("DButton", toolButtons)
    removeTool:Dock(LEFT)
    removeTool:SetWide(120)
    removeTool:DockMargin(8, 0, 0, 0)
    removeTool:SetText("Remove Tool")
    removeTool.DoClick = function()
        local value = GetSelectedLineValue(toolList)
        if not value then return end
        RunULXArgs("zrpwltoolremove", value)
        timer.Simple(0.1, RequestWhitelistSync)
    end
end

net.Receive("ZRP_BuildWL_OpenMenu", function()
    OpenWhitelistMenu()
    RequestWhitelistSync()
end)

net.Receive("ZRP_BuildWL_Sync", function()
    OpenWhitelistMenu(net.ReadTable() or {})
end)

net.Receive("ZRP_BuildBuddy_OpenMenu", function()
    OpenBuddyMenu()
    RequestBuddySync()
end)

net.Receive("ZRP_BuildBuddy_Sync", function()
    OpenBuddyMenu(net.ReadTable() or {})
end)

hook.Add("PopulateToolMenu", "ZRP_BuildBuddy_OptionsMenu", function()
    spawnmenu.AddToolCategory("Options", "Zcity", "Zcity")
    spawnmenu.AddToolMenuOption("Options", "Zcity", "ZRP_PropBuddies", "ZRP Prop Buddies", "", "", function(panel)
        panel:ClearControls()
        panel:Help("Manage who can interact with the props you spawn in ZRP.")

        local openButton = vgui.Create("DButton")
        openButton:SetText("Open Buddy Menu")
        openButton:SetTall(30)
        openButton.DoClick = function()
            RunConsoleCommand("zrp_buddymenu")
        end
        panel:AddItem(openButton)

        local refreshButton = vgui.Create("DButton")
        refreshButton:SetText("Refresh Buddy Data")
        refreshButton:SetTall(26)
        refreshButton.DoClick = function()
            RequestBuddySync()
        end
        panel:AddItem(refreshButton)
    end)
end)

hook.Add("SpawnlistOpenGenericMenu", "ZRP_BuildWhitelist_SpawnlistRightClick", function(selectionCanvas)
    if not IsAdminLike() then return end

    local models = GatherSelectionModels(selectionCanvas)
    if #models == 0 then return end

    local menu = DermaMenu()
    AddPropBatchOptions(menu, models)
    menu:AddSpacer()
    menu:AddOption("ZRP: Open whitelist menu", function()
        RunULXArgs("zrpwlmenu")
    end)
    menu:Open()
    return menu
end)

hook.Add("SpawnmenuIconMenuOpen", "ZRP_BuildWhitelist_IconMenu", function(menu, pnl, iconType)
    if not IsAdminLike() then return end
    if iconType ~= "model" then return end
    if not IsValid(menu) or not IsValid(pnl) or not pnl.GetModelName then return end

    local model = NormalizeBuildValue(pnl:GetModelName())
    if not model or not string.EndsWith(model, ".mdl") then return end

    menu:AddSpacer()
    AddPropBatchOptions(menu, { model })
    menu:AddOption("ZRP: Open whitelist menu", function()
        RunULXArgs("zrpwlmenu")
    end)
end)
