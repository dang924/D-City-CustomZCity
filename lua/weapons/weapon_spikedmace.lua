if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "spikedmace"
SWEP.Instructions = ""
SWEP.Category = "Weapons - Age of Chivalry"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/weapons/ageofchivalry/w_spikedmace.mdl"
SWEP.WorldModelReal = "models/weapons/ageofchivalry/c_spikedmace.mdl"
SWEP.WorldModelExchange = false
SWEP.ViewModel = ""

SWEP.bloodID = 1

SWEP.HoldType = "melee"
SWEP.weight = 1.5

SWEP.HoldPos = Vector(-12,-1,-12)
SWEP.HoldAng = Angle(-19,0,-22)

SWEP.AttackTime = 0.45
SWEP.AnimTime1 = 0.65
SWEP.WaitTime1 = 0.95
SWEP.ViewPunch1 = Angle(1,2,0)

SWEP.Attack2Time = 0.3
SWEP.AnimTime2 = 0.8
SWEP.WaitTime2 = 0.8
SWEP.ViewPunch2 = Angle(0,0,-2)

SWEP.attack_ang = Angle(0,0,0)
SWEP.sprint_ang = Angle(15,0,0)

SWEP.basebone = 94

SWEP.weaponPos = Vector(0,0,0)
SWEP.weaponAng = Angle(0,0,0)

SWEP.AnimList = {
    ["idle"] = "Idle",
    ["deploy"] = "Draw",
    ["attack"] = "swing1",
    ["attack2"] = "stab",
}

if CLIENT then
	SWEP.WepSelectIcon = Material("entities/aoc_spikedmace.png")
	SWEP.IconOverride = "entities/aoc_spikedmace.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.setlh = false
SWEP.setrh = true
SWEP.TwoHanded = false

SWEP.AttackHit = "Canister.ImpactHard"
SWEP.Attack2Hit = "Canister.ImpactHard"
SWEP.AttackHitFlesh = "Flesh.ImpactHard"
SWEP.Attack2HitFlesh = "Flesh.ImpactHard"
SWEP.DeploySnd = "physics/wood/wood_plank_impact_soft2.wav"

SWEP.AttackPos = Vector(0,0,0)

SWEP.DamageType = DMG_SLASH
SWEP.DamagePrimary = 25
SWEP.DamageSecondary = 18

SWEP.PenetrationPrimary = 4
SWEP.PenetrationSecondary = 4

SWEP.MaxPenLen = 2

SWEP.PenetrationSizePrimary = 2
SWEP.PenetrationSizeSecondary = 2

SWEP.StaminaPrimary = 25
SWEP.StaminaSecondary = 15

SWEP.AttackLen1 = 55
SWEP.AttackLen2 = 30

SWEP.NoHolster = true

function SWEP:CanSecondaryAttack()
    return false
end

SWEP.AttackTimeLength = 0.155
SWEP.Attack2TimeLength = 0.1

SWEP.AttackRads = 85
SWEP.AttackRads2 = 0

SWEP.SwingAng = 180
SWEP.SwingAng2 = 0

SWEP.MinSensivity = 0.5