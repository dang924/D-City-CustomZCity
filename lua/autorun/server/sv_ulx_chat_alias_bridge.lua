if CLIENT then return end

if _G.ZC_ULXChatAliasBridgeInstalled then return end
_G.ZC_ULXChatAliasBridgeInstalled = true

local aliases = {}
local pending = _G.ZC_ULXPendingAliases or {}
_G.ZC_ULXPendingAliases = pending
local recentDispatch = {}
local recentCommandDispatch = {}

local function dispatchKeyFor(ply, token)
    if not IsValid(ply) then return "" end
    return tostring(ply:SteamID64() or "") .. ":" .. tostring(token or "")
end

local function markDispatched(ply, token)
    local key = dispatchKeyFor(ply, token)
    if key == "" then return end
    recentDispatch[key] = CurTime() + 0.75
end

local function wasRecentlyDispatched(ply, token)
    local key = dispatchKeyFor(ply, token)
    if key == "" then return false end

    local expiresAt = recentDispatch[key]
    if not expiresAt then return false end
    if expiresAt < CurTime() then
        recentDispatch[key] = nil
        return false
    end

    return true
end

local function commandDispatchKeyFor(ply, commandName, args)
    if not IsValid(ply) then return "" end
    return string.format("%s:%s:%s", tostring(ply:SteamID64() or ""), tostring(commandName or ""), tostring(args or ""))
end

local function markCommandDispatched(ply, commandName, args)
    local key = commandDispatchKeyFor(ply, commandName, args)
    if key == "" then return end
    recentCommandDispatch[key] = CurTime() + 0.75
end

local function wasCommandRecentlyDispatched(ply, commandName, args)
    local key = commandDispatchKeyFor(ply, commandName, args)
    if key == "" then return false end

    local expiresAt = recentCommandDispatch[key]
    if not expiresAt then return false end
    if expiresAt < CurTime() then
        recentCommandDispatch[key] = nil
        return false
    end

    return true
end

local skipAliases = {
    ["!join"] = true,
    ["/join"] = true,
    ["!damagelog"] = true,
    ["/damagelog"] = true,
    ["!event"] = true,
    ["/event"] = true,
    ["!godmode"] = true,
    ["/godmode"] = true,
    ["!manageclasses"] = true,
    ["/manageclasses"] = true,
    ["!manageclass"] = true,
    ["/manageclass"] = true,
    ["!managecombine"] = true,
    ["/managecombine"] = true,
    ["!managegordon"] = true,
    ["/managegordon"] = true,
    ["!managerebel"] = true,
    ["/managerebel"] = true,
    ["!mapvote"] = true,
    ["/mapvote"] = true,
    ["!menu"] = true,
    ["/menu"] = true,
    ["!notarget"] = true,
    ["/notarget"] = true,
    ["!rtv"] = true,
    ["/rtv"] = true,
    ["!stuck"] = true,
    ["/stuck"] = true,
    ["!toggleloadouts"] = true,
    ["/toggleloadouts"] = true,
}

-- ── Standard ULX built-in commands (must be explicit — ZChat swallows PlayerSay
--    before ULX's own chat handler can see them) ───────────────────────────────
local auditedAliases = {
    -- moderation
    ["!slap"]          = "slap",
    ["!slay"]          = "slay",
    ["!freeze"]        = "freeze",
    ["!unfreeze"]      = "unfreeze",
    ["!kick"]          = "kick",
    ["!ban"]           = "ban",
    ["!banid"]         = "banid",
    ["!unban"]         = "unban",
    ["!xban"]          = "xban",
    ["!xbanid"]        = "xbanid",
    ["!xkick"]         = "xkick",
    -- movement / state
    ["!noclip"]        = "noclip",
    ["!god"]           = "god",
    ["!hp"]            = "hp",
    ["!armor"]         = "armor",
    ["!respawn"]       = "respawn",
    ["!spectate"]      = "spectate",
    ["!bring"]         = "bring",
    ["!goto"]          = "goto",
    ["!teleport"]      = "teleport",
    ["!tp"]            = "teleport",
    -- fun
    ["!blind"]         = "blind",
    ["!deaf"]          = "deaf",
    ["!cloak"]         = "cloak",
    ["!maul"]          = "maul",
    ["!ignite"]        = "ignite",
    ["!extinguish"]    = "extinguish",
    ["!jail"]          = "jail",
    ["!unjail"]        = "unjail",
    ["!strip"]         = "strip",
    ["!fire"]          = "fire",
    ["!throw"]         = "throw",
    ["!ragdoll"]       = "ragdoll",
    ["!damage"]        = "damage",
    -- messaging
    ["!psay"]          = "psay",
    ["!tsay"]          = "tsay",
    ["!csay"]          = "csay",
    ["!pm"]            = "pm",
    -- server admin
    ["!decalclean"]    = "decalclean",
    ["!vote"]          = "vote",
    ["!votemap"]       = "votemap",
    ["!stopsound"]     = "stopsound",
    ["!etime"]         = "etime",
    ["!rcon"]          = "rcon",
    ["!cexec"]         = "cexec",
    ["!map"]           = "map",
    ["!changelevel"]   = "changelevel",
    ["!luarun"]        = "luarun",
    ["!luafile"]       = "luafile",
    -- info
    ["!steamid"]       = "steamid",
    ["!usteamid"]      = "usteamid",
    ["!ip"]            = "ip",
    ["!gag"]           = "gag",
    ["!ungag"]         = "ungag",
    ["!mute"]          = "mute",
    ["!unmute"]        = "unmute",
    -- user / group management
    ["!adduser"]       = "adduser",
    ["!removeuser"]    = "removeuser",
    ["!addgroup"]      = "addgroup",
    ["!removegroup"]   = "removegroup",
    ["!userallow"]     = "userallow",
    ["!userdeny"]      = "userdeny",
    ["!groupallow"]    = "groupallow",
    ["!groupdeny"]     = "groupdeny",
    ["!maxplayers"]    = "maxplayers",
    ["!plimit"]        = "plimit",
    -- DCityPatch custom
    ["!addmap"]              = "addmap",
    ["!areaportalsopen"]     = "areaportalsopen",
    ["!csendmatch"]          = "csendmatch",
    ["!csinfo"]              = "csinfo",
    ["!csmatch"]             = "csmatch",
    ["!csmatchscore"]        = "csmatchscore",
    ["!csteamaccept"]        = "csteamaccept",
    ["!csteamdeny"]          = "csteamdeny",
    ["!csteamdisband"]       = "csteamdisband",
    ["!csteamjoin"]          = "csteamjoin",
    ["!csteamleave"]         = "csteamleave",
    ["!csteamlist"]          = "csteamlist",
    ["!csteamregister"]      = "csteamregister",
    ["!csteamstatus"]        = "csteamstatus",
    ["!dcityallmodes"]       = "dcityallmodes",
    ["!dcitypackfeat"]       = "dcitypackfeat",
    ["!dcitypackfeatalle"]   = "dcitypackfeatalle",
    ["!dcitypackfeatlist"]   = "dcitypackfeatlist",
    ["!dlog"]                = "dlog",
    ["!eventclass"]          = "eventclass",
    ["!eventhealth"]         = "eventhealth",
    ["!eventreset"]          = "eventreset",
    ["!eventresetall"]       = "eventresetall",
    ["!eventsplit"]          = "eventsplit",
    ["!handsall"]            = "handsall",
    ["!jwick"]               = "jwick",
    ["!jwickend"]            = "jwickend",
    ["!jwickset"]            = "jwickset",
    ["!kickprotection"]      = "kickprotection",
    ["!kickprotectionstatus"]= "kickprotectionstatus",
    ["!mapvote_end"]         = "mapvote_end",
    ["!mapvote_start"]       = "mapvote_start",
    ["!nobots"]              = "nobots",
    ["!npcmanager"]          = "npcmanager",
    ["!playerclass"]         = "playerclass",
    ["!removemap"]           = "removemap",
    ["!setcoop"]             = "setcoop",
    ["!setdod"]              = "setdod",
    ["!setevent"]            = "setevent",
    ["!shoptoggle"]          = "shoptoggle",
    ["!moneyreset"]          = "moneyreset",
}

local function registerAlias(alias, commandName)
    alias = string.lower(string.Trim(tostring(alias or "")))
    commandName = string.lower(string.Trim(tostring(commandName or "")))
    commandName = string.gsub(commandName, "^ulx%s+", "")

    if alias == "" or commandName == "" then return false end
    if string.sub(alias, 1, 1) ~= "!" and string.sub(alias, 1, 1) ~= "/" then
        alias = "!" .. alias
    end

    aliases[alias] = commandName

    local altPrefix = string.sub(alias, 1, 1) == "!" and "/" or "!"
    aliases[altPrefix .. string.sub(alias, 2)] = commandName
    return true
end

-- Fallback: any !word or /word not in the audited list or skipAliases is assumed
-- to be a standard ULX command. ULX's own access control handles permission checks;
-- unknown commands fail silently. This catches ULX addon commands not in the list.
local function ulxCommandFromToken(token)
    local prefix = string.sub(token, 1, 1)
    if prefix ~= "!" and prefix ~= "/" then return nil end
    local cmd = string.sub(token, 2)
    if cmd == "" or not string.match(cmd, "^[%w_]+$") then return nil end
    return cmd
end

function _G.ZC_RegisterULXSayAlias(alias, commandName)
    return registerAlias(alias, commandName)
end

for alias, commandName in pairs(auditedAliases) do
    registerAlias(alias, commandName)
end

for alias, commandName in pairs(pending) do
    registerAlias(alias, commandName)
    pending[alias] = nil
end

local function sanitizeArgs(rest)
    rest = tostring(rest or "")
    if string.find(rest, "[\r\n;]") then
        return nil
    end
    return string.Trim(rest)
end

hook.Add("HG_PlayerSay", "ZC_ULXAuditedChatBridge", function(ply, txtTbl, text)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local raw = string.Trim(tostring(text or ""))
    if raw == "" then return end

    local token, rest = string.match(raw, "^(%S+)%s*(.*)$")
    token = string.lower(token or "")

    if token == "" or skipAliases[token] then return end

    local commandName = aliases[token]
    if not commandName then
        commandName = ulxCommandFromToken(token)
        if not commandName then return end
    end

    if wasRecentlyDispatched(ply, token) then
        if istable(txtTbl) then txtTbl[1] = "" end
        return ""
    end

    rest = sanitizeArgs(rest)
    if rest == nil then
        ply:ChatPrint("[ULX] Command arguments contained unsupported separators.")
        if istable(txtTbl) then txtTbl[1] = "" end
        return ""
    end

    if wasCommandRecentlyDispatched(ply, commandName, rest) then
        if istable(txtTbl) then txtTbl[1] = "" end
        return ""
    end

    if istable(txtTbl) then txtTbl[1] = "" end
    markDispatched(ply, token)
    markCommandDispatched(ply, commandName, rest)

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        local cmd = "ulx " .. commandName
        if rest ~= "" then
            cmd = cmd .. " " .. rest
        end
        ply:ConCommand(cmd)
    end)

    return ""
end)

hook.Add("PlayerSay", "ZC_ULXAuditedChatBridge_Dedupe", function(ply, text)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local token = string.match(string.Trim(tostring(text or "")), "^(%S+)")
    token = string.lower(token or "")
    if token == "" then return end

    -- Suppress original chat for any token the bridge already dispatched
    -- (covers both audited aliases and universal ULX fallback)
    if wasRecentlyDispatched(ply, token) then return "" end
end)

-- ── Post-load bulk alias registration ─────────────────────────────────────────
-- After ULib finishes loading, scan all registered ULX commands and register any
-- say aliases not already in the audited list. Belt-and-suspenders backstop for
-- ULX addon commands that aren't in the hardcoded list above.
hook.Add("ULibLoaded", "ZC_ULXAliasBridge_BulkScan", function()
    timer.Simple(0.5, function()
        local count = 0

        -- Method 1: ULib.ucl.accesses  (keyed "ulx <command>")
        if ULib and ULib.ucl and istable(ULib.ucl.accesses) then
            for accessKey in pairs(ULib.ucl.accesses) do
                local cmdName = string.match(string.lower(tostring(accessKey or "")), "^ulx%s+([%w_]+)$")
                if cmdName then
                    local bang = "!" .. cmdName
                    if not aliases[bang] and not skipAliases[bang] then
                        if registerAlias(bang, cmdName) then count = count + 1 end
                    end
                end
            end
        end

        -- Method 2: ULib.cmds  (some ULib versions store command objects here)
        if ULib and istable(ULib.cmds) then
            for cmdKey, cmdObj in pairs(ULib.cmds) do
                local say = istable(cmdObj) and cmdObj.say_cmd
                if isstring(say) and say ~= "" then
                    local cmdName = string.lower(string.gsub(string.lower(tostring(cmdKey or "")), "^ulx%s+", ""))
                    local bang = string.lower(string.Trim(say))
                    if bang ~= "" and not aliases[bang] and not skipAliases[bang] then
                        if registerAlias(bang, cmdName) then count = count + 1 end
                    end
                end
            end
        end

        if count > 0 then
            print("[ZC ULX AliasBridge] Bulk-registered " .. count .. " additional say aliases post-ULibLoaded")
        end
    end)
end)