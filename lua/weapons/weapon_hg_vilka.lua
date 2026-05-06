if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_melee"

SWEP.PrintName = "Fork"

SWEP.Instructions = "говно чистить"

SWEP.Category = "Weapons - Melee"

SWEP.Spawnable = true

SWEP.AdminOnly = true

SWEP.HoldType = "melee"



SWEP.WorldModel = "models/props_junk/glassbottle01a_chunk01a.mdl"

SWEP.WorldModelReal = "models/weapons/salat/reanim/c_s&wch0014.mdl"

SWEP.WorldModelExchange = "models/fork/fork.mdl"



SWEP.BreakBoneMul = 0.1



SWEP.AnimTime1 = 1.0

SWEP.AttackTime = 0.2

SWEP.WaitTime1 = 0.5



if CLIENT then

	SWEP.WepSelectIcon = Material("vgui/icons/ico_botle_broken.png")

	SWEP.IconOverride = "vgui/icons/ico_botle_broken.png"

	SWEP.BounceWeaponIcon = false

end



SWEP.setlh = false

SWEP.setrh = true



SWEP.NoHolster = true



SWEP.DamagePrimary = 9



SWEP.PenetrationPrimary = 1.3



SWEP.StaminaPrimary = 15



SWEP.BleedMultiplier = 1.5



SWEP.AttackLen1 = 40



SWEP.AttackHit = "vilka/2.wav"

SWEP.AttackHitFlesh = "bratishka/argh.wav"



SWEP.DeploySnd = "zel/chisti.wav"



SWEP.DamageType = DMG_SLASH

SWEP.PainMultiplier = .4

SWEP.MaxPenLen = 0.7

SWEP.PenetrationSizePrimary = 1.2



SWEP.AnimList = {

    ["idle"] = "idle",

    ["deploy"] = "draw",

    ["attack"] = "stab",

    ["attack2"] = "midslash1",

    ["duct_cut"] = "cut",

    ["inspect"] = "inspect"

}



SWEP.HoldPos = Vector(-4,0,-1)

SWEP.HoldAng = Angle(0,0,0)

SWEP.weaponPos = Vector(-0,3,1.2)

SWEP.weaponAng = Angle(0,270,100)

SWEP.basebone = 39



function SWEP:CanSecondaryAttack()

    return false

end



SWEP.AttackPos = Vector(-3,8,-20)



function SWEP:PrimaryAttackAdd(ent, trace)

end



SWEP.AttackTimeLength = 0.15

SWEP.Attack2TimeLength = 0.01



SWEP.AttackRads = 65

SWEP.AttackRads2 = 0



SWEP.SwingAng = -35

SWEP.SwingAng2 = 0