-- cl_currentround_nil_guard.lua
-- Client-side safety wrapper: some base HUD/UI code assumes CurrentRound() is never nil.

if SERVER then return end
if _G.ZC_CurrentRoundNilGuarded then return end
if not isfunction(_G.CurrentRound) then
    if not _G.ZC_CurrentRoundNilGuardPending then
        _G.ZC_CurrentRoundNilGuardPending = true

        local function installWhenCurrentRoundLoads()
            if not isfunction(_G.CurrentRound) then return end

            hook.Remove("InitPostEntity", "ZC_CurrentRoundNilGuard_Init")
            timer.Remove("ZC_CurrentRoundNilGuard_Init")
            _G.ZC_CurrentRoundNilGuardPending = nil
            include("autorun/client/cl_currentround_nil_guard.lua")
        end

        hook.Add("InitPostEntity", "ZC_CurrentRoundNilGuard_Init", installWhenCurrentRoundLoads)
        timer.Create("ZC_CurrentRoundNilGuard_Init", 1, 0, installWhenCurrentRoundLoads)
    end

    return
end

local OriginalCurrentRound = _G.CurrentRound

local function BuildFallbackRound(roundName)
    local name = roundName or (zb and zb.CROUND) or "hmcd"

    if zb and zb.modes and zb.modes[name] then
        return zb.modes[name], name
    end

    if zb and zb.modes and zb.modes["hmcd"] then
        return zb.modes["hmcd"], name
    end

    return {
        name = name,
        PrintName = name,
        start_time = 5,
        end_time = 5,
        ROUND_TIME = 300,
    }, name
end

_G.CurrentRound = function(...)
    local ok, mode, roundName = pcall(OriginalCurrentRound, ...)
    if not ok then
        return BuildFallbackRound(nil)
    end

    if mode == nil then
        return BuildFallbackRound(roundName)
    end

    if not istable(mode) then
        local fallback, fallbackName = BuildFallbackRound(roundName)
        return fallback, fallbackName
    end

    mode.name = mode.name or roundName or (zb and zb.CROUND) or "hmcd"
    return mode, roundName
end

_G.ZC_CurrentRoundNilGuarded = true
print("[DCityPatch] Client CurrentRound nil guard loaded.")
