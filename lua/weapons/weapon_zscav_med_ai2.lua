-- AI-2 Medkit (100 HP pool, no statuses, 2s)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "AI-2 Medkit"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_ai2"
SWEP.SlotPos    = 1

-- automedkit IS the EFT AI-2 model — exact match.
SWEP.ViewModel  = "models/weapons/sweps/eft/automedkit/v_meds_automedkit.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/automedkit/w_meds_automedkit.mdl"

SWEP.SfxDraw    = "ZScavMeds.Medkit.Draw"
SWEP.SfxOpen    = "ZScavMeds.Medkit.Open"
SWEP.SfxUse     = "ZScavMeds.Medkit.Use"
SWEP.SfxPutaway = "ZScavMeds.Medkit.Putaway"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_eft_aii")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a body part from the Health tab)
Heals up to 100 HP.]]
