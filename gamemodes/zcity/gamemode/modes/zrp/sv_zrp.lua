-- sv_zrp.lua — ZRP server logic: respawns, containers, loot table, staff commands.

local MODE = MODE

-- ── Constants ─────────────────────────────────────────────────────────────────

local RESPAWN_DELAY       = 10     -- seconds after death before respawn
local CONTAINER_RESET_TIME   = 900   -- 15 min: time after looting before container resets
local CONTAINER_RESPAWN_TIME = 900   -- 15 min: time after destruction before container respawns
local LOOT_DATA_PATH      = "zbattle/zrp/loottable.json"
local LOOT_PROFILE_DATA_PATH = "zbattle/zrp/lootprofiles.json"
local BUILD_DATA_PATH     = "zbattle/zrp/build_data.json"
local CONTAINER_DIR       = "zbattle/zrp/containers"
local INVENTORY_BACKUP_PATH = "zbattle/zrp/inventory_backup.json"
local INVENTORY_BACKUP_INTERVAL = 30
local INVENTORY_SQL_TABLE = "zc_zrp_inventory_backup"
local ZRP_DEFAULT_PLAYERCLASS = "Refugee"

-- ── Loot Table ────────────────────────────────────────────────────────────────
-- weight, entity class. Clients never see this table (only the editor panel does).

ZRP.DEFAULT_LOOT_TABLE = {
    -- Melee / Utility
    { 8, "weapon_hg_crowbar" },
    { 6, "weapon_leadpipe" },
    { 5, "weapon_tomahawk" },
    { 4, "weapon_hatchet" },
    { 3, "weapon_hg_axe" },
    -- Pistols
    { 9, "weapon_glock18c" },
    { 8, "weapon_hk_usp" },
    { 7, "weapon_revolver357" },
    { 6, "weapon_deagle" },
    -- SMGs
    { 7, "weapon_mp5" },
    { 5, "weapon_mp7" },
    -- Shotguns
    { 6, "weapon_remington870" },
    { 5, "weapon_doublebarrel" },
    { 4, "weapon_doublebarrel_short" },
    -- Rifles
    { 5, "weapon_sks" },
    { 4, "weapon_akm" },
    { 3, "weapon_m4a1" },
    { 2, "weapon_sr25" },
    { 1, "weapon_m98b" },
    -- Explosives
    { 5, "weapon_hg_grenade_tpik" },
    { 4, "weapon_hg_molotov_tpik" },
    { 3, "weapon_hg_pipebomb_tpik" },
    { 2, "weapon_claymore" },
    { 2, "weapon_hg_slam" },
    -- Medical
    { 10, "weapon_bandage_sh" },
    { 9,  "weapon_tourniquet" },
    { 8,  "weapon_painkillers" },
    { 6,  "weapon_bigbandage_sh" },
    { 5,  "weapon_medkit_sh" },
    { 4,  "weapon_bloodbag" },
    { 3,  "weapon_afak_sh" },
    -- Armor
    { 7, "ent_armor_vest1" },
    { 6, "ent_armor_vest2" },
    { 5, "ent_armor_vest3" },
    { 3, "ent_armor_vest4" },
    { 6, "ent_armor_helmet1" },
    { 4, "ent_armor_helmet2" },
    -- Ammo
    { 10, "ent_ammo_9x19mmparabellum" },
    { 8,  "ent_ammo_4.6x30mm" },
    { 8,  "ent_ammo_12/70gauge" },
    { 7,  "ent_ammo_5.56x45mm" },
    { 6,  "ent_ammo_7.62x39mm" },
    { 5,  "ent_ammo_.357magnum" },
    { 5,  "ent_ammo_7.62x51mm" },
}

-- ── Runtime loot state ────────────────────────────────────────────────────────
-- Loaded from disk; staff can modify via loot editor.

ZRP.LootData = {
    items     = {},   -- { {weight, class}, ... } — overrides DEFAULT_LOOT_TABLE when non-empty
    blacklist = {},   -- [class] = true → never spawns
    whitelist = {},   -- [class] = true → ONLY these spawn when table non-empty
}
ZRP.PropLootProfiles = ZRP.PropLootProfiles or {}

local function SanitizeLootClass(className)
    className = string.lower(string.Trim(tostring(className or "")))
    if string.match(className, "^%*[%w_]+%*$") then
        return className
    end
    return string.gsub(className, "[^%w_/]", "")
end

local function AddUnique(tbl, className)
    if not className or className == "" then return end
    if tbl[className] then return end
    tbl[className] = true
end

local function ToSortedArray(setTbl)
    local out = {}
    for className in pairs(setTbl or {}) do
        out[#out + 1] = className
    end
    table.sort(out)
    return out
end

local function IsWeaponMedicine(className)
    return string.find(className, "med", 1, true)
        or string.find(className, "bandage", 1, true)
        or string.find(className, "tourniquet", 1, true)
        or string.find(className, "morphine", 1, true)
        or string.find(className, "fentanyl", 1, true)
        or string.find(className, "adrenaline", 1, true)
        or string.find(className, "painkiller", 1, true)
end

local function BuildRegisteredLootGroupsInternal()
    local groups = {
        vests = {}, helmets = {}, armor = {},
        medicine = {},
        pistols = {}, machinepistols = {}, smgs = {},
        assaultrifles = {}, rifles = {}, shotguns = {}, snipers = {}, lmgs = {},
        explosives = {}, melee = {},
        ammo = {}, attachments = {},
        weapons = {},
    }

    for className, _ in pairs(scripted_ents.GetList() or {}) do
        className = string.lower(tostring(className or ""))
        if className == "" then continue end

        if string.StartWith(className, "ent_armor_") then
            AddUnique(groups.armor, className)
            if string.find(className, "vest", 1, true) then AddUnique(groups.vests, className) end
            if string.find(className, "helmet", 1, true) then AddUnique(groups.helmets, className) end
        end

        if string.StartWith(className, "ent_ammo_") then AddUnique(groups.ammo, className) end
        if string.StartWith(className, "ent_att_") then AddUnique(groups.attachments, className) end
    end

    for _, wep in ipairs(weapons.GetList() or {}) do
        local className = string.lower(tostring(wep.ClassName or wep.Classname or ""))
        if className == "" then continue end
        if not string.StartWith(className, "weapon_") then continue end

        AddUnique(groups.weapons, className)

        if IsWeaponMedicine(className) then
            AddUnique(groups.medicine, className)
            continue
        end

        if string.find(className, "grenade", 1, true)
            or string.find(className, "molotov", 1, true)
            or string.find(className, "claymore", 1, true)
            or string.find(className, "rpg", 1, true)
            or string.find(className, "slam", 1, true)
            or string.find(className, "ied", 1, true)
            or string.find(className, "pipebomb", 1, true)
            or string.find(className, "f1", 1, true) then
            AddUnique(groups.explosives, className)
            continue
        end

        if string.find(className, "crowbar", 1, true)
            or string.find(className, "axe", 1, true)
            or string.find(className, "hatchet", 1, true)
            or string.find(className, "knife", 1, true)
            or string.find(className, "tomahawk", 1, true)
            or string.find(className, "leadpipe", 1, true)
            or string.find(className, "melee", 1, true) then
            AddUnique(groups.melee, className)
            continue
        end

        if string.find(className, "shotgun", 1, true)
            or string.find(className, "xm1014", 1, true)
            or string.find(className, "remington", 1, true)
            or string.find(className, "doublebarrel", 1, true)
            or string.find(className, "winchester", 1, true) then
            AddUnique(groups.shotguns, className)
            continue
        end

        if string.find(className, "sniper", 1, true)
            or string.find(className, "m98", 1, true)
            or string.find(className, "sr25", 1, true)
            or string.find(className, "mosin", 1, true)
            or string.find(className, "svd", 1, true)
            or string.find(className, "awp", 1, true)
            or string.find(className, "mini14", 1, true) then
            AddUnique(groups.snipers, className)
            AddUnique(groups.rifles, className)
            continue
        end

        if string.find(className, "pkm", 1, true)
            or string.find(className, "m249", 1, true)
            or string.find(className, "rpk", 1, true)
            or string.find(className, "m60", 1, true) then
            AddUnique(groups.lmgs, className)
            continue
        end

        if string.find(className, "pistol", 1, true)
            or string.find(className, "revolver", 1, true)
            or string.find(className, "deagle", 1, true)
            or string.find(className, "usp", 1, true)
            or string.find(className, "glock", 1, true)
            or string.find(className, "beretta", 1, true)
            or string.find(className, "cz", 1, true)
            or string.find(className, "p22", 1, true)
            or string.find(className, "px4", 1, true)
            or string.find(className, "flintlock", 1, true) then
            AddUnique(groups.pistols, className)
            continue
        end

        if string.find(className, "skorpion", 1, true)
            or string.find(className, "tec9", 1, true)
            or string.find(className, "machinepistol", 1, true)
            or string.find(className, "vz61", 1, true) then
            AddUnique(groups.machinepistols, className)
            AddUnique(groups.smgs, className)
            continue
        end

        if string.find(className, "smg", 1, true)
            or string.find(className, "mp5", 1, true)
            or string.find(className, "mp7", 1, true)
            or string.find(className, "vector", 1, true)
            or string.find(className, "uzi", 1, true)
            or string.find(className, "mac10", 1, true) then
            AddUnique(groups.smgs, className)
            continue
        end

        if string.find(className, "ak", 1, true)
            or string.find(className, "m4", 1, true)
            or string.find(className, "hk416", 1, true)
            or string.find(className, "sg552", 1, true)
            or string.find(className, "asval", 1, true)
            or string.find(className, "ac556", 1, true)
            or string.find(className, "qbz", 1, true)
            or string.find(className, "lr300", 1, true)
            or string.find(className, "mk18", 1, true)
            or string.find(className, "famas", 1, true)
            or string.find(className, "galil", 1, true)
            or string.find(className, "scar", 1, true)
            or string.find(className, "sks", 1, true) then
            AddUnique(groups.assaultrifles, className)
            AddUnique(groups.rifles, className)
            continue
        end

        AddUnique(groups.rifles, className)
    end

    local out = {}
    for groupName, setTbl in pairs(groups) do
        out[groupName] = ToSortedArray(setTbl)
    end

    out.tokens = {
        ["*ammo*"] = "random ammo entity",
        ["*attachments*"] = "random attachment",
        ["*sight*"] = "random sight attachment",
        ["*barrel*"] = "random barrel attachment",
        ["*vests*"] = "random armor vest",
        ["*helmets*"] = "random armor helmet",
        ["*armor*"] = "random vest or helmet",
        ["*medicine*"] = "random medical weapon",
        ["*pistols*"] = "random pistol",
        ["*machinepistols*"] = "random machine pistol",
        ["*smgs*"] = "random SMG",
        ["*assaultrifles*"] = "random assault rifle",
        ["*rifles*"] = "random rifle",
        ["*shotguns*"] = "random shotgun",
        ["*snipers*"] = "random sniper rifle",
        ["*lmgs*"] = "random LMG",
        ["*explosives*"] = "random explosive weapon",
        ["*melee*"] = "random melee weapon",
    }

    return out
end

function ZRP.BuildRegisteredLootGroups()
    return BuildRegisteredLootGroupsInternal()
end

local function ResolveLootTokenClass(token)
    token = string.lower(string.Trim(tostring(token or "")))
    local groups = BuildRegisteredLootGroupsInternal()

    local tokenMap = {
        ["*vests*"] = "vests",
        ["*helmets*"] = "helmets",
        ["*armor*"] = "armor",
        ["*medicine*"] = "medicine",
        ["*pistols*"] = "pistols",
        ["*machinepistols*"] = "machinepistols",
        ["*smgs*"] = "smgs",
        ["*assaultrifles*"] = "assaultrifles",
        ["*rifles*"] = "rifles",
        ["*shotguns*"] = "shotguns",
        ["*snipers*"] = "snipers",
        ["*lmgs*"] = "lmgs",
        ["*explosives*"] = "explosives",
        ["*melee*"] = "melee",
    }

    local groupName = tokenMap[token]
    if not groupName then return nil end

    local choices = groups[groupName] or {}
    if #choices == 0 then return nil end

    return choices[math.random(#choices)]
end

local function SanitizeLootModel(model)
    model = string.lower(string.Trim(tostring(model or "")))
    return string.gsub(model, "[^%w%._/-]", "")
end

local function ParseLootTarget(target)
    target = string.Trim(tostring(target or ""))
    local lowerTarget = string.lower(target)

    if lowerTarget == "" then
        return "global", nil, nil
    end

    if string.StartWith(lowerTarget, "container:") then
        local containerId = tonumber(string.Trim(string.sub(lowerTarget, 11)))
        if not containerId then return nil, nil, nil end
        return "container", containerId, "container:" .. math.floor(containerId)
    end

    if string.StartWith(lowerTarget, "model:") then
        lowerTarget = string.sub(lowerTarget, 7)
    end

    local model = SanitizeLootModel(lowerTarget)
    if model == "" then return nil, nil, nil end
    return "model", model, model
end

local function NormalizeLootData(data)
    data = data or {}

    local out = {
        items = {},
        blacklist = {},
        whitelist = {},
    }

    for _, entry in ipairs(data.items or {}) do
        local weight = math.Clamp(tonumber(entry[1]) or 0, 1, 255)
        local className = SanitizeLootClass(entry[2])
        if className ~= "" then
            out.items[#out.items + 1] = { weight, className }
        end
    end

    for className, state in pairs(data.blacklist or {}) do
        className = SanitizeLootClass(className)
        if state and className ~= "" then
            out.blacklist[className] = true
        end
    end

    for className, state in pairs(data.whitelist or {}) do
        className = SanitizeLootClass(className)
        if state and className ~= "" then
            out.whitelist[className] = true
        end
    end

    return out
end

local function LootDataHasCustomState(data)
    data = data or {}
    return (#(data.items or {}) > 0)
        or (next(data.blacklist or {}) ~= nil)
        or (next(data.whitelist or {}) ~= nil)
end

local function NormalizeTargetLootData(data)
    if not istable(data) then
        return NormalizeLootData(nil)
    end

    if istable(data.items) or istable(data.blacklist) or istable(data.whitelist) then
        return NormalizeLootData(data)
    end

    return NormalizeLootData({ items = data })
end

-- ── Utility: weighted random ───────────────────────────────────────────────────

local function WeightedRandom(tbl)
    local total = 0
    for _, e in ipairs(tbl) do total = total + e[1] end
    if total == 0 then return nil end
    local r = math.random() * total
    local cum = 0
    for _, e in ipairs(tbl) do
        cum = cum + e[1]
        if r <= cum then return e[2] end
    end
    return tbl[#tbl][2]
end

local function BuildEffectiveLootPoolFromData(lootData, fallbackPool)
    lootData = NormalizeLootData(lootData)
    local base = (#lootData.items > 0) and lootData.items or (fallbackPool or ZRP.DEFAULT_LOOT_TABLE)
    local hasWhitelist = next(lootData.whitelist) ~= nil
    local out = {}

    for _, entry in ipairs(base) do
        local className = SanitizeLootClass(entry[2])
        if className == "" then continue end
        if hasWhitelist and not lootData.whitelist[className] then continue end
        if lootData.blacklist[className] then continue end
        out[#out + 1] = { math.Clamp(tonumber(entry[1]) or 0, 1, 255), className }
    end

    return out
end

-- Build the effective loot pool (applying whitelist/blacklist).
function ZRP.BuildEffectiveLootPool()
    ZRP.LootData = NormalizeLootData(ZRP.LootData)
    return BuildEffectiveLootPoolFromData(ZRP.LootData, ZRP.DEFAULT_LOOT_TABLE)
end

function ZRP.GetLootProfile(model, createIfMissing)
    model = SanitizeLootModel(model)
    if model == "" then return nil end

    ZRP.PropLootProfiles = ZRP.PropLootProfiles or {}
    if createIfMissing and not ZRP.PropLootProfiles[model] then
        ZRP.PropLootProfiles[model] = NormalizeLootData(nil)
    end

    local profile = ZRP.PropLootProfiles[model]
    if not profile then return nil end

    ZRP.PropLootProfiles[model] = NormalizeLootData(profile)
    return ZRP.PropLootProfiles[model], model
end

function ZRP.GetEffectiveLootPoolForModel(model, overrideData)
    local profile = ZRP.GetLootProfile(model, false)
    local globalPool = ZRP.BuildEffectiveLootPool()
    local profilePool = (profile and LootDataHasCustomState(profile))
        and BuildEffectiveLootPoolFromData(profile, globalPool)
        or globalPool

    if overrideData then
        local normalizedOverride = NormalizeTargetLootData(overrideData)
        if LootDataHasCustomState(normalizedOverride) then
            return BuildEffectiveLootPoolFromData(normalizedOverride, profilePool)
        end
    end

    if profile and LootDataHasCustomState(profile) then
        return profilePool
    end

    return globalPool
end

-- Pick one item from the effective loot pool.  Returns entity class or nil.
function ZRP.PickLootItem(overrideData, model)
    local pool = ZRP.GetEffectiveLootPoolForModel(model, overrideData)
    if #pool == 0 then return nil end
    return WeightedRandom(pool)
end

-- ── Loot persistence ──────────────────────────────────────────────────────────

local function EnsureZRPDir()
    if not file.Exists("zbattle", "DATA") then file.CreateDir("zbattle") end
    if not file.Exists("zbattle/zrp", "DATA") then file.CreateDir("zbattle/zrp") end
    if not file.Exists(CONTAINER_DIR, "DATA") then file.CreateDir(CONTAINER_DIR) end
end

function ZRP.SaveLootData()
    EnsureZRPDir()
    file.Write(LOOT_DATA_PATH, util.TableToJSON(ZRP.LootData, true))
    print("[ZRP] Loot data saved.")
end

function ZRP.LoadLootData()
    EnsureZRPDir()
    local raw = file.Read(LOOT_DATA_PATH, "DATA")
    if not raw or raw == "" then return end
    local t = util.JSONToTable(raw)
    if not t then return end
    ZRP.LootData = NormalizeLootData(t)
    print("[ZRP] Loot data loaded (" .. #ZRP.LootData.items .. " custom items).")
end

function ZRP.SaveLootProfiles()
    EnsureZRPDir()

    local out = {}
    for model, data in pairs(ZRP.PropLootProfiles or {}) do
        model = SanitizeLootModel(model)
        if model == "" then continue end
        data = NormalizeLootData(data)
        if LootDataHasCustomState(data) then
            out[model] = data
        end
    end

    ZRP.PropLootProfiles = out
    file.Write(LOOT_PROFILE_DATA_PATH, util.TableToJSON(out, true))
    print("[ZRP] Loot profiles saved (" .. table.Count(out) .. " models).")
end

function ZRP.LoadLootProfiles()
    EnsureZRPDir()
    ZRP.PropLootProfiles = {}

    local raw = file.Read(LOOT_PROFILE_DATA_PATH, "DATA")
    if not raw or raw == "" then return end

    local decoded = util.JSONToTable(raw)
    if not istable(decoded) then return end

    for model, data in pairs(decoded) do
        model = SanitizeLootModel(model)
        if model == "" then continue end
        local normalized = NormalizeLootData(data)
        if LootDataHasCustomState(normalized) then
            ZRP.PropLootProfiles[model] = normalized
        end
    end

    print("[ZRP] Loot profiles loaded (" .. table.Count(ZRP.PropLootProfiles) .. " models).")
end

local function GetLootRollCountForModel(model)
    local normalizedModel = SanitizeLootModel(model)
    local lootBoxData = normalizedModel ~= "" and hg and hg.loot_boxes and hg.loot_boxes[normalizedModel] or nil
    local bucket = istable(lootBoxData) and tonumber(lootBoxData[1]) or nil
    local amountRange = bucket and hg and hg.loot_amount and hg.loot_amount[bucket] or nil

    if istable(amountRange) then
        return math.random(amountRange[1], amountRange[2])
    end

    return math.random(1, 3)
end

local function EnsureInventoryTables(ent)
    ent.inventory = ent.inventory or {}
    ent.inventory.Weapons = ent.inventory.Weapons or {}
    ent.inventory.Ammo = ent.inventory.Ammo or {}
    ent.inventory.Armor = ent.inventory.Armor or {}
    ent.inventory.Attachments = ent.inventory.Attachments or {}
    ent.armors = ent.armors or {}
end

local function AddClassToContainerInventory(ent, className)
    className = SanitizeLootClass(className)
    if className == "" then return false end

    EnsureInventoryTables(ent)

    if className == "*ammo*" then
        if not (hg and hg.ammoents) then return false end
        local keys = table.GetKeys(hg.ammoents)
        if not keys or #keys == 0 then return false end
        className = "ent_ammo_" .. tostring(keys[math.random(#keys)] or "")
        if className == "ent_ammo_" then return false end
    elseif className == "*attachments*" then
        if not (hg and hg.validattachments) then return false end
        local groups = table.GetKeys(hg.validattachments)
        local pickedGroup = groups and groups[math.random(#groups)]
        local pickedTbl = pickedGroup and hg.validattachments[pickedGroup]
        local attKeys = istable(pickedTbl) and table.GetKeys(pickedTbl) or nil
        local pickedAtt = attKeys and attKeys[math.random(#attKeys)]
        if not pickedAtt then return false end
        className = "ent_att_" .. pickedAtt
    elseif className == "*sight*" then
        local sightTbl = hg and hg.validattachments and hg.validattachments.sight
        local attKeys = istable(sightTbl) and table.GetKeys(sightTbl) or nil
        local pickedAtt = attKeys and attKeys[math.random(#attKeys)]
        if not pickedAtt then return false end
        className = "ent_att_" .. pickedAtt
    elseif className == "*barrel*" then
        local barrelTbl = hg and hg.validattachments and hg.validattachments.barrel
        local attKeys = istable(barrelTbl) and table.GetKeys(barrelTbl) or nil
        local pickedAtt = attKeys and attKeys[math.random(#attKeys)]
        if not pickedAtt then return false end
        className = "ent_att_" .. pickedAtt
    elseif string.match(className, "^%*[%w_]+%*$") then
        local resolved = ResolveLootTokenClass(className)
        if not resolved then return false end
        className = resolved
    end

    if string.StartWith(className, "weapon_") then
        -- Weapons are keyed by class name, so re-rolling the same class would
        -- silently overwrite an existing slot while the caller's counter still
        -- ticks up. Reject duplicates so the generator keeps trying until it
        -- actually fills `rolls` distinct weapons (within its retry budget).
        if ent.inventory.Weapons[className] ~= nil then return false end
        local weapon = weapons.Get(className)
        ent.inventory.Weapons[className] = weapon and weapon.GetInfo and weapon:GetInfo() or true
        return true
    end

    if string.StartWith(className, "ent_ammo_") then
        local ammoName = string.sub(className, 10)
        local ammoType = hg and hg.ammotypeshuy and hg.ammotypeshuy[ammoName]
        local resolvedAmmoName = ammoType and ammoType.name or ammoName
        local ammoId = game.GetAmmoID(resolvedAmmoName)
        if not ammoId or ammoId == -1 then return false end

        local maxCount = 30
        if hg and hg.ammoents and hg.ammoents[ammoName] and hg.ammoents[ammoName].Count then
            maxCount = hg.ammoents[ammoName].Count
        end

        ent.inventory.Ammo[ammoId] = (ent.inventory.Ammo[ammoId] or 0) + math.random(maxCount)
        return true
    end

    if string.StartWith(className, "ent_armor_") then
        local armorName = string.sub(className, 11)
        if not (hg and hg.AddArmor) then return false end
        hg.AddArmor(ent, armorName)
        return true
    end

    if string.StartWith(className, "ent_att_") then
        ent.inventory.Attachments[#ent.inventory.Attachments + 1] = string.sub(className, 9)
        return true
    end

    return false
end

function ZRP.IsInventoryEmpty(inventory, armors)
    for _, entries in pairs(inventory or {}) do
        for _, value in pairs(entries or {}) do
            if value ~= nil then
                return false
            end
        end
    end

    for _, value in pairs(armors or {}) do
        if value ~= nil then
            return false
        end
    end

    return true
end

function ZRP.ClearContainerInventory(ent)
    if not IsValid(ent) then return end

    ent.inventory = nil
    ent.armors = {}
    ent.ZRP_LootGenerated = false

    ent:SetNetVar("Inventory", nil)
    ent:SetNetVar("Armor", {})
end

function ZRP.GenerateContainerInventory(ent, model, overrideData)
    if not IsValid(ent) then return false end

    EnsureInventoryTables(ent)
    ent.inventory.Weapons = {}
    ent.inventory.Ammo = {}
    ent.inventory.Armor = {}
    ent.inventory.Attachments = {}
    ent.armors = {}

    local pool = ZRP.GetEffectiveLootPoolForModel(model, overrideData)
    if #pool == 0 then
        ent:SetNetVar("Inventory", ent.inventory)
        ent:SetNetVar("Armor", ent.armors)
        ent.ZRP_LootGenerated = true
        return false
    end

    local rolls = GetLootRollCountForModel(model)

    -- Per-entity max-items cap (set by event mode's per-model loot caps).
    -- Lets admins make small props (e.g. duffel bags) yield only 2-3 items
    -- while large props (lockers, crates) keep their bigger payload.
    --
    -- When a max is set, we also honour a minimum so big containers actually
    -- spawn a meaningful amount of loot rather than the default 1-3 roll.
    -- Min defaults to ceil(max/2) (or an explicit ZRP_LootMinItems override).
    local maxItems = tonumber(ent.ZRP_LootMaxItems)
    local minItems = tonumber(ent.ZRP_LootMinItems)

    -- Fall back to the live event MODE-table caps so paths that build
    -- inventory without going through MODE:RefreshContainerLoot (admin refill
    -- button, AdoptSpawnedContainerProp, ZRP_WorldContainerUse lazy-fill,
    -- container reset timer) still respect the per-model min/max.
    if (not maxItems or maxItems <= 0) and isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) and istable(round.ModelLootCaps) then
            local mdlKey = string.lower(string.Trim(tostring(model or "")))
            if mdlKey ~= "" then
                maxItems = tonumber(round.ModelLootCaps[mdlKey])
                if not minItems and istable(round.ModelLootMins) then
                    minItems = tonumber(round.ModelLootMins[mdlKey])
                end
            end
        end
    end

    if maxItems and maxItems > 0 then
        if not minItems or minItems <= 0 then
            minItems = math.ceil(maxItems / 2)
        end
        if minItems > maxItems then minItems = maxItems end
        if minItems < 1 then minItems = 1 end
        rolls = math.random(minItems, maxItems)
    end

    -- Generous retry budget so high `rolls` values still fill containers when
    -- the loot pool is small relative to rolls (each duplicate weapon class
    -- now returns false instead of silently overwriting).
    local attempts = math.max(rolls * 24, math.max(#pool * 4, 24))
    local added = 0

    for _ = 1, attempts do
        if added >= rolls then break end
        local className = WeightedRandom(pool)
        if className and AddClassToContainerInventory(ent, className) then
            added = added + 1
        end
    end

    -- If random picks missed due to unsupported classes in the pool, force-fill
    -- from the first valid classes so containers never stay empty when valid
    -- entries exist.
    if added == 0 then
        for _, entry in ipairs(pool) do
            local className = entry[2]
            if className and AddClassToContainerInventory(ent, className) then
                added = added + 1
                break
            end
        end
    end

    ent.ZRP_LootGenerated = true
    ent:SetNetVar("Armor", ent.armors)
    ent:SetNetVar("Inventory", ent.inventory)

    return not ZRP.IsInventoryEmpty(ent.inventory, ent.armors)
end

function ZRP.SaveBuildData()
    EnsureZRPDir()
    file.Write(BUILD_DATA_PATH, util.TableToJSON({
        propWhitelist = ZRP.BuildPropWhitelist or {},
        propBlacklist = ZRP.BuildPropBlacklist or {},
        toolWhitelist = ZRP.BuildToolWhitelist or {},
        propertyWhitelist = ZRP.BuildPropertyWhitelist or {},
        buddyLists = ZRP.BuildBuddyLists or {},
    }, true))
    print("[ZRP] Build data saved.")
end

function ZRP.LoadBuildData()
    EnsureZRPDir()
    local raw = file.Read(BUILD_DATA_PATH, "DATA")
    if not raw or raw == "" then return end

    local t = util.JSONToTable(raw)
    if not t then return end

    if istable(t.propWhitelist) then
        ZRP.BuildPropWhitelist = t.propWhitelist
    end

    if istable(t.propBlacklist) then
        ZRP.BuildPropBlacklist = t.propBlacklist
    end

    if istable(t.toolWhitelist) then
        ZRP.BuildToolWhitelist = t.toolWhitelist
    end

    if istable(t.propertyWhitelist) then
        ZRP.BuildPropertyWhitelist = t.propertyWhitelist
    end

    if istable(t.buddyLists) then
        ZRP.BuildBuddyLists = t.buddyLists
    end

    print("[ZRP] Build data loaded.")
end

-- ── Container registry ────────────────────────────────────────────────────────
-- ZRP.Containers[id] = { model, pos, ang, respawnDelay, lootOverride }
-- ZRP.ActiveContainers[id] = entity (zrp_container)

ZRP.Containers = {}

local function ContainerPath()
    return CONTAINER_DIR .. "/" .. game.GetMap() .. ".json"
end

local function NormalizeContainerLootData(cfg)
    if not istable(cfg) then return NormalizeLootData(nil) end

    local source = cfg.lootData
    if not source and istable(cfg.lootOverride) and #cfg.lootOverride > 0 then
        source = { items = cfg.lootOverride }
    end

    local normalized = NormalizeTargetLootData(source)
    cfg.lootData = normalized
    cfg.lootOverride = normalized.items
    return normalized
end

function ZRP.SaveContainers()
    EnsureZRPDir()
    -- Serialise vectors/angles as arrays for JSON.
    local out = {}
    for id, cfg in ipairs(ZRP.Containers) do
        out[id] = {
            model        = cfg.model,
            pos          = { cfg.pos.x, cfg.pos.y, cfg.pos.z },
            ang          = { cfg.ang.p, cfg.ang.y, cfg.ang.r },
            respawnDelay = cfg.respawnDelay,
            enabled      = (cfg.enabled ~= false),
            lootData     = NormalizeContainerLootData(cfg),
            lootOverride = (cfg.lootData and cfg.lootData.items) or {},
        }
    end
    file.Write(ContainerPath(), util.TableToJSON(out, true))
    print("[ZRP] Container list saved (" .. #out .. " containers).")
end

function ZRP.LoadContainers()
    EnsureZRPDir()
    ZRP.Containers = {}
    local raw = file.Read(ContainerPath(), "DATA")
    if not raw or raw == "" then return end
    local t = util.JSONToTable(raw)
    if not t then return end
    for _, cfg in ipairs(t) do
        local p = cfg.pos or {0,0,0}
        local a = cfg.ang or {0,0,0}
        ZRP.Containers[#ZRP.Containers + 1] = {
            model        = cfg.model or "models/props_junk/wood_crate001a.mdl",
            pos          = Vector(p[1], p[2], p[3]),
            ang          = Angle(a[1], a[2], a[3]),
            respawnDelay = cfg.respawnDelay,
            enabled      = (cfg.enabled ~= false),
            lootData     = NormalizeTargetLootData(cfg.lootData or { items = cfg.lootOverride or {} }),
            lootOverride = nil,
        }
        local loadedCfg = ZRP.Containers[#ZRP.Containers]
        loadedCfg.lootOverride = loadedCfg.lootData.items
    end
    print("[ZRP] Containers loaded (" .. #ZRP.Containers .. " containers for " .. game.GetMap() .. ").")
end

-- ── Container spawning ────────────────────────────────────────────────────────

ZRP.ActiveContainers = {}
ZRP.InventoryBackup = ZRP.InventoryBackup or {}
ZRP.InventorySQLReady = ZRP.InventorySQLReady or false
ZRP.SessionPlayerClasses = ZRP.SessionPlayerClasses or {}
ZRP.PlayerJobIds = ZRP.PlayerJobIds or {}
ZRP.JobPlayerClassMap = ZRP.JobPlayerClassMap or {}
local GetRandomSafeSpawn

local function IsZRPRoundActive()
    return zb and zb.ROUND_STATE == 1 and zb.CROUND == "zrp"
end

ZRP.BuildAccess = ZRP.BuildAccess or {}
ZRP.BuildPropWhitelist = ZRP.BuildPropWhitelist or {
    ["models/props_c17/furniturestove001a.mdl"] = true,
    ["models/props_c17/furnituredrawer001a.mdl"] = true,
    ["models/props_c17/furnituredrawer003a.mdl"] = true,
    ["models/props_c17/furnituretable001a.mdl"] = true,
    ["models/props_c17/furnituretable002a.mdl"] = true,
    ["models/props_c17/furniturechair001a.mdl"] = true,
    ["models/props_c17/furniturecouch001a.mdl"] = true,
    ["models/props_c17/furniturefridge001a.mdl"] = true,
    ["models/props_c17/oildrum001.mdl"] = true,
    ["models/props_c17/woodbarrel001.mdl"] = true,
    ["models/props_c17/woodencrate001a.mdl"] = true,
    ["models/props_junk/wood_crate001a.mdl"] = true,
    ["models/props_junk/cardboard_box001a.mdl"] = true,
    ["models/props_junk/cardboard_box002a.mdl"] = true,
    ["models/props_debris/wood_board04a.mdl"] = true,
    ["models/props_debris/wood_board05a.mdl"] = true,
    ["models/props_debris/wood_board06a.mdl"] = true,
    ["models/props_wasteland/kitchen_counter001d.mdl"] = true,
    ["models/props_wasteland/controlroom_chair001a.mdl"] = true,
    ["models/props_wasteland/laundry_cart001.mdl"] = true,
}

ZRP.BuildPropBlacklist = ZRP.BuildPropBlacklist or {}

ZRP.BuildToolWhitelist = ZRP.BuildToolWhitelist or {
    ["remover"] = true,
    ["weld"] = true,
    ["axis"] = true,
    ["ballsocket"] = true,
    ["rope"] = true,
    ["nocollide"] = true,
    ["material"] = true,
    ["color"] = true,
    ["light"] = true,
    ["lamp"] = true,
}

ZRP.BuildPropertyWhitelist = ZRP.BuildPropertyWhitelist or {
    ["remover"] = true,
    ["collision"] = true,
    ["bodygroups"] = true,
    ["skin"] = true,
    ["persist"] = true,
}

ZRP.BuildBuddyLists = ZRP.BuildBuddyLists or {}

local function NormalizeBuildKey(value)
    value = string.Trim(string.lower(tostring(value or "")))
    if value == "" then return nil end
    return value
end

local function GetBuildAccessKey(ply)
    if not IsValid(ply) then return nil end
    local sid = ply:SteamID64() or ply:SteamID()
    if not sid or sid == "" then return nil end
    return sid
end

local function IsBuildPropWhitelisted(model)
    local key = NormalizeBuildKey(model)
    if not key then return false end
    return ZRP.BuildPropWhitelist[key] == true
end

local function IsBuildPropBlacklisted(model)
    local key = NormalizeBuildKey(model)
    if not key then return false end
    return ZRP.BuildPropBlacklist[key] == true
end

local function IsBuildToolWhitelisted(tool)
    local key = NormalizeBuildKey(tool)
    if not key then return false end
    return ZRP.BuildToolWhitelist[key] == true
end

local function IsBuildPropertyWhitelisted(property)
    local key = NormalizeBuildKey(property)
    if not key then return false end
    return ZRP.BuildPropertyWhitelist[key] == true
end

local function GetBuddyOwnerList(ownerKey)
    if not ownerKey then return nil end
    local list = ZRP.BuildBuddyLists[ownerKey]
    if not istable(list) then
        list = {}
        ZRP.BuildBuddyLists[ownerKey] = list
    end
    return list
end

function ZRP.SetBuildBuddyState(ownerPly, targetPly, enabled)
    local ownerKey = GetBuildAccessKey(ownerPly)
    local targetKey = isstring(targetPly)
        and string.Trim(tostring(targetPly))
        or GetBuildAccessKey(targetPly)
    if not ownerKey or not targetKey or ownerKey == targetKey then return false end

    local list = GetBuddyOwnerList(ownerKey)
    list[targetKey] = enabled == true or nil
    ZRP.SaveBuildData()
    return true
end

function ZRP.GetBuildBuddyList(ply)
    local ownerKey = GetBuildAccessKey(ply)
    if not ownerKey then return {} end
    return GetBuddyOwnerList(ownerKey)
end

local function GetBuildEntityOwnerKey(ent)
    if not IsValid(ent) then return nil end

    local ownerKey = ent.ZRP_BuildOwnerKey
    if ownerKey and ownerKey ~= "" then
        return ownerKey
    end

    local nwOwnerKey = ent:GetNWString("ZRP_BuildOwnerKey", "")
    if nwOwnerKey ~= "" then
        ent.ZRP_BuildOwnerKey = nwOwnerKey
        return nwOwnerKey
    end

    if ent.CPPIGetOwner then
        local owner = ent:CPPIGetOwner()
        local cppiOwnerKey = GetBuildAccessKey(owner)
        if cppiOwnerKey then
            ent.ZRP_BuildOwnerKey = cppiOwnerKey
            ent:SetNWString("ZRP_BuildOwnerKey", cppiOwnerKey)
            return cppiOwnerKey
        end
    end

    return nil
end

local function AssignBuildEntityOwner(ent, ply)
    if not IsValid(ent) then return end
    local ownerKey = GetBuildAccessKey(ply)
    if not ownerKey then return end
    ent.ZRP_BuildOwnerKey = ownerKey
    ent:SetNWString("ZRP_BuildOwnerKey", ownerKey)
end

local function CanPlayerInteractWithBuildEntity(ply, ent)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply:IsAdmin() then return true end
    if not IsZRPRoundActive() then return true end
    if not IsValid(ent) or ent:IsPlayer() then return true end

    local ownerKey = GetBuildEntityOwnerKey(ent)
    if not ownerKey then return true end

    local actorKey = GetBuildAccessKey(ply)
    if not actorKey then return false end
    if actorKey == ownerKey then return true end

    local buddyList = ZRP.BuildBuddyLists[ownerKey]
    return istable(buddyList) and buddyList[actorKey] == true
end

function ZRP.PlayerHasBuildAccess(ply)
    local key = GetBuildAccessKey(ply)
    if not key then return false end
    -- Default allow for all players; explicit false can be used for exceptions.
    return ZRP.BuildAccess[key] ~= false
end

local function SyncPlayerBuildWeapons(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local shouldHave = IsZRPRoundActive()
        and ply:Alive()
        and ply:Team() ~= TEAM_SPECTATOR
        and ZRP.PlayerHasBuildAccess(ply)

    if shouldHave then
        if not IsValid(ply:GetWeapon("weapon_physgun")) then
            ply:Give("weapon_physgun")
        end
        if not IsValid(ply:GetWeapon("gmod_tool")) then
            ply:Give("gmod_tool")
        end
    else
        if IsValid(ply:GetWeapon("weapon_physgun")) then
            ply:StripWeapon("weapon_physgun")
        end
        if IsValid(ply:GetWeapon("gmod_tool")) then
            ply:StripWeapon("gmod_tool")
        end
    end
end

function ZRP.SetPlayerBuildAccess(ply, enabled)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local key = GetBuildAccessKey(ply)
    if not key then return false end

    local state = enabled == true
    ZRP.BuildAccess[key] = state
    ply:SetNWBool("ZRP_BuildAccess", state)
    SyncPlayerBuildWeapons(ply)
    return true
end

-- IMPORTANT: declared here so it is in scope for the session/job helpers below.
-- Previously declared further down; locals declared after their callers compile to
-- global lookups in Lua, which silently broke session class assignment at round start.
local function GetPlayerBackupKey(ply)
    if not IsValid(ply) then return nil end
    local sid = ply:SteamID64() or ply:SteamID()
    if not sid or sid == "" then return nil end
    return sid
end

local function NormalizePlayerClassName(className)
    className = string.Trim(tostring(className or ""))
    if className == "" then return nil end
    return className
end

local function EnsureSessionPlayerClassForSpawn(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return nil end

    local key = GetPlayerBackupKey(ply)
    if not key then return nil end

    local className = ZRP.SessionPlayerClasses[key]

    if not className then
        local jobId = ZRP.PlayerJobIds[key]
        if jobId ~= nil then
            className = NormalizePlayerClassName(ZRP.JobPlayerClassMap[jobId])
        end
    end

    className = NormalizePlayerClassName(className) or ZRP_DEFAULT_PLAYERCLASS
    ZRP.SessionPlayerClasses[key] = className

    if ply.PlayerClassName ~= className then
        -- bNoEquipment prevents the class's On hook (e.g. Refugee, sh_refuge.lua)
        -- from auto-giving its built-in loadout. ZRP is loot-based — equipment is
        -- handled by ApplyBackupToPlayer / ApplyFreshRespawnLoadout in PlayerSpawn,
        -- not by the class itself. Without this, Refugee's On hook would stack a
        -- random primary/secondary on top of our restored inventory.
        ply:SetPlayerClass(className, { bNoEquipment = true })
    end

    return className
end

function ZRP.SetSessionPlayerClass(ply, className, options)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    className = NormalizePlayerClassName(className)
    if not className then return false end

    local key = GetPlayerBackupKey(ply)
    if not key then return false end

    ZRP.SessionPlayerClasses[key] = className

    if not options or options.applyNow ~= false then
        if ply.PlayerClassName ~= className then
            -- See comment in EnsureSessionPlayerClassForSpawn — ZRP suppresses the
            -- class's auto-equipment so loot-based inventory remains authoritative.
            ply:SetPlayerClass(className, { bNoEquipment = true })
        end
    end

    return true
end

function ZRP.GetSessionPlayerClass(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return nil end
    local key = GetPlayerBackupKey(ply)
    if not key then return nil end
    return ZRP.SessionPlayerClasses[key]
end

function ZRP.SetJobPlayerClass(jobId, className)
    if jobId == nil then return false end

    className = NormalizePlayerClassName(className)
    if not className then
        ZRP.JobPlayerClassMap[jobId] = nil
        return true
    end

    ZRP.JobPlayerClassMap[jobId] = className
    return true
end

function ZRP.SetPlayerJob(ply, jobId, options)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local key = GetPlayerBackupKey(ply)
    if not key then return false end

    ZRP.PlayerJobIds[key] = jobId

    local mappedClass = jobId ~= nil and NormalizePlayerClassName(ZRP.JobPlayerClassMap[jobId]) or nil
    if mappedClass then
        return ZRP.SetSessionPlayerClass(ply, mappedClass, options)
    end

    return true
end

local function IsInventorySQLUsable()
    return ZRP.InventorySQLReady and hg and hg.MySQL and isfunction(hg.MySQL.query) and isfunction(hg.MySQL.EscapeStr)
end

local function InitInventorySQLTable()
    if ZRP.InventorySQLReady then return end
    if not hg or not hg.MySQL or not isfunction(hg.MySQL.query) then return end

    local query = [[
        CREATE TABLE IF NOT EXISTS ]] .. INVENTORY_SQL_TABLE .. [[ (
            steamid VARCHAR(32) NOT NULL PRIMARY KEY,
            inventory_json LONGTEXT NOT NULL,
            map_name VARCHAR(128) NOT NULL,
            updated_unix BIGINT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_updated_unix (updated_unix)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]

    hg.MySQL.query(query, function(result)
        if result then
            ZRP.InventorySQLReady = true
            print("[ZRP] Inventory SQL table ready: " .. INVENTORY_SQL_TABLE)
        end
    end)
end

local function SaveInventoryBackupToSQL(steamid, entry)
    if not IsInventorySQLUsable() then return end
    if not isstring(steamid) or steamid == "" then return end
    if not istable(entry) or not istable(entry.inventory) then return end

    local escapedSteamID = hg.MySQL.EscapeStr(steamid)
    local escapedInventory = hg.MySQL.EscapeStr(util.TableToJSON(entry.inventory, false) or "{}")
    local escapedMap = hg.MySQL.EscapeStr(game.GetMap() or "unknown")
    local updatedUnix = tonumber(entry.savedAt) or os.time()

    local query = string.format(
        "INSERT INTO %s (steamid, inventory_json, map_name, updated_unix) VALUES (%s, %s, %s, %d) ON DUPLICATE KEY UPDATE inventory_json = VALUES(inventory_json), map_name = VALUES(map_name), updated_unix = VALUES(updated_unix)",
        INVENTORY_SQL_TABLE,
        escapedSteamID,
        escapedInventory,
        escapedMap,
        updatedUnix
    )

    hg.MySQL.query(query, function() end)
end

local function DeleteInventoryBackupFromSQL(steamid)
    if not IsInventorySQLUsable() then return end
    if not isstring(steamid) or steamid == "" then return end

    local query = string.format(
        "DELETE FROM %s WHERE steamid = %s",
        INVENTORY_SQL_TABLE,
        hg.MySQL.EscapeStr(steamid)
    )

    hg.MySQL.query(query, function() end)
end

local function LoadPlayerInventoryBackupFromSQL(ply, callback)
    if not IsValid(ply) then
        if callback then callback(false) end
        return
    end

    local key = GetPlayerBackupKey(ply)
    if not key or not IsInventorySQLUsable() then
        if callback then callback(false) end
        return
    end

    local query = string.format(
        "SELECT inventory_json, updated_unix FROM %s WHERE steamid = %s LIMIT 1",
        INVENTORY_SQL_TABLE,
        hg.MySQL.EscapeStr(key)
    )

    hg.MySQL.query(query, function(result)
        local found = false

        if istable(result) and istable(result[1]) then
            local row = result[1]
            local invTbl = util.JSONToTable(tostring(row.inventory_json or ""))
            if istable(invTbl) then
                ZRP.InventoryBackup[key] = {
                    inventory = invTbl,
                    savedAt = tonumber(row.updated_unix) or os.time(),
                    map = game.GetMap(),
                }
                found = true
            end
        end

        if callback then callback(found) end
    end)
end

local function SaveInventoryBackupData()
    EnsureZRPDir()
    file.Write(INVENTORY_BACKUP_PATH, util.TableToJSON(ZRP.InventoryBackup or {}, true) or "{}")

    for steamid, entry in pairs(ZRP.InventoryBackup or {}) do
        SaveInventoryBackupToSQL(steamid, entry)
    end
end

local function LoadInventoryBackupData()
    EnsureZRPDir()
    local raw = file.Read(INVENTORY_BACKUP_PATH, "DATA")
    if not raw or raw == "" then
        ZRP.InventoryBackup = {}
        return
    end

    local parsed = util.JSONToTable(raw)
    ZRP.InventoryBackup = istable(parsed) and parsed or {}
end

local function CapturePlayerInventoryBackup(ply)
    local key = GetPlayerBackupKey(ply)
    if not key then return end
    if not IsZRPRoundActive() then return end
    if not ply:Alive() then return end
    if ply:Team() == TEAM_SPECTATOR then return end

    local inv = ply:GetNetVar("Inventory", nil)
    if istable(inv) then
        ZRP.InventoryBackup[key] = {
            inventory = table.Copy(inv),
            savedAt = os.time(),
            map = game.GetMap(),
        }
        SaveInventoryBackupToSQL(key, ZRP.InventoryBackup[key])
    end
end

local function RemovePlayerInventoryBackup(ply)
    local key = GetPlayerBackupKey(ply)
    if not key then return end
    ZRP.InventoryBackup[key] = nil
    DeleteInventoryBackupFromSQL(key)
end

local function RestorePlayerInventoryBackup(ply)
    local key = GetPlayerBackupKey(ply)
    if not key then return false end

    local entry = ZRP.InventoryBackup[key]
    if not istable(entry) or not istable(entry.inventory) then
        return false
    end

    local invCopy = table.Copy(entry.inventory)
    ply:SetNetVar("Inventory", invCopy)
    ply.inventory = invCopy
    return true
end

-- Strips a player to a clean ZRP slate. Used when a player is entering ZRP from
-- another mode — without this, the previous mode's weapons / NetVar inventory
-- carry over.
local function WipePlayerForZRP(ply)
    if not IsValid(ply) then return end

    ply:StripWeapons()
    ply:RemoveAllAmmo()

    local clean = { Weapons = {}, Ammo = {}, Armor = {}, Attachments = {} }
    ply:SetNetVar("Inventory", clean)
    ply.inventory = clean

    if ply.armors then ply.armors = {} end
    if ply.armors_health then ply.armors_health = {} end
    if isfunction(ply.SyncArmor) then ply:SyncArmor() end
end

-- Actually re-gives weapons / ammo / armor described by a saved inventory backup
-- entry. RestorePlayerInventoryBackup only mirrors the data into the NetVar; the
-- homigrad inventory system rebuilds the NetVar from real weapons on Player Spawn,
-- so without this the saved data is silently overwritten with an empty inventory.
local function ApplyBackupToPlayer(ply, entry)
    if not IsValid(ply) or not istable(entry) or not istable(entry.inventory) then
        return false
    end

    local inv = entry.inventory

    -- Always make sure baseline ZRP weapons exist.
    if not IsValid(ply:GetWeapon("weapon_hands_sh")) then
        ply:Give("weapon_hands_sh")
    end
    if not IsValid(ply:GetWeapon("weapon_bandage_sh")) then
        ply:Give("weapon_bandage_sh")
    end

    -- Re-give any saved weapons that aren't already on the player.
    if istable(inv.Weapons) then
        for class, _ in pairs(inv.Weapons) do
            if isstring(class)
               and class ~= "weapon_hands_sh"
               and class ~= "weapon_bandage_sh"
               and not IsValid(ply:GetWeapon(class)) then
                -- Validate against the registered weapons table to avoid giving
                -- bogus classes from an outdated backup.
                if weapons.Get(class) then
                    ply:Give(class)
                end
            end
        end
    end

    -- Re-give ammo. inv.Ammo is keyed by ammo ID (number) → count.
    if istable(inv.Ammo) then
        for ammoID, count in pairs(inv.Ammo) do
            local id = tonumber(ammoID)
            local c  = tonumber(count)
            if id and c and c > 0 then
                ply:GiveAmmo(c, id, true)
            end
        end
    end

    -- Re-equip armor via the homigrad armor system if available.
    if istable(inv.Armor) and hg and isfunction(hg.AddArmor) then
        for _, armorEntry in pairs(inv.Armor) do
            if isstring(armorEntry) and armorEntry ~= "" then
                hg.AddArmor(ply, armorEntry)
            end
        end
        if isfunction(ply.SyncArmor) then ply:SyncArmor() end
    end

    ply:SelectWeapon("weapon_hands_sh")

    -- Mirror the saved inventory back into the NetVar so the client UI reflects
    -- exactly what the backup contained. hg.CreateInv (registered on Player Spawn
    -- and run after this hook) will rebuild Weapons/Ammo from the actual entities
    -- we just gave; Armor/Attachments survive that rebuild.
    local invCopy = table.Copy(inv)
    ply:SetNetVar("Inventory", invCopy)
    ply.inventory = invCopy

    return true
end

local function SaveAllAliveInventoryBackups()
    if not IsZRPRoundActive() then return end

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        CapturePlayerInventoryBackup(ply)
    end

    SaveInventoryBackupData()
end

local function EnsureInfiniteBandage(ply)
    if not IsValid(ply) then return end
    local wep = ply:GetWeapon("weapon_bandage_sh")
    if not IsValid(wep) then return end
    wep.ShouldDeleteOnFullUse = false
    if not istable(wep.modeValues) then
        wep.modeValues = {40}
    end
    if (wep.modeValues[1] or 0) <= 0 then
        wep.modeValues[1] = 40
    end
    wep:SetNetVar("modeValues", wep.modeValues)
end

local function ApplyFreshRespawnLoadout(ply)
    if not IsValid(ply) then return end
    if not ply:Alive() then return end

    ply:StripWeapons()
    ply:Give("weapon_hands_sh")
    ply:Give("weapon_bandage_sh")
    ply:SelectWeapon("weapon_hands_sh")

    if IsValid(ply:GetWeapon("weapon_morphine")) then
        ply:StripWeapon("weapon_morphine")
    end

    local inv = ply:GetNetVar("Inventory", {})
    if not istable(inv) then inv = {} end
    inv.Weapons = {
        ["weapon_hands_sh"] = true,
        ["weapon_bandage_sh"] = true,
    }
    inv.Ammo = {}
    inv.Attachments = {}
    inv.Armor = {}
    ply:SetNetVar("Inventory", inv)
    ply.inventory = inv

    EnsureInfiniteBandage(ply)
end

local function QueueJoinRespawn(ply, delay, reason)
    if not IsValid(ply) then return end
    if not IsZRPRoundActive() then return end
    if ply:Team() == TEAM_SPECTATOR then return end
    if ply:Alive() then return end

    local steamid = ply:SteamID()
    local timerName = "ZRP_Respawn_" .. steamid
    if timer.Exists(timerName) then return end

    local respawnDelay = math.max(0, tonumber(delay) or 0)

    net.Start("ZRP_RespawnTimer")
    net.WriteFloat(respawnDelay)
    net.Send(ply)

    timer.Create(timerName, respawnDelay, 1, function()
        if not IsValid(ply) then return end
        if not IsZRPRoundActive() then return end
        if ply:Team() == TEAM_SPECTATOR then return end

        local pt = GetRandomSafeSpawn()
        if pt then
            ply.ZRP_RespawnPos = pt.pos
            ply.ZRP_RespawnAng = pt.ang
        end

        if reason == "join" and not ply.ZRP_JoinAcked then
            ply:ChatPrint("[ZRP] You joined the round.")
            ply.ZRP_JoinAcked = true
        end

        ply:Spawn()
    end)
end

function ZRP.SpawnContainer(id)
    local cfg = ZRP.Containers[id]
    if not cfg then return end
    if cfg.enabled == false then
        ZRP.ActiveContainers[id] = nil
        return
    end

    local ent = ents.Create("zrp_container")
    if not IsValid(ent) then
        print("[ZRP] ERROR: could not create zrp_container (entity class missing?)")
        return
    end
    ent:SetPos(cfg.pos)
    ent:SetAngles(cfg.ang)
    -- ZRP_Model is declared as a NetworkVar in shared.lua (SetupDataTables), not
    -- as an old-style NWString. SetZRP_Model is the auto-generated setter; the
    -- earlier code used SetNWString which wrote to a separate networking system
    -- that ENT:Initialize never read, so containers always fell back to the
    -- default crate model.
    if isfunction(ent.SetZRP_Model) then
        ent:SetZRP_Model(cfg.model or "")
    else
        ent:SetNWString("ZRP_Model", cfg.model or "")
    end
    ent.ZRP_ContainerID   = id
    local lootData = NormalizeContainerLootData(cfg)
    ent.ZRP_LootData      = LootDataHasCustomState(lootData) and lootData or nil
    ent.ZRP_LootOverride  = ent.ZRP_LootData and ent.ZRP_LootData.items or nil
    ent.ZRP_RespawnDelay  = cfg.respawnDelay or CONTAINER_RESPAWN_TIME
    ent.ZRP_ResetDelay    = cfg.respawnDelay or CONTAINER_RESET_TIME
    ent:Spawn()
    ent:Activate()
    -- Belt-and-suspenders: ENT:Initialize already calls SetModel based on
    -- GetZRP_Model, but if there's any Spawn-time race we explicitly enforce
    -- the chosen model here so the placed model isn't silently swapped out.
    if cfg.model and cfg.model ~= "" and util.IsValidModel(cfg.model) then
        if ent:GetModel() ~= cfg.model then
            ent:SetModel(cfg.model)
        end
    end
    ZRP.ClearContainerInventory(ent)

    ZRP.ActiveContainers[id] = ent
    return ent
end

function ZRP.SpawnAllContainers()
    -- Remove any lingering active containers first.
    for id, ent in pairs(ZRP.ActiveContainers) do
        if IsValid(ent) then
            ent.ZRP_SilentRemove = true
            ent:Remove()
        end
    end
    ZRP.ActiveContainers = {}

    for id = 1, #ZRP.Containers do
        ZRP.SpawnContainer(id)
    end
    print("[ZRP] Spawned " .. #ZRP.Containers .. " containers.")
end

-- Called by the zrp_container entity when looted.
function ZRP.OnContainerLooted(id)
    if ZRP.Containers[id] and ZRP.Containers[id].enabled == false then return end
    local delay = (ZRP.Containers[id] and ZRP.Containers[id].respawnDelay) or CONTAINER_RESET_TIME
    local timerName = "ZRP_CReset_" .. id
    timer.Remove(timerName)
    timer.Create(timerName, delay, 1, function()
        local ent = ZRP.ActiveContainers[id]
        if IsValid(ent) then
            ent:ZRP_Reset()
        end
    end)
end

-- Called by the zrp_container entity's OnRemove when destroyed.
function ZRP.OnContainerDestroyed(id)
    ZRP.ActiveContainers[id] = nil
    if ZRP.Containers[id] and ZRP.Containers[id].enabled == false then return end
    local delay = (ZRP.Containers[id] and ZRP.Containers[id].respawnDelay) or CONTAINER_RESPAWN_TIME
    local timerName = "ZRP_CRespawn_" .. id
    timer.Remove(timerName)
    timer.Create(timerName, delay, 1, function()
        if zb.ROUND_STATE == 1 and zb.CROUND == "zrp" then
            ZRP.SpawnContainer(id)
        end
    end)
end

-- ── SAFE_SPAWN helpers ────────────────────────────────────────────────────────

local function GetSafeSpawnPoints()
    local pts = zb.GetMapPoints("SAFE_SPAWN")
    if not pts or #pts == 0 then
        -- Fallback: try generic Spawnpoint group.
        pts = zb.GetMapPoints("Spawnpoint") or {}
    end
    return pts
end

GetRandomSafeSpawn = function()
    local pts = GetSafeSpawnPoints()
    if #pts == 0 then return nil end
    return pts[math.random(#pts)]
end

-- ── MODE: lifecycle ───────────────────────────────────────────────────────────

function MODE:CanLaunch()
    return true
end

function MODE:Intermission()
    game.CleanUpMap()

    -- Note: appearance is applied by MODE:PlayerSpawn after KillPlayers respawns
    -- everyone; calling ApplyAppearance here as well caused appearance flicker.
    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        ply:SetupTeam(0)
    end

    ZRP.LoadContainers()
    if ZRP.LoadWorldContainers then
        ZRP.LoadWorldContainers()
    end

    if IsZRPRoundActive() then
        SaveAllAliveInventoryBackups()
    end

    -- ZRP_Start is no longer broadcast here (it fired during intermission, *before*
    -- the round actually started, so the client's intro splash had already expired
    -- by the time players had control). Broadcast from RoundStart instead.
end

function MODE:GiveWeapons()
end

function MODE:GiveEquipment()
end

function MODE:RoundStart()
    -- Spawn ZRP-placed containers.
    ZRP.SpawnAllContainers()
    -- Activate world-prop containers (map-native props adopted by staff).
    if ZRP.ActivateWorldContainers then
        ZRP.ActivateWorldContainers()
    end

    -- Give players hands + role label.
    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        EnsureSessionPlayerClassForSpawn(ply)

        local pt = GetRandomSafeSpawn()

        if ply:Alive() then
            ply:SetSuppressPickupNotices(true)
            ply.noSound = true
            ply:Give("weapon_hands_sh")
            ply:SelectWeapon("weapon_hands_sh")
            timer.Simple(0.1, function() if IsValid(ply) then ply.noSound = false end end)
            ply:SetSuppressPickupNotices(false)

            zb.GiveRole(ply, "Survivor", Color(60, 200, 120))

            -- Teleport directly when alive.
            if pt then
                timer.Simple(0, function()
                    if IsValid(ply) and ply:Alive() then
                        ply:SetPos(pt.pos)
                        if pt.ang then ply:SetAngles(pt.ang) end
                    end
                end)
            end
        else
            -- Player is dead/loading at the moment the round started.
            -- Stash the spawn point so MODE:PlayerSpawn picks it up on the
            -- next spawn (it consumes ZRP_RespawnPos / ZRP_RespawnAng).
            if pt then
                ply.ZRP_RespawnPos = pt.pos
                ply.ZRP_RespawnAng = pt.ang
            end
        end
    end

    -- Tell every client the round just started so the intro splash + sound fire
    -- at the right moment (this was previously broadcast from MODE:Intermission
    -- which is the wrong lifecycle phase).
    net.Start("ZRP_Start")
    net.Broadcast()
end

function MODE:ShouldRoundEnd()
    -- ZRP is persistent; staff must manually end it via !nextevent / !forcenextmode.
    return false
end

function MODE:RoundThink()
end

-- ── MODE: PlayerSpawn ─────────────────────────────────────────────────────────
-- Runs when a player spawns (initial or respawn).
-- OverrideSpawn=true prevents GM:PlayerSpawn's team-balance logic.

function MODE:PlayerSpawn(ply)
    if not ply:Alive() then return end

    timer.Remove("ZRP_Respawn_" .. ply:SteamID())
    ply.ZRP_JoinAcked = nil

    -- Match base spawn behavior when OverrideSpawn is enabled.
    ply:SuppressHint("OpeningMenu")
    ply:SuppressHint("Annoy1")
    ply:SuppressHint("Annoy2")
    ply.viewmode = 3
    ply:UnSpectate()
    ply:SetMoveType(MOVETYPE_WALK)

    EnsureSessionPlayerClassForSpawn(ply)

    -- Apply appearance (replaces GM:PlayerSpawn's ApplyAppearance call).
    ApplyAppearance(ply, nil, nil, nil, true)

    -- If ZRP_RespawnPos is set, teleport there after the spawn hook finishes.
    if ply.ZRP_RespawnPos then
        local pos = ply.ZRP_RespawnPos
        local ang = ply.ZRP_RespawnAng
        ply.ZRP_RespawnPos = nil
        ply.ZRP_RespawnAng = nil
        timer.Simple(0, function()
            if IsValid(ply) and ply:Alive() then
                ply:SetPos(pos)
                if ang then ply:SetAngles(ang) end
            end
        end)
    end

    -- Inventory handling.
    -- IMPORTANT: gated on CROUND, NOT IsZRPRoundActive(). When transitioning from
    -- another mode into ZRP, KillPlayers respawns everyone *before* ROUND_STATE
    -- flips to 1 — gating on round-active here meant the previous mode's weapons
    -- and NetVar inventory carried over into ZRP. Gating on CROUND covers both
    -- the transition spawn (state=0, CROUND=zrp) and normal respawns (state=1).
    if zb.CROUND == "zrp" then
        -- Survivors always get the role label once we're sure this is a ZRP spawn.
        zb.GiveRole(ply, "Survivor", Color(60, 200, 120))

        local skipRestoreForUnfake = (ply.ZRP_SkipInventoryReloadUntil or 0) > CurTime()
        if skipRestoreForUnfake and not ply.ZRP_ForceFreshLoadout then
            -- FakeUp can fire a spawn path; keep the current live loadout intact.
            -- We only snapshot it back into backup storage.
            ply.ZRP_SkipInventoryReloadUntil = nil
            EnsureInfiniteBandage(ply)
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                if zb.CROUND ~= "zrp" then return end
                if not ply:Alive() then return end
                CapturePlayerInventoryBackup(ply)
                SaveInventoryBackupData()
            end)
        else

        -- Wipe whatever the previous mode (or previous life with morphine etc.) left
        -- on the player. ApplyBackupToPlayer / ApplyFreshRespawnLoadout below give
        -- weapons back from a clean slate.
        WipePlayerForZRP(ply)

        local key = GetPlayerBackupKey(ply)
        local hasInMemBackup = key and istable(ZRP.InventoryBackup[key])
            and istable(ZRP.InventoryBackup[key].inventory)

        if ply.ZRP_ForceFreshLoadout then
            -- Player died last life — fresh start regardless of any backup.
            ApplyFreshRespawnLoadout(ply)
            CapturePlayerInventoryBackup(ply)
            SaveInventoryBackupData()
        elseif hasInMemBackup then
            -- We already have their backup loaded (either from memory or a prior
            -- SQL fetch this session) — restore synchronously.
            if not ApplyBackupToPlayer(ply, ZRP.InventoryBackup[key]) then
                ApplyFreshRespawnLoadout(ply)
            else
                EnsureInfiniteBandage(ply)
                if IsValid(ply:GetWeapon("weapon_morphine")) and ply.ZRP_ForceNoMorphine then
                    ply:StripWeapon("weapon_morphine")
                end
            end
        else
            -- No in-memory backup — give fresh loadout immediately so the player
            -- isn't standing there empty-handed, then try SQL in the background.
            -- If SQL returns a valid backup we wipe + re-apply it.
            ApplyFreshRespawnLoadout(ply)

            if not ply.ZRP_TriedSQLLoad then
                ply.ZRP_TriedSQLLoad = true
                LoadPlayerInventoryBackupFromSQL(ply, function(found)
                    if not IsValid(ply) then return end
                    if zb.CROUND ~= "zrp" then return end
                    if not ply:Alive() then return end
                    if not found then return end

                    local k2 = GetPlayerBackupKey(ply)
                    if not k2 then return end
                    local entry = ZRP.InventoryBackup[k2]
                    if not istable(entry) or not istable(entry.inventory) then return end

                    WipePlayerForZRP(ply)
                    if ApplyBackupToPlayer(ply, entry) then
                        EnsureInfiniteBandage(ply)
                        ply:ChatPrint("[ZRP] Restored your saved inventory from the database.")
                    else
                        ApplyFreshRespawnLoadout(ply)
                    end
                end)
            end
        end
        end
    end

    if IsZRPRoundActive() then
        SyncPlayerBuildWeapons(ply)
    end

    ply.ZRP_ForceFreshLoadout = nil
    ply.ZRP_ForceNoMorphine = nil
end

function MODE:PlayerInitialSpawn(ply)
    -- Always pre-load this player's saved inventory from SQL on connect, regardless
    -- of whether the current round is ZRP. This way, if ZRP starts later in the
    -- session, ZRP.InventoryBackup[steamid] is already populated and the spawn
    -- pipeline restores synchronously instead of standing them empty-handed for a
    -- couple of seconds while SQL roundtrips.
    timer.Simple(2, function()
        if not IsValid(ply) then return end

        local key = GetPlayerBackupKey(ply)
        if key and istable(ZRP.InventoryBackup[key]) then
            -- Already in memory — only the join-respawn path below cares about it.
            if IsZRPRoundActive()
               and ply:Team() ~= TEAM_SPECTATOR
               and not ply:Alive() then
                QueueJoinRespawn(ply, 1, "join")
            end
            return
        end

        LoadPlayerInventoryBackupFromSQL(ply, function(found)
            if not IsValid(ply) then return end
            if not IsZRPRoundActive() then return end
            if ply:Team() == TEAM_SPECTATOR then return end
            if ply:Alive() then return end
            QueueJoinRespawn(ply, 1, "join")
        end)
    end)
end

-- ── MODE: PlayerDeath ─────────────────────────────────────────────────────────

function MODE:PlayerDeath(victim, inflictor, attacker)
    if not IsValid(victim) then return end
    if not IsZRPRoundActive() then return end
    if victim:Team() == TEAM_SPECTATOR then return end

    victim.ZRP_ForceFreshLoadout = true
    victim.ZRP_ForceNoMorphine = true
    RemovePlayerInventoryBackup(victim)
    SaveInventoryBackupData()

    QueueJoinRespawn(victim, RESPAWN_DELAY, "death")
end

-- Prevent the gamemode from auto-respawning players (we handle it ourselves).
function MODE:CanSpawn(ply)
    return false
end

-- ── MODE: EndRound ────────────────────────────────────────────────────────────

function MODE:EndRound()
    -- Cancel all pending respawn timers.
    for _, ply in player.Iterator() do
        timer.Remove("ZRP_Respawn_" .. ply:SteamID())
    end
    -- Cancel container timers.
    for id = 1, #ZRP.Containers do
        timer.Remove("ZRP_CReset_"   .. id)
        timer.Remove("ZRP_CRespawn_" .. id)
    end
    -- Remove active containers.
    for id, ent in pairs(ZRP.ActiveContainers) do
        if IsValid(ent) then
            ent.ZRP_SilentRemove = true
            ent:Remove()
        end
    end
    ZRP.ActiveContainers = {}
    SaveAllAliveInventoryBackups()

    -- Cancel world-prop container reset timers.
    if ZRP.CancelWorldContainerTimers then
        ZRP.CancelWorldContainerTimers()
    end

    net.Start("ZRP_End")
    net.Broadcast()
end

-- ── Initialization ────────────────────────────────────────────────────────────

hook.Add("Initialize", "ZRP_LoadLootData", function()
    timer.Simple(1, function()
        ZRP.LoadLootData()
        ZRP.LoadLootProfiles()
        ZRP.LoadBuildData()
        LoadInventoryBackupData()
        -- LoadContainers must run on boot too — MODE:Intermission only fires when
        -- transitioning *between* rounds, so when the server boots straight into
        -- ZRP (or a !zrpstart fires before any prior Intermission has run) the
        -- ZRP.Containers table stays empty and SpawnAllContainers no-ops with
        -- "Spawned 0 containers" — the user-visible symptom of containers never
        -- activating.
        ZRP.LoadContainers()
        if ZRP.LoadWorldContainers then ZRP.LoadWorldContainers() end

        -- If we boot directly into a ZRP round (zb_forcemode=zrp at server start,
        -- or a map change while mid-ZRP), the round-system's PreRound→RoundStart
        -- has likely already fired by the time this Initialize timer runs, which
        -- means SpawnAllContainers ran with an empty table. Spawn now if needed.
        if zb and zb.CROUND == "zrp" and zb.ROUND_STATE == 1 and #ZRP.Containers > 0 then
            ZRP.SpawnAllContainers()
        end
    end)

    timer.Create("ZRP_InventorySQL_InitRetry", 1, 30, function()
        InitInventorySQLTable()
        if ZRP.InventorySQLReady then
            timer.Remove("ZRP_InventorySQL_InitRetry")
        end
    end)
end)

hook.Add("PlayerDisconnected", "ZRP_BackupOnDisconnect", function(ply)
    if not IsValid(ply) then return end

    local key = GetPlayerBackupKey(ply)
    if key then
        ZRP.SessionPlayerClasses[key] = nil
        ZRP.PlayerJobIds[key] = nil
    end

    if not IsZRPRoundActive() then return end
    CapturePlayerInventoryBackup(ply)
    SaveInventoryBackupData()
end)

hook.Add("Fake Up", "ZRP_PreserveInventoryOnUnfake", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if zb.CROUND ~= "zrp" then return end
    ply.ZRP_SkipInventoryReloadUntil = CurTime() + 1
end)

hook.Remove("PlayerSpawnProp", "BlockSpawn")
hook.Add("PlayerSpawnProp", "ZRP_BuildPropWhitelist", function(ply, model)
    if game.SinglePlayer() or ply:IsAdmin() then return true end
    if IsZRPRoundActive() and ZRP.PlayerHasBuildAccess(ply) then
        if IsBuildPropBlacklisted(model) then
            return false
        end
        return IsBuildPropWhitelisted(model)
    end
    return false
end)

local function IsZRPManagedFrozenProp(ent)
    if not IsValid(ent) then return false end
    if ent:GetClass() ~= "prop_physics" and ent:GetClass() ~= "prop_physics_multiplayer" then return false end
    return ent.ZRP_AlwaysFrozen == true
end

local function ForceFreezeZRPProp(ent)
    if not IsValid(ent) then return end

    ent.ZRP_AlwaysFrozen = true
    ent:SetCustomCollisionCheck(true)

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end

hook.Add("PlayerSpawnedProp", "ZRP_AssignBuildPropOwner", function(ply, model, ent)
    if not IsZRPRoundActive() then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsValid(ent) then return end
    AssignBuildEntityOwner(ent, ply)
    ForceFreezeZRPProp(ent)
end)

hook.Add("CanTool", "ZRP_BuildToolWhitelist", function(ply, tr, toolname)
    if not IsZRPRoundActive() then return end
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local toolKey = NormalizeBuildKey(toolname)
    if toolKey == "zcity_safe_zone" then
        local safeZoneLib = rawget(_G, "ZCitySafeZones")
        if istable(safeZoneLib) and isfunction(safeZoneLib.CanEdit) and safeZoneLib.CanEdit(ply) then
            return true
        end
    end

    if ply:IsAdmin() then return end
    if not ZRP.PlayerHasBuildAccess(ply) then return false end
    if tr and IsValid(tr.Entity) and not CanPlayerInteractWithBuildEntity(ply, tr.Entity) then
        return false
    end
    return IsBuildToolWhitelisted(toolname)
end)

hook.Add("CanProperty", "AntiExploit", function(ply, property, ent)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply:IsAdmin() then return true end
    if IsZRPRoundActive() and ZRP.PlayerHasBuildAccess(ply) then
        if IsValid(ent) and not CanPlayerInteractWithBuildEntity(ply, ent) then
            return false
        end
        return IsBuildPropertyWhitelisted(property)
    end
    return false
end)

hook.Add("PhysgunPickup", "ZRP_BuildBuddyPhysgun", function(ply, ent)
    if not CanPlayerInteractWithBuildEntity(ply, ent) then
        return false
    end

    if IsZRPRoundActive() and IsZRPManagedFrozenProp(ent) then
        ent.ZRP_GhostPlayersWhilePhysgun = true
    end
end)

hook.Add("CanPlayerUnfreeze", "ZRP_BuildBuddyUnfreeze", function(ply, ent)
    if IsZRPRoundActive() and IsZRPManagedFrozenProp(ent) then
        return false
    end

    if not CanPlayerInteractWithBuildEntity(ply, ent) then
        return false
    end
end)

hook.Add("PhysgunDrop", "ZRP_FreezeAndUnghostOnDrop", function(_, ent)
    if not IsZRPRoundActive() then return end
    if not IsValid(ent) then return end

    if IsZRPManagedFrozenProp(ent) then
        ForceFreezeZRPProp(ent)
    end

    ent.ZRP_GhostPlayersWhilePhysgun = nil
end)

hook.Add("ShouldCollide", "ZRP_PhysgunPropGhostPlayers", function(entA, entB)
    if not IsZRPRoundActive() then return end

    local characterBody, prop
    if IsValid(entA) and (entA:IsPlayer() or entA:IsRagdoll()) and IsValid(entB) then
        characterBody, prop = entA, entB
    elseif IsValid(entB) and (entB:IsPlayer() or entB:IsRagdoll()) and IsValid(entA) then
        characterBody, prop = entB, entA
    end

    if not IsValid(characterBody) or not IsValid(prop) then return end
    if not IsZRPManagedFrozenProp(prop) then return end
    if prop.ZRP_GhostPlayersWhilePhysgun ~= true then return end

    return false
end)

hook.Add("GravGunPickupAllowed", "ZRP_BuildBuddyGravGun", function(ply, ent)
    if not CanPlayerInteractWithBuildEntity(ply, ent) then
        return false
    end
end)

hook.Add("GravGunPunt", "ZRP_BuildBuddyGravGunPunt", function(ply, ent)
    if not CanPlayerInteractWithBuildEntity(ply, ent) then
        return false
    end
end)

hook.Add("PlayerSpawn", "ZRP_BuildAccess_NWRefresh", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local key = GetBuildAccessKey(ply)
    if not key then return end
    local state = ZRP.BuildAccess[key] ~= false
    ply:SetNWBool("ZRP_BuildAccess", state)
    if IsZRPRoundActive() then
        SyncPlayerBuildWeapons(ply)
    end
end)

hook.Add("ShutDown", "ZRP_BackupOnShutdown", function()
    if not IsZRPRoundActive() then return end
    SaveAllAliveInventoryBackups()
end)

timer.Create("ZRP_InventoryBackupInterval", INVENTORY_BACKUP_INTERVAL, 0, function()
    if not IsZRPRoundActive() then return end
    SaveAllAliveInventoryBackups()
end)

hook.Add("Think", "ZRP_EnsureBandageInfinite", function()
    if not IsZRPRoundActive() then return end
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if not ply:Alive() then continue end
        EnsureInfiniteBandage(ply)
    end
end)

-- ── Staff commands ────────────────────────────────────────────────────────────

-- Sends full loot state to a player (admin only).
local function SyncLootToPlayer(ply)
    net.Start("ZRP_LootSync")
    net.WriteTable({
        global = ZRP.LootData,
        profiles = ZRP.PropLootProfiles or {},
    })
    net.Send(ply)
end

local function GetLootDataTarget(targetModel, createIfMissing)
    local targetType, targetValue, normalizedTarget = ParseLootTarget(targetModel)
    if targetType == "global" then
        ZRP.LootData = NormalizeLootData(ZRP.LootData)
        return ZRP.LootData, nil
    end

    if targetType == "container" then
        local containerId = targetValue
        local cfg = ZRP.Containers[containerId]
        if not cfg then return nil, nil end

        cfg.lootData = NormalizeContainerLootData(cfg)
        if createIfMissing and not LootDataHasCustomState(cfg.lootData) then
            cfg.lootData = NormalizeLootData(nil)
            cfg.lootOverride = cfg.lootData.items
        end

        return cfg.lootData, normalizedTarget
    end

    if targetType ~= "model" then return nil, nil end

    local profile, normalizedModel = ZRP.GetLootProfile(targetValue, createIfMissing)
    return profile, normalizedModel
end

local function SaveLootDataTarget(targetModel)
    local targetType = ParseLootTarget(targetModel)

    if targetType == "container" then
        ZRP.SaveContainers()
        return
    end

    if targetType == "model" then
        ZRP.SaveLootProfiles()
        return
    end

    ZRP.SaveLootData()
end

-- Sends container list for the current map to a player (admin only).
function ZRP.SyncContainersToPlayer(ply)
    local out = {}
    for id, cfg in ipairs(ZRP.Containers) do
        out[id] = {
            id    = id,
            model = cfg.model,
            pos   = { cfg.pos.x, cfg.pos.y, cfg.pos.z },
            ang   = { cfg.ang.p, cfg.ang.y, cfg.ang.r },
            respawnDelay = cfg.respawnDelay,
            enabled = (cfg.enabled ~= false),
            active = IsValid(ZRP.ActiveContainers[id]),
            lootData = NormalizeContainerLootData(cfg),
        }
    end
    net.Start("ZRP_ContainerSync")
    net.WriteTable(out)
    net.Send(ply)
end

-- Open the loot / container editor on a client's screen.
-- The legacy ZRP loot editor has been unified with the Event loot menu so
-- both modes share a single editing surface. Both editors operate on the
-- same persisted ZRP container/world-container data, so changes here apply
-- to ZRP and Event sessions identically. We still sync ZRP container/world
-- data first (for the toolgun + container manager), then route the user to
-- the Event Loot Manager UI.
concommand.Add("zrp_open_editor", function(ply, _, _, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    SyncLootToPlayer(ply)
    ZRP.SyncContainersToPlayer(ply)
    if ZRP.SyncWorldContainersToPlayer then ZRP.SyncWorldContainersToPlayer(ply) end
    -- Hand off to the unified Event Loot Manager menu (zb_event_loot_menu
    -- is registered by cl_event.lua and aliases zb_event_lootpoll).
    ply:ConCommand("zb_event_loot_menu")
end)

-- Loot table: add item.
net.Receive("ZRP_LootAdd", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local class  = net.ReadString()
    local weight = net.ReadUInt(8)
    local targetModel = net.ReadString()
    class  = SanitizeLootClass(class)
    weight = math.Clamp(weight, 1, 255)
    if class == "" then return end
    local targetData, normalizedTarget = GetLootDataTarget(targetModel, true)
    if not targetData then return end
    -- Prevent duplicates.
    for _, e in ipairs(targetData.items) do
        if e[2] == class then
            e[1] = weight
            SaveLootDataTarget(normalizedTarget)
            SyncLootToPlayer(ply)
            return
        end
    end
    targetData.items[#targetData.items + 1] = { weight, class }
    SaveLootDataTarget(normalizedTarget)
    SyncLootToPlayer(ply)
    ply:ChatPrint("[ZRP] Added item to " .. (normalizedTarget or "global") .. ": " .. class .. " (weight " .. weight .. ")")
end)

-- Loot table: remove item by index.
net.Receive("ZRP_LootRemove", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local idx = net.ReadUInt(16)
    local targetModel = net.ReadString()
    local targetData, normalizedTarget = GetLootDataTarget(targetModel, false)
    if not targetData or not targetData.items[idx] then return end
    local cls = targetData.items[idx][2]
    table.remove(targetData.items, idx)
    SaveLootDataTarget(normalizedTarget)
    SyncLootToPlayer(ply)
    ply:ChatPrint("[ZRP] Removed from " .. (normalizedTarget or "global") .. ": " .. cls)
end)

-- Loot table: change weight.
net.Receive("ZRP_LootSetWeight", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local idx    = net.ReadUInt(16)
    local weight = net.ReadUInt(8)
    local targetModel = net.ReadString()
    local targetData, normalizedTarget = GetLootDataTarget(targetModel, false)
    if not targetData or not targetData.items[idx] then return end
    targetData.items[idx][1] = math.Clamp(weight, 1, 255)
    SaveLootDataTarget(normalizedTarget)
    SyncLootToPlayer(ply)
end)

-- Loot table: toggle blacklist.
net.Receive("ZRP_LootSetBlacklist", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local class = net.ReadString()
    local state = net.ReadBool()
    local targetModel = net.ReadString()
    class = SanitizeLootClass(class)
    if class == "" then return end
    local targetData, normalizedTarget = GetLootDataTarget(targetModel, true)
    if not targetData then return end
    if state then
        targetData.blacklist[class] = true
    else
        targetData.blacklist[class] = nil
    end
    SaveLootDataTarget(normalizedTarget)
    SyncLootToPlayer(ply)
    ply:ChatPrint("[ZRP] Blacklist " .. class .. " on " .. (normalizedTarget or "global") .. ": " .. tostring(state))
end)

-- Loot table: toggle whitelist.
net.Receive("ZRP_LootSetWhitelist", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local class = net.ReadString()
    local state = net.ReadBool()
    local targetModel = net.ReadString()
    class = SanitizeLootClass(class)
    if class == "" then return end
    local targetData, normalizedTarget = GetLootDataTarget(targetModel, true)
    if not targetData then return end
    if state then
        targetData.whitelist[class] = true
    else
        targetData.whitelist[class] = nil
    end
    SaveLootDataTarget(normalizedTarget)
    SyncLootToPlayer(ply)
    ply:ChatPrint("[ZRP] Whitelist " .. class .. " on " .. (normalizedTarget or "global") .. ": " .. tostring(state))
end)

-- Reset loot to defaults.
concommand.Add("zrp_loot_reset_target", function(ply, _, args, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local targetType, targetValue, normalizedTarget = ParseLootTarget(args[1])

    if targetType == "container" then
        local cfg = ZRP.Containers[targetValue]
        if not cfg then
            ply:ChatPrint("[ZRP] Invalid container target.")
            return
        end

        cfg.lootData = NormalizeLootData(nil)
        cfg.lootOverride = cfg.lootData.items
        ZRP.SaveContainers()
        SyncLootToPlayer(ply)
        ZRP.SyncContainersToPlayer(ply)
        ply:ChatPrint("[ZRP] Reset loot profile: " .. normalizedTarget)
        return
    end

    if targetType == "model" then
        local targetModel = targetValue
        ZRP.PropLootProfiles[targetModel] = nil
        ZRP.SaveLootProfiles()
        SyncLootToPlayer(ply)
        ply:ChatPrint("[ZRP] Reset loot profile: " .. targetModel)
        return
    end

    ZRP.LootData = NormalizeLootData(nil)
    ZRP.SaveLootData()
    SyncLootToPlayer(ply)
    ply:ChatPrint("[ZRP] Loot table reset to defaults.")
end)

-- ── Container management commands (from LootEditor stool) ────────────────────

-- Add a container at the given position (called by stool via console).
concommand.Add("zrp_container_add", function(ply, _, args, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    -- args: model posx posy posz angp angy angr [respawnDelay]
    local model = args[1] or "models/props_junk/wood_crate001a.mdl"
    model = string.lower(string.Trim(model))
    if string.find(model, "%.%.") then return end  -- path traversal guard
    local px, py, pz = tonumber(args[2]) or 0, tonumber(args[3]) or 0, tonumber(args[4]) or 0
    local ap, ay, ar = tonumber(args[5]) or 0, tonumber(args[6]) or 0, tonumber(args[7]) or 0
    local delay      = tonumber(args[8]) or nil

    local cfg = {
        model        = model,
        pos          = Vector(px, py, pz),
        ang          = Angle(ap, ay, ar),
        respawnDelay = delay,
        enabled      = true,
        lootData     = NormalizeLootData(nil),
        lootOverride = {},
    }
    ZRP.Containers[#ZRP.Containers + 1] = cfg
    local id = #ZRP.Containers
    ZRP.SaveContainers()
    ZRP.SpawnContainer(id)
    ZRP.SyncContainersToPlayer(ply)
    ply:ChatPrint("[ZRP] Container #" .. id .. " added.")
end)

-- Remove a container by ID.
concommand.Add("zrp_container_remove", function(ply, _, args, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local id = tonumber(args[1])
    if not id or not ZRP.Containers[id] then
        ply:ChatPrint("[ZRP] Invalid container ID.")
        return
    end
    if IsValid(ZRP.ActiveContainers[id]) then
        ZRP.ActiveContainers[id].ZRP_SilentRemove = true
        ZRP.ActiveContainers[id]:Remove()
        ZRP.ActiveContainers[id] = nil
    end
    timer.Remove("ZRP_CReset_"   .. id)
    timer.Remove("ZRP_CRespawn_" .. id)
    table.remove(ZRP.Containers, id)
    -- Re-index active containers after removal.
    local newActive = {}
    for k, v in pairs(ZRP.ActiveContainers) do
        if k > id then newActive[k - 1] = v
        elseif k ~= id then newActive[k] = v end
    end
    ZRP.ActiveContainers = newActive
    ZRP.SaveContainers()
    ZRP.SyncContainersToPlayer(ply)
    ply:ChatPrint("[ZRP] Container #" .. id .. " removed.")
end)

-- Set respawn delay for a container.
concommand.Add("zrp_container_setdelay", function(ply, _, args, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local id    = tonumber(args[1])
    local delay = tonumber(args[2])
    if not id or not ZRP.Containers[id] or not delay then
        ply:ChatPrint("[ZRP] Usage: zrp_container_setdelay <id> <seconds>")
        return
    end
    ZRP.Containers[id].respawnDelay = math.max(1, delay)
    ZRP.SaveContainers()
    ZRP.SyncContainersToPlayer(ply)
    ply:ChatPrint("[ZRP] Container #" .. id .. " delay set to " .. delay .. "s.")
end)

-- Enable/disable a container. Disabled containers are persisted but do not spawn.
local function ParseEnabledState(stateArg)
    local v = string.lower(string.Trim(tostring(stateArg or "")))
    if v == "1" or v == "true" or v == "on" or v == "yes" or v == "enable" or v == "enabled" then
        return true
    end
    if v == "0" or v == "false" or v == "off" or v == "no" or v == "disable" or v == "disabled" then
        return false
    end
    return nil
end

local function SetContainerActiveState(ply, id, stateArg)
    local cfg = ZRP.Containers[id]
    if not cfg then
        ply:ChatPrint("[ZRP] Invalid container ID.")
        return
    end

    local enabled = ParseEnabledState(stateArg)
    if enabled == nil then
        ply:ChatPrint("[ZRP] Usage: zrp_container_setactive <id> <1/0>")
        return
    end

    cfg.enabled = enabled

    if not enabled then
        timer.Remove("ZRP_CReset_" .. id)
        timer.Remove("ZRP_CRespawn_" .. id)
        if IsValid(ZRP.ActiveContainers[id]) then
            ZRP.ActiveContainers[id].ZRP_SilentRemove = true
            ZRP.ActiveContainers[id]:Remove()
            ZRP.ActiveContainers[id] = nil
        end
    else
        if zb.ROUND_STATE == 1 and zb.CROUND == "zrp" and not IsValid(ZRP.ActiveContainers[id]) then
            ZRP.SpawnContainer(id)
        end
    end

    ZRP.SaveContainers()
    ZRP.SyncContainersToPlayer(ply)
    ply:ChatPrint("[ZRP] Container #" .. id .. " " .. (enabled and "enabled" or "disabled") .. ".")
end

local function ForceActivateContainer(ply, id)
    local cfg = ZRP.Containers[id]
    if not cfg then
        ply:ChatPrint("[ZRP] Invalid container ID.")
        return
    end
    if cfg.enabled == false then
        ply:ChatPrint("[ZRP] Container #" .. id .. " is disabled. Enable it first.")
        return
    end

    timer.Remove("ZRP_CReset_" .. id)
    timer.Remove("ZRP_CRespawn_" .. id)

    local ent = ZRP.ActiveContainers[id]
    if IsValid(ent) then
        ent:ZRP_Reset()
        ent:SetHealth(ent:GetMaxHealth())
    else
        ent = ZRP.SpawnContainer(id)
        if not IsValid(ent) then
            ply:ChatPrint("[ZRP] Failed to spawn container #" .. id .. ".")
            ZRP.SyncContainersToPlayer(ply)
            return
        end
        if not (zb.ROUND_STATE == 1 and zb.CROUND == "zrp") then
            ply:ChatPrint("[ZRP] Container #" .. id .. " spawned outside an active ZRP round for editor preview.")
        end
    end

    if not IsValid(ent) then
        ZRP.SyncContainersToPlayer(ply)
        return
    end

    ZRP.SyncContainersToPlayer(ply)
    ply:ChatPrint("[ZRP] Container #" .. id .. " activated.")
end

concommand.Add("zrp_container_setactive", function(ply, _, args, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local id = tonumber(args[1])
    if not id then
        ply:ChatPrint("[ZRP] Usage: zrp_container_setactive <id> <1/0>")
        return
    end

    SetContainerActiveState(ply, id, args[2])
end)

concommand.Add("zrp_container_activate", function(ply, _, args, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local id = tonumber(args[1])
    if not id then
        ply:ChatPrint("[ZRP] Usage: zrp_container_activate <id>")
        return
    end

    ForceActivateContainer(ply, id)
end)

net.Receive("ZRP_ContainerSetActive", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local id = net.ReadUInt(16)
    local enabled = net.ReadBool()
    SetContainerActiveState(ply, id, enabled and "1" or "0")
end)

net.Receive("ZRP_ContainerActivate", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local id = net.ReadUInt(16)
    ForceActivateContainer(ply, id)
end)

net.Receive("ZRP_ContainerRequestSync", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    ZRP.SyncContainersToPlayer(ply)
    if ZRP.SyncWorldContainersToPlayer then
        ZRP.SyncWorldContainersToPlayer(ply)
    end
end)

-- Sync editor data to the admin who just joined or connects.
hook.Add("PlayerInitialSpawn", "ZRP_AdminLootSync", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) and ply:IsAdmin() and zb.CROUND == "zrp" then
            SyncLootToPlayer(ply)
            if ZRP.SyncWorldContainersToPlayer then ZRP.SyncWorldContainersToPlayer(ply) end
        end
    end)
end)

hook.Add("HG_PlayerSay", "ZRP_JoinSpawnChat", function(ply, txtTbl, text)
    local cmd = string.lower(string.Trim(text or ""))
    if cmd ~= "!join" and cmd ~= "/join" and cmd ~= "!zrpjoin" and cmd ~= "/zrpjoin" then
        return
    end

    if not IsZRPRoundActive() then
        return
    end

    txtTbl[1] = ""

    if ply:Team() == TEAM_SPECTATOR then
        ply:ChatPrint("[ZRP] Leave spectator mode before joining.")
        return ""
    end
    if ply:Alive() then
        ply:ChatPrint("[ZRP] You are already alive.")
        return ""
    end

    local timerName = "ZRP_Respawn_" .. ply:SteamID()
    if timer.Exists(timerName) then
        ply:ChatPrint("[ZRP] You are already queued to respawn.")
        return ""
    end

    QueueJoinRespawn(ply, 1, "join")
    return ""
end)

-- Chat aliases for the ZRP staff GUIs. Admin-gated. Eats the chat message so
-- the command text doesn't broadcast.
local ZRP_CLASS_BUILDER_ALIASES = {
    ["!classes"] = true, ["/classes"] = true,
    ["!zrpclasses"] = true, ["/zrpclasses"] = true,
}

hook.Add("HG_PlayerSay", "ZRP_StaffGUIChat", function(ply, txtTbl, text)
    local cmd = string.lower(string.Trim(text or ""))

    if ZRP_CLASS_BUILDER_ALIASES[cmd] then
        txtTbl[1] = ""
        if not IsValid(ply) or not ply:IsAdmin() then
            ply:ChatPrint("[ZRP] Class builder is admin-only.")
            return ""
        end
        ply:ConCommand("zrp_open_class_builder")
        return ""
    end
end)
