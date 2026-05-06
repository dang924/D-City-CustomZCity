SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "SVDS"
SWEP.Author = "Kalashnikov Concern Norinco"
SWEP.Instructions = "Semi-automatic Marksman rifle chambered in 7.62x54 mm"
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_g3sg1.mdl"
SWEP.WorldModelFake = "models/weapons/arc9/darsu_eft/c_svds.mdl"

SWEP.FakePos = Vector(-13, 4.5, 6.5)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0.5,0.1,0.3)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeScale = 0.95
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"
SWEP.FakeBodyGroups = "110010111000000"

function SWEP:OnCantReload()
	--inspect1
	--print("huy")
	if self.Inspecting and self.Inspecting > CurTime() then return end
	self.Inspecting = CurTime() + 4.5
	self:PlayAnim("check_1",4.5,false,function(self)
		self:PlayAnim("idle",1)
		--self.Inspecting = false
	end,false,true)

end

SWEP.AnimsEvents = {
	["check_1"] = {
		[0.2] = function(self)
			self:EmitSound("weapons/tfa_nam_svd/svd_magrelease.wav",55)
		end,
		[0.3] = function(self)
			self:EmitSound("weapons/tfa_nam_svd/svd_magout.wav",55)
		end,
		[0.8] = function(self)
			self:EmitSound("weapons/tfa_nam_svd/svd_magin.wav",55)
		end,
	},
}



SWEP.FakeReloadSounds = {
	[0.35] = "weapons/tfa_nam_svd/svd_magrelease.wav",
	[0.4] = "weapons/tfa_nam_svd/svd_magout.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.95] = "weapons/tfa_nam_svd/svd_magin.wav",
	--[0.91] = "weapons/tfa_nam_svd/svd_boltback.wav",
	--[0.92] = "weapons/tfa_nam_svd/svd_boltrelease.wav",
	[1] = "",
}

SWEP.FakeEmptyReloadSounds = {
	--[0.22] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.27] = "weapons/tfa_nam_svd/svd_magrelease.wav",
	[0.3] = "weapons/tfa_nam_svd/svd_magout.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.7] = "weapons/tfa_nam_svd/svd_magin.wav",
	[0.90] = "weapons/tfa_nam_svd/svd_boltback.wav",
	[0.95] = "weapons/tfa_nam_svd/svd_boltrelease.wav",
	[1] = "",
}
SWEP.MagModel = "models/kali/weapons/10rd m14 magazine.mdl"

SWEP.FakeMagDropBone = "mod_magazine"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,1.2,0)
SWEP.lmagang2 = Angle(0,0,15)
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 40

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.6] = function( self, timeMul )
			if self:Clip1() >= 1 then
				for i = 93, 95 do
					self:GetWM():ManipulateBoneScale(i, vector_full)
				end
			end
		end,
		[0.31] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(20,0,10), "11111", true )
				self:GetWM():ManipulateBoneScale(50, vecPochtiZero)
				for i = 93, 95 do
					self:GetWM():ManipulateBoneScale(i, vecPochtiZero)
				end
			end 
		end,
		[0.45] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(50, vector_full)
				for i = 93, 95 do
					self:GetWM():ManipulateBoneScale(i, vector_full)
				end
			end
		end,
	}
end

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload1",
	["reload_empty"] = "reload_empty1_2",
}

SWEP.ScrappersSlot = "Primary"
SWEP.WepSelectIcon2 = Material("entities/arc9_eft_svds.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_eft_svds.png"
SWEP.weight = 3.5
SWEP.weaponInvCategory = 1
SWEP.CustomShell = "762x54"

SWEP.AutomaticDraw = true
SWEP.UseCustomWorldModel = false
SWEP.Primary.ClipSize = 10
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "7.62x54 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.Primary.Damage = 65
SWEP.Primary.Force = 65
SWEP.Primary.Sound = {"weapons/tfa_ins2/sks/sks_fp.wav", 65, 90, 100}
SWEP.SupressedSound = {"homigrad/weapons/rifle/m4a1-1.wav", 65, 90, 100}
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor1", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(3,0,0), {}},
		["mount"] = Vector(-0.75,0.45,-0.1),
	},
	sight = {
		["mountType"] = {"picatinny", "dovetail"},
		["mount"] = {["dovetail"] = Vector(-28, 1.5, -0.4),["picatinny"] = Vector(-29.5, 2.35, -0.15)},
	},
	mount = {
		["picatinny"] = {
			"mount3",
			Vector(-26.5, -0.3, -1.25),
			{},
			["mountType"] = "picatinny",
		},
		["dovetail"] = {
			"empty",
			Vector(0, 0, 0),
			{},
			["mountType"] = "dovetail",
		},
	},
		underbarrel = {
		[1] = {"laser5", Vector(0.0,0.4,0.2), {}},

		["mount"] = Vector(6, -1.15, -1.3),
		["mountAngle"] = Angle(-0.1, -0.9, 90),
		["mountType"] = "picatinny_small"
	},
}

SWEP.addSprayMul = 1
SWEP.cameraShakeMul = 2
SWEP.RecoilMul = 0.2

SWEP.LocalMuzzlePos = Vector(29,0.45,3.58)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffect = "muzzleflash_svd" -- shared in sh_effects.lu

SWEP.ShockMultiplier = 2

SWEP.handsAng = Angle(0, 0, 0)
SWEP.handsAng2 = Angle(-3, 1, 0)

SWEP.Primary.Wait = 0.15
SWEP.NumBullet = 1
SWEP.AnimShootMul = 1
SWEP.AnimShootHandMul = 1
SWEP.ReloadTime = 5
SWEP.ReloadSoundes = {
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magout.wav",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magoutrattle.wav",
	"weapons/tfa_ins2/ak103/ak103_magin.wav",
	"weapons/tfa_ins2/ak103/ak103_boltback.wav",
	"weapons/tfa_ins2/ak103/ak103_boltrelease.wav",
	"none",
	"none",
	"none"
}
SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.4186, 5.1022)
SWEP.RHandPos = Vector(-8, -2, 6)
SWEP.LHandPos = Vector(6, -3, 1)
SWEP.AimHands = Vector(-10, 1.8, -6.1)
SWEP.SprayRand = {Angle(0.04, -0.05, 0), Angle(-0.05, 0.035, 0)}
SWEP.Ergonomics = 0.9
SWEP.Penetration = 15
SWEP.ZoomFOV = 1
SWEP.WorldPos = Vector(5.5, -1, -1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.handsAng = Angle(-2, -1, 0)
SWEP.scopemat = Material("decals/scope.png")
SWEP.perekrestie = Material("decals/perekrestie8.png", "smooth")
SWEP.localScopePos = Vector(-21, 3.95, -0.2)
SWEP.scope_blackout = 400
SWEP.maxzoom = 3.5
SWEP.rot = 37
SWEP.FOVMin = 3.5
SWEP.FOVMax = 10
SWEP.huyRotate = 25
SWEP.FOVScoped = 0

local vecZero = Vector(0, 0, 0)

SWEP.DistSound = "weapons/tfa_ins2/sks/sks_dist.wav"

SWEP.lengthSub = 15


--local to head
SWEP.RHPos = Vector(3,-6.5,4)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(17,1.3,-3.4)
SWEP.LHAng = Angle(-110,-180,-5)

SWEP.ShootAnimMul = 5

local lfang2 = Angle(-2, -35, -1)
local lfang21 = Angle(0, 35, 20)
local lfang1 = Angle(5, -15,-20)
local lfang0 = Angle(-0, -5, 0)
local vec_zero = Vector(0,0,0)
local ang_zero = Angle(0,0,0)
function SWEP:AnimHoldPost()
	--self:BoneSet("l_finger0", vec_zero, lfang0)

end

function SWEP:PrimaryShootPost()
	if CLIENT then
		if self:Clip1() < 3 then
			self:GetWM():ManipulateBoneScale(95, vecPochtiZero)
			if self:Clip1() < 2 then
			self:GetWM():ManipulateBoneScale(94, vecPochtiZero)
			if self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(93, vecPochtiZero)
			end
			end
		end
	end
end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() < 1 and not self.reload) and 2.3 or self.ReloadSlideOffset)
		wep:ManipulateBonePosition(4,Vector(0 , 2.4*self.shooanim,0 ),false)
	end
end

-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-1,7,-3),
	Vector(-7,15,-15),
	Vector(-7,15,-15),
	Vector(-1,7,-3),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	"fastreload",
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
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
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,2),
	Vector(8,1,2),
	Vector(8,2.5,-2),
	Vector(7,2.5,-2),
	Vector(6,2.5,-2),
	Vector(3,2.5,-2),
	Vector(3,2.5,-1),
	Vector(0,4,-1),
	"reloadend",
	Vector(0,5,0),
	Vector(-2,2,1),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-80,0,110),
	Angle(-20,0,110),
	Angle(-30,0,110),
	Angle(-20,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-20,0,45),
	Angle(-2,0,-3),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
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
	Angle(20,-10,-20),
	Angle(20,0,-20),
	Angle(20,0,-20),
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-15,15,-17),
	Angle(-14,14,-22),
	Angle(-10,15,-24),
	Angle(12,14,-23),
	Angle(11,15,-20),
	Angle(12,14,-19),
	Angle(11,14,-20),
	Angle(7,9,-21),
	Angle(0,14,-21),
	Angle(0,15,-22),
	Angle(0,24,-23),
	Angle(0,25,-22),
	Angle(-15,24,-25),
	Angle(-15,25,-23),
	Angle(5,0,2),
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