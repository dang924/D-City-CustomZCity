local entMeta = FindMetaTable("Entity")
if not entMeta or not isfunction(entMeta.SetKeyValue) then return end

local function normalizeGenericKeyValue(value)
    if isstring(value) then
        return value
    end

    if isnumber(value) or isbool(value) then
        return tostring(value)
    end

    if isentity(value) and IsValid(value) then
        if isfunction(value.GetName) then
            local name = string.Trim(tostring(value:GetName() or ""))
            if name ~= "" then
                return name
            end
        end

        if isfunction(value.GetModel) then
            local model = string.Trim(tostring(value:GetModel() or ""))
            if model ~= "" then
                return model
            end
        end
    end

    local asString = string.Trim(tostring(value or ""))
    if asString ~= "" then
        return asString
    end

    return ""
end

local function normalizeModelKeyValue(ent, value)
    if isstring(value) then
        value = string.Trim(value)
        if value ~= "" then
            return value
        end
    end

    if isentity(value) and IsValid(value) and isfunction(value.GetModel) then
        local model = string.Trim(tostring(value:GetModel() or ""))
        if model ~= "" then
            return model
        end
    end

    if istable(value) then
        local model = value.model or value.Model
        if isstring(model) then
            model = string.Trim(model)
            if model ~= "" then
                return model
            end
        end
    end

    local asString = string.Trim(tostring(value or ""))
    if asString ~= "" and string.EndsWith(string.lower(asString), ".mdl") then
        return asString
    end

    if IsValid(ent) and isfunction(ent.GetModel) then
        local existingModel = string.Trim(tostring(ent:GetModel() or ""))
        if existingModel ~= "" then
            return existingModel
        end
    end

    return "models/error.mdl"
end

local function installModelKeyValueGuard()
    local meta = FindMetaTable("Entity")
    if not meta or not isfunction(meta.SetKeyValue) then return end
    if meta.SetKeyValue == meta._zcModelKeyValueGuard then return end

    local rawSetKeyValue = meta.SetKeyValue

    local function guardedSetKeyValue(self, key, value)
        local originalKey = key
        local normalizedKey = string.lower(string.Trim(tostring(key or "")))
        local normalizedValue = string.lower(string.Trim(tostring(value or "")))

        if normalizedKey == "model" then
            key = "model"
            if not isstring(value) then
                value = normalizeModelKeyValue(self, value)
            end
        elseif normalizedValue == "model" then
            key = "model"
            value = normalizeModelKeyValue(self, originalKey)
        elseif not isstring(key) then
            key = string.Trim(tostring(key or ""))
        end

        if not isstring(value) then
            value = normalizedKey == "model"
                and normalizeModelKeyValue(self, value)
                or normalizeGenericKeyValue(value)
        end

        return rawSetKeyValue(self, key, value)
    end

    meta.SetKeyValue = guardedSetKeyValue
    meta._zcModelKeyValueGuard = guardedSetKeyValue
end

installModelKeyValueGuard()

hook.Add("Initialize", "ZC_PermapropsModelKeyValueGuard_Init", installModelKeyValueGuard)
hook.Add("InitPostEntity", "ZC_PermapropsModelKeyValueGuard", installModelKeyValueGuard)
hook.Add("ZB_PreRoundStart", "ZC_PermapropsModelKeyValueGuard", installModelKeyValueGuard)