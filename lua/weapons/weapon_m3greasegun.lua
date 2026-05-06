SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "M3 Grease Gun"
SWEP.Author = "General Motors"
SWEP.Instructions = "Submachine gun chambered in .45 ACP\n\nRate of fire 450 rounds per minute"
SWEP.Category = "Weapons - Machine-Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_smg_ump45.mdl"
SWEP.WorldModelFake = "models/weapons/v_m3_grease_gun.mdl"

SWEP.FakePos = Vector(-5, 3.2, 8.1)
SWEP.FakeAng = Angle(0, 0, 9)
SWEP.AttachmentPos = Vector(0,-0.15,0.3)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.OpenBolt = true
SWEP.attAng = Angle(0, 0, 90)

SWEP.FakeEjectBrassATT = "2"

SWEP.CanEpicRun = true
SWEP.EpicRunPos = Vector(2,10,2)


SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.25] = "weapons/tfa_ins2/m3greasegun/m3_magrelease.wav",
	[0.35] = "weapons/mp40/handling/mp40_magout.wav",
	[0.4] = "universal/uni_crawl_r_04.wav",
	[0.8] = "weapons/mp40/handling/mp40_maghit.wav",
	[0.75] = "weapons/mp40/handling/mp40_magin.wav",

}
SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/tfa_ins2/m3greasegun/m3_magrelease.wav",
	[0.35] = "weapons/mp40/handling/mp40_magout.wav",
	[0.4] = "universal/uni_crawl_r_04.wav",
	[0.59] = "weapons/mp40/handling/mp40_magin.wav",
	[0.63] = "weapons/mp40/handling/mp40_maghit.wav",
	[0.7] = "universal/uni_ads_in_06.wav",
	[0.8] = "weapons/tfa_ins2/m3greasegun/m3_boltback.wav",
	[0.85] = "weapons/mp40/handling/mp40_boltunlock.wav",
}

SWEP.MagModel = "models/weapons/upgrades/w_magazine_m45_15.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,-1,0)
SWEP.lmagang2 = Angle(0,0,-20)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70
SWEP.FakeMagDropBone = "b_wpn_mag"

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reloadempty",
}
if CLIENT then
	local vector_full = Vector(1,1,1)
	SWEP.FakeReloadEvents = {
		[0.38] = function (self)
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,-30,0) )
				self:GetWM():ManipulateBoneScale(60, vector_origin)
				self:GetWM():ManipulateBoneScale(61, vector_origin)
				self:GetWM():ManipulateBoneScale(62, vector_origin)
				self:GetWM():ManipulateBoneScale(63, vector_origin)
			end
		end,
		[0.46] = function( self, timeMul )
			if self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(60, vector_full)
			self:GetWM():ManipulateBoneScale(61, vector_full)
			self:GetWM():ManipulateBoneScale(62, vector_full)
			self:GetWM():ManipulateBoneScale(63, vector_full)
			end
		end,
	}
end

--
SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_inss_m3_new")
SWEP.IconOverride = "vgui/hud/tfa_inss_m3_new"

SWEP.LocalMuzzlePos = Vector(18.4,1.315,4.88)
SWEP.LocalMuzzleAng = Angle(0,-0.0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.weight = 2.3
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.CustomShell = "9x19"
--SWEP.EjectPos = Vector(-4,0,-9)
--SWEP.EjectAng = Angle(0,0,0)
SWEP.WorldPos = Vector(1, -0.8, 0)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = ".45 ACP"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 23
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 20
SWEP.animposmul = 2
SWEP.Primary.Sound = {"homigrad/weapons/pistols/p228-1.wav", 75, 120, 130}
SWEP.Primary.Wait = 0.12
SWEP.availableAttachments = {
	sight = {
		["mountType"] = "picatinny",
		["mount"] = Vector(-13, 1.2, -0.28),
	},
	barrel = {
		[1] = {"supressor4", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(-0.5,0.2,0), {}},
		["mount"] = Vector(-3.9 + 2,0 +0.55,1.3-1.6),
	}
}

SWEP.ReloadTime = 5.7
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb2/weapons/vectorsmg/magout.wav",
	"none",
	"none",
	"pwb2/weapons/vectorsmg/magin.wav",
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
SWEP.ZoomPos = Vector(0, 1.3217, 6.1437)
SWEP.RHandPos = Vector(-2, -2, 0)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.Spray = {}
SWEP.randmul = 0.25
//SWEP.norand = true
--SWEP.addSprayMul = 0.5
for i = 1, 30 do
	SWEP.Spray[i] = Angle(0, math.cos(i * i) * 0.01, 0) * 0
end

SWEP.Ergonomics = 1.2
SWEP.ShootAnimMul = 2

local ang1 = Angle(25, 0, 0)
local ang2 = Angle(0, 60, 0)

function SWEP:AnimHoldPost(model)
	--self:BoneSet("l_finger0", vector_origin, ang1)
	--self:BoneSet("l_finger02", vector_origin, ang2)
end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,((self:Clip1() > 0 or self.reload) and 0) or 1.8)
		wep:ManipulateBonePosition(58,Vector(0 ,-1.62*self.shooanim ,0 ),false)
		local mul = self:Clip1() > 0 and 1 or 0
		--wep:ManipulateBoneScale(12,Vector(mul,mul,mul),false)
	end
end

SWEP.Penetration = 7
SWEP.lengthSub = 31
SWEP.handsAng = Angle(0, 1, 0)
SWEP.DistSound = "mp5k/mp5k_dist.wav"

--local to head
SWEP.RHPos = Vector(3,-6,4)
SWEP.RHAng = Angle(0,-5,90)
--local to rh
SWEP.LHPos = Vector(13,-2,-3.5)
SWEP.LHAng = Angle(-40,0,-90)

--RELOAD ANIMS SMG????

SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(0,-5,-4),
	Vector(-15,5,-7),
	Vector(-15,5,-15),
	Vector(0,-5,-4),
	Vector(0,-5,-4),
	Vector(0,0,0),
	"fastreload",
	Vector(2,2,0),
	Vector(2,2,0),
	Vector(2,2,0),
	Vector(-4,2,0),
	Vector(0,0,0),
	"reloadend",
	Vector(0,0,0)
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
	5,
	5,
	5,
	0,
	0,
	0,
	0,
	0,
	0
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(-35,0,0),
	Angle(-55,0,0),
	Angle(-75,0,0),
	Angle(-75,0,0),
	Angle(-75,0,0),
	Angle(-25,0,0),
	Angle(0,0,0),
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0)
}
SWEP.ReloadAnimRHAng = {
	Angle(0,0,0)
}
SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(0,25,25),
	Angle(5,25,25),
	Angle(-5,25,25),
	Angle(0,0,-15),
	Angle(0,0,-25),
	Angle(-25,0,-25),
	Angle(-15,0,-15),
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