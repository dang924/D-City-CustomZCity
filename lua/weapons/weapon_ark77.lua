SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.PrintName = "ARK-77 R.I.P.R. Mk.2"
SWEP.Author = "Unknown..."
SWEP.Instructions = "An modified ARK-7 Resonant Mk.2 Ion Pulse Rifle Mk.2 ion pulse rifle; the classic Kalashnikov design updated for futuristic warfare with DMI-patented Ion Fusion Energy accelerator parts and 3rd generation Plasma Weapons technology. Fires the same 7.62x39 mm cartridge, but the force of the bullet is stronger."
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/c_dmi_ark77_resonant.mdl"

SWEP.FakePos = Vector(-7.5, 2.9, 5.95)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(3,3,-26.8)
SWEP.AttachmentAng = Angle(0,-1.5,0)
SWEP.FakeAttachment = "1"
--PrintAnims(Entity(1):GetActiveWeapon():GetWM())

SWEP.FakeEjectBrassATT = "2"

SWEP.PenetrationMultiplier = 2.5
SWEP.DamageMultiplier = 1.6

SWEP.FakeViewBobBone = "CAM_Homefield"

SWEP.FakeReloadSounds = {
	[0.25] = "weapons/newakm/akmm_magout.wav",
	[0.27] = "ar1/ar2_reload_push.wav",
	[0.35] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.8] = "weapons/newakm/akmm_magin.wav",
	[0.82] = "ar1/ar2_reload_rotate.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/newakm/akmm_magout.wav",
	[0.27] = "ar1/ar2_reload_push.wav",
	[0.35] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.65] = "weapons/newakm/akmm_magin.wav",
	[0.95] = "weapons/newakm/akmm_boltback.wav",
	[1.00] = "weapons/newakm/akmm_boltrelease.wav",
	[1.02] = "ar1/ar2_reload_rotate.wav",
}

SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_ak_izhmash_ak103_std_762x39_30.mdl" 

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.3] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,0,-50) )
				self:GetWM():ManipulateBoneScale(54, vecPochtiZero)
			end 
		end,
		[0.4] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(54, vector_full)
			end 
		end,
	}
end

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,2)
SWEP.lmagang2 = Angle(0,90,0)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70
SWEP.FakeMagDropBone = 54

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reload_empty",
}

local vector_full = Vector(1,1,1)

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

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

SWEP.Primary.Sound = {"weapons/resonant_v2/ak_pulse.wav", 85, 90, 100}

SWEP.Primary.SoundEmpty = {"weapons/newakm/akmm_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}

SWEP.DistSound = "weapons/newakm/akmm_dist.wav"



SWEP.WepSelectIcon2 = Material("vgui/entities/hud/tfa_dmi_ak_pulsev2")
SWEP.IconOverride = "vgui/entities/hud/tfa_dmi_ak_pulsev2"
SWEP.ScrappersSlot = "Primary"
SWEP.availableAttachments = {
		sight = {
		["mountType"] = {"picatinny", "dovetail"},
		["mount"] = {["dovetail"] = Vector(-27, 1.5, -0.2),["picatinny"] = Vector(-27, 2.05, 0.05)},
	},
	mount = {
		["picatinny"] = {
			"mount3",
			Vector(-25, -0.6, -0.945),
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
	grip = {
		["mount"] = Vector(0.0, -0.75, 0.0),
		["mountType"] = "picatinny"
	},
	underbarrel = {
	[1] = {"laser5", Vector(0.0,0.2,0.33), {}},

		["mount"] = {["picatinny_small"] = Vector(6.5, -0.4, 0.2),["picatinny"] = Vector(6.7,-4,1.5)},
		["mountAngle"] = {["picatinny_small"] = Angle(0.97, 1.47, 0),["picatinny"] = Angle(0.35, 0.2, 90)},
		["mountType"] = {"picatinny_small","picatinny"},
		["noblock"] = true,
	}
}

SWEP.Primary.Wait = 0.095
SWEP.ReloadTime = 4.8
SWEP.ReloadSoundes = {
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magout.wav",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magin.wav",
	"none",
	"weapons/tfa_ins2/ak103/ak103_boltback.wav",
	"weapons/tfa_ins2/ak103/ak103_boltrelease.wav",
	"none",
	"none",
	"none"
}

SWEP.LocalMuzzlePos = Vector(31,0.0,2.6)
SWEP.LocalMuzzleAng = Angle(0.0,-0.06,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffect = "new_ar2_muzzle" -- shared in sh_effects.lua

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, -0.0231, 5.1319)
SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -3, -2)
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.01, 0) * 0.1
end

SWEP.Ergonomics = 0.8
SWEP.HaveModel = "models/pwb/weapons/w_akm.mdl"
--SWEP.ShellEject = "EjectBrass_338Mag"
SWEP.CustomShell = "762x39"

SWEP.Penetration = 15
SWEP.WorldPos = Vector(4, -1, -1.5)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
--https://youtu.be/I7TUHPn_W8c?list=RDEMAfyWQ8p5xUzfAWa3B6zoJg
SWEP.attPos = Vector(-2.5, -3.0, 26.8)
SWEP.attAng = Angle(-0, 0.0, 0)
SWEP.lengthSub = 20
SWEP.handsAng = Angle(3, -1, 0)
SWEP.AimHands = Vector(-4, 0.5, -4)


SWEP.weight = 4

--local to head
SWEP.RHPos = Vector(3,-6.5,3.5)
SWEP.RHAng = Angle(0,-8,90)
--local to rh
SWEP.LHPos = Vector(15,1.5,-3.5)
SWEP.LHAng = Angle(-110,-180,0)

SWEP.ShootAnimMul = 3

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0, self.ReloadSlideOffset)
		vec[1] = 0
		vec[2] = 2*self.shooanim
		vec[3] = 0
		wep:ManipulateBonePosition(85,vec,false)
	end
end
local lfang4 = Angle(0,70,0)
local lfang3 = Angle(0,-25,0)
local lfang2 = Angle(0,46,0)
local lfang1 = Angle(0,-30,0)
local lfang0 = Angle(0,-7,0)
local vec_zero = Vector(0,0,0)
local l_finger02 = Angle(-10,0,0)
function SWEP:AnimHoldPost()

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