-- Car First Aid Kit (220 HP pool, light bleed, 4s)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "Car First Aid Kit"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_car"
SWEP.SlotPos    = 2

-- No dedicated Car model in eftmeds — reuse the salewa kit shape.
SWEP.ViewModel  = "models/weapons/sweps/eft/salewa/v_meds_salewa.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/salewa/w_meds_salewa.mdl"

SWEP.SfxDraw    = "ZScavMeds.Medkit.Draw"
SWEP.SfxOpen    = "ZScavMeds.Salewa.Open"
SWEP.SfxUse     = "ZScavMeds.Salewa.Use"
SWEP.SfxPutaway = "ZScavMeds.Medkit.Putaway"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_carmedkit")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a body part from the Health tab)
Heals up to 220 HP. Stops light bleed (50 HP/use).]]
