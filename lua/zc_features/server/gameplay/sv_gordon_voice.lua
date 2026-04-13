if CLIENT then return end

local HELMET_COMMANDS = {
    ["!helmet"] = "toggle",
    ["/helmet"] = "toggle",
    ["!helmetoff"] = "off",
    ["/helmetoff"] = "off",
    ["!helmeton"] = "on",
    ["/helmeton"] = "on",
    ["!hevhelmet"] = "toggle",
    ["/hevhelmet"] = "toggle",
}

local HEV_HELMET_CLASS = "gordon_helmet"
local GORDON_TALK_CVAR = CreateConVar(
    "zc_gordontalk",
    "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
    "Enable Gordon helmet-based talk system (1 = enabled, 0 = vanilla mute)",
    0,
    1
)

local gordonTalkEnabled = GORDON_TALK_CVAR:GetBool()

local function IsGordon(ply)
    return IsValid(ply) and ply:IsPlayer() and ply.PlayerClassName == "Gordon"
end

local function HasHEVSuit(ply)
    return IsGordon(ply) and ply:GetNetVar("HEVSuit") == true
end

local function HasHelmetOn(ply)
    return HasHEVSuit(ply) and istable(ply.armors) and ply.armors["head"] == HEV_HELMET_CLASS
end

local function RemoveBaseMuteHooks()
    hook.Remove("CanListenOthers", "GordonWeDontHearYou")
    hook.Remove("HG_PlayerSay", "GordonWeDontSeeYouChat")
end

local function AddBaseMuteHooks()
    hook.Add("CanListenOthers", "GordonWeDontHearYou", function(talker)
        if IsValid(talker) and talker:Alive() and talker.PlayerClassName == "Gordon" then
            return false, false
        end
    end)

    hook.Add("HG_PlayerSay", "GordonWeDontSeeYouChat", function(ply, txtTbl)
        if IsValid(ply) and ply:Alive() and ply.PlayerClassName == "Gordon" then
            txtTbl[1] = ""
        end
    end)
end

local function IsGordonTalkEnabled()
    return gordonTalkEnabled == true
end

local function NotifyPlayer(ply, key, message, cooldown)
    if not IsValid(ply) then return end

    local cd = tonumber(cooldown) or 0
    if cd > 0 then
        ply.ZCGordonVoiceMsgCD = ply.ZCGordonVoiceMsgCD or {}
        local nextAllowed = ply.ZCGordonVoiceMsgCD[key] or 0
        if CurTime() < nextAllowed then return end
        ply.ZCGordonVoiceMsgCD[key] = CurTime() + cd
    end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        ply:ChatPrint(message)
    end)
end

local function SyncHelmetVoiceEffect(ply)
    if not IsGordonTalkEnabled() then
        if IsValid(ply) then
            ply.ZCGordonVoiceMuffled = nil
            ply:SetNWBool("ZC_GordonHelmetMuffled", false)
            if eightbit and eightbit.EnableEffect and ply.UserID then
                eightbit.EnableEffect(ply:UserID(), 0)
            end
        end
        return
    end

    if not IsGordon(ply) then
        if IsValid(ply) then
            ply.ZCGordonVoiceMuffled = nil
            ply:SetNWBool("ZC_GordonHelmetMuffled", false)
        end
        return
    end

    local shouldMuffle = HasHelmetOn(ply)
    if ply.ZCGordonVoiceMuffled == shouldMuffle then return end

    ply.ZCGordonVoiceMuffled = shouldMuffle
    ply:SetNWBool("ZC_GordonHelmetMuffled", shouldMuffle)

    if eightbit and eightbit.EnableEffect and ply.UserID then
        local maskEffect = eightbit.EFF_MASKVOICE or eightbit.EFF_PROOT or 0
        eightbit.EnableEffect(ply:UserID(), shouldMuffle and maskEffect or 0)
    end
end

local function ApplyTalkMode()
    gordonTalkEnabled = GORDON_TALK_CVAR:GetBool()
    SetGlobalBool("ZC_GordonTalkEnabled", gordonTalkEnabled)

    if gordonTalkEnabled then
        RemoveBaseMuteHooks()
    else
        AddBaseMuteHooks()
    end

    for _, ply in ipairs(player.GetHumans()) do
        if IsValid(ply) then
            SyncHelmetVoiceEffect(ply)
        end
    end
end

local function SetHelmetState(ply, enabled)
    if not HasHEVSuit(ply) then
        return false, "[HEV] Only Gordon in the HEV suit can toggle the helmet."
    end

    ply.armors = ply.armors or {}
    ply.armors_health = ply.armors_health or {}

    if enabled then
        if HasHelmetOn(ply) then
            return false, "[HEV] Helmet is already engaged. Voice is filtered and text remains degraded."
        end

        if hg and hg.AddArmor then
            hg.AddArmor(ply, HEV_HELMET_CLASS)
        end

        if ply.armors["head"] ~= HEV_HELMET_CLASS then
            ply.armors["head"] = HEV_HELMET_CLASS
            if ply.SyncArmor then
                ply:SyncArmor()
            end
        end

        SyncHelmetVoiceEffect(ply)
        return true, "[HEV] Helmet engaged. Head protection restored. Voice is muffled and text will cut out again."
    end

    if not HasHelmetOn(ply) then
        return false, "[HEV] Helmet is already off. You can speak and type normally."
    end

    ply.armors["head"] = nil
    ply.armors_health[HEV_HELMET_CLASS] = nil
    ply:SetNWString("ArmorMaterials" .. HEV_HELMET_CLASS, nil)
    ply:SetNWInt("ArmorSkins" .. HEV_HELMET_CLASS, nil)

    if ply.SyncArmor then
        ply:SyncArmor()
    end

    SyncHelmetVoiceEffect(ply)
    return true, "[HEV] Helmet disengaged. Head protection removed. You can now speak and type normally."
end

local function ApplyHelmetTextDropout(text)
    text = utf8.force(tostring(text or ""))
    if text == "" then return text end

    local chars = {}
    local visibleCount = 0
    local dropoutRun = 0

    for _, code in utf8.codes(text) do
        local char = utf8.char(code)

        if string.match(char, "%s") then
            dropoutRun = 0
            chars[#chars + 1] = char
        elseif dropoutRun > 0 then
            if dropoutRun == 2 and math.random(2) == 1 then
                chars[#chars + 1] = "..."
            end
            dropoutRun = dropoutRun - 1
        else
            local roll = math.random(8)

            if roll == 1 then
                chars[#chars + 1] = "-"
            elseif roll == 2 then
                chars[#chars + 1] = char
                chars[#chars + 1] = "-"
            elseif roll == 3 then
                dropoutRun = math.random(1, 3)
                chars[#chars + 1] = "..."
            else
                chars[#chars + 1] = char
                visibleCount = visibleCount + 1
            end
        end
    end

    local out = string.Trim(table.concat(chars))
    if visibleCount <= 0 or out == "" then
        return "..."
    end

    return out
end

local function HandleHelmetCommand(ply, mode)
    if not IsGordonTalkEnabled() then
        NotifyPlayer(ply, "talk_disabled", "[HEV] Gordon talk system is disabled. Use !gordontalk 1 to enable it.", 2)
        return true
    end

    if not IsGordon(ply) then
        NotifyPlayer(ply, "helmet_not_gordon", "[HEV] Only Gordon can use helmet voice controls.", 2)
        return true
    end

    local enable = mode == "on" or (mode == "toggle" and not HasHelmetOn(ply))
    local _, message = SetHelmetState(ply, enable)
    NotifyPlayer(ply, "helmet_state", message, 0.25)
    return true
end

hook.Add("HG_PlayerSay", "ZC_GordonVoice_Command", function(ply, txtTbl, text)
    local raw = string.Trim(tostring(text or ""))
    local cmd = string.lower(raw)
    local args = string.Explode(" ", cmd, false)

    if args[1] == "!gordontalk" or args[1] == "/gordontalk" then
        txtTbl[1] = ""

        if not IsValid(ply) or not ply:IsSuperAdmin() then
            if IsValid(ply) then
                NotifyPlayer(ply, "talk_superadmin_only", "[HEV] Only superadmins can change !gordontalk.", 2)
            end
            return ""
        end

        local value = args[2]
        if value == nil or value == "" then
            NotifyPlayer(ply, "talk_status", "[HEV] Current !gordontalk: " .. (IsGordonTalkEnabled() and "1" or "0"), 1)
            NotifyPlayer(ply, "talk_usage_chat", "[HEV] Chat usage: !gordontalk 1 or !gordontalk 0", 1)
            NotifyPlayer(ply, "talk_usage_console", "[HEV] Console usage: zc_gordontalk 1 or zc_gordontalk 0", 1)
            return ""
        end

        if value ~= "0" and value ~= "1" then
            NotifyPlayer(ply, "talk_invalid_usage", "[HEV] Usage: !gordontalk 1 or !gordontalk 0", 1)
            NotifyPlayer(ply, "talk_invalid_console", "[HEV] Console usage: zc_gordontalk 1 or zc_gordontalk 0", 1)
            NotifyPlayer(ply, "talk_invalid_current", "[HEV] Current: " .. (IsGordonTalkEnabled() and "1" or "0"), 1)
            return ""
        end

        local newEnabled = value == "1"
        if IsGordonTalkEnabled() == newEnabled then
            NotifyPlayer(ply, "talk_already", "[HEV] Gordontalk is already " .. value .. ".", 1)
            return ""
        end

        GORDON_TALK_CVAR:SetBool(newEnabled)
        ApplyTalkMode()
        PrintMessage(HUD_PRINTTALK, "[HEV] " .. ply:Nick() .. " set !gordontalk to " .. value .. ".")
        return ""
    end

    local mode = HELMET_COMMANDS[cmd]
    if not mode then return end

    txtTbl[1] = ""

    if HandleHelmetCommand(ply, mode) then
        return ""
    end
end)

hook.Add("HG_PlayerSay", "ZC_GordonVoice_TextMuffle", function(ply, txtTbl, text)
    if not IsGordonTalkEnabled() then return end
    if not IsGordon(ply) or not ply:Alive() or not HasHelmetOn(ply) then return end

    local current = tostring(txtTbl[1] or text or "")
    if current == "" then return end

    local firstNonSpace = string.match(current, "^%s*(.)")
    if firstNonSpace == "!" or firstNonSpace == "/" then return end

    txtTbl[1] = ApplyHelmetTextDropout(current)
end)

hook.Add("Player Spawn", "ZC_GordonVoice_SpawnSync", function(ply)
    if not IsGordon(ply) then return end

    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        SyncHelmetVoiceEffect(ply)
    end)
end)

hook.Add("PlayerDisconnected", "ZC_GordonVoice_ClearState", function(ply)
    ply.ZCGordonVoiceMuffled = nil
    ply.ZCGordonVoiceMsgCD = nil
end)

timer.Create("ZC_GordonVoice_Sync", 1, 0, function()
    if IsGordonTalkEnabled() then
        RemoveBaseMuteHooks()
    else
        AddBaseMuteHooks()
    end

    for _, ply in ipairs(player.GetHumans()) do
        if IsValid(ply) then
            SyncHelmetVoiceEffect(ply)
        end
    end
end)

hook.Add("InitPostEntity", "ZC_GordonVoice_Init", function()
    ApplyTalkMode()
end)

cvars.AddChangeCallback("zc_gordontalk", function()
    ApplyTalkMode()
end, "ZC_GordonVoice_TalkToggle")
