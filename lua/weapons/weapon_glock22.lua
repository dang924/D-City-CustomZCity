SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Glock 22"
SWEP.Author = "Glock GmbH"
SWEP.Instructions = "Glock is a brand of polymer-framed, short recoil-operated, striker-fired, locked-breech semi-automatic pistols designed and produced by Austrian manufacturer Glock Ges.m.b.H. Thats version of Glock is 22 chambered in .40 SW ammo."
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/bnw_eder22/w_eder22.mdl"
SWEP.WorldModelFake = "models/weapons/bnw_eder22/c_eder22.mdl"
SWEP.FakePos = Vector(-17, 2.5, 2.8)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0.5,-1.2,-6.5)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeAttachment = "1"


SWEP.FakeEjectBrassATT = "2"

SWEP.FakeVPShouldUseHand = true

SWEP.stupidgun = false

SWEP.CantFireFromCollision = true // 2 спусковых крючка все дела

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reloadempty",
}

SWEP.ViewPunchDiv = 40

SWEP.FakeReloadSounds = {
	[0.16] = "weapons/universal/uni_crawl_l_03.wav",
	[0.22] = "weapons/tfa_ins2/usp_tactical/magrelease.wav",
	[0.3] = "weapons/tfa_ins2/usp_tactical/magout.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	--[0.5] = "weapons/universal/uni_pistol_draw_01.wav",
	[0.39] = "weapons/universal/uni_pistol_draw_01.wav",
	[0.6] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.65] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	--[0.85] = "weapons/m45/m45_boltback.wav",
	--[0.92] = "weapons/m45/m45_boltrelease.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.16] = "weapons/universal/uni_crawl_l_03.wav",
	[0.22] = "weapons/tfa_ins2/usp_tactical/magrelease.wav",
	[0.3] = "weapons/tfa_ins2/usp_tactical/magout.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.39] = "weapons/universal/uni_pistol_draw_01.wav",
	[0.55] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.6] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	[0.85] = "weapons/m45/m45_boltrelease.wav",
	--[0.92] = "weapons/m45/m45_boltrelease.wav",
}
SWEP.lmagpos = Vector(0,0,-0.0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(-1,0,0.0)
SWEP.lmagang2 = Angle(-90,-10,-90)

SWEP.GunCamPos = Vector(2.2,-17,-3)
SWEP.GunCamAng = Angle(180,0,-90)

SWEP.MagModel = "models/weapons/zcity/w_glockmag.mdl"

if CLIENT then
	local vector_full = Vector(1, 1, 1)
	SWEP.FakeReloadEvents = {
		[0.3] = function( self ) 
				hg.CreateMag( self, Vector(5,10,10) )
				self:GetWM():ManipulateBoneScale(51, vector_origin)
		end,
		[0.40] = function( self ) 
				self:GetWM():ManipulateBoneScale(51, vector_full)
		end,
	}
end

SWEP.FakeMagDropBone = "30rndassaultclip"

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_glock_p80.png")
SWEP.IconOverride = "entities/weapon_pwb_glock17.png"

SWEP.CustomShell = "9x19"
--SWEP.EjectPos = Vector(0,0,2)
--SWEP.EjectAng = Angle(-45,-80,0)

SWEP.weight = 1

SWEP.ScrappersSlot = "Secondary"

SWEP.weaponInvCategory = 2
SWEP.ShellEject = "EjectBrass_9mm"
SWEP.Primary.ClipSize = 15
SWEP.Primary.DefaultClip = 15
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ".40 SW"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 30
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/firearms/hndg_glock17/glock_fire_01.wav", 75, 90, 100}
SWEP.SupressedSound = {"zcitysnd/sound/weapons/m45/m45_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/makarov/handling/makarov_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Force = 30
SWEP.Primary.Wait = PISTOLS_WAIT
SWEP.ReloadTime = 4.2
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb/weapons/fnp45/clipout.wav",
	"none",
	"none",
	"none",
	"pwb/weapons/fnp45/clipin.wav",
	"pwb/weapons/fnp45/sliderelease.wav",
	"none",
	"none",
	"none",
	"none"
}
SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}
SWEP.HoldType = "revolver"
SWEP.ZoomPos = Vector(0, 0.2076, 1.3019)
--SWEP.RHandPos = Vector(-13.5,0,4)
SWEP.RHandPos = Vector(-4, 0, -3)
SWEP.LHandPos = false
SWEP.SprayRand = {Angle(-0.03, -0.03, 0), Angle(-0.05, 0.03, 0)}
SWEP.Ergonomics = 1.1
SWEP.Penetration = 9

SWEP.punchmul = 1.5
SWEP.punchspeed = 3
--SWEP.WorldPos = Vector(13,0,3.5)
--SWEP.WorldAng = Angle(0,0,0)
SWEP.WorldPos = Vector(2.9, -1.2, -2.8)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, -0, 6.5)
SWEP.attAng = Angle(0, -0.2, 0)
SWEP.lengthSub = 25
SWEP.DistSound = "m9/m9_dist.wav"
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, -2, 1)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor4", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(3.87,0,0), {}},
		["mount"] = Vector(-0.77,1.5,0),
	},
	sight = {
		["mountType"] = {"picatinny","pistolmount"},
		["mount"] = {["picatinny"] = Vector(-3.1, 2.15, 0), ["pistolmount"] = Vector(-6.2, .5, 0.025)},
		["mountAngle"] = Angle(0,0,0),
	},
	underbarrel = {
		["mount"] = Vector(12.5, -0.35, -1),
		["mountAngle"] = Angle(0, -0.6, 90),
		["mountType"] = "picatinny_small"
	},
	mount = {
		["picatinny"] = {
			"mount4",
			Vector(-1.5, -.1, 0),
			{},
			["mountType"] = "picatinny",
		}
	},
	grip = {
		["mount"] = Vector(15, 1.2, 0.1), 
		["mountType"] = "picatinny"
	}
}

--local to head
SWEP.RHPos = Vector(12,-4.5,3)
SWEP.RHAng = Angle(0,-5,90)
--local to rh
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)

SWEP.ShootAnimMul = 3
SWEP.SightSlideOffset = 1.2

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,((self:Clip1() > 0 or self.reload) and 0) or 1.8)
		wep:ManipulateBonePosition(49,Vector(-1*self.shooanim  ,0  ,-0 ),false)
		local mul = self:Clip1() > 0 and 1 or 0
		--wep:ManipulateBoneScale(12,Vector(mul,mul,mul),false)
	end
end

SWEP.LocalMuzzlePos = Vector(5,0.25,0.65)
SWEP.LocalMuzzleAng = Angle(0.5,0.25,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

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