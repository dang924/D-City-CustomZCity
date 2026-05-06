-- Esmarch Tourniquet (8 uses, heavy bleed, 4s, limbs only)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "Esmarch Tourniquet"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_esmarch"
SWEP.SlotPos    = 9

SWEP.ViewModel  = "models/weapons/sweps/eft/esmarch/v_meds_esmarch.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/esmarch/w_meds_esmarch.mdl"

SWEP.SfxDraw    = "ZScavMeds.Cat.Draw"
SWEP.SfxOpen    = "ZScavMeds.Cat.Use"
SWEP.SfxUse     = "ZScavMeds.Cat.Fasten"
SWEP.SfxPutaway = "ZScavMeds.Medkit.Putaway"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_esmarch")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a limb from the Health tab)
8 uses. Stops heavy bleed on arms / legs.]]
