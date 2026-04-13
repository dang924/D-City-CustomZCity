-- sv_currentround_nil_guard.lua
-- Server-side safety wrapper: mirrors cl_currentround_nil_guard.lua.
-- Many server modules use  `if not CurrentRound or CurrentRound().name ~= "x"`
-- which correctly guards against CurrentRound being nil/false, but CRASHES if
-- CurrentRound() returns nil (which ZCity can do during map/round transitions).
-- This file replaces the global CurrentRound with a nil-safe version so all
-- existing code is protected without touching any individual file.

if CLIENT then return end
if _G.ZC_SV_CurrentRoundNilGuarded then return end
if not isfunction(_G.CurrentRound) then
    -- ZCity not loaded yet; retry once Homigrad is running.
    hook.Add("HomigradRun", "ZC_SV_CurrentRoundNilGuard_Init", function()
        hook.Remove("HomigradRun", "ZC_SV_CurrentRoundNilGuard_Init")
        if isfunction(_G.CurrentRound) and not _G.ZC_SV_CurrentRoundNilGuarded then
            include("autorun/server/sv_currentround_nil_guard.lua")
        end
    end)
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
        return BuildFallbackRound(roundName)
    end

    mode.name = mode.name or roundName or (zb and zb.CROUND) or "hmcd"
    return mode, roundName
end

_G.ZC_SV_CurrentRoundNilGuarded = true
print("[DCityPatch] Server CurrentRound nil guard loaded.")
