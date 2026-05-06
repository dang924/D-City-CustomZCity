-- AFAK Tactical Trauma Kit (400 HP pool, light + heavy bleed, 4s)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "AFAK Tactical Trauma Kit"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_afak"
SWEP.SlotPos    = 5

SWEP.ViewModel  = "models/weapons/sweps/eft/afak/v_meds_afak.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/afak/w_meds_afak.mdl"

SWEP.SfxDraw    = "ZScavMeds.Medkit.Draw"
SWEP.SfxOpen    = "ZScavMeds.Medkit.Open"
SWEP.SfxUse     = "ZScavMeds.Medkit.Use"
SWEP.SfxPutaway = "ZScavMeds.Medkit.Putaway"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_afak")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a body part from the Health tab)
Heals up to 400 HP. Stops light bleed (30 HP) + heavy bleed (170 HP).]]
