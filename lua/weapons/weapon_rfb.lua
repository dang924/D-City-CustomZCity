if true then return end
SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "RFB"
SWEP.Author = "Springfield Armory"
SWEP.Instructions = "The M14 rifle, officially the United States Rifle, Caliber 7.62 mm, M14, is an American battle rifle chambered for the 7.62×51mm NATO cartridge."
SWEP.Category = "Weapons - Carbines"
SWEP.Slot = 2  ---Vector( 20.33, -2.78, -0.6 )
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_g3sg1.mdl"
SWEP.WorldModelFake = "models/weapons/tfa_ins2/c_rfb.mdl" -- МОДЕЛЬ ГОВНА, НАЙТИ НОРМАЛЬНЫЙ КАЛАШ
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
--uncomment for funny
SWEP.FakePos = Vector(-10,2.8, 6.0)
SWEP.FakeAng = Angle(-0.0, -0.6, 0)
SWEP.AttachmentPos = Vector(3.8,2.1,-27.8)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeAttachment = "1"
SWEP.FakeBodyGroups = "00000000000"
SWEP.ZoomPos = Vector(0, 0.6823, 5.3122)

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.FakeEjectBrassATT = "2"
//SWEP.MagIndex = 57
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():AddLayeredSequence(Entity(1):GetActiveWeapon():GetWM():LookupSequence("delta_foregrip"),1)
SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.29] = "weapons/arccw_ud/m16/grab.ogg",
	[0.30] = "weapons/m14/m14_magrelease.wav",
	[0.35] = "weapons/m14/m14_magout.wav",
	[0.40] = "weapons/m14/m14_magout_rattle.wav",
	--[0.51] = "weapons/universal/uni_crawl_l_02.wav",
	[0.80] = "weapons/m14/m14_magin.wav",
	[0.60] = "weapons/universal/uni_crawl_l_03.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav"
}

SWEP.FakeEmptyReloadSounds = {
	--[0.22] = "weapons/ak74/ak74_magrelease.wav",
	[0.21] = "weapons/arccw_ud/m16/grab.ogg",
	[0.25] = "weapons/m14/m14_magrelease.wav",
	[0.30] = "weapons/m14/m14_magout.wav",
	[0.40] = "weapons/m14/m14_magout_rattle.wav",
	[0.45] = "weapons/universal/uni_crawl_l_03.wav",
	[0.7] = "weapons/m14/m14_magin.wav",
	--[0.75] = "weapons/universal/uni_crawl_l_05.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav",
	[0.9] = "weapons/m14/m14_boltrelease.wav",
}


SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_toz106_5.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0.5,0)
SWEP.lmagang2 = Angle(0,0,0)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70

SWEP.FakeMagDropBone = 53

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reload_empty",
}
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
	}
end


SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

SWEP.BurstNum = 0


SWEP.weaponInvCategory = 1
SWEP.CustomEjectAngle = Angle(0, 0, 90)
SWEP.Primary.ClipSize = 20
SWEP.Primary.DefaultClip = 20
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x51 mm"
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor7", Vector(-1.5, -0.1, 0), {}},
	},
}

SWEP.CustomShell = "556x45"
--SWEP.EjectPos = Vector(1,5,3.5)
--SWEP.EjectAng = Angle(0,-90,0)

SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 65
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 65
SWEP.Primary.Sound = {"weapons/m14/m14_tp.wav", 75, 120, 140}
SWEP.SupressedSound = {"homigrad/weapons/rifle/m4a1-1.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak74/handling/ak74_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.080
SWEP.ReloadTime = 5
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

SWEP.PPSMuzzleEffect = "muzzleflash_SR25" -- shared in sh_effects.lua

SWEP.LocalMuzzlePos = Vector(27.285,0.42,4.3)
SWEP.LocalMuzzleAng = Angle(-0.0,-0.6,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.HoldType = "rpg"

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.Penetration = 15
SWEP.Spray = {}
for i = 1, 20 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 0.5
end

SWEP.WepSelectIcon2 = Material("entities/m1a1.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/m1a1.png"

SWEP.Ergonomics = 1.2
SWEP.WorldPos = Vector(5, -0.8, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-3, -2.1, 27.8)
SWEP.attAng = Angle(0, 0.4, 0)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(1, -1.5, 0)
SWEP.DistSound = "weapons/m14/m14_dist.wav"



SWEP.weight = 4

--local to head
SWEP.RHPos = Vector(3,-6,3.5)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(15,1,-3.3)
SWEP.LHAng = Angle(-110,-180,0)

local finger1 = Angle(25,0, 40)

SWEP.ShootAnimMul = 3
function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 3)
		wep:ManipulateBonePosition(43,Vector(0 ,1.5*self.shooanim ,0 ),false)
	end
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 3)
		wep:ManipulateBonePosition(44,Vector(0 ,-0.4*self.shooanim ,0 ),false)
	end
end

function SWEP:AnimHands()

	local wep = self:GetWeaponEntity()
	local ply = self:GetOwner()
	local lh = ply:GetBoneMatrix(ply:LookupBone("ValveBiped.Bip01_L_Hand"))
	local bon = wep:GetBoneMatrix(76)
	if bon then
		local pos,ang = LocalToWorld(self.MagOffsetVec,self.MagOffsetAng,lh:GetTranslation(),lh:GetAngles())
		if self.reload then
			bon:SetTranslation(pos)
			bon:SetAngles(ang)
		end
		wep:SetBoneMatrix(76,bon)
	end
	--print(WorldToLocal(bon:GetTranslation(),bon:GetAngles(),lh:GetTranslation(),lh:GetAngles()))
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

