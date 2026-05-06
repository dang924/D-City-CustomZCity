-- CMS Surgical Kit (260 HP pool, restores blacked-out limb, 16s, limbs + stomach)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "CMS Surgical Kit"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_surgicalkit"
SWEP.SlotPos    = 12

SWEP.ViewModel  = "models/weapons/sweps/eft/surgicalkit/v_meds_surgicalkit.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/surgicalkit/w_meds_surgicalkit.mdl"

SWEP.SfxDraw    = "ZScavMeds.Surgical.Draw"
SWEP.SfxOpen    = "ZScavMeds.Surgical.Use"
SWEP.SfxUse     = "ZScavMeds.Surgical.Use"
SWEP.SfxPutaway = "ZScavMeds.Surgical.Close"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_surgicalkit")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a damaged limb from the Health tab)
260 HP pool. Revives a blacked-out limb (introduces a light bleed).]]
