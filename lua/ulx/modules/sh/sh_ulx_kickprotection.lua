if not ulx then return end
if CLIENT then return end

local CATEGORY_NAME = "ZCity"
local CVAR_NAME = "zc_kick_protection_enable"

local function getKickProtectionState()
    local cvar = GetConVar(CVAR_NAME)
    if not cvar then return nil end
    return cvar:GetBool()
end

local function setKickProtectionState(enabled)
    RunConsoleCommand(CVAR_NAME, enabled and "1" or "0")
end

local function ulxKickProtection(calling_ply, enabled)
    enabled = tonumber(enabled) == 1

    if not GetConVar(CVAR_NAME) then
        ULib.tsay(calling_ply, "[KickProtection] ConVar zc_kick_protection_enable is missing.")
        return
    end

    setKickProtectionState(enabled)

    local stateText = enabled and "ENABLED" or "DISABLED"
    ulx.fancyLogAdmin(calling_ply, "#A set kick protection to " .. stateText)
end

local function ulxKickProtectionStatus(calling_ply)
    local state = getKickProtectionState()
    if state == nil then
        ULib.tsay(calling_ply, "[KickProtection] ConVar zc_kick_protection_enable is missing.")
        return
    end

    local stateText = state and "ENABLED (1)" or "DISABLED (0)"
    ULib.tsay(calling_ply, "[KickProtection] Current state: " .. stateText)
end

local cmd = ulx.command(CATEGORY_NAME, "ulx kickprotection", ulxKickProtection, "!kickprotection")
cmd:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "1=enable, 0=disable" }
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Toggle DCity leg-kick protection patches.")

local statusCmd = ulx.command(CATEGORY_NAME, "ulx kickprotectionstatus", ulxKickProtectionStatus, "!kickprotectionstatus")
statusCmd:defaultAccess(ULib.ACCESS_ADMIN)
statusCmd:help("Show current zc_kick_protection_enable state.")
