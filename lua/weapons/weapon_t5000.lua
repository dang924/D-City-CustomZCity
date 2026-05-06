SWEP.Base = "weapon_m4super"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "T-5000"
SWEP.Author = "ORSIS"
SWEP.Instructions = "Bolt-action Sniper Rifle chambered in .338 Lapua Magnum"
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_awp.mdl"
SWEP.WorldModelFake = "models/weapons/c_ins2_warface_orsis_t5000.mdl"

SWEP.FakePos = Vector(-9, 3.5, 6)
SWEP.FakeAng = Angle(-0.2, 0, 0)
SWEP.AttachmentPos = Vector(0.5,0.1,0.3)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.stupidgun = true

SWEP.FakeReloadSounds = {
	[0.2] = "weapons/universal/uni_crawl_l_03.wav",
	[0.35] = "weapons/tfa_ins2/vz61/vz61_magrelease.wav",
	[0.45] = "weapons/tfa_ins2/csniper/csniper_magout.wav",
	[0.55] = "weapons/aks74u/aks_magout_rattle.wav",
	[0.85] = "weapons/tfa_ins2/csniper/csniper_magin.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.2] = "weapons/universal/uni_crawl_l_03.wav",
	[0.35] = "weapons/tfa_ins2/vz61/vz61_magrelease.wav",
	[0.45] = "weapons/tfa_ins2/csniper/csniper_magout.wav",
	[0.55] = "weapons/aks74u/aks_magout_rattle.wav",
	[0.85] = "weapons/tfa_ins2/csniper/csniper_magin.wav",
}

local math = math
local math_random = math.random
SWEP.AnimsEvents = {
	["base_fire_end"] = {
		[0.25] = function(self)
			self:EmitSound("weapons/tfa_ins2/m40a1/m40a1_boltback.wav", 45, math_random(110, 115))
		end,
		[0.35] = function(self)
			if !self.noeject then
				self:RejectShell(self.ShellEject)
			else
				self.noeject = false
			end
		end,
		[0.4] = function(self)
			self:EmitSound("weapons/tfa_ins2/m40a1/m40a1_boltforward.wav", 45, math_random(110, 115))
		end,
		[0.5] = function(self)
			self:EmitSound("weapons/tfa_ins2/k98/m40a1_boltlatch.wav", 45, math_random(110, 115))
		end
	}
}

SWEP.MagModel = "models/kali/weapons/10rd m14 magazine.mdl"

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
	["reload_empty"] = "base_reloadempty",
	["cycle"] = "base_fire_end",
}

SWEP.ScrappersSlot = "Primary"
SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_warface_orsis_t5000")
SWEP.IconOverride = "vgui/hud/tfa_ins2_warface_orsis_t5000"
SWEP.weight = 4.4
SWEP.weaponInvCategory = 1
SWEP.CustomShell = ".338Lapua"

SWEP.AutomaticDraw = false
SWEP.UseCustomWorldModel = false
SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 5
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ".338 Lapua Magnum"
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.Primary.Damage = 180
SWEP.Primary.Force = 60
SWEP.Primary.Sound = {"homigrad/weapons/rifle/loud_awp.wav", 65, 90, 100}
SWEP.SupressedSound = {"homigrad/weapons/rifle/m4a1-1.wav", 65, 90, 100}
SWEP.availableAttachments = {
	sight = {
		["mount"] = {picatinny = Vector(-31, 0.9, 0.0), ironsight = Vector(-26.3, 0.9, 0.00)},
		["mountType"] = {"picatinny", "ironsight"},
		["empty"] = {
			"empty",
		},
	},
	underbarrel = {
		[1] = {"laser5", Vector(0.0,0.4,0.2), {}},

		["mount"] = {["picatinny_small"] =Vector(-1.3, -1.6, -1.01),["picatinny"] = Vector(-0.45,-0.15,0)},
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

SWEP.StartAtt = {"ironsight1"}

SWEP.addSprayMul = 1
SWEP.cameraShakeMul = 1
SWEP.RecoilMul = 1

SWEP.LocalMuzzlePos = Vector(35,0.9,3.6)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffect = "muzzleflash_m79" -- shared in sh_effects.lu

SWEP.ShockMultiplier = 1

SWEP.handsAng = Angle(0, 0, 0)
SWEP.handsAng2 = Angle(-3, 1, 0)

SWEP.Primary.Wait = 0.15
SWEP.NumBullet = 1
SWEP.AnimShootMul = 1
SWEP.AnimShootHandMul = 1
SWEP.ReloadTime = 5
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
SWEP.ZoomPos = Vector(0, 0.8636, 5.0264)
SWEP.RHandPos = Vector(-8, -2, 6)
SWEP.LHandPos = Vector(6, -3, 1)
SWEP.AimHands = Vector(-10, 1.8, -6.1)
SWEP.SprayRand = {Angle(-0.8, -0.2, 0), Angle(-0.8, 0.2, 0)}
SWEP.Ergonomics = 1
SWEP.Penetration = 35
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
