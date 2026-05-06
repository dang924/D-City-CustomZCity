if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "Old hand scythe"
SWEP.Instructions = "An old hand scythe with a chipped handle. In the days of the fall harvest, it is used to gather the bloody haul."
SWEP.Category = "Weapons - EFT Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Weight = 0

SWEP.WorldModel = "models/weapons/arc9/darsu_eft/w_melee_scythe.mdl"
SWEP.WorldModelReal = "models/weapons/arc9/darsu_eft/c_melee_hultafors.mdl"
SWEP.WorldModelExchange = "models/weapons/arc9/darsu_eft/w_melee_scythe.mdl"
SWEP.ViewModel = ""

SWEP.HoldType = "revolver"

SWEP.weight = 3.5

SWEP.HoldPos = Vector(-2,-2,1)
SWEP.HoldAng = Angle(0,0,0)

SWEP.AttackTime = 0.63
SWEP.AnimTime1 = 2.2
SWEP.WaitTime1 = 1.5
SWEP.ViewPunch1 = Angle(1,2,0)

SWEP.Attack2Time = 0.8
SWEP.AnimTime2 = 2.3
SWEP.WaitTime2 = 1.3
SWEP.ViewPunch2 = Angle(0,0,-2)
SWEP.BreakBoneMul = 1.15
SWEP.attack_ang = Angle(0,0,-15)
SWEP.sprint_ang = Angle(15,0,0)

SWEP.basebone = 74

SWEP.weaponPos = Vector(1.4,-0.9,-2)
SWEP.weaponAng = Angle(202,0,-0)

SWEP.DamageType = DMG_SLASH
SWEP.DamagePrimary = 30
SWEP.DamageSecondary = 40
SWEP.BleedMultiplier = 33.8
SWEP.PainMultiplier = 2.0

SWEP.PenetrationPrimary = 10
SWEP.PenetrationSecondary = 37

SWEP.MaxPenLen = 6

SWEP.PenetrationSizePrimary = 0.5
SWEP.PenetrationSizeSecondary = 1

SWEP.StaminaPrimary = 40
SWEP.StaminaSecondary = 45

SWEP.AttackLen1 = 70
SWEP.AttackLen2 = 75

SWEP.AnimList = {
    ["idle"] = "idle",
    ["deploy"] = "draw",
    ["attack"] = "fire1",
    ["attack2"] = "fire2",
}

if CLIENT then
	SWEP.WepSelectIcon = Material("entities/arc9_eft_melee_scythe.png")
	SWEP.IconOverride = "entities/arc9_eft_melee_scythe.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.setlh = true
SWEP.setrh = true
SWEP.TwoHanded = true

SWEP.AttackPos = Vector(0,0,0)

function SWEP:CanSecondaryAttack()
    self.DamageType = DMG_SLASH
    self.AttackSwing = "weapons/darsu_eft/melee/scythe_whoosh_02.ogg"
    return true
end

function SWEP:CanPrimaryAttack()
    self.DamageType = DMG_SLASH
    return true
end

function SWEP:PrimaryAttackAdd(ent)
    if hgIsDoor(ent) and math.random(7) > 3 then
        hgBlastThatDoor(ent,self:GetOwner():GetAimVector() * 50 + self:GetOwner():GetVelocity())
    end
end

function SWEP:CustomBlockAnim(addPosLerp, addAngLerp)
    addPosLerp.z = addPosLerp.z + (self:GetBlocking() and -2 or 0)
    addPosLerp.x = addPosLerp.x + (self:GetBlocking() and 1 or 0)
    addPosLerp.y = addPosLerp.y + (self:GetBlocking() and -5 or 0)
    addAngLerp.p = addAngLerp.p + (self:GetBlocking() and -20 or 0)
    addAngLerp.r = addAngLerp.r + (self:GetBlocking() and 45 or 0)

    return true
end

function SWEP:OwnerChanged()
    if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
        self:PlayAnim("deploy",3.5,false,nil,false)
        self:SetHold(self.HoldType)
        timer.Simple(0,function() self.picked = true end)
    else
        self:SetInAttack(false)
        timer.Simple(0,function() self.picked = nil end)
    end
end

SWEP.NoHolster = true

SWEP.AttackTimeLength = 0.155
SWEP.Attack2TimeLength = 0.155

SWEP.AttackRads = 95
SWEP.AttackRads2 = 0

SWEP.SwingAng = -165
SWEP.SwingAng2 = 0

SWEP.MinSensivity = 0.87

SWEP.AttackSwing = "weapons/darsu_eft/melee/scythe_whoosh_01.ogg" --!! заменить звуки
SWEP.AttackHit = "weapons/darsu_eft/melee/hammer_hit_wall1.ogg"
SWEP.Attack2Hit = "weapons/darsu_eft/melee/hammer_hit_wall2.ogg"
SWEP.AttackHitFlesh = "weapons/darsu_eft/melee/body1.ogg"
SWEP.Attack2HitFlesh = "weapons/darsu_eft/melee/body2.ogg"
SWEP.DeploySnd = "weapons/darsu_eft/melee/hammer_charge3.ogg"