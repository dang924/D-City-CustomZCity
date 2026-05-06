SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Maxim 9"
SWEP.Author = "SilencerCo"
SWEP.Instructions = "The SilencerCo Maxim 9 is the world's first integrally suppressed 9mm handgun that is holster-able and hearing safe with all 9mm ammunition. It is incredibly flat-shooting due to its front-heavy design."
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_pist_glock18.mdl"
SWEP.WorldModelFake = "models/weapons/v_maxim9.mdl"

SWEP.FakePos = Vector(-18, 2.6, -2)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(1000,1000,1000) -- сорри мне лень
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeAttachment = "1"
SWEP.FakeBodyGroups = "0000"
SWEP.FakeBodyGroupsPresets = {
    "0000",
    "1000",
    "0001",
    "1001",
    "0006",
    "1006",
}

SWEP.FakeEjectBrassATT = "2"

SWEP.FakeVPShouldUseHand = true
SWEP.stupidgun = true
SWEP.CantFireFromCollision = true

SWEP.AnimList = {
    ["idle"] = "idle",
    ["reload"] = "reload",
    ["reload_empty"] = "reload_empty",
}

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 40

SWEP.FakeReloadSounds = {
    [0.17] = "weapons/universal/uni_pistol_draw_01.wav",
    [0.22] = "weapons/tfa_ins2/usp_tactical/magrelease.wav",
    [0.3] = "weapons/tfa_ins2/usp_tactical/magout.wav",
    [0.45] = "weapons/universal/uni_crawl_l_03.wav",
    [0.7] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
    [0.8] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
}

SWEP.FakeEmptyReloadSounds = {
    [0.16] = "weapons/universal/uni_crawl_l_03.wav",
    [0.22] = "weapons/tfa_ins2/usp_tactical/magrelease.wav",
    [0.3] = "weapons/tfa_ins2/usp_tactical/magout.wav",
    [0.37] = "weapons/universal/uni_pistol_draw_01.wav",
    [0.6] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
    [0.65] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
    [0.85] = "weapons/m45/m45_boltrelease.wav",
}

SWEP.lmagpos = Vector(1.8,0,-0.3)
SWEP.lmagang = Angle(-10,0,0)
SWEP.lmagpos2 = Vector(0,3.5,0.3)
SWEP.lmagang2 = Angle(0,0,-110)

SWEP.GunCamPos = Vector(2.2,-17,-3)
SWEP.GunCamAng = Angle(180,0,-90)

SWEP.MagModel = "models/weapons/zcity/w_glockmag.mdl"

if CLIENT then
    local vector_full = Vector(1, 1, 1)
    SWEP.FakeReloadEvents = {
        [0.15] = function( self, timeMul )
            if self:Clip1() < 1 then
                self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 1.5 * timeMul)
            else
                local wm = self:GetWM()
                if IsValid(wm) then
                    local mag = wm:LookupBone("def_c_mag")
                    local bullet = wm:LookupBone("def_c_mag_bullet")
                    if mag then wm:ManipulateBoneScale(mag, vector_origin) end
                    if bullet then wm:ManipulateBoneScale(bullet, vector_full) end
                end
                self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 0.5 * timeMul)
            end
        end,
        [0.3] = function( self )
            local wm = self:GetWM()
            local mag = IsValid(wm) and wm:LookupBone("def_c_mag") or nil
            
            if self:Clip1() < 1 then
                hg.CreateMag( self, Vector(0,55,-55) )
                if mag then wm:ManipulateBoneScale(mag, vector_origin) end
            else
                if mag then wm:ManipulateBoneScale(mag, vector_full) end
            end
        end,
        [0.45] = function( self )
            if self:Clip1() < 1 then
                local wm = self:GetWM()
                local mag = IsValid(wm) and wm:LookupBone("def_c_mag") or nil
                if mag then wm:ManipulateBoneScale(mag, vector_full) end
            end
        end,
        [0.9] = function( self, timeMul )
            if self:Clip1() >= 1 then
                local wm = self:GetWM()
                local bullet = IsValid(wm) and wm:LookupBone("def_c_mag_bullet") or nil
                if bullet then wm:ManipulateBoneScale(bullet, vector_origin) end
                self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 0.5 * timeMul)
            end
        end
    }
end

SWEP.FakeMagDropBone = "def_c_mag"

SWEP.WepSelectIcon2 = Material("vgui/hud/tfa_ins2_glock_p80.png")
SWEP.IconOverride = "entities/weapon_pwb_glock17.png"

SWEP.CustomShell = "9x19"

SWEP.weight = 1.1 
SWEP.ScrappersSlot = "Secondary"
SWEP.weaponInvCategory = 2
SWEP.ShellEject = "EjectBrass_9mm"

SWEP.Primary.ClipSize = 17
SWEP.Primary.DefaultClip = 17
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "9x19 mm Parabellum"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 28 

SWEP.DoMuzzleFlash = false 
SWEP.MuzzleFlash = false   
SWEP.Supressor = true      
SWEP.SetSupressor = true   
SWEP.Primary.Sound = {"zcitysnd/sound/weapons/m45/m45_suppressed_fp.wav", 65, 90, 100}
SWEP.SupressedSound = {"zcitysnd/sound/weapons/m45/m45_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/makarov/handling/makarov_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.DistSound = "none"    

SWEP.Primary.Force = 25
SWEP.Primary.Wait = PISTOLS_WAIT

SWEP.ReloadTime = 3.6      
SWEP.ReloadEmptyTime = 2.7 

SWEP.ReloadSoundes = {
    "none", "none",
    "pwb/weapons/fnp45/clipout.wav",
    "none", "none", "none",
    "pwb/weapons/fnp45/clipin.wav",
    "pwb/weapons/fnp45/sliderelease.wav",
    "none", "none", "none", "none"
}
SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}
SWEP.HoldType = "revolver"

SWEP.ZoomPos = Vector(-26, 0.0178, 1.6966)
SWEP.RHandPos = Vector(-4, 0, -3)
SWEP.LHandPos = false
SWEP.SprayRand = {Angle(-0.03, -0.03, 0), Angle(-0.05, 0.03, 0)}

SWEP.Ergonomics = 2
SWEP.Penetration = 8

SWEP.punchmul = 1.1 
SWEP.punchspeed = 3

SWEP.WorldPos = Vector(2.9, -1.2, -2.8)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, -0, 6.5)
SWEP.attAng = Angle(0, -0.2, 0)
SWEP.lengthSub = 25

SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, -2, 1)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true

--local to head
SWEP.RHPos = Vector(12,-4.5,3)
SWEP.RHAng = Angle(0,-5,90)
--local to rh
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)

SWEP.ShootAnimMul = 3
SWEP.SightSlideOffset = 1.2


function SWEP:DrawPost()
    local wep = self:GetWeaponEntity()
    if CLIENT and IsValid(wep) then
        
        self.shooanim = LerpFT(0.4, self.shooanim or 0, 0)
        
        local bolt = wep:LookupBone("def_c_bolt")
        if bolt then
            
            wep:ManipulateBonePosition(bolt, Vector(0, -1.5 * self.shooanim, 0), false)
        end
    end
end

function SWEP:PostSetupDataTables()
    self:NetworkVar("Int",0,"GlockSkin")
    self:NetworkVar("String",1,"RandomBodygroups")
    if ( CLIENT ) then
        self:NetworkVarNotify( "GlockSkin", self.OnVarChanged2 )
        self:NetworkVarNotify( "RandomBodygroups", self.OnVarChanged )
    end
end

function SWEP:OnVarChanged( name, old, new )
    if !IsValid(self:GetWM()) then return end
    self:GetWM():SetBodyGroups(new)
end

function SWEP:OnVarChanged2( name, old, new )
    if !IsValid(self:GetWM()) then return end
    self:GetWM():SetSkin(new)
end

function SWEP:InitializePost()
    local Skin = math.random(0,2)
    if math.random(0,100) > 99 then
        Skin = 3
    end
    self:SetGlockSkin(Skin)
    self:SetRandomBodygroups(self.FakeBodyGroupsPresets[math.random(#self.FakeBodyGroupsPresets)] or "0000")
end

function SWEP:ModelCreated(model)
    local bullet = model:LookupBone("def_c_mag_bullet")
    if bullet then 
        model:ManipulateBoneScale(bullet, vector_origin) 
    end
    model:SetBodyGroups(self:GetRandomBodygroups() or "00000")
    model:SetSkin(self:GetGlockSkin())
end

SWEP.LocalMuzzlePos = Vector(6.5,0,-0.023)
SWEP.LocalMuzzleAng = Angle(0.2,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

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