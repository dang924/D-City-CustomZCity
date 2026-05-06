-- Displays a HUD hint to newly connected dead players telling them how to join.
-- Disappears once the player is alive.

local showHint    = false
local hintEndTime = nil
local HINT_JOIN_DURATION  = 14
local HINT_STUCK_DURATION = 8
local hintKind = nil
local lastAliveState = nil
local allowNextSpawnHint = false
local lastRagdollState = false
local suppressSpawnHintUntil = 0

local function HasActiveRagdollState(ply)
    if not IsValid(ply) then return false end

    return IsValid(ply.FakeRagdoll)
        or IsValid(ply:GetNWEntity("FakeRagdoll"))
        or IsValid(ply.OldRagdoll)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end
    local ok, round = pcall(CurrentRound)
    return ok and istable(round) and round.name == "coop"
end

local function HideHint()
    showHint    = false
    hintEndTime = nil
    hintKind    = nil
end

local function ShowHint(kind, duration)
    showHint    = true
    hintKind    = kind
    hintEndTime = CurTime() + duration
end

local function UpdateAliveTracking(ply)
    if not IsValid(ply) then return end

    local isAlive = ply:Alive()
    if lastAliveState == nil then
        lastAliveState = isAlive
        return
    end

    if lastAliveState and not isAlive then
        allowNextSpawnHint = true
    end

    lastAliveState = isAlive
end

local function UpdateRagdollTracking(ply)
    if not IsValid(ply) then return end

    local hasRagdoll = HasActiveRagdollState(ply)
    if lastRagdollState and not hasRagdoll then
        suppressSpawnHintUntil = CurTime() + 3
        allowNextSpawnHint = false
        if hintKind == "stuck" then
            HideHint()
        end
    end

    lastRagdollState = hasRagdoll
end

local function GetHUDScale()
    local sw, sh = ScrW(), ScrH()
    return math.Clamp(math.min(sw / 1920, sh / 1080), 0.9, 1.5)
end

local function GetTextWidth(font, text)
    surface.SetFont(font)
    local w = surface.GetTextSize(text)
    return w
end

local function FitFontToWidth(text, preferredFont, fallbackFont, maxWidth)
    if GetTextWidth(preferredFont, text) <= maxWidth then
        return preferredFont
    end
    if fallbackFont and GetTextWidth(fallbackFont, text) <= maxWidth then
        return fallbackFont
    end
    return fallbackFont or preferredFont
end

hook.Add("InitPostEntity", "ZCity_CoopJoinSpawn", function()
    timer.Simple(3, function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        UpdateAliveTracking(ply)
        UpdateRagdollTracking(ply)
        allowNextSpawnHint = not ply:Alive()
        if not IsCoopRoundActive() then return end
        if ply:Alive() then return end
        ShowHint("join", HINT_JOIN_DURATION)
    end)
end)

hook.Add("Think", "ZCity_CoopJoinSpawn_TrackAlive", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    UpdateAliveTracking(ply)
    UpdateRagdollTracking(ply)
end)

-- Also show hint after a regular respawn so all players see the !stuck tip
hook.Add("player_spawn", "ZCity_CoopStuckHint", function(data)
    if not LocalPlayer or not IsValid(LocalPlayer()) then return end
    if not IsCoopRoundActive() then return end
    if data.userid ~= LocalPlayer():UserID() then return end
    timer.Simple(1, function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        UpdateAliveTracking(ply)
        UpdateRagdollTracking(ply)
        if not IsCoopRoundActive() then return end
        if not ply:Alive() then return end
        if suppressSpawnHintUntil > CurTime() then return end
        if not allowNextSpawnHint then return end
        allowNextSpawnHint = false
        ShowHint("stuck", HINT_STUCK_DURATION)
    end)
end)

hook.Add("HUDPaint", "ZCity_CoopJoinSpawnHint", function()
    if not showHint then return end
    if not IsCoopRoundActive() then
        HideHint()
        return
    end

    local ply = LocalPlayer()
    if hintKind == "join" and ply:Alive() then
        HideHint()
        return
    end

    if CurTime() > hintEndTime then
        HideHint()
        return
    end

    local sw, sh  = ScrW(), ScrH()
    local uiScale = GetHUDScale()
    local alpha   = math.Clamp((hintEndTime - CurTime()) * 2, 0, 1) * 220
    local bw      = math.floor(math.min(sw * 0.92, 980 * uiScale) + 0.5)
    local bh      = math.floor(86 * uiScale + 0.5)
    local x       = sw / 2 - bw / 2
    local y       = sh * 0.65
    local maxTextWidth = bw - math.floor(56 * uiScale + 0.5)

    draw.RoundedBox(6, x, y, bw, bh, Color(30, 30, 30, alpha * 0.9))

    if hintKind == "stuck" and ply:Alive() then
        local stuckTopText = "Use !stuck to teleport to Gordon"
        local stuckTopFont = FitFontToWidth(stuckTopText, "HomigradFontMedium", "HomigradFontSmall", maxTextWidth)
        draw.SimpleText(
            stuckTopText,
            stuckTopFont,
            sw / 2, y + bh * 0.38,
            Color(255, 255, 255, alpha),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            "if you spawn in a bad area",
            "HomigradFontSmall",
            sw / 2, y + bh * 0.68,
            Color(190, 190, 190, alpha * 0.9),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    else
        local joinTopText = "Type !join in chat to spawn"
        local joinTopFont = FitFontToWidth(joinTopText, "HomigradFontMedium", "HomigradFontSmall", maxTextWidth)
        draw.SimpleText(
            joinTopText,
            joinTopFont,
            sw / 2, y + bh * 0.38,
            Color(255, 255, 255, alpha),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )

        draw.SimpleText(
            "Use !stuck if you spawn in a bad area",
            "HomigradFontSmall",
            sw / 2, y + bh * 0.68,
            Color(180, 180, 180, alpha * 0.8),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end
end)

hook.Add("ShutDown", "ZCity_CoopJoinSpawn_Cleanup", HideHint)
