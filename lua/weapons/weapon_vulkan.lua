SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Malyuk"
SWEP.Author = "Krasyliv Assembly Manufacturing Plant"
SWEP.Instructions = "The Malyuk or Vulcan is a bullpup assault rifle with a rate of fire of 660 developed by the Ukrainian arms company Interproinvest. This one is chambered in 5.45x39."
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/arc9/stalker2/ar_vulkan/v_ar_vulkan.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 
--uncomment for funny
--а еще надо настраивать заново zoompos
SWEP.FakePos = Vector(-11, 3.0, 7)
SWEP.FakeBodyGroups = "11111111"
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(-2,2.2,-26.9)
SWEP.AttachmentAng = Angle(0,0,0)
//SWEP.MagIndex = 53
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakeAttachment = "2"
SWEP.FakeEjectBrassATT = "3"
SWEP.FakeReloadSounds = {
	[0.31] = "weapons/tfa_ins2/xm177/old/xm177_magrelease.wav",
	[0.35] = "weapons/tfa_ins2/xm177/old/xm177_magout.wav",
	[0.5] = "weapons/tfa_ins2/ak103/ak103_rattle.wav",
	[0.36] = "weapons/tfa_ins2/ak103/ak103_magoutrattle.wav",
	[0.8] = "weapons/tfa_ins2/xm177/old/xm177_magin.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.26] = "weapons/tfa_ins2/xm177/old/xm177_magrelease.wav",
	[0.3] = "weapons/tfa_ins2/xm177/old/xm177_magout.wav",
	[0.4] = "weapons/tfa_ins2/ak103/ak103_rattle.wav",
	[0.31] = "weapons/tfa_ins2/ak103/ak103_magoutrattle.wav",
	[0.7] = "weapons/tfa_ins2/xm177/old/xm177_magin.wav",
	[0.9] = "weapons/tfa_ins2/xm177/old/xm177_boltback.wav",
	[0.99] = "weapons/tfa_ins2/xm177/old/xm177_boltrelease.wav"
}
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_ak74_izhmash_6l23_545x39_30.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.stupidgun = false
SWEP.lmagpos2 = Vector(0,0,0)
SWEP.lmagang2 = Angle(90,0,-90)
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
	}
end

SWEP.GetDebug = false

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,-1,-1)
SWEP.lmagang2 = Angle(0,90,0)


SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 160
SWEP.FakeMagDropBone = 94

SWEP.AnimList = {
	["idle"] = "basepose",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}

SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 35
SWEP.Primary.DefaultClip = 35
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.45x39 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 40
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 40
SWEP.ShockMultiplier = 2
SWEP.Primary.Sound = {"weapons/ak74/ak74_fp.wav", 85, 90, 100}
SWEP.SupressedSound = {"weapons/ak74/ak74_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak47/handling/ak47_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}

SWEP.WepSelectIcon2 = Material("entities/arc9_stalker2_ar_vulkan.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_stalker2_ar_vulkan.png"
SWEP.ScrappersSlot = "Primary"
SWEP.availableAttachments = {
		sight = {
		["mount"] = { ironsight = Vector(-16.9, 2.25, -0.11), picatinny = Vector(-15.6, 2.15, -0.08)},
		["mountAngle"] = { ironsight = Angle(0, 0, 0.0), picatinny = Angle(0, 0, 0.00)},
		["mountType"] = {"picatinny", "ironsight"},
	},
	barrel = {
		[1] = {"supressor8", Vector(0,0.0,0.0), {}},
		[2] = {"supressor6", Vector(0.35,0.65,-0.0), {}},
		["mount"] = Vector(0.1,-0.26,-0.18),
	},
	grip = {
		["mount"] = { ["picatinny"] = Vector(10.5,-0.4,-0.15) },
		["mountType"] = {"picatinny"}
	},
	underbarrel = {
		["mount"] = {["picatinny"] = Vector(9.1,1.2,-0.11)},
		["mountAngle"] = {["picatinny"] = Angle(0.1, 0.4, 0)},
		["mountType"] = {"picatinny"},
	},
}
SWEP.StartAtt = {"ironsight1"}
SWEP.LocalMuzzlePos = Vector(15.8,0.89,1.95)
SWEP.LocalMuzzleAng = Angle(-0.7,1.95,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.Primary.Wait = 0.0885
SWEP.ReloadTime = 4
SWEP.ReloadSoundes = {
	"none",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magout.wav",
	"weapons/tfa_ins2/ak103/ak103_magoutrattle.wav",
	"weapons/tfa_ins2/ak103/ak103_magin.wav",
	"none",
	"none",
	"weapons/tfa_ins2/ak103/ak103_boltback.wav",
	"weapons/tfa_ins2/ak103/ak103_boltrelease.wav",
	"none",
	"none",
	"none"
}

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1" -- shared in sh_effects.lua

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.3329, 4.8814)

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -3, -2)
SWEP.Spray = {}
for i = 1, 35 do
	SWEP.Spray[i] = Angle(-0.02 - math.cos(i) * 0.03, math.cos(i * i) * 0.03, 0) * 0.6
end

SWEP.Ergonomics = 1.3
SWEP.HaveModel = "models/pwb/weapons/w_akm.mdl"
--SWEP.ShellEject = "EjectBrass_338Mag"
SWEP.CustomShell = "545x39"

SWEP.Penetration = 11
SWEP.WorldPos = Vector(5, -0.5,-2)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
--https://youtu.be/I7TUHPn_W8c?list=RDEMAfyWQ8p5xUzfAWa3B6zoJg
SWEP.attPos = Vector(3.5, -27, -2)
SWEP.attAng = Angle(0, 0, 90)
SWEP.lengthSub = 20
SWEP.handsAng = Angle(6, 2, 0)
SWEP.AimHands = Vector(-4, 0.5, -4)
SWEP.DistSound = "weapons/ak74/ak74_dist.wav"

--SWEP.EjectPos = Vector(1,5,3.5)
--SWEP.EjectAng = Angle(0,-90,0)

SWEP.weight = 2.5

--local to head
SWEP.RHPos = Vector(3,-7,3)
SWEP.RHAng = Angle(0,-8,90)
--local to rh
SWEP.LHPos = Vector(15,2,-3.)
SWEP.LHAng = Angle(-110,-180,0)

SWEP.ShootAnimMul = 3

function SWEP:PrimaryShootPost()
	--if CLIENT then
	--	self:PlayAnim("base_fire",1,false)
	--end
end

local lfang2 = Angle(0, -25, -1)
local lfang21 = Angle(0, 20, -1)
local lfang1 = Angle(-5, -5, -5)
local lfang0 = Angle(-15, -22, 20)
local vec_zero = Vector(0,0,0)
local ang_zero = Angle(0,0,0)
function SWEP:AnimHoldPost()

end
-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-6,7,-9),
	Vector(-15,7,-15),
	Vector(-15,6,-15),
	Vector(-13,5,-5),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	"fastreload",
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
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
	2.5,
	2.5,
	0,
	0,
	0,
	0
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
	Vector(9,4.5,-4.5),
	Vector(9,4.5,-4.5),
	Vector(8,4.5,-4.5),
	Vector(-1,4.5,-4.5),
	Vector(-1,4.5,-4.5),
	Vector(0,4,-1),
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
	Angle(7,9,-21),
	Angle(0,14,-21),
	Angle(0,15,-22),
	Angle(0,24,-23),
	Angle(0,25,-22),
	Angle(-15,24,-25),
	Angle(-15,25,-23),
	Angle(5,0,2),
	Angle(0,0,0),
}

-- Inspect Assault

SWEP.InspectAnimLH = {
	Vector(0,0,0)
}
SWEP.InspectAnimLHAng = {
	Angle(0,0,0)
}
SWEP.InspectAnimRH = {
	Vector(0,0,0)
}
SWEP.InspectAnimRHAng = {
	Angle(0,0,0)
}
SWEP.InspectAnimWepAng = {
	Angle(0,0,0),
	Angle(15,15,15),
	Angle(15,15,24),
	Angle(15,15,24),
	Angle(15,15,24),
	Angle(15,7,24),
	Angle(10,3,-5),
	Angle(2,3,-15),
	Angle(0,4,-22),
	Angle(0,3,-45),
	Angle(0,3,-45),
	Angle(0,-2,-2),
	Angle(0,0,0)
}