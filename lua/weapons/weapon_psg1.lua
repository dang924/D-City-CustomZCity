SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "PSG1"
SWEP.Author = "Heckler & Koch"
SWEP.Instructions = "Semi-Automatic Sniper Rifle chambered in 7.62×51 mm"
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_g3sg1.mdl"
SWEP.WorldModelFake = "models/weapons/arccw/c_ur_g3.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840
//SWEP.FakeScale = 0.9
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
//SWEP.ZoomPos = Vector(-2, 7, 0.02)
SWEP.FakePos = Vector(-16.5, 3.50, 12.27)
SWEP.FakeAng = Angle(0, -0.6, 0)
SWEP.AttachmentPos = Vector(-9,3.3,28)
SWEP.AttachmentAng = Angle(180,0,180)
SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_wallace_psg1")
SWEP.IconOverride = "vgui/hud/tfa_ins2_wallace_psg1"
SWEP.weight = 3.3
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 10
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "7.62x51 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 60
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 60
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/firearms/rifle_fnfal/fnfal_fire_01.wav", 85, 80, 90}
SWEP.SupressedSound = {"homigrad/weapons/rifle/m4a1-1.wav", 65, 90, 100}
SWEP.Primary.Wait = 0.11
SWEP.ReloadTime = 4.8
SWEP.FakeBodyGroups = "01321443031"
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip out 1.wav",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip in 2.wav",
	"none",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 bolt back.wav",
	"none",
	"pwb2/weapons/m4a1/ru-556 bolt forward.wav",
	"none",
	"none",
	"none",
	"none"
}

SWEP.PPSMuzzleEffect = "muzzleflash_SR25" -- shared in sh_effects.lua

SWEP.LocalMuzzlePos = Vector(24.004,1,9.4)
SWEP.LocalMuzzleAng = Angle(-0.0,-0.25,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(-0, 9, -14)
SWEP.holsteredAng = Angle(210, 0, 180)
SWEP.FakeReloadSounds = {
	[0.4] = "weapons/galil/handling/galil_rattle.wav",
	[0.33] = "weapons/galil/handling/galil_magrelease.wav",
	[0.35] = "weapons/galil/handling/galil_magout.wav",
	[0.75] = "weapons/galil/handling/galil_magin.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/galil/handling/galil_boltback.wav",
	[0.31] = "weapons/mp5k/mp5k_boltlock.wav",
	[0.47] = "weapons/galil/handling/galil_magrelease.wav",
	[0.50] = "weapons/galil/handling/galil_magout.wav",
	[0.65] = "weapons/galil/handling/galil_rattle.wav",
	[0.75] = "weapons/galil/handling/galil_magin.wav",
	[0.95] = "weapons/galil/handling/galil_boltrelease.wav",
}

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 1.0284, 11.3745)
SWEP.ZoomAng = Angle(0, 0, 0)
SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.EjectAng = Angle(180, 0, 0)
SWEP.Spray = {}
for i = 1, 10 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.01, math.cos(i * i) * 0.02, 0) * 0.8
end

SWEP.ShockMultiplier = 3

SWEP.ScrappersSlot = "Primary"

SWEP.CustomShell = "556x45"
--SWEP.EjectPos = Vector(0,5,5)
SWEP.EjectAng = Angle(-175,180,0)

SWEP.Ergonomics = 1.1
SWEP.Penetration = 15
SWEP.WorldPos = Vector(13, -1, 4)
SWEP.WorldAng = Angle(0, -0.0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-1, 3.5, -28)
SWEP.attAng = Angle(0, 180, 0)
SWEP.AimHands = Vector(0, 2, -3)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(3, -0.5, 0)
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor7", Vector(-0.5, -0.3, 0), {}},
	},
	sight = {
		["mount"] = {picatinny = Vector(-30.5, 1.5, 0.03), kar98mount = Vector(-31.0, 2.2, 0.1)},
		["mountType"] = {"picatinny","kar98mount"},
		["empty"] = {
			"empty",
		},
	},
}

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload_10rnd",
	["reload_empty"] = "reload_empty_10rnd",
}

--local to head
SWEP.RHPos = Vector(4,-7,4)
SWEP.RHAng = Angle(0,-8,90)
--local to rh
SWEP.LHPos = Vector(14,0.8,-3.7)
SWEP.LHAng = Angle(-110,-180,0)
function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,self:Clip1() > 0 and 0 or 0)
		wep:ManipulateBonePosition(42,Vector(0 ,0 ,-3*self.shooanim ),false)
		--wep:ManipulateBonePosition(7,Vector(-1*self.ReloadSlideOffset ,0.09*self.ReloadSlideOffset ,-(0.18/3)*self.ReloadSlideOffset ),false)
	end
end
SWEP.MagModel = "models/weapons/arccw/c_ur_g3.mdl"
local vector_full = Vector(1,1,1)
--models/weapons/arccw/uc_shells/22lr.mdl
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(3,5,-15)
SWEP.lmagang2 = Angle(0,0,-90)
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.51] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 1.0 * timeMul)//, self.MagModel, {self.lmagpos3, self.lmagang3, isnumber(self.FakeMagDropBone) and self.FakeMagDropBone or self:GetWM():LookupBone(self.FakeMagDropBone or "Magazine") or self:GetWM():LookupBone("ValveBiped.Bip01_L_Hand"), self.lmagpos2, self.lmagang2}, function(self)
			else
			end
		end,
		[0.53] = function( self, timeMul )
			if self:Clip1() < 1 then
				local ent = hg.CreateMag( self, Vector(40,15,-10),nil, true )
				for i = 0, ent:GetBoneCount() - 1 do
					ent:ManipulateBoneScale(i, vector_origin)
				end
				ent:ManipulateBoneScale(51, vector_full)
				ent:SetBodyGroups(self.FakeBodyGroups)
				self:GetWM():ManipulateBoneScale(51, vecPochtiZero)
			end 
		end,
		[0.66] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(51, vector_full)
			end 
		end,
	}
end
SWEP.StartAtt = {"optic12"}

function SWEP:AnimationPost()
end
function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
		self:GetWM():SetBodyGroups(self.FakeBodyGroups)
	end
end

SWEP.bipodAvailable = true
SWEP.bipodsub = 15
SWEP.RestPosition = Vector(13, 1, -0.5)
	
SWEP.FakeMagDropBone = 51

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
	Vector(-2,5,-1),
	Vector(-2,1,-1),
	"fastreload",
	Vector(-1,5,-1),
	Vector(-2,-2,-2),
	Vector(-2,-2,-2),
	Vector(-2,-2,-2),
	Vector(-2,-2,-15),
	Vector(-2,-2,-5),
	"reloadend",
	Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0)
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,110),
	Angle(0,0,110),
	Angle(0,0,110),
	Angle(0,0,110),
	Angle(0,0,110),
	Angle(0,0,110),
	Angle(0,0,110),
	Angle(0,0,110),
	Angle(0,0,110),
	Angle(0,0,110),
	Angle(0,0,95),
	Angle(0,0,60),
	Angle(0,0,30),
	Angle(0,0,2),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-15,15,-5),
	Angle(-15,15,-15),
	Angle(-10,15,-15),
	Angle(15,0,-15),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,-5),
	Angle(0,5,15),
	Angle(0,5,20),
	Angle(0,5,15),
	Angle(0,5,-15),
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