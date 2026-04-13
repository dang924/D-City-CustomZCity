local waveActive = false
local waveEndTime = 0

net.Receive("ZC_WaveSync", function()
    waveActive = net.ReadBool()
    waveEndTime = net.ReadFloat()
end)

hook.Add("HUDPaint", "ZC_WaveHUD_Clean", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if not waveActive then return end
    if ply:Alive() then return end

    local timeLeft = math.max(0, waveEndTime - CurTime())

    local text = "NEXT WAVE IN " .. math.ceil(timeLeft) .. "s"

    surface.SetFont("Trebuchet24")
    local w, h = surface.GetTextSize(text)

    local x = ScrW() / 2
    local y = ScrH() * 0.8

    -- Background
    draw.RoundedBox(12, x - w/2 - 20, y - 10, w + 40, h + 20, Color(0, 0, 0, 200))

    -- Text
    draw.SimpleText(text, "Trebuchet24", x, y, Color(255, 200, 50), TEXT_ALIGN_CENTER)

    -- Subtext
    draw.SimpleText("Waiting for reinforcements...", "Trebuchet18", x, y + 26, Color(200,200,200), TEXT_ALIGN_CENTER)
end)