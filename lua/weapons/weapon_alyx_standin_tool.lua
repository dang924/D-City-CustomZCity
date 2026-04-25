if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "Alyx Stand-In Tool"
SWEP.Author = "GitHub Copilot"
SWEP.Instructions = "Primary: use aimed scripted_sequence | Reload: browser | Secondary: cancel"
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
    self:SetNextPrimaryFire(CurTime() + 0.4)

    if CLIENT and IsFirstTimePredicted() then
        RunConsoleCommand("zc_alyx_standin_activate_look")
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.4)

    if CLIENT and IsFirstTimePredicted() then
        RunConsoleCommand("zc_alyx_standin_stop")
    end
end

function SWEP:Reload()
    self:SetNextPrimaryFire(CurTime() + 0.2)
    self:SetNextSecondaryFire(CurTime() + 0.2)

    if CLIENT and IsFirstTimePredicted() then
        RunConsoleCommand("zc_alyx_standin_browser")
    end

    return true
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    return true
end