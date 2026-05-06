SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "VSS Vintorez"
SWEP.Author = "TsNIITochmash Tula arms plant"
SWEP.Instructions = "An incredibly potent armament, this steel/polymer 9x39mm gas-operated, selective-fire, integrally suppressed rifle, the VSS, is the epitome of Soviet special operations units in the mid-1980s. With a 10-round-capacity magazine, it's designed for precision and stealth. Its unique design allows it to fire subsonic ammunition, reducing muzzle flash and report to a mere whisper. This makes the VSS a formidable weapon in the right hands, symbolizing the silent but deadly efficiency of specialized warfare. \n\nRate of fire 900 rounds per minute"
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_g3sg1.mdl"
SWEP.WorldModelFake = "models/weapons/arc9/stalker2/ar_vss/v_ar_vintorez.mdl"

SWEP.FakePos = Vector(-8.5, 3.2, 8.8)
SWEP.FakeAng = Angle(0, 0, 4.2)
SWEP.AttachmentPos = Vector(1,0,0.5)
SWEP.AttachmentAng = Angle(0,0,0)


SWEP.FakeAttachment = "muzzle"

SWEP.FakeAttachment = "2"
SWEP.FakeEjectBrassATT = "3"
SWEP.FakeReloadSounds = {
	[0.3] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.55] = "weapons/tfa_ins2/akm_bw/magout.wav",
	[0.88] = "weapons/ak47/ak47_magin.wav",
}
SWEP.DOZVUK = true

SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.45] = "weapons/tfa_ins2/akm_bw/magout.wav",
	[0.68] = "weapons/ak47/ak47_magin.wav",
	[0.9] = "weapons/ak47/ak47_boltback.wav",
	[0.99] = "weapons/ak47/ak47_boltrelease.wav"
}

SWEP.MagModel = "models/weapons/arc9/stalker2/ar_vss/w_ar_vss_mag.mdl"

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.3] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(113, vector_full)
		end,
		[0.53] = function( self, timeMul )
			if self:Clip1() < 1 then
			hg.CreateMag( self, Vector(15,10,10),nil, true )
			self:GetWM():ManipulateBoneScale(118, vecPochtiZero)
		end
		end,
		[1.05] = function( self, timeMul )
			if self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(118, vector_full)
		end
	end,
		[1.08] = function( self, timeMul )
			if self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(113, vecPochtiZero)
		end
	end,
		[0.69] = function( self, timeMul )
			if self:Clip1() >= 1 then
			hg.CreateMag( self, Vector(15,10,10),nil, true )
			self:GetWM():ManipulateBoneScale(118, vecPochtiZero)
		end
		end,
		[1.06] = function( self, timeMul )
			if self:Clip1() >= 1 then
			self:GetWM():ManipulateBoneScale(118, vector_full)
		end
	end,
		[1.09] = function( self, timeMul )
			if self:Clip1() >= 1 then
			self:GetWM():ManipulateBoneScale(113, vecPochtiZero)
		end
	end
	}
end

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,-2)
SWEP.lmagang2 = Angle(0,90,0)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 180
SWEP.FakeMagDropBone = 118

SWEP.AnimList = {
	["idle"] = "basepose",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}


function SWEP:ModelCreated(model)
	self:GetWM():ManipulateBoneScale(113, vecPochtiZero)
end

SWEP.WepSelectIcon2 = Material("entities/arc9_eft_vss.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_eft_vss.png"
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.dwr_customIsSuppressed = true
SWEP.Primary.ClipSize = 10
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "9x39 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 42
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 42
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/m14/m14_suppressed_fp.wav", 65, 90, 100}
SWEP.SupressedSound = {"zcitysnd/sound/weapons/m14/m14_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.Wait = 0.066
SWEP.ReloadTime = 4
SWEP.ReloadSoundes = {
	"none",
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magout.wav",
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/akm_bw/magin.wav",
	"none",
	"weapons/tfa_inss/asval/slideback.wav",
	"weapons/tfa_inss/asval/slideforward.wav",
	"none",
	"none",
	"none",
	"none"
}

SWEP.LocalMuzzlePos = Vector(23.8,0.655,4.65)
SWEP.LocalMuzzleAng = Angle(-0.15,0.57,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffectSuppress = "muzzleflash_suppressed"

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.3626, 6.0613)
SWEP.RHandPos = Vector(-5, -1, 1)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.ShockMultiplier = 3
SWEP.CustomShell = "762x39"
--SWEP.EjectPos = Vector(-4,0,4)
--SWEP.EjectAng = Angle(0,0,-65)

SWEP.weight = 4

SWEP.Spray = {}
for i = 1, 10 do
	SWEP.Spray[i] = Angle(-0.005 - math.cos(i) * 0.005, math.cos(i * i) * 0.01, 0) * 0.5
end

SWEP.addSprayMul = 0.25

SWEP.Ergonomics = 1.05
SWEP.Penetration = 15
SWEP.WorldPos = Vector(3, -1, 1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, 0.2, 0.3)
SWEP.attAng = Angle(-0, 0.00, 90)
SWEP.lengthSub = 15
SWEP.handsAng = Angle(0, 0, 0)
SWEP.Supressor = true
SWEP.SetSupressor = true
SWEP.availableAttachments = {
	sight = {
		["mountType"] = {"dovetail","picatinny"},
		["mount"] = { dovetail = Vector(-21, 2.15, 0), picatinny = Vector(-22.5,2.65,0.0)}
	},
	mount = {
		["picatinny"] = {
			"mount3",
			Vector(-19, 0, -0.95),
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
}

--local to head
SWEP.RHPos = Vector(4,-5.5,3.5)
SWEP.RHAng = Angle(0,-15,90)
--local to rh
SWEP.LHPos = Vector(12,0.2,-3.5)
SWEP.LHAng = Angle(-110,-180,5)

SWEP.ShootAnimMul = 3

function SWEP:AnimHoldPost()
end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,self.ReloadSlideOffset)
		vec[1] = -1*self.shooanim
		vec[2] = 0
		vec[3] = 0
		wep:ManipulateBonePosition(112,vec,false)
	end
end

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