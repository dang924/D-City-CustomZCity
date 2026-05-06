SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Gewehr 43"
SWEP.Author = "Nazi Germany"
SWEP.Instructions = "The Gewehr 43 or Karabiner 43 is a 7.92×57mm Mauser caliber semi-automatic rifle developed by Germany during World War II."
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_g3sg1.mdl"
SWEP.WorldModelFake = "models/weapons/arc9_doi/c_g43.mdl"
SWEP.FakeScale = 0.95
SWEP.FakePos = Vector(-10.5, 3.9, 6.8)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0.5,0.1,0.3)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeEjectBrassATT = "2"

SWEP.FakeReloadSounds = {
	[0.3] = "weapons/m14/m14_magout.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.73] = "weapons/m14/m14_magin.wav",
	--[0.91] = "weapons/tfa_nam_svd/svd_boltback.wav",
	--[0.92] = "weapons/tfa_nam_svd/svd_boltrelease.wav",
}

SWEP.FakeEmptyReloadSounds = {
	--[0.22] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.3] = "weapons/m14/m14_magout.wav",
	--[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.57] = "weapons/m14/m14_magin.wav",
	[0.75] = "weapons/tfa_nam_svd/svd_boltback.wav",
	[0.79] = "weapons/m14/m14_boltback.wav",
	[0.83] = "weapons/tfa_nam_svd/svd_boltrelease.wav",
}
SWEP.MagModel = "models/kali/weapons/10rd m14 magazine.mdl"

SWEP.FakeMagDropBone = "50"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(5.5,-2.5,1.8)
SWEP.lmagang2 = Angle(20,90,50)
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 40

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
	}
end

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reloadfull",
	["reload_empty"] = "base_reloadempty",
}

SWEP.ScrappersSlot = "Primary"
SWEP.WepSelectIcon2 = Material("vgui/tfa_doi_icons/weapon_g43")
SWEP.IconOverride = "vgui/tfa_doi_icons/weapon_g43"
SWEP.weight = 3.7
SWEP.weaponInvCategory = 1
SWEP.CustomShell = "762x54"

SWEP.AutomaticDraw = true
SWEP.UseCustomWorldModel = false
SWEP.Primary.ClipSize = 10
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "7.92x57mm Mauser"
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.Primary.Damage = 80
SWEP.Primary.Force = 80
SWEP.attAng = Angle(0, 0, 90)
SWEP.Primary.Sound = {"weapons/tfa_ins2/sks/sks_fp.wav", 65, 90, 100}
SWEP.SupressedSound = {"homigrad/weapons/rifle/m4a1-1.wav", 65, 90, 100}
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor8", Vector(0,0,0), {}},
		["mount"] = Vector(0.67,-0.25,-0.3),
	},
	sight = {
		["mountType"] = {"kar98mount"},
		["mount"] = {["kar98mount"] = Vector(-21, 2.2, -0.1)},
	},
}

SWEP.addSprayMul = 1
SWEP.cameraShakeMul = 2
SWEP.RecoilMul = 0.2

SWEP.LocalMuzzlePos = Vector(30,0.91,4.28)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.ShockMultiplier = 2

SWEP.handsAng = Angle(0, 0, 0)
SWEP.handsAng2 = Angle(-3, 1, 0)

SWEP.Primary.Wait = 0.17
SWEP.NumBullet = 1
SWEP.AnimShootMul = 1
SWEP.AnimShootHandMul = 1
SWEP.ReloadTime = 6.5
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
SWEP.ZoomPos = Vector(0, 0.8766, 5.6164)
SWEP.RHandPos = Vector(-8, -2, 6)
SWEP.LHandPos = Vector(6, -3, 1)
SWEP.AimHands = Vector(-10, 1.8, -6.1)
SWEP.SprayRand = {Angle(0.04, -0.05, 0), Angle(-0.05, 0.035, 0)}
SWEP.Ergonomics = 0.93
SWEP.Penetration = 20
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

function SWEP:PostFireBullet(bullet)
	if CLIENT then
		self:PlayAnim("iron_fire_1",1.0,nil,false)
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