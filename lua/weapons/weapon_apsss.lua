SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "APS"
SWEP.Author = "Vytatsky Polyany Machine-Building Plant"
SWEP.Instructions = "Automatic Pistol chambered in 9x18mm"
SWEP.Category = "Weapons - Pistols"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/zcity/w_p99.mdl"
SWEP.WorldModelFake = "models/weapons/arc9/stalker2/pt_aps/v_apb.mdl"
--uncomment for funny
SWEP.FakePos = Vector(-20.5, 5.1, 6.0)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0,0,-0.2)
SWEP.AttachmentAng = Angle(0,0,90)
//MagazineSwap
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakeEjectBrassATT = "3"
SWEP.FakeAttachment = "2"

SWEP.AnimList = {
	["idle"] = "basepose",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}

SWEP.FakeReloadSounds = {
	[0.35] = "zcitysnd/sound/weapons/m9/handling/m9_magrelease.wav",
	[0.5] = "zcitysnd/sound/weapons/m9/handling/m9_magout.wav",
	--[0.45] = "weapons/tfa_ins2/usp_tactical/magout.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.20] = "weapons/universal/uni_pistol_holster.wav",
	[0.8] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.75] = "weapons/universal/uni_crawl_l_02.wav",
	[0.9] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	--[1] = "weapons/tfa_ins2/usp_match/usp_match_boltrelease.wav",
	--[0.77] = "weapons/tfa_ins2/usp_match/usp_match_maghit.wav",
	--[0.95] = "weapons/tfa_ins2/usp_match/usp_match_boltrelease.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.35] = "zcitysnd/sound/weapons/m9/handling/m9_magrelease.wav",
	[0.45] = "zcitysnd/sound/weapons/m9/handling/m9_magout.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.28] = "weapons/universal/uni_pistol_draw_01.wav",
	[0.41] = "weapons/universal/uni_crawl_l_05.wav",
	[0.75] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.85] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	[0.9] = "weapons/universal/uni_crawl_l_03.wav",
	[1] = "zcitysnd/sound/weapons/m9/handling/m9_boltrelease.wav",
}

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 80
SWEP.MagModel = "models/weapons/upgrades/w_magazine_makarov_8.mdl" 

SWEP.FakeMagDropBone = 106

SWEP.WepSelectIcon2 = Material("entities/arc9_eft_aps.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_eft_aps.png"

SWEP.CustomShell = "9x18"
--SWEP.EjectPos = Vector(0,0,0)
--SWEP.EjectAng = Angle(0,90,0)

SWEP.weight = 2
SWEP.punchmul = 1.2
SWEP.punchspeed = 4
SWEP.ScrappersSlot = "Secondary"

SWEP.LocalMuzzlePos = Vector(4.4,0.8,2.35)
SWEP.LocalMuzzleAng = Angle(0.68,1,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor4", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(1.7,-0.1,0), {}},
		["mount"] = Vector(-0.95,0.43,0.065),
	}
}

SWEP.weaponInvCategory = 2
SWEP.ShellEject = "EjectBrass_9mm"
SWEP.Primary.ClipSize = 20
SWEP.Primary.DefaultClip = 20
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "9x18 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 8
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/makarov/makarov_fp.wav", 75, 90, 100}
SWEP.SupressedSound = {"zcitysnd/sound/weapons/makarov/makarov_suppressed_fp.wav", 55, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/makarov/handling/makarov_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Force = 20
SWEP.ReloadTime = 4.1
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb/weapons/fnp45/clipout.wav",
	"none",
	"none",
	"pwb/weapons/fnp45/clipin.wav",
	"pwb/weapons/fnp45/sliderelease.wav",
	"none",
	"none",
	"none"
}
SWEP.Primary.Wait = 0.075
SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = false
SWEP.HoldType = "revolver"
SWEP.ZoomPos = Vector(0, 0.6856, 2.9796)
SWEP.RHandPos = Vector(-5, -1.5, 2)
SWEP.LHandPos = false
SWEP.SprayRand = {Angle(-0, -0.01, 0), Angle(-0.01, 0.01, 0)}
SWEP.Ergonomics = 1
SWEP.AnimShootMul = 4.5
SWEP.AnimShootHandMul = 3
SWEP.addSprayMul = 0.25
SWEP.Penetration = 4

SWEP.ShockMultiplier = 1
SWEP.WorldPos = Vector(4.5, -1.5, -1.9)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(2.8, 0.1, 0.5)
SWEP.attAng = Angle(0, 0, 0)
SWEP.lengthSub = 25
SWEP.DistSound = "zcitysnd/sound/weapons/makarov/makarov_dist.wav"
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, -3, 2)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true
SWEP.ImmobilizationMul = 1

--local to head
SWEP.RHPos = Vector(12,-4.5,3.5)
SWEP.RHAng = Angle(5,-5,90)
--local to rh
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)

local finger1 = Angle(-25,10,25)
local finger2 = Angle(0,25,0)
local finger3 = Angle(31,1,-25)
local finger4 = Angle(-10,-5,-5)
local finger5 = Angle(0,-65,-15)
local finger6 = Angle(15,-5,-15)

function SWEP:AnimHoldPost()
	--self:BoneSet("r_finger0", vector_zero, finger6)
	--self:BoneSet("l_finger0", vector_zero, finger1)
    --self:BoneSet("l_finger02", vector_zero, finger2)
	--self:BoneSet("l_finger1", vector_zero, finger3)
	--self:BoneSet("r_finger1", vector_zero, finger4)
	--self:BoneSet("r_finger11", vector_zero, finger5)
end
SWEP.ShootAnimMul = 3
SWEP.SightSlideOffset = 1.2

SWEP.podkid = 0.65

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 2.2)
		wep:ManipulateBonePosition(208,Vector(-0.65*self.shooanim, 0,0),false)
		wep:ManipulateBonePosition(210,Vector(-0.65*self.shooanim, 0,0),false)
	end
end
---RELOAD ANIMS PISTOL

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
	Angle(6,0,5),
	Angle(15,0,14),
	Angle(16,0,16),
	Angle(4,0,12),
	Angle(-6,0,-2),
	Angle(-15,7,-15),
	Angle(-16,18,-35),
	Angle(-17,17,-42),
	Angle(-18,16,-44),
	Angle(-14,10,-46),
	Angle(-2,2,-4),
	Angle(0,0,0)
}