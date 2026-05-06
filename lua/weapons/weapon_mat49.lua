SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "MAT-49"
SWEP.Author = "Manufacture Nationale d'Armes de Tulle"
SWEP.Instructions = "Submachine gun chambered in 9x19 mm\n\nRate of fire 600 rounds per minute"
SWEP.Category = "Weapons - Machine-Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/w_uzi.mdl"
SWEP.WorldModelFake = "models/rs2_weapons/mat49/c_rs2v_mat49.mdl"
SWEP.FakePos = Vector(-11, 0.3, 5.)
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0,0,-0.2)
SWEP.AttachmentAng = Angle(0,0,90)
SWEP.Primary.Sound = {"sounds_zcity/uzi/close.wav", 75, 120, 130}
SWEP.MagIndex = nil
SWEP.stupidgun = false
SWEP.FakeEjectBrassATT = "2"
SWEP.FakeAttachment = "1"
SWEP.AnimList = {
	["idle"] = "mat49_shoulder_idle",
	["reload"] = "mat49_reloadhalf",
	["reload_empty"] = "mat49_reloadempty",
}
SWEP.NoIdleLoop = true

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 40
SWEP.punchmul = 1.5
SWEP.punchspeed = 3
SWEP.FakeReloadSounds = {
	[0.32] = "weapons/mp40/handling/mp40_magrelease.wav",
	[0.35] = "weapons/mp40/handling/mp40_magout.wav",
	[0.85] = "weapons/mp40/handling/mp40_magin.wav",
	[0.93] = "weapons/mp40/handling/mp40_maghit.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.27] = "weapons/mp40/handling/mp40_magrelease.wav",
	[0.30] = "weapons/mp40/handling/mp40_magout.wav",
	[0.75] = "weapons/mp40/handling/mp40_magin.wav",
	[0.8] = "weapons/mp40/handling/mp40_maghit.wav",
	[0.9] = "weapons/mp5k/mp5k_boltback.wav",
	[0.96] = "weapons/mp5k/mp5k_boltrelease.wav",
}

if CLIENT then
	local vector_full = Vector(1, 1, 1)

	SWEP.FakeReloadEvents = {
	}
end

SWEP.FakeMagDropBone = 62
SWEP.MagModel = "models/weapons/upgrades/w_magazine_m45_15.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,-1,0)
SWEP.lmagang2 = Angle(0,0,-10)

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_rs2v_mat49")
SWEP.IconOverride = "vgui/hud/tfa_rs2v_mat49"
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
SWEP.animposmul = 2
SWEP.CanEpicRun = true
SWEP.EpicRunPos = Vector(0,10,10)
SWEP.Primary.Sound = {"homigrad/weapons/pistols/mp5-1.wav", 75, 120, 130}
SWEP.Primary.Wait = 0.1
SWEP.ReloadTime = 5
SWEP.availableAttachments = {
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
SWEP.ZoomPos = Vector(0, 0.29, 4.9967)
SWEP.RHandPos = Vector(-15, 0, 3)
SWEP.LHandPos = false
SWEP.Spray = {}
for i = 1, 32 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.01, math.cos(i * 8) * 0.01, 0) * 1
end

SWEP.LocalMuzzlePos = Vector(11,0.31,3.75)
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

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.5,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 3)
		wep:ManipulateBonePosition(91,Vector(1*self.shooanim ,0 ,0 ),false)
	end
end

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