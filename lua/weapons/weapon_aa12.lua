SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "AA-12"
SWEP.Author = "Maxwell Atchisson"
SWEP.Instructions = "The AA-12 (Auto Assault - 12), originally designed and known as the Atchisson Assault Shotgun, is a fully automatic combat shotgun chambered in 12/70. Developed in 1972 by Maxwell Atchisson."
SWEP.Category = "Weapons - Shotguns"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_shot_m3super90.mdl"
--models/weapons/zcity/v_saiga_12k.mdl
SWEP.WorldModelFake = "models/weapons/arc9/darsu_eft/c_aa12.mdl"
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
--PrintAnims(Entity(1):GetActiveWeapon():GetWM())
--uncomment for funny
SWEP.FakePos = Vector(-19, 4.5, 10)
SWEP.FakeAng = Angle(0, 0.0, 0)
SWEP.FakeBodyGroups = "10110101"
SWEP.AttachmentPos = Vector(26,-2.5,2)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeEjectBrassATT = "2"
SWEP.FakeAttachment = "1"

function SWEP:PostFireBullet(bullet)
	if CLIENT then
		self:PlayAnim("fire",0.3,nil,false)
	end
end
function SWEP:OnCantReload()
	--inspect1
	--print("huy")
	if self.Inspecting and self.Inspecting > CurTime() then return end
	self.Inspecting = CurTime() + 4.2
	if self:Clip1() >= 1 then
	self:PlayAnim("check_0",4.2,false,function(self)
	self:PlayAnim("idle",1)
		--self.Inspecting = false
end,false,true)
else
	self:PlayAnim("check_0_empty_empty",2.5,false,function(self)
	self:PlayAnim("idle_empty",1)
		--self.Inspecting = false
end,false,true)
end

end

SWEP.AnimsEvents = {
	["check_0"] = {
		[0.15] = function(self)
			self:EmitSound("weapons/arccw_ur/ak/12ga/magout.ogg",55)
		end,
		[0.38] = function(self)
			self:EmitSound("weapons/universal/uni_crawl_l_05.wav",55)
		end,
		[0.65] = function(self)
			self:EmitSound("weapons/arccw_ur/ak/12ga/magin.ogg",55)
		end,
	},
	["check_0_empty_empty"] = {
		[0.25] = function(self)
			self:EmitSound("weapons/arccw_ur/ak/12ga/magout.ogg",55)
		end,
		[0.6] = function(self)
			self:EmitSound("weapons/arccw_ur/ak/12ga/magin.ogg",55)
		end,
	},
}
//SWEP.MagIndex = 6
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():AddLayeredSequence(Entity(1):GetActiveWeapon():GetWM():LookupSequence("delta_foregrip"),1)
SWEP.FakeReloadSounds = {
	[0.3] = "weapons/arccw_ur/ak/12ga/magout.ogg",
	[0.45] = "weapons/ak74/ak74_magout_rattle.wav",
	[0.75] = "weapons/arccw_ur/ak/12ga/magin.ogg",
	[0.9] = "weapons/universal/uni_crawl_l_05.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav"
}

SWEP.FakeEmptyReloadSounds = {
	--[0.22] = "weapons/ak74/ak74_magrelease.wav",
	[0.25] = "weapons/arccw_ur/ak/12ga/chback.ogg",
	[0.3] = "weapons/arccw_ur/ak/12ga/chamber.ogg",
	[0.45] = "weapons/arccw_ur/ak/12ga/magout.ogg",
	[0.6] = "weapons/ak74/ak74_magout_rattle.wav",
	[0.8] = "weapons/arccw_ur/ak/12ga/magin.ogg",
	[0.92] = "weapons/universal/uni_crawl_l_05.wav",
	--[0.95] = "weapons/ak74/ak74_boltback.wav",
}
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_aa12_8.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,-0.0,-0.0)
SWEP.lmagang2 = Angle(-0,0,0)
if CLIENT then
local vector_full = Vector(1,1,1)
	SWEP.FakeReloadEvents = {
		[0.46] = function(self,timeMul)
			if self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(50, vector_origin)
			self:GetWM():SetBodygroup(7,0)
			hg.CreateMag( self, Vector(7,2,0) )
			end
		end,
		[0.62] = function(self,timeMul)
				if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(50, vector_full)
				self:GetWM():SetBodygroup(7,1)
				--self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 0.5 * timeMul)
				end
		end,
	}
end


SWEP.FakeMagDropBone = 50

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 40

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload0",
	["reload_empty"] = "reload_empty0_1",
}

--SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

SWEP.WepSelectIcon2 = Material("entities/arc9_eft_aa12.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_eft_aa12.png"

SWEP.ScrappersSlot = "Primary"
SWEP.CustomShell = "12x70"
SWEP.weight = 3.5
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 8
SWEP.OpenBolt = true
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "12/70 gauge"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 16
SWEP.Primary.Spread = Vector(0.025, 0.025, 0.025)
SWEP.Primary.Force = 17
SWEP.Primary.Sound = {"toz_shotgun/toz_fp.wav", 80, 70, 75}
SWEP.Primary.Wait = 0.16
SWEP.NumBullet = 8
SWEP.AnimShootMul = 3
SWEP.AnimShootHandMul = 10
SWEP.ReloadTime = 5.5
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

SWEP.PPSMuzzleEffect = "muzzleflash_M3" -- shared in sh_effects.lua

SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.2208, 10.3363)
SWEP.RHandPos = Vector(-15, -2, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.ShellEject = "ShotgunShellEject"
SWEP.SprayRand = {Angle(-0.1, -0.1, 0), Angle(-0.1, 0.1, 0)}
SWEP.Ergonomics = 0.85
SWEP.Penetration = 7
SWEP.WorldPos = Vector(13, -1, 4)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-27, 1.2, -2)
SWEP.attAng = Angle(0.05, -0.6, 0)
SWEP.lengthSub = 20
SWEP.DistSound = "toz_shotgun/toz_dist.wav"

SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(3, 8, -12)
SWEP.holsteredAng = Angle(210, 0, 180)

SWEP.LocalMuzzlePos = Vector(13.400,0.25,5.8)
SWEP.LocalMuzzleAng = Angle(1,0.0,0)
SWEP.WeaponEyeAngles = Angle(-0.0,-0.00,-0.0)

SWEP.punchmul = 2
SWEP.punchspeed = 0.5

SWEP.availableAttachments = {
}

--local to head
SWEP.RHPos = Vector(3,-5.5,3.5)
SWEP.RHAng = Angle(0,-10,90)
--local to rh
SWEP.LHPos = Vector(16,-1,-3.5)
SWEP.LHAng = Angle(-110,-90,-90)
function SWEP:PrimaryShootPost()
	if CLIENT then
		if self:Clip1() < 1 then
			self:PlayAnim("idle_empty",1)
			self:GetWM():SetBodygroup(7,0)
			self.AnimList["idle"] = "idle_empty"
		else
			self.AnimList["idle"] = "idle"
		end
	end
end

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