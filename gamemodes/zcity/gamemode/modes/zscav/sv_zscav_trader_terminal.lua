local NET_OPEN = "ZScavTraderTerminalOpen"
local NET_STATE = "ZScavTraderTerminalState"
local NET_ACTION = "ZScavTraderTerminalAction"
local NET_TRADE_STATE = "ZScavTraderTradeState"
local NET_TRADE_ACTION = "ZScavTraderTradeAction"

util.AddNetworkString(NET_OPEN)
util.AddNetworkString(NET_STATE)
util.AddNetworkString(NET_ACTION)
util.AddNetworkString(NET_TRADE_STATE)
util.AddNetworkString(NET_TRADE_ACTION)

ZSCAV = ZSCAV or {}
ZSCAV.TraderTerminal = ZSCAV.TraderTerminal or {}

local lib = ZSCAV.TraderTerminal
local helpers = ZSCAV.ServerHelpers or {}
local OFFER_BAG_CLASS = "zscav_trade_player_offer"
local TICKET_ITEM_CLASS = "zscav_vendor_ticket"
local DATA_ROOT = "zcity"
local DATA_DIR = "zcity/trader_terminal"
local DATA_FILE = DATA_DIR .. "/state.json"
local NEARBY_RANGE = 220
local MAX_PRESET_ITEMS = 32
local MAX_PRESET_COOLDOWN = 60 * 60 * 24 * 365

local CopyItemEntry = helpers.CopyItemEntry
local Notice = helpers.Notice
local DeliverToPlayerMailbox = helpers.DeliverToPlayerMailbox

if not isfunction(CopyItemEntry) then
    CopyItemEntry = function(entry, overrides)
        if not istable(entry) then return nil end
        local out = table.Copy(entry)
        for key, value in pairs(overrides or {}) do
            out[key] = value
        end
        return out
    end
end

if not isfunction(Notice) then
    Notice = function(ply, msg)
        if IsValid(ply) then
            ply:ChatPrint(tostring(msg or ""))
        end
    end
end

lib.State = lib.State or {
    grants = {},
    presets = {},
    redemptions = {},
    next_ticket_number = 1,
    now_serving = 0,
}
lib.Sessions = lib.Sessions or {}
lib.SessionByTrader = lib.SessionByTrader or {}
lib.SessionByPlayer = lib.SessionByPlayer or {}
lib.SessionByOfferUID = lib.SessionByOfferUID or {}
lib.TerminalByPlayer = lib.TerminalByPlayer or {}
lib.ActiveVendors = lib.ActiveVendors or {}

local syncAllOpenTerminals

local function sendJSON(netName, target, payload)
    net.Start(netName)
        net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.Send(target)
end

local function normalizeSID64(value)
    value = tostring(value or "")
    if value == "" or not string.match(value, "^%d+$") then return "" end
    return value
end

local function ensureDataDir()
    if not file.IsDir(DATA_ROOT, "DATA") then
        file.CreateDir(DATA_ROOT)
    end

    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end
end

local function normalizePresetItem(item)
    if not istable(item) then return nil end

    local class = tostring(item.class or "")
    if class == "" or class == OFFER_BAG_CLASS or class == TICKET_ITEM_CLASS then return nil end

    local count = math.Clamp(math.floor(tonumber(item.count) or 1), 1, 64)
    return {
        class = class,
        count = count,
    }
end

local function normalizePresetItems(items)
    local out = {}

    for _, item in ipairs(items or {}) do
        local normalized = normalizePresetItem(item)
        if normalized then
            out[#out + 1] = normalized
            if #out >= MAX_PRESET_ITEMS then
                break
            end
        end
    end

    return out
end

local function normalizeCooldownSeconds(value)
    return math.Clamp(math.floor(tonumber(value) or 0), 0, MAX_PRESET_COOLDOWN)
end

local function normalizePreset(preset)
    if not istable(preset) then return nil end

    local name = string.Trim(tostring(preset.name or ""))
    if name == "" then return nil end

    local playerItems = normalizePresetItems(preset.player_items or {})
    local traderItems = normalizePresetItems(preset.trader_items or preset.items or {})
    if #traderItems <= 0 then return nil end

    return {
        id = string.Trim(tostring(preset.id or "")),
        name = name,
        description = string.Trim(tostring(preset.description or "")),
        player_items = playerItems,
        trader_items = traderItems,
        items = table.Copy(traderItems),
        cooldown_seconds = normalizeCooldownSeconds(preset.cooldown_seconds or preset.cooldown),
    }
end

local function saveState()
    ensureDataDir()
    file.Write(DATA_FILE, util.TableToJSON(lib.State or {}, true) or "{}")
end

local function normalizeQueueState()
    lib.State = lib.State or {}

    local nextTicketNumber = math.max(1, math.floor(tonumber(lib.State.next_ticket_number) or 1))
    local highestIssued = math.max(0, nextTicketNumber - 1)
    local nowServing = math.max(0, math.floor(tonumber(lib.State.now_serving) or 0))

    if nowServing > highestIssued then
        nowServing = highestIssued
    end

    local dirty = nextTicketNumber ~= tonumber(lib.State.next_ticket_number)
        or nowServing ~= tonumber(lib.State.now_serving)

    lib.State.next_ticket_number = nextTicketNumber
    lib.State.now_serving = nowServing

    return nowServing, nextTicketNumber, dirty
end

local function getNextTicketNumber()
    local _, nextTicketNumber = normalizeQueueState()
    return nextTicketNumber
end

local function getHighestIssuedTicketNumber()
    return math.max(0, getNextTicketNumber() - 1)
end

local function getWaitingTicketCount()
    local nowServing, nextTicketNumber = normalizeQueueState()
    return math.max(0, (nextTicketNumber - 1) - nowServing)
end

local function loadState()
    ensureDataDir()

    if not file.Exists(DATA_FILE, "DATA") then
        lib.State = {
            grants = {},
            presets = {},
            redemptions = {},
            next_ticket_number = 1,
            now_serving = 0,
        }
        saveState()
        return
    end

    local raw = file.Read(DATA_FILE, "DATA") or "{}"
    local decoded = util.JSONToTable(raw) or {}
    local grants = {}
    local presets = {}
    local redemptions = {}
    local nextTicketNumber = math.max(1, math.floor(tonumber(decoded.next_ticket_number) or 1))
    local nowServing = math.max(0, math.floor(tonumber(decoded.now_serving) or 0))

    for sid64, row in pairs(decoded.grants or {}) do
        sid64 = normalizeSID64(sid64)
        if sid64 ~= "" then
            grants[sid64] = {
                granted = row == true or (istable(row) and row.granted ~= false),
                name = istable(row) and tostring(row.name or "") or "",
                by_sid64 = istable(row) and normalizeSID64(row.by_sid64) or "",
                by_name = istable(row) and tostring(row.by_name or "") or "",
                at = istable(row) and tonumber(row.at) or os.time(),
            }
        end
    end

    for _, preset in ipairs(decoded.presets or {}) do
        local normalized = normalizePreset(preset)
        if normalized then
            if normalized.id == "" then
                normalized.id = string.format("preset_%d_%d", os.time(), math.random(1000, 9999))
            end
            presets[#presets + 1] = normalized
        end
    end

    for presetID, rows in pairs(decoded.redemptions or {}) do
        presetID = string.Trim(tostring(presetID or ""))
        if presetID ~= "" and istable(rows) then
            local bucket = {}

            for sid64, value in pairs(rows) do
                sid64 = normalizeSID64(sid64)
                local at = istable(value) and tonumber(value.at) or tonumber(value)
                if sid64 ~= "" and (at or 0) > 0 then
                    bucket[sid64] = math.floor(at)
                end
            end

            if next(bucket) ~= nil then
                redemptions[presetID] = bucket
            end
        end
    end

    table.sort(presets, function(left, right)
        return string.lower(left.name or "") < string.lower(right.name or "")
    end)

    lib.State = {
        grants = grants,
        presets = presets,
        redemptions = redemptions,
        next_ticket_number = nextTicketNumber,
        now_serving = nowServing,
    }

    local _, _, dirty = normalizeQueueState()
    if dirty then
        saveState()
    end
end

local function canManage(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return true end

    if COMMAND_GETACCES then
        local access = tonumber(COMMAND_GETACCES(ply)) or 0
        if access >= 1 then return true end
    end

    local ulxLib = rawget(_G, "ULX") or rawget(_G, "ulx")
    if ulxLib and ulxLib.CheckAccess then
        if ulxLib.CheckAccess(ply, "ulx ban") or ulxLib.CheckAccess(ply, "ulx kick") then
            return true
        end
    end

    return false
end

local function canUse(ply)
    if not IsValid(ply) then return false end
    if canManage(ply) then return true end

    local sid64 = normalizeSID64(ply:SteamID64())
    local row = sid64 ~= "" and lib.State.grants[sid64] or nil
    return istable(row) and row.granted == true
end

local function isTradeableClass(class)
    class = tostring(class or "")
    if class == "" or class == OFFER_BAG_CLASS or class == TICKET_ITEM_CLASS then return false end

    if ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(class) then return true end
    if ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) then return true end
    if ZSCAV.ItemSizes and ZSCAV.ItemSizes[class] then return true end
    if weapons.GetStored(class) or scripted_ents.GetStored(class) then return true end
    return false
end

local function buildTradeEntry(class)
    if not isTradeableClass(class) then return nil end

    local entry = CopyItemEntry({ class = class }) or { class = class }
    local size = ZSCAV.GetItemSize and ZSCAV:GetItemSize(entry) or nil

    entry.class = tostring(entry.class or class)
    entry.x = nil
    entry.y = nil
    entry.slot = nil
    entry.w = math.max(tonumber(entry.w) or tonumber(size and size.w) or 1, 1)
    entry.h = math.max(tonumber(entry.h) or tonumber(size and size.h) or 1, 1)
    return entry
end

local function getTradeDisplayName(class)
    class = tostring(class or "")
    if class == "" then return "Unknown" end

    local gear = ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) or nil
    if gear and tostring(gear.name or "") ~= "" then
        return tostring(gear.name)
    end

    local meta = ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(class) or nil
    if meta and tostring(meta.name or meta.PrintName or "") ~= "" then
        return tostring(meta.name or meta.PrintName)
    end

    local swep = weapons.GetStored(class)
    if swep and tostring(swep.PrintName or "") ~= "" then
        return tostring(swep.PrintName)
    end

    local sent = scripted_ents.GetStored(class)
    if sent and sent.t and tostring(sent.t.PrintName or "") ~= "" then
        return tostring(sent.t.PrintName)
    end

    return class
end

local function getPlayerBySID64(sid64)
    sid64 = normalizeSID64(sid64)
    if sid64 == "" then return nil end
    if player.GetBySteamID64 then
        return player.GetBySteamID64(sid64)
    end

    for _, ply in ipairs(player.GetAll()) do
        if normalizeSID64(ply:SteamID64()) == sid64 then
            return ply
        end
    end
end

local function getDisplayNameForSID64(sid64)
    local ply = getPlayerBySID64(sid64)
    if IsValid(ply) then
        return tostring(ply:Nick() or sid64)
    end

    local row = lib.State.grants[normalizeSID64(sid64)]
    if istable(row) and tostring(row.name or "") ~= "" then
        return tostring(row.name)
    end

    return tostring(sid64)
end

local function getOpenTerminalFor(ply)
    local ent = lib.TerminalByPlayer[ply]
    return IsValid(ent) and ent or nil
end

local function getPlayerSafeZoneContext(ply)
    if not IsValid(ply) then return false, nil end

    local safeZoneLib = rawget(_G, "ZCitySafeZones")
    if istable(safeZoneLib) and isfunction(safeZoneLib.FindZoneAtPos) then
        local zone = safeZoneLib.FindZoneAtPos(ply:GetPos(), safeZoneLib.ServerZones or {}, 0)
        if zone then
            return true, {
                id = tostring(zone.id or zone.uid or zone.name or "safe_zone"),
                name = tostring(zone.name or zone.id or "Safe Zone"),
            }
        end
    end

    if ply:GetNWBool("ZCityInSafeZone", false) then
        return true, {
            id = tostring(ply:GetNWString("ZCitySafeZoneID", "") or ""),
            name = tostring(ply:GetNWString("ZCitySafeZoneName", "") or ""),
        }
    end

    return false, nil
end

local function getActiveVendorsForZone(zoneID)
    zoneID = tostring(zoneID or "")
    local rows = {}

    if zoneID == "" then
        return rows
    end

    for sid64, row in pairs(lib.ActiveVendors or {}) do
        if tostring(row and row.zone_id or "") == zoneID then
            rows[#rows + 1] = {
                sid64 = tostring(sid64 or ""),
                name = tostring(row.name or sid64 or "Vendor"),
                zone_id = zoneID,
                zone_name = tostring(row.zone_name or ""),
                active_at = math.floor(tonumber(row.active_at) or 0),
            }
        end
    end

    table.sort(rows, function(left, right)
        return string.lower(left.name or "") < string.lower(right.name or "")
    end)

    return rows
end

local function setVendorStatusActive(ply)
    if not IsValid(ply) then return false, "invalid" end

    local inSafeZone, zone = getPlayerSafeZoneContext(ply)
    if not inSafeZone or not istable(zone) then
        return false, "safe_zone_required"
    end

    local sid64 = normalizeSID64(ply:SteamID64())
    if sid64 == "" then
        return false, "invalid"
    end

    lib.ActiveVendors[sid64] = {
        sid64 = sid64,
        name = tostring(ply:Nick() or sid64),
        zone_id = tostring(zone.id or ""),
        zone_name = tostring(zone.name or ""),
        active_at = os.time(),
    }

    return true, nil, lib.ActiveVendors[sid64]
end

local function clearVendorStatusBySID64(sid64)
    sid64 = normalizeSID64(sid64)
    if sid64 == "" then return false end
    if not lib.ActiveVendors[sid64] then return false end

    lib.ActiveVendors[sid64] = nil
    return true
end

local function getVendorStatusForPlayer(ply)
    local sid64 = normalizeSID64(IsValid(ply) and ply:SteamID64() or "")
    return sid64 ~= "" and lib.ActiveVendors[sid64] or nil
end

local function getNowServingNumber()
    local nowServing = normalizeQueueState()
    return nowServing
end

local function advanceNowServingNumber()
    local nowServing, nextTicketNumber = normalizeQueueState()
    local highestIssued = math.max(0, nextTicketNumber - 1)
    if nowServing >= highestIssued then
        return false, nowServing
    end

    lib.State.now_serving = nowServing + 1
    saveState()
    return true, lib.State.now_serving
end

local function getNearbyPlayersSnapshot(ply)
    local terminal = getOpenTerminalFor(ply)
    local origin = IsValid(terminal) and terminal:GetPos() or ply:GetPos()
    local rows = {}

    for _, target in ipairs(player.GetAll()) do
        if target == ply then
            continue
        end

        local dist = origin:Distance(target:GetPos())
        if dist > NEARBY_RANGE then
            continue
        end

        local targetSID64 = normalizeSID64(target:SteamID64())
        local grantRow = lib.State.grants[targetSID64]
        rows[#rows + 1] = {
            ent_index = target:EntIndex(),
            sid64 = targetSID64,
            name = tostring(target:Nick() or "Player"),
            distance = math.floor(dist + 0.5),
            has_trader_access = canUse(target),
            granted_access = istable(grantRow) and grantRow.granted == true or false,
            alive = target:Alive(),
            can_trade = ZSCAV.CanPlayerUseInventory and ZSCAV:CanPlayerUseInventory(target) or true,
            vendor_available = lib.ActiveVendors[targetSID64] ~= nil,
        }
    end

    table.sort(rows, function(left, right)
        if left.distance ~= right.distance then
            return left.distance < right.distance
        end
        return string.lower(left.name or "") < string.lower(right.name or "")
    end)

    return rows
end

local function getPlayerOfferEntries(session)
    if not istable(session) then return {} end

    local bag = ZSCAV:LoadBag(tostring(session.player_offer_uid or ""))
    local out = {}

    for _, entry in ipairs(bag and bag.contents or {}) do
        local copied = CopyItemEntry(entry)
        if copied and copied.class then
            out[#out + 1] = copied
        end
    end

    return out
end

local function getTraderOfferEntries(session)
    local out = {}

    for _, entry in ipairs(session and session.trader_items or {}) do
        local copied = CopyItemEntry(entry)
        if copied and copied.class then
            out[#out + 1] = copied
        end
    end

    return out
end

local function clonePresetItems(items)
    local out = {}

    for _, item in ipairs(items or {}) do
        local normalized = normalizePresetItem(item)
        if normalized then
            out[#out + 1] = normalized
        end
    end

    return out
end

local function buildTicketPresetSnapshot()
    local out = {}

    for _, preset in ipairs(lib.State.presets or {}) do
        local normalized = normalizePreset(preset)
        if normalized then
            out[#out + 1] = {
                id = tostring(normalized.id or ""),
                name = tostring(normalized.name or ""),
                player_items = clonePresetItems(normalized.player_items),
                trader_items = clonePresetItems(normalized.trader_items or normalized.items),
                cooldown_seconds = normalizeCooldownSeconds(normalized.cooldown_seconds),
            }
        end
    end

    return out
end

local function getTicketIssuerInfo(source)
    if IsValid(source) then
        if source:IsPlayer() then
            return tostring(source:Nick() or "Vendor"), normalizeSID64(source:SteamID64())
        end

        local label = tostring(source.PrintName or "")
        if label == "" and source.GetClass then
            label = tostring(source:GetClass() or "")
        end
        if label == "" then
            label = "Ticket Machine"
        end

        return label, ""
    end

    return "Vendor", ""
end

local function playerHasInventoryTicket(ply)
    if not IsValid(ply) or not (ZSCAV and ZSCAV.GetInventory) then
        return false
    end

    local inv = ZSCAV:GetInventory(ply)
    if not istable(inv) then
        return false
    end

    for _, gridName in ipairs({ "pocket", "backpack", "vest", "secure" }) do
        for _, entry in ipairs(inv[gridName] or {}) do
            if tostring(entry and entry.class or "") == TICKET_ITEM_CLASS then
                return true
            end
        end
    end

    return false
end

local function buildVendorTicketEntry(source, ticketNumber, target)
    local traderName, traderSID64 = getTicketIssuerInfo(source)
    local inSafeZone, zone = getPlayerSafeZoneContext(target)
    local availableVendors = inSafeZone and getActiveVendorsForZone(zone and zone.id or "") or {}
    local shoppingListOnly = #availableVendors > 0

    return CopyItemEntry({
        class = TICKET_ITEM_CLASS,
        ticket_data = {
            number = math.max(1, math.floor(tonumber(ticketNumber) or 1)),
            vendor_name = traderName,
            vendor_sid64 = traderSID64,
            issued_at = os.time(),
            presets = buildTicketPresetSnapshot(),
            shopping_list_only = shoppingListOnly,
            available_vendors = availableVendors,
            zone_id = tostring(zone and zone.id or ""),
            zone_name = tostring(zone and zone.name or ""),
        },
    }) or {
        class = TICKET_ITEM_CLASS,
        ticket_data = {
            number = math.max(1, math.floor(tonumber(ticketNumber) or 1)),
            vendor_name = traderName,
            vendor_sid64 = traderSID64,
            issued_at = os.time(),
            presets = buildTicketPresetSnapshot(),
            shopping_list_only = shoppingListOnly,
            available_vendors = availableVendors,
            zone_id = tostring(zone and zone.id or ""),
            zone_name = tostring(zone and zone.name or ""),
        },
    }
end

local function issueVendorTicket(source, target, options)
    options = istable(options) and options or {}

    if not IsValid(target) then
        return false, "invalid_target"
    end

    if playerHasInventoryTicket(target) then
        return false, "already_has_ticket"
    end

    local ticketNumber = getNextTicketNumber()
    local entry = buildVendorTicketEntry(source, ticketNumber, target)
    local deliveredToInventory = false
    local deliveredToMailbox = false
    local targetSID64 = normalizeSID64(target:SteamID64())
    local issuerName = getTicketIssuerInfo(source)
    local allowMailbox = options.allow_mailbox ~= false
    local ticketData = istable(entry) and entry.ticket_data or nil
    local shoppingListOnly = istable(ticketData) and ticketData.shopping_list_only == true
    local ticketLabel = shoppingListOnly and "shopping list ticket" or "vendor ticket"

    if ZSCAV.TryAddItemEntry and ZSCAV.IsActive and ZSCAV:IsActive() then
        deliveredToInventory = ZSCAV:TryAddItemEntry(target, entry) == true
    end

    if not deliveredToInventory and allowMailbox and isfunction(DeliverToPlayerMailbox) then
        deliveredToMailbox = select(1, DeliverToPlayerMailbox(targetSID64, {
            entries = { entry },
            source = issuerName,
            subject = shoppingListOnly and "Vendor Shopping List" or "Vendor Ticket",
            message = shoppingListOnly and "A vendor issued you a shopping-list ticket for the active player vendors in this safe zone." or "A vendor issued you a numbered ticket with the current preset sales list.",
            notify = false,
        })) == true
    end

    if not deliveredToInventory and not deliveredToMailbox then
        return false, allowMailbox and "delivery_failed" or "inventory_full"
    end

    lib.State.next_ticket_number = ticketNumber + 1
    saveState()

    Notice(target, string.format("%s issued you %s #%d%s.", issuerName, ticketLabel, ticketNumber, deliveredToMailbox and " to your mailbox" or ""))
    if IsValid(source) and source:IsPlayer() and source ~= target then
        Notice(source, string.format("Issued %s #%d to %s%s.", ticketLabel, ticketNumber, tostring(target:Nick() or "Player"), deliveredToMailbox and " (mailbox)" or ""))
    end

    return true
end

local function findPresetByID(presetID)
    presetID = tostring(presetID or "")
    if presetID == "" then return nil end

    for _, preset in ipairs(lib.State.presets or {}) do
        if tostring(preset.id or "") == presetID then
            return preset
        end
    end
end

local function getLastPresetRedemptionAt(presetID, playerSID64)
    presetID = tostring(presetID or "")
    playerSID64 = normalizeSID64(playerSID64)
    if presetID == "" or playerSID64 == "" then return 0 end

    local byPlayer = lib.State.redemptions and lib.State.redemptions[presetID] or nil
    return math.max(0, math.floor(tonumber(byPlayer and byPlayer[playerSID64]) or 0))
end

local function getPresetCooldownRemaining(presetOrID, playerSID64)
    local preset = istable(presetOrID) and presetOrID or findPresetByID(presetOrID)
    if not istable(preset) then return 0 end

    local cooldown = math.max(0, tonumber(preset.cooldown_seconds) or 0)
    if cooldown <= 0 then return 0 end

    local lastAt = getLastPresetRedemptionAt(tostring(preset.id or ""), playerSID64)
    if lastAt <= 0 then return 0 end

    return math.max(0, cooldown - math.max(0, os.time() - lastAt))
end

local function recordPresetRedemption(presetID, playerSID64)
    presetID = tostring(presetID or "")
    playerSID64 = normalizeSID64(playerSID64)
    if presetID == "" or playerSID64 == "" then return end

    lib.State.redemptions = lib.State.redemptions or {}
    lib.State.redemptions[presetID] = lib.State.redemptions[presetID] or {}
    lib.State.redemptions[presetID][playerSID64] = os.time()
    saveState()
end

local function countEntriesByClass(entries)
    local out = {}

    for _, entry in ipairs(entries or {}) do
        local class = tostring(entry.class or "")
        if class ~= "" then
            local count = math.max(1, math.floor(tonumber(entry.count) or 1))
            out[class] = (out[class] or 0) + count
        end
    end

    return out
end

local function buildRequirementMismatch(requiredItems, offerEntries)
    local missing = {}
    local extra = {}
    local requiredCounts = countEntriesByClass(requiredItems)
    local offerCounts = countEntriesByClass(offerEntries)

    for class, count in pairs(requiredCounts) do
        local have = offerCounts[class] or 0
        if have < count then
            missing[#missing + 1] = string.format("%dx %s", count - have, getTradeDisplayName(class))
        end
    end

    for class, count in pairs(offerCounts) do
        local need = requiredCounts[class] or 0
        if count > need then
            extra[#extra + 1] = string.format("%dx %s", count - need, getTradeDisplayName(class))
        end
    end

    table.sort(missing)
    table.sort(extra)

    if #missing <= 0 and #extra <= 0 then
        return nil
    end

    local parts = {}
    if #missing > 0 then
        parts[#parts + 1] = "missing " .. table.concat(missing, ", ")
    end
    if #extra > 0 then
        parts[#parts + 1] = "extra " .. table.concat(extra, ", ")
    end

    return table.concat(parts, "; ")
end

local function validateSessionOfferAgainstPreset(session)
    local requiredItems = istable(session) and session.required_player_items or nil
    if not istable(requiredItems) or #requiredItems <= 0 then
        return true
    end

    local mismatch = buildRequirementMismatch(requiredItems, getPlayerOfferEntries(session))
    if mismatch then
        return false, "Trade basket must match the preset exactly: " .. mismatch .. "."
    end

    return true
end

local function clearSessionPreset(session)
    if not istable(session) then return end

    session.active_preset_id = ""
    session.active_preset_name = ""
    session.required_player_items = {}
    session.preset_cooldown_seconds = 0
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if string.NiceTime then
        return string.NiceTime(seconds)
    end

    if seconds < 60 then
        return tostring(seconds) .. "s"
    end

    local minutes = math.floor(seconds / 60)
    local remain = seconds % 60
    if remain <= 0 then
        return tostring(minutes) .. "m"
    end

    return string.format("%dm %ds", minutes, remain)
end

local function buildSessionSnapshot(session)
    if not istable(session) then return nil end

    local trader = getPlayerBySID64(session.trader_sid64)
    local target = getPlayerBySID64(session.player_sid64)
    local offerOK, offerMessage = validateSessionOfferAgainstPreset(session)
    local activePresetID = tostring(session.active_preset_id or "")

    return {
        id = tostring(session.id or ""),
        trader_sid64 = tostring(session.trader_sid64 or ""),
        trader_name = IsValid(trader) and tostring(trader:Nick() or "") or getDisplayNameForSID64(session.trader_sid64),
        player_sid64 = tostring(session.player_sid64 or ""),
        player_name = IsValid(target) and tostring(target:Nick() or "") or getDisplayNameForSID64(session.player_sid64),
        player_ent_index = IsValid(target) and target:EntIndex() or -1,
        player_offer_uid = tostring(session.player_offer_uid or ""),
        player_offer_items = getPlayerOfferEntries(session),
        trader_items = getTraderOfferEntries(session),
        active_preset_id = activePresetID,
        active_preset_name = tostring(session.active_preset_name or ""),
        required_player_items = clonePresetItems(session.required_player_items or {}),
        preset_cooldown_seconds = math.max(0, tonumber(session.preset_cooldown_seconds) or 0),
        cooldown_remaining = getPresetCooldownRemaining(activePresetID, session.player_sid64),
        required_offer_ok = offerOK,
        required_offer_message = tostring(offerMessage or ""),
        player_ready = session.player_ready == true,
        created_at = tonumber(session.created_at) or os.time(),
    }
end

local function buildTerminalSnapshot(ply)
    local sid64 = normalizeSID64(IsValid(ply) and ply:SteamID64() or "")
    local activeSession = sid64 ~= "" and lib.Sessions[lib.SessionByTrader[sid64] or ""] or nil
    local terminal = getOpenTerminalFor(ply)
    local inSafeZone, zone = getPlayerSafeZoneContext(ply)
    local vendorStatus = getVendorStatusForPlayer(ply)
    local waitingCount = getWaitingTicketCount()

    local presets = {}
    for _, preset in ipairs(lib.State.presets or {}) do
        presets[#presets + 1] = table.Copy(preset)
    end

    return {
        can_manage = canManage(ply),
        can_use = canUse(ply),
        terminal_ent_index = IsValid(terminal) and terminal:EntIndex() or -1,
        nearby_players = getNearbyPlayersSnapshot(ply),
        presets = presets,
        active_session = buildSessionSnapshot(activeSession),
        in_safe_zone = inSafeZone,
        safe_zone_id = tostring(zone and zone.id or ""),
        safe_zone_name = tostring(zone and zone.name or ""),
        vendor_status_active = vendorStatus ~= nil,
        available_vendors = inSafeZone and getActiveVendorsForZone(zone and zone.id or "") or {},
        now_serving_number = getNowServingNumber(),
        next_ticket_number = getNextTicketNumber(),
        waiting_ticket_count = waitingCount,
        can_advance_now_serving = waitingCount > 0,
    }
end

local function syncTerminalState(ply, useOpenNet)
    if not IsValid(ply) then return end
    local payload = buildTerminalSnapshot(ply)
    sendJSON(useOpenNet and NET_OPEN or NET_STATE, ply, payload)
end

syncAllOpenTerminals = function()
    for ply in pairs(lib.TerminalByPlayer or {}) do
        if IsValid(ply) then
            syncTerminalState(ply, false)
        else
            lib.TerminalByPlayer[ply] = nil
        end
    end
end

local function syncPlayerTradeState(ply, session, closedReason)
    if not IsValid(ply) then return end

    if not istable(session) then
        sendJSON(NET_TRADE_STATE, ply, {
            closed = true,
            reason = tostring(closedReason or "closed"),
        })
        return
    end

    local snapshot = buildSessionSnapshot(session) or {}
    snapshot.closed = false
    sendJSON(NET_TRADE_STATE, ply, snapshot)
end

local function syncSession(session, reopenPlayerWindow)
    if not istable(session) then return end

    local trader = getPlayerBySID64(session.trader_sid64)
    local target = getPlayerBySID64(session.player_sid64)

    if IsValid(trader) then
        syncTerminalState(trader, false)
    end

    if IsValid(target) then
        syncPlayerTradeState(target, session)
        if reopenPlayerWindow then
            net.Start("ZScavInvOpen")
            net.Send(target)

            timer.Simple(0, function()
                if not IsValid(target) then return end
                local liveSession = lib.Sessions[tostring(session.id or "")]
                if not liveSession then return end

                target.zscav_container_chain = {
                    "trade_session:" .. tostring(liveSession.id or ""),
                    tostring(liveSession.player_offer_uid or ""),
                }

                local sendSnapshot = ZSCAV.ServerHelpers and ZSCAV.ServerHelpers.SendContainerSnapshotForUID or nil
                if isfunction(sendSnapshot) then
                    sendSnapshot(target, tostring(liveSession.player_offer_uid or ""))
                end
            end)
        end
    end
end

local function clearSessionIndexes(session)
    if not istable(session) then return end
    lib.SessionByTrader[tostring(session.trader_sid64 or "")] = nil
    lib.SessionByPlayer[tostring(session.player_sid64 or "")] = nil
    lib.SessionByOfferUID[tostring(session.player_offer_uid or "")] = nil
end

local function expandPresetItems(items)
    local out = {}

    for _, item in ipairs(items or {}) do
        local normalized = normalizePresetItem(item)
        if normalized then
            for _ = 1, normalized.count do
                local entry = buildTradeEntry(normalized.class)
                if entry then
                    out[#out + 1] = entry
                end
            end
        end
    end

    return out
end

local function addTradeItem(session, class, count)
    if not istable(session) then return false end
    count = math.Clamp(math.floor(tonumber(count) or 1), 1, 32)
    clearSessionPreset(session)

    for _ = 1, count do
        local entry = buildTradeEntry(class)
        if not entry then
            return false
        end
        session.trader_items[#session.trader_items + 1] = entry
    end

    session.player_ready = false
    syncSession(session, false)
    return true
end

local function setTraderItemsFromPreset(session, presetID)
    if not istable(session) then return false end

    local preset = findPresetByID(presetID)
    if not istable(preset) then return false, "missing" end

    local cooldownRemaining = getPresetCooldownRemaining(preset, session.player_sid64)
    if cooldownRemaining > 0 then
        return false, "cooldown", cooldownRemaining, preset
    end

    session.trader_items = expandPresetItems(preset.trader_items)
    session.active_preset_id = tostring(preset.id or "")
    session.active_preset_name = tostring(preset.name or "")
    session.required_player_items = clonePresetItems(preset.player_items)
    session.preset_cooldown_seconds = math.max(0, tonumber(preset.cooldown_seconds) or 0)
    session.player_ready = false
    syncSession(session, false)
    return true
end

local function getPresetReadyFailureMessage(session)
    local ok, reason = validateSessionOfferAgainstPreset(session)
    if ok then
        return nil
    end

    return reason
end

local function returnOfferItemsToPlayer(session, reason)
    if not istable(session) then return end

    local offerEntries = getPlayerOfferEntries(session)
    local target = getPlayerBySID64(session.player_sid64)
    local returnedToInventory = 0
    local mailed = 0

    for _, entry in ipairs(offerEntries) do
        local placed = false
        if IsValid(target) and ZSCAV.TryAddItemEntry and ZSCAV.IsActive and ZSCAV:IsActive() then
            local ok = ZSCAV:TryAddItemEntry(target, entry)
            if ok then
                returnedToInventory = returnedToInventory + 1
                placed = true
            end
        end

        if not placed and isfunction(DeliverToPlayerMailbox) then
            local ok = select(1, DeliverToPlayerMailbox(tostring(session.player_sid64 or ""), {
                entries = { entry },
                source = "Trader Terminal",
                subject = "Returned Trade Items",
                message = tostring(reason or "Trade session ended before completion."),
                notify = false,
            }))

            if ok then
                mailed = mailed + 1
                placed = true
            end
        end
    end

    if IsValid(target) then
        if returnedToInventory > 0 or mailed > 0 then
            Notice(target, string.format("Trade cancelled. Returned %d item%s and mailed %d.", returnedToInventory, returnedToInventory == 1 and "" or "s", mailed))
        else
            Notice(target, "Trade cancelled.")
        end
    end
end

local function deliverOfferItemsToTrader(session)
    local offerEntries = getPlayerOfferEntries(session)
    if #offerEntries <= 0 then return true end
    if not isfunction(DeliverToPlayerMailbox) then return false end

    return select(1, DeliverToPlayerMailbox(tostring(session.trader_sid64 or ""), {
        entries = offerEntries,
        source = getDisplayNameForSID64(session.player_sid64),
        subject = "Trade Payment",
        message = "Items received from a completed trader-terminal exchange.",
        notify = true,
    }))
end

local function deliverTraderItemsToPlayer(session)
    local target = getPlayerBySID64(session.player_sid64)
    local given = 0
    local mailed = 0

    for _, entry in ipairs(session.trader_items or {}) do
        local delivered = false

        if IsValid(target) and ZSCAV.TryAddItemEntry and ZSCAV.IsActive and ZSCAV:IsActive() then
            local ok = ZSCAV:TryAddItemEntry(target, entry)
            if ok then
                given = given + 1
                delivered = true
            end
        end

        if not delivered and isfunction(DeliverToPlayerMailbox) then
            local ok = select(1, DeliverToPlayerMailbox(tostring(session.player_sid64 or ""), {
                entries = { entry },
                source = getDisplayNameForSID64(session.trader_sid64),
                subject = "Trader Purchase",
                message = "Items purchased through a trader terminal were delivered to your mailbox.",
                notify = false,
            }))

            if ok then
                mailed = mailed + 1
                delivered = true
            end
        end

        if not delivered then
            return false, given, mailed
        end
    end

    return true, given, mailed
end

local function closeSessionUI(session, reason)
    local target = getPlayerBySID64(session.player_sid64)
    if IsValid(target) then
        target.zscav_container_chain = nil
        sendJSON(NET_TRADE_STATE, target, {
            closed = true,
            reason = tostring(reason or "closed"),
            player_offer_uid = tostring(session.player_offer_uid or ""),
        })
    end
end

local function removeOfferBag(session)
    local uid = tostring(session and session.player_offer_uid or "")
    if uid ~= "" then
        ZSCAV:DeleteBag(uid)
    end
end

local function endSession(session, reason, returnItems, suppressNotices)
    if not istable(session) then return end

    lib.Sessions[tostring(session.id or "")] = nil
    clearSessionIndexes(session)

    if returnItems then
        returnOfferItemsToPlayer(session, reason)
    end

    closeSessionUI(session, reason)
    removeOfferBag(session)

    local trader = getPlayerBySID64(session.trader_sid64)
    local target = getPlayerBySID64(session.player_sid64)
    if IsValid(trader) and not suppressNotices then
        Notice(trader, tostring(reason or "Trade ended."))
        syncTerminalState(trader, false)
    elseif IsValid(trader) then
        syncTerminalState(trader, false)
    end
    if IsValid(target) and not returnItems and not suppressNotices then
        Notice(target, tostring(reason or "Trade ended."))
    end
end

local function completeSession(session)
    if not istable(session) then return false end
    if session.player_ready ~= true then return false end
    if #(session.trader_items or {}) <= 0 then return false end

    local readyFailure = getPresetReadyFailureMessage(session)
    if readyFailure then
        return false, readyFailure
    end

    local trader = getPlayerBySID64(session.trader_sid64)
    local target = getPlayerBySID64(session.player_sid64)

    local paid = deliverOfferItemsToTrader(session)
    if not paid then
        if IsValid(trader) then
            Notice(trader, "Could not route trade payment to mailbox.")
        end
        return false
    end

    local ok, given, mailed = deliverTraderItemsToPlayer(session)
    if not ok then
        if IsValid(trader) then
            Notice(trader, "Could not deliver trader offer items.")
        end
        return false
    end

    if IsValid(trader) then
        Notice(trader, string.format("Trade completed for %s.", getDisplayNameForSID64(session.player_sid64)))
    end
    if IsValid(target) then
        Notice(target, string.format("Trade completed. Received %d item%s and mailed %d.", given, given == 1 and "" or "s", mailed))
    end

    if tostring(session.active_preset_id or "") ~= "" and math.max(0, tonumber(session.preset_cooldown_seconds) or 0) > 0 then
        recordPresetRedemption(session.active_preset_id, session.player_sid64)
    end

    endSession(session, "Trade completed.", false, true)
    return true
end

local function getSessionByTrader(ply)
    local sid64 = normalizeSID64(IsValid(ply) and ply:SteamID64() or "")
    return sid64 ~= "" and lib.Sessions[lib.SessionByTrader[sid64] or ""] or nil
end

local function getSessionByPlayer(ply)
    local sid64 = normalizeSID64(IsValid(ply) and ply:SteamID64() or "")
    return sid64 ~= "" and lib.Sessions[lib.SessionByPlayer[sid64] or ""] or nil
end

local function startSession(trader, target)
    if not (IsValid(trader) and IsValid(target)) then return false end
    if trader == target then return false end
    if not canUse(trader) then return false end
    if not (ZSCAV.IsActive and ZSCAV:IsActive()) then
        Notice(trader, "Trader sessions can only start while ZScav is active.")
        return false
    end
    if ZSCAV.CanPlayerUseInventory and not ZSCAV:CanPlayerUseInventory(target) then
        Notice(trader, tostring(target:Nick() or "Player") .. " cannot use inventory right now.")
        return false
    end

    local traderSID64 = normalizeSID64(trader:SteamID64())
    local targetSID64 = normalizeSID64(target:SteamID64())
    if traderSID64 == "" or targetSID64 == "" then return false end

    if lib.SessionByTrader[traderSID64] then
        local existing = lib.Sessions[lib.SessionByTrader[traderSID64]]
        if existing then
            endSession(existing, "Previous trade session closed.", true)
        end
    end

    if lib.SessionByPlayer[targetSID64] then
        Notice(trader, tostring(target:Nick() or "Player") .. " is already in a trader session.")
        return false
    end

    local offerUID = tostring(ZSCAV:CreateBag(OFFER_BAG_CLASS) or "")
    if offerUID == "" then
        Notice(trader, "Could not allocate a trade basket.")
        return false
    end

    if not ZSCAV:SaveBag(offerUID, OFFER_BAG_CLASS, {}) then
        Notice(trader, "Could not initialize a trade basket.")
        return false
    end

    local sessionID = string.format("trade_%d_%d", os.time(), math.random(1000, 9999))
    local session = {
        id = sessionID,
        trader_sid64 = traderSID64,
        player_sid64 = targetSID64,
        player_offer_uid = offerUID,
        trader_items = {},
        required_player_items = {},
        active_preset_id = "",
        active_preset_name = "",
        preset_cooldown_seconds = 0,
        player_ready = false,
        created_at = os.time(),
    }

    lib.Sessions[sessionID] = session
    lib.SessionByTrader[traderSID64] = sessionID
    lib.SessionByPlayer[targetSID64] = sessionID
    lib.SessionByOfferUID[offerUID] = sessionID

    Notice(target, string.format("%s opened a trade terminal with you.", tostring(trader:Nick() or "Trader")))
    syncSession(session, true)
    return true
end

local function setTraderAccess(targetSID64, enabled, byPly)
    targetSID64 = normalizeSID64(targetSID64)
    if targetSID64 == "" then return false end

    if enabled then
        lib.State.grants[targetSID64] = {
            granted = true,
            name = getDisplayNameForSID64(targetSID64),
            by_sid64 = normalizeSID64(IsValid(byPly) and byPly:SteamID64() or ""),
            by_name = IsValid(byPly) and tostring(byPly:Nick() or "") or "",
            at = os.time(),
        }
    else
        lib.State.grants[targetSID64] = nil
    end

    saveState()
    return true
end

local function savePreset(presetData)
    local normalized = normalizePreset(presetData)
    if not normalized then return false end

    if normalized.id == "" then
        normalized.id = string.format("preset_%d_%d", os.time(), math.random(1000, 9999))
    end

    local replaced = false
    for index, preset in ipairs(lib.State.presets or {}) do
        if tostring(preset.id or "") == normalized.id then
            lib.State.presets[index] = normalized
            replaced = true
            break
        end
    end

    if not replaced then
        lib.State.presets[#lib.State.presets + 1] = normalized
    end

    table.sort(lib.State.presets, function(left, right)
        return string.lower(left.name or "") < string.lower(right.name or "")
    end)
    saveState()
    return true
end

local function deletePreset(presetID)
    presetID = tostring(presetID or "")
    if presetID == "" then return false end

    for index, preset in ipairs(lib.State.presets or {}) do
        if tostring(preset.id or "") == presetID then
            table.remove(lib.State.presets, index)
            if lib.State.redemptions then
                lib.State.redemptions[presetID] = nil
            end
            saveState()
            return true
        end
    end

    return false
end

local function openTerminalForPlayer(ply, terminal)
    if not IsValid(ply) then return end
    if not canUse(ply) then
        Notice(ply, "You are not appointed to use this trader terminal.")
        return
    end

    lib.TerminalByPlayer[ply] = IsValid(terminal) and terminal or nil
    syncTerminalState(ply, true)
end

function lib:HandleTerminalUse(terminal, ply)
    openTerminalForPlayer(ply, terminal)
end

function lib:HandleTicketMachineUse(machine, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not (ZSCAV and ZSCAV.IsActive and ZSCAV:IsActive()) then
        Notice(ply, "Ticket machines only work during ZScav.")
        return
    end
    if ZSCAV.CanPlayerUseInventory and not ZSCAV:CanPlayerUseInventory(ply) then
        Notice(ply, "You cannot take a ticket right now.")
        return
    end

    local ok, reason = issueVendorTicket(machine, ply, {
        allow_mailbox = false,
    })

    if ok then
        if syncAllOpenTerminals then
            syncAllOpenTerminals()
        end
        return
    end

    if reason == "already_has_ticket" then
        Notice(ply, "You already have a vendor ticket in your inventory.")
        return
    end
    if reason == "inventory_full" then
        Notice(ply, "No room in inventory for a vendor ticket.")
        return
    end

    Notice(ply, "Could not dispense a vendor ticket.")
end

hook.Add("Think", "ZSCAV_TraderTerminalVendorStatusSweep", function()
    lib._nextVendorStatusSweep = lib._nextVendorStatusSweep or 0
    if lib._nextVendorStatusSweep > CurTime() then return end
    lib._nextVendorStatusSweep = CurTime() + 1

    local changed = false

    for sid64, row in pairs(lib.ActiveVendors or {}) do
        local ply = getPlayerBySID64(sid64)
        local inSafeZone, zone = getPlayerSafeZoneContext(ply)
        if not IsValid(ply) or not canUse(ply) or not inSafeZone or not istable(zone) or tostring(zone.id or "") ~= tostring(row.zone_id or "") then
            lib.ActiveVendors[sid64] = nil
            changed = true
        else
            row.name = tostring(ply:Nick() or row.name or sid64)
            row.zone_name = tostring(zone.name or row.zone_name or "")
        end
    end

    if changed and syncAllOpenTerminals then
        syncAllOpenTerminals()
    end
end)

loadState()

if not lib._saveBagWrapped then
    local originalSaveBag = ZSCAV.SaveBag
    ZSCAV.SaveBag = function(self, uid, class, contents)
        local ok = originalSaveBag(self, uid, class, contents)
        if ok then
            local sessionID = lib.SessionByOfferUID[tostring(uid or "")]
            local session = sessionID and lib.Sessions[sessionID] or nil
            if session then
                session.player_ready = false
                timer.Simple(0, function()
                    local live = lib.Sessions[tostring(session.id or "")]
                    if live then
                        syncSession(live, false)
                    end
                end)
            end
        end
        return ok
    end
    lib._saveBagWrapped = true
end

hook.Add("PlayerDisconnected", "ZSCAV_TraderTerminalDisconnect", function(ply)
    lib.TerminalByPlayer[ply] = nil
    local clearedVendor = clearVendorStatusBySID64(IsValid(ply) and ply:SteamID64() or "")

    local session = getSessionByTrader(ply) or getSessionByPlayer(ply)
    if session then
        endSession(session, tostring(ply:Nick() or "Player") .. " disconnected.", true)
    end

    if clearedVendor and syncAllOpenTerminals then
        syncAllOpenTerminals()
    end
end)

hook.Add("PlayerDeath", "ZSCAV_TraderTerminalCancelOnDeath", function(ply)
    local session = getSessionByTrader(ply) or getSessionByPlayer(ply)
    if session then
        endSession(session, tostring(ply:Nick() or "Player") .. " died.", true)
    end
end)

net.Receive(NET_ACTION, function(_, ply)
    if not IsValid(ply) or not canUse(ply) then return end

    local action = tostring(net.ReadString() or "")
    local args = net.ReadTable() or {}
    local session = getSessionByTrader(ply)

    if action == "refresh" then
        syncTerminalState(ply, false)
        return
    end

    if action == "advance_now_serving" then
        local advanced, current = advanceNowServingNumber()
        if advanced then
            Notice(ply, string.format("Now serving #%d.", current))
        elseif getHighestIssuedTicketNumber() <= 0 then
            Notice(ply, "No tickets have been printed yet.")
        else
            Notice(ply, "No newer printed tickets are waiting.")
        end

        if syncAllOpenTerminals then
            syncAllOpenTerminals()
        else
            syncTerminalState(ply, false)
        end
        return
    end

    if action == "set_vendor_status" then
        local ok, reason = setVendorStatusActive(ply)
        if not ok then
            if reason == "safe_zone_required" then
                Notice(ply, "Vendor status can only be enabled inside a safe zone.")
            else
                Notice(ply, "Could not enable vendor status.")
            end
        else
            Notice(ply, "Vendor status enabled. It will stay active until you disconnect or leave the safe zone.")
            syncTerminalState(ply, false)
            if syncAllOpenTerminals then
                syncAllOpenTerminals()
            end
        end
        return
    end

    if action == "grant_access" then
        if not canManage(ply) then return end
        if setTraderAccess(args.target_sid64, true, ply) then
            syncTerminalState(ply, false)
        end
        return
    end

    if action == "revoke_access" then
        if not canManage(ply) then return end
        if setTraderAccess(args.target_sid64, false, ply) then
            syncTerminalState(ply, false)
        end
        return
    end

    if action == "start_session" then
        local target = getPlayerBySID64(args.target_sid64)
        if IsValid(target) then
            startSession(ply, target)
        end
        return
    end

    if action == "issue_ticket" then
        local target = getPlayerBySID64(args.target_sid64)
        if not IsValid(target) and session then
            target = getPlayerBySID64(session.player_sid64)
        end

        if not IsValid(target) then
            Notice(ply, "Select a player or use an active session first.")
            return
        end

        local ok, reason = issueVendorTicket(ply, target)
        if not ok then
            if reason == "already_has_ticket" then
                Notice(ply, tostring(target:Nick() or "Player") .. " already has a vendor ticket in inventory.")
            elseif reason == "inventory_full" then
                Notice(ply, "No room in that player's inventory for a vendor ticket.")
            elseif reason == "delivery_failed" then
                Notice(ply, "Could not deliver the vendor ticket to that player.")
            else
                Notice(ply, "Could not issue a vendor ticket.")
            end
        elseif syncAllOpenTerminals then
            syncAllOpenTerminals()
        else
            syncTerminalState(ply, false)
        end
        return
    end

    if action == "cancel_session" then
        if session then
            endSession(session, "Trader cancelled the session.", true)
        end
        return
    end

    if action == "save_preset" then
        if not canManage(ply) then return end
        if savePreset(args.preset or {}) then
            syncTerminalState(ply, false)
        else
            Notice(ply, "Could not save preset.")
        end
        return
    end

    if action == "delete_preset" then
        if not canManage(ply) then return end
        if deletePreset(args.preset_id) then
            syncTerminalState(ply, false)
        end
        return
    end

    if not session then return end

    if action == "add_offer_item" then
        local class = tostring(args.class or "")
        local count = tonumber(args.count) or 1
        if not addTradeItem(session, class, count) then
            Notice(ply, "Could not add that catalog item.")
        end
        return
    end

    if action == "remove_offer_index" then
        local index = tonumber(args.index)
        if not index then return end
        if session.trader_items[index] then
            table.remove(session.trader_items, index)
            clearSessionPreset(session)
            session.player_ready = false
            syncSession(session, false)
        end
        return
    end

    if action == "clear_offer" then
        session.trader_items = {}
        clearSessionPreset(session)
        session.player_ready = false
        syncSession(session, false)
        return
    end

    if action == "apply_preset" then
        local ok, reason, cooldownRemaining, preset = setTraderItemsFromPreset(session, args.preset_id)
        if not ok then
            if reason == "cooldown" then
                Notice(ply, string.format("%s can trade for %s again in %s.", getDisplayNameForSID64(session.player_sid64), tostring(preset and preset.name or "that preset"), formatDuration(cooldownRemaining)))
            else
                Notice(ply, "Preset not found.")
            end
        end
        return
    end

    if action == "complete_trade" then
        local ok, reason = completeSession(session)
        if not ok then
            Notice(ply, tostring(reason or "Trade is not ready to complete."))
        end
        return
    end
end)

net.Receive(NET_TRADE_ACTION, function(_, ply)
    if not IsValid(ply) then return end

    local action = tostring(net.ReadString() or "")
    local args = net.ReadTable() or {}
    local session = getSessionByPlayer(ply)
    if not session then return end

    if action == "refresh" then
        syncSession(session, true)
        return
    end

    if action == "cancel" then
        endSession(session, "Player cancelled the session.", true)
        return
    end

    if action == "ready" then
        local readyFailure = getPresetReadyFailureMessage(session)
        if readyFailure then
            session.player_ready = false
            Notice(ply, readyFailure)
            syncSession(session, false)
            return
        end
        session.player_ready = true
        syncSession(session, false)
        return
    end

    if action == "unready" then
        session.player_ready = false
        syncSession(session, false)
        return
    end

    if action == "set_ready" then
        if args.ready == true then
            local readyFailure = getPresetReadyFailureMessage(session)
            if readyFailure then
                session.player_ready = false
                Notice(ply, readyFailure)
                syncSession(session, false)
                return
            end
        end
        session.player_ready = args.ready == true
        syncSession(session, false)
        return
    end
end)

concommand.Add("zscav_trader_terminal", function(ply)
    if not IsValid(ply) then return end
    openTerminalForPlayer(ply, getOpenTerminalFor(ply))
end)

concommand.Add("zscav_trader_grant", function(ply, _, args)
    if IsValid(ply) and not canManage(ply) then return end
    local target = getPlayerBySID64(args[1]) or player.GetBySteamID64 and player.GetBySteamID64(args[1]) or nil
    local sid64 = IsValid(target) and normalizeSID64(target:SteamID64()) or normalizeSID64(args[1])
    if sid64 == "" then return end
    setTraderAccess(sid64, true, ply)
end)

concommand.Add("zscav_trader_revoke", function(ply, _, args)
    if IsValid(ply) and not canManage(ply) then return end
    local sid64 = normalizeSID64(args[1])
    if sid64 == "" then return end
    setTraderAccess(sid64, false, ply)
end)