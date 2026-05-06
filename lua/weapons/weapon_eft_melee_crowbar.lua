if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "Freeman crowbar"
SWEP.Instructions = "Designed as a tool for working with hard surfaces. Materials and construction are designed to provide optimal impact and strength. The head of the axe is made of 6AL4V titanium with a thickness of 2.85 inches."
SWEP.Category = "Weapons - EFT Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/weapons/arc9/darsu_eft/w_melee_crowbar.mdl"
SWEP.WorldModelReal = "models/weapons/arc9/darsu_eft/c_melee_crowbar.mdl"
SWEP.ViewModel = ""
SWEP.weight = 1.5

SWEP.CanSuicide = false


SWEP.NoHolster = true

SWEP.HoldType = "revolver"

SWEP.DamageType = DMG_SLASH

SWEP.HoldPos = Vector(-5,4,0)
SWEP.HoldAng = Angle(0,0,0)

SWEP.AttackTime = 0.42
SWEP.AnimTime1 = 1.2
SWEP.WaitTime1 = 1.3
SWEP.ViewPunch1 = Angle(1, 1, -1)

SWEP.Attack2Time = 0.4
SWEP.AnimTime2 = 1.0
SWEP.WaitTime2 = 0.8
SWEP.ViewPunch2 = Angle(0, 0, -2)

SWEP.attack_ang = Angle(0, 0, 0)
SWEP.sprint_ang = Angle(15, 0, 0)

SWEP.basebone = 75

SWEP.weaponPos = Vector(5,8,13)
SWEP.weaponAng = Angle(200,10,30)

SWEP.DamageType = DMG_CLUB
SWEP.DamagePrimary = 35
SWEP.DamageSecondary = 22

SWEP.PenetrationPrimary = 3
SWEP.PenetrationSecondary = 5

SWEP.MaxPenLen = 4

SWEP.PenetrationSizePrimary = 3
SWEP.PenetrationSizeSecondary = 1.25

SWEP.StaminaPrimary = 25
SWEP.StaminaSecondary = 35

SWEP.AttackLen1 = 35
SWEP.AttackLen2 = 55

SWEP.AnimList = {
    ["idle"] = "idle",
    ["deploy"] = "draw",
    ["attack"] = "fire1_axe",
    ["attack2"] = "fire2",
}

if CLIENT then
    SWEP.WepSelectIcon = Material("entities/arc9_eft_melee_crowbar.png")
    SWEP.IconOverride = "entities/arc9_eft_melee_crowbar.png"
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

SWEP.AttackPos = Vector(0, 0, 0)



SWEP.AttackTimeLength = 0.10
SWEP.Attack2TimeLength = 0.01

SWEP.AttackRads = 65
SWEP.AttackRads2 = 0

SWEP.SwingAng = -15
SWEP.SwingAng2 = 0

function SWEP:Reload()
    if SERVER then
        if self:GetOwner():KeyPressed(IN_ATTACK) then
            self:SetNetVar("mode", not self:GetNetVar("mode"))
            self:GetOwner():ChatPrint("Changed mode to "..(self:GetNetVar("mode") and "bash." or "slash."))
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

function SWEP:PrimaryAttack()
    if hg.KeyDown(self:GetOwner(),IN_USE) then
        local tr = self.Owner:GetEyeTrace()
        if IsValid(tr.Entity) and string.find(string.lower(tr.Entity:GetClass()), "door") and self:GetOwner():GetPos():Distance(tr.Entity:GetPos()) <= 80 then
            local locked = false
            if tr.Entity.GetInternalVariable then
                locked = tr.Entity:GetInternalVariable("m_bLocked")
            end
            if not locked then
                return
            end
            if not self.BreakingDoor then
                self.BreakingDoor = true
                self.BreakStartTime = CurTime()
                self.BreakDuration = math.random(15, 20)
                self.DoorEntity = tr.Entity
                self.NextBreakSound = CurTime() + math.Rand(1, 2)
            end
            return
        end
    end
    self.BaseClass.PrimaryAttack(self)
end

function SWEP:PrimaryAttackAdd(ent)
    if hgIsDoor(ent) and math.random(10) > 8 then
        hgBlastThatDoor(ent,self:GetOwner():GetAimVector() * 30 + self:GetOwner():GetVelocity())
    end
end

function SWEP:Think()
    if self.BreakingDoor then
        if not (hg.KeyDown(self:GetOwner(),IN_USE) and hg.KeyDown(self:GetOwner(),IN_ATTACK)) then
            self.BreakingDoor = false
        elseif not (IsValid(self.DoorEntity) and self:GetOwner():GetPos():Distance(self.DoorEntity:GetPos()) <= 80) then
            self.BreakingDoor = false
        else
            if not self.NextBreakSound then
                self.NextBreakSound = CurTime() + math.Rand(1, 2)
            end
            if CurTime() >= self.NextBreakSound then
                if IsValid(self.DoorEntity) then
                    self.DoorEntity:EmitSound("physics/wood/wood_crate_break2.wav", 75, 100)
                end
                self.NextBreakSound = CurTime() + math.Rand(1, 2)
            end
            if CurTime() >= self.BreakStartTime + self.BreakDuration then
                if IsValid(self.DoorEntity) then
                    self.DoorEntity:Fire("Unlock", "", 0)
                    self.DoorEntity:Fire("Open", "", 0)
                end
                self.BreakingDoor = false
            end
        end
    end
    self.BaseClass.Think(self)
end

SWEP.MinSensivity = 0.6