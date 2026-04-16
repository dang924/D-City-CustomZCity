-- sh_ulx_infstamina.lua - ULX toggle for infinite stamina (all players).
-- Place in: lua/ulx/modules/sh/
-- Command: ulx infstamina 1/0   |   !infstamina 1/0

if not SERVER then return end
if not ulx or not ULib then return end

local CATEGORY_NAME = "ZCity"
local lastInfStamChat = {}

local function ulxInfStamina(calling_ply, enabled)
    enabled = tonumber(enabled) == 1
    RunConsoleCommand("hg_infstamina", enabled and "1" or "0")

    local stateText = enabled and "ENABLED" or "DISABLED"

    if ulx.fancyLogAdmin and IsValid(calling_ply) then
        ulx.fancyLogAdmin(calling_ply, "#A set infinite stamina to #s", stateText)
    else
        local actor = IsValid(calling_ply) and calling_ply:Nick() or "Console"
        local msg = "Infinite Stamina " .. stateText .. " by " .. actor
        ulx.logString(msg)
        print(msg)
    end
end

local cmd = ulx.command(CATEGORY_NAME, "ulx infstamina", ulxInfStamina, "!infstamina")
cmd:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "1 = enable, 0 = disable" }
cmd:defaultAccess(ULib.ACCESS_OPERATOR)
cmd:help("Toggles infinite stamina for all players. 1 = infinite, 0 = normal.")

-- HG_PlayerSay intercept so ZChat doesn't swallow the command before ULX sees it.
hook.Add("HG_PlayerSay", "ZC_InfStamina_ChatCommand", function(ply, txtTbl, text)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local raw = string.Trim(tostring(text or ""))
    local cmdLower, arg = string.match(string.lower(raw), "^([!/][%w_]+)%s*(%d*)$")
    if cmdLower ~= "!infstamina" and cmdLower ~= "/infstamina" then return end

    if istable(txtTbl) then txtTbl[1] = "" end

    if not ULib.ucl or not ULib.ucl.query or not ULib.ucl.query(ply, "ulx infstamina") then
        return ""
    end

    local enabled = (tonumber(arg) == 1) and 1 or 0
    local key = ply:SteamID64() .. ":" .. tostring(enabled)
    local now = CurTime()

    if (lastInfStamChat[key] or 0) > now then
        return ""
    end

    lastInfStamChat[key] = now + 0.25
    ulxInfStamina(ply, enabled)
    return ""
end)
