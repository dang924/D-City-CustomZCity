-- sv_mysql_nil_guard.lua
-- DCityPatch1.1
--
-- ZCity's sv_mysql.lua:546 crashes with "attempt to index field 'connection' (a nil value)"
-- when MySQL is not connected. This fires inside guilt_SetValue and GiveExp during EndRound,
-- crashing the save and causing the round system to loop because EndRound never cleanly finishes.
--
-- This patch wraps mysql.Execute / hg.mysql.Execute (entry points for ZCity DB calls) to silently
-- no-op when the connection is nil rather than hard-erroring mid-round.

if CLIENT then return end

local SQL_CFG_PATH = "zbattle/sql.json"
local _dcpLastConfigWarn = 0
local _dcpLastModuleWarn = 0
local _dcpModuleMissing = false

local function ForceSQLConfigMySQL()
    local cfgRaw = file.Exists(SQL_CFG_PATH, "DATA") and file.Read(SQL_CFG_PATH, "DATA") or nil
    local cfg = isstring(cfgRaw) and util.JSONToTable(cfgRaw) or {}
    if not istable(cfg) then cfg = {} end

    local changed = false
    if cfg.dbmodule ~= "mysqloo" then
        cfg.dbmodule = "mysqloo"
        changed = true
    end

    if changed then
        file.CreateDir("zbattle")
        file.Write(SQL_CFG_PATH, util.TableToJSON(cfg, true))
        print("[DCP] sv_mysql_nil_guard: forced zbattle/sql.json dbmodule to mysqloo")
    end
end

local function ReadSQLConfig()
    local cfgRaw = file.Exists(SQL_CFG_PATH, "DATA") and file.Read(SQL_CFG_PATH, "DATA") or nil
    local cfg = isstring(cfgRaw) and util.JSONToTable(cfgRaw) or nil
    if not istable(cfg) then return nil end
    return cfg
end

local function IsPlaceholder(v)
    v = string.lower(tostring(v or ""))
    if v == "" then return true end
    return string.find(v, "your_", 1, true) ~= nil
end

local function HasUsableSQLConfig(cfg)
    if not istable(cfg) then return false end
    if IsPlaceholder(cfg.hostname) or IsPlaceholder(cfg.username) or IsPlaceholder(cfg.database) then
        return false
    end
    return true
end

local function IsMySQLConnected()
    if istable(mysql) and isfunction(mysql.IsConnected) then
        local ok, connected = pcall(mysql.IsConnected, mysql)
        if ok and connected then return true end
    end

    if hg and istable(hg.mysql) and isfunction(hg.mysql.IsConnected) then
        local ok, connected = pcall(hg.mysql.IsConnected, hg.mysql)
        if ok and connected then return true end
    end

    return false
end

local function IsMysqlooInstalled()
    if not util or not util.IsBinaryModuleInstalled then return true end
    local ok, installed = pcall(util.IsBinaryModuleInstalled, "mysqloo")
    if not ok then return true end
    return installed and true or false
end

local function TryReconnectMySQL(reason)
    if IsMySQLConnected() then return end

    if _dcpModuleMissing then return end

    if not IsMysqlooInstalled() then
        _dcpModuleMissing = true
        if CurTime() - _dcpLastModuleWarn > 30 then
            _dcpLastModuleWarn = CurTime()
            ErrorNoHalt("[DCP] MySQL offline: mysqloo module is missing. Ask host to install mysqloo for this server build (gmsv_mysqloo).\n")
        end
        return
    end

    local cfg = ReadSQLConfig()
    if not HasUsableSQLConfig(cfg) then
        if CurTime() - _dcpLastConfigWarn > 30 then
            _dcpLastConfigWarn = CurTime()
            ErrorNoHalt("[DCP] MySQL not connected: check data/zbattle/sql.json hostname/username/database values and mysqloo module install.\n")
        end
        return
    end

    if hg and hg.db and isfunction(hg.db.Connect) then
        local ok, err = pcall(hg.db.Connect)
        if not ok then
            local errText = string.lower(tostring(err or ""))
            if string.find(errText, "module not found", 1, true) or string.find(errText, "mysqloo", 1, true) then
                _dcpModuleMissing = true
                ErrorNoHalt("[DCP] MySQL offline: mysqloo module not found. Host must install gmsv_mysqloo for your branch/OS.\n")
                return
            end
            ErrorNoHalt("[DCP] MySQL reconnect attempt failed (" .. tostring(reason or "unknown") .. "): " .. tostring(err) .. "\n")
            return
        end
        print("[DCP] MySQL reconnect attempt triggered (" .. tostring(reason or "unknown") .. ")")
    end
end

local function ForceSetModuleMySQL(dbObj, tag)
    if not istable(dbObj) then return false end

    if dbObj.module ~= "mysqloo" then
        dbObj.module = "mysqloo"
        print("[DCP] sv_mysql_nil_guard: forced " .. tostring(tag or "db") .. ".module to mysqloo")
    end

    if dbObj._DCP_SetModuleMySQLForced then return true end

    local origSetModule = dbObj.SetModule
    if isfunction(origSetModule) then
        dbObj.SetModule = function(self, moduleName, ...)
            if moduleName ~= "mysqloo" then
                moduleName = "mysqloo"
            end
            return origSetModule(self, moduleName, ...)
        end
    end

    dbObj._DCP_SetModuleMySQLForced = true
    return true
end

local function PatchExecuteTable(dbObj, tag)
    if not istable(dbObj) then return false end
    if dbObj._DCP_NilGuarded then return true end

    local origExecute = dbObj.Execute
    if not isfunction(origExecute) then return false end

    dbObj.Execute = function(self, query, callback, ...)
        -- If connection is nil, ZCity would crash at sv_mysql.lua:546.
        -- Silently skip and optionally fire the callback with a failure signal.
        if not self or not self.connection then
            if isfunction(callback) then
                -- Pass nil result + error string so callers that check can handle it.
                pcall(callback, nil, "MySQL not connected")
            end
            return
        end
        return origExecute(self, query, callback, ...)
    end

    dbObj._DCP_NilGuarded = true
    print("[DCP] sv_mysql_nil_guard: " .. tostring(tag or "db") .. ".Execute patched (connection nil guard active)")
    return true
end

local function PatchRawQueryTable(dbObj, tag)
    if not istable(dbObj) then return false end
    if dbObj._DCP_RawQueryNilGuarded then return true end

    local origRawQuery = dbObj.RawQuery
    if not isfunction(origRawQuery) then return false end

    dbObj.RawQuery = function(self, query, callback, ...)
        local conn = self and self.connection
        if not conn or not isfunction(conn.query) then
            if isfunction(callback) then
                pcall(callback, nil, false, nil, "MySQL not connected")
            end
            return
        end

        return origRawQuery(self, query, callback, ...)
    end

    dbObj._DCP_RawQueryNilGuarded = true
    print("[DCP] sv_mysql_nil_guard: " .. tostring(tag or "db") .. ".RawQuery patched (connection nil guard active)")
    return true
end

local function PatchMySQLExecute()
    local ok = false

    ForceSQLConfigMySQL()

    -- Base Homigrad mysql wrapper object used by sv_mysql.lua
    if istable(mysql) then
        ForceSetModuleMySQL(mysql, "mysql")
        ok = PatchExecuteTable(mysql, "mysql") or ok
        ok = PatchRawQueryTable(mysql, "mysql") or ok
    end

    -- Some forks keep a mirror reference under hg.mysql
    if hg and istable(hg.mysql) then
        ForceSetModuleMySQL(hg.mysql, "hg.mysql")
        ok = PatchExecuteTable(hg.mysql, "hg.mysql") or ok
        ok = PatchRawQueryTable(hg.mysql, "hg.mysql") or ok
    end

    return ok
end

local function TryPatchMySQL()
    -- Do NOT remove the timer on success: ZCity may replace hg.mysql after a
    -- reconnect attempt, blowing away our patch on the old object. The timer
    -- must keep running indefinitely to re-patch whenever that happens.
    PatchMySQLExecute()
end

-- Try immediately in case mysql/hg.mysql is already populated at file load
TryPatchMySQL()

hook.Add("InitPostEntity", "DCP_MySQLNilGuard_Init", function()
    TryPatchMySQL()
    TryReconnectMySQL("init")
    timer.Simple(1, TryPatchMySQL)
    timer.Simple(3, TryPatchMySQL)
    timer.Simple(2, function() TryReconnectMySQL("init+2") end)
    timer.Simple(5, function() TryReconnectMySQL("init+5") end)
end)

-- Defer via timer.Simple(0) so our patch fires AFTER ZCity finishes
-- reinitializing mysql/hg.mysql in the same HomigradRun execution chain.
hook.Add("HomigradRun", "DCP_MySQLNilGuard_HG", function()
    TryPatchMySQL()
    timer.Simple(0,   TryPatchMySQL)
    timer.Simple(0.5, TryPatchMySQL)
    timer.Simple(1, function() TryReconnectMySQL("homigrad") end)
end)

hook.Add("DatabaseConnectionFailed", "DCP_MySQLNilGuard_ReconnectOnFail", function(err)
    ErrorNoHalt("[DCP] DatabaseConnectionFailed: " .. tostring(err) .. "\n")
    timer.Simple(2, function() TryReconnectMySQL("db_fail") end)
end)

hook.Add("DatabaseConnected", "DCP_MySQLNilGuard_DBConnected", function()
    _dcpModuleMissing = false
    print("[DCP] DatabaseConnected: MySQL is active.")
end)

-- Run indefinitely (0 iterations) — ZCity can replace mysql objects at any time.
timer.Create("DCP_MySQLNilGuardRetry", 2, 0, TryPatchMySQL)
timer.Create("DCP_MySQLReconnectRetry", 15, 0, function()
    TryPatchMySQL()
    TryReconnectMySQL("retry_timer")
end)

-- ── Belt-and-suspenders: pcall wrap on zb.KillPlayers ────────────────────────
-- Even when mysql.Execute is guarded, GiveExp may crash through a code path
-- that caches the original Execute in a local. Wrapping zb.KillPlayers ensures
-- the round end sequence always completes so the round loop stops.
local function PatchKillPlayers()
    if not zb or not zb.KillPlayers then return false end
    if zb._DCP_KillPlayersGuarded then return true end

    local orig = zb.KillPlayers
    zb.KillPlayers = function(self, ...)
        local ok, err = xpcall(orig, debug.traceback, self, ...)
        if not ok then
            ErrorNoHalt("[DCP] KillPlayers caught error (MySQL offline?): " .. tostring(err) .. "\n")
        end
    end
    zb._DCP_KillPlayersGuarded = true
    print("[DCP] sv_mysql_nil_guard: zb.KillPlayers pcall guard active")
    return true
end

-- ── Belt-and-suspenders: pcall wrap on zb.EndRound ───────────────────────────
-- guilt_SetValue fires from the ZB_EndRound hook at sv_roundsystem.lua:87,
-- which is INSIDE zb:EndRound() before KillPlayers is called.
-- The KillPlayers pcall doesn't cover it. Wrap EndRound itself so the entire
-- round-end path is protected and the loop always terminates cleanly.
local function PatchEndRound()
    if not zb or not zb.EndRound then return false end
    if zb._DCP_EndRoundGuarded then return true end

    local orig = zb.EndRound
    zb.EndRound = function(self, ...)
        local ok, err = xpcall(orig, debug.traceback, self, ...)
        if not ok then
            -- Only log if it's actually a MySQL error to avoid swallowing real bugs.
            if string.find(tostring(err), "connection", 1, true)
            or string.find(tostring(err), "mysql", 1, true) then
                ErrorNoHalt("[DCP] EndRound MySQL error (offline?): " .. tostring(err) .. "\n")
            else
                ErrorNoHalt("[DCP] EndRound error: " .. tostring(err) .. "\n")
            end
        end
    end
    zb._DCP_EndRoundGuarded = true
    print("[DCP] sv_mysql_nil_guard: zb.EndRound pcall guard active")
    return true
end

-- ── guilt_SetValue direct guard ───────────────────────────────────────────────
-- guilt_SetValue calls mysql.Execute directly via a local-captured reference in some forks.
-- Our Execute wrapper covers active objects, but if ZCity replaced references between
-- timer ticks the old reference can still be used and escape the wrapper. Guard here too.
-- used and escapes the wrapper. Guard guilt_SetValue at the source.
local function PatchGuiltSetValue()
    if not guilt_SetValue or guilt_SetValue._DCP_GuiltGuarded then return false end
    local orig = guilt_SetValue
    _G.guilt_SetValue = function(ply, key, value)
        if not IsValid(ply) then return end
        local dbObj = nil
        if istable(mysql) then
            dbObj = mysql
        elseif hg and istable(hg.mysql) then
            dbObj = hg.mysql
        end
        if not dbObj or not dbObj.connection then return end
        return orig(ply, key, value)
    end
    _G.guilt_SetValue._DCP_GuiltGuarded = true
    print("[DCP] sv_mysql_nil_guard: guilt_SetValue nil guard active")
    return true
end

local function PatchAllRoundEndPaths()
    PatchKillPlayers()
    PatchEndRound()
    PatchGuiltSetValue()
end

hook.Add("InitPostEntity", "DCP_KillPlayersGuard_Init", function()
    timer.Simple(2, PatchAllRoundEndPaths)
end)
hook.Add("HomigradRun", "DCP_KillPlayersGuard_HG", function()
    timer.Simple(0, PatchAllRoundEndPaths)
    timer.Simple(0.5, PatchAllRoundEndPaths)
end)
timer.Create("DCP_KillPlayersGuardRetry", 3, 0, PatchAllRoundEndPaths)
