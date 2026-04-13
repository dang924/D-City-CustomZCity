-- sv_damage_log.lua — logs player-to-player damage to daily CSV files.
-- Admin+ can view via !damagelog (ULX) or zc_damagelog_open (console).
-- Live feed shows last 30 minutes of all damage across all players.

if CLIENT then return end

util.AddNetworkString("ZC_DamageLog_Open")
util.AddNetworkString("ZC_DamageLog_Data")
util.AddNetworkString("ZC_DamageLog_Request")

local LOG_DIR    = "zcity/damagelogs"
local MAX_DAYS   = 30
local MIN_DAMAGE = 5

-- ── Friendly fire auto-report ─────────────────────────────────────────────────
-- Tracks cumulative friendly fire damage per attacker in a rolling window.
-- When a player crosses the threshold, all online admins get a chat alert.
-- A per-player cooldown prevents the alert from repeating every hit.

local FF_WINDOW       = 120   -- seconds to look back
local FF_DMG_THRESH   = 200   -- total FF damage in window before alerting
local FF_HIT_THRESH   = 5     -- OR this many FF hits in window before alerting
local FF_ALERT_CD     = 90    -- seconds before the same attacker alerts again

-- Faction groups — same group = friendly fire
local FF_FACTIONS = {
    ["Rebel"]    = "resistance",
    ["Refugee"]  = "resistance",
    ["Gordon"]   = "resistance",
    ["Combine"]  = "combine",
    ["Metrocop"] = "combine",
}

local function IsFriendlyFire(atkClass, vicClass)
    local af = FF_FACTIONS[atkClass]
    local vf = FF_FACTIONS[vicClass]
    return af and vf and af == vf
end

-- ffTracker[atkSteamID] = { events = {{t, dmg}, ...}, lastAlert = time }
local ffTracker = {}

local function AlertAdmins(atk, victim, totalDmg, hitCount)
    local msg = string.format(
        "[FF Alert] %s (%s) dealt %.0f friendly-fire damage to %s (%s) over %ds (%d hits) — search '%s' in !damagelog",
        atk:Nick(), atk.PlayerClassName or "?",
        totalDmg,
        victim:Nick(), victim.PlayerClassName or "?",
        FF_WINDOW, hitCount,
        atk:SteamID()
    )
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsAdmin() then
            ply:ChatPrint(msg)
        end
    end
    print("[ZC FF] " .. msg)
end

local function TrackFF(attacker, victim, damage)
    if not IsValid(attacker) or not IsValid(victim) then return end
    if attacker == victim then return end
    if not IsFriendlyFire(attacker.PlayerClassName, victim.PlayerClassName) then return end
    if damage < 1 then return end

    local sid  = attacker:SteamID()
    local now  = CurTime()
    local data = ffTracker[sid]
    if not data then
        data = { events = {}, lastAlert = 0, lastVictim = victim }
        ffTracker[sid] = data
    end

    -- Add event
    table.insert(data.events, { t = now, dmg = damage })
    data.lastVictim = victim

    -- Prune old events outside the window
    local cutoff = now - FF_WINDOW
    local i = 1
    while i <= #data.events do
        if data.events[i].t < cutoff then table.remove(data.events, i)
        else i = i + 1 end
    end

    -- Tally window totals
    local totalDmg, hitCount = 0, 0
    for _, ev in ipairs(data.events) do
        totalDmg = totalDmg + ev.dmg
        hitCount = hitCount + 1
    end

    -- Alert if threshold crossed and cooldown has elapsed
    local shouldAlert = (totalDmg >= FF_DMG_THRESH or hitCount >= FF_HIT_THRESH)
    local cdOk        = (now - data.lastAlert) >= FF_ALERT_CD

    if shouldAlert and cdOk then
        data.lastAlert = now
        data.events    = {}  -- reset so it needs to accumulate again
        AlertAdmins(attacker, data.lastVictim, totalDmg, hitCount)
    end
end

hook.Add("PlayerDisconnected", "ZCity_FFTracker_Cleanup", function(ply)
    ffTracker[ply:SteamID()] = nil
end)

-- Drug ticks come in as tiny HomigradDamage calls (FrameTime()*0.5 each).
-- We bucket them per attacker→victim pair and flush every DRUG_FLUSH_INTERVAL
-- seconds so they appear as a single meaningful log entry instead of being
-- dropped by MIN_DAMAGE or flooding the log with hundreds of micro-entries.
local DRUG_FLUSH_INTERVAL = 3.0   -- seconds between flushes per pair
local DRUG_MIN_LOG        = 0.5   -- minimum accumulated harm before logging

-- Drug weapons that produce these micro-ticks
local DRUG_WEAPONS = {
    weapon_morphine  = "morphine",
    weapon_fentanyl  = "fentanyl",
}

-- drugBuckets[attackerSteamID][victimSteamID] = { total, lastFlush, entry fields }
local drugBuckets = {}

-- In-memory ring buffer for the live 30-minute feed
local liveFeed    = {}
local LIVE_WINDOW = 1800  -- seconds

local HITGROUP_NAMES = {
    [0] = "generic", [1] = "head",    [2] = "chest",
    [3] = "stomach", [4] = "larm",    [5] = "rarm",
    [6] = "lleg",    [7] = "rleg",    [8] = "gear",
}

-- ── File helpers ──────────────────────────────────────────────────────────────

local function EnsureDir()
    if not file.IsDir("zcity", "DATA") then file.CreateDir("zcity") end
    if not file.IsDir(LOG_DIR, "DATA") then file.CreateDir(LOG_DIR) end
end

local function GetLogPath()
    return LOG_DIR .. "/" .. os.date("%Y-%m-%d") .. ".csv"
end

local function EnsureHeader(path)
    if not file.Exists(path, "DATA") then
        file.Write(path, "timestamp,attacker,attacker_steamid,attacker_class,victim,victim_steamid,victim_class,damage,hitgroup,weapon\n")
    end
end

local function PruneOldLogs()
    local files = file.Find(LOG_DIR .. "/*.csv", "DATA")
    if not files or #files <= MAX_DAYS then return end
    table.sort(files)
    for i = 1, #files - MAX_DAYS do
        file.Delete(LOG_DIR .. "/" .. files[i])
    end
end

local function Escape(s)
    s = tostring(s)
    if string.find(s, "[,\"\n]") then
        s = '"' .. string.gsub(s, '"', '""') .. '"'
    end
    return s
end

-- ── Logging ───────────────────────────────────────────────────────────────────

local function WriteEntry(entry)
    EnsureDir()
    local path = GetLogPath()
    EnsureHeader(path)
    local line = table.concat({
        Escape(entry.time),    Escape(entry.atkName),  Escape(entry.atkSteam),
        Escape(entry.atkClass),Escape(entry.vicName),  Escape(entry.vicSteam),
        Escape(entry.vicClass),Escape(entry.damage),   Escape(entry.hitgroup),
        Escape(entry.weapon),
    }, ",") .. "\n"
    local existing = file.Read(path, "DATA") or ""
    file.Write(path, existing .. line)
    
    -- Also write to SQL for persistence
    if ZC_DamageLog_WriteSQLEntry then
        ZC_DamageLog_WriteSQLEntry(entry)
    end
end

local function PruneLiveFeed()
    local cutoff = CurTime() - LIVE_WINDOW
    local i = 1
    while i <= #liveFeed do
        if liveFeed[i].t < cutoff then table.remove(liveFeed, i)
        else i = i + 1 end
    end
end

hook.Add("InitPostEntity", "ZCity_DamageLog_Init", function()
    EnsureDir()
    PruneOldLogs()
    print("[ZC DamageLog] Logging to data/" .. LOG_DIR .. "/")
end)

local function FlushDrugBucket(atkSID, vicSID)
    local ab = drugBuckets[atkSID]
    if not ab then return end
    local b = ab[vicSID]
    if not b or b.total < DRUG_MIN_LOG then
        if b then ab[vicSID] = nil end
        return
    end
    local entry = {
        t        = b.lastFlush,
        time     = b.time,
        atkName  = b.atkName,
        atkSteam = b.atkSteam,
        atkClass = b.atkClass,
        vicName  = b.vicName,
        vicSteam = b.vicSteam,
        vicClass = b.vicClass,
        damage   = string.format("%.1f (drug tick ×%d)", b.total * 100, b.ticks),
        hitgroup = "rarm",
        weapon   = b.weapon,
    }
    WriteEntry(entry)
    table.insert(liveFeed, entry)
    PruneLiveFeed()
    ab[vicSID] = nil
end

hook.Add("HomigradDamage", "ZCity_DamageLog", function(victim, dmgInfo, hitgroup, ent, harm)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    local attacker = dmgInfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if attacker == victim then return end

    local wep      = attacker:GetActiveWeapon()
    local wepClass = IsValid(wep) and wep:GetClass() or "unknown"
    local damage   = math.Round((harm or dmgInfo:GetDamage()) * 100, 1)

    -- ── Drug tick aggregation ─────────────────────────────────────────────────
    if DRUG_WEAPONS[wepClass] then
        local rawHarm = harm or (dmgInfo:GetDamage())
        if rawHarm <= 0 then return end

        local atkSID = attacker:SteamID()
        local vicSID = victim:SteamID()
        local now    = CurTime()

        drugBuckets[atkSID] = drugBuckets[atkSID] or {}
        local b = drugBuckets[atkSID][vicSID]

        -- Flush and start fresh if interval elapsed or victim changed state
        if b and (now - b.lastFlush) >= DRUG_FLUSH_INTERVAL then
            FlushDrugBucket(atkSID, vicSID)
            b = nil
        end

        if not b then
            drugBuckets[atkSID][vicSID] = {
                total     = rawHarm,
                ticks     = 1,
                lastFlush = now,
                time      = os.date("%H:%M:%S"),
                atkName   = attacker:Nick(),
                atkSteam  = atkSID,
                atkClass  = attacker.PlayerClassName or "?",
                vicName   = victim:Nick(),
                vicSteam  = vicSID,
                vicClass  = victim.PlayerClassName or "?",
                weapon    = DRUG_WEAPONS[wepClass],
            }
        else
            b.total = b.total + rawHarm
            b.ticks = b.ticks + 1
        end
        return  -- do not fall through to normal log
    end

    -- ── Normal damage log ─────────────────────────────────────────────────────
    if damage < MIN_DAMAGE then return end

    -- Track for friendly fire auto-report (uses raw harm value, not display damage)
    TrackFF(attacker, victim, harm or dmgInfo:GetDamage())

    local entry = {
        t        = CurTime(),
        time     = os.date("%H:%M:%S"),
        atkName  = attacker:Nick(),
        atkSteam = attacker:SteamID(),
        atkClass = attacker.PlayerClassName or "?",
        vicName  = victim:Nick(),
        vicSteam = victim:SteamID(),
        vicClass = victim.PlayerClassName or "?",
        damage   = tostring(damage),
        hitgroup = HITGROUP_NAMES[hitgroup] or tostring(hitgroup),
        weapon   = wepClass,
    }

    WriteEntry(entry)
    table.insert(liveFeed, entry)
    PruneLiveFeed()
end)

-- Flush any leftover drug buckets when players disconnect or die
local function FlushPlayerBuckets(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    -- Flush as attacker
    if drugBuckets[sid] then
        for vicSID, _ in pairs(drugBuckets[sid]) do
            FlushDrugBucket(sid, vicSID)
        end
        drugBuckets[sid] = nil
    end
    -- Flush as victim (scan all attackers)
    for atkSID, ab in pairs(drugBuckets) do
        if ab[sid] then
            FlushDrugBucket(atkSID, sid)
        end
    end
end

hook.Add("PlayerDisconnected", "ZCity_DamageLog_DrugFlush", FlushPlayerBuckets)
hook.Add("DoPlayerDeath",      "ZCity_DamageLog_DrugFlush", FlushPlayerBuckets)

-- Periodic flush of any stale buckets (covers cases where injection stopped mid-way)
timer.Create("ZCity_DamageLog_DrugFlushTimer", DRUG_FLUSH_INTERVAL * 2, 0, function()
    local now = CurTime()
    for atkSID, ab in pairs(drugBuckets) do
        for vicSID, b in pairs(ab) do
            if (now - b.lastFlush) >= DRUG_FLUSH_INTERVAL then
                FlushDrugBucket(atkSID, vicSID)
            end
        end
        if not next(ab) then drugBuckets[atkSID] = nil end
    end
end)

-- ── Net ───────────────────────────────────────────────────────────────────────

-- Max entries per send — each entry is ~10 strings avg ~20 chars = ~200 bytes
-- GMod reliable buffer limit is 256KB so cap at 50 entries to stay safe
local MAX_SEND = 50

local function SendEntries(ply, entries)
    local total = #entries
    local send  = math.min(total, MAX_SEND)

    net.Start("ZC_DamageLog_Data")
        net.WriteUInt(total, 16)
        net.WriteUInt(send, 16)
        -- Send most recent first
        for i = total, math.max(1, total - send + 1), -1 do
            local e = entries[i]
            -- Truncate strings to stay within limits
            local function trunc(s, n) s = tostring(s or "") return #s > n and string.sub(s,1,n) or s end
            net.WriteString(trunc(e.time,     8))
            net.WriteString(trunc(e.atkName,  32))
            net.WriteString(trunc(e.atkSteam, 20))
            net.WriteString(trunc(e.atkClass, 16))
            net.WriteString(trunc(e.vicName,  32))
            net.WriteString(trunc(e.vicSteam, 20))
            net.WriteString(trunc(e.vicClass, 16))
            net.WriteString(trunc(e.damage,   8))
            net.WriteString(trunc(e.hitgroup, 8))
            net.WriteString(trunc(e.weapon,   32))
        end
    net.Send(ply)
end

net.Receive("ZC_DamageLog_Request", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local keyword = net.ReadString()
    local date    = net.ReadString()

    local function matches(e)
        if keyword == "" then return true end
        local kw = string.lower(keyword)
        return string.find(string.lower(e.atkName  or ""), kw, 1, true) or
               string.find(string.lower(e.vicName  or ""), kw, 1, true) or
               string.find(string.lower(e.atkSteam or ""), kw, 1, true) or
               string.find(string.lower(e.vicSteam or ""), kw, 1, true) or
               string.find(string.lower(e.weapon   or ""), kw, 1, true) or
               string.find(string.lower(e.hitgroup or ""), kw, 1, true)
    end

    -- Try SQL first
    if ZC_DamageLog_QuerySQL then
        ZC_DamageLog_QuerySQL(keyword, date, function(sqlEntries)
            if sqlEntries and #sqlEntries > 0 then
                SendEntries(ply, sqlEntries)
                return
            end
            
            -- SQL failed or returned nothing — fall back to CSV/live feed
            if date == "" then
                PruneLiveFeed()
                local filtered = {}
                for _, e in ipairs(liveFeed) do
                    if matches(e) then table.insert(filtered, e) end
                end
                SendEntries(ply, filtered)
            else
                local path    = LOG_DIR .. "/" .. date .. ".csv"
                local entries = {}
                if file.Exists(path, "DATA") then
                    local lines = string.Explode("\n", file.Read(path, "DATA") or "")
                    for i, line in ipairs(lines) do
                        if i == 1 or line == "" then continue end
                        local f = string.Explode(",", line)
                        if #f >= 10 then
                            local e = {
                                time=f[1],atkName=f[2],atkSteam=f[3],atkClass=f[4],
                                vicName=f[5],vicSteam=f[6],vicClass=f[7],
                                damage=f[8],hitgroup=f[9],weapon=f[10],
                            }
                            if matches(e) then table.insert(entries, e) end
                        end
                    end
                end
                SendEntries(ply, entries)
            end
        end)
    else
        -- SQL layer not available — use CSV/live feed directly
        if date == "" then
            PruneLiveFeed()
            local filtered = {}
            for _, e in ipairs(liveFeed) do
                if matches(e) then table.insert(filtered, e) end
            end
            SendEntries(ply, filtered)
        else
            local path    = LOG_DIR .. "/" .. date .. ".csv"
            local entries = {}
            if file.Exists(path, "DATA") then
                local lines = string.Explode("\n", file.Read(path, "DATA") or "")
                for i, line in ipairs(lines) do
                    if i == 1 or line == "" then continue end
                    local f = string.Explode(",", line)
                    if #f >= 10 then
                        local e = {
                            time=f[1],atkName=f[2],atkSteam=f[3],atkClass=f[4],
                            vicName=f[5],vicSteam=f[6],vicClass=f[7],
                            damage=f[8],hitgroup=f[9],weapon=f[10],
                        }
                        if matches(e) then table.insert(entries, e) end
                    end
                end
            end
            SendEntries(ply, entries)
        end
    end
end)

local function OpenLogForPlayer(ply)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("[DamageLog] Admin only.") end
        return
    end
    net.Start("ZC_DamageLog_Open")
    net.Send(ply)
end

-- ── Console commands ──────────────────────────────────────────────────────────

concommand.Add("zc_damagelog_open", function(ply)
    OpenLogForPlayer(ply)
end, nil, "Open the damage log viewer (admin+)")

concommand.Add("zc_damagelog", function(ply, cmd, args)
    local fromConsole = not IsValid(ply)
    if not fromConsole and not ply:IsSuperAdmin() then
        ply:ChatPrint("[DamageLog] Superadmin only.")
        return
    end
    local function out(msg)
        if fromConsole then Msg(msg .. "\n") else ply:ChatPrint(msg) end
    end
    if not args[1] then
        out("Usage: zc_damagelog <name/steamid> [YYYY-MM-DD]")
        return
    end
    local keyword = string.lower(args[1])
    local date    = args[2] or os.date("%Y-%m-%d")

    local function format_results(entries)
        if #entries == 0 then
            out("[DamageLog] No entries for '" .. keyword .. "' on " .. date)
            return
        end
        out("[DamageLog] " .. #entries .. " entries for '" .. keyword .. "' on " .. date .. ":")
        local start = math.max(1, #entries - 19)
        for i = start, #entries do
            out("  " .. entries[i])
        end
        if #entries > 20 then
            out("  ... and " .. (#entries - 20) .. " more.")
        end
    end

    -- Try SQL first
    if ZC_DamageLog_QuerySQL then
        ZC_DamageLog_QuerySQL(keyword, date, function(sqlEntries)
            if sqlEntries and #sqlEntries > 0 then
                local lines = {}
                for _, e in ipairs(sqlEntries) do
                    table.insert(lines, string.format("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s",
                        e.time, e.atkName, e.atkSteam, e.atkClass,
                        e.vicName, e.vicSteam, e.vicClass,
                        e.damage, e.hitgroup, e.weapon))
                end
                format_results(lines)
                return
            end
            -- SQL returned nothing, try CSV fallback
            local path = LOG_DIR .. "/" .. date .. ".csv"
            if not file.Exists(path, "DATA") then
                out("[DamageLog] No log for " .. date)
                return
            end
            local csvLines = string.Explode("\n", file.Read(path, "DATA") or "")
            local results = {}
            for i, line in ipairs(csvLines) do
                if i == 1 or line == "" then continue end
                if string.find(string.lower(line), keyword, 1, true) then
                    table.insert(results, line)
                end
            end
            format_results(results)
        end)
    else
        -- SQL not available, use CSV directly
        local path = LOG_DIR .. "/" .. date .. ".csv"
        if not file.Exists(path, "DATA") then
            out("[DamageLog] No log for " .. date)
            return
        end
        local lines   = string.Explode("\n", file.Read(path, "DATA") or "")
        local results = {}
        for i, line in ipairs(lines) do
            if i == 1 or line == "" then continue end
            if string.find(string.lower(line), keyword, 1, true) then
                table.insert(results, line)
            end
        end
        format_results(results)
    end
end, nil, "Search damage logs. Usage: zc_damagelog <name/steamid> [YYYY-MM-DD]")
