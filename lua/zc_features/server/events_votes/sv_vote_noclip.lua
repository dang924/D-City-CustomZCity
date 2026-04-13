if CLIENT then return end

local VOTE_DURATION = 45
local VOTE_COMMANDS = {
    ["!votenoclip"] = true,
    ["/votenoclip"] = true,
}

local voteState = {
    active = false,
    enabled = false,
    votes = {},
    expiresAt = 0,
}

local originalHookPlayerNoClip

local function DefaultPlayerNoClip(ply, desiredState)
    if desiredState == false then
        return true
    elseif ply:IsAdmin() then
        return true
    end

    return false
end

local function VotePlayerNoClip()
    return true
end

local function BroadcastChat(message)
    PrintMessage(HUD_PRINTTALK, message)
    print(message)
end

local function GetEligiblePlayers()
    local players = {}

    for _, ply in ipairs(player.GetHumans()) do
        if IsValid(ply) and not ply:IsBot() then
            players[#players + 1] = ply
        end
    end

    return players
end

local function GetRequiredVotes()
    local totalPlayers = #GetEligiblePlayers()
    if totalPlayers <= 0 then return 1, totalPlayers end

    return math.floor(totalPlayers * 0.5) + 1, totalPlayers
end

local function GetVoteCount()
    local count = 0

    for _ in pairs(voteState.votes) do
        count = count + 1
    end

    return count
end

local function TrimVotesToActivePlayers()
    local active = {}

    for _, ply in ipairs(GetEligiblePlayers()) do
        active[ply:SteamID()] = true
    end

    for steamID in pairs(voteState.votes) do
        if not active[steamID] then
            voteState.votes[steamID] = nil
        end
    end
end

local function TryCaptureHookPlayerNoClip()
    if originalHookPlayerNoClip then return true end
    if not Hook or not isfunction(Hook.PlayerNoClip) then return false end

    originalHookPlayerNoClip = Hook.PlayerNoClip
    return true
end

local function SyncNoClipAccess()
    if voteState.enabled then
        hook.Remove("PlayerNoClip", "FeelFreeToTurnItOff")

        if TryCaptureHookPlayerNoClip() then
            Hook.PlayerNoClip = VotePlayerNoClip
        end

        return
    end

    hook.Add("PlayerNoClip", "FeelFreeToTurnItOff", DefaultPlayerNoClip)

    if originalHookPlayerNoClip then
        Hook.PlayerNoClip = originalHookPlayerNoClip
    end
end

local function EndVote()
    voteState.active = false
    voteState.votes = {}
    voteState.expiresAt = 0
    timer.Remove("ZC_VoteNoClip_Timeout")
end

local function EnableVoteNoClip()
    voteState.enabled = true
    SyncNoClipAccess()
    EndVote()
    BroadcastChat("[VoteNoClip] Vote passed. Noclip is now enabled for everyone until the map changes.")
end

local function CheckVoteSuccess()
    TrimVotesToActivePlayers()

    local requiredVotes, totalPlayers = GetRequiredVotes()
    local currentVotes = GetVoteCount()

    if currentVotes >= requiredVotes then
        EnableVoteNoClip()
        return true
    end

    if voteState.active then
        BroadcastChat("[VoteNoClip] " .. currentVotes .. "/" .. totalPlayers .. " approvals. " .. requiredVotes .. " needed to enable noclip.")
    end

    return false
end

local function StartVote(ply)
    voteState.active = true
    voteState.votes = {}
    voteState.expiresAt = CurTime() + VOTE_DURATION

    timer.Create("ZC_VoteNoClip_Timeout", VOTE_DURATION, 1, function()
        if not voteState.active then return end

        local currentVotes = GetVoteCount()
        local requiredVotes, totalPlayers = GetRequiredVotes()
        EndVote()
        BroadcastChat("[VoteNoClip] Vote failed. " .. currentVotes .. "/" .. totalPlayers .. " approvals; " .. requiredVotes .. " were required.")
    end)

    BroadcastChat("[VoteNoClip] " .. ply:Nick() .. " started a noclip vote. Type !votenoclip within " .. VOTE_DURATION .. " seconds to approve.")
end

local function HandleVoteCommand(ply, txtTbl)
    if not IsValid(ply) then return end

    if istable(txtTbl) then
        txtTbl[1] = ""
    end

    if voteState.enabled then
        ply:ChatPrint("[VoteNoClip] Noclip is already enabled until the map changes.")
        return true
    end

    if not voteState.active then
        StartVote(ply)
    end

    local steamID = ply:SteamID()
    if voteState.votes[steamID] then
        local requiredVotes, totalPlayers = GetRequiredVotes()
        ply:ChatPrint("[VoteNoClip] You already voted. Current approvals: " .. GetVoteCount() .. "/" .. totalPlayers .. ". Needed: " .. requiredVotes .. ".")
        return true
    end

    voteState.votes[steamID] = true
    CheckVoteSuccess()
    return true
end

hook.Add("HG_PlayerSay", "ZC_VoteNoClip_ChatCommand", function(ply, txtTbl, text)
    local cmd = string.lower(string.Trim(tostring(text or "")))
    if not VOTE_COMMANDS[cmd] then return end

    if HandleVoteCommand(ply, txtTbl) then
        return ""
    end
end)

hook.Add("PlayerDisconnected", "ZC_VoteNoClip_PlayerDisconnected", function(ply)
    if not voteState.active then return end

    voteState.votes[ply:SteamID()] = nil
    CheckVoteSuccess()
end)

hook.Add("PlayerInitialSpawn", "ZC_VoteNoClip_PlayerInitialSpawn", function(ply)
    if not voteState.enabled then return end

    timer.Simple(2, function()
        if not IsValid(ply) then return end
        ply:ChatPrint("[VoteNoClip] Noclip is currently enabled for everyone until the map changes.")
    end)
end)

hook.Add("InitPostEntity", "ZC_VoteNoClip_Init", function()
    SyncNoClipAccess()
end)
