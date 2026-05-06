
SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "FN FAL"
SWEP.Author = "FN Herstal"
SWEP.Instructions = "The FAL (French: Fusil Automatique Léger 'Light Automatic Rifle') is a battle rifle designed in Belgium by Dieudonné Saive chambered in 7.62x51 mm with a fire rate of 700 RPM"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2  ---Vector( 20.33, -2.78, -0.6 )
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_g3sg1.mdl"
SWEP.WorldModelFake = "models/weapons/nmrih/fnfal/v_fa_fn_fal.mdl" -- МОДЕЛЬ ГОВНА, НАЙТИ НОРМАЛЬНЫЙ КАЛАШ
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
--uncomment for funny
SWEP.FakePos = Vector(-12.5,3.2, 5.8)
SWEP.FakeAng = Angle(-0.0, -0.0, 0)
SWEP.FakeScale = 0.9
SWEP.AttachmentPos = Vector(3.8,2.1,-27.8)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.ZoomPos = Vector(0, 0.7416, 4.9275)
SWEP.FakeAttachment = "1"

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.FakeEjectBrassATT = "2"
//SWEP.MagIndex = 57
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():AddLayeredSequence(Entity(1):GetActiveWeapon():GetWM():LookupSequence("delta_foregrip"),1)
SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.33] = "weapons/arccw_ud/m16/grab.ogg",
	[0.36] = "weapons/fnfal/fnfal_magrelease.wav",
	[0.41] = "weapons/fnfal/fnfal_magout.wav",
	[0.46] = "weapons/fnfal/fnfal_magout_rattle.wav",
	[0.65] = "weapons/universal/uni_crawl_l_03.wav",
	[0.85] = "weapons/fnfal/fnfal_magin.wav",
	[0.95] = "weapons/universal/uni_crawl_l_03.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav"
}

SWEP.FakeEmptyReloadSounds = {
	--[0.22] = "weapons/ak74/ak74_magrelease.wav",
	[0.27] = "weapons/arccw_ud/m16/grab.ogg",
	[0.30] = "weapons/fnfal/fnfal_magrelease.wav",
	[0.35] = "weapons/fnfal/fnfal_magout.wav",
	[0.40] = "weapons/fnfal/fnfal_magout_rattle.wav",
	[0.55] = "weapons/universal/uni_crawl_l_03.wav",
	[0.7] = "weapons/fnfal/fnfal_magin.wav",
	--[0.75] = "weapons/universal/uni_crawl_l_05.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav",
	[0.9] = "weapons/fnfal/fnfal_boltback.wav",
	[0.95] = "weapons/fnfal/fnfal_boltrelease.wav",
}


SWEP.MagModel = "models/weapons/mags/fnfal_mag.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0.0,0)
SWEP.lmagang2 = Angle(0,90,0)


SWEP.FakeMagDropBone = 57
SWEP.NoIdleLoop = true

SWEP.AnimList = {
	["idle"] = "fire_dry",
	["reload"] = "reload",
	["reload_empty"] = "reload_dry",
}
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.39] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(20,30,10), "1111", true )
				self:GetWM():ManipulateBoneScale(57, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(58, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(53, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(64, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(65, vecPochtiZero)
			end 
		end,
		[0.5] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(57, vector_full)
				self:GetWM():ManipulateBoneScale(58, vector_full)
				self:GetWM():ManipulateBoneScale(53, vector_full)
				self:GetWM():ManipulateBoneScale(64, vector_full)
				self:GetWM():ManipulateBoneScale(65, vector_full)
			end 
		end,
		[0.45] = function( self, timeMul )
			if self:Clip1() >= 1 then
				hg.CreateMag( self, Vector(20,30,10), nil, true )
				self:GetWM():ManipulateBoneScale(57, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(58, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(53, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(64, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(65, vecPochtiZero)
			end 
		end,
		[0.6] = function( self, timeMul )
			if self:Clip1() >= 1 then
				self:GetWM():ManipulateBoneScale(57, vector_full)
				self:GetWM():ManipulateBoneScale(58, vector_full)
				self:GetWM():ManipulateBoneScale(53, vector_full)
				self:GetWM():ManipulateBoneScale(64, vector_full)
				self:GetWM():ManipulateBoneScale(65, vector_full)
			end 
		end,
	}
end


SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

SWEP.BurstNum = 0


SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 20
SWEP.Primary.DefaultClip = 20
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x51 mm"
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor7", Vector(-1.5, -0.1, 0), {}},
	},
}

SWEP.CustomShell = "762x51"
--SWEP.EjectPos = Vector(1,5,3.5)
--SWEP.EjectAng = Angle(0,-90,0)

SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 65
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 65
SWEP.Primary.Sound = {"weapons/fnfal/fnfal_tp.wav", 75, 120, 140}
SWEP.SupressedSound = {"homigrad/weapons/rifle/m4a1-1.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak74/handling/ak74_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.085
SWEP.ReloadTime = 5.5
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

SWEP.LocalMuzzlePos = Vector(30.285,0.75,3.15)
SWEP.LocalMuzzleAng = Angle(-0.0,-0.02,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.HoldType = "rpg"

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.Penetration = 15
SWEP.Spray = {}
for i = 1, 20 do
	SWEP.Spray[i] = Angle(-0.02 - math.cos(i) * 0.01, math.cos(i * i) * 0.03, 0) * 0.7
end

SWEP.WepSelectIcon2 = Material("vgui/entities/hud/weapon_tfa_fnfal_inss")
SWEP.IconOverride = "vgui/entities/hud/weapon_tfa_fnfal_inss"

SWEP.Ergonomics = 0.85
SWEP.WorldPos = Vector(5, -0.8, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-3, -2.1, 27.8)
SWEP.attAng = Angle(0, 0.4, 0)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(1, -1.5, 0)
SWEP.DistSound = "weapons/fnfal/fnfal_dist.wav"



SWEP.weight = 3.6

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
		wep:ManipulateBonePosition(60,Vector(-1.2*self.shooanim ,0 ,0 ),false)
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

