-- sv_cs_teams.lua — Competitive team registration and match scoring for cstrike mode.
--
-- Chat commands (all players):
--   !csteamregister <name> <size>   — register a new team (2 or 5), you become leader
--   !csteamjoin <name>              — request to join a team (leader must accept within 30s)
--   !csteamleave                    — leave your current team
--   !csteamlist                     — list all registered teams
--   !csteamstatus                   — show your team and match status
--
-- Chat commands (admin only):
--   !csmatch <team1> <team2>        — start a match between two teams
--   !csendmatch                     — end the current match and print final score
--   !csteamdisband <name>           — forcibly disband a team
--
-- Score persistence: data/zcity/cs_teams.json

if CLIENT then return end

-- ── State ─────────────────────────────────────────────────────────────────────

-- teams[name] = { name, size, leader=steamid64, members={steamid64,...}, wins, losses }
local teams = {}

-- pendingJoin[leaderSteamID64] = { requester=ply, teamName, expireTime, timerName }
local pendingJoin = {}

-- activeMatch = { team1=name, team2=name, score={[name]=n,...}, rounds=0 } or nil
local activeMatch = nil

-- players' current team, keyed by steamid64
local playerTeam = {}   -- steamid64 → team name

-- ── Persistence ───────────────────────────────────────────────────────────────

local DATA_PATH = "zcity/cs_teams.json"

local function SaveTeams()
    if not file.IsDir("zcity", "DATA") then file.CreateDir("zcity") end
    -- Store only persistent fields (not transient member presence)
    local out = {}
    for name, t in pairs(teams) do
        out[name] = {
            name    = t.name,
            size    = t.size,
            leader  = t.leader,
            members = t.members,
            wins    = t.wins,
            losses  = t.losses,
        }
    end
    file.Write(DATA_PATH, util.TableToJSON(out, true))
end

local function LoadTeams()
    if not file.Exists(DATA_PATH, "DATA") then return end
    local raw = file.Read(DATA_PATH, "DATA")
    if not raw then return end
    local ok, decoded = pcall(util.JSONToTable, raw)
    if not ok or not decoded then return end
    teams = decoded
    -- Rebuild playerTeam index from saved member lists
    for name, t in pairs(teams) do
        for _, sid in ipairs(t.members or {}) do
            playerTeam[sid] = name
        end
    end
    print("[ZC CS Teams] Loaded " .. table.Count(teams) .. " teams from disk.")
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function FindPlayerBySID64(sid64)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:SteamID64() == sid64 then return ply end
    end
end

local function GetTeamOf(ply)
    return playerTeam[ply:SteamID64()]
end

local function IsTeamLeader(ply, teamName)
    local t = teams[teamName]
    return t and t.leader == ply:SteamID64()
end

local function ChatAll(msg)
    PrintMessage(HUD_PRINTTALK, "[CS Teams] " .. msg)
end

local function ChatPly(ply, msg)
    if IsValid(ply) then ply:ChatPrint("[CS Teams] " .. msg) end
end

local function MemberCount(t)
    return t and #(t.members or {}) or 0
end

-- ── Team registration ─────────────────────────────────────────────────────────

COMMANDS.csteamregister = {function(ply, args)
    if not args[1] or not args[2] then
        ChatPly(ply, "Usage: !csteamregister <name> <size>  (size: 2 or 5)")
        return
    end

    -- Size is the last argument; everything before it is the team name
    local size = tonumber(args[#args])
    local nameParts = {}
    for i = 1, #args - 1 do nameParts[i] = args[i] end
    local name = table.concat(nameParts, " "):sub(1, 32)

    if name == "" then
        ChatPly(ply, "Usage: !csteamregister <name> <size>  (size: 2 or 5)")
        return
    end

    if size ~= 2 and size ~= 5 then
        ChatPly(ply, "Size must be 2 or 5.")
        return
    end

    if teams[name] then
        ChatPly(ply, "A team named \"" .. name .. "\" already exists.")
        return
    end

    local existing = GetTeamOf(ply)
    if existing then
        ChatPly(ply, "You are already in team \"" .. existing .. "\". Leave first with !csteamleave.")
        return
    end

    local sid = ply:SteamID64()
    teams[name] = {
        name    = name,
        size    = size,
        leader  = sid,
        members = { sid },
        wins    = 0,
        losses  = 0,
    }
    playerTeam[sid] = name
    SaveTeams()

    ChatAll(ply:Nick() .. " registered team \"" .. name .. "\" (" .. size .. "v" .. size .. ").")
end, 0, "<name> <size>"}

-- ── Join request flow ─────────────────────────────────────────────────────────

COMMANDS.csteamjoin = {function(ply, args)
    if not args[1] then
        ChatPly(ply, "Usage: !csteamjoin <team name>")
        return
    end

    local name = table.concat(args, " ")
    local t = teams[name]
    if not t then
        ChatPly(ply, "No team named \"" .. name .. "\".")
        return
    end

    local existing = GetTeamOf(ply)
    if existing then
        ChatPly(ply, "You are already in team \"" .. existing .. "\". Leave first with !csteamleave.")
        return
    end

    if MemberCount(t) >= t.size then
        ChatPly(ply, "Team \"" .. name .. "\" is full (" .. t.size .. "/" .. t.size .. ").")
        return
    end

    local leader = FindPlayerBySID64(t.leader)
    if not IsValid(leader) then
        ChatPly(ply, "Team leader is not online. Ask them to be present when joining.")
        return
    end

    -- Cancel any existing pending request to the same leader
    if pendingJoin[t.leader] then
        timer.Remove(pendingJoin[t.leader].timerName)
        local prev = pendingJoin[t.leader].requester
        if IsValid(prev) then
            ChatPly(prev, "Your join request was replaced by a new one.")
        end
    end

    local timerName = "ZC_CSTeamJoin_" .. ply:SteamID64()
    pendingJoin[t.leader] = {
        requester = ply,
        teamName  = name,
        expireTime = CurTime() + 30,
        timerName = timerName,
    }

    ChatPly(leader, ply:Nick() .. " wants to join your team \"" .. name .. "\". Type !csteamaccept or !csteamdeny within 30 seconds.")
    ChatPly(ply, "Join request sent to " .. leader:Nick() .. ". Waiting up to 30 seconds for a response.")

    timer.Create(timerName, 30, 1, function()
        if pendingJoin[t.leader] and pendingJoin[t.leader].timerName == timerName then
            local req = pendingJoin[t.leader]
            pendingJoin[t.leader] = nil
            if IsValid(req.requester) then
                ChatPly(req.requester, "Your join request to \"" .. name .. "\" expired. Try again.")
            end
            if IsValid(leader) then
                ChatPly(leader, "Join request from " .. (IsValid(req.requester) and req.requester:Nick() or "a player") .. " expired.")
            end
        end
    end)
end, 0, "<team name>"}

COMMANDS.csteamaccept = {function(ply, args)
    local sid = ply:SteamID64()
    local req = pendingJoin[sid]
    if not req then
        ChatPly(ply, "No pending join request.")
        return
    end

    timer.Remove(req.timerName)
    pendingJoin[sid] = nil

    local requester = req.requester
    local t = teams[req.teamName]

    if not t then
        ChatPly(ply, "The team no longer exists.")
        return
    end

    if MemberCount(t) >= t.size then
        ChatPly(ply, "Team is now full — cannot accept.")
        if IsValid(requester) then ChatPly(requester, "Team \"" .. req.teamName .. "\" is now full.") end
        return
    end

    if not IsValid(requester) then
        ChatPly(ply, "That player has disconnected.")
        return
    end

    local existing = GetTeamOf(requester)
    if existing then
        ChatPly(ply, requester:Nick() .. " has already joined another team.")
        return
    end

    table.insert(t.members, requester:SteamID64())
    playerTeam[requester:SteamID64()] = req.teamName
    SaveTeams()

    ChatPly(requester, "You have joined team \"" .. req.teamName .. "\" (" .. MemberCount(t) .. "/" .. t.size .. ").")
    ChatPly(ply, requester:Nick() .. " has joined the team.")
    ChatAll(requester:Nick() .. " joined team \"" .. req.teamName .. "\" (" .. MemberCount(t) .. "/" .. t.size .. ").")
end, 0}

COMMANDS.csteamdeny = {function(ply, args)
    local sid = ply:SteamID64()
    local req = pendingJoin[sid]
    if not req then
        ChatPly(ply, "No pending join request.")
        return
    end

    timer.Remove(req.timerName)
    pendingJoin[sid] = nil

    if IsValid(req.requester) then
        ChatPly(req.requester, "Your join request to \"" .. req.teamName .. "\" was denied.")
    end
    ChatPly(ply, "Join request from " .. (IsValid(req.requester) and req.requester:Nick() or "a player") .. " denied.")
end, 0}

-- ── Leave ─────────────────────────────────────────────────────────────────────

COMMANDS.csteamleave = {function(ply, args)
    local name = GetTeamOf(ply)
    if not name then
        ChatPly(ply, "You are not in a team.")
        return
    end

    local t = teams[name]
    local sid = ply:SteamID64()

    -- Remove from members list
    for i, msid in ipairs(t.members) do
        if msid == sid then table.remove(t.members, i) break end
    end
    playerTeam[sid] = nil

    -- If leader left, assign next member or disband
    if t.leader == sid then
        if #t.members > 0 then
            t.leader = t.members[1]
            local newLeader = FindPlayerBySID64(t.leader)
            local leaderName = IsValid(newLeader) and newLeader:Nick() or t.leader
            ChatAll(ply:Nick() .. " left team \"" .. name .. "\". New leader: " .. leaderName .. ".")
        else
            teams[name] = nil
            ChatAll(ply:Nick() .. " left team \"" .. name .. "\" — team disbanded (no members remaining).")
            SaveTeams()
            return
        end
    else
        ChatAll(ply:Nick() .. " left team \"" .. name .. "\".")
    end

    SaveTeams()
end, 0}

-- ── Info commands ─────────────────────────────────────────────────────────────

COMMANDS.csteamlist = {function(ply, args)
    if table.Count(teams) == 0 then
        ChatPly(ply, "No teams registered.")
        return
    end
    ply:ChatPrint("[CS Teams] Registered teams:")
    for name, t in pairs(teams) do
        local leaderPly = FindPlayerBySID64(t.leader)
        local leaderName = IsValid(leaderPly) and leaderPly:Nick() or ("SID:" .. t.leader)
        ply:ChatPrint(string.format("  %-20s  %d/%d members  W:%d L:%d  Leader: %s",
            name, MemberCount(t), t.size, t.wins, t.losses, leaderName))
    end
end, 0}

COMMANDS.csteamstatus = {function(ply, args)
    local name = GetTeamOf(ply)
    if not name then
        ChatPly(ply, "You are not in a team.")
        return
    end
    local t = teams[name]
    local isLeader = IsTeamLeader(ply, name)
    ply:ChatPrint(string.format("[CS Teams] Team: %s  (%d/%d)  W:%d L:%d  %s",
        name, MemberCount(t), t.size, t.wins, t.losses,
        isLeader and "[Leader]" or ""))
    ply:ChatPrint("  Members:")
    for _, sid in ipairs(t.members) do
        local mp = FindPlayerBySID64(sid)
        local mname = IsValid(mp) and mp:Nick() or ("(offline:" .. sid .. ")")
        ply:ChatPrint("    " .. mname .. (sid == t.leader and " [Leader]" or ""))
    end
    if activeMatch then
        if activeMatch.team1 == name or activeMatch.team2 == name then
            local opp = activeMatch.team1 == name and activeMatch.team2 or activeMatch.team1
            ply:ChatPrint(string.format("  Active match vs %s — Score: %s %d - %d %s",
                opp, name, activeMatch.score[name] or 0,
                activeMatch.score[opp] or 0, opp))
        end
    end
end, 0}

-- ── Admin commands ────────────────────────────────────────────────────────────

COMMANDS.csmatch = {function(ply, args)
    if not ply:IsAdmin() then ChatPly(ply, "Admins only.") return end
    if not args[1] or not args[2] then
        ChatPly(ply, "Usage: !csmatch <team1> <team2>")
        return
    end

    local t1name, t2name = args[1], args[2]
    if not teams[t1name] then ChatPly(ply, "No team named \"" .. t1name .. "\".") return end
    if not teams[t2name] then ChatPly(ply, "No team named \"" .. t2name .. "\".") return end
    if t1name == t2name then ChatPly(ply, "A team cannot match itself.") return end

    if activeMatch then
        ChatPly(ply, "A match is already in progress. Use !csendmatch first.")
        return
    end

    local t1, t2 = teams[t1name], teams[t2name]
    if t1.size ~= t2.size then
        ChatPly(ply, "Teams must have the same size (" .. t1.size .. " vs " .. t2.size .. ").")
        return
    end

    -- Map registered team names to ZCity team indices (0=T, 1=CT) based on
    -- which side their leader is currently on. Recorded at match start so
    -- scoring doesn't depend on live player positions after each round ends.
    local function GetZCityTeam(tname)
        local t = teams[tname]
        if not t then return nil end
        for _, sid in ipairs(t.members) do
            local mp = FindPlayerBySID64(sid)
            if IsValid(mp) and mp:Alive() then return mp:Team() end
        end
        return nil
    end

    local side1 = GetZCityTeam(t1name)
    local side2 = GetZCityTeam(t2name)

    activeMatch = {
        team1  = t1name,
        team2  = t2name,
        score  = { [t1name] = 0, [t2name] = 0 },
        rounds = 0,
        -- ZCity team index → registered team name (set at match start)
        sideMap = {},
    }
    if side1 then activeMatch.sideMap[side1] = t1name end
    if side2 then activeMatch.sideMap[side2] = t2name end

    local sideStr = ""
    if side1 ~= nil then sideStr = " | " .. t1name .. "=" .. (side1 == 0 and "T" or "CT") .. " " .. t2name .. "=" .. (side2 == nil and "?" or (side2 == 0 and "T" or "CT")) end

    ChatAll("Match started: \"" .. t1name .. "\" vs \"" .. t2name .. "\" (" .. t1.size .. "v" .. t1.size .. ")" .. sideStr)
end, 1, "<team1> <team2>"}

COMMANDS.csmatchscore = {function(ply, args)
    if not activeMatch then
        ChatPly(ply, "No active match.")
        return
    end
    local m = activeMatch
    ply:ChatPrint(string.format("[CS Teams] Match: \"%s\" vs \"%s\" — Round %d",
        m.team1, m.team2, m.rounds))
    ply:ChatPrint(string.format("  Score: %s %d  :  %d %s",
        m.team1, m.score[m.team1] or 0,
        m.score[m.team2] or 0, m.team2))
end, 0}

COMMANDS.csendmatch = {function(ply, args)
    if not ply:IsAdmin() then ChatPly(ply, "Admins only.") return end
    if not activeMatch then
        ChatPly(ply, "No active match.")
        return
    end

    local m = activeMatch
    local s1, s2 = m.score[m.team1] or 0, m.score[m.team2] or 0
    local result

    if s1 > s2 then
        result = "\"" .. m.team1 .. "\" wins!"
        teams[m.team1].wins   = teams[m.team1].wins + 1
        teams[m.team2].losses = teams[m.team2].losses + 1
    elseif s2 > s1 then
        result = "\"" .. m.team2 .. "\" wins!"
        teams[m.team2].wins   = teams[m.team2].wins + 1
        teams[m.team1].losses = teams[m.team1].losses + 1
    else
        result = "Draw!"
    end

    ChatAll(string.format("Match over — %s %d  :  %d %s — %s (%d rounds)",
        m.team1, s1, s2, m.team2, result, m.rounds))

    activeMatch = nil
    SaveTeams()
end, 1}

COMMANDS.csteamdisband = {function(ply, args)
    if not ply:IsAdmin() then ChatPly(ply, "Admins only.") return end
    if not args[1] then ChatPly(ply, "Usage: !csteamdisband <name>") return end

    local name = table.concat(args, " ")
    if name == "" then ChatPly(ply, "Usage: !csteamdisband <n>") return end
    if not teams[name] then ChatPly(ply, "No team named \"" .. name .. "\".") return end

    -- Clear all member associations
    for _, sid in ipairs(teams[name].members) do
        playerTeam[sid] = nil
    end
    teams[name] = nil
    SaveTeams()

    ChatAll("Admin " .. ply:Nick() .. " disbanded team \"" .. name .. "\".")
end, 1, "<name>"}

-- ── Round scoring hook ────────────────────────────────────────────────────────
-- ZCity's cstrike MODE:EndRound() increments zb.Winners[winnerTeamIndex] and
-- then fires ZB_EndRound. We snapshot zb.Winners just before EndRound runs so
-- we can diff it afterwards to find which team index just scored.

local winnersSnapshot = {}

-- Snapshot zb.Winners before EndRound modifies it, by wrapping zb.EndRound.
-- ZB_PreEndRound doesn't exist in this ZCity version.
local function HookZBEndRound()
    if not zb or not zb.EndRound then return false end
    local orig = zb.EndRound
    zb.EndRound = function(self, ...)
        -- Snapshot before MODE:EndRound() increments zb.Winners
        if activeMatch and zb.CROUND == "cstrike" then
            winnersSnapshot = {}
            if zb.Winners then
                for k, v in pairs(zb.Winners) do winnersSnapshot[k] = v end
            end
        end
        return orig(self, ...)
    end
    return true
end

hook.Add("InitPostEntity", "ZC_CSTeams_WrapEndRound", function()
    timer.Simple(1, function()
        if not HookZBEndRound() then
            print("[ZC CS Teams] WARNING: zb.EndRound not found — score tracking may be off by one round")
        end
    end)
end)

-- Read diff after EndRound has run
hook.Add("ZB_EndRound", "ZC_CSTeams_ScoreRound", function()
    if not activeMatch then return end
    if not (zb and zb.CROUND == "cstrike") then return end
    if not zb.Winners then return end

    -- Find which team index gained a win this round
    local winnerTeamIndex = nil
    for teamIdx, wins in pairs(zb.Winners) do
        if (wins or 0) > (winnersSnapshot[teamIdx] or 0) then
            winnerTeamIndex = teamIdx
            break
        end
    end
    if winnerTeamIndex == nil then return end  -- draw / nobody

    activeMatch.rounds = activeMatch.rounds + 1

    -- Resolve winning ZCity team index → registered team name via sideMap
    -- (recorded at match start; avoids relying on live player positions)
    local bestName = activeMatch.sideMap and activeMatch.sideMap[winnerTeamIndex]

    -- Fallback: live player vote if sideMap wasn't populated (e.g. match started mid-round)
    if not bestName then
        local teamVotes = {}
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if ply:Team() ~= winnerTeamIndex then continue end
            local tname = GetTeamOf(ply)
            if not tname then continue end
            if tname ~= activeMatch.team1 and tname ~= activeMatch.team2 then continue end
            teamVotes[tname] = (teamVotes[tname] or 0) + 1
        end
        local bestCount = 0
        for name, count in pairs(teamVotes) do
            if count > bestCount then bestName, bestCount = name, count end
        end
    end

    if bestName then
        activeMatch.score[bestName] = (activeMatch.score[bestName] or 0) + 1
        local m = activeMatch
        ChatAll(string.format("Round %d: \"%s\" scores! — %s %d : %d %s",
            m.rounds, bestName,
            m.team1, m.score[m.team1] or 0,
            m.score[m.team2] or 0, m.team2))
    end
end)

-- ── Cleanup on disconnect ─────────────────────────────────────────────────────

hook.Add("PlayerDisconnected", "ZC_CSTeams_Disconnect", function(ply)
    local sid = ply:SteamID64()

    -- Cancel any pending join requests involving this player
    for leaderSID, req in pairs(pendingJoin) do
        if req.requester == ply then
            timer.Remove(req.timerName)
            pendingJoin[leaderSID] = nil
        end
        if leaderSID == sid then
            -- Leader disconnected — cancel their incoming request
            timer.Remove(req.timerName)
            if IsValid(req.requester) then
                ChatPly(req.requester, "Team leader disconnected — your join request was cancelled.")
            end
            pendingJoin[leaderSID] = nil
        end
    end

    -- Note: we keep the player in their team's member list so they rejoin into it.
    -- playerTeam mapping is rebuilt on load from the members list.
end)

-- ── Re-associate on reconnect ─────────────────────────────────────────────────

hook.Add("PlayerInitialSpawn", "ZC_CSTeams_Reconnect", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        local sid = ply:SteamID64()
        local name = playerTeam[sid]
        if name and teams[name] then
            ChatPly(ply, "Welcome back — you are in team \"" .. name .. "\".")
        end
    end)
end)

-- ── Init ──────────────────────────────────────────────────────────────────────

hook.Add("InitPostEntity", "ZC_CSTeams_Load", function()
    LoadTeams()
end)

print("[ZC CS Teams] Team system loaded.")
