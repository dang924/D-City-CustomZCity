-- Grizzly Medical Kit (1800 HP pool, light + heavy bleed, fracture, 4.5s)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "Grizzly Medical Kit"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_grizzly"
SWEP.SlotPos    = 6

SWEP.ViewModel  = "models/weapons/sweps/eft/grizzly/v_meds_grizzly.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/grizzly/w_meds_grizzly.mdl"

SWEP.SfxDraw    = "ZScavMeds.Grizzly.Draw"
SWEP.SfxOpen    = "ZScavMeds.Grizzly.Open"
SWEP.SfxUse     = "ZScavMeds.Grizzly.Take"
SWEP.SfxPutaway = "ZScavMeds.Medkit.Putaway"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_grizzly")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a body part from the Health tab)
Heals up to 1800 HP. Stops light + heavy bleed, fixes fracture, clears
contusion + pain.]]
