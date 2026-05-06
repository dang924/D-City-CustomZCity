SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Zastava M70"
SWEP.Author = "Zastava Arms"
SWEP.Instructions = "The Zastava M70 is a 7.62×39mm assault rifle with a fire rate of 650 RPM developed in the Socialist Federal Republic of Yugoslavia by Zastava Arms. Due to political differences between the Soviet Union and Yugoslavia at the time, namely the latter's refusal to join the Warsaw Pact, Zastava was unable to directly obtain the technical specifications for the AK and opted to reverse engineer the weapon type."
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/v_coldwar_m70.mdl"
SWEP.FakeScale = 0.9
SWEP.FakePos = Vector(-8, 3.1, 5.95)
SWEP.FakeAng = Angle(-2, 0.0, 0)
SWEP.AttachmentPos = Vector(-2,2.2,-26.9)
SWEP.AttachmentAng = Angle(0,0,0)


--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")

SWEP.FakeEjectBrassATT = "2"
SWEP.FakeReloadSounds = {
	[0.35] = "weapons/tfa_ins2/akm_bw/magout.wav",
	[0.45] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.85] = "weapons/ak47/ak47_magin.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.3] = "weapons/tfa_ins2/akm_bw/magout.wav",
	[0.4] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.65] = "weapons/ak47/ak47_magin.wav",
	[0.95] = "weapons/ak47/ak47_boltback.wav",
	[1.00] = "weapons/ak47/ak47_boltrelease.wav"
}
SWEP.MagModel = "models/btk/nam_akmmag.mdl"
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.25] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 1.1 * timeMul)
			end
		end,
		[0.3] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,0,-50) )
				self:GetWM():ManipulateBoneScale(68, vecPochtiZero)

			end 
		end,
		[0.4] = function( self, timeMul )
			if self:Clip1() < 1 then

				self:GetWM():ManipulateBoneScale(68, vector_full)
			end
		end,
	}
end

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,-1,-1)
SWEP.lmagang2 = Angle(0,0,0)


SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70
SWEP.FakeMagDropBone = 68

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reload_empty",
}

SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x39 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 50
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 50
SWEP.ShockMultiplier = 2
SWEP.Primary.Sound = {"weapons/tfa_ins2/ak103/ak103_fp.wav", 95, 90, 100}
SWEP.SupressedSound = {"ak74/ak74_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak47/handling/ak47_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_cold_war_m70")
SWEP.IconOverride = "vgui/hud/tfa_cold_war_m70"
SWEP.ScrappersSlot = "Primary"
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor1", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(0,0.21,-0.2), {}},
		["mount"] = Vector(-1.01,0.7,0.1),
	}
}

SWEP.LocalMuzzlePos = Vector(25.7,0.2,3.85)
SWEP.LocalMuzzleAng = Angle(-0.65,0,0)
SWEP.WeaponEyeAngles = Angle(0.00,0,0)

SWEP.Primary.Wait = 0.09
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
SWEP.ZoomPos = Vector(0, 0.1714, 5.5043)

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -3, -2)
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.07 - math.cos(i) * 0.05, math.cos(i * i) * 0.04, 0) * 2
end

SWEP.Ergonomics = 0.9
SWEP.HaveModel = "models/pwb/weapons/w_akm.mdl"
--SWEP.ShellEject = "EjectBrass_338Mag"
SWEP.CustomShell = "762x39"

SWEP.Penetration = 15
SWEP.WorldPos = Vector(5, -0.5,-2)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
--https://youtu.be/I7TUHPn_W8c?list=RDEMAfyWQ8p5xUzfAWa3B6zoJg
SWEP.attPos = Vector(0, -2.5, 27)
SWEP.attAng = Angle(0, 0, 0)
SWEP.lengthSub = 20
SWEP.handsAng = Angle(6, 2, 0)
SWEP.AimHands = Vector(-4, 0.5, -4)
SWEP.DistSound = "weapons/tfa_ins2/akp/ak47/ak47_dist.wav"



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
		vec[2] = 3.2*self.shooanim
		vec[3] = 0
		wep:ManipulateBonePosition(71,vec,false)
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