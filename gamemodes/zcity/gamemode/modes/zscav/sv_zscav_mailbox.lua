-- ZScav mailbox persistence and delivery helpers.

ZSCAV = ZSCAV or {}

local ZScavServerHelpers = ZSCAV.ServerHelpers or {}
ZSCAV.ServerHelpers = ZScavServerHelpers

local MAILBOX_TABLE = "zscav_player_mailbox"
local MAILBOX_CLASS = "zscav_mailbox_container"
local MAILBOX_MAX_RECENT = 24

local Notice = ZScavServerHelpers.Notice
local findFreeSpotAR = ZScavServerHelpers.findFreeSpotAR
local CopyItemEntry = ZScavServerHelpers.CopyItemEntry

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

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS zscav_player_mailbox (
    owner_sid64 TEXT PRIMARY KEY,
    uid         TEXT NOT NULL DEFAULT '',
    unread      INTEGER NOT NULL DEFAULT 0,
    deliveries  TEXT NOT NULL DEFAULT '[]',
    updated     INTEGER NOT NULL DEFAULT 0
)
]]

local function EnsureMailboxSchema()
    if sql.TableExists(MAILBOX_TABLE) then return true end

    local ok = sql.Query(SCHEMA)
    if ok == false then
        ErrorNoHalt("[ZScav] Failed to create sqlite zscav_player_mailbox table: " .. tostring(sql.LastError()) .. "\n")
        return false
    end

    return true
end

local function NormalizeOwnerSID64(ownerSID64)
    ownerSID64 = tostring(ownerSID64 or "")
    if ownerSID64 == "" then return "" end
    if not string.match(ownerSID64, "^%d+$") then return "" end
    return ownerSID64
end

local function NormalizeDeliveries(deliveries)
    local out = {}

    for _, delivery in ipairs(deliveries or {}) do
        if istable(delivery) then
            out[#out + 1] = {
                id = tostring(delivery.id or util.CRC(string.format("%s:%s:%s", os.time(), delivery.subject or "", #out + 1))),
                source = tostring(delivery.source or "System"),
                subject = tostring(delivery.subject or "Delivery"),
                message = tostring(delivery.message or ""),
                item_count = math.max(tonumber(delivery.item_count) or 0, 0),
                created_at = tonumber(delivery.created_at) or os.time(),
            }
        end
    end

    while #out > MAILBOX_MAX_RECENT do
        table.remove(out, 1)
    end

    return out
end

local function CopyMailboxState(state)
    return {
        owner_sid64 = tostring(state and state.owner_sid64 or ""),
        uid = tostring(state and state.uid or ""),
        unread = math.max(tonumber(state and state.unread) or 0, 0),
        deliveries = table.Copy(state and state.deliveries or {}),
        updated = tonumber(state and state.updated) or os.time(),
    }
end

local function GetPlayerMailboxRow(ownerSID64)
    if ownerSID64 == "" or not EnsureMailboxSchema() then return nil end

    return sql.QueryRow(
        "SELECT * FROM " .. MAILBOX_TABLE .. " WHERE owner_sid64 = " .. SQLStr(ownerSID64)
    )
end

function ZSCAV:GetPlayerMailboxState(ownerSID64, createIfMissing)
    ownerSID64 = NormalizeOwnerSID64(ownerSID64)
    if ownerSID64 == "" then return nil end

    local row = GetPlayerMailboxRow(ownerSID64)
    if row then
        return CopyMailboxState({
            owner_sid64 = ownerSID64,
            uid = row.uid,
            unread = row.unread,
            deliveries = NormalizeDeliveries(util.JSONToTable(row.deliveries or "[]") or {}),
            updated = row.updated,
        })
    end

    if not createIfMissing then return nil end

    local state = {
        owner_sid64 = ownerSID64,
        uid = "",
        unread = 0,
        deliveries = {},
        updated = os.time(),
    }

    self:SavePlayerMailboxState(state)
    return CopyMailboxState(state)
end

function ZSCAV:SavePlayerMailboxState(state)
    if not istable(state) or not EnsureMailboxSchema() then return false end

    local ownerSID64 = NormalizeOwnerSID64(state.owner_sid64)
    if ownerSID64 == "" then return false end

    local unread = math.max(tonumber(state.unread) or 0, 0)
    local uid = tostring(state.uid or "")
    local deliveries = NormalizeDeliveries(state.deliveries or {})
    local updated = tonumber(state.updated) or os.time()
    local payload = util.TableToJSON(deliveries, false) or "[]"

    local q = string.format(
        "INSERT OR REPLACE INTO %s (owner_sid64, uid, unread, deliveries, updated) VALUES (%s, %s, %d, %s, %d)",
        MAILBOX_TABLE,
        SQLStr(ownerSID64),
        SQLStr(uid),
        unread,
        SQLStr(payload),
        updated
    )

    local ok = sql.Query(q)
    if ok == false then
        ErrorNoHalt("[ZScav] SavePlayerMailboxState failed: " .. tostring(sql.LastError()) .. "\n")
        return false
    end

    return true
end

function ZSCAV:GetCanonicalPlayerMailboxUID(ownerSID64, createIfMissing)
    ownerSID64 = NormalizeOwnerSID64(ownerSID64)
    if ownerSID64 == "" then return nil end

    local state = self:GetPlayerMailboxState(ownerSID64, createIfMissing)
    if not state then return nil end

    local uid = tostring(state.uid or "")
    if uid ~= "" then
        if not self:LoadBag(uid) then
            self:SaveBag(uid, MAILBOX_CLASS, {})
        end
        return uid
    end

    if not createIfMissing then return nil end

    uid = tostring(self:CreateBag(MAILBOX_CLASS) or "")
    if uid == "" then return nil end

    if not self:SaveBag(uid, MAILBOX_CLASS, {}) then
        return nil
    end

    state.uid = uid
    state.updated = os.time()
    if not self:SavePlayerMailboxState(state) then
        return nil
    end

    return uid
end

function ZSCAV:IsPlayerMailboxUID(ownerOrSID64, uid)
    uid = tostring(uid or "")
    if uid == "" then return false end

    local ownerSID64 = ownerOrSID64
    if IsValid(ownerOrSID64) then
        ownerSID64 = ownerOrSID64:SteamID64()
    end

    ownerSID64 = NormalizeOwnerSID64(ownerSID64)
    if ownerSID64 == "" then return false end

    return tostring(self:GetCanonicalPlayerMailboxUID(ownerSID64, false) or "") == uid
end

function ZSCAV:GetPlayerMailboxUnread(ownerSID64)
    local state = self:GetPlayerMailboxState(ownerSID64, false)
    return math.max(tonumber(state and state.unread) or 0, 0)
end

function ZSCAV:MarkPlayerMailboxRead(ownerSID64)
    ownerSID64 = NormalizeOwnerSID64(ownerSID64)
    if ownerSID64 == "" then return false end

    local state = self:GetPlayerMailboxState(ownerSID64, false)
    if not state then return false end
    if math.max(tonumber(state.unread) or 0, 0) <= 0 then return true end

    state.unread = 0
    state.updated = os.time()
    if not self:SavePlayerMailboxState(state) then return false end

    local recipient = player.GetBySteamID64 and player.GetBySteamID64(ownerSID64) or nil
    if IsValid(recipient) then
        recipient:SetNWInt("ZScavMailboxUnread", 0)
    end

    return true
end

function ZSCAV:CanAccessMailbox(ply)
    return IsValid(ply)
        and ply:IsPlayer()
        and ply:GetNWBool("ZCityInSafeZone", false)
end

local function NormalizeMailboxEntry(entry)
    local out = CopyItemEntry(entry)
    if not out or not out.class then return nil end

    local size = ZSCAV:GetItemSize(out) or { w = out.w or 1, h = out.h or 1 }
    out.w = math.max(tonumber(out.w) or tonumber(size.w) or 1, 1)
    out.h = math.max(tonumber(out.h) or tonumber(size.h) or 1, 1)
    out.x = nil
    out.y = nil
    out.slot = nil
    return out
end

local function NormalizeDeliveryRecord(delivery, itemCount)
    return {
        id = util.CRC(string.format("%s:%s:%s:%s", os.time(), delivery.subject or "Delivery", delivery.source or "System", itemCount or 0)),
        source = tostring(delivery.source or "System"),
        subject = tostring(delivery.subject or "Delivery"),
        message = tostring(delivery.message or ""),
        item_count = math.max(tonumber(itemCount) or 0, 0),
        created_at = os.time(),
    }
end

local function SyncMailboxUnread(ply)
    if not IsValid(ply) then return end
    ply:SetNWInt("ZScavMailboxUnread", ZSCAV:GetPlayerMailboxUnread(ply:SteamID64()))
end

function ZSCAV:DeliverToPlayerMailbox(ownerSID64, delivery)
    ownerSID64 = NormalizeOwnerSID64(ownerSID64)
    if ownerSID64 == "" or not istable(delivery) then
        return false, 0, "invalid_delivery"
    end

    local uid = tostring(self:GetCanonicalPlayerMailboxUID(ownerSID64, true) or "")
    if uid == "" then
        return false, 0, "mailbox_missing"
    end

    local bag = self:LoadBag(uid) or {
        uid = uid,
        class = MAILBOX_CLASS,
        contents = {},
    }

    bag.class = MAILBOX_CLASS
    bag.contents = bag.contents or {}

    local inputEntries = delivery.entries or delivery.items
    if not istable(inputEntries) then
        inputEntries = istable(delivery.item) and { delivery.item } or {}
    end

    local entries = {}
    for _, entry in ipairs(inputEntries) do
        local normalized = NormalizeMailboxEntry(entry)
        if normalized then
            entries[#entries + 1] = normalized
        end
    end

    local gw, gh = ZSCAV:GetContainerGridSize(MAILBOX_CLASS)
    local def = ZSCAV:GetGearDef(MAILBOX_CLASS) or {}
    local internal = def.internal or {}
    gw = tonumber(gw) or tonumber(internal.w) or 10
    gh = tonumber(gh) or tonumber(internal.h) or 64

    for _, entry in ipairs(entries) do
        if not isfunction(findFreeSpotAR) then
            return false, 0, "layout_helper_missing"
        end

        local x, y, rotated = findFreeSpotAR(bag.contents, gw, gh, entry.w, entry.h)
        if not x then
            return false, 0, "mailbox_full"
        end

        bag.contents[#bag.contents + 1] = CopyItemEntry(entry, {
            x = x,
            y = y,
            w = rotated and entry.h or entry.w,
            h = rotated and entry.w or entry.h,
            slot = nil,
        })
    end

    if not self:SaveBag(uid, MAILBOX_CLASS, bag.contents) then
        return false, 0, "save_failed"
    end

    local count = #entries
    if count > 0 then
        local state = self:GetPlayerMailboxState(ownerSID64, true) or {
            owner_sid64 = ownerSID64,
            uid = uid,
            unread = 0,
            deliveries = {},
            updated = os.time(),
        }

        state.uid = uid
        state.unread = math.max(tonumber(state.unread) or 0, 0) + 1
        state.deliveries = NormalizeDeliveries(state.deliveries or {})
        state.deliveries[#state.deliveries + 1] = NormalizeDeliveryRecord(delivery, count)
        state.updated = os.time()
        self:SavePlayerMailboxState(state)
    end

    local recipient = player.GetBySteamID64 and player.GetBySteamID64(ownerSID64) or nil
    if IsValid(recipient) then
        SyncMailboxUnread(recipient)
        if delivery.notify ~= false and count > 0 and isfunction(Notice) then
            Notice(recipient, string.format("Mailbox received %d item%s.", count, count == 1 and "" or "s"))
        end
    end

    return true, count, nil
end

hook.Add("PlayerInitialSpawn", "ZSCAV_MailboxSyncUnread", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        SyncMailboxUnread(ply)
    end)
end)

hook.Add("PlayerSpawn", "ZSCAV_MailboxRefreshUnread", function(ply)
    if not IsValid(ply) then return end
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        SyncMailboxUnread(ply)
    end)
end)

ZScavServerHelpers.MAILBOX_CLASS = MAILBOX_CLASS
ZScavServerHelpers.GetCanonicalPlayerMailboxUID = function(ownerSID64, createIfMissing)
    return ZSCAV:GetCanonicalPlayerMailboxUID(ownerSID64, createIfMissing)
end
ZScavServerHelpers.IsPlayerMailboxUID = function(ownerOrSID64, uid)
    return ZSCAV:IsPlayerMailboxUID(ownerOrSID64, uid)
end
ZScavServerHelpers.GetPlayerMailboxUnread = function(ownerSID64)
    return ZSCAV:GetPlayerMailboxUnread(ownerSID64)
end
ZScavServerHelpers.MarkPlayerMailboxRead = function(ownerSID64)
    return ZSCAV:MarkPlayerMailboxRead(ownerSID64)
end
ZScavServerHelpers.CanAccessMailbox = function(ply)
    return ZSCAV:CanAccessMailbox(ply)
end
ZScavServerHelpers.DeliverToPlayerMailbox = function(ownerSID64, delivery)
    return ZSCAV:DeliverToPlayerMailbox(ownerSID64, delivery)
end
ZScavServerHelpers.SyncMailboxUnread = SyncMailboxUnread