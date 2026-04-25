if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "Sequence Helper Tool"
SWEP.Author = "GitHub Copilot"
SWEP.Instructions = "Primary: set corner A | Secondary: set corner B | Reload: browser"
SWEP.Category = "ZCity Debug"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
SWEP.HoldType = "pistol"
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.2)

    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or not ZC_SequenceHelper or not ZC_SequenceHelper.SetCorner then return end

    ZC_SequenceHelper.SetCorner(owner, "cornerA", owner:GetEyeTrace().HitPos)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.2)

    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or not ZC_SequenceHelper or not ZC_SequenceHelper.SetCorner then return end

    ZC_SequenceHelper.SetCorner(owner, "cornerB", owner:GetEyeTrace().HitPos)
end

function SWEP:Reload()
    self:SetNextPrimaryFire(CurTime() + 0.2)
    self:SetNextSecondaryFire(CurTime() + 0.2)

    if CLIENT and IsFirstTimePredicted() then
        RunConsoleCommand("zc_sequence_helper_browser")
    end

    return true
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)

    if CLIENT and IsFirstTimePredicted() then
        RunConsoleCommand("zc_sequence_helper_browser")
    end

    return true
end