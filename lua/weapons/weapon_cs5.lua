SWEP.Base = "weapon_m4super"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "CS5"
SWEP.Author = "McMillan Brothers Rifle Co."
SWEP.Instructions = "Bolt-action Integrally Supressed Sniper Rifle chambered in 7.62x51 mm"
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_awp.mdl"
SWEP.WorldModelFake = "models/weapons/c_ins2_warface_mcmillan_cs5.mdl"
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
SWEP.FakePos = Vector(-10, 4, 6)
SWEP.FakeAng = Angle(-0.2, 0, 0)
SWEP.AttachmentPos = Vector(0.5,0.1,0.3)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.stupidgun = true
SWEP.DOZVUK = true

SWEP.FakeReloadSounds = {
	[0.25] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.27] = "weapons/m4a1/m4a1_magout.wav",
	[0.3] = "weapons/universal/uni_crawl_l_03.wav",
	[0.7] = "weapons/m4a1/m4a1_magain.wav",
	[0.45] = "weapons/aks74u/aks_magout_rattle.wav",
	[0.85] = "weapons/m4a1/m4a1_hit.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/m4a1/m4a1_magrelease.wav",
	[0.27] = "weapons/m4a1/m4a1_magout.wav",
	[0.3] = "weapons/universal/uni_crawl_l_03.wav",
	[0.7] = "weapons/m4a1/m4a1_magain.wav",
	[0.45] = "weapons/aks74u/aks_magout_rattle.wav",
	[0.85] = "weapons/m4a1/m4a1_hit.wav",
}

local math = math
local math_random = math.random
SWEP.MagModel = "models/kali/weapons/10rd m14 magazine.mdl"

SWEP.FakeMagDropBone = "mag"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(1.3,1.5,0)
SWEP.lmagang2 = Angle(90,0,-90)
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
SWEP.AnimsEvents = {
	["base_fire_end"] = {
		[0.25] = function(self)
			self:EmitSound("weapons/tfa_ins2/k98/m40a1_boltback.wav", 45, math_random(110, 115))
		end,
		[0.3] = function(self)
			if !self.noeject then
				self:RejectShell(self.ShellEject)
			else
				self.noeject = false
			end
		end,
		[0.4] = function(self)
			self:EmitSound("weapons/tfa_ins2/k98/m40a1_boltforward.wav", 45, math_random(110, 115))
		end,
		[0.5] = function(self)
			self:EmitSound("weapons/tfa_ins2/k98/m40a1_boltlatch.wav", 45, math_random(110, 115))
		end
	},
	["base_reload"] = {
		[0.14] = function( self, timeMul )
				hg.CreateMag( self, Vector(0,0,0), "111111", true )
			self:GetWM():ManipulateBoneScale(105, vecPochtiZero)
			self:GetWM():ManipulateBoneScale(106, vecPochtiZero)
		end,
		[0.3] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(105, vector_full)
			self:GetWM():ManipulateBoneScale(106, vector_full)
		end,
	}
}

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reloadempty",
	["cycle"] = "base_fire_end",
}

SWEP.ScrappersSlot = "Primary"
SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_warface_mcmillan_cs5")
SWEP.IconOverride = "vgui/hud/tfa_ins2_warface_mcmillan_cs5"
SWEP.weight = 3.0
SWEP.weaponInvCategory = 1
SWEP.CustomShell = "762x51"

SWEP.AutomaticDraw = false
SWEP.UseCustomWorldModel = false
SWEP.Primary.ClipSize = 10
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "7.62x51 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.Primary.Damage = 65
SWEP.Primary.Force = 65
SWEP.Primary.Sound = {"weapons/ak74/ak74_suppressed_tp.wav", 65, 90, 100}
SWEP.SupressedSound = {"weapons/ak74/ak74_suppressed_tp.wav", 65, 90, 100}
SWEP.availableAttachments = {
	sight = {
		["mount"] = {picatinny = Vector(-22, 1.4, 0.0)},
		["mountType"] = {"picatinny"},
		["empty"] = {
			"empty",
		},
	},
	underbarrel = {
		[1] = {"laser5", Vector(0.0,0.4,0.2), {}},

		["mount"] = {["picatinny_small"] =Vector(3.8, -1.9, -1.00),["picatinny"] = Vector(6.3,0.4,0)},
		["mountAngle"] = {["picatinny_small"] = Angle(-0.05, -1.1, 90),["picatinny"] = Angle(-0.1, 0.3, 0)},
		["mountType"] = {"picatinny_small","picatinny"},
		["removehuy"] = {
			["picatinny"] = {
			},
			["picatinny_small"] = {
			}
		}
	},
}

SWEP.StartAtt = {"optic2"}

SWEP.addSprayMul = 1
SWEP.cameraShakeMul = 1
SWEP.RecoilMul = 1

SWEP.LocalMuzzlePos = Vector(24,0.4,3.2)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)
SWEP.FakeViewBobBone = "ValveBiped.Bip01_L_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 90

SWEP.PPSMuzzleEffect = "muzzleflash_svd" -- shared in sh_effects.lu

SWEP.ShockMultiplier = 2
SWEP.Supressor = true
SWEP.SetSupressor = true

SWEP.handsAng = Angle(0, 0, 0)
SWEP.handsAng2 = Angle(-3, 1, 0)

SWEP.Primary.Wait = 0.15
SWEP.NumBullet = 1
SWEP.AnimShootMul = 1
SWEP.AnimShootHandMul = 1
SWEP.ReloadTime = 4.5
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
SWEP.ZoomPos = Vector(0, 0.3724, 5.1879)
SWEP.RHandPos = Vector(-8, -2, 6)
SWEP.LHandPos = Vector(6, -3, 1)
SWEP.AimHands = Vector(-10, 1.8, -6.1)
SWEP.SprayRand = {Angle(-0.03, -0.04, 0), Angle(-0.05, 0.04, 0)}
SWEP.Ergonomics = 1.3
SWEP.Penetration = 15
SWEP.ZoomFOV = 20
SWEP.WorldPos = Vector(5.5, -1, -1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.handsAng = Angle(-2, -1, 0)
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


SWEP.DistSound = "weapons/tfa_ins2/sks/sks_dist.wav"

SWEP.lengthSub = 15


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

function SWEP:InitializePost()
	self.AnimStart_Insert = 0
	self.AnimStart_Draw = 0
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
