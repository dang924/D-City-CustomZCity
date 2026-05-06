SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "SCAR-L"
SWEP.Author = "FN Herstal"
SWEP.Instructions = "Automatic rifle chambered in 5.56×45 mm\n\nRate of fire 650 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.WorldModelFake = "models/weapons/arccw/c_uc_myt_scar.mdl" -- Контент инсурги https://steamcommunity.com/sharedfiles/filedetails/?id=3437590840
//SWEP.FakeScale = 0.9
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
//SWEP.ZoomPos = Vector(-2, 7, 0.02)
SWEP.FakePos = Vector(-16, 4.50, 12.27)
SWEP.FakeAng = Angle(0, -0.6, 0)
SWEP.AttachmentPos = Vector(-9,3.3,28)
SWEP.AttachmentAng = Angle(180,0,180)
SWEP.WepSelectIcon2 = Material("vgui/inventory/weapon_scarl")
SWEP.IconOverride = "vgui/inventory/weapon_scarl"
SWEP.weight = 2.8
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.56x45 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 45
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 45
SWEP.Primary.Sound = {"sounds_zcity/ar15/close.wav", 75, 90, 100, 1}
SWEP.Primary.Wait = 0.090
SWEP.ReloadTime = 4.9
SWEP.FakeBodyGroups = "0010161400"
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

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle2"

SWEP.LocalMuzzlePos = Vector(11.004,0.55,7.9)
SWEP.LocalMuzzleAng = Angle(-0.0,-0.5,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(-0, 9, -14)
SWEP.holsteredAng = Angle(210, 0, 180)
SWEP.FakeReloadSounds = {
	[0.31] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.35] = "weapons/m4a1/m4a1_magout.wav",
	[0.8] = "weapons/m4a1/m4a1_magain.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.26] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.30] = "weapons/m4a1/m4a1_magout.wav",
	[0.37] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.75] = "weapons/m4a1/m4a1_magain.wav",
	[0.93] = "weapons/arccw_ud/m16/boltdrop.ogg",
}

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.6295, 10.5571)
SWEP.ZoomAng = Angle(0, 0, 0)
SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.EjectAng = Angle(180, 0, 0)
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.02 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 0.5
end

SWEP.ShockMultiplier = 3

SWEP.ScrappersSlot = "Primary"

SWEP.CustomShell = "556x45"
--SWEP.EjectPos = Vector(0,5,5)
SWEP.EjectAng = Angle(-175,180,0)

SWEP.Ergonomics = 1.2
SWEP.Penetration = 15
SWEP.WorldPos = Vector(13, -1, 4)
SWEP.WorldAng = Angle(0, -0.0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-7, 3.5, -28)
SWEP.attAng = Angle(0, 180, 0)
SWEP.AimHands = Vector(0, 2, -3)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(3, -0.5, 0)
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor2", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(1.7,0.6,-0.1), {}},
		["mount"] = Vector(-4.0,0.1,0.15),
	},
	sight = {
		["mount"] = {picatinny = Vector(-21.4, 1.8, 0.05), ironsight = Vector(-20, 1.8, 0.05)},
		["mountType"] = {"picatinny", "ironsight"},
		["empty"] = {
			"empty",
		},
	},
	grip = {
		["mount"] = Vector(5, 0.0, 0.0),
		["mountType"] = "picatinny"
	},
	underbarrel = {
		[1] = {"laser5", Vector(0.0,0.2,0.1), {}},

		["mount"] = {["picatinny_small"] =Vector(5, -0.4, 0.1),["picatinny"] = Vector(5.9,0.8,0)},
		["mountAngle"] = {["picatinny_small"] = Angle(0.8, 0, 0),["picatinny"] = Angle(-0.20, 0.4, 0)},
		["mountType"] = {"picatinny_small","picatinny"},
		["removehuy"] = {
			["picatinny"] = {
			},
			["picatinny_small"] = {
			}
		}
	},
}

SWEP.StartAtt = {"ironsight1"}

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload_556",
	["reload_empty"] = "reload_empty_556",
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
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 3)
		wep:ManipulateBonePosition(42,Vector(0 ,0 ,-1.8*self.shooanim ),false)
	end
end
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_stanag_fn_mk16_std_556x45_30.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,5,1	)
SWEP.lmagang2 = Angle(0,0,-90)
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.15] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 2 * timeMul)//, self.MagModel, {self.lmagpos3, self.lmagang3, isnumber(self.FakeMagDropBone) and self.FakeMagDropBone or self:GetWM():LookupBone(self.FakeMagDropBone or "Magazine") or self:GetWM():LookupBone("ValveBiped.Bip01_L_Hand"), self.lmagpos2, self.lmagang2}, function(self)
			else
			end
		end,
		[0.28] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(10,10,0), nil, true )
				self:GetWM():ManipulateBoneScale(43, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(44, vecPochtiZero)
			end 
		end,
		[0.45] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(43, vector_full)
				self:GetWM():ManipulateBoneScale(44, vector_full)
			end 
		end,
	}
end

function SWEP:AnimationPost()
end
function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
		self:GetWM():SetBodyGroups(self.FakeBodyGroups)
	end
end
	
SWEP.FakeMagDropBone = 43

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