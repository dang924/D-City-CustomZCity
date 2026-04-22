if SERVER then return end

local BLEEDOUT_TIME = 15

surface.CreateFont("UnconsciousDots", {
    font = "Bahnschrift",
    size = 120,
    weight = 800,
    antialias = true,
})

local enabled = GetConVar("hg_unconsciousring")
if not enabled then
    enabled = GetConVar("zc_bleedout_ring")
end
if not enabled then
    enabled = CreateClientConVar("zc_bleedout_ring", "1", true, false, "Enable bleedout ring UI", 0, 1)
end

local ringAlpha = 0
local dotBeat = 0
local observed = nil
local unconStartAt = {}

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

local function IsBleedoutExempt(ply)
    return string.lower(tostring(ply and ply.PlayerClassName or "")) == "gordon"
end

local function DrawArc(x, y, radius, thickness, startAng, endAng, roughness, color)
    surface.SetDrawColor(color.r, color.g, color.b, color.a)
    draw.NoTexture()

    local segs = roughness
    local step = (endAng - startAng) / segs

    for i = 0, segs - 1 do
        local a1 = math.rad(startAng + i * step)
        local a2 = math.rad(startAng + (i + 1) * step)

        local cos1, sin1 = math.cos(a1), math.sin(a1)
        local cos2, sin2 = math.cos(a2), math.sin(a2)

        local p1 = { x = x + cos1 * (radius - thickness), y = y - sin1 * (radius - thickness) }
        local p2 = { x = x + cos1 * radius, y = y - sin1 * radius }
        local p3 = { x = x + cos2 * radius, y = y - sin2 * radius }
        local p4 = { x = x + cos2 * (radius - thickness), y = y - sin2 * (radius - thickness) }

        surface.DrawPoly({ p1, p2, p3, p4 })
    end
end

local function GetObservedPlayer(lp)
    if not IsValid(lp) then return nil end

    if lp:Alive() then
        return lp
    end

    local target = lp:GetNWEntity("spect")
    local viewmode = lp:GetNWInt("viewmode", 1)
    if IsValid(target) and target:IsPlayer() and viewmode == 1 then
        return target
    end

    return nil
end

local function GetObservedKey(ply)
    if not IsValid(ply) then return nil end
    return ply:SteamID64() or tostring(ply:EntIndex())
end

hook.Add("HUDPaint", "ZC_DrawBleedoutRing", function()
    if not enabled:GetBool() or not IsCoopRoundActive() then
        ringAlpha = math.Approach(ringAlpha, 0, FrameTime() * 3)
        observed = nil
        return
    end

    local lp = LocalPlayer()
    local ply = GetObservedPlayer(lp)
    local key = GetObservedKey(ply)

    if key then
        unconStartAt[key] = unconStartAt[key] or CurTime()
    end

    if not IsValid(ply) or IsBleedoutExempt(ply) then
        ringAlpha = math.Approach(ringAlpha, 0, FrameTime() * 3)
        if key then unconStartAt[key] = nil end
        observed = nil
        return
    end

    local org = ply.organism
    if not org or not org.otrub then
        ringAlpha = math.Approach(ringAlpha, 0, FrameTime() * 3)
        if key then unconStartAt[key] = nil end
        observed = nil
        return
    end

    if observed ~= ply then
        observed = ply
        dotBeat = 0
        if key then unconStartAt[key] = CurTime() end
    end

    ringAlpha = math.Approach(ringAlpha, 1, FrameTime() * 2)
    dotBeat = math.floor(CurTime()) % 3

    local elapsed = math.max(tonumber(org.uncon_timer) or -1, 0)
    if elapsed <= 0 and key and unconStartAt[key] then
        elapsed = CurTime() - unconStartAt[key]
    end

    local progress = math.Clamp(elapsed / BLEEDOUT_TIME, 0, 1)
    local isCritical = progress >= 0.7

    local scrW, scrH = ScrW(), ScrH()
    local centerX, centerY = scrW / 2, scrH / 2

    surface.SetDrawColor(0, 0, 0, 100 * ringAlpha)
    surface.DrawRect(0, 0, scrW, scrH)

    local ringColor = isCritical and Color(200, 0, 0, 255 * ringAlpha) or Color(220, 220, 220, 255 * ringAlpha)
    local dotColor = isCritical and ringColor or Color(255, 255, 255, 255 * ringAlpha)

    local radius = 180
    local thickness = 8

    DrawArc(centerX, centerY, radius, thickness, 0, 360, 60, Color(40, 40, 40, 100 * ringAlpha))
    DrawArc(centerX, centerY, radius, thickness, 90, 90 - (progress * 360), 80, ringColor)

    local dotText = ""
    if isCritical then
        local redDots = { ".!", "..!", "...!" }
        dotText = redDots[dotBeat + 1]
    else
        local whiteDots = { ".", "..", "..." }
        dotText = whiteDots[dotBeat + 1]
    end

    draw.SimpleText(dotText, "UnconsciousDots", centerX, centerY, dotColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
