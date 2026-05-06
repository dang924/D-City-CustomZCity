SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "m4a1 MWB"
SWEP.Author = "Izhevsk Machine-Building Plant"
SWEP.Instructions = "Automatic rifle chambered in 5.45x39 mm\n\nRate of fire 700 rounds per minute"
SWEP.Category = "Weapons - Event"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/mw/Mwb_M4a1.mdl"

SWEP.FakePos = Vector(-11, 2.53, 5.3)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(-8.1,0,0)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeAttachment = "1"
SWEP.FakeBodyGroups = "00900080302"
SWEP.ZoomPos = Vector(0, -0.0027, 4.6866)

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.FakeEjectBrassATT = "2"

SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.29] = "weapons/arccw_ud/m16/grab.ogg",
	[0.34] = "iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_reload_magout.wav",
	[0.38] = "iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_reload_magbump.wav",

	[0.64] = "iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_reload_magbump.wav",
	[0.64] = "iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_reload_magin.wav",
	[0.81] = "weapons/universal/uni_crawl_l_03.wav",
	[0.99] = "weapons/universal/uni_crawl_l_04.wav",

}

SWEP.FakeEmptyReloadSounds = {

	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.29] = "weapons/arccw_ud/m16/magout_empty.ogg",
	[0.32] = "weapons/ak74/ak74_magout_rattle.wav",
	[0.59] = "weapons/arccw_ud/m16/grab.ogg",
	[0.62] = "weapons/arccw_ud/m16/magin.ogg",

	[0.83] = "weapons/arccw_ud/m16/magtap.ogg",
	[1.01] = "weapons/universal/uni_crawl_l_04.wav",
}

SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_ak74_izhmash_6l23_545x39_30.mdl"
SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,1)
SWEP.lmagang2 = Angle(90,0,-90)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70

SWEP.FakeMagDropBone = 57

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}
if CLIENT then
	local vector_full = Vector(1,1,1)
	SWEP.FakeReloadEvents = {
		[0.15] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(55, vector_origin)
			self:GetWM():ManipulateBoneScale(56, vector_origin)
			self:GetWM():ManipulateBoneScale(57, vector_full)
			self:GetWM():ManipulateBoneScale(58, vector_full)
		end,
		[0.16] = function( self, timeMul )
			self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.58 * timeMul)
		end,
		[0.27] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(57, vector_full)
			self:GetWM():ManipulateBoneScale(58, vector_full)
			self:GetWM():ManipulateBoneScale(55, vector_full)
			self:GetWM():ManipulateBoneScale(56, vector_full)
		end,
		
		[0.40] = function(self,timeMul)
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(50,10,10),nil, true )
				self:GetWM():ManipulateBoneScale(57, vector_origin)
				self:GetWM():ManipulateBoneScale(58, vector_origin)
				--self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 0.5 * timeMul)
			end
		end,
		[0.85] = function(self,timeMul)
			self:GetWM():ManipulateBoneScale(57, vector_origin)
			self:GetWM():ManipulateBoneScale(58, vector_origin)
		end
	}
end

SWEP.settedGroups = false
function SWEP:ThinkAdd()
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
		if self:HasAttachment("grip", "grip_akdong") then
			self:GetWM():SetBodyGroups("02900080302")
			self.settedGroups = true
		else
			self:GetWM():SetBodyGroups(self.FakeBodyGroups)
			self.settedGroups = true
		end
		--self:GetWM():SetBodyGroups(self.FakeBodyGroups)
	end
end

function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
		self:GetWM():ManipulateBoneScale(57, vector_origin)
		self:GetWM():ManipulateBoneScale(58, vector_origin)
		self:GetWM():SetBodyGroups(self.FakeBodyGroups)
	end
end

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false


SWEP.weaponInvCategory = 1
SWEP.CustomEjectAngle = Angle(0, 0, 90)
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.45x39 mm"

SWEP.CustomShell = "545x39"


SWEP.ScrappersSlot = "Primary"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 35
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 35

SWEP.Primary.Sound = {
	"iw9/wpn/atmo/ext/weap_ar14_fire_plr_atmo_ext1_01.wav",
		"iw9/wpn/atmo/ext/weap_ar14_fire_plr_atmo_ext1_02.wav",
		"iw9/wpn/atmo/ext/weap_ar14_fire_plr_atmo_ext1_03.wav",
		"iw9/wpn/atmo/ext/weap_ar14_fire_plr_atmo_ext1_04.wav",
		"iw9/wpn/atmo/ext/weap_ar14_fire_plr_atmo_ext1_05.wav",
		"iw9/wpn/atmo/ext/weap_ar14_fire_plr_atmo_ext1_06.wav",
		"iw9/wpn/atmo/ext/weap_ar14_fire_plr_atmo_ext1_07.wav",
		"iw9/wpn/atmo/ext/weap_ar14_fire_plr_atmo_ext1_08.wav", 85, 90, 100}


SWEP.Primary.SoundFP = {"weap_iw9_mike4_fire_plr_01", 85, 90, 100}

SWEP.SupressedSound = {"weapons/ak74/ak74_suppressed_tp.wav", 65, 90, 100}
SWEP.SupressedSoundFP = {"weapons/ak74/ak74_suppressed_fp.wav", 65, 90, 100}

SWEP.DistSound = "weapons/ak74/ak74_dist.wav"

SWEP.Primary.Wait = 0.055
SWEP.ReloadTime = 3
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip out 1.wav",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip in 2.wav",
	"none",
	"pwb2/weapons/m4a1/ru-556 bolt back.wav",
	"pwb2/weapons/m4a1/ru-556 bolt forward.wav",
	"none",
	"none",
	"none",
	"none"
}

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1" -- shared in sh_effects.lua

SWEP.LocalMuzzlePos = Vector(27.985,-0.25,2.295)
SWEP.LocalMuzzleAng = Angle(-0.2,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.HoldType = "rpg"

SWEP.RHandPos = Vector(-12, -1, 4)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.Penetration = 11
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 0.5
end

SWEP.WepSelectIcon2 = Material("entities/tfa_ins2_ak74_r.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/tfa_ins2_ak74_r.png"

SWEP.Ergonomics = 1
SWEP.WorldPos = Vector(5, -0.8, -1.1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0.25, -2.1, 28)
SWEP.attAng = Angle(0, 0.4, 0)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(1, -1.5, 0)

SWEP.availableAttachments = {
}

SWEP.weight = 3

--local to head
SWEP.RHPos = Vector(3,-6,3.5)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(15,1,-3.3)
SWEP.LHAng = Angle(-110,-180,0)

local finger1 = Angle(25,0, 40)

SWEP.ShootAnimMul = 3
function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = Lerp(FrameTime()*15,self.shooanim or 0,self.ReloadSlideOffset)
		vec[1] = 0*self.shooanim
		vec[2] = 1*self.shooanim
		vec[3] = 0*self.shooanim
		wep:ManipulateBonePosition(8,vec,false)
	end
end

local lfang2 = Angle(0, -15, -1)
local lfang1 = Angle(-5, -5, -5)
local lfang0 = Angle(-12, -16, 20)
local vec_zero = Vector(0,0,0)
local ang_zero = Angle(0,0,0)
function SWEP:AnimHoldPost()

end

function SWEP:OnCantReload()
    --inspect1
    --print("huy")
    if self.Inspecting and self.Inspecting > CurTime() then return end
    self.Inspecting = CurTime() + 4
    local anim = math.random(2) == 1 and "inspect" or "inspect"
    self:PlayAnim(anim,5,false,function(self)
        self:PlayAnim("idle",1)
        --self.Inspecting = false
    end,false,true)
end

SWEP.AnimsEvents = {
		 ["inspect"] = {
        [0.0] = function(self)
            self:EmitSound("iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_inspect_mvt1.wav",55)
        end,
		[0.1] = function(self)
            self:EmitSound("iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_inspect_magout.wav",55)
        end,
        [0.3] = function(self)
            self:EmitSound("iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_inspect_magbump.wav",55)
		end,
		 [0.35] = function(self)
            self:EmitSound("iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_inspect_magin.wav",65)
		end,
		 [0.45] = function(self)
            self:EmitSound("iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_inspect_charge.wav",55)
		end,
		 [0.69] = function(self)
            self:EmitSound("iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_inspect_return.wav",55)
		end,
		 [0.74] = function(self)
            self:EmitSound("iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_inspect_mvt2.wav",55)
		end,
		[0.75] = function(self)
            self:EmitSound("iw9/wpn/reloads/iw9_mike4/p01_ar_mike4_inspect_shoulder.wav",55)
		end,
    }
}

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
	0,
	3,
	3,
	0,
	0,
	0,
	0
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
	Angle(7,17,-22),
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