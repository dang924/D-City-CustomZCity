SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.PrintName = "O.S.I.P.B.S."
SWEP.Author = "Universal Union"
SWEP.Instructions = "O.S.I.P.B.S.(Overwatch Standard Issue Pulse Buckshot Shotgun) is a Dark Energy/pulse-powered shotgun"
SWEP.Category = "Weapons - Shotguns"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_heavyshotgun.mdl"
--models/weapons/zcity/v_saiga_12k.mdl
SWEP.WorldModelFake = "models/weapons/v_heavyshotgun.mdl"
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
--PrintAnims(Entity(1):GetActiveWeapon():GetWM())
--uncomment for funny
SWEP.FakePos = Vector(-17.5, 4.4, 11.0)
SWEP.FakeAng = Angle(0, 0.1, 0)
//SWEP.MagIndex = 42
SWEP.AttachmentPos = Vector(26,-2.5,2)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeEjectBrassATT = "eject"
SWEP.EjectPos = Vector(2,13,-1.3)
SWEP.EjectAng = Angle(15,-90,0)

//SWEP.MagIndex = 6
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():AddLayeredSequence(Entity(1):GetActiveWeapon():GetWM():LookupSequence("delta_foregrip"),1)
SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.27] = "pshotgun/wpn_shotgun_foley_open_chamber_01.wav",
	[0.45] = "pshotgun/wpn_shotgun_foley_close_tube_01.wav",
	[0.75] = "pshotgun/wpn_shotgun_foley_rack_back_01.wav",
	[0.8] = "pshotgun/wpn_shotgun_foley_rack_forward_01.wav",
	[0.87] = "pshotgun/wpn_shotgun_foley_close_chamber_01.wav",
	--[0.82] = "weapons/ar2/ar2_reload_rotate.wav",
	--[0.92] = "weapons/ar2/ar2_reload_push.wav"
}
--SWEP.GetDebug = true
SWEP.FakeEmptyReloadSounds = {
	[0.16] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_jamswitchoff.ogg",
	[0.17] = "pshotgun/wpn_shotgun_foley_open_chamber_01.wav",
	[0.45] = "pshotgun/wpn_shotgun_foley_close_tube_01.wav",
	[0.75] = "pshotgun/wpn_shotgun_foley_rack_back_01.wav",
	[0.8] = "pshotgun/wpn_shotgun_foley_rack_forward_01.wav",
	[0.87] = "pshotgun/wpn_shotgun_foley_close_chamber_01.wav",
	[0.88] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_jamswitchon.ogg"
	--[0.82] = "weapons/hmcd_ar2/ar2_reload_rotate.wav",
	--[0.92] = "weapons/hmcd_ar2/ar2_reload_push.wav"
}
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_saiga12_std.mdl"
	SWEP.FakeReloadEvents = {
	}


SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 10
SWEP.FakeMagDropBone = 42

SWEP.AnimList = {
	["idle"] = "idle01",
	["reload"] = "reload",
	["reload_empty"] = "reload",
}

--SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

SWEP.WepSelectIcon2 = Material("sprites/weapons/hevsg")
SWEP.IconOverride = "entities/tfa_heavyshotgun.png"

SWEP.addSprayMul = 2
SWEP.ScrappersSlot = "Primary"
SWEP.CustomShell = "12x70"
SWEP.weight = 5
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 6
SWEP.Primary.DefaultClip = 6
SWEP.Primary.Automatic = false
SWEP.OpenBolt = true
SWEP.Primary.Ammo = "Pulse Buckshot"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 64
SWEP.Primary.Spread = Vector(0.02, 0.02, 0.02)
SWEP.Primary.Force = 25
local math_random = math.random
SWEP.Primary.Sound = {"pshotgun/shotgun_fire"..math_random(1,4)..".wav", 85, 90, 100}
SWEP.Primary.Wait = 0.65	
SWEP.NumBullet = 8
SWEP.AnimShootMul = 3
SWEP.AnimShootHandMul = 10
SWEP.ReloadTime = 5.3
SWEP.ReloadSoundes = {
	"none",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magout.wav",
	"weapons/tfa_ins2/ak103/ak103_magoutrattle.wav",
	"weapons/tfa_ins2/ak103/ak103_magin.wav",
	"weapons/tfa_ins2/ak103/ak103_boltback.wav",
	"weapons/tfa_ins2/ak103/ak103_boltrelease.wav",
	"none",
	"none"
}

SWEP.PPSMuzzleEffect = "new_ar2_muzzle"

SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, -0.2011, 9.8616)
SWEP.RHandPos = Vector(-15, -2, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.ShellEject = "ShotgunShellEject"
SWEP.SprayRand = {Angle(-0.3, -0.5, 0), Angle(-0.5, 0.5, 0)}
SWEP.Ergonomics = 0.65
SWEP.Penetration = 14
SWEP.WorldPos = Vector(13, -1, 4)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-25, 2.5, -2)
SWEP.attAng = Angle(0.05, -0.6, 0)
SWEP.ShellEject = false
SWEP.lengthSub = 20
SWEP.DistSound = "toz_shotgun/toz_dist.wav"
SWEP.internalholo = Vector(10, 0, 0)
SWEP.holo = Material("effects/sun_textures/birthshock2")
SWEP.colorholo = Color(79, 255, 255)
SWEP.NoWINCHESTERFIRE = true
SWEP.internalholosize = 1
SWEP.holo_size = 1

SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(3, 8, -12)
SWEP.holsteredAng = Angle(210, 0, 180)

SWEP.LocalMuzzlePos = Vector(17.400,-2.6,4.8)
SWEP.LocalMuzzleAng = Angle(0,-1,0)
SWEP.WeaponEyeAngles = Angle(-0.147,-0.055,-0.187)

SWEP.punchmul = 4
SWEP.punchspeed = 0.5

SWEP.availableAttachments = {
}

--local to head
SWEP.RHPos = Vector(3,-5.5,3.5)
SWEP.RHAng = Angle(0,-10,90)
--local to rh
SWEP.LHPos = Vector(16,-1,-3.5)
SWEP.LHAng = Angle(-110,-90,-90)

-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(0,2,-5),
	Vector(0,2,-6),
	Vector(0,8,-5),
	Vector(-6,7,-6),
	Vector(-15,7,-15),
	Vector(-15,6,-15),
	Vector(-13,5,-5),
	Vector(-2,3,-5),
	Vector(0,3,-5),
	Vector(0,3,-5),
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
	"fastreload",
	Vector(0,0,1),
	Vector(8,1,2),
	Vector(9,2,-1),
	Vector(9,2,-2),
	Vector(8,2,-2),
	Vector(-1,3,1),
	Vector(-2,3,1),
	Vector(-5,3,1),
	"reloadend",
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-70,0,110),
	Angle(-50,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-60,0,95),
	Angle(0,0,60),
	Angle(0,0,30),
	Angle(0,0,10),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
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
	Angle(7,17,-9),
	Angle(0,24,-21),
	Angle(0,25,-22),
	Angle(0,24,-23),
	Angle(0,25,-22),
	Angle(-15,24,-25),
	Angle(-15,25,-23),
	Angle(5,0,2),
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
	Angle(-15,15,5),
	Angle(-15,15,14),
	Angle(-15,14,16),
	Angle(-16,16,15),
	Angle(-15,14,16),
	Angle(-10,25,-15),
	Angle(-2,22,-15),
	Angle(0,25,-22),
	Angle(0,24,-45),
	Angle(0,22,-45),
	Angle(0,20,-35),
	Angle(0,0,0)
}