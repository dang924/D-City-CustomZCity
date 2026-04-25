local MODE = MODE

MODE.HiddenConfig = MODE.HiddenConfig or {}
MODE.HiddenConfig.PrepDuration = MODE.HiddenConfig.PrepDuration or 60
MODE.HiddenConfig.CombatDuration = MODE.HiddenConfig.CombatDuration or 240
MODE.HiddenConfig.LoadoutBudget = MODE.HiddenConfig.LoadoutBudget or 170
MODE.HiddenConfig.PrimaryAmmoMultiplier = MODE.HiddenConfig.PrimaryAmmoMultiplier or 3
MODE.HiddenConfig.SecondaryAmmoMultiplier = MODE.HiddenConfig.SecondaryAmmoMultiplier or 2
MODE.HiddenConfig.DefaultIrisLoadout = MODE.HiddenConfig.DefaultIrisLoadout or {
    primary = "weapon_mp5",
    secondary = "weapon_glock17",
    attachments = {
        primary = {},
        secondary = {},
    },
    armor = {
        torso = "vest3",
        head = "helmet1",
        face = "",
        ears = "",
    },
}

MODE.HiddenLoadoutArmorSlots = {
    "torso",
    "head",
    "face",
    "ears",
}

MODE.HiddenLoadoutAttachmentSlots = {
    "barrel",
    "mount",
    "sight",
    "underbarrel",
    "grip",
    "magwell",
}

local weaponBlacklist = {
    weapon_bandage_sh = true,
    weapon_betablock = true,
    weapon_bigbandage_sh = true,
    weapon_bloodbag = true,
    weapon_breachcharge = true,
    weapon_claymore = true,
    weapon_handcuffs = true,
    weapon_handcuffs_key = true,
    weapon_hands_sh = true,
    weapon_hg_flashbang_tpik = true,
    weapon_hg_hl2nade_tpik = true,
    weapon_hg_m18_tpik = true,
    weapon_hg_mk2_tpik = true,
    weapon_hg_pipebomb_tpik = true,
    weapon_hg_slam = true,
    weapon_melee = true,
    weapon_medkit_sh = true,
    weapon_morphine = true,
    weapon_naloxone = true,
    weapon_needle = true,
    weapon_painkillers = true,
    weapon_tourniquet = true,
    weapon_traitor_ied = true,
    weapon_walkie_talkie = true,
}

local armorSlots = MODE.HiddenLoadoutArmorSlots
local attachmentSlots = MODE.HiddenLoadoutAttachmentSlots
local attachmentSlotLookup = {}

for _, slotName in ipairs(attachmentSlots) do
    attachmentSlotLookup[slotName] = true
end

local function clampNumber(value, fallback)
    local numberValue = tonumber(value)
    if numberValue == nil then
        return fallback or 0
    end

    return numberValue
end

local function normalizeArmorKey(armorKey)
    if not isstring(armorKey) then
        return ""
    end

    armorKey = string.Trim(string.lower(armorKey))
    armorKey = string.Replace(armorKey, "ent_armor_", "")
    return armorKey
end

local function normalizeAttachmentKey(attKey)
    if not isstring(attKey) then
        return ""
    end

    attKey = string.Trim(string.lower(attKey))
    attKey = string.Replace(attKey, "ent_att_", "")
    if attKey == "empty" then
        return ""
    end

    return attKey
end

local function resolveAttachmentName(attKey)
    local dict = hg and (hg.attachmentslaunguage or hg.attachmentslanguage) or nil
    attKey = tostring(attKey or "")

    if istable(dict) and isstring(dict[attKey]) and dict[attKey] ~= "" then
        return dict[attKey]
    end

    local label = string.gsub(attKey, "_", " ")
    label = string.gsub(label, "(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)

    return label ~= "" and label or attKey
end

local function isMountTypeCompatible(availableMountType, attachmentMountType)
    if not availableMountType or not attachmentMountType then
        return false
    end

    if istable(availableMountType) then
        return table.HasValue(availableMountType, attachmentMountType)
    end

    return tostring(availableMountType) == tostring(attachmentMountType)
end

local function addAttachmentOption(entries, seen, placement, attKey)
    attKey = normalizeAttachmentKey(attKey)
    if seen[attKey] then
        return
    end

    -- Hidden admin blacklist: skip non-empty attachment keys flagged by superadmins.
    if attKey ~= "" and MODE.IsHiddenAdminBlacklisted and MODE:IsHiddenAdminBlacklisted("attachment", attKey) then
        return
    end

    local iconMap = hg and hg.attachmentsIcons or nil
    local score = 0
    if MODE.GetHiddenAdminScoreOverride and attKey ~= "" then
        local override = MODE:GetHiddenAdminScoreOverride("attachment", attKey)
        if override and override > 0 then
            score = override
        end
    end
    seen[attKey] = true
    entries[#entries + 1] = {
        key = attKey,
        name = attKey == "" and "None" or resolveAttachmentName(attKey),
        placement = tostring(placement or ""),
        icon = attKey ~= "" and tostring(iconMap and iconMap[attKey] or "") or "",
        score = score,
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Hidden loadout admin overrides (per-server, persisted via sv_hidden_loadout_admin.lua)
-- Provides per-key score overrides and blacklists for weapons/armor/attachments.
-- The data table is populated server-side from disk and synced to clients so the
-- shared score helpers see the same values on both realms.
-- ─────────────────────────────────────────────────────────────────────────────

MODE.HiddenAdminData = MODE.HiddenAdminData or {
    scoreOverrides = { weapon = {}, armor = {}, attachment = {} },
    blacklist      = { weapon = {}, armor = {}, attachment = {} },
}

local function ensureHiddenAdminBucket(self)
    self.HiddenAdminData = self.HiddenAdminData or {}
    self.HiddenAdminData.scoreOverrides = self.HiddenAdminData.scoreOverrides or {}
    self.HiddenAdminData.blacklist      = self.HiddenAdminData.blacklist or {}
    for _, kind in ipairs({"weapon", "armor", "attachment"}) do
        self.HiddenAdminData.scoreOverrides[kind] = self.HiddenAdminData.scoreOverrides[kind] or {}
        self.HiddenAdminData.blacklist[kind]      = self.HiddenAdminData.blacklist[kind] or {}
    end
end

function MODE:GetHiddenAdminData()
    ensureHiddenAdminBucket(self)
    return self.HiddenAdminData
end

function MODE:GetHiddenAdminScoreOverride(kind, key)
    if not isstring(kind) or not isstring(key) or key == "" then return nil end
    ensureHiddenAdminBucket(self)
    local bucket = self.HiddenAdminData.scoreOverrides[kind]
    if not istable(bucket) then return nil end
    local override = tonumber(bucket[string.lower(key)])
    if override == nil then return nil end
    return math.max(0, math.floor(override + 0.5))
end

function MODE:IsHiddenAdminBlacklisted(kind, key)
    if not isstring(kind) or not isstring(key) or key == "" then return false end
    ensureHiddenAdminBucket(self)
    local bucket = self.HiddenAdminData.blacklist[kind]
    return istable(bucket) and bucket[string.lower(key)] == true
end

function MODE:CalculateHiddenAttachmentScore(attKey)
    if not isstring(attKey) or attKey == "" then return 0 end
    local override = self:GetHiddenAdminScoreOverride("attachment", attKey)
    return override and math.max(0, override) or 0
end

function MODE:IsHiddenPreparationPhase()
    return (zb.ROUND_BEGIN or 0) > CurTime()
end

function MODE:GetHiddenLoadoutSlots()
    return armorSlots
end

function MODE:GetHiddenLoadoutAttachmentSlots()
    return attachmentSlots
end

function MODE:GetDefaultHiddenLoadout()
    return table.Copy(self.HiddenConfig.DefaultIrisLoadout or {
        primary = "",
        secondary = "",
        attachments = {
            primary = {},
            secondary = {},
        },
        armor = {},
    })
end

function MODE:NormalizeHiddenArmorKey(armorKey)
    return normalizeArmorKey(armorKey)
end

function MODE:NormalizeHiddenAttachmentKey(attKey)
    return normalizeAttachmentKey(attKey)
end

function MODE:GetHiddenAttachmentPlacement(attKey)
    attKey = normalizeAttachmentKey(attKey)
    if attKey == "" or not hg or not istable(hg.attachments) then
        return nil
    end

    for placement, placementTable in pairs(hg.attachments) do
        if attachmentSlotLookup[placement] and istable(placementTable) and placementTable[attKey] then
            return placement
        end
    end

    return nil
end

function MODE:BuildHiddenAttachmentOptionsForWeapon(className)
    local optionsByPlacement = {}

    for _, placement in ipairs(attachmentSlots) do
        optionsByPlacement[placement] = {
            {
                key = "",
                name = "None",
                placement = placement,
                icon = "",
            },
        }
    end

    className = string.Trim(string.lower(tostring(className or "")))
    if className == "" then
        return optionsByPlacement
    end

    local storedWeapon = weapons.GetStored(className)
    if not istable(storedWeapon) or not istable(storedWeapon.availableAttachments) then
        return optionsByPlacement
    end

    local hgAttachments = hg and hg.attachments or {}

    for _, placement in ipairs(attachmentSlots) do
        local entries = optionsByPlacement[placement]
        local seen = {
            [""] = true,
        }
        local placementOptions = storedWeapon.availableAttachments[placement]

        if istable(placementOptions) then
            if placementOptions.cannotremove then
                entries[1] = nil
                seen[""] = nil
            end

            for index = 1, #placementOptions do
                local option = placementOptions[index]
                if istable(option) and isstring(option[1]) then
                    addAttachmentOption(entries, seen, placement, option[1])
                end
            end

            local placementTable = istable(hgAttachments) and hgAttachments[placement] or nil
            local mountType = placementOptions.mountType
            if istable(placementTable) and mountType then
                for attKey, attData in pairs(placementTable) do
                    if isstring(attKey) and istable(attData) and isMountTypeCompatible(mountType, attData.mountType) then
                        addAttachmentOption(entries, seen, placement, attKey)
                    end
                end
            end

            if placement == "underbarrel" and istable(placementTable) then
                for attKey, attData in pairs(placementTable) do
                    local keyLower = isstring(attKey) and string.lower(attKey) or ""
                    if keyLower ~= "" and string.find(keyLower, "laser", 1, true) then
                        if mountType and istable(attData) and attData.mountType then
                            if isMountTypeCompatible(mountType, attData.mountType) then
                                addAttachmentOption(entries, seen, placement, attKey)
                            end
                        elseif not mountType then
                            addAttachmentOption(entries, seen, placement, attKey)
                        end
                    end
                end
            end
        end

        table.sort(entries, function(left, right)
            if tostring(left.key or "") == "" then
                return true
            end

            if tostring(right.key or "") == "" then
                return false
            end

            return string.lower(tostring(left.name or "")) < string.lower(tostring(right.name or ""))
        end)
    end

    return optionsByPlacement
end

function MODE:NormalizeHiddenWeaponAttachments(className, attachments)
    local normalized = {}
    local optionsByPlacement = self:BuildHiddenAttachmentOptionsForWeapon(className)

    attachments = istable(attachments) and attachments or {}

    for _, placement in ipairs(attachmentSlots) do
        local chosenKey = normalizeAttachmentKey(attachments[placement])
        local hasChoice = false
        local fallbackKey = ""

        for _, entry in ipairs(optionsByPlacement[placement] or {}) do
            local entryKey = normalizeAttachmentKey(entry.key)
            if fallbackKey == "" then
                fallbackKey = entryKey
            end

            if entryKey == chosenKey then
                normalized[placement] = entryKey
                hasChoice = true
                break
            end
        end

        if not hasChoice then
            normalized[placement] = fallbackKey
        end
    end

    return normalized
end

function MODE:NormalizeHiddenLoadout(loadout)
    local defaultLoadout = self:GetDefaultHiddenLoadout()
    local hasSecondarySelection = istable(loadout) and loadout.secondary ~= nil
    local normalized = {
        primary = "",
        secondary = "",
        attachments = {
            primary = {},
            secondary = {},
        },
        armor = {},
    }

    if istable(loadout) then
        if isstring(loadout.primary) then
            normalized.primary = string.Trim(string.lower(loadout.primary))
        end

        if isstring(loadout.secondary) then
            normalized.secondary = string.Trim(string.lower(loadout.secondary))
        end
    end

    if normalized.primary == "" then
        normalized.primary = string.lower(defaultLoadout.primary or "")
    end

    if normalized.secondary == "" and not hasSecondarySelection then
        normalized.secondary = string.lower(defaultLoadout.secondary or "")
    end

    local sourceArmor = istable(loadout) and istable(loadout.armor) and loadout.armor or {}
    local defaultArmor = istable(defaultLoadout.armor) and defaultLoadout.armor or {}
    local sourceAttachments = istable(loadout) and istable(loadout.attachments) and loadout.attachments or {}
    local defaultAttachments = istable(defaultLoadout.attachments) and defaultLoadout.attachments or {}

    for _, slotName in ipairs(armorSlots) do
        normalized.armor[slotName] = normalizeArmorKey(sourceArmor[slotName] or defaultArmor[slotName])
    end

    normalized.attachments.primary = self:NormalizeHiddenWeaponAttachments(normalized.primary, sourceAttachments.primary or defaultAttachments.primary)
    normalized.attachments.secondary = self:NormalizeHiddenWeaponAttachments(normalized.secondary, sourceAttachments.secondary or defaultAttachments.secondary)

    return normalized
end

function MODE:IsHiddenWeaponAllowed(storedWeapon, className)
    if not istable(storedWeapon) or not isstring(className) then
        return false
    end

    className = string.Trim(string.lower(className))
    if className == "" or weaponBlacklist[className] then
        return false
    end

    if self:IsHiddenAdminBlacklisted("weapon", className) then
        return false
    end

    if storedWeapon.AdminOnly then
        return false
    end

    -- Opt-in bypass for non-firearm hg utility tablets (e.g. the Solitron
    -- heartbeat sensor) that shouldn't have to satisfy the damage/clip/Base
    -- = "homigrad_base" gate but should still appear in the IRIS pool.
    if storedWeapon.HiddenLoadoutAllow then
        local slotHint = tostring(storedWeapon.HiddenLoadoutSlot or "")
        if slotHint == "primary" or slotHint == "secondary" then
            return true
        end
        local invCat = clampNumber(storedWeapon.weaponInvCategory, 0)
        if invCat == 1 or invCat == 2 then
            return true
        end
    end

    if string.lower(tostring(storedWeapon.Base or "")) ~= "homigrad_base" then
        return false
    end

    local inventoryCategory = clampNumber(storedWeapon.weaponInvCategory, 0)
    if inventoryCategory ~= 1 and inventoryCategory ~= 2 then
        return false
    end

    local primary = storedWeapon.Primary or {}
    local damage = clampNumber(primary.Damage, 0)
    local waitTime = clampNumber(primary.Wait, 0)
    local clipSize = clampNumber(primary.ClipSize, 0)
    local worldModel = tostring(storedWeapon.WorldModelFake or storedWeapon.WorldModel or "")

    if damage <= 0 or waitTime <= 0 or clipSize <= 0 then
        return false
    end

    return worldModel ~= ""
end

function MODE:GetHiddenWeaponSlot(storedWeapon)
    -- Honour an explicit slot tag first so opt-in utility weapons (radar etc.)
    -- can land in the secondary pool regardless of weaponInvCategory quirks.
    if istable(storedWeapon) and isstring(storedWeapon.HiddenLoadoutSlot) then
        local slotHint = string.Trim(string.lower(storedWeapon.HiddenLoadoutSlot))
        if slotHint == "primary" or slotHint == "secondary" then
            return slotHint
        end
    end

    local inventoryCategory = clampNumber(storedWeapon and storedWeapon.weaponInvCategory, 0)

    if inventoryCategory == 1 then
        return "primary"
    end

    if inventoryCategory == 2 then
        return "secondary"
    end
end

function MODE:GetHiddenWeaponStats(storedWeapon)
    local primary = istable(storedWeapon) and (storedWeapon.Primary or {}) or {}
    local waitTime = clampNumber(primary.Wait, 0.12)

    return {
        damage = clampNumber(primary.Damage, 0),
        wait = waitTime,
        clipSize = math.max(math.floor(clampNumber(primary.ClipSize, 0)), 0),
        penetration = clampNumber((storedWeapon and storedWeapon.Penetration) or primary.Penetration, 0),
        weight = clampNumber((storedWeapon and (storedWeapon.weight or storedWeapon.Weight)) or 0, 0),
        rpm = waitTime > 0 and math.floor((60 / waitTime) + 0.5) or 0,
        caliber = tostring(primary.Ammo or ""),
        automatic = primary.Automatic and true or false,
        worldModel = tostring((storedWeapon and (storedWeapon.WorldModelFake or storedWeapon.WorldModel)) or ""),
    }
end

function MODE:CalculateHiddenWeaponScore(storedWeapon, classNameHint)
    -- SWEP-declared score override: utility tablets (radar etc.) opt in via
    -- HiddenLoadoutScore so their loadout cost isn't auto-derived from a
    -- fake damage stat. Admin file override (handled below) still wins.
    if istable(storedWeapon) and tonumber(storedWeapon.HiddenLoadoutScore) then
        local declared = math.max(0, math.floor(tonumber(storedWeapon.HiddenLoadoutScore) + 0.5))
        if self.GetHiddenAdminScoreOverride and isstring(classNameHint) and classNameHint ~= "" then
            local override = self:GetHiddenAdminScoreOverride("weapon", classNameHint)
            if override ~= nil then
                return override
            end
        end
        return declared
    end

    local stats = self:GetHiddenWeaponStats(storedWeapon)
    local dps = stats.wait > 0 and (stats.damage / stats.wait) or stats.damage
    local score = (stats.damage * 0.4)
        + (dps * 0.08)
        + (stats.clipSize * 0.18)
        + (stats.penetration * 1.35)
        + (stats.weight * 2)
        + (stats.automatic and 4 or 0)

    if stats.rpm >= 900 then
        score = score + 4
    end

    score = math.max(0, math.floor(math.min(score, 120) + 0.5))

    -- Admin-set score override (superadmin-managed; takes priority over computed score).
    local className = classNameHint
    if not isstring(className) or className == "" then
        className = tostring(storedWeapon and (storedWeapon.ClassName or storedWeapon.Classname) or "")
    end
    className = string.lower(string.Trim(tostring(className or "")))
    if className ~= "" then
        local override = self:GetHiddenAdminScoreOverride("weapon", className)
        if override ~= nil then
            return math.Clamp(override, 0, 120)
        end
    end

    return score
end

function MODE:IsHiddenArmorAllowed(armorKey)
    armorKey = normalizeArmorKey(armorKey)
    if armorKey == "" or not hg or not hg.armor or not hg.GetArmorPlacement then
        return false
    end

    if self:IsHiddenAdminBlacklisted("armor", armorKey) then
        return false
    end

    local placement = hg.GetArmorPlacement(armorKey)
    local armorData = placement and hg.armor[placement] and hg.armor[placement][armorKey] or nil
    if not istable(armorData) then
        return false
    end

    if armorData.AdminOnly or armorData.Spawnable == false or armorData.nodrop then
        return false
    end

    if armorData.whitelistClasses and not armorData.whitelistClasses.swat then
        return false
    end

    return tostring(armorData.model or "") ~= ""
end

function MODE:GetHiddenArmorStats(armorKey)
    armorKey = normalizeArmorKey(armorKey)
    if armorKey == "" or not hg or not hg.armor or not hg.GetArmorPlacement then
        return nil
    end

    local placement = hg.GetArmorPlacement(armorKey)
    local armorData = placement and hg.armor[placement] and hg.armor[placement][armorKey] or nil
    if not istable(armorData) then
        return nil
    end

    return {
        key = armorKey,
        slot = placement,
        name = tostring((hg.armorNames and hg.armorNames[armorKey]) or string.NiceName(armorKey)),
        protection = clampNumber(armorData.protection, 0),
        mass = clampNumber(armorData.mass, 0),
        model = tostring(armorData.model or ""),
        bone = tostring(armorData.bone or ""),
        pos = armorData[3],
        ang = armorData[4],
        femPos = armorData.femPos,
        scale = clampNumber(armorData.scale, 1),
        femscale = clampNumber(armorData.femscale, clampNumber(armorData.scale, 1)),
        material = armorData.material,
        nobonemerge = armorData.nobonemerge and true or false,
    }
end

function MODE:CalculateHiddenArmorScore(armorKey)
    local stats = self:GetHiddenArmorStats(armorKey)
    if not stats then
        return 0
    end

    -- Admin-set score override takes priority over computed score.
    local normalizedKey = normalizeArmorKey(armorKey)
    if normalizedKey ~= "" then
        local override = self:GetHiddenAdminScoreOverride("armor", normalizedKey)
        if override ~= nil then
            return math.Clamp(override, 0, 120)
        end
    end

    local slotBonus = 0
    if stats.slot == "torso" then
        slotBonus = 6
    elseif stats.slot == "head" then
        slotBonus = 3
    elseif stats.slot == "face" then
        slotBonus = 2
    elseif stats.slot == "ears" then
        slotBonus = 1
    end

    local score = (stats.protection * 3) + (stats.mass * 1.5) + slotBonus
    return math.max(0, math.floor(score + 0.5))
end