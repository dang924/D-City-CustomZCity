SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "M320"
SWEP.Author = "Heckler & Koch"
SWEP.Instructions = "One-Shot Grenade  Launcher Chambered for 40mm Grenades"
SWEP.Category = "Weapons - Grenade Launchers"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/w_m1014.mdl"

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_l4d2_m320")
SWEP.IconOverride = "vgui/hud/tfa_l4d2_m320"

SWEP.ShellEject = false
SWEP.CustomShell = "12x70"
SWEP.weight = 2.5
SWEP.weaponInvCategory = 2
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Spread = Vector(0,0,0)
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Grenade 40mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 65
SWEP.Primary.Force = 125
SWEP.UsePhysBullets = true
SWEP.Primary.Sound = {"weapons/m203/m203_tp.wav", 75, 80, 90}
SWEP.SupressedSound = {"weapons/m203/m203_tp.wav", 75, 80, 90}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/fnfal/handling/fnfal_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0
SWEP.FakeAttachment = "1"
SWEP.OpenBolt = true
SWEP.WorldModelFake = "models/viewmodels/c_l4d2_m320.mdl" -- МОДЕЛЬ ГОВНА, НАЙТИ НОРМАЛЬНЫЙ КАЛАШ
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
--uncomment for funny
SWEP.FakePos = Vector(-10.5, 5.1, 3)
SWEP.FakeAng = Angle(1.5, 0, 7)
SWEP.AttachmentPos = Vector(0,-0.0,0)
SWEP.AttachmentAng = Angle(0,0,0)

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.CanEpicRun = true
SWEP.EpicRunPos = Vector(2,10,2)
SWEP.availableAttachments = {
}

SWEP.FakeEjectBrassATT = "2"
//SWEP.MagIndex = 57
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():AddLayeredSequence(Entity(1):GetActiveWeapon():GetWM():LookupSequence("delta_foregrip"),1)
local path = ")weapons/arccw_ur/dbs/"
local common = ")/arccw_uc/common/"
SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.27] = path.."open.ogg",
	[0.4] = path.."eject.ogg",
	[0.60] = path.."struggle.ogg",
	[0.7] = common.."dbs-shell-insert-01.ogg",
	[0.95] =  path.."close.ogg",
}

SWEP.FakeEmptyReloadSounds = {
	[0.35] = "weapons/m203/handling/m203_openbarrel.wav",
	[0.3] = "weapons/m203/handling/m203_deselect.wav",
	[0.50] = path.."struggle.ogg",
	[0.55] = "weapons/m203/handling/m203_insertgrenade_01.wav",
	[0.9] = "weapons/m203/handling/m203_closebarrel.wav",
}

--[[

	["reload"] = {
        Source = "reload",
        TPAnim = ACT_HL2MP_GESTURE_RELOAD_AR2,
        ShellEjectAt = 0.91,
        SoundTable = {
            {s = common .. "cloth_4.ogg", t = 0},
            {s = path .. "open.ogg", t = 0.2},
            {s = path .. "eject.ogg", t = 0.8},
            {s = common .. "magpouch_pull_small.ogg", t = 1.0},
            {s = shellfall, t = 1.0},
            {s = common .. "cloth_2.ogg", t = 1.1},
            {s = path .. "struggle.ogg", t = 1.5, v = 0.5},
            {s = shellin, t = 1.8},
            {s = path .. "grab.ogg", t = 2.15, v = 0.5},
            {s = path .. "close.ogg", t = 2.3},
            {s = common .. "shoulder.ogg", t = 2.4},
            {s = path .. "shoulder.ogg", t = 2.675},
        },
        LHIK = true,
        LHIKIn = 0.5,
        LHIKOut = 0.5,
        MinProgress = 2.05,
    },
    ["reload_empty"] = {
        Source = "reload_empty",
        TPAnim = ACT_HL2MP_GESTURE_RELOAD_AR2,
        ShellEjectAt = 1.0,
        SoundTable = {
            {s = common .. "cloth_4.ogg", t = 0},
            {s = path .. "open.ogg", t = 0.3},
            {s = path .. "eject.ogg", t = 0.8},
            {s = shellfall, t = 0.9},
            {s = shellfall, t = 0.95},
            {s = common .. "cloth_2.ogg", t = 1.1},
            {s = common .. "magpouch_pull_small.ogg", t = 1.2},
            {s = path .. "struggle.ogg", t = 1.7, v = 0.5},
            {s = shellin, t = 1.85},
            {s = shellin, t = 1.9},
            {s = path .. "grab.ogg", t = 2.17, v = 0.5},
            {s = path .. "close.ogg", t = 2.3},
            {s = common .. "shoulder.ogg", t = 2.44},
            {s = path .. "shoulder.ogg", t = 2.6},
        },
        LHIK = true,
        LHIKIn = 0.5,
        LHIKOut = 0.5,
        MinProgress = 2.05,
    },
--]]

SWEP.MagModel = "models/weapons/upgrades/w_magazine_m1a1_30.mdl"

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70

SWEP.AnimList = {
	["idle"] = "idle_raw",
	["reload"] = "reload",
	["reload_empty"] = "reload",
}
local vector_full = Vector(1,1,1)
SWEP.FakeReloadEvents = {
		[0.15] = function( self ) 
		if CLIENT and self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(112, vector_origin)
		end 
	end,
	[0.43] = function( self ) 
		if CLIENT and self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(112, vector_full)
		end 
	end,
}

function SWEP:PrimaryShootPost()
	if CLIENT then
		if self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(112, vector_origin)
		end
		end
end
--SWEP.IsPistol = true

SWEP.cameraShakeMul = 0.25

SWEP.LocalMuzzlePos = Vector(12.0,0.2,-0.3)
SWEP.LocalMuzzleAng = Angle(-7.2,-1.1,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)


SWEP.punchmul = 1
SWEP.punchspeed = 0.1

SWEP.ReloadSound = "weapons/tfa_ins2/doublebarrel/shellinsert1.wav"
SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 2.3468, 1.3744)
SWEP.RHandPos = Vector(-15, -2, 4)
SWEP.LHandPos = false
SWEP.Ergonomics = 1.15
SWEP.Penetration = 0
SWEP.WorldPos = Vector(4, -1, -2)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0.3, 0.0, 0)
SWEP.attAng = Angle(0, 0, 0)
SWEP.lengthSub = 20
SWEP.NoIdleLoop = true
SWEP.bigNoDrop = true
SWEP.holsteredBone = "ValveBiped.Bip01_Pelvis"
SWEP.holsteredPos = Vector(-7.5, 6.5, 4.3)
SWEP.holsteredAng = Angle(-180, 165, 90)

SWEP.IsPistol = false
SWEP.ReloadTime = 3.5

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 30
SWEP.Supressor = true
SWEP.SetSupressor = true



--local to head
SWEP.RHPos = Vector(3,-4,3.5)
SWEP.RHAng = Angle(0,0,90)
--local to rh
SWEP.LHPos = Vector(15,-1,-3.3)
SWEP.LHAng = Angle(-110,-90,-90)

local ang1 = Angle(30, -20, 0)
local ang2 = Angle(-10, 50, 0)

function SWEP:AnimationPost()
	self:BoneSet("l_finger0", vector_origin, ang1)
	self:BoneSet("l_finger02", vector_origin, ang2)
end

-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-2,-5,-5),
	Vector(-2,-5,-5),
	Vector(-2,-5,-12),
	Vector(-2,-4,-8),
	Vector(-2,1,-7),
	Vector(-2,1,-7),
	Vector(-2,1,-5),
	Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0)
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,180),
	Angle(0,0,180),
	Angle(0,0,180),
	Angle(0,0,180),
	Angle(0,0,180),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(2,5,0),
	Angle(2,5,0),
	Angle(5,10,0),
	Angle(5,10,0),
	--Angle(0,0,0)
}

function SWEP:GetAnimPos_Insert(time)
	return 0
end

function SWEP:GetAnimPos_Draw(time)
	return 0
end

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
	Angle(-5,15,5),
	Angle(-5,15,15),
	Angle(-5,14,16),
	Angle(-7,16,18),
	Angle(-7,14,20),
	Angle(-6,15,-15),
	Angle(-2,12,-15),
	Angle(0,15,-22),
	Angle(0,14,-45),
	Angle(0,12,-45),
	Angle(0,10,-35),
	Angle(0,0,0)
}