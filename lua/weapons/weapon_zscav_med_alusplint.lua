-- Aluminium Splint (8 uses, fixes fracture, 16s, limbs only)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "Aluminium Splint"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_alusplint"
SWEP.SlotPos    = 11

SWEP.ViewModel  = "models/weapons/sweps/eft/alusplint/v_meds_alusplint.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/alusplint/w_meds_alusplint.mdl"

SWEP.SfxDraw    = "ZScavMeds.Splint.Start"
SWEP.SfxOpen    = "ZScavMeds.Splint.Middle"
SWEP.SfxUse     = "ZScavMeds.Splint.Middle"
SWEP.SfxPutaway = "ZScavMeds.Splint.End"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_alusplint")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a limb from the Health tab)
8 uses. Fixes fractures on arms / legs.]]
