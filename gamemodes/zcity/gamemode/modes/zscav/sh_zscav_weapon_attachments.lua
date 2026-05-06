ZSCAV = ZSCAV or {}

local ATTACHMENT_SLOTS = {
    "barrel",
    "mount",
    "sight",
    "underbarrel",
    "grip",
    "magwell",
}

local ATTACHMENT_SLOT_LABELS = {
    barrel = "Barrel",
    mount = "Mount",
    sight = "Sight",
    underbarrel = "Underbarrel",
    grip = "Grip",
    magwell = "Magwell",
}

local attachmentSlotLookup = {}
for _, slotName in ipairs(ATTACHMENT_SLOTS) do
    attachmentSlotLookup[slotName] = true
end

local function normalizeToken(value)
    return string.Trim(string.lower(tostring(value or "")))
end

local function normalizeWeaponClass(className)
    className = normalizeToken(className)
    if className == "" then return "" end

    if ZSCAV.GetWeaponBaseClass then
        return normalizeToken(ZSCAV:GetWeaponBaseClass(className))
    end

    return className
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

local function extractInstalledAttachmentKey(slotData)
    if isstring(slotData) then
        return ZSCAV:NormalizeAttachmentKey(slotData)
    end

    if not istable(slotData) then
        return ""
    end

    if isstring(slotData[1]) then
        return ZSCAV:NormalizeAttachmentKey(slotData[1])
    end

    if isstring(slotData.key) then
        return ZSCAV:NormalizeAttachmentKey(slotData.key)
    end

    return ""
end

local function addAttachmentOption(entries, seen, placement, attKey)
    attKey = ZSCAV:NormalizeAttachmentKey(attKey)
    if seen[attKey] then
        return
    end

    local iconMap = hg and hg.attachmentsIcons or nil
    seen[attKey] = true
    entries[#entries + 1] = {
        key = attKey,
        name = attKey == "" and "None" or ZSCAV:GetAttachmentName(attKey),
        placement = tostring(placement or ""),
        icon = attKey ~= "" and tostring(iconMap and iconMap[attKey] or "") or "",
    }
end

local originalGetItemMeta = ZSCAV.GetItemMeta

function ZSCAV:GetWeaponAttachmentSlots()
    return table.Copy(ATTACHMENT_SLOTS)
end

function ZSCAV:GetWeaponAttachmentSlotLabel(slotName)
    slotName = normalizeToken(slotName)
    return ATTACHMENT_SLOT_LABELS[slotName] or slotName
end

function ZSCAV:NormalizeAttachmentKey(attKey)
    if istable(attKey) then
        attKey = attKey.actual_class or attKey.class
    elseif IsValid(attKey) then
        attKey = attKey:GetClass()
    end

    attKey = normalizeToken(attKey)
    attKey = string.Replace(attKey, "ent_att_", "")
    if attKey == "empty" or attKey == "none" then
        return ""
    end

    return attKey
end

function ZSCAV:GetAttachmentItemClass(attKey)
    attKey = self:NormalizeAttachmentKey(attKey)
    if attKey == "" then return "" end
    return "ent_att_" .. attKey
end

function ZSCAV:IsAttachmentItemClass(className)
    if istable(className) then
        className = className.actual_class or className.class
    elseif IsValid(className) then
        className = className:GetClass()
    end

    className = normalizeToken(className)
    if className == "" then return false end
    if string.StartWith(className, "ent_att_") then return true end

    local attKey = self:NormalizeAttachmentKey(className)
    if attKey == "" then return false end
    return self:GetAttachmentPlacement(attKey) ~= nil
end

function ZSCAV:GetAttachmentPlacement(attKey)
    attKey = self:NormalizeAttachmentKey(attKey)
    if attKey == "" or not (hg and istable(hg.attachments)) then
        return nil
    end

    for placement, placementTable in pairs(hg.attachments) do
        if attachmentSlotLookup[placement] and istable(placementTable) and placementTable[attKey] then
            return placement
        end
    end

    return nil
end

function ZSCAV:GetAttachmentName(attKey)
    attKey = self:NormalizeAttachmentKey(attKey)
    if attKey == "" then return "None" end

    local dict = hg and (hg.attachmentslaunguage or hg.attachmentslanguage) or nil
    if istable(dict) and isstring(dict[attKey]) and dict[attKey] ~= "" then
        return dict[attKey]
    end

    local label = string.gsub(attKey, "_", " ")
    label = string.gsub(label, "(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)

    return label ~= "" and label or attKey
end

function ZSCAV:GetItemMeta(class)
    local className = class
    if istable(class) then
        className = class.actual_class or class.class
    end
    className = normalizeToken(className)
    if originalGetItemMeta then
        local meta = originalGetItemMeta(self, class)
        if meta then return meta end
    end

    if self:IsAttachmentItemClass(className) then
        return {
            name = self:GetAttachmentName(className),
            w = 1,
            h = 1,
            weight = 0.15,
        }
    end

    return nil
end

function ZSCAV:CanRemoveWeaponAttachment(className, placement)
    className = normalizeWeaponClass(className)
    placement = normalizeToken(placement)
    if className == "" or placement == "" then return true end

    local storedWeapon = weapons.GetStored(className)
    local placementOptions = storedWeapon and storedWeapon.availableAttachments and storedWeapon.availableAttachments[placement] or nil
    return not (istable(placementOptions) and placementOptions.cannotremove)
end

function ZSCAV:BuildWeaponAttachmentOptions(className)
    local optionsByPlacement = {}

    for _, placement in ipairs(ATTACHMENT_SLOTS) do
        optionsByPlacement[placement] = {
            {
                key = "",
                name = "None",
                placement = placement,
                icon = "",
            },
        }
    end

    className = normalizeWeaponClass(className)
    if className == "" then
        return optionsByPlacement
    end

    local storedWeapon = weapons.GetStored(className)
    if not istable(storedWeapon) or not istable(storedWeapon.availableAttachments) then
        return optionsByPlacement
    end

    local hgAttachments = hg and hg.attachments or {}

    for _, placement in ipairs(ATTACHMENT_SLOTS) do
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

function ZSCAV:NormalizeWeaponAttachments(className, attachments)
    local normalized = {}
    local optionsByPlacement = self:BuildWeaponAttachmentOptions(className)

    attachments = istable(attachments) and attachments or {}

    for _, placement in ipairs(ATTACHMENT_SLOTS) do
        local chosenKey = self:NormalizeAttachmentKey(attachments[placement])
        local hasChoice = false
        local fallbackKey = ""

        for _, entry in ipairs(optionsByPlacement[placement] or {}) do
            local entryKey = self:NormalizeAttachmentKey(entry.key)
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

function ZSCAV:GetInstalledWeaponAttachments(weaponEntity)
    local className = IsValid(weaponEntity) and weaponEntity:GetClass() or ""
    local normalized = self:NormalizeWeaponAttachments(className, {})
    if not IsValid(weaponEntity) or not istable(weaponEntity.attachments) then
        return normalized
    end

    for _, placement in ipairs(ATTACHMENT_SLOTS) do
        local attKey = extractInstalledAttachmentKey(weaponEntity.attachments[placement])
        if attKey ~= "" then
            normalized[placement] = attKey
        end
    end

    return self:NormalizeWeaponAttachments(className, normalized)
end

function ZSCAV:ResetWeaponAttachments(weaponEntity)
    if not IsValid(weaponEntity) then
        return
    end

    if isfunction(weaponEntity.ClearAttachments) then
        pcall(function()
            weaponEntity:ClearAttachments()
        end)
    end

    weaponEntity.attachments = istable(weaponEntity.attachments) and weaponEntity.attachments or {}

    for _, placement in ipairs(ATTACHMENT_SLOTS) do
        local placementOptions = istable(weaponEntity.availableAttachments) and weaponEntity.availableAttachments[placement] or nil
        if not istable(placementOptions) then
            weaponEntity.attachments[placement] = istable(weaponEntity.attachments[placement]) and weaponEntity.attachments[placement] or {}
            continue
        end

        if placementOptions.cannotremove then
            weaponEntity.attachments[placement] = istable(weaponEntity.attachments[placement]) and weaponEntity.attachments[placement] or {}
            continue
        end

        local emptyOption = nil
        for _, option in pairs(placementOptions) do
            if istable(option) and self:NormalizeAttachmentKey(option[1]) == "" then
                emptyOption = table.Copy(option)
                break
            end
        end

        weaponEntity.attachments[placement] = emptyOption or { "empty", {} }
    end

    if isfunction(weaponEntity.SyncAtts) then
        weaponEntity:SyncAtts()
    end
end

function ZSCAV:ApplyWeaponAttachments(ply, weaponEntity, attachments)
    if not IsValid(weaponEntity) then
        return
    end

    local normalized = self:NormalizeWeaponAttachments(weaponEntity:GetClass(), attachments)
    self:ResetWeaponAttachments(weaponEntity)

    if IsValid(ply) and hg and isfunction(hg.AddAttachmentForce) and istable(weaponEntity.availableAttachments) then
        for _, placement in ipairs(ATTACHMENT_SLOTS) do
            local attKey = self:NormalizeAttachmentKey(normalized[placement])
            if attKey ~= "" then
                hg.AddAttachmentForce(ply, weaponEntity, attKey)
            end
        end
    end

    timer.Simple(0, function()
        if IsValid(weaponEntity) and isfunction(weaponEntity.SyncAtts) then
            weaponEntity:SyncAtts()
        end
    end)
end

if SERVER then
    ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}

    local ATTACHMENT_MIRROR_GRIDS = {
        "backpack",
        "pocket",
        "secure",
        "vest",
    }
    local helpers = ZSCAV.ServerHelpers

    local function scanLooseAttachmentEntries(list, keys)
        if not istable(list) then
            return keys
        end

        keys = keys or {}

        for _, entry in ipairs(list) do
            if not istable(entry) then
                continue
            end

            local attKey = ZSCAV:NormalizeAttachmentKey(entry)
            if attKey ~= "" and ZSCAV:IsAttachmentItemClass(entry) then
                keys[#keys + 1] = attKey
            end
        end

        return keys
    end

    local function findLooseAttachmentEntryInList(list, attKey)
        if not istable(list) then
            return nil
        end

        for index, entry in ipairs(list) do
            if not istable(entry) then
                continue
            end

            if ZSCAV:IsAttachmentItemClass(entry) and ZSCAV:NormalizeAttachmentKey(entry) == attKey then
                return list, index, entry
            end
        end

        return nil
    end

    local function collectLooseAttachmentKeys(inv)
        local keys = {}
        if not istable(inv) then
            return keys
        end

        for _, gridName in ipairs(ATTACHMENT_MIRROR_GRIDS) do
            scanLooseAttachmentEntries(inv[gridName], keys)
        end

        return keys
    end

    local function writeLegacyAttachmentView(ply, legacyInventory, attachmentList)
        if not IsValid(ply) then
            return
        end

        legacyInventory = istable(legacyInventory) and legacyInventory or {}
        legacyInventory.Attachments = istable(attachmentList) and attachmentList or {}
        ply.inventory = legacyInventory
        ply:SetNetVar("Inventory", legacyInventory)
    end

    local function getLegacyInventoryState(ply)
        if not IsValid(ply) then
            return {}, {}
        end

        local netInventory = ply:GetNetVar("Inventory", {})
        local legacyInventory = istable(netInventory) and table.Copy(netInventory) or {}

        if istable(ply.inventory) then
            for key, value in pairs(ply.inventory) do
                if key ~= "Attachments" then
                    legacyInventory[key] = value
                end
            end
        end

        local currentAttachments = {}
        for _, attKey in ipairs(legacyInventory.Attachments or {}) do
            attKey = ZSCAV:NormalizeAttachmentKey(attKey)
            if attKey ~= "" then
                currentAttachments[#currentAttachments + 1] = attKey
            end
        end

        if not ply.zscav_attachment_bridge_initialized then
            local looseCounts = {}
            if ZSCAV:IsActive() and istable(ply.zscav_inv) then
                for _, looseKey in ipairs(collectLooseAttachmentKeys(ply.zscav_inv)) do
                    looseCounts[looseKey] = (looseCounts[looseKey] or 0) + 1
                end
            end

            local legacyPool = {}
            for _, attKey in ipairs(currentAttachments) do
                local remaining = looseCounts[attKey] or 0
                if remaining > 0 then
                    looseCounts[attKey] = remaining - 1
                else
                    legacyPool[#legacyPool + 1] = attKey
                end
            end

            ply.zscav_attachment_legacy_pool = legacyPool
            ply.zscav_attachment_bridge_initialized = true
        elseif not istable(ply.zscav_attachment_legacy_pool) then
            ply.zscav_attachment_legacy_pool = {}
        end

        legacyInventory.Attachments = currentAttachments
        return legacyInventory, ply.zscav_attachment_legacy_pool
    end

    local function updateLegacyAttachmentView(ply)
        local legacyInventory, legacyPool = getLegacyInventoryState(ply)
        local merged = {}

        if ZSCAV:IsActive() and istable(ply.zscav_inv) then
            for _, attKey in ipairs(collectLooseAttachmentKeys(ply.zscav_inv)) do
                merged[#merged + 1] = attKey
            end
        end

        for _, attKey in ipairs(legacyPool) do
            attKey = ZSCAV:NormalizeAttachmentKey(attKey)
            if attKey ~= "" then
                merged[#merged + 1] = attKey
            end
        end

        table.sort(merged)
        writeLegacyAttachmentView(ply, legacyInventory, merged)
        return merged, legacyPool
    end

    local function clearBridgeState(ply)
        if not IsValid(ply) then
            return
        end

        ply.zscav_attachment_legacy_pool = nil
        ply.zscav_attachment_bridge_initialized = nil
    end

    local function restoreLegacyAttachmentView(ply, resetState)
        if not IsValid(ply) then
            return {}
        end

        if not ply.zscav_attachment_bridge_initialized then
            return {}
        end

        local legacyInventory, legacyPool = getLegacyInventoryState(ply)
        local restored = {}

        for _, attKey in ipairs(legacyPool or {}) do
            attKey = ZSCAV:NormalizeAttachmentKey(attKey)
            if attKey ~= "" then
                restored[#restored + 1] = attKey
            end
        end

        table.sort(restored)
        writeLegacyAttachmentView(ply, legacyInventory, restored)

        if resetState ~= false then
            clearBridgeState(ply)
        end

        return restored
    end

    local function findLooseAttachmentEntry(inv, attKey)
        if not istable(inv) then
            return nil
        end

        for _, gridName in ipairs(ATTACHMENT_MIRROR_GRIDS) do
            local list, index, entry = findLooseAttachmentEntryInList(inv[gridName], attKey)
            if list and index then
                return list, index, gridName, entry
            end
        end

        return nil
    end

    function ZSCAV:SyncLegacyAttachmentInventory(ply)
        if not IsValid(ply) then
            return {}
        end

        return updateLegacyAttachmentView(ply)
    end

    function ZSCAV:RestoreLegacyAttachmentInventory(ply, resetState)
        return restoreLegacyAttachmentView(ply, resetState)
    end

    function ZSCAV:CountAttachmentResources(ply, attKey)
        attKey = self:NormalizeAttachmentKey(attKey)
        if attKey == "" or not IsValid(ply) then
            return 0
        end

        local total = 0
        if self:IsActive() then
            local inv = self.GetInventory and self:GetInventory(ply) or ply.zscav_inv
            if istable(inv) then
                for _, looseKey in ipairs(collectLooseAttachmentKeys(inv)) do
                    if looseKey == attKey then
                        total = total + 1
                    end
                end
            end
        end

        local _, legacyPool = getLegacyInventoryState(ply)
        for _, storedKey in ipairs(legacyPool) do
            if self:NormalizeAttachmentKey(storedKey) == attKey then
                total = total + 1
            end
        end

        return total
    end

    function ZSCAV:HasAttachmentResource(ply, attKey)
        return self:CountAttachmentResources(ply, attKey) > 0
    end

    function ZSCAV:ConsumeAttachmentResource(ply, attKey)
        attKey = self:NormalizeAttachmentKey(attKey)
        if attKey == "" or not IsValid(ply) then
            return false, "invalid"
        end

        if self:IsActive() then
            local inv = self.GetInventory and self:GetInventory(ply) or ply.zscav_inv
            local list, index, gridName = findLooseAttachmentEntry(inv, attKey)
            if list and index then
                table.remove(list, index)

                if helpers.SyncInventory then
                    helpers.SyncInventory(ply)
                else
                    updateLegacyAttachmentView(ply)
                end
                return true, gridName
            end
        end

        local legacyInventory, legacyPool = getLegacyInventoryState(ply)
        for index, storedKey in ipairs(legacyPool) do
            if self:NormalizeAttachmentKey(storedKey) == attKey then
                table.remove(legacyPool, index)
                if self:IsActive() and istable(ply.zscav_inv) then
                    updateLegacyAttachmentView(ply)
                else
                    writeLegacyAttachmentView(ply, legacyInventory, table.Copy(legacyPool))
                end
                return true, "legacy"
            end
        end

        return false, "missing"
    end

    function ZSCAV:GrantAttachmentResource(ply, attKey, options)
        attKey = self:NormalizeAttachmentKey(attKey)
        options = istable(options) and options or {}
        if attKey == "" or not IsValid(ply) then
            return false, "invalid"
        end

        if options.allowDuplicate == false and self:HasAttachmentResource(ply, attKey) then
            return false, "duplicate"
        end

        if self:IsActive() then
            local ok, where = self:TryAddItemEntry(ply, {
                class = self:GetAttachmentItemClass(attKey),
            })
            if ok then
                return true, where
            end

            return false, where or "space"
        end

        local legacyInventory, legacyPool = getLegacyInventoryState(ply)
        legacyPool[#legacyPool + 1] = attKey
        writeLegacyAttachmentView(ply, legacyInventory, table.Copy(legacyPool))
        return true, "legacy"
    end

    function ZSCAV:StashDetachedAttachment(ply, attKey)
        return self:GrantAttachmentResource(ply, attKey, {
            allowDuplicate = true,
        })
    end

    function ZSCAV:SyncHeldWeaponEntryState(ply, weaponEntity)
        if not (IsValid(ply) and IsValid(weaponEntity) and self:IsActive() and self.CaptureWeaponState) then
            return false
        end

        local inv = self.GetInventory and self:GetInventory(ply) or ply.zscav_inv
        if not (istable(inv) and istable(inv.weapons)) then
            return false
        end

        local weaponUID = tostring(weaponEntity.zscav_weapon_uid or "")
        local actualClass = tostring(weaponEntity:GetClass() or "")
        local entry = nil

        for _, candidate in pairs(inv.weapons) do
            if not istable(candidate) then
                continue
            end

            if weaponUID ~= "" and tostring(candidate.weapon_uid or "") == weaponUID then
                entry = candidate
                break
            end

            if actualClass ~= "" and tostring(candidate.actual_class or "") == actualClass then
                entry = candidate
                break
            end
        end

        if not entry and self.FindHeldWeaponForEntry then
            local baseClass = self:GetWeaponBaseClass(weaponEntity)
            for _, candidate in pairs(inv.weapons) do
                if istable(candidate) and self:GetWeaponBaseClass(candidate.class) == baseClass then
                    local matchedWeapon = self:FindHeldWeaponForEntry(ply, candidate)
                    if matchedWeapon == weaponEntity then
                        entry = candidate
                        break
                    end
                end
            end
        end

        if not entry then
            return false
        end

        if self.EnsureWeaponEntryRuntime then
            self:EnsureWeaponEntryRuntime(entry, weaponEntity)
        end

        entry.actual_class = actualClass ~= "" and actualClass or tostring(entry.actual_class or "")
        entry.weapon_state = self:CaptureWeaponState(ply, weaponEntity, entry)

        if helpers.SyncInventory then
            helpers.SyncInventory(ply)
        else
            updateLegacyAttachmentView(ply)
        end

        return true
    end

    hook.Add("ZB_PreRoundStart", "ZScavAttachmentBridge_RestoreLegacyView", function()
        local nextRound = zb and (zb.nextround or (zb.GetPreferredRoundName and zb.GetPreferredRoundName())) or nil
        if tostring(nextRound or "") == tostring(ZSCAV.MODE_NAME or "zscav") then
            return
        end

        for _, ply in player.Iterator() do
            restoreLegacyAttachmentView(ply)
        end
    end)

    hook.Add("PlayerSpawn", "ZScavAttachmentBridge_SpawnSafetyRestore", function(ply)
        if not IsValid(ply) then
            return
        end

        if ZSCAV:IsActive() then
            return
        end

        restoreLegacyAttachmentView(ply)
    end)
end