-- sh_ulx_godmode.lua - ULX toggle for organism godmode (all players).
-- Place in: lua/ulx/modules/sh/

if not SERVER then return end
if not ulx or not ULib then return end

local CATEGORY_NAME = "ZCity"
local lastGodmodeChat = {}

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

local cmd = ulx.command(CATEGORY_NAME, "ulx godmode", ulxGodMode, "!godmode")
cmd:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "1 = enable godmode, 0 = disable godmode" }
cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
cmd:help("Toggles organism godmode for all players. 1 = immortal with normal vitals, 0 = normal.")

-- ZChat can swallow PlayerSay before ULX sees it. Intercept here once and consume.
hook.Add("HG_PlayerSay", "ZC_GodMode_ChatCommand", function(ply, txtTbl, text)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local raw = string.Trim(tostring(text or ""))
    local cmdLower, arg = string.match(string.lower(raw), "^([!/][%w_]+)%s*(%d*)$")
    if cmdLower ~= "!godmode" and cmdLower ~= "/godmode" then return end

    if istable(txtTbl) then txtTbl[1] = "" end

    if not ULib.ucl or not ULib.ucl.query or not ULib.ucl.query(ply, "ulx godmode") then
        return ""
    end

    local enabled = (tonumber(arg) == 1) and 1 or 0
    local key = ply:SteamID64() .. ":" .. tostring(enabled)
    local now = CurTime()

    if (lastGodmodeChat[key] or 0) > now then
        return ""
    end

    lastGodmodeChat[key] = now + 0.25
    ulxGodMode(ply, enabled)
    return ""
end)
