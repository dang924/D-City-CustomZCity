local VECTOR_ZERO = Vector(0, 0, 0)
local ANGLE_ZERO = Angle(0, 0, 0)

local function normalizeNumber(value, fallback)
    local asNumber = tonumber(value)
    if asNumber == nil then
        return fallback
    end

    return asNumber
end

local function normalizeVector(value)
    if isvector(value) then
        return value
    end

    if istable(value) then
        local x = normalizeNumber(value.x or value[1], nil)
        local y = normalizeNumber(value.y or value[2], nil)
        local z = normalizeNumber(value.z or value[3], nil)
        if x ~= nil and y ~= nil and z ~= nil then
            return Vector(x, y, z)
        end
    end

    local x, y, z = string.match(tostring(value or ""), "^%[([%-%d%.]+) ([%-%d%.]+) ([%-%d%.]+)%]$")
    if x and y and z then
        return Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
    end

    return VECTOR_ZERO
end

local function normalizeAngle(value)
    if isangle(value) then
        return value
    end

    if istable(value) then
        local p = normalizeNumber(value.p or value[1], nil)
        local y = normalizeNumber(value.y or value[2], nil)
        local r = normalizeNumber(value.r or value[3], nil)
        if p ~= nil and y ~= nil and r ~= nil then
            return Angle(p, y, r)
        end
    end

    local p, y, r = string.match(tostring(value or ""), "^%{([%-%d%.]+) ([%-%d%.]+) ([%-%d%.]+)%}$")
    if p and y and r then
        return Angle(tonumber(p) or 0, tonumber(y) or 0, tonumber(r) or 0)
    end

    return ANGLE_ZERO
end

local function normalizeColor(value)
    if IsColor(value) then
        return value
    end

    if istable(value) then
        return Color(
            math.Clamp(math.floor(normalizeNumber(value.r or value[1], 255)), 0, 255),
            math.Clamp(math.floor(normalizeNumber(value.g or value[2], 255)), 0, 255),
            math.Clamp(math.floor(normalizeNumber(value.b or value[3], 255)), 0, 255),
            math.Clamp(math.floor(normalizeNumber(value.a or value[4], 255)), 0, 255)
        )
    end

    return Color(255, 255, 255, 255)
end

local function normalizeModel(value, fallback)
    if isstring(value) then
        local model = string.Trim(value)
        if model ~= "" then
            return model
        end
    end

    if isentity(value) and IsValid(value) and isfunction(value.GetModel) then
        local model = string.Trim(tostring(value:GetModel() or ""))
        if model ~= "" then
            return model
        end
    end

    fallback = string.Trim(tostring(fallback or ""))
    if fallback ~= "" then
        return fallback
    end

    return "models/error.mdl"
end

local function sanitizeKeyvalues(keyvalues)
    if not istable(keyvalues) then return {} end

    local sanitized = {}
    for key, value in pairs(keyvalues) do
        local normalizedKey = string.Trim(tostring(key or ""))
        if normalizedKey == "" then
            continue
        end

        if isstring(value) or isnumber(value) or isbool(value) then
            sanitized[normalizedKey] = value
        elseif isentity(value) and IsValid(value) and normalizedKey == "model" then
            sanitized[normalizedKey] = normalizeModel(value)
        elseif istable(value) and normalizedKey == "model" then
            sanitized[normalizedKey] = normalizeModel(value.model or value.Model)
        end
    end

    return sanitized
end

local function sanitizeNetworkVars(dt)
    if not istable(dt) then return nil end

    local sanitized = {}
    for key, value in pairs(dt) do
        local normalizedKey = string.Trim(tostring(key or ""))
        if normalizedKey == "" then
            continue
        end

        if isstring(value) or isnumber(value) or isbool(value) then
            sanitized[normalizedKey] = value
        end
    end

    if next(sanitized) == nil then
        return nil
    end

    return sanitized
end

local function logPermaPropsSpawnFailure(system, propData, stage, err)
    local rowID = tostring(istable(propData) and propData.id or "unknown")
    local class = tostring(istable(propData) and propData.class or "unknown")
    local model = tostring(istable(propData) and propData.model or "")
    local message = string.format("PermaProps spawn guard skipped row %s at %s (%s | %s)", rowID, tostring(stage or "unknown"), class, model)

    if istable(system) and isfunction(system.Print) then
        system:Print(Color(255, 175, 55), message)
    else
        print("[PermaProps] " .. message)
    end

    if err and err ~= "" then
        ErrorNoHalt("[PermaProps] " .. tostring(err) .. "\n")
    end
end

local function safeEntityCall(system, propData, stage, fn, ...)
    if not isfunction(fn) then return true end

    local ok, err = xpcall(fn, debug.traceback, ...)
    if ok then
        return true
    end

    logPermaPropsSpawnFailure(system, propData, stage, err)
    return false
end

local function installPermaPropsSpawnGuard()
    local system = rawget(_G, "PermaPropsSystem")
    if not istable(system) or not isfunction(system.SpawnProp) then return false end
    if system._zcSpawnGuardInstalled then return true end

    system._zcSpawnGuardInstalled = true

    function system:SpawnProp(propData)
        if not istable(propData) then return nil end

        local class = string.Trim(tostring(propData.class or ""))
        if class == "" then
            logPermaPropsSpawnFailure(self, propData, "validate", "missing entity class")
            return nil
        end

        local data = istable(propData.data) and propData.data or {}
        propData.data = data
        propData.model = normalizeModel(propData.model or data.model, "models/error.mdl")

        local ent = ents.Create(class)
        if not IsValid(ent) then
            logPermaPropsSpawnFailure(self, propData, "create", "invalid entity type")
            return nil
        end

        ent:SetPos(normalizeVector(data.pos))
        ent:SetAngles(normalizeAngle(data.ang))
        ent:SetModel(propData.model)
        ent:SetColor(normalizeColor(data.color))

        safeEntityCall(self, propData, "pre_spawn_hook", hook.Run, "PermaProps.PreSpawn", ent, data)

        if not safeEntityCall(self, propData, "spawn", ent.Spawn, ent) then
            SafeRemoveEntity(ent)
            return nil
        end

        safeEntityCall(self, propData, "collision", ent.SetCollisionGroup, ent, normalizeNumber(data.collision, 0))
        safeEntityCall(self, propData, "material", ent.SetMaterial, ent, tostring(data.material or ""))
        safeEntityCall(self, propData, "skin", ent.SetSkin, ent, math.max(math.floor(normalizeNumber(data.skin, 0)), 0))
        safeEntityCall(self, propData, "render_fx", ent.SetRenderFX, ent, math.max(math.floor(normalizeNumber(data.renderFX, 0)), 0))
        safeEntityCall(self, propData, "render_mode", ent.SetRenderMode, ent, math.max(math.floor(normalizeNumber(data.renderMode, 0)), 0))
        safeEntityCall(self, propData, "model_scale", ent.SetModelScale, ent, math.max(normalizeNumber(data.modelScale, 1), 0.001))

        for key, value in pairs(sanitizeKeyvalues(data.keyvalues)) do
            safeEntityCall(self, propData, "keyvalue:" .. key, ent.SetKeyValue, ent, key, value)
        end

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            safeEntityCall(self, propData, "freeze", phys.EnableMotion, phys, false)
        end

        local dt = sanitizeNetworkVars(data.dt)
        if dt then
            for key, value in pairs(dt) do
                local setter = ent["Set" .. key]
                if isfunction(setter) then
                    safeEntityCall(self, propData, "dt:" .. key, setter, ent, value)
                end
            end
        end

        ent.PermaPropID = propData.id
        self.CurrentPropsCount = (tonumber(self.CurrentPropsCount) or 0) + 1

        safeEntityCall(self, propData, "post_spawn_hook", hook.Run, "PermaProps.PostSpawn", ent, data)
        return ent
    end

    return true
end

hook.Add("PermaPropsSystem.SQLReady", "ZC_PermapropsSpawnGuard", function()
    timer.Simple(0, installPermaPropsSpawnGuard)
end)

hook.Add("Initialize", "ZC_PermapropsSpawnGuard_Init", installPermaPropsSpawnGuard)
hook.Add("InitPostEntity", "ZC_PermapropsSpawnGuard", installPermaPropsSpawnGuard)

timer.Create("ZC_PermapropsSpawnGuardRetry", 1, 10, function()
    if installPermaPropsSpawnGuard() then
        timer.Remove("ZC_PermapropsSpawnGuardRetry")
    end
end)