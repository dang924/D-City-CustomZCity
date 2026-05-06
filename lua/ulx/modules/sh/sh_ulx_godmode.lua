-- sh_ulx_godmode.lua - ULX toggle for organism godmode (global or per player via chat).
-- Place in: lua/ulx/modules/sh/

if not SERVER then return end
if not ulx or not ULib then return end

local CATEGORY_NAME = "ZCity"
local lastGodmodeChat = {}

local function setPlayerGodMode(target_ply, enabled)
    if isfunction(ZC_SetPlayerOrganismGodMode) then
        return ZC_SetPlayerOrganismGodMode(target_ply, enabled)
    end

    ZC_OrgGodModePlayers = ZC_OrgGodModePlayers or {}
    if not IsValid(target_ply) or not target_ply:IsPlayer() then return false end

    if enabled then
        ZC_OrgGodModePlayers[target_ply] = true
    else
        ZC_OrgGodModePlayers[target_ply] = nil
    end

    return true
end

local function getPlayerGodMode(target_ply)
    if isfunction(ZC_GetPlayerOrganismGodMode) then
        return ZC_GetPlayerOrganismGodMode(target_ply)
    end

    return IsValid(target_ply) and target_ply:IsPlayer()
        and istable(ZC_OrgGodModePlayers) and ZC_OrgGodModePlayers[target_ply] == true or false
end

local function ulxGodMode(calling_ply, enabled)
    enabled = tonumber(enabled) == 1
    ZC_OrgGodMode = enabled

    local stateText = enabled and "ENABLED" or "DISABLED"

    if ulx.fancyLogAdmin and IsValid(calling_ply) then
        ulx.fancyLogAdmin(calling_ply, "#A set organism godmode to #s", stateText)
    else
        local actor = IsValid(calling_ply) and calling_ply:Nick() or "Console"
        local msg = "Organism God Mode " .. stateText .. " by " .. actor
        ulx.logString(msg)
        print(msg)
    end
end

local function ulxPlayerGodMode(calling_ply, target_ply, enabled)
    if not IsValid(target_ply) then
        if IsValid(calling_ply) then
            ULib.tsay(calling_ply, "Select a valid player target.")
        end
        return
    end

    local state = enabled
    if state == nil then
        state = not getPlayerGodMode(target_ply)
    else
        state = tonumber(state) == 1
    end

    if not setPlayerGodMode(target_ply, state) then
        if IsValid(calling_ply) then
            ULib.tsay(calling_ply, "Could not update organism godmode for that player.")
        end
        return
    end

    local stateText = state and "ENABLED" or "DISABLED"

    if ulx.fancyLogAdmin and IsValid(calling_ply) then
        ulx.fancyLogAdmin(calling_ply, "#A set organism godmode for #T to #s", target_ply, stateText)
    else
        local actor = IsValid(calling_ply) and calling_ply:Nick() or "Console"
        local msg = "Organism God Mode " .. stateText .. " for " .. target_ply:Nick() .. " by " .. actor
        ulx.logString(msg)
        print(msg)
    end
end

local function findPlayerByQuery(query)
    query = string.Trim(string.lower(tostring(query or "")))
    if query == "" then
        return nil, "Specify a player name."
    end

    local partialMatches = {}
    for _, target in ipairs(player.GetAll()) do
        local nick = string.lower(target:Nick() or "")
        local steamId = string.lower(target:SteamID() or "")
        local steamId64 = tostring(target:SteamID64() or "")

        if nick == query or steamId == query or steamId64 == query then
            return target
        end

        if string.find(nick, query, 1, true) then
            partialMatches[#partialMatches + 1] = target
        end
    end

    if #partialMatches == 1 then
        return partialMatches[1]
    end

    if #partialMatches > 1 then
        return nil, "Multiple players match '" .. query .. "'."
    end

    return nil, "No player matches '" .. query .. "'."
end

local cmd = ulx.command(CATEGORY_NAME, "ulx godmode", ulxGodMode, "!godmode")
cmd:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "1 = enable godmode, 0 = disable godmode" }
cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
cmd:help("Toggles organism godmode for all players. Chat also supports !godmode <name> [1/0] for individual players.")

local playerCmd = ulx.command(CATEGORY_NAME, "ulx playergodmode", ulxPlayerGodMode, "!playergodmode")
playerCmd:addParam{ type = ULib.cmds.PlayerArg, hint = "target player" }
playerCmd:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "1 = enable godmode, 0 = disable godmode", ULib.cmds.optional }
playerCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
playerCmd:help("Toggles organism godmode for one player. If 1/0 is omitted, it toggles that player's state.")

-- ZChat can swallow PlayerSay before ULX sees it. Intercept here once and consume.
hook.Add("HG_PlayerSay", "ZC_GodMode_ChatCommand", function(ply, txtTbl, text)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local raw = string.Trim(tostring(text or ""))
    local cmdLower, arg = string.match(string.lower(raw), "^([!/][%w_]+)%s*(.-)%s*$")
    if cmdLower ~= "!godmode" and cmdLower ~= "/godmode" then return end

    if istable(txtTbl) then txtTbl[1] = "" end

    if not ULib.ucl or not ULib.ucl.query or not ULib.ucl.query(ply, "ulx godmode") then
        return ""
    end

    local targetPly
    local enabled
    local keySuffix
    local stateArg, targetArg = string.match(arg, "^(%d)%s*$"), nil

    if arg == "" then
        targetPly = ply
        enabled = not getPlayerGodMode(targetPly)
        keySuffix = "self:" .. tostring(enabled and 1 or 0)
    elseif stateArg then
        enabled = tonumber(stateArg) == 1
        keySuffix = "global:" .. stateArg
    else
        local targetText, trailingState = string.match(arg, "^(.-)%s+(%d)$")
        if trailingState then
            targetArg = string.Trim(targetText or "")
            enabled = tonumber(trailingState) == 1
        else
            targetArg = arg
        end

        targetPly = findPlayerByQuery(targetArg)
        if not IsValid(targetPly) then
            local _, err = findPlayerByQuery(targetArg)
            ULib.tsay(ply, err or "Select a valid player target.")
            return ""
        end

        if enabled == nil then
            enabled = not getPlayerGodMode(targetPly)
        end

        keySuffix = tostring(targetPly:SteamID64() or targetPly:Nick()) .. ":" .. tostring(enabled and 1 or 0)
    end

    local key = ply:SteamID64() .. ":" .. keySuffix
    local now = CurTime()

    if (lastGodmodeChat[key] or 0) > now then
        return ""
    end

    lastGodmodeChat[key] = now + 0.25

    if IsValid(targetPly) then
        ulxPlayerGodMode(ply, targetPly, enabled and 1 or 0)
    else
        ulxGodMode(ply, enabled and 1 or 0)
    end

    return ""
end)
