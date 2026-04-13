-- Shows a wave countdown HUD for dead Combine players waiting to respawn.
-- Mirrors cl_wave_hud.lua but for the Combine faction.

local combineWaveActive = false
local combineWaveEnd    = 0

net.Receive("ZC_CombineWaveSync", function()
    combineWaveActive = net.ReadBool()
    combineWaveEnd    = net.ReadFloat()
end)

hook.Add("HUDPaint", "ZC_CombineWaveHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not combineWaveActive then return end
    if ply:Alive() then return end

    local timeLeft = math.max(0, combineWaveEnd - CurTime())
    local text = "NEXT WAVE IN " .. math.ceil(timeLeft) .. "s"

    surface.SetFont("Trebuchet24")
    local w, h = surface.GetTextSize(text)

    local x = ScrW() / 2
    local y = ScrH() * 0.8

    draw.RoundedBox(12, x - w/2 - 20, y - 10, w + 40, h + 20, Color(0, 0, 0, 200))
    draw.SimpleText(text, "Trebuchet24", x, y, Color(89, 230, 255), TEXT_ALIGN_CENTER)
    draw.SimpleText("Awaiting deployment...", "Trebuchet18", x, y + 26, Color(200, 200, 200), TEXT_ALIGN_CENTER)
end)
