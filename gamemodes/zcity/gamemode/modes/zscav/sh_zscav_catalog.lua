-- ZScav shared catalog: item metadata, gear, grid grants, weight.
--
-- Loads after sh_zscav.lua (alphabetical). Anything tunable for items
-- and gear should live in this file so balance changes don't touch
-- mode logic.

ZSCAV = ZSCAV or {}

-- =====================================================================
-- Generic item meta. Keys are weapon/entity classnames (lowercase).
-- All fields optional; missing values are filled from defaults below.
--   w, h     = grid footprint (overrides ZSCAV.ItemSizes if present)
--   weight   = kg-equivalent, summed for the carry counter
--   slot     = which weapon gear-slot this item occupies when equipped
--              ("primary"|"sidearm"|"grenade"|"medical"|"scabbard")
--   medical  = optional ZScav-native medical profile for future health-tab
--              items, e.g. { health_tab = true, target_parts = "any" }
-- =====================================================================
ZSCAV.ItemMeta = ZSCAV.ItemMeta or {}

local WEAPON_SLOT_REGISTRATION_ALIASES = {
    primary = "primary",
    secondary = "primary",
    sidearm = "sidearm",
    sidearm2 = "sidearm",
    grenade = "grenade",
    throwable = "grenade",
    explosive = "grenade",
    medical = "medical",
    med = "medical",
    medicine = "medical",
    heal = "medical",
    scabbard = "scabbard",
    melee = "scabbard",
}

local WEAPON_SLOT_COMPATIBILITY = {
    primary = { "primary", "secondary" },
    sidearm = { "sidearm", "sidearm2" },
    scabbard = { "melee" },
}

local function meta(class, t)
    ZSCAV.ItemMeta[class] = t
end

local HEALTH_PART_ORDER = {
    "head",
    "thorax",
    "stomach",
    "left_arm",
    "right_arm",
    "left_leg",
    "right_leg",
}

local HEALTH_PART_DEFS = {
    head = {
        id = "head",
        label = "Head",
        short_label = "HEAD",
        max_hp = 35,
        lethal = true,
        bones = {
            "ValveBiped.Bip01_Head1",
        },
    },
    thorax = {
        id = "thorax",
        label = "Thorax",
        short_label = "THORAX",
        max_hp = 85,
        lethal = true,
        bones = {
            "ValveBiped.Bip01_Spine2",
            "ValveBiped.Bip01_Spine1",
            "ValveBiped.Bip01_Spine4",
        },
    },
    stomach = {
        id = "stomach",
        label = "Stomach",
        short_label = "STOMACH",
        max_hp = 70,
        lethal = false,
        bones = {
            "ValveBiped.Bip01_Pelvis",
            "ValveBiped.Bip01_Spine",
        },
    },
    left_arm = {
        id = "left_arm",
        label = "Left Arm",
        short_label = "L. ARM",
        max_hp = 60,
        lethal = false,
        bones = {
            "ValveBiped.Bip01_L_UpperArm",
            "ValveBiped.Bip01_L_Forearm",
            "ValveBiped.Bip01_L_Hand",
        },
    },
    right_arm = {
        id = "right_arm",
        label = "Right Arm",
        short_label = "R. ARM",
        max_hp = 60,
        lethal = false,
        bones = {
            "ValveBiped.Bip01_R_UpperArm",
            "ValveBiped.Bip01_R_Forearm",
            "ValveBiped.Bip01_R_Hand",
        },
    },
    left_leg = {
        id = "left_leg",
        label = "Left Leg",
        short_label = "L. LEG",
        max_hp = 65,
        lethal = false,
        bones = {
            "ValveBiped.Bip01_L_Thigh",
            "ValveBiped.Bip01_L_Calf",
            "ValveBiped.Bip01_L_Foot",
        },
    },
    right_leg = {
        id = "right_leg",
        label = "Right Leg",
        short_label = "R. LEG",
        max_hp = 65,
        lethal = false,
        bones = {
            "ValveBiped.Bip01_R_Thigh",
            "ValveBiped.Bip01_R_Calf",
            "ValveBiped.Bip01_R_Foot",
        },
    },
}

local HEALTH_PART_BY_BONE = {}
local HEALTH_TOTAL_MAX_HP = 0

for orderIndex, partID in ipairs(HEALTH_PART_ORDER) do
    local def = HEALTH_PART_DEFS[partID]
    if def then
        def.order = orderIndex
        HEALTH_TOTAL_MAX_HP = HEALTH_TOTAL_MAX_HP + math.max(math.floor(tonumber(def.max_hp) or 0), 0)

        for _, boneName in ipairs(def.bones or {}) do
            boneName = tostring(boneName or "")
            if boneName ~= "" then
                HEALTH_PART_BY_BONE[boneName] = partID
            end
        end
    end
end

function ZSCAV:GetHealthPartDefinitions()
    local out = {}
    for _, partID in ipairs(HEALTH_PART_ORDER) do
        local def = HEALTH_PART_DEFS[partID]
        if def then
            out[#out + 1] = table.Copy(def)
        end
    end
    return out
end

function ZSCAV:GetHealthPartDef(partID)
    partID = tostring(partID or ""):lower()
    local def = HEALTH_PART_DEFS[partID]
    return def and table.Copy(def) or nil
end

function ZSCAV:GetHealthPartIDForBoneName(boneName)
    boneName = tostring(boneName or "")
    if boneName == "" then return nil end
    return HEALTH_PART_BY_BONE[boneName]
end

function ZSCAV:GetHealthTotalMaxHP()
    return HEALTH_TOTAL_MAX_HP
end

local function copyMedicalTargetParts(targetParts)
    if targetParts == nil or targetParts == "any" then
        return "any"
    end

    if not istable(targetParts) then
        return "any"
    end

    local out = {}
    local found = false

    for key, value in pairs(targetParts) do
        local partID = nil

        if value == true then
            partID = tostring(key or ""):lower()
        elseif type(key) == "number" then
            partID = tostring(value or ""):lower()
        end

        if partID ~= "" and HEALTH_PART_DEFS[partID] then
            out[partID] = true
            found = true
        end
    end

    if not found then
        return "any"
    end

    return out
end

function ZSCAV:GetMedicalUseProfile(class)
    local metaDef = self:GetItemMeta(class)
    local profile = metaDef and metaDef.medical or nil

    if not istable(profile) then
        local eftRow = self.GetMedicalEFTData and self:GetMedicalEFTData(class) or nil
        if not istable(eftRow) then return nil end

        profile = {
            health_tab = true,
            target_parts = eftRow.target_parts,
            print_name = eftRow.print_name,
            category = eftRow.category,
            pool_hp = eftRow.pool_hp,
            uses = eftRow.uses,
            single_use = eftRow.single_use == true,
            use_time = eftRow.use_time,
            instant_hp = eftRow.instant_hp,
            treats = eftRow.treats,
        }
    end

    local out = table.Copy(profile)
    out.target_parts = copyMedicalTargetParts(out.target_parts)
    if istable(out.treats) then out.treats = table.Copy(out.treats) end
    out.health_tab = out.health_tab == true
    return out
end

function ZSCAV:DoesMedicalProfileSupportHealthPart(profile, partID)
    if not (istable(profile) and profile.health_tab == true) then return false end

    partID = tostring(partID or ""):lower()
    if partID == "" or not HEALTH_PART_DEFS[partID] then return false end

    local targetParts = profile.target_parts
    if targetParts == nil or targetParts == "any" then
        return true
    end

    if not istable(targetParts) then return false end
    if targetParts[partID] == true then return true end

    for _, candidate in ipairs(targetParts) do
        if tostring(candidate or ""):lower() == partID then
            return true
        end
    end

    return false
end

function ZSCAV:NormalizeWeaponRegistrationSlot(slot)
    slot = tostring(slot or ""):lower()
    if slot == "" then return nil end
    return WEAPON_SLOT_REGISTRATION_ALIASES[slot] or slot
end

function ZSCAV:GetCompatibleWeaponSlots(slot)
    local normalized = self:NormalizeWeaponRegistrationSlot(slot)
    local compatible = normalized and WEAPON_SLOT_COMPATIBILITY[normalized] or nil
    if not compatible then return nil end
    return table.Copy(compatible)
end

function ZSCAV:IsWeaponSlotCompatible(expected, slotID)
    slotID = tostring(slotID or ""):lower()
    if slotID == "" then return false end

    for _, candidate in ipairs(self:GetCompatibleWeaponSlots(expected) or {}) do
        if candidate == slotID then
            return true
        end
    end

    return false
end

-- Sidearms
for _, c in ipairs({
    "weapon_glock17","weapon_glock18c","weapon_hk_usp","weapon_p22",
    "weapon_cz75","weapon_deagle","weapon_revolver357",
}) do meta(c, { slot = "sidearm",   weight = 0.8 }) end

-- SMGs / compact still use their lighter weight, but they occupy the same
-- long-gun class as other primaries so either back or sling can hold them.
for _, c in ipairs({ "weapon_mp5","weapon_mp7" }) do
    meta(c, { slot = "primary", weight = 2.4 })
end

-- Shotguns / rifles (back-sling primary)
for _, c in ipairs({
    "weapon_doublebarrel","weapon_doublebarrel_short","weapon_remington870",
    "weapon_xm1014","weapon_sks","weapon_akm",
}) do meta(c, { slot = "primary", weight = 3.5 }) end

-- Long heavies
for _, c in ipairs({
    "weapon_m98b","weapon_sr25","weapon_ptrd","weapon_hg_rpg",
}) do meta(c, { slot = "primary", weight = 6.0 }) end

-- Melee
for _, c in ipairs({
    "weapon_leadpipe","weapon_hg_crowbar","weapon_tomahawk","weapon_hatchet",
    "weapon_hg_axe","weapon_kabar","weapon_pocketknife","weapon_melee",
}) do meta(c, { slot = "scabbard", weight = 1.2 }) end

-- Throwables
for _, c in ipairs({
    "weapon_hg_molotov_tpik","weapon_hg_pipebomb_tpik","weapon_hg_f1_tpik",
    "weapon_hg_grenade_tpik","weapon_hg_flashbang_tpik","weapon_hg_hl2nade_tpik",
    "weapon_hg_m18_tpik","weapon_hg_mk2_tpik",
    "weapon_hg_smokenade_tpik","weapon_hg_rgd_tpik",
    "weapon_hg_type59_tpik",
    "weapon_hg_legacy_grenade_shg","weapon_claymore","weapon_traitor_ied",
    "weapon_hg_slam",
}) do meta(c, { slot = "grenade", weight = 0.4 }) end

meta("zscav_vendor_ticket", {
    name = "Vendor Ticket",
    w = 1,
    h = 1,
    weight = 0,
})

-- =====================================================================
-- Gear catalog. Keys are gear-item classnames. ZScav treats these as
-- inventory items first; equipping them moves them into a gear slot
-- and applies their `grants` to the player's effective grid sizes.
--
--   slot     = which gear slot ("ears"|"helmet"|"face_cover"|"body_armor"|"tactical_rig"|"backpack")
--   w, h     = footprint while in a grid (before equip)
--   weight   = carry-weight when on the player (in or out of a slot)
--   grants   = { pocket={w,h}, backpack={w,h} }
--              additive bonuses to the player's effective grids while equipped
-- =====================================================================
ZSCAV.GearItems = ZSCAV.GearItems or {}

local ARMOR_SLOT_BY_PLACEMENT = {
    head = "helmet",
    face = "face_cover",
    ears = "ears",
}

local ARMOR_FALLBACK_META = {
    torso = { w = 2, h = 2, weight = 4.5 },
    head = { w = 2, h = 2, weight = 1.5 },
    face = { w = 1, h = 1, weight = 0.4 },
    ears = { w = 1, h = 1, weight = 0.2 },
}

function ZSCAV:IsArmorEntityClass(class)
    class = tostring(class or ""):lower()
    return string.StartWith(class, "ent_armor_")
end

function ZSCAV:GetArmorEntityName(class)
    class = tostring(class or ""):lower()
    return string.Replace(class, "ent_armor_", "")
end

function ZSCAV:GetArmorPlacement(class)
    if not self:IsArmorEntityClass(class) then return nil end
    if hg and hg.GetArmorPlacement then
        return hg.GetArmorPlacement(class)
    end
    return nil
end

function ZSCAV:GetArmorGearDef(class)
    local placement = self:GetArmorPlacement(class)
    local slot = ARMOR_SLOT_BY_PLACEMENT[placement or ""]
    if placement == "torso" then
        slot = self:GetTorsoArmorSlotForClass(class)
    end
    if not slot then return nil end

    local armorName = self:GetArmorEntityName(class)
    local fallback = ARMOR_FALLBACK_META[placement] or ARMOR_FALLBACK_META.torso
    local label = (hg and hg.armorNames and hg.armorNames[armorName]) or string.NiceName(armorName)

    local out = {
        name = label,
        slot = slot,
        w = fallback.w,
        h = fallback.h,
        weight = fallback.weight,
    }
    if slot == "tactical_rig" then
        local stripped = self:GetArmorEntityName(class)
        local rigCfg = self.ArmorRigClasses[class] or self.ArmorRigClasses[stripped]
        local fb = (istable(rigCfg) and rigCfg) or self.ArmorVestFallbackInternal or { w = 5, h = 5 }
        out.compartment = true
        out.internal = { w = tonumber(fb.w) or 5, h = tonumber(fb.h) or 5 }
    end
    return out
end

-- A few starter examples covering the full layout. These intentionally
-- use generic class IDs so they don't collide with any existing weapon
-- entity. Real model spawning is out of scope for iteration 2.
ZSCAV.GearItems["zscav_helmet_basic"] = {
    name = "Light Helmet", slot = "helmet",
    w = 2, h = 2, weight = 1.0,
}
ZSCAV.GearItems["zscav_facecover_balaclava"] = {
    name = "Balaclava", slot = "face_cover",
    w = 1, h = 1, weight = 0.1,
}
ZSCAV.GearItems["zscav_ears_headset"] = {
    name = "Comm Headset", slot = "ears",
    w = 1, h = 1, weight = 0.2,
}
ZSCAV.GearItems["zscav_vest_chestrig"] = {
    name = "Chest Rig", slot = "tactical_rig",
    w = 2, h = 2, weight = 1.5,
    compartment = true,
    internal = { w = 4, h = 2 },
}
ZSCAV.GearItems["zscav_vest_platecarrier"] = {
    name = "Plate Carrier", slot = "tactical_rig",
    w = 3, h = 3, weight = 6.0,
    compartment = true,
    internal = { w = 6, h = 3 },
}
ZSCAV.GearItems["zscav_pack_small"] = {
    name = "Sling Pack", slot = "backpack",
    w = 3, h = 3, weight = 1.5,
    grants = { backpack = { w = 4, h = 4 } },
}
ZSCAV.GearItems["zscav_pack_large"] = {
    name = "Combat Pack", slot = "backpack",
    w = 4, h = 4, weight = 4.0,
    grants = { backpack = { w = 6, h = 8 } },
}
ZSCAV.GearItems["zscav_alpha_container"] = {
    name = "Alpha Container", slot = "secure_container",
    w = 2, h = 2, weight = 0.8,
    compartment = false,
    internal = { w = 2, h = 2 },
    secure = true,  -- Mark as secure/undroppable
}
ZSCAV.GearItems["zscav_mailbox_container"] = {
    name = "Mailbox", slot = "mailbox",
    w = 2, h = 2, weight = 0,
    compartment = false,
    internal = { w = 10, h = 64 },
    no_player_insert = true,
    virtual = true,
}
ZSCAV.GearItems["zscav_trade_player_offer"] = {
    name = "Trade Basket", slot = "trade_offer",
    w = 2, h = 2, weight = 0,
    compartment = false,
    internal = { w = 6, h = 6 },
    virtual = true,
}

-- ---------------------------------------------------------------------
-- Real backpack entities (iteration 1: 3 starter packs).
-- The class IS the SENT classname so dropping/equipping spawns the
-- correct world prop. Tunable from the live admin config (sv_zscav_config)
-- which can override w/h/weight/grants per class without touching code.
-- ---------------------------------------------------------------------
ZSCAV.GearItems["ent_zscav_pack_sportbag"] = {
    name = "Sportbag", slot = "backpack",
    w = 3, h = 3, weight = 1.2,
    -- Modest default. With the 2x2 pocket base this gives a 3x4 grid.
    grants = { backpack = { w = 3, h = 2 } },
    -- Internal storage when accessed as a container (on ground / nested).
    internal = { w = 4, h = 4 },
    -- Bonemerge display defaults. Tunable live via zscav_config.
    display = {
        bone   = "ValveBiped.Bip01_Spine2",
        pos    = { x = 1.14, y = -4.44, z = -3.39 },
        ang    = { p = -25.44, y = 166.11, r = -2.43 },
        scale  = 1.000,
    },
}
ZSCAV.GearItems["ent_zscav_pack_molle"] = {
    name = "MOLLE Pack", slot = "backpack",
    w = 4, h = 4, weight = 2.6,
    -- Mid-tier. Effective backpack: 4x6.
    grants = { backpack = { w = 4, h = 4 } },
    internal = { w = 5, h = 6 },
    display = {
        bone   = "ValveBiped.Bip01_Spine2",
        pos    = { x = 3.02, y = -4.21, z = -0.91 },
        ang    = { p = -92.57, y = 135.78, r = 45.25 },
        scale  = 1.000,
    },
}
ZSCAV.GearItems["ent_zscav_pack_pilgrim"] = {
    name = "Pilgrim Backpack", slot = "backpack",
    w = 4, h = 5, weight = 4.6,
    grants = { backpack = { w = 5, h = 5 } },
    internal = { w = 6, h = 7 },
    display = {
        bone   = "ValveBiped.Bip01_Spine2",
        -- First-pass fit copied from the similar MOLLE export; tune live via zscav_config if needed.
        pos    = { x = 3.66, y = -4.50, z = 0.68 },
        ang    = { p = -99.83, y = 172.66, r = 9.37 },
        scale  = 1.000,
    },
}
ZSCAV.GearItems["ent_zscav_pack_paratus"] = {
    name = "Paratus 3-Day", slot = "backpack",
    w = 4, h = 5, weight = 4.2,
    -- Large 3-day ruck. Effective backpack: 6x8.
    grants = { backpack = { w = 6, h = 6 } },
    internal = { w = 6, h = 8 },
    display = {
        bone   = "ValveBiped.Bip01_Spine2",
        pos    = { x = -8, y = 0, z = 0 },
        ang    = { p = 0, y = 0, r = 0 },
        scale  = 1.0,
    },
}

-- Iteration helper for code that needs to enumerate pack classes (admin
-- config UI, give-commands, etc.). Filters GearItems by slot=="backpack".
function ZSCAV:GetPackClasses()
    local out = {}
    for class, def in pairs(ZSCAV.GearItems) do
        if def and def.slot == "backpack" then out[#out + 1] = class end
    end
    table.sort(out)
    return out
end

-- =====================================================================
-- Base grids when nothing is equipped. The "backpack" grid stays at
-- 2x2 to act as the player's pockets even with no gear.
-- =====================================================================
ZSCAV.BaseGrids = {
    backpack = { w = 2, h = 2 },   -- pack/pocket fallback (kept for parity)
    pocket   = { w = 4, h = 1 },   -- single pocket grid (wide row)
    vest     = { w = 0, h = 0 },   -- vest compartment (sized by equipped vest def)
}

-- Fallback tactical-rig size for torso armor that should have a compartment
-- but does not define an explicit internal size in GearItems.
ZSCAV.ArmorVestFallbackInternal = ZSCAV.ArmorVestFallbackInternal or { w = 5, h = 5 }

-- Admin-editable table: mark specific torso armors as tactical rigs.
-- Keys: armor name WITHOUT "ent_armor_" prefix (e.g. "vest30") OR full class (e.g. "ent_armor_vest30").
-- Values: true  → use ArmorVestFallbackInternal grid size.
--         {w=N, h=N} → override grid size for that rig specifically.
-- Example:  ZSCAV.ArmorRigClasses["vest30"] = {w=4, h=4}
ZSCAV.ArmorRigClasses = ZSCAV.ArmorRigClasses or {}

-- Register known tactical rigs. Accept both stripped name and full ent_armor_ class.
ZSCAV.ArmorRigClasses["vest30"] = { w = 4, h = 4 }
ZSCAV.ArmorRigClasses["ent_armor_vest30"] = { w = 4, h = 4 }

function ZSCAV:IsCompartmentedRigDef(def)
    if not istable(def) then return false end
    if def.compartment then return true end
    if istable(def.layoutBlocks) and #def.layoutBlocks > 0 then return true end
    if istable(def.internal) and ((tonumber(def.internal.w) or 0) > 0) and ((tonumber(def.internal.h) or 0) > 0) then
        return true
    end
    return false
end

function ZSCAV:GetTorsoArmorSlotForClass(class)
    class = tostring(class or ""):lower()
    local stripped = self:GetArmorEntityName(class)

    -- For armor entities (ent_armor_*) the slot is determined ONLY by whether
    -- a grid exists. This prevents the chicken-and-egg where ApplyOverrides
    -- writes slot="body_armor" before the internal grid is applied, and that
    -- stored value then permanently overrides the grid-based routing.
    if self:IsArmorEntityClass(class) then
        -- ArmorRigClasses hard-override (admin table set in code/console).
        if self.ArmorRigClasses[class] or self.ArmorRigClasses[stripped] then
            return "tactical_rig"
        end
        -- GearItems entry exists with grid data: treat as tactical rig.
        local configured = self.GearItems and self.GearItems[class]
        if istable(configured) and self:IsCompartmentedRigDef(configured) then
            return "tactical_rig"
        end
        -- No grid configured: plain body armor.
        return "body_armor"
    end

    -- For custom/non-armor gear items: respect the explicit slot tag.
    local configured = self.GearItems and self.GearItems[class]
    if istable(configured) then
        local explicit = tostring(configured.slot or ""):lower()
        if explicit == "tactical_rig" or explicit == "body_armor" then
            return explicit
        end
        if explicit == "vest" or explicit == "" then
            return self:IsCompartmentedRigDef(configured) and "tactical_rig" or "body_armor"
        end
    end
    return "body_armor"
end

-- =====================================================================
-- Lookups
-- =====================================================================
local function normalizeItemToken(value)
    return string.Trim(string.lower(tostring(value or "")))
end

local function copyItemMeta(source)
    if not istable(source) then return nil end

    local out = {}
    for key, value in pairs(source) do
        out[key] = value
    end

    return out
end

local function extractScaledVariantKey(className)
    className = normalizeItemToken(className)
    if className == "" then return "" end
    return tostring(className:match("^zscav_(i%d+)_.+$") or "")
end

function ZSCAV:GetCanonicalItemClass(classOrEntry)
    local className = classOrEntry
    if istable(classOrEntry) then
        className = classOrEntry.actual_class or classOrEntry.class
    elseif IsValid(classOrEntry) then
        className = classOrEntry:GetClass()
    end

    className = normalizeItemToken(className)
    if className == "" then return "" end

    if self.IsAttachmentItemClass and self:IsAttachmentItemClass(className) and self.GetAttachmentItemClass then
        local attachmentClass = normalizeItemToken(self:GetAttachmentItemClass(className))
        if attachmentClass ~= "" then
            return attachmentClass
        end
    end

    if self.GetWeaponBaseClass then
        local baseClass = normalizeItemToken(self:GetWeaponBaseClass(className))
        if baseClass ~= "" then
            return baseClass
        end
    end

    return className
end

local function resolveItemMetaContext(self, classOrEntry)
    local rawClass = ""
    local actualClass = ""

    if istable(classOrEntry) then
        rawClass = normalizeItemToken(classOrEntry.class)
        actualClass = normalizeItemToken(classOrEntry.actual_class)
    elseif IsValid(classOrEntry) then
        rawClass = normalizeItemToken(classOrEntry:GetClass())
    else
        rawClass = normalizeItemToken(classOrEntry)
    end

    local variantClass = actualClass ~= "" and actualClass or rawClass
    local canonicalClass = self:GetCanonicalItemClass(variantClass)
    if canonicalClass == "" then
        canonicalClass = self:GetCanonicalItemClass(rawClass)
    end
    if canonicalClass == "" then
        canonicalClass = variantClass ~= "" and variantClass or rawClass
    end

    return {
        rawClass = rawClass,
        actualClass = actualClass,
        variantClass = variantClass,
        canonicalClass = canonicalClass,
        scaleKey = extractScaledVariantKey(variantClass),
    }
end

local function applyItemMetaVariant(baseMeta, variantMeta)
    baseMeta = copyItemMeta(baseMeta) or {}
    if not istable(variantMeta) then return baseMeta end

    if variantMeta.w ~= nil then
        baseMeta.w = math.max(1, math.floor(tonumber(variantMeta.w) or tonumber(baseMeta.w) or 1))
    elseif variantMeta.dw ~= nil and baseMeta.w ~= nil then
        baseMeta.w = math.max(1, math.floor((tonumber(baseMeta.w) or 1) + (tonumber(variantMeta.dw) or 0)))
    end

    if variantMeta.h ~= nil then
        baseMeta.h = math.max(1, math.floor(tonumber(variantMeta.h) or tonumber(baseMeta.h) or 1))
    elseif variantMeta.dh ~= nil and baseMeta.h ~= nil then
        baseMeta.h = math.max(1, math.floor((tonumber(baseMeta.h) or 1) + (tonumber(variantMeta.dh) or 0)))
    end

    if variantMeta.weight ~= nil then
        baseMeta.weight = tonumber(variantMeta.weight) or baseMeta.weight
    end

    if variantMeta.slot ~= nil then
        local slot = string.Trim(tostring(variantMeta.slot or ""))
        baseMeta.slot = slot ~= "" and slot or nil
    end

    return baseMeta
end

local function getItemMetaVariant(meta, context)
    local variants = istable(meta) and meta.size_variants or nil
    if not istable(variants) then return nil end

    local seen = {}
    for _, key in ipairs({
        context.actualClass,
        context.variantClass,
        context.rawClass,
        context.scaleKey,
    }) do
        key = normalizeItemToken(key)
        if key ~= "" and not seen[key] then
            seen[key] = true
            local variant = variants[key]
            if istable(variant) then
                return variant
            end
        end
    end

    return nil
end

function ZSCAV:GetItemMeta(class)
    local context = resolveItemMetaContext(self, class)
    if context.canonicalClass == "" then return nil end

    local base = ZSCAV.ItemMeta[context.canonicalClass] or ZSCAV.GearItems[context.canonicalClass]
    local direct = nil

    if context.actualClass ~= "" then
        direct = ZSCAV.ItemMeta[context.actualClass] or ZSCAV.GearItems[context.actualClass]
    end
    if not direct and context.rawClass ~= "" and context.rawClass ~= context.canonicalClass then
        direct = ZSCAV.ItemMeta[context.rawClass] or ZSCAV.GearItems[context.rawClass]
    end
    if not direct and context.variantClass ~= "" and context.variantClass ~= context.canonicalClass then
        direct = ZSCAV.ItemMeta[context.variantClass] or ZSCAV.GearItems[context.variantClass]
    end

    if base then
        local out = copyItemMeta(base) or {}
        if direct and direct ~= base then
            out = applyItemMetaVariant(out, direct)
        else
            local variant = getItemMetaVariant(base, context)
            if variant then
                out = applyItemMetaVariant(out, variant)
            end
        end
        return out
    end

    if direct then
        return copyItemMeta(direct)
    end

    return nil
end

function ZSCAV:IsGearItem(class)
    class = self:GetCanonicalItemClass(class)
    return ZSCAV.GearItems[class] ~= nil or self:GetArmorGearDef(class) ~= nil
end

function ZSCAV:GetGearDef(class)
    class = self:GetCanonicalItemClass(class)
    local g = ZSCAV.GearItems[class]
    if g then
        -- Shallow-copy to avoid permanently mutating the GearItems table.
        local out = {}
        for k, v in pairs(g) do out[k] = v end
        if self:IsArmorEntityClass(class) then
            local placement = self:GetArmorPlacement(class)
            if placement == "torso" then
                local slot = self:GetTorsoArmorSlotForClass(class)
                out.slot = slot
                if slot == "tactical_rig" then
                    out.compartment = true
                    if not istable(out.internal) then
                        local stripped = self:GetArmorEntityName(class)
                        local rigCfg = self.ArmorRigClasses[class] or self.ArmorRigClasses[stripped]
                        local fb = (istable(rigCfg) and rigCfg) or self.ArmorVestFallbackInternal or { w = 5, h = 5 }
                        out.internal = { w = tonumber(fb.w) or 5, h = tonumber(fb.h) or 5 }
                    end
                end
            end
        end
        if out.slot == "vest" then
            out.slot = "tactical_rig"
            out.compartment = out.compartment ~= false
        end
        return out
    end
    return self:GetArmorGearDef(class)
end

function ZSCAV:GetEquipWeaponSlot(class)
    local m = self:GetItemMeta(class)
    if m and m.slot then
        return self:NormalizeWeaponRegistrationSlot(m.slot)
    end

    -- Fallback: infer from the SWEP table so we don't need to hard-code
    -- every weapon (especially ArcCW / ArccW EFT / TFA classes).
    local context = resolveItemMetaContext(self, class)
    class = context.canonicalClass ~= "" and context.canonicalClass or context.rawClass
    local wep = weapons.Get(class)
    if not wep then return nil end

    local cat = tostring(wep.Category or ""):lower()
    if cat:find("grenade") or cat:find("throw") or cat:find("explosive") then
        return "grenade"
    end
    if cat:find("med") or cat:find("medical") or cat:find("medicine") or cat:find("heal") then
        return "medical"
    end
    if cat:find("pistol") or cat:find("sidearm") or cat:find("revolver") then
        return "sidearm"
    end
    if cat:find("melee") or cat:find("knife") or cat:find("blade")
        or cat:find("axe") or cat:find("blunt") then
        return "scabbard"
    end
    if cat:find("smg") or cat:find("shotgun") or cat:find("submachine")
        or cat:find("compact") or cat:find("pdw") then
        return "primary"
    end
    if cat:find("rifle") or cat:find("sniper") or cat:find("dmr")
        or cat:find("assault") or cat:find("battle") or cat:find("lmg")
        or cat:find("launcher") or cat:find("primary") or cat:find("heavy") then
        return "primary"
    end

    -- HoldType heuristics
    local hold = tostring(wep.HoldType or ""):lower()
    if hold == "pistol" or hold == "revolver" then return "sidearm" end
    if hold == "melee" or hold == "melee2" or hold == "knife" then return "scabbard" end
    if hold == "grenade" then return "grenade" end
    if hold == "smg" or hold == "shotgun" then return "primary" end
    if hold == "ar2" or hold == "rpg" or hold == "crossbow" or hold == "physgun" then
        return "primary"
    end

    -- Class-name heuristics last.
    if class:find("pistol") or class:find("revolver") or class:find("deagle")
        or class:find("glock") or class:find("usp") then return "sidearm" end
    if class:find("knife") or class:find("axe") or class:find("hatchet")
        or class:find("crowbar") or class:find("pipe") or class:find("bat") then
        return "scabbard"
    end
    if class:find("grenade") or class:find("nade") or class:find("flashbang") or class:find("molotov")
        or class:find("claymore") or class:find("ied") or class:find("slam") then
        return "grenade"
    end
    if class:find("med") or class:find("medicine") or class:find("bandage")
        or class:find("morphine") or class:find("splint") or class:find("heal")
        or class:find("stim") or class:find("pain") or class:find("tourniquet")
        or class:find("naloxone") or class:find("needle") or class:find("adrenaline")
        or class:find("betablock") or class:find("bloodbag") or class:find("clot")
        or class:find("fentanyl") or class:find("mannitol") or class:find("thiamine")
        or class:find("afak") then
        return "medical"
    end
    if class:find("smg") or class:find("mp5") or class:find("mp7")
        or class:find("p90") or class:find("uzi") or class:find("vector") then
        return "primary"
    end
    if class:find("rifle") or class:find("sniper") or class:find("ak")
        or class:find("ar15") or class:find("m4") or class:find("shotgun")
        or class:find("rpg") or class:find("lmg") or class:find("g3") then
        return "primary"
    end

    -- Default any remaining firearm-like weapon to primary so it can use the
    -- back/sling pair instead of a separate secondary classification.
    return "primary"
end

function ZSCAV:GetItemWeight(class)
    local m = self:GetItemMeta(class)
    if m and m.weight then return m.weight end

    local canonicalClass = self:GetCanonicalItemClass(class)
    if canonicalClass == "" then
        canonicalClass = normalizeItemToken(istable(class) and (class.class or class.actual_class) or class)
    end

    class = canonicalClass
    local g = self:GetGearDef(class)
    if g and g.weight then return g.weight end
    local wep = weapons.Get(class)
    local cat = wep and tostring(wep.Category or ""):lower() or ""
    local hold = wep and tostring(wep.HoldType or ""):lower() or ""
    if cat:find("smg") or cat:find("submachine") or cat:find("compact") or cat:find("pdw")
        or hold == "smg"
        or class:find("smg") or class:find("mp5") or class:find("mp7")
        or class:find("p90") or class:find("uzi") or class:find("vector") then
        return 2.4
    end
    -- Infer from inferred slot when class isn't catalogued.
    local slot = self:GetEquipWeaponSlot(class)
    if slot == "sidearm"   then return 0.8 end
    if slot == "scabbard"  then return 1.2 end
    if slot == "grenade"   then return 0.4 end
    if slot == "medical"   then return 0.2 end
    if slot == "primary"   then return 3.5 end
    -- Heuristic fallbacks
    if class:find("ammo")    then return 0.3 end
    if class:find("med")     then return 0.2 end
    if class:find("bandage") then return 0.05 end
    return 0.5
end

-- Override sh_zscav.lua's size lookup so gear w/h is respected.
local _origGetItemSize = ZSCAV.GetItemSize
function ZSCAV:GetItemSize(class)
    local m = self:GetItemMeta(class)
    if m and m.w and m.h then return { w = m.w, h = m.h } end

    local context = resolveItemMetaContext(self, class)
    local lookupClass = context.canonicalClass ~= "" and context.canonicalClass or context.rawClass
    local g = self:GetGearDef(lookupClass)
    if g and g.w and g.h then return { w = g.w, h = g.h } end
    return _origGetItemSize(self, class)
end

-- =====================================================================
-- Effective grid sizes for a given inventory state. Sums BaseGrids +
-- equipped gear grants. Returns {backpack={w,h}, pocket={w,h}}.
-- =====================================================================
function ZSCAV:GetEffectiveGrids(inv)
    local bp = ZSCAV.BaseGrids.backpack or { w = 0, h = 0 }
    local p  = ZSCAV.BaseGrids.pocket   or { w = 0, h = 0 }
    local out = {
        backpack = { w = bp.w, h = bp.h },
        pocket   = { w = p.w, h = p.h },
        vest     = { w = 0, h = 0 },
        secure   = { w = 0, h = 0 },
    }
    if not inv or not inv.gear then return out end

    local hasBackpackEquipped = false

    for slotID, slotData in pairs(inv.gear) do
        local def = slotData and slotData.class and self:GetGearDef(slotData.class)
        if def then
            if slotID == "backpack" then
                hasBackpackEquipped = true
            end

            -- Vest compartment: sized from def.internal, not grants.
            if (slotID == "tactical_rig" or slotID == "vest") and def.compartment and def.internal then
                out.vest = { w = def.internal.w or 0, h = def.internal.h or 0 }
            elseif (slotID == "tactical_rig" or slotID == "vest") and def.slot == "tactical_rig" then
                local fb = self.ArmorVestFallbackInternal or { w = 0, h = 0 }
                out.vest = {
                    w = math.max(out.vest.w or 0, fb.w or 0),
                    h = math.max(out.vest.h or 0, fb.h or 0),
                }
            end

            if slotID == "secure_container" and def.secure and def.internal then
                out.secure = {
                    w = tonumber(def.internal.w) or 0,
                    h = tonumber(def.internal.h) or 0,
                }
            end

            -- Legacy pocket/backpack grants (chest rigs without compartment).
            if def.grants then
                for gname, g in pairs(def.grants) do
                    if out[gname] then
                        local gw = tonumber(g.w) or 0
                        local gh = tonumber(g.h) or 0
                        if slotID == "backpack" and gname == "backpack" then
                            -- Worn backpack space must mirror the bag's own internal container
                            -- size so equipped and stash views are identical.
                            local iw = tonumber(def.internal and def.internal.w) or 0
                            local ih = tonumber(def.internal and def.internal.h) or 0
                            if iw > 0 and ih > 0 then
                                out[gname].w = iw
                                out[gname].h = ih
                            else
                                -- Legacy fallback: old gear rows that only define grants.
                                out[gname].w = gw
                                out[gname].h = gh
                            end
                        else
                            out[gname].w = math.max(out[gname].w, gw)
                            out[gname].h = out[gname].h + gh
                        end
                    end
                end
            end
        end
    end

    if not hasBackpackEquipped then
        out.backpack.w = 0
        out.backpack.h = 0
    end

    return out
end

-- Total carry weight: every item in any grid + every equipped gear piece
-- + every equipped weapon. Returns kg. Recursive into bag UID contents
-- (server-only walk; clients only see the synced inv structure).
ZSCAV.WeightNoticeStartKG = ZSCAV.WeightNoticeStartKG or 30.0
ZSCAV.WeightJogStartKG = ZSCAV.WeightJogStartKG or 50.0
ZSCAV.WeightUnstableStartKG = ZSCAV.WeightUnstableStartKG or 70.0
ZSCAV.WeightCollapseStartKG = ZSCAV.WeightCollapseStartKG or 90.0
ZSCAV.WeightCollapsePeakKG = ZSCAV.WeightCollapsePeakKG or 110.0
ZSCAV.WeightSprintStaminaSoftStartFrac = ZSCAV.WeightSprintStaminaSoftStartFrac or 0.20
ZSCAV.WeightSprintStaminaHardBlockFrac = ZSCAV.WeightSprintStaminaHardBlockFrac or 0.07
ZSCAV.WeightSprintStaminaRecoverFrac = ZSCAV.WeightSprintStaminaRecoverFrac or 0.18

local function GetWeightRangeT(weightKg, minKg, maxKg)
    if maxKg <= minKg then return 1 end
    return math.Clamp((weightKg - minKg) / (maxKg - minKg), 0, 1)
end

function ZSCAV:GetWeightMovementProfile(weightKg)
    weightKg = math.max(tonumber(weightKg) or 0, 0)

    local noticeStart = tonumber(self.WeightNoticeStartKG) or 30.0
    local jogStart = tonumber(self.WeightJogStartKG) or 50.0
    local unstableStart = tonumber(self.WeightUnstableStartKG) or 70.0
    local collapseStart = tonumber(self.WeightCollapseStartKG) or 90.0
    local collapsePeak = math.max(tonumber(self.WeightCollapsePeakKG) or 110.0, collapseStart + 1.0)

    local profile = {
        id = "light",
        severity = 0,
        label = "Unburdened",
        sprintLabel = "Full sprint",
        walkMul = 1.0,
        sprintMul = 1.0,
        speedGainMul = 1.0,
        inertiaMul = 1.0,
        staminaMul = 1.0,
        blockSprint = false,
        sprintAttemptRagdoll = false,
        moveRagdollChance = 0.0,
        sprintRagdollChance = 0.0,
    }

    if weightKg < noticeStart then
        local t = GetWeightRangeT(weightKg, 0, noticeStart)
        profile.walkMul = Lerp(t, 1.0, 0.97)
        profile.sprintMul = Lerp(t, 1.0, 0.96)
        profile.speedGainMul = Lerp(t, 1.0, 0.97)
        profile.inertiaMul = Lerp(t, 1.0, 0.97)
        profile.staminaMul = Lerp(t, 1.0, 1.1)
        return profile
    end

    if weightKg < jogStart then
        local t = GetWeightRangeT(weightKg, noticeStart, jogStart)
        profile.id = "noticeable"
        profile.severity = 1
        profile.label = "Noticeable load"
        profile.sprintLabel = "Noticeable drag"
        profile.walkMul = Lerp(t, 0.97, 0.9)
        profile.sprintMul = Lerp(t, 0.96, 0.82)
        profile.speedGainMul = Lerp(t, 0.97, 0.88)
        profile.inertiaMul = Lerp(t, 0.97, 0.88)
        profile.staminaMul = Lerp(t, 1.1, 1.25)
        return profile
    end

    if weightKg < unstableStart then
        local t = GetWeightRangeT(weightKg, jogStart, unstableStart)
        profile.id = "jog"
        profile.severity = 2
        profile.label = "Encumbered"
        profile.sprintLabel = "Light jog max"
        profile.walkMul = Lerp(t, 0.9, 0.82)
        profile.sprintMul = Lerp(t, 0.82, 0.64)
        profile.speedGainMul = Lerp(t, 0.88, 0.72)
        profile.inertiaMul = Lerp(t, 0.88, 0.7)
        profile.staminaMul = Lerp(t, 1.25, 1.55)
        return profile
    end

    if weightKg < collapseStart then
        local t = GetWeightRangeT(weightKg, unstableStart, collapseStart)
        profile.id = "unstable"
        profile.severity = 3
        profile.label = "Overloaded"
        profile.sprintLabel = "Unstable sprint"
        profile.walkMul = Lerp(t, 0.82, 0.72)
        profile.sprintMul = Lerp(t, 0.64, 0.5)
        profile.speedGainMul = Lerp(t, 0.72, 0.58)
        profile.inertiaMul = Lerp(t, 0.7, 0.54)
        profile.staminaMul = Lerp(t, 1.55, 1.9)
        profile.sprintRagdollChance = Lerp(t, 0.001, 0.0035)
        return profile
    end

    local t = GetWeightRangeT(weightKg, collapseStart, collapsePeak)
    profile.id = "collapse"
    profile.severity = 4
    profile.label = "Collapse risk"
    profile.sprintLabel = "Sprint blocked"
    profile.walkMul = Lerp(t, 0.72, 0.58)
    profile.sprintMul = profile.walkMul
    profile.speedGainMul = Lerp(t, 0.58, 0.42)
    profile.inertiaMul = Lerp(t, 0.54, 0.38)
    profile.staminaMul = Lerp(t, 1.9, 2.35)
    profile.blockSprint = true
    profile.sprintAttemptRagdoll = true
    profile.moveRagdollChance = Lerp(t, 0.0035, 0.012)
    return profile
end

function ZSCAV:GetGridCarryWeight(inv)
    if not inv then return 0 end

    if CLIENT then
        local networkedCarry = tonumber(inv._gridCarryWeight)
        if networkedCarry ~= nil then
            return math.max(networkedCarry, 0)
        end
    end

    local total = 0
    for _, gname in ipairs({ "backpack", "pocket", "vest" }) do
        for _, it in ipairs(inv[gname] or {}) do
            total = total + self:GetItemWeight(it)
            if SERVER and it.uid and self.GetBagStoredWeight then
                total = total + self:GetBagStoredWeight(it.uid)
            end
        end
    end

    return total
end

function ZSCAV:GetTotalWeight(inv)
    if not inv then return 0 end

    if CLIENT then
        local networkedTotal = tonumber(inv._totalWeight)
        if networkedTotal ~= nil then
            return math.max(networkedTotal, 0)
        end
    end

    local total = self:GetGridCarryWeight(inv)
    for _, slotData in pairs(inv.gear or {}) do
        if slotData and slotData.class then
            total = total + self:GetItemWeight(slotData)
            if SERVER and slotData.uid and self.GetBagStoredWeight then
                total = total + self:GetBagStoredWeight(slotData.uid)
            end
        end
    end
    for _, slotData in pairs(inv.weapons or {}) do
        if slotData and slotData.class then
            total = total + self:GetItemWeight(slotData)
        end
    end
    return total
end

-- Legacy carry-cap knob kept for compatibility with existing admin configs.
-- ZScav no longer hard-rejects pickups by weight; movement penalties are
-- applied server-side instead.
ZSCAV.MaxCarryWeight = ZSCAV.MaxCarryWeight or 35.0

function ZSCAV:CanCarryMore(inv, addClass, addUID)
    local cap = math.huge
    local cur = self:GetTotalWeight(inv)
    local extra = self:GetItemWeight(addClass) or 0
    if SERVER and addUID and self.GetBagStoredWeight then
        extra = extra + self:GetBagStoredWeight(addUID)
    end
    return true, cur, extra, cap
end
