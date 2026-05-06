SWEP.Base = "weapon_revolver2" 
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.PrintName = "Milkor MGL"
SWEP.Author = "Milkor (Pty) Ltd"
SWEP.Instructions = "Multiple Grenade Launcher. Chambered in 40x46mm grenades.\n\nA six-shot revolver-type grenade launcher capable of firing all six rounds in less than 3 seconds."
SWEP.Category = "Weapons - Grenade Launchers"
SWEP.Slot = 4
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_shot_xm1014.mdl" 
SWEP.WorldModelFake = "models/v_models/v_423gl3.mdl"

SWEP.HoldType = "shotgun"

SWEP.FakePos = Vector(-10, 2.2, 5)
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

-- Анимации 
SWEP.AnimList = {
    ["idle"] = "idle",
    ["reload"] = "reload",
    ["reload_empty"] = "reload",
}

if CLIENT then
    SWEP.FakeReloadEvents = {
        [0.2] = function( self, timeMul )
            self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.5 * timeMul)
        end
    }
end


local function ScaleDownBullets(mdl)
    if not IsValid(mdl) then return end
    
    local smallScale = Vector(0.5, 0.5, 0.5) 
    
    for i = 1, 6 do
        local bulletBone = mdl:LookupBone("bullet00" .. i)
        local shellBone = mdl:LookupBone("shell00" .. i)
        
        if bulletBone then mdl:ManipulateBoneScale(bulletBone, smallScale) end
        if shellBone then mdl:ManipulateBoneScale(shellBone, smallScale) end
    end
end

function SWEP:ModelCreated(model)
    if CLIENT and self:GetWM() and not isbool(self:GetWM()) then
        if isstring(self.FakeBodyGroups) then
            self:GetWM():SetBodyGroups(self.FakeBodyGroups)
        end
        
        ScaleDownBullets(self:GetWM())
    end
end


function SWEP:PostFireBullet(bullet)
    local owner = self:GetOwner()
    if ( SERVER or self:IsLocal2() ) and owner:OnGround() then
        if IsValid(owner) and owner:IsPlayer() then
            owner:SetVelocity(owner:GetVelocity() - owner:GetVelocity()/0.45)
        end
    end
end

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false
SWEP.weaponInvCategory = 1
SWEP.WepSelectIcon2 = Material("entities/423gl3.png")
SWEP.IconOverride = "entities/423gl3.png"

SWEP.Primary.ClipSize = 6
SWEP.Primary.DefaultClip = 6
SWEP.Primary.Automatic = false 
SWEP.Primary.Ammo = "Grenade 30x29mm"
SWEP.CustomShell = "12x70"

SWEP.UsePhysBullets = true
SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 150
SWEP.Primary.Spread = Vector(0,0,0)
SWEP.Primary.Force = 150


SWEP.Primary.Wait = 0.5

SWEP.Primary.Sound = "snds_jack_gmod/ez_weapons/heavy_autoloader."
SWEP.ReloadTime = 4.5 

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1" 

SWEP.LocalMuzzlePos = Vector(24, 0, 2)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)


SWEP.podkid = 1.8
SWEP.punchmul = 2.5 
SWEP.punchspeed = 1.5
SWEP.animposmul = 1
SWEP.cameraShakeMul = 3.0
SWEP.RecoilMul = 2.5
SWEP.Ergonomics = 0.4
SWEP.Penetration = 0 
SWEP.lengthSub = 20

SWEP.Spray = {}
for i = 1, 6 do
    SWEP.Spray[i] = Angle(-0.2 - math.cos(i) * 0.05, math.cos(i * i) * 0.05, 0) * 1.5
end

SWEP.WorldPos = Vector(5, -0.8, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.handsAng = Angle(1, -1.5, 0)

SWEP.weight = 5.3 

SWEP.RHPos = Vector(3,-6,3.5)
SWEP.RHAng = Angle(0,-12,90)
SWEP.LHPos = Vector(11,1,-3.3)
SWEP.LHAng = Angle(-110,-180,0)

SWEP.ShootAnimMul = 1


SWEP.availableAttachments = {
    sight = {
        ["mountType"] = {"picatinny"},
        
        
        ["mount"] = { ["picatinny"] = Vector(-12, 1.4, -23) }, 
        
        
        ["mountAngle"] = { ["picatinny"] = Angle(0, 0, 0) },
        
        
        [1] = {"optic2", Vector(-10, 1.4, -23), {}}, -- Burris Fullfield / EOTech
        [2] = {"optic5", Vector(-10, 1.4, -23), {}}, -- Vortex Razor / Aimpoint
        [3] = {"optic6", Vector(-10, 1.4, -23), {}}, -- Leupold / Trijicon
    }
}

function SWEP:AnimHoldPost()
end


function SWEP:DrawPost()
    local wep = self:GetWeaponEntity()
    if CLIENT and IsValid(wep) then
        self.shooanim = Lerp(FrameTime()*15, self.shooanim or 0, self.ReloadSlideOffset or 0)
        
        
        self.DrumAng = LerpFT(0.05, self.DrumAng or 0, self:GetNWInt("drumroll", 0))
        local rotAngle = Angle(0, -(360/6) * (self.reload and 0 or self.DrumAng), 0)
        
        
        local cylinderBone = wep:LookupBone("cylinder")
        if cylinderBone then
            wep:ManipulateBoneAngles(cylinderBone, rotAngle)
        end
    end
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