SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Five-seveN"
SWEP.Author = "FN Herstal"
SWEP.Instructions = "The FN Five-seveN is a semi-automatic pistol designed and manufactured by FN Herstal in Belgium. Chambered for the 5.7×28mm ammunition."
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_pist_glock18.mdl"
SWEP.WorldModelFake = "models/weapons/fml/c_57.mdl"

SWEP.FakePos = Vector(-16, 1.7, 2.3)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(12,-1,1.6)
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
    ["reload"] = "ACT_VM_RELOAD",
    ["reload_empty"] = "ACT_VM_RELOAD_EMPTY",
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
    local vector_zero = Vector(0.001, 0.001, 0.001)
    
    SWEP.FakeReloadEvents = {
        [0.15] = function( self, timeMul )
            if self:Clip1() < 1 then
                self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 1.5 * timeMul)
            else
                local wm = self:GetWM()
                if IsValid(wm) then
                    local mag = wm:LookupBone("Magazine")
                    local bullet = wm:LookupBone("Bullet")
                    if mag then wm:ManipulateBoneScale(mag, vector_zero) end
                    if bullet then wm:ManipulateBoneScale(bullet, vector_full) end
                end
                self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 0.5 * timeMul)
            end
        end,
        [0.3] = function( self )
            local wm = self:GetWM()
            local mag = IsValid(wm) and wm:LookupBone("Magazine") or nil
            
            if self:Clip1() < 1 then
                hg.CreateMag( self, Vector(0,55,-55) )
                if mag then wm:ManipulateBoneScale(mag, vector_zero) end
            else
                if mag then wm:ManipulateBoneScale(mag, vector_full) end
            end
        end,
        [0.45] = function( self )
            if self:Clip1() < 1 then
                local wm = self:GetWM()
                local mag = IsValid(wm) and wm:LookupBone("Magazine") or nil
                if mag then wm:ManipulateBoneScale(mag, vector_full) end
            end
        end,
        [0.9] = function( self, timeMul )
            if self:Clip1() >= 1 then
                local wm = self:GetWM()
                local bullet = IsValid(wm) and wm:LookupBone("Bullet") or nil
                if bullet then wm:ManipulateBoneScale(bullet, vector_zero) end
                self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 0.5 * timeMul)
            end
        end
    }
end


SWEP.FakeMagDropBone = "Magazine"

SWEP.WepSelectIcon2 = Material("entities/fiveseven.png")
SWEP.IconOverride = "materials/entities/fiveseven.png"

SWEP.CustomShell = "9x19"

SWEP.weight = 1

SWEP.ScrappersSlot = "Secondary"

SWEP.weaponInvCategory = 2
SWEP.ShellEject = "EjectBrass_9mm"
SWEP.Primary.ClipSize = 20
SWEP.Primary.DefaultClip = 20
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "5.7x28 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 25
SWEP.Primary.Sound = {"sound/weapons/bo57/fire.wav", 75, 90, 100}
SWEP.SupressedSound = {"zcitysnd/sound/weapons/m45/m45_suppressed_fp.wav", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/makarov/handling/makarov_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Force = 25
SWEP.Primary.Wait = PISTOLS_WAIT
SWEP.ReloadTime = 4.2
SWEP.ReloadSoundes = {
    "none", "none", "pwb/weapons/fnp45/clipout.wav",
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
SWEP.Ergonomics = 1.2
SWEP.Penetration = 7

SWEP.punchmul = 1.5
SWEP.punchspeed = 3
SWEP.WorldPos = Vector(2.9, -1.2, -2.8)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, -0, 6.5)
SWEP.attAng = Angle(0, -0.2, 0)
SWEP.lengthSub = 25
SWEP.DistSound = "m9/m9_dist.wav"
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, -2, 1)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true
--SWEP.availableAttachments = {
   -- barrel = {
     --   [1] = {"supressor4", Vector(0,0,0), {}},
       -- [2] = {"supressor6", Vector(4.2,0,0), {}},
        --[--"mount"] = Vector(-0.5,1.5,0),
    --},
  --  magwell = {
--
--        [1] = {"mag1",Vector(-6.3,-2.2,0), {}},
  --  },
   -- sight = {
    --    ["mountType"] = {"picatinny","pistolmount"},
      --  ["mount"] = {["picatinny"] = Vector(-3.1, 2.15, 0), ["pistolmount"] = Vector(-6.2, .5, 0.025)},
        --["mountAngle"] = Angle(0,0,0),
 --   },
  --  underbarrel = {
    --    ["mount"] = Vector(12.5, -0.35, -1),
      --  ["mountAngle"] = Angle(0, -0.6, 90),
   --     ["mountType"] = "picatinny_small"
--    },
--    mount = {
--        ["picatinny"] = {
 --           "mount4",
---            Vector(-1.5, -.1, 0),
 --           {},
 --           ["mountType"] = "picatinny",
 --       }
 --   },
--    grip = {
--        ["mount"] = Vector(15, 1.2, 0.1), 
 --       ["mountType"] = "picatinny"
  --  }
--}

SWEP.RHPos = Vector(12,-4.5,3)
SWEP.RHAng = Angle(0,-5,90)
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)

SWEP.ShootAnimMul = 3
SWEP.SightSlideOffset = 1.2


function SWEP:DrawPost()
    local wep = self:GetWeaponEntity()
    if CLIENT and IsValid(wep) then
        
        self.shooanim = LerpFT(0.4, self.shooanim or 0, ((self:Clip1() > 0 or self.reload) and 0) or 1.8)
        
        local slide = wep:LookupBone("Slide")
        if slide then
            wep:ManipulateBonePosition(slide, Vector(0, 1.5 * self.shooanim, 0), false)
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
    local bullet = model:LookupBone("Bullet")
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
    Angle(0,0,0), Angle(4,4,15), Angle(10,15,25),
    Angle(10,15,25), Angle(10,15,25), Angle(-6,-15,-15),
    Angle(1,15,-45), Angle(15,25,-55), Angle(15,25,-55),
    Angle(15,25,-55), Angle(0,0,0), Angle(0,0,0)
}