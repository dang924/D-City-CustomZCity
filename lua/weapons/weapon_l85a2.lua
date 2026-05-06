SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "L85A2"
SWEP.Author = "Royal Small Arms Factory"
SWEP.Instructions = "Automatic rifle chambered in 5.56x45 mm\n\nRate of fire 750 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.WorldModelFake = "models/weapons/tfa_ins2/c_l85a2.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 
--uncomment for funny
--а еще надо настраивать заново zoompos
SWEP.FakePos = Vector(-6, 3.5, 6.5)
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
	[0.30] = "weapons/tfa_ins2_sr25_eft/m14_magrelease.wav",
	[0.32] = "weapons/tfa_ins2_sr25_eft/m14_magout.wav",
	[0.5] = "weapons/tfa_ins2_sr25_eft/m14_magout_rattle.wav",
	[0.8] = "weapons/tfa_ins2_sr25_eft/m14_magin.wav",
	[0.92] = "weapons/tfa_ins2_sr25_eft/m16_hit.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.28] = "weapons/tfa_ins2_sr25_eft/m14_magrelease.wav",
	[0.3] = "weapons/tfa_ins2_sr25_eft/m14_magout.wav",
	[0.45] = "weapons/tfa_ins2_sr25_eft/m14_magout_rattle.wav",
	[0.7] = "weapons/tfa_ins2_sr25_eft/m14_magin.wav",
	[0.92] = "weapons/tfa_ins2_sr25_eft/m14_boltback.wav",
	[0.97] = "weapons/tfa_ins2_sr25_eft/m14_boltrelease.wav"
}
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_stanag_fn_mk16_std_556x45_30.mdl"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,-2,3)
SWEP.lmagang2 = Angle(-0,0,0)

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
	}
end
SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reload_empty",
}

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_l85a2")
SWEP.IconOverride = "vgui/hud/tfa_ins2_l85a2"

SWEP.CustomShell = "556x45"
--SWEP.EjectPos = Vector(-5,0,-5)
--SWEP.EjectAng = Angle(-45,-80,0)
SWEP.ShockMultiplier = 3
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70

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

SWEP.Primary.Sound = {"zcitysnd/sound/weapons/firearms/mil_m16a4/m16_fire_01.wav", 75, 90, 100, 2}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/mk18/handling/mk18_empty.wav", 75, 105, 110, CHAN_WEAPON, 2}
SWEP.DistSound = "zcitysnd/sound/weapons/mk18/mk18_dist.wav"
SWEP.Primary.Wait = 0.07

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor2", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(1.85,0,-0.3), {}},
		["mount"] = Vector(-2.9,0.4,0.2),
	},
	sight = {
		["mount"] = { ironsight = Vector(-19.8, 1.45, 0.025), picatinny = Vector(-20.9, 1.55, 0.05)},
		["mountType"] = {"picatinny", "ironsight"},
		["empty"] = {
			"empty",
		},
	},
	grip = {
		["mount"] = Vector(5.8, -0.9, 0.03),
		["mountType"] = "picatinny"
	},
	underbarrel = {
	[1] = {"laser5", Vector(0.0,0.2,0.33), {}},

		["mount"] = {["picatinny_small"] = Vector(7.8, -1.38, -2.05),["picatinny"] = Vector(6.0,0.35,0.1)},
		["mountAngle"] = {["picatinny_small"] = Angle(-0.95, 0.1, 180),["picatinny"] = Angle(-0.05, 0.5, 0)},
		["mountType"] = {"picatinny_small","picatinny"},
		["noblock"] = true,
	}
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

SWEP.FakeMagDropBone = 94

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, -0.1978, 5.2242)

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

SWEP.LocalMuzzlePos = Vector(28.5,-0.2,2.7)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0.002)

SWEP.attPos = Vector(-5, -3.1, 22.02)
SWEP.attAng = Angle(0, 0, 0)

SWEP.StartAtt = {"ironsight1"}

SWEP.Ergonomics = 1
SWEP.holsteredPos = Vector(7, 6, -2)
SWEP.holsteredAng = Angle(210, 0, 180)

SWEP.UseCustomWorldModel = true

SWEP.BMerge = nil
function SWEP:SetupBoneMerge(mdl)
	if not mdl then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local vm = self:GetWeaponEntity()
	if not IsValid(vm) then return end

	if not IsValid(self.BMerge) then
		self.BMerge = ClientsideModel(mdl, RENDERGROUP_VIEWMODEL)
		if IsValid(self.BMerge) then
			self.BMerge:SetPos(vm:GetPos())
			self.BMerge:SetAngles(vm:GetAngles())
			self.BMerge:AddEffects(EF_BONEMERGE)
			self.BMerge:SetNoDraw(true)
			self.BMerge:SetParent(vm)
			self.BMerge:SetupBones()
			self.BMerge:DrawModel()
		end
	end
end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,self.ReloadSlideOffset)
		vec[1] = 0
		vec[2] = 2.5*self.shooanim
		vec[3] = 0
		wep:ManipulateBonePosition(61,vec,false)
	local owner = self:GetOwner()
	if IsValid(owner) and owner.GetActiveWeapon and IsValid(owner:GetActiveWeapon()) then
		if owner:GetActiveWeapon() ~= nil and owner:GetActiveWeapon() ~= NULL and owner:GetActiveWeapon() ~= self then return end
	end
	if not IsValid(self.BMerge) then
		self:SetupBoneMerge("models/weapons/tfa_ins2/upgrades/l85a2/a_modkit.mdl")
	else
		self.BMerge:SetupBones()
		self.BMerge:DrawModel()
	end
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