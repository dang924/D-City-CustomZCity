SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "QBZ-97-1"
SWEP.Author = "Norinco"
SWEP.Instructions = "Automatic rifle chambered in 5.56x45 mm\n\nRate of fire 650 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/smc/qbz97/w_warface_t97.mdl"
SWEP.WorldModelFake = "models/weapons/smc/qbz97/c_warface_t97.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 
--uncomment for funny
--а еще надо настраивать заново zoompos
SWEP.FakePos = Vector(-4, 2.5, 6.0)
SWEP.FakeAng = Angle(0, 0, 0)
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.AttachmentPos = Vector(5,3.2,-22.05)
SWEP.AttachmentAng = Angle(0,0,0)
//SWEP.MagIndex = 53
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")

SWEP.CanEpicRun = true
SWEP.EpicRunPos = Vector(2,1,2)
SWEP.FakeEjectBrassATT = "2"

SWEP.FakeReloadSounds = {
	[0.34] = "weapons/tfa_ins2_sr25_eft/m14_magrelease.wav",
	[0.36] = "weapons/m16a4/handling/m16_magout.wav",
	[0.72] = "weapons/aks74u/aks_magout_rattle.wav",
	[0.85] = "weapons/m16a4/handling/m16_magin.wav"
}

SWEP.FakeEmptyReloadSounds = {
	[0.33] = "weapons/tfa_ins2_sr25_eft/m14_magrelease.wav",
	[0.35] = "weapons/m16a4/handling/m16_magout.wav",
	[0.37] = "weapons/tfa_ins2_sr25_eft/m14_magrelease.wav",
	[0.65] = "weapons/aks74u/aks_magout_rattle.wav",
	[0.70] = "weapons/m16a4/handling/m16_magin.wav",
	[0.92] = "weapons/tfa_ins2_sr25_eft/m14_boltback.wav",
	[0.96] = "weapons/tfa_ins2_sr25_eft/m14_boltrelease.wav",
}
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_stanag_fn_mk16_std_556x45_30.mdl"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(-2.5,-5,-2)
SWEP.lmagang2 = Angle(180,180,0)

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.31] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.95 * timeMul)//, self.MagModel, {self.lmagpos3, self.lmagang3, isnumber(self.FakeMagDropBone) and self.FakeMagDropBone or self:GetWM():LookupBone(self.FakeMagDropBone or "Magazine") or self:GetWM():LookupBone("ValveBiped.Bip01_L_Hand"), self.lmagpos2, self.lmagang2}, function(self)
			else
			end
		end,
		[0.32] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,40,-5), nil, true )
				self:GetWM():ManipulateBoneScale(104, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(105, vecPochtiZero)
			end 
		end,
		[0.5] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(104, vector_full)
				self:GetWM():ManipulateBoneScale(105, vector_full)
			end 
		end,
		[0.41] = function( self, timeMul )
			if self:Clip1() >= 1 then
				self:GetWM():ManipulateBoneScale(104, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(105, vecPochtiZero)
			end 
		end,
		[0.40] = function( self, timeMul )
			if self:Clip1() >= 1 then
				self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.6 * timeMul)
			else
			end
		end,
		[0.54] = function( self, timeMul )
			if self:Clip1() >= 1 then
				self:GetWM():ManipulateBoneScale(104, vector_full)
				self:GetWM():ManipulateBoneScale(105, vector_full)
			end 
		end,
	}
end
SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reloadempty",
}

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_norinco_qbz97")
SWEP.IconOverride = "vgui/hud/tfa_ins2_norinco_qbz97"

SWEP.CustomShell = "556x45"
--SWEP.EjectPos = Vector(-5,0,-5)
--SWEP.EjectAng = Angle(-45,-80,0)
SWEP.ShockMultiplier = 3
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"

SWEP.weight = 3.2
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.56x45 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 50
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 50

SWEP.Primary.Sound = {"m4a1/m4a1_fp.wav", 75, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/mk18/handling/mk18_empty.wav", 75, 105, 110, CHAN_WEAPON, 2}
SWEP.DistSound = "zcitysnd/sound/weapons/mk18/mk18_dist.wav"
SWEP.Primary.Wait = 0.090

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor2", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(0.8,0,-0.3), {}},
		["mount"] = Vector(-6.75,0.5,0.24),
	},
	sight = {
		["mount"] = { picatinny = Vector(-14.8, 3.4, 0.05)},
		["mountType"] = {"picatinny"},
		["empty"] = {
			"empty",
		},
	},
	grip = {
		["mount"] = Vector(4.8, 0.5, 0.0),
		["mountType"] = "picatinny"
	},
	underbarrel = {
	[1] = {"laser5", Vector(0.0,0.25,0.35), {}},

		["mount"] = {["picatinny_small"] = Vector(2.8, 0.85, -1.9),["picatinny"] = Vector(5.5,0.0,1)},
		["mountAngle"] = {["picatinny_small"] = Angle(-1, 0, 180),["picatinny"] = Angle(0.4, -0.0, 90)},
		["mountType"] = {"picatinny_small","picatinny"},
		["noblock"] = true,
	}
}


SWEP.ReloadTime = 4.8
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

SWEP.FakeMagDropBone = 70

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, -0.5603, 5.8965)

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

SWEP.LocalMuzzlePos = Vector(20.0,-0.52,2.5)
SWEP.LocalMuzzleAng = Angle(-0.6,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0.002)

SWEP.attPos = Vector(0, -3.25, 22)
SWEP.attAng = Angle(0, 0, 0)

SWEP.Ergonomics = 1.1
SWEP.holsteredPos = Vector(5.0, 6.5, -3)
SWEP.holsteredAng = Angle(210, 0, 180)

SWEP.UseCustomWorldModel = true

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 3)
		wep:ManipulateBonePosition(94,Vector(0 ,0 ,-0.8*self.shooanim ),false)
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