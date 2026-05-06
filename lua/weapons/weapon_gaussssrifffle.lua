SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.PrintName = "Item 62"
SWEP.Author = "Unknown..."
SWEP.Instructions = "Gauss Rifle, or item 62 as it's called officially, the first designs for the rifle came from a covert weapons research program in the Chernobyl Zone of Exclusion, before the Zone even came into being. The project that eventually birthed the Gauss rifle focused on creating weapons based on the principle of projectile acceleration via an electromagnetic field.\n\nVery powerful."
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_awp.mdl"
--models/weapons/v_sr25_eft.mdl
SWEP.WorldModelFake = "models/weapons/arc9/stalker2/sr_gauss/v_sr_gauss.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840 
--uncomment for funny
--а еще надо настраивать заново zoompos
SWEP.FakePos = Vector(-10.5, 2.85, 6.3)
SWEP.FakeAng = Angle(0, -1.7, 0)
SWEP.FakeAttachment = "10"
SWEP.FakeScale = 0.95
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.AttachmentPos = Vector(6.5,-2.5,-0.05)
SWEP.AttachmentAng = Angle(0,0,90)
SWEP.AnimsEvents = {
	["fire_ads"] = {
		[0.0] = function(self)
			self:EmitSound("weapons/arc9/stalker2/sr_gauss/fire_windup_1.ogg",75)
		end
	},
}
//SWEP.MagIndex = 53
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():SetSubMaterial(0,"NULL")

SWEP.FakeReloadSounds = {
	[0.30] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_magout_button.ogg",
	[0.36] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_magout.ogg",
	[0.65] = "universal/uni_ads_in_06.wav",
	[0.80] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_magin_intro.ogg",
}

SWEP.FakeEmptyReloadSounds = {	
	[0.20] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_jamswitchoff.ogg",
	[0.30] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_magout_button.ogg",
	[0.36] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_magout.ogg",
	[0.55] = "universal/uni_ads_in_06.wav",
	[0.70] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_magin_intro.ogg",
	[0.90] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_cock.ogg",
	[0.96] = "weapons/arc9/stalker2/sr_gauss/sfx_gauss_jamswitchon.ogg",
}
SWEP.GetDebug = false

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0.3,0)
SWEP.lmagang2 = Angle(0,0,0)

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)


SWEP.AnimList = {
	["idle"] = "basepose",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}

SWEP.ScrappersSlot = "Primary"
SWEP.WepSelectIcon2 = Material("vgui/hud/vgui_gauss")
SWEP.IconOverride = "vgui/hud/vgui_gauss"
SWEP.weight = 4.5
SWEP.weaponInvCategory = 1
--SWEP.EjectPos = Vector(-2,0,4)
--SWEP.EjectAng = Angle(0,0,0)
SWEP.AutomaticDraw = true
SWEP.UseCustomWorldModel = false
SWEP.Primary.ClipSize = 10
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Gauss"
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.OpenBolt = true
SWEP.Primary.Damage = 300
SWEP.Primary.Force = 50
SWEP.Primary.Sound = {"weapons/arc9/stalker2/sr_gauss/indoors_3.ogg", 85, 90, 100}
SWEP.Primary.SoundEmpty = {"weapons/arc9/stalker2/sr_gauss/sfx_gauss_teethreload_6.ogg", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.DistSound = "weapons/arc9/stalker2/sr_gauss/outdoors_4.ogg"
SWEP.availableAttachments = {
		sight = {
		["mountType"] = {"picatinny"},
		["mount"] = {picatinny = Vector(-26.7, 1.15, -0.7)}
	},
}

SWEP.LocalMuzzlePos = Vector(28.5,0.15,2.2)
SWEP.LocalMuzzleAng = Angle(-0.2,-0.02,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffect = "gauss_muzzle"

SWEP.ShockMultiplier = 2

SWEP.handsAng = Angle(0, 0, 0)
SWEP.handsAng2 = Angle(-1, -0.5, 0)

SWEP.Primary.Wait = 3
SWEP.NumBullet = 1
SWEP.AnimShootMul = .5
SWEP.AnimShootHandMul = 10.5
SWEP.ReloadTime = 5.2
SWEP.ReloadSoundes = {
	"none",
	"none",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip out 1.wav",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip in 2.wav",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 bolt back.wav",
	"pwb2/weapons/m4a1/ru-556 bolt forward.wav",
	"none",
	"none",
	"none",
	"none"
}
SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.1714, 4.911)
SWEP.RHandPos = Vector(-8, -2, 6)
SWEP.LHandPos = Vector(9, -3, 1)
SWEP.AimHands = Vector(-10, 1.8, -6.1)
SWEP.SprayRand = {Angle(-0.03, -0.04, 0), Angle(-0.05, 0.04, 0)}
SWEP.Ergonomics = 0.75
SWEP.Penetration = 35
SWEP.ZoomFOV = 20
SWEP.WorldPos = Vector(5, -1.2, -1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.handsAng = Angle(4, -2, 0)
SWEP.scopemat = Material("decals/scope.png")
SWEP.perekrestie = Material("decals/perekrestie8.png", "smooth")
SWEP.localScopePos = Vector(-21, 3.95, -0.2)
SWEP.scope_blackout = 400
SWEP.maxzoom = 3.5
SWEP.rot = 37
SWEP.FOVMin = 3.5
SWEP.FOVMax = 10
SWEP.huyRotate = 25
SWEP.FOVScoped = 40

SWEP.addSprayMul = 1
SWEP.cameraShakeMul = 2

SWEP.ShootAnimMul = 5

function SWEP:AnimHoldPost()
	--self:BoneSet("l_finger0", Vector(0, 0, 0), Angle(0, -20, 40))
	--self:BoneSet("l_finger02", Vector(0, 0, 0), Angle(0, 25, 0))
	--self:BoneSet("l_finger1", Vector(0, 0, 0), Angle(0, -5, 0))
	--self:BoneSet("l_finger2", Vector(0, 0, 0), Angle(0, -5, 0))
end

function SWEP:PostFireBullet(bullet)
	if CLIENT then
		self:PlayAnim("fire_ads",3,nil,false)
	end
end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,self:Clip1() > 0 and 0 or 0)
		wep:ManipulateBonePosition(54,Vector(0 ,1.8*self.shooanim ,0 ),false)
		--wep:ManipulateBonePosition(7,Vector(-1*self.ReloadSlideOffset ,0.09*self.ReloadSlideOffset ,-(0.18/3)*self.ReloadSlideOffset ),false)
	end
end



SWEP.lengthSub = 15
--SWEP.Supressor = false
--SWEP.SetSupressor = true

--local to head
SWEP.RHPos = Vector(2,-6.5,3.5)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(16,1.9,-3.2)
SWEP.LHAng = Angle(-110,-180,0)

-- RELOAD ANIM SR25/AR15

SWEP.ReloadAnimRH = {
	Vector(0,0,0),
	Vector(-2,2,-10),
	Vector(-2,2,-11),
	Vector(-2,3,-11),
	Vector(-2,7,-13),
	Vector(-8,15,-25),
	Vector(-15,5,-25),
	Vector(-5,5,-25),
	Vector(-2,4,-11),
	Vector(-2,2,-11),
	Vector(-2,2,-11),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(-60,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(0,0,95),
	Angle(0,0,60),
	Angle(0,0,30),
	Angle(0,0,2),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
	Angle(-60,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(0,0,95),
	Angle(0,0,60),
	Angle(0,0,30),
	Angle(0,0,2),
	Angle(0,0,0),
}



SWEP.ReloadSlideAnim = {
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	4,
	4,
	4,
	0,
	0,
	0,
	0
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