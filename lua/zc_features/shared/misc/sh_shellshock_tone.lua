if CLIENT then
    CreateClientConVar("zc_fx_viewpunch_scale", "0.60", true, false, "Scale local viewpunch intensity", 0, 1)
    CreateClientConVar("zc_fx_tinnitus_scale", "0.45", true, false, "Scale tinnitus duration/intensity", 0, 1)
    CreateClientConVar("zc_fx_smoke_scale", "0.50", true, false, "Scale particle smoke effects from explosions", 0, 1)
end

if SERVER then
    CreateConVar("zc_fx_screenshake_scale", "0.55", FCVAR_ARCHIVE, "Scale util.ScreenShake amplitude/frequency/radius", 0, 1)
    CreateConVar("zc_fx_tinnitus_scale", "0.45", FCVAR_ARCHIVE, "Scale tinnitus duration sent to clients", 0, 1)
    CreateConVar("zc_fx_weapon_shock_scale", "0.55", FCVAR_ARCHIVE, "Scale weapon ShockMultiplier values", 0, 1)
end

local function clampScale(value, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.Clamp(value, 0, 1)
end

if CLIENT then
    local function installClientSmokeWrapper()
        if not ParticleEffect then return false end
        if _ZC_ParticleEffectWrapped then return true end

        local oldParticleEffect = ParticleEffect
        ParticleEffect = function(strName, vOrigin, vAngles, eEntity, nAttachType, nAttachment)
            local s = clampScale(GetConVar("zc_fx_smoke_scale"):GetFloat(), 0.50)
            if s >= 1 or math.Rand(0, 1) <= s then
                return oldParticleEffect(strName, vOrigin, vAngles, eEntity, nAttachType, nAttachment)
            end
            return nil
        end
        _ZC_ParticleEffectWrapped = true
        return true
    end

    local retries = 0
    hook.Add("InitPostEntity", "ZC_InstallSmokeWrapper", function()
        if installClientSmokeWrapper() then
            hook.Remove("InitPostEntity", "ZC_InstallSmokeWrapper")
            hook.Remove("Think", "ZC_RetrySmokeWrapper")
            return
        end
        retries = retries + 1
        if retries > 20 then
            hook.Remove("InitPostEntity", "ZC_InstallSmokeWrapper")
            hook.Remove("Think", "ZC_RetrySmokeWrapper")
        end
    end)

    hook.Add("Think", "ZC_RetrySmokeWrapper", function()
        retries = retries + 1
        if retries > 20 then return end
        installClientSmokeWrapper()
    end)
end

if SERVER then
    local function getCvarScale(name, fallback)
        local cv = GetConVar(name)
        if not cv then return fallback end
        return clampScale(cv:GetFloat(), fallback)
    end

    local function installServerScreenShakeWrapper()
        if not util or not util.ScreenShake then return false end
        if util._ZC_ShellShockWrapped then return true end

        local oldScreenShake = util.ScreenShake
        util.ScreenShake = function(vPos, nAmplitude, nFrequency, nDuration, nRadius, bAirshake, crfFilter)
            local s = getCvarScale("zc_fx_screenshake_scale", 0.55)
            return oldScreenShake(
                vPos,
                (tonumber(nAmplitude) or 0) * s,
                (tonumber(nFrequency) or 0) * s,
                (tonumber(nDuration) or 0) * math.max(0.35, s),
                (tonumber(nRadius) or 0) * math.max(0.5, s),
                bAirshake,
                crfFilter
            )
        end
        util._ZC_ShellShockWrapped = true
        return true
    end

    local function installServerTinnitusWrapper()
        local plymeta = FindMetaTable("Player")
        if not plymeta or not plymeta.AddTinnitus then return false end
        if plymeta._ZC_AddTinnitusWrapped then return true end

        local oldAddTinnitus = plymeta.AddTinnitus
        plymeta.AddTinnitus = function(self, time, needSound)
            local s = getCvarScale("zc_fx_tinnitus_scale", 0.45)
            local t = (tonumber(time) or 0) * s
            return oldAddTinnitus(self, t, needSound)
        end

        plymeta._ZC_AddTinnitusWrapped = true
        return true
    end

    local function tuneWeaponShockMultipliers()
        local scale = getCvarScale("zc_fx_weapon_shock_scale", 0.55)
        local any = false

        for _, wep in ipairs(weapons.GetList() or {}) do
            if not istable(wep) then continue end
            if type(wep.ShockMultiplier) ~= "number" then continue end

            if wep._ZC_BaseShockMultiplier == nil then
                wep._ZC_BaseShockMultiplier = wep.ShockMultiplier
            end

            wep.ShockMultiplier = wep._ZC_BaseShockMultiplier * scale
            any = true
        end

        return any
    end

    local function installServerTonePatch()
        local a = installServerScreenShakeWrapper()
        local b = installServerTinnitusWrapper()
        local c = tuneWeaponShockMultipliers()
        return a and b and c
    end

    hook.Add("InitPostEntity", "ZC_ShellShockTone_ServerInit", function()
        if installServerTonePatch() then return end

        timer.Create("ZC_ShellShockTone_ServerRetry", 1, 20, function()
            if installServerTonePatch() then
                timer.Remove("ZC_ShellShockTone_ServerRetry")
            end
        end)
    end)

    hook.Add("OnReloaded", "ZC_ShellShockTone_ServerReload", function()
        timer.Simple(0, installServerTonePatch)
    end)

    cvars.AddChangeCallback("zc_fx_weapon_shock_scale", function()
        timer.Simple(0, tuneWeaponShockMultipliers)
    end, "ZC_ShellShockTone_ShockScale")
end

if CLIENT then
    local function getClientScale(name, fallback)
        local cv = GetConVar(name)
        if not cv then return fallback end
        return clampScale(cv:GetFloat(), fallback)
    end

    local function scaleAngle(ang, scale)
        if not ang then return ang end
        return Angle(ang.p * scale, ang.y * scale, ang.r * scale)
    end

    local function wrapViewPunchFunction(globalName)
        local fn = _G[globalName]
        if type(fn) ~= "function" then return false end
        if _G["_ZC_Wrapped_" .. globalName] then return true end

        _G[globalName] = function(ang)
            local s = getClientScale("zc_fx_viewpunch_scale", 0.60)
            return fn(scaleAngle(ang, s))
        end

        _G["_ZC_Wrapped_" .. globalName] = true
        return true
    end

    local function installClientTinnitusWrapper()
        local plymeta = FindMetaTable("Player")
        if not plymeta or not plymeta.AddTinnitus then return false end
        if plymeta._ZC_AddTinnitusWrappedClient then return true end

        local oldAddTinnitus = plymeta.AddTinnitus
        plymeta.AddTinnitus = function(self, time, needSound)
            local s = getClientScale("zc_fx_tinnitus_scale", 0.45)
            local t = (tonumber(time) or 0) * s
            return oldAddTinnitus(self, t, needSound)
        end

        plymeta._ZC_AddTinnitusWrappedClient = true
        return true
    end

    local function installClientTonePatch()
        local ok = true
        ok = wrapViewPunchFunction("ViewPunch") and ok
        ok = wrapViewPunchFunction("ViewPunch2") and ok
        ok = wrapViewPunchFunction("ViewPunch3") and ok
        ok = wrapViewPunchFunction("ViewPunch4") and ok
        ok = wrapViewPunchFunction("Viewpunch") and ok
        ok = wrapViewPunchFunction("Viewpunch2") and ok
        ok = wrapViewPunchFunction("Viewpunch3") and ok
        ok = wrapViewPunchFunction("Viewpunch4") and ok
        ok = installClientTinnitusWrapper() and ok
        return ok
    end

    hook.Add("InitPostEntity", "ZC_ShellShockTone_ClientInit", function()
        if installClientTonePatch() then return end

        timer.Create("ZC_ShellShockTone_ClientRetry", 1, 20, function()
            if installClientTonePatch() then
                timer.Remove("ZC_ShellShockTone_ClientRetry")
            end
        end)
    end)

    hook.Add("OnReloaded", "ZC_ShellShockTone_ClientReload", function()
        timer.Simple(0, installClientTonePatch)
    end)
end
