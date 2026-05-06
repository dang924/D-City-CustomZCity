SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "O.S.I.P.S."
SWEP.Author = "Universal Union"
SWEP.Instructions = "O.S.I.P.S.(Overwatch Standard Issue Pulse Sub-Machinegun) is a Dark Energy/pulse-powered sub machine gun.\n\nRate of fire 750 rounds per minute"
SWEP.Category = "Weapons - Machine-Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/psmg/w_psmg.mdl"
SWEP.WorldModelFake = "models/weapons/v_pulsesmg.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 
--uncomment for funny
--а еще надо настраивать заново zoompos
SWEP.FakePos = Vector(27, -7.2, 7.4)
SWEP.FakeAng = Angle(0, 174, 0)
SWEP.AttachmentPos = Vector(0,0,0)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeEjectBrassATT = "plug1"
//SWEP.MagIndex = 53
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")
--PrintTable(Entity(1):GetActiveWeapon():GetWM():GetAttachments())
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakeReloadSounds = {
	[0.17] = "psmg/eblaster_screw_in_01.wav",
	[0.18] = "weapons/hmcd_ar2/ar2_magout.wav",
	[0.75] = "weapons/hmcd_ar2/ar2_magin.wav",
	[0.85] = "psmg/eblaster_screw_in_04.wav"
	--[0.82] = "weapons/ar2/ar2_reload_rotate.wav",
	--[0.92] = "weapons/ar2/ar2_reload_push.wav"
}
--SWEP.GetDebug = true
SWEP.FakeEmptyReloadSounds = {
	[0.19] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_jamswitchoff.ogg",
	[0.17] = "psmg/eblaster_screw_in_01.wav",
	[0.18] = "weapons/hmcd_ar2/ar2_magout.wav",
	[0.75] = "weapons/hmcd_ar2/ar2_magin.wav",
	[0.85] = "psmg/eblaster_screw_in_04.wav",
	[0.88] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_jamswitchon.ogg"
	--[0.82] = "weapons/hmcd_ar2/ar2_reload_rotate.wav",
	--[0.92] = "weapons/hmcd_ar2/ar2_reload_push.wav"
}
SWEP.MagModel = "models/Items/combine_rifle_cartridge01.mdl"
SWEP.FakeMagDropBone = 40
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)

SWEP.FakeViewBobBone = "hand1"
SWEP.FakeViewBobBaseBone = "pulserifle"
SWEP.ViewPunchDiv = 30
SWEP.internalholo = Vector(10, 0, 0)
SWEP.holo = Material("effects/sun_textures/birthshock")
SWEP.colorholo = Color(79, 255, 255)
SWEP.internalholosize = 0.8
SWEP.holo_size = 0.5

if CLIENT then
SWEP.FakeReloadEvents = {
		[0.37] = function( self )
				if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(70,0,-20) )
				self:GetWM():ManipulateBoneScale(40, vecPochtiZero )
			end
		end,
		[0.63] = function( self )
				if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(40, vector_full)
			end
		end,
		[0.36] = function( self )
				if self:Clip1() >= 1 then
				hg.CreateMag( self, Vector(70,0,-20) )
				self:GetWM():ManipulateBoneScale(40, vecPochtiZero)
			end
		end,
		[0.62] = function( self )
				if self:Clip1() >= 1 then
				self:GetWM():ManipulateBoneScale(40, vector_full)
			end
		end,
	}		
end


SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload",
}

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(5,1,-1)
SWEP.lmagang2 = Angle(0,-90,0)

SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 40
SWEP.Primary.DefaultClip = 40
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "Pulse"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 18
SWEP.Primary.Spread = 0.01 
SWEP.Primary.Force = 40
local math_random = math.random
SWEP.Primary.Sound = {"psmg/smg1_fire"..math_random(1,16)..".wav", 85, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/mk18/handling/mk18_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.ShootEffect = 5
SWEP.ShellEject = true
SWEP.MuzzleEffectType = 0
SWEP.CustomShell = "Pulse"
SWEP.EjectPos = Vector(6,23,-3)
SWEP.EjectAng = Angle(15,-90,0)
SWEP.ScrappersSlot = "Primary"
SWEP.weight = 3.5
SWEP.NoWINCHESTERFIRE = true
SWEP.punchmul = 0.5
SWEP.punchspeed = 1
SWEP.holsteredPos = Vector(8, 10, -5)
SWEP.holsteredAng = Angle(210, 0, 160)
SWEP.podkid = 0.25

SWEP.PPSMuzzleEffect = "new_ar2_muzzle" -- shared in sh_effects.lu

SWEP.WepSelectIcon2 = Material("sprites/weapons/psmg")
SWEP.IconOverride = "entities/tfa_osips.png"

SWEP.availableAttachments = {
}

SWEP.Primary.Wait = 0.091
SWEP.ReloadTime = 3.5
SWEP.CanEpicRun = true
SWEP.EpicRunPos = Vector(2, 10, 2)
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

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 1.35, 7.2786)
SWEP.Spray = {}
for i = 1, 40 do
	SWEP.Spray[i] = Angle(-0.06 - math.cos(i) * 0.03, math.cos(i * i) * 0.04, 0) * 2
end

SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}

SWEP.Ergonomics = 1.0
SWEP.HaveModel = "models/weapons/arccw/w_irifle.mdl"
SWEP.Penetration = 17
SWEP.WorldPos = Vector(15, -0.5, -1.5)
SWEP.WorldAng = Angle(0, 180, 0)
SWEP.UseCustomWorldModel = true
--https://youtu.be/I7TUHPn_W8c?list=RDEMAfyWQ8p5xUzfAWa3B6zoJg  wizards
SWEP.attPos = Vector(0, 0.7, 0)
SWEP.attAng = Angle(0.2, 0.7, 90)
SWEP.lengthSub = 20
SWEP.DistSound = "psmg/wpn_combine_smg_body_03.wav"

SWEP.LocalMuzzlePos = Vector(-2.7,-0.2,4.9)
SWEP.LocalMuzzleAng = Angle(0.0,180)
SWEP.WeaponEyeAngles = Angle(0,180,0)

SWEP.rotatehuy = 180

--local to head
SWEP.RHPos = Vector(4,-8.5,5)
SWEP.RHAng = Angle(0,0,90)
--local to rh
SWEP.LHPos = Vector(10.5,-3,-9)
SWEP.LHAng = Angle(0-10,0,-90)

local finger1 = Angle(45,-25,50)

function SWEP:AnimHoldPost(model)
	--self:BoneSet("l_finger0", vector_zero, finger1)
end


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