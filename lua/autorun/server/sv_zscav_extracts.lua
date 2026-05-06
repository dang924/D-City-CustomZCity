-- ZScav named extracts - server: persistence, net handlers, public API.

if not istable(ZScavExtracts) then
    include("autorun/sh_zscav_extracts.lua")
end

local lib = ZScavExtracts
if not istable(lib) then return end

util.AddNetworkString(lib.Net.Sync)
util.AddNetworkString(lib.Net.Action)

lib.ServerExtracts = lib.ServerExtracts or {}
lib._lastEditAt = lib._lastEditAt or {}

local EDIT_DEBOUNCE = 0.30

local function ensureDir()
    if not file.IsDir(lib.DataDir, "DATA") then file.CreateDir(lib.DataDir) end
    if not file.IsDir(lib.DataSubDir, "DATA") then file.CreateDir(lib.DataSubDir) end
end

local function getBackupPath()
    return string.format("%s/%s.bak.json", lib.DataSubDir, string.lower(game.GetMap() or "unknown"))
end

local function buildEncodedExtracts()
    local out = {}
    for _, extract in ipairs(lib.ServerExtracts) do
        local encoded = lib.EncodeExtract(extract)
        if encoded then
            out[#out + 1] = encoded
        end
    end

    return out
end

local function save()
    ensureDir()

    local json = util.TableToJSON(buildEncodedExtracts(), true) or "[]"
    file.Write(lib.GetSavePath(), json)
    file.Write(getBackupPath(), json)
end

local function readSavedExtracts(path)
    if not file.Exists(path, "DATA") then return nil end

    local raw = file.Read(path, "DATA") or ""
    if raw == "" then return nil end

    local decoded = util.JSONToTable(raw)
    if not istable(decoded) then return nil end

    return decoded
end

local function load()
    lib.ServerExtracts = {}

    local decoded = readSavedExtracts(lib.GetSavePath())
    local loadedFromBackup = false

    if not decoded then
        decoded = readSavedExtracts(getBackupPath())
        loadedFromBackup = istable(decoded)
    end

    decoded = decoded or {}

    for _, entry in ipairs(decoded) do
        local extract = lib.DecodeExtract(entry)
        if extract then
            lib.ServerExtracts[#lib.ServerExtracts + 1] = extract
        end
    end

    if loadedFromBackup then
        save()
    end
end

local function broadcast(target)
    net.Start(lib.Net.Sync)
        net.WriteString(util.TableToJSON(buildEncodedExtracts(), false) or "[]")
    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

local function canEdit(ply)
    if not IsValid(ply) then return false end
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function passDebounce(ply)
    if not IsValid(ply) then return false end

    local sid = ply:SteamID64() or "noone"
    local now = CurTime()
    local last = lib._lastEditAt[sid] or 0
    if (now - last) < EDIT_DEBOUNCE then return false end

    lib._lastEditAt[sid] = now
    return true
end

local function newID()
    return string.format("ex_%d_%d", os.time(), math.random(1000, 9999))
end

local function trimName(name)
    name = string.sub(string.Trim(tostring(name or "")), 1, 64)
    return name
end

local function normalizeDuration(duration)
    return math.Clamp(math.floor(tonumber(duration) or lib.DEFAULT_DURATION or 8), 1, 255)
end

local function resolveGroupRefs(rawText)
    local refs = {}
    local groups = ZScavSpawnPoints and ZScavSpawnPoints.GetGroups and ZScavSpawnPoints.GetGroups() or {}
    local byToken = {}

    for index, group in ipairs(groups) do
        local groupID = string.Trim(tostring(group.id or ""))
        if groupID ~= "" then
            byToken[string.lower(groupID)] = groupID
            byToken[tostring(index)] = groupID
            byToken["#" .. tostring(index)] = groupID

            local ref = ZScavSpawnPoints.GetGroupRef and ZScavSpawnPoints.GetGroupRef(index) or ("G" .. tostring(index))
            byToken[string.lower(tostring(ref))] = groupID
        end
    end

    for token in string.gmatch(tostring(rawText or ""), "[^,%s]+") do
        token = string.Trim(token)
        local resolved = byToken[string.lower(token)]
        if resolved then
            refs[#refs + 1] = resolved
        end
    end

    return lib.NormalizeGroupRefs(refs)
end

function lib.GetExtracts()
    return lib.ServerExtracts
end

function lib.AddOrUpdateNearest(pos, yaw, name, groups, duration, ply, maxDist)
    if ply and not canEdit(ply) then return false end
    if not isvector(pos) then return false end

    groups = lib.NormalizeGroupRefs(groups)
    duration = normalizeDuration(duration)

    local radius = math.max(tonumber(maxDist) or 128, 1)
    local index = lib.NearestExtractIndex(pos, lib.ServerExtracts, radius * radius)
    if index then
        local extract = lib.ServerExtracts[index]
        if not istable(extract) then return false end

        extract.pos = pos
        extract.yaw = tonumber(yaw) or 0

        local nextName = trimName(name)
        if nextName ~= "" then
            extract.name = nextName
        elseif trimName(extract.name) == "" then
            extract.name = "Extract #" .. tostring(index)
        end

        extract.groups = groups
        extract.duration = duration
        save()
        broadcast()

        if IsValid(ply) then
            ply:ChatPrint(string.format("[ZScav] Updated extract '%s' (%ds) with %d linked spawn group%s.",
                trimName(extract.name) ~= "" and trimName(extract.name) or ("Extract #" .. tostring(index)),
                duration,
                #groups,
                #groups == 1 and "" or "s"))
        end

        return extract, index, true
    end

    local extract = {
        id = newID(),
        pos = pos,
        yaw = tonumber(yaw) or 0,
        name = trimName(name),
        duration = duration,
        groups = groups,
    }

    table.insert(lib.ServerExtracts, extract)
    if extract.name == "" then
        extract.name = "Extract #" .. tostring(#lib.ServerExtracts)
    end

    save()
    broadcast()

    if IsValid(ply) then
        ply:ChatPrint(string.format("[ZScav] Added extract '%s' (%ds) with %d linked spawn group%s. %d total.",
            extract.name,
            duration,
            #groups,
            #groups == 1 and "" or "s",
            #lib.ServerExtracts))
    end

    return extract, #lib.ServerExtracts, false
end

function lib.RemoveNearestExtract(pos, ply, maxDist)
    if ply and not canEdit(ply) then return false end

    local radius = math.max(tonumber(maxDist) or 128, 1)
    local index = lib.NearestExtractIndex(pos, lib.ServerExtracts, radius * radius)
    if not index then
        if IsValid(ply) then
            ply:ChatPrint("[ZScav] No named extract within range.")
        end
        return false
    end

    local removed = table.remove(lib.ServerExtracts, index)
    save()
    broadcast()

    if IsValid(ply) then
        ply:ChatPrint(string.format("[ZScav] Removed extract '%s'. %d remaining.",
            trimName(removed and removed.name) ~= "" and trimName(removed.name) or ("Extract #" .. tostring(index)),
            #lib.ServerExtracts))
    end

    return true
end

function lib.ClearAll(ply)
    if ply and not canEdit(ply) then return false end

    lib.ServerExtracts = {}
    save()
    broadcast()

    if IsValid(ply) then
        ply:ChatPrint("[ZScav] All named extracts cleared.")
    end

    return true
end

net.Receive(lib.Net.Action, function(_, ply)
    if not canEdit(ply) then return end
    if not passDebounce(ply) then return end

    local action = net.ReadUInt(3)
    if action == lib.ACTION_UPSERT then
        local pos = net.ReadVector()
        local yaw = net.ReadFloat()
        local name = net.ReadString()
        local duration = net.ReadUInt(8)
        local rawGroups = net.ReadString()
        lib.AddOrUpdateNearest(pos, yaw, name, resolveGroupRefs(rawGroups), duration, ply, 128)
    elseif action == lib.ACTION_REMOVE then
        lib.RemoveNearestExtract(net.ReadVector(), ply, 128)
    elseif action == lib.ACTION_CLEAR then
        lib.ClearAll(ply)
    end
end)

hook.Add("InitPostEntity", "ZScavExtracts_Load", function()
    load()
end)

hook.Add("ZB_PreRoundStart", "ZScavExtracts_RewriteBeforeRound", function()
    timer.Simple(0, save)
end)

hook.Add("PostCleanupMap", "ZScavExtracts_RewriteAfterCleanup", function()
    timer.Simple(0, function()
        save()
        broadcast()
    end)
end)

hook.Add("ShutDown", "ZScavExtracts_SaveOnShutdown", function()
    save()
end)

hook.Add("PlayerInitialSpawn", "ZScavExtracts_SyncToNew", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then
            broadcast(ply)
        end
    end)
end)

concommand.Add("zscav_extracts_list", function(ply)
    if IsValid(ply) and not canEdit(ply) then return end

    local extracts = lib.ServerExtracts or {}
    local msg = string.format("[ZScav] %d named extract%s on this map.", #extracts, #extracts == 1 and "" or "s")
    if IsValid(ply) then
        ply:ChatPrint(msg)
        for index, extract in ipairs(extracts) do
            ply:ChatPrint(string.format("  #%d %s (%ds, %d linked group%s)",
                index,
                trimName(extract.name) ~= "" and trimName(extract.name) or ("Extract #" .. tostring(index)),
                normalizeDuration(extract.duration),
                #(extract.groups or {}),
                #(extract.groups or {}) == 1 and "" or "s"))
        end
    else
        print(msg)
        for index, extract in ipairs(extracts) do
            print(string.format("  #%d %s (%ds, %d linked group%s)",
                index,
                trimName(extract.name) ~= "" and trimName(extract.name) or ("Extract #" .. tostring(index)),
                normalizeDuration(extract.duration),
                #(extract.groups or {}),
                #(extract.groups or {}) == 1 and "" or "s"))
        end
    end
end)