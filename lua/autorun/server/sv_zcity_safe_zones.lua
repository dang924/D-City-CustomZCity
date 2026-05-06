if CLIENT then return end

if not istable(ZCitySafeZones) then
    include("autorun/sh_zcity_safe_zones.lua")
end

local lib = ZCitySafeZones
if not istable(lib) then return end

util.AddNetworkString(lib.Net.RequestState)
util.AddNetworkString(lib.Net.SyncZones)
util.AddNetworkString(lib.Net.SyncEditor)
util.AddNetworkString(lib.Net.Action)

lib.ServerZones = lib.ServerZones or {}
lib.EditorStates = lib.EditorStates or {}

local function lowerTrim(value)
    return string.lower(string.Trim(tostring(value or "")))
end

local function ensureDataDir()
    if not file.IsDir(lib.DataDir, "DATA") then
        file.CreateDir(lib.DataDir)
    end

    if not file.IsDir(lib.DataSubDir, "DATA") then
        file.CreateDir(lib.DataSubDir)
    end
end

function lib.CanEdit(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return true end

    if COMMAND_GETACCES then
        local access = tonumber(COMMAND_GETACCES(ply)) or 0
        if access >= 1 then return true end
    end

    local ulxLib = rawget(_G, "ULX") or rawget(_G, "ulx")
    if ulxLib and ulxLib.CheckAccess then
        if ulxLib.CheckAccess(ply, "ulx ban") or ulxLib.CheckAccess(ply, "ulx kick") then
            return true
        end
    end

    local group = ply.GetUserGroup and lowerTrim(ply:GetUserGroup()) or ""
    return group == "operator" or group == "admin" or group == "superadmin"
end

local function getEditorState(ply)
    if not IsValid(ply) then return nil end

    local state = lib.EditorStates[ply]
    if state then return state end

    state = {
        selectedZoneID = "",
        startCorner = nil,
    }

    lib.EditorStates[ply] = state
    return state
end

local function sendEditorState(ply)
    if not IsValid(ply) then return end

    local state = getEditorState(ply)
    local hasStart = isvector(state.startCorner)

    net.Start(lib.Net.SyncEditor)
        net.WriteBool(hasStart)
        net.WriteString(tostring(state.selectedZoneID or ""))
        if hasStart then
            net.WriteVector(state.startCorner)
        end
    net.Send(ply)
end

local function broadcastZones(target)
    local json = util.TableToJSON(lib.ServerZones, false) or "[]"

    net.Start(lib.Net.SyncZones)
        net.WriteString(json)

    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

function lib.GetZones()
    return lib.ServerZones or {}
end

function lib.GetZoneByID(zoneID)
    zoneID = tostring(zoneID or "")
    if zoneID == "" then return nil end

    for _, zone in ipairs(lib.ServerZones) do
        if zone.id == zoneID then
            return zone
        end
    end
end

function lib.GetZoneAtPos(pos)
    return lib.FindZoneAtPos(pos, lib.ServerZones, 0)
end

function lib.GetPlayerZone(ply)
    if not IsValid(ply) then return nil end
    return lib.GetZoneAtPos(ply:GetPos())
end

function lib.IsPlayerProtected(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return false end
    return lib.GetPlayerZone(ply) ~= nil or ply:GetNWBool("ZCityInSafeZone", false)
end

local function RestoreProtectedPlayerResources(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end

    local org = ply.organism
    if not istable(org) then return end

    local stamina = org.stamina
    if istable(stamina) then
        local maxValue = math.max(tonumber(stamina.max or stamina.range) or tonumber(stamina[1]) or 0, 0)
        stamina.sub = 0
        stamina.subadd = 0
        if maxValue > 0 then
            stamina[1] = maxValue
        end
    end

    local oxygen = org.o2
    if istable(oxygen) then
        local oxygenMax = math.max(tonumber(oxygen.range) or tonumber(oxygen[1]) or 0, 0)
        if oxygenMax > 0 then
            oxygen[1] = oxygenMax
        end
        local oxygenRegen = math.max(tonumber(oxygen.regen) or tonumber(oxygen.curregen) or 0, 0)
        if oxygenRegen > 0 then
            oxygen.curregen = oxygenRegen
        end
    end

    local lungHoldMax = math.max(tonumber(org.zscav_lung_hold_max) or 0, 0)
    if lungHoldMax > 0 then
        org.zscav_lung_hold_current = lungHoldMax
    end

    org.holdingbreath = false
    ply.releasebreathe = nil
end

local function GetProtectedPlayer(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then
        return ent
    end

    if hg and isfunction(hg.RagdollOwner) then
        local owner = hg.RagdollOwner(ent)
        if IsValid(owner) and owner:IsPlayer() then
            return owner
        end
    end

    local owner = ent.GetOwner and ent:GetOwner() or nil
    if IsValid(owner) and owner:IsPlayer() then
        return owner
    end

    owner = ent.owner
    if IsValid(owner) and owner:IsPlayer() then
        return owner
    end

    owner = ent.ply
    if IsValid(owner) and owner:IsPlayer() then
        return owner
    end

    return nil
end

local function IsProtectedEntity(ent)
    local ply = GetProtectedPlayer(ent)
    return IsValid(ply) and lib.IsPlayerProtected(ply), ply
end

local function ZeroDamageInfo(dmgInfo)
    if dmgInfo and dmgInfo.SetDamage then
        dmgInfo:SetDamage(0)
    end
end

hook.Add("EntityTakeDamage", "ZCitySafeZones_BlockDamage", function(ent, dmgInfo)
    local blocked = IsProtectedEntity(ent)
    if not blocked then return end
    ZeroDamageInfo(dmgInfo)
    return true
end)

hook.Add("HomigradDamage", "ZCitySafeZones_BlockHomigradDamage", function(victim, dmgInfo)
    local blocked = IsProtectedEntity(victim)
    if not blocked then return end
    ZeroDamageInfo(dmgInfo)
    return true
end)

local function WrapHook(tableName, hookName, stateKey, wrapperFactory)
    if lib[stateKey] then return true end

    local hookTable = hook.GetTable()[tableName]
    local original = hookTable and hookTable[hookName] or nil
    if not isfunction(original) then return false end

    hook.Remove(tableName, hookName)
    hook.Add(tableName, hookName, wrapperFactory(original))
    lib[stateKey] = true
    return true
end

local function WrapFunction(container, key, stateKey, wrapperFactory)
    if lib[stateKey] then return true end
    if not (istable(container) and isfunction(container[key])) then return false end

    container[key] = wrapperFactory(container[key])
    lib[stateKey] = true
    return true
end

local function EnsureProtectionWrappers()
    local damageReady = WrapHook("EntityTakeDamage", "homigrad-damage", "_wrappedHomigradDamage", function(original)
        return function(ent, dmgInfo)
            local blocked = IsProtectedEntity(ent)
            if blocked then
                ZeroDamageInfo(dmgInfo)
                return true
            end

            return original(ent, dmgInfo)
        end
    end)

    local thinkReady = WrapHook("Think", "homigrad-organism", "_wrappedHomigradOrganismThink", function(original)
        return function(...)
            local protected = {}

            for _, ply in ipairs(player.GetAll()) do
                if lib.IsPlayerProtected(ply) and istable(ply.organism) then
                    protected[#protected + 1] = {
                        org = ply.organism,
                        godmode = ply.organism.godmode == true,
                    }
                    ply.organism.godmode = true
                end
            end

            local ok, err = xpcall(function(...)
                return original(...)
            end, debug.traceback, ...)

            for _, snapshot in ipairs(protected) do
                if istable(snapshot.org) then
                    snapshot.org.godmode = snapshot.godmode
                end
            end

            if not ok then
                ErrorNoHalt("[ZCitySafeZones] Wrapped homigrad-organism Think failed:\n" .. tostring(err) .. "\n")
                return
            end
        end
    end)

    local fakeReady = WrapFunction(hg, "Fake", "_wrappedHgFake", function(original)
        return function(ply, ...)
            if lib.IsPlayerProtected(ply) then return end
            return original(ply, ...)
        end
    end)

    local stunReady = WrapFunction(hg, "StunPlayer", "_wrappedHgStun", function(original)
        return function(ply, ...)
            if lib.IsPlayerProtected(ply) then return end
            return original(ply, ...)
        end
    end)

    local lightStunReady = WrapFunction(hg, "LightStunPlayer", "_wrappedHgLightStun", function(original)
        return function(ply, ...)
            if lib.IsPlayerProtected(ply) then return end
            return original(ply, ...)
        end
    end)

    local amputateReady = WrapFunction(hg and hg.organism or nil, "AmputateLimb", "_wrappedHgAmputate", function(original)
        return function(ply, ...)
            if lib.IsPlayerProtected(ply) then return end
            return original(ply, ...)
        end
    end)

    return damageReady and thinkReady and fakeReady and stunReady and lightStunReady and amputateReady
end

timer.Create("ZCitySafeZones_ProtectionRetry", 1, 0, function()
    if EnsureProtectionWrappers() then
        timer.Remove("ZCitySafeZones_ProtectionRetry")
    end
end)

hook.Add("InitPostEntity", "ZCitySafeZones_WrapProtectionHooks", function()
    if EnsureProtectionWrappers() then
        timer.Remove("ZCitySafeZones_ProtectionRetry")
    end
end)

function lib.GetSelectedZoneID(ply)
    local state = getEditorState(ply)
    return state and tostring(state.selectedZoneID or "") or ""
end

function lib.GetSelectedZone(ply)
    return lib.GetZoneByID(lib.GetSelectedZoneID(ply))
end

function lib.SetSelectedZoneID(ply, zoneID)
    local state = getEditorState(ply)
    if not state then return nil end

    local zone = lib.GetZoneByID(zoneID)
    state.selectedZoneID = zone and zone.id or ""
    sendEditorState(ply)
    return zone
end

function lib.GetStartCorner(ply)
    local state = getEditorState(ply)
    return state and state.startCorner or nil
end

function lib.SetStartCorner(ply, pos)
    local state = getEditorState(ply)
    if not (state and isvector(pos)) then return false end

    state.startCorner = pos
    sendEditorState(ply)
    return true
end

function lib.ClearStartCorner(ply)
    local state = getEditorState(ply)
    if not state then return false end

    state.startCorner = nil
    sendEditorState(ply)
    return true
end

function lib.SelectZoneAtPos(ply, pos, padding)
    local zone = lib.FindZoneAtPos(pos, lib.ServerZones, padding)
    lib.SetSelectedZoneID(ply, zone and zone.id or "")
    return zone
end

local function saveZones()
    ensureDataDir()

    local json = util.TableToJSON(lib.ServerZones, true)
    if not json then return false end

    file.Write(lib.GetSavePath(), json)
    return true
end

local function loadZones()
    ensureDataDir()

    if not file.Exists(lib.GetSavePath(), "DATA") then
        lib.ServerZones = {}
        return
    end

    local raw = file.Read(lib.GetSavePath(), "DATA") or "[]"
    local decoded = util.JSONToTable(raw) or {}
    local zones = {}

    for _, zone in ipairs(decoded) do
        local clean = lib.NormalizeZone(zone)
        if clean then
            zones[#zones + 1] = clean
        end
    end

    lib.ServerZones = zones
end

local function clearDeletedSelections(zoneID)
    for ply, state in pairs(lib.EditorStates) do
        if not IsValid(ply) then
            lib.EditorStates[ply] = nil
        elseif state.selectedZoneID == zoneID then
            state.selectedZoneID = ""
            sendEditorState(ply)
        end
    end
end

function lib.CreateZone(ply, name, cornerA, cornerB, height)
    local zone = lib.MakeZoneFromCorners(name, cornerA, cornerB, height)
    if not zone then return nil end

    while lib.GetZoneByID(zone.id) do
        zone.id = string.format("zone_%d_%d", os.time(), math.random(1000, 9999))
    end

    lib.ServerZones[#lib.ServerZones + 1] = zone
    saveZones()
    broadcastZones()
    lib.SetSelectedZoneID(ply, zone.id)
    lib.ClearStartCorner(ply)
    hook.Run("ZCitySafeZones_Changed", "create", zone, ply)

    return zone
end

function lib.DeleteZone(ply, zoneID)
    zoneID = tostring(zoneID or "")
    if zoneID == "" then return nil end

    for index, zone in ipairs(lib.ServerZones) do
        if zone.id == zoneID then
            table.remove(lib.ServerZones, index)
            saveZones()
            broadcastZones()
            clearDeletedSelections(zoneID)
            hook.Run("ZCitySafeZones_Changed", "delete", zone, ply)
            return zone
        end
    end
end

function lib.RenameZone(ply, zoneID, newName)
    local zone = lib.GetZoneByID(zoneID)
    if not zone then return nil end

    zone.name = lib.SanitizeName(newName)
    saveZones()
    broadcastZones()
    hook.Run("ZCitySafeZones_Changed", "rename", zone, ply)
    return zone
end

local function sendFullState(ply)
    broadcastZones(ply)
    if IsValid(ply) then
        sendEditorState(ply)
    end
end

net.Receive(lib.Net.RequestState, function(_, ply)
    sendFullState(ply)
end)

net.Receive(lib.Net.Action, function(_, ply)
    if not lib.CanEdit(ply) then return end

    local action = tostring(net.ReadString() or "")

    if action == "select_zone" then
        lib.SetSelectedZoneID(ply, net.ReadString())
        return
    end

    if action == "rename_selected" then
        local selectedID = lib.GetSelectedZoneID(ply)
        if selectedID ~= "" then
            lib.RenameZone(ply, selectedID, net.ReadString())
        end
        return
    end

    if action == "delete_selected" then
        local selectedID = lib.GetSelectedZoneID(ply)
        if selectedID ~= "" then
            lib.DeleteZone(ply, selectedID)
        end
        return
    end

    if action == "clear_start" then
        lib.ClearStartCorner(ply)
        return
    end
end)

hook.Add("PlayerInitialSpawn", "ZCitySafeZones_SyncOnJoin", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        sendFullState(ply)
    end)
end)

hook.Add("PlayerDisconnected", "ZCitySafeZones_ClearEditorState", function(ply)
    lib.EditorStates[ply] = nil
end)

do
    local nextZoneThink = 0

    hook.Add("Think", "ZCitySafeZones_UpdatePlayers", function()
        local now = CurTime()
        if now < nextZoneThink then return end
        nextZoneThink = now + 0.5

        for _, ply in ipairs(player.GetAll()) do
            local zone = lib.GetPlayerZone(ply)
            local zoneID = zone and zone.id or ""
            local zoneName = zone and zone.name or ""
            local wasInZone = ply:GetNWBool("ZCityInSafeZone", false)
            local isInZone = zone ~= nil

            ply:SetNWBool("ZCityInSafeZone", isInZone)
            ply:SetNWString("ZCitySafeZoneID", zoneID)
            ply:SetNWString("ZCitySafeZoneName", zoneName)

            if isInZone then
                RestoreProtectedPlayerResources(ply)
            end

            if wasInZone ~= isInZone then
                hook.Run("ZCitySafeZoneStateChanged", ply, isInZone, zone)
            end
        end
    end)
end

loadZones()

hook.Add("InitPostEntity", "ZCitySafeZones_BroadcastLoadedZones", function()
    broadcastZones()
end)