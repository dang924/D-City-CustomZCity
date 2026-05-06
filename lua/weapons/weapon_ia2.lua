SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "IA2"
SWEP.Author = "IMBEL"
SWEP.Instructions = "Automatic rifle chambered in 5.56x45 mm\n\nRate of fire 650 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.WorldModelFake = "models/weapons/v_imbelia2.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 models/weapons/zcity/v_416c.mdl
--uncomment for funny
SWEP.FakePos = Vector(-2, 2.5, 6.5)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(5,3.2,-22.05)
SWEP.AttachmentAng = Angle(0,0,0)
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
//SWEP.MagIndex = 53
//MagazineSwap
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")

SWEP.CanEpicRun = false
SWEP.EpicRunPos = Vector(2,12,5)

SWEP.FakeReloadSounds = {
	[0.32] = "weapons/galil/handling/galil_magrelease.wav",
	[0.35] = "weapons/m4a1/m4a1_magout.wav",
	[0.75] = "weapons/m4a1/m4a1_magain.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.3] = "weapons/galil/handling/galil_magrelease.wav",
	[0.35] = "weapons/m4a1/m4a1_magout.wav",
	[0.7] = "weapons/m4a1/m4a1_magain.wav",
	[0.85] = "weapons/galil/handling/galil_boltback.wav",
	[0.9] = "weapons/galil/handling/galil_boltrelease.wav",
}
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_stanag_fn_mk16_std_556x45_30.mdl"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(-2,0,1)
SWEP.lmagang2 = Angle(0,90,-90)

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.42] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(30,15,0), nil, true )
				self:GetWM():ManipulateBoneScale(97, vecPochtiZero)
			end 
		end,
		[0.58] = function( self, timeMul )
			if self:Clip1() < 1 then
				//self:GetOwner():PullLHTowards()
				self:GetWM():ManipulateBoneScale(97, vector_full)
			end 
		end,
	}
end
SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reload_empty",
}

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_imbelia2")
SWEP.IconOverride = "vgui/hud/tfa_ins2_imbelia2"

SWEP.CustomShell = "556x45"
--SWEP.EjectPos = Vector(-5,0,-5)
--SWEP.EjectAng = Angle(-45,-80,0)
SWEP.ShockMultiplier = 3

SWEP.weight = 3
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.56x45 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 44
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 44

SWEP.Primary.Sound = {"zcitysnd/sound/weapons/firearms/mil_m16a4/m16_fire_01.wav", 75, 90, 100, 2}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/mk18/handling/mk18_empty.wav", 75, 105, 110, CHAN_WEAPON, 2}
SWEP.DistSound = "zcitysnd/sound/weapons/mk18/mk18_dist.wav"
SWEP.Primary.Wait = 0.09

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor2", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(2.2,0,-0.2), {}},
		["mount"] = Vector(-3,0.4,0.24),
	},
	sight = {
		["mount"] = { picatinny = Vector(-18, 1.5, 0.1)},
		["mountAngle"] = { picatinny = Angle(0, 0, 0.00)},
		["mountType"] = {"picatinny"},
	},
	underbarrel = {
			[1] = {"laser5", Vector(0.0,0.2,0.35), {}},

		["mount"] = {["picatinny_small"] = Vector(7.4, -0.3, -1.9),["picatinny"] = Vector(9.9,0.5,0.1)},
		["mountAngle"] = {["picatinny_small"] = Angle(-1, -0.1, 180),["picatinny"] = Angle(0.0, 0.25, 0)},
		["mountType"] = {"picatinny_small","picatinny"},
		["noblock"] = true,
	},
	grip = {
		["mount"] = Vector(5 + 9.3 - 6, -0.85 + 1, 0.05),
		["mountType"] = "picatinny"
	},
}


SWEP.ReloadTime = 4.5
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip out 1.wav",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip in 2.wav",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 bolt back.wav",
	"pwb2/weapons/m4a1/ru-556 bolt forward.wav",
	"none",
	"none",
	"none",
	"none"
}

SWEP.FakeMagDropBone = 97

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, -0.1088, 5.4219)

--local to head
SWEP.RHPos = Vector(2,-7,3.5)
SWEP.RHAng = Angle(0,0,90)
--local to rh
SWEP.LHPos = Vector(12.5,2.2,-4)
SWEP.LHAng = Angle(-110,-180,0)

SWEP.WorldPos = Vector(-2, -1.5, -2)
SWEP.WorldAng = Angle(0, 0, 0)

function SWEP:AnimationPost()
	self:BoneSet("l_finger0", Vector(0, 0, 0), Angle(-5, -11, 40))
	self:BoneSet("l_finger02", Vector(0, 0, 0), Angle(0, 15, 0))
end

SWEP.LocalMuzzlePos = Vector(27.2,-0.1,3.65)
SWEP.LocalMuzzleAng = Angle(0.2,-0.02,0)
SWEP.WeaponEyeAngles = Angle(0,0,0.002)

SWEP.attPos = Vector(-4, -22.0, -3)
SWEP.attAng = Angle(0, 0, 90)

SWEP.Ergonomics = 0.97

SWEP.UseCustomWorldModel = true

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,((self:Clip1() > 0 or self.reload) and 0) or 1.8)
		wep:ManipulateBonePosition(95,Vector(0  ,0  ,-1.58*self.shooanim ),false)
		local mul = self:Clip1() > 0 and 1 or 0
		--wep:ManipulateBoneScale(12,Vector(mul,mul,mul),false)
	end
end


-- RELOAD ANIM SR25/AR15
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-2,1,-6),
	Vector(-2,2,-6),
	Vector(-2,2,-6),
	Vector(2,7,-10),
	Vector(-15,5,-25),
	Vector(-15,15,-25),
	Vector(-5,15,-25),
	Vector(-2,4,-6),
	Vector(-2,2,-6),
	Vector(-2,2,-6),
	Vector(0,0,0),
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
	"fastreload",
	Vector(-3,1,-3),
	Vector(-3,2,-3),
	Vector(-3,3,-3),
	Vector(-9,3,-3),
	Vector(-9,3,-3),
	Vector(0,3,-3),
	"reloadend",
	Vector(0,0,0),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(-60,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-15,25,-15),
	Angle(-15,25,-25),
	Angle(5,28,-25),
	Angle(5,25,-25),
	Angle(1,24,-22),
	Angle(2,25,-21),
	Angle(-5,24,-22),
	Angle(1,25,-21),
	Angle(0,24,-22),
	Angle(1,25,-32),
	Angle(-5,24,-25),
	Angle(0,25,-26),
	Angle(0,0,2),
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
	4,
	4,
	4,
	0,
	0,
	0,
	0
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