-- ZScav Spawn Points - server: persistence, net handlers, public API.
-- Group-based: each editor click creates one group (a circle of N points).

if not istable(ZScavSpawnPoints) then
    include("autorun/sh_zscav_spawnpoints.lua")
end

local lib = ZScavSpawnPoints
if not istable(lib) then return end

util.AddNetworkString(lib.Net.Sync)
util.AddNetworkString(lib.Net.Action)

lib.ServerGroups = lib.ServerGroups or {}
lib._lastEditAt  = lib._lastEditAt or {}  -- per-player (sid64) debounce timestamps

local EDIT_DEBOUNCE = 0.30  -- minimum seconds between edits per player

local function newID()
    return string.format("sg_%d_%d", os.time(), math.random(1000, 9999))
end

local function getGroupName(group)
    local normalize = lib.NormalizeGroupName
    if isfunction(normalize) then
        return normalize(istable(group) and group.name or "")
    end

    return string.Trim(tostring(istable(group) and group.name or ""))
end

local function ensureUniqueGroupIDs(groups)
    local changed = false
    local seen = {}

    for _, group in ipairs(groups or {}) do
        if not istable(group) then continue end

        local groupID = string.Trim(tostring(group.id or ""))
        while groupID == "" or seen[groupID] do
            groupID = newID()
            changed = true
        end

        if group.id ~= groupID then
            group.id = groupID
        end

        seen[groupID] = true
    end

    return changed
end

local function ensureDir()
    if not file.IsDir(lib.DataDir, "DATA") then file.CreateDir(lib.DataDir) end
    if not file.IsDir(lib.DataSubDir, "DATA") then file.CreateDir(lib.DataSubDir) end
end

local function getBackupPath()
    return string.format("%s/%s.bak.json",
        lib.DataSubDir,
        string.lower(game.GetMap() or "unknown"))
end

local function buildEncodedGroups()
    ensureUniqueGroupIDs(lib.ServerGroups)

    local out = {}
    for _, group in ipairs(lib.ServerGroups) do
        local encoded = lib.EncodeGroup(group)
        if encoded then
            out[#out + 1] = encoded
        end
    end

    return out
end

local function save()
    ensureDir()

    local json = util.TableToJSON(buildEncodedGroups(), true) or "[]"
    file.Write(lib.GetSavePath(), json)
    file.Write(getBackupPath(), json)
end

local function readSavedGroups(path)
    if not file.Exists(path, "DATA") then return nil end

    local raw = file.Read(path, "DATA") or ""
    if raw == "" then return nil end

    local decoded = util.JSONToTable(raw)
    if not istable(decoded) then return nil end

    return decoded
end

local function load()
    lib.ServerGroups = {}

    local primaryPath = lib.GetSavePath()
    local backupPath = getBackupPath()
    local decoded = readSavedGroups(primaryPath)
    local loadedFromBackup = false

    if not decoded then
        decoded = readSavedGroups(backupPath)
        loadedFromBackup = istable(decoded)
    end

    decoded = decoded or {}

    for _, rawGroup in ipairs(decoded) do
        local group = lib.DecodeGroup(rawGroup)
        if group then
            lib.ServerGroups[#lib.ServerGroups + 1] = group
        end
    end

    if loadedFromBackup or ensureUniqueGroupIDs(lib.ServerGroups) then
        save()
    end

    lib._loadedOnce = true
end

local function broadcast(target)
    net.Start(lib.Net.Sync)
        net.WriteString(util.TableToJSON(buildEncodedGroups(), false) or "[]")
    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

local function findGroupIndexByID(groupID)
    groupID = string.Trim(tostring(groupID or ""))
    if groupID == "" then return nil end

    for index, group in ipairs(lib.ServerGroups) do
        if string.Trim(tostring(group.id or "")) == groupID then
            return index
        end
    end

    return nil
end

local function canEdit(ply)
    if not IsValid(ply) then return false end
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

-- Per-player debounce. Returns true if the edit is allowed (and stamps the
-- timer); false if too soon. This kills the gmod_tool repeat-fire bug where
-- one click registers 5-7 stacked edits.
local function passDebounce(ply)
    if not IsValid(ply) then return false end
    local sid = ply:SteamID64() or "noone"
    local now = CurTime()
    local last = lib._lastEditAt[sid] or 0
    if (now - last) < EDIT_DEBOUNCE then return false end
    lib._lastEditAt[sid] = now
    return true
end

-- =========================================================================
-- Public API
-- =========================================================================

function lib.GetGroups() return lib.ServerGroups end

function lib.GetGroupByID(groupID)
    local index = findGroupIndexByID(groupID)
    if not index then return nil end
    return lib.ServerGroups[index], index
end

function lib.AddGroup(center, yaw, count, radius, ply)
    if ply and not canEdit(ply) then return false end
    if not isvector(center) then return false end
    local group = {
        id = newID(),
        name = "",
        center = center,
        yaw = tonumber(yaw) or 0,
        count = math.Clamp(math.floor(tonumber(count) or lib.DEFAULT_GROUP_COUNT), 1, 16),
        radius = math.Clamp(tonumber(radius) or lib.DEFAULT_GROUP_RADIUS, 24, 1024),
    }

    table.insert(lib.ServerGroups, group)
    save()
    broadcast()

    if IsValid(ply) then
        ply:ChatPrint(string.format(
            "[ZScav] Spawn group %s added (%d points, %du radius). %d total.",
            lib.GetGroupLabel and lib.GetGroupLabel(group, #lib.ServerGroups) or ("G" .. tostring(#lib.ServerGroups)),
            group.count,
            group.radius,
            #lib.ServerGroups
        ))
    end

    return group
end

function lib.RemoveNearestGroup(pos, ply, maxDist)
    if ply and not canEdit(ply) then return false end
    local index = lib.NearestGroupIndex(pos, lib.ServerGroups, (maxDist or 128) ^ 2)
    if not index then
        if IsValid(ply) then ply:ChatPrint("[ZScav] No spawn group within range.") end
        return false
    end

    local removed = table.remove(lib.ServerGroups, index)
    save()
    broadcast()

    if IsValid(ply) then
        ply:ChatPrint(string.format(
            "[ZScav] Spawn group %s removed. %d remaining.",
            lib.GetGroupLabel and lib.GetGroupLabel(removed, index) or ("G" .. tostring(index)),
            #lib.ServerGroups
        ))
    end

    return true
end

function lib.RemoveGroupByID(groupID, ply)
    if ply and not canEdit(ply) then return false end

    local index = findGroupIndexByID(groupID)
    if not index then
        if IsValid(ply) then
            ply:ChatPrint("[ZScav] Spawn group selection is no longer valid.")
        end
        return false
    end

    local removed = table.remove(lib.ServerGroups, index)
    save()
    broadcast()

    if IsValid(ply) then
        ply:ChatPrint(string.format(
            "[ZScav] Deleted %s. %d remaining.",
            lib.GetGroupLabel and lib.GetGroupLabel(removed, index) or ("G" .. tostring(index)),
            #lib.ServerGroups
        ))
    end

    return true
end

function lib.RenameGroup(groupID, name, ply)
    if ply and not canEdit(ply) then return false end

    local group, index = lib.GetGroupByID(groupID)
    if not group then
        if IsValid(ply) then
            ply:ChatPrint("[ZScav] Spawn group selection is no longer valid.")
        end
        return false
    end

    local nextName = getGroupName({ name = name })
    group.name = nextName
    save()
    broadcast()

    if IsValid(ply) then
        ply:ChatPrint(string.format(
            "[ZScav] %s renamed to '%s'.",
            lib.GetGroupRef and lib.GetGroupRef(index) or ("G" .. tostring(index)),
            nextName ~= "" and nextName or (lib.GetGroupRef and lib.GetGroupRef(index) or ("G" .. tostring(index)))
        ))
    end

    return true
end

function lib.TeleportPlayerToGroup(groupID, ply)
    if not (IsValid(ply) and canEdit(ply)) then return false end

    local group, index = lib.GetGroupByID(groupID)
    if not (istable(group) and isvector(group.center)) then
        ply:ChatPrint("[ZScav] Spawn group selection is no longer valid.")
        return false
    end

    ply:SetPos(group.center + Vector(0, 0, 8))
    ply:SetEyeAngles(Angle(0, tonumber(group.yaw) or 0, 0))
    ply:SetVelocity(-ply:GetVelocity())
    ply:ChatPrint(string.format(
        "[ZScav] Teleported to %s.",
        lib.GetGroupLabel and lib.GetGroupLabel(group, index) or ("G" .. tostring(index))
    ))

    return true
end

function lib.ClearAll(ply)
    if ply and not canEdit(ply) then return false end
    lib.ServerGroups = {}
    save()
    broadcast()
    if IsValid(ply) then ply:ChatPrint("[ZScav] All spawn groups cleared.") end
    return true
end

-- Returns one random group (whole circle, not a single point).
function lib.RandomGroup()
    local n = #lib.ServerGroups
    if n == 0 then return nil end
    return lib.ServerGroups[math.random(n)]
end

-- Returns N expanded {pos, yaw} entries from one randomly-chosen group. If a
-- team is bigger than the group's count, the surplus members reuse positions
-- in order (rare; shouldn't happen with sensible defaults).
function lib.RandomGroupPositions(teamSize)
    teamSize = math.max(1, teamSize or 1)
    local g = lib.RandomGroup()
    if not g then return {} end
    local positions = lib.ExpandGroup(g)
    local out = {}
    for i = 1, teamSize do
        out[i] = positions[((i - 1) % math.max(1, #positions)) + 1]
    end
    return out
end

function lib.RandomGroupDeployment(teamSize)
    teamSize = math.max(1, tonumber(teamSize) or 1)

    local groups = lib.ServerGroups or {}
    local count = #groups
    if count <= 0 then return nil end

    local groupIndex = math.random(count)
    local group = groups[groupIndex]
    if not istable(group) then return nil end

    local expanded = lib.ExpandGroup(group)
    if #expanded <= 0 then return nil end

    local positions = {}
    for index = 1, teamSize do
        positions[index] = expanded[((index - 1) % #expanded) + 1]
    end

    return {
        group = group,
        groupIndex = groupIndex,
        groupID = tostring(group.id or ""),
        positions = positions,
    }
end

-- =========================================================================
-- Net handler
-- =========================================================================
net.Receive(lib.Net.Action, function(_len, ply)
    if not canEdit(ply) then return end
    if not passDebounce(ply) then return end

    local action = net.ReadUInt(3)
    if action == lib.ACTION_ADD then
        local pos = net.ReadVector()
        local yaw = net.ReadFloat()
        lib.AddGroup(pos, yaw, lib.DEFAULT_GROUP_COUNT, lib.DEFAULT_GROUP_RADIUS, ply)
    elseif action == lib.ACTION_REMOVE then
        local pos = net.ReadVector()
        lib.RemoveNearestGroup(pos, ply, 128)
    elseif action == lib.ACTION_CLEAR then
        lib.ClearAll(ply)
    elseif action == lib.ACTION_RENAME then
        local groupID = net.ReadString()
        local name = net.ReadString()
        lib.RenameGroup(groupID, name, ply)
    elseif action == lib.ACTION_REMOVE_ID then
        lib.RemoveGroupByID(net.ReadString(), ply)
    elseif action == lib.ACTION_TELEPORT then
        lib.TeleportPlayerToGroup(net.ReadString(), ply)
    end
end)

-- =========================================================================
-- Init / sync
-- =========================================================================
hook.Add("InitPostEntity", "ZScavSpawnPoints_Load", function()
    load()
    broadcast()
end)

local function reloadAndBroadcastSpawnGroups()
    if not lib._loadedOnce then
        load()
    else
        local existing = #lib.ServerGroups
        load()
        if existing > 0 and #lib.ServerGroups == 0 then
            print("[ZScav] Spawn group reload returned 0 groups; preserved disk state by reloading instead of overwriting.")
        end
    end

    broadcast()
end

hook.Add("ZB_PreRoundStart", "ZScavSpawnPoints_RewriteBeforeRound", function()
    timer.Simple(0, reloadAndBroadcastSpawnGroups)
end)

hook.Add("PostCleanupMap", "ZScavSpawnPoints_RewriteAfterCleanup", function()
    timer.Simple(0, reloadAndBroadcastSpawnGroups)
end)

hook.Add("PlayerInitialSpawn", "ZScavSpawnPoints_SyncToNew", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then broadcast(ply) end
    end)
end)

concommand.Add("zscav_spawnpoints_list", function(ply)
    if IsValid(ply) and not canEdit(ply) then return end
    local n = #lib.ServerGroups
    local total = 0
    for _, g in ipairs(lib.ServerGroups) do total = total + (g.count or 0) end
    local msg = string.format("[ZScav] %d groups, %d total spawn positions on this map.", n, total)
    if IsValid(ply) then
        ply:ChatPrint(msg)
        for index, group in ipairs(lib.ServerGroups) do
            ply:ChatPrint(string.format("  %s (%d slots, %du radius)",
                lib.GetGroupLabel and lib.GetGroupLabel(group, index) or ("G" .. tostring(index)),
                math.max(math.floor(tonumber(group.count) or 0), 0),
                math.max(math.floor(tonumber(group.radius) or 0), 0)))
        end
    else
        print(msg)
        for index, group in ipairs(lib.ServerGroups) do
            print(string.format("  %s (%d slots, %du radius)",
                lib.GetGroupLabel and lib.GetGroupLabel(group, index) or ("G" .. tostring(index)),
                math.max(math.floor(tonumber(group.count) or 0), 0),
                math.max(math.floor(tonumber(group.radius) or 0), 0)))
        end
    end
end)
