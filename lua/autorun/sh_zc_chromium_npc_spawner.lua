AddCSLuaFile()

ZC_ChromiumNPCSpawner = ZC_ChromiumNPCSpawner or {}

local Bridge = ZC_ChromiumNPCSpawner
local ENTITY_CLASS = "zc_chromium_npc_spawner"
local DATA_ROOT = "zcity"
local DATA_PARENT_DIR = "zcity/sequence_helper"
local DATA_DIR = "zcity/sequence_helper/chromium_npc_spawners"
local THINK_INTERVAL = 0.1
local DEFAULT_NPC_BOX = 34
local DEFAULT_HEIGHT_PADDING = 64
local POST_TRACE_OFFSET = Vector(0, 0, 512)
local ANGLE_ZERO = Angle(0, 0, 0)
local VECTOR_ZERO = Vector(0, 0, 0)

local NPC_BOXES = {
    ["_def"] = 34,
    ["Antlion"] = 48,
    ["Antlion Worker"] = 48,
    ["Antlion Guard"] = 96,
    ["Antlion Guardian"] = 96,
    ["Strider"] = 140,
    ["Turret"] = 50,
    ["City Scanner"] = 24,
    ["Shield Scanner"] = 24,
    ["Manhack"] = 24,
    ["Hunter-Chopper"] = 140,
    ["Combine Dropship"] = 144,
    ["Combine Gunship"] = 144,
}

local CEILING_NPCS = {
    Barnacle = true,
    Camera = true,
    ["Ceiling Turret"] = true,
}

local npcCatalogByCategory
local npcCatalogByClass

local function trimString(value)
    return string.Trim(tostring(value or ""))
end

local function lowerString(value)
    return string.lower(trimString(value))
end

local function emptyToNil(value)
    local text = trimString(value)
    if text == "" then return nil end
    return text
end

local function toNumber(value, defaultValue)
    local numberValue = tonumber(value)
    if numberValue == nil then return defaultValue end
    return numberValue
end

local function toBool(value, defaultValue)
    if value == nil then
        return defaultValue == true
    end

    if isbool(value) then
        return value
    end

    if isnumber(value) then
        return value ~= 0
    end

    local lowered = lowerString(value)
    if lowered == "1" or lowered == "true" or lowered == "yes" or lowered == "on" then
        return true
    end

    if lowered == "0" or lowered == "false" or lowered == "no" or lowered == "off" or lowered == "" then
        return false
    end

    return defaultValue == true
end

local function toVector(value)
    if isvector(value) then
        return Vector(value.x, value.y, value.z)
    end

    if istable(value) then
        return Vector(
            tonumber(value.x or value[1]) or 0,
            tonumber(value.y or value[2]) or 0,
            tonumber(value.z or value[3]) or 0
        )
    end

    return Vector(VECTOR_ZERO.x, VECTOR_ZERO.y, VECTOR_ZERO.z)
end

local function toAngle(value)
    if isangle(value) then
        return Angle(value.p, value.y, value.r)
    end

    if istable(value) then
        return Angle(
            tonumber(value.p or value[1]) or 0,
            tonumber(value.y or value[2]) or 0,
            tonumber(value.r or value[3]) or 0
        )
    end

    return Angle(ANGLE_ZERO.p, ANGLE_ZERO.y, ANGLE_ZERO.r)
end

local function copyVector(vec)
    return Vector(vec.x, vec.y, vec.z)
end

local function mergeBounds(mins, maxs, extraMins, extraMaxs)
    if not mins or not maxs then
        return copyVector(extraMins), copyVector(extraMaxs)
    end

    return Vector(
        math.min(mins.x, extraMins.x),
        math.min(mins.y, extraMins.y),
        math.min(mins.z, extraMins.z)
    ), Vector(
        math.max(maxs.x, extraMaxs.x),
        math.max(maxs.y, extraMaxs.y),
        math.max(maxs.z, extraMaxs.z)
    )
end

local function ensureDataDirs()
    if not SERVER then return end
    file.CreateDir(DATA_ROOT)
    file.CreateDir(DATA_PARENT_DIR)
    file.CreateDir(DATA_DIR)
end

local function getDataPath()
    return string.format("%s/%s.json", DATA_DIR, game.GetMap() or "unknown")
end

local function getNPCPerTick()
    local cvar = GetConVar and GetConVar("ct_npc_tick") or nil
    local perTick = cvar and cvar:GetInt() or 1
    return math.Clamp(perTick, 1, 100)
end

local function ensureNPCCatalog()
    if npcCatalogByCategory and npcCatalogByClass then return end

    npcCatalogByCategory = {}
    npcCatalogByClass = {}

    local npcList = list.Get("NPC") or {}
    for _, npcData in pairs(npcList) do
        local category = trimString(npcData.Category or "Other")
        local name = trimString(npcData.Name)
        local className = trimString(npcData.Class)

        if category ~= "" and name ~= "" then
            npcCatalogByCategory[category] = npcCatalogByCategory[category] or {}
            npcCatalogByCategory[category][name] = npcData
        end

        if className ~= "" then
            npcCatalogByClass[lowerString(className)] = npcData
        end
    end
end

local function getNPCBox(areaDefinition, npcData)
    local candidates = {
        trimString(areaDefinition.class),
        trimString(areaDefinition.npcName),
        npcData and trimString(npcData.Name) or "",
    }

    for _, candidate in ipairs(candidates) do
        if candidate ~= "" and NPC_BOXES[candidate] then
            return NPC_BOXES[candidate]
        end
    end

    return NPC_BOXES._def or DEFAULT_NPC_BOX
end

local function resolveNPCData(areaDefinition)
    ensureNPCCatalog()

    local npcClass = emptyToNil(areaDefinition.npcClass or areaDefinition.npcEntityClass or areaDefinition.npc_entity_class)
    if npcClass then
        local resolved = npcCatalogByClass[lowerString(npcClass)] and table.Copy(npcCatalogByClass[lowerString(npcClass)]) or {
            Class = npcClass,
            Name = npcClass,
            Category = emptyToNil(areaDefinition.npccat) or "Custom",
        }

        resolved.Class = npcClass
        resolved.Name = emptyToNil(areaDefinition.npcName or areaDefinition.class) or resolved.Name or npcClass
        resolved.Category = emptyToNil(areaDefinition.npccat) or resolved.Category or "Custom"
        return resolved
    end

    local category = emptyToNil(areaDefinition.npccat)
    local displayName = emptyToNil(areaDefinition.class or areaDefinition.npcName)
    if displayName == nil then return nil end

    if category and npcCatalogByCategory[category] and npcCatalogByCategory[category][displayName] then
        return table.Copy(npcCatalogByCategory[category][displayName])
    end

    for _, categoryEntries in pairs(npcCatalogByCategory) do
        if categoryEntries[displayName] then
            return table.Copy(categoryEntries[displayName])
        end
    end

    return nil
end

local function buildAreaBounds(posStart, maxZ, cellSize, byX, byY, ssx, ssy)
    local endX = posStart.x + cellSize * byX * ssx
    local endY = posStart.y + cellSize * byY * ssy

    return Vector(
        math.min(posStart.x, endX),
        math.min(posStart.y, endY),
        math.min(posStart.z, maxZ)
    ), Vector(
        math.max(posStart.x, endX),
        math.max(posStart.y, endY),
        math.max(posStart.z, maxZ) + DEFAULT_HEIGHT_PADDING
    )
end

local function cloneAreaGrid(area)
    local grid = {}

    for x = 1, area.byX do
        for y = 1, area.byY do
            grid[#grid + 1] = {
                area.posStart.x + x * area.abs * area.ssx,
                area.posStart.y + y * area.abs * area.ssy,
                area.posStart.x + (x - 1) * area.abs * area.ssx,
                area.posStart.y + (y - 1) * area.abs * area.ssy,
            }
        end
    end

    return grid
end

local function normalizeArea(areaDefinition, areaIndex)
    if not istable(areaDefinition) then return nil end

    local npcData = resolveNPCData(areaDefinition)
    if not npcData or trimString(npcData.Class) == "" then
        return nil
    end

    local posStart = toVector(areaDefinition.pos_start or areaDefinition.posStart)
    local posEnd = nil
    if areaDefinition.pos_end ~= nil or areaDefinition.posEnd ~= nil then
        posEnd = toVector(areaDefinition.pos_end or areaDefinition.posEnd)
    end

    local cellSize = toNumber(areaDefinition.abs, 0)
    if cellSize <= 0 then
        local spread = toNumber(areaDefinition.spread, 0)
        if spread > 0 then
            cellSize = getNPCBox(areaDefinition, npcData) * math.Clamp(spread, 10, 1000) / 10
        end
    end
    if cellSize <= 0 then
        cellSize = DEFAULT_NPC_BOX
    end

    local byX = math.floor(toNumber(areaDefinition.by_x or areaDefinition.byX, 0))
    local byY = math.floor(toNumber(areaDefinition.by_y or areaDefinition.byY, 0))
    local ssx = toNumber(areaDefinition.ssx, 0)
    local ssy = toNumber(areaDefinition.ssy, 0)
    local maxZ = toNumber(areaDefinition.maxz, posStart.z)

    if byX < 1 or byY < 1 then
        if not isvector(posEnd) then return nil end

        local delta = posEnd - posStart
        byX = math.floor(math.abs(delta.x) / cellSize)
        byY = math.floor(math.abs(delta.y) / cellSize)
        ssx = delta.x >= 0 and 1 or -1
        ssy = delta.y >= 0 and 1 or -1
        maxZ = math.max(posStart.z, posEnd.z)
    end

    if byX < 1 or byY < 1 then
        return nil
    end

    ssx = ssx >= 0 and 1 or -1
    ssy = ssy >= 0 and 1 or -1

    local randomDistance = math.max(toNumber(areaDefinition.random, 0), 0)
    if randomDistance == 0 and areaDefinition.randomPercent ~= nil then
        randomDistance = math.max((cellSize - getNPCBox(areaDefinition, npcData) / 2) / 2, 0) * math.Clamp(toNumber(areaDefinition.randomPercent, 0), 0, 100) / 100
    end

    local smMethod = math.Clamp(math.floor(toNumber(areaDefinition.sm_method or areaDefinition.smMethod, 1)), 1, 3)
    local mins, maxs = buildAreaBounds(posStart, maxZ, cellSize, byX, byY, ssx, ssy)

    return {
        id = emptyToNil(areaDefinition.id) or string.format("area_%d", areaIndex),
        label = emptyToNil(areaDefinition.label or areaDefinition.name) or trimString(npcData.Name or npcData.Class),
        npcData = npcData,
        posStart = posStart,
        maxZ = maxZ,
        abs = cellSize,
        byX = byX,
        byY = byY,
        byCount = byX * byY,
        ssx = ssx,
        ssy = ssy,
        random = randomDistance,
        angle = toAngle(areaDefinition.angle),
        flags = math.max(math.floor(toNumber(areaDefinition.flags, 0)), 0),
        equip = emptyToNil(areaDefinition.equip),
        model = emptyToNil(areaDefinition.model),
        skin = math.max(math.floor(toNumber(areaDefinition.skin, 0)), 0),
        prof = math.floor(toNumber(areaDefinition.prof or areaDefinition.wepprof, 8)),
        ignoreply = toBool(areaDefinition.ignoreply, false),
        ignoreplys = toBool(areaDefinition.ignoreplys, false),
        immobile = toBool(areaDefinition.immobile, false),
        squad = emptyToNil(areaDefinition.squad),
        hp = math.max(toNumber(areaDefinition.hp, 0), 0),
        maxhp = math.max(toNumber(areaDefinition.maxhp, 0), 0),
        smMethod = smMethod,
        smRemoval = toBool(areaDefinition.sm_removal, true),
        smRespDelay = math.max(toNumber(areaDefinition.sm_respdelay, 0), 0),
        smAlive = math.max(math.floor(toNumber(areaDefinition.sm_alive, 0)), 0),
        smTotal = math.max(math.floor(toNumber(areaDefinition.sm_total, 0)), 0),
        smTimer = math.max(toNumber(areaDefinition.sm_timer, 0), 0),
        smRandom = toBool(areaDefinition.sm_random, true),
        mins = mins,
        maxs = maxs,
        isCeilingNPC = CEILING_NPCS[trimString(areaDefinition.class)] == true or CEILING_NPCS[trimString(npcData.Name or "")] == true,
    }
end

local function normalizePreset(definition)
    if not istable(definition) then return nil end

    local name = emptyToNil(definition.name or definition.targetName or definition.id)
    if name == nil then return nil end

    local rawAreas = {}
    if istable(definition.areas) then
        if definition.areas[1] ~= nil then
            rawAreas = definition.areas
        else
            for _, areaDefinition in pairs(definition.areas) do
                rawAreas[#rawAreas + 1] = areaDefinition
            end
        end
    else
        rawAreas[1] = definition
    end

    local areas = {}
    local mins
    local maxs

    for areaIndex, areaDefinition in ipairs(rawAreas) do
        local area = normalizeArea(areaDefinition, areaIndex)
        if not area then continue end

        areas[#areas + 1] = area
        mins, maxs = mergeBounds(mins, maxs, area.mins, area.maxs)
    end

    if #areas == 0 or not mins or not maxs then
        return nil
    end

    return {
        name = name,
        areas = areas,
        mins = mins,
        maxs = maxs,
        origin = Vector(
            (mins.x + maxs.x) * 0.5,
            (mins.y + maxs.y) * 0.5,
            (mins.z + maxs.z) * 0.5
        ),
        enabled = toBool(definition.enabled, true),
        autoStart = toBool(definition.autoStart, false),
    }
end

local function readDiskDefinitions()
    ensureDataDirs()

    local raw = file.Read(getDataPath(), "DATA") or ""
    if trimString(raw) == "" then
        return {}
    end

    local parsed = util.JSONToTable(raw)
    if not istable(parsed) then
        return {}
    end

    return parsed
end

local function mergeDefinitionCollection(out, definitions)
    if not istable(definitions) then return end

    if definitions[1] ~= nil then
        for _, definition in ipairs(definitions) do
            if not istable(definition) then continue end

            local copy = table.Copy(definition)
            local name = emptyToNil(copy.name or copy.targetName or copy.id)
            if name == nil then continue end

            copy.name = name
            out[name] = copy
        end

        return
    end

    for key, definition in pairs(definitions) do
        if not istable(definition) then continue end

        local copy = table.Copy(definition)
        copy.name = emptyToNil(copy.name) or trimString(key)
        if emptyToNil(copy.name) == nil then continue end

        out[copy.name] = copy
    end
end

local function sortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function requestAliveLimit(request)
    if request.area.smMethod == 1 then
        return request.area.byCount
    end

    if request.area.smAlive > 0 then
        return request.area.smAlive
    end

    return request.area.byCount
end

local function applyNPCSetup(npc, request, spawnPos)
    local area = request.area
    local npcData = area.npcData
    local offset = Vector(0, 0, tonumber(npcData.Offset) or 32)

    npc:SetPos(spawnPos + offset)
    npc:SetAngles(area.angle or ANGLE_ZERO)

    local spawnFlags = area.flags
    if npcData.SpawnFlags then
        spawnFlags = bit.bor(spawnFlags, npcData.SpawnFlags)
    end
    if npcData.TotalSpawnFlags then
        spawnFlags = npcData.TotalSpawnFlags
    end
    npc:SetKeyValue("spawnflags", spawnFlags)
    npc.SpawnFlags = spawnFlags

    if istable(npcData.KeyValues) then
        for key, value in pairs(npcData.KeyValues) do
            npc:SetKeyValue(key, value)
        end
    end

    if area.squad then
        npc:SetKeyValue("SquadName", area.squad)
        npc:Fire("setsquad", area.squad)
    end

    if npcData.Model then
        npc:SetModel(npcData.Model)
    end
    if area.model and util.IsValidModel(area.model) then
        npc:SetModel(area.model)
    end

    if npcData.Material then
        npc:SetMaterial(npcData.Material)
    end

    if area.equip == "_def" then
        if istable(npcData.Weapons) and #npcData.Weapons > 0 then
            npc:SetKeyValue("additionalequipment", npcData.Weapons[math.random(#npcData.Weapons)])
        end
    elseif area.equip then
        npc:SetKeyValue("additionalequipment", area.equip)
    end

    npc:Spawn()
    npc:Activate()

    if npcData.Skin then
        npc:SetSkin(npcData.Skin)
    end

    if area.skin == 1 and npc.SkinCount then
        local skinCount = npc:SkinCount()
        if skinCount > 0 then
            npc:SetSkin(math.random(1, skinCount) - 1)
        end
    elseif area.skin > 1 then
        npc:SetSkin(area.skin - 1)
    end

    if istable(npcData.BodyGroups) then
        for bodygroupId, bodygroupValue in pairs(npcData.BodyGroups) do
            npc:SetBodygroup(bodygroupId, bodygroupValue)
        end
    end

    local prof = area.prof
    if prof == 5 then
        prof = math.random(0, 4)
    elseif prof == 6 then
        prof = math.random(2, 4)
    elseif prof == 7 then
        prof = math.random(0, 2)
    elseif prof == 8 then
        prof = nil
    end
    if prof and npc.SetCurrentWeaponProficiency then
        npc:SetCurrentWeaponProficiency(prof)
    end

    if area.ignoreply and IsValid(request.activator) and request.activator:IsPlayer() and npc.AddEntityRelationship then
        npc:AddEntityRelationship(request.activator, D_LI, 99)
    end
    if area.ignoreplys and npc.AddRelationship then
        npc:AddRelationship("player D_LI 99")
    end

    if area.immobile and npc.CapabilitiesRemove then
        npc:CapabilitiesRemove(CAP_MOVE_GROUND)
        npc:CapabilitiesRemove(CAP_MOVE_FLY)
        npc:CapabilitiesRemove(CAP_MOVE_CLIMB)
        npc:CapabilitiesRemove(CAP_MOVE_SWIM)
    end

    if area.maxhp > 0 then
        npc:SetMaxHealth(area.maxhp)
    end
    if area.hp > 0 then
        npc:SetHealth(area.hp)
    elseif npcData.Health then
        npc:SetHealth(npcData.Health)
    end

    if IsValid(request.activator) and request.activator:IsPlayer() and npc.SetCreator then
        npc:SetCreator(request.activator)
    end
end

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Chromium NPC Spawner"
ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:UpdateTransmitState()
    return TRANSMIT_NEVER
end

function ENT:Draw()
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
        self:SetNoDraw(true)
        self:DrawShadow(false)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetNotSolid(true)
        self:SetCollisionBounds(Vector(-16, -16, -16), Vector(16, 16, 16))

        self.ActiveRequests = {}
        self.RequestCounter = 0
        self.RequestCursor = 0
        self.PersistentEnabled = false
        self.Disabled = false
    end

    function ENT:ConfigurePreset(preset)
        self.Preset = table.Copy(preset)
        self.Disabled = preset.enabled == false

        self:SetPos(preset.origin)
        self:SetAngles(ANGLE_ZERO)
        self:SetCollisionBounds(preset.mins - preset.origin, preset.maxs - preset.origin)
        self:SetKeyValue("targetname", preset.name)
        if self.SetName then
            self:SetName(preset.name)
        end

        if preset.autoStart and not self.Disabled then
            self:StartPreset(true, nil, nil, false)
        end
    end

    function ENT:HasActiveRequests()
        return istable(self.ActiveRequests) and #self.ActiveRequests > 0
    end

    function ENT:RefreshPersistentEnabledState()
        self.PersistentEnabled = false

        for _, request in ipairs(self.ActiveRequests or {}) do
            if request.persistent then
                self.PersistentEnabled = true
                return
            end
        end
    end

    function ENT:BuildRequest(area, activator, caller, persistent)
        self.RequestCounter = self.RequestCounter + 1

        local owner = IsValid(activator) and activator or (IsValid(caller) and caller or nil)
        local totalRemaining = nil
        if area.smMethod == 2 then
            totalRemaining = area.smTotal ~= 0 and area.smTotal or math.huge
        end

        local stopAt = nil
        if area.smMethod == 3 then
            stopAt = area.smTimer < 1 and math.huge or (CurTime() + area.smTimer)
        end

        return {
            id = self.RequestCounter,
            area = area,
            activator = owner,
            persistent = persistent == true,
            count = 0,
            totalRemaining = totalRemaining,
            stopAt = stopAt,
            grid = cloneAreaGrid(area),
            spawned = {},
        }
    end

    function ENT:StartPreset(persistent, activator, caller, ignoreDisabled)
        if not self.Preset then return 0 end
        if self.Disabled and not ignoreDisabled then return 0 end
        if persistent and self.PersistentEnabled then return 0 end

        local created = 0
        for _, area in ipairs(self.Preset.areas) do
            self.ActiveRequests[#self.ActiveRequests + 1] = self:BuildRequest(area, activator, caller, persistent)
            created = created + 1
        end

        if persistent and created > 0 then
            self.PersistentEnabled = true
        end

        return created
    end

    function ENT:FindRequest(requestId)
        for index, request in ipairs(self.ActiveRequests or {}) do
            if request.id == requestId then
                return index, request
            end
        end
    end

    function ENT:RemoveRequest(index)
        if not self.ActiveRequests[index] then return end

        table.remove(self.ActiveRequests, index)
        if self.RequestCursor > #self.ActiveRequests then
            self.RequestCursor = 0
        end
        self:RefreshPersistentEnabledState()
    end

    function ENT:IsRequestExpired(request, now)
        if #request.grid < 1 and request.count < 1 then
            return true
        end

        if request.area.smMethod == 1 then
            return #request.grid < 1 and request.count < 1
        end

        if request.area.smMethod == 2 then
            return request.totalRemaining ~= nil and request.totalRemaining < 1 and request.count < 1
        end

        if request.area.smMethod == 3 then
            return request.stopAt ~= nil and request.stopAt <= now and request.count < 1
        end

        return false
    end

    function ENT:GetSpawnCell(request, now)
        local available = {}

        for index, cell in ipairs(request.grid) do
            if request.area.smMethod ~= 1 and IsValid(cell.npc) then
                continue
            end

            if request.area.smRespDelay > 0 and cell.npc ~= nil then
                if not cell.delay then
                    cell.delay = now + request.area.smRespDelay
                    continue
                end

                if now < cell.delay then
                    continue
                end
            end

            available[#available + 1] = index
        end

        if #available == 0 then
            return nil
        end

        if request.area.smRandom then
            return available[math.random(#available)]
        end

        return available[#available]
    end

    function ENT:CalculateSpawnPos(request, cellIndex)
        local cell = request.grid[cellIndex]
        if not cell then return nil end

        local area = request.area
        local x = math.Round((cell[1] + cell[3]) * 0.5 + math.random(-area.random, area.random))
        local y = math.Round((cell[2] + cell[4]) * 0.5 + math.random(-area.random, area.random))
        local gridPos = Vector(x, y, area.maxZ)

        local tr1 = util.TraceLine({
            start = gridPos,
            endpos = gridPos + POST_TRACE_OFFSET,
        })
        if tr1.StartSolid then
            table.remove(request.grid, cellIndex)
            return nil
        end

        if area.isCeilingNPC then
            if IsValid(tr1.HitEntity) and tr1.HitEntity:IsNPC() then
                return nil
            end

            if not tr1.Hit then
                table.remove(request.grid, cellIndex)
                return nil
            end

            return tr1.HitPos
        end

        local tr2 = util.TraceLine({
            start = tr1.HitPos,
            endpos = tr1.HitPos - POST_TRACE_OFFSET * 2,
        })
        if IsValid(tr2.HitEntity) and tr2.HitEntity:IsNPC() then
            return nil
        end

        return tr2.HitPos
    end

    function ENT:SpawnRequestNPC(request, cellIndex)
        local spawnPos = self:CalculateSpawnPos(request, cellIndex)
        if not spawnPos then
            return false
        end

        local npc = ents.Create(request.area.npcData.Class)
        if not IsValid(npc) then
            return nil
        end

        if request.area.smMethod == 1 then
            table.remove(request.grid, cellIndex)
        else
            request.grid[cellIndex].npc = npc
            request.grid[cellIndex].delay = nil
        end

        request.spawned[#request.spawned + 1] = npc
        npc.ZCChromiumSpawnerOwner = self
        npc.ZCChromiumSpawnerRequestId = request.id

        applyNPCSetup(npc, request, spawnPos)

        if request.area.smMethod == 2 and request.totalRemaining ~= nil and request.totalRemaining ~= math.huge then
            request.totalRemaining = request.totalRemaining - 1
        end

        request.count = request.count + 1
        return true
    end

    function ENT:GetNextRunnableRequest(now)
        local total = #self.ActiveRequests
        if total == 0 then return nil end

        for offset = 1, total do
            local index = ((self.RequestCursor + offset - 1) % total) + 1
            local request = self.ActiveRequests[index]
            if not request then continue end

            local canSpawn = #request.grid > 0
            if canSpawn and request.area.smMethod ~= 1 then
                canSpawn = request.count < requestAliveLimit(request)
            end
            if canSpawn and request.area.smMethod == 2 and request.totalRemaining ~= nil and request.totalRemaining < 1 then
                canSpawn = false
            end
            if canSpawn and request.area.smMethod == 3 and request.stopAt ~= nil and request.stopAt <= now then
                canSpawn = false
            end

            if canSpawn then
                self.RequestCursor = index
                return request, index
            end
        end

        return nil
    end

    function ENT:RunSpawnerThink(now)
        for index = #self.ActiveRequests, 1, -1 do
            if self:IsRequestExpired(self.ActiveRequests[index], now) then
                self:RemoveRequest(index)
            end
        end

        if #self.ActiveRequests == 0 then
            return
        end

        local quota = getNPCPerTick()
        local idlePasses = 0

        while quota > 0 do
            local request, requestIndex = self:GetNextRunnableRequest(now)
            if not request then
                break
            end

            local cellIndex = self:GetSpawnCell(request, now)
            if not cellIndex then
                idlePasses = idlePasses + 1
                if idlePasses >= #self.ActiveRequests then
                    break
                end
            else
                idlePasses = 0
                local result = self:SpawnRequestNPC(request, cellIndex)
                if result == nil then
                    self:RemoveRequest(requestIndex)
                elseif result then
                    quota = quota - 1
                end
            end

            local currentIndex, currentRequest = self:FindRequest(request.id)
            if currentIndex and currentRequest and self:IsRequestExpired(currentRequest, now) then
                self:RemoveRequest(currentIndex)
            end
        end
    end

    function ENT:HandleSpawnedNPCRemoved(npc)
        local requestIndex, request = self:FindRequest(npc.ZCChromiumSpawnerRequestId)
        if not request then return end

        request.count = math.max(request.count - 1, 0)

        if self:IsRequestExpired(request, CurTime()) then
            self:RemoveRequest(requestIndex)
        end
    end

    function ENT:StopRequests(removeSpawnedNPCs)
        if removeSpawnedNPCs then
            for _, request in ipairs(self.ActiveRequests or {}) do
                for _, npc in ipairs(request.spawned or {}) do
                    if not IsValid(npc) then continue end
                    npc.ZCChromiumSpawnerOwner = nil
                    npc.ZCChromiumSpawnerRequestId = nil
                    npc:Remove()
                end
            end
        end

        self.ActiveRequests = {}
        self.RequestCursor = 0
        self.PersistentEnabled = false
    end

    function ENT:AcceptInput(inputName, activator, caller, value)
        local normalizedInput = lowerString(inputName)

        if normalizedInput == "spawn" or normalizedInput == "trigger" then
            self:StartPreset(false, activator, caller, true)
            return true
        end

        if normalizedInput == "enable" then
            self.Disabled = false
            self:StartPreset(true, activator, caller, false)
            return true
        end

        if normalizedInput == "disable" then
            self.Disabled = true
            self:StopRequests(false)
            return true
        end

        if normalizedInput == "toggle" then
            if self.Disabled or not self.PersistentEnabled then
                self.Disabled = false
                self:StartPreset(true, activator, caller, false)
            else
                self.Disabled = true
                self:StopRequests(false)
            end
            return true
        end

        if normalizedInput == "kill" or normalizedInput == "cancel" or normalizedInput == "removechildren" then
            self.Disabled = true
            self:StopRequests(true)
            return true
        end

        if normalizedInput == "restart" then
            self.Disabled = false
            self:StopRequests(true)
            self:StartPreset(true, activator, caller, false)
            return true
        end

        if normalizedInput == "reload" and Bridge.Reload then
            Bridge.Reload()
            return true
        end

        return false
    end

    function ENT:Think()
        self:RunSpawnerThink(CurTime())
        self:NextThink(CurTime() + THINK_INTERVAL)
        return true
    end

    function ENT:OnRemove()
        self:StopRequests(false)

        if self.Preset and Bridge.Entities and Bridge.Entities[self.Preset.name] == self then
            Bridge.Entities[self.Preset.name] = nil
        end
    end
end

scripted_ents.Register(ENT, ENTITY_CLASS)

if CLIENT then
    return
end

Bridge.RegisteredDefinitions = Bridge.RegisteredDefinitions or {}
Bridge.ActivePresets = Bridge.ActivePresets or {}
Bridge.Entities = Bridge.Entities or {}
Bridge.Initialized = Bridge.Initialized or false

function Bridge.GetDataPath()
    return getDataPath()
end

function Bridge.RegisterPreset(definition)
    if not istable(definition) then return false end

    local copy = table.Copy(definition)
    local name = emptyToNil(copy.name or copy.targetName or copy.id)
    if name == nil then return false end

    copy.name = name
    Bridge.RegisteredDefinitions[name] = copy

    if Bridge.Initialized then
        Bridge.Reload()
    end

    return true
end

function Bridge.RegisterPresets(definitions)
    if not istable(definitions) then return false end

    local merged = {}
    mergeDefinitionCollection(merged, definitions)

    local changed = false
    for name, definition in pairs(merged) do
        Bridge.RegisteredDefinitions[name] = definition
        changed = true
    end

    if changed and Bridge.Initialized then
        Bridge.Reload()
    end

    return changed
end

function Bridge.GetLoadedPresets()
    return Bridge.ActivePresets
end

function Bridge.FireInput(name, inputName, activator, caller, value)
    local ent = Bridge.Entities[trimString(name)]
    if not IsValid(ent) then return false end

    return ent:AcceptInput(inputName or "Spawn", activator, caller, value)
end

local function clearEntities()
    for _, ent in pairs(Bridge.Entities or {}) do
        if IsValid(ent) then
            ent:Remove()
        end
    end

    Bridge.Entities = {}
    Bridge.ActivePresets = {}
end

local function spawnPresetEntity(preset)
    local ent = ents.Create(ENTITY_CLASS)
    if not IsValid(ent) then
        return nil
    end

    ent:SetPos(preset.origin)
    ent:SetAngles(ANGLE_ZERO)
    ent:SetKeyValue("targetname", preset.name)
    ent:Spawn()
    ent:Activate()
    ent:ConfigurePreset(preset)

    return ent
end

function Bridge.Reload()
    clearEntities()
    ensureNPCCatalog()

    local mergedDefinitions = {}
    mergeDefinitionCollection(mergedDefinitions, readDiskDefinitions())
    mergeDefinitionCollection(mergedDefinitions, Bridge.RegisteredDefinitions)

    local count = 0
    for _, name in ipairs(sortedKeys(mergedDefinitions)) do
        local preset = normalizePreset(mergedDefinitions[name])
        if not preset then continue end

        local ent = spawnPresetEntity(preset)
        if not IsValid(ent) then continue end

        Bridge.ActivePresets[name] = preset
        Bridge.Entities[name] = ent
        count = count + 1
    end

    return count
end

local function reportTo(ply, message)
    if IsValid(ply) then
        ply:ChatPrint(message)
        return
    end

    print(message)
end

concommand.Add("zc_chromium_spawner_reload", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local count = Bridge.Reload()
    reportTo(ply, string.format("[Chromium Spawner] Loaded %d preset(s) from %s", count, Bridge.GetDataPath()))
end)

concommand.Add("zc_chromium_spawner_list", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local names = sortedKeys(Bridge.ActivePresets)
    if #names == 0 then
        reportTo(ply, string.format("[Chromium Spawner] No presets loaded from %s", Bridge.GetDataPath()))
        return
    end

    reportTo(ply, string.format("[Chromium Spawner] %d preset(s) loaded:", #names))
    for _, name in ipairs(names) do
        reportTo(ply, string.format(" - %s", name))
    end
end)

hook.Add("InitPostEntity", "ZC_ChromiumNPCSpawner_Load", function()
    Bridge.Initialized = true
    Bridge.Reload()
end)

hook.Add("PostCleanupMap", "ZC_ChromiumNPCSpawner_PostCleanup", function()
    timer.Simple(0, function()
        if not Bridge.Initialized then return end
        Bridge.Reload()
    end)
end)

hook.Add("EntityRemoved", "ZC_ChromiumNPCSpawner_Track", function(ent)
    local owner = ent.ZCChromiumSpawnerOwner
    if not IsValid(owner) or not owner.HandleSpawnedNPCRemoved then return end

    owner:HandleSpawnedNPCRemoved(ent)
end)