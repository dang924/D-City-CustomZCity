SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "TTI G17"
SWEP.Author = "Taran Tactical Innovations"
SWEP.Instructions =  "Enhanced version of the Glock 17 pistol chambered in 9x19mm by the manufacturer Taran Tactical Innovations allowing for faster reloads,aiming and overall better performance."
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_pist_elite_single.mdl"
SWEP.WorldModelFake = "models/weapons/fa_glock17/c_tfa_re8glock17.mdl"

SWEP.FakePos = Vector(-16, 2.6, 5.1)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0,-0.1,0)
SWEP.AttachmentAng = Angle(0,90,0)
SWEP.ZoomPos = Vector(0, 0.056, 3.8959)
SWEP.FakeEjectBrassATT = "1"

SWEP.EjectAng = Angle(-120,90,0)
SWEP.EjectPos = Vector(2.8,19,-1.9)
SWEP.CantFireFromCollision = true // 2 спусковых крючка все дела

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_dry",
}
SWEP.NoIdleLoop = true

SWEP.FakeReloadSounds = {
	[0.25] = "weapons/tfa_ins2/usp_tactical/magout.wav",
	[0.3] = "weapons/universal/uni_pistol_draw_01.wav",
	[0.68] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.78] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",

}
SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/tfa_ins2/usp_tactical/magout.wav",
	[0.3] = "weapons/universal/uni_pistol_draw_01.wav",
	[0.68] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.78] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	[0.92] = "weapons/m45/m45_boltrelease.wav",
}

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_tti_glock")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "vgui/hud/tfa_tti_glock"

SWEP.CustomShell = "9x19"
SWEP.punchmul = 1
SWEP.punchspeed = 4
SWEP.weight = 1

SWEP.ScrappersSlot = "Secondary"

SWEP.weaponInvCategory = 2
SWEP.ShellEject = "EjectBrass_9mm"
SWEP.Primary.ClipSize = 20
SWEP.Primary.DefaultClip = 20
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "9x19 mm Parabellum"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 22
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/firearms/hndg_glock17/glock_fire_01.wav", 75, 90, 100}
SWEP.SupressedSound = {"zcitysnd/sound/weapons/m45/m45_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/makarov/handling/makarov_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Force = 22
SWEP.Primary.Wait = PISTOLS_WAIT
SWEP.ReloadTime = 2.5
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 90
SWEP.ReloadSoundes = {
	"none",
	"weapons/tfa_ins2/usp_tactical/magout.wav",
	"weapons/tfa_ins2/browninghp/magin.wav",
	"pwb/weapons/fnp45/sliderelease.wav",
	"none",
	"none"
}
SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}
SWEP.HoldType = "revolver"
SWEP.SprayRand = {Angle(-0.02, -0.025, 0), Angle(-0.03, 0.025, 0)}
SWEP.Ergonomics = 1.25
SWEP.Penetration = 7
SWEP.WorldPos = Vector(2.2, -1.2, -0.8)
SWEP.WorldAng = Angle(0, 0, 0)

SWEP.MagModel = "models/weapons/zcity/w_glockmag.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,2,0)
SWEP.lmagang2 = Angle(0,0,0)

if CLIENT then
	local vector_full = Vector(1, 1, 1)

	SWEP.FakeReloadEvents = {
		[0.25] = function( self, timeMul )
				hg.CreateMag( self, Vector(-8,5,0) )
					self:GetWM():ManipulateBoneScale(100, vector_origin)
					self:GetWM():ManipulateBoneScale(101, vector_origin)
		end,
		[0.35] = function( self, timeMul )
					self:GetWM():ManipulateBoneScale(100, vector_full)
					self:GetWM():ManipulateBoneScale(101, vector_full)
		end,
	}
end

SWEP.FakeMagDropBone = 99

SWEP.LocalMuzzlePos = Vector(8.4,0.07,3.15)
SWEP.LocalMuzzleAng = Angle(0.65,-0.02,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.handsAng = Angle(-1, 10, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, 0, -0.1)
SWEP.attAng = Angle(90.0, -90.0, 0)
SWEP.lengthSub = 5
SWEP.DistSound = "m9/m9_dist.wav"
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, -2, -1)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor4", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(3.3,-0.1,-0.07), {}},
		["mount"] = Vector(-0.51,0.45,-0.03),
	},
    magwell = {
        [1] = {"mag1",Vector(-6.8,-2.2,0), {}},
    },
	sight = {
		["mountType"] = {"picatinny","pistolmount"},
		["mount"] = {["picatinny"] = Vector(-3.1, 1.25, -0.05), ["pistolmount"] = Vector(-7, -0.45, 0.0)},
		["mountAngle"] = Angle(0,0,0),
	},
	underbarrel = {
		["mount"] = Vector(12, -1.5, -1.05),
		["mountAngle"] = Angle(-0.03, -1.45, 90),
		["mountType"] = "picatinny_small"
	},
	mount = {
		["picatinny"] = {
			"mount4",
			Vector(-1.5, -1, -0.05),
			{},
			["mountType"] = "picatinny",
		}
	},
	grip = {
		["mount"] = Vector(15.3, -0.35, -0.05), 
		["mountType"] = "picatinny"
	}
}

SWEP.RHandPos = Vector(3, -1, 0)
SWEP.LHandPos = false

--local to head
SWEP.RHPos = Vector(10,-4.5,3)
SWEP.RHAng = Angle(0,-5,90)
--local to rh
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)

local vector_zero = Vector(0,0,0)
SWEP.ShootAnimMul = 2
SWEP.podkid = 0.8

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 2.2)
		wep:ManipulateBonePosition(97,Vector(-0.8*self.shooanim ,0 ,0 ),false)
	end
end

--RELOAD ANIMS PISTOL

SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(-3,-1,-5),
	Vector(-12,1,-22),
	Vector(-12,1,-22),
	Vector(-12,1,-22),
	Vector(-12,1,-22),
	Vector(-2,-1,-3),
	"fastreload",
	Vector(0,0,0),
	"reloadend",
	"reloadend",
}
SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(30,-10,0),
	Angle(60,-20,0),
	Angle(70,-40,0),
	Angle(90,-30,0),
	Angle(40,-20,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
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
	Vector(-2,0,0),
	Vector(-1,0,0),
	Vector(0,0,0)
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
	Angle(0,0,0),
	Angle(15,2,20),
	Angle(15,2,20),
	Angle(0,0,0)
}
SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(5,15,15),
	Angle(-5,21,14),
	Angle(-5,21,14),
	Angle(5,20,13),
	Angle(5,22,13),
	Angle(1,22,13),
	Angle(1,21,13),
	Angle(2,22,12),
	Angle(-5,21,16),
	Angle(-5,22,14),
	Angle(-4,23,13),
	Angle(7,22,8),
	Angle(7,12,3),
	Angle(2,6,1),
	Angle(0,0,0)
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
