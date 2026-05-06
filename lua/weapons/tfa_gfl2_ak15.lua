SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "AK15"
SWEP.Author = "."
SWEP.Instructions = "."
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/gfl2_voymastina/c_ak47.mdl"

SWEP.FakePos = Vector(-10, 0, 4)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(3.8,2.1,-27.8)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeAttachment = "1"
SWEP.FakeBodyGroups = "00900080302"
SWEP.ZoomPos = Vector(0, -0.0027, 4.6866)

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.FakeEjectBrassATT = "2"

SWEP.FakeViewBobBone = "CAM_Homefield"

SWEP.FakeReloadSounds = {
    [0.0] = "TFA_GFL2.AK15.RELOAD_RAISE",
    [11 / 30] = "TFA_GFL2.AK15.MAGOUT",
    [30 / 30] = "TFA_GFL2.AK15.RELOAD_SWAP",
    [47 / 30] = "TFA_GFL2.AK15.MAGIN",
    [65 / 30] = "TFA_GFL2.AK15.BOLT",
    [70 / 30] = "TFA_GFL2.AK15.RELOAD_LOWER"
}

SWEP.FakeEmptyReloadSounds = {
    [0.0] = "TFA_GFL2.AK15.RELOAD_RAISE",
    [11 / 30] = "TFA_GFL2.AK15.MAGOUT",
    [30 / 30] = "TFA_GFL2.AK15.RELOAD_SWAP",
    [47 / 30] = "TFA_GFL2.AK15.MAGIN",
    [65 / 30] = "TFA_GFL2.AK15.BOLT",
    [70 / 30] = "TFA_GFL2.AK15.RELOAD_LOWER"
}

SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_ak74_izhmash_6l23_545x39_30.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,1)
SWEP.lmagang2 = Angle(90,0,-90)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEPunchDiv = 70

SWEP.FakeMagDropBone = 57

SWEP.AnimList = {
    ["idle"] = "idle",
    ["reload"] = "reload",
    ["reload_empty"] = "reload",
}

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)

if CLIENT then
    SWEP.FakeReloadEvents = {
        [0.15] = function( self, timeMul )
            self:GetWM():ManipulateBoneScale(55, vecPochtiZero)
            self:GetWM():ManipulateBoneScale(56, vecPochtiZero)
            self:GetWM():ManipulateBoneScale(57, vector_full)
            self:GetWM():ManipulateBoneScale(58, vector_full)
        end,
        [0.16] = function( self, timeMul )
            self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.58 * timeMul)
        end,
        [0.27] = function( self, timeMul )
            self:GetWM():ManipulateBoneScale(57, vector_full)
            self:GetWM():ManipulateBoneScale(58, vector_full)
            self:GetWM():ManipulateBoneScale(55, vector_full)
            self:GetWM():ManipulateBoneScale(56, vector_full)
        end,
        
        [0.40] = function(self,timeMul)
            if self:Clip1() < 1 then
                hg.CreateMag( self, Vector(50,10,10),nil, true )
                self:GetWM():ManipulateBoneScale(57, vecPochtiZero)
                self:GetWM():ManipulateBoneScale(58, vecPochtiZero)
            end
        end,
        [0.85] = function(self,timeMul)
            self:GetWM():ManipulateBoneScale(57, vecPochtiZero)
            self:GetWM():ManipulateBoneScale(58, vecPochtiZero)
        end
    }
end

SWEP.settedGroups = false
function SWEP:ThinkAdd()
    if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
        self:GetWM():SetBodyGroups(self.FakeBodyGroups)
        self.settedGroups = true
    end
end

function SWEP:ModelCreated(model)
    if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
        self:GetWM():ManipulateBoneScale(57, vecPochtiZero)
        self:GetWM():ManipulateBoneScale(58, vecPochtiZero)
        self:GetWM():SetBodyGroups(self.FakeBodyGroups)
    end
end

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

SWEP.weaponInvCategory = 1
SWEP.CustomEjectAngle = Angle(0, 0, 90)
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x39 mm"

SWEP.CustomShell = "762x39"

SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 45
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 35

SWEP.Primary.Sound = {"TFA_GFL2.AK15.FIRE", 85, 90, 100}
SWEP.Primary.SoundFP = {"TFA_GFL2.AK15.FIRE", 85, 90, 100}
SWEP.Primary.SoundEmpty = {"TFA_GFL2.AK15.DRY_FIRE", 75, 100, 105, CHAN_WEAPON, 2}

SWEP.DistSound = "weapons/ak74/ak74_dist.wav"

SWEP.Primary.Wait = 0.085
SWEP.ReloadTime = 5.5
SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1"

SWEP.LocalMuzzlePos = Vector(27.985,-0.25,2.295)
SWEP.LocalMuzzleAng = Angle(-0.2,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.HoldType = "smg"
SWEP.LHandPos = Vector(5.5, 0.5, -4.5) 

SWEP.Penetration = 11
SWEP.Spray = {}
for i = 1, 30 do
    SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 0.5
end

SWEP.WepSelectIcon2 = Material("entities/ak15.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/ak15.png"

SWEP.Ergonomics = 1
SWEP.WorldPos = Vector(5, -0.8, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0.25, -2.1, 28)
SWEP.attAng = Angle(0, 0.4, 0)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(1, -1.5, 0)


SWEP.availableAttachments = {
    sight = {
        ["mountType"] = {"picatinny"},
        ["mount"] = { ["picatinny"] = Vector (-27, 0.1, 2) }, 
        ["mountAngle"] = { ["picatinny"] = Angle(0, 0, 90) },
        [1] = {"optic2", Vector(0, -1.4, 1.8), {}},
        [2] = {"optic5", Vector(0, -1.4, 1.8), {}},
        [3] = {"optic6", Vector(0, -1.5, -1.6), {}},   
    },
    grip = {
        ["mountType"] = "picatinny",
        ["mount"] = Vector(-3, 1.5, -1.2),                
        ["mountAngle"] = Angle(0, 0, 90)                    
    },
    barrel = {
       [1] = {"supressor1", Vector(-6, -0.25, -0.1), {}},
        [2] = {"supressor6", Vector(-6, -0.25, -0.1), {}},
       ["mount"] = Vector(-1.9, 0.6, -0.3),
    }
}

SWEP.weight = 3

SWEP.RHPos = Vector(3,-6,3.5)
SWEP.RHAng = Angle(0,-12,90)

SWEP.LHPos = Vector(5.5, 0.5, -4.5)
SWEP.LHAng = Angle(0, -90, -20)

SWEP.ShootAnimMul = 3
function SWEP:DrawPost()
    local wep = self:GetWeaponEntity()
    if CLIENT and IsValid(wep) then
        self.shooanim = Lerp(FrameTime()*15,self.shooanim or 0,self.ReloadSlideOffset or 0)
        local vec = Vector(0, 1 * self.shooanim, 0)
        wep:ManipulateBonePosition(8,vec,false)
    end
end

SWEP.ReloadAnimLH = {
    Vector(0,0,0), Vector(-1.5,1.5,-8), Vector(-1.5,1.5,-8), Vector(-1.5,1.5,-8),
    Vector(-1,7,-3), Vector(-7,15,-15), Vector(-7,15,-15), Vector(-1,7,-3),
    Vector(-1.5,1.5,-8), Vector(-1.5,1.5,-8), Vector(-1.5,1.5,-8), "fastreload",
    Vector(0,0,0), Vector(0,0,0), Vector(0,0,0), Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
    Vector(0,0,0), Vector(0,0,0), Vector(0,0,0), Vector(0,0,0), Vector(0,0,0),
    Vector(0,0,0), Vector(0,0,0), Vector(0,0,0), Vector(0,0,0), Vector(0,0,0),
    Vector(0,0,0), Vector(0,0,0), Vector(0,0,0), Vector(0,0,0), Vector(0,0,0),
    Vector(0,0,0), Vector(0,0,0), Vector(0,0,2), Vector(8,1,2), Vector(8,2.5,-2),
    Vector(7,2.5,-2), Vector(6,2.5,-2), Vector(3,2.5,-2), Vector(3,2.5,-1),
    Vector(0,4,-1), "reloadend", Vector(0,5,0), Vector(-2,2,1), Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
    Angle(0,0,0), Angle(-90,0,110), Angle(-90,0,110), Angle(-80,0,110),
    Angle(-20,0,110), Angle(-30,0,110), Angle(-20,0,110), Angle(-90,0,110),
    Angle(-90,0,110), Angle(-90,0,110), Angle(-90,0,110), Angle(-20,0,45),
    Angle(-2,0,-3), Angle(0,0,0), Angle(0,0,0), Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = { Angle(0,0,0) }

SWEP.ReloadAnimWepAng = {
    Angle(0,0,0), Angle(-15,15,-17), Angle(-14,14,-22), Angle(-10,15,-24),
    Angle(12,14,-23), Angle(11,15,-20), Angle(12,14,-19), Angle(11,14,-20),
    Angle(7,17,-22), Angle(0,14,-21), Angle(0,15,-22), Angle(0,24,-23),
    Angle(0,25,-22), Angle(-15,24,-25), Angle(-15,25,-23), Angle(5,0,2), Angle(0,0,0),
}

SWEP.InspectAnimWepAng = {
    Angle(0,0,0), Angle(4,4,15), Angle(10,15,25), Angle(10,15,25),
    Angle(10,15,25), Angle(-6,-15,-15), Angle(1,15,-45), Angle(15,25,-55),
    Angle(15,25,-55), Angle(15,25,-55), Angle(0,0,0), Angle(0,0,0)
}