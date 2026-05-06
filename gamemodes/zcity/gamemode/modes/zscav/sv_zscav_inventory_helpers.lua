ZSCAV = ZSCAV or {}
ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}

local helpers = ZSCAV.ServerHelpers
local NewInventory = helpers.NewInventory
local MigrateLegacyGrids = helpers.MigrateLegacyGrids
local SyncInventory = helpers.SyncInventory
local Notice = helpers.Notice
local CanStoreItemInPlayerGrid = helpers.CanStoreItemInPlayerGrid
local routeOrder = helpers.routeOrder
local getGridLayoutBlocks = helpers.getGridLayoutBlocks
local findFreeSpotAR = helpers.findFreeSpotAR
local CopyItemEntry = helpers.CopyItemEntry
local EnsureWeaponEntryRuntime = helpers.EnsureWeaponEntryRuntime
local FindHeldWeaponForEntry = helpers.FindHeldWeaponForEntry
local SelectWeaponEntry = helpers.SelectWeaponEntry
local GiveWeaponInstance = helpers.GiveWeaponInstance
local GetWeaponBaseClass = helpers.GetWeaponBaseClass

function ZSCAV:GetInventory(ply)
    if not IsValid(ply) then return nil end
    ply.zscav_inv = ply.zscav_inv or NewInventory()
    MigrateLegacyGrids(ply, ply.zscav_inv)
    return ply.zscav_inv
end

function ZSCAV:FindWeaponSlotByClass(inv, class)
    if not inv or not inv.weapons then return nil end
    class = GetWeaponBaseClass and GetWeaponBaseClass(class) or tostring(class or ""):lower()
    for slot, entry in pairs(inv.weapons) do
        if entry and (GetWeaponBaseClass and GetWeaponBaseClass(entry.class) or tostring(entry.class or ""):lower()) == class then
            return slot, entry
        end
    end
    return nil
end

local function FindWeaponSlotForHeldWeapon(inv, wep)
    if not inv or not inv.weapons or not IsValid(wep) then return nil end

    local weaponUID = tostring(wep.zscav_weapon_uid or "")
    if weaponUID ~= "" then
        for slot, entry in pairs(inv.weapons) do
            if entry and tostring(entry.weapon_uid or "") == weaponUID then
                return slot, entry
            end
        end
    end

    local actualClass = tostring(wep:GetClass() or "")
    if actualClass ~= "" then
        for slot, entry in pairs(inv.weapons) do
            if entry and tostring(entry.actual_class or "") == actualClass then
                return slot, entry
            end
        end
    end

    return ZSCAV:FindWeaponSlotByClass(inv, wep)
end

local function BuildHeldWeaponSlotEntry(existingEntry, wep, slot)
    local out = CopyItemEntry(existingEntry or { class = GetWeaponBaseClass(wep) }) or {
        class = GetWeaponBaseClass(wep),
    }
    if tostring(slot or "") ~= "" then
        out.slot = tostring(slot)
    end
    EnsureWeaponEntryRuntime(out, wep)
    return out
end

local function WeaponEntriesEquivalent(left, right)
    if not left and not right then return true end
    if not left or not right then return false end

    return (GetWeaponBaseClass(left.class) == GetWeaponBaseClass(right.class))
        and tostring(left.weapon_uid or "") == tostring(right.weapon_uid or "")
        and tostring(left.actual_class or "") == tostring(right.actual_class or "")
end

local function GetCompatibleWeaponSlots(expected)
    if ZSCAV.GetCompatibleWeaponSlots then
        return ZSCAV:GetCompatibleWeaponSlots(expected)
    end
    if not expected or expected == "" then return nil end
    return { expected }
end

local function WeaponSlotIsCompatible(expected, slot)
    if ZSCAV.IsWeaponSlotCompatible then
        return ZSCAV:IsWeaponSlotCompatible(expected, slot)
    end

    for _, candidate in ipairs(GetCompatibleWeaponSlots(expected) or {}) do
        if candidate == slot then
            return true
        end
    end
    return false
end

local function ResolveWeaponEquipSlot(inv, class, preferredSlot)
    local expected = ZSCAV:GetEquipWeaponSlot(class)
    if not expected then return nil end

    inv = inv or {}
    inv.weapons = inv.weapons or {}
    preferredSlot = tostring(preferredSlot or "")

    local compatibleSlots = GetCompatibleWeaponSlots(expected)
    if not compatibleSlots then return nil end

    if preferredSlot ~= "" then
        if not WeaponSlotIsCompatible(expected, preferredSlot) then return nil end
        return preferredSlot
    end

    for _, slot in ipairs(compatibleSlots) do
        if not inv.weapons[slot] then
            return slot
        end
    end

    return nil
end

helpers.ResolveWeaponEquipSlot = ResolveWeaponEquipSlot

local function ReserveActualWeaponSlot(inv, wep, actualBySlot)
    local class = GetWeaponBaseClass(wep)
    local expected = ZSCAV:GetEquipWeaponSlot(class)
    if not expected then return nil end

    local compatibleSlots = GetCompatibleWeaponSlots(expected)
    if not compatibleSlots then return nil end

    local existingSlot, existingEntry = FindWeaponSlotForHeldWeapon(inv, wep)
    if existingSlot and WeaponSlotIsCompatible(expected, existingSlot) and not actualBySlot[existingSlot] then
        actualBySlot[existingSlot] = BuildHeldWeaponSlotEntry(existingEntry, wep, existingSlot)
        return existingSlot
    end

    for _, slot in ipairs(compatibleSlots) do
        if not actualBySlot[slot] then
            actualBySlot[slot] = BuildHeldWeaponSlotEntry(nil, wep, slot)
            return slot
        end
    end

    return nil
end

-- Reconcile inv.weapons against the player's actual weapon list. Handles:
--  * Homigrad radial "drop" routing the weapon onto hg_sling instead of the
--    ground (weapon stays in ply:GetWeapons() - slot must NOT be cleared).
--  * Weapon stripped externally without a PlayerDroppedWeapon fire.
--  * Weapon equipped externally (admin give, mode start kit) - slot adopts it.
function ZSCAV:ReconcileWeapons(ply)
    if not IsValid(ply) then return end
    local inv = self:GetInventory(ply)
    if not inv then return end
    inv.weapons = inv.weapons or {}

    local actualBySlot = {}
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and not self:ShouldBypassInventoryPickup(wep) then
            ReserveActualWeaponSlot(inv, wep, actualBySlot)
        end
    end

    local changed = false

    for slot, entry in pairs(inv.weapons) do
        local actual = actualBySlot[slot]
        if not actual then
            inv.weapons[slot] = nil
            changed = true
        elseif not WeaponEntriesEquivalent(entry, actual) then
            inv.weapons[slot] = actual
            changed = true
        end
    end

    for slot, class in pairs(actualBySlot) do
        if not inv.weapons[slot] then
            inv.weapons[slot] = class
            changed = true
        end
    end

    if changed then SyncInventory(ply) end
end

local SLOT_TO_ARMOR_PLACEMENT = {
    ears = "ears",
    helmet = "head",
    face_cover = "face",
}

local TORSO_ARMOR_SLOTS = {
    "body_armor",
    "tactical_rig",
    "vest",
}

-- Keep ZScav gear slots in sync with actual Homigrad armor state.
-- This fixes stale equipped slots when armor is removed externally and also
-- adopts externally equipped armor into the right modern torso slot.
function ZSCAV:ReconcileArmor(ply)
    if not IsValid(ply) then return end
    local inv = self:GetInventory(ply)
    if not inv then return end

    inv.gear = inv.gear or {}
    ply.armors = ply.armors or ply:GetNetVar("Armor", {}) or {}

    local changed = false

    for slot, placement in pairs(SLOT_TO_ARMOR_PLACEMENT) do
        local entry = inv.gear[slot]
        local worn = tostring(ply.armors[placement] or ""):lower()

        if entry and self:IsArmorEntityClass(entry.class) then
            local want = tostring(self:GetArmorEntityName(entry.class) or ""):lower()
            if worn ~= want then
                if worn ~= "" then
                    inv.gear[slot] = { class = "ent_armor_" .. worn, slot = slot }
                else
                    inv.gear[slot] = nil
                end
                changed = true
            end
        elseif (not entry) and worn ~= "" then
            inv.gear[slot] = { class = "ent_armor_" .. worn, slot = slot }
            changed = true
        end
    end

    local torsoWorn = tostring(ply.armors.torso or ""):lower()
    local desiredTorsoSlot = ""
    if torsoWorn ~= "" then
        local armorClass = "ent_armor_" .. torsoWorn
        desiredTorsoSlot = tostring(self.GetTorsoArmorSlotForClass and self:GetTorsoArmorSlotForClass(armorClass) or "body_armor")
        if desiredTorsoSlot == "vest" then
            desiredTorsoSlot = "body_armor"
        end
    end

    for _, slot in ipairs(TORSO_ARMOR_SLOTS) do
        local entry = inv.gear[slot]
        local shouldHold = torsoWorn ~= "" and slot == desiredTorsoSlot

        if entry and self:IsArmorEntityClass(entry.class) then
            local want = tostring(self:GetArmorEntityName(entry.class) or ""):lower()
            if shouldHold then
                if want ~= torsoWorn then
                    inv.gear[slot] = { class = "ent_armor_" .. torsoWorn, slot = slot }
                    changed = true
                end
            else
                inv.gear[slot] = nil
                changed = true
            end
        elseif shouldHold then
            inv.gear[slot] = { class = "ent_armor_" .. torsoWorn, slot = slot }
            changed = true
        end
    end

    if changed then SyncInventory(ply) end
end

-- Compatibility shim: older loaded chunks may still call global
-- ReconcileArmor(ply, inv). Route that safely to the namespaced method.
function ReconcileArmor(ply, _inv)
    if not ZSCAV or not ZSCAV.ReconcileArmor then return end
    return ZSCAV:ReconcileArmor(ply)
end

function ZSCAV:TryAddItemEntry(ply, item)
    local inv = self:GetInventory(ply)
    if not inv then return false end

    item = CopyItemEntry(item)
    if not item or not item.class then return false end

    local class = GetWeaponBaseClass(item.class)
    local uid = item.uid
    item.class = class

    local ok = self:CanCarryMore(inv, item, uid)
    if not ok then return false, "weight" end

    local size = self:GetItemSize(item)
    local grids = self:GetEffectiveGrids(inv)

    for _, gridName in ipairs(routeOrder(class)) do
        local canStoreInGrid = true
        if CanStoreItemInPlayerGrid then
            canStoreInGrid = select(1, CanStoreItemInPlayerGrid(gridName, item))
        end

        if not canStoreInGrid then
            continue
        end

        local grid = grids[gridName]
        local canFitGrid = grid and (
            (grid.w >= size.w and grid.h >= size.h)
            or (grid.w >= size.h and grid.h >= size.w)
        )
        if canFitGrid then
            local list = inv[gridName] or {}
            inv[gridName] = list
            local layoutBlocks = getGridLayoutBlocks and getGridLayoutBlocks(inv, gridName) or nil
            local x, y, wasRotated = findFreeSpotAR(list, grid.w, grid.h, size.w, size.h, layoutBlocks)
            if x then
                local entry = CopyItemEntry(item, {
                    x = x,
                    y = y,
                    w = wasRotated and size.h or size.w,
                    h = wasRotated and size.w or size.h,
                })
                list[#list + 1] = entry
                SyncInventory(ply)
                if self.IsGrenadeClass and self:IsGrenadeClass(class) and self.SyncGrenadeHotbar then
                    self:SyncGrenadeHotbar(ply)
                end
                return true, gridName
            end
        end
    end

    return false
end

function ZSCAV:TryAddItem(ply, class, uid, actualClass)
    local entry = CopyItemEntry(class)
    if not entry then
        entry = {
            class = class,
            uid = uid,
            actual_class = actualClass,
        }
    end

    if entry.uid == nil and uid ~= nil then
        entry.uid = uid
    end
    if (entry.actual_class == nil or tostring(entry.actual_class) == "") and actualClass ~= nil then
        entry.actual_class = actualClass
    end

    return self:TryAddItemEntry(ply, entry)
end

function ZSCAV:TryAutoEquipWeapon(ply, class)
    local inv = self:GetInventory(ply)
    if not inv then return false, "no_inventory" end

    local itemEntry = CopyItemEntry(class)
    if not itemEntry then
        itemEntry = { class = tostring(class or "") }
    end

    itemEntry.class = GetWeaponBaseClass(itemEntry.class)

    local expectedSlot = self:GetEquipWeaponSlot(itemEntry.class)
    if not expectedSlot then return false, "not_weapon" end

    local slot = ResolveWeaponEquipSlot(inv, itemEntry.class)
    if not slot then return false, "slot_occupied", expectedSlot end

    inv.weapons = inv.weapons or {}
    if inv.weapons[slot] then
        return false, "slot_occupied", slot
    end

    if not (weapons.GetStored(itemEntry.class) or scripted_ents.GetStored(itemEntry.class)) then
        return false, "missing_class", slot
    end

    EnsureWeaponEntryRuntime(itemEntry)
    inv.weapons[slot] = itemEntry

    local wepEnt = GiveWeaponInstance and GiveWeaponInstance(ply, itemEntry) or NULL
    local hasNow = IsValid(wepEnt) or (FindHeldWeaponForEntry and IsValid(FindHeldWeaponForEntry(ply, itemEntry)))
    if not hasNow then
        inv.weapons[slot] = nil
        SyncInventory(ply)
        return false, "blocked_give", slot
    end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        local selected = SelectWeaponEntry and select(1, SelectWeaponEntry(ply, itemEntry))
        if selected then
            return
        else
            inv.weapons[slot] = nil
            ZSCAV:TryAddItemEntry(ply, itemEntry)
            Notice(ply, "Auto-equip failed: " .. itemEntry.class .. " moved to inventory if possible.")
        end
    end)

    SyncInventory(ply)
    return true, slot
end
