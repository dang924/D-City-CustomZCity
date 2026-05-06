SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.PrintName = "Milkor MGL"
SWEP.Author = "Milkor (Pty) Ltd"
SWEP.Instructions = "Six-shot Revolver-Type Grenade Launcher Chambered for 40mm Grenades"
SWEP.Category = "Weapons - Grenade Launchers"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/w_m1014.mdl"

SWEP.WepSelectIcon2 = Material("vgui/hud/423gl3")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "vgui/hud/423gl3"

SWEP.ShellEject = false
SWEP.CustomShell = "ags_shell"
SWEP.weight = 4
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 6
SWEP.Primary.DefaultClip = 6
SWEP.Primary.Spread = Vector(0,0,0)
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Grenade 40mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 65
SWEP.Primary.Force = 125
SWEP.UsePhysBullets = true
SWEP.Primary.Sound = {"weapons/m203/m203_tp.wav", 75, 80, 90}
SWEP.SupressedSound = {"weapons/m203/m203_tp.wav", 75, 80, 90}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/fnfal/handling/fnfal_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Wait = 0.2
SWEP.FakeAttachment = "1"
SWEP.OpenBolt = true
SWEP.WorldModelFake = "models/v_models/v_423gl3.mdl" -- МОДЕЛЬ ГОВНА, НАЙТИ НОРМАЛЬНЫЙ КАЛАШ
--PrintBones(Entity(1):GetActiveWeapon():GetWM())
--uncomment for funny
SWEP.FakePos = Vector(-10, 5, 3)
SWEP.FakeAng = Angle(-2, 0, 0)
SWEP.AttachmentPos = Vector(0,-0.0,0)
SWEP.AttachmentAng = Angle(0,0,0)

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.availableAttachments = {
		sight = {
		["mount"] = {picatinny = Vector(-10.5, 2.8, 0.00)},
		["mountType"] = {"picatinny"},
		["empty"] = {
			"empty",
		},
	},
		underbarrel = {
		["mount"] = Vector(-1.5, -2.5, 1.9),
		["mountAngle"] = Angle(0.1, 6, 0),
	},
}
SWEP.StartAtt = {"sightmgl"}

SWEP.FakeEjectBrassATT = "2"
//SWEP.MagIndex = 57
//MagazineSwap
--Entity(1):GetActiveWeapon():GetWM():AddLayeredSequence(Entity(1):GetActiveWeapon():GetWM():LookupSequence("delta_foregrip"),1)
SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.23] = "weapons/m203/handling/m203_openbarrel.wav",
	[0.28] = "weapons/arccw_ur/sw586/extractor1.ogg",
	[0.3] = "weapons/arccw_ur/sw586/rattle.ogg",
	[0.4] = "weapons/m203/handling/m203_deselect.wav",
	[0.47] = "weapons/m203/handling/m203_insertgrenade_01.wav",
	[0.55] = "weapons/m203/handling/m203_deselect.wav",
	[0.57] = "weapons/m203/handling/m203_insertgrenade_01.wav",
	[0.7] = "weapons/m203/handling/m203_deselect.wav",
	[0.72] = "weapons/m203/handling/m203_insertgrenade_02.wav",
	[0.92] = "weapons/m203/handling/m203_closebarrel.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.23] = "weapons/m203/handling/m203_openbarrel.wav",
	[0.28] = "weapons/arccw_ur/sw586/extractor1.ogg",
	[0.3] = "weapons/arccw_ur/sw586/rattle.ogg",
	[0.4] = "weapons/m203/handling/m203_deselect.wav",
	[0.47] = "weapons/m203/handling/m203_insertgrenade_01.wav",
	[0.55] = "weapons/m203/handling/m203_deselect.wav",
	[0.57] = "weapons/m203/handling/m203_insertgrenade_01.wav",
	[0.7] = "weapons/m203/handling/m203_deselect.wav",
	[0.72] = "weapons/m203/handling/m203_insertgrenade_02.wav",
	[0.92] = "weapons/m203/handling/m203_closebarrel.wav",
}

--[[

	["reload"] = {
        Source = "reload",
        TPAnim = ACT_HL2MP_GESTURE_RELOAD_AR2,
        ShellEjectAt = 0.91,
        SoundTable = {
            {s = common .. "cloth_4.ogg", t = 0},
            {s = path .. "open.ogg", t = 0.2},
            {s = path .. "eject.ogg", t = 0.8},
            {s = common .. "magpouch_pull_small.ogg", t = 1.0},
            {s = shellfall, t = 1.0},
            {s = common .. "cloth_2.ogg", t = 1.1},
            {s = path .. "struggle.ogg", t = 1.5, v = 0.5},
            {s = shellin, t = 1.8},
            {s = path .. "grab.ogg", t = 2.15, v = 0.5},
            {s = path .. "close.ogg", t = 2.3},
            {s = common .. "shoulder.ogg", t = 2.4},
            {s = path .. "shoulder.ogg", t = 2.675},
        },
        LHIK = true,
        LHIKIn = 0.5,
        LHIKOut = 0.5,
        MinProgress = 2.05,
    },
    ["reload_empty"] = {
        Source = "reload_empty",
        TPAnim = ACT_HL2MP_GESTURE_RELOAD_AR2,
        ShellEjectAt = 1.0,
        SoundTable = {
            {s = common .. "cloth_4.ogg", t = 0},
            {s = path .. "open.ogg", t = 0.3},
            {s = path .. "eject.ogg", t = 0.8},
            {s = shellfall, t = 0.9},
            {s = shellfall, t = 0.95},
            {s = common .. "cloth_2.ogg", t = 1.1},
            {s = common .. "magpouch_pull_small.ogg", t = 1.2},
            {s = path .. "struggle.ogg", t = 1.7, v = 0.5},
            {s = shellin, t = 1.85},
            {s = shellin, t = 1.9},
            {s = path .. "grab.ogg", t = 2.17, v = 0.5},
            {s = path .. "close.ogg", t = 2.3},
            {s = common .. "shoulder.ogg", t = 2.44},
            {s = path .. "shoulder.ogg", t = 2.6},
        },
        LHIK = true,
        LHIKIn = 0.5,
        LHIKOut = 0.5,
        MinProgress = 2.05,
    },
--]]

SWEP.MagModel = "models/weapons/upgrades/w_magazine_m1a1_30.mdl"

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70

SWEP.AnimList = {
	["idle"] = "idle_raw",
	["reload"] = "reload",
	["reload_empty"] = "reload",
}
if CLIENT then
	local vector_full = Vector(1, 1, 1)
	
	local ang = Angle(-90, 0, 0)
	ang:RotateAroundAxis(ang:Right(), 180)

	SWEP.FakeReloadEvents = {
		[0.33] = function( self, timeMul )
			if CLIENT then
				local owner = self:GetOwner()
				local drum = self:GetDrum()
				for i = 1, #drum do
					if self.CustomShell and drum[i] == -1 then
						local pos, ang = self:GetWM():GetBonePosition(72)
						self:MakeShell(self.CustomShell, pos, ang, Vector(0,0,0)) 
					end
				end
			end
			for i = 71, 83 do
				self:GetWM():ManipulateBoneScale(i, vector_origin)
			end
		end,
		[0.4] = function( self ) 
			for i = 74, 77 do
				self:GetWM():ManipulateBoneScale(i, vector_full)
			end
		end,
		[0.55] = function( self ) 
			for i = 82, 83 do
				self:GetWM():ManipulateBoneScale(i, vector_full)
			end
			for i = 72, 73 do
				self:GetWM():ManipulateBoneScale(i, vector_full)
			end
		end,
		[0.7] = function( self ) 
			for i = 78, 81 do
				self:GetWM():ManipulateBoneScale(i, vector_full)
			end
		end,
		[1.2] = function( self ) 
			if self:Clip1() >= 1 then
				//self:PlayAnim("idle",1,false)
			end
		end,
	}
end
--SWEP.IsPistol = true

SWEP.cameraShakeMul = 0.5

SWEP.LocalMuzzlePos = Vector(15.5,1.12,-0.6)
SWEP.LocalMuzzleAng = Angle(-0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)
function SWEP:PostFireBullet(bullet)
	SlipWeapon(self, bullet)
end

SWEP.punchmul = 1.5
SWEP.punchspeed = 0.5

SWEP.ReloadSound = "weapons/tfa_ins2/doublebarrel/shellinsert1.wav"
SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 1.0877, 3.2894)
SWEP.RHandPos = Vector(-15, -2, 4)
SWEP.LHandPos = false
SWEP.Ergonomics = 0.9
SWEP.Penetration = 0
SWEP.WorldPos = Vector(4, -1, -2)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0.3, 0.0, 0)
SWEP.attAng = Angle(0, 0, 0)
SWEP.lengthSub = 20
SWEP.NoIdleLoop = true
SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(7.5, 9, -0)
SWEP.holsteredAng = Angle(210, 0, 180)
SWEP.ReloadTime = 11.5

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 30
SWEP.Supressor = true
SWEP.SetSupressor = true



--local to head
SWEP.RHPos = Vector(3,-4,3.5)
SWEP.RHAng = Angle(0,0,90)
--local to rh
SWEP.LHPos = Vector(15,-1,-3.3)
SWEP.LHAng = Angle(-110,-90,-90)

local ang1 = Angle(30, -20, 0)
local ang2 = Angle(-10, 50, 0)

function SWEP:AnimationPost()
	self:BoneSet("l_finger0", vector_origin, ang1)
	self:BoneSet("l_finger02", vector_origin, ang2)
end

function SWEP:ReloadStartPost()
	if not self or not IsValid(self:GetOwner()) then return end
	hook.Run("HGReloading", self)
end

function SWEP:ShiftDrum(val)
	val = math.Round(val % 6)
	
	if val == 0 then val = 1 end

	local drumCopy = table.Copy(self.Drum)

	for i = 1,#self.Drum do
		local nextval = i + val
		
		local setval = nextval < 1 and #self.Drum - nextval or nextval > 6 and nextval - 6 or nextval
		
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
		[5] = 1,
		[6] = 1
	}
	self:RevolverPostInit()
	self.attachments.underbarrel = {[1] = "lasertaser0"}
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

local clr_notify = Color(122, 0, 0)
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
		if SERVER and IsValid(ply) and ply:IsPlayer() and ply.organism and self.Rolled and self:Clip1() > 0 and ply.suiciding and ply:GetNWFloat("willsuicide") < CurTime() then
			ply.organism.adrenalineAdd = ply.organism.adrenalineAdd + self:Clip1()
			ply.organism.fearadd = ply.organism.fearadd + 0.5
			ply:Notify(phrases[math.random(#phrases)], 1, "suicide", nil, nil, clr_notify)
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

	for i = 1, 6 do
		self.Drum[i] = 0
	end

	for i = 1, math.min(need,6) do
		self.Drum[i] = 1
	end
	
	if SERVER then
		self:SendDrum()
	end

	owner:SetAmmo(primaryAmmoCount - need, primaryAmmo)
end

function SWEP:PrimaryShootPost()
	if CLIENT then
		if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(73, vector_origin)
		end
	end
end




-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-2,-5,-5),
	Vector(-2,-5,-5),
	Vector(-2,-5,-12),
	Vector(-2,-4,-8),
	Vector(-2,1,-7),
	Vector(-2,1,-7),
	Vector(-2,1,-5),
	Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0)
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(0,0,180),
	Angle(0,0,180),
	Angle(0,0,180),
	Angle(0,0,180),
	Angle(0,0,180),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(2,5,0),
	Angle(2,5,0),
	Angle(5,10,0),
	Angle(5,10,0),
	--Angle(0,0,0)
}

function SWEP:GetAnimPos_Insert(time)
	return 0
end

function SWEP:GetAnimPos_Draw(time)
	return 0
end

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
	Angle(-5,15,5),
	Angle(-5,15,15),
	Angle(-5,14,16),
	Angle(-7,16,18),
	Angle(-7,14,20),
	Angle(-6,15,-15),
	Angle(-2,12,-15),
	Angle(0,15,-22),
	Angle(0,14,-45),
	Angle(0,12,-45),
	Angle(0,10,-35),
	Angle(0,0,0)
}