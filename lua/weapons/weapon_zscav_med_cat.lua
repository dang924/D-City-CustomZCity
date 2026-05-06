-- CAT Tourniquet (12 uses, heavy bleed, 4s, limbs only)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "CAT Tourniquet"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_cat"
SWEP.SlotPos    = 10

SWEP.ViewModel  = "models/weapons/sweps/eft/cat/v_meds_cat.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/cat/w_meds_cat.mdl"

SWEP.SfxDraw    = "ZScavMeds.Cat.Draw"
SWEP.SfxOpen    = "ZScavMeds.Cat.Use"
SWEP.SfxUse     = "ZScavMeds.Cat.Fasten"
SWEP.SfxPutaway = "ZScavMeds.Medkit.Putaway"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_cat")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a limb from the Health tab)
12 uses. Stops heavy bleed on arms / legs.]]
