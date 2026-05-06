-- cl_zrp.lua — ZRP client-side HUD and net receivers.

local MODE = MODE

if SERVER then return end

-- ── Fonts ─────────────────────────────────────────────────────────────────────

local function GetHUDScale()
    local sw, sh = ScrW(), ScrH()
    return math.Clamp(math.min(sw / 1920, sh / 1080), 0.9, 1.6)
end

local function RebuildHUDFonts()
    local s = GetHUDScale()
    local function sz(v)
        return math.max(12, math.floor(v * s + 0.5))
    end

    surface.CreateFont("ZRP_HUD_Respawn",    { font = "Roboto", size = sz(48), weight = 700 })
    surface.CreateFont("ZRP_HUD_RespawnSub", { font = "Roboto", size = sz(18), weight = 500 })
    surface.CreateFont("ZRP_HUD_Intro",      { font = "Roboto", size = sz(36), weight = 700 })
    surface.CreateFont("ZRP_HUD_IntroSub",   { font = "Roboto", size = sz(18), weight = 400 })
    surface.CreateFont("ZRP_HUD_Outro",      { font = "Roboto", size = sz(32), weight = 700 })
    surface.CreateFont("ZRP_HUD_OutroSub",   { font = "Roboto", size = sz(16), weight = 400 })
end

RebuildHUDFonts()

hook.Add("OnScreenSizeChanged", "ZRP_HUD_RebuildFonts", function()
    RebuildHUDFonts()
end)

-- ── Colors ────────────────────────────────────────────────────────────────────

local CLR_SURVIVOR  = Color(60, 200, 120, 255)
local CLR_DEAD_BG   = Color(15, 15, 20, 200)
local CLR_DEAD_TXT  = Color(230, 230, 230, 255)
local CLR_DEAD_SUB  = Color(160, 160, 170, 220)
local CLR_ACCENT    = Color(60, 200, 120, 255)

-- ── Client state ──────────────────────────────────────────────────────────────

local respawnAt    = nil    -- CurTime() value when player will respawn
local roundStarted = false
local introExpiry  = 0
local outroExpiry  = 0      -- CurTime() value while end banner is visible

-- Sounds played at round start / end. Centralised so they're easy to swap.
local SND_ROUND_START = "ambient/alarms/warningbell1.wav"
local SND_ROUND_END   = "buttons/button10.wav"

-- Dedupe guard: both the ZRP_Start net broadcast and the RoundInfoCalled hook
-- below can independently fire the intro. We only want it to play once per round.
-- "round id" is just a CurTime stamp captured when intro fires; if another
-- trigger arrives within a half-second we ignore it.
local lastIntroFiredAt = 0
local lastOutroFiredAt = 0

local function IsZRPRoundActiveClient()
    return zb and zb.ROUND_STATE == 1 and zb.CROUND == "zrp"
end

local function FireIntroSplash()
    if CurTime() - lastIntroFiredAt < 0.5 then return end
    lastIntroFiredAt = CurTime()

    roundStarted = true
    introExpiry  = CurTime() + 8
    outroExpiry  = 0
    if zb and zb.RemoveFade then zb.RemoveFade() end
    surface.PlaySound(SND_ROUND_START)
end

local function FireOutroSplash()
    if CurTime() - lastOutroFiredAt < 0.5 then return end
    lastOutroFiredAt = CurTime()

    roundStarted = false
    respawnAt    = nil
    outroExpiry  = CurTime() + 6
    surface.PlaySound(SND_ROUND_END)
end

-- ── Net receivers ──────────────────────────────────────────────────────────────

net.Receive("ZRP_Start", FireIntroSplash)
net.Receive("ZRP_End",   FireOutroSplash)

-- Backup trigger: cl_init.lua fires "RoundInfoCalled" whenever a RoundInfo packet
-- is received from the server (state changes, mode switches). If for any reason
-- the dedicated ZRP_Start/ZRP_End broadcasts get dropped or arrive at the wrong
-- frame, this catches the transition from CROUND/ROUND_STATE alone.
hook.Add("RoundInfoCalled", "ZRP_IntroFallback", function(rnd)
    if rnd ~= "zrp" then
        -- Leaving ZRP — fire the outro if we were previously in a ZRP round.
        if roundStarted then FireOutroSplash() end
        return
    end

    -- We can't read the new ROUND_STATE here (it's set right after this hook by
    -- cl_init.lua). Fire intro on the next tick when state is settled.
    timer.Simple(0, function()
        if zb and zb.ROUND_STATE == 1 and zb.CROUND == "zrp" then
            FireIntroSplash()
        elseif zb and zb.ROUND_STATE == 3 and zb.CROUND == "zrp" then
            FireOutroSplash()
        end
    end)
end)

net.Receive("ZRP_RespawnTimer", function()
    respawnAt = CurTime() + net.ReadFloat()  -- server sends duration; convert to local CurTime
end)

-- ── HUD: respawn countdown (shown only to dead players) ────────────────────────

function MODE:HUDPaint()
    local lply = LocalPlayer()

    -- ── Outro splash (round end) ──────────────────────────────────────────────
    if outroExpiry > 0 and CurTime() < outroExpiry then
        local remain = outroExpiry - CurTime()
        local fade   = math.Clamp(remain, 0, 1)
        local sw, sh = ScrW(), ScrH()

        draw.RoundedBox(6, sw * 0.5 - 240, sh * 0.10, 480, 70, ColorAlpha(CLR_DEAD_BG, 210 * fade))
        draw.SimpleText(
            "ZRP Round Ended",
            "ZRP_HUD_Outro",
            sw * 0.5, sh * 0.125,
            ColorAlpha(CLR_ACCENT, 255 * fade),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            "Returning to round selection…",
            "ZRP_HUD_OutroSub",
            sw * 0.5, sh * 0.16,
            ColorAlpha(CLR_DEAD_SUB, 255 * fade),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    -- ── Intro splash ──────────────────────────────────────────────────────────
    if roundStarted and CurTime() < introExpiry then
        local fade   = math.Clamp(introExpiry - CurTime(), 0, 1)
        local sw, sh = ScrW(), ScrH()

        draw.SimpleText(
            "ZCity | ZRP",
            "ZRP_HUD_Intro",
            sw * 0.5, sh * 0.1,
            ColorAlpha(CLR_ACCENT, 255 * fade),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            "You are a Survivor",
            "ZRP_HUD_IntroSub",
            sw * 0.5, sh * 0.17,
            ColorAlpha(CLR_DEAD_TXT, 255 * fade),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            "Loot containers. Sell trash. Stay alive.",
            "ZRP_HUD_IntroSub",
            sw * 0.5, sh * 0.22,
            ColorAlpha(CLR_DEAD_SUB, 255 * fade),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    -- ── Respawn countdown ─────────────────────────────────────────────────────
    if not lply:Alive() and respawnAt and respawnAt > CurTime() then
        local sw, sh       = ScrW(), ScrH()
        local uiScale      = GetHUDScale()
        local remaining    = math.ceil(respawnAt - CurTime())
        local pct          = math.Clamp((respawnAt - CurTime()) / 10, 0, 1)
        local barW         = math.Clamp(sw * 0.34, 680 * uiScale, 1080 * uiScale)
        local barH         = math.max(6, math.floor(8 * uiScale + 0.5))
        local panelPadX    = math.floor(26 * uiScale + 0.5)
        local panelH       = math.floor(156 * uiScale + 0.5)
        local panelY       = sh * 0.32
        local barX         = sw * 0.5 - barW * 0.5
        local barY         = panelY + panelH + math.floor(22 * uiScale + 0.5)

        -- Background panel.
        draw.RoundedBox(6, sw * 0.5 - barW * 0.5 - panelPadX, panelY, barW + panelPadX * 2, panelH, ColorAlpha(CLR_DEAD_BG, 210))

        -- "RESPAWNING IN" label.
        draw.SimpleText(
            "RESPAWNING IN",
            "ZRP_HUD_RespawnSub",
            sw * 0.5, panelY + panelH * 0.33,
            ColorAlpha(CLR_DEAD_SUB, 220),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )

        -- Countdown number.
        draw.SimpleText(
            tostring(remaining),
            "ZRP_HUD_Respawn",
            sw * 0.5, panelY + panelH * 0.68,
            ColorAlpha(CLR_DEAD_TXT, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )

        -- Progress bar track.
        draw.RoundedBox(3, barX, barY, barW, barH, Color(40, 40, 50, 200))
        -- Progress bar fill (green → red as time runs out).
        local r = math.floor(255 * (1 - pct))
        local g = math.floor(200 * pct)
        draw.RoundedBox(3, barX, barY, barW * pct, barH, Color(r, g, 60, 220))
    elseif IsZRPRoundActiveClient() and not lply:Alive() then
        local sw, sh = ScrW(), ScrH()
        local uiScale = GetHUDScale()
        local hintW = math.floor(420 * uiScale + 0.5)
        local hintH = math.floor(44 * uiScale + 0.5)
        draw.RoundedBox(6, sw * 0.5 - hintW * 0.5, sh * 0.47, hintW, hintH, ColorAlpha(CLR_DEAD_BG, 210))
        draw.SimpleText(
            "Type !join in chat to joinspawn",
            "ZRP_HUD_RespawnSub",
            sw * 0.5, sh * 0.47 + hintH * 0.5,
            ColorAlpha(CLR_DEAD_TXT, 235),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end
end

function MODE:RenderScreenspaceEffects()
    -- Fade in at round start.
    if not roundStarted then return end
    if CurTime() > (zb.ROUND_START or 0) + 7.5 then return end

    local fade = math.Clamp((zb.ROUND_START or 0) + 7.5 - CurTime(), 0, 1)
    surface.SetDrawColor(0, 0, 0, math.floor(255 * fade))
    surface.DrawRect(-1, -1, ScrW() + 2, ScrH() + 2)
end
