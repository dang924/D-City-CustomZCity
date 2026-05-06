if not (ZSCAV and ZSCAV.WorldLoot) then
    include("autorun/sh_zscav_world_loot.lua")
end

local lib = ZSCAV and ZSCAV.WorldLoot or nil
if not istable(lib) then return end

util.AddNetworkString(lib.Net.Sync)
util.AddNetworkString(lib.Net.Action)
util.AddNetworkString(lib.Net.Open)

lib.LivePlacedEnts = lib.LivePlacedEnts or {}
lib._lastEditAt = lib._lastEditAt or {}

local EDIT_DEBOUNCE = 0.30
local REMOVE_DIST_SQR = 160 * 160
local UPDATE_DIST_SQR = 72 * 72
local PROXY_MODEL_PLACEHOLDER = "__brush_proxy__"

local function round(value)
    return math.Round(tonumber(value) or 0, 3)
end

local function ensureDir()
    if not file.IsDir(lib.DataDir, "DATA") then file.CreateDir(lib.DataDir) end
    if not file.IsDir(lib.DataSubDir, "DATA") then file.CreateDir(lib.DataSubDir) end
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

local function notice(ply, text)
    if IsValid(ply) then
        ply:ChatPrint("[ZScav] " .. tostring(text or ""))
    end
end

local function normalizeLabel(value, fallback)
    value = string.sub(string.Trim(tostring(value or "")), 1, 64)
    if value ~= "" then return value end
    return string.sub(string.Trim(tostring(fallback or "")), 1, 64)
end

local function normalizeCategory(value)
    value = string.sub(string.Trim(tostring(value or "valuable")), 1, 32)
    if value == "" then return "valuable" end
    return value
end

local function normalizeGroupDescription(value, fallback)
    value = string.sub(string.Trim(tostring(value or fallback or "")), 1, 160)
    return value
end

local function normalizeLootGroupDef(raw, forcedToken)
    raw = istable(raw) and raw or {}

    local token = lib.NormalizeLootGroupToken(forcedToken or raw.token or raw.id or raw.key or raw.name)
    if token == "" then return nil end

    local default = lib.GetDefaultLootGroupDef and lib.GetDefaultLootGroupDef(token) or nil
    local fallbackLabel = tostring(istable(default) and default.label or string.NiceName(string.sub(token, 2)))
    local classes = lib.NormalizeLootGroupClasses and lib.NormalizeLootGroupClasses(raw.classes or raw.members or raw.items or {}) or {}
    if #classes <= 0 then return nil end

    return {
        token = token,
        label = normalizeLabel(raw.label or raw.name, fallbackLabel),
        description = normalizeGroupDescription(raw.description, istable(default) and default.description or ""),
        classes = classes,
    }
end

local function normalizeChance(value)
    return math.Clamp(math.Round(tonumber(value) or 100, 2), 0, 100)
end

local function normalizeGrid(value)
    value = istable(value) and value or {}
    return {
        w = math.Clamp(math.floor(tonumber(value.w) or tonumber(value.gw) or 4), 1, 32),
        h = math.Clamp(math.floor(tonumber(value.h) or tonumber(value.gh) or 4), 1, 32),
    }
end

local function normalizeProxySize(value)
    value = istable(value) and value or {}
    return {
        x = math.Clamp(math.Round(tonumber(value.x) or tonumber(value.w) or tonumber(value.width) or 56), 8, 256),
        y = math.Clamp(math.Round(tonumber(value.y) or tonumber(value.d) or tonumber(value.depth) or 56), 8, 256),
        z = math.Clamp(math.Round(tonumber(value.z) or tonumber(value.h) or tonumber(value.height) or 72), 8, 256),
    }
end

local function normalizePos(raw)
    if isvector(raw) then
        return {
            x = round(raw.x),
            y = round(raw.y),
            z = round(raw.z),
        }
    end

    raw = istable(raw) and raw or {}
    return {
        x = round(raw.x),
        y = round(raw.y),
        z = round(raw.z),
    }
end

local function normalizeAng(raw)
    if isangle(raw) then
        return {
            p = round(raw.p),
            y = round(raw.y),
            r = round(raw.r),
        }
    end

    raw = istable(raw) and raw or {}
    return {
        p = round(raw.p),
        y = round(raw.y),
        r = round(raw.r),
    }
end

local function posToVector(raw)
    raw = istable(raw) and raw or {}
    return Vector(tonumber(raw.x) or 0, tonumber(raw.y) or 0, tonumber(raw.z) or 0)
end

local function angToAngle(raw)
    raw = istable(raw) and raw or {}
    return Angle(tonumber(raw.p) or 0, tonumber(raw.y) or 0, tonumber(raw.r) or 0)
end

local function newSpawnID()
    return string.format("wl_%d_%d", os.time(), math.random(1000, 9999))
end

local function normalizeLootRows(rows)
    local normalized = {}

    for _, row in ipairs(istable(rows) and rows or {}) do
        if not istable(row) then
            continue
        end

        local class = string.lower(string.Trim(tostring(row.class or row.item_class or row.token or "")))
        if class == "" then
            continue
        end

        local minCount = math.Clamp(math.floor(tonumber(row.min) or tonumber(row.count) or 1), 1, 32)
        local maxCount = math.Clamp(math.floor(tonumber(row.max) or tonumber(row.count) or minCount), 1, 32)
        if maxCount < minCount then
            maxCount = minCount
        end

        normalized[#normalized + 1] = {
            class = class,
            chance = normalizeChance(row.chance),
            min = minCount,
            max = maxCount,
        }
    end

    return normalized
end

local function normalizePlacedSpawn(raw, forcedID)
    if not istable(raw) then return nil end

    local proxy = raw.proxy == true
    local model = lib.NormalizeModel(raw.model)
    if model == "" and proxy then
        model = PROXY_MODEL_PLACEHOLDER
    end
    if model == "" then return nil end

    local id = string.Trim(tostring(forcedID or raw.id or newSpawnID()))
    if id == "" then
        id = newSpawnID()
    end

    return {
        id = id,
        label = normalizeLabel(raw.label or raw.name, "Loot Container"),
        model = model,
        pos = normalizePos(raw.pos or raw),
        ang = normalizeAng(raw.ang or raw),
        frozen = raw.frozen ~= false,
        spawn_chance = normalizeChance(raw.spawn_chance or raw.chance),
        grid = normalizeGrid(raw.grid or raw),
        loot = normalizeLootRows(raw.loot),
        proxy = proxy,
        proxy_size = proxy and normalizeProxySize(raw.proxy_size or raw.proxy_bounds or raw) or nil,
        container_class = lib.GetPlacedContainerClass(id),
    }
end

local function normalizeModelContainer(raw, modelKey)
    if not istable(raw) then return nil end

    local model = lib.NormalizeModel(raw.model or modelKey)
    if model == "" then return nil end

    return {
        model = model,
        label = normalizeLabel(raw.label or raw.name, "Loot Container"),
        spawn_chance = normalizeChance(raw.spawn_chance or raw.chance),
        grid = normalizeGrid(raw.grid or raw),
        loot = normalizeLootRows(raw.loot),
        container_class = lib.GetModelContainerClass(model),
    }
end

local function normalizeValuable(raw, classKey)
    if not istable(raw) then return nil end

    local itemClass = lib.GetValuableClass(classKey or raw.item_class or raw.class or raw.id or raw.key)
    local model = lib.NormalizeModel(raw.model)
    if itemClass == "" or model == "" then return nil end

    return {
        item_class = itemClass,
        name = normalizeLabel(raw.name, string.NiceName(itemClass)),
        model = model,
        w = math.Clamp(math.floor(tonumber(raw.w) or 1), 1, 16),
        h = math.Clamp(math.floor(tonumber(raw.h) or 1), 1, 16),
        weight = math.max(0, tonumber(raw.weight) or 0),
        category = normalizeCategory(raw.category),
    }
end

local function normalizeState(raw)
    raw = istable(raw) and raw or {}
    local state = {
        placed_spawns = {},
        model_containers = {},
        valuables = {},
        custom_groups = {},
    }

    for _, row in ipairs(raw.placed_spawns or {}) do
        local normalized = normalizePlacedSpawn(row)
        if normalized then
            state.placed_spawns[#state.placed_spawns + 1] = normalized
        end
    end

    for key, row in pairs(raw.model_containers or {}) do
        local normalized = normalizeModelContainer(row, key)
        if normalized then
            state.model_containers[normalized.model] = normalized
        end
    end

    for key, row in pairs(raw.valuables or {}) do
        local normalized = normalizeValuable(row, key)
        if normalized then
            state.valuables[normalized.item_class] = normalized
        end
    end

    for key, row in pairs(raw.custom_groups or raw.loot_groups or {}) do
        local normalized = normalizeLootGroupDef(row, key)
        if normalized then
            state.custom_groups[normalized.token] = normalized
        end
    end

    return state
end

local function save()
    ensureDir()
    file.Write(lib.GetSavePath(), util.TableToJSON(lib.GetState(), true) or "{}")
end

local function broadcast(target)
    net.Start(lib.Net.Sync)
        net.WriteString(util.TableToJSON(lib.GetState(), false) or "{}")
    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

local function reapplyRuntimeCatalog()
    timer.Simple(0, function()
        if ZSCAV and ZSCAV.WorldLoot and ZSCAV.WorldLoot.ApplyRuntimeCatalogEntries then
            ZSCAV.WorldLoot:ApplyRuntimeCatalogEntries()
        end
    end)
end

local function load()
    local raw = file.Read(lib.GetSavePath(), "DATA")
    if not raw or raw == "" then
        lib.SetState(normalizeState())
        return
    end

    lib.SetState(normalizeState(util.JSONToTable(raw) or {}))
end

local function findPlacedIndexByID(spawnID)
    spawnID = string.Trim(tostring(spawnID or ""))
    if spawnID == "" then return nil end

    for index, row in ipairs(lib.GetState().placed_spawns or {}) do
        if string.Trim(tostring(row.id or "")) == spawnID then
            return index
        end
    end

    return nil
end

local function findNearestPlacedIndex(pos, maxDistSq)
    if not isvector(pos) then return nil end

    local bestIndex
    local bestDist = tonumber(maxDistSq) or math.huge

    for index, row in ipairs(lib.GetState().placed_spawns or {}) do
        local rowPos = posToVector(row.pos)
        local dist = rowPos:DistToSqr(pos)
        if dist < bestDist then
            bestDist = dist
            bestIndex = index
        end
    end

    return bestIndex
end

local function canUseLootClass(class)
    class = string.lower(string.Trim(tostring(class or "")))
    if class == "" then return false end
    if lib.IsLootGroupToken and lib.IsLootGroupToken(class) then return true end
    return (ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(class)) ~= nil
        or (ZSCAV.GetGearDef and ZSCAV:GetGearDef(class)) ~= nil
        or (weapons.GetStored(class) ~= nil)
        or (scripted_ents.GetStored(class) ~= nil)
end

local function gridCanFit(contents, gridW, gridH, x, y, w, h)
    if x < 0 or y < 0 or (x + w) > gridW or (y + h) > gridH then
        return false
    end

    for _, entry in ipairs(contents) do
        local ex = tonumber(entry.x) or 0
        local ey = tonumber(entry.y) or 0
        local ew = tonumber(entry.w) or 1
        local eh = tonumber(entry.h) or 1
        if x < (ex + ew) and ex < (x + w) and y < (ey + eh) and ey < (y + h) then
            return false
        end
    end

    return true
end

local function placeEntryInGrid(contents, gridW, gridH, entry)
    if not (ZSCAV and ZSCAV.GetItemSize) then return false end

    local size = ZSCAV:GetItemSize(entry)
    local baseW = math.max(1, math.floor(tonumber(size and size.w) or 1))
    local baseH = math.max(1, math.floor(tonumber(size and size.h) or 1))
    local options = {
        { w = baseW, h = baseH },
    }

    if baseW ~= baseH then
        options[#options + 1] = { w = baseH, h = baseW }
    end

    for _, option in ipairs(options) do
        for y = 0, gridH - option.h do
            for x = 0, gridW - option.w do
                if gridCanFit(contents, gridW, gridH, x, y, option.w, option.h) then
                    entry.x = x
                    entry.y = y
                    entry.w = option.w
                    entry.h = option.h
                    contents[#contents + 1] = entry
                    return true
                end
            end
        end
    end

    return false
end

local function buildLootEntry(class)
    class = string.lower(string.Trim(tostring(class or "")))
    if class == "" then return nil end

    local entry = { class = class }
    local worldModel = lib.GetWorldModelForEntry(class)
    if worldModel ~= "" then
        entry.world_model = worldModel
    end

    local def = ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) or nil
    if istable(def) and istable(def.internal) and ZSCAV.CreateBag and ZSCAV.SaveBag then
        local uid = tostring(ZSCAV:CreateBag(class) or "")
        if uid ~= "" then
            entry.uid = uid
            ZSCAV:SaveBag(uid, class, {})
        end
    end

    return entry
end

local function getLootRowChoices(class, groupCache)
    class = string.lower(string.Trim(tostring(class or "")))
    if class == "" then return nil end
    if not (lib.IsLootGroupToken and lib.IsLootGroupToken(class)) then return nil end

    groupCache = groupCache or {}
    local cached = groupCache[class]
    if cached ~= nil then
        return cached
    end

    cached = lib.GetLootGroupMembers and lib.GetLootGroupMembers(class) or {}
    groupCache[class] = cached
    return cached
end

local function buildContainerContents(def)
    local contents = {}
    local grid = istable(def.grid) and def.grid or normalizeGrid(def)
    local gridW = math.max(1, math.floor(tonumber(grid.w) or 4))
    local gridH = math.max(1, math.floor(tonumber(grid.h) or 4))
    local groupCache = {}

    for _, row in ipairs(def.loot or {}) do
        local rowClass = string.lower(string.Trim(tostring(row.class or row.item_class or "")))
        local choices = getLootRowChoices(rowClass, groupCache)
        local canRoll = (istable(choices) and #choices > 0) or canUseLootClass(rowClass)

        if canRoll and math.Rand(0, 100) <= normalizeChance(row.chance) then
            local minCount = math.Clamp(math.floor(tonumber(row.min) or 1), 1, 32)
            local maxCount = math.Clamp(math.floor(tonumber(row.max) or minCount), minCount, 32)
            local count = math.random(minCount, maxCount)

            for _ = 1, count do
                local entryClass = rowClass
                if istable(choices) and #choices > 0 then
                    entryClass = tostring(choices[math.random(#choices)] or "")
                end

                local entry = buildLootEntry(entryClass)
                if not entry then
                    continue
                end

                if not placeEntryInGrid(contents, gridW, gridH, entry) then
                    break
                end
            end
        end
    end

    return contents
end

local function getFreezeState(ent)
    if not IsValid(ent) then return false end
    local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil
    if not IsValid(phys) then return false end
    return not phys:IsMotionEnabled()
end

local function finalizeReplacementPhysics(ent, frozen)
    local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil
    if not IsValid(phys) then return end

    phys:Wake()
    if frozen then
        phys:EnableMotion(false)
    end
end

function lib.SpawnWorldItem(def, pos, ang, frozen)
    if not istable(def) then return NULL end

    local ent = ents.Create("ent_zscav_world_item")
    if not IsValid(ent) then return NULL end

    ent:SetPos(pos or vector_origin)
    ent:SetAngles(ang or angle_zero)
    ent.zscav_pack_class = tostring(def.item_class or def.class or "")
    ent.zscav_world_model = lib.NormalizeModel(def.model)
    ent.zscav_world_entry = {
        class = tostring(def.item_class or def.class or ""),
        world_model = lib.NormalizeModel(def.model),
    }
    ent:Spawn()
    finalizeReplacementPhysics(ent, frozen == true)
    return ent
end

function lib.SpawnWorldContainer(def, pos, ang, frozen, placedID)
    if not (istable(def) and ZSCAV and ZSCAV.CreateBag and ZSCAV.SaveBag) then return NULL end

    local class = tostring(def.container_class or "")
    if class == "" then return NULL end

    local uid = tostring(ZSCAV:CreateBag(class) or "")
    if uid == "" then return NULL end

    ZSCAV:SaveBag(uid, class, buildContainerContents(def))

    local ent = ents.Create("ent_zscav_world_container")
    if not IsValid(ent) then
        if ZSCAV.DeleteBag then
            ZSCAV:DeleteBag(uid)
        end
        return NULL
    end

    ent:SetPos(pos or vector_origin)
    ent:SetAngles(ang or angle_zero)
    ent.zscav_pack_class = class
    ent.zscav_pack_uid = uid
    ent.zscav_world_model = lib.NormalizeModel(def.model)
    ent.zscav_source_model = lib.NormalizeModel(def.model)
    ent.zscav_proxy = def.proxy == true
    ent.zscav_proxy_size = ent.zscav_proxy and normalizeProxySize(def.proxy_size or def) or nil
    ent.zscav_should_freeze = frozen == true
    ent.zscav_loot_placed_id = tostring(placedID or "")
    ent:Spawn()
    finalizeReplacementPhysics(ent, frozen == true)
    return ent
end

local function replaceEntityWithWorldItem(sourceEnt, def)
    if not IsValid(sourceEnt) then return NULL end
    local pos = sourceEnt:GetPos()
    local ang = sourceEnt:GetAngles()
    local frozen = getFreezeState(sourceEnt)

    local replacement = lib.SpawnWorldItem(def, pos, ang, frozen)
    if IsValid(replacement) then
        sourceEnt:Remove()
    end
    return replacement
end

local function replaceEntityWithWorldContainer(sourceEnt, def, placedID)
    if not IsValid(sourceEnt) then return NULL end
    local pos = sourceEnt:GetPos()
    local ang = sourceEnt:GetAngles()
    local frozen = getFreezeState(sourceEnt)

    local replacement = lib.SpawnWorldContainer(def, pos, ang, frozen, placedID)
    if IsValid(replacement) then
        sourceEnt:Remove()
    end
    return replacement
end

local function isCatalogConvertibleProp(ent)
    if not IsValid(ent) then return false end
    if lib.IsWorldItemEntity and lib.IsWorldItemEntity(ent) then return false end
    if lib.IsWorldContainerEntity and lib.IsWorldContainerEntity(ent) then return false end

    local class = tostring(ent:GetClass() or "")
    if class ~= "prop_physics" and class ~= "prop_physics_multiplayer"
        and class ~= "prop_physics_override" then
        return false
    end

    if ent.zscav_world_entry or tostring(ent.zscav_pack_uid or "") ~= "" then
        return false
    end

    local model = lib.NormalizeModel(ent.GetModel and ent:GetModel() or "")
    if model == "" then return false end

    return (lib.GetWorldItemDefByModel and lib.GetWorldItemDefByModel(model) ~= nil)
        or (lib.GetModelContainerDefByModel and lib.GetModelContainerDefByModel(model) ~= nil)
end

function lib.TryAdoptEntityFromCatalog(ent)
    if not isCatalogConvertibleProp(ent) then return NULL end

    local model = lib.NormalizeModel(ent.GetModel and ent:GetModel() or "")
    local itemDef = lib.GetWorldItemDefByModel and lib.GetWorldItemDefByModel(model) or nil
    if istable(itemDef) then
        return replaceEntityWithWorldItem(ent, itemDef)
    end

    local containerDef = lib.GetModelContainerDefByModel and lib.GetModelContainerDefByModel(model) or nil
    if istable(containerDef) then
        return replaceEntityWithWorldContainer(ent, containerDef)
    end

    return NULL
end

local function queueCatalogPropAdoption(ent, delay)
    if not IsValid(ent) then return end

    timer.Simple(math.max(tonumber(delay) or 0, 0), function()
        if not IsValid(ent) then return end
        if not (ZSCAV and ZSCAV.IsActive and ZSCAV:IsActive()) then return end

        lib.TryAdoptEntityFromCatalog(ent)
    end)
end

local function removeLivePlacedEntity(ent)
    if not IsValid(ent) then return end

    if ZSCAV and ZSCAV.GetEntPackUID and ZSCAV.DeleteBag then
        local uid = tostring(ZSCAV:GetEntPackUID(ent) or "")
        if uid ~= "" then
            ZSCAV:DeleteBag(uid)
        end
    end

    ent:Remove()
end

function lib.RespawnPlacedContainers()
    for id, ent in pairs(lib.LivePlacedEnts or {}) do
        lib.LivePlacedEnts[id] = nil
        removeLivePlacedEntity(ent)
    end

    for _, row in ipairs(lib.GetState().placed_spawns or {}) do
        if math.Rand(0, 100) <= normalizeChance(row.spawn_chance) then
            local ent = lib.SpawnWorldContainer(row, posToVector(row.pos), angToAngle(row.ang), row.frozen ~= false, row.id)
            if IsValid(ent) then
                lib.LivePlacedEnts[row.id] = ent
            end
        end
    end
end

local function syncState(target)
    reapplyRuntimeCatalog()
    save()
    broadcast(target)
end

local function findValuableClassByModel(model, exceptClass)
    model = lib.NormalizeModel(model)
    exceptClass = lib.GetValuableClass(exceptClass)
    if model == "" then return "" end

    for class, def in pairs(lib.GetState().valuables or {}) do
        if class ~= exceptClass and istable(def) and lib.NormalizeModel(def.model) == model then
            return tostring(class)
        end
    end

    return ""
end

local function saveValuableProfile(payload, ply)
    payload = istable(payload) and payload or {}

    local model = lib.NormalizeModel(payload.model)
    if model == "" then
        notice(ply, "Pick a prop model first.")
        return nil
    end

    local state = lib.GetState()
    if state.model_containers[model] then
        notice(ply, "That prop model is already registered as an auto-loot container.")
        return nil
    end

    local suggestedClass = (lib.GetSuggestedValuableClassForModel and lib.GetSuggestedValuableClassForModel(model)) or ""
    local suggestedName = (lib.GetSuggestedValuableNameForModel and lib.GetSuggestedValuableNameForModel(model)) or "Prop Item"
    local normalized = normalizeValuable({
        item_class = tostring(payload.item_class or suggestedClass),
        class = tostring(payload.item_class or suggestedClass),
        name = tostring(payload.name or suggestedName),
        model = model,
        w = payload.w,
        h = payload.h,
        weight = payload.weight,
        category = payload.category,
    }, payload.item_class)
    if not normalized then
        notice(ply, "Provide a valuable id before saving this prop profile.")
        return nil
    end

    local previousClass = lib.GetValuableClass(payload.previous_item_class)
    if previousClass ~= "" and previousClass ~= normalized.item_class then
        state.valuables[previousClass] = nil
    end

    local duplicateModelClass = findValuableClassByModel(normalized.model, normalized.item_class)
    if duplicateModelClass ~= "" then
        state.valuables[duplicateModelClass] = nil
    end

    state.valuables[normalized.item_class] = normalized
    lib.SetState(normalizeState(state))
    syncState()

    if payload.open_config and ZSCAV and ZSCAV.OpenConfigForClass then
        timer.Simple(0, function()
            if IsValid(ply) then
                ZSCAV:OpenConfigForClass(ply, normalized.item_class)
            end
        end)
    end

    return normalized
end

local function cleanupBagEntry(entry)
    if not (istable(entry) and ZSCAV and ZSCAV.DeleteBag) then return end

    local uid = tostring(entry.uid or "")
    if uid ~= "" then
        ZSCAV:DeleteBag(uid)
    end
end

local function resolveTargetContainerProfile(ent)
    if not IsValid(ent) then return nil, nil, nil end

    local state = lib.GetState()
    local placedID = string.Trim(tostring(ent.zscav_loot_placed_id or ""))
    if placedID ~= "" then
        local index = findPlacedIndexByID(placedID)
        if index then
            return "placed", index, state.placed_spawns[index]
        end
    end

    local model = lib.NormalizeModel(ent.GetModel and ent:GetModel() or "")
    if model ~= "" and istable(state.model_containers[model]) then
        return "model", model, state.model_containers[model]
    end

    local containerClass = string.Trim(tostring(ent.zscav_pack_class or ""))
    if containerClass ~= "" then
        for index, row in ipairs(state.placed_spawns or {}) do
            if string.Trim(tostring(row.container_class or "")) == containerClass then
                return "placed", index, row
            end
        end

        for key, row in pairs(state.model_containers or {}) do
            if string.Trim(tostring(row.container_class or "")) == containerClass then
                return "model", key, row
            end
        end
    end

    return nil, nil, nil
end

local function getTargetContainerBag(ent)
    if not (IsValid(ent) and ZSCAV and ZSCAV.LoadBag and ZSCAV.GetEntPackUID) then
        return "", nil
    end

    local uid = tostring(ZSCAV:GetEntPackUID(ent) or "")
    if uid == "" then
        uid = tostring(ent.zscav_corpse_root_uid or "")
    end
    if uid == "" then return "", nil end

    return uid, ZSCAV:LoadBag(uid)
end

local function getContainerGridForTarget(def, bag)
    if istable(def) then
        return normalizeGrid(def.grid or def)
    end

    local gearDef = ZSCAV and ZSCAV.GetGearDef and ZSCAV:GetGearDef(tostring(istable(bag) and bag.class or "")) or nil
    local internal = istable(gearDef) and gearDef.internal or nil
    if not istable(internal) then return nil end

    return normalizeGrid(internal)
end

local function upsertLootRow(def, class, count)
    if not istable(def) then return false end

    def.loot = normalizeLootRows(def.loot or {})
    local itemClass = string.lower(string.Trim(tostring(class or "")))
    local amount = math.Clamp(math.floor(tonumber(count) or 1), 1, 32)
    if itemClass == "" then return false end

    for _, row in ipairs(def.loot) do
        if string.lower(string.Trim(tostring(row.class or ""))) == itemClass then
            row.chance = 100
            row.min = amount
            row.max = amount
            return true
        end
    end

    def.loot[#def.loot + 1] = {
        class = itemClass,
        chance = 100,
        min = amount,
        max = amount,
    }
    return true
end

local function insertEntriesIntoBag(uid, bag, grid, class, count)
    if uid == "" or not (istable(bag) and istable(grid) and ZSCAV and ZSCAV.SaveBag) then
        return 0
    end

    bag.contents = istable(bag.contents) and bag.contents or {}
    local inserted = 0

    for _ = 1, math.Clamp(math.floor(tonumber(count) or 1), 1, 32) do
        local entry = buildLootEntry(class)
        if not entry then break end

        if placeEntryInGrid(bag.contents, tonumber(grid.w) or 0, tonumber(grid.h) or 0, entry) then
            inserted = inserted + 1
        else
            cleanupBagEntry(entry)
            break
        end
    end

    if inserted > 0 then
        ZSCAV:SaveBag(uid, tostring(bag.class or ""), bag.contents)
    end

    return inserted
end

local function spawnValuableFromPayload(payload, ply)
    local normalized = saveValuableProfile(payload, ply)
    if not normalized or not IsValid(ply) then return false end

    local count = math.Clamp(math.floor(tonumber(payload.count) or 1), 1, 32)
    local basePos = ply:EyePos() + ply:GetAimVector() * 52
    local right = ply:GetRight()
    local ang = Angle(0, ply:EyeAngles().y, 0)
    local spawned = 0

    for index = 1, count do
        local slot = index - 1
        local offset = right * (((slot % 5) - 2) * 14) + Vector(0, 0, math.floor(slot / 5) * 6)
        local ent = lib.SpawnWorldItem(normalized, basePos + offset, ang, false)
        if IsValid(ent) then
            spawned = spawned + 1
        end
    end

    if spawned > 0 then
        notice(ply, string.format("Spawned %d '%s' world item%s.", spawned, tostring(normalized.name or normalized.item_class), spawned == 1 and "" or "s"))
        return true
    end

    notice(ply, "Could not spawn that valuable profile.")
    return false
end

local function addValuableToTargetContainer(payload, ply)
    local normalized = saveValuableProfile(payload, ply)
    if not normalized then return false end

    local ent = getPayloadEntity(payload)
    if not IsValid(ent) then
        notice(ply, "Aim at a loot container or saved loot prop first.")
        return false
    end

    local count = math.Clamp(math.floor(tonumber(payload.count) or 1), 1, 32)
    local profileScope, profileKey, profileDef = resolveTargetContainerProfile(ent)
    local persisted = false

    if profileScope ~= nil then
        local state = lib.GetState()
        local targetDef = profileScope == "placed" and state.placed_spawns[profileKey] or state.model_containers[profileKey]
        if istable(targetDef) and upsertLootRow(targetDef, normalized.item_class, count) then
            lib.SetState(normalizeState(state))
            syncState()
            persisted = true
            profileDef = targetDef
        end
    end

    local uid, bag = getTargetContainerBag(ent)
    local inserted = 0
    if uid ~= "" and istable(bag) then
        local grid = getContainerGridForTarget(profileDef, bag)
        if istable(grid) then
            inserted = insertEntriesIntoBag(uid, bag, grid, normalized.item_class, count)
        end
    end

    if persisted and inserted > 0 then
        notice(ply, string.format("Saved '%s' to the aimed container profile and inserted %d live cop%s.", tostring(normalized.name or normalized.item_class), inserted, inserted == 1 and "y" or "ies"))
        return true
    end

    if persisted then
        notice(ply, string.format("Saved '%s' into the aimed container loot profile.", tostring(normalized.name or normalized.item_class)))
        return true
    end

    if inserted > 0 then
        notice(ply, string.format("Inserted %d live '%s' cop%s into the aimed container.", inserted, tostring(normalized.name or normalized.item_class), inserted == 1 and "y" or "ies"))
        return true
    end

    notice(ply, "That aimed entity does not expose a usable ZScav container profile or free grid space.")
    return false
end

local function refreshPlacedContainers()
    reapplyRuntimeCatalog()
    timer.Simple(0, function()
        if ZSCAV and ZSCAV.WorldLoot and ZSCAV.WorldLoot.RespawnPlacedContainers then
            ZSCAV.WorldLoot:RespawnPlacedContainers()
        else
            lib.RespawnPlacedContainers()
        end
    end)
end

local function extractPayload()
    local raw = net.ReadString() or "{}"
    local data = util.JSONToTable(raw)
    return istable(data) and data or {}
end

local function getPayloadEntity(data)
    if not istable(data) then return nil end
    local entIndex = tonumber(data.ent_index) or -1
    local ent = Entity(entIndex)
    if not IsValid(ent) then return nil end
    return ent
end

local function upsertPlacedSpawnFromEntity(ent, payload, ply)
    payload = istable(payload) and payload or {}

    local hasEnt = IsValid(ent)
    local explicitID = string.Trim(tostring(payload.id or ""))
    local payloadPos = istable(payload.pos) and posToVector(payload.pos) or nil

    if not hasEnt and not isvector(payloadPos) then
        notice(ply, "Aim at a prop or existing loot container first.")
        return false
    end

    local existingID = explicitID
    if existingID == "" and hasEnt then
        existingID = string.Trim(tostring(ent.zscav_loot_placed_id or ""))
    end
    if existingID == "" then
        local nearestPos = payloadPos or (hasEnt and ent:GetPos() or nil)
        local nearestIndex = isvector(nearestPos) and findNearestPlacedIndex(nearestPos, UPDATE_DIST_SQR) or nil
        if nearestIndex then
            existingID = tostring((lib.GetState().placed_spawns or {})[nearestIndex].id or "")
        end
    end

    local state = lib.GetState()
    local existingIndex = existingID ~= "" and findPlacedIndexByID(existingID) or nil
    local existingRow = existingIndex and state.placed_spawns[existingIndex] or nil
    local proxyMode = payload.proxy == true or (payload.proxy == nil and istable(existingRow) and existingRow.proxy == true)

    local model = lib.NormalizeModel(payload.model)
    if model == "" and hasEnt then
        model = lib.NormalizeModel(ent.zscav_source_model or (ent.GetModel and ent:GetModel() or ""))
    end
    if model == "" and istable(existingRow) then
        model = lib.NormalizeModel(existingRow.model)
    end

    local savePos
    local saveAng
    if proxyMode then
        savePos = (payload.proxy == true and isvector(payloadPos)) and payloadPos or (istable(existingRow) and posToVector(existingRow.pos) or payloadPos or (hasEnt and ent:GetPos() or vector_origin))
        saveAng = (payload.proxy == true and istable(payload.ang)) and angToAngle(payload.ang) or (istable(existingRow) and angToAngle(existingRow.ang) or angle_zero)
    else
        savePos = hasEnt and ent:GetPos() or payloadPos or vector_origin
        saveAng = hasEnt and ent:GetAngles() or (istable(payload.ang) and angToAngle(payload.ang) or angle_zero)
    end

    local proxySize = proxyMode and normalizeProxySize(payload.proxy_size or (istable(existingRow) and existingRow.proxy_size) or {}) or nil
    local normalized = normalizePlacedSpawn({
        id = existingID,
        label = payload.label,
        name = payload.label,
        model = model,
        pos = savePos,
        ang = saveAng,
        frozen = proxyMode and true or (payload.frozen ~= false and ((hasEnt and getFreezeState(ent)) or (istable(existingRow) and existingRow.frozen ~= false))),
        spawn_chance = payload.spawn_chance,
        grid = payload.grid,
        loot = payload.loot,
        proxy = proxyMode,
        proxy_size = proxySize,
    }, existingID ~= "" and existingID or nil)
    if not normalized then
        notice(ply, "Could not create a loot container from that entity.")
        return false
    end

    if existingIndex then
        state.placed_spawns[existingIndex] = normalized
    else
        state.placed_spawns[#state.placed_spawns + 1] = normalized
    end

    lib.SetState(normalizeState(state))
    syncState()
    refreshPlacedContainers()
    if normalized.proxy then
        notice(ply, string.format("Saved contact-box container '%s' (%dx%d, %.0f%% spawn chance, box %dx%dx%d).",
            normalized.label,
            normalized.grid.w,
            normalized.grid.h,
            normalized.spawn_chance,
            tonumber(normalized.proxy_size and normalized.proxy_size.x) or 0,
            tonumber(normalized.proxy_size and normalized.proxy_size.y) or 0,
            tonumber(normalized.proxy_size and normalized.proxy_size.z) or 0))
    else
        notice(ply, string.format("Saved placed loot container '%s' (%dx%d, %.0f%% spawn chance).",
            normalized.label,
            normalized.grid.w,
            normalized.grid.h,
            normalized.spawn_chance))
    end
    return true
end

local function removePlacedSpawnForEntity(ent, payload, ply)
    local index = nil
    payload = istable(payload) and payload or {}

    local explicitID = string.Trim(tostring(payload.id or ""))
    if explicitID ~= "" then
        index = findPlacedIndexByID(explicitID)
    end

    if not index and istable(payload.pos) then
        index = findNearestPlacedIndex(posToVector(payload.pos), REMOVE_DIST_SQR)
    end

    if not index and IsValid(ent) then
        local placedID = string.Trim(tostring(ent.zscav_loot_placed_id or ""))
        if placedID ~= "" then
            index = findPlacedIndexByID(placedID)
        else
            index = findNearestPlacedIndex(ent:GetPos(), REMOVE_DIST_SQR)
        end
    end

    if not index then
        notice(ply, "No saved loot container was found for that prop.")
        return false
    end

    local state = lib.GetState()
    local removed = table.remove(state.placed_spawns, index)
    lib.SetState(normalizeState(state))
    syncState()
    refreshPlacedContainers()

    if removed then
        notice(ply, string.format("Removed placed loot container '%s'.", tostring(removed.label or removed.id or index)))
    end
    return true
end

local function registerModelContainerFromEntity(ent, payload, ply)
    payload = istable(payload) and payload or {}

    local model = lib.NormalizeModel(payload.model)
    if model == "" and IsValid(ent) then
        model = lib.NormalizeModel(ent:GetModel())
    end
    if model == "" then
        notice(ply, "Aim at a prop or provide a prop model first.")
        return false
    end

    local state = lib.GetState()
    if lib.GetWorldItemDefByModel(model) then
        notice(ply, "That prop model is already registered as a valuable item.")
        return false
    end

    state.model_containers[model] = normalizeModelContainer({
        model = model,
        label = payload.label,
        name = payload.label,
        spawn_chance = payload.spawn_chance,
        grid = payload.grid,
        loot = payload.loot,
    }, model)

    lib.SetState(normalizeState(state))
    syncState()

    local replacement = IsValid(ent) and replaceEntityWithWorldContainer(ent, state.model_containers[model]) or NULL
    if IsValid(replacement) then
        notice(ply, string.format("Registered %s as an auto-loot container model and converted this prop.", model))
    else
        notice(ply, string.format("Registered %s as an auto-loot container model.", model))
    end

    return true
end

local function unregisterModelContainerFromEntity(ent, payload, ply)
    local model = lib.NormalizeModel(istable(payload) and payload.model or "")
    if model == "" and IsValid(ent) then
        model = lib.NormalizeModel(ent:GetModel())
    end

    if model == "" then
        notice(ply, "Aim at a prop or select a saved model profile first.")
        return false
    end

    local state = lib.GetState()
    if not state.model_containers[model] then
        notice(ply, "That model is not registered as an auto-loot container.")
        return false
    end

    state.model_containers[model] = nil
    lib.SetState(normalizeState(state))
    syncState()
    notice(ply, string.format("Removed auto-loot container profile for %s.", model))
    return true
end

local function registerValuableFromEntity(ent, payload, ply)
    payload = istable(payload) and payload or {}

    if (payload.model == nil or tostring(payload.model) == "") and IsValid(ent) then
        payload.model = lib.NormalizeModel(ent:GetModel())
    end

    local normalized = saveValuableProfile(payload, ply)
    if not normalized then return false end

    local replacement = IsValid(ent) and replaceEntityWithWorldItem(ent, normalized) or NULL
    if IsValid(replacement) then
        notice(ply, string.format("Registered %s and converted this prop into a pickup item.", normalized.item_class))
    else
        notice(ply, string.format("Registered %s as a prop-backed valuable.", normalized.item_class))
    end

    return true
end

local function unregisterValuableFromEntity(ent, payload, ply)
    local state = lib.GetState()
    local class = lib.GetValuableClass(payload.item_class)

    if class == "" and IsValid(ent) then
        local def = lib.GetWorldItemDefByModel(ent:GetModel())
        class = tostring(istable(def) and def.item_class or "")
    end

    if class == "" or not state.valuables[class] then
        notice(ply, "No valuable profile matched that prop.")
        return false
    end

    state.valuables[class] = nil
    lib.SetState(normalizeState(state))
    syncState()
    notice(ply, string.format("Removed prop-backed valuable profile %s.", class))
    return true
end

local function registerLootGroup(payload, ply)
    local normalized = normalizeLootGroupDef(payload, istable(payload) and payload.token or nil)
    if not normalized then
        notice(ply, "Provide a group token and at least one valid member item first.")
        return false
    end

    local state = lib.GetState()
    state.custom_groups[normalized.token] = normalized
    lib.SetState(normalizeState(state))
    syncState()

    if lib.IsDefaultLootGroupToken and lib.IsDefaultLootGroupToken(normalized.token) then
        notice(ply, string.format("Saved override for loot group %s.", normalized.token))
    else
        notice(ply, string.format("Saved custom loot group %s.", normalized.token))
    end
    return true
end

local function unregisterLootGroup(payload, ply)
    local token = lib.NormalizeLootGroupToken(istable(payload) and payload.token or "")
    if token == "" then
        notice(ply, "Select a loot group first.")
        return false
    end

    local state = lib.GetState()
    if not istable(state.custom_groups) or not state.custom_groups[token] then
        if lib.IsDefaultLootGroupToken and lib.IsDefaultLootGroupToken(token) then
            notice(ply, string.format("Loot group %s is already using its default definition.", token))
        else
            notice(ply, string.format("No custom loot group matched %s.", token))
        end
        return false
    end

    state.custom_groups[token] = nil
    lib.SetState(normalizeState(state))
    syncState()

    if lib.IsDefaultLootGroupToken and lib.IsDefaultLootGroupToken(token) then
        notice(ply, string.format("Reset loot group %s back to its default definition.", token))
    else
        notice(ply, string.format("Removed custom loot group %s.", token))
    end
    return true
end

net.Receive(lib.Net.Action, function(_, ply)
    if not canEdit(ply) then return end
    if not passDebounce(ply) then return end

    local action = net.ReadUInt(4)
    local payload = extractPayload()
    local ent = getPayloadEntity(payload)

    if action == lib.ACTION_PLACE_CONTAINER then
        upsertPlacedSpawnFromEntity(ent, payload, ply)
    elseif action == lib.ACTION_REMOVE_CONTAINER then
        removePlacedSpawnForEntity(ent, payload, ply)
    elseif action == lib.ACTION_REGISTER_MODEL_CONTAINER then
        registerModelContainerFromEntity(ent, payload, ply)
    elseif action == lib.ACTION_UNREGISTER_MODEL_CONTAINER then
        unregisterModelContainerFromEntity(ent, payload, ply)
    elseif action == lib.ACTION_REGISTER_VALUABLE then
        registerValuableFromEntity(ent, payload, ply)
    elseif action == lib.ACTION_UNREGISTER_VALUABLE then
        unregisterValuableFromEntity(ent, payload, ply)
    elseif action == lib.ACTION_SPAWN_VALUABLE then
        spawnValuableFromPayload(payload, ply)
    elseif action == lib.ACTION_ADD_VALUABLE_TO_CONTAINER then
        payload.ent_index = payload.ent_index or (IsValid(ent) and ent:EntIndex()) or -1
        addValuableToTargetContainer(payload, ply)
    elseif action == lib.ACTION_REGISTER_LOOT_GROUP then
        registerLootGroup(payload, ply)
    elseif action == lib.ACTION_UNREGISTER_LOOT_GROUP then
        unregisterLootGroup(payload, ply)
    end
end)

hook.Add("Initialize", "ZScavWorldLoot_LoadState", function()
    load()
    reapplyRuntimeCatalog()
end)

hook.Add("InitPostEntity", "ZScavWorldLoot_SpawnPlacedContainers", function()
    timer.Simple(0, function()
        lib.RespawnPlacedContainers()
        broadcast()
    end)
end)

hook.Add("PostCleanupMap", "ZScavWorldLoot_RebuildAfterCleanup", function()
    timer.Simple(0, function()
        lib.RespawnPlacedContainers()
        broadcast()
    end)
end)

hook.Add("ZB_PreRoundStart", "ZScavWorldLoot_ReapplyRuntimeState", function()
    timer.Simple(0, function()
        reapplyRuntimeCatalog()
        lib.RespawnPlacedContainers()
        broadcast()
    end)
end)

hook.Add("PlayerInitialSpawn", "ZScavWorldLoot_SyncNewPlayer", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then
            broadcast(ply)
        end
    end)
end)

hook.Add("PlayerSpawnedProp", "ZScavWorldLoot_AutoAdoptSpawnedProp", function(_ply, _model, ent)
    if not IsValid(ent) then return end

    queueCatalogPropAdoption(ent, 0)
end)

hook.Add("OnEntityCreated", "ZScavWorldLoot_AutoAdoptSpawnedPropFallback", function(ent)
    if not isCatalogConvertibleProp(ent) then return end

    queueCatalogPropAdoption(ent, 0.1)
end)

local function openMenu(ply, focus)
    if not canEdit(ply) then return end

    broadcast(ply)

    net.Start(lib.Net.Open)
        net.WriteString(util.TableToJSON(istable(focus) and focus or {}, false) or "{}")
    net.Send(ply)
end

local function openMenuFromArgs(ply, args)
    if not IsValid(ply) then
        print("[ZScav] zscav_loot_gui is only available to connected admins.")
        return false
    end

    if not canEdit(ply) then
        notice(ply, "Admin access required.")
        return false
    end

    local focus = {}
    local page = string.Trim(tostring(args[1] or ""))
    if page == "placed" or page == "model" or page == "valuable" then
        focus.page = page
    end

    local model = lib.NormalizeModel(args[2] or "")
    if model ~= "" then
        focus.model = model
    end

    openMenu(ply, focus)
    return true
end

concommand.Add("zscav_loot_gui", function(ply, _cmd, args)
    openMenuFromArgs(ply, args)
end)

concommand.Add("zscav_loot_menu", function(ply, _cmd, args)
    openMenuFromArgs(ply, args)
end)

concommand.Add("zc_loot_gui", function(ply, _cmd, args)
    openMenuFromArgs(ply, args)
end)

hook.Add("PlayerSay", "ZScavWorldLoot_ChatShortcut", function(ply, text)
    local message = string.lower(string.Trim(tostring(text or "")))
    if message == "!zloot" or message == "/zloot"
        or message == "!lootgui" or message == "/lootgui"
        or message == "!zlootgui" or message == "/zlootgui" then
        if openMenuFromArgs(ply, {}) then
            return ""
        end
    end
end)