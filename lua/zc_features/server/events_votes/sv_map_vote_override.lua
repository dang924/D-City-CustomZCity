-- Map Voting System - RTV Command Override
-- Disables the core Z-City RTV menu and replaces it with our new system

if CLIENT then return end

print("[MapVote] Loading RTV override module...")

-- Hook to override the core RTV command after it loads
hook.Add("InitPostEntity", "MapVote_OverrideRTV", function()
    -- Override the COMMANDS.rtv to call our new voting system instead
    if COMMANDS and COMMANDS.rtv then
        print("[MapVote] Overriding core RTV command...")
        COMMANDS.rtv = {function(ply, args)
            -- Call our new map voting system instead of the old RTV menu
            if MapVoting then
                if MapVoting.VoteActive then
                    ply:PrintMessage(HUD_PRINTTALK, "[MapVote] A vote is already in progress!")
                    print("[MapVote] RTV block: vote already active for " .. ply:Nick() .. "[" .. (ply:SteamID64() or "unknown") .. "]")
                    return
                end
                
                MapVoting:StartVote()
                ply:PrintMessage(HUD_PRINTTALK, "[MapVote] You started a map vote! Type !mapvote to vote.")
                print("[MapVote] RTV override: " .. ply:Nick() .. "[" .. (ply:SteamID64() or "unknown") .. "] started a vote")
                return true
            else
                ply:PrintMessage(HUD_PRINTTALK, "[MapVote] System not loaded yet")
                print("[MapVote] ERROR: MapVoting not loaded yet in RTV override")
            end
        end, "MAP", "Start a map vote", 1, function() return true end}
    else
        print("[MapVote] WARNING: COMMANDS.rtv not found to override")
    end
end)

print("[MapVote] RTV override module loaded")
