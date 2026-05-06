-- Event-only join hint for late joiners.
-- Keeps coop join messaging out of Event rounds and provides a dedicated command.

if SERVER then return end

local showHint = false
local hintEndTime = 0
local HINT_DURATION = 30

local function IsEventRoundActive()
    if not CurrentRound then return false end
    local ok, round = pcall(CurrentRound)
    return ok and istable(round) and round.name == "event"
end

local function HideHint()
    showHint = false
    hintEndTime = 0
end

local function ShowHintForDuration(duration)
    if not IsEventRoundActive() then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:Alive() then return end

    showHint = true
    hintEndTime = CurTime() + (duration or HINT_DURATION)
end

hook.Add("InitPostEntity", "ZC_EventJoinSpawn_InitHint", function()
    timer.Simple(2, function()
        ShowHintForDuration(HINT_DURATION)
    end)
end)

hook.Add("player_death", "ZC_EventJoinSpawn_DeathHint", function(data)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if data.userid ~= ply:UserID() then return end

    timer.Simple(0.2, function()
        ShowHintForDuration(HINT_DURATION)
    end)
end)

hook.Add("HUDPaint", "ZC_EventJoinSpawn_HUDHint", function()
    if not showHint then return end

    if not IsEventRoundActive() then
        HideHint()
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) or ply:Alive() then
        HideHint()
        return
    end

    if CurTime() >= hintEndTime then
        HideHint()
        return
    end

    local alpha = math.Clamp((hintEndTime - CurTime()) * 2, 0, 1) * 220
    local sw, sh = ScrW(), ScrH()
    local bw, bh = 360, 46
    local x = sw * 0.5 - bw * 0.5
    local y = sh * 0.68

    draw.RoundedBox(6, x, y, bw, bh, Color(30, 30, 30, alpha * 0.9))
    draw.SimpleText(
        "Type !eventjoin in chat to join the Event",
        "HomigradFontMedium",
        sw * 0.5,
        y + bh * 0.5,
        Color(255, 255, 255, alpha),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )
end)

hook.Add("ShutDown", "ZC_EventJoinSpawn_Cleanup", HideHint)
