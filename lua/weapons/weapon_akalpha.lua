SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Ak Alpha"
SWEP.Author = "Izhevsk Machine-Building Plant"
SWEP.Instructions = "The AK-105 is a short barrel, carbine version of the AK-74M rifle, originally developed to replace the shorter barrelled AKS-74U. The AK-105 is chambered in 5.45×39mm ammunition and is used domestically by the Russian Army in contrast to other AK-100 series rifles. It uses a 5.45x39 caliber"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/demons/alpha/v_ak_alpha.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 
--uncomment for funny
--а еще надо настраивать заново zoompos
SWEP.FakePos = Vector(-7.5, 2.9, 5.95)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(-2,2.2,-26.9)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeScale = 1.15
//SWEP.MagIndex = 53
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakeEjectBrassATT = "2"
SWEP.FakeReloadSounds = {
	[0.25] = "weapons/ak74/ak74_magout.wav",
	[0.35] = "weapons/ak74/ak74_magout_rattle.wav",
	[0.8] = "weapons/ak74/ak74_magin.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/ak74/ak74_magout.wav",
	[0.35] = "weapons/ak74/ak74_magout_rattle.wav",
	[0.65] = "weapons/ak74/ak74_magin.wav",
	[0.95] = "weapons/ak74/ak74_boltback.wav",
	[1.00] = "weapons/ak74/ak74_boltrelease.wav"
}
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_ak74_izhmash_6l23_545x39_30.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,0)
SWEP.lmagang2 = Angle(90,0,-90)
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.25] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 1.1 * timeMul)//, self.MagModel, {self.lmagpos3, self.lmagang3, isnumber(self.FakeMagDropBone) and self.FakeMagDropBone or self:GetWM():LookupBone(self.FakeMagDropBone or "Magazine") or self:GetWM():LookupBone("ValveBiped.Bip01_L_Hand"), self.lmagpos2, self.lmagang2}, function(self)
				//	if IsValid(self) then
				//		self:GetWM():ManipulateBoneScale(75, vector_full)
				//		self:GetWM():ManipulateBoneScale(76, vector_full)
				//		self:GetWM():ManipulateBoneScale(77, vector_full)
				//	end
				//end)
			else
				//self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 1.5 * timeMul, self.MagModel, {Vector(-2,-3,0), Angle(180,-0,90), 75, self.lmagpos, self.lmagang}, true)
			end
		end,
		[0.3] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,0,-50) )
				self:GetWM():ManipulateBoneScale(94, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(113, vecPochtiZero)
			else
				//self:GetWM():ManipulateBoneScale(75, vecPochtiZero)
				//self:GetWM():ManipulateBoneScale(76, vecPochtiZero)
				//self:GetWM():ManipulateBoneScale(77, vecPochtiZero)
			end 
		end,
		[0.4] = function( self, timeMul )
			if self:Clip1() < 1 then
				//self:GetOwner():PullLHTowards()
				self:GetWM():ManipulateBoneScale(94, vector_full)
				self:GetWM():ManipulateBoneScale(113, vector_full)
			else
				//self:GetWM():ManipulateBoneScale(75, vector_full)
				//self:GetWM():ManipulateBoneScale(76, vector_full)
				//self:GetWM():ManipulateBoneScale(77, vector_full)
			end 
		end,
	}
end

SWEP.GetDebug = false

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,-1,-1)
SWEP.lmagang2 = Angle(0,90,0)


SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70
SWEP.FakeMagDropBone = 94

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reloadempty",
}

SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.45x39 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 35
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 35
SWEP.ShockMultiplier = 2
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/aks74u/aks_fp.wav", 75, 120, 140}
SWEP.SupressedSound = {"ak74/ak74_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak47/handling/ak47_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}

SWEP.WepSelectIcon2 = Material("vgui/hud/devl_kalashnikov_alpha")
SWEP.IconOverride = "vgui/hud/devl_kalashnikov_alpha"
SWEP.ScrappersSlot = "Primary"
SWEP.availableAttachments = {
	sight = {
		["mountType"] = {"picatinny"},
		["mount"] = {["picatinny"] = Vector(-16.5, 1.95, -0.1)},
	},
	barrel = {
		[1] = {"supressor1", Vector(-0.8,0.6,0.1), {}},
		[2] = {"supressor8", Vector(0,0,-0.15), {}},
		["mount"] = Vector(2.48,0.3,-0.0),
		["mountAngle"] = Angle(0,0,0)
	},
	grip = {
		["mount"] = { ["picatinny"] = Vector(9,0.75,-0.1) },
		["mountType"] = {"picatinny"}
	},
	underbarrel = {
		[1] = {"laser5", Vector(0.0,0.25,0.15), {}},

		["mount"] = {["picatinny_small"] = Vector(10.5, 0.17, -0.1),["picatinny"] = Vector(13,1.1,-0.08)},
		["mountAngle"] = {["picatinny_small"] = Angle(0.95, 0.15, 0),["picatinny"] = Angle(0.0, 0.59, 0)},
		["mountType"] = {"picatinny_small","picatinny"},
		["removehuy"] = {
			["picatinny"] = {
			},
			["picatinny_small"] = {
			}
		}
	},
}

SWEP.LocalMuzzlePos = Vector(20.5,0.32,3.15)
SWEP.LocalMuzzleAng = Angle(-0.15,-0.035,0)
SWEP.WeaponEyeAngles = Angle(0.016,0,0)

SWEP.Primary.Wait = 0.095
SWEP.ReloadTime = 5
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
SWEP.ZoomPos = Vector(0, 0.3197, 5.0132)

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -3, -2)
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 0.5
end

SWEP.Ergonomics = 1.2
SWEP.HaveModel = "models/pwb/weapons/w_akm.mdl"
--SWEP.ShellEject = "EjectBrass_338Mag"
SWEP.CustomShell = "545x39"

SWEP.Penetration = 11
SWEP.WorldPos = Vector(5, -0.5,-2)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
--https://youtu.be/I7TUHPn_W8c?list=RDEMAfyWQ8p5xUzfAWa3B6zoJg
SWEP.attPos = Vector(0, -2.5, 27)
SWEP.attAng = Angle(0, 0, 0)
SWEP.lengthSub = 20
SWEP.handsAng = Angle(6, 2, 0)
SWEP.AimHands = Vector(-4, 0.5, -4)
SWEP.DistSound = "ak74/ak74_dist.wav"

--SWEP.EjectPos = Vector(1,5,3.5)
--SWEP.EjectAng = Angle(0,-90,0)

SWEP.weight = 3

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

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0, self.ReloadSlideOffset)
		vec[1] = 0
		vec[2] = 1.7*self.shooanim
		vec[3] = 0
		wep:ManipulateBonePosition(97,vec,false)
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