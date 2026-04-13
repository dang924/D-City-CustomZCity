-- Tracks all-time kill counts between factions:
--   Rebel players killing Combine players
--   Combine players killing Rebel players
-- Stats persist across server restarts via file storage.
-- Reset requires superadmin.
--
-- ZCity kills players via organism blood loss, not direct damage. By the time
-- ply:Kill() fires and PlayerDeath runs, the 15-second SetPhysicsAttacker
-- window has expired and attacker is the world entity. We track the last
-- relevant attacker ourselves via HomigradDamage.

if CLIENT then return end
if not ZC_IsPatchRebelClassName then
    include("autorun/server/sv_patch_player_factions.lua")
end

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    local SAVE_FILE = "zcity_killtracker.json"
    local SAVE_DIR  = "zcity"

    -- { [steamid64] = { nick, kills, deaths } }
    local stats = {}

    -- ── Persistence ───────────────────────────────────────────────────────────────

    local function SaveStats()
        if not file.IsDir(SAVE_DIR, "DATA") then
            file.CreateDir(SAVE_DIR)
        end
        local ok, encoded = pcall(util.TableToJSON, stats, true)
        if not ok then
            print("[ZC KillTracker] ERROR: Failed to encode stats: " .. tostring(encoded))
            return
        end
        local path = SAVE_DIR .. "/" .. SAVE_FILE
        file.Write(path, encoded)
        -- Verify write landed
        local verify = file.Read(path, "DATA")
        if not verify or verify == "" then
            print("[ZC KillTracker] ERROR: file.Write failed — data not on disk! Host may not support data persistence.")
        else
            local count = 0
            for _ in pairs(stats) do count = count + 1 end
            print("[ZC KillTracker] Saved stats for " .. count .. " players to " .. path)
        end
    end

    local function LoadStats()
        local path = SAVE_DIR .. "/" .. SAVE_FILE
        if not file.Exists(path, "DATA") then
            print("[ZC KillTracker] No save file found at " .. path .. " — starting fresh.")
            return
        end
        local raw = file.Read(path, "DATA")
        if not raw or raw == "" then
            print("[ZC KillTracker] Save file exists but is empty — starting fresh.")
            return
        end
        local ok, decoded = pcall(util.JSONToTable, raw)
        if not ok or type(decoded) ~= "table" then
            print("[ZC KillTracker] ERROR: Corrupt save file — starting fresh.")
            return
        end
        stats = decoded
        local count = 0
        for _ in pairs(stats) do count = count + 1 end
        print("[ZC KillTracker] Loaded stats for " .. count .. " players from " .. path)
    end

    LoadStats()

    -- ── Last attacker tracking ────────────────────────────────────────────────────
    -- ZCity's organism kills via ply:Kill() long after damage lands.
    -- We track the last player who dealt faction-relevant damage to each player
    -- so PlayerDeath can use it instead of the stale physics attacker.

    local lastAttacker = {}  -- { [victim steamid64] = attacker player }

    hook.Add("HomigradDamage", "ZCity_KillTracker_TrackAttacker", function(ply, dmgInfo)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        local attacker = dmgInfo:GetAttacker()
        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        if attacker == ply then return end

        -- Only track cross-faction damage
        local aC = attacker.PlayerClassName
        local vC = ply.PlayerClassName
        local relevant = (ZC_IsPatchRebelClassName(aC) and ZC_IsPatchCombineClassName(vC)) or
                 (ZC_IsPatchCombineClassName(aC) and ZC_IsPatchRebelClassName(vC))
        if not relevant then return end

        lastAttacker[ply:SteamID64()] = attacker
    end)

    -- ── Helpers ───────────────────────────────────────────────────────────────────

    local function GetOrCreate(ply)
        local id = ply:SteamID64()
        if not stats[id] then
            stats[id] = { nick = ply:Nick(), kills = 0, deaths = 0 }
        end
        stats[id].nick = ply:Nick()
        return stats[id]
    end

    -- ── Kill tracking ─────────────────────────────────────────────────────────────

    hook.Add("PlayerDeath", "ZCity_KillTracker", function(victim, inflictor, attacker)
        if victim:Team() == TEAM_SPECTATOR then return end

        -- Prefer our tracked attacker over the stale physics attacker
        local trackedAttacker = lastAttacker[victim:SteamID64()]
        if IsValid(trackedAttacker) and trackedAttacker ~= victim then
            attacker = trackedAttacker
        end

        -- Clear the tracked attacker on death
        lastAttacker[victim:SteamID64()] = nil

        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        if attacker == victim then return end

        local aC = attacker.PlayerClassName
        local vC = victim.PlayerClassName
        local relevant = (ZC_IsPatchRebelClassName(aC) and ZC_IsPatchCombineClassName(vC)) or
                 (ZC_IsPatchCombineClassName(aC) and ZC_IsPatchRebelClassName(vC))
        if not relevant then return end

        local aStats = GetOrCreate(attacker)
        local vStats = GetOrCreate(victim)

        aStats.kills  = aStats.kills  + 1
        vStats.deaths = vStats.deaths + 1

        SaveStats()

        local subInfo = attacker.subClass and (" [" .. attacker.subClass .. "]") or ""
        attacker:ChatPrint(
            "[KillTracker] " .. victim:Nick() ..
            " killed — your total: " .. aStats.kills .. "K / " .. aStats.deaths .. "D"
        )

    end)

    -- ── Commands ──────────────────────────────────────────────────────────────────

    local function PrintStats(ply)
        local id = ply:SteamID64()
        local s  = stats[id]
        if not s or (s.kills == 0 and s.deaths == 0) then
            ply:ChatPrint("[KillTracker] No faction kills or deaths on record.")
            return
        end
        local kd = s.deaths > 0 and math.Round(s.kills / s.deaths, 2) or s.kills
        ply:ChatPrint(
            "[KillTracker] All-time — Kills: " .. s.kills ..
            "  Deaths: " .. s.deaths ..
            "  K/D: " .. kd
        )
    end

    local function PrintLeaderboard(ply)
        local list = {}
        for _, s in pairs(stats) do
            if s.kills > 0 or s.deaths > 0 then
                table.insert(list, s)
            end
        end
        if #list == 0 then
            ply:ChatPrint("[KillTracker] No stats on record yet.")
            return
        end

        table.sort(list, function(a, b) return a.kills > b.kills end)

        ply:ChatPrint("[KillTracker] ── All-Time Faction Kill Leaderboard ──")
        for i, s in ipairs(list) do
            local kd = s.deaths > 0 and math.Round(s.kills / s.deaths, 2) or s.kills
            ply:ChatPrint(
                "  " .. i .. ". " .. s.nick ..
                " — " .. s.kills .. "K / " .. s.deaths .. "D  (K/D " .. kd .. ")"
            )
            if i >= 10 then break end
        end
    end

    hook.Add("HG_PlayerSay", "ZCity_KillTracker", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text))

        if cmd ~= "!killstats" and cmd ~= "/killstats" and
           cmd ~= "!killtop"   and cmd ~= "/killtop"   and
           cmd ~= "!killreset" and cmd ~= "/killreset"  then return end
        txtTbl[1] = ""

        if cmd == "!killstats" or cmd == "/killstats" then
            PrintStats(ply)
            return
        end

        if cmd == "!killtop" or cmd == "/killtop" then
            PrintLeaderboard(ply)
            return
        end

        if cmd == "!killreset" or cmd == "/killreset" then
            if not ply:IsSuperAdmin() then
                ply:ChatPrint("[KillTracker] Only superadmins can reset stats.")
                return
            end
            stats = {}
            SaveStats()
            PrintMessage(HUD_PRINTTALK, "[KillTracker] All-time stats reset by " .. ply:Nick() .. ".")
            return
        end
    end)

    -- ── Persistence hooks ─────────────────────────────────────────────────────────

    hook.Add("PlayerDisconnected", "ZCity_KillTracker", function(ply)
        lastAttacker[ply:SteamID64()] = nil
        local id = ply:SteamID64()
        local s  = stats[id]
        if not s then return end
        SaveStats()
    end)

    hook.Add("PostCleanupMap", "ZCity_KillTracker", SaveStats)

    -- ShutDown fires on map changes and server restarts — PostCleanupMap does NOT
    -- fire on changelevel, so this is the only reliable save on map change.
    hook.Add("ShutDown", "ZCity_KillTracker", SaveStats)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
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

