SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "American-180"
SWEP.Author = "American Arms International"
SWEP.Instructions = "The American-180 is a .22 Long Rifle submachine gun developed in the 1960s which fires from a pan magazine at the rate of 1200-1500 RPM"
SWEP.Category = "Weapons - Machine-Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/w_uzi.mdl"
SWEP.WorldModelFake = "models/weapons/v_american180_epic.mdl"

SWEP.FakePos = Vector(-8, 3.2, 6.56)
SWEP.FakeAng = Angle(0, 0, 0.1)
SWEP.AttachmentPos = Vector(3.8,2.1,-27.8)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.ZoomPos = Vector(0, 0.5867, 4.41)


SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.stupidgun = false
SWEP.OpenBolt = true

SWEP.FakeEjectBrassATT = "2"

SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.20] = "weapons/universal/uni_crawl_l_03.wav",
	[0.30] = "weapons/rifle_ruger1022/ruger_clipout.wav",
	[0.34] = "weapons/ppsh/ppsh_magout.wav",
	[0.8] = "weapons/rifle_ruger1022/ruger_clipin.wav",
    [0.95] = "weapons/arccw_ud/m16/grab.ogg",
	[0.83] = "weapons/universal/uni_crawl_l_03.wav",
	[0.99] = "weapons/universal/uni_crawl_l_04.wav",

}

SWEP.FakeEmptyReloadSounds = {

	[0.20] = "weapons/universal/uni_crawl_l_03.wav",
	[0.27] = "weapons/rifle_ruger1022/ruger_clipout.wav",
	[0.31] = "weapons/ppsh/ppsh_magout.wav",
	[0.65] = "weapons/rifle_ruger1022/ruger_clipin.wav",
    [0.75] = "weapons/arccw_ud/m16/grab.ogg",
	[0.90] = "weapons/m1a1/handling/m1a1_boltback.wav",
	[0.95] = "weapons/rifle_ruger1022/ruger_slidelock.wav",
	[0.98] = "weapons/universal/uni_crawl_l_03.wav",
}



SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_stanag_magpul_pmag_gen_m3_556x45_10.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,1)
SWEP.lmagang2 = Angle(90,0,-90)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 70

SWEP.FakeMagDropBone = 52

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reloadempty",
}
if CLIENT then
	local vector_full = Vector(1,1,1)
	SWEP.FakeReloadEvents = {
	}
end


SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false
SWEP.NoIdleLoop = true


SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 165
SWEP.Primary.DefaultClip = 165
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = ".22 Long Rifle"

SWEP.CustomShell = "556x45"


SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 35
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 20
SWEP.Primary.Sound = {"weapons/rifle_ruger1022/ruger_fire_01.wav", 75, 120, 140}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak74/handling/ak74_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.05
SWEP.ReloadTime = 6.5
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

SWEP.PPSMuzzleEffect = "pcf_jack_mf_tpistol" -- shared in sh_effects.lua

SWEP.LocalMuzzlePos = Vector(25.5,0.62,2.7)
SWEP.LocalMuzzleAng = Angle(0.2,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.HoldType = "rpg"

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.Penetration = 11
SWEP.Spray = {}
for i = 1, 165 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 0.5
end

SWEP.WepSelectIcon2 = Material("entities/arccw_uc_a180.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arccw_uc_a180.png"

SWEP.Ergonomics = 1
SWEP.WorldPos = Vector(2, -1, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-17, -2, 27.5)
SWEP.attAng = Angle(0, 0.0, 0)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(1, -1.5, 0)
SWEP.DistSound = "m9/m9_dist.wav"



SWEP.weight = 3

--local to head
SWEP.RHPos = Vector(3,-6,3.5)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(15,1,-3.3)
SWEP.LHAng = Angle(-110,-180,0)

local finger1 = Angle(25,0, 40)
SWEP.ShootAnimMul = 3
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
	local owner = self:GetOwner()
	if IsValid(owner) and owner.GetActiveWeapon and IsValid(owner:GetActiveWeapon()) then
		if owner:GetActiveWeapon() ~= nil and owner:GetActiveWeapon() ~= NULL and owner:GetActiveWeapon() ~= self then return end
	end
	if not IsValid(self.BMerge) then
		self:SetupBoneMerge("models/weapons/upgrades/v_american180_epic_mag_1.mdl")
	else
		self.BMerge:SetupBones()
		self.BMerge:DrawModel()
	end
end

function SWEP:PostFireBullet(bullet)
	if CLIENT then
		self:PlayAnim("base_fire_1",0.5,nil,false)
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