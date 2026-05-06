SWEP.Base = "weapon_m4super"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "CheyTac Intervention"
SWEP.Author = "Mauser"
SWEP.Instructions = "This is a BIG Bolt-Action Sniper rifle. This weapon is chambered on 12.7x55 mm"
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_shot_m3super90.mdl"
SWEP.WorldModelFake = "models/weapons/c_ins2_warface_cheytac_m200_2.mdl"
SWEP.FakePos = Vector(-10, 2, 6.5)
SWEP.FakeAng = Angle(-0.2, 0, 0)
SWEP.AttachmentPos = Vector(0,0,0)
SWEP.AttachmentAng = Angle(0,0,0)

SWEP.FakeReloadSounds = {
	[0.44] = "weapons/cheytac_m200/m200_clipout.wav",
	[0.86] = "weapons/arccw/mw3e_scarl/hit.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.1] = "weapons/tfa_ins2/k98/m40a1_boltlatch.wav",
	[0.15] = "weapons/tfa_ins2/k98/m40a1_boltrelease.wav",
	[0.45] = "weapons/cheytac_m200/m200_clipout.wav",
	[0.87] = "weapons/arccw/mw3e_scarl/hit.wav",
	[0.97] = "weapons/tfa_ins2/k98/m40a1_boltrelease.wav",
}

local math = math
local math_random = math.random
SWEP.AnimsEvents = {
	["base_fire_end"] = {
		[0.1] = function(self)
			self:EmitSound("weapons/cheytac_m200/m200_boltup.wav", 45, math_random(110, 115))
		end,
		[0.3] = function(self)
			if !self.noeject then
				self:RejectShell(self.ShellEject)
			else
				self.noeject = false
			end
			self:EmitSound("weapons/cheytac_m200/m200_boltback.wav", 45, math_random(110, 115))
		end,
		[0.5] = function(self)
			self:EmitSound("weapons/cheytac_m200/m200_boltdown.wav", 45, math_random(110, 115))
		end
	}
}

SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_axmc_86x70_10.mdl"

SWEP.FakeMagDropBone = "Magazine"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0.3,0)
SWEP.lmagang2 = Angle(0,0,0)

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.35] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 1.1 * timeMul)
			end
		end,
		[0.36] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,0,-50), "111111")
				self:GetWM():ManipulateBoneScale(67, vecPochtiZero)

			end 
		end,
		[0.6] = function( self, timeMul )
			if self:Clip1() < 1 then

				self:GetWM():ManipulateBoneScale(67, vector_full)
			end
		end,
	}
end

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reload_empty",
	["cycle"] = "base_fire_end",
}

SWEP.ScrappersSlot = "Primary"
SWEP.WepSelectIcon2 = Material("entities/tfa_ins2_warface_cheytac_m200_1.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/tfa_ins2_warface_cheytac_m200.png"
SWEP.weight = 2
SWEP.weaponInvCategory = 1
SWEP.CustomShell = ".338Lapua"

SWEP.EjectAng = Angle(-45,0,0)
SWEP.AutomaticDraw = false
SWEP.UseCustomWorldModel = false
SWEP.Primary.ClipSize = 6
SWEP.Primary.DefaultClip = 6
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "12.7x108 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.Primary.Damage = 90
SWEP.Primary.Force = 70
SWEP.Primary.Sound = {"weapons/cheytac_m200/m200_shoot.wav", 65, 90, 100}
SWEP.SupressedSound = {"weapons/cheytac_m200/m200_suppressed.wav", 65, 90, 100}
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor8", Vector(2,-2,0), {}},
		[2] = {"supressor6", Vector(3,0,0), {}},
		["mount"] = Vector(-3,2,0.2),
	},
	sight = {
		["mountType"] = {"picatinny", "dovetail"},
		["mount"] = {["dovetail"] = Vector(-27, 0.4, 0.1),["picatinny"] = Vector(-27, 1, 0.25)},
	},
	mount = {
		["dovetail"] = {
			"empty",
			Vector(0, 0, 0),
			{},
			["mountType"] = "dovetail",
		},
	},
}
SWEP.StartAtt = {"optic6"}
SWEP.addSprayMul = 0.1
SWEP.cameraShakeMul = 1.3
SWEP.RecoilMul = 1.6

SWEP.LocalMuzzlePos = Vector(33.6,-0.022,2.758)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffect = "muzzleflash_svd" -- shared in sh_effects.lu

SWEP.ShockMultiplier = 2

SWEP.handsAng = Angle(0, 0, 0)
SWEP.handsAng2 = Angle(-3, 1, 0)

SWEP.Primary.Wait = 0.15
SWEP.NumBullet = 1
SWEP.AnimShootMul = 1
SWEP.AnimShootHandMul = 0
SWEP.ReloadTime = 6
SWEP.ReloadSoundes = {
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magout.wav",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magoutrattle.wav",
	"weapons/tfa_ins2/ak103/ak103_magin.wav",
	"weapons/tfa_ins2/ak103/ak103_boltback.wav",
	"weapons/tfa_ins2/ak103/ak103_boltrelease.wav",
	"none",
	"none",
	"none"
}
SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(-3, -0.3, 5.2)
SWEP.RHandPos = Vector(-8, -2, 6)
SWEP.LHandPos = Vector(6, -3, 1)
SWEP.SprayRand = {Angle(-0.2, -0.4, 0), Angle(-0.4, 0.4, 0)}
SWEP.Ergonomics = 0.75
SWEP.Penetration = 35
SWEP.WorldPos = Vector(5.5, -1, -1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.FakeViewBobBone = "ValveBiped.Bip01_L_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 90

SWEP.DistSound = "weapons/darsu_eft/axmc/aiax_outdoor_distant.ogg"

SWEP.lengthSub = 15
SWEP.bipodAvailable = true
SWEP.bipodsub = 15
SWEP.RestPosition = Vector(22, -1, 4)
--local to head
SWEP.RHPos = Vector(3,-6.5,4)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(17,1.3,-3.4)
SWEP.LHAng = Angle(-110,-180,-5)

SWEP.ShootAnimMul = 5

function SWEP:AnimHoldPost(model)
end

function SWEP:AnimationPost()
end

function SWEP:GetAnimPos_Insert(time)
	return 0
end

function SWEP:GetAnimPos_Draw(time)
	return 0
end

local function cock(self,time)
	if SERVER then
		self:Draw(true, true)
	end

	if self:Clip1() == 0 then
		self.drawBullet = nil
	end

	if CLIENT and LocalPlayer() == self:GetOwner() then return end

	net.Start("hgwep draw")
		net.WriteEntity(self)
		net.WriteBool(self.drawBullet)
		net.WriteFloat(CurTime())
	net.Broadcast()

	self.Primary.Next = CurTime() + self.AnimDraw + self.Primary.Wait

	local ply = self:GetOwner()

	self.reloadCoolDown = CurTime() + time
end


SWEP.GunCamPos = Vector(6,-12,-5)
SWEP.GunCamAng = Angle(190,-5,-95)

SWEP.FakeEjectBrassATT = "4"

function SWEP:Reload(time)
	--PrintTable(self:GetWM():GetAttachments())
	--print(self:GetNetVar("shootgunReload",0))
	local ply = self:GetOwner()
	--if ply.organism and (ply.organism.larmamputated or ply.organism.rarmamputated) then return end
	if self.AnimStart_Draw > CurTime() - 0.5 then return end
	if not self:CanUse() then return end
	if self.reloadCoolDown > CurTime() then return end
	if self.Primary.Next > CurTime() then return end
	if self:GetNetVar("shootgunReload",0) > CurTime() then return end

	if self.drawBullet == false and SERVER then
		cock(self,1.5)
		self:SetNetVar("shootgunReload",CurTime() + 1.3)
		self:PlayAnim(self.AnimList["cycle"] or "cycle", 1.5, false, nil, false, true)
		return
	end

	if not self:CanReload() then return end

	if SERVER then
		self:SetNetVar("shootgunReload",CurTime() + 1.1)
		self.LastReload = CurTime()
		self:ReloadStart()
		self:ReloadStartPost()
		local org = self:GetOwner().organism
		self.StaminaReloadMul = (org and ((2 - (self:GetOwner().organism.stamina[1] / 180)) + ((org.pain / 40) + (org.larm / 3) + (org.rarm / 5)) - (1 - math.Clamp(org.recoilmul or 1,0.45,1.4))) or 1)
		self.StaminaReloadMul = math.Clamp(self.StaminaReloadMul,0.65,1.5)
		self.StaminaReloadTime = self.ReloadTime * self.StaminaReloadMul
		self.StaminaReloadTime = (self.StaminaReloadTime + (self:Clip1() > 0 and -self.StaminaReloadTime/3 or 0 ))
		self.reload = self.LastReload + self.StaminaReloadTime
		self.dwr_reverbDisable = true
		self:PlayAnim(self.AnimList["reload"] or "reload", self.StaminaReloadTime, false, nil, false, true)
		net.Start("hgwep reload")
			net.WriteEntity(self)
			net.WriteFloat(self.LastReload)
			net.WriteInt(self:Clip1(),10)
			net.WriteFloat(self.StaminaReloadTime)
			net.WriteFloat(self.StaminaReloadMul)
		net.Broadcast()
	end
end

function SWEP:ReloadEnd()
	--if not self.CustomAmmoInsertEvent then
	self:InsertAmmo(self:GetMaxClip1() - self:Clip1() + (self.drawBullet ~= nil and not self.OpenBolt and 1 or 0))
	--end
	self.ReloadNext = CurTime() + self.ReloadCooldown --я хуй знает чо это
	if CLIENT and self.drawBullet == nil then
		self.noeject = true
	end
	if SERVER and self.drawBullet == nil then
		self:SetNetVar("shootgunReload",CurTime() + 1.3)
		self:PlayAnim(self.AnimList["cycle"] or "cycle", 1.5, false, nil, false, true)
	end

	self:Draw(nil,true)
end

function SWEP:CanPrimaryAttack()
	return not (self:GetNetVar("shootgunReload",0) > CurTime())
end

function SWEP:DrawPost()
end

function SWEP:ModelCreated(model)
	model:SetBodyGroups(self:GetRandomBodygroups() or "1112011")
end

function SWEP:PostSetupDataTables()
	self:NetworkVar("String",0,"RandomBodygroups")
	if ( CLIENT ) then
		self:NetworkVarNotify( "RandomBodygroups", self.OnVarChanged )
	end
end

function SWEP:OnVarChanged( name, old, new )
	if !IsValid(self:GetWM()) then return end

	self:GetWM():SetBodyGroups(new)
end

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
