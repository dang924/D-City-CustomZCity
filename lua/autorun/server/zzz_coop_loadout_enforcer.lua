if CLIENT then return end
if _G.ZC_CoopLoadoutEnforcerLoaded then return end

local LOADOUTS_FILE = "zc_coop_loadouts.json"
local LOADOUTS_FILE_BACKUP = "zc_coop_loadouts.backup.json"

local DEFAULT_PRESET_BY_CLASS = {
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
        default = "Metrocop Default",
        metropolice = "Metrocop Default",
    },
}

local WEAPON_CLASS_ALIASES = {
    weapon_osi_pr = "weapon_osipr",
}

local ARMOR_SLOTS = { "torso", "head", "ears", "face" }

local function CurrentRoundIsCoop()
    if istable(zb) and string.lower(tostring(zb.CROUND or "")) == "coop" then
        return true
    end

    if CurrentRound then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) and string.lower(tostring(round.name or "")) == "coop" then
            return true
        end
    end

    return false
end

local function GetCanonicalCurrentMap()
    local mapName = string.lower(tostring(game.GetMap() or ""))
    if mapName == "" then return "" end
    if ZC_MapRoute and ZC_MapRoute.GetCanonicalMap then
        return tostring(ZC_MapRoute.GetCanonicalMap(mapName) or mapName)
    end
    return mapName
end

local function ShouldUseManagedGordonLoadout()
    if _G.ZC_ShouldUseManagedGordonLoadout then
        local ok, managed = pcall(_G.ZC_ShouldUseManagedGordonLoadout)
        if ok then
            return managed == true
        end
    end

    local canonical = GetCanonicalCurrentMap()
    if canonical == "" then return true end
    if string.match(canonical, "^d1_") then return false end
    if string.match(canonical, "^d2_") then return false end
    return true
end

local function TableCountSafe(tbl)
    return istable(tbl) and table.Count(tbl) or 0
end

local function DeepCopyTable(tbl)
    if not istable(tbl) then return tbl end
    return table.Copy(tbl)
end

local function TableToSequence(tbl)
    if not istable(tbl) then return nil end

    if #tbl > 0 then
        local out = {}
        for i = 1, #tbl do
            out[i] = tbl[i]
        end
        return out
    end

    local numeric = {}
    for key, value in pairs(tbl) do
        local n = tonumber(key)
        if n then
            numeric[#numeric + 1] = { index = n, value = value }
        end
    end

    if #numeric == 0 then return nil end

    table.sort(numeric, function(a, b)
        return a.index < b.index
    end)

    local out = {}
    for i = 1, #numeric do
        out[i] = numeric[i].value
    end

    return out
end

local function ResolveRandomEntry(entry)
    if not istable(entry) then return entry end

    local seq = TableToSequence(entry) or entry
    if seq.value and istable(seq.value) then
        seq = TableToSequence(seq.value) or seq.value
    elseif seq.Value and istable(seq.Value) then
        seq = TableToSequence(seq.Value) or seq.Value
    end

    if not istable(seq) then return entry end
    if seq[1] ~= "$random" then return seq end

    local choices = {}
    for i = 2, #seq do
        choices[#choices + 1] = seq[i]
    end

    if #choices == 0 then return "" end
    return choices[math.random(#choices)]
end

local function NormalizeBaseClass(value, presetName)
    local key = string.lower(string.Trim(tostring(value or "")))
    if key == "rebel" or key == "resistance" then return "Rebel" end
    if key == "refugee" or key == "citizen" then return "Refugee" end
    if key == "combine" or key == "overwatch" then return "Combine" end
    if key == "metrocop" or key == "metropolice" or key == "civil protection" or key == "civilprotection" then return "Metrocop" end
    if key == "gordon" or key == "freeman" or key == "gordon freeman" then return "Gordon" end

    local name = string.lower(string.Trim(tostring(presetName or "")))
    if string.find(name, "gordon", 1, true) or string.find(name, "freeman", 1, true) then return "Gordon" end
    if string.find(name, "metrocop", 1, true) or string.find(name, "metropolice", 1, true) then return "Metrocop" end
    if string.find(name, "combine", 1, true) then return "Combine" end
    if string.find(name, "refugee", 1, true) or string.find(name, "citizen", 1, true) then return "Refugee" end
    return "Rebel"
end

local function NormalizeSubclass(value, baseClass, presetName)
    local key = string.lower(string.Trim(tostring(value or "")))
    if key == "" or key == "default" or key == "soldier" then
        local name = string.lower(string.Trim(tostring(presetName or "")))
        if string.find(name, "grenadier", 1, true) then return "grenadier" end
        if string.find(name, "medic", 1, true) then return "medic" end
        if string.find(name, "sniper", 1, true) then return "sniper" end
        if string.find(name, "shotgun", 1, true) then return "shotgunner" end
        if string.find(name, "elite", 1, true) then return "elite" end
        if baseClass == "Metrocop" then return "metropolice" end
        return "default"
    end

    if key == "citizen" then return "default" end
    if key == "police" or key == "civil protection" or key == "civilprotection" then return "metropolice" end
    return key
end

local function SanitiseWeaponEntry(entry)
    if isstring(entry) then
        return WEAPON_CLASS_ALIASES[string.lower(entry)] or entry
    end

    if not istable(entry) then return entry end

    local source = entry
    if istable(entry.value) then
        source = entry.value
    elseif istable(entry.Value) then
        source = entry.Value
    end

    local seq = TableToSequence(source)
    if not istable(seq) then
        return source
    end

    local out = {}
    for i = 1, #seq do
        out[i] = SanitiseWeaponEntry(seq[i])
    end
    return out
end

local function SanitiseWeapons(weaponsTbl)
    if not istable(weaponsTbl) then return {} end

    local seq = TableToSequence(weaponsTbl) or weaponsTbl
    local out = {}
    for i = 1, #seq do
        out[i] = SanitiseWeaponEntry(seq[i])
    end
    return out
end

local function SanitiseArmor(armorTbl)
    if not istable(armorTbl) then return {} end

    local out = {}
    for slot, value in pairs(armorTbl) do
        if isstring(value) then
            out[slot] = value
        elseif istable(value) then
            local seq = TableToSequence(value) or value
            local inner = {}
            for i = 1, #seq do
                inner[i] = seq[i]
            end
            out[slot] = inner
        end
    end
    return out
end

local function NormalizePreset(presetName, data)
    data = istable(data) and data or {}

    local baseClass = NormalizeBaseClass(
        data.baseClass or data.className or data.class or data.PlayerClass or data.playerClass,
        presetName
    )
    local subclass = NormalizeSubclass(
        data.subclass or data.subClass or data.SubClass or data.role or data.Role,
        baseClass,
        presetName
    )

    return {
        baseClass = baseClass,
        subclass = subclass,
        weapons = SanitiseWeapons(data.weapons or data.Weapons),
        armor = SanitiseArmor(data.armor or data.Armor),
    }
end

local function ReadPresetSource(path, realm)
    if not file.Exists(path, realm) then return nil end
    local raw = file.Read(path, realm)
    local parsed = isstring(raw) and util.JSONToTable(raw) or nil
    if not istable(parsed) or TableCountSafe(parsed) == 0 then return nil end
    return parsed
end

local function LoadPersistedCoopLoadouts()
    local runtime = rawget(_G, "ZC_CoopLoadouts")
    if istable(runtime) and TableCountSafe(runtime) > 0 then
        return runtime
    end

    return ReadPresetSource(LOADOUTS_FILE, "DATA")
        or ReadPresetSource(LOADOUTS_FILE, "GAME")
        or ReadPresetSource(LOADOUTS_FILE_BACKUP, "DATA")
        or ReadPresetSource(LOADOUTS_FILE_BACKUP, "GAME")
        or {}
end

local function ResolveManagedPresetForPlayer(ply)
    if not IsValid(ply) then return nil, nil, nil end

    local className = tostring(ply.PlayerClassName or "")
    if className == "Citizen" then
        className = "Refugee"
    end

    if className == "Gordon" and not ShouldUseManagedGordonLoadout() then
        return nil, nil, nil
    end

    local subClass = tostring(ply.subClass or ply.ZCPreferredSubClass or "")
    if subClass == "" then
        subClass = "default"
    end

    if className == "Metrocop" and subClass == "default" then
        subClass = "metropolice"
    end

    local classPresets = DEFAULT_PRESET_BY_CLASS[className]
    if not istable(classPresets) then return nil, nil, nil end

    local presetName = classPresets[subClass] or classPresets.default
    if not presetName then return nil, nil, nil end

    return className, subClass, presetName
end

local function ClearArmor(ply)
    if not IsValid(ply) then return end
    if not ply.armors then return end
    -- Silently nil each slot and resync; do NOT use DropArmorForce which
    -- physically spawns the armor as a floor prop.
    for _, slot in ipairs(ARMOR_SLOTS) do
        ply.armors[slot] = nil
    end
    local inv = ply:GetNetVar("Inventory", {})
    inv["Armor"] = {}
    ply:SetNetVar("Inventory", inv)
    ply.inventory = inv
    if ply.SyncArmor then
        pcall(function() ply:SyncArmor() end)
    end
end

local function ApplyArmorFromPreset(ply, armor)
    if not IsValid(ply) or not istable(armor) or not hg or not hg.AddArmor then return end

    local className = tostring(ply.PlayerClassName or "")

    local function AllowedForClass(armorClass)
        armorClass = string.lower(tostring(armorClass or ""))
        if string.StartWith(armorClass, "gordon_") then return className == "Gordon" end
        if string.StartWith(armorClass, "combine_") then return className == "Combine" end
        if string.StartWith(armorClass, "metrocop_") then return className == "Metrocop" end
        return true
    end

    for _, slot in ipairs(ARMOR_SLOTS) do
        local resolved = ResolveRandomEntry(armor[slot])
        if isstring(resolved) and resolved ~= "" and AllowedForClass(resolved) then
            pcall(function()
                hg.AddArmor(ply, resolved)
            end)
        end
    end

    if ply.SyncArmor then
        pcall(function()
            ply:SyncArmor()
        end)
    end
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

local function ApplyPresetDirectly(ply, presetName)
    local loadouts = LoadPersistedCoopLoadouts()
    local preset = loadouts[presetName]
    if not istable(preset) then return false end

    preset = NormalizePreset(presetName, preset)
    if not istable(preset.weapons) or #preset.weapons == 0 then return false end

    ply:SetSuppressPickupNotices(true)
    ply.noSound = true

    ClearArmor(ply)
    ply:StripWeapons()

    local inv = ply:GetNetVar("Inventory", {})
    inv["Weapons"] = { ["hg_sling"] = true, ["hg_flashlight"] = true }
    inv["Ammo"] = {}
    inv["Armor"] = {}
    inv["Attachments"] = {}
    ply:SetNetVar("Inventory", inv)
    ply.inventory = inv

    for i = 1, #preset.weapons do
        local resolved = ResolveRandomEntry(preset.weapons[i])
        if isstring(resolved) and resolved ~= "" then
            local wep = ply:Give(resolved)
            if IsValid(wep) and wep.GetMaxClip1 and wep:GetMaxClip1() and wep:GetMaxClip1() > 0 then
                ply:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType(), true)
            end
        end
    end

    ApplyArmorFromPreset(ply, preset.armor)

    if not IsValid(ply:GetWeapon("weapon_hands_sh")) then
        ply:Give("weapon_hands_sh")
    end

    if IsValid(ply:GetWeapon("weapon_hands_sh")) then
        ply:SelectWeapon("weapon_hands_sh")
    end

    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        ply.noSound = false
        ply:SetSuppressPickupNotices(false)
    end)

    return HasNonHandsWeapon(ply)
end

local function ApplyManagedPresetForPlayer(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if not CurrentRoundIsCoop() then return false end

    local className, subClass, presetName = ResolveManagedPresetForPlayer(ply)
    if not presetName then return false end

    local applied = false

    if _G.ZC_ApplyNamedCoopLoadout then
        local ok, result = pcall(_G.ZC_ApplyNamedCoopLoadout, ply, presetName)
        if ok and result == true then
            applied = true
        end
    end

    if not applied and _G.ZC_ApplyCoopLoadout then
        local ok, result = pcall(_G.ZC_ApplyCoopLoadout, ply, subClass, className)
        if ok and result == true then
            applied = true
        end
    end

    if not applied then
        applied = ApplyPresetDirectly(ply, presetName)
    end

    if applied then
        ply.ZC_LastManagedCoopPreset = presetName
        print("[ZC Coop Enforcer] Applied " .. tostring(presetName) .. " to " .. tostring(ply:Nick()) .. " (" .. tostring(className) .. "/" .. tostring(subClass) .. ")")
    end

    return applied
end

local function ScheduleManagedApply(ply)
    if not IsValid(ply) then return end

    ply.ZC_CoopManagedSpawnSerial = (tonumber(ply.ZC_CoopManagedSpawnSerial) or 0) + 1
    local serial = ply.ZC_CoopManagedSpawnSerial

    local delays = { 0, 0.2, 0.7, 1.2 }
    for _, delay in ipairs(delays) do
        timer.Simple(delay, function()
            if not IsValid(ply) or not ply:Alive() then return end
            if ply.ZC_CoopManagedSpawnSerial ~= serial then return end
            ApplyManagedPresetForPlayer(ply)
        end)
    end
end

hook.Add("PlayerSpawn", "ZC_CoopLoadoutEnforcer_EngineSpawn", function(ply)
    ScheduleManagedApply(ply)
end)

hook.Add("Player Spawn", "ZC_CoopLoadoutEnforcer_CustomSpawn", function(ply)
    ScheduleManagedApply(ply)
end)

_G.ZC_CoopLoadoutEnforcerLoaded = true
print("[ZC Coop Enforcer] Loaded.")