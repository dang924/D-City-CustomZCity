-- Shows a tap-[E] revive prompt when a Medic or Gordon looks at an incapped player
-- within revive range. Fades in and out smoothly.
--
-- Uses two detection methods:
--  1. Eyetrace — catches direct hits on the ragdoll or player entity
--  2. Proximity scan — finds any incapped player within range, regardless of
--     whether the crosshair lands cleanly on their ragdoll

local REVIVE_RANGE   = 100   -- must match sv_coop_revive.lua
local SCAN_RANGE     = 120   -- slightly wider for the indicator so it appears before you're at the exact edge
local FADE_SPEED     = 8
local COL_KEY        = Color(255, 220, 80)
local COL_TEXT       = Color(255, 255, 255)
local COL_NAME       = Color(180, 230, 255)
local COL_SHADOW     = Color(0, 0, 0, 180)

local alpha      = 0
local targetName = ""

local function IsReviver(ply)
    if ply.PlayerClassName == "Gordon" then return true end
    if ply.subClass == "medic" then return true end
    return false
end

local function HasAnyAmputation(org)
    return org.llegamputated or org.rlegamputated or org.rarmamputated or org.larmamputated or org.headamputated
end

local function FindReviveTarget(ply)
    local pos = ply:GetPos()

    -- Method 1: eyetrace — works when crosshair lands directly on ragdoll/player
    local tr  = hg.eyeTrace(ply)
    local ent = tr.Entity

    -- Resolve fake ragdoll to player
    if IsValid(ent) and not ent:IsPlayer() and ent.ply then
        ent = ent.ply
    end

    if IsValid(ent) and ent:IsPlayer() and ent ~= ply then
        if ent.organism and ent.organism.otrub and not HasAnyAmputation(ent.organism) then
            if ent:GetPos():Distance(pos) <= SCAN_RANGE then
                return ent
            end
        end
    end

    -- Method 2: proximity scan — finds any incapped player nearby even if
    -- the crosshair misses their ragdoll geometry
    local best, bestDist = nil, SCAN_RANGE
    for _, p in ipairs(player.GetAll()) do
        if not IsValid(p) or p == ply then continue end
        if not p.organism or not p.organism.otrub then continue end
        if HasAnyAmputation(p.organism) then continue end
        local dist = p:GetPos():Distance(pos)
        if dist < bestDist then
            bestDist = dist
            best     = p
        end
    end

    return best
end

hook.Add("HUDPaint", "ZCity_ReviveIndicator", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        alpha = 0
        return
    end
    if not ply.organism or ply.organism.otrub then
        alpha = 0
        return
    end
    if not IsReviver(ply) then
        alpha = 0
        return
    end

    local target = FindReviveTarget(ply)

    -- Fade toward target alpha
    local desired = target and 1 or 0
    alpha = math.Clamp(alpha + (desired - alpha) * FADE_SPEED * FrameTime(), 0, 1)

    if alpha <= 0.01 then return end

    if target then
        targetName = target:GetPlayerName() or target:Nick()
    end

    local sw, sh = ScrW(), ScrH()
    local cx = sw / 2
    local cy = sh * 0.62
    local a  = math.floor(alpha * 255)

    -- Key badge
    local keyW, keyH = 28, 28
    draw.RoundedBox(4, cx - keyW / 2 - 1, cy - keyH / 2 - 1, keyW + 2, keyH + 2, Color(0, 0, 0, math.floor(a * 0.7)))
    draw.RoundedBox(4, cx - keyW / 2, cy - keyH / 2, keyW, keyH, Color(40, 40, 40, a))
    draw.SimpleText("E", "HomigradFontMedium", cx, cy, Color(COL_KEY.r, COL_KEY.g, COL_KEY.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Revive label
    local labelX = cx + keyW / 2 + 8
    draw.SimpleText("Tap Revive", "HomigradFontMedium", labelX + 1, cy + 1, Color(0, 0, 0, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("Tap Revive", "HomigradFontMedium", labelX, cy, Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Player name below
    draw.SimpleText(targetName, "HomigradFontSmall", cx + 1, cy + 18, Color(0, 0, 0, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(targetName, "HomigradFontSmall", cx, cy + 17, Color(COL_NAME.r, COL_NAME.g, COL_NAME.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
