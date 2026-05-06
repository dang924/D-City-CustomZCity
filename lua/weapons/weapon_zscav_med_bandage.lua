-- Aseptic Bandage (single use, stops light bleed, 4s)
if SERVER then AddCSLuaFile() end

SWEP.Base       = "weapon_zscav_med_base"
SWEP.PrintName  = "Aseptic Bandage"
SWEP.Category   = "ZScav Meds"
SWEP.Spawnable  = true
SWEP.MedClass   = "weapon_zscav_med_bandage"
SWEP.SlotPos    = 7

-- No dedicated bandage model in eftmeds — reuse the small anaglin pack.
SWEP.ViewModel  = "models/weapons/sweps/eft/anaglin/v_meds_anaglin.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/anaglin/w_meds_anaglin.mdl"

SWEP.SfxDraw    = "ZScavMeds.Bandage.Open"
SWEP.SfxOpen    = "ZScavMeds.Bandage.Open"
SWEP.SfxUse     = "ZScavMeds.Bandage.Use"
SWEP.SfxPutaway = "ZScavMeds.Bandage.End"

if CLIENT then
    SWEP.WepSelectIcon     = surface.GetTextureID("vgui/hud/vgui_bandage")
    SWEP.BounceWeaponIcon  = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.Purpose = [[ZScav medical (target a body part from the Health tab)
Single use. Stops light bleed.]]
