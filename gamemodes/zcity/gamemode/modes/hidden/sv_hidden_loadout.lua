local MODE = MODE

util.AddNetworkString("hidden_loadout_sync")
util.AddNetworkString("hidden_loadout_save")
util.AddNetworkString("hidden_loadout_request")
util.AddNetworkString("hidden_loadout_publish")
util.AddNetworkString("hidden_prep_state")
util.AddNetworkString("hidden_public_presets_sync")

local HIDDEN_LOADOUT_FILE = "zcity/hidden_iris_loadouts.json"
local HIDDEN_PUBLIC_LOADOUT_FILE = "zcity/hidden_public_iris_loadouts.json"
local hiddenStoredLoadouts = nil
local hiddenPublicLoadouts = nil
local hiddenCatalogCache = nil
local hiddenCatalogCacheTime = 0
local HIDDEN_PUBLIC_PROFANITY = {
    "fuck",
    "shit",
    "bitch",
    "cunt",
    "asshole",
    "bastard",
    "dick",
    "cock",
    "penis",
    "pussy",
    "vagina",
}

local function packVector(vec)
    if not isvector(vec) then
        return nil
    end

    return {
        x = vec.x,
        y = vec.y,
        z = vec.z,
    }
end

local function packAngle(ang)
    if not isangle(ang) then
        return nil
    end

    return {
        p = ang.p,
        y = ang.y,
        r = ang.r,
    }
end

local function getLoadoutStore()
    if hiddenStoredLoadouts ~= nil then
        return hiddenStoredLoadouts
    end

    file.CreateDir("zcity")

    local raw = file.Read(HIDDEN_LOADOUT_FILE, "DATA") or ""
    local parsed = util.JSONToTable(raw)
    hiddenStoredLoadouts = istable(parsed) and parsed or {}
    return hiddenStoredLoadouts
end

local function saveLoadoutStore()
    if not istable(hiddenStoredLoadouts) then
        return
    end

    file.CreateDir("zcity")
    file.Write(HIDDEN_LOADOUT_FILE, util.TableToJSON(hiddenStoredLoadouts, true))
end

local function getPublicLoadoutStore()
    if hiddenPublicLoadouts ~= nil then
        return hiddenPublicLoadouts
    end

    file.CreateDir("zcity")

    local raw = file.Read(HIDDEN_PUBLIC_LOADOUT_FILE, "DATA") or ""
    local parsed = util.JSONToTable(raw)
    hiddenPublicLoadouts = istable(parsed) and parsed or {}
    return hiddenPublicLoadouts
end

local function savePublicLoadoutStore()
    if not istable(hiddenPublicLoadouts) then
        return
    end

    file.CreateDir("zcity")
    file.Write(HIDDEN_PUBLIC_LOADOUT_FILE, util.TableToJSON(hiddenPublicLoadouts, true))
end

local function sanitizeHiddenPublicPresetDisplayName(name)
    local cleaned = string.Trim(tostring(name or ""))
    cleaned = string.gsub(cleaned, "[%c\r\n\t]", " ")
    cleaned = string.gsub(cleaned, "%s+", " ")
    cleaned = string.sub(cleaned, 1, 32)
    return cleaned
end

local function sanitizeHiddenPublicPresetId(name)
    local cleaned = string.lower(string.Trim(tostring(name or "")))
    cleaned = string.gsub(cleaned, "[^%w%s_%-]", "")
    cleaned = string.gsub(cleaned, "%s+", "_")
    cleaned = string.gsub(cleaned, "_+", "_")
    cleaned = string.gsub(cleaned, "^_+", "")
    cleaned = string.gsub(cleaned, "_+$", "")
    cleaned = string.sub(cleaned, 1, 40)
    return cleaned
end

local function normalizeHiddenPublicFilterText(text)
    local cleaned = string.lower(string.Trim(tostring(text or "")))
    cleaned = string.gsub(cleaned, "[@4]", "a")
    cleaned = string.gsub(cleaned, "3", "e")
    cleaned = string.gsub(cleaned, "[1!|]", "i")
    cleaned = string.gsub(cleaned, "0", "o")
    cleaned = string.gsub(cleaned, "[5$]", "s")
    cleaned = string.gsub(cleaned, "[7+]", "t")
    cleaned = string.gsub(cleaned, "[^%w]", "")
    return cleaned
end

local function hiddenPublicNameHasProfanity(text)
    local cleaned = normalizeHiddenPublicFilterText(text)
    if cleaned == "" then
        return false
    end

    for _, fragment in ipairs(HIDDEN_PUBLIC_PROFANITY) do
        if string.find(cleaned, fragment, 1, true) then
            return true
        end
    end

    return false
end

local function sanitizeHiddenPublicAuthorName(name)
    local cleaned = sanitizeHiddenPublicPresetDisplayName(name)
    if cleaned == "" or hiddenPublicNameHasProfanity(cleaned) then
        return "Anonymous Operative"
    end

    return cleaned
end

local function sortEntriesByScore(left, right)
    local leftScore = tonumber(left.score or 0) or 0
    local rightScore = tonumber(right.score or 0) or 0
    if leftScore ~= rightScore then
        return leftScore < rightScore
    end

    return string.lower(tostring(left.name or "")) < string.lower(tostring(right.name or ""))
end

function MODE:EnsureHiddenSling(ply)
    if not IsValid(ply) then
        return
    end

    local inventory = ply:GetNetVar("Inventory")
    if not istable(inventory) then
        return
    end

    inventory.Weapons = inventory.Weapons or {}
    inventory.Weapons.hg_sling = true
    ply:SetNetVar("Inventory", inventory)
    ply.inventory = inventory
end

function MODE:ClearHiddenArmor(ply)
    if not IsValid(ply) then
        return
    end

    ply.armors = istable(ply.armors) and ply.armors or {}

    -- Hidden loadout swaps must hard-delete armor state instead of routing
    -- through DropArmor/DropArmorForce, which would spawn pickup props and let
    -- players recycle stripped gear.
    for _, slotName in ipairs(self:GetHiddenLoadoutSlots()) do
        ply.armors[slotName] = nil
    end

    local inventory = ply:GetNetVar("Inventory", {})
    if not istable(inventory) then
        inventory = {}
    end

    inventory.Armor = {}
    ply:SetNetVar("Inventory", inventory)
    ply.inventory = inventory

    if ply.SyncArmor then
        pcall(function()
            ply:SyncArmor()
        end)
    end
end

function MODE:BuildHiddenWeaponPool(slotName)
    local entries = {}
    local scoreMap = {
        [""] = 0,
    }
    local seen = {}

    for _, swepData in ipairs(weapons.GetList() or {}) do
        local className = tostring(swepData.ClassName or swepData.Classname or swepData.Class or "")
        className = string.Trim(string.lower(className))
        if className == "" or seen[className] then
            continue
        end

        local storedWeapon = weapons.GetStored(className) or swepData
        if not self:IsHiddenWeaponAllowed(storedWeapon, className) then
            continue
        end

        if self:GetHiddenWeaponSlot(storedWeapon) ~= slotName then
            continue
        end

        local stats = self:GetHiddenWeaponStats(storedWeapon)
        local score = self:CalculateHiddenWeaponScore(storedWeapon)

        entries[#entries + 1] = {
            class = className,
            name = tostring(storedWeapon.PrintName or className),
            score = score,
            caliber = stats.caliber,
            damage = stats.damage,
            rpm = stats.rpm,
            clip = stats.clipSize,
            penetration = stats.penetration,
            weight = stats.weight,
            model = stats.worldModel,
        }

        scoreMap[className] = score
        seen[className] = true
    end

    table.sort(entries, sortEntriesByScore)
    return entries, scoreMap
end

function MODE:BuildHiddenArmorPool(slotName)
    local entries = {
        {
            key = "",
            name = "None",
            score = 0,
            protection = 0,
            mass = 0,
            model = "",
        },
    }
    local scoreMap = {
        [""] = 0,
    }

    local slotTable = hg and hg.armor and hg.armor[slotName] or nil
    if not istable(slotTable) then
        return entries, scoreMap
    end

    for armorKey in pairs(slotTable) do
        if not self:IsHiddenArmorAllowed(armorKey) then
            continue
        end

        local armorStats = self:GetHiddenArmorStats(armorKey)
        if not armorStats then
            continue
        end

        local score = self:CalculateHiddenArmorScore(armorKey)
        local material = armorStats.material
        if istable(material) then
            material = material[1]
        end

        entries[#entries + 1] = {
            key = armorStats.key,
            name = armorStats.name,
            score = score,
            protection = armorStats.protection,
            mass = armorStats.mass,
            model = armorStats.model,
            bone = armorStats.bone,
            pos = packVector(armorStats.pos),
            ang = packAngle(armorStats.ang),
            femPos = packVector(armorStats.femPos),
            scale = armorStats.scale,
            femscale = armorStats.femscale,
            material = isstring(material) and material or "",
            nobonemerge = armorStats.nobonemerge and true or false,
        }

        scoreMap[armorStats.key] = score
    end

    table.sort(entries, function(left, right)
        if left.key == "" then
            return true
        end

        if right.key == "" then
            return false
        end

        return sortEntriesByScore(left, right)
    end)

    return entries, scoreMap
end

function MODE:GetHiddenLoadoutCatalog()
    if hiddenCatalogCache and hiddenCatalogCacheTime > CurTime() - 10 then
        return hiddenCatalogCache
    end

    local catalog = {
        payload = {
            budget = self.HiddenConfig.LoadoutBudget or 170,
            primary = {},
            secondary = {},
            armor = {},
        },
        scoreMaps = {
            primary = {},
            secondary = {},
            armor = {},
        },
    }

    catalog.payload.primary, catalog.scoreMaps.primary = self:BuildHiddenWeaponPool("primary")
    catalog.payload.secondary, catalog.scoreMaps.secondary = self:BuildHiddenWeaponPool("secondary")

    for _, slotName in ipairs(self:GetHiddenLoadoutSlots()) do
        catalog.payload.armor[slotName], catalog.scoreMaps.armor[slotName] = self:BuildHiddenArmorPool(slotName)
    end

    hiddenCatalogCache = catalog
    hiddenCatalogCacheTime = CurTime()
    return catalog
end

function MODE:CalculateHiddenLoadoutCost(loadout, catalog)
    catalog = catalog or self:GetHiddenLoadoutCatalog()
    loadout = self:NormalizeHiddenLoadout(loadout)

    local totalCost = 0
    totalCost = totalCost + (catalog.scoreMaps.primary[loadout.primary] or 0)
    totalCost = totalCost + (catalog.scoreMaps.secondary[loadout.secondary] or 0)

    for _, slotName in ipairs(self:GetHiddenLoadoutSlots()) do
        totalCost = totalCost + ((catalog.scoreMaps.armor[slotName] and catalog.scoreMaps.armor[slotName][loadout.armor[slotName]]) or 0)
    end

    return totalCost
end

function MODE:ValidateHiddenLoadout(loadout, catalog)
    catalog = catalog or self:GetHiddenLoadoutCatalog()
    local normalized = self:NormalizeHiddenLoadout(loadout)

    if normalized.primary ~= "" and not catalog.scoreMaps.primary[normalized.primary] then
        return false, "Primary weapon is not available in Hidden.", normalized, 0
    end

    if normalized.secondary ~= "" and not catalog.scoreMaps.secondary[normalized.secondary] then
        return false, "Secondary weapon is not available in Hidden.", normalized, 0
    end

    for _, slotName in ipairs(self:GetHiddenLoadoutSlots()) do
        local armorKey = normalized.armor[slotName]
        if armorKey ~= "" and not (catalog.scoreMaps.armor[slotName] and catalog.scoreMaps.armor[slotName][armorKey]) then
            return false, string.format("%s armor is not available in Hidden.", string.upper(slotName)), normalized, 0
        end
    end

    local totalCost = self:CalculateHiddenLoadoutCost(normalized, catalog)
    if totalCost > (self.HiddenConfig.LoadoutBudget or 170) then
        return false, string.format("Loadout is over budget by %d points.", totalCost - (self.HiddenConfig.LoadoutBudget or 170)), normalized, totalCost
    end

    return true, nil, normalized, totalCost
end

function MODE:BuildFallbackHiddenLoadout(catalog)
    local fallback = {
        primary = catalog.payload.primary[1] and catalog.payload.primary[1].class or "",
        secondary = catalog.payload.secondary[1] and catalog.payload.secondary[1].class or "",
        armor = {},
    }

    for _, slotName in ipairs(self:GetHiddenLoadoutSlots()) do
        local slotEntries = catalog.payload.armor[slotName] or {}
        fallback.armor[slotName] = slotEntries[1] and slotEntries[1].key or ""
    end

    local ok, _, normalized = self:ValidateHiddenLoadout(fallback, catalog)
    if ok then
        return normalized
    end

    fallback.secondary = ""
    ok, _, normalized = self:ValidateHiddenLoadout(fallback, catalog)
    if ok then
        return normalized
    end

    for _, slotName in ipairs(self:GetHiddenLoadoutSlots()) do
        fallback.armor[slotName] = ""
    end

    ok, _, normalized = self:ValidateHiddenLoadout(fallback, catalog)
    if ok then
        return normalized
    end

    return self:NormalizeHiddenLoadout({
        primary = fallback.primary,
        secondary = "",
        armor = {},
    })
end

function MODE:GetPlayerHiddenLoadout(ply, catalog)
    catalog = catalog or self:GetHiddenLoadoutCatalog()

    local store = getLoadoutStore()
    local identity = IsValid(ply) and (ply:SteamID64() or ply:SteamID()) or nil
    local savedLoadout = identity and store[identity] or nil

    local ok, _, normalized, totalCost = self:ValidateHiddenLoadout(savedLoadout, catalog)
    if ok then
        return normalized, totalCost
    end

    ok, _, normalized, totalCost = self:ValidateHiddenLoadout(self:GetDefaultHiddenLoadout(), catalog)
    if ok then
        if identity then
            store[identity] = normalized
            saveLoadoutStore()
        end

        return normalized, totalCost
    end

    normalized = self:BuildFallbackHiddenLoadout(catalog)
    totalCost = self:CalculateHiddenLoadoutCost(normalized, catalog)

    if identity then
        store[identity] = normalized
        saveLoadoutStore()
    end

    return normalized, totalCost
end

function MODE:SetPlayerHiddenLoadout(ply, loadout)
    if not IsValid(ply) then
        return false, "Invalid player."
    end

    local catalog = self:GetHiddenLoadoutCatalog()
    local ok, err, normalized = self:ValidateHiddenLoadout(loadout, catalog)
    if not ok then
        return false, err
    end

    local identity = ply:SteamID64() or ply:SteamID()
    if not identity then
        return false, "Could not resolve your Steam identity for saving."
    end

    local store = getLoadoutStore()
    store[identity] = normalized
    saveLoadoutStore()
    return true, normalized
end

function MODE:GetHiddenPublicPresets(catalog)
    catalog = catalog or self:GetHiddenLoadoutCatalog()

    local list = {}
    local store = getPublicLoadoutStore()

    for presetId, presetData in pairs(store) do
        local ok, _, normalized, totalCost = self:ValidateHiddenLoadout(presetData.loadout, catalog)
        local cleanId = sanitizeHiddenPublicPresetId(presetData.id or presetId)
        local cleanName = sanitizeHiddenPublicPresetDisplayName(presetData.name or presetId)

        if ok and cleanId ~= "" and cleanName ~= "" then
            list[#list + 1] = {
                id = cleanId,
                name = cleanName,
                author = sanitizeHiddenPublicAuthorName(presetData.author or ""),
                cost = totalCost,
                updatedAt = tonumber(presetData.updatedAt) or 0,
                selection = normalized,
            }
        end
    end

    table.sort(list, function(left, right)
        local leftUpdated = tonumber(left.updatedAt) or 0
        local rightUpdated = tonumber(right.updatedAt) or 0
        if leftUpdated ~= rightUpdated then
            return leftUpdated > rightUpdated
        end

        return string.lower(tostring(left.name or "")) < string.lower(tostring(right.name or ""))
    end)

    return list
end

function MODE:SendHiddenPublicPresetData(targets)
    if not targets then
        return
    end

    if istable(targets) and #targets <= 0 then
        return
    end

    local payload = self:GetHiddenPublicPresets()
    local json = util.TableToJSON(payload)
    if not isstring(json) then
        return
    end

    net.Start("hidden_public_presets_sync")
    net.WriteString(json)
    net.Send(targets)
end

function MODE:GetHiddenPublicPresetRecipients()
    local recipients = {}

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if ply:Team() ~= 1 then continue end
        recipients[#recipients + 1] = ply
    end

    return recipients
end

function MODE:SetPublicHiddenLoadout(ply, presetName, loadout)
    if not IsValid(ply) then
        return false, "Invalid player."
    end

    local displayName = sanitizeHiddenPublicPresetDisplayName(presetName)
    if #displayName < 3 then
        return false, "Public preset names must be at least 3 characters."
    end

    if hiddenPublicNameHasProfanity(displayName) then
        return false, "Public preset name blocked by profanity filter."
    end

    local presetId = sanitizeHiddenPublicPresetId(displayName)
    if presetId == "" then
        return false, "Public preset name is not valid."
    end

    local identity = ply:SteamID64() or ply:SteamID()
    if not identity then
        return false, "Could not resolve your Steam identity for publishing."
    end

    local catalog = self:GetHiddenLoadoutCatalog()
    local ok, err, normalized, totalCost = self:ValidateHiddenLoadout(loadout, catalog)
    if not ok then
        return false, err
    end

    local store = getPublicLoadoutStore()
    local existing = store[presetId]
    if istable(existing) and tostring(existing.authorId or "") ~= "" and tostring(existing.authorId) ~= tostring(identity) then
        return false, "That public preset name is already in use."
    end

    store[presetId] = {
        id = presetId,
        name = displayName,
        authorId = identity,
        author = sanitizeHiddenPublicAuthorName(ply:Nick()),
        updatedAt = os.time(),
        loadout = normalized,
        cost = totalCost,
    }

    savePublicLoadoutStore()
    return true, presetId, normalized
end

function MODE:BuildHiddenPayloadFor(ply, autoOpen)
    local catalog = self:GetHiddenLoadoutCatalog()
    local selection, totalCost = self:GetPlayerHiddenLoadout(ply, catalog)
    local payload = table.Copy(catalog.payload)

    payload.selection = selection
    payload.cost = totalCost
    payload.prepEndsAt = zb.ROUND_BEGIN or 0
    payload.canEdit = self:IsHiddenPreparationPhase() and IsValid(ply) and ply:Team() == 1
    payload.autoOpen = autoOpen and true or false
    payload.playerModel = IsValid(ply) and tostring(ply:GetModel() or "") or ""
    payload.publicPresets = self:GetHiddenPublicPresets(catalog)

    return payload
end

function MODE:SendHiddenLoadoutData(ply, autoOpen)
    if not IsValid(ply) then
        return
    end

    local payload = self:BuildHiddenPayloadFor(ply, autoOpen)
    local json = util.TableToJSON(payload)
    if not isstring(json) then
        return
    end

    net.Start("hidden_loadout_sync")
    net.WriteString(json)
    net.Send(ply)
end

function MODE:GiveHiddenSupportItems(ply)
    if not IsValid(ply) then
        return nil
    end

    local selectedWeapon = nil
    local fixedItems = {
        "weapon_melee",
        "weapon_walkie_talkie",
        "weapon_bandage_sh",
        "weapon_tourniquet",
        "weapon_hg_flashbang_tpik",
    }

    for _, className in ipairs(fixedItems) do
        local weapon = ply:Give(className)
        if not IsValid(selectedWeapon) and IsValid(weapon) then
            selectedWeapon = weapon
        end
    end

    return selectedWeapon
end

function MODE:GiveAmmoForWeapon(ply, weaponEntity, multiplier)
    if not IsValid(ply) or not IsValid(weaponEntity) then
        return
    end

    local maxClip = weaponEntity.GetMaxClip1 and weaponEntity:GetMaxClip1() or -1
    local ammoType = weaponEntity.GetPrimaryAmmoType and weaponEntity:GetPrimaryAmmoType() or -1
    if maxClip == nil or maxClip <= 0 or ammoType == nil or ammoType < 0 then
        return
    end

    ply:GiveAmmo(maxClip * math.max(multiplier or 0, 0), ammoType, true)
end

function MODE:ApplyHiddenCombatEquipment(ply)
    if not IsValid(ply) or not ply:Alive() or ply:Team() == TEAM_SPECTATOR then
        return
    end

    ply:StripWeapons()
    ply:StripAmmo()
    ply:SetSuppressPickupNotices(true)
    ply.noSound = true

    local hands = ply:Give("weapon_hands_sh")
    local selectedWeapon = hands

    if ply:Team() == 0 then
        local melee = ply:Give("weapon_kabar")
        if not IsValid(melee) then
            melee = ply:Give("weapon_pocketknife")
        end

        if not IsValid(melee) then
            melee = ply:Give("weapon_melee")
        end

        ply:Give("weapon_hg_pipebomb_tpik")
        ply:Give("weapon_traitor_ied")

        if IsValid(melee) then
            selectedWeapon = melee
        end
    elseif ply:Team() == 1 then
        self:EnsureHiddenSling(ply)
        self:ClearHiddenArmor(ply)

        local loadout = self:GetPlayerHiddenLoadout(ply)

        local primary = loadout.primary ~= "" and ply:Give(loadout.primary) or nil
        if IsValid(primary) then
            self:GiveAmmoForWeapon(ply, primary, self.HiddenConfig.PrimaryAmmoMultiplier or 3)
            selectedWeapon = primary
        end

        local secondary = loadout.secondary ~= "" and ply:Give(loadout.secondary) or nil
        if IsValid(secondary) and not IsValid(selectedWeapon) then
            selectedWeapon = secondary
        end

        if IsValid(secondary) then
            self:GiveAmmoForWeapon(ply, secondary, self.HiddenConfig.SecondaryAmmoMultiplier or 2)
        end

        local supportWeapon = self:GiveHiddenSupportItems(ply)
        if not IsValid(selectedWeapon) and IsValid(supportWeapon) then
            selectedWeapon = supportWeapon
        end

        for _, slotName in ipairs(self:GetHiddenLoadoutSlots()) do
            local armorKey = loadout.armor[slotName]
            if isstring(armorKey) and armorKey ~= "" then
                pcall(function()
                    hg.AddArmor(ply, armorKey)
                end)
            end
        end
    end

    if IsValid(selectedWeapon) then
        ply:SelectWeapon(selectedWeapon:GetClass())
    end

    timer.Simple(0.1, function()
        if not IsValid(ply) then
            return
        end

        ply.noSound = false
        ply:SetSuppressPickupNotices(false)
    end)
end

net.Receive("hidden_loadout_request", function(_, ply)
    local round = CurrentRound()
    if not round or round.name ~= "hidden" then
        return
    end

    if not IsValid(ply) or ply:Team() ~= 1 then
        return
    end

    round:SendHiddenLoadoutData(ply, true)
end)

net.Receive("hidden_loadout_save", function(_, ply)
    local round = CurrentRound()
    if not round or round.name ~= "hidden" then
        return
    end

    if not IsValid(ply) or ply:Team() ~= 1 then
        return
    end

    if not round:IsHiddenPreparationPhase() then
        ply:ChatPrint("[Hidden] The loadout builder is only available during the prep phase.")
        round:SendHiddenLoadoutData(ply, false)
        return
    end

    local raw = net.ReadString()
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then
        ply:ChatPrint("[Hidden] Could not read that loadout payload.")
        round:SendHiddenLoadoutData(ply, false)
        return
    end

    local ok, result = round:SetPlayerHiddenLoadout(ply, parsed)
    if not ok then
        ply:ChatPrint("[Hidden] " .. tostring(result or "Could not save your loadout."))
        round:SendHiddenLoadoutData(ply, false)
        return
    end

    ply:ChatPrint("[Hidden] Loadout saved.")
    round:SendHiddenLoadoutData(ply, false)
end)

net.Receive("hidden_loadout_publish", function(_, ply)
    local round = CurrentRound()
    if not round or round.name ~= "hidden" then
        return
    end

    if not IsValid(ply) or ply:Team() ~= 1 then
        return
    end

    if not round:IsHiddenPreparationPhase() then
        ply:ChatPrint("[Hidden] Public preset publishing is only available during the prep phase.")
        return
    end

    local raw = net.ReadString()
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then
        ply:ChatPrint("[Hidden] Could not read that public preset payload.")
        return
    end

    local ok, result = round:SetPublicHiddenLoadout(ply, parsed.name, parsed.loadout)
    if not ok then
        ply:ChatPrint("[Hidden] " .. tostring(result or "Could not publish that preset."))
        return
    end

    ply:ChatPrint("[Hidden] Public preset published.")
    round:SendHiddenPublicPresetData(round:GetHiddenPublicPresetRecipients())
end)