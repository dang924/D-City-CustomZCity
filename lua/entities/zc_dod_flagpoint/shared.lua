ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "DoD Flag Point"
ENT.Category = "ZCity DoD"
ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:SetFlagOwnerState(owner)
    self:SetNWInt("DODFlagOwner", tonumber(owner) or -1)
end

function ENT:GetFlagOwnerState()
    return self:GetNWInt("DODFlagOwner", -1)
end

function ENT:SetFlagName(name)
    self:SetNWString("DODFlagName", tostring(name or "Flag"))
end

function ENT:GetFlagName()
    return self:GetNWString("DODFlagName", "Flag")
end

function ENT:SetCaptureRadius(radius)
    self:SetNWFloat("DODFlagRadius", tonumber(radius) or 200)
end

function ENT:GetCaptureRadius()
    return self:GetNWFloat("DODFlagRadius", 200)
end

function ENT:SetInitialOwner(owner)
    self:SetNWInt("DODFlagInitOwner", tonumber(owner) or -1)
end

function ENT:GetInitialOwner()
    return self:GetNWInt("DODFlagInitOwner", -1)
end
