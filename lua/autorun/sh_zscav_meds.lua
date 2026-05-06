-- ZScav meds shared autorun (testing-branch native).
--
-- This file fills the ZScav "medical" weapon slot and routes the ZScav
-- health-tab + hotbar to a server-side healing handler. It is part of the
-- ZCity testing branch tree, not a standalone addon.
--
-- Related files in this same branch:
--   gamemodes/zcity/gamemode/modes/zscav/sh_zscav_meds_catalog.lua
--     Item meta (sizes, weights, medical profile) + canonical EFT healing
--     data table at ZSCAV.MedicalEFT.
--   gamemodes/zcity/gamemode/modes/zscav/sv_zscav.lua
--     Patched: medical-quickslot stub now fires ZSCAV_UseMedicalQuickslot.
--   lua/weapons/weapon_zscav_med_base.lua
--     Non-spawnable base SWEP. Children inherit via SWEP.Base = "weapon_zscav_med_base".
--   lua/zscav_meds/sv_handler.lua
--     ApplyMedical pipeline + body-part picker + both hooks.
--   lua/weapons/weapon_zscav_med_*.lua
--     12 SWEP files, one per EFT-style item.
--
-- Content (models / materials / sounds) is provided by the existing
-- "eftmeds" workshop addon. See lua/zscav_meds/MEDS_README.md for details.
--
-- This file:
--   * Registers ammo types so each SWEP can carry a pool/use counter even
--     when used standalone (outside ZScav).
--   * Defines sound aliases used by the SWEPs.  We deliberately name them
--     "ZScavMeds.*" so we don't fight the existing eftmeds addon's sounds
--     even though they target the same .wav files.
--   * Adds shared helpers used by both the SWEP code and the server hook.

AddCSLuaFile()

ZScavMeds = ZScavMeds or {}
ZScavMeds.Version = "0.2.0"

-- ---------------------------------------------------------------------
-- Ammo types
-- ---------------------------------------------------------------------
local AMMO_TYPES = {
    "zscav_med_ai2",
    "zscav_med_car",
    "zscav_med_salewa",
    "zscav_med_ifak",
    "zscav_med_afak",
    "zscav_med_grizzly",
    "zscav_med_bandage",
    "zscav_med_armybandage",
    "zscav_med_esmarch",
    "zscav_med_cat",
    "zscav_med_alusplint",
    "zscav_med_surgicalkit",
}

for _, name in ipairs(AMMO_TYPES) do
    game.AddAmmoType({ name = name })
end

-- ---------------------------------------------------------------------
-- Sound aliases. We re-use the eftmeds workshop addon's .wav assets but
-- register under our own keys so the SWEPs don't depend on that addon's
-- load order.
-- ---------------------------------------------------------------------
local function addSnd(name, file_path, level)
    sound.Add({
        name    = name,
        channel = CHAN_WEAPON,
        volume  = 1.0,
        level   = level or 65,
        pitch   = { 95, 115 },
        sound   = file_path,
    })
end

-- Medkit / bandage shared sounds
addSnd("ZScavMeds.Medkit.Draw",     "weapons/eft/medkit/item_medkit_ai_00_draw.wav")
addSnd("ZScavMeds.Medkit.Open",     "weapons/eft/medkit/item_medkit_ai_01_open.wav")
addSnd("ZScavMeds.Medkit.Use",      "weapons/eft/medkit/item_medkit_ai_04_injection.wav")
addSnd("ZScavMeds.Medkit.Putaway",  "weapons/eft/medkit/item_medkit_ai_06_putaway.wav")

addSnd("ZScavMeds.Bandage.Open",    "weapons/eft/bandage/item_bandage_01_open.wav")
addSnd("ZScavMeds.Bandage.Use",     "weapons/eft/bandage/item_bandage_03_use.wav")
addSnd("ZScavMeds.Bandage.End",     "weapons/eft/bandage/item_bandage_04_end.wav")

addSnd("ZScavMeds.Salewa.Open",     "weapons/eft/salewa/item_medkit_salewa_01_open.wav")
addSnd("ZScavMeds.Salewa.Use",      "weapons/eft/salewa/item_medkit_salewa_03_use.wav")
addSnd("ZScavMeds.Salewa.End",      "weapons/eft/salewa/item_medkit_salewa_04_end.wav")

addSnd("ZScavMeds.Grizzly.Draw",    "weapons/eft/grizzly/item_medkit_grizzly_00_draw.wav")
addSnd("ZScavMeds.Grizzly.Open",    "weapons/eft/grizzly/item_medkit_grizzly_01_open.wav")
addSnd("ZScavMeds.Grizzly.Take",    "weapons/eft/grizzly/item_medkit_grizzly_02_medtake.wav")

addSnd("ZScavMeds.Cat.Draw",        "weapons/eft/cat/item_cat_00_draw.wav")
addSnd("ZScavMeds.Cat.Use",         "weapons/eft/cat/item_cat_01_use.wav")
addSnd("ZScavMeds.Cat.Fasten",      "weapons/eft/cat/item_cat_02_fasten.wav")

addSnd("ZScavMeds.Splint.Start",    "weapons/eft/splint/item_splint_00_start.wav")
addSnd("ZScavMeds.Splint.Middle",   "weapons/eft/splint/item_splint_01_middle.wav")
addSnd("ZScavMeds.Splint.End",      "weapons/eft/splint/item_splint_02_end.wav")

addSnd("ZScavMeds.Surgical.Draw",   "weapons/eft/surgicalkit/item_surgicalkit_00_draw.wav")
addSnd("ZScavMeds.Surgical.Use",    "weapons/eft/surgicalkit/item_surgicalkit_08_stapler_use.wav")
addSnd("ZScavMeds.Surgical.Close",  "weapons/eft/surgicalkit/item_surgicalkit_10_close.wav")

-- ---------------------------------------------------------------------
-- Shared helpers (read by the SWEPs and the server hook handler).
-- ---------------------------------------------------------------------

-- Lookup an EFT data row for a given SWEP class. Returns nil outside ZScav
-- (when the gamemode catalog hasn't loaded), so callers must handle that.
function ZScavMeds.GetData(class)
    if not (ZSCAV and ZSCAV.GetMedicalEFTData) then return nil end
    return ZSCAV:GetMedicalEFTData(class)
end

-- Initial pool/use count for a freshly spawned item.
function ZScavMeds.GetInitialCharge(class)
    local row = ZScavMeds.GetData(class)
    if not row then return 1 end
    if row.pool_hp then return row.pool_hp end
    if row.uses    then return row.uses    end
    if row.single_use then return 1 end
    return 1
end

-- Pretty status label list for tooltips (e.g. "stops light bleed,
-- stops heavy bleed, fixes fracture").
function ZScavMeds.DescribeTreats(treats)
    if not istable(treats) then return "" end

    local parts = {}
    if treats.light_bleed then parts[#parts + 1] = "stops light bleed" end
    if treats.heavy_bleed then parts[#parts + 1] = "stops heavy bleed" end
    if treats.fracture    then parts[#parts + 1] = "fixes fracture"    end
    if treats.contusion   then parts[#parts + 1] = "clears contusion"  end
    if treats.pain        then parts[#parts + 1] = "kills pain"        end
    if treats.restore_blacked then parts[#parts + 1] = "revives blacked-out limb" end

    return table.concat(parts, ", ")
end

-- The SWEP base is now a normal GMod base SWEP at
-- lua/weapons/weapon_zscav_med_base.lua and gets auto-loaded by the
-- weapon system. Children inherit via SWEP.Base = "weapon_zscav_med_base".
if SERVER then
    include("zscav_meds/sv_handler.lua")
end
