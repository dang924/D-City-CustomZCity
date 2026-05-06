-- IFAK Personal Tactical Kit (300 HP pool, light bleed, 3s)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "IFAK Personal Tactical Kit"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_ifak"
SWEP.SlotPos    = 4

-- No dedicated IFAK model — reuse the AFAK kit shape.
SWEP.ViewModel  = "models/weapons/sweps/eft/afak/v_meds_afak.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/afak/w_meds_afak.mdl"

SWEP.SfxDraw    = "ZScavMeds.Medkit.Draw"
SWEP.SfxOpen    = "ZScavMeds.Medkit.Open"
SWEP.SfxUse     = "ZScavMeds.Medkit.Use"
SWEP.SfxPutaway = "ZScavMeds.Medkit.Putaway"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_ifak")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a body part from the Health tab)
Heals up to 300 HP. Stops light bleed (30 HP/use). Clears contusion.]]
