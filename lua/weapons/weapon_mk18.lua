
SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "MK 18"
SWEP.Author = "Colt Defense"
SWEP.Instructions = "Automatic rifle chambered in 5.56x45 mm\n\nRate of fire 740 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.WorldModelFake = "models/weapons/arc9/mk18.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 models/weapons/zcity/v_416c.mdl
--uncomment for funny
SWEP.FakePos = Vector(-24.0, 7.5, 6.8)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(-25.18,2.5,-0.1)
SWEP.AttachmentAng = Angle(0,90,-91)
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
//SWEP.MagIndex = 53
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")

SWEP.stupidgun = false
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,-1,2.8)
SWEP.lmagang2 = Angle(0,0,-2.5)
SWEP.lmagpos3 = Vector(-3,-5.5,0)
SWEP.lmagang3 = Angle(180,180,-90)
SWEP.FakeMagDropBone = 36

SWEP.FakeReloadSounds = {
	[0.3] = "weapons/universal/uni_crawl_l_03.wav",
	[0.45] = "weapons/arccw_ud/m16/grab.ogg",
	[0.50] = "weapons/arccw_ud/m16/magout.ogg",
	[0.54] = "weapons/ak74/ak74_magout_rattle.wav",

	[0.59] = "weapons/arccw_ud/m16/grab.ogg",
	[0.60] = "weapons/arccw_ud/m16/magin.ogg",
	[0.70] = "weapons/universal/uni_crawl_l_03.wav",
	[0.90] = "weapons/universal/uni_crawl_l_04.wav",

}

SWEP.FakeEmptyReloadSounds = {

	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.29] = "weapons/arccw_ud/m16/magout_empty.ogg",
	[0.32] = "weapons/ak74/ak74_magout_rattle.wav",
	[0.59] = "weapons/arccw_ud/m16/grab.ogg",
	[0.60] = "weapons/arccw_ud/m16/magin.ogg",

	[0.85] = "weapons/arccw_ud/m16/magtap.ogg",
	[1.01] = "weapons/universal/uni_crawl_l_04.wav",
}

SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_stanag_fn_mk16_std_556x45_30.mdl"

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.15] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(36, vector_full)
				self:GetWM():ManipulateBoneScale(121, vector_full)
				self:GetWM():ManipulateBoneScale(81, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(122, vecPochtiZero)
			end 
		end,
		[0.3] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,10,0) )
				self:GetWM():ManipulateBoneScale(36, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(121, vecPochtiZero)
			end 
		end,
		[0.4] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(36, vector_full)
				self:GetWM():ManipulateBoneScale(121, vector_full)
			end 
		end,
		[0.31] = function( self, timeMul )
			if self:Clip1() >= 1 then
				self:GetWM():ManipulateBoneScale(36, vector_full)
				self:GetWM():ManipulateBoneScale(121, vector_full)
			else
			end 
		end,
		[0.35] = function( self, timeMul )
			if self:Clip1() >= 1 then
				self:GetWM():ManipulateBoneScale(81, vector_full)
				self:GetWM():ManipulateBoneScale(122, vector_full)
			else
			end 
		end,
		[0.86] = function( self, timeMul )
			if self:Clip1() >= 1 then
				self:GetWM():ManipulateBoneScale(36, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(121, vecPochtiZero)
			else
			end 
		end,
		[1.14] = function( self, timeMul )
			if self:Clip1() >= 1 then
				self:GetWM():ManipulateBoneScale(81, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(122, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(36, vector_full)
				self:GetWM():ManipulateBoneScale(121, vector_full)
			else
			end 
		end,
	}
end

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}

SWEP.GunCamPos = Vector(5,-10,-5)
SWEP.GunCamAng = Angle(180,-95,-75)

SWEP.weaponInvCategory = 1
SWEP.addSprayMul = 1
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.56x45 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 44
SWEP.Primary.Spread = 0.001
SWEP.Primary.Force = 44
SWEP.ShockMultiplier = 3
SWEP.Primary.Sound = {"sounds_zcity/ar15/close.wav", 75, 90, 100, 1}
SWEP.DistSound = "zcitysnd/sound/weapons/mk18/mk18_dist.wav"
SWEP.Primary.Wait = 0.071

SWEP.CustomShell = "556x45"
SWEP.ScrappersSlot = "Primary"
SWEP.WepSelectIcon2 = Material("entities/arc9_ron_mk18.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_ron_mk18.png"

SWEP.LocalMuzzlePos = Vector(10.5,1.1,2.4)
SWEP.LocalMuzzleAng = Angle(0.0,0,0)
SWEP.WeaponEyeAngles = Angle(0,-90,0.5)

SWEP.weight = 2.4

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor2", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(3.2,0,-0.1), {}},
		["mount"] = Vector(-2.5,0.45,0),
	},
	sight = {
		["empty"] = {
			"empty",
			{
				[2] = "models/drgordon/weapons/colt/m4/m4_sights",
			},
		},
		["ironsight2"] = {
			"ironsight2",
			{
				[2] = "models/drgordon/weapons/colt/m4/m4_sights",
			},
		},
		["mountType"] = {"picatinny","ironsight"},
		["mount"] = {ironsight = Vector(-8 - 4.5, 1.55 - 0.4, -0.1), picatinny = Vector(-8.5 - 6, 1.6 - 0.45, -0.11)},
		["mountAngle"] = Angle(0,0,1),
		["removehuy"] = {
			[2] = "null"
		},
	},
	grip = {
		[1] = {"grip3", Vector(1,0,0), {}},
		["mount"] = Vector(5 + 9 - 6, -0.75 + 1, -0.2),
		["mountType"] = "picatinny"
	},
	underbarrel = {
	[1] = {"laser5", Vector(0.0,0.2,0.1), {}},

		["mount"] = {["picatinny"] = Vector(10.35,0.2,-0.1),["picatinny_small"] =Vector(7.7, -0.2, -0.05)},
		["mountAngle"] = {["picatinny_small"] = Angle(0.9, 0, 0),["picatinny"] = Angle(-0.05, 0.5, 0)},
		["mountType"] = {"picatinny_small","picatinny"},
	}
}

SWEP.StartAtt = {"ironsight2"}

SWEP.ReloadTime = 4.5
SWEP.ReloadSoundes = {
	"none",
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

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle2" -- shared in sh_effects.lua

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 1.0844, 5.0297)

SWEP.attPos = Vector(6.5, 25, -0.15)
SWEP.attAng = Angle(0, 90, 180)

SWEP.cameraShakeMul = 1.5

SWEP.rotatehuy = 0

SWEP.Ergonomics = 0.7
SWEP.Penetration = 13
SWEP.WorldPos = Vector(10, -0, -2)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true

--local to head
SWEP.RHPos = Vector(2,-6.2,3.2)
SWEP.RHAng = Angle(0,-15,90)
--local to rh
SWEP.LHPos = Vector(13,1.5,-4)
SWEP.LHAng = Angle(-80,90,90)

local finger1 = Angle(15, -15, 0)
local finger2 = Angle(-40, 20, 40)

SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(7, 10, -3)
SWEP.holsteredAng = Angle(210, 0, 180)

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 3)
		wep:ManipulateBonePosition(40,Vector(0 ,1.3*self.shooanim ,0 ),false)
	end
end

local ang1 = Angle(10, -10, 20)
local ang2 = Angle(0, 40, 0)
local ang3 = Angle(0, 10, 0)

function SWEP:AnimHoldPost()
	self:BoneSet("l_finger0", vector_origin, ang1)
	self:BoneSet("l_finger02", vector_origin, ang2)
	self:BoneSet("l_finger2", vector_origin, ang3)
end

function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) then
		self:GetWM():ManipulateBoneScale(81, vector_origin)
		self:GetWM():ManipulateBoneScale(122, vector_origin)
	end
end

function SWEP:DrawHUDAdd()
	--[[local att = self:GetWeaponEntity():GetAttachment(1)
	local pos,ang = LocalToWorld(self.attPos,self.attAng,att.Pos,att.Ang)
	cam.Start3D()
	render.DrawLine(pos,pos+ang:Forward()*30,color_white,true)
	cam.End3D()--]]
end

-- RELOAD ANIM SR25/AR15
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-2,1,-8),
	Vector(-2,2,-9),
	Vector(-2,2,-9),
	Vector(-2,7,-10),
	Vector(-15,5,-25),
	Vector(-15,15,-25),
	Vector(-5,15,-25),
	Vector(-2,4,-10),
	Vector(-2,2,-10),
	Vector(-2,2,-10),
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
	Angle(0,0,95),
	Angle(0,0,60),
	Angle(0,0,30),
	Angle(0,0,2),
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