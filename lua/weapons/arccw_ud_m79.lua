SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.PrintName = "M79 Grenade Launcher"
SWEP.Author = "Springfield Armory"
SWEP.Instructions = "Single-shot, break-action grenade launcher chambered in 40x46mm."
SWEP.Category = "Weapons - Grenade Launchers"
SWEP.Slot = 4
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_shot_xm1014.mdl" 
SWEP.WorldModelFake = "models/weapons/arccw/c_ud_m79.mdl"

SWEP.HoldType = "shotgun"


SWEP.FakePos = Vector(-16, 2.2, 5)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0,0,0)
SWEP.AttachmentAng = Angle(0,0,0)


SWEP.FakeAttachment = "1"
SWEP.FakeBodyGroups = "0" 


SWEP.ZoomPos = Vector(-2.5, -1, 3.5)

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70


SWEP.MagModel = "" 

SWEP.AnimList = {
    ["idle"] = "idle",
    ["reload"] = "reload_caseless",
    ["reload_empty"] = "reload_caseless",
}

if CLIENT then
    
    SWEP.FakeReloadEvents = {
        [0.2] = function( self, timeMul )
            self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.5 * timeMul)
        end
    }
end

function SWEP:ModelCreated(model)
    if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
        self:GetWM():SetBodyGroups(self.FakeBodyGroups)
    end
end

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

SWEP.weaponInvCategory = 1


SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Grenade 30x29mm"


SWEP.UsePhysBullets = true

SWEP.CustomShell = "12x70"

SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 150


SWEP.Primary.Spread = Vector(0,0,0)

SWEP.Primary.Force = 150
SWEP.Primary.Wait = 1.0


SWEP.Primary.Sound = "snds_jack_gmod/ez_weapons/heavy_autoloader."
SWEP.ReloadTime = 2.8


SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1" 


SWEP.LocalMuzzlePos = Vector(24, 0, 2)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)


SWEP.podkid = 1.5 
SWEP.punchmul = 2.0 
SWEP.punchspeed = 1.5
SWEP.animposmul = 1
SWEP.cameraShakeMul = 2.5 
SWEP.RecoilMul = 2.0
SWEP.Ergonomics = 0.5
SWEP.Penetration = 0 
SWEP.lengthSub = 20



SWEP.Spray = {}
for i = 1, 5 do
    SWEP.Spray[i] = Angle(-0.1 - math.cos(i) * 0.05, math.cos(i * i) * 0.05, 0) * 1.5
end

SWEP.WorldPos = Vector(5, -0.8, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.handsAng = Angle(1, -1.5, 0)

SWEP.weight = 3


SWEP.RHPos = Vector(3,-6,3.5)
SWEP.RHAng = Angle(0,-12,90)
SWEP.LHPos = Vector(11,1,-3.3)
SWEP.LHAng = Angle(-110,-180,0)

SWEP.ShootAnimMul = 1

function SWEP:DrawPost()
end

function SWEP:AnimHoldPost()
end


SWEP.ReloadAnimLH = {
    Vector(0,0,0), Vector(-1.5,1.5,-8), Vector(-1.5,1.5,-8), Vector(-1.5,1.5,-8),
    Vector(-1,7,-3), Vector(-7,15,-15), Vector(-7,15,-15), Vector(-1,7,-3),
    Vector(-1.5,1.5,-8), Vector(-1.5,1.5,-8), Vector(-1.5,1.5,-8), "fastreload",
    Vector(0,0,0), Vector(0,0,0), Vector(0,0,0), Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
    Vector(0,0,0)
}

SWEP.ReloadAnimLHAng = {
    Angle(0,0,0), Angle(-90,0,110), Angle(-90,0,110), Angle(-80,0,110),
    Angle(-20,0,110), Angle(-30,0,110), Angle(-20,0,110), Angle(-90,0,110),
    Angle(-90,0,110), Angle(-90,0,110), Angle(-90,0,110), Angle(-20,0,45),
    Angle(-2,0,-3), Angle(0,0,0), Angle(0,0,0), Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
    Angle(0,0,0)
}

SWEP.ReloadSlideAnim = { 0, 0, 0, 0 }

SWEP.ReloadAnimWepAng = {
    Angle(0,0,0), Angle(-15,15,-17), Angle(-14,14,-22), Angle(-10,15,-24),
    Angle(12,14,-23), Angle(11,15,-20), Angle(12,14,-19), Angle(11,14,-20),
    Angle(7,17,-22), Angle(0,14,-21), Angle(0,15,-22), Angle(0,24,-23),
    Angle(0,25,-22), Angle(-15,24,-25), Angle(-15,25,-23), Angle(5,0,2), Angle(0,0,0),
}