if SERVER then
    util.AddNetworkString("ZC_FXTone_OpenMenu")
    util.AddNetworkString("ZC_FXTone_RequestState")
    util.AddNetworkString("ZC_FXTone_State")
    util.AddNetworkString("ZC_FXTone_Apply")

    local DEFAULTS = {
        screenshake = 0.55,
        tinnitusServer = 0.45,
        weaponShock = 0.55,
    }

    local function clamp01(v, fallback)
        v = tonumber(v)
        if not v then return fallback end
        return math.Clamp(v, 0, 1)
    end

    local function sendState(ply)
        if not IsValid(ply) then return end

        local cvShake = GetConVar("zc_fx_screenshake_scale")
        local cvTin = GetConVar("zc_fx_tinnitus_scale")
        local cvShock = GetConVar("zc_fx_weapon_shock_scale")

        net.Start("ZC_FXTone_State")
            net.WriteFloat(clamp01(cvShake and cvShake:GetFloat() or nil, DEFAULTS.screenshake))
            net.WriteFloat(clamp01(cvTin and cvTin:GetFloat() or nil, DEFAULTS.tinnitusServer))
            net.WriteFloat(clamp01(cvShock and cvShock:GetFloat() or nil, DEFAULTS.weaponShock))
        net.Send(ply)
    end

    local function isAdmin(ply)
        return IsValid(ply) and ply:IsPlayer() and ply:IsAdmin()
    end

    hook.Add("HG_PlayerSay", "ZC_FXTone_OpenChat", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text or ""))
        if cmd ~= "!fxtone" and cmd ~= "/fxtone" and cmd ~= "!shellshock" and cmd ~= "/shellshock" then return end
        txtTbl[1] = ""

        if not isAdmin(ply) then
            ply:ChatPrint("[FX Tone] Admins only.")
            return ""
        end

        net.Start("ZC_FXTone_OpenMenu")
        net.Send(ply)

        timer.Simple(0, function()
            if not IsValid(ply) then return end
            sendState(ply)
        end)

        return ""
    end)

    net.Receive("ZC_FXTone_RequestState", function(_, ply)
        if not isAdmin(ply) then return end
        sendState(ply)
    end)

    net.Receive("ZC_FXTone_Apply", function(_, ply)
        if not isAdmin(ply) then return end

        local shake = clamp01(net.ReadFloat(), DEFAULTS.screenshake)
        local tinServer = clamp01(net.ReadFloat(), DEFAULTS.tinnitusServer)
        local weaponShock = clamp01(net.ReadFloat(), DEFAULTS.weaponShock)

        RunConsoleCommand("zc_fx_screenshake_scale", tostring(shake))
        RunConsoleCommand("zc_fx_tinnitus_scale", tostring(tinServer))
        RunConsoleCommand("zc_fx_weapon_shock_scale", tostring(weaponShock))

        sendState(ply)
    end)

    return
end

local frameRef = nil
local localDefaults = {
    viewPunch = 0.60,
    tinnitusClient = 0.45,
    smoke = 0.50,
}

local function clamp01(v, fallback)
    v = tonumber(v)
    if not v then return fallback end
    return math.Clamp(v, 0, 1)
end

local function getClientScale(name, fallback)
    local cv = GetConVar(name)
    if not cv then return fallback end
    return clamp01(cv:GetFloat(), fallback)
end

local function openMenu()
    if IsValid(frameRef) then frameRef:Remove() end

    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:IsAdmin() then
        chat.AddText(Color(255, 80, 80), "[FX Tone] Admins only.")
        return
    end

    local w, h = 520, 360
    local frame = vgui.Create("DFrame")
    frameRef = frame
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("ZCity FX Tone (Live)")
    frame:MakePopup()

    local y = 36

    local function makeSlider(label, min, max, decimals)
        local s = vgui.Create("DNumSlider", frame)
        s:SetPos(12, y)
        s:SetSize(w - 24, 52)
        s:SetText(label)
        s:SetMin(min)
        s:SetMax(max)
        s:SetDecimals(decimals or 2)
        y = y + 56
        return s
    end

    local sShake = makeSlider("Screen Shake Scale (server)", 0, 1, 2)
    local sView = makeSlider("ViewPunch Scale (client)", 0, 1, 2)
    local sTinServer = makeSlider("Tinnitus Scale (server)", 0, 1, 2)
    local sTinClient = makeSlider("Tinnitus Scale (client)", 0, 1, 2)
    local sWeaponShock = makeSlider("Weapon Shock Scale (server)", 0, 1, 2)
    local sSmoke = makeSlider("Particle Smoke Scale (client)", 0, 1, 2)

    local applyBtn = vgui.Create("DButton", frame)
    applyBtn:SetPos(12, h - 38)
    applyBtn:SetSize(120, 26)
    applyBtn:SetText("Apply")

    local resetBtn = vgui.Create("DButton", frame)
    resetBtn:SetPos(138, h - 38)
    resetBtn:SetSize(120, 26)
    resetBtn:SetText("Reset Defaults")

    local liveToggle = vgui.Create("DCheckBoxLabel", frame)
    liveToggle:SetPos(270, h - 34)
    liveToggle:SetText("Live apply")
    liveToggle:SetValue(1)
    liveToggle:SizeToContents()

    local status = vgui.Create("DLabel", frame)
    status:SetPos(360, h - 34)
    status:SetSize(150, 20)
    status:SetText("")

    local function applyClientLocal()
        RunConsoleCommand("zc_fx_viewpunch_scale", tostring(clamp01(sView:GetValue(), localDefaults.viewPunch)))
        RunConsoleCommand("zc_fx_tinnitus_scale", tostring(clamp01(sTinClient:GetValue(), localDefaults.tinnitusClient)))
        RunConsoleCommand("zc_fx_smoke_scale", tostring(clamp01(sSmoke:GetValue(), localDefaults.smoke)))
    end

    local function applyServer()
        net.Start("ZC_FXTone_Apply")
            net.WriteFloat(clamp01(sShake:GetValue(), 0.55))
            net.WriteFloat(clamp01(sTinServer:GetValue(), 0.45))
            net.WriteFloat(clamp01(sWeaponShock:GetValue(), 0.55))
        net.SendToServer()
    end

    local function applyAll()
        applyClientLocal()
        applyServer()
        status:SetText("Applied")
    end

    applyBtn.DoClick = applyAll

    resetBtn.DoClick = function()
        sShake:SetValue(0.55)
        sView:SetValue(0.60)
        sTinServer:SetValue(0.45)
        sTinClient:SetValue(0.45)
        sWeaponShock:SetValue(0.55)
        sSmoke:SetValue(0.50)
        applyAll()
    end

    local function setupLive(slider)
        function slider:OnValueChanged()
            if liveToggle:GetChecked() then
                applyAll()
            end
        end
    end

    setupLive(sShake)
    setupLive(sView)
    setupLive(sTinServer)
    setupLive(sTinClient)
    setupLive(sWeaponShock)
    setupLive(sSmoke)

    -- Set client-side values immediately
    sView:SetValue(getClientScale("zc_fx_viewpunch_scale", localDefaults.viewPunch))
    sTinClient:SetValue(getClientScale("zc_fx_tinnitus_scale", localDefaults.tinnitusClient))
    sSmoke:SetValue(getClientScale("zc_fx_smoke_scale", localDefaults.smoke))

    net.Start("ZC_FXTone_RequestState")
    net.SendToServer()
end

net.Receive("ZC_FXTone_OpenMenu", function()
    openMenu()
end)

net.Receive("ZC_FXTone_State", function()
    local shake = clamp01(net.ReadFloat(), 0.55)
    local tinServer = clamp01(net.ReadFloat(), 0.45)
    local weaponShock = clamp01(net.ReadFloat(), 0.55)

    if not IsValid(frameRef) then return end

    for _, child in ipairs(frameRef:GetChildren()) do
        if child:GetClassName() ~= "DNumSlider" then continue end
        local txt = string.lower(child:GetText() or "")
        if string.find(txt, "screen shake", 1, true) then child:SetValue(shake) end
        if string.find(txt, "tinnitus scale (server)", 1, true) then child:SetValue(tinServer) end
        if string.find(txt, "weapon shock", 1, true) then child:SetValue(weaponShock) end
    end
end)

concommand.Add("zc_fxtone_menu", function()
    openMenu()
end)
