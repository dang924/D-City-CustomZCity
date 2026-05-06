-- ZScav bag persistence layer.
--
-- Each backpack-class entity carries a UID. Its grid contents are stored
-- in SQLite (gmod's local sql.* — sv.db) keyed by UID. The same rows are
-- mirrored to MySQL (hg.MySQL) when available so they can be inspected in
-- the same external SQL backend used by ZBattle.
--
-- Bag contents survive while rooted by a live player/world/corpse container
-- or a persistent stash/secure row. Non-persistent rows are purged on
-- disconnect, cleanup, and shutdown.
--
-- Data layout:
--   zscav_bags(uid TEXT PK, class TEXT, contents TEXT, updated INTEGER)
-- contents JSON = array of item entries. We persist grid placement
-- metadata (x/y/w/h/rotated), originating slot metadata when present,
-- and nested uid/weapon runtime fields.

ZSCAV = ZSCAV or {}

local BAG_TABLE = "zscav_bags"
local BAG_MYSQL_READY = false
local BAG_MYSQL_INIT_TIMER = "ZSCAV_BagsMySQL_InitRetry"
local BAG_MYSQL_BACKFILL_DONE = false
local BAG_MYSQL_READY_ANNOUNCED = false
local BAG_PENDING_CREATES = {}
local BAG_PENDING_CREATE_FLUSH_QUEUED = false
local BAG_CACHE = {}

local BAG_MYSQL_MIRROR_CVAR = CreateConVar(
    "zscav_mysql_runtime_mirror",
    "0",
    FCVAR_ARCHIVE,
    "Mirror live ZScav bag and stash rows to the external MySQL bridge. Disabled by default so runtime persistence stays on sv.db only."
)

local BackfillBagsToMySQL
local ProbeBagMySQLReady
local RunBagMySQLQuery
local EscapeBagMySQLValue
local MirrorSaveBagToMySQL
local FlushPendingBagCreatesNow
local SchedulePendingBagCreateFlush

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS zscav_bags (
    uid     TEXT PRIMARY KEY,
    class   TEXT NOT NULL,
    contents TEXT NOT NULL DEFAULT '[]',
    updated INTEGER NOT NULL DEFAULT 0
)
]]

local MYSQL_SCHEMA = [[
CREATE TABLE IF NOT EXISTS zscav_bags (
    uid      VARCHAR(128) NOT NULL PRIMARY KEY,
    class    VARCHAR(128) NOT NULL,
    contents LONGTEXT     NOT NULL,
    updated  BIGINT       NOT NULL DEFAULT 0,
    INDEX idx_updated (updated)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

local function GetBagMySQLHandle()
    if hg and istable(hg.MySQL) and isfunction(hg.MySQL.query) and isfunction(hg.MySQL.EscapeStr) then
        return hg.MySQL, "hg.MySQL", "wrapped"
    end

    if hg and istable(hg.mysql) and isfunction(hg.mysql.RawQuery) and isfunction(hg.mysql.Escape) then
        return hg.mysql, "hg.mysql", "raw"
    end

    if istable(mysql) and isfunction(mysql.RawQuery) and isfunction(mysql.Escape) then
        return mysql, "mysql", "raw"
    end

    return nil, "none", nil
end

local function IsBagMySQLMirrorEnabled()
    return BAG_MYSQL_MIRROR_CVAR ~= nil and BAG_MYSQL_MIRROR_CVAR:GetBool()
end

local function GetCurrentDBModuleName()
    local handle = GetBagMySQLHandle()
    if handle and isstring(handle.module) then
        return tostring(handle.module)
    end

    if istable(mysql) and isstring(mysql.module) then
        return tostring(mysql.module)
    end

    return ""
end

local function IsBagMySQLConnected()
    if hg and istable(hg.MySQL) and isfunction(hg.MySQL.IsConnected) then
        local ok, connected = pcall(hg.MySQL.IsConnected, hg.MySQL)
        if ok then return connected == true end
    end

    if istable(mysql) and isfunction(mysql.IsConnected) then
        local ok, connected = pcall(mysql.IsConnected, mysql)
        if ok then return connected == true end
    end

    if hg and istable(hg.mysql) and isfunction(hg.mysql.IsConnected) then
        local ok, connected = pcall(hg.mysql.IsConnected, hg.mysql)
        if ok then return connected == true end
    end

    return false
end

local function IsBagMySQLUsable()
    local handle = GetBagMySQLHandle()
    return IsBagMySQLMirrorEnabled()
        and GetCurrentDBModuleName() == "mysqloo"
        and handle ~= nil
        and IsBagMySQLConnected()
end

RunBagMySQLQuery = function(query, callback)
    local handle, _, mode = GetBagMySQLHandle()
    if not handle or not IsBagMySQLUsable() then
        if isfunction(callback) then
            callback(nil, false, nil, "MySQL handle unavailable")
        end
        return nil
    end

    if mode == "wrapped" then
        return handle.query(query, callback)
    end

    return handle:RawQuery(query, callback)
end

EscapeBagMySQLValue = function(value)
    local handle, _, mode = GetBagMySQLHandle()
    local text = tostring(value or "")

    if handle then
        if mode == "wrapped" and isfunction(handle.EscapeStr) then
            return handle.EscapeStr(text)
        end

        if mode == "raw" and isfunction(handle.Escape) then
            local ok, escaped = pcall(handle.Escape, handle, text)
            if ok then
                return "'" .. tostring(escaped or "") .. "'"
            end
        end
    end

    return SQLStr(text)
end

local function EnsureSchema()
    if sql.TableExists(BAG_TABLE) then return end
    local ok = sql.Query(SCHEMA)
    if ok == false then
        ErrorNoHalt("[ZScav] Failed to create sqlite zscav_bags table: " .. tostring(sql.LastError()) .. "\n")
    end
end

local function WriteBagRowToSQLite(uid, class, payload, updated)
    local q = string.format(
        "INSERT OR REPLACE INTO %s (uid, class, contents, updated) VALUES (%s, %s, %s, %d)",
        BAG_TABLE,
        SQLStr(uid),
        SQLStr(class or ""),
        SQLStr(payload or "[]"),
        tonumber(updated) or os.time()
    )

    local ok = sql.Query(q)
    if ok == false then
        ErrorNoHalt("[ZScav] SaveBag failed: " .. tostring(sql.LastError()) .. "\n")
        return false
    end

    return true
end

FlushPendingBagCreatesNow = function()
    BAG_PENDING_CREATE_FLUSH_QUEUED = false

    local hadFailures = false
    for uid, pending in pairs(BAG_PENDING_CREATES) do
        BAG_PENDING_CREATES[uid] = nil

        local class = tostring(pending and pending.class or "")
        local updated = tonumber(pending and pending.updated) or os.time()
        if WriteBagRowToSQLite(uid, class, "[]", updated) then
            MirrorSaveBagToMySQL(uid, class, "[]", updated)
        else
            BAG_PENDING_CREATES[uid] = pending
            hadFailures = true
        end
    end

    if hadFailures and next(BAG_PENDING_CREATES) ~= nil then
        timer.Simple(1, function()
            if next(BAG_PENDING_CREATES) ~= nil then
                SchedulePendingBagCreateFlush()
            end
        end)
    end
end

SchedulePendingBagCreateFlush = function()
    if BAG_PENDING_CREATE_FLUSH_QUEUED then return end
    BAG_PENDING_CREATE_FLUSH_QUEUED = true

    timer.Simple(0, function()
        if next(BAG_PENDING_CREATES) == nil then
            BAG_PENDING_CREATE_FLUSH_QUEUED = false
            return
        end

        FlushPendingBagCreatesNow()
    end)
end

local function EnsureMySQLSchema()
    if BAG_MYSQL_READY then return end
    if not IsBagMySQLUsable() then return end

    RunBagMySQLQuery(MYSQL_SCHEMA, function(_, success)
        if success == false then return end
        if ProbeBagMySQLReady then
            timer.Simple(0, ProbeBagMySQLReady)
        end
    end)

    if ProbeBagMySQLReady then
        timer.Simple(0.25, ProbeBagMySQLReady)
    end
end

MirrorSaveBagToMySQL = function(uid, class, payload, updated)
    if not BAG_MYSQL_READY or not IsBagMySQLUsable() then return end

    local q = string.format(
        "INSERT INTO %s (uid, class, contents, updated) VALUES (%s, %s, %s, %d) " ..
        "ON DUPLICATE KEY UPDATE class = VALUES(class), contents = VALUES(contents), updated = VALUES(updated)",
        BAG_TABLE,
        EscapeBagMySQLValue(uid),
        EscapeBagMySQLValue(class or ""),
        EscapeBagMySQLValue(payload or "[]"),
        tonumber(updated) or os.time()
    )

    RunBagMySQLQuery(q, function() end)
end

local function MirrorDeleteBagFromMySQL(uid)
    if not BAG_MYSQL_READY or not IsBagMySQLUsable() then return end
    if not uid or uid == "" then return end

    local q = string.format(
        "DELETE FROM %s WHERE uid = %s",
        BAG_TABLE,
        EscapeBagMySQLValue(uid)
    )
    RunBagMySQLQuery(q, function() end)
end

BackfillBagsToMySQL = function()
    if BAG_MYSQL_BACKFILL_DONE then return end
    if not BAG_MYSQL_READY or not IsBagMySQLUsable() then return end

    BAG_MYSQL_BACKFILL_DONE = true

    local rows = sql.Query("SELECT uid, class, contents, updated FROM " .. BAG_TABLE) or {}
    local mirrored = 0

    for _, row in ipairs(rows) do
        local uid = tostring(row.uid or "")
        if uid ~= "" then
            MirrorSaveBagToMySQL(uid, tostring(row.class or ""), tostring(row.contents or "[]"), tonumber(row.updated) or os.time())
            mirrored = mirrored + 1
        end
    end

    if mirrored > 0 then
        print(string.format("[ZScav] Mirrored %d bag row(s) to ZBattle MySQL.", mirrored))
    end
end

ProbeBagMySQLReady = function()
    if BAG_MYSQL_READY or not IsBagMySQLUsable() then return end

    RunBagMySQLQuery("SELECT COUNT(*) AS row_count FROM " .. BAG_TABLE, function(_, success)
        if success == false or BAG_MYSQL_READY then return end

        BAG_MYSQL_READY = true
        if not BAG_MYSQL_READY_ANNOUNCED then
            BAG_MYSQL_READY_ANNOUNCED = true
            print("[ZScav] Bag MySQL mirror ready: " .. BAG_TABLE)
        end

        timer.Simple(0, function()
            if BackfillBagsToMySQL then
                BackfillBagsToMySQL()
            end
        end)
    end)
end

EnsureSchema()
EnsureMySQLSchema()

hook.Add("DatabaseConnected", "ZSCAV_BagsMySQLReconnect", function()
    if not IsBagMySQLMirrorEnabled() then return end
    timer.Simple(0, EnsureMySQLSchema)
end)

hook.Add("DatabaseConnectionFailed", "ZSCAV_BagsMySQLDisconnect", function()
    if not IsBagMySQLMirrorEnabled() then return end
    BAG_MYSQL_READY = false
    BAG_MYSQL_BACKFILL_DONE = false
    BAG_MYSQL_READY_ANNOUNCED = false
end)

timer.Create(BAG_MYSQL_INIT_TIMER, 1, 0, function()
    if not IsBagMySQLMirrorEnabled() then
        timer.Remove(BAG_MYSQL_INIT_TIMER)
        return
    end

    EnsureMySQLSchema()
    if BAG_MYSQL_READY then
        timer.Remove(BAG_MYSQL_INIT_TIMER)
    end
end)

concommand.Add("zscav_bags_mysql_diag", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local function emit(msg)
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print(msg)
        end
    end

    local _, bridgeName = GetBagMySQLHandle()
    local sqliteCount = tonumber(sql.QueryValue("SELECT COUNT(*) FROM " .. BAG_TABLE) or 0) or 0
    emit(string.format(
        "[ZScav] bags mysql diag: module=%s bridge=%s connected=%s ready=%s backfilled=%s sqlite_rows=%d",
        GetCurrentDBModuleName(),
        tostring(bridgeName or "none"),
        tostring(IsBagMySQLConnected()),
        tostring(BAG_MYSQL_READY),
        tostring(BAG_MYSQL_BACKFILL_DONE),
        sqliteCount
    ))

    if not BAG_MYSQL_READY and IsBagMySQLUsable() then
        EnsureMySQLSchema()
        emit("[ZScav] bags mysql diag: readiness retry requested")
        return
    end

    if not (BAG_MYSQL_READY and IsBagMySQLUsable()) then return end

    RunBagMySQLQuery("SELECT COUNT(*) AS row_count FROM " .. BAG_TABLE, function(result, success)
        if success == false then
            emit("[ZScav] bags mysql diag: row count query failed")
            return
        end

        local row = istable(result) and result[1] or nil
        local rowCount = tonumber(row and row.row_count or 0) or 0
        emit(string.format("[ZScav] bags mysql rows=%d", rowCount))
    end)
end)

-- ---------------------------------------------------------------------
-- UID generation. 16 hex chars, time-prefixed for rough ordering.
-- ---------------------------------------------------------------------
function ZSCAV:NewBagUID()
    local t = os.time()
    local r = math.random(0, 0xFFFFFF)
    return string.format("%08x%06x%02x", t, r, math.random(0, 0xFF))
end

-- ---------------------------------------------------------------------
-- CRUD
-- ---------------------------------------------------------------------
local function NormalizeBagContents(contents)
    local out = {}
    for _, it in ipairs(contents or {}) do
        local class = tostring((it and it.class) or "")
        if class ~= "" then
            local entry = ZSCAV:CopyItemEntry(it, {
                class = class,
                x = math.max(0, math.floor(tonumber(it.x) or 0)),
                y = math.max(0, math.floor(tonumber(it.y) or 0)),
                w = math.max(1, math.floor(tonumber(it.w) or 1)),
                h = math.max(1, math.floor(tonumber(it.h) or 1)),
                uid = (it.uid and tostring(it.uid) ~= "") and tostring(it.uid) or nil,
            })
            out[#out + 1] = entry
        end
    end
    return out
end

local function CopyBagRecord(record)
    if not istable(record) then return nil end

    return {
        uid = tostring(record.uid or ""),
        class = tostring(record.class or ""),
        contents = table.Copy(record.contents or {}),
    }
end

local function LoadBagRecord(uid)
    uid = tostring(uid or "")
    if uid == "" then return nil end

    local pending = BAG_PENDING_CREATES[uid]
    if pending then
        return {
            uid = uid,
            class = tostring(pending.class or ""),
            contents = {},
        }
    end

    local cached = BAG_CACHE[uid]
    if cached then
        return cached
    end

    local row = sql.QueryRow("SELECT * FROM " .. BAG_TABLE .. " WHERE uid = " .. SQLStr(uid))
    if not row then return nil end

    local record = {
        uid = tostring(row.uid or uid),
        class = tostring(row.class or ""),
        contents = NormalizeBagContents(util.JSONToTable(row.contents or "[]") or {}),
    }

    BAG_CACHE[uid] = record
    return record
end

function ZSCAV:LoadBag(uid)
    return CopyBagRecord(LoadBagRecord(uid))
end

function ZSCAV:SaveBag(uid, class, contents)
    uid = tostring(uid or "")
    if uid == "" then return false end
    local normalized = NormalizeBagContents(contents)
    local payload = util.TableToJSON(normalized) or "[]"
    local updated = os.time()
    if not WriteBagRowToSQLite(uid, class, payload, updated) then return false end

    BAG_PENDING_CREATES[uid] = nil
    BAG_CACHE[uid] = {
        uid = uid,
        class = tostring(class or ""),
        contents = table.Copy(normalized),
    }
    MirrorSaveBagToMySQL(uid, class, payload, updated)
    return true
end

function ZSCAV:DeleteBag(uid)
    uid = tostring(uid or "")
    if uid == "" then return end
    BAG_PENDING_CREATES[uid] = nil
    -- Recursively delete nested bags so we don't leak orphan rows.
    local bag = LoadBagRecord(uid)
    if bag and bag.contents then
        for _, it in ipairs(bag.contents) do
            if it.uid then self:DeleteBag(it.uid) end
        end
    end
    BAG_CACHE[uid] = nil
    sql.Query("DELETE FROM " .. BAG_TABLE .. " WHERE uid = " .. SQLStr(uid))
    MirrorDeleteBagFromMySQL(uid)
end

-- Create a fresh empty bag row. Returns the new UID.
function ZSCAV:CreateBag(class)
    local uid = self:NewBagUID()
    BAG_PENDING_CREATES[uid] = {
        class = tostring(class or ""),
        updated = os.time(),
    }
    SchedulePendingBagCreateFlush()
    return uid
end

function ZSCAV:FlushPendingBagCreates()
    if next(BAG_PENDING_CREATES) == nil then return end
    FlushPendingBagCreatesNow()
end

-- ---------------------------------------------------------------------
-- Recursive helpers used by weight calc and "drop bag with contents".
-- ---------------------------------------------------------------------

-- Walks SQL contents recursively and yields every leaf item entry.
-- callback(entry, parentUID).
function ZSCAV:WalkBag(uid, callback)
    local bag = self:LoadBag(uid)
    if not bag then return end
    for _, it in ipairs(bag.contents) do
        callback(it, uid)
        if it.uid then self:WalkBag(it.uid, callback) end
    end
end

-- Total weight stored in a bag (recursive, includes nested bag own-weight).
function ZSCAV:GetBagStoredWeight(uid)
    local bag = LoadBagRecord(uid)
    if not bag then return 0 end
    local total = 0
    for _, it in ipairs(bag.contents) do
        total = total + (self:GetItemWeight(it) or 0)
        if it.uid then total = total + self:GetBagStoredWeight(it.uid) end
    end
    return total
end

-- ---------------------------------------------------------------------
-- Admin: dump and prune
-- ---------------------------------------------------------------------
concommand.Add("zscav_bags_dump", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local rows = sql.Query("SELECT uid, class, length(contents) AS sz, updated FROM " .. BAG_TABLE .. " ORDER BY updated DESC LIMIT 50") or {}
    for _, r in ipairs(rows) do
        local line = string.format("%s | %s | %s bytes | %s", r.uid, r.class, r.sz, os.date("%Y-%m-%d %H:%M", tonumber(r.updated) or 0))
        if IsValid(ply) then ply:ChatPrint(line) else print(line) end
    end
end)

-- ---------------------------------------------------------------------
-- Map cleanup purge.
--
-- When the map is cleaned (round restart, `gmod_admin_cleanup`, etc.) all
-- world entities including dropped/stashed bag SENTs get removed. Any
-- bag UID not currently held by a connected player is therefore
-- abandoned loot and must be burned -- otherwise the SQL grows
-- unboundedly and old bag UIDs could re-resolve to unrelated future
-- spawns.
--
-- "Held by a player" =
--   inv.gear[slot].uid                (worn pack)
--   any entry in inv.pockets/vest/backpack with .uid (a bag inside a bag)
--   recursively, any nested bag UIDs stored inside SQL contents of those
-- ---------------------------------------------------------------------

local function CollectFromGrid(grid, set)
    if not istable(grid) then return end
    for _, it in ipairs(grid) do
        if it and it.uid and it.uid ~= "" then set[it.uid] = true end
    end
end

local function CollectLiveEntityBagUIDs(set)
    for _, ent in ipairs(ents.GetAll()) do
        local uid = ""
        if isfunction(ent.GetBagUID) then
            uid = tostring(ent:GetBagUID() or "")
        end
        if uid == "" then
            uid = tostring(ent.zscav_pack_uid or "")
        end
        if uid ~= "" then
            set[uid] = true
        end
    end
end

local function CollectLiveCorpseBagUIDs(set)
    local corpses = ZSCAV and ZSCAV.CorpseContainers
    if not istable(corpses) then return end

    for _, record in pairs(corpses) do
        if istable(record) then
            CollectFromGrid(record.contents, set)
        end
    end
end

local function CollectPersistedStashUIDs(set)
    if not sql.TableExists("zscav_player_stashes") then return end
    local rows = sql.Query("SELECT uid FROM zscav_player_stashes WHERE uid IS NOT NULL AND uid <> ''") or {}
    for _, r in ipairs(rows) do
        if r.uid and r.uid ~= "" then
            set[r.uid] = true
        end
    end
end

local function CollectPersistedSecureUIDs(set)
    if not sql.TableExists("zscav_player_secure") then return end
    local rows = sql.Query("SELECT uid, status FROM zscav_player_secure WHERE uid IS NOT NULL AND uid <> ''") or {}
    for _, r in ipairs(rows) do
        local uid = tostring(r.uid or "")
        local status = tostring(r.status or "")
        if uid ~= "" and status ~= "destroyed" then
            set[uid] = true
        end
    end
end

local function CollectNestedFromSQL(uid, set, walked)
    uid = tostring(uid or "")
    if uid == "" or walked[uid] then return end
    walked[uid] = true

    local row = sql.QueryRow("SELECT contents FROM zscav_bags WHERE uid = " .. SQLStr(uid))
    if not row then return end

    local contents = util.JSONToTable(row.contents or "[]") or {}
    for _, it in ipairs(contents) do
        local childUID = tostring(it.uid or "")
        if childUID ~= "" then
            set[childUID] = true
            CollectNestedFromSQL(childUID, set, walked)
        end
    end
end

local function ExpandNestedOwnedBagUIDs(set)
    local walked = {}
    local seeds = {}
    for uid in pairs(set) do
        seeds[#seeds + 1] = uid
    end
    for _, uid in ipairs(seeds) do
        CollectNestedFromSQL(uid, set, walked)
    end
    return set
end

function ZSCAV:CollectOwnedBagUIDs(options)
    options = istable(options) and options or {}

    local set = {}

    if options.includePlayers ~= false then
        for _, ply in player.Iterator() do
            local inv = ply.zscav_inv
            if istable(inv) then
                if istable(inv.gear) then
                    for _, entry in pairs(inv.gear) do
                        if istable(entry) and entry.uid and entry.uid ~= "" then
                            set[entry.uid] = true
                        end
                    end
                end

                CollectFromGrid(inv.pocket, set)
                CollectFromGrid(inv.backpack, set)
                CollectFromGrid(inv.vest, set)
                CollectFromGrid(inv.secure, set)
            end
        end
    end

    if options.includeWorld ~= false then
        CollectLiveEntityBagUIDs(set)
    end

    if options.includeCorpses ~= false then
        CollectLiveCorpseBagUIDs(set)
    end

    if options.includeStashes ~= false then
        CollectPersistedStashUIDs(set)
    end

    if options.includeSecure ~= false then
        CollectPersistedSecureUIDs(set)
    end

    return ExpandNestedOwnedBagUIDs(set)
end

function ZSCAV:CollectPersistentBagUIDs()
    return self:CollectOwnedBagUIDs({
        includePlayers = false,
        includeWorld = false,
        includeCorpses = false,
    })
end

-- Burn every SQL bag row whose UID is no longer rooted by the supplied set.
-- Returns the number of rows deleted.
function ZSCAV:PurgeUnownedBags(owned)
    self:FlushPendingBagCreates()
    owned = owned or self:CollectOwnedBagUIDs()
    local rows  = sql.Query("SELECT uid FROM zscav_bags") or {}
    local removed = 0
    for _, r in ipairs(rows) do
        local uid = tostring(r.uid or "")
        if uid ~= "" and not owned[uid] and self:LoadBag(uid) then
            self:DeleteBag(uid)
            removed = removed + 1
        end
    end
    return removed
end

local function SaveLiveStashesForShutdown()
    if not isfunction(ZSCAV.SavePlayerStashEntity) then return end

    for _, ent in ipairs(ents.FindByClass("ent_zscav_player_stash")) do
        if IsValid(ent) then
            ZSCAV:SavePlayerStashEntity(ent)
        end
    end
end

local function FlushLiveSecureContainersForShutdown()
    local helpers = ZSCAV and ZSCAV.ServerHelpers or nil
    local flushSecure = helpers and helpers.FlushSecurePersistence or nil
    if not isfunction(flushSecure) then return end

    for _, ply in player.Iterator() do
        if IsValid(ply) then
            flushSecure(ply)
        end
    end
end

-- Cleanup hook. By the time PostCleanupMap runs, world entities and corpse
-- anchors are already gone, so only live player inventories and persistent
-- stash/secure roots remain valid bag owners.
hook.Add("PostCleanupMap", "ZSCAV_BurnAbandonedBags", function()
    local n = ZSCAV:PurgeUnownedBags()
    if n > 0 then
        print(string.format("[ZScav] Map cleanup burned %d abandoned bag(s).", n))
    end
end)

hook.Add("PlayerDisconnected", "ZSCAV_BurnAbandonedBags_OnLeave", function()
    timer.Simple(0, function()
        if not ZSCAV or not ZSCAV.PurgeUnownedBags then return end

        local n = ZSCAV:PurgeUnownedBags()
        if n > 0 then
            print(string.format("[ZScav] Disconnect purge burned %d abandoned bag(s).", n))
        end
    end)
end)

hook.Add("ShutDown", "ZSCAV_BurnNonPersistentBags_Shutdown", function()
    SaveLiveStashesForShutdown()
    FlushLiveSecureContainersForShutdown()

    local n = ZSCAV:PurgeUnownedBags(ZSCAV:CollectPersistentBagUIDs())
    if n > 0 then
        print(string.format("[ZScav] Shutdown purge burned %d non-persistent bag(s).", n))
    end
end)

-- Manual trigger for admins / scripted round resets.
concommand.Add("zscav_bags_purge_abandoned", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local n = ZSCAV:PurgeUnownedBags()
    local msg = string.format("[ZScav] Purged %d abandoned bag row(s).", n)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

-- Drop bag rows older than N days that are not currently referenced by
-- any spawned ent. Cheap GC; safe to run periodically.
concommand.Add("zscav_bags_gc", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local days = math.max(1, tonumber(args[1] or "30") or 30)
    local cutoff = os.time() - days * 86400

    local live = ZSCAV:CollectOwnedBagUIDs()

    local rows = sql.Query("SELECT uid FROM zscav_bags WHERE updated < " .. cutoff) or {}
    local removed = 0
    for _, r in ipairs(rows) do
        local uid = tostring(r.uid or "")
        if uid ~= "" and not live[uid] and ZSCAV:LoadBag(uid) then
            ZSCAV:DeleteBag(uid)
            removed = removed + 1
        end
    end
    local msg = string.format("[ZScav] GC removed %d stale bag rows (older than %d days).", removed, days)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)
