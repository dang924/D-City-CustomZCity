-- Auto-gate DCityPatchPack gameplay features outside Coop/Event.
-- Safety modules still respect per-file zc_dcp_feat_* toggles (default ON).
-- Infrastructure (this file, aaa_zcity_dcp_feature_core, sh_ulx_dcity_pack_features) is never wrapped.

local PATCH_ROOTS = {
    "/addons/dcitypatchpack/",
    "/addons/dcitypatch1.1/",
}

local alwaysOnSourcePatterns = {
    "/lua/autorun/a_command_handler.lua",
    "/lua/autorun/client/cl_currentround_nil_guard.lua",
    "/lua/autorun/client/cl_dbutton_image_nil_guard.lua",
    "/lua/autorun/client/cl_backcarry_view_stabilizer.lua",
    "/lua/autorun/client/cl_organism_nil_guard.lua",
    "/lua/autorun/client/cl_tpik_nil_guard.lua",
    "/lua/autorun/client/cl_zframe_bootstrap.lua",
    "/lua/autorun/client/cl_zcity_nil_guard_hotfix.lua",
    "/lua/autorun/client/cl_ragdoll_owner_fix.lua",
    "/lua/autorun/sh/sh_eyetrace_nil_guard.lua",
    "/lua/autorun/server/sv_zcity_nil_guard_hotfix.lua",
    "/lua/autorun/server/sv_currentround_nil_guard.lua",
    "/lua/autorun/server/sv_cooppersistence_spawn_guard.lua",
    "/lua/autorun/server/sv_hitboxorgans_nil_guard.lua",
    "/lua/autorun/server/sv_playerclass_organism_guard.lua",
    "/lua/autorun/server/sv_organism_safety_patch.lua",
    "/lua/autorun/server/sv_command_access_fix.lua",
    "/lua/autorun/server/sv_changelevel2_safety.lua",
    "/lua/autorun/server/sv_trigger_changelevel_guard.lua",
    "/lua/autorun/server/sv_vehicle_seat_switch_safety.lua",
    "/lua/autorun/server/sv_physics_spike_ghosting.lua",
    "/lua/autorun/server/sv_bullseye_refresh.lua",
    "/lua/autorun/client/cl_simfphys_view_unlock.lua",
    "/lua/autorun/client/cl_aircraft_camera_unlock.lua",
    "/lua/autorun/server/sv_rotor_occupant_fix.lua",
    "/lua/autorun/server/sv_airboat_ragdoll_suppress.lua",
    "/lua/autorun/server/sv_coast04_ent_fixes.lua",
    "/lua/autorun/server/sv_areaportal_force_open.lua",
    "/lua/autorun/server/sv_ulx_chat_alias_bridge.lua",
    "/lua/autorun/server/sv_alyx_enemy_sanity.lua",
    "/lua/autorun/server/sv_alyx_npc_weapon_fix.lua",
    "/lua/autorun/server/sv_alyx_squad_cleanup.lua",
    "/lua/autorun/server/sv_remove_grubs.lua",
    "/lua/autorun/server/sv_npc_wake.lua",
    "/lua/autorun/server/sv_spray_nil_fix.lua",
    "/lua/autorun/server/sv_mysql_nil_guard.lua",
    "/lua/autorun/client/cl_zcity_scoreboard_fix.lua",
    "/lua/autorun/sh/sh_nuggify_property.lua",
}

local function toLower(v)
    return string.lower(tostring(v or ""))
end

local function sourcePath(level)
    local info = debug.getinfo(level or 3, "S")
    if not info or not info.source then return "" end
    local src = toLower(info.source)
    if string.sub(src, 1, 1) == "@" then
        src = string.sub(src, 2)
    end
    src = string.gsub(src, "\\", "/")
    return src
end

local function getModeName()
    if isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) and round.name then
            return toLower(round.name)
        end
    end

    if istable(zb) and zb.CROUND then
        return toLower(zb.CROUND)
    end

    return ""
end

local function modeAllowed()
    if GetConVar and GetConVar("zc_patch_force_all_modes") and GetConVar("zc_patch_force_all_modes"):GetBool() then
        return true
    end

    local mode = getModeName()
    return mode == "coop" or mode == "event"
end

local function isPatchSource(src)
    if src == "" then return false end
    for i = 1, #PATCH_ROOTS do
        if string.find(src, PATCH_ROOTS[i], 1, true) then
            return true
        end
    end
    return false
end

local function sourceAlwaysOn(src)
    for i = 1, #alwaysOnSourcePatterns do
        if string.find(src, alwaysOnSourcePatterns[i], 1, true) then
            return true
        end
    end
    return false
end

local function isInfrastructureSource(src)
    return string.find(src, "/lua/autorun/a_command_handler.lua", 1, true)
        or string.find(src, "/lua/autorun/aa_dcity_mode_gate.lua", 1, true)
        or string.find(src, "/lua/autorun/aaa_zcity_dcp_feature_core.lua", 1, true)
        or string.find(src, "/lua/ulx/modules/sh/sh_ulx_dcity_pack_features.lua", 1, true)
end

local function sourceNeverGate(src)
    return string.find(src, "/lua/ulx/modules/sh/", 1, true)
end

local function shouldGateSource(src)
    if not isPatchSource(src) then return false end
    if isInfrastructureSource(src) then return false end
    if sourceAlwaysOn(src) then return false end
    return true
end

local function wrapIfNeeded(fn, src)
    if type(fn) ~= "function" then return fn end
    if not isPatchSource(src) then return fn end
    if sourceNeverGate(src) then return fn end

    local infra = isInfrastructureSource(src)
    local needMode = shouldGateSource(src)
    local featKey = (not infra) and ZC_DCP_FeatureKeyFromSource and ZC_DCP_FeatureKeyFromSource(src) or nil

    if SERVER and featKey and ZC_DCP_EnsureFeatureConvar then
        ZC_DCP_EnsureFeatureConvar(featKey)
    end

    if infra and not needMode then
        return fn
    end

    return function(...)
        if featKey and ZC_DCP_FeatureEnabledForKey and not ZC_DCP_FeatureEnabledForKey(featKey) then
            return
        end
        if needMode and not modeAllowed() then
            return
        end
        return fn(...)
    end
end

local function wrapCommandIfNeeded(kind, name, fn, src)
    local wrapped = wrapIfNeeded(fn, src)
    if SERVER and ZC_CommandGuard and ZC_CommandGuard.Wrap then
        wrapped = ZC_CommandGuard.Wrap(kind, name, wrapped, src)
    end
    return wrapped
end

if SERVER then
    local cvAllModes = CreateConVar(
        "zc_patch_force_all_modes",
        "0",
        FCVAR_ARCHIVE,
        "Enable DCityPatchPack gated gameplay features in all modes instead of coop/event only.",
        0,
        1
    )

    local function SetAllModes(ply, enabled)
        local v = tonumber(enabled) or 0
        v = (v ~= 0) and 1 or 0
        cvAllModes:SetInt(v)

        local state = (v == 1) and "ENABLED" or "DISABLED"
        local actor = IsValid(ply) and ply:Nick() or "Console"
        local msg = "[DCityPatchPack] All-modes override " .. state .. " by " .. actor .. "."

        if ulx and ulx.fancyLogAdmin and IsValid(ply) then
            ulx.fancyLogAdmin(ply, "#A set DCityPatchPack all-modes override to #s", tostring(v))
        else
            PrintMessage(HUD_PRINTTALK, msg)
            print(msg)
        end
    end

    local function RegisterULXAllModes()
        if not ulx or not ULib then return end
        if ulx.dcityallmodes and ulx.dcityallmodes._zcRegistered then return end

        ulx.dcityallmodes = ulx.dcityallmodes or {}
        ulx.dcityallmodes._zcRegistered = true

        function ulx.dcityallmodes.toggle(calling_ply, enabled)
            SetAllModes(calling_ply, enabled)
        end

        local cmd = ulx.command("ZCity", "ulx dcityallmodes", ulx.dcityallmodes.toggle, "!dcityallmodes")
        cmd:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "1=enable, 0=disable" }
        cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
        cmd:help("Toggle DCityPatchPack all-modes override (1=all modes, 0=coop/event only).")
    end

    RegisterULXAllModes()
    hook.Add("ULibLoaded", "ZC_RegisterDCityAllModes", RegisterULXAllModes)
end

if not _G.ZC_PatchModeGateInstalled then
    _G.ZC_PatchModeGateInstalled = true

    local hookAdd = hook.Add
    hook.Add = function(eventName, identifier, fn)
        local src = sourcePath(3)
        return hookAdd(eventName, identifier, wrapIfNeeded(fn, src))
    end

    if net and net.Receive then
        local netReceive = net.Receive
        net.Receive = function(name, fn)
            local src = sourcePath(3)
            return netReceive(name, wrapIfNeeded(fn, src))
        end
    end

    if concommand and concommand.Add then
        local ccAdd = concommand.Add
        concommand.Add = function(name, fn, completeFn, help, flags)
            local src = sourcePath(3)
            return ccAdd(name, wrapCommandIfNeeded("concommand", tostring(name or ""), fn, src), completeFn, help, flags)
        end
    end

    if SERVER then
        local function installUlxCommandWrapper()
            if not ulx or not ulx.command then return end
            if ulx._zcCommandGuardWrapped then return end

            ulx._zcCommandGuardWrapped = true
            ulx._zcCommandGuardOrigCommand = ulx.command

            ulx.command = function(category, commandName, fn, say_cmd, hide_say)
                local src = sourcePath(3)
                local cmdName = string.lower(tostring(commandName or ""))
                cmdName = string.gsub(cmdName, "^ulx%s+", "")
                local wrapped = wrapCommandIfNeeded("ulx", cmdName, fn, src)
                local sayAlias = string.Trim(tostring(say_cmd or ""))

                if sayAlias ~= "" then
                    _G.ZC_ULXPendingAliases = _G.ZC_ULXPendingAliases or {}
                    if _G.ZC_RegisterULXSayAlias then
                        _G.ZC_RegisterULXSayAlias(sayAlias, cmdName)
                    else
                        _G.ZC_ULXPendingAliases[string.lower(sayAlias)] = cmdName
                    end
                end

                return ulx._zcCommandGuardOrigCommand(category, commandName, wrapped, say_cmd, hide_say)
            end
        end

        installUlxCommandWrapper()
        hook.Add("ULibLoaded", "ZC_CommandGuardInstallULX", installUlxCommandWrapper)
        timer.Simple(0, installUlxCommandWrapper)
    end

    if timer and timer.Create then
        local tCreate = timer.Create
        timer.Create = function(name, delay, reps, fn)
            local src = sourcePath(3)
            return tCreate(name, delay, reps, wrapIfNeeded(fn, src))
        end
    end
end
