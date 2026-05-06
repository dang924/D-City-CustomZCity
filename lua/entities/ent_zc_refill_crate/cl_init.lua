include("shared.lua")

local bgCol = Color(18, 22, 28, 210)
local borderCol = Color(65, 80, 98, 230)
local textCol = Color(232, 240, 248, 255)
local subCol = Color(168, 184, 202, 255)
local barBg = Color(34, 41, 50, 220)
local fillCol = Color(110, 200, 120, 240)

local function getCrateLabel(kind)
    if kind == "ar2" then
        return "Big Supply Box"
    end
    return "Small Supply Box"
end

function ENT:Draw()
    self:DrawModel()

    local lply = LocalPlayer()
    if not IsValid(lply) then return end

    local distSqr = lply:GetPos():DistToSqr(self:GetPos())
    if distSqr > (550 * 550) then return end

    local mins, maxs = self:OBBMins(), self:OBBMaxs()
    local pos = self:LocalToWorld(Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, maxs.z + 8))
    local ang = Angle(0, lply:EyeAngles().y - 90, 90)

    local usesLeft = math.max(self:GetUsesLeft(), 0)
    local usesMax = math.max(self:GetUsesMax(), 1)
    local ratio = math.Clamp(usesLeft / usesMax, 0, 1)
    local label = getCrateLabel(self:GetCrateKind())

    cam.Start3D2D(pos, ang, 0.08)
        local w, h = 260, 74
        local x, y = -w * 0.5, -h

        draw.RoundedBox(8, x, y, w, h, bgCol)
        surface.SetDrawColor(borderCol)
        surface.DrawOutlinedRect(x, y, w, h, 1)

        draw.SimpleText(label, "DermaDefaultBold", x + 10, y + 8, textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.format("Uses Left: %d / %d", usesLeft, usesMax), "DermaDefault", x + w - 10, y + 8, subCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        local barX, barY = x + 10, y + 36
        local barW, barH = w - 20, 16
        draw.RoundedBox(4, barX, barY, barW, barH, barBg)
        draw.RoundedBox(4, barX + 1, barY + 1, (barW - 2) * ratio, barH - 2, fillCol)
    cam.End3D2D()
end
