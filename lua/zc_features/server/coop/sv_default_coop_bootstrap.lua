-- Ensure DCity defaults to coop at startup unless an explicit alternate mode
-- was requested (e.g. !setevent / !setdod / F6 mode selection).

if not SERVER then return end

local RETRIES = 20
local DELAY = 1

local function lower(v)
    return string.lower(tostring(v or ""))
end

local function isExplicitAltModeForced()
    local cv = GetConVar and GetConVar("zb_forcemode")
    local forced = cv and lower(cv:GetString()) or ""
    return forced == "event" or forced == "dod"
end

local function setCoopDefault()
    if isExplicitAltModeForced() then
        print("[ZC CoopBootstrap] Skipping coop default: explicit alternate mode forced.")
        return true
    end

    local mapName = lower(game.GetMap())
    if string.StartWith(mapName, "dod_") then
        print("[ZC CoopBootstrap] Skipping coop default on DoD-prefixed map: " .. mapName)
        return true
    end

    local roundName = ""
    if isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) then
            roundName = lower(round.name)
        end
    end

    if roundName == "coop" then
        return true
    end

    if GetConVar and GetConVar("zb_forcemode") then
        RunConsoleCommand("zb_forcemode", "coop")
    end

    if zb then
        zb.nextround = "coop"
        zb.RoundList = {}
        for i = 1, 20 do
            zb.RoundList[i] = "coop"
        end
    end

    if NextRound then
        NextRound("coop")
    end

    print("[ZC CoopBootstrap] Enforced default mode: coop")
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
