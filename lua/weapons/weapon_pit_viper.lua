SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Pit Viper"
SWEP.Author = "Colt"
SWEP.Instructions = "Pistol chambered in .45 ACP"
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/pathfinder_fufu/tti/weapons/w_pit_viper.mdl"
SWEP.WorldModelFake = "models/pathfinder_fufu/tti/weapons/v_pit_viper.mdl"
-- SWEP.GetDebug = false

SWEP.WepSelectIcon2 = Material("entities/arccw_pitviper.png")
SWEP.IconOverride = "entities/arccw_pitviper.png"
SWEP.WepSelectIcon2box = true


SWEP.FakeAttachment = "1"
SWEP.FakePos = Vector(-22, 2.2, 9)
SWEP.FakeAng = Angle(0, 0, 3)
SWEP.AttachmentPos = Vector(4.35,1.5,0.5)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.MagIndex = nil

SWEP.FakeEjectBrassATT = "2"

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}

SWEP.CustomShell = "9x19"
SWEP.EjectAng = Angle(0,0,0)
SWEP.EjectPos = Vector(0.5,13,-1)

SWEP.weight = 1
SWEP.punchmul = 1.5
SWEP.punchspeed = 3
SWEP.ScrappersSlot = "Secondary"

SWEP.LocalMuzzlePos = Vector(-2.5,2,7.5)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.weaponInvCategory = 2
SWEP.ShellEject = "EjectBrass_9mm"
SWEP.Primary.ClipSize = 21
SWEP.Primary.DefaultClip = 21
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "9x19 mm Parabellum"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 25
SWEP.Primary.Sound = {"weapons/newakm/akmm_fp.wav", 75, 90, 100}
SWEP.SupressedSound = {"m9/m9_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/m1911/handling/m1911_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Force = 25
SWEP.Primary.Wait = PISTOLS_WAIT
SWEP.ReloadTime = 3.5
SWEP.FakeReloadSounds = {
	
	[0.3] = "pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_reload_magout.wav",
	[0.7] = "pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_reload_empty_magin.wav",
	
}

SWEP.FakeEmptyReloadSounds = {
	[0.3] = "pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_reload_empty_magout.wav",
	[0.59] = "pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_reload_empty_magin.wav",
	[0.82] = "pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_reload_empty_charge.wav",
}

local vector_origin = Vector(0,0,0)
local vector_full = Vector(1,1,1)

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


SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}
SWEP.UseCustomWorldModel = true
SWEP.WorldPos = Vector(11, -0.8, 2.6)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.HoldType = "revolver"
SWEP.ZoomPos = Vector(25, 2.8, 7.6)
SWEP.RHandPos = Vector(-13.5, 0, 3)
SWEP.LHandPos = false
SWEP.attPos = Vector(-0.4, 3, 15.5)
SWEP.attAng = Angle(0, 0, 0)
SWEP.SprayRand = {Angle(-0.03, -0.03, 0), Angle(-0.05, 0.03, 0)}
SWEP.Ergonomics = 1.2
SWEP.Penetration = 7
SWEP.lengthSub = 25
SWEP.DistSound = "m9/m9_dist.wav"
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(-3, 4, 0)
SWEP.holsteredAng = Angle(0, 0, 100)
SWEP.shouldntDrawHolstered = true

SWEP.FakeReloadEvents = {
	[0.15] = function( self, timeMul ) 
		if CLIENT then
			self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 2.5 * timeMul)
			self:GetWM():ManipulateBoneScale(2, vector_full)
		end 
	end,
	[0.37] = function( self ) 
		if CLIENT and self:Clip1() < 1 then
			hg.CreateMag( self, Vector(-15,5,-15) )
			self:GetWM():ManipulateBoneScale(2, vector_origin)
		end 
	end,
	[0.55] = function( self ) 
		if CLIENT and self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(2, vector_full)
		end 
	end,
}

--local to head
SWEP.RHPos = Vector(12,-4.5,3)
SWEP.RHAng = Angle(0,-5,90)
--local to rh
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)

SWEP.ShootAnimMul = 3
SWEP.SightSlideOffset = 0.8

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_Forearm"
SWEP.ViewPunchDiv = 50
SWEP.FakeMagDropBone = "vm_mag"
SWEP.MagModel = "models/weapons/upgrades/w_magazine_m45_8.mdl"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(-12.7,0,-2.4)
SWEP.lmagang2 = Angle(90,0,-110)

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		-- Bone 119: slide back ONLY when empty - manual Vector lerp (LerpVector error fixed)
		self.empty_anim = self.empty_anim or 0
		local target_empty = (self:Clip1() == 0) and 1 or 0
		self.empty_anim = Lerp(FrameTime() * 30, self.empty_anim, target_empty)
		if target_empty == 0 then
			self.empty_anim = math.max(0, self.empty_anim - FrameTime() * 40)  -- faster snap back to 0
		end
		self.empty_anim = math.Clamp(self.empty_anim, 0, 1)
		
		local y = Lerp(self.empty_anim, 0, 0)
		local z = Lerp(self.empty_anim, 0, 0)
		local bone119_pos = Vector(x, y, z)
		wep:ManipulateBonePosition(119, bone119_pos, false)
		
		-- Bone 8 slide from second DrawPost
		self.vec = self.vec or Vector(0,0,0)
		local vec = self.vec
		local slideOffset = self.ReloadSlideOffset or 0
		self.shooanim_slide = Lerp(FrameTime()*15, self.shooanim_slide or 0, slideOffset)
		vec[1] = 0 * self.shooanim_slide
		vec[2] = 1 * self.shooanim_slide
		vec[3] = 0 * self.shooanim_slide
		wep:ManipulateBonePosition(8, vec, false)
		
		-- Bone 141 scale during reload
		local seq = wep:GetSequenceName(wep:GetSequence())
		local bone_scale = (seq:find("reload") or self.reload) and vector_full or vector_origin
		wep:ManipulateBoneScale(141, bone_scale)
		
		wep:InvalidateBoneCache()
	end
end

function SWEP:OnCantReload()
    --inspect1
    --print("huy")
    if self.Inspecting and self.Inspecting > CurTime() then return end
    self.Inspecting = CurTime() + 12
    local anim = math.random(2) == 1 and "inspect" or "inspect"
    self:PlayAnim(anim,12,false,function(self)
        self:PlayAnim("idle",1)
        --self.Inspecting = false
    end,false,true)
end

function SWEP:ModelCreated(model)
	if CLIENT and IsValid(model) then
		model:ManipulateBoneScale(141, Vector(0,0,0))
		model:InvalidateBoneCache()
	end
end

function SWEP:PostDrawWorldModel()
	local model = self:GetWorldModel()
	if IsValid(model) then
		model:ManipulateBoneScale(141, Vector(0,0,0))
		model:InvalidateBoneCache()
	end
end

SWEP.AnimsEvents = {
		 ["inspect"] = {
        [0.0] = function(self)
            self:EmitSound("pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_inspect_decock.wav",55)
        end,
		[0.05] = function(self)
            self:EmitSound("pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_inspect_empty_rotate1.wav",55)
        end,
        [0.08] = function(self)
            self:EmitSound("pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_raise_first_twirl.wav",55)
		end,
		 [0.28] = function(self)
            self:EmitSound("pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_inspect_empty_magmvmnt1.wav",55)
		end,
		 [0.43] = function(self)
            self:EmitSound("pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_inspect_magout.wav",55)
		end,
		 [0.6] = function(self)
            self:EmitSound("pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_inspect_chargeeject.wav",55)
		end,
		 [0.64] = function(self)
            self:EmitSound("pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_inspect_bulletland.wav",55)
		end,
		[0.75] = function(self)
            self:EmitSound("pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_reload_empty_charge.wav",55)
		end,
		[0.89] = function(self)
            self:EmitSound("pathfinder_fufu/tti/weapons/viper/p55_pi_mike2011_reload_empty_magin.wav",55)
		end,
    }
}

