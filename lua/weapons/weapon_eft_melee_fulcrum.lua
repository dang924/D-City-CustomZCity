if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "ER FULCRUM BAYONET"
SWEP.Instructions = "Following on from the successful FULCRUM knife, Extrema Ratio developed a bayonet version of that design. Like the original FULCRUM, this bayonet is extremely versatile and strong. The tanto-shaped blade allows for large amounts of work and wear while still keeping a sharp edge at its exceedingly sturdy tip. This feature, combined with a sharp false edge, makes the knife retain sufficient combat penetration capability to engage targets covered in heavy clothing, padding, or soft ballistic protections. Thanks to its weight and top-heavy balancing, the FULCRUM BAYONET blade is suitable for hard work on the field."
SWEP.Category = "Weapons - EFT Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/weapons/arc9/darsu_eft/w_melee_fulcrum.mdl"
SWEP.WorldModelReal = "models/weapons/arc9/darsu_eft/c_melee_fulcrum.mdl"
SWEP.DontChangeDropped = true
SWEP.modelscale = 1.0
SWEP.modelscale2 = 1
SWEP.BleedMultiplier = 1.5
SWEP.PainMultiplier = 1.8

SWEP.DamagePrimary = 16
SWEP.DamageSecondary = 8

SWEP.setlh = true
SWEP.setrh = true
SWEP.TwoHanded = false

SWEP.basebone = 78

SWEP.HoldPos = Vector(-4,3,-1)
SWEP.HoldAng = Angle(0,0,0)

SWEP.SuicidePos = Vector(-10, 5, -7)
SWEP.SuicideAng = Angle(-30, 0, 0)
SWEP.SuicideCutVec = Vector(-1, -5, 1)
SWEP.SuicideCutAng = Angle(10, 0, 0)
SWEP.SuicideTime = 0.5
SWEP.CanSuicide = true
SWEP.SuicideNoLH = true
SWEP.SuicidePunchAng = Angle(5, -15, 0)

SWEP.BreakBoneMul = 0.25
SWEP.AttackPos = Vector(0,0,0)
SWEP.AttackingPos = Vector(0,0,0)

SWEP.weaponPos = Vector(3.3,0.4,2)
SWEP.weaponAng = Angle(330,160,-150)

SWEP.HoldType = "melee"

--SWEP.InstantPainMul = 0.25

--models/weapons/gleb/c_knife_t.mdl
if CLIENT then
	SWEP.WepSelectIcon = Material("entities/arc9_eft_melee_fulcrum.png")
	SWEP.IconOverride = "entities/arc9_eft_melee_fulcrum.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.BreakBoneMul = 0.5
SWEP.ImmobilizationMul = 0.45
SWEP.StaminaMul = 0.5
SWEP.HadBackBonus = true

SWEP.attack_ang = Angle(0,0,0)
function SWEP:Initialize()
    self.attackanim = 0
    self.sprintanim = 0
    self.animtime = 0
    self.animspeed = 1
    self.reverseanim = false
    self.Initialzed = true
    self:PlayAnim("idle",10,true)

    self:SetHold(self.HoldType)

    self:InitAdd()
end

SWEP.AttackTime = 0.2
SWEP.AnimTime1 = 0.7
SWEP.WaitTime1 = 0.35

SWEP.AnimTime2 = 0.7
SWEP.WaitTime2 = 0.7

SWEP.AnimList = {
    ["idle"] = "idle",
    ["deploy"] = "draw",
    ["attack"] = "fire2",
    ["attack2"] = "fire1",
}

function SWEP:Reload()
    if SERVER then
        if self:GetOwner():KeyPressed(IN_ATTACK) then
            self:SetNetVar("mode", not self:GetNetVar("mode"))
            self:GetOwner():ChatPrint("Changed mode to "..(self:GetNetVar("mode") and "slash." or "stab."))
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

SWEP.AttackTimeLength = 0.15
SWEP.Attack2TimeLength = 0.1

SWEP.AttackRads = 35
SWEP.AttackRads2 = 65

SWEP.SwingAng = -90
SWEP.SwingAng2 = 0

SWEP.MultiDmg1 = false
SWEP.MultiDmg2 = true

SWEP.AttackSwing = "weapons/darsu_eft/melee/knife_bayonet_swing1.ogg" --!! заменить звуки
SWEP.AttackHit = "weapons/darsu_eft/melee/knife_bayonet_hit1.ogg"
SWEP.Attack2Hit = "weapons/darsu_eft/melee/knife_bayonet_hit2.ogg"
SWEP.AttackHitFlesh = "weapons/darsu_eft/melee/body1.ogg"
SWEP.Attack2HitFlesh = "weapons/darsu_eft/melee/body2.ogg"
SWEP.DeploySnd = "weapons/darsu_eft/knife_bayonet_equip.ogg"