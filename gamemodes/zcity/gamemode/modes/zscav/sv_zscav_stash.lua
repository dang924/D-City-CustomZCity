-- ZScav persistent player stash layer.
--
-- Stores one stash inventory per player (shared across maps). The world stash
-- entity itself is a single shared object per map, while player rows can stay
-- locationless and only root each player's canonical stash UID.
-- existing zscav_bags table via bag UID. This table tracks only ownership,
-- transform and freeze state so the shared world stash can be restored after
-- restart and map cleanup.

if not SERVER then return end

ZSCAV = ZSCAV or {}

local STASH_CLASS = "ent_zscav_player_stash"
local STASH_TABLE = "zscav_player_stashes"
local STASH_FROZEN_LOCATIONLESS = 2
local STASH_SHARED_WORLD_OWNER = "__shared_world__"

ZSCAV.PlayerStashCache = ZSCAV.PlayerStashCache or {}
ZSCAV.PlayerStashCacheByMap = ZSCAV.PlayerStashCacheByMap or {}
ZSCAV.PlayerStashUIDByOwner = ZSCAV.PlayerStashUIDByOwner or {}
ZSCAV.SharedPlayerStashWorldOwner = ZSCAV.SharedPlayerStashWorldOwner or STASH_SHARED_WORLD_OWNER

local STASH_MYSQL_READY = false
local STASH_MYSQL_LOAD_DONE = false
local STASH_MYSQL_INIT_TIMER = "ZSCAV_StashMySQL_InitRetry"
local STASH_MYSQL_BACKFILL_DONE = false
local STASH_MYSQL_READY_ANNOUNCED = false

local STASH_MYSQL_MIRROR_CVAR = CreateConVar(
    "zscav_mysql_runtime_mirror",
    "0",
    FCVAR_ARCHIVE,
    "Mirror live ZScav bag and stash rows to the external MySQL bridge. Disabled by default so runtime persistence stays on sv.db only."
)

local BackfillStashRowsToMySQL
local NormalizeStashRow
local ProbeStashMySQLReady
local RunStashMySQLQuery
local EscapeStashMySQLValue

local STASH_SCHEMA = [[
CREATE TABLE IF NOT EXISTS zscav_player_stashes (
    owner_sid64 TEXT NOT NULL,
    map         TEXT NOT NULL,
    uid         TEXT NOT NULL,
    posx        REAL NOT NULL,
    posy        REAL NOT NULL,
    posz        REAL NOT NULL,
    angp        REAL NOT NULL,
    angy        REAL NOT NULL,
    angr        REAL NOT NULL,
    frozen      INTEGER NOT NULL DEFAULT 1,
    updated     INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (owner_sid64, map)
)
]]

local STASH_MYSQL_SCHEMA = [[
CREATE TABLE IF NOT EXISTS zscav_player_stashes (
    owner_sid64 VARCHAR(32)  NOT NULL,
    map         VARCHAR(128) NOT NULL,
    uid         VARCHAR(128) NOT NULL,
    posx        DOUBLE       NOT NULL,
    posy        DOUBLE       NOT NULL,
    posz        DOUBLE       NOT NULL,
    angp        DOUBLE       NOT NULL,
    angy        DOUBLE       NOT NULL,
    angr        DOUBLE       NOT NULL,
    frozen      TINYINT      NOT NULL DEFAULT 1,
    updated     BIGINT       NOT NULL DEFAULT 0,
    PRIMARY KEY (owner_sid64, map),
    INDEX idx_map (map)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

local function GetStashMySQLHandle()
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

local function IsStashMySQLMirrorEnabled()
    return STASH_MYSQL_MIRROR_CVAR ~= nil and STASH_MYSQL_MIRROR_CVAR:GetBool()
end

local function GetCurrentDBModuleName()
    local handle = GetStashMySQLHandle()
    if handle and isstring(handle.module) then
        return tostring(handle.module)
    end

    if istable(mysql) and isstring(mysql.module) then
        return tostring(mysql.module)
    end

    return ""
end

local function IsStashMySQLConnected()
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

local function IsStashMySQLUsable()
    local handle = GetStashMySQLHandle()
    return IsStashMySQLMirrorEnabled()
        and GetCurrentDBModuleName() == "mysqloo"
        and handle ~= nil
        and IsStashMySQLConnected()
end

RunStashMySQLQuery = function(query, callback)
    local handle, _, mode = GetStashMySQLHandle()
    if not handle or not IsStashMySQLUsable() then
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

EscapeStashMySQLValue = function(value)
    local handle, _, mode = GetStashMySQLHandle()
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

local function SaveStashRowToSQLite(row)
    row = NormalizeStashRow(row)
    if not row then return false end

    local sqliteQuery = string.format(
        "INSERT OR REPLACE INTO %s " ..
        "(owner_sid64, map, uid, posx, posy, posz, angp, angy, angr, frozen, updated) " ..
        "VALUES (%s, %s, %s, %f, %f, %f, %f, %f, %f, %d, %d)",
        STASH_TABLE,
        SQLStr(row.owner_sid64),
        SQLStr(row.map),
        SQLStr(row.uid),
        row.posx, row.posy, row.posz,
        row.angp, row.angy, row.angr,
        row.frozen,
        row.updated
    )

    local ok = sql.Query(sqliteQuery)
    if ok == false then
        ErrorNoHalt("[ZScav] SavePlayerStashEntity sqlite fallback failed: " .. tostring(sql.LastError()) .. "\n")
        return false
    end

    return true
end

local function MirrorSaveStashRowToMySQL(row)
    row = NormalizeStashRow(row)
    if not row then return false end
    if not STASH_MYSQL_READY or not IsStashMySQLUsable() then return false end

    local q = string.format(
        "INSERT INTO %s (owner_sid64, map, uid, posx, posy, posz, angp, angy, angr, frozen, updated) " ..
        "VALUES (%s, %s, %s, %f, %f, %f, %f, %f, %f, %d, %d) " ..
        "ON DUPLICATE KEY UPDATE uid = VALUES(uid), posx = VALUES(posx), posy = VALUES(posy), posz = VALUES(posz), angp = VALUES(angp), angy = VALUES(angy), angr = VALUES(angr), frozen = VALUES(frozen), updated = VALUES(updated)",
        STASH_TABLE,
        EscapeStashMySQLValue(row.owner_sid64),
        EscapeStashMySQLValue(row.map),
        EscapeStashMySQLValue(row.uid),
        row.posx, row.posy, row.posz,
        row.angp, row.angy, row.angr,
        row.frozen,
        row.updated
    )

    RunStashMySQLQuery(q, function() end)
    return true
end

local function MirrorDeleteStashRowFromMySQL(ownerSID64, mapName)
    if not STASH_MYSQL_READY or not IsStashMySQLUsable() then return false end

    local q = string.format(
        "DELETE FROM %s WHERE owner_sid64 = %s AND map = %s",
        STASH_TABLE,
        EscapeStashMySQLValue(ownerSID64),
        EscapeStashMySQLValue(mapName)
    )
    RunStashMySQLQuery(q, function() end)
    return true
end

local function DeleteStashRowFromSQLite(ownerSID64, mapName)
    local ok = sql.Query(
        "DELETE FROM " .. STASH_TABLE .. " WHERE owner_sid64 = " .. SQLStr(ownerSID64) ..
        " AND map = " .. SQLStr(mapName)
    )
    if ok == false then
        ErrorNoHalt("[ZScav] DeletePlayerStash failed: " .. tostring(sql.LastError()) .. "\n")
        return false
    end
    return true
end

NormalizeStashRow = function(row)
    if not istable(row) then return nil end

    local ownerSID64 = tostring(row.owner_sid64 or "")
    local mapName = tostring(row.map or "")
    if ownerSID64 == "" or mapName == "" then return nil end

    local frozen = tonumber(row.frozen)
    if frozen == STASH_FROZEN_LOCATIONLESS then
        frozen = STASH_FROZEN_LOCATIONLESS
    else
        frozen = (frozen == 1) and 1 or 0
    end

    return {
        owner_sid64 = ownerSID64,
        map = mapName,
        uid = tostring(row.uid or ""),
        posx = tonumber(row.posx) or 0,
        posy = tonumber(row.posy) or 0,
        posz = tonumber(row.posz) or 0,
        angp = tonumber(row.angp) or 0,
        angy = tonumber(row.angy) or 0,
        angr = tonumber(row.angr) or 0,
        frozen = frozen,
        updated = tonumber(row.updated) or 0,
    }
end

local function HasStashWorldLocation(row)
    return (tonumber(row and row.frozen) or 0) ~= STASH_FROZEN_LOCATIONLESS
end

local function UpsertStashCacheRow(row)
    local normalized = NormalizeStashRow(row)
    if not normalized then return nil end

    local key = normalized.owner_sid64 .. "|" .. normalized.map
    ZSCAV.PlayerStashCache[key] = normalized

    ZSCAV.PlayerStashCacheByMap[normalized.map] = ZSCAV.PlayerStashCacheByMap[normalized.map] or {}
    ZSCAV.PlayerStashCacheByMap[normalized.map][normalized.owner_sid64] = normalized

    if normalized.uid ~= "" then
        local prev = ZSCAV.PlayerStashUIDByOwner[normalized.owner_sid64]
        if not prev or (tonumber(normalized.updated) or 0) >= (tonumber(prev.updated) or 0) then
            ZSCAV.PlayerStashUIDByOwner[normalized.owner_sid64] = {
                uid = normalized.uid,
                updated = tonumber(normalized.updated) or 0,
            }
        end
    end

    return normalized
end

function ZSCAV:GetCanonicalPlayerStashUID(ownerSID64, createIfMissing)
    ownerSID64 = tostring(ownerSID64 or "")
    if ownerSID64 == "" then return nil, "missing_owner" end

    local cached = ZSCAV.PlayerStashUIDByOwner[ownerSID64]
    if istable(cached) and tostring(cached.uid or "") ~= "" then
        return tostring(cached.uid)
    end

    local row = sql.QueryRow(
        "SELECT uid, updated FROM " .. STASH_TABLE .. " WHERE owner_sid64 = " .. SQLStr(ownerSID64) ..
        " AND uid IS NOT NULL AND uid <> '' ORDER BY updated DESC LIMIT 1"
    )
    if istable(row) then
        local uid = tostring(row.uid or "")
        if uid ~= "" then
            ZSCAV.PlayerStashUIDByOwner[ownerSID64] = {
                uid = uid,
                updated = tonumber(row.updated) or 0,
            }
            return uid
        end
    end

    if STASH_MYSQL_READY and not STASH_MYSQL_LOAD_DONE then
        return nil, "stash_loading"
    end

    if not createIfMissing then
        return nil, "missing_uid"
    end

    if not self.CreateBag then
        return nil, "missing_createbag"
    end

    local uid = tostring(self:CreateBag(STASH_CLASS) or "")
    if uid == "" then
        return nil, "createbag_failed"
    end

    ZSCAV.PlayerStashUIDByOwner[ownerSID64] = {
        uid = uid,
        updated = os.time(),
    }

    return uid
end

local function RemoveStashCacheRow(ownerSID64, mapName)
    local key = ownerSID64 .. "|" .. mapName
    ZSCAV.PlayerStashCache[key] = nil

    local byMap = ZSCAV.PlayerStashCacheByMap[mapName]
    if istable(byMap) then
        byMap[ownerSID64] = nil
        if next(byMap) == nil then
            ZSCAV.PlayerStashCacheByMap[mapName] = nil
        end
    end
end

local function GetCachedStashRow(ownerSID64, mapName)
    return ZSCAV.PlayerStashCache[ownerSID64 .. "|" .. mapName]
end

local function GetCachedStashRowsForMap(mapName)
    local rows = {}
    local byMap = ZSCAV.PlayerStashCacheByMap[mapName]
    if not istable(byMap) then return rows end
    for _, row in pairs(byMap) do
        rows[#rows + 1] = row
    end
    return rows
end

function ZSCAV:IsSharedWorldStashOwner(ownerSID64)
    return tostring(ownerSID64 or "") == STASH_SHARED_WORLD_OWNER
end

local function PrimeCachedStashRowsForMap(mapName)
    local rows = GetCachedStashRowsForMap(mapName)
    if #rows > 0 or not sql.TableExists(STASH_TABLE) then
        return rows
    end

    local sqliteRows = sql.Query("SELECT * FROM " .. STASH_TABLE .. " WHERE map = " .. SQLStr(mapName)) or {}
    for _, row in ipairs(sqliteRows) do
        local normalized = UpsertStashCacheRow(row)
        if normalized then
            rows[#rows + 1] = normalized
        end
    end

    return rows
end

function ZSCAV:GetSharedWorldStashRow(mapName)
    mapName = tostring(mapName or game.GetMap() or "")
    if mapName == "" then return nil end

    local sharedRow = GetCachedStashRow(STASH_SHARED_WORLD_OWNER, mapName)
    if sharedRow then
        return table.Copy(sharedRow)
    end

    local rows = PrimeCachedStashRowsForMap(mapName)
    local legacyRow = nil

    for _, row in ipairs(rows) do
        if self:IsSharedWorldStashOwner(row.owner_sid64) then
            return table.Copy(row)
        end

        if HasStashWorldLocation(row) then
            if not legacyRow or (tonumber(row.updated) or 0) > (tonumber(legacyRow.updated) or 0) then
                legacyRow = row
            end
        end
    end

    if not legacyRow then
        return nil
    end

    return {
        owner_sid64 = STASH_SHARED_WORLD_OWNER,
        map = mapName,
        uid = "",
        posx = tonumber(legacyRow.posx) or 0,
        posy = tonumber(legacyRow.posy) or 0,
        posz = tonumber(legacyRow.posz) or 0,
        angp = tonumber(legacyRow.angp) or 0,
        angy = tonumber(legacyRow.angy) or 0,
        angr = tonumber(legacyRow.angr) or 0,
        frozen = tonumber(legacyRow.frozen) == 1 and 1 or 0,
        updated = tonumber(legacyRow.updated) or 0,
    }
end

function ZSCAV:EnsureSharedWorldStashRow(mapName, data)
    mapName = tostring(mapName or game.GetMap() or "")
    if mapName == "" then return nil, "missing_map" end

    local existing = self:GetSharedWorldStashRow(mapName)
    local row = UpsertStashCacheRow({
        owner_sid64 = STASH_SHARED_WORLD_OWNER,
        map = mapName,
        uid = tostring(existing and existing.uid or ""),
        posx = tonumber(data and data.posx or existing and existing.posx) or 0,
        posy = tonumber(data and data.posy or existing and existing.posy) or 0,
        posz = tonumber(data and data.posz or existing and existing.posz) or 0,
        angp = tonumber(data and data.angp or existing and existing.angp) or 0,
        angy = tonumber(data and data.angy or existing and existing.angy) or 0,
        angr = tonumber(data and data.angr or existing and existing.angr) or 0,
        frozen = tonumber(data and data.frozen or existing and existing.frozen) == 1 and 1 or 0,
        updated = os.time(),
    })
    if not row then
        return nil, "stash_row_invalid"
    end

    if not SaveStashRowToSQLite(row) then
        return nil, "sqlite_save_failed"
    end

    if STASH_MYSQL_READY and IsStashMySQLUsable() then
        MirrorSaveStashRowToMySQL(row)
    end

    return row
end

local function RestoreAfterMySQLLoad()
    if not ZSCAV or not ZSCAV.RestoreAllPlayerStashesForMap then return end
    if ZSCAV.zscav_stash_restore_after_mysql then return end
    ZSCAV.zscav_stash_restore_after_mysql = true
    timer.Simple(0, function()
        if not ZSCAV or not ZSCAV.RestoreAllPlayerStashesForMap then return end
        ZSCAV:RestoreAllPlayerStashesForMap(game.GetMap())
    end)
end

local function LoadStashRowsFromMySQL()
    if not STASH_MYSQL_READY or not IsStashMySQLUsable() then return end

    RunStashMySQLQuery("SELECT owner_sid64, map, uid, posx, posy, posz, angp, angy, angr, frozen, updated FROM " .. STASH_TABLE, function(result, success)
        if success == false then return end

        if istable(result) then
            for _, row in ipairs(result) do
                local normalized = UpsertStashCacheRow(row)
                if normalized then
                    SaveStashRowToSQLite(normalized)
                end
            end
        end

        STASH_MYSQL_LOAD_DONE = true
        RestoreAfterMySQLLoad()
    end)
end

local function EnsureStashMySQLSchema()
    if STASH_MYSQL_READY then return end
    if not IsStashMySQLUsable() then return end

    RunStashMySQLQuery(STASH_MYSQL_SCHEMA, function(_, success)
        if success == false then return end
        if ProbeStashMySQLReady then
            timer.Simple(0, ProbeStashMySQLReady)
        end
    end)

    if ProbeStashMySQLReady then
        timer.Simple(0.25, ProbeStashMySQLReady)
    end
end

local function EnsureStashSchema()
    if sql.TableExists(STASH_TABLE) then return end
    local ok = sql.Query(STASH_SCHEMA)
    if ok == false then
        ErrorNoHalt("[ZScav] Failed to create sqlite stash table: " .. tostring(sql.LastError()) .. "\n")
    end
end
EnsureStashSchema()
EnsureStashMySQLSchema()

hook.Add("DatabaseConnected", "ZSCAV_StashMySQLReconnect", function()
    if not IsStashMySQLMirrorEnabled() then return end
    timer.Simple(0, EnsureStashMySQLSchema)
end)

hook.Add("DatabaseConnectionFailed", "ZSCAV_StashMySQLDisconnect", function()
    if not IsStashMySQLMirrorEnabled() then return end
    STASH_MYSQL_READY = false
    STASH_MYSQL_LOAD_DONE = false
    STASH_MYSQL_BACKFILL_DONE = false
    STASH_MYSQL_READY_ANNOUNCED = false
end)

timer.Create(STASH_MYSQL_INIT_TIMER, 1, 0, function()
    if not IsStashMySQLMirrorEnabled() then
        timer.Remove(STASH_MYSQL_INIT_TIMER)
        return
    end

    EnsureStashMySQLSchema()
    if STASH_MYSQL_READY then
        timer.Remove(STASH_MYSQL_INIT_TIMER)
    end
end)

BackfillStashRowsToMySQL = function()
    if STASH_MYSQL_BACKFILL_DONE then return end
    if not STASH_MYSQL_READY or not IsStashMySQLUsable() then return end

    STASH_MYSQL_BACKFILL_DONE = true

    local rows = sql.Query("SELECT owner_sid64, map, uid, posx, posy, posz, angp, angy, angr, frozen, updated FROM " .. STASH_TABLE) or {}
    local mirrored = 0

    for _, row in ipairs(rows) do
        local normalized = NormalizeStashRow(row)
        if normalized and MirrorSaveStashRowToMySQL(normalized) then
            mirrored = mirrored + 1
        end
    end

    if mirrored > 0 then
        print(string.format("[ZScav] Mirrored %d stash row(s) to ZBattle MySQL.", mirrored))
    end
end

ProbeStashMySQLReady = function()
    if STASH_MYSQL_READY or not IsStashMySQLUsable() then return end

    RunStashMySQLQuery("SELECT COUNT(*) AS row_count FROM " .. STASH_TABLE, function(_, success)
        if success == false or STASH_MYSQL_READY then return end

        STASH_MYSQL_READY = true
        if not STASH_MYSQL_READY_ANNOUNCED then
            STASH_MYSQL_READY_ANNOUNCED = true
            print("[ZScav] Stash MySQL mirror ready: " .. STASH_TABLE)
        end

        timer.Simple(0, function()
            if BackfillStashRowsToMySQL then
                BackfillStashRowsToMySQL()
            end
            LoadStashRowsFromMySQL()
        end)
    end)
end

concommand.Add("zscav_stash_mysql_diag", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local function emit(msg)
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print(msg)
        end
    end

    local _, bridgeName = GetStashMySQLHandle()
    local sqliteCount = tonumber(sql.QueryValue("SELECT COUNT(*) FROM " .. STASH_TABLE) or 0) or 0
    emit(string.format(
        "[ZScav] stash mysql diag: module=%s bridge=%s connected=%s ready=%s loaded=%s backfilled=%s sqlite_rows=%d",
        GetCurrentDBModuleName(),
        tostring(bridgeName or "none"),
        tostring(IsStashMySQLConnected()),
        tostring(STASH_MYSQL_READY),
        tostring(STASH_MYSQL_LOAD_DONE),
        tostring(STASH_MYSQL_BACKFILL_DONE),
        sqliteCount
    ))

    if not STASH_MYSQL_READY and IsStashMySQLUsable() then
        EnsureStashMySQLSchema()
        emit("[ZScav] stash mysql diag: readiness retry requested")
        return
    end

    if not (STASH_MYSQL_READY and IsStashMySQLUsable()) then return end

    RunStashMySQLQuery("SELECT COUNT(*) AS row_count FROM " .. STASH_TABLE, function(result, success)
        if success == false then
            emit("[ZScav] stash mysql diag: row count query failed")
            return
        end

        local row = istable(result) and result[1] or nil
        local rowCount = tonumber(row and row.row_count or 0) or 0
        emit(string.format("[ZScav] stash mysql rows=%d", rowCount))
    end)
end)

local function ReadFrozenFromEntity(ent)
    local frozen = ent.GetIsFrozen and ent:GetIsFrozen() or false
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        frozen = not phys:IsMotionEnabled()
    end
    return frozen and 1 or 0
end

local function FindSpawnedSharedStash()
    local sharedEnt = nil
    local fallbackEnt = nil

    for _, ent in ipairs(ents.FindByClass(STASH_CLASS)) do
        if IsValid(ent) then
            local ownerSID64 = ent.GetOwnerSID64 and tostring(ent:GetOwnerSID64() or "") or ""
            if ownerSID64 == STASH_SHARED_WORLD_OWNER then
                if not IsValid(sharedEnt) then
                    sharedEnt = ent
                else
                    ent.zscav_skip_save = true
                    ent:Remove()
                end
            elseif not IsValid(fallbackEnt) then
                fallbackEnt = ent
            else
                ent.zscav_skip_save = true
                ent:Remove()
            end
        end
    end

    if IsValid(sharedEnt) and IsValid(fallbackEnt) and fallbackEnt ~= sharedEnt then
        fallbackEnt.zscav_skip_save = true
        fallbackEnt:Remove()
    end

    local keep = IsValid(sharedEnt) and sharedEnt or fallbackEnt
    if IsValid(keep) and keep.SetOwnerSID64 and tostring(keep:GetOwnerSID64() or "") ~= STASH_SHARED_WORLD_OWNER then
        keep:SetOwnerSID64(STASH_SHARED_WORLD_OWNER)
    end

    return keep
end

function ZSCAV:GetContainerGridSize(containerClass)
    if tostring(containerClass or "") == STASH_CLASS then
        return 10, 64
    end
    return nil
end

function ZSCAV:GetPlayerStashRow(ownerSID64, mapName)
    ownerSID64 = tostring(ownerSID64 or "")
    mapName = tostring(mapName or game.GetMap() or "")
    if ownerSID64 == "" or mapName == "" then return nil end

    local cached = GetCachedStashRow(ownerSID64, mapName)
    if cached then
        return table.Copy(cached)
    end

    local row = sql.QueryRow(
        "SELECT * FROM " .. STASH_TABLE .. " WHERE owner_sid64 = " .. SQLStr(ownerSID64) ..
        " AND map = " .. SQLStr(mapName)
    )
    if istable(row) then
        row = UpsertStashCacheRow(row)
    end

    return row
end

function ZSCAV:EnsurePlayerStashRecord(ownerSID64, mapName)
    ownerSID64 = tostring(ownerSID64 or "")
    mapName = tostring(mapName or game.GetMap() or "")
    if ownerSID64 == "" or mapName == "" then return nil, "missing_owner" end

    local uid, uidErr = self:GetCanonicalPlayerStashUID(ownerSID64, true)
    if uidErr == "stash_loading" then
        return nil, "stash_loading"
    end

    uid = tostring(uid or "")
    if uid == "" then
        return nil, uidErr or "missing_uid"
    end

    local existing = self:GetPlayerStashRow(ownerSID64, mapName)
    if existing and tostring(existing.uid or "") == uid then
        return existing
    end

    local row = UpsertStashCacheRow(existing or {
        owner_sid64 = ownerSID64,
        map = mapName,
        uid = uid,
        posx = 0,
        posy = 0,
        posz = 0,
        angp = 0,
        angy = 0,
        angr = 0,
        frozen = STASH_FROZEN_LOCATIONLESS,
        updated = os.time(),
    })

    if not row then
        return nil, "stash_row_invalid"
    end

    row.uid = uid
    row.updated = os.time()
    if not existing then
        row.frozen = STASH_FROZEN_LOCATIONLESS
    end

    row = UpsertStashCacheRow(row)
    if not row then
        return nil, "stash_row_invalid"
    end

    if not SaveStashRowToSQLite(row) then
        return nil, "sqlite_save_failed"
    end

    if STASH_MYSQL_READY and IsStashMySQLUsable() then
        MirrorSaveStashRowToMySQL(row)
    end

    return row
end

function ZSCAV:GetAccessiblePlayerStashUID(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        return nil, "invalid_player"
    end

    local ownerSID64 = tostring(ply:SteamID64() or "")
    if ownerSID64 == "" then
        return nil, "missing_steamid64"
    end

    local row, rowErr = self:EnsurePlayerStashRecord(ownerSID64, game.GetMap())
    if rowErr == "stash_loading" then
        return nil, rowErr
    end

    local uid = tostring(row and row.uid or "")
    if uid == "" then
        return nil, rowErr or "missing_uid"
    end

    return uid
end

local function NormalizeStashOwnerSID64(ownerSID64)
    ownerSID64 = tostring(ownerSID64 or "")
    if ownerSID64 == STASH_SHARED_WORLD_OWNER then
        return ownerSID64
    end
    if ownerSID64 == "" or not string.match(ownerSID64, "^%d+$") then
        return ""
    end

    return ownerSID64
end

local function GetStashOwnerSID64FromPlayer(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return "" end
    return NormalizeStashOwnerSID64(ply:SteamID64())
end

function ZSCAV:ResolvePlayerStashOwnerSID64(ent, fallbackPlayer)
    if not IsValid(ent) then return "" end

    local ownerSID64 = ent.GetOwnerSID64 and NormalizeStashOwnerSID64(ent:GetOwnerSID64()) or ""
    if ownerSID64 ~= "" then
        return ownerSID64
    end

    ownerSID64 = GetStashOwnerSID64FromPlayer(fallbackPlayer)
    if ownerSID64 ~= "" then
        return ownerSID64
    end

    if ent.CPPIGetOwner then
        ownerSID64 = GetStashOwnerSID64FromPlayer(ent:CPPIGetOwner())
        if ownerSID64 ~= "" then
            return ownerSID64
        end
    end

    if ent.GetCreator then
        ownerSID64 = GetStashOwnerSID64FromPlayer(ent:GetCreator())
        if ownerSID64 ~= "" then
            return ownerSID64
        end
    end

    if ent.GetOwner then
        ownerSID64 = GetStashOwnerSID64FromPlayer(ent:GetOwner())
        if ownerSID64 ~= "" then
            return ownerSID64
        end
    end

    return ""
end

function ZSCAV:SavePlayerStashEntity(ent)
    if not IsValid(ent) or ent:GetClass() ~= STASH_CLASS then return false end

    local ownerSID64 = self.ResolvePlayerStashOwnerSID64 and self:ResolvePlayerStashOwnerSID64(ent) or ""
    if ownerSID64 == "" and ent.SetOwnerSID64 then
        ent:SetOwnerSID64(STASH_SHARED_WORLD_OWNER)
        ownerSID64 = STASH_SHARED_WORLD_OWNER
    end
    if ownerSID64 == "" then return false end
    if self:IsSharedWorldStashOwner(ownerSID64) then
        local pos = ent:GetPos()
        local ang = ent:GetAngles()
        local frozen = ReadFrozenFromEntity(ent)
        if ent.SetIsFrozen then
            ent:SetIsFrozen(frozen == 1)
        end

        local row, rowErr = self:EnsureSharedWorldStashRow(game.GetMap(), {
            posx = pos.x,
            posy = pos.y,
            posz = pos.z,
            angp = ang.p,
            angy = ang.y,
            angr = ang.r,
            frozen = frozen,
        })
        return row ~= nil, rowErr
    end

    if ent.SetOwnerSID64 and ent.GetOwnerSID64 and ent:GetOwnerSID64() ~= ownerSID64 then
        ent:SetOwnerSID64(ownerSID64)
    end

    local uid, uidErr = self:GetCanonicalPlayerStashUID(ownerSID64, true)
    if uidErr == "stash_loading" then return false end
    uid = tostring(uid or "")
    if uid ~= "" and ent.SetBagUID and ent:GetBagUID() ~= uid then
        ent:SetBagUID(uid)
    end
    if uid == "" then return false end

    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    local frozen = ReadFrozenFromEntity(ent)
    if ent.SetIsFrozen then
        ent:SetIsFrozen(frozen == 1)
    end

    local row = UpsertStashCacheRow({
        owner_sid64 = ownerSID64,
        map = game.GetMap() or "",
        uid = uid,
        posx = pos.x,
        posy = pos.y,
        posz = pos.z,
        angp = ang.p,
        angy = ang.y,
        angr = ang.r,
        frozen = frozen,
        updated = os.time(),
    })
    if not row then return false end

    if not SaveStashRowToSQLite(row) then return false end

    if STASH_MYSQL_READY and IsStashMySQLUsable() then
        MirrorSaveStashRowToMySQL(row)
    end

    return true
end

function ZSCAV:DeletePlayerStash(ownerSID64, mapName, deleteBag)
    ownerSID64 = tostring(ownerSID64 or "")
    mapName = tostring(mapName or game.GetMap() or "")
    if ownerSID64 == "" or mapName == "" then return false end

    if self:IsSharedWorldStashOwner(ownerSID64) then
        local ent = FindSpawnedSharedStash()
        if IsValid(ent) then
            ent.zscav_skip_save = true
            ent:Remove()
        end

        RemoveStashCacheRow(STASH_SHARED_WORLD_OWNER, mapName)

        if not DeleteStashRowFromSQLite(STASH_SHARED_WORLD_OWNER, mapName) then return false end

        if STASH_MYSQL_READY and IsStashMySQLUsable() then
            MirrorDeleteStashRowFromMySQL(STASH_SHARED_WORLD_OWNER, mapName)
        end

        return true
    end

    local row = self:GetPlayerStashRow(ownerSID64, mapName)
    if row and deleteBag and row.uid and row.uid ~= "" and self.DeleteBag then
        self:DeleteBag(row.uid)
    end

    RemoveStashCacheRow(ownerSID64, mapName)

    if not DeleteStashRowFromSQLite(ownerSID64, mapName) then return false end

    if STASH_MYSQL_READY and IsStashMySQLUsable() then
        MirrorDeleteStashRowFromMySQL(ownerSID64, mapName)
    end

    return true
end

function ZSCAV:SpawnPlayerStashFromRow(row)
    if not istable(row) then return nil end
    if not HasStashWorldLocation(row) then return nil end

    local position = Vector(
        tonumber(row.posx) or 0,
        tonumber(row.posy) or 0,
        tonumber(row.posz) or 0
    )
    local angles = Angle(
        tonumber(row.angp) or 0,
        tonumber(row.angy) or 0,
        tonumber(row.angr) or 0
    )

    local ent = FindSpawnedSharedStash()
    if not IsValid(ent) then
        ent = ents.Create(STASH_CLASS)
        if not IsValid(ent) then return nil end
        ent:SetOwnerSID64(STASH_SHARED_WORLD_OWNER)
        ent:SetBagUID("")
        ent:SetPos(position)
        ent:SetAngles(angles)
        ent:SetIsFrozen(tonumber(row.frozen) == 1)
        ent:Spawn()
        ent:Activate()
    else
        ent:SetOwnerSID64(STASH_SHARED_WORLD_OWNER)
        if ent.SetBagUID and ent:GetBagUID() ~= "" then
            ent:SetBagUID("")
        end
        ent:SetPos(position)
        ent:SetAngles(angles)
        ent:SetIsFrozen(tonumber(row.frozen) == 1)
    end

    timer.Simple(0, function()
        if IsValid(ent) and ent.ApplyFrozenState then
            ent:ApplyFrozenState(ent:GetIsFrozen(), false)
        end
    end)

    return ent
end

function ZSCAV:RestoreAllPlayerStashesForMap(mapName)
    mapName = tostring(mapName or game.GetMap() or "")
    if mapName == "" then return 0 end

    local row = self:GetSharedWorldStashRow(mapName)
    if not row or not HasStashWorldLocation(row) then
        return 0
    end

    local savedRow, rowErr = self:EnsureSharedWorldStashRow(mapName, row)
    if not savedRow then
        ErrorNoHalt("[ZScav] Failed to persist shared stash row for map restore: " .. tostring(rowErr or "unknown") .. "\n")
        savedRow = row
    end

    return IsValid(self:SpawnPlayerStashFromRow(savedRow)) and 1 or 0
end

function ZSCAV:SpawnPlayerStashForPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return nil, "invalid_player" end

    local tr = util.TraceLine({
        start  = ply:EyePos(),
        endpos = ply:EyePos() + ply:EyeAngles():Forward() * 120,
        filter = ply,
        mask   = MASK_SOLID,
    })
    local pos = tr.HitPos + Vector(0, 0, 8)
    local ang = Angle(0, ply:EyeAngles().y, 0)

    local ent = FindSpawnedSharedStash()
    if not IsValid(ent) then
        ent = ents.Create(STASH_CLASS)
        if not IsValid(ent) then return nil, "create_failed" end
        ent:SetOwnerSID64(STASH_SHARED_WORLD_OWNER)
        ent:SetBagUID("")
        ent:SetPos(pos)
        ent:SetAngles(ang)
        ent:SetIsFrozen(true)
        ent:Spawn()
        ent:Activate()
    else
        ent:SetOwnerSID64(STASH_SHARED_WORLD_OWNER)
        if ent.SetBagUID and ent:GetBagUID() ~= "" then
            ent:SetBagUID("")
        end
        ent:SetPos(pos)
        ent:SetAngles(ang)
    end

    if ent.ApplyFrozenState then
        ent:ApplyFrozenState(true, false)
    end
    self:SavePlayerStashEntity(ent)
    return ent
end

concommand.Add("zscav_stash_spawn", function(ply)
    if not IsValid(ply) then
        print("[ZScav] zscav_stash_spawn must be run by a player.")
        return
    end
    local ent, err = ZSCAV:SpawnPlayerStashForPlayer(ply)
    if not IsValid(ent) then
        if tostring(err or "") == "stash_loading" then
            ply:ChatPrint("[ZScav] Stash data is still loading, try again in a moment.")
            return
        end
        ply:ChatPrint("[ZScav] Failed to spawn stash: " .. tostring(err or "unknown"))
        return
    end
    ply:ChatPrint("[ZScav] Shared stash placed for this map (inventory remains per-player across maps).")
end)

concommand.Add("zscav_stash_freeze", function(ply, _, args)
    if not IsValid(ply) then return end

    local ent = FindSpawnedSharedStash()
    if not IsValid(ent) then
        ply:ChatPrint("[ZScav] No shared stash found. Use zscav_stash_spawn first.")
        return
    end

    local arg = tostring(args[1] or "toggle"):lower()
    local want
    if arg == "1" or arg == "true" or arg == "on" then
        want = true
    elseif arg == "0" or arg == "false" or arg == "off" then
        want = false
    else
        want = not ent:GetIsFrozen()
    end

    if ent.ApplyFrozenState then
        ent:ApplyFrozenState(want, true)
    else
        ent:SetIsFrozen(want)
        ZSCAV:SavePlayerStashEntity(ent)
    end

    ply:ChatPrint("[ZScav] Stash " .. (want and "frozen" or "unfrozen") .. ".")
end)

concommand.Add("zscav_stash_remove", function(ply)
    if not IsValid(ply) then return end
    local ok = ZSCAV:DeletePlayerStash(STASH_SHARED_WORLD_OWNER, game.GetMap(), false)
    if ok then
        ply:ChatPrint("[ZScav] Shared stash removed from this map (player contents preserved).")
    else
        ply:ChatPrint("[ZScav] Failed to remove shared stash.")
    end
end)

concommand.Add("zscav_stash_selftest", function(ply)
    if not IsValid(ply) then
        print("[ZScav][StashTest] Must be run by a player.")
        return
    end

    local results = {}
    local function Pass(msg)
        results[#results + 1] = "PASS: " .. msg
    end
    local function Fail(msg)
        results[#results + 1] = "FAIL: " .. msg
    end

    local ownerSID64 = tostring(ply:SteamID64() or "")
    if ownerSID64 == "" then
        Fail("Missing SteamID64")
        for _, line in ipairs(results) do ply:ChatPrint("[ZScav][StashTest] " .. line) end
        return
    end

    if STASH_MYSQL_READY and IsStashMySQLUsable() then
        Pass("Backend: MySQL (ZBattle-accessible path)")
    else
        Fail("Backend: SQLite fallback active (MySQL path not ready)")
    end

    local w, h = ZSCAV:GetContainerGridSize(STASH_CLASS)
    if w == 10 and h == 64 then
        Pass("Container size override is 10x64")
    else
        Fail("Container size override expected 10x64, got " .. tostring(w) .. "x" .. tostring(h))
    end

    local ent = FindSpawnedSharedStash()
    if not IsValid(ent) then
        local spawned, err = ZSCAV:SpawnPlayerStashForPlayer(ply)
        ent = spawned
        if not IsValid(ent) then
            Fail("Failed to spawn stash: " .. tostring(err or "unknown"))
            for _, line in ipairs(results) do ply:ChatPrint("[ZScav][StashTest] " .. line) end
            return
        end
        Pass("Spawned stash entity")
    else
        Pass("Found existing stash entity")
    end

    if ent:GetClass() == STASH_CLASS then
        Pass("Stash class is " .. STASH_CLASS)
    else
        Fail("Unexpected stash class: " .. tostring(ent:GetClass()))
    end

    local expectedModel = "models/props/cs_militia/boxes_frontroom.mdl"
    if string.lower(tostring(ent:GetModel() or "")) == expectedModel then
        Pass("Stash model is boxes_frontroom")
    else
        Fail("Stash model mismatch: " .. tostring(ent:GetModel() or "nil"))
    end

    local frozen = ent.GetIsFrozen and ent:GetIsFrozen() or false
    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    local uid, uidErr = ZSCAV:GetCanonicalPlayerStashUID(ownerSID64, true)
    uid = tostring(uid or "")

    if tostring(uidErr or "") == "stash_loading" then
        Fail("Canonical stash UID still loading")
    elseif uid ~= "" then
        Pass("Canonical stash UID resolves for player")
    else
        Fail("Canonical stash UID missing for player")
    end

    if ZSCAV:SavePlayerStashEntity(ent) then
        Pass("Saved stash row to SQL")
    else
        Fail("SavePlayerStashEntity returned false")
    end

    local row = ZSCAV:GetSharedWorldStashRow(game.GetMap())
    if not istable(row) then
        Fail("SQL row not found after save")
        for _, line in ipairs(results) do ply:ChatPrint("[ZScav][StashTest] " .. line) end
        return
    else
        Pass("Shared stash row exists for map")
    end

    local savedFrozen = tonumber(row.frozen) == 1
    if savedFrozen == frozen then
        Pass("Frozen state persisted")
    else
        Fail("Frozen state mismatch between entity and SQL")
    end

    local bag = ZSCAV:LoadBag(uid)
    if istable(bag) then
        Pass("Player stash bag UID resolves in zscav_bags")
    else
        Fail("Player stash bag UID does not resolve in zscav_bags")
    end

    ent.zscav_skip_save = true
    ent:Remove()
    local restored = ZSCAV:SpawnPlayerStashFromRow(row)
    if not IsValid(restored) then
        Fail("Restore from SQL row failed")
    else
        Pass("Restore from SQL row succeeded")

        if tostring(restored:GetOwnerSID64() or "") == STASH_SHARED_WORLD_OWNER then
            Pass("Restored stash is marked as shared world stash")
        else
            Fail("Restored stash owner marker is not shared")
        end

        local restoredPos = restored:GetPos()
        local restoredAng = restored:GetAngles()
        if restoredPos:Distance(pos) <= 1 then
            Pass("Position restored")
        else
            Fail("Position mismatch after restore")
        end

        local yawDelta = math.abs(math.AngleDifference(restoredAng.y, ang.y))
        if yawDelta <= 1 then
            Pass("Angles restored")
        else
            Fail("Angle mismatch after restore")
        end

        local restoredFrozen = restored.GetIsFrozen and restored:GetIsFrozen() or false
        if restoredFrozen == frozen then
            Pass("Frozen state restored")
        else
            Fail("Frozen state mismatch after restore")
        end
    end

    local passCount = 0
    local failCount = 0
    for _, line in ipairs(results) do
        if string.sub(line, 1, 4) == "PASS" then
            passCount = passCount + 1
        else
            failCount = failCount + 1
        end
        ply:ChatPrint("[ZScav][StashTest] " .. line)
    end
    ply:ChatPrint("[ZScav][StashTest] Summary: " .. passCount .. " passed, " .. failCount .. " failed")
end)

hook.Add("InitPostEntity", "ZSCAV_RestorePlayerStashes_Init", function()
    timer.Simple(0, function()
        ZSCAV:RestoreAllPlayerStashesForMap(game.GetMap())
    end)
end)

hook.Add("PostCleanupMap", "ZSCAV_RestorePlayerStashes_Cleanup", function()
    timer.Simple(0, function()
        ZSCAV:RestoreAllPlayerStashesForMap(game.GetMap())
    end)
end)

hook.Add("ShutDown", "ZSCAV_SavePlayerStashes_Shutdown", function()
    for _, ent in ipairs(ents.FindByClass(STASH_CLASS)) do
        if IsValid(ent) then
            ZSCAV:SavePlayerStashEntity(ent)
        end
    end
end)
