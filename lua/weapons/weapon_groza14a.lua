SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "OTs-14-1A"
SWEP.Author = "TsKIB SOO"
SWEP.Instructions = "Automatic rifle chambered in 7.62x39\n\nRate of fire 750 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_g3sg1.mdl"
SWEP.WorldModelFake = "models/weapons/arccw/eap/c_groza.mdl"

SWEP.FakePos = Vector(-15.5, 6, 7.2)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(1,0,0.5)
SWEP.AttachmentAng = Angle(0,0,0)


SWEP.FakeAttachment = "1"
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")
--PrintAnims(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakeEjectBrassATT = "2"
SWEP.FakeReloadSounds = {
	[0.32] = "weapons/tfa_ins2/akm_bw/magout.wav",
	[0.45] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.8] = "weapons/ak47/ak47_magin.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.3] = "weapons/tfa_ins2/akm_bw/magout.wav",
	[0.43] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.65] = "weapons/ak47/ak47_magin.wav",
	[0.8] = "weapons/ak47/ak47_boltback.wav",
	[0.9] = "weapons/ak47/ak47_boltrelease.wav"
}
SWEP.MagModel = "models/weapons/upgrades/w_magazine_galil_35.mdl"
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
	}
end

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,2,-6)
SWEP.lmagang2 = Angle(0,0,-90)
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 70
SWEP.FakeMagDropBone = 48

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}



SWEP.WepSelectIcon2 = Material("entities/arccw_eap_groza.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arccw_eap_groza.png"
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x39 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 50
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 50
SWEP.Primary.Sound = {"weapons/newakm/akmm_fp.wav", 65, 90, 100}
SWEP.SupressedSound = {"zcitysnd/sound/weapons/m14/m14_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.Wait = 0.075
SWEP.ReloadTime = 3.5
SWEP.ReloadSoundes = {
	"none",
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magout.wav",
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/akm_bw/magin.wav",
	"none",
	"weapons/tfa_inss/asval/slideback.wav",
	"weapons/tfa_inss/asval/slideforward.wav",
	"none",
	"none",
	"none",
	"none"
}

SWEP.LocalMuzzlePos = Vector(13.5,0.6,3.8)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1"

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.5603, 7.3336)
SWEP.RHandPos = Vector(-5, -1, 1)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.ShockMultiplier = 3
SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(3, 8, -6)
SWEP.holsteredAng = Angle(210, 0, 180)
SWEP.CustomShell = "762x39"
SWEP.CanEpicRun = true
SWEP.EpicRunPos = Vector(-1,5,1)
--SWEP.EjectPos = Vector(-4,0,4)
--SWEP.EjectAng = Angle(0,0,-65)

SWEP.weight = 3.5

SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.01, math.cos(i * i) * 0.02, 0) * 0.8
end

SWEP.addSprayMul = 0.5

SWEP.Ergonomics = 0.9
SWEP.Penetration = 15
SWEP.WorldPos = Vector(3, -1, 1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, 0, -0.5)
SWEP.attAng = Angle(-0, 0.05, 0)
SWEP.lengthSub = 15
SWEP.handsAng = Angle(0, 0, 0)
SWEP.availableAttachments = {
}

--local to head
SWEP.RHPos = Vector(4,-5.5,3.5)
SWEP.RHAng = Angle(0,-15,90)
--local to rh
SWEP.LHPos = Vector(12,0.2,-3.5)
SWEP.LHAng = Angle(-110,-180,5)

SWEP.ShootAnimMul = 4

local lfang2 = Angle(0, -35, -15)
local lfang21 = Angle(0, 35, 25)
local lfang1 = Angle(-5, -5, -5)
local lfang0 = Angle(-15, -22, 15)
local vec_zero = Vector(0,0,0)
local ang_zero = Angle(0,0,0)
function SWEP:AnimHoldPost()

end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,self.ReloadSlideOffset)
		vec[1] = -3.5*self.shooanim
		vec[2] = 0
		vec[3] = 0
		wep:ManipulateBonePosition(5,vec,false)
	end
end

-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-0.5,1.5,-5),
	Vector(-0.5,1.5,-5),
	Vector(-0.5,1.5,-5),
	Vector(-6,7,-9),
	Vector(-15,7,-15),
	Vector(-15,6,-15),
	Vector(-13,5,-5),
	Vector(-0.5,1.5,-5),
	Vector(-0.5,1.5,-5),
	Vector(-0.5,1.5,-5),
	"fastreload",
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,1),
	Vector(8,1,2),
	Vector(6,4.5,-4),
	Vector(6,4.5,-4),
	Vector(6,4.5,-4),
	Vector(1,4.5,-3),
	Vector(1,4.5,-2),
	Vector(0,4,-2),
	Vector(0,5,0),
	"reloadend",
	Vector(-2,2,1),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-70,0,110),
	Angle(-50,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-60,0,95),
	Angle(0,0,60),
	Angle(0,0,30),
	Angle(0,0,2),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(20,0,-60),
	Angle(20,0,-60),
	Angle(20,0,-60),
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-15,15,-17),
	Angle(-14,14,-22),
	Angle(-10,15,-24),
	Angle(12,14,-23),
	Angle(11,15,-20),
	Angle(12,14,-19),
	Angle(11,14,-20),
	Angle(7,17,-22),
	Angle(0,14,-21),
	Angle(0,15,-22),
	Angle(0,24,-23),
	Angle(0,25,-22),
	Angle(-15,24,-25),
	Angle(-15,25,-23),
	Angle(5,0,2),
	Angle(0,0,0),
}


SWEP.ReloadSlideAnim = {
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	4,
	4,
	0,
	0,
	0,
	0
}

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