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

function MODE:IsHiddenPreparationPhase()
    return (zb.ROUND_BEGIN or 0) > CurTime()
end

function MODE:GetHiddenLoadoutSlots()
    return armorSlots
end

function MODE:GetDefaultHiddenLoadout()
    return table.Copy(self.HiddenConfig.DefaultIrisLoadout or {
        primary = "",
        secondary = "",
        armor = {},
    })
end

function MODE:NormalizeHiddenArmorKey(armorKey)
    return normalizeArmorKey(armorKey)
end

function MODE:NormalizeHiddenLoadout(loadout)
    local defaultLoadout = self:GetDefaultHiddenLoadout()
    local hasSecondarySelection = istable(loadout) and loadout.secondary ~= nil
    local normalized = {
        primary = "",
        secondary = "",
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

    for _, slotName in ipairs(armorSlots) do
        normalized.armor[slotName] = normalizeArmorKey(sourceArmor[slotName] or defaultArmor[slotName])
    end

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

    if storedWeapon.AdminOnly then
        return false
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

function MODE:CalculateHiddenWeaponScore(storedWeapon)
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

    return math.max(0, math.floor(math.min(score, 120) + 0.5))
end

function MODE:IsHiddenArmorAllowed(armorKey)
    armorKey = normalizeArmorKey(armorKey)
    if armorKey == "" or not hg or not hg.armor or not hg.GetArmorPlacement then
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