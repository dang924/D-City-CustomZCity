-- Map Voting System - Server Side
-- Replaces !rtv with a menu-based voting system with live vote tracking

if not game.IsDedicated() and not CLIENT then return end

-- Register ALL network strings FIRST (before any code tries to use them)
util.AddNetworkString("MapVote_StartVote")
util.AddNetworkString("MapVote_UpdateCounts")
util.AddNetworkString("MapVote_Cast")
util.AddNetworkString("MapVote_CastSuccess")
util.AddNetworkString("MapVote_OpenMenu")
print("[MapVote] Network messages registered immediately on load")

local MapVoting = {}
MapVoting.Votes = {} -- { player_steamid = "mapname" }
MapVoting.VoteCounts = {} -- { mapname = count }
MapVoting.AvailableMaps = {}
MapVoting.VoteActive = false
MapVoting.VoteStartTime = 0
MapVoting.VOTE_DURATION = 60 -- seconds until automatic vote execution
MapVoting.VOTE_THRESHOLD = 0.7 -- 70% of active players required for map change
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
        self.VoteStartTime = CurTime()
        self.Votes = {}
        self:ResetVoteCounts()
        
        -- Notify all players
        local mapCount = #self.AvailableMaps
        PrintMessage(HUD_PRINTTALK, "[MapVote] Map voting has started! Type !mapvote to vote. 70% is required to pass.")
        print("[MapVote] Vote started with " .. mapCount .. " maps")
        
        -- Reset vote counts GUI on all clients
        net.Start("MapVote_StartVote")
        net.WriteTable(self.AvailableMaps)
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
    local winningMap = self:GetWinningMap()
    
    if winningMap then
        PrintMessage(HUD_PRINTTALK, "[MapVote] Vote passed! Changing to " .. winningMap .. " in 10 seconds...")
        print("[MapVote] Vote won by " .. winningMap .. " with " .. (self.VoteCounts[winningMap] or 0) .. " votes")
        timer.Simple(10, function()
            RunConsoleCommand("changelevel", winningMap)
        end)
    else
        PrintMessage(HUD_PRINTTALK, "[MapVote] No map reached voting threshold.")
        print("[MapVote] Vote ended with no winner")
    end
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
    
    -- Remove previous vote if exists
    if self.Votes[steamid] then
        local oldMap = self.Votes[steamid]
        self.VoteCounts[oldMap] = math.max(0, self.VoteCounts[oldMap] - 1)
        print("[MapVote] " .. ply:Nick() .. " changed vote from " .. oldMap .. " to " .. mapname)
    else
        print("[MapVote] " .. ply:Nick() .. " voted for " .. mapname)
    end
    
    -- Add new vote
    self.Votes[steamid] = mapname
    self.VoteCounts[mapname] = (self.VoteCounts[mapname] or 0) + 1
    
    -- Broadcast updated vote counts to all players
    self:BroadcastVoteCounts()
    
    return true
end

-- Broadcast current vote counts to all clients
function MapVoting:BroadcastVoteCounts()
    net.Start("MapVote_UpdateCounts")
    net.WriteTable(self.VoteCounts)
    net.WriteInt(self:GetActivePlayerCount(), 32)
    net.Broadcast()
end

-- Add a map to the voting list (admin only)
function MapVoting:AddMap(mapname)
    if table.HasValue(self.AvailableMaps, mapname) then
        return false, "Map already in list"
    end
    
    -- Validate map exists
    if not file.Exists("maps/" .. mapname .. ".bsp", "GAME") then
        return false, "Map file not found"
    end
    
    table.insert(self.AvailableMaps, mapname)
    self:SaveMaps()
    return true, "Map added successfully"
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

-- Register net receiver for vote casts
net.Receive("MapVote_Cast", function(len, ply)
    local mapname = net.ReadString()
    local success = MapVoting:CastVote(ply, mapname)
    
    if success then
        net.Start("MapVote_CastSuccess")
        net.WriteString(mapname)
        net.Send(ply)
    end
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
    net.Send(ply)
end

_G.mapvote_OpenMenuFor = mapvote_OpenMenuFor

-- INITIALIZATION
print("[MapVote] Initializing map voting system...")
MapVoting:LoadMaps()
print("[MapVote] Loaded " .. #MapVoting.AvailableMaps .. " maps from storage")

-- Auto-end vote after duration
timer.Create("MapVote_CheckTimeout", 1, 0, function()
    if MapVoting.VoteActive and (CurTime() - MapVoting.VoteStartTime) > MapVoting.VOTE_DURATION then
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
