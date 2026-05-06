SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName =[[AKMN "Nomad"]]
SWEP.Author = "Unknown..."
SWEP.Instructions = "Automatic Rifle chambered in 7.62x39mm, looks like this one was modified by it's owner."
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/wpn_nomad_world.mdl"
SWEP.WorldModelFake = "models/weapons/tfa_ins2/wpn_nomad_hud_v.mdl" -- МОДЕЛЬ ГОВНА, НАЙТИ НОРМАЛЬНЫЙ КАЛАШ
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
--uncomment for funny
SWEP.FakePos = Vector(-17.5, 4.5, 5.55)
SWEP.FakeAng = Angle(0, 0.0, 0.0)
SWEP.AttachmentPos = Vector(3.8,2.1,-27.8)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.ZoomPos = Vector(0, -0.1681, 4.3573)
SWEP.FakeEjectBrassATT = "zatvor"

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

//SWEP.MagIndex = 57
//MagazineSwap	
--Entity(1):GetActiveWeapon():GetWM():AddLayeredSequence(Entity(1):GetActiveWeapon():GetWM():LookupSequence("delta_foregrip"),1)
SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.30] = "weapons/galil/handling/galil_drum_magout.wav",
	[0.35] = "weapons/galil/handling/galil_drum_magout_rattle.wav",
	--[0.51] = "weapons/universal/uni_crawl_l_02.wav",
	[0.8] = "weapons/galil/handling/galil_drum_magin.wav",
	[0.81] = "weapons/universal/uni_crawl_l_03.wav",
	[0.99] = "weapons/universal/uni_crawl_l_04.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav"
}

SWEP.FakeEmptyReloadSounds = {
	--[0.22] = "weapons/ak74/ak74_magrelease.wav",
	[0.18] = "weapons/universal/uni_crawl_l_03.wav",
	[0.27] = "weapons/galil/handling/galil_drum_magout.wav",
	[0.33] = "weapons/galil/handling/galil_drum_magout_rattle.wav",
	[0.65] = "weapons/galil/handling/galil_drum_magin.wav",
	--[0.75] = "weapons/universal/uni_crawl_l_05.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav",
	[0.85] = "weapons/ak47/ak47_boltback.wav",
	[0.90] = "weapons/ak47/ak47_boltrelease.wav",
	[1.01] = "weapons/universal/uni_crawl_l_04.wav",
}

SWEP.MagModel = "models/weapons/tfa_ins2/wpn_nomad_hud_v.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(7,22,10)
SWEP.lmagang2 = Angle(0,0,0)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 70

SWEP.FakeMagDropBone = 2

SWEP.AnimList = {
	["idle"] = "anm_idle",
	["reload"] = "anm_reload",
	["reload_empty"] = "anm_reload_empty",
}
if CLIENT then
	local vector_full = Vector(1,1,1)
	local vecPochtiZero = Vector(0.01,0.01,0.01)
	SWEP.FakeReloadEvents = {
		[0.32] = function( self, timeMul )
			if self:Clip1() < 1 then
			local ent = hg.CreateMag( self, Vector(0,15,-15) )
			for i = 0, ent:GetBoneCount() - 1 do
				ent:ManipulateBoneScale(i, vector_origin)
			end
			ent:ManipulateBoneScale(2, vector_full)
				self:GetWM():ManipulateBoneScale(2, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(3, vecPochtiZero)
			end 
		end,
		[0.49] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(2, vector_full)
				self:GetWM():ManipulateBoneScale(3, vector_full)
			end 
		end,
	}
end

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false


SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 75
SWEP.Primary.DefaultClip = 75
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x39 mm"

SWEP.CustomShell = "762x39"
SWEP.EjectPos = Vector(5,21,-2.7)
SWEP.EjectAng = Angle(-30,-80,0)

SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 35
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 35
SWEP.Primary.Sound = {"weapons/newsndw/rpk2_fp.wav", 75, 120, 140}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak74/handling/ak74_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.0827
SWEP.ReloadTime = 6
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

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1" -- shared in sh_effects.lua

SWEP.LocalMuzzlePos = Vector(25.985,-0.15,2.295)
SWEP.LocalMuzzleAng = Angle(-0.0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.HoldType = "rpg"

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.Penetration = 11
SWEP.Spray = {}
for i = 1, 75 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 0.5
end

SWEP.WepSelectIcon2 = Material("pwb2/vgui/weapons/rpk")
SWEP.IconOverride = "pwb2/vgui/weapons/rpk"

SWEP.Ergonomics = 1.1
SWEP.WorldPos = Vector(5, -0.8, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(28, -2.1, -2)
SWEP.attAng = Angle(90, 0, 0)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(1, -1.5, 0)
SWEP.DistSound = "weapons/newsndw/rpk2_dist.wav"

SWEP.availableAttachments = {
	sight = {
		["mountType"] = {"dovetail","picatinny"},
		["mount"] = {["dovetail"] = Vector(-31.5, 1.8, -0.25),["picatinny"] = Vector(-31, 2.42, -0.05)},
	},
	mount = {
		["picatinny"] = {
			"mount3",
			Vector(-28, -0.3, -1.00),
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
		[1] = {"supressor1", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(-5,0.2,0), {}},
		["mount"] = Vector(-5.9,0.4,0.15),
	},
	underbarrel = {
	[1] = {"laser5", Vector(0.0,0.2,-0.00), {}},

		["mount"] = {["picatinny_small"] = Vector(-7, -0.25, -0.05)},
		["mountAngle"] = {["picatinny_small"] = Angle(0.85, 0, -0)},
		["mountType"] = {"picatinny_small"},
		["noblock"] = true,
	}
}

SWEP.weight = 4.3

--local to head
SWEP.RHPos = Vector(3,-6,3.5)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(15,1,-3.3)
SWEP.LHAng = Angle(-110,-180,0)
SWEP.NoIdleLoop = true

local finger1 = Angle(25,0, 40)

SWEP.ShootAnimMul = 3
function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = Lerp(FrameTime()*15,self.shooanim or 0,self.ReloadSlideOffset)
		vec[1] = 0*self.shooanim
		vec[2] = 0*self.shooanim
		vec[3] = 2*self.shooanim
		wep:ManipulateBonePosition(7,vec,false)
	end
end
function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) then
		self:GetWM():ManipulateBoneScale(8, vector_origin)
	end
end
local lfang2 = Angle(0, -15, -1)
local lfang1 = Angle(-5, -5, -5)
local lfang0 = Angle(-12, -16, 20)
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
	Vector(-1,7,-3),
	Vector(-7,15,-15),
	Vector(-7,15,-15),
	Vector(-1,7,-3),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
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
	Vector(0,0,2),
	Vector(8,1,2),
	Vector(8,2.5,-2),
	Vector(7,2.5,-2),
	Vector(6,2.5,-2),
	Vector(3,2.5,-2),
	Vector(3,2.5,-1),
	Vector(0,4,-1),
	"reloadend",
	Vector(0,5,0),
	Vector(-2,2,1),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-80,0,110),
	Angle(-20,0,110),
	Angle(-30,0,110),
	Angle(-20,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-20,0,45),
	Angle(-2,0,-3),
	Angle(0,0,0),
	Angle(0,0,0),
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
	Angle(20,-10,-20),
	Angle(20,0,-20),
	Angle(20,0,-20),
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
	3,
	3,
	0,
	0,
	0,
	0
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