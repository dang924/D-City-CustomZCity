SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Suomi KP/-31"
SWEP.Author = "Tikkakoski"
SWEP.Instructions = "Submachine gun chambered in 9x19 mm\n\nRate of fire 850 rounds per minute"
SWEP.Category = "Weapons - Machine-Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/pwb2/weapons/w_p90.mdl"
SWEP.WorldModelFake = "models/khrcw2/doipack/suomi.mdl"
SWEP.FakePos = Vector(-20.5, 4, 10)
SWEP.FakeAng = Angle(1, 0, 0)
SWEP.AttachmentPos = Vector(5.5, 0.2, 0.45)
SWEP.AttachmentAng = Angle(0, 0, 0)
SWEP.FakeBodyGroups = "1111"
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"
SWEP.FakeScale = 1.05
//SWEP.MagIndex = 53
//MagazineSwap
--PrintBones(Entity(1):GetActiveWeapon():GetWM())

SWEP.FakeReloadSounds = {
	[0.3] = "weapons/ppsh/ppsh_magout.wav",
	[0.45] = "weapons/universal/uni_crawl_l_05.wav",
	[0.8] = "weapons/ppsh/ppsh_magin.wav",
	[0.92] = "weapons/ump45/ump45_magin.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/ppsh/ppsh_magout.wav",
	[0.35] = "weapons/universal/uni_crawl_l_05.wav",
	[0.52] = "weapons/ppsh/ppsh_magin.wav",
	[0.6] = "weapons/ump45/ump45_magin.wav",
	[0.83] = "weapons/ump45/ump45_boltback.wav",
	[0.88] = "weapons/mp5k/mp5k_boltrelease.wav",
}
SWEP.MagModel = "models/weapons/upgrades/w_magazine_m45_15.mdl"
local vector_full = Vector(1,1,1)

SWEP.GetDebug = false
SWEP.lmagpos = Vector(0, 0, 0)
SWEP.lmagang = Angle(0, 0, 0)
SWEP.lmagpos2 = Vector(0, -1.1, 3.5)
SWEP.lmagang2 = Angle(0, 0, -17)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 80
SWEP.FakeMagDropBone = 73
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
SWEP.FakeReloadEvents = {
	[0.15] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(52, vecPochtiZero)
			end 
		end,
		[0.4] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(52, vector_full)
			end 
		end,
}
end

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload_extmag",
	["reload_empty"] = "base_reloadempty_extmag",
}

SWEP.WepSelectIcon2 = Material("vgui/inventory/weapon_suomi")
SWEP.IconOverride = "vgui/inventory/weapon_suomi"

SWEP.weight = 2.5
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.CustomShell = "9x19"
--SWEP.EjectPos = Vector(-5,0,11)
--SWEP.EjectAng = Angle(-80,-90,0)
SWEP.Primary.ClipSize = 71
SWEP.Primary.DefaultClip = 71
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "9x19 mm Parabellum"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 25
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 15
SWEP.animposmul = 2
SWEP.Primary.Sound = {"mp5k/mp5k_tp.wav", 75, 120, 130}
SWEP.SupressedSound = {"mp5k/mp5k_suppressed_tp.wav", 55, 90, 100}
SWEP.Primary.Wait = 0.069
SWEP.ReloadTime = 6.5
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb/weapons/tmp/clipout.wav",
	"none",
	"none",
	"pwb/weapons/tmp/clipin.wav",
	"none",
	"none",
	"weapons/tfa_ins2/mp7/boltback.wav",
	"none",
	"weapons/tfa_ins2/mp7/boltrelease.wav",
	"none",
	"none",
	"none",
	"none"
}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.7779, 8.1181)
SWEP.RHandPos = Vector(-14, -1, 3)
SWEP.LHandPos = false
SWEP.Spray = {}
for i = 1, 71 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * 8) * 0.02, 0) * 1
end

SWEP.availableAttachments = {
}

SWEP.LocalMuzzlePos = Vector(8, 0.82, 6.88)
SWEP.LocalMuzzleAng = Angle(1.0, 0.0, 0)
SWEP.WeaponEyeAngles = Angle(-1.5, -0.5, 0)

SWEP.Ergonomics = 0.95
SWEP.DistSound = "m9/m9_dist.wav"
SWEP.OpenBolt = true
SWEP.Penetration = 7
SWEP.WorldPos = Vector(13.7, -0.5, 2.5)
SWEP.WorldAng = Angle(2, 0.7, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-5.5, -0.2, -0.5)
SWEP.attAng = Angle(-0.03, -0.3, 0)
SWEP.lengthSub = 10
SWEP.SetSupressor = false
SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(0, 9, -10)
SWEP.holsteredAng = Angle(210, -5, 180)
SWEP.handsAng = Angle(-10, 5, 0)

--local to head
SWEP.RHPos = Vector(5.8, -5.5, 3.5)
SWEP.RHAng = Angle(0, 5, 90)
--local to rh
SWEP.LHPos = Vector(7.5, -1, -3.5)
SWEP.LHAng = Angle(-40, 10, -90)


SWEP.ShootAnimMul = 2


function SWEP:AnimHoldPost(model)
	--self:BoneSet("l_finger0", Vector(0, 0, 0), Angle(-5, -10, 0))
	--self:BoneSet("l_finger02", Vector(0, 0, 0), Angle(0, 25, 0))
	--self:BoneSet("l_finger01", Vector(0, 0, 0), Angle(-25, 40, 0))
	--self:BoneSet("l_finger1", Vector(0, 0, 0), Angle(-10, -40, 0))
	--self:BoneSet("l_finger11", Vector(0, 0, 0), Angle(-10, -40, 0))
	--self:BoneSet("l_finger2", Vector(0, 0, 0), Angle(-5, -50, 0))
	--self:BoneSet("l_finger21", Vector(0, 0, 0), Angle(0, -10, 0))
end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0, self.ReloadSlideOffset)
		vec[1] = 0
		vec[2] = -1.5*self.shooanim
		vec[3] = 0
		wep:ManipulateBonePosition(5,vec,false)
	end
end

--RELOAD ANIMS SMG????

SWEP.ReloadAnimLH = {
	Vector(0,0,0)
}
SWEP.ReloadAnimLHAng = {
	Angle(0,0,0)
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
	5,
	5,
	5,
	0,
	0,
	0,
	0,
	0,
	0
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0),
	Vector(0,2,4),
	Vector(0,0,5),
	Vector(-5,-3,9),
	Vector(-15,-15,2),
	Vector(-15,-15,2),
	Vector(-2,1,8),
	Vector(0,0,4),
	Vector(0,0,4),
	Vector(0,0,4),
	"fastreload",
	Vector(-4,1,-3),
	Vector(-8,1,-3),
	Vector(-8,1,-3),
	Vector(-4,4,-1),
	"reloadend",
	"reloadend"
}
SWEP.ReloadAnimRHAng = {
	Angle(0,0,0)
}
SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-25,25,-44),
	Angle(-15,25,-45),
	Angle(-25,25,-45),
	Angle(-35,26,-44),
	Angle(-35,25,-45),
	Angle(-25,25,-44),
	Angle(-25,25,-44),
	Angle(-45,45,-55),
	Angle(-35,45,-55),
	Angle(-25,25,-44),
	Angle(0,0,0)
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