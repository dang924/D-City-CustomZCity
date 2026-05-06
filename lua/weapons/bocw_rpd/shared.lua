SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "RPD"

SWEP.Author = "Vasily Degtyaryov"
SWEP.Instructions = "The RPD (Ruchnoy Pulemyot Degtyaryova) is a 7.62x39mm light machine gun developed in the Soviet Union.\n\nRate of fire: ~650 rounds per minute."

SWEP.Category = "Weapons - Machineguns"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/w_mach_ins2_m249.mdl"
SWEP.WorldModelFake = "models/weapons/bocw_rpd.mdl"
SWEP.FakeAttachment = "1"
SWEP.FakeScale = 1
SWEP.FakePos = Vector(-10, 3.3, 11)
SWEP.FakeAng = Angle(0.19, 0.04, 0)
SWEP.AttachmentPos = Vector(-0,0.7,0.2)
SWEP.AttachmentAng = Angle(0,0,0)

SWEP.FakeEjectBrassATT = "2"
SWEP.FakeVPShouldUseHand = true
SWEP.AnimList = {
    ["primary_attack"] = "fire",
    ["idle"] = "idle",
    ["reload"] = "reload",
    ["reload_empty"] = "reload",
}

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 35

SWEP.FakeReloadSounds = {
    [0.25] = "weapons/bocw_rpd/topopen.wav",
    [0.4] = "weapons/bocw_rpd/magout.wav",
    [0.63] = "weapons/m249/m249_shoulder.wav",
    [0.7] = "weapons/m249/m249_magin.wav",
    [0.75] = "weapons/m249/m249_beltpullout.wav",
    [0.77] = "weapons/m249/m249_fetchmag.wav",
    [0.94] = "weapons/m249/m249_coverclose.wav",
    [1.04] = "weapons/m249/m249_shoulder.wav"
}

SWEP.FakeEmptyReloadSounds = {
    [0.16] = "weapons/m249/m249_shoulder.wav",
    [0.25] = "weapons/m249/m249_boltback.wav",
    [0.28] = "weapons/m249/m249_boltrelease.wav",
    [0.45] = "weapons/m249/m249_coveropen.wav",
    [0.54] = "weapons/m249/m249_magout.wav",
    [0.73] = "weapons/m249/m249_shoulder.wav",
    [0.8] = "weapons/m249/m249_magin.wav",
    [0.83] = "weapons/m249/m249_beltpullout.wav",
    [0.85] = "weapons/m249/m249_fetchmag.wav",
    [1] = "weapons/m249/m249_coverclose.wav",
    [1.04] = "weapons/m249/m249_shoulder.wav"
}
SWEP.MagModel = "models/weapons/zcity/w_glockmag.mdl"

function SWEP:ThinkAdd()
    if not CLIENT then return end
    
    local belt_bg = 10
    
    local isReloading = (self:GetNextPrimaryFire() > CurTime() + 0.5) 
                        and (self:GetSequenceActivityName(self:GetSequence()) == "ACT_VM_RELOAD" 
                        or self:GetSequenceActivityName(self:GetSequence()) == "ACT_VM_RELOAD_EMPTY")

    if isReloading then
        belt_bg = 0
    else
        local clip = self:Clip1()
        if clip >= 10 then belt_bg = 10
        elseif clip == 9 then belt_bg = 9
        elseif clip == 8 then belt_bg = 8
        elseif clip == 7 then belt_bg = 7
        elseif clip == 6 then belt_bg = 6
        elseif clip == 5 then belt_bg = 5
        elseif clip == 4 then belt_bg = 4
        elseif clip > 0 then belt_bg = 3 
        else belt_bg = 0 end 
    end

    local wm = self:GetWM()
    if IsValid(wm) and not isbool(wm) then
        wm:SetBodygroup(1, belt_bg)
    end
    
    local wep = self:GetWeaponEntity()
    if IsValid(wep) and not isbool(wep) then
        wep:SetBodygroup(1, belt_bg)
    end
end

function SWEP:PostFireBullet(bullet)
    local owner = self:GetOwner()
    if ( SERVER or self:IsLocal2() ) and owner:OnGround() then
        if IsValid(owner) and owner:IsPlayer() then
            owner:SetVelocity(owner:GetVelocity() - owner:GetVelocity()/0.45)
        end
    end
    SlipWeapon(self, bullet)
end

SWEP.FakeMagDropBone = "magazine"

SWEP.WepSelectIcon2 = Material("entities/bocw_rpd.png")
SWEP.IconOverride = "entities/bocw_rpd.png"

SWEP.CustomShell = "762x39"
SWEP.CustomSecShell = "m249len"

SWEP.CanSuicide = false
SWEP.ScrappersSlot = "Primary"

SWEP.weight = 7.5

SWEP.LocalMuzzlePos = Vector(23.632,0.400,5.860)
SWEP.LocalMuzzleAng = Angle(0.3,0.02,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.ShockMultiplier = 3

SWEP.weaponInvCategory = 1

SWEP.Primary.ClipSize = 100
SWEP.Primary.DefaultClip = 100
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x39 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 42
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 40
SWEP.Primary.Sound = {"weapons/bocw_rpd/wz_fire.wav", 75, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/fnfal/handling/fnfal_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}

SWEP.Primary.Wait = 0.092 

SWEP.ReloadTime = 12.5
SWEP.ReloadSoundes = {
    "none", "none", "pwb/weapons/m249/coverup.wav", "none", "none",
    "pwb/weapons/m249/boxout.wav", "none", "pwb/weapons/m249/boxin.wav",
    "none", "none", "none", "none", "none", "none", "none"
}

SWEP.PPSMuzzleEffect = "muzzleflash_m14"

SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(-9, 0.2, 7.35)
SWEP.RHandPos = Vector(-5, -2, 0)
SWEP.LHandPos = Vector(7, -2, -2)

SWEP.RHPos = Vector(7,-7,5)
SWEP.RHAng = Angle(0,0,90)

SWEP.LHPos = Vector(8.5,-2,-6)
SWEP.LHAng = Angle(-20,0,-90)
SWEP.Spray = {}
for i = 1, 150 do
    SWEP.Spray[i] = Angle(-0.03 - math.cos(i) * 0.02, math.cos(i * i) * 0.04, 0) * 2
end

SWEP.Ergonomics = 0.75
SWEP.OpenBolt = true
SWEP.Penetration = 16
SWEP.WorldPos = Vector(4, -0.5, 0)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, -1, 0)
SWEP.attAng = Angle(0, -0.2, 0)
SWEP.AimHands = Vector(0, 1.65, -3.65)
SWEP.lengthSub = 15
SWEP.DistSound = "weapons/zwei/m249/fire/m249_indoor_close_tail.wav"

SWEP.bipodAvailable = true
SWEP.bipodsub = 15
SWEP.RestPosition = Vector(22, -1, 4)
SWEP.RecoilMul = 0.3

function SWEP:DrawPost()
    local wep = self:GetWeaponEntity()
    self.vec = self.vec or Vector(0,0,0)
    local vec = self.vec
    if CLIENT and IsValid(wep) then
        self.shooanim = Lerp(FrameTime()*15,self.shooanim or 0,self.ReloadSlideOffset)
        vec[1] = 0*self.shooanim
        vec[2] = 1.5*self.shooanim
        vec[3] = 0*self.shooanim
        wep:ManipulateBonePosition(143,vec,false)
    end
end

SWEP.punchmul = 15
SWEP.punchspeed = 0.11
SWEP.podkid = 0.05

SWEP.ReloadAnimLH = {
    Vector(0,0,0), Vector(-4,-6,1), Vector(0,-7,-5), Vector(0,-9,1),
    Vector(-4,-6,1), Vector(-4,2,2), Vector(-4,4,2), Vector(-4,15,-15),
    Vector(-4,4,2), Vector(-4,4,2), Vector(-4,2,2), Vector(0,-9,1),
    Vector(0,-7,-5), Vector(-4,-6,1), Vector(-2,-3,1), "reloadend", Vector(0,0,0),
}

SWEP.ReloadAnimRH = { Vector(0,0,0), Vector(0,0,0), }

SWEP.ReloadAnimLHAng = {
    Angle(0,0,0), Angle(0,0,190), Angle(0,0,190), Angle(0,0,190),
    Angle(0,0,120), Angle(0,0,190), Angle(0,0,190), Angle(0,0,190), Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = { Angle(0,0,0), }

SWEP.ReloadAnimWepAng = {
    Angle(0,0,0), Angle(10,0,0), Angle(10,0,0), Angle(0,15,0),
    Angle(5,15,0), Angle(-15,15,0), Angle(-15,15,0), Angle(0,0,0),
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