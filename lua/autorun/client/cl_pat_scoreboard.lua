if SERVER then return end

PATSB = PATSB or {}
PATSB.Settings = PATSB.Settings or {}

local function colorData(r, g, b, a)
    return {
        r = r,
        g = g,
        b = b,
        a = a or 255
    }
end

PATSB.ThemeDefaults = PATSB.ThemeDefaults or {
    white = colorData(245, 245, 245, 255),
    text = colorData(220, 220, 220, 255),
    muted = colorData(160, 160, 160, 255),
    accent = colorData(190, 20, 20, 220),
    accent_soft = colorData(255, 45, 45, 120),
    bg = colorData(8, 8, 8, 220),
    bg2 = colorData(18, 18, 18, 235),
    bg3 = colorData(28, 28, 28, 220),
    spec = colorData(180, 180, 180, 255),
    team_t = colorData(190, 55, 55, 255),
    team_ct = colorData(70, 150, 220, 255)
}

local THEME_KEYS = {
    "accent",
    "accent_soft",
    "bg",
    "bg2",
    "bg3",
    "white",
    "text",
    "muted",
    "spec",
    "team_t",
    "team_ct"
}

local THEME_LABELS = {
    accent = "Accent",
    accent_soft = "Accent Soft",
    bg = "Background",
    bg2 = "Panel Background",
    bg3 = "Panel Accent Background",
    white = "Primary Text",
    text = "Secondary Text",
    muted = "Muted Text",
    spec = "Spectator",
    team_t = "Team T",
    team_ct = "Team CT"
}

PATSB.Defaults = {
    refresh_interval = 1,
    enable_ulx_menu = true,
    enable_profile_button = true,
    show_spectators = true,
    show_karma = true,
    show_session = true,
    show_playtime = true,
    show_tickrate = true,
    show_voice_buttons = true,
    show_bottom_mute_buttons = true,
    show_team_button = true,
    blur_strength = 5,
    frame_width = 1600,
    frame_height = 920,
    sidebar_width_min = 300,
    sidebar_width_max = 420,
    sidebar_width_frac = 0.24,
    command_1_enabled = true,
    command_1_text = "Store",
    command_1_say = "!store",
    command_2_enabled = true,
    command_2_text = "Guide",
    command_2_say = "!motd",
    font_title = "Tahoma",
    font_body = "Tahoma",
    ui_scale_mul = 1,
    theme = table.Copy(PATSB.ThemeDefaults)
}

for k, v in pairs(PATSB.Defaults) do
    if PATSB.Settings[k] == nil then
        PATSB.Settings[k] = istable(v) and table.Copy(v) or v
    end
end

local scoreBoardMenu
hg = hg or {}
hg.playerInfo = hg.playerInfo or {}
zb = zb or {}

local COL_WHITE
local COL_TEXT
local COL_MUTED
local COL_RED
local COL_RED_SOFT
local COL_BG
local COL_BG2
local COL_BG3
local COL_SPEC
local COL_T
local COL_CT

local BASE_W, BASE_H = 1920, 1080
local _lastScrW, _lastScrH = 0, 0

local FONT_TITLE = "PATSB_Title"
local FONT_HEADER = "PATSB_Header"
local FONT_MED = "PATSB_Med"
local FONT_SMALL = "PATSB_Small"

local function themeColorData(entry, fallback)
    local defaults = istable(fallback) and fallback or { r = 255, g = 255, b = 255, a = 255 }
    local value = istable(entry) and entry or {}

    return Color(
        math.Clamp(tonumber(value.r) or defaults.r or 255, 0, 255),
        math.Clamp(tonumber(value.g) or defaults.g or 255, 0, 255),
        math.Clamp(tonumber(value.b) or defaults.b or 255, 0, 255),
        math.Clamp(tonumber(value.a) or defaults.a or 255, 0, 255)
    )
end

local function ensureThemeTable(settings)
    settings.theme = istable(settings.theme) and settings.theme or {}

    for key, defaults in pairs(PATSB.ThemeDefaults) do
        settings.theme[key] = istable(settings.theme[key]) and settings.theme[key] or table.Copy(defaults)
    end
end

local function applyThemeColors()
    ensureThemeTable(PATSB.Settings)

    local theme = PATSB.Settings.theme
    COL_WHITE = themeColorData(theme.white, PATSB.ThemeDefaults.white)
    COL_TEXT = themeColorData(theme.text, PATSB.ThemeDefaults.text)
    COL_MUTED = themeColorData(theme.muted, PATSB.ThemeDefaults.muted)
    COL_RED = themeColorData(theme.accent, PATSB.ThemeDefaults.accent)
    COL_RED_SOFT = themeColorData(theme.accent_soft, PATSB.ThemeDefaults.accent_soft)
    COL_BG = themeColorData(theme.bg, PATSB.ThemeDefaults.bg)
    COL_BG2 = themeColorData(theme.bg2, PATSB.ThemeDefaults.bg2)
    COL_BG3 = themeColorData(theme.bg3, PATSB.ThemeDefaults.bg3)
    COL_SPEC = themeColorData(theme.spec, PATSB.ThemeDefaults.spec)
    COL_T = themeColorData(theme.team_t, PATSB.ThemeDefaults.team_t)
    COL_CT = themeColorData(theme.team_ct, PATSB.ThemeDefaults.team_ct)
end

applyThemeColors()

local function sbBool(name, fallback)
    local v = PATSB.Settings[name]
    if v == nil then return fallback end
    return v and true or false
end

local function sbInt(name, fallback)
    local v = tonumber(PATSB.Settings[name])
    if v == nil then return fallback end
    return math.floor(v)
end

local function sbFloat(name, fallback)
    local v = tonumber(PATSB.Settings[name])
    if v == nil then return fallback end
    return v
end

local function sbString(name, fallback)
    local v = PATSB.Settings[name]
    if v == nil or v == "" then return fallback end
    return tostring(v)
end

local function UIScale()
    return math.min(ScrW() / BASE_W, ScrH() / BASE_H) * sbFloat("ui_scale_mul", 1)
end

local function ui(v)
    return math.max(1, math.floor(v * UIScale()))
end

local function rebuildFonts(force)
    if not force and _lastScrW == ScrW() and _lastScrH == ScrH() then return end
    _lastScrW, _lastScrH = ScrW(), ScrH()

    local titleFont = sbString("font_title", "Tahoma")
    local bodyFont = sbString("font_body", "Tahoma")

    surface.CreateFont(FONT_TITLE, {
        font = titleFont,
        size = ui(28),
        weight = 900,
        extended = true
    })

    surface.CreateFont(FONT_HEADER, {
        font = bodyFont,
        size = ui(20),
        weight = 800,
        extended = true
    })

    surface.CreateFont(FONT_MED, {
        font = bodyFont,
        size = ui(18),
        weight = 700,
        extended = true
    })

    surface.CreateFont(FONT_SMALL, {
        font = bodyFont,
        size = ui(14),
        weight = 600,
        extended = true
    })
end

rebuildFonts(true)

hook.Add("OnScreenSizeChanged", "PATSB_RebuildFonts", function()
    rebuildFonts(true)
end)

local function drawOutlinedRect(x, y, w, h, col, thick)
    surface.SetDrawColor(col)
    surface.DrawOutlinedRect(x, y, w, h, thick or 1)
end

local function blurPanel(panel, a)
    local blur = sbInt("blur_strength", 5)

    if hg and hg.DrawBlur then
        hg.DrawBlur(panel, blur, 1, a or 120)
    else
        surface.SetDrawColor(0, 0, 0, a or 120)
        surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())
    end
end

local function getTeamAccent(ply)
    if not IsValid(ply) then return COL_SPEC end
    if TEAM_SPECTATOR and ply:Team() == TEAM_SPECTATOR then return COL_SPEC end
    return ply:Team() == 1 and COL_CT or COL_T
end

local function getKarma(ply)
    if not IsValid(ply) then return 0 end

    local candidates = {"Karma", "karma", "PlayerKarma", "HMCD_Karma", "hg_karma"}
    for _, key in ipairs(candidates) do
        local v = ply:GetNWInt(key, -999999)
        if v ~= -999999 then
            return math.floor(tonumber(v) or 0)
        end
    end

    if ply.Karma then
        return math.floor(tonumber(ply.Karma) or 0)
    end

    return 0
end

local function prettifyUserGroup(group)
    group = tostring(group or "user")
    if group == "" then
        return "User"
    end

    group = string.gsub(group, "_", " ")
    group = string.Trim(group)

    return string.upper(string.sub(group, 1, 1)) .. string.sub(group, 2)
end

local function getUserGroupText(ply)
    if not IsValid(ply) then return "User" end

    if AS and AS.GetUserGroup then
        return prettifyUserGroup(AS:GetUserGroup(ply))
    end

    if ply.GetUserGroup then
        return prettifyUserGroup(ply:GetUserGroup())
    end

    return "User"
end

local function getNickNameText(ply)
    if not IsValid(ply) then return "Disconnected" end
    return tostring((ply.Nick and ply:Nick()) or (ply.Name and ply:Name()) or "Disconnected")
end

local function getCharacterNicknameText(ply)
    if not IsValid(ply) then return "Disconnected" end

    if ply.GetPlayerName then
        local characterName = tostring(ply:GetPlayerName() or "")
        if characterName ~= "" then
            return characterName
        end
    end

    return getNickNameText(ply)
end

local steamNameCache = {}
local steamNamePending = {}

local function requestSteamName(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    if not steamworks or not steamworks.RequestPlayerInfo then return end

    local sid64 = tostring(ply:SteamID64() or "")
    if sid64 == "" then return end
    if steamNamePending[sid64] then return end

    steamNamePending[sid64] = true
    steamworks.RequestPlayerInfo(sid64, function(_, name)
        steamNamePending[sid64] = nil
        if isstring(name) and name ~= "" then
            steamNameCache[sid64] = tostring(name)
        end
    end)
end

local function getSteamNameText(ply)
    if not IsValid(ply) then return "" end
    if ply:IsBot() then return "BOT" end

    local sid64 = tostring(ply:SteamID64() or "")
    if sid64 ~= "" and steamNameCache[sid64] and steamNameCache[sid64] ~= "" then
        return steamNameCache[sid64]
    end

    local steamName = ""
    if ply.SteamName then
        steamName = tostring(ply:SteamName() or "")
    end

    if steamName ~= "" then
        if sid64 ~= "" then
            steamNameCache[sid64] = steamName
        end
        return steamName
    end

    requestSteamName(ply)
    return "Loading..."
end

local function formatSessionTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if hours > 0 then
        return string.format("%02ih %02im", hours, minutes)
    end

    return string.format("%02im", minutes)
end

local function getSessionTimeText(ply)
    if not IsValid(ply) then
        return "00m"
    end

    local joined = ply:GetNWInt("PATSB_JoinUnix", 0)
    if joined <= 0 then
        return "00m"
    end

    return formatSessionTime(os.time() - joined)
end

local function getPlaytimeSeconds(ply)
    if not IsValid(ply) then
        return nil
    end

    local baseTotal = tonumber(ply:GetNWInt("PATSB_TotalPlayBase", -1))
    if baseTotal and baseTotal >= 0 then
        return baseTotal + math.max(0, os.time() - math.max(0, ply:GetNWInt("PATSB_JoinUnix", os.time())))
    end

    if ply.GetUTimeTotalTime then
        local total = tonumber(ply:GetUTimeTotalTime())
        local session = ply.GetUTimeSessionTime and tonumber(ply:GetUTimeSessionTime()) or 0
        if total and total >= 0 then
            return total + math.max(session or 0, 0)
        end
    end

    local nwKeys = {
        "UTimeTotalTime",
        "UTime_TotalTime",
        "PlayTime",
        "TimePlayed",
        "TotalPlayTime"
    }

    for _, key in ipairs(nwKeys) do
        local value = tonumber(ply:GetNWInt(key, -1))
        if value and value >= 0 then
            return value
        end
    end

    return nil
end

local function getPlaytimeText(ply)
    local seconds = getPlaytimeSeconds(ply)
    if not seconds or seconds <= 0 then
        return nil
    end

    return formatSessionTime(seconds)
end

local function getRoundStateText()
    if zb.ROUND_STATE == 0 then return "Waiting" end
    if zb.ROUND_STATE == 1 then return "Live" end
    if zb.ROUND_STATE == 2 then return "Post-Round" end
    if zb.ROUND_STATE == 3 then return "Ending" end
    return "Unknown"
end

local function getTimeText()
    local startTime = zb.ROUND_START or CurTime()
    local roundTime = zb.ROUND_TIME or 0
    local left = math.max(startTime + roundTime - CurTime(), 0)
    return string.FormattedTime(left, "%02i:%02i")
end

local function getVoiceKey(ply)
    if not IsValid(ply) then return "" end

    if ply:IsBot() then
        return "bot_" .. tostring(ply:EntIndex())
    end

    return ply:SteamID() or ""
end

local function volumeFor(ply)
    local key = getVoiceKey(ply)
    if key == "" then return 1 end

    local info = hg.playerInfo and hg.playerInfo[key]
    if istable(info) then
        return tonumber(info[2]) or 1
    end

    return 1
end

local function isStoredMuted(ply)
    local key = getVoiceKey(ply)
    if key == "" then return false end

    local info = hg.playerInfo and hg.playerInfo[key]
    if istable(info) then
        return info[1] and true or false
    end

    return false
end

local function saveMuteInfo(ply, muted, volume)
    if not IsValid(ply) then return end

    local key = getVoiceKey(ply)
    if key == "" then return end

    hg.playerInfo = hg.playerInfo or {}
    hg.playerInfo[key] = {muted and true or false, volume or volumeFor(ply)}

    local json = util.TableToJSON(hg.playerInfo)
    if json then
        file.Write("zcity_muted.txt", json)
    end
end

local function applyVoiceState(ply)
    if not IsValid(ply) then return end

    if hg.muteall then
        ply:SetVoiceVolumeScale(0)
        return
    end

    if hg.mutespect and not ply:Alive() then
        ply:SetVoiceVolumeScale(0)
        return
    end

    if isStoredMuted(ply) then
        ply:SetVoiceVolumeScale(0)
        return
    end

    ply:SetVoiceVolumeScale(volumeFor(ply))
end

local function runULXCommand(cmd)
    LocalPlayer():ConCommand(cmd)
end

local function hasZCityKarmaULX()
    return istable(ZCITY_ULX_KARMA)
        and ZCITY_ULX_KARMA.Loaded
        and istable(ZCITY_ULX_KARMA.Commands)
        and ZCITY_ULX_KARMA.Commands.setkarma
        and ZCITY_ULX_KARMA.Commands.addkarma
        and ZCITY_ULX_KARMA.Commands.removekarma
end

local function hasZCityStoreULX()
    return istable(ZCITY_ULX_STORE)
        and ZCITY_ULX_STORE.Loaded
        and istable(ZCITY_ULX_STORE.Commands)
        and ZCITY_ULX_STORE.Commands.settokens
        and ZCITY_ULX_STORE.Commands.addtokens
end

local function addStaffULXSubmenu(menu, ply)
    if not sbBool("enable_ulx_menu", true) then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():IsAdmin() then return end
    if not IsValid(ply) then return end

    local nick = string.gsub(ply:Nick() or "unknown", "\"", "")
    local sid = ply:SteamID() or ""
    local sid64 = ply:SteamID64() or ""

    local staffMenu = menu:AddSubMenu("Staff / ULX")

    local tpMenu = staffMenu:AddSubMenu("Teleport")
    tpMenu:AddOption("Bring", function() runULXCommand('ulx bring "' .. nick .. '"') end)
    tpMenu:AddOption("Goto", function() runULXCommand('ulx goto "' .. nick .. '"') end)
    tpMenu:AddOption("Return", function() runULXCommand('ulx return "' .. nick .. '"') end)

    local modMenu = staffMenu:AddSubMenu("Moderation")
    modMenu:AddOption("Freeze", function() runULXCommand('ulx freeze "' .. nick .. '"') end)
    modMenu:AddOption("Unfreeze", function() runULXCommand('ulx unfreeze "' .. nick .. '"') end)
    modMenu:AddOption("Jail", function() runULXCommand('ulx jail "' .. nick .. '"') end)
    modMenu:AddOption("Unjail", function() runULXCommand('ulx unjail "' .. nick .. '"') end)
    modMenu:AddOption("Spectate", function() runULXCommand('ulx spectate "' .. nick .. '"') end)
    modMenu:AddSpacer()
    modMenu:AddOption("Slay", function()
        Derma_Query(
            "Slay " .. nick .. "?",
            "Confirm Slay",
            "Yes", function() runULXCommand('ulx slay "' .. nick .. '"') end,
            "No"
        )
    end)
    modMenu:AddOption("Kick", function()
        Derma_StringRequest(
            "Kick Player",
            "Enter kick reason for " .. nick,
            "",
            function(reason)
                reason = reason ~= "" and reason or "No reason"
                runULXCommand('ulx kick "' .. nick .. '" "' .. string.gsub(reason, '"', "'") .. '"')
            end,
            function() end,
            "Kick",
            "Cancel"
        )
    end)
    modMenu:AddOption("Ban (60m)", function()
        Derma_StringRequest(
            "Ban Player",
            "Enter ban reason for " .. nick,
            "",
            function(reason)
                reason = reason ~= "" and reason or "No reason"
                runULXCommand('ulx ban "' .. nick .. '" 60 "' .. string.gsub(reason, '"', "'") .. '"')
            end,
            function() end,
            "Ban",
            "Cancel"
        )
    end)

    if hasZCityKarmaULX() or hasZCityStoreULX() then
        local zcity = staffMenu:AddSubMenu("Z-City")

        if hasZCityKarmaULX() then
            zcity:AddOption("Set Karma", function()
                Derma_StringRequest(
                    "Set Karma",
                    "Enter karma value for " .. nick .. " (0-120)",
                    tostring(ply.Karma or 0),
                    function(value)
                        value = tonumber(value)
                        if not value then return end
                        value = math.Clamp(math.floor(value), 0, 120)
                        runULXCommand('ulx setkarma "' .. nick .. '" ' .. value)
                    end,
                    function() end,
                    "Set",
                    "Cancel"
                )
            end)

            zcity:AddOption("Add Karma", function()
                Derma_StringRequest(
                    "Add Karma",
                    "Enter amount to add for " .. nick,
                    "10",
                    function(value)
                        value = tonumber(value)
                        if not value then return end
                        value = math.Clamp(math.floor(value), 0, 120)
                        runULXCommand('ulx addkarma "' .. nick .. '" ' .. value)
                    end,
                    function() end,
                    "Add",
                    "Cancel"
                )
            end)

            zcity:AddOption("Remove Karma", function()
                Derma_StringRequest(
                    "Remove Karma",
                    "Enter amount to remove from " .. nick,
                    "10",
                    function(value)
                        value = tonumber(value)
                        if not value then return end
                        value = math.Clamp(math.floor(value), 0, 120)
                        runULXCommand('ulx removekarma "' .. nick .. '" ' .. value)
                    end,
                    function() end,
                    "Remove",
                    "Cancel"
                )
            end)

            zcity:AddOption("Set Spectator", function()
                Derma_Query(
                    "Move " .. nick .. " to spectators?",
                    "Set Spectator",
                    "Yes", function() runULXCommand('ulx setspectator "' .. nick .. '"') end,
                    "No"
                )
            end)
        end

        if hasZCityStoreULX() then
            if hasZCityKarmaULX() then
                zcity:AddSpacer()
            end

            local setTokensCommand = tostring(ZCITY_ULX_STORE.Commands.settokens or "zbstoretokens")
            local addTokensCommand = tostring(ZCITY_ULX_STORE.Commands.addtokens or "zbstoreaddtokens")

            zcity:AddOption("Set Tokens", function()
                Derma_StringRequest(
                    "Set Tokens",
                    "Enter token total for " .. nick,
                    tostring(ply:GetNWInt("ZCStore_Tokens", 0)),
                    function(value)
                        value = tonumber(value)
                        if not value then return end
                        value = math.max(0, math.floor(value))
                        runULXCommand('ulx ' .. setTokensCommand .. ' "' .. nick .. '" ' .. value)
                    end,
                    function() end,
                    "Set",
                    "Cancel"
                )
            end)

            zcity:AddOption("Add Tokens", function()
                Derma_StringRequest(
                    "Add Tokens",
                    "Enter token amount to add for " .. nick,
                    "10",
                    function(value)
                        value = tonumber(value)
                        if not value then return end
                        value = math.max(0, math.floor(value))
                        runULXCommand('ulx ' .. addTokensCommand .. ' "' .. nick .. '" ' .. value)
                    end,
                    function() end,
                    "Add",
                    "Cancel"
                )
            end)
        end
    end

    local utilMenu = staffMenu:AddSubMenu("Utility")
    utilMenu:AddOption("Copy SteamID", function() SetClipboardText(sid) end)
    utilMenu:AddOption("Copy SteamID64", function() SetClipboardText(sid64) end)

    if sbBool("enable_profile_button", true) and not ply:IsBot() then
        utilMenu:AddOption("Open Steam Profile", function()
            gui.OpenURL("https://steamcommunity.com/profiles/" .. sid64)
        end)
    end
end

local function createCommandButton(parent, text, x, y, w, h, sayText)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn.DoClick = function()
        RunConsoleCommand("say", sayText)
    end
    btn.Paint = function(self, pw, ph)
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(0, 0, pw, ph)
        drawOutlinedRect(0, 0, pw, ph, COL_RED, ui(2))
        draw.SimpleText(text, FONT_MED, pw * 0.5, ph * 0.5, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return btn
end

local function createMiniButton(parent, text, x, y, w, h, fn)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn.DoClick = fn
    btn.Paint = function(self, pw, ph)
        surface.SetDrawColor(0, 0, 0, 160)
        surface.DrawRect(0, 0, pw, ph)
        drawOutlinedRect(0, 0, pw, ph, COL_RED, ui(2))
        draw.SimpleText(text, FONT_SMALL, pw * 0.5, ph * 0.5, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return btn
end

local function makeScrollBarPretty(panel)
    local bar = panel:GetVBar()

    function bar:Paint() end
    function bar.btnUp:Paint(w, h)
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, COL_RED, 1)
    end
    function bar.btnDown:Paint(w, h)
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, COL_RED, 1)
    end
    function bar.btnGrip:Paint(w, h)
        surface.SetDrawColor(40, 40, 40, 220)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, COL_RED, 1)
    end

    bar:SetWide(ui(10))
end

local function createPlayerCard(parent, ply)
    local card = vgui.Create("DButton", parent)
    card:SetTall(ui(72))
    card:Dock(TOP)
    card:DockMargin(ui(10), 0, ui(10), ui(8))
    card:SetText("")

    local avatar = vgui.Create("AvatarImage", card)
    avatar:SetSize(ui(52), ui(52))
    avatar:SetPos(ui(12), ui(10))
    if IsValid(ply) and not ply:IsBot() then
        avatar:SetPlayer(ply, 64)
    end

    local voiceButton
    if sbBool("show_voice_buttons", true) then
        voiceButton = vgui.Create("DButton", card)
        voiceButton:SetSize(ui(72), ui(28))
        voiceButton:SetText("")
        voiceButton:SetTooltip("Toggle voice for " .. (ply:Name() or "Unknown"))
        voiceButton.DoClick = function()
            if not IsValid(ply) then return end
            local newMuted = not isStoredMuted(ply)
            saveMuteInfo(ply, newMuted, volumeFor(ply))
            applyVoiceState(ply)
        end
        voiceButton.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 160)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, isStoredMuted(ply) and Color(107,0,0) or Color(0,97,5), 1)
            draw.SimpleText(isStoredMuted(ply) and "Muted" or "Voice", FONT_SMALL, w / 2, h / 2, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    card.PerformLayout = function(self, w, h)
        if IsValid(voiceButton) then
            voiceButton:SetPos(w - ui(84), h / 2 - ui(14))
        end
    end

    card.DoClick = function()
        if not sbBool("enable_profile_button", true) then return end
        if not IsValid(ply) or ply:IsBot() then return end
        gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
    end

    card.DoRightClick = function()
        if not IsValid(ply) then return end

        local menu = DermaMenu()
        menu:AddOption("Copy SteamID", function() SetClipboardText(ply:SteamID()) end)

        if sbBool("enable_profile_button", true) and not ply:IsBot() then
            menu:AddOption("Open Steam Profile", function()
                gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
            end)
        end

        addStaffULXSubmenu(menu, ply)
        menu:Open()
    end

    card.Paint = function(self, w, h)
        if not IsValid(ply) then return end

        local accent = getTeamAccent(ply)
        surface.SetDrawColor(COL_BG2)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(COL_BG3)
        surface.DrawRect(0, h * 0.52, w, h * 0.48)
        surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
        surface.DrawRect(0, 0, ui(6), h)
        drawOutlinedRect(0, 0, w, h, COL_RED_SOFT, ui(2))

        local name = getNickNameText(ply)
        local characterNickname = getCharacterNicknameText(ply)
        local usergroup = getUserGroupText(ply)
        local subline = "Player Nickname: " .. characterNickname .. " | " .. usergroup
        local sessionTime = getSessionTimeText(ply)
        local playtimeText = getPlaytimeText(ply)
        local karma = getKarma(ply)
        local ping = ply:Ping() or 0

        local nameX = ui(76)
        local topY = ui(12)
        local valueY = ui(34)
        local statColumnWidth = ui(108)
        local statGap = ui(6)
        local statRightEdge = w - (IsValid(voiceButton) and ui(96) or ui(14))
        local stats = {}

        draw.SimpleText(name, FONT_MED, nameX, topY, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(subline, FONT_SMALL, nameX, valueY, COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if sbBool("show_session", true) then
            table.insert(stats, {
                label = "Session",
                value = sessionTime
            })
        end

        if sbBool("show_playtime", true) and playtimeText then
            table.insert(stats, {
                label = "Playtime",
                value = playtimeText
            })
        end

        if sbBool("show_karma", true) then
            table.insert(stats, {
                label = "Karma",
                value = tostring(karma)
            })
        end

        table.insert(stats, {
            label = "Ping",
            value = tostring(ping)
        })

        for index, stat in ipairs(stats) do
            local remaining = #stats - index
            local statX = statRightEdge - statColumnWidth - (remaining * (statColumnWidth + statGap))
            draw.SimpleText(stat.label, FONT_SMALL, statX, topY, COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(stat.value, FONT_MED, statX, valueY, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    return card
end

local function buildSidebar(parent, x, y, w, h)
    local pad = ui(18)
    local rowGap = ui(20)
    local blockGap = ui(56)

    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(x, y)
    panel:SetSize(w, h)

    panel.Paint = function(self, pw, ph)
        blurPanel(self, 90)
        surface.SetDrawColor(COL_BG)
        surface.DrawRect(0, 0, pw, ph)
        drawOutlinedRect(0, 0, pw, ph, COL_RED_SOFT, ui(2))

        local modeName = (zb.CROUND and zb.CROUND ~= "" and string.upper(zb.CROUND)) or "LOBBY"

        draw.SimpleText("ROUND INFO", FONT_HEADER, pad, ui(16), COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(modeName, FONT_MED, pad, ui(60), Color(255,80,80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        draw.SimpleText("State", FONT_SMALL, pad, ui(102), COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(getRoundStateText(), FONT_MED, pad, ui(102) + rowGap, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        draw.SimpleText("Time Left", FONT_SMALL, pad, ui(102) + blockGap, COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(getTimeText(), FONT_MED, pad, ui(102) + blockGap + rowGap, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        draw.SimpleText("Players", FONT_SMALL, pad, ui(102) + blockGap * 2, COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(#player.GetAll()), FONT_MED, pad, ui(102) + blockGap * 2 + rowGap, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if sbBool("show_tickrate", true) then
            draw.SimpleText("Tickrate", FONT_SMALL, pad, ui(102) + blockGap * 3, COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(math.Round(1 / engine.ServerFrameTime())), FONT_MED, pad, ui(102) + blockGap * 3 + rowGap, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        draw.SimpleText("SERVER COMMANDS", FONT_HEADER, pad, ui(345), COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Use @ \"message\" in chat to contact an admin", FONT_SMALL, pad, ui(390), COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if sbBool("show_spectators", true) then
            draw.SimpleText("SPECTATORS", FONT_HEADER, pad, ph - ui(170), COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    local commandCount = 0
    if sbBool("command_1_enabled", true) then
        createCommandButton(panel, sbString("command_1_text", "Store"), pad, ui(424), w - pad * 2, ui(40), sbString("command_1_say", "!store"))
        commandCount = commandCount + 1
    end

    if sbBool("command_2_enabled", true) then
        local y = commandCount == 0 and ui(424) or ui(474)
        createCommandButton(panel, sbString("command_2_text", "Guide"), pad, y, w - pad * 2, ui(40), sbString("command_2_say", "!motd"))
    end

    if not sbBool("show_spectators", true) then
        return panel
    end

    local specScroll = vgui.Create("DScrollPanel", panel)
    specScroll:SetPos(pad, h - ui(128))
    specScroll:SetSize(w - pad * 2, ui(104))
    makeScrollBarPretty(specScroll)
    specScroll.Paint = function(self, pw, ph)
        surface.SetDrawColor(0, 0, 0, 120)
        surface.DrawRect(0, 0, pw, ph)
        drawOutlinedRect(0, 0, pw, ph, COL_RED_SOFT, 1)
    end

    local specs = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and TEAM_SPECTATOR and ply:Team() == TEAM_SPECTATOR then
            table.insert(specs, ply)
        end
    end

    table.sort(specs, function(a, b)
        return a:Name():lower() < b:Name():lower()
    end)

    if #specs == 0 then
        local row = vgui.Create("DLabel", specScroll)
        row:Dock(TOP)
        row:DockMargin(ui(8), ui(8), ui(8), 0)
        row:SetTall(ui(20))
        row:SetText("No spectators")
        row:SetFont(FONT_SMALL)
        row:SetTextColor(COL_MUTED)
    else
        for _, ply in ipairs(specs) do
            local row = vgui.Create("DLabel", specScroll)
            row:Dock(TOP)
            row:DockMargin(ui(8), ui(4), ui(8), 0)
            row:SetTall(ui(20))
            row:SetText((ply:Name() or "Unknown") .. "  •  " .. (ply:Ping() or 0) .. " ping")
            row:SetFont(FONT_SMALL)
            row:SetTextColor(COL_TEXT)
        end
    end

    return panel
end

local function buildTopHeader(parent, w)
    local header = vgui.Create("DPanel", parent)
    header:SetPos(ui(12), ui(12))
    header:SetSize(w - ui(24), ui(78))
    header.Paint = function(self, pw, ph)
        surface.SetDrawColor(0, 0, 0, 165)
        surface.DrawRect(0, 0, pw, ph)
        drawOutlinedRect(0, 0, pw, ph, COL_RED_SOFT, ui(2))
        draw.SimpleText(GetHostName() or "ZBattle", FONT_TITLE, pw * 0.5, ui(12), COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
    return header
end

local function refreshScoreboardLists(playersScroll)
    if not IsValid(playersScroll) then return end
    playersScroll:Clear()

    local players = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and (not TEAM_SPECTATOR or ply:Team() ~= TEAM_SPECTATOR) then
            table.insert(players, ply)
        end
    end

    table.sort(players, function(a, b)
        if a:IsBot() ~= b:IsBot() then return not a:IsBot() end
        return (a:Name() or ""):lower() < (b:Name() or ""):lower()
    end)

    for _, ply in ipairs(players) do
        createPlayerCard(playersScroll, ply)
    end
end

local settingsFrame

local function openScoreboardSettingsMenu(initialSettings)
    if not IsValid(LocalPlayer()) or not LocalPlayer():IsAdmin() then return end

    if IsValid(settingsFrame) then
        settingsFrame:Remove()
        settingsFrame = nil
    end

    rebuildFonts(true)

    local staged = table.Copy(istable(initialSettings) and initialSettings or PATSB.Settings)
    ensureThemeTable(staged)

    local frameClass = vgui.GetControlTable("ZFrame") and "ZFrame" or "DFrame"
    settingsFrame = vgui.Create(frameClass)
    local fr = settingsFrame

    fr:SetSize(math.min(ui(1180), ScrW() * 0.84), math.min(ui(900), ScrH() * 0.9))
    fr:Center()
    fr:MakePopup()
    fr:SetKeyboardInputEnabled(true)

    if fr.SetTitle then fr:SetTitle("") end
    if fr.ShowCloseButton then fr:ShowCloseButton(false) end

    fr.Paint = function(self, w, h)
        blurPanel(self, 100)
        surface.SetDrawColor(COL_BG)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, COL_RED, ui(2))
    end

    local titleBar = fr:Add("DPanel")
    titleBar:Dock(TOP)
    titleBar:SetTall(ui(56))
    titleBar.Paint = function(self, w, h)
        surface.SetDrawColor(COL_BG2)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, COL_RED_SOFT, 1)
        draw.SimpleText("Scoreboard Admin", FONT_TITLE, ui(14), ui(6), COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Admin changes apply to everyone.", FONT_SMALL, ui(16), ui(32), COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local function styleTitleButton(button, label)
        button:SetText("")
        button.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 180)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, self:IsHovered() and COL_RED or COL_RED_SOFT, ui(2))
            draw.SimpleText(label, FONT_SMALL, w * 0.5, h * 0.5, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local closeButton = titleBar:Add("DButton")
    closeButton:Dock(RIGHT)
    closeButton:DockMargin(0, ui(10), ui(10), ui(10))
    closeButton:SetWide(ui(36))
    styleTitleButton(closeButton, "X")
    closeButton.DoClick = function()
        fr:Remove()
    end

    local saveButton = titleBar:Add("DButton")
    saveButton:Dock(RIGHT)
    saveButton:DockMargin(0, ui(10), ui(10), ui(10))
    saveButton:SetWide(ui(132))
    styleTitleButton(saveButton, "Save Settings")
    saveButton.DoClick = function()
        net.Start("PATSB_SaveSettings")
        net.WriteString(util.TableToJSON(staged, false) or "{}")
        net.SendToServer()
        fr:Remove()
    end

    local resetButton = titleBar:Add("DButton")
    resetButton:Dock(RIGHT)
    resetButton:DockMargin(0, ui(10), ui(10), ui(10))
    resetButton:SetWide(ui(120))
    styleTitleButton(resetButton, "Reset Defaults")
    resetButton.DoClick = function()
        fr:Remove()
        openScoreboardSettingsMenu(table.Copy(PATSB.Defaults))
    end

    local sheet = fr:Add("DPropertySheet")
    sheet:Dock(FILL)
    sheet:DockMargin(ui(10), ui(10), ui(10), ui(10))
    sheet.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 85)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, COL_RED_SOFT, 1)
    end
    if IsValid(sheet.tabScroller) then
        sheet.tabScroller:SetTall(ui(42))
        sheet.tabScroller:SetOverlap(0)
    end

    local function styleSheetTab(tab, label)
        tab:SetText(label)
        if tab.SetContentAlignment then
            tab:SetContentAlignment(5)
        end
        if tab.SetTextColor then
            tab:SetTextColor(Color(0, 0, 0, 0))
        end
        if tab.DockMargin then
            tab:DockMargin(0, 0, ui(6), 0)
        end
        tab.ApplySchemeSettings = function(self)
            self:SetTextInset(ui(14), ui(4))
            surface.SetFont(FONT_MED)
            local textWidth = select(1, surface.GetTextSize(label))
            self:SetSize(math.max(ui(160), textWidth + ui(56)), ui(36))
            DLabel.ApplySchemeSettings(self)
            self:SetTextStyleColor(Color(0, 0, 0, 0))
        end
        tab.PerformLayout = function(self)
            self:ApplySchemeSettings()
            if IsValid(self.Image) then
                self.Image:SetPos(ui(7), ui(3))
            end
        end
        tab.Paint = function(self, w, h)
            local active = sheet:GetActiveTab() == self
            surface.SetDrawColor(0, 0, 0, active and 220 or 160)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, active and COL_RED or COL_RED_SOFT, 1)
            draw.SimpleText(label, FONT_MED, w * 0.5, h * 0.5, active and COL_WHITE or COL_MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local function createTab(label)
        local panel = vgui.Create("DScrollPanel", sheet)
        makeScrollBarPretty(panel)
        if IsValid(panel:GetCanvas()) then
            panel:GetCanvas():DockPadding(ui(12), ui(12), ui(12), ui(12))
        end

        local tabData = sheet:AddSheet(label, panel)
        styleSheetTab(tabData.Tab, label)

        return panel
    end

    local function styleTextEntry(entry)
        entry:SetFont(FONT_MED)
        entry:SetTextColor(COL_WHITE)
        entry:SetHighlightColor(COL_RED)
        entry.Paint = function(self, w, h)
            surface.SetDrawColor(COL_BG3)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, self:HasFocus() and COL_RED or COL_RED_SOFT, 1)
            self:DrawTextEntryText(COL_WHITE, COL_RED, COL_WHITE)
        end
    end

    local function styleCombo(combo)
        combo:SetFont(FONT_MED)
        combo:SetTextColor(COL_WHITE)
        combo.Paint = function(self, w, h)
            surface.SetDrawColor(COL_BG3)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, self:IsMenuOpen() and COL_RED or COL_RED_SOFT, 1)
            draw.SimpleText(self:GetValue() or "", FONT_MED, ui(10), h * 0.5, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        if IsValid(combo.DropButton) then
            combo.DropButton:SetText("")
            combo.DropButton.Paint = function(self, w, h)
                draw.SimpleText("v", FONT_SMALL, w * 0.5, h * 0.5, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    local function stagedThemeColor(key)
        return themeColorData(staged.theme and staged.theme[key], PATSB.ThemeDefaults[key])
    end

    local function addSectionHeader(parent, title, subtitle)
        local header = parent:Add("DPanel")
        header:Dock(TOP)
        header:DockMargin(0, 0, 0, ui(10))
        header:SetTall(subtitle and ui(52) or ui(30))
        header.Paint = nil

        local titleLabel = header:Add("DLabel")
        titleLabel:Dock(TOP)
        titleLabel:SetTall(ui(24))
        titleLabel:SetFont(FONT_HEADER)
        titleLabel:SetText(title)
        titleLabel:SetTextColor(COL_WHITE)
        titleLabel:SetContentAlignment(4)

        if subtitle then
            local subtitleLabel = header:Add("DLabel")
            subtitleLabel:Dock(TOP)
            subtitleLabel:SetTall(ui(18))
            subtitleLabel:SetFont(FONT_SMALL)
            subtitleLabel:SetText(subtitle)
            subtitleLabel:SetTextColor(COL_MUTED)
            subtitleLabel:SetContentAlignment(4)
        end
    end

    local function addFieldBlock(parent, labelText, opts)
        opts = opts or {}

        local block = parent:Add("DPanel")
        block:Dock(TOP)
        block:DockMargin(0, 0, 0, ui(10))
        block:SetTall(opts.height or ui(58))
        block.Paint = function(self, w, h)
            surface.SetDrawColor(COL_BG2)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, COL_RED_SOFT, 1)
        end

        local label = block:Add("DLabel")
        label:Dock(TOP)
        label:DockMargin(ui(10), ui(8), ui(10), ui(4))
        label:SetTall(ui(16))
        label:SetFont(FONT_SMALL)
        label:SetText(labelText)
        label:SetTextColor(COL_WHITE)
        label:SetContentAlignment(4)

        return block, label
    end

    local function addTextEntry(parent, labelText, key, opts)
        opts = opts or {}
        local block = addFieldBlock(parent, labelText, { height = opts.multiline and ui(104) or ui(58) })
        local entry = block:Add("DTextEntry")
        entry:Dock(FILL)
        entry:DockMargin(ui(10), 0, ui(10), ui(8))
        entry:SetText(tostring(staged[key] or ""))
        entry:SetUpdateOnType(true)
        entry:SetMultiline(opts.multiline == true)
        if opts.numeric then
            entry:SetNumeric(true)
        end
        styleTextEntry(entry)
        entry.OnValueChange = function(self, val)
            staged[key] = val
        end

        return entry
    end

    local function addCheck(parent, labelText, key)
        local block = parent:Add("DPanel")
        block:Dock(TOP)
        block:DockMargin(0, 0, 0, ui(10))
        block:SetTall(ui(38))
        block.Paint = function(self, w, h)
            surface.SetDrawColor(COL_BG2)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, COL_RED_SOFT, 1)
        end

        local label = block:Add("DLabel")
        label:Dock(FILL)
        label:DockMargin(ui(10), 0, ui(10), 0)
        label:SetFont(FONT_MED)
        label:SetText(labelText)
        label:SetTextColor(COL_WHITE)
        label:SetContentAlignment(4)

        local checkbox = block:Add("DCheckBox")
        checkbox:Dock(RIGHT)
        checkbox:DockMargin(0, ui(8), ui(10), ui(8))
        checkbox:SetWide(ui(22))
        checkbox:SetChecked(staged[key] and true or false)
        checkbox.Paint = function(self, w, h)
            surface.SetDrawColor(COL_BG3)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, self:GetChecked() and COL_RED or COL_RED_SOFT, 1)
            if self:GetChecked() then
                surface.SetDrawColor(COL_RED)
                surface.DrawRect(ui(4), ui(4), w - ui(8), h - ui(8))
            end
        end
        checkbox.OnChange = function(_, val)
            staged[key] = val and true or false
        end
    end

    local function addCombo(parent, labelText, key, choices)
        local block = addFieldBlock(parent, labelText)
        local combo = block:Add("DComboBox")
        combo:Dock(FILL)
        combo:DockMargin(ui(10), 0, ui(10), ui(8))
        for _, choice in ipairs(choices or {}) do
            combo:AddChoice(choice)
        end
        combo:SetValue(tostring(staged[key] or choices[1] or ""))
        styleCombo(combo)
        combo.OnSelect = function(_, _, value)
            staged[key] = value
        end

        return combo
    end

    local generalPanel = createTab("General")
    addSectionHeader(generalPanel, "Core", "High-level behavior and font setup.")
    addTextEntry(generalPanel, "Refresh interval (0.25 - 5)", "refresh_interval", { numeric = true })
    addTextEntry(generalPanel, "Blur strength (0 - 10)", "blur_strength", { numeric = true })
    addTextEntry(generalPanel, "UI scale multiplier (0.75 - 1.50)", "ui_scale_mul", { numeric = true })
    addSectionHeader(generalPanel, "Fonts", "These rebuild after save when the server syncs settings back.")
    addTextEntry(generalPanel, "Title font", "font_title")
    addTextEntry(generalPanel, "Body font", "font_body")

    local layoutPanel = createTab("Layout")
    addSectionHeader(layoutPanel, "Window Size", "Scoreboard frame bounds for all clients.")
    addTextEntry(layoutPanel, "Frame width (1000 - 1800)", "frame_width", { numeric = true })
    addTextEntry(layoutPanel, "Frame height (700 - 1100)", "frame_height", { numeric = true })
    addSectionHeader(layoutPanel, "Sidebar", "Left-side summary panel sizing.")
    addTextEntry(layoutPanel, "Sidebar min width (220 - 500)", "sidebar_width_min", { numeric = true })
    addTextEntry(layoutPanel, "Sidebar max width (260 - 600)", "sidebar_width_max", { numeric = true })
    addTextEntry(layoutPanel, "Sidebar width fraction (0.15 - 0.40)", "sidebar_width_frac", { numeric = true })

    local featuresPanel = createTab("Features")
    addSectionHeader(featuresPanel, "Visibility", "Toggle what players can see and interact with.")
    addCheck(featuresPanel, "Enable ULX menu", "enable_ulx_menu")
    addCheck(featuresPanel, "Enable Steam profile button", "enable_profile_button")
    addCheck(featuresPanel, "Show spectators", "show_spectators")
    addCheck(featuresPanel, "Show karma", "show_karma")
    addCheck(featuresPanel, "Show session time", "show_session")
    addCheck(featuresPanel, "Show total playtime", "show_playtime")
    addCheck(featuresPanel, "Show tickrate", "show_tickrate")
    addCheck(featuresPanel, "Show per-player voice buttons", "show_voice_buttons")
    addCheck(featuresPanel, "Show mute buttons", "show_bottom_mute_buttons")
    addCheck(featuresPanel, "Show spectate/join button", "show_team_button")

    local commandsPanel = createTab("Commands")
    addSectionHeader(commandsPanel, "Bottom Bar Buttons", "Configure the two custom command buttons on the scoreboard.")
    addCheck(commandsPanel, "Enable command button 1", "command_1_enabled")
    addTextEntry(commandsPanel, "Command 1 text", "command_1_text")
    addTextEntry(commandsPanel, "Command 1 say", "command_1_say")
    addCheck(commandsPanel, "Enable command button 2", "command_2_enabled")
    addTextEntry(commandsPanel, "Command 2 text", "command_2_text")
    addTextEntry(commandsPanel, "Command 2 say", "command_2_say")

    local themePanel = vgui.Create("DPanel", sheet)
    themePanel:Dock(FILL)
    themePanel.Paint = nil
    local themeTab = sheet:AddSheet("Theme", themePanel)
    styleSheetTab(themeTab.Tab, "Theme")

    local themeList = themePanel:Add("DScrollPanel")
    themeList:Dock(LEFT)
    themeList:SetWide(ui(220))
    themeList:DockMargin(0, 0, ui(10), 0)
    makeScrollBarPretty(themeList)

    local themeRight = themePanel:Add("DPanel")
    themeRight:Dock(FILL)
    themeRight.Paint = nil

    local themePreview = themeRight:Add("DPanel")
    themePreview:Dock(TOP)
    themePreview:SetTall(ui(180))
    themePreview:DockMargin(0, 0, 0, ui(10))
    themePreview.Paint = function(self, w, h)
        local bg = stagedThemeColor("bg")
        local bg2 = stagedThemeColor("bg2")
        local bg3 = stagedThemeColor("bg3")
        local accent = stagedThemeColor("accent")
        local accentSoft = stagedThemeColor("accent_soft")
        local white = stagedThemeColor("white")
        local muted = stagedThemeColor("muted")
        local teamT = stagedThemeColor("team_t")

        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, accent, ui(2))

        surface.SetDrawColor(bg2)
        surface.DrawRect(ui(12), ui(12), w - ui(24), ui(44))
        drawOutlinedRect(ui(12), ui(12), w - ui(24), ui(44), accentSoft, 1)
        draw.SimpleText(GetHostName() or "ZBattle", FONT_HEADER, w * 0.5, ui(24), white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        surface.SetDrawColor(bg2)
        surface.DrawRect(ui(12), ui(68), w - ui(24), ui(88))
        surface.SetDrawColor(bg3)
        surface.DrawRect(ui(12), ui(112), w - ui(24), ui(44))
        surface.SetDrawColor(teamT)
        surface.DrawRect(ui(12), ui(68), ui(6), ui(88))
        drawOutlinedRect(ui(12), ui(68), w - ui(24), ui(88), accentSoft, 1)

        draw.SimpleText("Sample Player", FONT_MED, ui(32), ui(78), white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Admin", FONT_SMALL, ui(32), ui(100), muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Karma", FONT_SMALL, w - ui(170), ui(78), muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("100", FONT_MED, w - ui(170), ui(100), white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local themeMixer = themeRight:Add("DColorMixer")
    themeMixer:Dock(FILL)
    themeMixer:SetPalette(true)
    themeMixer:SetAlphaBar(true)
    themeMixer:SetWangs(true)

    local selectedThemeKey = THEME_KEYS[1]
    local selectedThemeButtons = {}

    local function syncThemeMixer()
        themeMixer:SetColor(stagedThemeColor(selectedThemeKey))
    end

    local function refreshThemeButtons()
        for key, button in pairs(selectedThemeButtons) do
            if IsValid(button) then
                button:InvalidateLayout(true)
            end
        end
        themePreview:InvalidateLayout(true)
    end

    for _, key in ipairs(THEME_KEYS) do
        local button = themeList:Add("DButton")
        selectedThemeButtons[key] = button
        button:Dock(TOP)
        button:SetTall(ui(34))
        button:DockMargin(0, 0, 0, ui(6))
        button:SetText("")
        button.Paint = function(self, w, h)
            local colorValue = stagedThemeColor(key)
            surface.SetDrawColor(25, 25, 25, 220)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, key == selectedThemeKey and stagedThemeColor("accent") or stagedThemeColor("accent_soft"), 1)
            surface.SetDrawColor(colorValue)
            surface.DrawRect(ui(8), ui(8), ui(18), h - ui(16))
            draw.SimpleText(THEME_LABELS[key] or key, FONT_SMALL, ui(34), h * 0.5, stagedThemeColor("white"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        button.DoClick = function()
            selectedThemeKey = key
            syncThemeMixer()
            refreshThemeButtons()
        end
    end

    themeMixer.ValueChanged = function(_, value)
        if not selectedThemeKey then return end

        staged.theme[selectedThemeKey] = {
            r = math.floor(value.r or 255),
            g = math.floor(value.g or 255),
            b = math.floor(value.b or 255),
            a = math.floor(value.a or 255)
        }

        refreshThemeButtons()
    end

    syncThemeMixer()
end

local function OpenZBScoreboard()
    rebuildFonts()

    if IsValid(scoreBoardMenu) then
        scoreBoardMenu:Remove()
        scoreBoardMenu = nil
    end

    local frameClass = vgui.GetControlTable("ZFrame") and "ZFrame" or "DFrame"
    scoreBoardMenu = vgui.Create(frameClass)

    local sizeX = math.min(ui(sbInt("frame_width", 1600)), ScrW() * 0.9)
    local sizeY = math.min(ui(sbInt("frame_height", 920)), ScrH() * 0.9)

    scoreBoardMenu:SetSize(sizeX, sizeY)
    scoreBoardMenu:Center()
    scoreBoardMenu:MakePopup()
    scoreBoardMenu:SetKeyboardInputEnabled(false)

    if scoreBoardMenu.ShowCloseButton then
        scoreBoardMenu:ShowCloseButton(false)
    end
    if scoreBoardMenu.SetTitle then
        scoreBoardMenu:SetTitle("")
    end

    scoreBoardMenu.Paint = function(self, w, h)
        blurPanel(self, 100)
        surface.SetDrawColor(COL_BG)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, COL_RED, ui(2))
    end

    buildTopHeader(scoreBoardMenu, sizeX)

    local outerPad = ui(12)
    local topOffset = ui(100)
    local bottomBar = ui(46)
    local sidebarGap = ui(10)

    local sidebarFrac = sbFloat("sidebar_width_frac", 0.24)
    local sidebarMin = sbInt("sidebar_width_min", 300)
    local sidebarMax = sbInt("sidebar_width_max", 420)

    local sidebarW = math.Clamp(math.floor(sizeX * sidebarFrac), ui(sidebarMin), ui(sidebarMax))
    local leftX, leftY = outerPad, topOffset
    local leftW = sizeX - sidebarW - outerPad * 2 - sidebarGap
    local leftH = sizeY - topOffset - ui(54)

    local playerPanel = vgui.Create("DPanel", scoreBoardMenu)
    playerPanel:SetPos(leftX, leftY)
    playerPanel:SetSize(leftW, leftH)
    playerPanel.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 155)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, COL_RED_SOFT, ui(2))
        draw.SimpleText("PLAYERS", FONT_HEADER, ui(16), ui(10), COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Right click for options", FONT_SMALL, ui(100), ui(13), COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local playersScroll = vgui.Create("DScrollPanel", playerPanel)
    playersScroll:SetPos(0, ui(42))
    playersScroll:SetSize(leftW, leftH - ui(82))
    playersScroll.Paint = function() end
    makeScrollBarPretty(playersScroll)

    refreshScoreboardLists(playersScroll)

    local sidebar = buildSidebar(scoreBoardMenu, leftX + leftW + sidebarGap, leftY, sidebarW, leftH)

    if sbBool("show_bottom_mute_buttons", true) then
        local muteAll = vgui.Create("DButton", scoreBoardMenu)
        muteAll:SetPos(outerPad, sizeY - bottomBar)
        muteAll:SetSize(ui(160), ui(30))
        muteAll:SetText("")
        muteAll.DoClick = function()
            hg.muteall = not hg.muteall
            for _, ply in ipairs(player.GetAll()) do
                applyVoiceState(ply)
            end
        end
        muteAll.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 160)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, hg.muteall and Color(120,120,120) or COL_RED, ui(2))
            draw.SimpleText(hg.muteall and "Unmute All" or "Mute All", FONT_SMALL, w / 2, h / 2, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local muteSpecs = vgui.Create("DButton", scoreBoardMenu)
        muteSpecs:SetPos(outerPad + ui(170), sizeY - bottomBar)
        muteSpecs:SetSize(ui(180), ui(30))
        muteSpecs:SetText("")
        muteSpecs.DoClick = function()
            hg.mutespect = not hg.mutespect
            for _, ply in ipairs(player.GetAll()) do
                applyVoiceState(ply)
            end
        end
        muteSpecs.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 160)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, hg.mutespect and Color(120,120,120) or COL_RED, ui(2))
            draw.SimpleText(hg.mutespect and "Unmute Spectators" or "Mute Spectators", FONT_SMALL, w / 2, h / 2, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local closeBtnW = ui(110)
    local settingsBtnW = ui(110)
    local teamBtnW = ui(138)
    local buttonGap = ui(12)
    local rightX = sizeX - outerPad

    local closeBtnX = rightX - closeBtnW

    local closeBtn = vgui.Create("DButton", scoreBoardMenu)
    closeBtn:SetPos(closeBtnX, sizeY - bottomBar)
    closeBtn:SetSize(closeBtnW, ui(30))
    closeBtn:SetText("")
    closeBtn.DoClick = function()
        if IsValid(scoreBoardMenu) then
            scoreBoardMenu:Remove()
            scoreBoardMenu = nil
        end
    end
    closeBtn.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 160)
        surface.DrawRect(0, 0, w, h)
        drawOutlinedRect(0, 0, w, h, COL_RED, ui(2))
        draw.SimpleText("Close", FONT_SMALL, w / 2, h / 2, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local nextRight = closeBtnX - buttonGap

    if IsValid(LocalPlayer()) and LocalPlayer():IsAdmin() then
        local settingsBtn = vgui.Create("DButton", scoreBoardMenu)
        settingsBtn:SetPos(nextRight - settingsBtnW, sizeY - bottomBar)
        settingsBtn:SetSize(settingsBtnW, ui(30))
        settingsBtn:SetText("")
        settingsBtn.DoClick = function()
            openScoreboardSettingsMenu()
        end
        settingsBtn.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 160)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, COL_RED, ui(2))
            draw.SimpleText("ADMIN", FONT_SMALL, w / 2, h / 2, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        nextRight = nextRight - settingsBtnW - buttonGap
    end

    if sbBool("show_team_button", true) then
        local teamButton = vgui.Create("DButton", scoreBoardMenu)
        teamButton:SetPos(nextRight - teamBtnW, sizeY - bottomBar)
        teamButton:SetSize(teamBtnW, ui(30))
        teamButton:SetText("")
        teamButton.DoClick = function()
            if net and net.Start and TEAM_SPECTATOR then
                net.Start("ZB_SpecMode")
                    net.WriteBool(LocalPlayer():Team() ~= TEAM_SPECTATOR)
                net.SendToServer()
            end

            if IsValid(scoreBoardMenu) then
                scoreBoardMenu:Remove()
                scoreBoardMenu = nil
            end
        end
        teamButton.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 160)
            surface.DrawRect(0, 0, w, h)
            drawOutlinedRect(0, 0, w, h, COL_RED, ui(2))
            local txt = (TEAM_SPECTATOR and LocalPlayer():Team() == TEAM_SPECTATOR) and "Join" or "Spectate"
            draw.SimpleText(txt, FONT_SMALL, w / 2, h / 2, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    scoreBoardMenu.Think = function()
        if not IsValid(scoreBoardMenu) then return end

        if not scoreBoardMenu.NextRefresh or scoreBoardMenu.NextRefresh < CurTime() then
            refreshScoreboardLists(playersScroll)

            if IsValid(sidebar) then
                sidebar:Remove()
                sidebar = buildSidebar(scoreBoardMenu, leftX + leftW + sidebarGap, leftY, sidebarW, leftH)
            end

            scoreBoardMenu.NextRefresh = CurTime() + sbFloat("refresh_interval", 1)
        end
    end
end

local function CloseZBScoreboard()
    if IsValid(scoreBoardMenu) then
        scoreBoardMenu:Remove()
        scoreBoardMenu = nil
    end
end

net.Receive("PATSB_SendSettings", function()
    local raw = net.ReadString()
    local data = util.JSONToTable(raw)
    if not istable(data) then return end

    PATSB.Settings = table.Copy(PATSB.Defaults)
    for k, v in pairs(data) do
        PATSB.Settings[k] = v
    end
    ensureThemeTable(PATSB.Settings)
    applyThemeColors()

    rebuildFonts(true)

    if IsValid(scoreBoardMenu) then
        timer.Simple(0, function()
            if not IsValid(scoreBoardMenu) then return end
            OpenZBScoreboard()
        end)
    end
end)

hook.Add("InitPostEntity", "PATSB_RequestInitialSettings", function()
    net.Start("PATSB_RequestSettings")
    net.SendToServer()
end)

hook.Add("ScoreboardShow", "PATSB_Show", function()
    OpenZBScoreboard()
    return true
end)

hook.Add("ScoreboardHide", "PATSB_Hide", function()
    CloseZBScoreboard()
    return true
end)
