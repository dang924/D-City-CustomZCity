-- Centralized command mode handler for DCityPatch commands.
-- Modes:
--   always_on: command is never mode-gated.
--   coop:      command only runs when current mode is coop.
--   event:     command only runs when current mode is event.

if not SERVER then return end

ZC_CommandGuard = ZC_CommandGuard or {}

local MODE_ALWAYS = "always_on"
local MODE_COOP = "coop"
local MODE_EVENT = "event"

local ULX_MODES = {
    addmap = MODE_ALWAYS,
    areaportalsopen = MODE_ALWAYS,
    attachments = MODE_ALWAYS,
    csendmatch = MODE_EVENT,
    csinfo = MODE_EVENT,
    csmatch = MODE_EVENT,
    csmatchscore = MODE_EVENT,
    csteamaccept = MODE_EVENT,
    csteamdeny = MODE_EVENT,
    csteamdisband = MODE_EVENT,
    csteamjoin = MODE_EVENT,
    csteamleave = MODE_EVENT,
    csteamlist = MODE_EVENT,
    csteamregister = MODE_EVENT,
    csteamstatus = MODE_EVENT,
    damagelog = MODE_ALWAYS,
    dcityallmodes = MODE_ALWAYS,
    dcitypackfeat = MODE_ALWAYS,
    dcitypackfeatalle = MODE_ALWAYS,
    dcitypackfeatlist = MODE_ALWAYS,
    dlog = MODE_ALWAYS,
    event = MODE_EVENT,
    eventclass = MODE_EVENT,
    eventhealth = MODE_EVENT,
    eventreset = MODE_EVENT,
    eventresetall = MODE_EVENT,
    eventsplit = MODE_EVENT,
    godmode = MODE_ALWAYS,
    handsall = MODE_ALWAYS,
    jwick = MODE_EVENT,
    jwickend = MODE_EVENT,
    jwickset = MODE_EVENT,
    kickprotection = MODE_ALWAYS,
    kickprotectionstatus = MODE_ALWAYS,
    manageclass = MODE_COOP,
    manageclasses = MODE_COOP,
    mapvote_end = MODE_ALWAYS,
    mapvote_start = MODE_ALWAYS,
    nobots = MODE_ALWAYS,
    notarget = MODE_ALWAYS,
    npcmanager = MODE_ALWAYS,
    playerclass = MODE_ALWAYS,
    removemap = MODE_ALWAYS,
    setcoop = MODE_ALWAYS,
    setdod = MODE_ALWAYS,
    setevent = MODE_ALWAYS,
    shoptoggle = MODE_ALWAYS,
    toggleloadouts = MODE_EVENT,
}

local CONCOMMAND_MODES = {
    alyx_debug = MODE_ALWAYS,
    alyx_fire_debug = MODE_ALWAYS,
    dod_cfg_menu = MODE_ALWAYS,
    hg_garand_tuner = MODE_ALWAYS,
    hg_garand_zero = MODE_ALWAYS,
    hg_garand_zero_sv = MODE_ALWAYS,
    hg_wep_tuner = MODE_ALWAYS,
    mapvote = MODE_ALWAYS,
    mapvote_add = MODE_ALWAYS,
    mapvote_admin = MODE_ALWAYS,
    mapvote_end = MODE_ALWAYS,
    mapvote_help = MODE_ALWAYS,
    mapvote_list = MODE_ALWAYS,
    mapvote_remove = MODE_ALWAYS,
    mapvote_start = MODE_ALWAYS,
    rtv = MODE_ALWAYS,
    zc_corpse_sweep_now = MODE_ALWAYS,
    zc_damagelog = MODE_ALWAYS,
    zc_damagelog_open = MODE_ALWAYS,
    zc_damagelog_panel = MODE_ALWAYS,
    zc_fxtone_menu = MODE_ALWAYS,
    zc_spawn_clearstart = MODE_COOP,
    zc_spawn_printstart = MODE_COOP,
    zc_spawn_setstart = MODE_COOP,
    zc_spawn_teststart = MODE_COOP,
    zc_town_debug = MODE_ALWAYS,
    zc_town_rebuild = MODE_ALWAYS,
    zc_town_return_dump = MODE_ALWAYS,
}

local CHAT_MODES = {
    ["!addmap"] = MODE_ALWAYS,
    ["/addmap"] = MODE_ALWAYS,
    ["!buy"] = MODE_ALWAYS,
    ["/buy"] = MODE_ALWAYS,
    ["!csendmatch"] = MODE_EVENT,
    ["/csendmatch"] = MODE_EVENT,
    ["!csinfo"] = MODE_EVENT,
    ["/csinfo"] = MODE_EVENT,
    ["!csmatch"] = MODE_EVENT,
    ["/csmatch"] = MODE_EVENT,
    ["!csmatchscore"] = MODE_EVENT,
    ["/csmatchscore"] = MODE_EVENT,
    ["!csteamaccept"] = MODE_EVENT,
    ["/csteamaccept"] = MODE_EVENT,
    ["!csteamdeny"] = MODE_EVENT,
    ["/csteamdeny"] = MODE_EVENT,
    ["!csteamdisband"] = MODE_EVENT,
    ["/csteamdisband"] = MODE_EVENT,
    ["!csteamjoin"] = MODE_EVENT,
    ["/csteamjoin"] = MODE_EVENT,
    ["!csteamleave"] = MODE_EVENT,
    ["/csteamleave"] = MODE_EVENT,
    ["!csteamlist"] = MODE_EVENT,
    ["/csteamlist"] = MODE_EVENT,
    ["!csteamregister"] = MODE_EVENT,
    ["/csteamregister"] = MODE_EVENT,
    ["!csteamstatus"] = MODE_EVENT,
    ["/csteamstatus"] = MODE_EVENT,
    ["!damagelog"] = MODE_ALWAYS,
    ["/damagelog"] = MODE_ALWAYS,
    ["!dcityallmodes"] = MODE_ALWAYS,
    ["/dcityallmodes"] = MODE_ALWAYS,
    ["!dcitypackfeat"] = MODE_ALWAYS,
    ["/dcitypackfeat"] = MODE_ALWAYS,
    ["!dcitypackfeatalle"] = MODE_ALWAYS,
    ["/dcitypackfeatalle"] = MODE_ALWAYS,
    ["!dcitypackfeatlist"] = MODE_ALWAYS,
    ["/dcitypackfeatlist"] = MODE_ALWAYS,
    ["!dlog"] = MODE_ALWAYS,
    ["/dlog"] = MODE_ALWAYS,
    ["!event"] = MODE_EVENT,
    ["/event"] = MODE_EVENT,
    ["!eventclass"] = MODE_EVENT,
    ["/eventclass"] = MODE_EVENT,
    ["!eventhealth"] = MODE_EVENT,
    ["/eventhealth"] = MODE_EVENT,
    ["!eventreset"] = MODE_EVENT,
    ["/eventreset"] = MODE_EVENT,
    ["!eventresetall"] = MODE_EVENT,
    ["/eventresetall"] = MODE_EVENT,
    ["!eventsplit"] = MODE_EVENT,
    ["/eventsplit"] = MODE_EVENT,
    ["!fxtone"] = MODE_ALWAYS,
    ["/fxtone"] = MODE_ALWAYS,
    ["!godmode"] = MODE_ALWAYS,
    ["/godmode"] = MODE_ALWAYS,
    ["!handsall"] = MODE_ALWAYS,
    ["/handsall"] = MODE_ALWAYS,
    ["!jwick"] = MODE_EVENT,
    ["/jwick"] = MODE_EVENT,
    ["!jwickend"] = MODE_EVENT,
    ["/jwickend"] = MODE_EVENT,
    ["!jwickset"] = MODE_EVENT,
    ["/jwickset"] = MODE_EVENT,
    ["!kickprotection"] = MODE_ALWAYS,
    ["/kickprotection"] = MODE_ALWAYS,
    ["!kickprotectionstatus"] = MODE_ALWAYS,
    ["/kickprotectionstatus"] = MODE_ALWAYS,
    ["!manageclasses"] = MODE_COOP,
    ["/manageclasses"] = MODE_COOP,
    ["!manageclass"] = MODE_COOP,
    ["/manageclass"] = MODE_COOP,
    ["!managecombine"] = MODE_COOP,
    ["/managecombine"] = MODE_COOP,
    ["!managegordon"] = MODE_COOP,
    ["/managegordon"] = MODE_COOP,
    ["!managerebel"] = MODE_COOP,
    ["/managerebel"] = MODE_COOP,
    ["!mapvote"] = MODE_ALWAYS,
    ["/mapvote"] = MODE_ALWAYS,
    ["!mapvote_end"] = MODE_ALWAYS,
    ["/mapvote_end"] = MODE_ALWAYS,
    ["!mapvote_start"] = MODE_ALWAYS,
    ["/mapvote_start"] = MODE_ALWAYS,
    ["!moneyreset"] = MODE_ALWAYS,
    ["/moneyreset"] = MODE_ALWAYS,
    ["!nobots"] = MODE_ALWAYS,
    ["/nobots"] = MODE_ALWAYS,
    ["!notarget"] = MODE_ALWAYS,
    ["/notarget"] = MODE_ALWAYS,
    ["!npcmanager"] = MODE_ALWAYS,
    ["/npcmanager"] = MODE_ALWAYS,
    ["!playerclass"] = MODE_ALWAYS,
    ["/playerclass"] = MODE_ALWAYS,
    ["!removemap"] = MODE_ALWAYS,
    ["/removemap"] = MODE_ALWAYS,
    ["!rtv"] = MODE_ALWAYS,
    ["/rtv"] = MODE_ALWAYS,
    ["!setcoop"] = MODE_ALWAYS,
    ["/setcoop"] = MODE_ALWAYS,
    ["!setdod"] = MODE_ALWAYS,
    ["/setdod"] = MODE_ALWAYS,
    ["!setevent"] = MODE_ALWAYS,
    ["/setevent"] = MODE_ALWAYS,
    ["!shellshock"] = MODE_ALWAYS,
    ["/shellshock"] = MODE_ALWAYS,
    ["!shop"] = MODE_ALWAYS,
    ["/shop"] = MODE_ALWAYS,
    ["!shoptoggle"] = MODE_ALWAYS,
    ["/shoptoggle"] = MODE_ALWAYS,
    ["!toggleloadouts"] = MODE_EVENT,
    ["/toggleloadouts"] = MODE_EVENT,
}

local unsure = {
    chat = {},
    ulx = {},
    concommand = {},
}

local recentChatToken = {}

local function toLower(v)
    return string.lower(tostring(v or ""))
end

local function getModeName()
    if isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) and round.name then
            return toLower(round.name)
        end
    end

    if istable(zb) and zb.CROUND then
        return toLower(zb.CROUND)
    end

    return ""
end

local function currentGuardMode()
    local mode = getModeName()
    if mode == MODE_COOP then return MODE_COOP end
    if mode == MODE_EVENT then return MODE_EVENT end
    return MODE_ALWAYS
end

local function modeAllowed(requiredMode)
    if requiredMode == MODE_ALWAYS then return true end

    if GetConVar and GetConVar("zc_patch_force_all_modes") then
        local cv = GetConVar("zc_patch_force_all_modes")
        if cv and cv:GetBool() then
            return true
        end
    end

    return currentGuardMode() == requiredMode
end

local function getRequiredMode(kind, name, src)
    name = toLower(name)

    local map = (kind == "ulx") and ULX_MODES or CONCOMMAND_MODES
    local required = map[name]

    if required then
        return required
    end

    unsure[kind][name] = src or true
    map[name] = MODE_ALWAYS
    return MODE_ALWAYS
end

local function sendModeBlockedMessage(caller, kind, name, requiredMode)
    if not IsValid(caller) then return end
    if not caller.ChatPrint then return end

    local pretty = requiredMode
    if requiredMode == MODE_ALWAYS then
        pretty = "always on"
    end

    local prefix = (kind == "ulx") and "!" or ""
    caller:ChatPrint("[CommandGuard] " .. prefix .. tostring(name) .. " is only available in " .. pretty .. " mode.")
end

function ZC_CommandGuard.GetUnsure()
    return unsure
end

function ZC_CommandGuard.Wrap(kind, name, fn, src)
    if type(fn) ~= "function" then return fn end

    kind = toLower(kind)
    name = toLower(name)

    local requiredMode = getRequiredMode(kind, name, src)

    return function(...)
        if not modeAllowed(requiredMode) then
            local caller = select(1, ...)
            sendModeBlockedMessage(caller, kind, name, requiredMode)
            return
        end
        return fn(...)
    end
end

function ZC_CommandGuard.ChatCommandMode(token)
    token = toLower(token)
    local mode = CHAT_MODES[token]
    if mode then return mode end

    if string.sub(token, 1, 1) == "!" or string.sub(token, 1, 1) == "/" then
        unsure.chat[token] = true
        CHAT_MODES[token] = MODE_ALWAYS
        return MODE_ALWAYS
    end
    return nil
end

local function extractChatToken(text, args)
    if istable(args) and args[1] then
        return toLower(args[1])
    end

    local msg = tostring(text or "")
    local token = string.match(msg, "^%s*(%S+)")
    return toLower(token or "")
end

local function maybeBlockChatCommand(ply, text, args)
    local token = extractChatToken(text, args)
    if token == "" then return false end

    if IsValid(ply) then
        local key = ply:SteamID64() .. ":" .. token
        local now = CurTime()
        if (recentChatToken[key] or 0) > now then
            return false
        end
        recentChatToken[key] = now + 0.20
    end

    local mode = ZC_CommandGuard.ChatCommandMode(token)
    if not mode then return false end
    if modeAllowed(mode) then return false end

    sendModeBlockedMessage(ply, "ulx", token, mode)
    return true
end

hook.Add("HG_PlayerSay", "ZC_CommandGuardHGPlayerSay", function(ply, text, args)
    if maybeBlockChatCommand(ply, text, args) then
        return true
    end
end)

hook.Add("PlayerSay", "ZC_CommandGuardPlayerSay", function(ply, text)
    if maybeBlockChatCommand(ply, text, nil) then
        return ""
    end
end)

concommand.Add("zc_command_guard_unsure", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    print("[CommandGuard] ULX commands using fallback classification:")
    for cmd, src in pairs(unsure.ulx) do
        print("  " .. cmd .. " (" .. tostring(src) .. ")")
    end

    print("[CommandGuard] concommands using fallback classification:")
    for cmd, src in pairs(unsure.concommand) do
        print("  " .. cmd .. " (" .. tostring(src) .. ")")
    end

    print("[CommandGuard] chat commands missing explicit classification:")
    for cmd in pairs(unsure.chat) do
        print("  " .. cmd)
    end
end)