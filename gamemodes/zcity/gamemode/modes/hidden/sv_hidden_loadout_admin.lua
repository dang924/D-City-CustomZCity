-- ─────────────────────────────────────────────────────────────────────────────
-- Hidden mode loadout admin overrides
--
-- Persists per-server score overrides and blacklists for weapons, armor and
-- attachments shown in the Hidden prep loadout menu. Only superadmins can
-- mutate the data; clients receive the full table on prep sync so the shared
-- score helpers (in sh_hidden_loadout.lua) resolve overrides identically on
-- both realms.
-- ─────────────────────────────────────────────────────────────────────────────

local MODE = MODE

util.AddNetworkString("hidden_loadout_admin_sync")
util.AddNetworkString("hidden_loadout_admin_set_score")
util.AddNetworkString("hidden_loadout_admin_set_blacklist")
util.AddNetworkString("hidden_loadout_admin_reset")

local ADMIN_FILE = "zcity/hidden_loadout_admin.json"
local VALID_KINDS = {
    weapon = true,
    armor = true,
    attachment = true,
}

local function emptyAdminData()
    return {
        scoreOverrides = { weapon = {}, armor = {}, attachment = {} },
        blacklist      = { weapon = {}, armor = {}, attachment = {} },
    }
end

local function ensureBucket(data)
    data.scoreOverrides = istable(data.scoreOverrides) and data.scoreOverrides or {}
    data.blacklist      = istable(data.blacklist) and data.blacklist or {}
    for kind in pairs(VALID_KINDS) do
        data.scoreOverrides[kind] = istable(data.scoreOverrides[kind]) and data.scoreOverrides[kind] or {}
        data.blacklist[kind]      = istable(data.blacklist[kind]) and data.blacklist[kind] or {}
    end
    return data
end

local function loadAdminData()
    file.CreateDir("zcity")
    local raw = file.Exists(ADMIN_FILE, "DATA") and file.Read(ADMIN_FILE, "DATA") or ""
    local parsed = isstring(raw) and util.JSONToTable(raw) or nil
    return ensureBucket(istable(parsed) and parsed or emptyAdminData())
end

local function saveAdminData()
    file.CreateDir("zcity")
    local data = MODE:GetHiddenAdminData()
    file.Write(ADMIN_FILE, util.TableToJSON(data, true))
end

-- Load from disk on first include (after sh_hidden_loadout.lua so accessors exist).
MODE.HiddenAdminData = ensureBucket(loadAdminData())

local function canEdit(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

local function broadcastAdminSync(target)
    local data = MODE:GetHiddenAdminData()
    local json = util.TableToJSON(data)
    if not isstring(json) then return end

    net.Start("hidden_loadout_admin_sync")
    net.WriteString(json)
    if target and target ~= true then
        net.Send(target)
    else
        net.Broadcast()
    end
end

function MODE:SendHiddenAdminDataTo(ply)
    if not IsValid(ply) then return end
    broadcastAdminSync(ply)
end

local function applyChange()
    -- Drop catalog cache so the next prep sync rebuilds with new scores/blacklist.
    if MODE.InvalidateHiddenLoadoutCatalog then
        MODE:InvalidateHiddenLoadoutCatalog()
    end
    saveAdminData()
    broadcastAdminSync()
end

net.Receive("hidden_loadout_admin_set_score", function(_, ply)
    if not canEdit(ply) then return end

    local kind     = string.lower(tostring(net.ReadString() or ""))
    local key      = string.lower(string.Trim(tostring(net.ReadString() or "")))
    local hasValue = net.ReadBool()
    local value    = hasValue and math.Clamp(net.ReadInt(16), 0, 120) or nil

    if not VALID_KINDS[kind] or key == "" then return end

    local data = MODE:GetHiddenAdminData()
    if value == nil then
        data.scoreOverrides[kind][key] = nil
    else
        data.scoreOverrides[kind][key] = value
    end

    ply:ChatPrint(string.format(
        "[Hidden Loadout] %s score for '%s' %s",
        kind, key,
        value == nil and "reset to default" or ("set to " .. value)
    ))

    applyChange()
end)

net.Receive("hidden_loadout_admin_set_blacklist", function(_, ply)
    if not canEdit(ply) then return end

    local kind    = string.lower(tostring(net.ReadString() or ""))
    local key     = string.lower(string.Trim(tostring(net.ReadString() or "")))
    local enabled = net.ReadBool()

    if not VALID_KINDS[kind] or key == "" then return end

    local data = MODE:GetHiddenAdminData()
    data.blacklist[kind][key] = enabled and true or nil

    ply:ChatPrint(string.format(
        "[Hidden Loadout] %s '%s' %s",
        kind, key,
        enabled and "blacklisted" or "removed from blacklist"
    ))

    applyChange()
end)

net.Receive("hidden_loadout_admin_reset", function(_, ply)
    if not canEdit(ply) then return end

    MODE.HiddenAdminData = emptyAdminData()
    ply:ChatPrint("[Hidden Loadout] All admin overrides cleared.")

    applyChange()
end)

-- Sync admin data to fresh joins so the client UI can render the Admin tab.
hook.Add("PlayerInitialSpawn", "ZCity_HiddenLoadoutAdminSync", function(ply)
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        broadcastAdminSync(ply)
    end)
end)
