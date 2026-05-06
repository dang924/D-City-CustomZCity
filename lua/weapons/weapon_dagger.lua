if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "dagger"
SWEP.Instructions = ""
SWEP.Category = "Weapons - Age of Chivalry"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/weapons/ageofchivalry/w_dagger2.mdl"
SWEP.WorldModelReal = "models/weapons/ageofchivalry/c_dagger_onehand.mdl"
SWEP.WorldModelExchange = false

SWEP.HoldPos = Vector(-13,0,-6)
SWEP.HoldAng = Angle(0,0,-32)

SWEP.SuicidePos = Vector(-10, 5, -7)
SWEP.SuicideAng = Angle(-30, 0, 0)
SWEP.SuicideCutVec = Vector(-1, -5, 1)
SWEP.SuicideCutAng = Angle(10, 0, 0)
SWEP.SuicideTime = 0.5
SWEP.CanSuicide = true
SWEP.SuicideNoLH = true
SWEP.SuicidePunchAng = Angle(5, -15, 0)

SWEP.BreakBoneMul = 0.25

SWEP.AnimList = {
    ["idle"] = "idle_03",
    ["deploy"] = "draw",
    ["attack"] = "stab2",
    ["attack2"] = "midslash1",
    ["duct_cut"] = "cut",
    ["inspect"] = "inspect"
}

if CLIENT then
	SWEP.WepSelectIcon = Material("entities/aoc_dagger_onehand.png")
	SWEP.IconOverride = "entities/aoc_dagger_onehand.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.setlh = true
SWEP.setrh = true
SWEP.TwoHanded = false

SWEP.AttackHit = "weapons/knife/knife_hitwall1.wav"
SWEP.Attack2Hit = "snd_jack_hmcd_knifehit.wav"
--
SWEP.DeploySnd = "weapons/knife/knife_deploy1.wav"

SWEP.AttackPos = Vector(0,0,0)
SWEP.DamageType = DMG_SLASH
SWEP.DamagePrimary = 12
SWEP.DamageSecondary = 10

SWEP.PenetrationPrimary = 5
SWEP.PenetrationSecondary = 3
SWEP.BleedMultiplier = 1.5

SWEP.MaxPenLen = 3

SWEP.PainMultiplier = 0.5

SWEP.PenetrationSizePrimary = 1.5
SWEP.PenetrationSizeSecondary = 1

SWEP.StaminaPrimary = 9
SWEP.StaminaSecondary = 12

SWEP.AttackLen1 = 42
SWEP.AttackLen2 = 35

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
    local check = self:GetBlocking() and self:GetWM():GetSequenceName(self:GetWM():GetSequence()) != "cut"
    addPosLerp.z = addPosLerp.z + (check and 2 or 0)
    addPosLerp.x = addPosLerp.x + (check and 0 or 0)
    addPosLerp.y = addPosLerp.y + (check and 3 or 0)
    addAngLerp.r = addAngLerp.r + (check and -15 or 0)
    addAngLerp.y = addAngLerp.y + (check and 8 or 0)
    
    return true
end

function SWEP:CanSecondaryAttack()
    return self.allowsec and true or false
end

SWEP.AttackPos = Vector(0,0,0)
SWEP.AttackingPos = Vector(0,0,0)

SWEP.AttackTime = 0.2
SWEP.AnimTime1 = 0.7
SWEP.WaitTime1 = 0.5

SWEP.Attack2Time = 0.1
SWEP.AnimTime2 = 0.5
SWEP.WaitTime2 = 0.4

SWEP.AttackTimeLength = 0.15
SWEP.Attack2TimeLength = 0.1

SWEP.AttackRads = 80
SWEP.AttackRads2 = 55

SWEP.SwingAng = -90
SWEP.SwingAng2 = 0

SWEP.MultiDmg1 = false
SWEP.MultiDmg2 = true