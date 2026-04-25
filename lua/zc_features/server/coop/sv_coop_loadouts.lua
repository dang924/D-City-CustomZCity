-- sv_coop_loadouts.lua
-- Server-side management of Coop-specific loadout presets
-- Uses ZCity's default Rebel/Refugee/subclass equipping as the base,
-- allowing superadmins to customize and save preset equipment configurations.
-- Loadouts are stored separately from event menu presets in data/zc_coop_loadouts.json
if CLIENT then return end

AddCSLuaFile("zc_features/client/coop/cl_coop_loadout_menu.lua")

util.AddNetworkString("ZC_OpenCoopLoadoutMenu")
util.AddNetworkString("ZC_RequestCoopLoadouts")
util.AddNetworkString("ZC_SendCoopLoadouts")         -- kept for legacy; actual data via chunked messages below
util.AddNetworkString("ZC_SendCoopLoadoutsBegin")    -- signals start: UInt(16) = total count
util.AddNetworkString("ZC_SendCoopLoadoutEntry")     -- one preset: String(name) + String(json)
util.AddNetworkString("ZC_SendCoopLoadoutsEnd")      -- signals all entries sent
util.AddNetworkString("ZC_SaveCoopLoadoutJSON")  -- JSON payload avoids net.WriteTable key mangling
util.AddNetworkString("ZC_SaveCoopLoadout")
util.AddNetworkString("ZC_DeleteCoopLoadout")
util.AddNetworkString("ZC_ResetCoopLoadoutToDefault")
util.AddNetworkString("ZC_ResetAllCoopLoadoutsToDefault")
util.AddNetworkString("ZC_RequestArmorList")  -- client requests registered armor keys per slot
util.AddNetworkString("ZC_SendArmorList")
util.AddNetworkString("ZC_RequestSubclassSlotModifiers")
util.AddNetworkString("ZC_SendSubclassSlotModifiers")
util.AddNetworkString("ZC_SaveSubclassSlotModifiers")

local zc_coop_random_attachments = CreateConVar(
    "zc_coop_random_attachments",
    "1",
    FCVAR_ARCHIVE,
    "Randomize attachments on the first attachable coop loadout weapon at spawn.",
    0,
    1
)

CreateConVar("zc_rebel_medic_slot_mult", "1.0", FCVAR_ARCHIVE, "Multiplier for rebel medic subclass max slots", 0, 4)
CreateConVar("zc_rebel_grenadier_slot_mult", "1.0", FCVAR_ARCHIVE, "Multiplier for rebel grenadier subclass max slots", 0, 4)
CreateConVar("zc_combine_sniper_slot_mult", "1.0", FCVAR_ARCHIVE, "Multiplier for combine sniper subclass max slots", 0, 4)
CreateConVar("zc_combine_shotgunner_slot_mult", "1.0", FCVAR_ARCHIVE, "Multiplier for combine shotgunner subclass max slots", 0, 4)
CreateConVar("zc_combine_metropolice_slot_mult", "1.0", FCVAR_ARCHIVE, "Multiplier for combine metropolice subclass max slots", 0, 4)

local ARMOR_SLOTS = { "torso", "head", "ears", "face" }

-- ── Coop Loadout Presets ──────────────────────────────────────────────────────
-- These are built from ZCity's default Rebel and Refugee class equipment definitions.
-- Superadmins can customize them via !managerebel menu; changes persist in data/zc_coop_loadouts.json
--
-- Structure: {
--   name = { 
--       name = "Preset Name",
--       subclass = "default|medic|sniper|grenadier",  -- Coop subclass this is for
--       baseClass = "Rebel|Refugee",                  -- Which class to use as base
--       weapons = { "weapon_ak74", ... },             -- Weapon overrides (resolved with $random)
--       armor = { torso = "vest1", head = "helmet1", face = "mask1", ears = "" },  -- Armor overrides
--   }
-- }

ZC_CoopLoadouts = {}

-- Bootstrap request handler: survives partial file init failures.
-- The full handler later in this file will override this callback once loaded.
net.Receive("ZC_RequestCoopLoadouts", function(_, ply)
    if not IsValid(ply) then return end

    print("[ZC CoopLoadouts] SERVER(bootstrap): received ZC_RequestCoopLoadouts from " .. tostring(ply:Nick()) .. " (" .. tostring(ply:SteamID()) .. ")")

    -- If full sender is available, use it.
    if isfunction(_G.ZC_SendCoopLoadouts) then
        local ok = pcall(_G.ZC_SendCoopLoadouts, ply)
        if ok then return end
        print("[ZC CoopLoadouts] SERVER(bootstrap): full sender errored, falling back to minimal send")
    end

    local loadouts = istable(ZC_CoopLoadouts) and ZC_CoopLoadouts or {}
    local count = table.Count(loadouts)

    net.Start("ZC_SendCoopLoadoutsBegin")
    net.WriteUInt(count, 16)
    net.Send(ply)

    for presetName, presetData in pairs(loadouts) do
        local json = util.TableToJSON(presetData)
        if isstring(json) and json ~= "" then
            net.Start("ZC_SendCoopLoadoutEntry")
            net.WriteString(tostring(presetName))
            net.WriteString(json)
            net.Send(ply)
        end
    end

    net.Start("ZC_SendCoopLoadoutsEnd")
    net.Send(ply)

    local allJson = util.TableToJSON(loadouts)
    if isstring(allJson) and #allJson < 60000 then
        net.Start("ZC_SendCoopLoadouts")
        net.WriteString(allJson)
        net.Send(ply)
    end
end)

-- Default presets based on ZCity's official rebel/refugee definitions
local BASE_DEFAULT_COOP_LOADOUTS = {
    ["Rebel Default"] = {
        subclass = "default",
        baseClass = "Rebel",
        weapons = {
            {"$random", "weapon_akm", "weapon_asval", "weapon_mp7", "weapon_spas12", "weapon_xm1014", "weapon_svd", "weapon_osipr"},
            {"$random", "weapon_m9beretta", "weapon_browninghp", "weapon_revolver357", "weapon_revolver2", "weapon_hk_usp", "weapon_glock17"},
            "weapon_hg_hl2nade_tpik",
            "weapon_melee",
            "weapon_walkie_talkie",
        },
        armor = {
            torso = {"$random", "vest5", "vest4", "vest1"},
            head = {"$random", "helmet1", "helmet7"},
            face = {"$random", "mask1", "mask3", "nightvision1", ""},
            ears = "",
        }
    },
    ["Rebel Medic"] = {
        subclass = "medic",
        baseClass = "Rebel",
        weapons = {
            "weapon_bandage_sh",
            "weapon_bloodbag",
            "weapon_medkit_sh",
            "weapon_mannitol",
            "weapon_morphine",
            "weapon_naloxone",
            "weapon_painkillers",
            "weapon_tourniquet",
            "weapon_needle",
            "weapon_betablock",
            "weapon_adrenaline",
            {"$random", "weapon_akm", "weapon_asval", "weapon_mp7", "weapon_spas12", "weapon_xm1014", "weapon_svd", "weapon_osipr"},
            {"$random", "weapon_m9beretta", "weapon_browninghp", "weapon_revolver357", "weapon_revolver2", "weapon_hk_usp", "weapon_glock17"},
            "weapon_melee",
            "weapon_walkie_talkie",
        },
        armor = {
            torso = {"$random", "vest5", "vest4", "vest1"},
            head = {"$random", "helmet1", "helmet7"},
            face = {"$random", "mask1", "mask3", "nightvision1", ""},
            ears = "",
        }
    },
    ["Rebel Sniper"] = {
        subclass = "sniper",
        baseClass = "Rebel",
        weapons = {
            "weapon_hg_crossbow",
            "weapon_revolver357",
            "weapon_melee",
            "weapon_walkie_talkie",
        },
        armor = {
            torso = {"$random", "vest5", "vest4", "vest1"},
            head = {"$random", "helmet1", "helmet7"},
            face = {"$random", "mask1", "mask3", "nightvision1", ""},
            ears = "",
        }
    },
    ["Rebel Grenadier"] = {
        subclass = "grenadier",
        baseClass = "Rebel",
        weapons = {
            {"$random", "weapon_hg_rebelrpg", "weapon_hg_rpg"},
            "weapon_revolver357",
            "weapon_claymore",
            "weapon_traitor_ied",
            "weapon_hg_slam",
            "weapon_hg_pipebomb_tpik",
            "weapon_melee",
            "weapon_walkie_talkie",
        },
        armor = {
            torso = {"$random", "vest5", "vest4", "vest1"},
            head = {"$random", "helmet1", "helmet7"},
            face = {"$random", "mask1", "mask3", "nightvision1", ""},
            ears = "",
        }
    },
    ["Refugee Default"] = {
        subclass = "default",
        baseClass = "Refugee",
        weapons = {
            {"$random", "weapon_doublebarrel", "weapon_mp5", "weapon_mp7", "weapon_sks", "weapon_vpo136", "weapon_winchester"},
            {"$random", "weapon_m9beretta", "weapon_browninghp", "weapon_revolver357", "weapon_revolver2", "weapon_hk_usp", "weapon_glock17"},
            "weapon_melee",
            "weapon_walkie_talkie",
        },
        armor = {
            torso = {"$random", "vest2", ""},
            head = {"$random", "helmet1", ""},
            face = "",
            ears = "",
        }
    },
    ["Refugee Medic"] = {
        subclass = "medic",
        baseClass = "Refugee",
        weapons = {
            {"$random", "weapon_doublebarrel", "weapon_mp5", "weapon_mp7", "weapon_sks", "weapon_vpo136", "weapon_winchester"},
            {"$random", "weapon_m9beretta", "weapon_browninghp", "weapon_revolver357", "weapon_revolver2", "weapon_hk_usp", "weapon_glock17"},
            "weapon_bandage_sh",
            "weapon_medkit_sh",
            "weapon_painkillers",
            "weapon_tourniquet",
            "weapon_melee",
            "weapon_walkie_talkie",
        },
        armor = {
            torso = {"$random", "vest2", ""},
            head = {"$random", "helmet1", ""},
            face = "",
            ears = "",
        }
    },
    ["Combine Default"] = {
        subclass = "default",
        baseClass = "Combine",
        weapons = {
            "weapon_melee",
            "weapon_hg_hl2nade_tpik",
            "weapon_hk_usp",
            {"$random", "weapon_osipr", "weapon_mp7"},
        },
        armor = {
            torso = "", -- applied by Combine playerclass
            head  = "", -- applied by Combine playerclass
            face = "",
            ears = "",
        }
    },
    ["Combine Sniper"] = {
        subclass = "sniper",
        baseClass = "Combine",
        weapons = {
            "weapon_melee",
            "weapon_hg_hl2nade_tpik",
            "weapon_hk_usp",
            "weapon_combinesniper",
        },
        armor = {
            torso = "", -- applied by Combine playerclass
            head  = "", -- applied by Combine playerclass
            face = "",
            ears = "",
        }
    },
    ["Combine Shotgunner"] = {
        subclass = "shotgunner",
        baseClass = "Combine",
        weapons = {
            "weapon_melee",
            "weapon_hg_flashbang_tpik",
            "weapon_hk_usp",
            "weapon_breachcharge",
            "weapon_spas12",
        },
        armor = {
            torso = "", -- applied by Combine playerclass
            head  = "", -- applied by Combine playerclass
            face = "",
            ears = "",
        }
    },
    ["Combine Elite"] = {
        subclass = "elite",
        baseClass = "Combine",
        weapons = {
            "weapon_melee",
            "weapon_hg_hl2nade_tpik",
            "weapon_hk_usp",
            "weapon_osipr",
        },
        armor = {
            torso = "", -- applied by Combine playerclass
            head  = "", -- applied by Combine playerclass
            face = "",
            ears = "",
        }
    },
    ["Metrocop Default"] = {
        subclass = "metropolice",
        baseClass = "Metrocop",
        weapons = {
            "weapon_medkit_sh",
            "weapon_naloxone",
            "weapon_bigbandage_sh",
            "weapon_tourniquet",
            "weapon_hg_stunstick",
            "weapon_handcuffs",
            "weapon_handcuffs_key",
            "weapon_walkie_talkie",
            "weapon_hk_usp",
            "weapon_mp7",
        },
        armor = {
            torso = "", -- applied by Metrocop playerclass
            head  = "", -- applied by Metrocop playerclass
            face = "",
            ears = "",
        }
    },
    ["Gordon Default"] = {
        subclass = "default",
        baseClass = "Gordon",
        weapons = {
            {"$random", "weapon_akm", "weapon_asval", "weapon_mp7", "weapon_spas12", "weapon_xm1014", "weapon_svd", "weapon_osipr"},
            {"$random", "weapon_m9beretta", "weapon_browninghp", "weapon_revolver357", "weapon_revolver2", "weapon_hk_usp", "weapon_glock17"},
            "weapon_hg_hl2nade_tpik",
            "weapon_melee",
            "weapon_walkie_talkie",
        },
        armor = {
            torso = "", -- applied by Gordon playerclass
            head  = "", -- applied by Gordon playerclass
            face = "",
            ears = "",
        }
    },
}

local DEFAULT_PRESET_SOURCE_MAP = {
    ["Rebel Default"] = { "Rebel Assault", "Rebel Default" },
    ["Rebel Medic"] = { "Rebel Medic" },
    ["Rebel Sniper"] = { "Rebel Sniper" },
    ["Rebel Grenadier"] = { "Rebel Grenadier" },
    ["Combine Default"] = { "Combine Soldier", "Combine Default" },
    ["Combine Elite"] = { "Combine Elite" },
    ["Metrocop Default"] = { "Metropolice", "Metrocop Default" },
}

local function ResolveDefaultPresetSource(presetName)
    local source = _G.ZC_EventLoadouts
    if not istable(source) then return nil end

    local candidates = DEFAULT_PRESET_SOURCE_MAP[presetName]
    if istable(candidates) then
        for _, candidate in ipairs(candidates) do
            local src = source[candidate]
            if istable(src) then return src end
        end
    end

    local direct = source[presetName]
    if istable(direct) then return direct end
    return nil
end

local function GetDefaultCoopLoadouts()
    local out = table.Copy(BASE_DEFAULT_COOP_LOADOUTS)

    for presetName, preset in pairs(out) do
        local src = ResolveDefaultPresetSource(presetName)
        if not istable(src) then continue end

        if istable(src.weapons) then
            preset.weapons = table.Copy(src.weapons)
        end

        if istable(src.armor) then
            preset.armor = table.Copy(src.armor)
        end
    end

    return out
end

local STRIP_FACTION_ARMOR_VALUES = {
    cmb_armor = true,
    cmb_helmet = true,
    combine_armor = true,
    combine_helmet = true,
    metrocop_armor = true,
    metrocop_helmet = true,
    gordon_armor = true,
    gordon_helmet = true,
    gordon_arm_armor_left = true,
    gordon_arm_armor_right = true,
    gordon_leg_armor_left = true,
    gordon_leg_armor_right = true,
    gordon_calf_armor_left = true,
    gordon_calf_armor_right = true,
}

local function InferCoopLoadoutBaseClassFromName(presetName)
    local key = string.lower(string.Trim(tostring(presetName or "")))
    if key == "" then return "Rebel" end
    if string.find(key, "gordon", 1, true) or string.find(key, "freeman", 1, true) then return "Gordon" end
    if string.find(key, "metrocop", 1, true) or string.find(key, "metropolice", 1, true) then return "Metrocop" end
    if string.find(key, "combine", 1, true) then return "Combine" end
    if string.find(key, "refugee", 1, true) or string.find(key, "citizen", 1, true) then return "Refugee" end
    return "Rebel"
end

local function NormalizeCoopLoadoutBaseClass(value, presetName)
    local raw = string.Trim(tostring(value or ""))
    local key = string.lower(string.Trim(tostring(value or "")))
    if key == "" then
        return InferCoopLoadoutBaseClassFromName(presetName)
    end

    if key == "rebel" or key == "resistance" then return "Rebel" end
    if key == "refugee" or key == "citizen" then return "Refugee" end
    if key == "combine" or key == "overwatch" then return "Combine" end
    if key == "metrocop" or key == "metropolice" or key == "civil protection" or key == "civilprotection" then return "Metrocop" end
    if key == "gordon" or key == "freeman" or key == "gordon freeman" then return "Gordon" end

    -- Preserve unknown class names so manageclasses can target non-coop classes.
    return raw ~= "" and raw or InferCoopLoadoutBaseClassFromName(presetName)
end

local function InferCoopLoadoutSubclassFromName(presetName, baseClass)
    local key = string.lower(string.Trim(tostring(presetName or "")))
    if string.find(key, "grenadier", 1, true) then return "grenadier" end
    if string.find(key, "medic", 1, true) then return "medic" end
    if string.find(key, "sniper", 1, true) then return "sniper" end
    if string.find(key, "shotgun", 1, true) then return "shotgunner" end
    if string.find(key, "elite", 1, true) then return "elite" end
    if baseClass == "Metrocop" then return "metropolice" end
    return "default"
end

local function NormalizeCoopLoadoutSubclass(value, baseClass, presetName)
    local key = string.lower(string.Trim(tostring(value or "")))
    if key == "" or key == "default" or key == "soldier" then
        return InferCoopLoadoutSubclassFromName(presetName, baseClass)
    end

    if key == "citizen" then return "default" end
    if key == "police" or key == "civil protection" or key == "civilprotection" then return "metropolice" end
    return key
end

local function SanitiseCoopArmorTable(armorTbl)
    if not istable(armorTbl) then return {} end

    local out = {}
    for slot, val in pairs(armorTbl) do
        if istable(val) then
            local filtered = {}
            for i, entry in ipairs(val) do
                if i == 1 then
                    filtered[1] = entry
                elseif not STRIP_FACTION_ARMOR_VALUES[string.lower(tostring(entry))] then
                    filtered[#filtered + 1] = entry
                end
            end
            out[slot] = (#filtered <= 1) and "" or filtered
        elseif isstring(val) then
            out[slot] = STRIP_FACTION_ARMOR_VALUES[string.lower(val)] and "" or val
        else
            out[slot] = val
        end
    end

    return out
end

local WEAPON_CLASS_ALIASES = {
    weapon_osi_pr = "weapon_osipr",
}

local function SanitiseCoopWeaponEntry(entry)
    if isstring(entry) then
        return WEAPON_CLASS_ALIASES[string.lower(entry)] or entry
    end

    if not istable(entry) then return entry end

    if istable(entry.value) then
        entry = entry.value
    elseif istable(entry.Value) then
        entry = entry.Value
    else
        entry = table.Copy(entry)
    end

    for i = 1, #entry do
        entry[i] = SanitiseCoopWeaponEntry(entry[i])
    end

    return entry
end

local function SanitiseCoopWeaponsTable(weaponsTbl)
    if not istable(weaponsTbl) then return {} end

    local out = {}
    for i = 1, #weaponsTbl do
        out[i] = SanitiseCoopWeaponEntry(weaponsTbl[i])
    end
    return out
end

local function NormalizeCoopLoadoutPresetData(presetName, data)
    data = istable(data) and data or {}

    local baseClass = NormalizeCoopLoadoutBaseClass(
        data.baseClass or data.className or data.class or data.PlayerClass or data.playerClass,
        presetName
    )
    local subclass = NormalizeCoopLoadoutSubclass(
        data.subclass or data.subClass or data.SubClass or data.role or data.Role,
        baseClass,
        presetName
    )

    local clean = {
        subclass = subclass,
        baseClass = baseClass,
        weapons = SanitiseCoopWeaponsTable(data.weapons or data.Weapons),
        armor = SanitiseCoopArmorTable(data.armor or data.Armor),
    }

    if istable(data.attachments) then
        clean.attachments = table.Copy(data.attachments)
    elseif istable(data.Attachments) then
        clean.attachments = table.Copy(data.Attachments)
    end

    return clean
end

local function NormalizeAllLoadedCoopLoadouts()
    if not istable(ZC_CoopLoadouts) then
        ZC_CoopLoadouts = {}
        return
    end

    local normalized = {}
    for presetName, presetData in pairs(ZC_CoopLoadouts) do
        normalized[tostring(presetName)] = NormalizeCoopLoadoutPresetData(presetName, presetData)
    end

    ZC_CoopLoadouts = normalized
end

-- ── File Persistence ──────────────────────────────────────────────────────────

local LOADOUTS_FILE = "zc_coop_loadouts.json"
local LOADOUTS_FILE_BACKUP = "zc_coop_loadouts.backup.json"

local function SaveCoopLoadouts()
    local json = util.TableToJSON(ZC_CoopLoadouts, true)
    if not isstring(json) or json == "" then
        print("[ZC CoopLoadouts] ERROR: Failed to serialize loadouts; keeping existing file unchanged")
        return false
    end

    local current = file.Read(LOADOUTS_FILE, "DATA")
    if isstring(current) and current ~= "" then
        file.Write(LOADOUTS_FILE_BACKUP, current)
    end

    file.Write(LOADOUTS_FILE, json)
    return true
end

local CORE_CLASS_ORDER = {
    Gordon = 1,
    Rebel = 2,
    Refugee = 3,
    Combine = 3,
    Metrocop = 4,
}

local function ToKnownBaseClass(raw)
    raw = string.Trim(tostring(raw or ""))
    if raw == "" then return "" end

    local key = string.lower(raw)
    if key == "rebel" or key == "resistance" then return "Rebel" end
    if key == "refugee" or key == "refuge" or key == "citizen" then return "Refugee" end
    if key == "combine" or key == "overwatch" then return "Combine" end
    if key == "metrocop" or key == "metropolice" or key == "civilprotection" or key == "civil_protection" then return "Metrocop" end
    if key == "gordon" or key == "freeman" then return "Gordon" end

    return raw
end

local function GetDetectedPlayerClassNames()
    local names = {}
    local seen = {}

    if istable(player) and istable(player.classList) then
        for className in pairs(player.classList) do
            if isstring(className) then
                local clean = ToKnownBaseClass(className)
                if clean ~= "" and not seen[clean] then
                    seen[clean] = true
                    names[#names + 1] = clean
                end
            end
        end
    end

    -- Fallback: discover classes from shipped playerclass files.
    local classFiles = file.Find("homigrad/playerclass/classes/sh_*.lua", "LUA") or {}
    for _, fileName in ipairs(classFiles) do
        local slug = string.match(string.lower(fileName), "^sh_([%w_]+)%.lua$")
        if slug then
            local mapped = ToKnownBaseClass(slug)
            if mapped ~= "" and not seen[mapped] then
                seen[mapped] = true
                names[#names + 1] = mapped
            end
        end
    end

    table.sort(names, function(a, b)
        local ra = CORE_CLASS_ORDER[a] or 999
        local rb = CORE_CLASS_ORDER[b] or 999
        if ra ~= rb then return ra < rb end
        return string.lower(a) < string.lower(b)
    end)

    return names
end

local function EnsureDetectedClassDefaultLoadouts(target)
    if not istable(target) then return false end

    local changed = false
    for _, className in ipairs(GetDetectedPlayerClassNames()) do
        local presetName = className .. " Default"
        if target[presetName] == nil then
            target[presetName] = {
                subclass = "default",
                baseClass = className,
                weapons = {},
                armor = {},
            }
            changed = true
        end
    end

    return changed
end

local function MergeMissingDefaults(target)
    local defaults = GetDefaultCoopLoadouts()
    if not istable(target) then return table.Copy(defaults) end

    for name, preset in pairs(defaults) do
        if target[name] == nil then
            target[name] = table.Copy(preset)
        end
    end

    return target
end

local function EnsureCoopLoadoutsPopulated()
    local changed = false

    if not istable(ZC_CoopLoadouts) then
        ZC_CoopLoadouts = {}
        changed = true
    end

    local before = table.Count(ZC_CoopLoadouts)
    ZC_CoopLoadouts = MergeMissingDefaults(ZC_CoopLoadouts)
    local after = table.Count(ZC_CoopLoadouts)

    if before == 0 and after > 0 then
        print("[ZC CoopLoadouts] WARNING: runtime loadout table was empty; restoring built-in defaults")
        changed = true
    elseif after > before then
        print("[ZC CoopLoadouts] WARNING: missing built-in presets detected; restoring defaults")
        changed = true
    end

    if EnsureDetectedClassDefaultLoadouts(ZC_CoopLoadouts) then
        print("[ZC CoopLoadouts] Added detected playerclass default presets")
        changed = true
    end

    if changed then
        SaveCoopLoadouts()
    end
end

local function SendCoopLoadouts(ply)
    if not IsValid(ply) then return end

    EnsureCoopLoadoutsPopulated()

    local count = table.Count(ZC_CoopLoadouts)
    ply:ChatPrint("[ZC] Server preparing " .. count .. " coop loadouts...")

    -- Serialize once for optional legacy fallback and diagnostics.
    local allJson = util.TableToJSON(ZC_CoopLoadouts)
    if not isstring(allJson) or allJson == "" then
        ply:ChatPrint("[ZC] ERROR: failed to serialize loadouts on server.")
        return
    end

    -- Prefer chunked protocol (Begin/Entry/End) to avoid net string size limits.
    local hasChunk = util.NetworkStringToID("ZC_SendCoopLoadoutsBegin") ~= 0
        and util.NetworkStringToID("ZC_SendCoopLoadoutEntry") ~= 0
        and util.NetworkStringToID("ZC_SendCoopLoadoutsEnd") ~= 0

    if hasChunk then
        local sent = 0
        net.Start("ZC_SendCoopLoadoutsBegin")
        net.WriteUInt(count, 16)
        net.Send(ply)

        for presetName, presetData in pairs(ZC_CoopLoadouts) do
            local json = util.TableToJSON(presetData)
            if isstring(json) and json ~= "" then
                net.Start("ZC_SendCoopLoadoutEntry")
                net.WriteString(presetName)
                net.WriteString(json)
                net.Send(ply)
                sent = sent + 1
            end
        end

        net.Start("ZC_SendCoopLoadoutsEnd")
        net.Send(ply)
        ply:ChatPrint("[ZC] Server chunk-send complete: " .. sent .. "/" .. count .. " entries.")
    else
        ply:ChatPrint("[ZC] WARNING: chunk net strings unavailable, using legacy send.")
    end

    -- Always send legacy snapshot as a compatibility fallback when small enough.
    if #allJson < 60000 then
        net.Start("ZC_SendCoopLoadouts")
        net.WriteString(allJson)
        net.Send(ply)
        ply:ChatPrint("[ZC] Server legacy fallback sent (" .. #allJson .. " bytes).")
    else
        ply:ChatPrint("[ZC] Legacy fallback skipped (" .. #allJson .. " bytes > safe limit).")
    end
end

_G.ZC_SendCoopLoadouts = SendCoopLoadouts

-- Build and send the list of registered armor keys per slot from hg.armor.
-- Filters out faction-specific armor (cmb_armor/cmb_helmet,
-- metrocop_armor/metrocop_helmet, gordon_*, plus legacy combine_* aliases)
-- which are auto-applied by playerclass and should not appear in the loadout editor.
local ARMOR_FACTION_BLACKLIST = {
    cmb_armor           = true,
    cmb_helmet          = true,
    combine_armor       = true,
    combine_helmet      = true,
    metrocop_armor      = true,
    metrocop_helmet     = true,
    gordon_armor        = true,
    gordon_helmet       = true,
    gordon_arm_armor_left   = true,
    gordon_arm_armor_right  = true,
    gordon_leg_armor_left   = true,
    gordon_leg_armor_right  = true,
    gordon_calf_armor_left  = true,
    gordon_calf_armor_right = true,
}

local function InferMenuArmorSlot(key)
    key = string.lower(tostring(key or ""))
    if key == "" then return nil end

    if string.find(key, "headphone", 1, true) or string.find(key, "ear", 1, true) then
        return "ears"
    end

    if string.find(key, "mask", 1, true)
        or string.find(key, "respir", 1, true)
        or string.find(key, "face", 1, true)
        or string.find(key, "nightvision", 1, true)
        or string.find(key, "nv", 1, true) then
        return "face"
    end

    if string.find(key, "helmet", 1, true)
        or string.find(key, "head", 1, true)
        or string.find(key, "visor", 1, true) then
        return "head"
    end

    if string.find(key, "vest", 1, true)
        or string.find(key, "armor", 1, true)
        or string.find(key, "plate", 1, true)
        or string.find(key, "body", 1, true)
        or string.find(key, "torso", 1, true) then
        return "torso"
    end

    return nil
end

local function FallbackArmorDisplayName(armorKey)
    local words = string.Explode("_", tostring(armorKey or ""))
    for i = 1, #words do
        local w = words[i]
        if w == "" then
            words[i] = w
        else
            words[i] = string.upper(string.sub(w, 1, 1)) .. string.lower(string.sub(w, 2))
        end
    end
    local pretty = string.Trim(table.concat(words, " "))
    if pretty == "" then
        return tostring(armorKey or "")
    end
    return pretty
end

local function GetArmorDisplayName(armorKey)
    if not isstring(armorKey) or armorKey == "" then return "" end

    if hg and istable(hg.armorNames) then
        local fromNames = hg.armorNames[armorKey]
        if isstring(fromNames) and string.Trim(fromNames) ~= "" then
            return string.Trim(fromNames)
        end
    end

    local armorRoot = hg and hg.armor
    if istable(armorRoot) then
        for _, slotTbl in pairs(armorRoot) do
            if istable(slotTbl) and istable(slotTbl[armorKey]) then
                local def = slotTbl[armorKey]
                local candidate = def.name or def.title or def.printName or def.displayName
                if isstring(candidate) and string.Trim(candidate) ~= "" then
                    return string.Trim(candidate)
                end
            end
        end
    end

    return FallbackArmorDisplayName(armorKey)
end

local function AddArmorKeysFromScriptFile(path, addKey, displayNames)
    if not isstring(path) or path == "" then return end
    local raw = nil
    if file.Exists(path, "LUA") then
        raw = file.Read(path, "LUA")
    elseif file.Exists(path, "GAME") then
        raw = file.Read(path, "GAME")
    end
    if not isstring(raw) or raw == "" then return end

    local inArmorNames = false
    local currentSlot = nil

    for line in string.gmatch(raw, "[^\r\n]+") do
        local slotStart = string.match(line, "^%s*hg%.armor%.([%w_]+)%s*=%s*{%s*$")
        local startsArmorNames = string.match(line, "^%s*local%s+armorNames%s*=%s*{%s*$") ~= nil
        local closesTable = string.match(line, "^%s*}%s*,?%s*$") ~= nil

        if slotStart then
            inArmorNames = false
            currentSlot = string.lower(slotStart)
        elseif startsArmorNames then
            inArmorNames = true
            currentSlot = nil
        elseif closesTable then
            currentSlot = nil
            if inArmorNames then
                inArmorNames = false
            end
        else
            local armorKey = string.match(line, '%[%s*"([^"]+)"%s*%]%s*=')
            if armorKey then
                if currentSlot then
                    local menuSlot = currentSlot
                    if menuSlot ~= "torso" and menuSlot ~= "head" and menuSlot ~= "face" and menuSlot ~= "ears" then
                        menuSlot = InferMenuArmorSlot(armorKey)
                    end
                    if menuSlot then
                        addKey(menuSlot, armorKey)
                    end
                end

                if inArmorNames and not displayNames[armorKey] then
                    local label = string.match(line, '%]%s*=%s*"([^"]+)"')
                    if isstring(label) and string.Trim(label) ~= "" then
                        displayNames[armorKey] = string.Trim(label)
                    end
                end
            end
        end
    end
end

local function BuildArmorList()
    -- slot -> sorted list of armor key strings
    local result = {}
    local displayNames = {}
    local seenBySlot = {}
    local function addKey(slot, armorKey)
        if not isstring(slot) or not isstring(armorKey) then return end
        if armorKey == "" then return end
        if ARMOR_FACTION_BLACKLIST[armorKey] then return end
        if not seenBySlot[slot] then seenBySlot[slot] = {} end
        if seenBySlot[slot][armorKey] then return end
        seenBySlot[slot][armorKey] = true
        result[slot] = result[slot] or {}
        result[slot][#result[slot] + 1] = armorKey
        if not displayNames[armorKey] then
            displayNames[armorKey] = GetArmorDisplayName(armorKey)
        end
    end

    local armorRoot = hg and hg.armor
    if istable(armorRoot) then
        for slot, slotTbl in pairs(armorRoot) do
            if not istable(slotTbl) then continue end
            for armorKey in pairs(slotTbl) do
                if not isstring(armorKey) then continue end
                local menuSlot = slot
                if menuSlot ~= "torso" and menuSlot ~= "head" and menuSlot ~= "face" and menuSlot ~= "ears" then
                    menuSlot = InferMenuArmorSlot(armorKey)
                end
                if menuSlot then
                    addKey(menuSlot, armorKey)
                end
            end
        end
    end

    -- Auto-discover armor keys from names registry (catches many custom packs)
    -- and classify them to editor slots by key heuristics.
    if hg and istable(hg.armorNames) then
        for armorKey in pairs(hg.armorNames) do
            if isstring(armorKey) and armorKey ~= "" then
                local menuSlot = InferMenuArmorSlot(armorKey)
                if menuSlot then addKey(menuSlot, armorKey) end
            end
        end
    end

    -- Last-chance discovery from loaded scripted entities (ent_armor_*).
    -- Convert entity class names to equipment keys expected by hg.AddArmor.
    if scripted_ents and scripted_ents.GetList then
        local entsList = scripted_ents.GetList() or {}
        for className in pairs(entsList) do
            local cls = string.lower(tostring(className or ""))
            if string.sub(cls, 1, 10) ~= "ent_armor_" then continue end
            local armorKey = string.sub(cls, 11)
            if armorKey == "" then continue end
            local menuSlot = InferMenuArmorSlot(armorKey)
            if menuSlot then addKey(menuSlot, armorKey) end
        end
    end

    -- Fallback discovery from script files so extended armor packs (e.g.
    -- sh_armorstuff_new.lua) still populate editor choices even when their
    -- runtime registration order is late.
    local staticArmorFiles = {
        "homigrad/sh_armorstuff_new.lua",
        "homigrad/sh_armorstuff.lua",
    }
    for _, scriptPath in ipairs(staticArmorFiles) do
        AddArmorKeysFromScriptFile(scriptPath, addKey, displayNames)
    end

    -- Always ensure standard slots exist even if hg.armor doesn't cover them
    local STANDARD = { "torso", "head", "face", "ears" }
    for _, slot in ipairs(STANDARD) do
        if not result[slot] then result[slot] = {} end
        table.sort(result[slot], function(a, b)
            local an = string.lower(displayNames[a] or a)
            local bn = string.lower(displayNames[b] or b)
            if an == bn then
                return a < b
            end
            return an < bn
        end)
    end
    return result, displayNames
end

local function SendArmorList(ply)
    if not IsValid(ply) then return end
    local list, displayNames = BuildArmorList()
    list.__displayNames = displayNames or {}
    local json = util.TableToJSON(list)
    net.Start("ZC_SendArmorList")
    net.WriteString(json)
    net.Send(ply)
end

local function clamp01(v, fallback)
    local n = tonumber(v)
    if not n then return fallback end
    return math.Clamp(n, 0, 4)
end

local function GetSubclassSlotModifiers()
    local function readCV(name, fallback)
        local cv = GetConVar(name)
        return clamp01(cv and cv:GetFloat() or nil, fallback)
    end

    return {
        rebel = {
            medic = readCV("zc_rebel_medic_slot_mult", 1),
            grenadier = readCV("zc_rebel_grenadier_slot_mult", 1),
        },
        combine = {
            sniper = readCV("zc_combine_sniper_slot_mult", 1),
            shotgunner = readCV("zc_combine_shotgunner_slot_mult", 1),
            metropolice = readCV("zc_combine_metropolice_slot_mult", 1),
        }
    }
end

local function SendSubclassSlotModifiers(ply)
    if not IsValid(ply) then return end
    net.Start("ZC_SendSubclassSlotModifiers")
    net.WriteTable(GetSubclassSlotModifiers())
    net.Send(ply)
end

_G.ZC_GetSubclassSlotMultiplier = function(group, subclass, fallback)
    local map = GetSubclassSlotModifiers()
    if not map[group] then return fallback or 1 end
    local value = map[group][subclass]
    if value == nil then return fallback or 1 end
    return tonumber(value) or (fallback or 1)
end

local function GetCoopLoadoutFileTimestamp(path, realm)
    if not file.Exists(path, realm) then return -1 end

    local ok, stamp = pcall(file.Time, path, realm)
    if ok and isnumber(stamp) then
        return stamp
    end

    return -1
end

local function ReadCoopLoadoutSource(path, realm, label)
    if not file.Exists(path, realm) then return nil end

    local raw = file.Read(path, realm)
    local parsed = isstring(raw) and util.JSONToTable(raw) or nil
    if not istable(parsed) or table.Count(parsed) <= 0 then
        return nil
    end

    return {
        path = path,
        realm = realm,
        label = label,
        data = parsed,
        timestamp = GetCoopLoadoutFileTimestamp(path, realm),
    }
end

local function HasCustomCoopLoadoutChanges(tbl)
    if not istable(tbl) then return false end

    if table.Count(tbl) ~= table.Count(BASE_DEFAULT_COOP_LOADOUTS) then
        return true
    end

    for presetName, defaultPreset in pairs(BASE_DEFAULT_COOP_LOADOUTS) do
        local actualPreset = tbl[presetName]
        if not istable(actualPreset) then
            return true
        end

        local actualJson = util.TableToJSON(NormalizeCoopLoadoutPresetData(presetName, actualPreset), true) or ""
        local defaultJson = util.TableToJSON(NormalizeCoopLoadoutPresetData(presetName, defaultPreset), true) or ""
        if actualJson ~= defaultJson then
            return true
        end
    end

    return false
end

local function SelectPrimaryCoopLoadoutSource()
    local primary = ReadCoopLoadoutSource(LOADOUTS_FILE, "DATA", "data-primary")
    local legacy = ReadCoopLoadoutSource(LOADOUTS_FILE, "GAME", "game-primary")

    if primary and legacy then
        local primaryCustomized = HasCustomCoopLoadoutChanges(primary.data)
        local legacyCustomized = HasCustomCoopLoadoutChanges(legacy.data)

        if not primaryCustomized and legacyCustomized then
            return legacy, true
        end

        if primaryCustomized and not legacyCustomized then
            return primary, false
        end

        if (tonumber(legacy.timestamp) or -1) > (tonumber(primary.timestamp) or -1) then
            return legacy, true
        end

        return primary, false
    end

    if legacy and not primary then
        return legacy, true
    end

    return primary, false
end

-- Strip faction armor from all entries in ZC_CoopLoadouts after loading.
-- Handles legacy JSON that was saved before the faction armor blacklist was added.
local function SanitiseAllLoadedArmor()
    local function clean(armorTbl)
        if not istable(armorTbl) then return armorTbl end
        for slot, val in pairs(armorTbl) do
            if isstring(val) and STRIP_FACTION_ARMOR_VALUES[val] then
                armorTbl[slot] = ""
            elseif istable(val) and val[1] == "$random" then
                local filtered = {"$random"}
                for i = 2, #val do
                    if not STRIP_FACTION_ARMOR_VALUES[tostring(val[i])] then filtered[#filtered+1] = val[i] end
                end
                armorTbl[slot] = (#filtered <= 1) and "" or filtered
            end
        end
        return armorTbl
    end
    for _, preset in pairs(ZC_CoopLoadouts) do
        if istable(preset) and istable(preset.armor) then
            clean(preset.armor)
        end
    end
end

local function LoadCoopLoadouts()
    local selectedSource, shouldImportToData = SelectPrimaryCoopLoadoutSource()

    if selectedSource and istable(selectedSource.data) then
        ZC_CoopLoadouts = MergeMissingDefaults(selectedSource.data)
        NormalizeAllLoadedCoopLoadouts()
        SanitiseAllLoadedArmor()  -- strip legacy faction armor AFTER loading

        if shouldImportToData then
            SaveCoopLoadouts()
            print("[ZC CoopLoadouts] Imported " .. table.Count(ZC_CoopLoadouts) .. " presets from " .. tostring(selectedSource.label) .. " into DATA")
        else
            print("[ZC CoopLoadouts] Loaded " .. table.Count(ZC_CoopLoadouts) .. " presets from " .. tostring(selectedSource.label))
        end

        return
    end

    print("[ZC CoopLoadouts] WARNING: Primary loadout sources are missing/invalid; trying DATA backup")

    local backupJson = file.Read(LOADOUTS_FILE_BACKUP, "DATA")
    local backupParsed = isstring(backupJson) and util.JSONToTable(backupJson) or nil
    if istable(backupParsed) then
        ZC_CoopLoadouts = MergeMissingDefaults(backupParsed)
        NormalizeAllLoadedCoopLoadouts()
        SanitiseAllLoadedArmor()
        SaveCoopLoadouts()
        print("[ZC CoopLoadouts] Restored loadouts from backup (" .. table.Count(ZC_CoopLoadouts) .. " presets)")
        return
    end

    print("[ZC CoopLoadouts] WARNING: Backup missing/invalid; falling back to defaults")
    ZC_CoopLoadouts = MergeMissingDefaults({})
    SaveCoopLoadouts()
end

-- Load on startup
LoadCoopLoadouts()
EnsureCoopLoadoutsPopulated()

local function RefreshCoopLoadoutsRuntime(reason)
    local before = table.Count(ZC_CoopLoadouts or {})

    LoadCoopLoadouts()
    EnsureCoopLoadoutsPopulated()

    local after = table.Count(ZC_CoopLoadouts or {})
    print("[ZC CoopLoadouts] Runtime refresh (" .. tostring(reason or "unknown") .. "): " .. tostring(before) .. " -> " .. tostring(after) .. " presets")
end

hook.Add("InitPostEntity", "ZC_CoopLoadouts_StartupRefresh", function()
    RefreshCoopLoadoutsRuntime("InitPostEntity")

    -- Late pass in case dependent tables (e.g., event defaults) initialize slightly later.
    timer.Simple(2, function()
        RefreshCoopLoadoutsRuntime("InitPostEntity+2s")
    end)
end)

hook.Add("PostCleanupMap", "ZC_CoopLoadouts_MapCleanupRefresh", function()
    RefreshCoopLoadoutsRuntime("PostCleanupMap")
end)

hook.Add("ZB_PreRoundStart", "ZC_CoopLoadouts_PreRoundRefresh", function()
    RefreshCoopLoadoutsRuntime("ZB_PreRoundStart")
end)

-- ── Loadout Resolution Functions ──────────────────────────────────────────────

-- Resolve a single "$random" entry to one choice
local function ResolveRandom(entry)
    if not istable(entry) then return entry end
    if entry[1] ~= "$random" then return entry end
    
    local choices = {}
    for i = 2, #entry do
        choices[#choices + 1] = entry[i]
    end
    
    if #choices == 0 then return "" end
    return choices[math.random(#choices)]
end

local function ResolveAttachmentSelection(attachments)
    if not attachments then return nil end
    if not istable(attachments) then return attachments end
    if #attachments == 0 then return attachments end

    -- Supports DM-style preset profiles: { {"att1", "att2"}, {"att3"} }
    if istable(attachments[1]) then
        return table.Random(attachments)
    end

    -- Single explicit profile: {"att1", "att2"}
    return attachments
end

local function PresetHasConfiguredWeapons(preset)
    if not istable(preset) or not istable(preset.weapons) then return false end

    for _, weaponEntry in ipairs(preset.weapons) do
        local resolved = ResolveRandom(weaponEntry)
        if isstring(resolved) and resolved ~= "" then
            return true
        end
    end

    return false
end

local DEFAULT_COOP_PRESET_BY_CLASS = {
    Gordon = {
        default = "Gordon Default",
    },
    Rebel = {
        default = "Rebel Default",
        medic = "Rebel Medic",
        sniper = "Rebel Sniper",
        grenadier = "Rebel Grenadier",
    },
    Refugee = {
        default = "Refugee Default",
        medic = "Refugee Medic",
    },
    Combine = {
        default = "Combine Default",
        sniper = "Combine Sniper",
        shotgunner = "Combine Shotgunner",
        elite = "Combine Elite",
    },
    Metrocop = {
        metropolice = "Metrocop Default",
        default = "Metrocop Default",
    },
}

local function ResolveDefaultCoopPresetName(subClass, baseClass)
    local classPresets = DEFAULT_COOP_PRESET_BY_CLASS[tostring(baseClass or "")]
    if not istable(classPresets) then return nil end

    local key = tostring(subClass or "default")
    return classPresets[key] or classPresets.default
end

local function BuildRandomAttachmentProfile(wep)
    if not IsValid(wep) then return nil end
    if not istable(wep.availableAttachments) then return nil end

    local selected = {}

    local RANDOM_ATTACHMENT_WHITELIST = {
        sight = {
            holo3 = true,
            holo4 = true,
            holo5 = true,
            holo5fur = true,
            holo9 = true,
            holo13 = true,
            holo14 = true,
            optic2 = true,
            optic5 = true,
        },
        underbarrel = {
            laser1 = true,
            laser2 = true,
            laser4 = true,
        },
        barrel = {
            supressor1 = true,
            supressor2 = true,
            supressor5 = true,
            supressor7 = true,
            supressor8 = true,
        },
        grip = {
            grip1 = true,
            grip2 = true,
            grip3 = true,
        },
        magwell = {
            mag1 = true,
        },
    }

    local function IsOpticSlot(slotName)
        slotName = string.lower(tostring(slotName or ""))
        return string.find(slotName, "sight", 1, true)
            or string.find(slotName, "optic", 1, true)
            or string.find(slotName, "scope", 1, true)
    end

    local function GetWhitelistBucket(slotName)
        slotName = string.lower(tostring(slotName or ""))
        if IsOpticSlot(slotName) then return "sight" end
        if string.find(slotName, "barrel", 1, true) or string.find(slotName, "muzzle", 1, true) then return "barrel" end
        if string.find(slotName, "under", 1, true) or string.find(slotName, "laser", 1, true) then return "underbarrel" end
        if string.find(slotName, "grip", 1, true) then return "grip" end
        if string.find(slotName, "mag", 1, true) then return "magwell" end
        return nil
    end

    local function IsAllowedRandomAttachment(slotName, attachmentName)
        slotName = string.lower(tostring(slotName or ""))
        attachmentName = string.lower(tostring(attachmentName or ""))
        if attachmentName == "" then return false end

        local bucket = GetWhitelistBucket(slotName)
        if not bucket then return false end

        local allowed = RANDOM_ATTACHMENT_WHITELIST[bucket]
        return allowed and allowed[attachmentName] or false
    end

    for slotName, options in pairs(wep.availableAttachments) do
        if not istable(options) then continue end

        local candidates = {}
        for _, option in pairs(options) do
            if istable(option) and isstring(option[1]) and option[1] ~= "empty" then
                if IsAllowedRandomAttachment(slotName, option[1]) then
                    candidates[#candidates + 1] = option[1]
                end
            end
        end

        if #candidates > 0 and math.random(1, 100) <= 85 then
            selected[#selected + 1] = candidates[math.random(#candidates)]
        end
    end

    if #selected == 0 then return nil end
    return selected
end

local function ApplyAttachmentsToFirstAttachableWeapon(ply, givenWeapons, presetAttachments)
    if not IsValid(ply) then return false end
    if not hg or not hg.AddAttachmentForce then return false end
    if not istable(givenWeapons) then return false end

    local targetWeapon = nil
    for _, wep in ipairs(givenWeapons) do
        if IsValid(wep) and istable(wep.attachments) and istable(wep.availableAttachments) then
            targetWeapon = wep
            break
        end
    end

    if not IsValid(targetWeapon) then return false end

    local selection = ResolveAttachmentSelection(presetAttachments)
    if not selection and zc_coop_random_attachments:GetBool() then
        selection = BuildRandomAttachmentProfile(targetWeapon)
    end

    if not selection or selection == "" then return false end

    hg.AddAttachmentForce(ply, targetWeapon, selection)
    return true
end

-- Apply a coop loadout preset to a player
-- Returns: (success, presetName) tuple
local function ApplyCoopLoadoutPreset(ply, presetName)
    if not presetName or not ZC_CoopLoadouts[presetName] then
        return false, nil
    end

    local preset = NormalizeCoopLoadoutPresetData(presetName, ZC_CoopLoadouts[presetName])
    local applied = false
    local givenWeapons = {}

    ply:SetSuppressPickupNotices(true)
    ply.noSound = true

    ply:StripWeapons()

    local inv = ply:GetNetVar("Inventory", {})
    inv["Weapons"] = { ["hg_sling"] = true, ["hg_flashlight"] = true }
    ply:SetNetVar("Inventory", inv)

    if istable(ply.armors) then
        -- Clear old armor silently on respawn; do not spawn dropped armor entities.
        for _, slot in ipairs(ARMOR_SLOTS) do
            ply.armors[slot] = nil
        end
        if pcall(function() return ply.SyncArmor end) and ply.SyncArmor then
            pcall(function() ply:SyncArmor() end)
        end
    end

    if preset.weapons and istable(preset.weapons) then
        -- Pre-count how many times each class appears so count-based weapons (grenades)
        -- get their count set correctly. ply:Give() always resets count to 1, so we
        -- give once and then set wep.count = N manually.
        local classCount = {}
        local resolvedWeapons = {}
        for _, weapon in ipairs(preset.weapons) do
            local resolved = ResolveRandom(weapon)
            if resolved ~= "" then
                resolvedWeapons[#resolvedWeapons + 1] = resolved
                classCount[resolved] = (classCount[resolved] or 0) + 1
            end
        end

        local classGiven = {}
        for _, resolved in ipairs(resolvedWeapons) do
            if resolved ~= "" and not classGiven[resolved] then
                classGiven[resolved] = true
                local wep = ply:Give(resolved)
                if IsValid(wep) then
                    givenWeapons[#givenWeapons + 1] = wep
                    -- For count-based weapons (homigrad grenades) set count directly
                    local countForClass = tonumber(classCount[resolved]) or 0
                    if wep.count ~= nil and countForClass > 1 then
                        wep.count = classCount[resolved]
                    end
                end
                applied = true
            end
        end
    end

    ApplyAttachmentsToFirstAttachableWeapon(ply, givenWeapons, preset.attachments)

    -- Apply armor only when explicitly enabled for this preset.
    if preset.autoArmor == true and preset.armor and istable(preset.armor) then
        local armor = preset.armor

        local function IsArmorAllowedForCurrentClass(armorClass)
            local cls = tostring(ply.PlayerClassName or "")
            if string.StartWith(armorClass, "gordon_") then return cls == "Gordon" end
            if string.StartWith(armorClass, "cmb_") then return cls == "Combine" end
            if string.StartWith(armorClass, "combine_") then return cls == "Combine" end
            if string.StartWith(armorClass, "metrocop_") then return cls == "Metrocop" end
            return true
        end

        local function TryApplyArmor(armorEntry)
            local resolved = ResolveRandom(armorEntry)
            if not isstring(resolved) or resolved == "" then return end

            resolved = string.lower(resolved)
            if not IsArmorAllowedForCurrentClass(resolved) then return end

            if hg and hg.AddArmor then
                local ok = pcall(function()
                    hg.AddArmor(ply, resolved)
                end)
                if ok then
                    applied = true
                end
            end
        end

        if armor.torso then
            TryApplyArmor(armor.torso)
        end

        if armor.head then
            TryApplyArmor(armor.head)
        end

        if armor.face then
            TryApplyArmor(armor.face)
        end

        if armor.ears then
            TryApplyArmor(armor.ears)
        end

        if pcall(function() return ply.SyncArmor end) and ply.SyncArmor then
            pcall(function() ply:SyncArmor() end)
        end
    end

    if _G.ZC_ApplyPlayerClassArmor then
        local ok, classArmorApplied = pcall(_G.ZC_ApplyPlayerClassArmor, ply)
        if ok and classArmorApplied then
            applied = true
        end
    end


    if applied then
        ply:Give("weapon_hands_sh")
        ply:SelectWeapon("weapon_hands_sh")
    end

    timer.Simple(0.1, function()
        if IsValid(ply) then
            ply.noSound = false
            ply:SetSuppressPickupNotices(false)
        end
    end)

    return applied, presetName
end

-- Select a random loadout that matches the given subclass and baseClass
-- Returns: (success, presetName)
local function SelectCoopLoadoutPresetName(subClass, baseClass)
    local matching = {}
    local preferred = {}
    local canonicalPresetName = ResolveDefaultCoopPresetName(subClass, baseClass)

    if canonicalPresetName then
        local canonicalPreset = NormalizeCoopLoadoutPresetData(canonicalPresetName, ZC_CoopLoadouts[canonicalPresetName])
        if istable(canonicalPreset) and canonicalPreset.baseClass == baseClass and canonicalPreset.subclass == subClass then
            if baseClass ~= "Gordon" or PresetHasConfiguredWeapons(canonicalPreset) then
                return canonicalPresetName
            end
        end
    end

    for presetName, preset in pairs(ZC_CoopLoadouts) do
        local presetBaseClass = NormalizeCoopLoadoutBaseClass(
            istable(preset) and (preset.baseClass or preset.className or preset.class or preset.PlayerClass or preset.playerClass) or nil,
            presetName
        )
        local presetSubClass = NormalizeCoopLoadoutSubclass(
            istable(preset) and (preset.subclass or preset.subClass or preset.SubClass or preset.role or preset.Role) or nil,
            presetBaseClass,
            presetName
        )

        if presetBaseClass == baseClass and presetSubClass == subClass then
            matching[#matching + 1] = presetName
            if baseClass ~= "Gordon" or PresetHasConfiguredWeapons(preset) then
                preferred[#preferred + 1] = presetName
            end
        end
    end

    -- If Gordon presets are present but empty, fall back to configured rebel
    -- presets so managed non-d1/d2 maps still grant useful loadouts.

    if baseClass == "Gordon" and #preferred == 0 then
        local gordonFallbacks = {
            canonicalPresetName,
            "Gordon Default",
            "Rebel Default",
            "Rebel Assault",
            "Refugee Default",
        }

        for _, presetName in ipairs(gordonFallbacks) do
            local preset = ZC_CoopLoadouts[presetName]
            if istable(preset) and PresetHasConfiguredWeapons(preset) then
                return presetName
            end
        end
    end

    if #matching == 0 then
        return nil
    end

    local pool = (#preferred > 0) and preferred or matching
    return pool[math.random(#pool)]
end

local function SelectRandomCoopLoadoutForClass(ply, subClass, baseClass)
    local chosen = SelectCoopLoadoutPresetName(subClass, baseClass)
    if not chosen then
        return false, nil
    end

    return ApplyCoopLoadoutPreset(ply, chosen)
end

-- Find all presets for a specific subclass and baseClass
local function GetPresetsForClass(subClass, baseClass)
    local result = {}
    for presetName, preset in pairs(ZC_CoopLoadouts) do
        local presetBaseClass = NormalizeCoopLoadoutBaseClass(
            istable(preset) and (preset.baseClass or preset.className or preset.class or preset.PlayerClass or preset.playerClass) or nil,
            presetName
        )
        local presetSubClass = NormalizeCoopLoadoutSubclass(
            istable(preset) and (preset.subclass or preset.subClass or preset.SubClass or preset.role or preset.Role) or nil,
            presetBaseClass,
            presetName
        )

        if presetBaseClass == baseClass and presetSubClass == subClass then
            result[#result + 1] = presetName
        end
    end
    return result
end

local function GetCanonicalCurrentMap()
    local mapName = string.lower(tostring(game.GetMap() or ""))
    if mapName == "" then return "" end
    if ZC_MapRoute and ZC_MapRoute.GetCanonicalMap then
        return tostring(ZC_MapRoute.GetCanonicalMap(mapName) or mapName)
    end
    return mapName
end

-- Use native/base Gordon equipment only on d1_/d2_ maps.
-- All other maps should use managed Gordon loadouts.
local function ShouldUseManagedGordonLoadout()
    local canonical = GetCanonicalCurrentMap()
    if canonical == "" then return true end
    if string.match(canonical, "^d1_") then return false end
    if string.match(canonical, "^d2_") then return false end
    return true
end

local function ResolveCoopLoadoutContextForPlayer(ply)
    if not IsValid(ply) then return nil, nil end

    local className = tostring(ply.PlayerClassName or "")
    local subClass = tostring(ply.subClass or "")

    if className == "Gordon" then
        if not ShouldUseManagedGordonLoadout() then return nil, nil end
        return "default", "Gordon"
    end

    if className == "Rebel" then
        return (subClass ~= "" and subClass or "default"), "Rebel"
    end

    if className == "Refugee" or className == "Citizen" then
        return (subClass ~= "" and subClass or "default"), "Refugee"
    end

    if className == "Combine" then
        return (subClass ~= "" and subClass or "default"), "Combine"
    end

    if className == "Metrocop" then
        if subClass == "" or subClass == "default" then
            return "metropolice", "Metrocop"
        end
        return subClass, "Metrocop"
    end

    if className ~= "" then
        return (subClass ~= "" and subClass or "default"), className
    end

    return nil, nil
end

local function ResolveCoopLoadoutContextFromClassName(className, subClass)
    className = string.Trim(tostring(className or ""))
    if className == "Citizen" then
        className = "Refugee"
    end

    subClass = tostring(subClass or "")
    if subClass == "" then
        subClass = "default"
    end

    if className == "Gordon" then
        return "default", "Gordon", "Gordon"
    end

    if className == "Rebel" then
        return subClass, "Rebel", "Rebel"
    end

    if className == "Refugee" then
        return subClass, "Refugee", "Refugee"
    end

    if className == "Combine" then
        return subClass, "Combine", "Combine"
    end

    if className == "Metrocop" then
        if subClass == "default" then
            subClass = "metropolice"
        end
        return subClass, "Metrocop", "Metrocop"
    end

    if className ~= "" then
        return subClass, className, className
    end

    return nil, nil, className
end

-- ── Global Functions for Integration ──────────────────────────────────────────

-- Apply a coop loadout to a player by preset name and subclass/class filters
-- This is called from coop respawn/subclass systems
_G.ZC_ApplyCoopLoadout = function(ply, subClass, baseClass)
    return SelectRandomCoopLoadoutForClass(ply, subClass, baseClass)
end

_G.ZC_ApplyNamedCoopLoadout = function(ply, presetName)
    return ApplyCoopLoadoutPreset(ply, presetName)
end

_G.ZC_ShouldUseManagedGordonLoadout = ShouldUseManagedGordonLoadout

local function IsCoopRoundActive()
    if isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) and string.lower(tostring(round.name or "")) == "coop" then
            return true
        end
    end

    return string.lower(tostring(istable(zb) and zb.CROUND or "")) == "coop"
end

local function HasNonHandsWeapon(ply)
    if not IsValid(ply) then return false end
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and wep:GetClass() ~= "weapon_hands_sh" then
            return true
        end
    end
    return false
end

local function TryApplyManagedGordonLoadout(ply)
    if not IsValid(ply) or tostring(ply.PlayerClassName or "") ~= "Gordon" then
        return false, nil
    end

    if not ShouldUseManagedGordonLoadout() then
        return false, nil
    end

    local customApplied, appliedPresetName = false, nil
    local cachedPresetName = tostring(ply.ZC_ManagedGordonPresetName or "")

    if cachedPresetName ~= "" and istable(ZC_CoopLoadouts) and ZC_CoopLoadouts[cachedPresetName] and ZC_ApplyNamedCoopLoadout then
        customApplied, appliedPresetName = ZC_ApplyNamedCoopLoadout(ply, cachedPresetName)
    elseif ZC_ApplyCoopLoadout then
        customApplied, appliedPresetName = ZC_ApplyCoopLoadout(ply, "default", "Gordon")
    end

    customApplied = customApplied == true

    if (not customApplied) or (not HasNonHandsWeapon(ply)) then
        local fallbacks = {
            cachedPresetName,
            "Gordon Default",
            "Rebel Default",
            "Rebel Assault",
            "Refugee Default",
        }

        for _, fallbackName in ipairs(fallbacks) do
            if fallbackName ~= "" and istable(ZC_CoopLoadouts) and ZC_CoopLoadouts[fallbackName] then
                local ok, appliedName = ApplyCoopLoadoutPreset(ply, fallbackName)
                if ok and HasNonHandsWeapon(ply) then
                    customApplied = true
                    appliedPresetName = appliedName or fallbackName
                    break
                end
            end
        end
    end

    if customApplied and isstring(appliedPresetName) and appliedPresetName ~= "" then
        ply.ZC_ManagedGordonPresetName = appliedPresetName
    end

    local inv = ply:GetNetVar("Inventory", {})
    inv["Weapons"] = { ["hg_sling"] = true, ["hg_flashlight"] = true }
    ply:SetNetVar("Inventory", inv)

    if IsValid(ply:GetWeapon("weapon_hands_sh")) then
        ply:SelectWeapon("weapon_hands_sh")
    end

    return customApplied and HasNonHandsWeapon(ply), appliedPresetName
end

local function QueueManagedGordonLoadout(ply, attempt, maxAttempts)
    if not IsValid(ply) or not ply:Alive() then return end

    local ok = select(1, TryApplyManagedGordonLoadout(ply))
    if ok then return end

    attempt = attempt or 1
    maxAttempts = maxAttempts or 12
    if attempt >= maxAttempts then return end

    timer.Simple(0.25, function()
        QueueManagedGordonLoadout(ply, attempt + 1, maxAttempts)
    end)
end

_G.ZC_EnsureManagedGordonLoadout = function(ply, delay, maxAttempts)
    if not IsValid(ply) then return false end

    timer.Simple(delay or 0, function()
        if not IsValid(ply) then return end
        QueueManagedGordonLoadout(ply, 1, maxAttempts or 12)
    end)

    return true
end

_G.ZC_ApplyCoopClassLoadout = function(ply, options)
    if not IsValid(ply) then return false, nil end

    options = options or {}

    local requestedClass = tostring(options.className or ply.PlayerClassName or "")
    local requestedSubClass = options.subClass
    if requestedSubClass == nil then
        requestedSubClass = ply.subClass
    end

    local subClassKey, baseClass, classToSet = ResolveCoopLoadoutContextFromClassName(requestedClass, requestedSubClass)
    if not baseClass or classToSet == "" then return false, nil end

    local preserveWeapons = options.preserveWeapons == true
    local allowEmptyFallback = options.allowEmptyFallback ~= false
    local skipNativeEquipment = options.skipNativeEquipment == true
    local resolvedSubClass = (subClassKey ~= "default") and subClassKey or nil

    if classToSet == "Gordon" then
        local shouldManage = not options.forceNativeGordon and ShouldUseManagedGordonLoadout()
        local playerEquipment = tostring(options.playerEquipment or options.equipment or "rebel")

        if shouldManage then
            ply:SetPlayerClass("Gordon", {
                bRestored = options.bRestored == true,
            })

            local hasWeapons = HasNonHandsWeapon(ply)
            if preserveWeapons and hasWeapons then
                return true, "Gordon"
            end

            if preserveWeapons and not allowEmptyFallback then
                return false, "Gordon"
            end

            local applied = select(1, TryApplyManagedGordonLoadout(ply)) == true
            if not applied and options.queueManagedRetry ~= false and _G.ZC_EnsureManagedGordonLoadout then
                _G.ZC_EnsureManagedGordonLoadout(ply, options.retryDelay or 0.1, options.maxAttempts or 12)
            end

            return applied or HasNonHandsWeapon(ply), "Gordon"
        end

        ply:SetPlayerClass("Gordon", {
            equipment = playerEquipment,
            bRestored = options.bRestored == true,
        })
        return true, "Gordon"
    end

    ply.subClass = resolvedSubClass
    ply:SetPlayerClass(classToSet, { bNoEquipment = true })
    ply.subClass = resolvedSubClass

    if preserveWeapons and HasNonHandsWeapon(ply) then
        return true, baseClass
    end

    if preserveWeapons and not allowEmptyFallback then
        return false, baseClass
    end

    local customApplied = false
    if _G.ZC_ApplyCoopLoadout then
        customApplied = select(1, _G.ZC_ApplyCoopLoadout(ply, subClassKey, baseClass)) == true
    end

    if not customApplied and not skipNativeEquipment then
        local ok, err = pcall(function()
            ply:PlayerClassEvent("GiveEquipment", resolvedSubClass)
        end)
        if not ok then
            print("[ZC CoopLoadouts] GiveEquipment fallback error for " .. tostring(ply:Nick()) .. ": " .. tostring(err))
        end
        customApplied = ok and HasNonHandsWeapon(ply)
    end

    return customApplied or HasNonHandsWeapon(ply), baseClass
end

-- Late spawn guard: some class/event paths can grant equipment after SetPlayerClass.
-- Re-assert managed Gordon loadout and always ensure hands for all classes.
hook.Add("Player Spawn", "ZC_CoopLoadouts_PostSpawnGuard", function(ply)
    local function RunPostSpawnGuard(attempt)
        if not IsValid(ply) or not ply:Alive() then return end

        if not IsValid(ply:GetWeapon("weapon_hands_sh")) then
            ply:Give("weapon_hands_sh")
        end

        if not IsCoopRoundActive() then
            if (attempt or 1) < 8 then
                timer.Simple(0.25, function()
                    RunPostSpawnGuard((attempt or 1) + 1)
                end)
            end
            return
        end


        local subClass, baseClass = ResolveCoopLoadoutContextForPlayer(ply)
        if not subClass or not baseClass then
            if (attempt or 1) < 8 then
                timer.Simple(0.25, function()
                    RunPostSpawnGuard((attempt or 1) + 1)
                end)
            end
            return
        end

        local isGordon = (baseClass == "Gordon")

        local customApplied, appliedPresetName = false, nil
        if isGordon then
            customApplied, appliedPresetName = TryApplyManagedGordonLoadout(ply)
        elseif ZC_ApplyCoopLoadout then
            customApplied, appliedPresetName = ZC_ApplyCoopLoadout(ply, subClass, baseClass)
        end
        customApplied = customApplied == true

        if (not customApplied or not HasNonHandsWeapon(ply)) and (attempt or 1) < 12 then
            timer.Simple(0.25, function()
                RunPostSpawnGuard((attempt or 1) + 1)
            end)
        end

        if IsValid(ply:GetWeapon("weapon_hands_sh")) then
            ply:SelectWeapon("weapon_hands_sh")
        end
    end

    if tostring(ply.PlayerClassName or "") == "Gordon" then
        ply.ZC_ManagedGordonPresetName = nil
    end

    timer.Simple(0.25, function()
        RunPostSpawnGuard(1)
    end)
end)

-- Get all available coop loadout names
_G.ZC_GetAllCoopLoadoutNames = function()
    local names = {}
    for name, _ in pairs(ZC_CoopLoadouts) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

-- Get preset data (for editing)
_G.ZC_GetCoopLoadoutData = function(presetName)
    return ZC_CoopLoadouts[presetName]
end

-- Get all presets for a specific class
_G.ZC_GetCoopLoadsoutsForClass = function(subClass, baseClass)
    return GetPresetsForClass(subClass, baseClass)
end

-- Create or update a coop loadout preset
_G.ZC_SetCoopLoadout = function(presetName, data)
    if not presetName or not data then return false end
    if not istable(data) then return false end

    local clean = NormalizeCoopLoadoutPresetData(presetName, data)

    if istable(data.attachments) then
        clean.attachments = data.attachments
    elseif istable(ZC_CoopLoadouts[presetName]) and istable(ZC_CoopLoadouts[presetName].attachments) then
        -- Preserve existing attachments if UI did not send them.
        clean.attachments = ZC_CoopLoadouts[presetName].attachments
    end

    ZC_CoopLoadouts[presetName] = clean
    if not SaveCoopLoadouts() then
        return false
    end
    return true
end

-- Delete a coop loadout preset
_G.ZC_DeleteCoopLoadout = function(presetName)
    if not presetName or not ZC_CoopLoadouts[presetName] then return false end
    ZC_CoopLoadouts[presetName] = nil
    if not SaveCoopLoadouts() then
        return false
    end
    return true
end

-- Rename a coop loadout preset
_G.ZC_RenameCoopLoadout = function(oldName, newName)
    if not oldName or not newName or not ZC_CoopLoadouts[oldName] then return false end
    if oldName == newName then return true end
    if ZC_CoopLoadouts[newName] then return false end -- name exists
    
    ZC_CoopLoadouts[newName] = ZC_CoopLoadouts[oldName]
    ZC_CoopLoadouts[oldName] = nil
    if not SaveCoopLoadouts() then
        return false
    end
    return true
end

print("[ZC CoopLoadouts] Loaded " .. table.Count(ZC_CoopLoadouts) .. " coop loadout presets")

-- ── Network Messaging for Client Menu ──────────────────────────────────────────

local function HasCoopLoadoutAccess(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return true end

    -- Optional ULib permission hook for delegated groups.
    if ULib and ULib.ucl and ULib.ucl.query then
        if ULib.ucl.query(ply, "zc_manage_coop_loadouts") then
            return true
        end
    end

    return false
end

local function DenyCoopLoadoutAccess(ply)
    if not IsValid(ply) then return end
    ply:ChatPrint("[ZC] Coop loadout edit denied: admin permission required.")
end

-- Receive loadout save from client
net.Receive("ZC_SaveCoopLoadout", function(len, ply)
    if not HasCoopLoadoutAccess(ply) then
        DenyCoopLoadoutAccess(ply)
        return
    end

    local presetName = net.ReadString()
    local data = net.ReadTable()

    ZC_SetCoopLoadout(presetName, data)
    SendCoopLoadouts(ply)
    
    print("[ZC CoopLoadouts] Loadout '" .. presetName .. "' saved by " .. ply:Nick())
end)

-- Receive loadout delete from client
net.Receive("ZC_DeleteCoopLoadout", function(len, ply)
    if not HasCoopLoadoutAccess(ply) then
        DenyCoopLoadoutAccess(ply)
        return
    end

    local presetName = net.ReadString()
    ZC_DeleteCoopLoadout(presetName)
    SendCoopLoadouts(ply)
    
    print("[ZC CoopLoadouts] Loadout '" .. presetName .. "' deleted by " .. ply:Nick())
end)

-- JSON-based save: avoids net.WriteTable mangling numeric keys in nested tables
-- ($random weapon arrays come back with string keys via WriteTable, breaking JSON)
net.Receive("ZC_SaveCoopLoadoutJSON", function(len, ply)
    if not HasCoopLoadoutAccess(ply) then
        DenyCoopLoadoutAccess(ply)
        return
    end
    local presetName = net.ReadString()
    local jsonStr    = net.ReadString()
    local data       = util.JSONToTable(jsonStr)
    if not istable(data) then
        print("[ZC CoopLoadouts] JSON parse failed for save from " .. ply:Nick())
        return
    end
    ZC_SetCoopLoadout(presetName, data)
    SendCoopLoadouts(ply)
    print("[ZC CoopLoadouts] Loadout '" .. presetName .. "' saved (JSON) by " .. ply:Nick())
end)

-- Reset one preset to its built-in default
net.Receive("ZC_ResetCoopLoadoutToDefault", function(len, ply)
    if not HasCoopLoadoutAccess(ply) then
        DenyCoopLoadoutAccess(ply)
        return
    end
    local presetName = net.ReadString()
    local def = BASE_DEFAULT_COOP_LOADOUTS[presetName]
    if not def then
        ply:ChatPrint("[ZC] No built-in default for '" .. presetName .. "'.")
        return
    end
    -- Deep copy weapons/armor before passing to ZC_SetCoopLoadout
    local weps = {}
    for i, w in ipairs(def.weapons or {}) do
        if istable(w) then
            local inner = {}
            for j, v in ipairs(w) do inner[j] = v end
            weps[i] = inner
        else
            weps[i] = w
        end
    end
    local arm = {}
    for slot, val in pairs(def.armor or {}) do
        if istable(val) then
            local inner = {}
            for j, v in ipairs(val) do inner[j] = v end
            arm[slot] = inner
        else
            arm[slot] = val
        end
    end
    ZC_SetCoopLoadout(presetName, {
        subclass  = def.subclass,
        baseClass = def.baseClass,
        weapons   = weps,
        armor     = arm,
    })
    SendCoopLoadouts(ply)
    print("[ZC CoopLoadouts] Loadout '" .. presetName .. "' reset to original default by " .. ply:Nick())
end)

-- Reset ALL presets to built-in defaults
net.Receive("ZC_ResetAllCoopLoadoutsToDefault", function(len, ply)
    if not HasCoopLoadoutAccess(ply) then
        DenyCoopLoadoutAccess(ply)
        return
    end

    ply:ChatPrint("[ZC] Server accepted Reset All. Rebuilding built-in defaults...")

    -- Deep-copy each default preset into a fresh table.
    -- GMod's table.Copy is shallow, so weapon/armor sub-arrays must be copied manually.
    local function deepCopyPreset(p)
        local weps = {}
        for i, w in ipairs(p.weapons or {}) do
            if istable(w) then
                local inner = {}
                for j, v in ipairs(w) do inner[j] = v end
                weps[i] = inner
            else
                weps[i] = w
            end
        end
        local arm = {}
        for slot, val in pairs(p.armor or {}) do
            if istable(val) then
                local inner = {}
                for j, v in ipairs(val) do inner[j] = v end
                arm[slot] = inner
            else
                arm[slot] = val
            end
        end
        return {
            subclass  = tostring(p.subclass  or "default"),
            baseClass = tostring(p.baseClass or "Rebel"),
            weapons   = weps,
            armor     = arm,
        }
    end

    -- Wipe and repopulate from BASE_DEFAULT_COOP_LOADOUTS.
    -- Iterate the source constant, NOT ZC_CoopLoadouts, to avoid mutation-while-iterating.
    ZC_CoopLoadouts = {}
    local baseCount = table.Count(BASE_DEFAULT_COOP_LOADOUTS)
    print("[ZC CoopLoadouts] ResetAll: BASE_DEFAULT_COOP_LOADOUTS has " .. baseCount .. " entries")
    for presetName, presetData in pairs(BASE_DEFAULT_COOP_LOADOUTS) do
        ZC_CoopLoadouts[presetName] = deepCopyPreset(presetData)
        print("[ZC CoopLoadouts] ResetAll: copied preset '" .. presetName .. "'")
    end
    print("[ZC CoopLoadouts] ResetAll: ZC_CoopLoadouts now has " .. table.Count(ZC_CoopLoadouts) .. " entries")

    local saved = SaveCoopLoadouts()
    ply:ChatPrint("[ZC] Reset All save result: " .. tostring(saved) .. ", presets=" .. table.Count(ZC_CoopLoadouts))
    SendCoopLoadouts(ply)
    ply:ChatPrint("[ZC] Reset All complete.")
end)

-- Send loadouts to client when requested
net.Receive("ZC_RequestCoopLoadouts", function(len, ply)
    if not IsValid(ply) then return end
    print("[ZC CoopLoadouts] SERVER: received ZC_RequestCoopLoadouts from " .. tostring(ply:Nick()) .. " (" .. tostring(ply:SteamID()) .. ")")
    ply:ChatPrint("[ZC] Server received coop loadout request.")
    SendCoopLoadouts(ply)
    SendArmorList(ply)  -- send armor list alongside loadouts
end)

net.Receive("ZC_RequestArmorList", function(len, ply)
    if not HasCoopLoadoutAccess(ply) then return end
    SendArmorList(ply)
end)

net.Receive("ZC_RequestSubclassSlotModifiers", function(_, ply)
    if not HasCoopLoadoutAccess(ply) then return end
    SendSubclassSlotModifiers(ply)
end)

net.Receive("ZC_SaveSubclassSlotModifiers", function(_, ply)
    if not HasCoopLoadoutAccess(ply) then
        DenyCoopLoadoutAccess(ply)
        return
    end

    local payload = net.ReadTable() or {}
    local rebel = payload.rebel or {}
    local combine = payload.combine or {}

    RunConsoleCommand("zc_rebel_medic_slot_mult", tostring(clamp01(rebel.medic, 1)))
    RunConsoleCommand("zc_rebel_grenadier_slot_mult", tostring(clamp01(rebel.grenadier, 1)))
    RunConsoleCommand("zc_combine_sniper_slot_mult", tostring(clamp01(combine.sniper, 1)))
    RunConsoleCommand("zc_combine_shotgunner_slot_mult", tostring(clamp01(combine.shotgunner, 1)))
    RunConsoleCommand("zc_combine_metropolice_slot_mult", tostring(clamp01(combine.metropolice, 1)))

    SendSubclassSlotModifiers(ply)
end)
