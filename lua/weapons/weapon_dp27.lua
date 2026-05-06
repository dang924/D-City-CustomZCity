SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "DP-27"
SWEP.Author = "Degtyarev plant"
SWEP.Instructions = "Machine gun chambered in 7.62x54 mm\n\nRate of fire 500 rounds per minute"
SWEP.Category = "Weapons - Machineguns"
SWEP.Primary.ClipSize = 47
SWEP.Primary.DefaultClip = 47
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x54 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 80
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 80
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/rpk/rpk_tp.wav", 75, 100, 110}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak47/handling/ak47_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.12
SWEP.ReloadTime = 6.2
SWEP.FakeEjectBrassATT = "2"
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
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

function SWEP:PostFireBullet(bullet)
	--self:GetWM():SetBodygroup(1,math.min(self:Clip1()-1,1))
	local owner = self:GetOwner()
	if ( SERVER or self:IsLocal2() ) and owner:OnGround() then
		if IsValid(owner) and owner:IsPlayer() then
			owner:SetVelocity(owner:GetVelocity() - owner:GetVelocity()/0.45)
		end
	end
end

SWEP.CanSuicide = false

SWEP.PPSMuzzleEffect = "muzzleflash_MINIMI" -- shared in sh_effects.lua

SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/pwb2/weapons/w_pkm.mdl"
SWEP.WorldModelFake = "models/weapons/tfa_ins2/wpn_dp28_hud_v.mdl"
SWEP.FakeScale = 0.88
SWEP.FakePos = Vector(-12, 7.0, 8.7)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(1,0,0)
SWEP.AttachmentAng = Angle(0,0,90)
--PrintBones(Entity(1):GetActiveWeapon():GetWM())

SWEP.FakeVPShouldUseHand = true
SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload",
}

SWEP.GunCamPos = Vector(6,-17,-4)
SWEP.GunCamAng = Angle(190,0,-90)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 40

SWEP.FakeReloadSounds = {
	[0.26] = "weapons/ppsh/ppsh_boltback.wav",
	[0.42] = "weapons/ppsh/ppsh_magout.wav",
	[0.55] = "weapons/galil/handling/galil_drum_magout.wav",
	[0.58] = "weapons/galil/handling/galil_drum_magout_rattle.wav",
	[0.85] = "weapons/galil/handling/galil_drum_magin.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.99] = "weapons/galil/handling/galil_drum_maghit.wav",
}

SWEP.NoIdleLoop = true
SWEP.GetDebug = false
SWEP.FakeEmptyReloadSounds = {
	[0.26] = "weapons/ppsh/ppsh_boltback.wav",
	[0.42] = "weapons/ppsh/ppsh_magout.wav",
	[0.55] = "weapons/galil/handling/galil_drum_magout.wav",
	[0.58] = "weapons/galil/handling/galil_drum_magout_rattle.wav",
	[0.85] = "weapons/galil/handling/galil_drum_magin.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.99] = "weapons/galil/handling/galil_drum_maghit.wav",
}
--SWEP.MagModel = "models/weapons/zcity/w_glockmag.mdl"
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.61] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(2, vecPochtiZero)
			self:GetWM():ManipulateBoneScale(3, vecPochtiZero)
		end,
		[0.72] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(2, vector_full)
			self:GetWM():ManipulateBoneScale(3, vector_full)
		end
	}
end


SWEP.ScrappersSlot = "Primary"
SWEP.weight = 4.5

SWEP.ShockMultiplier = 2

SWEP.CustomShell = "762x54"
SWEP.EjectPos = Vector(6,20,-6)
SWEP.EjectAng = Angle(90,0,0)
SWEP.EjectAddAng = Angle(-60,0,0)

SWEP.WepSelectIcon2 = Material("vgui/entities/hud/weapon_tfa_dp28")
SWEP.IconOverride = "vgui/entities/hud/weapon_tfa_dp28"

SWEP.weaponInvCategory = 1
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 1.058, 5.5867)
SWEP.RHandPos = Vector(4, -2, 0)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.ShellEject = "EjectBrass_762Nato"
SWEP.Spray = {}
for i = 1, 47 do
	SWEP.Spray[i] = Angle(-0.03 - math.cos(i) * 0.02, math.cos(i * i) * 0.03, 0) * 1.5
end

SWEP.LocalMuzzlePos = Vector(37.836,1.1,3.751)
SWEP.LocalMuzzleAng = Angle(-0.0,-0.00,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.Ergonomics = 0.6
SWEP.OpenBolt = true
SWEP.Penetration = 20
SWEP.WorldPos = Vector(-1, -0.5, 0)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, 0, 0)
SWEP.attAng = Angle(90.00, -0.0, 0)
SWEP.AimHands = Vector(0, 1, -3.5)
SWEP.lengthSub = 15
SWEP.DistSound = "m249/m249_dist.wav"
SWEP.bipodAvailable = true
SWEP.bipodsub = 10
SWEP.RestPosition = Vector(20, 0, 6)

SWEP.RecoilMul = 0.3

SWEP.availableAttachments = {
}
function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 3)
		wep:ManipulateBonePosition(1,Vector(0 ,0 ,-2*self.shooanim ),false)
	end
end
function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) then
		self:GetWM():ManipulateBoneScale(7, vector_origin)
	end
end
--local to head
SWEP.RHPos = Vector(4,-7,4)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(9,-4,-5)
SWEP.LHAng = Angle(-10,10,-120)

local ang1 = Angle(30, -15, 0)
local ang2 = Angle(0, 10, 0)

function SWEP:AnimHoldPost()
	--self:BoneSet("l_finger0", vector_origin, ang1)
	--self:BoneSet("l_finger02", vector_origin, ang2)
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