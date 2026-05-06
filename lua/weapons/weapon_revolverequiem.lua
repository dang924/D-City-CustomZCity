SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = [["Requiem"]]
SWEP.Author = "Unknown..."
SWEP.Instructions = "Revolver Chambered in 12.7x55 issued to DSO agents for killing very evil residents\n\nrequiem requiem reference"
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_357.mdl"
SWEP.WorldModelFake = "models/v_models/c_requiem.mdl"

SWEP.FakePos = Vector(-12.5, 3.5, 7)
SWEP.FakeAng = Angle(0, 0, 4)
SWEP.AttachmentPos = Vector(-2,-1.6,-23.1)
SWEP.AttachmentAng = Angle(0,0,90)
SWEP.FakeScale = 1.0


SWEP.FakeVPShouldUseHand = true
SWEP.AnimList = {
	["idle"] = "idle01",
	["reload"] = "reload",
	["reload_empty"] = "reload",
}
SWEP.NoIdleLoop = true
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 80
	SWEP.FakeEmptyReloadSounds = {
		[0.16] = "weapons/universal/uni_crawl_l_03.wav",
		[0.2] = "weapons/arccw_ur/sw329/cyl_latch.ogg",
		[0.25] = "weapons/arccw_ur/sw329/cyl_open.ogg",
		[0.38] = "weapons/tfa_ins2/thanez_cobra/revolver_dump_rounds_01.wav",
		[0.52] = "weapons/universal/uni_crawl_l_01.wav",
		[0.65] = "weapons/arccw_ur/sw586/speedloader.ogg",
		[0.85] = "weapons/arccw_ur/sw586/cylinder_in.ogg",
		[1.00] = "weapons/357/357_spin1.wav",
	}
	SWEP.FakeReloadSounds = {
		[0.16] = "weapons/universal/uni_crawl_l_03.wav",
		[0.2] = "weapons/arccw_ur/sw329/cyl_latch.ogg",
		[0.25] = "weapons/arccw_ur/sw329/cyl_open.ogg",
		[0.38] = "weapons/tfa_ins2/thanez_cobra/revolver_dump_rounds_01.wav",
		[0.52] = "weapons/universal/uni_crawl_l_01.wav",
		[0.65] = "weapons/arccw_ur/sw586/speedloader.ogg",
		[0.85] = "weapons/arccw_ur/sw586/cylinder_in.ogg",
		[1.00] = "weapons/357/357_spin1.wav",
	}
SWEP.MagModel = "models/weapons/upgrades/w_magazine_m45_8.mdl" 

SWEP.lmagpos = Vector(2.,0,0)
SWEP.lmagang = Angle(-10,0,0)
SWEP.lmagpos2 = Vector(0,-1.5,0.7)
SWEP.lmagang2 = Angle(0,0,0)

--[[
	95	Trigger
96	speedloader
97	BULLETS6
98	BULLET1
99	BULLET2
100	BULLET3
101	BULLET4
102	BULLET5
103	BULLET6
104	BULLETS1
105	BULLETS2
106	BULLETS3
107	BULLETS4
108	BULLETS5

]]

if CLIENT then
	local vector_full = Vector(1, 1, 1)
	
	local ang = Angle(-90, 0, 0)
	ang:RotateAroundAxis(ang:Right(), 180)

	SWEP.FakeReloadEvents = {
		[0.38] = function( self, timeMul )
			if CLIENT then
				local owner = self:GetOwner()
				local drum = self:GetDrum()
				for i = 1, #drum do
					if self.CustomShell and drum[i] == -1 then
						local pos, ang = self:GetWM():GetBonePosition(5)
						self:MakeShell(self.CustomShell, pos, ang, Vector(0,0,0)) 
					end
				end
			end
			for i = 9, 13 do
				self:GetWM():ManipulateBoneScale(i, vector_origin)
			end
		end,
		[0.52] = function( self, timeMul )
			for i = 6, 13 do
				self:GetWM():ManipulateBoneScale(i, vector_full)
			end
		end,
		[0.8] = function( self ) 
		self:GetWM():ManipulateBoneScale(6, vector_origin)
		end,
	}

	function SWEP:ModelCreated(model)
		self:GetWM():ManipulateBoneScale(6, vector_origin)
	end
end



SWEP.WepSelectIcon2 = Material("entities/arc9_eft_rsh12.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/arc9_eft_rsh12.png"

SWEP.weight = 3

SWEP.punchmul = 15
SWEP.punchspeed = 0.2
SWEP.podkid = 4

SWEP.LocalMuzzlePos = Vector(19.5,0.8,3)
SWEP.LocalMuzzleAng = Angle(0.5,-0.02,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)
--
SWEP.weaponInvCategory = 2
SWEP.ShellEject = false
SWEP.ShellEject2 = "EjectBrass_57"
SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 5
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "12.7x55 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 70
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 70
SWEP.Primary.Sound = {"homigrad/weapons/rifle/loud_awp.wav", 80, 90, 100}
SWEP.SupressedSound = {"weapons/tfa_ins2/ak103/ak103_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/revolver/handling/revolver_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.28
SWEP.ReloadTime = 5
SWEP.ReloadSoundes = {
	"none",
	"none",
	"weapons/tfa_ins2/swmodel10/revolver_open_chamber.wav",
	"none",
	"none",
	"weapons/tfa_ins2/thanez_cobra/revolver_dump_rounds_01.wav",
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/thanez_cobra/revolver_speed_loader_insert_01.wav",
	"none",
	"weapons/tfa_ins2/thanez_cobra/revolver_close_chamber.wav",
	"none",
	"none",
	"none",
	"none"
}

function SWEP:PostFireBullet(bullet)
	SlipWeapon(self, bullet)
end

SWEP.PPSMuzzleEffect = "muzzleflash_m79" -- shared in sh_effects.lua

SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}
SWEP.HoldType = "revolver"
SWEP.AimHold = "revolver"
SWEP.ZoomPos = Vector(0, 0.8273, 5.3923)
SWEP.RHandPos = Vector(0, 0, 1)
SWEP.LHandPos = false
SWEP.SprayRand = {Angle(-0.2, -0.2, -0.2), Angle(-0.2, 0.2, -0.2)}
SWEP.AnimShootMul = 4
SWEP.AnimShootHandMul = 2
SWEP.Ergonomics = 1.12
SWEP.OpenBolt = true
SWEP.Penetration = 11
function SWEP:ReloadStartPost()
	if not self or not IsValid(self:GetOwner()) then return end
	hook.Run("HGReloading", self)
end

SWEP.ShockMultiplier = 3

SWEP.ScrappersSlot = "Secondary"

SWEP.CustomShell = "50cal"

function SWEP:ShiftDrum(val)
	val = math.Round(val % 5)
	
	if val == 0 then val = 1 end

	local drumCopy = table.Copy(self.Drum)

	for i = 1,#self.Drum do
		local nextval = i + val
		
		local setval = nextval < 1 and #self.Drum - nextval or nextval > 5 and nextval - 5 or nextval
		
		self.Drum[i] = drumCopy[setval]
	end

	local stringythingy = ""
	for i = 1,#self.Drum do
		stringythingy = stringythingy..tostring(self.Drum[i]).." "
	end
	
	--[[if SERVER then
		net.Start("hg_senddrum")
		net.WriteInt(self:EntIndex(),32)
		net.WriteString(stringythingy)
		net.Broadcast()
	end--]]
	self:SetNWInt("drumroll",self:GetNWInt("drumroll",0) + val)
	self:SetNWString("drum",stringythingy)
end

function SWEP:Step()
	self:CoreStep()
	local owner = self:GetOwner()
	if not IsValid(owner) or not IsValid(self) then return end

end

function SWEP:InitializePost()
	self.Drum = {
		[1] = 1,
		[2] = 1,
		[3] = 1,
		[4] = 1,
		[5] = 1
	}
	self:RevolverPostInit()
end

function SWEP:RevolverPostInit()
	
end

if SERVER then
	concommand.Add("hg_insertbullet",function( ply, cmd, args )
		local val = tonumber(args[1])
		local wep = ply:GetActiveWeapon() 
		if not IsValid(wep) then return end
		local primaryammo = wep:GetPrimaryAmmoType()
		local primaryammocount = ply:GetAmmoCount(primaryammo)

		if not wep.Drum then return end

		wep:AttachAnim()
		if wep.Drum[val] != 0 then
			local value = -(-wep.Drum[val])
			wep.Drum[val] = 0
			wep:SendDrum()
			wep:SetClip1(wep:Clip1() - math.max(value,0))
			ply:SetAmmo(primaryammocount+math.max(value,0),primaryammo)
			ply:EmitSound("weapons/usp_match/usp_match_magout.wav")
			return
		end

		if primaryammocount > 0 then
			wep.Drum[val] = 1
			wep:SendDrum()
			wep:SetClip1(wep:Clip1() + 1)
			ply:SetAmmo(primaryammocount-1,primaryammo)
			ply:EmitSound("weapons/usp_match/usp_match_magin.wav")
			wep.Rolled = false
		end
	end)

	concommand.Add("hg_rolldrum",function(ply, cmd, args)
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep.Drum and (ply.DrumCD or 0) < CurTime() then
			wep:AttachAnim()
			wep:ShiftDrum(math.random(6))
			ply:EmitSound("weapons/357/357_spin1.wav")
			wep.Rolled = true
			ply.DrumCD = CurTime() + 0.5
		end
	end)
end

if SERVER then
	util.AddNetworkString("hg_senddrum")
	
	function SWEP:SendDrum()
		local stringythingy = ""
		for i = 1,#self.Drum do
			stringythingy = stringythingy..tostring(self.Drum[i]).." "
		end
		
		--[[net.Start("hg_senddrum")
		net.WriteInt(self:EntIndex(),32)
		net.WriteString(stringythingy)
		net.Broadcast()--]]
		
		self:SetNWString("drum",stringythingy)
	end
else
	net.Receive("hg_senddrum",function() 
		local self = Entity(net.ReadInt(32))
		local drumtbl = string.Split(net.ReadString()," ")

		for i = 1,#self.Drum do
			self.Drum[i] = tonumber(drumtbl[i])
		end
		self.DrumLastPredicted = CurTime() + 0.5
	end)
end

function SWEP:Unload()
	if CLIENT then return end

	if self.SendDrum then
		for i = 1,#self.Drum do
			self.Drum[i] = 0
		end
		self:SendDrum()
	end
end

function SWEP:GetDrum()
	local drumtbl = string.Split(self:GetNWString("drum","1 1 1 1 1 1")," ")
	
	if (self.DrumLastPredicted or 0) < CurTime() then
		for i = 1,#self.Drum do
			self.Drum[i] = tonumber(drumtbl[i])
		end
	end
	
	return self.Drum
end

function SWEP:SetDrum(drum)
	self.Drum = drum
	self.DrumLastPredicted = CurTime() + 1
end

local phrases = {
	"Didn't fire...",
	"Lucky me...",
	"I thought that was it...",
	"Still not dead...",
	"I knew it wasn't there! I really did!..",
	"FUCK- Thought it would fire...",
	"HELL YEAH!",
	"Luck is on my side!",
}

function SWEP:Shoot(override)
	--self:GetWeaponEntity():ResetSequenceInfo()
	--self:GetWeaponEntity():SetSequence(1)
	if not self:CanPrimaryAttack() then return false end
	if self:KeyDown(IN_USE) and !IsValid(self:GetOwner().FakeRagdoll) then return false end
	if not self:CanUse() then return false end
	if CLIENT and self:GetOwner() != LocalPlayer() and not override then return false end
	local primary = self.Primary

	if primary.Next > CurTime() then return false end
	if (primary.NextFire or 0) > CurTime() then return false end

	self.Drum = SERVER and self.Drum or CLIENT and self:GetDrum()
	
	if self.Drum[1] != 1 then
		self.LastPrimaryDryFire = CurTime()
		self:PrimaryShootEmpty()
		primary.Automatic = false
		self:ShiftDrum(1)
		self.shooanim = 1

		local ply = self:GetOwner()
		if SERVER and IsValid(ply) and ply:IsPlayer() and ply.organism and self.Rolled and self:Clip1() > 0 and ply.suiciding then
			ply.organism.adrenalineAdd = ply.organism.adrenalineAdd + self:Clip1()
			ply.organism.fearadd = ply.organism.fearadd + 0.5
			ply:Notify(phrases[math.random(#phrases)], 1, "suicide", nil, nil, Color(122, 0, 0))
			hg.achievements.AddPlayerAchievement(ply, "deadlygambling", 1)
		end

		return false
	end

	self.Drum[1] = -1
	self:ShiftDrum(1)
	
	primary.Next = CurTime() + primary.Wait
	self:SetLastShootTime(CurTime())
	primary.Automatic = weapons.Get(self:GetClass()).Primary.Automatic
	self:PrimaryShoot()
	self:PrimaryShootPost()
end

function SWEP:InsertAmmo(need)
	local owner = self:GetOwner()
	local primaryAmmo = self:GetPrimaryAmmoType()
	if !owner.GetAmmoCount then self:SetClip1(self:GetMaxClip1()) return end
	
	if SERVER then
		owner:GiveAmmo(self:Clip1(), primaryAmmo, true)
		self:SetClip1(0)
	end

	local primaryAmmoCount = owner:GetAmmoCount(primaryAmmo)
	need = self:GetMaxClip1()
	need = math.min(primaryAmmoCount, need)
	need = math.min(need, self:GetMaxClip1())
	self:SetClip1(need)

	for i = 1, 5 do
		self.Drum[i] = 0
	end

	for i = 1, math.min(need,5) do
		self.Drum[i] = 1
	end
	
	if SERVER then
		self:SendDrum()
	end

	owner:SetAmmo(primaryAmmoCount - need, primaryAmmo)
end

SWEP.WorldPos = Vector(-1, -0.6, -0)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(6,1.57,21.8)
SWEP.attAng = Angle(0,0,0)
SWEP.lengthSub = 25
SWEP.DistSound = "weapons/m40a1/m40a1_dist.wav"
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, -2, -1)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true

SWEP.availableAttachments = {
		barrel = {
		["mount"] = Vector(0.9,-0.1,0.0),
		[1] = {"supressor5", Vector(0,0,0), {}},
	},
	sight = {
		["mountType"] = {"picatinny"},
		["mount"] = {["picatinny"] = Vector(-5.35, 2.1, 0.0)},
		["mountAngle"] = Angle(0,0,0),
	},
	underbarrel = {
		[1] = {"laser5", Vector(0.0,0.4,0.2), {}},

		["mount"] = Vector(12.5, -1.15, -1),
		["mountAngle"] = Angle(0, -1.35, 90),
		["mountType"] = "picatinny_small"
	},
	grip = {
		["mount"] = Vector(10, 0.5, 0.0), 
		["mountType"] = "picatinny"
	}
}

--local to head
SWEP.RHPos = Vector(10,-5,3)
SWEP.RHAng = Angle(0,-5,90)
--local to rh
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)

local finger1 = Angle(-15,0,5)
local finger2 = Angle(-15,45,-5)

function SWEP:AnimHoldPost(model)
	--self:BoneSet("l_finger0", vector_zero, finger1)
	--self:BoneSet("l_finger02", vector_zero, finger2)
end

--RELOAD ANIMS PISTOL

SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(4,1,2),
	Vector(3,0,1),
	Vector(-5,3,-4),
	Vector(-7,1,3),
	Vector(5,2,-2),
	Vector(0,0,0),
	"reloadend",
}
SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,-40),
	Angle(0,0,-50),
	Angle(0,0,-30),
	Angle(-25,35,-20),
	Angle(-35,25,-10),
	Angle(0,0,0),
	Angle(0,0,0),
}

SWEP.ReloadSlideAnim = {
	0,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	0,
	0,
	0
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0)
}
SWEP.ReloadAnimRHAng = {
	Angle(0,0,0)
}
SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-15,5,-25),
	Angle(-15,5,-15),
	Angle(-20,5,5),
	Angle(-12,0,-15),
	Angle(-5,0,-20),
	Angle(0,0,-25),
	Angle(-5,-5,65),
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