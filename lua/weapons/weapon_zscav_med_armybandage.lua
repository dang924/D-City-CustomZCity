-- Army Bandage (400 HP pool, +5 instant, light bleed, 6s)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "Army Bandage"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_armybandage"
SWEP.SlotPos    = 8

SWEP.ViewModel  = "models/weapons/sweps/eft/anaglin/v_meds_anaglin.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/anaglin/w_meds_anaglin.mdl"

SWEP.SfxDraw    = "ZScavMeds.Bandage.Open"
SWEP.SfxOpen    = "ZScavMeds.Bandage.Open"
SWEP.SfxUse     = "ZScavMeds.Bandage.Use"
SWEP.SfxPutaway = "ZScavMeds.Bandage.End"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_armybandage")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a body part from the Health tab)
400 HP pool (+5 instant). Stops light bleed (50 HP/use).]]
