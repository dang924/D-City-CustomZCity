include("shared.lua")

local function OwnerColor(owner)
    if owner == 0 then return Color(185, 70, 70) end
    if owner == 1 then return Color(70, 120, 200) end
    return Color(150, 150, 150)
end

function ENT:Draw()
    self:DrawModel()

    local owner = self:GetFlagOwnerState()
    local c = OwnerColor(owner)
    local name = self:GetFlagName()
    local radius = math.Round(self:GetCaptureRadius())

    local p = self:GetPos() + Vector(0, 0, 18)
    local a = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

    cam.Start3D2D(p, a, 0.08)
        draw.RoundedBox(4, -120, -32, 240, 64, Color(15, 18, 24, 220))
        draw.RoundedBox(2, -118, -30, 236, 6, c)
        draw.SimpleText(name, "DermaLarge", 0, -8, Color(230, 230, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Radius: " .. radius, "DermaDefault", 0, 14, Color(180, 180, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
