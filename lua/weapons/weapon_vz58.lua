SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Sa vz. 58"
SWEP.Author = "Česká zbrojovka Uherský Brod"
SWEP.Instructions = "The vz. 58 (or Sa vz. 58) is a 7.62×39mm assault rifle with a fire rate of 800 RPM that was designed and manufactured in Czechoslovakia and accepted into service in the late 1950s as the 7.62 mm samopal vzor 58"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/nmrih/cz858/v_fa_cz858.mdl"

SWEP.FakePos = Vector(-9.5, 2.6, 6)
SWEP.FakeAng = Angle(0, 0.0, 0)
SWEP.AttachmentPos = Vector(3,3,-26.8)
SWEP.AttachmentAng = Angle(0,-1.5,0)
SWEP.FakeAttachment = "1"
--PrintAnims(Entity(1):GetActiveWeapon():GetWM())

SWEP.FakeEjectBrassATT = "2"

SWEP.FakeViewBobBone = "CAM_Homefield"

SWEP.FakeReloadSounds = {
	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.4] = "weapons/newakm/akmm_magout.wav",
	[0.47] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.8] = "weapons/newakm/akmm_magin.wav",
	[0.92] = "weapons/universal/uni_crawl_l_03.wav",

}

SWEP.FakeEmptyReloadSounds = {

	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.35] = "weapons/newakm/akmm_magout.wav",
	[0.4] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.65] = "weapons/newakm/akmm_magin.wav",
	[0.95] = "weapons/tfa_ins2/cz805/boltforward.wav",
	[0.83] = "weapons/universal/uni_crawl_l_04.wav",
}

SWEP.MagModel = "models/btk/nam_akmmag.mdl" 

SWEP.lmagpos = Vector(0,0,1)
SWEP.lmagang = Angle(30,0,0)
SWEP.lmagpos2 = Vector(0,-2.5,1)
SWEP.lmagang2 = Angle(0,0,-90)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70
SWEP.FakeMagDropBone = 57
SWEP.NoIdleLoop = true

SWEP.AnimList = {
	["idle"] = "idle01",
	["reload"] = "reload_ne",
	["reload_empty"] = "reload_dry",
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

SWEP.Primary.Sound = {"weapons/newakm/akmm_tp.wav", 85, 90, 100}
SWEP.Primary.SoundFP = {"weapons/newakm/akmm_fp.wav", 85, 90, 100}

SWEP.SupressedSound = {"weapons/newakm/akmm_suppressed_tp.wav", 65, 90, 100}
SWEP.SupressedSoundFP = {"weapons/newakm/akmm_suppressed_fp.wav", 65, 90, 100}

SWEP.Primary.SoundEmpty = {"weapons/newakm/akmm_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}

SWEP.DistSound = "weapons/newakm/akmm_dist.wav"



SWEP.WepSelectIcon2 = Material("vgui/hud/fa_cz858")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "vgui/hud/fa_cz858"
SWEP.ScrappersSlot = "Primary"
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor1", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(0,0.2,-0.2), {}},
		["mount"] = Vector(-0.98,0.4,0.2),
		["mountAngle"] = Angle(0,0,0)
	},
}

SWEP.Primary.Wait = 0.08
SWEP.ReloadTime = 5
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

SWEP.LocalMuzzlePos = Vector(25.9,0.25,3.4)
SWEP.LocalMuzzleAng = Angle(-0.0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1" -- shared in sh_effects.lua

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.1945, 5.2044)
SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -3, -2)
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.02 - math.cos(i) * 0.02, math.cos(i * i) * 0.01, 0) * 1.8
end

SWEP.Ergonomics = 0.95
SWEP.HaveModel = "models/pwb/weapons/w_akm.mdl"
--SWEP.ShellEject = "EjectBrass_338Mag"
SWEP.CustomShell = "762x39"

SWEP.Penetration = 15
SWEP.WorldPos = Vector(4, -1, -1.5)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
--https://youtu.be/I7TUHPn_W8c?list=RDEMAfyWQ8p5xUzfAWa3B6zoJg
SWEP.attPos = Vector(-2.5, -3.0, 26.8)
SWEP.attAng = Angle(-0, 0.3, 0)
SWEP.lengthSub = 20
SWEP.handsAng = Angle(3, -1, 0)
SWEP.AimHands = Vector(-4, 0.5, -4)


SWEP.weight = 3.7

--local to head
SWEP.RHPos = Vector(3,-6.5,3.5)
SWEP.RHAng = Angle(0,-8,90)
--local to rh
SWEP.LHPos = Vector(15,1.5,-3.5)
SWEP.LHAng = Angle(-110,-180,0)

SWEP.ShootAnimMul = 7

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,((self:Clip1() > 0 or self.reload) and 0) or 1.8)
		wep:ManipulateBonePosition(54,Vector(-2.2*self.shooanim ,0 ,0 ),false)
		local mul = self:Clip1() > 0 and 1 or 0
		--wep:ManipulateBoneScale(12,Vector(mul,mul,mul),false)
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