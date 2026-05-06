if SERVER then
    AddCSLuaFile()
end

ZSCAV = ZSCAV or {}
ZSCAV.WorldLoot = ZSCAV.WorldLoot or {}

local lib = ZSCAV.WorldLoot

lib.Net = lib.Net or {
    Sync = "ZScavWorldLootSync",
    Action = "ZScavWorldLootAction",
    Open = "ZScavWorldLootOpen",
}

lib.DataDir = "zcity"
lib.DataSubDir = "zcity/zscav_world_loot"
lib.LootGroupPrefix = "@"

lib.ACTION_PLACE_CONTAINER = 1
lib.ACTION_REMOVE_CONTAINER = 2
lib.ACTION_REGISTER_MODEL_CONTAINER = 3
lib.ACTION_UNREGISTER_MODEL_CONTAINER = 4
lib.ACTION_REGISTER_VALUABLE = 5
lib.ACTION_UNREGISTER_VALUABLE = 6
lib.ACTION_SPAWN_VALUABLE = 7
lib.ACTION_ADD_VALUABLE_TO_CONTAINER = 8
lib.ACTION_REGISTER_LOOT_GROUP = 9
lib.ACTION_UNREGISTER_LOOT_GROUP = 10

lib.State = lib.State or {
    placed_spawns = {},
    model_containers = {},
    valuables = {},
    custom_groups = {},
}

lib.ModelItemIndex = lib.ModelItemIndex or {}
lib.ModelContainerIndex = lib.ModelContainerIndex or {}

lib._injectedItemClasses = lib._injectedItemClasses or {}
lib._injectedGearClasses = lib._injectedGearClasses or {}

local function normalizeToken(value)
    value = string.lower(string.Trim(tostring(value or "")))
    value = string.gsub(value, "[^a-z0-9_]+", "_")
    value = string.gsub(value, "_+", "_")
    value = string.Trim(value, "_")
    return value
end

function lib.NormalizeModel(model)
    model = string.lower(string.Trim(tostring(model or "")))
    model = string.gsub(model, "\\", "/")
    return model
end

local LOOT_GROUP_DEFS = {
    {
        token = "@weapons",
        label = "Weapons",
        description = "Random firearm from the current ZScav weapon catalog.",
        kinds = { weapon = true },
    },
    {
        token = "@ammo",
        label = "Ammo",
        description = "Random ammo stack, magazine, or ammo entity.",
        kinds = { ammo = true },
    },
    {
        token = "@gear",
        label = "Gear",
        description = "Random wearable gear, armor, rig, or backpack.",
        kinds = { gear = true },
    },
    {
        token = "@loot",
        label = "General Loot",
        description = "Random general loot item that is not ammo, weapon, gear, medical, or valuable.",
        kinds = { loot = true },
    },
    {
        token = "@medical",
        label = "Medical",
        description = "Random medical or healing item.",
        kinds = { medical = true },
    },
    {
        token = "@grenades",
        label = "Grenades",
        description = "Random grenade, explosive, or throwable.",
        kinds = { grenade = true },
    },
    {
        token = "@melee",
        label = "Melee",
        description = "Random melee or scabbard item.",
        kinds = { melee = true },
    },
    {
        token = "@valuables",
        label = "Valuables",
        description = "Random prop-backed valuable item.",
        kinds = { valuable = true },
    },
}

local LOOT_GROUP_INDEX = {}
for _, def in ipairs(LOOT_GROUP_DEFS) do
    LOOT_GROUP_INDEX[def.token] = def
end

local function getCustomLootGroupsRaw()
    local state = lib.State or {}
    return istable(state.custom_groups) and state.custom_groups or {}
end

local function normalizeLootClass(class)
    return string.lower(string.Trim(tostring(class or "")))
end

local function textContainsAny(value, needles)
    value = string.lower(string.Trim(tostring(value or "")))
    if value == "" then return false end

    for _, needle in ipairs(needles or {}) do
        needle = string.lower(string.Trim(tostring(needle or "")))
        if needle ~= "" and string.find(value, needle, 1, true) then
            return true
        end
    end

    return false
end

function lib.NormalizeLootGroupToken(token)
    token = string.lower(string.Trim(tostring(token or "")))
    token = string.gsub(token, "^" .. string.PatternSafe(lib.LootGroupPrefix) .. "+", "")
    token = string.gsub(token, "[^a-z0-9_]+", "_")
    token = string.gsub(token, "_+", "_")
    token = string.Trim(token, "_")
    if token == "" then return "" end
    return lib.LootGroupPrefix .. token
end

function lib.IsDefaultLootGroupToken(token)
    return LOOT_GROUP_INDEX[lib.NormalizeLootGroupToken(token)] ~= nil
end

function lib.GetDefaultLootGroupDef(token)
    local def = LOOT_GROUP_INDEX[lib.NormalizeLootGroupToken(token)]
    return istable(def) and table.Copy(def) or nil
end

function lib.IsLootGroupToken(token)
    token = lib.NormalizeLootGroupToken(token)
    return token ~= "" and (getCustomLootGroupsRaw()[token] ~= nil or lib.IsDefaultLootGroupToken(token))
end

function lib.GetLootGroupDef(token)
    token = lib.NormalizeLootGroupToken(token)
    if token == "" then return nil end

    local base = lib.GetDefaultLootGroupDef(token)
    local custom = getCustomLootGroupsRaw()[token]
    if not istable(base) and not istable(custom) then
        return nil
    end

    local out = istable(base) and table.Copy(base) or {}
    if istable(custom) then
        for key, value in pairs(custom) do
            out[key] = istable(value) and table.Copy(value) or value
        end
    end

    out.token = token
    out.builtin = istable(base)
    out.overridden = istable(base) and istable(custom)
    out.custom = istable(custom)
    out.label = string.Trim(tostring(out.label or (istable(base) and base.label) or string.NiceName(string.sub(token, 2))))
    out.description = string.Trim(tostring(out.description or (istable(base) and base.description) or ""))
    return out
end

local function shouldSkipLootCatalogClass(class)
    class = normalizeLootClass(class)
    if class == "" or class == "weapon_base" then return true end
    if string.StartWith(class, "gmod_") then return true end
    if class:find("physgun", 1, true) or class:find("camera", 1, true)
        or class:find("tool", 1, true) or class:find("hands", 1, true)
        or class:find("keys", 1, true) or class:find("fists", 1, true) then
        return true
    end

    local gear = ZSCAV and ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) or nil
    local slot = string.lower(string.Trim(tostring(istable(gear) and gear.slot or "")))
    if slot == "world_container" or slot == "mailbox" or slot == "trade_offer" then
        return true
    end

    return false
end

function lib.GetLootCatalogClasses()
    local out = {}
    local seen = {}

    local function add(class)
        class = normalizeLootClass(class)
        if class == "" or seen[class] or shouldSkipLootCatalogClass(class) then
            return
        end

        seen[class] = true
        out[#out + 1] = class
    end

    for class in pairs(ZSCAV and ZSCAV.ItemMeta or {}) do add(class) end
    for class in pairs(ZSCAV and ZSCAV.GearItems or {}) do add(class) end
    for class in pairs(ZSCAV and ZSCAV.ItemSizes or {}) do add(class) end

    for _, wep in ipairs(weapons.GetList() or {}) do
        local class = tostring(wep.ClassName or wep.Classname or "")
        if class ~= "" and ZSCAV and ZSCAV.GetItemSize then
            local size = ZSCAV:GetItemSize(class)
            if istable(size) and tonumber(size.w) and tonumber(size.h) then
                add(class)
            end
        end
    end

    table.sort(out)
    return out
end

local function normalizeLootGroupClasses(classes)
    local allowed = {}
    for _, class in ipairs(lib.GetLootCatalogClasses()) do
        allowed[class] = true
    end

    local out = {}
    local seen = {}
    for _, class in ipairs(istable(classes) and classes or {}) do
        class = normalizeLootClass(class)
        if class ~= "" and not seen[class] and not lib.IsLootGroupToken(class) and allowed[class] then
            seen[class] = true
            out[#out + 1] = class
        end
    end

    table.sort(out)
    return out
end

function lib.NormalizeLootGroupClasses(classes)
    return normalizeLootGroupClasses(classes)
end

function lib.ClassifyLootCatalogClass(class)
    class = normalizeLootClass(class)
    if class == "" then return nil end
    if lib.IsLootGroupToken(class) then return "group" end

    local itemMeta = ZSCAV and ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(class) or nil
    local gearDef = ZSCAV and ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) or nil
    local gearSlot = string.lower(string.Trim(tostring(istable(gearDef) and gearDef.slot or "")))

    if gearSlot == "world_container" then return "container" end
    if gearSlot == "mailbox" or gearSlot == "trade_offer" then return "service" end
    if istable(gearDef) then return "gear" end

    if istable(itemMeta) and itemMeta.valuable == true then
        return "valuable"
    end

    local equipSlot = ZSCAV and ZSCAV.GetEquipWeaponSlot and ZSCAV:GetEquipWeaponSlot(class) or nil
    if equipSlot == "primary" or equipSlot == "sidearm" then
        return "weapon"
    end
    if equipSlot == "grenade" then
        return "grenade"
    end
    if equipSlot == "scabbard" then
        return "melee"
    end
    if equipSlot == "medical" then
        return "medical"
    end

    local category = string.lower(string.Trim(tostring(istable(itemMeta) and itemMeta.category or "")))
    if textContainsAny(category, { "ammo", "round", "magazine", "cartridge" }) then
        return "ammo"
    end
    if textContainsAny(category, { "med", "medical", "medicine", "healing", "health" }) then
        return "medical"
    end
    if textContainsAny(category, { "valuable", "artifact", "treasure" }) then
        return "valuable"
    end

    if string.StartWith(class, "ent_ammo_") or textContainsAny(class, { "ammo", "round", "cartridge" }) then
        return "ammo"
    end

    if textContainsAny(class, {
        "bandage", "tourniquet", "med", "medical", "morphine", "adrenaline",
        "stim", "splint", "afak", "salewa", "medkit", "bloodbag", "clot",
        "pain", "naloxone", "fentanyl", "mannitol", "thiamine"
    }) then
        return "medical"
    end

    return "loot"
end

function lib.GetLootGroupMembers(token)
    local def = lib.GetLootGroupDef(token)
    if not istable(def) then return {} end

    if istable(def.classes) then
        return normalizeLootGroupClasses(def.classes)
    end

    local out = {}
    for _, class in ipairs(lib.GetLootCatalogClasses()) do
        local kind = lib.ClassifyLootCatalogClass(class)
        if def.kinds and def.kinds[kind] then
            out[#out + 1] = class
        end
    end

    table.sort(out)
    return out
end

function lib.GetLootGroupCatalog()
    local out = {}
    local seen = {}

    for _, def in ipairs(LOOT_GROUP_DEFS) do
        local merged = lib.GetLootGroupDef(def.token)
        if istable(merged) then
            merged.count = #lib.GetLootGroupMembers(merged.token)
            out[#out + 1] = merged
            seen[merged.token] = true
        end
    end

    local extras = {}
    for token in pairs(getCustomLootGroupsRaw()) do
        if not seen[token] then
            local def = lib.GetLootGroupDef(token)
            if istable(def) then
                def.count = #lib.GetLootGroupMembers(def.token)
                extras[#extras + 1] = def
            end
        end
    end

    table.sort(extras, function(left, right)
        local leftName = string.lower(tostring(left.label or left.token or ""))
        local rightName = string.lower(tostring(right.label or right.token or ""))
        if leftName == rightName then
            return tostring(left.token or "") < tostring(right.token or "")
        end
        return leftName < rightName
    end)

    for _, def in ipairs(extras) do
        out[#out + 1] = def
    end

    return out
end

function lib.GetSuggestedValuableKeyForModel(model)
    model = lib.NormalizeModel(model)
    if model == "" then return "" end

    local fileName = string.GetFileFromFilename(model or "") or ""
    fileName = string.gsub(fileName, "%.mdl$", "")
    fileName = normalizeToken(fileName)
    if fileName == "" then
        fileName = "prop"
    end

    local hash = string.sub(tostring(util.CRC(model) or "0"), 1, 6)
    return string.Trim(fileName .. "_" .. hash, "_")
end

function lib.GetSuggestedValuableClassForModel(model)
    return lib.GetValuableClass(lib.GetSuggestedValuableKeyForModel(model))
end

function lib.GetSuggestedValuableNameForModel(model)
    model = lib.NormalizeModel(model)
    if model == "" then return "Prop Item" end

    local fileName = string.GetFileFromFilename(model or "") or ""
    fileName = string.gsub(fileName, "%.mdl$", "")
    fileName = string.gsub(fileName, "[_%-]+", " ")
    fileName = string.Trim(fileName)
    if fileName == "" then
        return "Prop Item"
    end

    return string.NiceName(fileName)
end

function lib.GetSavePath()
    return string.format("%s/%s.json", lib.DataSubDir, string.lower(game.GetMap() or "unknown"))
end

function lib.GetValuableClass(key)
    key = normalizeToken(key)
    if key == "" then return "" end
    if string.StartWith(key, "zscav_loot_item_") then
        return key
    end
    return "zscav_loot_item_" .. key
end

function lib.GetPlacedContainerClass(key)
    key = normalizeToken(key)
    if key == "" then return "" end
    if string.StartWith(key, "zscav_loot_container_spawn_") then
        return key
    end
    return "zscav_loot_container_spawn_" .. key
end

function lib.GetModelContainerClass(model)
    model = lib.NormalizeModel(model)
    if model == "" then return "" end
    return "zscav_loot_container_model_" .. tostring(util.CRC(model) or "0")
end

function lib.IsWorldItemClass(class)
    class = string.lower(string.Trim(tostring(class or "")))
    return class ~= "" and string.StartWith(class, "zscav_loot_item_")
end

function lib.IsWorldContainerClass(class)
    class = string.lower(string.Trim(tostring(class or "")))
    return class ~= "" and (
        string.StartWith(class, "zscav_loot_container_spawn_")
        or string.StartWith(class, "zscav_loot_container_model_")
    )
end

function lib.GetState()
    return lib.State or {
        placed_spawns = {},
        model_containers = {},
        valuables = {},
        custom_groups = {},
    }
end

function lib.GetWorldItemDef(class)
    class = string.lower(string.Trim(tostring(class or "")))
    if class == "" then return nil end

    local valuables = lib.GetState().valuables or {}
    return valuables[class]
end

function lib.GetWorldItemDefByModel(model)
    model = lib.NormalizeModel(model)
    if model == "" then return nil end

    return lib.ModelItemIndex and lib.ModelItemIndex[model] or nil
end

function lib.GetModelContainerDefByModel(model)
    model = lib.NormalizeModel(model)
    if model == "" then return nil end

    return lib.ModelContainerIndex and lib.ModelContainerIndex[model] or nil
end

function lib.GetContainerDefByClass(class)
    class = string.lower(string.Trim(tostring(class or "")))
    if class == "" then return nil end

    local state = lib.GetState()

    for _, row in ipairs(state.placed_spawns or {}) do
        if istable(row) and string.lower(string.Trim(tostring(row.container_class or ""))) == class then
            return row
        end
    end

    for _, row in pairs(state.model_containers or {}) do
        if istable(row) and string.lower(string.Trim(tostring(row.container_class or ""))) == class then
            return row
        end
    end

    return nil
end

function lib.GetWorldModelForEntry(entryOrClass)
    if istable(entryOrClass) then
        local explicit = lib.NormalizeModel(entryOrClass.world_model or entryOrClass.model)
        if explicit ~= "" then return explicit end

        local itemClass = tostring(entryOrClass.class or entryOrClass.actual_class or "")
        local itemDef = lib.GetWorldItemDef(itemClass)
        if istable(itemDef) then
            return lib.NormalizeModel(itemDef.model)
        end

        return ""
    end

    local itemDef = lib.GetWorldItemDef(entryOrClass)
    if not istable(itemDef) then return "" end
    return lib.NormalizeModel(itemDef.model)
end

function lib.IsWorldItemEntity(ent)
    return IsValid(ent) and ent:GetClass() == "ent_zscav_world_item"
end

function lib.IsWorldContainerEntity(ent)
    return IsValid(ent) and ent:GetClass() == "ent_zscav_world_container"
end

local function clearInjectedClasses()
    ZSCAV.ItemMeta = ZSCAV.ItemMeta or {}
    ZSCAV.GearItems = ZSCAV.GearItems or {}

    for class in pairs(lib._injectedItemClasses or {}) do
        ZSCAV.ItemMeta[class] = nil
        if SERVER and istable(ZSCAV.ConfiguredItemMetaClasses) then
            ZSCAV.ConfiguredItemMetaClasses[class] = nil
        end
    end

    for class in pairs(lib._injectedGearClasses or {}) do
        ZSCAV.GearItems[class] = nil
        if SERVER and istable(ZSCAV.ConfiguredGearClasses) then
            ZSCAV.ConfiguredGearClasses[class] = nil
        end
    end

    lib._injectedItemClasses = {}
    lib._injectedGearClasses = {}
end

local function injectValuableDefs()
    local valuables = lib.GetState().valuables or {}

    ZSCAV.ItemMeta = ZSCAV.ItemMeta or {}
    if SERVER then
        ZSCAV.ConfiguredItemMetaClasses = ZSCAV.ConfiguredItemMetaClasses or {}
    end

    for class, def in pairs(valuables) do
        class = string.lower(string.Trim(tostring(class or "")))
        if class == "" or not istable(def) then
            continue
        end

        local worldModel = lib.NormalizeModel(def.model)
        if worldModel == "" then
            continue
        end

        ZSCAV.ItemMeta[class] = {
            name = string.Trim(tostring(def.name or string.NiceName(class) or class)),
            w = math.Clamp(math.floor(tonumber(def.w) or 1), 1, 16),
            h = math.Clamp(math.floor(tonumber(def.h) or 1), 1, 16),
            weight = math.max(0, tonumber(def.weight) or 0),
            category = string.Trim(tostring(def.category or "valuable")),
            world_model = worldModel,
            valuable = true,
        }

        lib._injectedItemClasses[class] = true
        if SERVER then
            ZSCAV.ConfiguredItemMetaClasses[class] = true
        end
    end
end

local function injectContainerDefs(rows)
    ZSCAV.GearItems = ZSCAV.GearItems or {}
    if SERVER then
        ZSCAV.ConfiguredGearClasses = ZSCAV.ConfiguredGearClasses or {}
    end

    for _, def in pairs(rows or {}) do
        if not istable(def) then
            continue
        end

        local class = string.lower(string.Trim(tostring(def.container_class or "")))
        local model = lib.NormalizeModel(def.model)
        local grid = istable(def.grid) and def.grid or {}
        local gw = math.Clamp(math.floor(tonumber(grid.w) or tonumber(def.gw) or 4), 1, 32)
        local gh = math.Clamp(math.floor(tonumber(grid.h) or tonumber(def.gh) or 4), 1, 32)
        if class == "" or model == "" then
            continue
        end

        ZSCAV.GearItems[class] = {
            name = string.Trim(tostring(def.label or def.name or "World Loot")),
            slot = "world_container",
            w = 2,
            h = 2,
            weight = 0,
            internal = { w = gw, h = gh },
            virtual = true,
            player_insert_restricted = true,
            world_model = model,
        }

        lib._injectedGearClasses[class] = true
        if SERVER then
            ZSCAV.ConfiguredGearClasses[class] = true
        end
    end
end

function lib.ApplyRuntimeCatalogEntries()
    clearInjectedClasses()
    injectValuableDefs()
    injectContainerDefs(lib.GetState().model_containers or {})
    injectContainerDefs(lib.GetState().placed_spawns or {})
end

local function rebuildModelIndices(state)
    state = istable(state) and state or lib.GetState()

    local itemIndex = {}
    for _, def in pairs(state.valuables or {}) do
        local model = lib.NormalizeModel(istable(def) and def.model or "")
        if model ~= "" and istable(def) then
            itemIndex[model] = def
        end
    end

    local containerIndex = {}
    for key, def in pairs(state.model_containers or {}) do
        local model = lib.NormalizeModel((istable(def) and def.model) or key)
        if model ~= "" and istable(def) then
            containerIndex[model] = def
        end
    end

    lib.ModelItemIndex = itemIndex
    lib.ModelContainerIndex = containerIndex
end

function lib.SetState(state)
    state = istable(state) and state or {}

    lib.State = {
        placed_spawns = istable(state.placed_spawns) and state.placed_spawns or {},
        model_containers = istable(state.model_containers) and state.model_containers or {},
        valuables = istable(state.valuables) and state.valuables or {},
        custom_groups = istable(state.custom_groups) and state.custom_groups or {},
    }

    rebuildModelIndices(lib.State)
    lib.ApplyRuntimeCatalogEntries()
end

if CLIENT then
    net.Receive(lib.Net.Sync, function()
        local raw = net.ReadString() or "{}"
        local decoded = util.JSONToTable(raw) or {}
        lib.SetState(decoded)
        hook.Run("ZScavWorldLoot_ClientUpdated", lib.GetState())
    end)
end