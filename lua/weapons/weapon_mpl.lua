SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Walther MPL"
SWEP.Author = "Walther"
SWEP.Instructions = "Submachine gun chambered in 9x19 mm\n\nRate of fire 550 rounds per minute"
SWEP.Category = "Weapons - Machine-Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/w_uzi.mdl"
SWEP.WorldModelFake = "models/weapons/v_walther_mpl_remake.mdl"
SWEP.FakePos = Vector(-12.5, 2.6, 6.3)
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0,0,-0.2)
SWEP.AttachmentAng = Angle(0,0,90)
SWEP.Primary.Sound = {"sounds_zcity/uzi/close.wav", 75, 120, 130}
SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reloadempty",
}

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 40
SWEP.punchmul = 1.5
SWEP.punchspeed = 3
SWEP.FakeReloadSounds = {
	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.31] = "weapons/mp5k/mp5k_magrelease.wav",
	[0.35] = "weapons/mp5k/mp5k_magout.wav",
	--[0.34] = "weapons/ak74/ak74_magout_rattle.wav",
	[0.60] = "weapons/universal/uni_crawl_l_02.wav",
	[0.75] = "weapons/mp5k/mp5k_magin.wav",
	[0.94] = "weapons/universal/uni_crawl_l_04.wav",
	--[0.9] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav"
}
--SWEP.GetDebug = false
SWEP.FakeEmptyReloadSounds = {
	[0.16] = "weapons/universal/uni_crawl_l_03.wav",
	[0.30] = "weapons/mp40/handling/mp40_boltback.wav",
	[0.36] = "zcitysnd/sound/weapons/ump45/handling/ump45_boltrelease.wav",
	--[0.34] = "weapons/ak74/ak74_magout_rattle.wav",
	[0.37] = "weapons/universal/uni_crawl_l_02.wav",
	[0.46] = "weapons/mp5k/mp5k_magrelease.wav",
	[0.50] = "weapons/mp5k/mp5k_magout.wav",
	[0.72] = "weapons/universal/uni_crawl_l_05.wav",
	[0.80] = "weapons/mp5k/mp5k_magin.wav",
	[1.02] = "weapons/universal/uni_crawl_l_04.wav",
	--[0.9] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav"
}

if CLIENT then
	local vector_full = Vector(1, 1, 1)

	SWEP.FakeReloadEvents = {
		[0.49] = function( self ) 
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,5,10) )
				self:GetWM():ManipulateBoneScale(69, vector_origin)
				self:GetWM():ManipulateBoneScale(70, vector_origin)
				self:GetWM():ManipulateBoneScale(71, vector_origin)
			end
		end,
		[0.65] = function( self ) 
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(69, vector_full)
				self:GetWM():ManipulateBoneScale(70, vector_full)
				self:GetWM():ManipulateBoneScale(71, vector_full)
			end
		end,
	}
end

SWEP.FakeMagDropBone = 69
SWEP.MagModel = "models/weapons/upgrades/w_magazine_m45_15.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,-0.5,0)
SWEP.lmagang2 = Angle(0,0,-10)

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_coldwar_walther_mpl_renewal")
SWEP.IconOverride = "vgui/hud/tfa_coldwar_walther_mpl_renewal"
SWEP.weight = 1.8
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.CustomShell = "9x19"
SWEP.Primary.ClipSize = 32
SWEP.Primary.DefaultClip = 32
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "9x19 mm Parabellum"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 20
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 20
SWEP.CanEpicRun = true
SWEP.EpicRunPos = Vector(-1,3,5)
SWEP.animposmul = 2
SWEP.Primary.Wait = 0.11
SWEP.ReloadTime = 5
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor4", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(3.7,0.1,-0.1), {}},
		["mount"] = Vector(-1.15,0.6,-0.05),
	},
}
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb/weapons/uzi/clipout.wav",
	"none",
	"none",
	"pwb/weapons/uzi/clipin.wav",
	"none",
	"none",
	"weapons/tfa_ins2/mp7/boltback.wav",
	"pwb2/weapons/vectorsmg/boltrelease.wav",
	"none",
	"none",
	"none",
	"none"
}

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, -0.2802, 4.5188)
SWEP.RHandPos = Vector(-15, 0, 3)
SWEP.LHandPos = false
SWEP.Spray = {}
for i = 1, 32 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.01, math.cos(i * 5) * 0.01, 0) * 0.4
end

SWEP.LocalMuzzlePos = Vector(12.706,-0.25,2.1)
SWEP.LocalMuzzleAng = Angle(-0.0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.Ergonomics = 1.6
SWEP.OpenBolt = true
SWEP.Penetration = 7
SWEP.WorldPos = Vector(3, -1.2, -1.5)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, 0.0, -0.0)
SWEP.attAng = Angle(0, 0, 0)
SWEP.lengthSub = 25
SWEP.DistSound = "mp5k/mp5k_dist.wav"
SWEP.AnimShootMul = 0.5
SWEP.AnimShootHandMul = 0.01

SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(0, 7.5, -1)
SWEP.holsteredAng = Angle(210, 0, 180)

--local to head
SWEP.RHPos = Vector(10,-6.5,3.5)
SWEP.RHAng = Angle(0,0,90)
--local to rh
SWEP.LHPos = Vector(8,-0.1,-3.5)
SWEP.LHAng = Angle(-110,-90,-90)

function SWEP:AnimHoldPost(model)
	self:BoneSet("l_finger0", Vector(0, 0, 0), Angle(10, -12, 0))
    --self:BoneSet("l_finger02", Vector(0, 0, 0), Angle(0, -10, 0))
end

--RELOAD ANIMS SMG????

SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(0,5,-5),
	Vector(-4,10,-5),
	Vector(-15,15,-25),
	Vector(-4,10,-5),
	Vector(0,5,-5),
	"fastreload",
	Vector(-1,-5,4),
	Vector(-1,-5,-5),
	Vector(-3,0,0),
	"reloadend",
}
SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,90),
	Angle(0,0,90),
	Angle(0,0,90),
	Angle(0,0,90),
	Angle(0,0,90),
	Angle(0,0,90),
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
	Angle(0,0,45),
	Angle(15,0,45),
	Angle(0,5,45),
	Angle(0,2,42),
	Angle(-5,0,15),
	Angle(10,0,-15),
	Angle(-15,0,-10),
	Angle(5,0,-0),
	Angle(0,0,0)
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