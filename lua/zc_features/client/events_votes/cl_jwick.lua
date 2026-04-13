-- John Wick vs Everyone — Client
-- Handles role HUD, music override for John, and blocked-shot feedback.

if SERVER then return end

-- ── Configuration ─────────────────────────────────────────────────────────────

local JOHN_MUSIC_PATH = "jwick/main_theme.wav" -- must match sv_jwick.lua path
                                                 -- place file in: sound/jwick/
local MUSIC_VOLUME    = 0.65
local MUSIC_FADE_TIME = 1.5  -- seconds to fade back in after releasing breath

-- ── State ─────────────────────────────────────────────────────────────────────

local myRole       = nil   -- "john", "guard", "elite", "vip", "bystander"
local jwickActive  = false
local music        = nil   -- IGmodAudioChannel
local musicTarget  = 0     -- target volume (0 or MUSIC_VOLUME)
local lastBlocked  = 0     -- time of last blocked shot flash

-- Crosshair state (John only — smoothly tracks weapon trace like Gordon's)
local posSight   = nil
local colorSight = Color(200, 200, 200, 220)

-- ── Role colours and labels ───────────────────────────────────────────────────

local ROLE_INFO = {
    john      = { label = "JOHN WICK",      col = Color(20,  20,  20),  text = Color(255, 220, 50)  },
    vip       = { label = "VIP",            col = Color(180, 20,  20),  text = Color(255, 255, 255) },
    elite     = { label = "ELITE GUARD",    col = Color(20,  60,  180), text = Color(255, 255, 255) },
    guard     = { label = "GUARD",          col = Color(30,  90,  30),  text = Color(255, 255, 255) },
    bystander = { label = "BYSTANDER",      col = Color(80,  80,  80),  text = Color(220, 220, 220) },
}

-- ── Music helpers ─────────────────────────────────────────────────────────────

local function StartJohnMusic()
    if IsValid(music) then music:Stop() end
    -- ZCity's pattern: "sound/" prefix + "noplay noblock" flags
    sound.PlayFile("sound/" .. JOHN_MUSIC_PATH, "noplay noblock", function(ch, id, err)
        if not IsValid(ch) then return end
        music = ch
        music:EnableLooping(true)
        music:SetVolume(0)
        music:Play()
        musicTarget = MUSIC_VOLUME
    end)
end

local function StopJohnMusic()
    musicTarget = 0
    timer.Simple(MUSIC_FADE_TIME + 0.1, function()
        if IsValid(music) and musicTarget == 0 then
            music:Stop()
            music = nil
        end
    end)
end

-- ── PlayerClass detection ────────────────────────────────────────────────────
-- When John class is set via !playerclass (outside the JWick event),
-- we still want the crosshair and music to activate.

hook.Add("Think", "JWick_ClassDetect", function()
    JWick_ClassDetect_Next = JWick_ClassDetect_Next or 0
    local now = CurTime()
    if now < JWick_ClassDetect_Next then return end
    JWick_ClassDetect_Next = now + 0.2

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    -- Only apply outside of an active JWick event (event system sets myRole itself)
    if jwickActive then return end

    local isJohn = lp.PlayerClassName == "John"

    if isJohn and myRole ~= "john" then
        myRole = "john"
        StartJohnMusic()
    elseif not isJohn and myRole == "john" then
        StopJohnMusic()
        myRole = nil
    end
end)

-- Fade music volume toward target each frame
hook.Add("Think", "JWick_MusicFade", function()
    if not IsValid(music) then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    -- Tie to ZCity's hmcd_holdbreath system — org.holdingbreath is synced
    -- to the client via organism_send so it's authoritative, not a key guess
    local org = IsValid(lp) and lp.organism
    local holdingBreath = org and org.holdingbreath or false
    local target = holdingBreath and 0 or musicTarget

    local current = music:GetVolume()
    local newVol  = Lerp(FrameTime() * (1 / MUSIC_FADE_TIME), current, target)
    music:SetVolume(math.Clamp(newVol, 0, 1))
end)

-- ── Net receives ──────────────────────────────────────────────────────────────

net.Receive("JWick_SetRole", function()
    local role = net.ReadString()

    if role == "blocked" then
        -- Blocked shot feedback flash
        lastBlocked = CurTime()
        return
    end

    myRole = role

    if role == "john" then
        StartJohnMusic()
        chat.AddText(Color(255,220,50), "[J.WICK] ", color_white, "You are ", Color(255,220,50), "JOHN WICK",
            color_white, ". Eliminate the VIP.")
    elseif role == "vip" then
        chat.AddText(Color(200,50,50), "[J.WICK] ", color_white, "You are the ", Color(200,50,50), "VIP",
            color_white, ". Stay alive.")
    elseif role == "elite" then
        chat.AddText(Color(50,100,255), "[J.WICK] ", color_white, "You are an ", Color(50,100,255), "ELITE GUARD",
            color_white, ". Protect the VIP.")
    elseif role == "guard" then
        chat.AddText(Color(50,180,50), "[J.WICK] ", color_white, "You are a ", Color(50,180,50), "GUARD",
            color_white, ". Protect the VIP.")
    elseif role == "bystander" then
        chat.AddText(Color(160,160,160), "[J.WICK] ", color_white, "You are a ", Color(160,160,160), "BYSTANDER",
            color_white, ". Run and hide.")
    end
end)

net.Receive("JWick_Start", function()
    jwickActive = true
end)

net.Receive("JWick_End", function()
    local winner = net.ReadString()
    jwickActive  = false

    if myRole == "john" then
        StopJohnMusic()
    end
    myRole = nil

    if winner == "john" then
        chat.AddText(Color(255,220,50), "[J.WICK] John Wick wins! The VIP has been eliminated.")
    elseif winner == "guards" then
        chat.AddText(Color(50,180,50), "[J.WICK] Guards win! John Wick has been eliminated.")
    end
end)

-- ── HUD ───────────────────────────────────────────────────────────────────────

hook.Add("HUDPaint", "JWick_HUD", function()
    if not myRole then return end
    local info = ROLE_INFO[myRole]
    if not info then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    -- Role badge and blocked-shot flash are event-only
    if jwickActive then
        local W = 160
        local H = 32
        local x = ScrW() / 2 - W / 2
        local y = 12

        draw.RoundedBox(6, x, y, W, H, ColorAlpha(info.col, 210))
        draw.SimpleText(info.label, "DermaDefaultBold", x + W/2, y + H/2,
            info.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local elapsed = CurTime() - lastBlocked
        if elapsed < 0.3 then
            local alpha = (1 - elapsed / 0.3) * 120
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawRect(0, 0, ScrW(), ScrH())
        end
    end

    -- John-specific elements render in any gamemode
    if myRole == "john" then
        local y = jwickActive and 12 or 0  -- no offset needed outside event

        -- Crosshair
        local wep = lp:GetActiveWeapon()
        if IsValid(wep) and wep.GetTrace then
            local FRT = FrameTime() * 5
            local tr  = wep:GetTrace(true)
            local scrPos = Vector(tr.HitPos:ToScreen().x, tr.HitPos:ToScreen().y, 0)
            if not posSight then posSight = scrPos end
            posSight = LerpVector(FRT * 5, posSight, scrPos)

            colorSight.a = Lerp(FRT * 5, colorSight.a, lp:KeyDown(IN_ATTACK2) and 0 or 220)

            local px, py = posSight.x, posSight.y
            draw.RoundedBox(0, px - 1, py + 2,  2, 6, colorSight)  -- bottom
            draw.RoundedBox(0, px - 1, py - 8,  2, 6, colorSight)  -- top
            draw.RoundedBox(0, px + 2, py - 1,  6, 2, colorSight)  -- right
            draw.RoundedBox(0, px - 8, py - 1,  6, 2, colorSight)  -- left
        end

        -- Breath hint
        local org = lp.organism
        local holdingBreath = org and org.holdingbreath or false
        if holdingBreath then
            draw.SimpleText("[ music muted ]", "DermaDefault",
                ScrW() / 2, y + (jwickActive and 44 or 14), Color(200, 200, 200, 160),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        -- Shield stamina bar
        local stamina   = lp:GetNWFloat("JWick_ShieldStamina", 100)
        local frac      = math.Clamp(stamina / 100, 0, 1)
        local shielding = lp:GetNWBool("JWick_Shielding", false)

        local bW = 160
        local bH = 8
        local bX = ScrW() / 2 - bW / 2
        local bY = y + (jwickActive and (holdingBreath and 30 or 14) + 32 or (holdingBreath and 38 or 14))

        draw.RoundedBox(4, bX - 1, bY - 1, bW + 2, bH + 2, Color(0, 0, 0, 160))

        local barCol
        if stamina < 15 then
            barCol = Color(200, 40, 40, 220)
        elseif shielding then
            barCol = Color(255, 220, 50, 220)
        else
            barCol = Color(200, 200, 200, 180)
        end
        draw.RoundedBox(4, bX, bY, math.max(bW * frac, 2), bH, barCol)

        local label = shielding and "SHIELDING" or "SHIELD  [+jwick_shield]"
        draw.SimpleText(label, "DermaDefault", bX + bW / 2, bY + bH + 3,
            shielding and Color(255, 220, 50, 200) or Color(180, 180, 180, 140),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end)

-- Clean up if we disconnect mid-event
hook.Add("ShutDown", "JWick_Cleanup", function()
    if IsValid(music) then music:Stop() end
end)
