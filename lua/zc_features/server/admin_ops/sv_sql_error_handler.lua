-- SQL Duplicate Key Handler
-- Converts selected INSERT queries into UPSERTs once hg.MySQL becomes available.

if CLIENT then return end

local INSTALL_TIMER = "ZC_SQLDuplicateKeyHandlerInstall"
local patchedQueries = 0

local upsertClauses = {
    hg_achievements = "steam_name=VALUES(steam_name), achievements=VALUES(achievements)",
    zb_experience = "steam_name=VALUES(steam_name), skill=VALUES(skill), experience=VALUES(experience), deaths=VALUES(deaths), kills=VALUES(kills), suicides=VALUES(suicides)",
    zb_guilt = "steam_name=VALUES(steam_name), value=VALUES(value)",
    hg_pointshop = "steam_name=VALUES(steam_name), donpoints=VALUES(donpoints), points=VALUES(points), items=VALUES(items)",
}

local function convertToUpsert(queryStr)
    if type(queryStr) ~= "string" then return queryStr end
    if string.find(queryStr, "ON DUPLICATE KEY UPDATE", 1, true) then
        return queryStr
    end

    local tableName = string.match(queryStr, "^%s*[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Nn][Tt][Oo]%s+`?([%w_]+)`?")
    if not tableName then
        return queryStr
    end

    local updateClause = upsertClauses[tableName]
    if not updateClause then
        return queryStr
    end

    local valuesStart, valuesEnd = string.find(queryStr, "[Vv][Aa][Ll][Uu][Ee][Ss]%s*%b()")
    if not valuesStart or not valuesEnd then
        return queryStr
    end

    local rewritten = string.sub(queryStr, 1, valuesEnd) .. " ON DUPLICATE KEY UPDATE " .. updateClause

    patchedQueries = patchedQueries + 1
    if patchedQueries <= 10 then
        print("[DCityPatch] Rewrote INSERT as UPSERT for " .. tableName)
    end

    return rewritten
end

local function patchRawQueryTable(dbObj, tag)
    if not istable(dbObj) then return false end
    if dbObj._ZC_DuplicateKeyHandlerInstalled then return true end

    local originalRawQuery = dbObj.RawQuery
    if not isfunction(originalRawQuery) then return false end

    dbObj._ZC_DuplicateKeyHandlerInstalled = true
    dbObj._ZC_OriginalRawQuery = originalRawQuery

    dbObj.RawQuery = function(self, queryStr, callback, ...)
        return originalRawQuery(self, convertToUpsert(queryStr), callback, ...)
    end

    print("[DCityPatch] SQL duplicate-key handler installed on " .. tostring(tag))
    return true
end

local function patchErrorCallback(dbObj)
    if not istable(dbObj) then return false end
    if dbObj._ZC_OriginalErrorCallback or not isfunction(dbObj.ErrorCallback) then
        return dbObj._ZC_OriginalErrorCallback ~= nil
    end

    dbObj._ZC_OriginalErrorCallback = dbObj.ErrorCallback

    function dbObj.ErrorCallback(err, query, ...)
        local errStr = tostring(err or "")
        if string.find(errStr, "Duplicate entry", 1, true) then
            print("[DCityPatch-Warning] Duplicate key still occurred after UPSERT rewrite: " .. errStr)
            print("  Query: " .. string.sub(tostring(query or ""), 1, 180) .. "...")
            return
        end

        return dbObj._ZC_OriginalErrorCallback(err, query, ...)
    end

    return true
end

local function installHandler()
    local ok = false

    if istable(mysql) then
        ok = patchRawQueryTable(mysql, "mysql") or ok
    end

    if hg and istable(hg.mysql) then
        ok = patchRawQueryTable(hg.mysql, "hg.mysql") or ok
    end

    if hg and istable(hg.MySQL) then
        if isfunction(hg.MySQL.query) and not hg.MySQL._ZC_DuplicateKeyQueryWrapped then
            local originalQuery = hg.MySQL.query
            hg.MySQL._ZC_DuplicateKeyQueryWrapped = true
            hg.MySQL.query = function(queryStr, callback, ...)
                return originalQuery(convertToUpsert(queryStr), callback, ...)
            end
            ok = true
        end

        ok = patchErrorCallback(hg.MySQL) or ok
    end

    return ok
end

timer.Create(INSTALL_TIMER, 1, 0, function()
    if installHandler() then
        timer.Remove(INSTALL_TIMER)
    end
end)

timer.Simple(0, function()
    if installHandler() then
        timer.Remove(INSTALL_TIMER)
    end
end)
