-- Salewa First Aid Kit (400 HP pool, +85 instant, light bleed, 3s)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "Salewa First Aid Kit"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_salewa"
SWEP.SlotPos    = 3

SWEP.ViewModel  = "models/weapons/sweps/eft/salewa/v_meds_salewa.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/salewa/w_meds_salewa.mdl"

SWEP.SfxDraw    = "ZScavMeds.Medkit.Draw"
SWEP.SfxOpen    = "ZScavMeds.Salewa.Open"
SWEP.SfxUse     = "ZScavMeds.Salewa.Use"
SWEP.SfxPutaway = "ZScavMeds.Medkit.Putaway"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_salewa")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a body part from the Health tab)
Heals up to 400 HP (+85 instant). Stops light bleed (45 HP/use).]]
