-- Map Voting System - ULX Module
-- Proper integration with Z-City's command system
-- Place in: lua/ulx/modules/sh/

local ulxLib = rawget(_G, "ulx") or rawget(_G, "ULX")

if not ulxLib then
    print("[MapVote] ERROR: ULX not found! Re-order addon load or check ULX installation")
    return
end

print("[MapVote] Loading ULX module...")

local CATEGORY_NAME = "Map Voting"

if SERVER then

-- ── Chat command interceptor ──────────────────────────────────────────────────
-- Z-City's chat system swallows messages, so we hook HG_PlayerSay to intercept
-- !mapvote and !rtv before the message is lost

hook.Add("HG_PlayerSay", "MapVote_ChatCommands", function(ply, txtTbl, text)
    local cmd = string.lower(string.Trim(text))
    
    -- Handle !mapvote
    if cmd == "!mapvote" or cmd == "/mapvote" then
        if not IsValid(ply) then return end
        
        txtTbl[1] = "" -- suppress from chat
        
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            if mapvote_OpenMenuFor then
                mapvote_OpenMenuFor(ply)
            else
                ply:PrintMessage(HUD_PRINTTALK, "[MapVote] Menu system not loaded yet")
            end
        end)
        
        print("[MapVote] Chat: " .. ply:Nick() .. " opened mapvote menu")
        return
    end
    
    -- Handle !rtv (delegate to MapVoting:StartVote)
    if cmd == "!rtv" or cmd == "/rtv" then
        if not IsValid(ply) then return end
        
        txtTbl[1] = "" -- suppress from chat
        
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            if MapVoting then
                if MapVoting.VoteActive then
                    ply:PrintMessage(HUD_PRINTTALK, "[MapVote] A vote is already in progress!")
                    return
                end
                
                MapVoting:StartVote()
                ply:PrintMessage(HUD_PRINTTALK, "[MapVote] You started a map vote! Type !mapvote to vote.")
                print("[MapVote] Chat: " .. ply:Nick() .. " started a vote")
            else
                ply:PrintMessage(HUD_PRINTTALK, "[MapVote] System not loaded yet")
            end
        end)
        
        return
    end
end)

-- ── Admin commands via ULX ─────────────────────────────────────────────────────

-- !addmap <mapname> — Add a map to voting pool
local function ulxAddMap(calling_ply, mapname_str)
    mapname_str = string.Trim(mapname_str)
    
    if not IsValid(calling_ply) then
        print("[MapVote] Console cannot add maps directly")
        return
    end
    
    if not MapVoting then
        ULib.tsay(_, "[MapVote] ERROR: System not loaded!")
        ulx.logString(calling_ply:Nick() .. " tried to add map but system not loaded")
        return
    end
    
    local success, msg = MapVoting:AddMap(mapname_str)
    
    if success then
        ULib.tsay(_, "[MapVote] " .. calling_ply:Nick() .. " added map: " .. mapname_str)
        ulx.logString(calling_ply:Nick() .. " added map to voting pool: " .. mapname_str)
    else
        ULib.tsay(calling_ply, "[MapVote] " .. msg)
        ulx.logString(calling_ply:Nick() .. " failed to add map (" .. msg .. "): " .. mapname_str)
    end
end

local cmd = ulx.command(CATEGORY_NAME, "ulx addmap", ulxAddMap, "!addmap")
cmd:addParam{ type = ULib.cmds.String, default = "", hint = "map name" }
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Add a map to the map voting pool")
print("[MapVote] Registered: ulx addmap (!addmap)")

-- !removemap <mapname> — Remove a map from voting pool
local function ulxRemoveMap(calling_ply, mapname_str)
    mapname_str = string.Trim(mapname_str)
    
    if not IsValid(calling_ply) then
        print("[MapVote] Console cannot remove maps directly")
        return
    end
    
    if not MapVoting then
        ULib.tsay(_, "[MapVote] ERROR: System not loaded!")
        ulx.logString(calling_ply:Nick() .. " tried to remove map but system not loaded")
        return
    end
    
    local success, msg = MapVoting:RemoveMap(mapname_str)
    
    if success then
        ULib.tsay(_, "[MapVote] " .. calling_ply:Nick() .. " removed map: " .. mapname_str)
        ulx.logString(calling_ply:Nick() .. " removed map from voting pool: " .. mapname_str)
    else
        ULib.tsay(calling_ply, "[MapVote] " .. msg)
        ulx.logString(calling_ply:Nick() .. " failed to remove map (" .. msg .. "): " .. mapname_str)
    end
end

local cmd = ulx.command(CATEGORY_NAME, "ulx removemap", ulxRemoveMap, "!removemap")
cmd:addParam{ type = ULib.cmds.String, default = "", hint = "map name" }
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Remove a map from the map voting pool")
print("[MapVote] Registered: ulx removemap (!removemap)")

-- !mapvote_start — Force start a vote (admin)
local function ulxStartVote(calling_ply)
    if not MapVoting then
        ULib.tsay(_, "[MapVote] ERROR: System not loaded!")
        return
    end
    
    if MapVoting.VoteActive then
        ULib.tsay(calling_ply, "[MapVote] A vote is already in progress!")
        return
    end
    
    MapVoting:StartVote()
    ULib.tsay(_, "[MapVote] " .. (IsValid(calling_ply) and calling_ply:Nick() or "Console") .. " started a map vote")
    ulx.logString((IsValid(calling_ply) and calling_ply:Nick() or "Console") .. " started a map vote")
end

local cmd = ulx.command(CATEGORY_NAME, "ulx mapvote_start", ulxStartVote, "!mapvote_start")
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Start a map voting round")
print("[MapVote] Registered: ulx mapvote_start (!mapvote_start)")

-- !mapvote_end — Force end a vote (superadmin)
local function ulxEndVote(calling_ply)
    if not MapVoting then
        ULib.tsay(_, "[MapVote] ERROR: System not loaded!")
        return
    end
    
    if not MapVoting.VoteActive then
        ULib.tsay(calling_ply, "[MapVote] No vote is currently active!")
        return
    end
    
    MapVoting:EndVote()
    ULib.tsay(_, "[MapVote] " .. (IsValid(calling_ply) and calling_ply:Nick() or "Console") .. " ended the map vote")
    ulx.logString((IsValid(calling_ply) and calling_ply:Nick() or "Console") .. " ended the map vote")
end

local cmd = ulx.command(CATEGORY_NAME, "ulx mapvote_end", ulxEndVote, "!mapvote_end")
cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
cmd:help("End the current map voting round")
print("[MapVote] Registered: ulx mapvote_end (!mapvote_end)")

-- !mapmanager — Open the GUI map manager panel (admin)
local function ulxMapManager(calling_ply)
    if not IsValid(calling_ply) then
        print("[MapVote] Console cannot open map manager GUI")
        return
    end

    if not MapVoting then
        ULib.tsay(calling_ply, "[MapVote] ERROR: System not loaded!")
        return
    end

    local allMaps = MapVoting:GetAllServerMaps()
    net.Start("MapVote_OpenAdminPanel")
    net.WriteTable(allMaps)
    net.WriteTable(MapVoting.AvailableMaps)
    net.Send(calling_ply)

    ulx.logString(calling_ply:Nick() .. " opened the map manager panel")
end

local cmd = ulx.command(CATEGORY_NAME, "ulx mapmanager", ulxMapManager, "!mapmanager")
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Open the GUI map manager to add/remove RTV maps")
print("[MapVote] Registered: ulx mapmanager (!mapmanager)")

-- Also intercept !mapmanager in chat
hook.Add("HG_PlayerSay", "MapVote_ChatManager", function(ply, txtTbl, text)
    local cmd_str = string.lower(string.Trim(text))
    if cmd_str == "!mapmanager" or cmd_str == "/mapmanager" then
        if not IsValid(ply) then return end
        txtTbl[1] = ""
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            if not ply:IsAdmin() then
                ply:PrintMessage(HUD_PRINTTALK, "[MapVote] Admins only.")
                return
            end
            if MapVoting then
                local allMaps = MapVoting:GetAllServerMaps()
                net.Start("MapVote_OpenAdminPanel")
                net.WriteTable(allMaps)
                net.WriteTable(MapVoting.AvailableMaps)
                net.Send(ply)
            end
        end)
        return
    end
end)

end -- SERVER

print("[MapVote] ULX module loaded successfully!")
