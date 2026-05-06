SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "MG 34"
SWEP.Author = "Mauserwerke AG"
SWEP.Instructions = "Machine gun chambered in 7.92x57mm Mauser\n\nRate of fire 800 rounds per minute"
SWEP.Category = "Weapons - Machineguns"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_mach_m249para.mdl"
SWEP.WorldModelFake = "models/weapons/comradebear/ww2/c_mg34_temp.mdl"
SWEP.FakeScale = 1
SWEP.FakePos = Vector(-11.5, 5, 9.7)
SWEP.FakeAng = Angle(0.0, 0.00, 0)
SWEP.AttachmentPos = Vector(-0,0.7,0.2)
SWEP.AttachmentAng = Angle(0,0,0)

SWEP.FakeEjectBrassATT = "2"




SWEP.FakeVPShouldUseHand = true
SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reload_empty",
}

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 35

SWEP.FakeReloadSounds = {
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.25] = "weapons/m249/m249_coveropen.wav",
	[0.4] = "weapons/m249/m249_magout_full.wav",
	[0.63] = "weapons/m249/m249_shoulder.wav",
	[0.7] = "weapons/m249/m249_magin.wav",
	[0.78] = "weapons/m249/m249_beltpullout.wav",
	[0.81] = "weapons/m249/m249_fetchmag.wav",
	[0.94] = "weapons/m249/m249_coverclose.wav",
	[1.04] = "weapons/m249/m249_shoulder.wav"
}

SWEP.FakeEmptyReloadSounds = {
	[0.16] = "weapons/m249/m249_shoulder.wav",
	[0.25] = "weapons/m249/m249_coveropen.wav",
	[0.35] = "weapons/m249/m249_boltback.wav",
	[0.38] = "weapons/m249/m249_boltrelease.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.52] = "weapons/m249/m249_magout.wav",
	[0.73] = "weapons/m249/m249_shoulder.wav",
	[0.78] = "weapons/m249/m249_magin.wav",
	[0.85] = "weapons/m249/m249_beltpullout.wav",
	[0.88] = "weapons/m249/m249_fetchmag.wav",
	[0.97] = "weapons/m249/m249_coverclose.wav",
	[1.04] = "weapons/m249/m249_shoulder.wav"
}
SWEP.MagModel = "models/weapons/zcity/w_glockmag.mdl"

local function UpdateVisualBullets(mdl,count)
	for i = 1, 6 do
		local boneid = 67 - i
		mdl:ManipulateBoneScale(boneid,i <= count and Vector(1,1,1) or Vector(0,0,0))
	end
end
SWEP.FakeReloadEvents = {
	[0.63] = function( self )
		if CLIENT then
			UpdateVisualBullets(self:GetWM(),20)
		end
	end,
}

SWEP.RestPosition = Vector(10, 0, 4)

function SWEP:PostFireBullet(bullet)
	if CLIENT then
		self:PlayAnim("base_fire_2",1.5,nil,false)
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

SWEP.FakeMagDropBone = "magazine"

SWEP.WepSelectIcon2 = Material("entities/arc9_cb_ger_mg34.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_cb_ger_mg34.png"

--"models/weapons/v_m249.mdl"
SWEP.CustomShell = "762x54"
SWEP.ShellEject = "EjectBrass_762Nato"
SWEP.CustomSecShell = "m60len"
--SWEP.EjectPos = Vector(0,-20,5)
--SWEP.EjectAng = Angle(0,90,0)

SWEP.CanSuicide = false

SWEP.ScrappersSlot = "Primary"

SWEP.weight = 4.5

SWEP.LocalMuzzlePos = Vector(30.8,1.38,5.0)
SWEP.LocalMuzzleAng = Angle(0.0,0.00,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.ShockMultiplier = 2

SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 50
SWEP.Primary.DefaultClip = 50
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.92x57mm Mauser"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 80
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 80
SWEP.Primary.Sound = {"weapons/newsndw/pkmnew_fp.wav", 75, 100, 110}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/fnfal/handling/fnfal_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.058
SWEP.ReloadTime = 12.5
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb/weapons/m249/coverup.wav",
	"none",
	"none",
	"pwb/weapons/m249/boxout.wav",
	"none",
	"pwb/weapons/m249/boxin.wav",
	"none",
	"none",
	"none",
	"none",
	"none",
	"none",
	"none"
}

SWEP.PPSMuzzleEffect = "muzzleflash_MINIMI" -- shared in sh_effects.lua

SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.holsteredPos = Vector(0, 9, -8)
SWEP.holsteredAng = Angle(-30, 180, 0)
SWEP.ZoomPos = Vector(0, 1.3514, 7.5577)
SWEP.RHandPos = Vector(-5, -2, 0)
SWEP.LHandPos = Vector(7, -2, -2)
--local to head
SWEP.RHPos = Vector(7,-7,5)
SWEP.RHAng = Angle(0,0,90)
--local to rh
SWEP.LHPos = Vector(8.5,-2,-6)
SWEP.LHAng = Angle(-20,0,-90)
SWEP.Spray = {}
for i = 1, 50 do
	SWEP.Spray[i] = Angle(-0.05 - math.cos(i) * 0.04, math.cos(i * i) * 0.07, 0) * 2.3
end

SWEP.Ergonomics = 0.8
SWEP.OpenBolt = true
SWEP.Penetration = 20
SWEP.WorldPos = Vector(4, -0.5, 1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, -1, 0)
SWEP.attAng = Angle(0, -0.2, 0)
SWEP.AimHands = Vector(0, 1.65, -3.65)
SWEP.lengthSub = 15
SWEP.DistSound = "m249/m249_dist.wav"
SWEP.availableAttachments = {
}

local vector_one = Vector(1,1,1)
local vector_zero = Vector(0,0,0)

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4, self.shooanim or 0, (self:Clip1() > 0 or self.reload) and 0 or 3)
		--wep:ManipulateBonePosition(44, Vector(0, 0, -1*self.shooanim), false)
		--self:GetWM():SetBodygroup(0,0)
	end
end

function SWEP:ModelCreated(model)
	self:GetWM():SetBodygroup(2,4)
end

SWEP.punchmul = 7
SWEP.punchspeed = 0.5

SWEP.RecoilMul = 1.0

SWEP.bipodAvailable = true
SWEP.bipodsub = 15

-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-4,-6,1),
	Vector(0,-7,-5),
	Vector(0,-9,1),
	Vector(-4,-6,1),
	Vector(-4,2,2),
	Vector(-4,4,2),
	Vector(-4,15,-15),
	Vector(-4,4,2),
	Vector(-4,4,2),
	Vector(-4,2,2),
	Vector(0,-9,1),
	Vector(0,-7,-5),
	Vector(-4,-6,1),
	Vector(-2,-3,1),
	"reloadend",
	Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,190),
	Angle(0,0,190),
	Angle(0,0,190),
	Angle(0,0,120),
	Angle(0,0,190),
	Angle(0,0,190),
	Angle(0,0,190),
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
	Angle(5,15,0),
	Angle(-15,15,0),
	Angle(-15,15,0),
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