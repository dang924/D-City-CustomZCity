SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Combine Sniper Rifle"
SWEP.Author = "Universal Union"
SWEP.Instructions = "A powerful combine semi-automatic sniper rifle. Fires the same pulse ammo, but the force of the bullet is much greater."
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/w_models/combine_sniper_test_huy.mdl"
SWEP.WepSelectIcon2 = Material("vgui/wep_jack_hmcd_combinesniper")
SWEP.IconOverride = "vgui/wep_jack_hmcd_combinesniper"
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 5
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Pulse"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 80
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 80
SWEP.Primary.Sound = {"weapons/tfa_hl2r/ar2/ar2_secondary_fire.wav", 120, 90, 100}
SWEP.Primary.Wait = 1.0
SWEP.ShellEject = true
SWEP.MuzzleEffectType = 0
SWEP.CustomShell = "Pulse"
SWEP.HoldType = "rpg"

SWEP.addweight = 20
SWEP.podkid = 0.25

SWEP.ZoomPos = Vector(-22, 0.1, 5.0923)
SWEP.Ergonomics = 0.7
SWEP.WorldPos = Vector(19,-1.1,-5)
SWEP.WorldAng = Angle(0, 0, 0)

SWEP.attPos = Vector(0,0,2)
SWEP.attAng = Angle(-90,0,0)
SWEP.AttachmentPos = Vector(-26.4566, -0.0885, -1.6433)
SWEP.AttachmentAng = Angle(0, 0, 0)
SWEP.LaserOriginPos = Vector(24, 0, 4.6)
SWEP.LaserOriginAng = Angle(0, 0, 0)
SWEP.LaserOriginAttachment = "laser"
SWEP.laser = true
SWEP.lasertoggle = 1
SWEP.laserData = {
	offsetPos = Vector(0, 0, 0),
	offsetAng = Angle(0, 0, 0),
	color = Color(89, 230, 255, 220),
	supportFlashlight = false,
	laserSize = 1.4,
	shouldalwaysdraw = true,
}

SWEP.DistSound = "weapons/tfa_ins2/m40a1/m40a1_fire.wav"

SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(8,8,-3)
SWEP.holsteredAng = Angle(-150, -5, 180)

SWEP.mat = Material("combine_sniper/huyhuy")
SWEP.scopemat = Material("decals/scope.png")
SWEP.perekrestie = Material("decals/perekrestie6.png")
SWEP.sizeperekrestie = 4200

SWEP.localScopePos = Vector(-30,0.1,3.9)
SWEP.scope_blackout = 700
SWEP.rot = 0
SWEP.FOVMin = 10
SWEP.FOVMax = 20
SWEP.perekrestieSize = false
SWEP.blackoutsize = 3100
SWEP.scopedef = true

SWEP.AnimShootMul = 2
SWEP.AnimShootHandMul = 5
SWEP.addSprayMul = 5

SWEP.PenetrationMultiplier = 4
SWEP.DamageMultiplier = 3

SWEP.weight = 5
SWEP.punchmul = 0.6
SWEP.punchspeed = 4

SWEP.dort = true

if CLIENT then
	function SWEP:DrawHUDAdd()
		
	end

	local lfang2 = Angle(0, 30, 0)
	local lfang1 = Angle(0, 30, 0)
	local lfang0 = Angle(-0, -30, 10)
	local vec_zero = Vector(0,0,0)
	local l_finger02 = Angle(-10,0,0)
	function SWEP:AnimHoldPost()
		self:BoneSet("l_finger0", vec_zero, lfang0)
		self:BoneSet("l_finger02", vec_zero, l_finger02)
		self:BoneSet("l_finger1", vec_zero, lfang1)
		self:BoneSet("l_finger2", vec_zero, lfang2)
	end
end

SWEP.LocalMuzzlePos = Vector(31,0,1.2)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.CanSuicide = false

SWEP.RestPosition = Vector(10, -1, 4)

--local to head
SWEP.RHPos = Vector(3,-10,5)
SWEP.RHAng = Angle(0,-5,90)
--local to rh
SWEP.LHPos = Vector(14,1,-5)
SWEP.LHAng = Angle(-90,-90,-90)

local finger1 = Angle(-15,0,5)
local finger2 = Angle(-15,45,-5)
local laser_origin_names = {
	"laser",
	"1",
	"muzzle",
	"muzzle_flash",
}

local function resolveLaserOrigin(model, attachmentName)
	if not IsValid(model) or not attachmentName then return end
	local attachmentId = model:LookupAttachment(attachmentName)
	if not attachmentId or attachmentId <= 0 then return end
	return model:GetAttachment(attachmentId)
end

function SWEP:GetLaserOrigin(model, attachmentData)
	if isvector(self.LaserOriginPos) then
		local pinModel = self:GetWeaponEntity()
		if not IsValid(pinModel) then
			pinModel = model
		end

		if IsValid(pinModel) then
			local pinPos, pinAng = LocalToWorld(
				self.LaserOriginPos,
				self.LaserOriginAng or angle_zero,
				pinModel:GetPos(),
				pinModel:GetAngles()
			)

			return LocalToWorld(self.AttachmentPos or vector_origin, self.AttachmentAng or angle_zero, pinPos, pinAng)
		end
	end

	local origin = resolveLaserOrigin(model, self.LaserOriginAttachment)
	if not origin then
		for i = 1, #laser_origin_names do
			origin = resolveLaserOrigin(model, laser_origin_names[i])
			if origin then break end
		end
	end

	if origin then
		return LocalToWorld(self.AttachmentPos or vector_origin, self.AttachmentAng or angle_zero, origin.Pos, origin.Ang)
	end

	local modelPos, modelAng = model:GetPos(), model:GetAngles()
	return LocalToWorld(attachmentData.offsetPos or vector_origin, attachmentData.offsetAng or angle_zero, modelPos, modelAng)
end

function SWEP:InitializePost()
	if self.lasertoggle == nil then
		self.lasertoggle = 1
	end
	self.laser = true
end

SWEP.Primary.Wait = 0.1
SWEP.ReloadTime = 4
SWEP.ReloadSoundes = {
	"none",
	"none",
	"none",
	"none",
	"weapons/ar2/ar2_magout.wav",
	"none",
	"none",
	"weapons/ar2/ar2_magin.wav",
	"none",
	"weapons/ar2/ar2_reload_rotate.wav",
	"none",
	"weapons/ar2/ar2_push.wav",
	"none",
	"none",
	"none",
	"none"
}

-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(0,1,-2),
	Vector(0,2,-2),
	Vector(0,3,-2),
	Vector(0,3,-8),
	Vector(-8,15,-15),
	Vector(-15,20,-25),
	Vector(-13,12,-5),
	Vector(-6,6,-3),
	Vector(-1,5,-1),
	Vector(0,4,-1),
	"fastreload",
	Vector(0,3,-3),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	"reloadend",
	Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0)
}

SWEP.ReloadAnimLHAng = {
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
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-25,15,-15),
	Angle(-25,15,-25),
	Angle(-10,15,-25),
	Angle(15,0,-25),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,-5),
	Angle(0,25,-40),
	Angle(0,25,-45),
	Angle(0,25,-25),
	Angle(0,25,-25),
	Angle(0,0,2),
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