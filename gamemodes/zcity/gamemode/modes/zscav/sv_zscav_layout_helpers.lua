ZSCAV = ZSCAV or {}
ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}

local helpers = ZSCAV.ServerHelpers

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    if ax + aw <= bx or bx + bw <= ax then return false end
    if ay + ah <= by or by + bh <= ay then return false end
    return true
end

local function rectInsideAnyBlock(x, y, w, h, blocks)
    for _, b in ipairs(blocks or {}) do
        if x >= b.x and y >= b.y and (x + w) <= (b.x + b.w) and (y + h) <= (b.y + b.h) then
            return true
        end
    end
    return false
end

local function getGridLayoutBlocks(inv, gridName)
    if gridName == "pocket" then
        -- Pockets are four independent 1x1 cells left-to-right.
        return {
            { x = 0, y = 0, w = 1, h = 1 },
            { x = 1, y = 0, w = 1, h = 1 },
            { x = 2, y = 0, w = 1, h = 1 },
            { x = 3, y = 0, w = 1, h = 1 },
        }
    end

    local class = nil
    if gridName == "vest" then
        local vest = inv and inv.gear and (inv.gear.tactical_rig or inv.gear.vest)
        class = vest and vest.class
    elseif gridName == "backpack" then
        local pack = inv and inv.gear and inv.gear.backpack
        class = pack and pack.class
    elseif gridName == "secure" then
        local secure = inv and inv.gear and inv.gear.secure_container
        class = secure and secure.class
    else
        return nil
    end

    if not class then return nil end

    local def = ZSCAV:GetGearDef(class)
    if not def or not istable(def.layoutBlocks) or #def.layoutBlocks == 0 then
        return nil
    end
    return def.layoutBlocks
end

local function getContainerLayoutBlocks(class, gw, gh)
    local def = ZSCAV:GetGearDef(class)
    local src = def and def.layoutBlocks
    if not istable(src) or #src == 0 then return nil end

    local out = {}
    gw = math.max(0, tonumber(gw) or 0)
    gh = math.max(0, tonumber(gh) or 0)

    for _, b in ipairs(src) do
        local bx = math.max(0, math.floor(tonumber(b.x) or 0))
        local by = math.max(0, math.floor(tonumber(b.y) or 0))
        local bw = math.max(1, math.floor(tonumber(b.w) or 1))
        local bh = math.max(1, math.floor(tonumber(b.h) or 1))
        if bx < gw and by < gh then
            if bx + bw > gw then bw = gw - bx end
            if by + bh > gh then bh = gh - by end
            if bw > 0 and bh > 0 then
                out[#out + 1] = { x = bx, y = by, w = bw, h = bh }
            end
        end
    end
    return (#out > 0) and out or nil
end

local function fitsAt(list, x, y, iw, ih, gw, gh, ignoreIdx, layoutBlocks)
    if x < 0 or y < 0 then return false end
    if x + iw > gw or y + ih > gh then return false end
    if layoutBlocks and #layoutBlocks > 0 and not rectInsideAnyBlock(x, y, iw, ih, layoutBlocks) then
        return false
    end
    for i, it in ipairs(list) do
        if i ~= ignoreIdx and rectsOverlap(x, y, iw, ih, it.x, it.y, it.w, it.h) then
            return false
        end
    end
    return true
end

local function findFreeSpot(list, gw, gh, iw, ih, layoutBlocks)
    if iw > gw or ih > gh or gw <= 0 or gh <= 0 then return nil end
    for y = 0, gh - ih do
        for x = 0, gw - iw do
            if fitsAt(list, x, y, iw, ih, gw, gh, nil, layoutBlocks) then return x, y end
        end
    end
    return nil
end

-- Like findFreeSpot but also tries the rotated (h×w) orientation when the
-- original doesn't fit. Returns x, y, wasRotated.
local function findFreeSpotAR(list, gw, gh, iw, ih, layoutBlocks)
    local x, y = findFreeSpot(list, gw, gh, iw, ih, layoutBlocks)
    if x then return x, y, false end
    if iw ~= ih then
        x, y = findFreeSpot(list, gw, gh, ih, iw, layoutBlocks)
        if x then return x, y, true end
    end
    return nil, nil, false
end

local secureBlockedWeaponSlots = {
    primary = true,
    secondary = true,
    sidearm = true,
    sidearm2 = true,
}

local secureBlockedGearSlots = {
    helmet = true,
    face_cover = true,
}

local function GetPlayerGridInsertBlockReason(gridName, item)
    gridName = tostring(gridName or "")
    if gridName ~= "secure" then return nil end

    local className = istable(item) and item.class or item
    className = tostring(className or "")
    if className == "" then return nil end

    local gearDef = ZSCAV.GetGearDef and ZSCAV:GetGearDef(className) or nil
    local gearSlot = tostring(gearDef and gearDef.slot or "")
    if secureBlockedGearSlots[gearSlot] then
        if gearSlot == "helmet" then
            return "Helmets cannot be stored in your secure container."
        end
        return "Face covers cannot be stored in your secure container."
    end

    local weaponSlot = ZSCAV.GetEquipWeaponSlot and ZSCAV:GetEquipWeaponSlot(className) or nil
    if secureBlockedWeaponSlots[tostring(weaponSlot or "")] then
        return "Guns cannot be stored in your secure container."
    end

    if ZSCAV.IsGrenadeClass and ZSCAV:IsGrenadeClass(className) then
        return "Grenades cannot be stored in your secure container."
    end

    return nil
end

local function CanStoreItemInPlayerGrid(gridName, item)
    local reason = GetPlayerGridInsertBlockReason(gridName, item)
    return reason == nil, reason
end

local function appendSecureRoute(order, class)
    if CanStoreItemInPlayerGrid("secure", class) then
        order[#order + 1] = "secure"
    end
    return order
end

local function routeOrder(class)
    class = tostring(class or ""):lower()
    if ZSCAV.IsAttachmentItemClass and ZSCAV:IsAttachmentItemClass(class) then
        return appendSecureRoute({ "backpack", "pocket", "vest" }, class)
    end
    -- Small consumables / ammo prefer quick-access grids first.
    if class:find("nade") or class:find("grenade") or class:find("molotov")
        or class:find("pipebomb") or class:find("ied") or class:find("claymore") then
        return appendSecureRoute({ "pocket", "vest", "backpack" }, class)
    end
    if class:find("ammo") or class:find("med") or class:find("bandage")
        or class:find("splint") or class:find("adrenaline") then
        return appendSecureRoute({ "pocket", "vest", "backpack" }, class)
    end
    return appendSecureRoute({ "vest", "backpack", "pocket" }, class)
end

local function FilterToFitGrid(list, gw, gh, layoutBlocks)
    local kept, evicted = {}, {}
    for _, it in ipairs(list) do
        if gw > 0 and gh > 0 and it.x + it.w <= gw and it.y + it.h <= gh
            and (not layoutBlocks or #layoutBlocks == 0 or rectInsideAnyBlock(it.x, it.y, it.w, it.h, layoutBlocks)) then
            kept[#kept + 1] = it
        else
            evicted[#evicted + 1] = it
        end
    end
    return kept, evicted
end

-- Re-place a list of items into a fresh grid using findFreeSpot. Returns
-- the placed list and any leftover (couldn't fit anywhere).
local function PackIntoGrid(items, gw, gh, layoutBlocks)
    local placed, leftover = {}, {}
    for _, it in ipairs(items) do
        if gw <= 0 or gh <= 0 then
            leftover[#leftover + 1] = it
        else
            local x, y, wasRotated = findFreeSpotAR(placed, gw, gh, it.w, it.h, layoutBlocks)
            if x then
                local ew = wasRotated and it.h or it.w
                local eh = wasRotated and it.w or it.h
                placed[#placed + 1] = {
                    class = it.class, x = x, y = y, w = ew, h = eh,
                    uid = it.uid,
                }
            else
                leftover[#leftover + 1] = it
            end
        end
    end
    return placed, leftover
end

helpers.getGridLayoutBlocks = getGridLayoutBlocks
helpers.getContainerLayoutBlocks = getContainerLayoutBlocks
helpers.fitsAt = fitsAt
helpers.findFreeSpot = findFreeSpot
helpers.findFreeSpotAR = findFreeSpotAR
helpers.GetPlayerGridInsertBlockReason = GetPlayerGridInsertBlockReason
helpers.CanStoreItemInPlayerGrid = CanStoreItemInPlayerGrid
helpers.routeOrder = routeOrder
helpers.FilterToFitGrid = FilterToFitGrid
helpers.PackIntoGrid = PackIntoGrid