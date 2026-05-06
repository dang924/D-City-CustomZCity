if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "PR-Taran baton"
SWEP.Instructions = "The PR-Taran baton with side handle is used by law enforcement agencies for protection and crowd control."
SWEP.Category = "Weapons - EFT Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/weapons/arc9/darsu_eft/w_melee_taran.mdl"
SWEP.WorldModelReal = "models/weapons/arc9/darsu_eft/c_melee_taran.mdl"
SWEP.ViewModel = ""

SWEP.HoldType = "melee"
SWEP.weight = 0.6

SWEP.HoldPos = Vector(-3,4,0)
SWEP.HoldAng = Angle(0,0,0)

SWEP.AttackTime = 0.37
SWEP.AnimTime1 = 0.9
SWEP.WaitTime1 = 0.9
SWEP.AttackLen1 = 45
SWEP.ViewPunch1 = Angle(1,1,0)

SWEP.Attack2Time = 0.6
SWEP.AnimTime2 = 1.2
SWEP.WaitTime2 = 0.9
SWEP.AttackLen2 = 30
SWEP.ViewPunch2 = Angle(0,2,-2)

SWEP.AnimAlwaysBack = true

SWEP.attack_ang = Angle(0,0,0)
SWEP.sprint_ang = Angle(15,0,0)

SWEP.basebone = 94

SWEP.weaponPos = Vector(-0.3,0.5,-8)
SWEP.weaponAng = Angle(0,-90,0)

SWEP.DamageType = DMG_CLUB
SWEP.DamagePrimary = 10
SWEP.DamageSecondary = 16
SWEP.BleedMultiplier = 1.3
SWEP.PainMultiplier = 1.5
SWEP.BreakBoneMul = 1.3
SWEP.PenetrationPrimary = 3
SWEP.PenetrationSecondary = 3

SWEP.MaxPenLen = 3

SWEP.PenetrationSizePrimary = 2
SWEP.PenetrationSizeSecondary = 2

SWEP.StaminaPrimary = 12
SWEP.StaminaSecondary = 8

SWEP.AttackLen1 = 55
SWEP.AttackLen2 = 30

SWEP.AnimList = {
    ["idle"] = "idle",
    ["deploy"] = "draw",
    ["attack"] = "fire1_axe",
    ["attack2"] = "fire_voodoo",
}


if CLIENT then
	SWEP.WepSelectIcon = Material("entities/arc9_eft_melee_taran.png")
	SWEP.IconOverride = "entities/arc9_eft_melee_taran.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.setlh = true
SWEP.setrh = true
SWEP.TwoHanded = false

SWEP.AttackSwing = "weapons/darsu_eft/melee/taran_swing_02.ogg" --!! заменить звуки
SWEP.AttackHit = "weapons/darsu_eft/melee/knife_bayonet_hit1.ogg"
SWEP.Attack2Hit = "weapons/darsu_eft/melee/knife_bayonet_hit2.ogg"
SWEP.AttackHitFlesh = "weapons/darsu_eft/melee/body1.ogg"
SWEP.Attack2HitFlesh = "weapons/darsu_eft/melee/body2.ogg"
SWEP.DeploySnd = "weapons/darsu_eft/knife_bayonet_equip.ogg"

SWEP.AttackPos = Vector(0,0,0)

function SWEP:Reload()
    if SERVER then
        if self:GetOwner():KeyPressed(IN_ATTACK) then
            self:SetNetVar("mode", not self:GetNetVar("mode"))
            self:GetOwner():ChatPrint("Changed mode to "..(self:GetNetVar("mode") and "slash2." or "slash."))
        end
    end
end

function SWEP:CanPrimaryAttack()
    if self:GetOwner():KeyDown(IN_RELOAD) then return end
    if not self:GetNetVar("mode") then
        return true
    else
        self.allowsec = true
        self:SecondaryAttack(true)
        self.allowsec = nil
        return false
    end
end

function SWEP:CustomBlockAnim(addPosLerp, addAngLerp)
    return false
end

function SWEP:CanSecondaryAttack()
    return self.allowsec and true or false
end

SWEP.NoHolster = true

function SWEP:PrimaryAttackAdd(ent)
    if hgIsDoor(ent) and math.random(6) > 3 then
        hgBlastThatDoor(ent,self:GetOwner():GetAimVector() * 50 + self:GetOwner():GetVelocity())
    end
end

SWEP.AttackTimeLength = 0.155
SWEP.Attack2TimeLength = 0.1

SWEP.AttackRads = 85
SWEP.AttackRads2 = 0

SWEP.SwingAng = -90
SWEP.SwingAng2 = 0