SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "AK-102"
SWEP.Author = "Kalashnikov Concern"
SWEP.Instructions = "The AK-102 is a shortened carbine version of the AK-101 rifle model developed in 1994 to use the 5.56x45mm NATO cartridge belonging to the export AK-100\n\nRate of fire 600 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/arccw/c_ur_ak.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 
--uncomment for funny
--а еще надо настраивать заново zoompos
SWEP.FakePos = Vector(-11, 2.53, 5.3)
SWEP.FakeAng = Angle(-1, 0.3, 5.5)
SWEP.AttachmentPos = Vector(3.8,2.1,-27.8)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeBodyGroups = "03a000c2222"
//SWEP.MagIndex = 53
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"
SWEP.FakeReloadSounds = {
	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.34] = "weapons/tfa_ins2/ak103/ak103_magout.wav",
	[0.38] = "weapons/tfa_ins2/ak103/ak103_magoutrattle.wav",
	[0.62] = "weapons/tfa_ins2/ak103/ak103_magin.wav",
	[0.81] = "weapons/universal/uni_crawl_l_03.wav",
	[0.99] = "weapons/universal/uni_crawl_l_04.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.34] = "weapons/tfa_ins2/ak103/ak103_magout.wav",
	[0.4] = "weapons/tfa_ins2/ak103/ak103_magoutrattle.wav",
	[0.62] = "weapons/tfa_ins2/ak103/ak103_magin.wav",
	[0.83] = "weapons/aks74u/aks_boltback.wav",
	[0.88] = "weapons/aks74u/aks_boltrelease.wav",
	[1.01] = "weapons/universal/uni_crawl_l_04.wav",
}
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_ak74_izhmash_6l23_545x39_30.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,1)
SWEP.lmagang2 = Angle(90,0,-90)
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
	}
end

SWEP.GetDebug = false


SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70
SWEP.FakeMagDropBone = 57

if CLIENT then
	local vector_full = Vector(1,1,1)
	SWEP.FakeReloadEvents = {
		[0.15] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(55, vector_origin)
			self:GetWM():ManipulateBoneScale(56, vector_origin)
			self:GetWM():ManipulateBoneScale(57, vector_full)
			self:GetWM():ManipulateBoneScale(58, vector_full)
		end,
		[0.16] = function( self, timeMul )
			self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.58 * timeMul)
		end,
		[0.27] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(57, vector_full)
			self:GetWM():ManipulateBoneScale(58, vector_full)
			self:GetWM():ManipulateBoneScale(55, vector_full)
			self:GetWM():ManipulateBoneScale(56, vector_full)
		end,
		
		[0.40] = function(self,timeMul)
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(50,10,10),nil, true )
				self:GetWM():ManipulateBoneScale(57, vector_origin)
				self:GetWM():ManipulateBoneScale(58, vector_origin)
				--self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 0.5 * timeMul)
			end
		end,
		[0.85] = function(self,timeMul)
			self:GetWM():ManipulateBoneScale(57, vector_origin)
			self:GetWM():ManipulateBoneScale(58, vector_origin)
		end
	}
end


SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}

SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.56x45 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 44
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 44
SWEP.ShockMultiplier = 2
SWEP.Primary.Sound = {"weapons/tfa_ins2/ak103/ak103_fp.wav", 75, 120, 140}
SWEP.SupressedSound = {"weapons/tfa_ins2/ak103/ak103_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak47/handling/ak47_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}

SWEP.WepSelectIcon2 = Material("vgui/entities/hud/weapon_tfa_dmak102")
SWEP.IconOverride = "vgui/entities/hud/weapon_tfa_dmak102"
SWEP.ScrappersSlot = "Primary"
SWEP.availableAttachments = {
	sight = {
		["mountType"] = {"dovetail","picatinny"},
		["mount"] = {["dovetail"] = Vector(-17, 2.5, -0.45),["picatinny"] = Vector(-17.5, 3.02, -0.4)},
	},
	mount = {
		["picatinny"] = {
			"mount3",
			Vector(-14.5, 0.3, -1.35),
			{},
			["mountType"] = "picatinny",
		},
		["dovetail"] = {
			"empty",
			Vector(0, 0, 0),
			{},
			["mountType"] = "dovetail",
		},
	},
	barrel = {
		[1] = {"supressor2", Vector(0,0.5,0.15), {}},
		[2] = {"supressor8", Vector(1.7,0,0), {}},
		["mount"] = Vector(-0.55,0.1,-0.2),
	},
	grip = {
		["mount"] = Vector(-9,-0.1,-0.2),
		["mountType"] = {"ak74"}
	},
	underbarrel = {
		["mount"] = {["ak74"] = Vector(0,0,0)},
		["mountAngle"] = {["ak74"] = Angle(0, 0, 0)},
		["mountType"] = {"ak74"},
		["removehuy"] = {
			["ak74"] = {
			},
		}
	}
}


SWEP.LocalMuzzlePos = Vector(19.785,-0.0,2.995)
SWEP.LocalMuzzleAng = Angle(-0.2,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.Primary.Wait = 0.095
SWEP.ReloadTime = 5.3
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

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle2" -- shared in sh_effects.lua

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, -0.0027, 4.6866)

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -3, -2)
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.03 - math.cos(i) * 0.04, math.cos(i * i) * 0.04, 0) * 1.2
end

SWEP.Ergonomics = 1.15
SWEP.HaveModel = "models/pwb/weapons/w_akm.mdl"
--SWEP.ShellEject = "EjectBrass_338Mag"
SWEP.CustomShell = "545x39"

SWEP.Penetration = 7
SWEP.WorldPos = Vector(5, -0.8, -2.3)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
--https://youtu.be/I7TUHPn_W8c?list=RDEMAfyWQ8p5xUzfAWa3B6zoJg
SWEP.attPos = Vector(-7.25, -2.1, 28)
SWEP.attAng = Angle(0, 0.4, 0)
SWEP.lengthSub = 20
SWEP.handsAng = Angle(6, 2, 0)
SWEP.AimHands = Vector(-4, 0.5, -4)
SWEP.DistSound = "weapons/m4a1/m4a1_dist.wav"

--SWEP.EjectPos = Vector(1,5,3.5)
--SWEP.EjectAng = Angle(0,-90,0)

SWEP.weight = 3

--local to head
SWEP.RHPos = Vector(3,-7,3)
SWEP.RHAng = Angle(0,-8,90)
--local to rh
SWEP.LHPos = Vector(15,2,-3.)
SWEP.LHAng = Angle(-110,-180,0)

SWEP.ShootAnimMul = 4

function SWEP:ThinkAdd()
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
		if self:HasAttachment("grip", "grip_akdong") then
			self:GetWM():SetBodyGroups("02a000c2222")
		else
			self:GetWM():SetBodyGroups(self.FakeBodyGroups)
		end
	end
end

function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
		self:GetWM():ManipulateBoneScale(57, vector_origin)
		self:GetWM():ManipulateBoneScale(58, vector_origin)
		self:GetWM():SetBodyGroups(self.FakeBodyGroups)
	end
end
SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

function SWEP:PrimaryShootPost()
	--if CLIENT then
	--	self:PlayAnim("base_fire",1,false)
	--end
end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = Lerp(FrameTime()*15,self.shooanim or 0,self.ReloadSlideOffset)
		vec[1] = 0*self.shooanim
		vec[2] = 1*self.shooanim
		vec[3] = 0*self.shooanim
		wep:ManipulateBonePosition(8,vec,false)
	end
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