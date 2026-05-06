-- Map Voting System - Server Side
-- Replaces !rtv with a menu-based voting system with live vote tracking

if not game.IsDedicated() and not CLIENT then return end

-- Register ALL network strings FIRST (before any code tries to use them)
util.AddNetworkString("MapVote_StartVote")
util.AddNetworkString("MapVote_UpdateCounts")
util.AddNetworkString("MapVote_Cast")
util.AddNetworkString("MapVote_CastSuccess")
util.AddNetworkString("MapVote_OpenMenu")
util.AddNetworkString("MapVote_OpenAdminPanel")
util.AddNetworkString("MapVote_AdminAddMap")
util.AddNetworkString("MapVote_AdminRemoveMap")
util.AddNetworkString("MapVote_AdminResult")
util.AddNetworkString("MapVote_TiebreakerStart")
print("[MapVote] Network messages registered immediately on load")

local MapVoting = {}
MapVoting.Votes = {} -- { player_steamid = "mapname" }
MapVoting.VoteCounts = {} -- { mapname = count }
MapVoting.AvailableMaps = {}
MapVoting.VoteActive = false
MapVoting.VoteStartTime = 0
MapVoting.EarlyWinPending = false  -- true once 70% hit but countdown not done yet
MapVoting.TiebreakerActive = false  -- true during secondary tiebreaker round
MapVoting.FullMapPool = {}          -- original pool saved before tiebreaker narrows it
MapVoting.VOTE_DURATION = 60 -- seconds until automatic vote execution
MapVoting.VOTE_THRESHOLD = 0.7 -- 70% of active players required for map change
MapVoting.TIEBREAKER_THRESHOLD = 0.5 -- 50% required during tiebreaker round
MapVoting.DataFile = "dcitypatch/mapvote_maps.txt"

-- Ensure data directory exists
if not file.Exists("dcitypatch", "DATA") then
    file.CreateDir("dcitypatch")
end

-- Load available maps from file
function MapVoting:LoadMaps()
    if file.Exists(self.DataFile, "DATA") then
        local data = file.Read(self.DataFile, "DATA")
        if data and data ~= "" then
            self.AvailableMaps = util.JSONToTable(data) or {}
        end
    else
        -- If no file exists, initialize with common maps
        self.AvailableMaps = {
            "gm_flatgrass_fxp",
            "gm_construct",
        }
        self:SaveMaps()
    end
end

-- Save available maps to file
function MapVoting:SaveMaps()
    local data = util.TableToJSON(self.AvailableMaps)
    file.Write(self.DataFile, data)
end

-- Get total active player count
function MapVoting:GetActivePlayerCount()
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            count = count + 1
        end
    end
    return count
end

-- Start vote round
function MapVoting:StartVote()
    if not self.VoteActive then
        self.VoteActive = true
        self.EarlyWinPending = false
        self.VoteStartTime = CurTime()
        self.Votes = {}
        self:ResetVoteCounts()

        local mapCount = #self.AvailableMaps
        PrintMessage(HUD_PRINTTALK, "[MapVote] Map voting has started! Type !mapvote to vote. 70% majority required to pass.")
        print("[MapVote] Vote started with " .. mapCount .. " maps")

        net.Start("MapVote_StartVote")
        net.WriteTable(self.AvailableMaps)
        net.WriteInt(self.VOTE_DURATION, 32)
        net.Broadcast()

        self:BroadcastVoteCounts()
    else
        print("[MapVote] Attempted to start vote but one is already active")
    end
end

-- End vote round and change map if needed
function MapVoting:EndVote()
    if not self.VoteActive then return end

    self.VoteActive = false
    self.EarlyWinPending = false
    local winningMap = self:GetWinningMap()

    if winningMap then
        PrintMessage(HUD_PRINTTALK, "[MapVote] Vote passed! Changing to " .. winningMap .. " in 10 seconds...")
        print("[MapVote] Vote won by " .. winningMap .. " with " .. (self.VoteCounts[winningMap] or 0) .. " votes")
        timer.Simple(10, function()
            RunConsoleCommand("changelevel", winningMap)
        end)
    else
        -- Check if it's a tie between multiple maps
        local tiedMaps = self:GetTiedMaps()
        if tiedMaps then
            PrintMessage(HUD_PRINTTALK, "[MapVote] It's a tie! Starting tiebreaker vote in 3 seconds...")
            print("[MapVote] Tie between: " .. table.concat(tiedMaps, ", "))
            timer.Simple(3, function()
                MapVoting:StartTiebreaker(tiedMaps)
            end)
        else
            PrintMessage(HUD_PRINTTALK, "[MapVote] Vote ended. No map reached the required threshold.")
            print("[MapVote] Vote ended with no winner")
        end
    end
end

-- Returns a sorted list of maps tied at the top vote count, or nil if not a genuine tie
function MapVoting:GetTiedMaps()
    local highest = 0
    for _, count in pairs(self.VoteCounts) do
        if count > highest then highest = count end
    end
    if highest == 0 then return nil end  -- nobody voted
    local tied = {}
    for map, count in pairs(self.VoteCounts) do
        if count == highest then table.insert(tied, map) end
    end
    table.sort(tied)
    return (#tied >= 2) and tied or nil  -- only a tie if 2+ maps share top
end

-- Start a secondary tiebreaker round (50% threshold, no early-win interrupt)
function MapVoting:StartTiebreaker(tiedMaps)
    -- Save full pool so we can restore it after tiebreaker ends
    self.FullMapPool = self.AvailableMaps
    self.AvailableMaps = tiedMaps
    self.TiebreakerActive = true
    self.VoteActive = true
    self.EarlyWinPending = false
    self.VoteStartTime = CurTime()
    self.Votes = {}
    self:ResetVoteCounts()

    PrintMessage(HUD_PRINTTALK, "[MapVote] TIEBREAKER between: " .. table.concat(tiedMaps, ", ") .. " — 50% required, no early cutoff")
    print("[MapVote] Tiebreaker started")

    net.Start("MapVote_TiebreakerStart")
    net.WriteTable(tiedMaps)
    net.WriteInt(self.VOTE_DURATION, 32)
    net.Broadcast()

    self:BroadcastVoteCounts()

    -- Tiebreaker has its own one-shot timer; no early-win interrupt
    timer.Create("MapVote_TiebreakerTimeout", self.VOTE_DURATION + 1, 1, function()
        if MapVoting.TiebreakerActive then
            MapVoting:EndTiebreaker()
        end
    end)
end

-- End tiebreaker: 50% threshold; random pick if still deadlocked
function MapVoting:EndTiebreaker()
    if not self.TiebreakerActive then return end
    self.TiebreakerActive = false
    self.VoteActive = false

    -- Restore original map pool
    self.AvailableMaps = self.FullMapPool
    self.FullMapPool = {}

    local activePlayers = self:GetActivePlayerCount()
    local required = math.max(1, math.ceil(activePlayers * self.TIEBREAKER_THRESHOLD))

    local winner = nil
    local highestVotes = 0
    for map, count in pairs(self.VoteCounts) do
        if count > highestVotes then
            highestVotes = count
            winner = map
        end
    end

    if winner and highestVotes >= required then
        PrintMessage(HUD_PRINTTALK, "[MapVote] Tiebreaker: " .. winner .. " wins! Changing map in 10 seconds...")
        print("[MapVote] Tiebreaker won by " .. winner)
        timer.Simple(10, function() RunConsoleCommand("changelevel", winner) end)
    else
        -- Still deadlocked — pick randomly from the remaining tied maps
        local candidates = {}
        local topCount = 0
        for _, count in pairs(self.VoteCounts) do
            if count > topCount then topCount = count end
        end
        for map, count in pairs(self.VoteCounts) do
            if count == topCount then table.insert(candidates, map) end
        end
        -- Fallback: if all zero, pick from the tiebreaker map set
        if #candidates == 0 then candidates = table.GetKeys(self.VoteCounts) end
        local picked = candidates[math.random(1, #candidates)]
        PrintMessage(HUD_PRINTTALK, "[MapVote] Tiebreaker inconclusive. Randomly selected: " .. picked .. "! Changing map in 10 seconds...")
        print("[MapVote] Tiebreaker random pick: " .. picked)
        timer.Simple(10, function() RunConsoleCommand("changelevel", picked) end)
    end
end

-- Called after every vote cast — schedules EndVote if 70% threshold is newly hit
-- Does NOT immediately end the vote so players have a chance to see results
-- Skipped entirely during tiebreaker (no early interrupt there)
function MapVoting:CheckEarlyWin()
    if not self.VoteActive then return end
    if self.EarlyWinPending then return end  -- already counting down
    if self.TiebreakerActive then return end  -- tiebreaker runs full duration

    local winner = self:GetWinningMap()
    if not winner then return end

    self.EarlyWinPending = true
    local votes = self.VoteCounts[winner] or 0
    PrintMessage(HUD_PRINTTALK, "[MapVote] " .. winner .. " has reached 70% (" .. votes .. " votes)! Vote ends in 10 seconds unless more votes change it.")
    print("[MapVote] Early-win countdown started for " .. winner)

    timer.Create("MapVote_EarlyWin", 10, 1, function()
        if not MapVoting.VoteActive then return end
        MapVoting:EndVote()
    end)
end

-- Reset vote counts
function MapVoting:ResetVoteCounts()
    self.VoteCounts = {}
    for i, map in ipairs(self.AvailableMaps) do
        self.VoteCounts[map] = 0
    end
end

-- Get winning map (if any)
function MapVoting:GetWinningMap()
    local activePlayers = self:GetActivePlayerCount()
    if activePlayers <= 0 then return nil end

    local requiredVotes = math.max(1, math.ceil(activePlayers * self.VOTE_THRESHOLD))

    local highestMap = nil
    local highestVotes = 0

    for map, count in pairs(self.VoteCounts) do
        if count > highestVotes then
            highestVotes = count
            highestMap = map
        end
    end

    if highestVotes >= requiredVotes then
        return highestMap
    end
    
    return nil
end

-- Register a vote from a player
function MapVoting:CastVote(ply, mapname)
    if not self.VoteActive then 
        print("[MapVote] Vote cast attempted but vote not active")
        return false 
    end
    if not table.HasValue(self.AvailableMaps, mapname) then 
        print("[MapVote] Invalid map vote: " .. mapname)
        return false 
    end
    
    local steamid = ply:SteamID()
    local who = (IsValid(ply) and (ply:Nick() .. "[" .. (ply:SteamID64() or "unknown") .. "]")) or "Console[server]"
    
    -- Remove previous vote if exists
    if self.Votes[steamid] then
        local oldMap = self.Votes[steamid]
        self.VoteCounts[oldMap] = math.max(0, self.VoteCounts[oldMap] - 1)
        print("[MapVote] " .. who .. " changed vote from " .. oldMap .. " to " .. mapname)
    else
        print("[MapVote] " .. who .. " voted for " .. mapname)
    end
    
    -- Add new vote
    self.Votes[steamid] = mapname
    self.VoteCounts[mapname] = (self.VoteCounts[mapname] or 0) + 1

    -- Broadcast updated vote counts to all players
    self:BroadcastVoteCounts()

    -- Check if early-win threshold just crossed
    self:CheckEarlyWin()

    return true
end

-- Broadcast current vote counts to all clients
function MapVoting:BroadcastVoteCounts()
    net.Start("MapVote_UpdateCounts")
    net.WriteTable(self.VoteCounts)
    net.WriteInt(self:GetActivePlayerCount(), 32)
    net.Broadcast()
end

-- Get all BSP map names available on the server
function MapVoting:GetAllServerMaps()
    local maps = {}
    local files, _ = file.Find("maps/*.bsp", "GAME")
    for _, f in ipairs(files or {}) do
        local name = string.StripExtension(f)
        table.insert(maps, name)
    end
    table.sort(maps)
    return maps
end

-- Add a map to the voting list (admin only)
function MapVoting:AddMap(mapname)
    if table.HasValue(self.AvailableMaps, mapname) then
        return false, "Map already in list"
    end

    if not file.Exists("maps/" .. mapname .. ".bsp", "GAME") then
        return false, "Map file not found"
    end

    table.insert(self.AvailableMaps, mapname)
    table.sort(self.AvailableMaps)
    self:SaveMaps()
    return true, "Map added: " .. mapname
end

-- Remove a map from the voting list (admin only)
function MapVoting:RemoveMap(mapname)
    local idx = table.KeyFromValue(self.AvailableMaps, mapname)
    if not idx then
        return false, "Map not found in list"
    end
    
    table.remove(self.AvailableMaps, idx)
    self:SaveMaps()
    return true, "Map removed successfully"
end

-- Get map list as a formatted string
function MapVoting:GetMapListString()
    local str = "Available maps:\n"
    for i, map in ipairs(self.AvailableMaps) do
        str = str .. i .. ". " .. map .. "\n"
    end
    return str
end

-- NET MESSAGES

-- Network strings are registered at the top of this file before anything else

-- Vote cast
net.Receive("MapVote_Cast", function(len, ply)
    local mapname = net.ReadString()
    local success = MapVoting:CastVote(ply, mapname)

    if success then
        net.Start("MapVote_CastSuccess")
        net.WriteString(mapname)
        net.Send(ply)
    end
end)

-- Admin requests map manager panel
net.Receive("MapVote_OpenAdminPanel", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local allMaps = MapVoting:GetAllServerMaps()
    net.Start("MapVote_OpenAdminPanel")
    net.WriteTable(allMaps)
    net.WriteTable(MapVoting.AvailableMaps)
    net.Send(ply)
end)

-- Admin adds a map
net.Receive("MapVote_AdminAddMap", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local mapname = net.ReadString()
    local ok, msg = MapVoting:AddMap(mapname)
    net.Start("MapVote_AdminResult")
    net.WriteBool(ok)
    net.WriteString(msg)
    net.WriteTable(MapVoting.AvailableMaps)
    net.Send(ply)
end)

-- Admin removes a map
net.Receive("MapVote_AdminRemoveMap", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local mapname = net.ReadString()
    local ok, msg = MapVoting:RemoveMap(mapname)
    net.Start("MapVote_AdminResult")
    net.WriteBool(ok)
    net.WriteString(msg)
    net.WriteTable(MapVoting.AvailableMaps)
    net.Send(ply)
end)

-- CONSOLE COMMANDS

local function HasMapVoteAccess(ply, requireSuperAdmin)
    if not IsValid(ply) then return false end

    local ulxLib = rawget(_G, "ULX") or rawget(_G, "ulx")

    if requireSuperAdmin then
        if ply:IsSuperAdmin() then return true end
    else
        if ply:IsAdmin() then return true end
    end

    return ulxLib and ulxLib.CheckAccess and ulxLib.CheckAccess(ply, "ulx mapvote")
end

concommand.Add("mapvote_list", function(ply, cmd, args)
    if not IsValid(ply) then return end
    ply:PrintMessage(HUD_PRINTTALK, MapVoting:GetMapListString())
end)

concommand.Add("mapvote_add", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not HasMapVoteAccess(ply, false) then
        ply:PrintMessage(HUD_PRINTTALK, "Access denied.")
        return
    end
    
    if not args[1] then
        ply:PrintMessage(HUD_PRINTTALK, "Usage: mapvote_add <mapname>")
        return
    end
    
    local success, msg = MapVoting:AddMap(args[1])
    ply:PrintMessage(HUD_PRINTTALK, msg)
    
    if success then
        PrintMessage(HUD_PRINTCONSOLE, "Admin added map: " .. args[1])
    end
end)

concommand.Add("mapvote_remove", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not HasMapVoteAccess(ply, false) then
        ply:PrintMessage(HUD_PRINTTALK, "Access denied.")
        return
    end
    
    if not args[1] then
        ply:PrintMessage(HUD_PRINTTALK, "Usage: mapvote_remove <mapname>")
        return
    end
    
    local success, msg = MapVoting:RemoveMap(args[1])
    ply:PrintMessage(HUD_PRINTTALK, msg)
    
    if success then
        PrintMessage(HUD_PRINTCONSOLE, "Admin removed map: " .. args[1])
    end
end)

concommand.Add("mapvote_start", function(ply, cmd, args)
    if not HasMapVoteAccess(ply, true) then
        ply:PrintMessage(HUD_PRINTTALK, "Access denied.")
        return
    end
    
    MapVoting:StartVote()
end)

concommand.Add("rtv", function(ply, cmd, args)
    if not IsValid(ply) then return end
    
    if MapVoting.VoteActive then
        ply:PrintMessage(HUD_PRINTTALK, "A vote is already in progress!")
        return
    end
    
    MapVoting:StartVote()
    ply:PrintMessage(HUD_PRINTTALK, "You started a map vote! Type !mapvote to vote.")
end)

concommand.Add("mapvote_end", function(ply, cmd, args)
    if not HasMapVoteAccess(ply, true) then
        ply:PrintMessage(HUD_PRINTTALK, "Access denied.")
        return
    end
    
    MapVoting:EndVote()
end)

-- Open voting menu for a specific player
function mapvote_OpenMenuFor(ply)
    if not IsValid(ply) then return end
    
    if not MapVoting.VoteActive then
        ply:PrintMessage(HUD_PRINTTALK, "[MapVote] No vote is currently active. Type !rtv to start one.")
        return
    end
    
    net.Start("MapVote_OpenMenu")
    net.WriteTable(MapVoting.AvailableMaps)
    net.WriteTable(MapVoting.VoteCounts)
    net.WriteInt(MapVoting:GetActivePlayerCount(), 32)
    net.WriteString(MapVoting.Votes[ply:SteamID()] or "")
    net.WriteFloat(MapVoting.VoteStartTime + MapVoting.VOTE_DURATION)
    net.Send(ply)
end

_G.mapvote_OpenMenuFor = mapvote_OpenMenuFor

-- INITIALIZATION
print("[MapVote] Initializing map voting system...")
MapVoting:LoadMaps()
print("[MapVote] Loaded " .. #MapVoting.AvailableMaps .. " maps from storage")

-- Auto-end vote after duration (only if early-win countdown hasn't already claimed it)
-- Tiebreaker uses its own separate timer (MapVote_TiebreakerTimeout)
timer.Create("MapVote_CheckTimeout", 1, 0, function()
    if MapVoting.VoteActive
    and not MapVoting.EarlyWinPending
    and not MapVoting.TiebreakerActive
    and (CurTime() - MapVoting.VoteStartTime) > MapVoting.VOTE_DURATION then
        MapVoting:EndVote()
    end
end)

-- Optional: Auto-start vote on map load
hook.Add("InitPostEntity", "MapVote_Init", function()
    print("[MapVote] InitPostEntity: System ready")
    -- Could auto-start vote here if desired
    -- MapVoting:StartVote()
end)

_G.MapVoting = MapVoting
print("[MapVote] Server-side voting system loaded successfully")
