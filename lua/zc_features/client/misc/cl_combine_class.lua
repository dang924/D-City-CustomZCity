-- Draws a blue targeting reticle for Elite soldiers matching Gordon's style,
-- and displays the Elite spawn message. Class hint is handled server-side.


-- Elite spawn message
local eliteMessage     = nil
local eliteMessageTime = nil
local MESSAGE_DURATION = 5

net.Receive("ZC_EliteSpawnMessage", function()
    eliteMessage     = net.ReadString()
    eliteMessageTime = CurTime() + MESSAGE_DURATION
end)

hook.Add("HUDPaint", "ZCity_EliteSpawnMessage", function()
    if not eliteMessage then return end
    if CurTime() > eliteMessageTime then
        eliteMessage     = nil
        eliteMessageTime = nil
        return
    end

    local remaining = eliteMessageTime - CurTime()
    -- Fade in for first 0.5s, hold, fade out for last 1s
    local fade
    local elapsed = MESSAGE_DURATION - remaining
    if elapsed < 0.5 then
        fade = elapsed / 0.5
    elseif remaining < 1 then
        fade = remaining
    else
        fade = 1
    end

    local sw, sh = ScrW(), ScrH()

    -- Main message text
    draw.SimpleText(
        eliteMessage,
        "HomigradFontMedium",
        sw / 2, sh * 0.42,
        Color(15, 165, 165, 255 * fade),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )

    -- Subtitle
    draw.SimpleText(
        "ELITE DESIGNATION CONFIRMED",
        "HomigradFontSmall",
        sw / 2, sh * 0.42 + 26,
        Color(89, 230, 255, 180 * fade),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
end)


-- Elite reticle — mirrors Gordon's exactly but in Combine blue
-- Drawn inside RenderScreenspaceEffects so it renders on top of the
-- Combine helmet overlay, matching how Gordon's reticle is drawn
local color_sight = Color(15, 165, 165, 220)  -- Combine cyan-blue
local posSight    = Vector(ScrW(), ScrH(), 0)

local function HasEliteCombineEffects(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if ply:GetNWBool("ZC_IsCombineElite", false) then return true end
    if ply.PlayerClassName ~= "Combine" then return false end
    if (ply:GetNWString("PlayerRole") or "") == "Elite" then return true end
    return ply.subClass == "elite"
end

hook.Add("RenderScreenspaceEffects", "ZCity_EliteReticle", function()
    local lply = LocalPlayer()
    if not HasEliteCombineEffects(lply) then return end

    local wep = lply:GetActiveWeapon()
    if not IsValid(wep) or not wep.GetTrace then return end

    local FRT = FrameTime() * 5
    local tr  = wep:GetTrace(true)

    posSight = LerpVector(FRT * 5, posSight,
        Vector(tr.HitPos:ToScreen().x, tr.HitPos:ToScreen().y, 0))

    -- Hide reticle when aiming down sights, matching Gordon's behaviour
    color_sight.a = Lerp(FRT * 5, color_sight.a,
        lply:KeyDown(IN_ATTACK2) and 0 or 220)

    -- Four rectangles in a cross — identical geometry to Gordon's reticle
    draw.RoundedBox(0, posSight.x - 1, posSight.y + 2,  2, 6, color_sight)
    draw.RoundedBox(0, posSight.x - 1, posSight.y - 8,  2, 6, color_sight)
    draw.RoundedBox(0, posSight.x + 2, posSight.y - 1,  6, 2, color_sight)
    draw.RoundedBox(0, posSight.x - 8, posSight.y - 1,  6, 2, color_sight)
end)
