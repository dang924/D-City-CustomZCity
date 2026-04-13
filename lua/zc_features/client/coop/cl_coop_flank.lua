-- Displays a full-screen warning with countdown when the flank system activates.

local warningEndTime  = nil
local warningDuration = 10

net.Receive("ZC_FlankWarning", function()
    local duration = net.ReadFloat()
    warningEndTime  = CurTime() + duration
    warningDuration = duration
    surface.PlaySound("ambient/alarms/warningbell1.wav")
end)

hook.Add("HUDPaint", "ZCity_FlankWarning", function()
    if not warningEndTime then return end

    local remaining = warningEndTime - CurTime()
    if remaining <= 0 then
        warningEndTime = nil
        return
    end

    local sw, sh   = ScrW(), ScrH()
    local fade     = math.Clamp(remaining * 2, 0, 1)  -- fade out in last 0.5s
    local pulse    = math.abs(math.sin(CurTime() * 3)) -- pulsing red tint

    -- Dark red vignette across full screen
    surface.SetDrawColor(120, 0, 0, 60 * pulse * fade)
    surface.DrawRect(0, 0, sw, sh)

    -- Warning box
    local bw, bh = 520, 90
    local x      = sw / 2 - bw / 2
    local y      = sh * 0.38

    draw.RoundedBox(6, x, y, bw, bh, Color(15, 0, 0, 210 * fade))
    draw.RoundedBox(6, x + 2, y + 2, bw - 4, bh - 4, Color(40, 5, 5, 180 * fade))

    -- Main warning text
    draw.SimpleText(
        "GORDON IS DEAD. THE DEATH SQUAD IS UNLEASHED.",
        "HomigradFontSmall",
        sw / 2, y + 22,
        Color(255, 60, 60, 255 * fade),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )

    -- Countdown
    draw.SimpleText(
        "Combine forces deploy in " .. math.ceil(remaining) .. "s",
        "HomigradFontMedium",
        sw / 2, y + 58,
        Color(255, 200, 200, 255 * fade),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )

    -- Thin red bar draining left to right
    local fraction   = remaining / warningDuration
    local barW       = bw - 20

    draw.RoundedBox(2, x + 10, y + bh - 12, barW, 5, Color(60, 0, 0, 180 * fade))
    draw.RoundedBox(2, x + 10, y + bh - 12, barW * fraction, 5, Color(220, 40, 40, 220 * fade))
end)
