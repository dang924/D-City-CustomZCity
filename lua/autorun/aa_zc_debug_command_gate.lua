-- Unified debug command gate for merged ZCity builds.
-- Any command with an explicit mapping or debug-like name is tied to one cvar.

if not concommand or not concommand.Add then return end

local FCV = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED)
if SERVER then
    CreateConVar("zc_debug_commands", "0", FCV, "Master toggle for debug console commands (0=off, 1=on)")
elseif CLIENT and not GetConVar("zc_debug_commands") then
    CreateClientConVar("zc_debug_commands", "0", true, false, "Master toggle for debug console commands (0=off, 1=on)")
end

local EXPLICIT_DEBUG_COMMANDS = {
    ["alyx_debug"] = true,
    ["alyx_fire_debug"] = true,
    ["zc_alyx_debug"] = true,
    ["zc_alyx_fire_debug"] = true,
    ["zc_command_guard_unsure"] = true,
    ["zc_town_debug"] = true,
    ["wos_dynabase_debug_reloadfixedmodels"] = true,
}

local seenDebugCommands = {}
local originalAdd = concommand.Add

local function isDebugCommand(name)
    local n = string.lower(tostring(name or ""))
    if n == "" then return false end
    if EXPLICIT_DEBUG_COMMANDS[n] then return true end
    if string.find(n, "debug", 1, true) then return true end
    if string.find(n, "dbg", 1, true) then return true end
    return false
end

local function debugCommandsEnabled()
    local cv = GetConVar and GetConVar("zc_debug_commands")
    return cv and cv:GetBool() or false
end

local function notifyBlocked(caller, name)
    local msg = "[ZC Debug] Command '" .. tostring(name) .. "' blocked. Set zc_debug_commands 1 to enable."
    if SERVER and IsValid(caller) and caller.ChatPrint then
        caller:ChatPrint(msg)
        return
    end
    print(msg)
end

concommand.Add = function(name, fn, completeFn, help, flags)
    if type(fn) ~= "function" then
        return originalAdd(name, fn, completeFn, help, flags)
    end

    local lowerName = string.lower(tostring(name or ""))
    if not isDebugCommand(lowerName) then
        return originalAdd(name, fn, completeFn, help, flags)
    end

    if seenDebugCommands[lowerName] then
        print("[ZC Debug] Duplicate debug command ignored: " .. lowerName)
        return
    end
    seenDebugCommands[lowerName] = true

    local wrapped = function(...)
        if not debugCommandsEnabled() then
            notifyBlocked(select(1, ...), lowerName)
            return
        end
        return fn(...)
    end

    return originalAdd(name, wrapped, completeFn, help, flags)
end
