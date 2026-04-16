-- sh_ulx_event.lua — ULX module for the Event Admin Menu
-- Replaces the old scattered !eventclass / !eventloadout / etc. commands
-- with a single !event command that opens a VGUI panel.
--
-- All old commands are preserved as thin wrappers for backwards compatibility
-- but the menu is the intended workflow.
--
-- Place in: lua/ulx/modules/sh/

local CATEGORY_NAME = "ZCity Event"

-- ── !event — opens the menu (admin+) ─────────────────────────────────────────

if SERVER then

local SOURCE_PATH = tostring(debug.getinfo(1, "S").source or "")
local COOP_MENU_NETS = {
    "ZC_OpenCoopLoadoutMenu",
    "ZC_RequestCoopLoadouts",
    "ZC_SendCoopLoadouts",
    "ZC_SendCoopLoadoutsBegin",
    "ZC_SendCoopLoadoutEntry",
    "ZC_SendCoopLoadoutsEnd",
    "ZC_RequestSubclassSlotModifiers",
    "ZC_SendSubclassSlotModifiers",
    "ZC_RequestCombineResistanceConfig",
    "ZC_SendCombineResistanceConfig",
    "ZC_RequestArmorList",
    "ZC_SendArmorList",
}

-- Pool UI/action messages here too so ULX command availability is not coupled
-- to autorun file load order.
if util and util.AddNetworkString then
    util.AddNetworkString("ZC_OpenCoopLoadoutMenu")
    util.AddNetworkString("ZC_RequestCoopLoadouts")
    util.AddNetworkString("ZC_SendCoopLoadouts")
    util.AddNetworkString("ZC_SendCoopLoadoutsBegin")
    util.AddNetworkString("ZC_SendCoopLoadoutEntry")
    util.AddNetworkString("ZC_SendCoopLoadoutsEnd")
    util.AddNetworkString("ZC_SaveCoopLoadoutJSON")
    util.AddNetworkString("ZC_SaveCoopLoadout")
    util.AddNetworkString("ZC_DeleteCoopLoadout")
    util.AddNetworkString("ZC_ResetCoopLoadoutToDefault")
    util.AddNetworkString("ZC_ResetAllCoopLoadoutsToDefault")
    util.AddNetworkString("ZC_RequestSubclassSlotModifiers")
    util.AddNetworkString("ZC_SendSubclassSlotModifiers")
    util.AddNetworkString("ZC_SaveSubclassSlotModifiers")
    util.AddNetworkString("ZC_RequestCombineResistanceConfig")
    util.AddNetworkString("ZC_SendCombineResistanceConfig")
    util.AddNetworkString("ZC_SaveCombineResistanceConfig")
    util.AddNetworkString("ZC_RequestArmorList")
    util.AddNetworkString("ZC_SendArmorList")
    util.AddNetworkString("ZC_EventMenu_Open")
    util.AddNetworkString("ZC_EventMenu_Action")
end

local function PrintCoopNetPoolState(prefix)
    local parts = {}
    for _, name in ipairs(COOP_MENU_NETS) do
        parts[#parts + 1] = name .. "=" .. tostring(util.NetworkStringToID(name))
    end
    print("[ZC ULX Event] " .. tostring(prefix or "net-state") .. " | src=" .. SOURCE_PATH)
    print("[ZC ULX Event] " .. table.concat(parts, " | "))
end

print("[ZC ULX Event] module loaded from " .. SOURCE_PATH)
PrintCoopNetPoolState("startup")

local function IsNetMessagePooled(name)
    return util.NetworkStringToID(name) ~= 0
end

local function ReadCoopLoadoutsFromDataFile(path)
    local raw = file.Read(path, "DATA")
    if not isstring(raw) or raw == "" then return nil end
    local parsed = util.JSONToTable(raw)
    if not istable(parsed) or table.Count(parsed) <= 0 then return nil end
    return parsed
end

local function GetCoopLoadoutsForDirectPush()
    local runtime = istable(_G.ZC_CoopLoadouts) and _G.ZC_CoopLoadouts or nil
    if istable(runtime) and table.Count(runtime) > 0 then
        return runtime, "runtime"
    end

    local disk = ReadCoopLoadoutsFromDataFile("zc_coop_loadouts.json")
    if istable(disk) then
        _G.ZC_CoopLoadouts = disk
        return disk, "disk-primary"
    end

    local backup = ReadCoopLoadoutsFromDataFile("zc_coop_loadouts.backup.json")
    if istable(backup) then
        _G.ZC_CoopLoadouts = backup
        return backup, "disk-backup"
    end

    return {}, "empty"
end

local function PushCoopLoadoutsDirect(ply, why)
    if not IsValid(ply) then return false end

    if isfunction(_G.ZC_SendCoopLoadouts) then
        local ok, err = pcall(_G.ZC_SendCoopLoadouts, ply)
        if ok then
            print("[ZC ULX Event] pushed coop loadouts directly via ZC_SendCoopLoadouts (" .. tostring(why or "") .. ")")
            return true
        end
        print("[ZC ULX Event] direct push via ZC_SendCoopLoadouts failed: " .. tostring(err))
    end

    local loadouts, source = GetCoopLoadoutsForDirectPush()
    local count = table.Count(loadouts)
    print("[ZC ULX Event] direct push using fallback table path, source=" .. tostring(source) .. ", count=" .. tostring(count))

    local hasChunk = IsNetMessagePooled("ZC_SendCoopLoadoutsBegin")
        and IsNetMessagePooled("ZC_SendCoopLoadoutEntry")
        and IsNetMessagePooled("ZC_SendCoopLoadoutsEnd")
    local hasLegacy = IsNetMessagePooled("ZC_SendCoopLoadouts")

    if not hasChunk and not hasLegacy then
        print("[ZC ULX Event] direct push aborted: no pooled coop send channels available")
        return false
    end

    if hasChunk then
        net.Start("ZC_SendCoopLoadoutsBegin")
        net.WriteUInt(count, 16)
        net.Send(ply)

        for presetName, presetData in pairs(loadouts) do
            local json = util.TableToJSON(presetData)
            if isstring(json) and json ~= "" then
                net.Start("ZC_SendCoopLoadoutEntry")
                net.WriteString(tostring(presetName))
                net.WriteString(json)
                net.Send(ply)
            end
        end

        net.Start("ZC_SendCoopLoadoutsEnd")
        net.Send(ply)
    end

    local allJson = util.TableToJSON(loadouts)
    if hasLegacy and isstring(allJson) and #allJson < 60000 then
        net.Start("ZC_SendCoopLoadouts")
        net.WriteString(allJson)
        net.Send(ply)
    end

    return true
end

local function CanEditCoopLoadouts(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return true end
    if ULib and ULib.ucl and ULib.ucl.query and ULib.ucl.query(ply, "zc_manage_coop_loadouts") then
        return true
    end
    return false
end

local function ReadPersistedCoopLoadouts()
    local tbl, source = GetCoopLoadoutsForDirectPush()
    if istable(tbl) then return table.Copy(tbl), source end
    return {}, "empty"
end

local function SavePersistedCoopLoadouts(tbl)
    if not istable(tbl) then return false, "invalid-table" end
    local json = util.TableToJSON(tbl, true)
    if not isstring(json) or json == "" then
        return false, "serialize-failed"
    end

    local current = file.Read("zc_coop_loadouts.json", "DATA")
    if isstring(current) and current ~= "" then
        file.Write("zc_coop_loadouts.backup.json", current)
    end

    file.Write("zc_coop_loadouts.json", json)
    _G.ZC_CoopLoadouts = tbl
    return true, nil
end

-- Fallback save path: this keeps coop customization working even if
-- sv_coop_loadouts.lua did not reach its late net.Receive registrations.
net.Receive("ZC_SaveCoopLoadoutJSON", function(_, ply)
    if not CanEditCoopLoadouts(ply) then
        if IsValid(ply) then
            ply:ChatPrint("[ZC] Coop loadout edit denied: admin permission required.")
        end
        return
    end

    local presetName = string.Trim(tostring(net.ReadString() or ""))
    local jsonStr = tostring(net.ReadString() or "")
    if presetName == "" or jsonStr == "" then return end

    local data = util.JSONToTable(jsonStr)
    if not istable(data) then
        print("[ZC ULX Event] save-json rejected: parse failed for preset '" .. presetName .. "'")
        return
    end

    local loadouts, source = ReadPersistedCoopLoadouts()
    local clean = {
        subclass = tostring(data.subclass or "default"),
        baseClass = tostring(data.baseClass or "Rebel"),
        weapons = istable(data.weapons) and data.weapons or {},
        armor = istable(data.armor) and data.armor or {},
    }

    if istable(data.attachments) then
        clean.attachments = data.attachments
    elseif istable(loadouts[presetName]) and istable(loadouts[presetName].attachments) then
        clean.attachments = loadouts[presetName].attachments
    end

    loadouts[presetName] = clean

    local ok, err = SavePersistedCoopLoadouts(loadouts)
    if not ok then
        print("[ZC ULX Event] save-json failed for '" .. presetName .. "': " .. tostring(err))
        return
    end

    print("[ZC ULX Event] save-json applied for '" .. presetName .. "' by " .. tostring(ply:Nick()) .. " (source=" .. tostring(source) .. ")")
    PushCoopLoadoutsDirect(ply, "save-json")
end)

local function SendCoopLoadoutMenuSafe(ply, mode, attempt)
    if not IsValid(ply) then return false end

    local msgName = "ZC_OpenCoopLoadoutMenu"
    if not IsNetMessagePooled(msgName) then
        attempt = (attempt or 0) + 1
        if attempt == 1 then
            PrintCoopNetPoolState("open-menu-unpooled")
        end
        if attempt <= 8 then
            timer.Simple(0.25, function()
                SendCoopLoadoutMenuSafe(ply, mode, attempt)
            end)
            return false
        end

        ply:ChatPrint("[Loadout] Coop Loadout Manager is unavailable right now (message not pooled yet).")
        return false
    end

    net.Start(msgName)
    net.WriteString(mode or "rebel")
    net.Send(ply)

    -- Some servers never hit ZC_RequestCoopLoadouts reliably; push data directly.
    timer.Simple(0.05, function()
        if not IsValid(ply) then return end
        PushCoopLoadoutsDirect(ply, "menu-open")
    end)

    return true
end

-- ── Direct chat intercept ─────────────────────────────────────────────────────
-- ZCity's ZChat hooks PlayerSay and returns "" which prevents ULX from seeing
-- !event via its own PlayerSay handler. We intercept via HG_PlayerSay which
-- ZChat fires before swallowing the message, so !event works in all gamemodes.

hook.Add("HG_PlayerSay", "ZC_EventMenu_ChatCommand", function(ply, txtTbl, text)
    local cmd = string.lower(string.Trim(text))
    if not IsValid(ply) or not ply:IsAdmin() then return end

    if cmd == "!toggleloadouts" or cmd == "/toggleloadouts" then
        txtTbl[1] = ""
        local enabled = GetConVar("zc_player_loadouts_enabled")
        local newState = not (enabled and enabled:GetBool())
        RunConsoleCommand("zc_player_loadouts_enabled", newState and "1" or "0")
        PrintMessage(HUD_PRINTTALK, "[Loadout] " .. ply:Nick() .. " set player !loadout to " .. (newState and "ENABLED" or "DISABLED") .. ".")
        ulx.logString(ply:Nick() .. " toggled player !loadout " .. (newState and "ON" or "OFF") .. " via chat")
        return ""
    end

    -- !manageclasses — unified loadout manager (aliases: !managerebel/combine/gordon)
    local _manageMode = ({
        ["!manageclasses"] = "rebel",  ["/manageclasses"] = "rebel",
        ["!manageclass"] = "rebel",    ["/manageclass"] = "rebel",
        ["!managerebel"]   = "rebel",  ["/managerebel"]   = "rebel",
        ["!managecombine"] = "combine",["/managecombine"] = "combine",
        ["!managegordon"]  = "gordon", ["/managegordon"]  = "gordon",
        ["!manageother"]   = "other",  ["/manageother"]   = "other",
    })[cmd]
    if _manageMode then
        txtTbl[1] = ""
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("[Loadout] !manageclasses requires Superadmin.")
            return ""
        end
        local _mode = _manageMode
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            SendCoopLoadoutMenuSafe(ply, _mode)
        end)
        ulx.logString(ply:Nick() .. " opened Coop Loadout Manager [" .. _mode .. "] via chat")
        return ""
    end

    if cmd ~= "!event" and cmd ~= "/event" then return end

    txtTbl[1] = ""  -- suppress message from chat

    -- Small delay so any round-start net traffic settles first
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if ZC_OpenEventMenuFor then
            ZC_OpenEventMenuFor(ply)
        end
    end)

    ulx.logString(ply:Nick() .. " opened the Event Admin Menu via chat")
end)

-- ── ULX command (ulx event / !event via ULX's own system) ────────────────────

local function ulxEventMenu(calling_ply)
    if not IsValid(calling_ply) then
        Msg("[Event] Menu cannot be opened from console.\n")
        return
    end

    if ZC_OpenEventMenuFor then
        ZC_OpenEventMenuFor(calling_ply)
    else
        -- sv_event_menu.lua not yet loaded — shouldn't happen in normal flow
        net.Start("ZC_EventMenu_Open")
        net.Send(calling_ply)
    end

    ulx.logString(calling_ply:Nick() .. " opened the Event Admin Menu")
end

local cmd = ulx.command(CATEGORY_NAME, "ulx event", ulxEventMenu, "!event")
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Opens the Event Admin Menu.")

local function ulxToggleLoadouts(calling_ply)
    if not IsValid(calling_ply) then
        Msg("[Loadout] toggleloadouts cannot be run from console.\n")
        return
    end

    local enabled = GetConVar("zc_player_loadouts_enabled")
    local newState = not (enabled and enabled:GetBool())
    RunConsoleCommand("zc_player_loadouts_enabled", newState and "1" or "0")

    PrintMessage(HUD_PRINTTALK, "[Loadout] " .. calling_ply:Nick() .. " set player !loadout to " .. (newState and "ENABLED" or "DISABLED") .. ".")
    ulx.logString(calling_ply:Nick() .. " toggled player !loadout " .. (newState and "ON" or "OFF"))
end

local tl = ulx.command(CATEGORY_NAME, "ulx toggleloadouts", ulxToggleLoadouts, "!toggleloadouts")
tl:defaultAccess(ULib.ACCESS_ADMIN)
tl:help("Toggles whether players can use !loadout.")

-- !manageclasses [rebel|combine|gordon] — unified coop loadout manager
-- Aliases !managerebel / !managecombine / !managegordon are handled by the
-- chat intercept above; this ULX command covers ulx console usage.
local function ulxManageClasses(calling_ply, mode)
    if not IsValid(calling_ply) then
        Msg("[Loadout] manageclasses cannot be run from console.\n")
        return
    end
    mode = string.lower(tostring(mode or "rebel"))
    if mode ~= "combine" and mode ~= "gordon" and mode ~= "other" then mode = "rebel" end
    if SendCoopLoadoutMenuSafe(calling_ply, mode) then
        ulx.logString(calling_ply:Nick() .. " opened Coop Loadout Manager [" .. mode .. "]")
    end
end
local mcls = ulx.command(CATEGORY_NAME, "ulx manageclasses", ulxManageClasses, "!manageclasses")
mcls:addParam{ type=ULib.cmds.StringArg, hint="rebel|combine|gordon|other", default="rebel" }
mcls:defaultAccess(ULib.ACCESS_SUPERADMIN)
mcls:help("Opens the unified loadout manager. Pass rebel/combine/gordon/other to start on that tab.")

-- ── Legacy command stubs (kept so existing muscle-memory / scripts still work) ─
-- Each stub sends the corresponding net action so the new server handler runs it.
-- They will still appear in ULX's autocomplete but point to the same logic.

local function legacyAction(calling_ply, action, steamid, arg)
    if not IsValid(calling_ply) then return end
    net.Start("ZC_EventMenu_Action")
        net.WriteString(action)
        net.WriteString(steamid or "")
        net.WriteString(arg or "")
    net.Send(calling_ply)
end

-- !eventclass <player> <class>
local function ulxEventClass(calling_ply, target_ply, class)
    if not IsValid(target_ply) then return end
    legacyAction(calling_ply, "setclass", target_ply:SteamID64(), class)
    ULib.tsay(calling_ply, "Setting " .. target_ply:Nick() .. "'s class to " .. class .. " (use !event for the menu)")
end
local ec = ulx.command(CATEGORY_NAME, "ulx eventclass", ulxEventClass, "!eventclass")
ec:addParam{ type=ULib.cmds.PlayerArg }
ec:addParam{ type=ULib.cmds.StringArg, hint="class (Rebel, Combine, Refugee, Gordon...)" }
ec:defaultAccess(ULib.ACCESS_ADMIN)
ec:help("[Legacy] Assign a ZCity class. Use !event for the full menu.")

-- !eventhealth <player>
local function ulxEventHealth(calling_ply, target_ply)
    if not IsValid(target_ply) then return end
    legacyAction(calling_ply, "healplayer", target_ply:SteamID64(), "")
end
local eh = ulx.command(CATEGORY_NAME, "ulx eventhealth", ulxEventHealth, "!eventhealth")
eh:addParam{ type=ULib.cmds.PlayerArg }
eh:defaultAccess(ULib.ACCESS_ADMIN)
eh:help("[Legacy] Reset a player's organism. Use !event for the full menu.")

-- !eventreset <player>
local function ulxEventReset(calling_ply, target_ply)
    if not IsValid(target_ply) then return end
    legacyAction(calling_ply, "resetplayer", target_ply:SteamID64(), "")
end
local er = ulx.command(CATEGORY_NAME, "ulx eventreset", ulxEventReset, "!eventreset")
er:addParam{ type=ULib.cmds.PlayerArg }
er:defaultAccess(ULib.ACCESS_ADMIN)
er:help("[Legacy] Full reset a player. Use !event for the full menu.")

-- !eventresetall
local function ulxEventResetAll(calling_ply)
    legacyAction(calling_ply, "resetall", "", "")
end
local era = ulx.command(CATEGORY_NAME, "ulx eventresetall", ulxEventResetAll, "!eventresetall")
era:defaultAccess(ULib.ACCESS_ADMIN)
era:help("[Legacy] Reset all organisms. Use !event for the full menu.")

-- !eventsplit [n]
local function ulxEventSplit(calling_ply, num_teams)
    legacyAction(calling_ply, "split", "", tostring(num_teams or 2))
end
local es = ulx.command(CATEGORY_NAME, "ulx eventsplit", ulxEventSplit, "!eventsplit")
es:addParam{ type=ULib.cmds.NumArg, min=2, max=4, default=2, hint="number of teams (2-4)" }
es:defaultAccess(ULib.ACCESS_ADMIN)
es:help("[Legacy] Split players into teams. Use !event for the full menu.")

end -- SERVER
