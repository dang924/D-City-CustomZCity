SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "RPD"
SWEP.Author = "Degtyarev plant"
SWEP.Instructions = "Machine gun chambered in 7.62x39 mm\n\nRate of fire 750 rounds per minute"
SWEP.Category = "Weapons - Machineguns"
SWEP.Primary.ClipSize = 100
SWEP.Primary.DefaultClip = 100
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x39 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 50
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 50
SWEP.Primary.Sound = {"weapons/newakm/akmm_tp.wav", 75, 100, 110}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak47/handling/ak47_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.08
SWEP.ReloadTime = 11
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakeEjectBrassATT = "2"
SWEP.FakeBodyGroups = "101111111111"
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb2/weapons/pkm/pkm_coverup.wav",
	"none",
	"none",
	"pwb2/weapons/pkm/pkm_boxout.wav",
	"none",
	"pwb2/weapons/pkm/pkm_boxin.wav",
	"none",
	"none",
	"pwb2/weapons/pkm/pkm_coverdown.wav",
	"none",
	"none",
	"none",
	"none"
}

local function UpdateVisualBullets(mdl,count)
	for i = 1, 26 do
		local boneid = 123 + i
		mdl:ManipulateBoneScale(boneid,i <= count and Vector(1,1,1) or Vector(0,0,0))
	end
end

function SWEP:PostFireBullet(bullet)
	if CLIENT then
		self:PlayAnim("fire_1",1.5,nil,false)
		UpdateVisualBullets(self:GetWM(),self:Clip1())
	end
	local owner = self:GetOwner()
	if ( SERVER or self:IsLocal2() ) and owner:OnGround() then
		if IsValid(owner) and owner:IsPlayer() then
			owner:SetVelocity(owner:GetVelocity() - owner:GetVelocity()/0.45)
		end
	end
	SlipWeapon(self, bullet)
end

SWEP.CanSuicide = true

SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/arc9/darsu_eft/c_rpd.mdl" -- увеличить модельку где-то в 1.5
//SWEP.FakeScale = 1.5
SWEP.FakeAttachment = "1"
SWEP.FakePos = Vector(-7, 5.85, 7.5)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.RestPosition = Vector(13, 1, 3)
SWEP.AttachmentPos = Vector(1,0,0)
SWEP.AttachmentAng = Angle(0,0,90)
//MagazineSwap
--PrintBones(Entity(1):GetActiveWeapon():GetWM())

SWEP.FakeVPShouldUseHand = true
SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty"
}

SWEP.GunCamPos = Vector(6,-17,-4)
SWEP.GunCamAng = Angle(190,0,-90)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 40

SWEP.FakeReloadSounds = {
	[0.15] = "weapons/m249/m249_shoulder.wav",
	[0.25] = "weapons/pkm/coverup.wav",
	[0.30] = "weapons/pkm/bullet.wav",
	[0.42] = "weapons/galil/handling/galil_magrelease.wav",
	[0.45] = "weapons/galil/handling/galil_drum_magout.wav",
	[0.53] = "weapons/galil/handling/galil_drum_magout_rattle.wav",
	[0.75] = "weapons/galil/handling/galil_drum_magin.wav",
	[0.80] = "weapons/galil/handling/galil_magrelease.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.85] = "weapons/pkm/chain.wav",
	[0.99] = "weapons/pkm/coverdown.wav",
}

SWEP.GetDebug = false
SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/m249/m249_boltback.wav",
	[0.3] = "weapons/m249/m249_boltrelease.wav",
	[0.15] = "weapons/m249/m249_shoulder.wav",
	[0.42] = "weapons/pkm/coverup.wav",
	[0.5] = "weapons/galil/handling/galil_magrelease.wav",
	[0.55] = "weapons/galil/handling/galil_drum_magout.wav",
	[0.65] = "weapons/galil/handling/galil_drum_magout_rattle.wav",
	[0.8] = "weapons/galil/handling/galil_drum_magin.wav",
	[0.83] = "weapons/galil/handling/galil_magrelease.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.85] = "weapons/pkm/chain.wav",
	[0.99] = "weapons/pkm/coverdown.wav",
}
--SWEP.MagModel = "models/weapons/zcity/w_glockmag.mdl"

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.56] = function( self, timeMul )
			if self:Clip1() < 1 then
			hg.CreateMag( self, Vector(-5,-5,0), nil, true )
			self:GetWM():SetBodygroup(3,0)
			self:GetWM():SetBodygroup(2,0)
			end
		end,
		[0.63] = function( self, timeMul )
			if self:Clip1() < 1 then
			self:GetWM():SetBodygroup(2,1)
			UpdateVisualBullets(self:GetWM(),20)
			self:GetWM():SetBodygroup(3,1)
		end
	end,
	[0.6] = function( self, timeMul )
			if self:Clip1() >= 1 then
			UpdateVisualBullets(self:GetWM(),20)
		end
	end,
	}
end
SWEP.FakeMagDropBone = 96
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_rpd_dropped2.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0.0,0,0)
SWEP.lmagang2 = Angle(0,0,0)


SWEP.ScrappersSlot = "Primary"
SWEP.weight = 4.0

SWEP.ShockMultiplier = 2

SWEP.CustomShell = "762x54"
SWEP.CustomSecShell = "m60len"

SWEP.WepSelectIcon2 = Material("entities/arc9_eft_rpd.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_eft_rpd.png"

SWEP.weaponInvCategory = 1
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 1.5854, 6.6118)
SWEP.RHandPos = Vector(4, -2, 0)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.ShellEject = "EjectBrass_762Nato"
SWEP.Spray = {}
for i = 1, 100 do
	SWEP.Spray[i] = Angle(-0.03 - math.cos(i) * 0.02, math.cos(i * i) * 0.03, 0) * 1
end

SWEP.LocalMuzzlePos = Vector(34.836,1.6,4.65)
SWEP.LocalMuzzleAng = Angle(-0.0,-0.00,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.Ergonomics = 0.8
SWEP.OpenBolt = true
SWEP.Penetration = 15
SWEP.WorldPos = Vector(-1, -0.5, 0)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, 0, 0)
SWEP.attAng = Angle(-0.00, -0.0, 0)
SWEP.AimHands = Vector(0, 1, -3.5)
SWEP.lengthSub = 15
SWEP.DistSound = "m249/m249_dist.wav"
SWEP.bipodAvailable = true
SWEP.bipodsub = 15

SWEP.RecoilMul = 0.3

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor1", Vector(0,0,0), {}},
		["mount"] = Vector(-0.8,0.5,0.15),
		["mountAngle"] = Angle(0,0,0)
	},
}

SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(7, 11, -7)
SWEP.holsteredAng = Angle(210, 0, 170)
--local to head
SWEP.RHPos = Vector(4,-7,4)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(9,-4,-5)
SWEP.LHAng = Angle(-10,10,-120)

local ang1 = Angle(30, -15, 0)
local ang2 = Angle(0, 10, 0)
local vector_one = Vector(1,1,1)
local vector_zero = Vector(0,0,0)

function SWEP:AnimHoldPost()
	--self:BoneSet("l_finger0", vector_origin, ang1)
	--self:BoneSet("l_finger02", vector_origin, ang2)
end

function SWEP:ModelCreated(model)
	model:ManipulateBoneScale(124, vector_origin)
	for i = 172, 219 do
	self:GetWM():ManipulateBoneScale(i, vector_origin)
	end
	model:SetBodyGroups(self.FakeBodyGroups)
end

-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(5,-2,7),
	Vector(7,-2,4),
	Vector(-5,-5,1),
	Vector(-5,-5,1),
	Vector(-15,-5,1),
	Vector(-5,-2,15),
	Vector(-5,-5,1),
	Vector(7,-2,4),
	Vector(5,-2,7),
	Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(45,0,-90),
	Angle(45,0,-90),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(10,0,0),
	Angle(10,0,0),
	Angle(0,15,0),
	Angle(15,15,0),
	Angle(-15,-15,0),
	Angle(-15,-5,0),
	Angle(0,0,0),
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