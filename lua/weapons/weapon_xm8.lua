SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "XM8"
SWEP.Author = "Heckler & Koch"
SWEP.Instructions = "Automatic rifle chambered in 5.56x45 mm\n\nRate of fire 750 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.WorldModelFake = "models/weapons/tfa_ins2/c_xm8.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 models/weapons/zcity/v_416c.mdl
--uncomment for funny
SWEP.FakePos = Vector(-10.5, 3.3, 9.0)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(5,3.2,-22.05)
SWEP.AttachmentAng = Angle(0,0,0)
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
//SWEP.MagIndex = 53
//MagazineSwap
SWEP.FakeEjectBrassATT = "2"
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 90

SWEP.CanEpicRun = false
SWEP.EpicRunPos = Vector(2,12,5)

SWEP.FakeReloadSounds = {
	[0.32] = "weapons/galil/handling/galil_magrelease.wav",
	[0.35] = "weapons/tfa_ins2/g36a1/g36a1_magout.wav",
	[0.45] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.71] = "weapons/tfa_ins2/g36a1/g36a1_magin.wav",
	[0.9] = "weapons/tfa_ins2_sr25_eft/m16_hit.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.22] = "weapons/galil/handling/galil_magrelease.wav",
	[0.25] = "weapons/tfa_ins2/g36a1/g36a1_magout.wav",
	[0.3] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.5] = "weapons/tfa_ins2/g36a1/g36a1_magin.wav",
	[0.63] = "weapons/tfa_ins2_sr25_eft/m16_hit.wav",
	[0.84] = "weapons/tfa_ins2/krissv/krisschargeback.wav",
	[0.97] = "weapons/m4a1/m4a1_boltarelease.wav",
}
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_stanag_fn_mk16_std_556x45_30.mdl"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(-0.2,-1,4)
SWEP.lmagang2 = Angle(0,0,0)

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.26] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,-30,30) )
					for i = 17, 22 do
							self:GetWM():ManipulateBoneScale(i, vecPochtiZero)
				end
			end 
		end,
		[0.35] = function( self, timeMul )
			if self:Clip1() < 1 then
				//self:GetOwner():PullLHTowards()
					for i = 17, 22 do
							self:GetWM():ManipulateBoneScale(i, vector_full)
				end
			end 
		end,
	}
end
SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reload_empty",
}

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_xm8")
SWEP.IconOverride = "vgui/hud/tfa_ins2_xm8"

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
SWEP.Primary.Damage = 45
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 45

SWEP.Primary.Sound = {"weapons/tfa_ins2/g36a1/g36a1_fp.wav", 75, 90, 100, 2}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/mk18/handling/mk18_empty.wav", 75, 105, 110, CHAN_WEAPON, 2}
SWEP.DistSound = "zcitysnd/sound/weapons/mk18/mk18_dist.wav"
SWEP.Primary.Wait = 0.07

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor2", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(2.2,0,-0.2), {}},
		["mount"] = Vector(-2.8,0.25,0.22),
	},
	sight = {
		["mount"] = { picatinny = Vector(-23.2, 2.75, 0.15)},
		["mountAngle"] = { picatinny = Angle(0, 0, 0.00)},
		["mountType"] = {"picatinny"},
	}
}


SWEP.ReloadTime = 5
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

SWEP.FakeMagDropBone = 17

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, -0.6032, 7.2743)

--local to head
SWEP.RHPos = Vector(2,-7,3.5)
SWEP.RHAng = Angle(0,0,90)
--local to rh
SWEP.LHPos = Vector(12.5,2.2,-4)
SWEP.LHAng = Angle(-110,-180,0)

SWEP.WorldPos = Vector(4, -1.5, -0)
SWEP.WorldAng = Angle(0, 0, 0)

function SWEP:AnimationPost()
	self:BoneSet("l_finger0", Vector(0, 0, 0), Angle(-5, -11, 40))
	self:BoneSet("l_finger02", Vector(0, 0, 0), Angle(0, 15, 0))
end

SWEP.LocalMuzzlePos = Vector(25.0,-0.57,3.35)
SWEP.LocalMuzzleAng = Angle(-0.2,-0.02,0)
SWEP.WeaponEyeAngles = Angle(0,0,0.002)

SWEP.attPos = Vector(-4, -22.0, -3)
SWEP.attAng = Angle(0, 0, 90)

SWEP.Ergonomics = 1.05

SWEP.UseCustomWorldModel = true

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,((self:Clip1() > 0 or self.reload) and 0) or 1.8)
		wep:ManipulateBonePosition(14,Vector(0  ,2.25*self.shooanim  ,0 ),false)
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