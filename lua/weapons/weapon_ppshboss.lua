
SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = [[PPSH-41 "Raider"]]
SWEP.Author = "Unknown..."
SWEP.Instructions = "Submachine gun chambered in 7.62x25 mm, looks like this one was modified by it's owner.\n\nRate of fire 950 rounds per minute"
SWEP.Category = "Weapons - Machine-Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/pwb2/weapons/w_p90.mdl"
SWEP.WorldModelFake = "models/weapons/tfa_ins2/wpn_ppsh_uptacppsh_hud.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840
//SWEP.FakeScale = 0.9
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
//SWEP.ZoomPos = Vector(-2, 5.7, 0.02)
SWEP.FakePos = Vector(-20, 5.15, 7.5)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(-9,3.3,28)
SWEP.AttachmentAng = Angle(180,0,180)
SWEP.MagIndex = 6
SWEP.FakeEjectBrassATT = "2"
SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_smc_ppsh_drum")
SWEP.IconOverride = "vgui/hud/tfa_smc_ppsh_drum"
SWEP.FakeReloadSounds = {
	[0.30] = "weapons/makarov/makarov_magrelease.wav",
	[0.40] = "weapons/ppsh/ppsh_magout.wav",
	[0.51] = "weapons/universal/uni_crawl_l_05.wav",
	[0.75] = "weapons/ppsh/ppsh_magin.wav",
	[0.90] = "weapons/ump45/ump45_magin.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav"
}

SWEP.FakeEmptyReloadSounds = {
	--[0.22] = "weapons/ak74/ak74_magrelease.wav",
	[0.25] = "weapons/ppsh/ppsh_boltback.wav",
	[0.45] = "weapons/makarov/makarov_magrelease.wav",
	[0.55] = "weapons/ppsh/ppsh_magout.wav",
	[0.65] = "weapons/universal/uni_crawl_l_05.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav",
	[0.85] = "weapons/ppsh/ppsh_magin.wav",
	[0.95] = "weapons/ump45/ump45_magin.wav",
}

SWEP.LocalMuzzlePos = Vector(19.469,1.25,4.5)
SWEP.LocalMuzzleAng = Angle(0,-0.026,90.298)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.weight = 2.4
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.CustomShell = "10mm"
SWEP.WorldPos = Vector(6, -0.8, 0)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 70
SWEP.Primary.ClipSize = 71
SWEP.Primary.DefaultClip = 71
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x25 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 35
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 35
SWEP.Primary.Sound = {"weapons/tfa_ins2/ump45/ump45_fp.wav", 75, 120, 130}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/aks74u/handling/aks_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.061
SWEP.availableAttachments = {
}

SWEP.AnimList = {
	["idle"] = "anm_idle_aim",
	["reload"] = "anm_reload",
	["reload_empty"] = "anm_reload_empty",
}

SWEP.ReloadTime = 5.1
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb2/weapons/vectorsmg/magout.wav",
	"none",
	"none",
	"pwb2/weapons/vectorsmg/magin.wav",
	"none",
	"none",
	"weapons/tfa_ins2/mp7/boltback.wav",
	"pwb2/weapons/vectorsmg/boltrelease.wav",
	"none",
	"none",
	"none",
	"none"
}
SWEP.ReloadSound = "weapons/ar2/ar2_reload.wav"
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 5.7351, -1.2624)
SWEP.RHandPos = Vector(-2, -2, 0)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.attPos = Vector(28, -3.1, 8)	
SWEP.attAng = Angle(-90, 0, 0)
SWEP.EjectPos = Vector(3.9,25,-2.7)
SWEP.EjectAng = Angle(-80,-80,0)

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
	}
end
SWEP.FakeMagDropBone = 2
SWEP.MagModel = "models/weapons/smc/ppsh/w_ppshdrum.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,0)
SWEP.lmagang2 = Angle(-180,0,-90)
SWEP.OpenBolt = true
SWEP.Spray = {}
for i = 1, 71 do
	SWEP.Spray[i] = Angle(-0.00 - math.cos(i) * 0.001, math.cos(i * i) * 0.001, 0) * 3
end

SWEP.Ergonomics = 1.1
SWEP.ShootAnimMul = 2

function SWEP:AnimHoldPost(model)
end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 3)
		wep:ManipulateBonePosition(8,Vector(0 ,0 ,-1*self.shooanim ),false)
	end
end

SWEP.Penetration = 7
SWEP.lengthSub = 31
SWEP.handsAng = Angle(0, 1, 0)
SWEP.DistSound = "mp5k/mp5k_dist.wav"

--local to head
SWEP.RHPos = Vector(5,-6,4)
SWEP.RHAng = Angle(0,-5,90)
--local to rh
SWEP.LHPos = Vector(10.5,-1.5,-4.5)
SWEP.LHAng = Angle(-10,0,-110)
SWEP.NoIdleLoop = true

function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) then
		self:GetWM():ManipulateBoneScale(9, vector_origin)
	end
end

-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-0.5,0,-2),
	Vector(-6,7,-4),
	Vector(-7,1,-7),
	Vector(-7,1,-7),
	Vector(-13,5,-2),
	Vector(-0.5,0,-2),
	Vector(-0.5,0,-2),
	Vector(-0.5,0,-2),
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
	Vector(0,0,-1),
	Vector(5,1,-2),
	Vector(6,3,-2),
	Vector(6,3,-2),
	Vector(5,3,-2),
	Vector(3,3,-2),
	Vector(3,3,-2),
	Vector(0,4,-1),
	"reloadend",
	Vector(0,5,0),
	Vector(-2,2,1),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,0)
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
	Angle(20,-10,-60),
	Angle(20,0,-60),
	Angle(20,0,-60),
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-15,15,17),
	Angle(-14,14,22),
	Angle(-10,15,24),
	Angle(12,14,23),
	Angle(11,15,20),
	Angle(12,14,19),
	Angle(11,14,20),
	Angle(7,9,21),
	Angle(0,14,-21),
	Angle(0,15,-22),
	Angle(0,18,-23),
	Angle(0,25,-22),
	Angle(-12,24,-25),
	Angle(-15,25,-23),
	-Angle(5,2,2),
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
	5,
	4.5,
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