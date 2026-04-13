if CLIENT then return end

local SAVE_PATH = "zc_player_warnings.json"
local MAX_WARNS_PER_PLAYER = 30
local MAX_ROWS_SENT = 250

local warnings = {}

util.AddNetworkString("ZC_WarnMenu_Open")
util.AddNetworkString("ZC_WarnMenu_Request")
util.AddNetworkString("ZC_WarnMenu_Data")

local function lowerTrim(s)
    return string.lower(string.Trim(tostring(s or "")))
end

local function isOperator(ply)
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

local function saveWarnings()
    local json = util.TableToJSON(warnings, true)
    if not json then return false end
    file.Write(SAVE_PATH, json)
    return true
end

local function loadWarnings()
    if not file.Exists(SAVE_PATH, "DATA") then
        warnings = {}
        return
    end

    local raw = file.Read(SAVE_PATH, "DATA")
    if not raw or raw == "" then
        warnings = {}
        return
    end

    local tbl = util.JSONToTable(raw)
    if not istable(tbl) then
        warnings = {}
        return
    end

    warnings = tbl
end

local function steamKeyFromPlayer(ply)
    if not IsValid(ply) then return nil end
    return ply:SteamID64() or tostring(ply:EntIndex())
end

local function getPlayerWarnings(key)
    if not isstring(key) or key == "" then return {} end
    warnings[key] = warnings[key] or {}
    return warnings[key]
end

local function appendWarn(target, issuer, reason)
    local key = steamKeyFromPlayer(target)
    if not key then return false end

    local list = getPlayerWarnings(key)
    list[#list + 1] = {
        at = os.time(),
        by = IsValid(issuer) and issuer:Nick() or "Console",
        by_sid64 = IsValid(issuer) and (issuer:SteamID64() or "") or "",
        target_name = IsValid(target) and target:Nick() or "unknown",
        reason = reason,
    }

    while #list > MAX_WARNS_PER_PLAYER do
        table.remove(list, 1)
    end

    warnings[key] = list
    saveWarnings()
    return true
end

local function findOnlinePlayer(query)
    query = lowerTrim(query)
    if query == "" then return nil end

    local exact = nil
    local partial = nil

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local name = lowerTrim(ply:Nick())
        local sid64 = tostring(ply:SteamID64() or "")
        local userid = tostring(ply:UserID() or "")

        if name == query or sid64 == query or userid == query then
            exact = ply
            break
        end

        if string.find(name, query, 1, true) then
            if partial then
                return nil, "Multiple players match that name."
            end
            partial = ply
        end
    end

    return exact or partial
end

local function formatTimestamp(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return "unknown-time" end
    return os.date("%Y-%m-%d %H:%M:%S", ts)
end

local function buildWarnRows(query)
    local q = lowerTrim(query)
    local rows = {}

    for steamid64, list in pairs(warnings) do
        if not istable(list) then continue end

        for idx, w in ipairs(list) do
            if not istable(w) then continue end

            local targetName = tostring(w.target_name or "unknown")
            local reason = tostring(w.reason or "")
            local by = tostring(w.by or "unknown")
            local bySid = tostring(w.by_sid64 or "")
            local ts = tonumber(w.at) or 0

            local matchesQuery = true
            if q ~= "" then
                local haystack = string.lower(targetName .. " " .. tostring(steamid64) .. " " .. reason .. " " .. by .. " " .. bySid)
                if not string.find(haystack, q, 1, true) then
                    matchesQuery = false
                end
            end

            if matchesQuery then
                rows[#rows + 1] = {
                    target_name = targetName,
                    target_sid64 = tostring(steamid64),
                    reason = reason,
                    by = by,
                    by_sid64 = bySid,
                    at = ts,
                    at_text = formatTimestamp(ts),
                    index = idx,
                }
            end
        end
    end

    table.sort(rows, function(a, b)
        return (a.at or 0) > (b.at or 0)
    end)

    if #rows > MAX_ROWS_SENT then
        local trimmed = {}
        for i = 1, MAX_ROWS_SENT do
            trimmed[i] = rows[i]
        end
        rows = trimmed
    end

    return rows
end

local function sendWarnList(viewer, header, list)
    if not IsValid(viewer) then return end
    viewer:ChatPrint(header)

    if #list == 0 then
        viewer:ChatPrint("[Warn] No warnings found.")
        return
    end

    local start = math.max(1, #list - 9)
    for i = start, #list do
        local w = list[i]
        local line = string.format(
            "[Warn] #%d | %s | by %s | %s",
            i,
            formatTimestamp(w.at),
            tostring(w.by or "unknown"),
            tostring(w.reason or "No reason")
        )
        viewer:ChatPrint(line)
    end

    if start > 1 then
        viewer:ChatPrint("[Warn] Showing latest 10 of " .. tostring(#list) .. " total warnings.")
    end
end

local function warnCommand(ply, text)
    if not IsValid(ply) then return false end
    if not isOperator(ply) then
        ply:ChatPrint("[Warn] You do not have permission to use !warn.")
        return true
    end

    local rest = string.Trim(string.sub(text, 6))
    if rest == "" then
        ply:ChatPrint("[Warn] Usage: !warn <player> <reason>")
        return true
    end

    local spacePos = string.find(rest, " ", 1, true)
    if not spacePos then
        ply:ChatPrint("[Warn] Usage: !warn <player> <reason>")
        return true
    end

    local targetQuery = string.Trim(string.sub(rest, 1, spacePos - 1))
    local reason = string.Trim(string.sub(rest, spacePos + 1))

    if reason == "" then
        ply:ChatPrint("[Warn] Reason is required.")
        return true
    end

    local target, err = findOnlinePlayer(targetQuery)
    if not IsValid(target) then
        ply:ChatPrint("[Warn] Target not found. " .. tostring(err or ""))
        return true
    end

    if appendWarn(target, ply, reason) then
        ply:ChatPrint("[Warn] Warning added for " .. target:Nick() .. ".")
        target:ChatPrint("[Warn] You have received a warning: " .. reason)

        if ulx and ulx.logString then
            ulx.logString(string.format("%s warned %s: %s", ply:Nick(), target:Nick(), reason))
        end
    else
        ply:ChatPrint("[Warn] Failed to save warning.")
    end

    return true
end

local function viewWarnsCommand(ply, text)
    if not IsValid(ply) then return false end
    if not isOperator(ply) then
        ply:ChatPrint("[Warn] You do not have permission to use !viewwarns.")
        return true
    end

    local rest = string.Trim(string.sub(text, 11))
    net.Start("ZC_WarnMenu_Open")
        net.WriteString(rest or "")
    net.Send(ply)
    return true
end

net.Receive("ZC_WarnMenu_Request", function(_, ply)
    if not IsValid(ply) or not isOperator(ply) then return end

    local query = net.ReadString() or ""
    local rows = buildWarnRows(query)

    net.Start("ZC_WarnMenu_Data")
        net.WriteUInt(#rows, 9)
        for _, row in ipairs(rows) do
            net.WriteString(row.at_text or "unknown-time")
            net.WriteString(row.target_name or "unknown")
            net.WriteString(row.target_sid64 or "")
            net.WriteString(row.by or "unknown")
            net.WriteString(row.reason or "")
        end
    net.Send(ply)
end)

hook.Add("Initialize", "ZC_Warnings_Load", function()
    loadWarnings()
end)

hook.Add("InitPostEntity", "ZC_Warnings_LoadLate", function()
    if next(warnings) == nil then
        loadWarnings()
    end
end)

hook.Add("HG_PlayerSay", "ZC_Warnings_Commands", function(ply, txtTbl, text)
    local msg = lowerTrim(text)

    if string.sub(msg, 1, 5) == "!warn" then
        if warnCommand(ply, tostring(text or "")) then
            return ""
        end
    end

    if string.sub(msg, 1, 10) == "!viewwarns" then
        if viewWarnsCommand(ply, tostring(text or "")) then
            return ""
        end
    end
end)
