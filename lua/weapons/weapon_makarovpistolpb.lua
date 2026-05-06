SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Makarov PB"
SWEP.Author = "Izhevsk Mechanical Plant"
SWEP.Instructions = "An semi-automatic integrally Suppressed Russian pistol chambered in 9x18mm"
SWEP.Category = "Weapons - Pistols"
SWEP.ViewModel = ""

SWEP.WorldModel = "models/weapons/w_pist_p228.mdl"
SWEP.WorldModelFake = "models/weapons/arc9/darsu_eft/c_pb.mdl"

SWEP.FakePos = Vector(-23.5, 4.8, 5.1)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0,0,-0.2)
SWEP.AttachmentAng = Angle(0,0,90)
SWEP.MagIndex = nil
SWEP.FakeBodyGroups = "1111"
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"

function SWEP:OnCantReload()
	--inspect1
	--print("huy")
	if self.Inspecting and self.Inspecting > CurTime() then return end
	self.Inspecting = CurTime() + 4
	self:PlayAnim("magcheck0",4,false,function(self)
		self:PlayAnim("idle",1)
		--self.Inspecting = false
	end,false,true)

end

SWEP.AnimsEvents = {
	["magcheck0"] = {
		[0.15] = function(self)
			self:EmitSound("zcitysnd/sound/weapons/m9/handling/m9_magrelease.wav",55)
		end,
		[0.25] = function(self)
			self:EmitSound("zcitysnd/sound/weapons/m9/handling/m9_magout.wav",55)
		end,
		[0.7] = function(self)
			self:EmitSound("zcitysnd/sound/weapons/m9/handling/m9_magin.wav",55)
		end,
		[0.8] = function(self)
			self:EmitSound("zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",55)
		end,
	},
}

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "reload0",
	["reload_empty"] = "reload_empty0",
}

SWEP.WepSelectIcon2 = Material("entities/arc9_eft_pb.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_eft_pb.png"
local function UpdateVisualBullets(mdl,count)
	for i = 1, 10 do
		local boneid = 92 + i
		mdl:ManipulateBoneScale(boneid,i <= count and Vector(1,1,1) or Vector(0,0,0))
	end
end

function SWEP:PostFireBullet(bullet)
	UpdateVisualBullets(self:GetWM(),self:Clip1())
	local owner = self:GetOwner()
end

if CLIENT then
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
SWEP.FakeReloadEvents = {
	[0.55] = function( self )
		if self:Clip1() >= 1 then
			UpdateVisualBullets(self:GetWM(),20)
		end
	end,
	[0.38] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(10,-25,-15), nil, true )
				for i = 94, 101 do
					self:GetWM():ManipulateBoneScale(i, vecPochtiZero)
				self:GetWM():ManipulateBoneScale(50, vecPochtiZero)
				end
			end 
		end,
		[0.48] = function( self, timeMul )
			if self:Clip1() < 1 then
				for i = 94, 101 do
					self:GetWM():ManipulateBoneScale(i, vector_full)
				self:GetWM():ManipulateBoneScale(50, vector_full)
				UpdateVisualBullets(self:GetWM(),20)
				end
			end 
		end,
}
end

SWEP.CustomShell = "9x18"

SWEP.weight = 1
SWEP.punchmul = 1.0
SWEP.punchspeed = 4
SWEP.ScrappersSlot = "Secondary"

SWEP.LocalMuzzlePos = Vector(7.1,0.535,2.35)
SWEP.LocalMuzzleAng = Angle(0.0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.weaponInvCategory = 2
SWEP.ShellEject = "EjectBrass_9mm"
SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 8
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "9x18 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 8
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/makarov/makarov_fp.wav", 75, 90, 100}
SWEP.SupressedSound = {"zcitysnd/sound/weapons/makarov/makarov_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/makarov/handling/makarov_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Force = 20
SWEP.ReloadTime = 5
SWEP.FakeReloadSounds = {
	[0.35] = "zcitysnd/sound/weapons/m9/handling/m9_magrelease.wav",
	[0.45] = "zcitysnd/sound/weapons/m9/handling/m9_magout.wav",
	[0.8] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.9] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.25] = "zcitysnd/sound/weapons/m9/handling/m9_magrelease.wav",
	[0.35] = "zcitysnd/sound/weapons/m9/handling/m9_magout.wav",
	[0.65] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.72] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	[0.95] = "zcitysnd/sound/weapons/m9/handling/m9_boltrelease.wav",
}

SWEP.FakeVPShouldUseHand = false
SWEP.Supressor = true
SWEP.SetSupressor = true
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_Forearm"
SWEP.ViewPunchDiv = 80
SWEP.FakeMagDropBone = "mod_magazine"
SWEP.MagModel = "models/weapons/arc9/darsu_eft/mods/mag_pm_8.mdl"

SWEP.Primary.Wait = PISTOLS_WAIT
SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = false
SWEP.HoldType = "revolver"
SWEP.ZoomPos = Vector(0, 0.5274, 3.1378)
SWEP.RHandPos = Vector(-5, -1.5, 2)
SWEP.LHandPos = false
SWEP.SprayRand = {Angle(-0, -0.00, 0), Angle(-0.00, 0.00, 0)}
SWEP.Ergonomics = 1.15
SWEP.AnimShootMul = 3.5
SWEP.AnimShootHandMul = 2.5
SWEP.addSprayMul = 0.1
SWEP.Penetration = 4

SWEP.ShockMultiplier = 1
SWEP.WorldPos = Vector(5.5, -2, -1.5)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(5.7, -0.2, 0)
SWEP.attAng = Angle(0.4, 0, 90)
SWEP.lengthSub = 25
SWEP.DistSound = "zcitysnd/sound/weapons/makarov/makarov_dist.wav"
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, -3, 2)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true
SWEP.ImmobilizationMul = 1

--local to head
SWEP.RHPos = Vector(12,-4.5,3.5)
SWEP.RHAng = Angle(5,-5,90)
--local to rh
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)
SWEP.ShootAnimMul = 3
SWEP.SightSlideOffset = 1.2

SWEP.podkid = 0.9

function SWEP:DrawPost()
	local wep = self:GetWM()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 1)
		wep:ManipulateBonePosition(103, Vector(0, 1.3 * self.shooanim, 0), false)
	end
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