SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "hk417"
SWEP.Author = "Germany"
SWEP.Instructions = "The HK417 is similar in internal design to the HK416, although the receiver and working parts are enlarged to suit the larger 7.62×51mm cartridge."
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/akpack/w_ak74.mdl"
SWEP.WorldModelFake = "models/weapons/arccw/dm1973/c_arccw_dmi_hk417.mdl"

SWEP.FakePos = Vector(-9, 1.7, 5.3)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(8,1.78,-29)
SWEP.AttachmentAng = Angle(0,0,90)
SWEP.FakeAttachment = "1"
SWEP.FakeBodyGroups = "0" 

SWEP.ZoomPos = Vector(0, -1.45, 4.9)

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.FakeEjectBrassATT = "2"

SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
    [0.22] = "weapons/universal/uni_crawl_l_03.wav",
    [0.34] = "weapons/m4a1/m4a1_magout.wav",
    [0.38] = "weapons/ak74/ak74_magout_rattle.wav",
    [0.7] = "weapons/m4a1/m4a1_magain.wav",
}

SWEP.FakeEmptyReloadSounds = {
    [0.22] = "weapons/universal/uni_crawl_l_03.wav",
    [0.34] = "weapons/m4a1/m4a1_magout.wav",
    [0.4] = "weapons/ak74/ak74_magout_rattle.wav",
    [0.62] = "weapons/m4a1/m4a1_magain.wav",
    [0.86] = "weapons/m4a1/m4a1_boltarelease.wav",
    [1.01] = "weapons/universal/uni_crawl_l_04.wav",
}

SWEP.MagModel = "models/kali/weapons/black_ops/magazines/30rd galil magazine.mdl"

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70

SWEP.FakeMagDropBone = 57

SWEP.lmagpos = Vector(0,0,1)
SWEP.lmagang = Angle(0,90,-30)
SWEP.lmagpos2 = Vector(0,-2,0.4)
SWEP.lmagang2 = Angle(-90,0,-90)

SWEP.AnimList = {
    ["idle"] = "idle",
    ["reload"] = "wet",
    ["reload_empty"] = "dry",
}
if CLIENT then
    local vector_full = Vector(1,1,1)
    local vector_origin = Vector(0,0,0)
    SWEP.FakeReloadEvents = {
        [0.16] = function( self, timeMul )
            self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.58 * timeMul)
        end,
        
        [0.35] = function(self,timeMul)
            if self:Clip1() < 1 then
                hg.CreateMag( self, Vector(50,10,10) )
            end
        end
    }
end

function SWEP:ModelCreated(model)
    if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
        self:GetWM():SetBodyGroups(self.FakeBodyGroups)
        
        
        self:GetWM():SetSubMaterial(1, "models/weapons/v_smg1/brass")
    end
end

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

SWEP.weaponInvCategory = 1
SWEP.CustomEjectAngle = Angle(0, 0, 90)
SWEP.Primary.ClipSize = 20
SWEP.Primary.DefaultClip = 20
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x51 mm"

SWEP.CustomShell = "762x51"

SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 47
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 35
SWEP.Primary.Sound = {"weapons/arrccw_dmi/dmi_hk_417/417_dmr1.wav", 75, 120, 140}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak74/handling/ak74_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.085
SWEP.ReloadTime = 4.5
SWEP.ReloadSoundes = {
    "none", "none", "weapons/m4a1/m4a1_magout.wav", "none",
    "weapons/m4a1/m4a1_magain.wav", "weapons/m4a1/m4a1_hit.wav",
    "weapons/m4a1/m4a1_boltarelease.wav", "none", "none", "none"
}

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1" 

SWEP.LocalMuzzlePos = Vector(27.985,-1.4,2.2)
SWEP.LocalMuzzleAng = Angle(-0.2,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.HoldType = "rpg"


SWEP.podkid = 0.35 
SWEP.punchmul = 0.7 
SWEP.punchspeed = 1.5
SWEP.animposmul = 1
SWEP.cameraShakeMul = 0.8 
SWEP.RecoilMul = 1

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.Penetration = 11
SWEP.Spray = {}
for i = 1, 30 do
    SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 0.5
end

SWEP.WepSelectIcon2 = Material("entities/arccw_dmi_hk417_fieldops.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arccw_dmi_hk417_fieldops.png"

SWEP.Ergonomics = 1
SWEP.WorldPos = Vector(5, -0.8, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0.25, -2.1, 28)
SWEP.attAng = Angle(0, 0.4, 0)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(1, -1.5, 0)
SWEP.DistSound = "tfa_ins2_wpns/tfa_ins2_m16a4custom/silenced.wav"

SWEP.availableAttachments = {
    barrel = {
        [1] = {"supressor2", Vector(0,0,0), {}},
        [2] = {"supressor6", Vector(0,0,0), {}},
        ["mount"] = Vector(-10,2),
    },
    sight = {
        ["mount"] = { ironsight = Vector(-18.5, 1.58, 0.05), picatinny = Vector(-23, 1, -2)},
        ["mountAngle"] = { ironsight = Angle(0, 180, 0), picatinny = Angle(0, 0, 270)},
        ["mountType"] = {"picatinny", "ironsight"},
        ["empty"] = {
            "empty",
        },
    },
    grip = {
        ["mount"] = Vector(1, 2, 0.6),
        
        ["mountAngle"] = Angle(0,0,270),
        ["mountType"] = "picatinny"
    },
    underbarrel = {
        ["mount"] = {["picatinny_small"] = Vector(300, 0.2, 0.65),["picatinny"] = Vector(2,-1.8)},
        ["mountAngle"] = {["picatinny_small"] = Angle(-1, 0, 180),["picatinny"] = Angle(0, 0.5, 0)},
        ["mountType"] = {"picatinny_small","picatinny"},
        ["noblock"] = true,
    }
}

SWEP.weight = 3

--local to head
SWEP.RHPos = Vector(3,-6,3.5)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(15,1,-3.3)
SWEP.LHAng = Angle(-110,-180,0)

local finger1 = Angle(25,0, 40)

SWEP.ShootAnimMul = 3
function SWEP:DrawPost()
end

local lfang2 = Angle(0, -15, -1)
local lfang1 = Angle(-5, -5, -5)
local lfang0 = Angle(-12, -16, 20)
local vec_zero = Vector(0,0,0)
local ang_zero = Angle(0,0,0)
function SWEP:AnimHoldPost()

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

SWEP.ReloadAnimRHAng = {
    Angle(0,0,0), Angle(0,0,0), Angle(0,0,0), Angle(0,0,0), Angle(0,0,0),
    Angle(0,0,0), Angle(0,0,0), Angle(0,0,0), Angle(0,0,0), Angle(20,-10,-20),
    Angle(20,0,-20), Angle(20,0,-20), Angle(0,0,0),
}

SWEP.ReloadSlideAnim = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 3, 3, 0, 0, 0, 0
}

SWEP.ReloadAnimWepAng = {
    Angle(0,0,0), Angle(-15,15,-17), Angle(-14,14,-22), Angle(-10,15,-24),
    Angle(12,14,-23), Angle(11,15,-20), Angle(12,14,-19), Angle(11,14,-20),
    Angle(7,17,-22), Angle(0,14,-21), Angle(0,15,-22), Angle(0,24,-23),
    Angle(0,25,-22), Angle(-15,24,-25), Angle(-15,25,-23), Angle(5,0,2), Angle(0,0,0),
}

SWEP.InspectAnimLH = { Vector(0,0,0) }
SWEP.InspectAnimLHAng = { Angle(0,0,0) }
SWEP.InspectAnimRH = { Vector(0,0,0) }
SWEP.InspectAnimRHAng = { Angle(0,0,0) }
SWEP.InspectAnimWepAng = {
    Angle(0,0,0), Angle(15,15,15), Angle(15,15,24), Angle(15,15,24),
    Angle(15,15,24), Angle(15,7,24), Angle(10,3,-5), Angle(2,3,-15),
    Angle(0,4,-22), Angle(0,3,-45), Angle(0,3,-45), Angle(0,-2,-2), Angle(0,0,0)
}