if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "MPL-50 entr. tool"
SWEP.Instructions = "MPL-50 (Malaya Pekhotnaya Lopata 50 - Small Infantry Spade 50) is a small spade invented by a Danish officer Mads Johan Buch Linnemann in 1869. While nominally an entrenching tool, MPL-50 saw a wide range of wartime applications ranging from a close quarters combat weapon to a cooking utensil."
SWEP.Category = "Weapons - EFT Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/weapons/arc9/darsu_eft/w_melee_mpl40.mdl"
SWEP.WorldModelReal = "models/weapons/arc9/darsu_eft/c_melee_mpl40.mdl"
SWEP.ViewModel = ""

SWEP.NoHolster = true

SWEP.BreakBoneMul = 0.35

SWEP.HoldType = "melee"
SWEP.TwoHanded = false

SWEP.HoldPos = Vector(-5,4,0)
SWEP.HoldAng = Angle(0,0,0)
SWEP.weight = 0.6

SWEP.AttackTime = 0.25
SWEP.AnimTime1 = 0.8
SWEP.WaitTime1 = 0.95
SWEP.ViewPunch1 = Angle(1,2,0)

SWEP.Attack2Time = 0.3
SWEP.AnimTime2 = 1
SWEP.WaitTime2 = 0.8
SWEP.ViewPunch2 = Angle(0,0,-2)

SWEP.attack_ang = Angle(0,0,0)
SWEP.sprint_ang = Angle(15,0,0)

SWEP.basebone = 94

SWEP.weaponPos = Vector(0,0,3)
SWEP.weaponAng = Angle(-90,0,0)

SWEP.AnimList = {
    ["idle"] = "idle",
    ["deploy"] = "draw",
    ["attack"] = "fire1_axe",
    ["attack2"] = "fire2_axe",
    ["inspect"] = "inspect_axe",
}

if CLIENT then
	SWEP.WepSelectIcon = Material("entities/arc9_eft_melee_mpl50.png")
	SWEP.IconOverride = "entities/arc9_eft_melee_mpl50.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.setlh = true
SWEP.setrh = true


SWEP.AttackSwing = "weapons/darsu_eft/melee/knife_bayonet_swing1.ogg" --!! заменить звуки
SWEP.AttackHit = "weapons/darsu_eft/melee/knife_bayonet_hit1.ogg"
SWEP.Attack2Hit = "weapons/darsu_eft/melee/knife_bayonet_hit2.ogg"
SWEP.AttackHitFlesh = "weapons/darsu_eft/melee/body1.ogg"
SWEP.Attack2HitFlesh = "weapons/darsu_eft/melee/body2.ogg"
SWEP.DeploySnd = "weapons/darsu_eft/knife_bayonet_equip.ogg"

SWEP.AttackPos = Vector(0,0,0)

SWEP.DamageType = DMG_SLASH
SWEP.DamagePrimary = 33
SWEP.DamageSecondary = 13
SWEP.BleedMultiplier = 1.1
SWEP.BreakBoneMul = 1.05

SWEP.PenetrationPrimary = 4
SWEP.PenetrationSecondary = 3

SWEP.MaxPenLen = 6

SWEP.PenetrationSizePrimary = 2
SWEP.PenetrationSizeSecondary = 2

SWEP.StaminaPrimary = 20
SWEP.StaminaSecondary = 15

SWEP.AttackLen1 = 36
SWEP.AttackLen2 = 30

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

SWEP.AttackTimeLength = 0.155
SWEP.Attack2TimeLength = 0.01

SWEP.AttackRads = 100
SWEP.AttackRads2 = 0

SWEP.SwingAng = -175
SWEP.SwingAng2 = 0