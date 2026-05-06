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
    -- DCity: visual draw is handled by the unified EKG ring in
    -- lua/autorun/client/cl_unconscious_ring.lua (which already follows
    -- org.heartbeat). This hook used to draw a second centered ring/dots
    -- on top of it, producing a duplicate inner circle during bleedout.
    -- Keep the hook registered as a no-op so other code that may rely on
    -- its presence (and so its associated state cleanup below) still runs,
    -- but skip the actual rendering.
    if not enabled:GetBool() or not IsCoopRoundActive() then
        ringAlpha = math.Approach(ringAlpha, 0, FrameTime() * 3)
        observed = nil
        return
    end

    local lp = LocalPlayer()
    local ply = GetObservedPlayer(lp)
    local key = GetObservedKey(ply)

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
end)

