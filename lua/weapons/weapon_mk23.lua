SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "MK 23"
SWEP.Author = "Heckler & Koch"
SWEP.Instructions = "The Heckler & Koch MK 23, Mk 23 MOD 0, Mark 23, or USSOCOM MARK 23 is a semi-automatic large-frame pistol chambered in .45 ACP, designed specifically to be an offensive pistol. Comes with LAM Module installed."
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_pist_p228.mdl"
SWEP.WorldModelFake = "models/weapons/v_mk23_hollen.mdl"

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_hollen_mk23")
SWEP.IconOverride = "vgui/hud/tfa_ins2_hollen_mk23"

SWEP.FakePos = Vector(-21.5, 3.4, 8.32)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(-0.5,1.8,0.5)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.MagIndex = nil
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"
SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}
SWEP.NoIdleLoop = true
SWEP.CustomShell = "45acp"

SWEP.weight = 1
SWEP.punchmul = 1.5
SWEP.punchspeed = 3
SWEP.ScrappersSlot = "Secondary"

SWEP.LocalMuzzlePos = Vector(-1.212,0.88,6.117)
SWEP.LocalMuzzleAng = Angle(0,-0.026,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.lmagpos = Vector(0,0,-0.0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,-1.0)
SWEP.lmagang2 = Angle(0,0,70)

SWEP.GunCamPos = Vector(2.2,-17,-3)
SWEP.GunCamAng = Angle(0,0,0)

SWEP.MagModel = "models/weapons/upgrades/w_magazine_m45_8.mdl"

if CLIENT then
	local vector_full = Vector(1, 1, 1)
	SWEP.FakeReloadEvents = {
		[0.27] = function( self ) 
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(-20,20,-20) )
				self:GetWM():ManipulateBoneScale(1, vector_origin)
		else
			hg.CreateMag( self, Vector(-0,10,-20) )
			self:GetWM():ManipulateBoneScale(1, vector_origin)
		end
		end,
		[0.5] = function( self ) 
				self:GetWM():ManipulateBoneScale(1, vector_full)
		end,
	}
end

SWEP.weaponInvCategory = 2
SWEP.ShellEject = "EjectBrass_9mm"
SWEP.Primary.ClipSize = 12
SWEP.Primary.DefaultClip = 12
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ".45 ACP"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 25
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/firearms/hndg_colt1911/colt_1911_fire1.wav", 75, 90, 100}
SWEP.SupressedSound = {"m9/m9_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/makarov/handling/makarov_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Force = 25
SWEP.Primary.Wait = PISTOLS_WAIT
SWEP.ReloadTime = 4
SWEP.FakeReloadSounds = {
	[0.25] = "zcitysnd/sound/weapons/m9/handling/m9_magout.wav",
	[0.7] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.8] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.25] = "zcitysnd/sound/weapons/m9/handling/m9_magout.wav",
	[0.6] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.7] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	[0.9] = "zcitysnd/sound/weapons/m9/handling/m9_boltrelease.wav",
}

SWEP.ReloadSoundes = {
	"none",
	"pwb/weapons/fnp45/clipout.wav",
	"none",
	"none",
	"pwb/weapons/fnp45/clipin.wav",
	"pwb/weapons/fnp45/sliderelease.wav",
	"none",
	"none",
	"none"
}
SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}
SWEP.UseCustomWorldModel = true
SWEP.WorldPos = Vector(11, -0.8, 2.6)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.HoldType = "revolver"
SWEP.ZoomPos = Vector(0, 0.8471, 6.8689)
SWEP.RHandPos = Vector(-13.5, 0, 3)
SWEP.LHandPos = false
SWEP.attPos = Vector(1.1,0.5, -1.9)
SWEP.attAng = Angle(0, 0, 90)
SWEP.SprayRand = {Angle(-0.02, -0.02, 0), Angle(-0.04, 0.02, 0)}
SWEP.Ergonomics = 1.25	
SWEP.Penetration = 7
SWEP.lengthSub = 25
SWEP.DistSound = "m9/m9_dist.wav"
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, 1, -7)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor4", Vector(0,0,0), {}},
        ["mount"] = Vector(-1.3,0.6,0),
    },
	sight = {
		["mountType"] = {"picatinny","pistolmount"},
		["mount"] = {["picatinny"] = Vector(-3.5, 1.0, 0.05), ["pistolmount"] = Vector(-7.7, -0.4, 0.05)}
	},
	underbarrel = {
		["mount"] = Vector(0.8, -3.7, -0.15),
		["mountAngle"] = Angle(0, 8, 0),
	},
	mount = {
		["picatinny"] = {
			"mount4",
			Vector(-2, -1.2, 0),
			{},
			["mountType"] = "picatinny",
		}
	}
}
function SWEP:InitializePost()
	self.attachments.underbarrel = {[1] = "lasertaser0"}
end

function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) then
		self:GetWM():ManipulateBoneScale(2, vector_origin)
	end
end
--local to head
SWEP.RHPos = Vector(12,-4.5,3)
SWEP.RHAng = Angle(0,-5,90)
--local to rh
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)

SWEP.ShootAnimMul = 3
SWEP.SightSlideOffset = 0.8
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.FakeMagDropBone = "mag"

SWEP.BMerge = nil
function SWEP:SetupBoneMerge(mdl)
	if not mdl then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local vm = self:GetWeaponEntity()
	if not IsValid(vm) then return end

	if not IsValid(self.BMerge) then
		self.BMerge = ClientsideModel(mdl, RENDERGROUP_VIEWMODEL)
		if IsValid(self.BMerge) then
			self.BMerge:SetPos(vm:GetPos())
			self.BMerge:SetAngles(vm:GetAngles())
			self.BMerge:AddEffects(EF_BONEMERGE)
			self.BMerge:SetNoDraw(true)
			self.BMerge:SetParent(vm)
			self.BMerge:SetupBones()
			self.BMerge:DrawModel()
		end
	end
end

function SWEP:DrawPost()
	local owner = self:GetOwner()
	if IsValid(owner) and owner.GetActiveWeapon and IsValid(owner:GetActiveWeapon()) then
		if owner:GetActiveWeapon() ~= nil and owner:GetActiveWeapon() ~= NULL and owner:GetActiveWeapon() ~= self then return end
	end
	if not IsValid(self.BMerge) then
		self:SetupBoneMerge("models/weapons/upgrades/v_mk23_hollen_lam.mdl")
	else
		self.BMerge:SetupBones()
		self.BMerge:DrawModel()
	end

	local wep = self:GetWM()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() > 0 or self.reload) and 0 or 1)
		wep:ManipulateBonePosition(82, Vector(0, -2 * self.shooanim, 0), false)
		if self:Clip1() < 1 and self.shooanim > 0.1 then
			--self:GetWM():ManipulateBoneScale(64, vector_origin)
		end
	end
end

--RELOAD ANIMS PISTOL

SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(-3,-1,-5),
	Vector(-12,1,-22),
	Vector(-12,1,-22),
	Vector(-12,1,-22),
	Vector(-12,1,-22),
	Vector(-2,-1,-3),
	"fastreload",
	Vector(0,0,0),
	"reloadend",
	"reloadend",
}
SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(30,-10,0),
	Angle(60,-20,0),
	Angle(70,-40,0),
	Angle(90,-30,0),
	Angle(40,-20,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
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
	Vector(-2,0,0),
	Vector(-1,0,0),
	Vector(0,0,0)
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
	Angle(0,0,0),
	Angle(15,2,20),
	Angle(15,2,20),
	Angle(0,0,0)
}
SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(5,15,15),
	Angle(-5,21,14),
	Angle(-5,21,14),
	Angle(5,20,13),
	Angle(5,22,13),
	Angle(1,22,13),
	Angle(1,21,13),
	Angle(2,22,12),
	Angle(-5,21,16),
	Angle(-5,22,14),
	Angle(-4,23,13),
	Angle(7,22,8),
	Angle(7,12,3),
	Angle(2,6,1),
	Angle(0,0,0)
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