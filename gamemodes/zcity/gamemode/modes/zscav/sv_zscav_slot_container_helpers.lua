ZSCAV = ZSCAV or {}
ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}

local helpers = ZSCAV.ServerHelpers
local Notice = helpers.Notice
local getGridLayoutBlocks = helpers.getGridLayoutBlocks
local getContainerLayoutBlocks = helpers.getContainerLayoutBlocks
local fitsAt = helpers.fitsAt
local findFreeSpotAR = helpers.findFreeSpotAR
local CopyItemEntry = helpers.CopyItemEntry
local StripWeaponEntry = helpers.StripWeaponEntry

local function SlotEntryForDrag(inv, kind, slot)
    if not istable(inv) then return nil end

    kind = tostring(kind or "")
    slot = tostring(slot or "")

    if kind == "gear" then
        local ge = inv.gear and inv.gear[slot]
        if not ge or not ge.class then return nil end

        local sz = ZSCAV:GetItemSize(ge)
        return CopyItemEntry(ge, {
            kind = "gear",
            slot = slot,
            w = math.max(1, tonumber(sz.w) or 1),
            h = math.max(1, tonumber(sz.h) or 1),
        }) or {
            kind = "gear",
            slot = slot,
            class = ge.class,
            uid = ge.uid,
            w = math.max(1, tonumber(sz.w) or 1),
            h = math.max(1, tonumber(sz.h) or 1),
        }
    elseif kind == "weapon" then
        local we = inv.weapons and inv.weapons[slot]
        if not we or not we.class then return nil end

        local sz = ZSCAV:GetItemSize(we)
        return CopyItemEntry(we, {
            kind = "weapon",
            slot = slot,
            w = math.max(1, tonumber(sz.w) or 1),
            h = math.max(1, tonumber(sz.h) or 1),
        })
    end

    return nil
end

local function RemoveFromSlotForDrag(ply, inv, s)
    if s.kind == "weapon" then
        StripWeaponEntry(ply, s)
        inv.weapons[s.slot] = nil
        return true
    end

    if s.slot == "backpack" then
        Notice(ply, "Drag unequip for backpack is blocked. Use unequip action.")
        return false
    end

    if s.slot == "tactical_rig" or s.slot == "vest" then
        local def = ZSCAV:GetGearDef(s.class)
        if def and def.compartment then
            Notice(ply, "Drag unequip for rig is blocked. Use unequip action.")
            return false
        end
    end

    if ZSCAV:IsArmorEntityClass(s.class) then
        if not ZSCAV:RemoveArmorNoDrop(ply, s.class) then
            Notice(ply, "Could not remove armor cleanly: " .. tostring(s.class))
            return false
        end
    end

    inv.gear[s.slot] = nil
    return true
end

local function PlaceSlotEntryIntoGrid(_ply, inv, s, toGrid, x, y, rotated)
    local toList = inv[toGrid]
    if not toList then return false, "bad_target" end

    local grids = ZSCAV:GetEffectiveGrids(inv)
    local target = grids[toGrid]
    if not target then return false, "bad_target" end

    local w, h = s.w, s.h
    if rotated and w ~= h then
        w, h = h, w
    end

    local layout = getGridLayoutBlocks(inv, toGrid)
    if not fitsAt(toList, x, y, w, h, target.w, target.h, nil, layout) then
        return false, "no_room"
    end

    toList[#toList + 1] = CopyItemEntry(s, {
        x = x,
        y = y,
        w = w,
        h = h,
    })

    return true
end

local function ResolveContainerPlacement(contents, gw, gh, x, y, w, h, layoutBlocks)
    if fitsAt(contents, x, y, w, h, gw, gh, nil, layoutBlocks) then
        return x, y, w, h
    end

    local fx, fy, wasRotated = findFreeSpotAR(contents, gw, gh, w, h, layoutBlocks)
    if not fx then return nil end

    local ew = wasRotated and h or w
    local eh = wasRotated and w or h
    return fx, fy, ew, eh
end

local function BagContainsUIDRecursive(rootUID, wantedUID, seen)
    rootUID = tostring(rootUID or "")
    wantedUID = tostring(wantedUID or "")
    if rootUID == "" or wantedUID == "" then return false end
    if rootUID == wantedUID then return true end

    seen = seen or {}
    if seen[rootUID] then return false end
    seen[rootUID] = true

    local bag = ZSCAV:LoadBag(rootUID)
    if not bag then return false end

    for _, it in ipairs(bag.contents or {}) do
        local childUID = tostring(it.uid or "")
        if childUID ~= "" then
            if childUID == wantedUID then return true end
            if BagContainsUIDRecursive(childUID, wantedUID, seen) then return true end
        end
    end

    return false
end

local function GetEquippedContainerForSlot(inv, slotID)
    if not istable(inv) then return nil end

    inv.gear = inv.gear or {}
    local eq = inv.gear[slotID]
    if not (istable(eq) and eq.class) then return nil end

    local uid = tostring(eq.uid or "")
    if uid == "" then return nil end

    local grids = ZSCAV:GetEffectiveGrids(inv)
    if not istable(grids) then return nil end

    if slotID == "backpack" then
        local g = grids.backpack
        if not g then return nil end

        inv.backpack = inv.backpack or {}
        return {
            uid = uid,
            class = eq.class,
            list = inv.backpack,
            w = tonumber(g.w) or 0,
            h = tonumber(g.h) or 0,
            layout = getGridLayoutBlocks(inv, "backpack"),
            gridName = "backpack",
            slotID = "backpack",
        }
    end

    if slotID == "tactical_rig" or slotID == "vest" then
        local g = grids.vest
        if not g then return nil end

        inv.vest = inv.vest or {}
        return {
            uid = uid,
            class = eq.class,
            list = inv.vest,
            w = tonumber(g.w) or 0,
            h = tonumber(g.h) or 0,
            layout = getGridLayoutBlocks(inv, "vest"),
            gridName = "vest",
            slotID = slotID,
        }
    end

    if slotID == "secure_container" then
        local g = grids.secure
        if not g then return nil end

        inv.secure = inv.secure or {}
        return {
            uid = uid,
            class = eq.class,
            list = inv.secure,
            w = tonumber(g.w) or 0,
            h = tonumber(g.h) or 0,
            layout = getGridLayoutBlocks(inv, "secure"),
            gridName = "secure",
            slotID = "secure_container",
        }
    end

    return nil
end

local function PlaceSlotEntryIntoContainer(_ply, s, targetUID, x, y, rotated)
    if not targetUID or targetUID == "" then return false, "bad_target" end

    local bag = ZSCAV:LoadBag(targetUID)
    if not bag then return false, "bad_target" end
    bag.contents = bag.contents or {}

    local gw, gh = 0, 0
    if ZSCAV and ZSCAV.GetContainerGridSize then
        gw, gh = ZSCAV:GetContainerGridSize(bag.class)
    end
    if not (isnumber(gw) and isnumber(gh) and gw > 0 and gh > 0) then
        local def = ZSCAV:GetGearDef(bag.class) or {}
        local internal = def.internal or { w = 4, h = 4 }
        gw, gh = tonumber(internal.w) or 4, tonumber(internal.h) or 4
    end

    local layoutBlocks = getContainerLayoutBlocks(bag.class, gw, gh)
    local w, h = s.w, s.h
    if rotated and w ~= h then
        w, h = h, w
    end

    local px, py, pw, ph = ResolveContainerPlacement(bag.contents, gw, gh, x, y, w, h, layoutBlocks)
    if not px then
        return false, "no_room"
    end

    bag.contents[#bag.contents + 1] = CopyItemEntry(s, {
        x = px,
        y = py,
        w = pw,
        h = ph,
    })

    if not ZSCAV:SaveBag(targetUID, bag.class, bag.contents) then
        return false, "save_failed"
    end

    return true
end

helpers.SlotEntryForDrag = SlotEntryForDrag
helpers.RemoveFromSlotForDrag = RemoveFromSlotForDrag
helpers.PlaceSlotEntryIntoGrid = PlaceSlotEntryIntoGrid
helpers.ResolveContainerPlacement = ResolveContainerPlacement
helpers.BagContainsUIDRecursive = BagContainsUIDRecursive
helpers.GetEquippedContainerForSlot = GetEquippedContainerForSlot
helpers.PlaceSlotEntryIntoContainer = PlaceSlotEntryIntoContainer