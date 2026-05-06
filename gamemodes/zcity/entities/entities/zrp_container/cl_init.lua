-- cl_init.lua — ZRP container entity client rendering.

local CLR_NORMAL  = Color(255, 255, 255, 255)
local CLR_LOOTED  = Color(100, 100, 100, 180)
local CLR_OUTLINE = Color(60, 200, 120, 200)
local OUTLINE_MAT = Material("models/debug/debugwhite")

function ENT:Initialize()
    -- Ensure the model is set from the networked var.
    local mdl = self:GetZRP_Model()
    if mdl and mdl ~= "" then
        self:SetModel(mdl)
    end
end

function ENT:Draw()
    -- Draw the prop with a colour overlay depending on loot state.
    if self:GetLooted() then
        render.SetColorModulation(0.35, 0.35, 0.35)
        self:DrawModel()
        render.SetColorModulation(1, 1, 1)
    else
        self:DrawModel()
    end

    -- Proximity outline: show when a live player is within use range.
    local lply = LocalPlayer()
    if not IsValid(lply) or not lply:Alive() then return end
    if lply:GetPos():DistToSqr(self:GetPos()) > (96 * 96) then return end
    if self:GetLooted() then return end

    -- Draw a simple overlay hint via 3D2D text.
    local pos = self:GetPos() + Vector(0, 0, self:BoundingRadius() + 8)
    local ang = lply:EyeAngles()
    ang.p = 0
    ang.r = 0

    cam.Start3D2D(pos, ang, 0.08)
        draw.SimpleTextOutlined(
            "[E] Open",
            "DermaDefaultBold",
            0, 0,
            CLR_OUTLINE,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
            1, Color(0, 0, 0, 180)
        )
        -- Timer if looted.
    cam.End3D2D()
end

-- Show reset countdown above container if it's been looted.
function ENT:Think()
    if not self:GetLooted() then return end
    local resetAt = self:GetResetAt()
    if resetAt <= 0 then return end
    -- Clientside Think is optional; the countdown is displayed in Draw3D2D below.
end

-- Additional 3D2D: reset timer label when looted and player is near.
local function FormatTime(secs)
    secs = math.max(0, math.floor(secs))
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

hook.Add("PostDrawTranslucentRenderables", "ZRP_ContainerTimers", function()
    for _, ent in ipairs(ents.FindByClass("zrp_container")) do
        if not IsValid(ent) or not ent:GetLooted() then continue end
        local resetAt = ent:GetResetAt()
        if resetAt <= 0 then continue end

        local lply = LocalPlayer()
        if not IsValid(lply) then continue end
        if lply:GetPos():DistToSqr(ent:GetPos()) > (256 * 256) then continue end

        local remaining = resetAt - CurTime()
        if remaining < 0 then continue end

        local pos = ent:GetPos() + Vector(0, 0, ent:BoundingRadius() + 14)
        local ang = lply:EyeAngles()
        ang.p = 0
        ang.r = 0

        cam.Start3D2D(pos, ang, 0.07)
            draw.SimpleTextOutlined(
                "Resets in " .. FormatTime(remaining),
                "DermaDefault",
                0, 0,
                Color(200, 160, 60, 220),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                1, Color(0, 0, 0, 160)
            )
        cam.End3D2D()
    end
end)
