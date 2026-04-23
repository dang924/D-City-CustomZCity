-- Ensure DCity defaults to coop at startup unless a map-specific default or an
-- explicit alternate mode was requested (e.g. !setevent / !setdod / F6 mode selection).

if not SERVER then return end

local RETRIES = 20
local DELAY = 1

local function lower(v)
    return string.lower(tostring(v or ""))
end

local function getMapDefaultMode()
    local mapName = lower(game.GetMap())

    if string.StartWith(mapName, "dod_") then
        return nil, "DoD-prefixed map"
    end

    if string.StartWith(mapName, "hdn_") or string.StartWith(mapName, "ovr_") then
        return "hidden", "Hidden-prefixed map"
    end

    return "coop"
end

local function isExplicitAltModeForced(defaultMode)
    local cv = GetConVar and GetConVar("zb_forcemode")
    local forced = cv and lower(cv:GetString()) or ""

    if forced == "" or forced == "random" or forced == defaultMode then
        return false
    end

    return true
end

local function setCoopDefault()
    local defaultMode, reason = getMapDefaultMode()
    if not defaultMode then
        print("[ZC CoopBootstrap] Skipping coop default on " .. reason .. ": " .. lower(game.GetMap()))
        return true
    end

    if defaultMode == "hidden" then
        print("[ZC CoopBootstrap] Hidden-prefixed map detected; coop bootstrap is disabled.")
        return true
    end

    if isExplicitAltModeForced(defaultMode) then
        print("[ZC CoopBootstrap] Skipping coop default: explicit alternate mode forced.")
        return true
    end

    local roundName = ""
    if isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) then
            roundName = lower(round.name)
        end
    end

    if roundName == defaultMode then
        return true
    end

    if GetConVar and GetConVar("zb_forcemode") then
        RunConsoleCommand("zb_forcemode", defaultMode)
    end

    if zb then
        zb.nextround = defaultMode
        zb.RoundList = {}
        for i = 1, 20 do
            zb.RoundList[i] = defaultMode
        end
    end

    if NextRound then
        NextRound(defaultMode)
    end

    print("[ZC CoopBootstrap] Enforced default mode: " .. defaultMode)
    return true
end

local function retryBootstrap(attempt)
    attempt = attempt or 1

    local ok, result = pcall(setCoopDefault)
    if ok and result then return end

    if attempt >= RETRIES then
        print("[ZC CoopBootstrap] Failed to enforce coop default after retries.")
        return
    end

    timer.Simple(DELAY, function()
        retryBootstrap(attempt + 1)
    end)
end

timer.Simple(1, function()
    retryBootstrap(1)
end)
