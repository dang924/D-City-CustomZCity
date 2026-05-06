SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Stoner 63A"
SWEP.Author = "Cadillac Gage"
SWEP.Instructions = "The Stoner 63 is a 5.56×45mm NATO modular weapon system. Using a variety of modular components, it can be configured as an assault rifle, carbine, top-fed light machine gun, belt-fed squad automatic weapon, or as a vehicle mounted weapon. RPM is 800."
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.WorldModelFake = "models/weapons/v_coldwar_stoner63a.mdl"

SWEP.FakePos = Vector(-7.5, 2.5, 6)
SWEP.FakeAng = Angle(0, 0, 0.0)
SWEP.AttachmentPos = Vector(3.8,2.1,-27.8)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.ZoomPos = Vector(0, 0.4746, 5.4812)
SWEP.stupidgun = true
SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.FakeEjectBrassATT = "2"

SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.32] = "weapons/m4a1/m4a1_maghitrelease.wav",
	[0.35] = "weapons/m4a1/m4a1_magout.wav",
	[0.84] = "weapons/m4a1/m4a1_magain.wav",
	[0.85] = "weapons/universal/uni_crawl_l_03.wav",
	[1.00] = "weapons/universal/uni_crawl_l_05.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.27] = "weapons/m4a1/m4a1_maghitrelease.wav",
	[0.3] = "weapons/m4a1/m4a1_magout.wav",
	[0.65] = "weapons/m4a1/m4a1_magain.wav",
	[0.85] = "weapons/rpk/rpk_boltback.wav",
	[0.9] = "weapons/m4a1/m4a1_boltarelease.wav"
}

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor2", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(0.0,0.2,-0.2), {}},
		["mount"] = Vector(-0.9,0.55,0.01),
	},
}

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reloadempty",
}

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(3,8,-17)
SWEP.lmagang2 = Angle(0,0,-90)
SWEP.FakeMagDropBone = 52

if CLIENT then
	local vector_full = Vector(1,1,1)
	SWEP.FakeReloadEvents = {	
	}
end

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

SWEP.BurstNum = 0


SWEP.weaponInvCategory = 1
SWEP.CustomEjectAngle = Angle(0, 0, 90)
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.56x45 mm"

SWEP.CustomShell = "556x45"


SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 35
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 35
SWEP.Primary.Sound = {"m16a4/m16a4_fp.wav", 75, 120, 140}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak74/handling/ak74_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.068
SWEP.ReloadTime = 5
SWEP.ReloadSoundes = {
	"none",
	"none",
	"weapons/tfa_ins2/akp/ak47/ak47_magout.wav",
	"none",
	"weapons/tfa_ins2/akp/ak47/ak47_magin.wav",
	"weapons/tfa_ins2/akp/aks74u/aks_boltback.wav",
	"weapons/tfa_ins2/akp/aks74u/aks_boltrelease.wav",
	"none",
	"none",
	"none"
}

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle2" -- shared in sh_effects.lua

SWEP.LocalMuzzlePos = Vector(25.8,0.5,3.35)
SWEP.LocalMuzzleAng = Angle(-0.0,-0.03,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.HoldType = "rpg"

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.Penetration = 11
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 0.2
end

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_coldwar_stoner63a")
SWEP.WepSelectIcon2box = false
SWEP.IconOverride = "vgui/hud/tfa_coldwar_stoner63a"

SWEP.Ergonomics = 1.1
SWEP.WorldPos = Vector(5, -0.8, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-5, -2.0, 27.8)
SWEP.attAng = Angle(0, 0.4, 0)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(1, -1.5, 0)
SWEP.DistSound = "m16a4/m16a4_dist.wav"



SWEP.weight = 2.8

--local to head
SWEP.RHPos = Vector(3,-6,3.5)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(15,1,-3.3)
SWEP.LHAng = Angle(-110,-180,0)

local finger1 = Angle(0,0, 0)

SWEP.ShootAnimMul = 3
function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = Lerp(FrameTime()*15,self.shooanim or 0,self.ReloadSlideOffset)
		vec[1] = 0
		vec[2] = 2.5* self.shooanim
		vec[3] = 0
		wep:ManipulateBonePosition(70,vec,false)
	end
end

-- Inspect Assault

SWEP.InspectAnimWepAng = {
	Angle(0,0,0),
	Angle(4,4,15),
	Angle(10,15,25),
	Angle(10,15,25),
	Angle(10,15,25),
	Angle(-6,-15,-15),
	Angle(1,15,-45),
	Angle(15,25,-55),
	Angle(15,25,-55),
	Angle(15,25,-55),
	Angle(0,0,0),
	Angle(0,0,0)
}

