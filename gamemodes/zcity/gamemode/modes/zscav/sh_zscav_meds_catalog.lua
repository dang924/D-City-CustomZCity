-- ZScav medical catalog (EFT-style meds).
--
-- Loaded after sh_zscav_catalog.lua (alphabetical: "_meds_" sorts after "_").
-- Registers ZSCAV.ItemMeta entries for the 12 ZScavMeds SWEPs and exposes the
-- canonical EFT healing/capacity table at ZSCAV.MedicalEFT, which the
-- ZScavMeds addon's server handler reads when ZSCAV_UseMedicalTarget fires.
--
-- All values mirror the EFT wiki (HP pools, use times, status-removal costs).
-- Tuning here is safe to hot-reload; classes are matched against entries that
-- live in lua/weapons/weapon_zscav_med_*.lua inside the ZScavMeds addon.

ZSCAV = ZSCAV or {}

-- Defensive: sh_zscav_catalog.lua should have already created these, but if
-- this file loads first (or after a partial reload) we don't want
-- ZSCAV.ItemMeta[class] = {...} below to throw.
ZSCAV.ItemMeta  = ZSCAV.ItemMeta  or {}
ZSCAV.GearItems = ZSCAV.GearItems or {}

-- =====================================================================
-- Canonical EFT data table.
--
-- Per item:
--   class        = SWEP classname (in ZScavMeds addon).
--   print_name   = display name shown in inventory + status messages.
--   category     = "medkit" | "bandage" | "tourniquet" | "splint" | "surgical".
--   pool_hp      = drains 1-for-1 with HP healed AND with status-removal cost.
--                  nil = item has no HP pool (uses 'uses' or 'single_use').
--   uses         = discrete activation counter (alternative to pool_hp).
--   single_use   = true = destroy after one activation (Bandage).
--   instant_hp   = HP applied immediately on use, still capped by pool_hp.
--   use_time     = seconds (animation length; SWEPs honour this).
--   treats       = which statuses this item can clear, with the pool/use
--                  cost to clear each one. Status keys:
--                    light_bleed, heavy_bleed, fracture, contusion, pain.
--                  A value of 0 means "free" (no pool/use deduction).
--   target_parts = "any" or array of body-part IDs from ZScav health table.
--   item_w / item_h = grid footprint (cells).
--   weight       = kg (carry weight).
-- =====================================================================
ZSCAV.MedicalEFT = {

    ----------------------------------------------------------------------
    -- Medkits
    ----------------------------------------------------------------------
    {
        class = "weapon_zscav_med_ai2",
        print_name = "AI-2 Medkit",
        category = "medkit",
        pool_hp = 100,
        use_time = 2.0,
        treats = {},
        target_parts = "any",
        item_w = 1, item_h = 1,
        weight = 0.10,
    },
    {
        class = "weapon_zscav_med_car",
        print_name = "Car First Aid Kit",
        category = "medkit",
        pool_hp = 220,
        use_time = 4.0,
        treats = { light_bleed = 50 },
        target_parts = "any",
        item_w = 2, item_h = 2,
        weight = 0.50,
    },
    {
        class = "weapon_zscav_med_salewa",
        print_name = "Salewa First Aid Kit",
        category = "medkit",
        pool_hp = 400,
        use_time = 3.0,
        instant_hp = 85,
        treats = { light_bleed = 45 },
        target_parts = "any",
        item_w = 1, item_h = 2,
        weight = 0.30,
    },
    {
        class = "weapon_zscav_med_ifak",
        print_name = "IFAK Personal Tactical Kit",
        category = "medkit",
        pool_hp = 300,
        use_time = 3.0,
        treats = { light_bleed = 30, contusion = 0 },
        target_parts = "any",
        item_w = 1, item_h = 2,
        weight = 0.50,
    },
    {
        class = "weapon_zscav_med_afak",
        print_name = "AFAK Tactical Trauma Kit",
        category = "medkit",
        pool_hp = 400,
        use_time = 4.0,
        treats = { light_bleed = 30, heavy_bleed = 170, contusion = 0 },
        target_parts = "any",
        item_w = 1, item_h = 2,
        weight = 0.55,
    },
    {
        class = "weapon_zscav_med_grizzly",
        print_name = "Grizzly Medical Kit",
        category = "medkit",
        pool_hp = 1800,
        use_time = 4.5,
        treats = {
            light_bleed = 50,
            heavy_bleed = 175,
            fracture    = 50,
            contusion   = 0,
            pain        = 0,
        },
        pain_relief_add = 0.35,
        pain_relief_floor = 0.20,
        pain_relief_cap = 1.20,
        target_parts = "any",
        item_w = 2, item_h = 2,
        weight = 0.85,
    },

    ----------------------------------------------------------------------
    -- Bandages
    ----------------------------------------------------------------------
    {
        class = "weapon_zscav_med_bandage",
        print_name = "Aseptic Bandage",
        category = "bandage",
        single_use = true,
        use_time = 4.0,
        treats = { light_bleed = 0 },
        target_parts = "any",
        item_w = 1, item_h = 1,
        weight = 0.05,
    },
    {
        class = "weapon_zscav_med_armybandage",
        print_name = "Army Bandage",
        category = "bandage",
        pool_hp = 400,
        use_time = 6.0,
        instant_hp = 5,
        treats = { light_bleed = 50 },
        target_parts = "any",
        item_w = 1, item_h = 1,
        weight = 0.10,
    },

    ----------------------------------------------------------------------
    -- Tourniquets (heavy bleed only, limbs only)
    ----------------------------------------------------------------------
    {
        class = "weapon_zscav_med_esmarch",
        print_name = "Esmarch Tourniquet",
        category = "tourniquet",
        uses = 8,
        use_time = 4.0,
        treats = { heavy_bleed = 1 },
        target_parts = { "left_arm", "right_arm", "left_leg", "right_leg" },
        item_w = 1, item_h = 1,
        weight = 0.10,
    },
    {
        class = "weapon_zscav_med_cat",
        print_name = "CAT Tourniquet",
        category = "tourniquet",
        uses = 12,
        use_time = 4.0,
        treats = { heavy_bleed = 1 },
        target_parts = { "left_arm", "right_arm", "left_leg", "right_leg" },
        item_w = 1, item_h = 1,
        weight = 0.16,
    },

    ----------------------------------------------------------------------
    -- Splint (fracture, limbs only)
    ----------------------------------------------------------------------
    {
        class = "weapon_zscav_med_alusplint",
        print_name = "Aluminium Splint",
        category = "splint",
        uses = 8,
        use_time = 16.0,
        treats = { fracture = 1 },
        target_parts = { "left_arm", "right_arm", "left_leg", "right_leg" },
        item_w = 1, item_h = 1,
        weight = 0.18,
    },

    ----------------------------------------------------------------------
    -- Surgical Kit (un-blacks a limb but leaves a light bleed)
    ----------------------------------------------------------------------
    {
        class = "weapon_zscav_med_surgicalkit",
        print_name = "CMS Surgical Kit",
        category = "surgical",
        pool_hp = 260,
        use_time = 16.0,
        -- Surgical kit converts a "destroyed" limb back to alive but applies
        -- a light bleed in the process. The handler uses 'restore_blacked'
        -- as a special action key; uses == 1 means a single revive per kit.
        uses_per_revive = 1,
        treats = { restore_blacked = 60, applies_light_bleed = true },
        target_parts = { "head", "thorax", "stomach", "left_arm", "right_arm", "left_leg", "right_leg" },
        item_w = 2, item_h = 2,
        weight = 0.40,
    },
}

-- =====================================================================
-- Lookup helper. Returns the EFT data row for a given SWEP classname
-- (or nil if unregistered).
-- =====================================================================
local _eftByClass = {}
for _, row in ipairs(ZSCAV.MedicalEFT) do
    _eftByClass[string.lower(row.class)] = row
end

function ZSCAV:GetMedicalEFTData(class)
    if istable(class) then class = class.actual_class or class.class end
    class = string.lower(tostring(class or ""))
    if class == "" then return nil end
    return _eftByClass[class]
end

-- =====================================================================
-- Register ZSCAV.ItemMeta entries from the EFT table. This is what the
-- inventory grid + medical health-tab routing actually reads.
-- =====================================================================
local function buildTargetPartsLookup(targetParts)
    if targetParts == "any" or targetParts == nil then
        return "any"
    end
    if not istable(targetParts) then return "any" end

    local lookup = {}
    for _, partID in ipairs(targetParts) do
        lookup[tostring(partID):lower()] = true
    end
    return lookup
end

for _, row in ipairs(ZSCAV.MedicalEFT) do
    local class = string.lower(row.class)
    ZSCAV.ItemMeta[class] = {
        slot   = "medical",
        w      = row.item_w or 1,
        h      = row.item_h or 1,
        weight = row.weight or 0.20,
        medical = {
            health_tab   = true,
            target_parts = buildTargetPartsLookup(row.target_parts),
            -- Mirror the EFT data row so future ZScav clients/UIs can read
            -- capacity directly from the item meta without a second lookup.
            print_name   = row.print_name,
            category     = row.category,
            pool_hp      = row.pool_hp,
            uses         = row.uses,
            single_use   = row.single_use == true,
            use_time     = row.use_time,
            instant_hp   = row.instant_hp,
            treats       = row.treats,
        },
    }
end

-- Loud diagnostic so we can see in the console exactly what registered.
do
    local registered = {}
    for _, row in ipairs(ZSCAV.MedicalEFT) do
        local class = string.lower(row.class)
        if ZSCAV.ItemMeta[class] and istable(ZSCAV.ItemMeta[class].medical)
           and ZSCAV.ItemMeta[class].medical.health_tab == true then
            registered[#registered + 1] = class
        end
    end
    print(("[ZScavMeds] catalog: %d / %d entries registered with health_tab=true. (%s)"):format(
        #registered, #ZSCAV.MedicalEFT,
        SERVER and "server" or "client"))
    if #registered ~= #ZSCAV.MedicalEFT then
        print("[ZScavMeds] WARNING: some entries did not register. Check load order.")
    end
end

-- Console command for runtime debugging. Type:
--   lua_run_cl print(ZSCAV.ItemMeta["weapon_zscav_med_grizzly"].medical.health_tab)
-- ...or just run zscav_meds_dump from a server console / RCON.
if SERVER then
    concommand.Add("zscav_meds_dump", function(ply)
        local function out(msg)
            if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        end
        out("=== ZScavMeds catalog dump ===")
        for _, row in ipairs(ZSCAV.MedicalEFT) do
            local class = string.lower(row.class)
            local meta  = ZSCAV.ItemMeta[class]
            if not meta then
                out(("  %s — NOT REGISTERED in ZSCAV.ItemMeta"):format(class))
            else
                local m = meta.medical
                out(("  %s — slot=%s health_tab=%s pool=%s uses=%s"):format(
                    class,
                    tostring(meta.slot),
                    tostring(istable(m) and m.health_tab),
                    tostring(istable(m) and m.pool_hp),
                    tostring(istable(m) and m.uses)))
            end
        end
        out("=== end dump ===")
    end, nil, "Print the ZScavMeds catalog state to console.")
end
