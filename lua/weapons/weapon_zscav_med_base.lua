-- ZScav Meds shared SWEP base. NOT spawnable on its own — child SWEPs
-- (weapon_zscav_med_ai2, _grizzly, _cat, etc.) use SWEP.Base = "weapon_zscav_med_base".
--
-- This file is loaded as a regular SWEP via lua/weapons/, so GMod registers
-- it with weapons.Register("weapon_zscav_med_base"). Children inherit by
-- name, which is the canonical Garry's Mod pattern (matches how
-- weapon_thiamine / weapon_splint inherit from weapon_bandage_sh).

if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_base"

SWEP.PrintName        = "ZScav Med (base)"
SWEP.Author           = "ZScavMeds"
SWEP.Category         = "ZScav Meds"
SWEP.Spawnable        = false   -- base only — children flip this to true
SWEP.AdminSpawnable   = false
SWEP.UseHands         = true
SWEP.DrawCrosshair    = false
SWEP.SwayScale        = 0.15
SWEP.BobScale         = 0.75

SWEP.ViewModelFOV     = 85
SWEP.HoldType         = "slam"

-- Default model — children should override.
SWEP.ViewModel        = "models/weapons/sweps/eft/medkit/v_meds_medkit.mdl"
SWEP.WorldModel       = "models/weapons/sweps/eft/medkit/w_meds_medkit.mdl"

SWEP.Slot             = 5
SWEP.SlotPos          = 7

SWEP.Primary = {
    ClipSize    = -1,
    DefaultClip = -1,
    Automatic   = false,
    Ammo        = "none",
}
SWEP.Secondary = {
    ClipSize    = -1,
    DefaultClip = -1,
    Automatic   = false,
    Ammo        = "none",
}

-- Sounds — children override per-item.
SWEP.SfxDraw      = "ZScavMeds.Medkit.Draw"
SWEP.SfxOpen      = "ZScavMeds.Medkit.Open"
SWEP.SfxUse       = "ZScavMeds.Medkit.Use"
SWEP.SfxPutaway   = "ZScavMeds.Medkit.Putaway"

-- World-model hand attachment. Children may override the offset/bone.
SWEP.WorldOffsetVec = Vector(3, -7, 5)
SWEP.WorldOffsetAng = Angle(0, 0, -180)
SWEP.WorldBone      = "ValveBiped.Bip01_R_Hand"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType or "slam")
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_IDLE)
    if self.SfxDraw and IsValid(self:GetOwner()) then
        self:GetOwner():EmitSound(self.SfxDraw)
    end
    return true
end

function SWEP:Holster()
    if self.SfxPutaway and IsValid(self:GetOwner()) then
        self:GetOwner():EmitSound(self.SfxPutaway)
    end
    return true
end

-- The "real" use action lives on the ZScav health tab (drag-drop) or hotbar
-- (bound key). PrimaryAttack just nudges the player toward the right UI so
-- they don't think the SWEP is broken. Spamming a med without selecting a
-- body part would be a balance problem, so no whole-body fallback heal.
local NEXT_ATTACK_DELAY = 1.0

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:SetNextPrimaryFire(CurTime() + NEXT_ATTACK_DELAY)
    self:SetNextSecondaryFire(CurTime() + NEXT_ATTACK_DELAY)

    if SERVER then
        if owner.zChatPrint then
            owner:zChatPrint("Open Inventory → Health tab to apply " .. (self.PrintName or "this item") .. " to a body part.")
        elseif owner.ChatPrint then
            owner:ChatPrint("Open Inventory → Health tab to apply " .. (self.PrintName or "this item") .. " to a body part.")
        end
    end

    if self.SfxOpen then owner:EmitSound(self.SfxOpen) end
    self:SendWeaponAnim(ACT_VM_PULLBACK_HIGH)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:Think() end

if CLIENT then
    function SWEP:PostDrawViewModel(vm)
        local attachment = vm:GetAttachment(1)
        if attachment then
            self.vmcamera = vm:GetAngles() - attachment.Ang
        else
            self.vmcamera = Angle(0, 0, 0)
        end
    end

    function SWEP:CalcView(ply, pos, ang, fov)
        self.vmcamera = self.vmcamera or Angle(0, 0, 0)
        return pos, ang + self.vmcamera, fov
    end

    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()

        if not IsValid(owner) then
            self:DrawModel()
            return
        end

        if not self._wm then
            self._wm = ClientsideModel(self.WorldModel or "")
            if IsValid(self._wm) then
                self._wm:SetSkin(0)
                self._wm:SetNoDraw(true)
            end
        end

        if not IsValid(self._wm) then
            self:DrawModel()
            return
        end

        local boneid = owner:LookupBone(self.WorldBone or "ValveBiped.Bip01_R_Hand")
        if not boneid then return end

        local matrix = owner:GetBoneMatrix(boneid)
        if not matrix then return end

        local newPos, newAng = LocalToWorld(
            self.WorldOffsetVec or Vector(0, 0, 0),
            self.WorldOffsetAng or Angle(0, 0, 0),
            matrix:GetTranslation(),
            matrix:GetAngles()
        )

        self._wm:SetPos(newPos)
        self._wm:SetAngles(newAng)
        self._wm:SetupBones()
        self._wm:DrawModel()
    end

    function SWEP:OnRemove()
        if IsValid(self._wm) then self._wm:Remove() end
    end
end
