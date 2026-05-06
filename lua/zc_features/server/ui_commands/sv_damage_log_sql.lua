-- sv_damage_log_sql.lua — SQL persistence layer for damage logs
-- Routes all damage log entries to MySQL for reliable storage and retrieval
-- Falls back to CSV if SQL is unavailable

if CLIENT then return end

local SQL_TABLE = "zc_damage_log"
local SQL_READY = false
local SQL_QUEUE = {}
local SQL_QUEUE_LIMIT = 4000
local SQL_BATCH_SIZE = 40
local SQL_FLUSH_INTERVAL = 0.25
local SQL_FLUSH_IN_FLIGHT = false
local SQL_DROPPED = 0

local function InitSQLTable()
    if SQL_READY then return end
    if not hg or not hg.MySQL then return end
    
    local query = [[
        CREATE TABLE IF NOT EXISTS ]] .. SQL_TABLE .. [[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            attacker_name VARCHAR(255),
            attacker_steamid VARCHAR(20),
            attacker_class VARCHAR(32),
            victim_name VARCHAR(255),
            victim_steamid VARCHAR(20),
            victim_class VARCHAR(32),
            damage DECIMAL(8,2),
            hitgroup VARCHAR(16),
            weapon VARCHAR(64),
            log_date DATE NOT NULL,
            INDEX idx_date (log_date),
            INDEX idx_attacker (attacker_steamid),
            INDEX idx_victim (victim_steamid),
            INDEX idx_timestamp (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]
    
    hg.MySQL.query(query, function(result)
        if result then
            SQL_READY = true
            print("[ZC DamageLog] SQL table ready: " .. SQL_TABLE)
            if #SQL_QUEUE > 0 then
                timer.Simple(0, function()
                    if SQL_READY then
                        local flush = ZC_DamageLog_FlushSQLQueue
                        if isfunction(flush) then
                            flush()
                        end
                    end
                end)
            end
        else
            print("[ZC DamageLog] WARNING: Failed to create SQL table")
        end
    end)
end

local function GetSQLDamageValue(entry)
    local damage = tonumber(entry and entry.damage)
    if damage then return string.format("%.2f", damage) end

    local text = tostring(entry and entry.damage or "")
    local match = string.match(text, "[-+]?%d+%.?%d*")
    return string.format("%.2f", tonumber(match) or 0)
end

local function BuildSQLValuesRow(entry)
    if not (hg and hg.MySQL and isfunction(hg.MySQL.EscapeStr) and istable(entry)) then return nil end

    local escape = hg.MySQL.EscapeStr
    return string.format(
        "(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
        escape(entry.atkName),
        escape(entry.atkSteam),
        escape(entry.atkClass),
        escape(entry.vicName),
        escape(entry.vicSteam),
        escape(entry.vicClass),
        escape(GetSQLDamageValue(entry)),
        escape(entry.hitgroup),
        escape(entry.weapon),
        escape(os.date("%Y-%m-%d"))
    )
end

local function EnqueueSQLEntry(entry)
    if not istable(entry) then return end

    if #SQL_QUEUE >= SQL_QUEUE_LIMIT then
        table.remove(SQL_QUEUE, 1)
        SQL_DROPPED = SQL_DROPPED + 1
    end

    SQL_QUEUE[#SQL_QUEUE + 1] = entry
end

function ZC_DamageLog_FlushSQLQueue()
    if SQL_FLUSH_IN_FLIGHT or not SQL_READY then return false end
    if not (hg and hg.MySQL) then return false end
    if #SQL_QUEUE == 0 then return false end

    local values = {}
    local batchCount = math.min(#SQL_QUEUE, SQL_BATCH_SIZE)

    for _ = 1, batchCount do
        local entry = table.remove(SQL_QUEUE, 1)
        local row = BuildSQLValuesRow(entry)
        if row then
            values[#values + 1] = row
        end
    end

    if #values == 0 then return false end

    local query_str = string.format(
        "INSERT INTO %s (attacker_name, attacker_steamid, attacker_class, victim_name, victim_steamid, victim_class, damage, hitgroup, weapon, log_date) VALUES %s",
        SQL_TABLE,
        table.concat(values, ",")
    )

    SQL_FLUSH_IN_FLIGHT = true
    hg.MySQL.query(query_str, function(result)
        SQL_FLUSH_IN_FLIGHT = false

        if not result then
            print("[ZC DamageLog] SQL batch write failed for " .. tostring(#values) .. " entries")
            return
        end

        if SQL_DROPPED > 0 then
            print("[ZC DamageLog] SQL queue dropped " .. tostring(SQL_DROPPED) .. " old entries under load")
            SQL_DROPPED = 0
        end
    end)

    return true
end

-- Global function to write damage entries to SQL
function ZC_DamageLog_WriteSQLEntry(entry)
    if not hg or not hg.MySQL then return end

    EnqueueSQLEntry(entry)

    if SQL_READY then
        ZC_DamageLog_FlushSQLQueue()
    end
end

-- Global function to query damage logs from SQL with fallback
function ZC_DamageLog_QuerySQL(keyword, date_str, callback)
    if not hg or not hg.MySQL or not SQL_READY then
        callback(nil)
        return
    end
    
    local query_str
    if date_str == "" or date_str == nil then
        -- Live feed: last 30 minutes
        query_str = string.format(
            "SELECT attacker_name, attacker_steamid, attacker_class, victim_name, victim_steamid, victim_class, damage, hitgroup, weapon, DATE_FORMAT(created_at, '%%H:%%i:%%S') as time FROM %s WHERE created_at > DATE_SUB(NOW(), INTERVAL 30 MINUTE) ORDER BY created_at DESC LIMIT 500",
            SQL_TABLE
        )
    else
        -- Specific date
        query_str = string.format(
            "SELECT attacker_name, attacker_steamid, attacker_class, victim_name, victim_steamid, victim_class, damage, hitgroup, weapon, DATE_FORMAT(created_at, '%%H:%%i:%%S') as time FROM %s WHERE log_date = %s ORDER BY created_at DESC LIMIT 2000",
            SQL_TABLE,
            hg.MySQL.EscapeStr(date_str)
        )
    end
    
    hg.MySQL.query(query_str, function(result)
        if result and istable(result) and #result > 0 then
            local entries = {}
            for _, row in ipairs(result) do
                local entry = {
                    t = CurTime(),  -- Approximate, for in-memory filtering
                    time = row.time or "",
                    atkName = row.attacker_name or "",
                    atkSteam = row.attacker_steamid or "",
                    atkClass = row.attacker_class or "?",
                    vicName = row.victim_name or "",
                    vicSteam = row.victim_steamid or "",
                    vicClass = row.victim_class or "?",
                    damage = tostring(row.damage or "0"),
                    hitgroup = row.hitgroup or "generic",
                    weapon = row.weapon or "unknown",
                }
                
                -- Filter by keyword if provided
                if keyword == "" or keyword == nil then
                    table.insert(entries, entry)
                else
                    local kw = string.lower(keyword)
                    if string.find(string.lower(entry.atkName or ""), kw, 1, true) or
                       string.find(string.lower(entry.vicName or ""), kw, 1, true) or
                       string.find(string.lower(entry.atkSteam or ""), kw, 1, true) or
                       string.find(string.lower(entry.vicSteam or ""), kw, 1, true) or
                       string.find(string.lower(entry.weapon or ""), kw, 1, true) then
                        table.insert(entries, entry)
                    end
                end
            end
            callback(entries)
        else
            callback(nil)
        end
    end)
end

-- Initialize SQL table when MySQL becomes ready
hook.Add("InitPostEntity", "ZC_DamageLog_SQL_Init", function()
    timer.Create("ZC_DamageLog_SQL_Flush", SQL_FLUSH_INTERVAL, 0, function()
        ZC_DamageLog_FlushSQLQueue()
    end)

    timer.Create("ZC_DamageLog_SQLInit_Retry", 1, 30, function()
        InitSQLTable()
        if SQL_READY then
            timer.Remove("ZC_DamageLog_SQLInit_Retry")
        end
    end)
end)
