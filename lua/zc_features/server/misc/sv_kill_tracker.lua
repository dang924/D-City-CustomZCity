-- Tracks all-time cross-faction player kills in coop via MySQL.
--   cmb_kill  = Combine players killed while attacker was Rebel
--   reb_kill  = Rebel players killed while attacker was Combine
--   ply_death = deaths to an opposing-faction player
--   all_kd    = (cmb_kill + reb_kill) / ply_death

if CLIENT then return end
if not ZC_IsPatchRebelPlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

local initialized = false
local sqlReady = false
local tableReady = false
local statsLoaded = false
local tableCreateInFlight = false
local statsLoadInFlight = false

local stats = {}
local dirtyRows = {}
local pendingEvents = {}
local lastAttacker = {}

local function ResolvePlayerFromEntity(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then return ent end

    if IsValid(ent.ply) and ent.ply:IsPlayer() then
        return ent.ply
    end

    if hg and hg.RagdollOwner then
        local owner = hg.RagdollOwner(ent)
        if IsValid(owner) and owner:IsPlayer() then
            return owner
        end
    end

    if ent.GetNWEntity then
        local owner = ent:GetNWEntity("RagdollOwner")
        if IsValid(owner) and owner:IsPlayer() then
            return owner
        end
    end

    if ent.GetOwner then
        local owner = ent:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            return owner
        end
    end

    return nil
end

local function ResolvePlayerAttacker(attacker, inflictor)
    local resolved = ResolvePlayerFromEntity(attacker)
    if IsValid(resolved) then return resolved end

    resolved = ResolvePlayerFromEntity(inflictor)
    if IsValid(resolved) then return resolved end

    return nil
end

local function IsTrackedRebelPlayer(ply)
    return ZC_IsPatchRebelPlayer and ZC_IsPatchRebelPlayer(ply) == true
end

local function IsTrackedCombinePlayer(ply)
    return ZC_IsPatchCombinePlayer and ZC_IsPatchCombinePlayer(ply) == true
end

local function IsTrackedCrossFactionKill(attacker, victim)
    return (IsTrackedRebelPlayer(attacker) and IsTrackedCombinePlayer(victim))
        or (IsTrackedCombinePlayer(attacker) and IsTrackedRebelPlayer(victim))
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

local function IsMySQLReady()
    if not istable(mysql) or not isfunction(mysql.IsConnected) then return false end

    local ok, connected = pcall(mysql.IsConnected, mysql)
    return ok and connected == true
end

local function BuildEmptyRow(steamID64, steamName)
    return {
        steamid = tostring(steamID64 or ""),
        steam_name = tostring(steamName or ""),
        cmb_kill = 0,
        reb_kill = 0,
        ply_death = 0,
        all_kd = 0
    }
end

local function GetTotalKills(row)
    return (tonumber(row.cmb_kill) or 0) + (tonumber(row.reb_kill) or 0)
end

local function RecalculateAllKD(row)
    if not istable(row) then return 0 end

    local totalKills = GetTotalKills(row)
    local deaths = tonumber(row.ply_death) or 0

    if deaths <= 0 then
        row.all_kd = totalKills
    else
        row.all_kd = math.Round(totalKills / deaths, 2)
    end

    return row.all_kd
end

local function GetOrCreateRowByID(steamID64, steamName)
    steamID64 = tostring(steamID64 or "")
    if steamID64 == "" then return nil end

    stats[steamID64] = stats[steamID64] or BuildEmptyRow(steamID64, steamName)

    if steamName and steamName ~= "" then
        stats[steamID64].steam_name = tostring(steamName)
    end

    RecalculateAllKD(stats[steamID64])
    return stats[steamID64]
end

local function GetOrCreateRowByPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() or ply:IsBot() then return nil end
    return GetOrCreateRowByID(ply:SteamID64(), ply:Nick())
end

local function MarkDirty(steamID64)
    steamID64 = tostring(steamID64 or "")
    if steamID64 == "" then return end
    dirtyRows[steamID64] = true
end

local function UpsertRow(steamID64)
    if not sqlReady or not tableReady or not statsLoaded then return false end

    local row = stats[tostring(steamID64 or "")]
    if not row then return false end

    RecalculateAllKD(row)

    local insertQuery = mysql:InsertIgnore("hg_factionkd")
    insertQuery:Insert("steamid", row.steamid)
    insertQuery:Insert("steam_name", row.steam_name)
    insertQuery:Insert("cmb_kill", tonumber(row.cmb_kill) or 0)
    insertQuery:Insert("reb_kill", tonumber(row.reb_kill) or 0)
    insertQuery:Insert("ply_death", tonumber(row.ply_death) or 0)
    insertQuery:Insert("all_kd", string.format("%.2f", tonumber(row.all_kd) or 0))
    insertQuery:Execute()

    local updateQuery = mysql:Update("hg_factionkd")
    updateQuery:Update("steam_name", row.steam_name)
    updateQuery:Update("cmb_kill", tonumber(row.cmb_kill) or 0)
    updateQuery:Update("reb_kill", tonumber(row.reb_kill) or 0)
    updateQuery:Update("ply_death", tonumber(row.ply_death) or 0)
    updateQuery:Update("all_kd", string.format("%.2f", tonumber(row.all_kd) or 0))
    updateQuery:Where("steamid", row.steamid)
    updateQuery:Execute()

    dirtyRows[row.steamid] = nil
    return true
end

local function FlushDirtyRows()
    if not sqlReady or not tableReady or not statsLoaded then return end

    local keys = {}
    for steamID64 in pairs(dirtyRows) do
        keys[#keys + 1] = steamID64
    end

    for _, steamID64 in ipairs(keys) do
        UpsertRow(steamID64)
    end
end

local function ApplyPendingEvents()
    if #pendingEvents == 0 then return end

    local queued = pendingEvents
    pendingEvents = {}

    for _, event in ipairs(queued) do
        local attackerRow = GetOrCreateRowByID(event.attackerSteamID64, event.attackerName)
        local victimRow = GetOrCreateRowByID(event.victimSteamID64, event.victimName)

        if attackerRow and victimRow then
            if event.attackerIsRebel then
                attackerRow.cmb_kill = (tonumber(attackerRow.cmb_kill) or 0) + 1
            else
                attackerRow.reb_kill = (tonumber(attackerRow.reb_kill) or 0) + 1
            end

            victimRow.ply_death = (tonumber(victimRow.ply_death) or 0) + 1

            RecalculateAllKD(attackerRow)
            RecalculateAllKD(victimRow)

            MarkDirty(attackerRow.steamid)
            MarkDirty(victimRow.steamid)
        end
    end

    FlushDirtyRows()
end

local function EnsurePlayerRow(ply)
    local row = GetOrCreateRowByPlayer(ply)
    if not row then return end

    MarkDirty(row.steamid)
    FlushDirtyRows()
end

local function LoadAllStats()
    if not sqlReady or not tableReady or statsLoadInFlight or statsLoaded then return end

    statsLoadInFlight = true

    local query = mysql:Select("hg_factionkd")
    query:Callback(function(result)
        local loaded = {}

        if istable(result) then
            for _, raw in ipairs(result) do
                local steamID64 = tostring(raw.steamid or "")
                if steamID64 == "" then continue end

                loaded[steamID64] = {
                    steamid = steamID64,
                    steam_name = tostring(raw.steam_name or ""),
                    cmb_kill = tonumber(raw.cmb_kill) or 0,
                    reb_kill = tonumber(raw.reb_kill) or 0,
                    ply_death = tonumber(raw.ply_death) or 0,
                    all_kd = tonumber(raw.all_kd) or 0
                }

                RecalculateAllKD(loaded[steamID64])
            end
        end

        stats = loaded
        statsLoaded = true
        statsLoadInFlight = false

        for _, ply in ipairs(player.GetHumans()) do
            EnsurePlayerRow(ply)
        end

        ApplyPendingEvents()

        print("[ZC KillTracker] Loaded " .. tostring(table.Count(stats)) .. " faction KD rows from MySQL.")
    end)
    query:Execute()
end

local EXPECTED_COLUMNS = {
    {
        name = "steamid",
        definition = "VARCHAR(20) NOT NULL",
        position = 1,
        positionSql = "FIRST"
    },
    {
        name = "steam_name",
        definition = "VARCHAR(32) NOT NULL",
        position = 2,
        positionSql = "AFTER `steamid`"
    },
    {
        name = "cmb_kill",
        definition = "INT NOT NULL DEFAULT 0",
        position = 3,
        positionSql = "AFTER `steam_name`"
    },
    {
        name = "reb_kill",
        definition = "INT NOT NULL DEFAULT 0",
        position = 4,
        positionSql = "AFTER `cmb_kill`"
    },
    {
        name = "ply_death",
        definition = "INT NOT NULL DEFAULT 0",
        position = 5,
        positionSql = "AFTER `reb_kill`"
    },
    {
        name = "all_kd",
        definition = "DECIMAL(10,2) NOT NULL DEFAULT 0",
        position = 6,
        positionSql = "AFTER `ply_death`"
    }
}

local function NormalizeColumnType(typeText)
    return string.lower(string.Trim(tostring(typeText or "")))
end

local function ColumnNeedsFix(expected, row, currentPosition)
    if not row then return true end

    local typeText = NormalizeColumnType(row.Type or row.type)
    local nullText = string.upper(tostring(row.Null or row.null or ""))

    if expected.name == "steamid" and typeText ~= "varchar(20)" then return true end
    if expected.name == "steam_name" and typeText ~= "varchar(32)" then return true end
    if (expected.name == "cmb_kill" or expected.name == "reb_kill" or expected.name == "ply_death") and string.sub(typeText, 1, 3) ~= "int" then
        return true
    end
    if expected.name == "all_kd" and typeText ~= "decimal(10,2)" then return true end
    if nullText ~= "NO" then return true end
    if currentPosition ~= expected.position then return true end

    return false
end

local function FinishTableSetup()
    tableReady = true
    tableCreateInFlight = false
    LoadAllStats()
end

local function EnforceStatsTableSchema()
    mysql:RawQuery("SHOW COLUMNS FROM `hg_factionkd`", function(result)
        local columns = {}
        local positions = {}

        if istable(result) then
            for index, row in ipairs(result) do
                local name = string.lower(tostring(row.Field or row.field or ""))
                if name ~= "" then
                    columns[name] = row
                    positions[name] = index
                end
            end
        end

        local clauses = {}

        for _, expected in ipairs(EXPECTED_COLUMNS) do
            local row = columns[expected.name]
            local currentPosition = positions[expected.name]

            if not row then
                clauses[#clauses + 1] = string.format(
                    "ADD COLUMN `%s` %s %s",
                    expected.name,
                    expected.definition,
                    expected.positionSql
                )
            elseif ColumnNeedsFix(expected, row, currentPosition) then
                clauses[#clauses + 1] = string.format(
                    "MODIFY COLUMN `%s` %s %s",
                    expected.name,
                    expected.definition,
                    expected.positionSql
                )
            end
        end

        if #clauses == 0 then
            FinishTableSetup()
            return
        end

        local alterQuery = "ALTER TABLE `hg_factionkd` " .. table.concat(clauses, ", ")
        mysql:RawQuery(alterQuery, function()
            print("[ZC KillTracker] Enforced exact hg_factionkd schema.")
            FinishTableSetup()
        end)
    end)
end

local function CreateStatsTable()
    if not sqlReady or tableReady or tableCreateInFlight then return end

    tableCreateInFlight = true

    local query = mysql:Create("hg_factionkd")
    query:Create("steamid", "VARCHAR(20) NOT NULL")
    query:Create("steam_name", "VARCHAR(32) NOT NULL")
    query:Create("cmb_kill", "INT NOT NULL DEFAULT 0")
    query:Create("reb_kill", "INT NOT NULL DEFAULT 0")
    query:Create("ply_death", "INT NOT NULL DEFAULT 0")
    query:Create("all_kd", "DECIMAL(10,2) NOT NULL DEFAULT 0")
    query:PrimaryKey("steamid")
    query:Callback(function()
        FinishTableSetup()
        EnforceStatsTableSchema()
    end)
    query:Execute()
end

local function RefreshSQLState()
    sqlReady = IsMySQLReady()

    if not sqlReady then return false end

    CreateStatsTable()

    if tableReady and not statsLoaded then
        LoadAllStats()
    end

    FlushDirtyRows()
    return true
end

local function QueuePendingEvent(attacker, victim)
    pendingEvents[#pendingEvents + 1] = {
        attackerSteamID64 = attacker:SteamID64(),
        attackerName = attacker:Nick(),
        attackerIsRebel = IsTrackedRebelPlayer(attacker),
        victimSteamID64 = victim:SteamID64(),
        victimName = victim:Nick()
    }
end

local function ProcessFactionDeath(attacker, victim)
    local attackerRow = GetOrCreateRowByPlayer(attacker)
    local victimRow = GetOrCreateRowByPlayer(victim)
    if not attackerRow or not victimRow then return end

    if IsTrackedRebelPlayer(attacker) then
        attackerRow.cmb_kill = (tonumber(attackerRow.cmb_kill) or 0) + 1
    else
        attackerRow.reb_kill = (tonumber(attackerRow.reb_kill) or 0) + 1
    end

    victimRow.ply_death = (tonumber(victimRow.ply_death) or 0) + 1

    RecalculateAllKD(attackerRow)
    RecalculateAllKD(victimRow)

    MarkDirty(attackerRow.steamid)
    MarkDirty(victimRow.steamid)
    FlushDirtyRows()
end

local function GetFactionDisplay(ply)
    local row = GetOrCreateRowByPlayer(ply)
    if not row then return "All-KD 0.00" end

    return string.format(
        "CMB %d | REB %d | Deaths %d | all-KD %.2f",
        tonumber(row.cmb_kill) or 0,
        tonumber(row.reb_kill) or 0,
        tonumber(row.ply_death) or 0,
        tonumber(row.all_kd) or 0
    )
end

local function BroadcastRoundStartStats(retryCount)
    if not IsCoopRoundActive() then return end

    retryCount = retryCount or 0

    timer.Simple(1, function()
        if not IsCoopRoundActive() then return end

        if not statsLoaded then
            if retryCount < 5 then
                BroadcastRoundStartStats(retryCount + 1)
            end
            return
        end

        local lines = {}
        for _, ply in ipairs(player.GetHumans()) do
            if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then continue end

            local row = GetOrCreateRowByPlayer(ply)
            local karma = math.Round(tonumber(ply.Karma) or 100, 0)
            lines[#lines + 1] = {
                name = ply:Nick(),
                karma = karma,
                allKD = row and (tonumber(row.all_kd) or 0) or 0
            }
        end

        if #lines == 0 then return end

        table.sort(lines, function(a, b)
            if a.allKD == b.allKD then
                return string.lower(a.name) < string.lower(b.name)
            end

            return a.allKD > b.allKD
        end)

        PrintMessage(HUD_PRINTTALK, "[KillTracker] Round-start Karma / all-KD:")

        for _, line in ipairs(lines) do
            PrintMessage(
                HUD_PRINTTALK,
                string.format("[KillTracker] %s - Karma %d | all-KD %.2f", line.name, line.karma, line.allKD)
            )
        end
    end)
end

local function PrintStats(ply)
    if not statsLoaded then
        ply:ChatPrint("[KillTracker] Stats are still loading from SQL.")
        return
    end

    local row = GetOrCreateRowByPlayer(ply)
    if not row or (GetTotalKills(row) == 0 and (tonumber(row.ply_death) or 0) == 0) then
        ply:ChatPrint("[KillTracker] No faction kills or deaths on record.")
        return
    end

    ply:ChatPrint("[KillTracker] All-time - " .. GetFactionDisplay(ply))
end

local function PrintLeaderboard(ply)
    if not statsLoaded then
        ply:ChatPrint("[KillTracker] Stats are still loading from SQL.")
        return
    end

    local list = {}
    for _, row in pairs(stats) do
        if GetTotalKills(row) > 0 or (tonumber(row.ply_death) or 0) > 0 then
            list[#list + 1] = row
        end
    end

    if #list == 0 then
        ply:ChatPrint("[KillTracker] No stats on record yet.")
        return
    end

    table.sort(list, function(a, b)
        local aKD = tonumber(a.all_kd) or 0
        local bKD = tonumber(b.all_kd) or 0

        if aKD == bKD then
            return GetTotalKills(a) > GetTotalKills(b)
        end

        return aKD > bKD
    end)

    ply:ChatPrint("[KillTracker] -- All-Time Faction KD Leaderboard --")

    for i, row in ipairs(list) do
        ply:ChatPrint(string.format(
            "  %d. %s - CMB %d | REB %d | Deaths %d | all-KD %.2f",
            i,
            tostring(row.steam_name or "Unknown"),
            tonumber(row.cmb_kill) or 0,
            tonumber(row.reb_kill) or 0,
            tonumber(row.ply_death) or 0,
            tonumber(row.all_kd) or 0
        ))

        if i >= 10 then break end
    end
end

local function Initialize()
    if initialized then
        RefreshSQLState()
        return
    end

    initialized = true
    RefreshSQLState()

    hook.Add("DatabaseConnected", "ZCity_KillTracker_DBConnected", function()
        RefreshSQLState()
    end)

    hook.Add("DatabaseConnectionFailed", "ZCity_KillTracker_DBFailed", function()
        sqlReady = false
    end)

    hook.Add("PlayerInitialSpawn", "ZCity_KillTracker_PlayerInitialSpawn", function(ply)
        timer.Simple(1, function()
            if not IsValid(ply) then return end
            EnsurePlayerRow(ply)
        end)
    end)

    hook.Add("HomigradDamage", "ZCity_KillTracker_TrackAttacker", function(ply, dmgInfo)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local attacker = ResolvePlayerAttacker(dmgInfo:GetAttacker(), dmgInfo:GetInflictor())
        if not IsValid(attacker) then return end
        if attacker == ply then return end

        if not IsTrackedCrossFactionKill(attacker, ply) then return end

        lastAttacker[ply:SteamID64()] = attacker
    end)

    hook.Add("PlayerDeath", "ZCity_KillTracker", function(victim, inflictor, attacker)
        if victim:Team() == TEAM_SPECTATOR then return end

        local trackedAttacker = lastAttacker[victim:SteamID64()]
        if IsValid(trackedAttacker) and trackedAttacker ~= victim then
            attacker = trackedAttacker
        else
            attacker = ResolvePlayerAttacker(attacker, inflictor)
        end

        lastAttacker[victim:SteamID64()] = nil

        if not IsValid(attacker) then return end
        if attacker == victim then return end

        if not IsTrackedCrossFactionKill(attacker, victim) then return end

        if not statsLoaded then
            QueuePendingEvent(attacker, victim)
            return
        end

        ProcessFactionDeath(attacker, victim)
        attacker:ChatPrint("[KillTracker] " .. victim:Nick() .. " killed - " .. GetFactionDisplay(attacker))
    end)

    hook.Add("ZB_StartRound", "ZCity_KillTracker_RoundStartStats", BroadcastRoundStartStats)

    hook.Add("HG_PlayerSay", "ZCity_KillTracker", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text))

        if cmd ~= "!killstats" and cmd ~= "/killstats" and
            cmd ~= "!killtop" and cmd ~= "/killtop" and
            cmd ~= "!killreset" and cmd ~= "/killreset" then return end

        txtTbl[1] = ""

        if cmd == "!killstats" or cmd == "/killstats" then
            PrintStats(ply)
            return
        end

        if cmd == "!killtop" or cmd == "/killtop" then
            PrintLeaderboard(ply)
            return
        end

        if not ply:IsSuperAdmin() then
            ply:ChatPrint("[KillTracker] Only superadmins can reset stats.")
            return
        end

        stats = {}
        dirtyRows = {}
        pendingEvents = {}

        if sqlReady and tableReady then
            local truncateQuery = mysql:Truncate("hg_factionkd")
            truncateQuery:Execute()
        end

        PrintMessage(HUD_PRINTTALK, "[KillTracker] All-time stats reset by " .. ply:Nick() .. ".")
    end)

    hook.Add("PlayerDisconnected", "ZCity_KillTracker", function(ply)
        lastAttacker[ply:SteamID64()] = nil
        EnsurePlayerRow(ply)
    end)

    hook.Add("PostCleanupMap", "ZCity_KillTracker", FlushDirtyRows)
    hook.Add("ShutDown", "ZCity_KillTracker", FlushDirtyRows)
end

hook.Add("InitPostEntity", "ZC_CoopInit_svkilltracker", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)

hook.Add("Think", "ZC_CoopInit_svkilltracker_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svkilltracker_Late")
        return
    end

    if not IsCoopRoundActive() then return end
    Initialize()
end)

