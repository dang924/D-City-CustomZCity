if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "UVSR Taiga-1"
SWEP.Instructions = "UVSR 'Device for carrying out rescue operations' Taiga-1. A truly versatile survival tool. It is a weapon and a shovel and an axe and everything you can imagine. It was developed and produced in the USSR for various agencies."
SWEP.Category = "Weapons - EFT Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Damage = 25
SWEP.Damage = 25
SWEP.HoldType = "melee"

SWEP.SuicidePos = Vector(28, 6, -31)
SWEP.SuicideAng = Angle(-70, -180, 90)
SWEP.SuicideCutVec = Vector(3, -6, 3)
SWEP.SuicideCutAng = Angle(10, 0, 0)
SWEP.SuicideTime = 0.5
SWEP.SuicideSound = "player/flesh/flesh_bullet_impact_03.wav"
SWEP.CanSuicide = true
SWEP.SuicideNoLH = true
SWEP.SuicidePunchAng = Angle(5, -15, 0)

SWEP.Weight = 0
SWEP.weight = 1

SWEP.WorldModel = "models/weapons/arc9/darsu_eft/w_melee_taiga.mdl"
SWEP.WorldModelReal = "models/weapons/arc9/darsu_eft/c_melee_taiga.mdl"
SWEP.WorldModelExchange = false
SWEP.DontChangeDropped = true
SWEP.ViewModel = ""

SWEP.bloodID = 3

SWEP.HoldPos = Vector(-7,4,0)
SWEP.HoldAng = Angle(0,0,0)

SWEP.AttackTime = 0.37
SWEP.AnimTime1 = 0.9
SWEP.WaitTime1 = 0.9
SWEP.AttackLen1 = 45
SWEP.ViewPunch1 = Angle(1,1,0)

SWEP.Attack2Time = 0.4
SWEP.AnimTime2 = 0.9
SWEP.WaitTime2 = 0.9
SWEP.AttackLen2 = 30
SWEP.ViewPunch2 = Angle(0,2,-2)

SWEP.attack_ang = Angle(0,0,0)
SWEP.sprint_ang = Angle(15,0,0)

SWEP.basebone = 94

SWEP.weaponPos = Vector(0,5,-2)
SWEP.weaponAng = Angle(0,-90,0)

SWEP.AnimAlwaysBack = true

SWEP.AnimList = {
    ["idle"] = "idle",
    ["deploy"] = "draw",
    ["attack"] = "fire1",
    ["attack2"] = "fire2",
}

if CLIENT then
	SWEP.WepSelectIcon = Material("entities/arc9_eft_melee_taiga.png")
	SWEP.IconOverride = "entities/arc9_eft_melee_taiga.png"
	SWEP.BounceWeaponIcon = false
end


SWEP.setlh = true
SWEP.setrh = true
SWEP.TwoHanded = false

SWEP.AttackSwing = "weapons/darsu_eft/melee/knife_bayonet_swing1.ogg" --!! заменить звуки
SWEP.AttackHit = "weapons/darsu_eft/melee/knife_bayonet_hit1.ogg"
SWEP.Attack2Hit = "weapons/darsu_eft/melee/knife_bayonet_hit2.ogg"
SWEP.AttackHitFlesh = "weapons/darsu_eft/melee/body1.ogg"
SWEP.Attack2HitFlesh = "weapons/darsu_eft/melee/body2.ogg"
SWEP.DeploySnd = "weapons/darsu_eft/knife_bayonet_equip.ogg"

SWEP.AttackPos = Vector(0,0,0)

SWEP.DamageType = DMG_SLASH
SWEP.DamagePrimary = 20
SWEP.DamageSecondary = 30
SWEP.BleedMultiplier = 1.9
SWEP.PainMultiplier = 1.3

SWEP.PenetrationPrimary = 10
SWEP.PenetrationSecondary = 13

SWEP.MaxPenLen = 6

SWEP.PenetrationSizePrimary = 2
SWEP.PenetrationSizeSecondary = 3

SWEP.StaminaPrimary = 20
SWEP.StaminaSecondary = 15

function SWEP:Reload()
    if SERVER then
        if self:GetOwner():KeyPressed(IN_ATTACK) then
            self:SetNetVar("mode", not self:GetNetVar("mode"))
            self:GetOwner():ChatPrint("Changed mode to "..(self:GetNetVar("mode") and "stab." or "slash."))
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

SWEP.AttackTimeLength = 0.12
SWEP.Attack2TimeLength = 0.05

SWEP.AttackRads = 75
SWEP.AttackRads2 = 0

SWEP.SwingAng = -90
SWEP.SwingAng2 = 0

SWEP.MinSensivity = 0.55