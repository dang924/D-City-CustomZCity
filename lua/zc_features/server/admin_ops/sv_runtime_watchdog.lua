-- sv_runtime_watchdog.lua
-- Lightweight crash breadcrumb writer for silent exits.

if CLIENT then return end

local WATCHDOG_DIR = "zc_watchdog"
local STATUS_FILE = WATCHDOG_DIR .. "/status.json"
local PULSE_INTERVAL = 10

local function safeRoundName()
    if isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) and round.name then
            return tostring(round.name)
        end
    end

    if istable(zb) and zb.CROUND then
        return tostring(zb.CROUND)
    end

    return "unknown"
end

local function makeStatus(eventName, cleanShutdown)
    local status = {
        event = tostring(eventName or "pulse"),
        map = game.GetMap(),
        players = #player.GetAll(),
        humans = #player.GetHumans(),
        round = safeRoundName(),
        realtime = RealTime(),
        systime = SysTime(),
        unix = os.time(),
        iso = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        cleanShutdown = cleanShutdown == true,
    }

    return status
end

local function writeStatus(eventName, cleanShutdown)
    local ok, err = pcall(function()
        if not file.Exists(WATCHDOG_DIR, "DATA") then
            file.CreateDir(WATCHDOG_DIR)
        end

        file.Write(STATUS_FILE, util.TableToJSON(makeStatus(eventName, cleanShutdown), true) or "{}")
    end)

    if not ok then
        ErrorNoHalt("[ZC Watchdog] Write failed: " .. tostring(err) .. "\n")
    end
end

local function readPreviousStatus()
    if not file.Exists(STATUS_FILE, "DATA") then return nil end

    local raw = file.Read(STATUS_FILE, "DATA")
    if not isstring(raw) or raw == "" then return nil end

    local ok, tbl = pcall(util.JSONToTable, raw)
    if not ok or not istable(tbl) then return nil end

    return tbl
end

hook.Add("InitPostEntity", "ZC_RuntimeWatchdog_Init", function()
    local prev = readPreviousStatus()
    if istable(prev) and prev.cleanShutdown == false then
        print("[ZC Watchdog] Previous run appears unclean. Last event=" .. tostring(prev.event)
            .. " map=" .. tostring(prev.map)
            .. " round=" .. tostring(prev.round)
            .. " iso=" .. tostring(prev.iso))
    end

    writeStatus("init", false)
end)

hook.Add("ShutDown", "ZC_RuntimeWatchdog_Shutdown", function()
    writeStatus("shutdown", true)
end)

hook.Add("DatabaseConnectionFailed", "ZC_RuntimeWatchdog_DBFail", function(err)
    writeStatus("db_fail:" .. tostring(err), false)
end)

hook.Add("DatabaseConnected", "ZC_RuntimeWatchdog_DBOK", function()
    writeStatus("db_connected", false)
end)

timer.Create("ZC_RuntimeWatchdog_Pulse", PULSE_INTERVAL, 0, function()
    writeStatus("pulse", false)
end)
