local TOOL_WEAPON_CLASS = "weapon_sequence_helper_tool"
local NET_REQUEST_DATA = "ZC_SequenceHelper_RequestData"
local NET_SEND_DATA = "ZC_SequenceHelper_SendData"
local NET_SAVE_DATA = "ZC_SequenceHelper_SaveData"
local NET_REQUEST_REFERENCES = "ZC_SequenceHelper_RequestReferences"
local NET_SEND_REFERENCES = "ZC_SequenceHelper_SendReferences"
local NET_REQUEST_REFERENCE_GRAPH = "ZC_SequenceHelper_RequestReferenceGraph"
local NET_SEND_REFERENCE_GRAPH = "ZC_SequenceHelper_SendReferenceGraph"
local NET_REQUEST_CHROMIUM_PRESETS = "ZC_SequenceHelper_RequestChromiumPresets"
local NET_SEND_CHROMIUM_PRESETS = "ZC_SequenceHelper_SendChromiumPresets"
local NET_STATUS = "ZC_SequenceHelper_Status"
local NET_EDITOR_STATE = "ZC_SequenceHelper_EditorState"
local NET_TEST_STAGE = "ZC_SequenceHelper_TestStage"
local NET_ZONE_PROGRESS = "ZC_SequenceHelper_ZoneProgress"
local DATA_ROOT = "zcity"
local DATA_DIR = "zcity/sequence_helper"
local LEGACY_DATA_DIR = "zcity/alyx_standin_zones"
local THINK_INTERVAL = 0.1
local DEFAULT_HOLD_TIME = 3
local DEFAULT_INPUT = "Trigger"
local DEFAULT_ZONE_ONCE = false
local DEFAULT_ZONE_ENABLED = true
local DEFAULT_ZONE_ALLOW_COMBINE = true
local DEFAULT_ZONE_ALLOW_GORDON = true
local DEFAULT_ZONE_REMEMBER_STAGE = true

local CLIENT_BROWSER_COMMAND = "zc_sequence_helper_browser"
local CLIENT_REFERENCES_COMMAND = "zc_sequence_helper_references"
local LEGACY_BROWSER_COMMAND = "zc_alyx_zone_browser"
local LEGACY_REFERENCES_COMMAND = "zc_alyx_zone_references"

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString(NET_REQUEST_DATA)
    util.AddNetworkString(NET_SEND_DATA)
    util.AddNetworkString(NET_SAVE_DATA)
    util.AddNetworkString(NET_REQUEST_REFERENCES)
    util.AddNetworkString(NET_SEND_REFERENCES)
    util.AddNetworkString(NET_REQUEST_REFERENCE_GRAPH)
    util.AddNetworkString(NET_SEND_REFERENCE_GRAPH)
    util.AddNetworkString(NET_REQUEST_CHROMIUM_PRESETS)
    util.AddNetworkString(NET_SEND_CHROMIUM_PRESETS)
    util.AddNetworkString(NET_STATUS)
    util.AddNetworkString(NET_EDITOR_STATE)
    util.AddNetworkString(NET_TEST_STAGE)
    util.AddNetworkString(NET_ZONE_PROGRESS)
end

ZC_SequenceHelper = ZC_SequenceHelper or ZC_AlyxStandinZones or {}
ZC_AlyxStandinZones = ZC_SequenceHelper

local BLOCKED_CLASSES = {
    combine = true,
    metrocop = true,
}

local REFERENCE_INCLUDE_CLASSES = {
    ai_script_conditions = true,
    ambient_generic = true,
    env_message = true,
    func_door = true,
    func_door_rotating = true,
    game_text = true,
    npc_maker = true,
    npc_template_maker = true,
    prop_door_rotating = true,
    trigger_multiple = true,
    trigger_once = true,
    zc_chromium_npc_spawner = true,
}

local REFERENCE_INPUT_HINTS = {
    ai_script_conditions = "Enable",
    ambient_generic = "PlaySound",
    env_message = "ShowMessage",
    func_door = "Open",
    func_door_rotating = "Open",
    game_text = "Display",
    logic_auto = "Trigger",
    logic_case = "PickRandom",
    logic_relay = "Trigger",
    logic_timer = "Enable",
    npc_maker = "Spawn",
    npc_template_maker = "ForceSpawn",
    prop_door_rotating = "Open",
    trigger_multiple = "Trigger",
    trigger_once = "Trigger",
    zc_chromium_npc_spawner = "Spawn",
}

local DOOR_REFERENCE_CLASSES = {
    func_door = true,
    func_door_rotating = true,
    prop_door_rotating = true,
}

local function trimString(value)
    return string.Trim(tostring(value or ""))
end

local function boolOrDefault(value, defaultValue)
    if value == nil then
        return defaultValue == true
    end

    return value == true
end

local function normalizeClassName(name)
    local key = string.lower(trimString(name))

    if key == "freeman" then return "gordon" end
    if key == "overwatch" then return "combine" end
    if key == "metropolice" or key == "civilprotection" or key == "civil_protection" then
        return "metrocop"
    end

    return key
end

local function vectorToTable(vec)
    return {
        x = tonumber(vec.x) or 0,
        y = tonumber(vec.y) or 0,
        z = tonumber(vec.z) or 0,
    }
end

local function tableToVector(data)
    if isvector(data) then
        return Vector(data.x, data.y, data.z)
    end

    if istable(data) then
        return Vector(tonumber(data.x) or 0, tonumber(data.y) or 0, tonumber(data.z) or 0)
    end

    return Vector(0, 0, 0)
end

local function angleToTable(ang)
    return {
        p = tonumber(ang.p) or 0,
        y = tonumber(ang.y) or 0,
        r = tonumber(ang.r) or 0,
    }
end

local function tableToAngle(data)
    if isangle(data) then
        return Angle(data.p, data.y, data.r)
    end

    if istable(data) then
        return Angle(tonumber(data.p) or 0, tonumber(data.y) or 0, tonumber(data.r) or 0)
    end

    return angle_zero
end

local function orderedBounds(first, second)
    local mins = Vector(
        math.min(first.x, second.x),
        math.min(first.y, second.y),
        math.min(first.z, second.z)
    )
    local maxs = Vector(
        math.max(first.x, second.x),
        math.max(first.y, second.y),
        math.max(first.z, second.z)
    )

    return mins, maxs
end

local function splitTargetNames(raw)
    local out = {}
    for part in string.gmatch(tostring(raw or ""), "[^,;\n]+") do
        local name = trimString(part)
        if name ~= "" then
            out[#out + 1] = name
        end
    end
    return out
end

local function startsWith(text, prefix)
    return string.sub(text, 1, #prefix) == prefix
end

local function zoneDataPath()
    return string.format("%s/%s.json", DATA_DIR, string.lower(game.GetMap() or "unknown"))
end

local function zoneBackupPath()
    return string.format("%s/%s.bak.json", DATA_DIR, string.lower(game.GetMap() or "unknown"))
end

local function legacyZoneDataPath()
    return string.format("%s/%s.json", LEGACY_DATA_DIR, string.lower(game.GetMap() or "unknown"))
end

local function legacyZoneBackupPath()
    return string.format("%s/%s.bak.json", LEGACY_DATA_DIR, string.lower(game.GetMap() or "unknown"))
end

local function normalizeStageOutput(raw)
    raw = istable(raw) and raw or {}

    local inputName = trimString(raw.inputName or raw.input)
    if inputName == "" then
        inputName = DEFAULT_INPUT
    end

    return {
        targetName = trimString(raw.targetName or raw.target),
        inputName = inputName,
        parameter = trimString(raw.parameter or raw.param),
        delay = math.Clamp(tonumber(raw.delay) or 0, 0, 60),
    }
end

local function stageOutputList(raw)
    local outputs = {}

    if istable(raw) and istable(raw.outputs) then
        for _, output in ipairs(raw.outputs) do
            outputs[#outputs + 1] = normalizeStageOutput(output)
        end
    end

    if #outputs == 0 then
        outputs[1] = normalizeStageOutput(raw)
    end

    return outputs
end

local function normalizeStage(raw, fallbackHoldTime)
    raw = istable(raw) and raw or {}
    local outputs = stageOutputList(raw)
    local primaryOutput = outputs[1] or normalizeStageOutput(nil)

    return {
        holdTime = math.Clamp(tonumber(raw.holdTime or raw.timer or raw.time) or fallbackHoldTime or DEFAULT_HOLD_TIME, 0, 600),
        targetName = primaryOutput.targetName,
        inputName = primaryOutput.inputName,
        parameter = primaryOutput.parameter,
        delay = primaryOutput.delay,
        outputs = outputs,
    }
end

local function copyStage(stage)
    return normalizeStage(stage, istable(stage) and stage.holdTime or DEFAULT_HOLD_TIME)
end

local function zoneStageList(zone)
    local stages = {}

    if istable(zone) and istable(zone.stages) then
        for _, stage in ipairs(zone.stages) do
            stages[#stages + 1] = copyStage(stage)
        end
    end

    if #stages == 0 then
        stages[1] = normalizeStage(zone, istable(zone) and zone.holdTime or DEFAULT_HOLD_TIME)
    end

    return stages
end

local function applyPrimaryStageFields(zone, stages)
    stages = istable(stages) and stages or zoneStageList(zone)
    if #stages == 0 then
        stages = { normalizeStage(zone, DEFAULT_HOLD_TIME) }
    end

    local primaryStage = stages[1]
    zone.stages = stages
    zone.holdTime = primaryStage.holdTime
    zone.targetName = primaryStage.targetName
    zone.inputName = primaryStage.inputName
    zone.parameter = primaryStage.parameter
    zone.delay = primaryStage.delay
    return zone
end

local function normalizeZone(raw, fallbackIndex)
    if not istable(raw) then return nil end

    local mins = tableToVector(raw.mins or raw.cornerA)
    local maxs = tableToVector(raw.maxs or raw.cornerB)
    mins, maxs = orderedBounds(mins, maxs)

    local name = trimString(raw.name)
    if name == "" then
        name = "Zone " .. tostring(fallbackIndex or 1)
    end

    local id = trimString(raw.id)
    if id == "" then
        id = string.format("zone_%s_%d", string.gsub(string.lower(name), "[^%w]+", "_"), fallbackIndex or 1)
    end

    local zone = {
        id = id,
        name = name,
        mins = mins,
        maxs = maxs,
        once = boolOrDefault(raw.once, DEFAULT_ZONE_ONCE),
        enabled = boolOrDefault(raw.enabled, DEFAULT_ZONE_ENABLED),
        allowCombinePlayers = boolOrDefault(raw.allowCombinePlayers, DEFAULT_ZONE_ALLOW_COMBINE),
        allowGordonSolo = boolOrDefault(raw.allowGordonSolo, DEFAULT_ZONE_ALLOW_GORDON),
        rememberStage = boolOrDefault(raw.rememberStage, DEFAULT_ZONE_REMEMBER_STAGE),
    }

    return applyPrimaryStageFields(zone, zoneStageList(raw))
end

local function serializeZone(zone)
    local stages = zoneStageList(zone)
    local primaryStage = stages[1]

    return {
        id = zone.id,
        name = zone.name,
        mins = vectorToTable(zone.mins),
        maxs = vectorToTable(zone.maxs),
        holdTime = primaryStage.holdTime,
        targetName = primaryStage.targetName,
        inputName = primaryStage.inputName,
        parameter = primaryStage.parameter,
        delay = primaryStage.delay,
        stages = stages,
        once = zone.once,
        enabled = zone.enabled,
        allowCombinePlayers = zone.allowCombinePlayers,
        allowGordonSolo = zone.allowGordonSolo,
        rememberStage = zone.rememberStage,
    }
end

if SERVER then
    if not ZC_IsPatchRebelPlayer then
        include("autorun/server/sv_patch_player_factions.lua")
    end

    local loadedZones = {}
    local zoneRuntime = {}
    local editorState = {}

    local function ensureDataDirs()
        if not file.IsDir(DATA_ROOT, "DATA") then
            file.CreateDir(DATA_ROOT)
        end

        if not file.IsDir(DATA_DIR, "DATA") then
            file.CreateDir(DATA_DIR)
        end
    end

    local function readZoneJson(path, backupPath)
        local raw = file.Exists(path, "DATA") and file.Read(path, "DATA") or ""
        if raw == "" or raw == "{}" then
            raw = file.Exists(backupPath, "DATA") and file.Read(backupPath, "DATA") or ""
        end

        return raw
    end

    local function canManageZones(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return false end
        if ply:IsSuperAdmin() or ply:IsAdmin() then return true end

        if COMMAND_GETACCES then
            local access = tonumber(COMMAND_GETACCES(ply)) or 0
            if access >= 1 then return true end
        end

        if ULib and ULib.ucl and ULib.ucl.query and ULib.ucl.query(ply, "ulx map") then
            return true
        end

        return false
    end

    local function canUseZoneTool(ply)
        if not canManageZones(ply) then return false end

        local activeWeapon = ply:GetActiveWeapon()
        return IsValid(activeWeapon) and activeWeapon:GetClass() == TOOL_WEAPON_CLASS
    end

    local function sendStatus(ply, msg)
        if not IsValid(ply) then return end

        net.Start(NET_STATUS)
            net.WriteString(tostring(msg or ""))
        net.Send(ply)
    end

    local function sendZoneProgress(ply, zoneId, payload)
        if not IsValid(ply) then return end

        net.Start(NET_ZONE_PROGRESS)
            net.WriteString(trimString(zoneId))
            net.WriteBool(istable(payload))
            if istable(payload) then
                net.WriteString(util.TableToJSON(payload, false) or "{}")
            end
        net.Send(ply)
    end

    local function syncZoneProgress(runtime, zoneId, recipients, payload)
        local nextRecipients = {}
        local recipientLookup = {}

        for _, ply in ipairs(recipients or {}) do
            if not IsValid(ply) then continue end
            recipientLookup[ply] = true
            nextRecipients[#nextRecipients + 1] = ply
            sendZoneProgress(ply, zoneId, payload)
        end

        for _, ply in ipairs(runtime.progressRecipients or {}) do
            if not IsValid(ply) or recipientLookup[ply] then continue end
            sendZoneProgress(ply, zoneId, nil)
        end

        runtime.progressRecipients = nextRecipients
    end

    local function stageTriggerOffset(stages, targetStageIndex)
        local total = 0

        for stageIndex = 1, math.min(tonumber(targetStageIndex) or 0, #stages) do
            total = total + math.max(0, tonumber(stages[stageIndex].holdTime) or 0)
        end

        return total
    end

    local function currentStageProgress(zone, stages, firedStages, startedAt, now)
        if not startedAt then return nil end

        local totalElapsed = math.max(0, now - startedAt)
        local previousOffset = 0

        for stageIndex, stage in ipairs(stages) do
            local duration = math.max(0, tonumber(stage.holdTime) or 0)
            local nextOffset = previousOffset + duration

            if not firedStages[stageIndex] then
                return {
                    zoneName = zone.name,
                    stageIndex = stageIndex,
                    stageCount = #stages,
                    duration = duration,
                    elapsed = math.Clamp(totalElapsed - previousOffset, 0, duration),
                    remaining = math.max(0, nextOffset - totalElapsed),
                }
            end

            previousOffset = nextOffset
        end

        return nil
    end

    local function getEditorState(ply)
        local state = editorState[ply]
        if state then return state end

        state = {
            cornerA = nil,
            cornerB = nil,
        }

        editorState[ply] = state
        return state
    end

    local function sendEditorState(ply)
        if not IsValid(ply) then return end

        local state = getEditorState(ply)
        net.Start(NET_EDITOR_STATE)
            net.WriteBool(isvector(state.cornerA))
            if isvector(state.cornerA) then
                net.WriteVector(state.cornerA)
            end
            net.WriteBool(isvector(state.cornerB))
            if isvector(state.cornerB) then
                net.WriteVector(state.cornerB)
            end
        net.Send(ply)
    end

    local function loadZonesFromDisk()
        ensureDataDirs()

        local raw = readZoneJson(zoneDataPath(), zoneBackupPath())
        if raw == "" or raw == "{}" then
            raw = readZoneJson(legacyZoneDataPath(), legacyZoneBackupPath())
        end

        local parsed = raw ~= "" and util.JSONToTable(raw) or nil
        if not istable(parsed) then
            loadedZones = {}
            zoneRuntime = {}
            return
        end

        local previousRuntime = zoneRuntime or {}
        loadedZones = {}
        zoneRuntime = {}

        for index, rawZone in ipairs(parsed) do
            local zone = normalizeZone(rawZone, index)
            if zone then
                loadedZones[#loadedZones + 1] = zone
                zoneRuntime[zone.id] = previousRuntime[zone.id] or {}
            end
        end
    end

    local function saveZonesToDisk(zones)
        ensureDataDirs()

        local serialized = {}
        for index, zone in ipairs(zones or {}) do
            local normalized = normalizeZone(zone, index)
            if normalized then
                serialized[#serialized + 1] = serializeZone(normalized)
            end
        end

        local json = util.TableToJSON(serialized, true) or "[]"
        file.Write(zoneDataPath(), json)
        file.Write(zoneBackupPath(), json)

        loadZonesFromDisk()
    end

    local function sendZoneData(ply)
        if not IsValid(ply) then return end

        local serialized = {}
        for index, zone in ipairs(loadedZones) do
            serialized[index] = serializeZone(zone)
        end

        net.Start(NET_SEND_DATA)
            net.WriteString(util.TableToJSON(serialized, true) or "[]")
            net.WriteString(zoneDataPath())
        net.Send(ply)

        sendEditorState(ply)
    end

    local function getReferenceName(ent)
        local name = trimString(ent.GetName and ent:GetName() or "")
        if name ~= "" then return name end

        if ent.GetInternalVariable then
            return trimString(ent:GetInternalVariable("targetname"))
        end

        return ""
    end

    local function getSuggestedInput(className)
        if REFERENCE_INPUT_HINTS[className] then
            return REFERENCE_INPUT_HINTS[className]
        end

        if startsWith(className, "logic_") then
            return DEFAULT_INPUT
        end

        return ""
    end

    local function shouldIncludeReference(className, targetName)
        if targetName == "" then return false end
        if startsWith(className, "logic_") then return true end
        return REFERENCE_INCLUDE_CLASSES[className] == true
    end

    local function collectReferenceEntries()
        local refs = {}
        local byKey = {}

        for _, ent in ipairs(ents.GetAll()) do
            if not IsValid(ent) then continue end

            local className = trimString(ent:GetClass())
            local targetName = getReferenceName(ent)
            if not shouldIncludeReference(className, targetName) then continue end

            local key = targetName .. "\n" .. className
            local entry = byKey[key]
            if not entry then
                local pos = ent.GetPos and ent:GetPos() or vector_origin
                entry = {
                    name = targetName,
                    className = className,
                    suggestedInput = getSuggestedInput(className),
                    count = 0,
                    pos = vectorToTable(pos),
                }

                byKey[key] = entry
                refs[#refs + 1] = entry
            end

            entry.count = entry.count + 1
        end

        table.sort(refs, function(left, right)
            local leftName = string.lower(left.name .. " " .. left.className)
            local rightName = string.lower(right.name .. " " .. right.className)
            return leftName < rightName
        end)

        return refs
    end

    local function sendReferenceData(ply)
        if not IsValid(ply) then return end

        net.Start(NET_SEND_REFERENCES)
            net.WriteString(util.TableToJSON(collectReferenceEntries(), true) or "[]")
        net.Send(ply)
    end

    local function appendOutputValues(out, value)
        if isstring(value) or isnumber(value) then
            local text = trimString(value)
            if text ~= "" then
                out[#out + 1] = text
            end
            return
        end

        if istable(value) then
            for _, nestedValue in pairs(value) do
                appendOutputValues(out, nestedValue)
            end
        end
    end

    local function parseOutputSpec(raw)
        raw = trimString(raw)
        if raw == "" then return nil end

        raw = string.gsub(raw, "\27", ",")

        local parts = string.Explode(",", raw, false)
        if #parts < 2 then return nil end

        local targetName = trimString(parts[1])
        local inputName = trimString(parts[2])
        if targetName == "" or inputName == "" then return nil end

        return {
            targetName = targetName,
            inputName = inputName,
            parameter = trimString(parts[3]),
            delay = tonumber(parts[4]) or 0,
            fireCount = tonumber(parts[5]) or -1,
        }
    end

    local function collectOutputSpecs(ent)
        local specs = {}
        local ok, kv = pcall(function()
            return ent:GetKeyValues()
        end)

        if not ok or not istable(kv) then
            return specs
        end

        for key, value in pairs(kv) do
            if not isstring(key) then continue end

            local outputName = trimString(key)
            if outputName == "" or not startsWith(string.lower(outputName), "on") then
                continue
            end

            local values = {}
            appendOutputValues(values, value)

            for _, rawValue in ipairs(values) do
                local spec = parseOutputSpec(rawValue)
                if not spec then continue end

                spec.outputName = outputName
                specs[#specs + 1] = spec
            end
        end

        return specs
    end

    local function getEntityDrawInfo(ent)
        return {
            name = getReferenceName(ent),
            className = trimString(ent:GetClass()),
            pos = vectorToTable(ent:GetPos()),
            mins = vectorToTable(ent:OBBMins()),
            maxs = vectorToTable(ent:OBBMaxs()),
            ang = angleToTable(ent:GetAngles()),
        }
    end

    local function findNamedEntities(name, className)
        local out = {}
        local seen = {}

        if ents.FindByName then
            for _, ent in ipairs(ents.FindByName(name)) do
                if not IsValid(ent) or seen[ent] then continue end
                if getReferenceName(ent) ~= name then continue end
                if className ~= "" and ent:GetClass() ~= className then continue end

                seen[ent] = true
                out[#out + 1] = ent
            end
        end

        if #out == 0 then
            for _, ent in ipairs(ents.GetAll()) do
                if not IsValid(ent) or seen[ent] then continue end
                if getReferenceName(ent) ~= name then continue end
                if className ~= "" and ent:GetClass() ~= className then continue end

                seen[ent] = true
                out[#out + 1] = ent
            end
        end

        return out
    end

    local function collectReferenceGraph(referenceName, className)
        local sourceEntities = findNamedEntities(referenceName, className)
        local graph = {
            name = referenceName,
            className = className,
            sources = {},
            links = {},
        }

        local seenLinks = {}

        for _, ent in ipairs(sourceEntities) do
            graph.sources[#graph.sources + 1] = getEntityDrawInfo(ent)

            for _, spec in ipairs(collectOutputSpecs(ent)) do
                local key = table.concat({
                    spec.outputName,
                    spec.targetName,
                    spec.inputName,
                    spec.parameter,
                    tostring(spec.delay),
                    tostring(spec.fireCount),
                }, "\n")

                if seenLinks[key] then continue end

                local targets = {}
                for _, targetEnt in ipairs(findNamedEntities(spec.targetName, "")) do
                    targets[#targets + 1] = getEntityDrawInfo(targetEnt)
                end

                seenLinks[key] = true
                graph.links[#graph.links + 1] = {
                    outputName = spec.outputName,
                    targetName = spec.targetName,
                    inputName = spec.inputName,
                    parameter = spec.parameter,
                    delay = spec.delay,
                    fireCount = spec.fireCount,
                    targets = targets,
                }
            end
        end

        table.sort(graph.links, function(left, right)
            local leftKey = string.lower(left.targetName .. " " .. left.inputName .. " " .. left.outputName)
            local rightKey = string.lower(right.targetName .. " " .. right.inputName .. " " .. right.outputName)
            return leftKey < rightKey
        end)

        return graph
    end

    local function sendReferenceGraph(ply, referenceName, className)
        if not IsValid(ply) then return end

        net.Start(NET_SEND_REFERENCE_GRAPH)
            net.WriteString(util.TableToJSON(collectReferenceGraph(referenceName, className), true) or "{}")
        net.Send(ply)
    end

    local function sendChromiumPresetData(ply)
        if not IsValid(ply) then return end

        local serialized = {}
        local dataPath = ""
        local bridge = istable(ZC_ChromiumNPCSpawner) and ZC_ChromiumNPCSpawner or nil
        local loadedPresets = bridge and isfunction(bridge.GetLoadedPresets) and (bridge.GetLoadedPresets() or {}) or {}

        if bridge and bridge.Initialized and isfunction(bridge.Reload) and not next(loadedPresets) then
            bridge.Reload()
            loadedPresets = isfunction(bridge.GetLoadedPresets) and (bridge.GetLoadedPresets() or {}) or {}
        end

        if bridge and isfunction(bridge.GetDataPath) then
            dataPath = tostring(bridge.GetDataPath() or "")
        end

        local presetEntries = {}
        for name, preset in pairs(loadedPresets) do
            local normalizedName = trimString(name)
            if normalizedName == "" or not istable(preset) then continue end

            presetEntries[#presetEntries + 1] = {
                name = normalizedName,
                preset = preset,
            }
        end

        table.sort(presetEntries, function(left, right)
            return string.lower(left.name) < string.lower(right.name)
        end)

        for index, entry in ipairs(presetEntries) do
            local preset = entry.preset
            serialized[index] = {
                name = entry.name,
                areaCount = istable(preset.areas) and #preset.areas or 0,
                enabled = boolOrDefault(preset.enabled, true),
                autoStart = boolOrDefault(preset.autoStart, false),
                mins = vectorToTable(preset.mins or vector_origin),
                maxs = vectorToTable(preset.maxs or vector_origin),
                origin = vectorToTable(preset.origin or vector_origin),
            }
        end

        net.Start(NET_SEND_CHROMIUM_PRESETS)
            net.WriteString(util.TableToJSON(serialized, true) or "[]")
            net.WriteString(dataPath)
        net.Send(ply)
    end

    local function isAliveHumanPlayer(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return false end
        if TEAM_SPECTATOR and ply:Team() == TEAM_SPECTATOR then return false end
        if not ply:Alive() then return false end
        if ply:IsBot() then return false end
        return true
    end

    local function isGordonAllowed(zone)
        return boolOrDefault(zone.allowGordonSolo, DEFAULT_ZONE_ALLOW_GORDON)
    end

    local function isEligibleZonePlayer(ply, zone)
        if not IsValid(ply) or not ply:IsPlayer() then return false end
        if not ply:Alive() then return false end
        if TEAM_SPECTATOR and ply:Team() == TEAM_SPECTATOR then return false end

        local className = normalizeClassName(ply.PlayerClassName)
        if BLOCKED_CLASSES[className] then
            return zone.allowCombinePlayers == true
        end

        if className == "gordon" then
            return isGordonAllowed(zone)
        end

        return true
    end

    local function playerInsideZone(ply, zone)
        return ply:GetPos():WithinAABox(zone.mins, zone.maxs)
    end

    local function entsByExactName(name)
        return findNamedEntities(trimString(name), "")
    end

    local function fireZoneOutputs(stage, activator)
        local firedCount = 0
        local missingTargets = {}
        local missingLookup = {}

        for _, output in ipairs(stageOutputList(stage)) do
            local targets = splitTargetNames(output.targetName)

            for _, targetName in ipairs(targets) do
                local matchedTargets = entsByExactName(targetName)
                if #matchedTargets == 0 then
                    if not missingLookup[targetName] then
                        missingLookup[targetName] = true
                        missingTargets[#missingTargets + 1] = targetName
                    end
                    continue
                end

                for _, ent in ipairs(matchedTargets) do
                    local parameter = trimString(output.parameter)
                    ent:Fire(output.inputName, parameter ~= "" and parameter or nil, output.delay, activator, activator)
                    firedCount = firedCount + 1
                end
            end
        end

        return firedCount, missingTargets
    end

    local function updateZone(zone, now)
        local runtime = zoneRuntime[zone.id] or {}
        local stages = zone.stages or zoneStageList(zone)
        local stageCount = #stages
        local firstStage = stages[1] or normalizeStage(nil, DEFAULT_HOLD_TIME)
        local rememberStage = boolOrDefault(zone.rememberStage, DEFAULT_ZONE_REMEMBER_STAGE)
        zoneRuntime[zone.id] = runtime

        if not zone.enabled then
            syncZoneProgress(runtime, zone.id, nil, nil)
            runtime.activePlayer = nil
            runtime.startedAt = nil
            runtime.pausedElapsed = nil
            runtime.firedStages = nil
            runtime.completed = nil
            return
        end

        local occupants = {}
        local occupantLookup = {}

        for _, ply in ipairs(player.GetAll()) do
            if not isEligibleZonePlayer(ply, zone) then continue end
            if not playerInsideZone(ply, zone) then continue end

            occupants[#occupants + 1] = ply
            occupantLookup[ply] = true
        end

        local activePlayer = IsValid(runtime.activePlayer) and occupantLookup[runtime.activePlayer] and runtime.activePlayer or occupants[1]

        runtime.activePlayer = activePlayer

        if not IsValid(activePlayer) then
            syncZoneProgress(runtime, zone.id, nil, nil)

            if runtime.completed then
                if zone.once then
                    return
                end

                runtime.completed = nil
                runtime.startedAt = nil
                runtime.pausedElapsed = nil
                runtime.firedStages = nil
                return
            end

            if runtime.startedAt then
                if rememberStage then
                    runtime.pausedElapsed = math.max(0, now - runtime.startedAt)
                else
                    runtime.firedStages = nil
                    runtime.pausedElapsed = nil
                end

                runtime.startedAt = nil
            elseif not rememberStage then
                runtime.firedStages = nil
                runtime.pausedElapsed = nil
            end

            return
        end

        if runtime.completed then
            syncZoneProgress(runtime, zone.id, occupants, nil)
            return
        end

        runtime.firedStages = istable(runtime.firedStages) and runtime.firedStages or {}

        if not runtime.startedAt then
            local resumeElapsed = rememberStage and math.max(0, tonumber(runtime.pausedElapsed) or 0) or 0
            if rememberStage and (resumeElapsed > 0 or next(runtime.firedStages) ~= nil) then
                runtime.startedAt = now - resumeElapsed
                runtime.pausedElapsed = nil
            else
                runtime.startedAt = now
                runtime.pausedElapsed = nil
                runtime.firedStages = {}
                sendStatus(activePlayer, string.format("Zone '%s' started: %d stage(s), first at %.1fs", zone.name, stageCount, firstStage.holdTime))
            end
        end

        for stageIndex, stage in ipairs(stages) do
            if runtime.firedStages[stageIndex] then
                continue
            end

            if now < (runtime.startedAt or now) + stageTriggerOffset(stages, stageIndex) then
                break
            end

            runtime.firedStages[stageIndex] = true
            runtime.lastFire = now

            local firedCount, missingTargets = fireZoneOutputs(stage, activePlayer)
            local statusMessage = string.format("Zone '%s' stage %d/%d fired %d map target(s).", zone.name, stageIndex, stageCount, firedCount)

            if #missingTargets > 0 then
                statusMessage = statusMessage .. " Missing target(s): " .. table.concat(missingTargets, ", ")
            end

            sendStatus(activePlayer, statusMessage)
        end

        local progressPayload = currentStageProgress(zone, stages, runtime.firedStages, runtime.startedAt, now)
        syncZoneProgress(runtime, zone.id, occupants, progressPayload)

        if progressPayload then
            return
        end

        runtime.completed = true
        syncZoneProgress(runtime, zone.id, occupants, nil)
    end

    loadZonesFromDisk()

    timer.Create("ZC_SequenceHelper_Runtime", THINK_INTERVAL, 0, function()
        local now = CurTime()
        for _, zone in ipairs(loadedZones) do
            updateZone(zone, now)
        end
    end)

    hook.Add("InitPostEntity", "ZC_SequenceHelper_Load", function()
        loadZonesFromDisk()
    end)

    hook.Add("PlayerDisconnected", "ZC_SequenceHelper_Cleanup", function(ply)
        editorState[ply] = nil
        for _, runtime in pairs(zoneRuntime) do
            if runtime.activePlayer == ply then
                runtime.activePlayer = nil
            end
        end
    end)

    local function handleRequestData(ply)
        if not canManageZones(ply) then return end
        sendZoneData(ply)
    end

    local function handleRequestReferences(ply)
        if not canManageZones(ply) then return end
        sendReferenceData(ply)
    end

    concommand.Add("zc_sequence_helper_request", handleRequestData)
    concommand.Add("zc_alyx_zone_request", handleRequestData)
    concommand.Add(CLIENT_REFERENCES_COMMAND, handleRequestReferences)
    concommand.Add(LEGACY_REFERENCES_COMMAND, handleRequestReferences)

    net.Receive(NET_REQUEST_DATA, function(_, ply)
        if not canManageZones(ply) then return end
        sendZoneData(ply)
    end)

    net.Receive(NET_REQUEST_REFERENCES, function(_, ply)
        if not canManageZones(ply) then return end
        sendReferenceData(ply)
    end)

    net.Receive(NET_REQUEST_CHROMIUM_PRESETS, function(_, ply)
        if not canManageZones(ply) then return end
        sendChromiumPresetData(ply)
    end)

    net.Receive(NET_REQUEST_REFERENCE_GRAPH, function(_, ply)
        if not canManageZones(ply) then return end

        local referenceName = trimString(net.ReadString())
        local className = trimString(net.ReadString())
        if referenceName == "" then return end

        sendReferenceGraph(ply, referenceName, className)
    end)

    net.Receive(NET_TEST_STAGE, function(_, ply)
        if not canManageZones(ply) then return end

        local payload = util.JSONToTable(tostring(net.ReadString() or ""))
        if not istable(payload) then
            sendStatus(ply, "Manual stage test failed: invalid payload.")
            return
        end

        local stage = normalizeStage(payload.stage or payload, DEFAULT_HOLD_TIME)
        if stage.targetName == "" then
            sendStatus(ply, "Manual stage test failed: target name is empty.")
            return
        end

        local zoneName = trimString(payload.zoneName)
        if zoneName == "" then
            zoneName = "Zone Test"
        end

        local firedCount, missingTargets = fireZoneOutputs(stage, ply)
        local statusMessage = string.format("Manual test for '%s' fired %d map target(s).", zoneName, firedCount)

        if #missingTargets > 0 then
            statusMessage = statusMessage .. " Missing target(s): " .. table.concat(missingTargets, ", ")
        end

        sendStatus(ply, statusMessage)
    end)

    net.Receive(NET_SAVE_DATA, function(_, ply)
        if not canManageZones(ply) then return end

        local json = tostring(net.ReadString() or "")
        local parsed = util.JSONToTable(json)
        if not istable(parsed) then
            sendStatus(ply, "Zone save failed: invalid JSON payload.")
            return
        end

        saveZonesToDisk(parsed)
        sendStatus(ply, string.format("Saved %d Sequence Helper zone(s) to %s", #loadedZones, zoneDataPath()))
        sendZoneData(ply)
    end)

    function ZC_SequenceHelper.SetCorner(ply, key, pos)
        if not canUseZoneTool(ply) then return end

        local state = getEditorState(ply)
        state[key] = Vector(pos.x, pos.y, pos.z)
        sendEditorState(ply)
        sendStatus(ply, string.format("Set %s to %.0f %.0f %.0f", key, pos.x, pos.y, pos.z))
    end

    function ZC_SequenceHelper.GetLoadedZones()
        return loadedZones
    end

    function ZC_SequenceHelper.GetDataPath()
        return zoneDataPath()
    end

    return
end

local browserFrame
local browserZones = {}
local browserReferences = {}
local selectedReferenceGraph
local editorCornerA
local editorCornerB
local zoneDataPathLabel = ""
local zoneProgressStates = {}
local selectedIndex = nil
local referenceFrame
local selectedReferenceIndex = nil
local chromiumPresetFrame
local browserChromiumPresets = {}
local selectedChromiumPresetIndex = nil
local chromiumPresetDataPathLabel = ""

local function zoneVector(data)
    return tableToVector(data)
end

local function zoneCopy(zone)
    local stages = zoneStageList(zone)
    local primaryStage = stages[1]

    return {
        id = trimString(zone.id),
        name = trimString(zone.name),
        mins = vectorToTable(zoneVector(zone.mins)),
        maxs = vectorToTable(zoneVector(zone.maxs)),
        holdTime = primaryStage.holdTime,
        targetName = primaryStage.targetName,
        inputName = primaryStage.inputName,
        parameter = primaryStage.parameter,
        delay = primaryStage.delay,
        stages = stages,
        once = boolOrDefault(zone.once, DEFAULT_ZONE_ONCE),
        enabled = boolOrDefault(zone.enabled, DEFAULT_ZONE_ENABLED),
        allowCombinePlayers = boolOrDefault(zone.allowCombinePlayers, DEFAULT_ZONE_ALLOW_COMBINE),
        allowGordonSolo = boolOrDefault(zone.allowGordonSolo, DEFAULT_ZONE_ALLOW_GORDON),
        rememberStage = boolOrDefault(zone.rememberStage, DEFAULT_ZONE_REMEMBER_STAGE),
    }
end

local function addClientStatus(msg)
    msg = tostring(msg or "")
    if msg == "" then return end

    if notification and notification.AddLegacy then
        notification.AddLegacy(msg, NOTIFY_HINT, 4)
    end

    if chat and chat.AddText then
        chat.AddText(Color(140, 210, 255), "[Sequence Helper] ", color_white, msg)
    end

    if IsValid(browserFrame) and IsValid(browserFrame.StatusLabel) then
        browserFrame.StatusLabel:SetText(msg)
    end
end

local function requestZoneData()
    net.Start(NET_REQUEST_DATA)
    net.SendToServer()
end

local function requestReferenceData()
    net.Start(NET_REQUEST_REFERENCES)
    net.SendToServer()
end

local function requestChromiumPresetData()
    net.Start(NET_REQUEST_CHROMIUM_PRESETS)
    net.SendToServer()
end

local function requestReferenceGraph(reference)
    if not istable(reference) or trimString(reference.name) == "" then
        selectedReferenceGraph = nil
        return
    end

    selectedReferenceGraph = nil

    net.Start(NET_REQUEST_REFERENCE_GRAPH)
        net.WriteString(trimString(reference.name))
        net.WriteString(trimString(reference.className))
    net.SendToServer()
end

local function saveZoneData()
    net.Start(NET_SAVE_DATA)
        net.WriteString(util.TableToJSON(browserZones, true) or "[]")
    net.SendToServer()
end

local function requestStageTest(zoneName, stage)
    net.Start(NET_TEST_STAGE)
        net.WriteString(util.TableToJSON({
            zoneName = trimString(zoneName),
            stage = stage,
        }, true) or "{}")
    net.SendToServer()
end

local refreshZoneList

local function persistZoneChanges(frame, statusMessage)
    if IsValid(frame) then
        refreshZoneList(frame)
    end

    saveZoneData()

    if statusMessage then
        addClientStatus(statusMessage)
    end
end

local function selectedZone()
    return selectedIndex and browserZones[selectedIndex] or nil
end

local function selectedChromiumPreset()
    return selectedChromiumPresetIndex and browserChromiumPresets[selectedChromiumPresetIndex] or nil
end

local function chromiumPresetSizeLabel(preset)
    local mins = zoneVector(preset.mins)
    local maxs = zoneVector(preset.maxs)
    local size = maxs - mins

    return string.format("%.0f x %.0f x %.0f", math.abs(size.x), math.abs(size.y), math.abs(size.z))
end

local function chromiumPresetOriginLabel(preset)
    local origin = zoneVector(preset.origin)
    return string.format("%.0f %.0f %.0f", origin.x, origin.y, origin.z)
end

local function makeZoneFromChromiumPreset(preset, zone, preserveStages)
    if not istable(preset) then
        addClientStatus("Select a Chromium spawner preset first.")
        return nil
    end

    zone = zone and zoneCopy(zone) or {}
    zone.name = trimString(zone.name) ~= "" and zone.name or trimString(preset.name)
    if zone.name == "" then
        zone.name = string.format("Zone %d", #browserZones + 1)
    end

    zone.id = trimString(zone.id)
    zone.mins = vectorToTable(zoneVector(preset.mins))
    zone.maxs = vectorToTable(zoneVector(preset.maxs))
    zone.once = boolOrDefault(zone.once, DEFAULT_ZONE_ONCE)
    zone.enabled = boolOrDefault(zone.enabled, DEFAULT_ZONE_ENABLED)
    zone.allowCombinePlayers = boolOrDefault(zone.allowCombinePlayers, DEFAULT_ZONE_ALLOW_COMBINE)
    zone.allowGordonSolo = boolOrDefault(zone.allowGordonSolo, DEFAULT_ZONE_ALLOW_GORDON)
    zone.rememberStage = boolOrDefault(zone.rememberStage, DEFAULT_ZONE_REMEMBER_STAGE)

    local stages
    if preserveStages then
        stages = zoneStageList(zone)
    else
        local holdTime = tonumber(zone.holdTime) or DEFAULT_HOLD_TIME
        stages = {
            normalizeStage({
                holdTime = holdTime,
                outputs = {
                    {
                        targetName = trimString(preset.name),
                        inputName = "Spawn",
                        parameter = "",
                        delay = 0,
                    },
                },
            }, holdTime),
        }
    end

    return applyPrimaryStageFields(zone, stages)
end

local function formatStageTime(value)
    local numeric = tonumber(value) or 0
    if math.floor(numeric) == numeric then
        return string.format("%.0f", numeric)
    end

    return string.format("%.1f", numeric)
end

local function formatStageOutputLine(output)
    output = normalizeStageOutput(output)

    return table.concat({
        output.targetName,
        output.inputName,
        output.parameter,
        formatStageTime(output.delay),
    }, " | ")
end

local function formatStageOutputLines(stage, startIndex)
    local lines = {}
    local outputs = stageOutputList(stage)

    for outputIndex = math.max(1, tonumber(startIndex) or 1), #outputs do
        lines[#lines + 1] = formatStageOutputLine(outputs[outputIndex])
    end

    return table.concat(lines, "\n")
end

local function formatAdditionalStageLines(zone)
    local blocks = {}
    local stages = zoneStageList(zone)

    for stageIndex = 2, #stages do
        local stage = stages[stageIndex]
        local blockLines = {
            formatStageTime(stage.holdTime),
            formatStageOutputLines(stage, 1),
        }

        blocks[#blocks + 1] = table.concat(blockLines, "\n")
    end

    return table.concat(blocks, "\n\n")
end

local function parseStageOutputLine(rawLine, label)
    local parts = string.Explode("|", tostring(rawLine or ""), false)
    if #parts < 2 then
        return nil, string.format("%s must use: target | input | parameter | fire delay", label)
    end

    local targetName = trimString(parts[1])
    local inputName = trimString(parts[2])
    if targetName == "" or inputName == "" then
        return nil, string.format("%s must include both a target and an input.", label)
    end

    local delayText = trimString(parts[4] or "")
    if delayText ~= "" and tonumber(delayText) == nil then
        return nil, string.format("%s has an invalid fire delay.", label)
    end

    return normalizeStageOutput({
        targetName = targetName,
        inputName = inputName,
        parameter = parts[3],
        delay = delayText ~= "" and tonumber(delayText) or 0,
    })
end

local function parseStageOutputLines(rawText, labelPrefix)
    local outputs = {}
    local normalizedText = string.Replace(tostring(rawText or ""), "\r\n", "\n")
    local outputLineIndex = 0

    for _, rawLine in ipairs(string.Explode("\n", normalizedText, false)) do
        local line = trimString(rawLine)
        if line == "" or startsWith(line, "#") then
            continue
        end

        outputLineIndex = outputLineIndex + 1
        local output, err = parseStageOutputLine(line, string.format("%s line %d", labelPrefix, outputLineIndex))
        if not output then
            return nil, err
        end

        outputs[#outputs + 1] = output
    end

    return outputs
end

local function parseAdditionalStages(rawText)
    local stages = {}
    local normalizedText = string.Replace(tostring(rawText or ""), "\r\n", "\n")
    local stageBlocks = {}
    local currentBlock = {}

    local function flushBlock()
        if #currentBlock == 0 then return end
        stageBlocks[#stageBlocks + 1] = currentBlock
        currentBlock = {}
    end

    for lineIndex, rawLine in ipairs(string.Explode("\n", normalizedText, false)) do
        local line = trimString(rawLine)
        if line == "" then
            flushBlock()
            continue
        end

        if startsWith(line, "#") then
            continue
        end

        currentBlock[#currentBlock + 1] = {
            text = line,
            lineIndex = lineIndex,
        }
    end

    flushBlock()

    for stageIndex, block in ipairs(stageBlocks) do
        local holdTime = tonumber(block[1].text)
        if holdTime == nil then
            return nil, string.format("Stage block %d must start with a numeric timer.", stageIndex)
        end

        if #block < 2 then
            return nil, string.format("Stage block %d needs at least one output line after the timer.", stageIndex)
        end

        local outputLines = {}
        for blockLine = 2, #block do
            outputLines[#outputLines + 1] = block[blockLine].text
        end

        local outputs, err = parseStageOutputLines(table.concat(outputLines, "\n"), string.format("Stage block %d output", stageIndex))
        if not outputs then
            return nil, err
        end

        stages[#stages + 1] = normalizeStage({
            holdTime = holdTime,
            outputs = outputs,
        }, holdTime)
    end

    return stages
end

local function makeZoneFromCorners(zone)
    if not isvector(editorCornerA) or not isvector(editorCornerB) then
        addClientStatus("Set both corners with the tool first.")
        return nil
    end

    local mins, maxs = orderedBounds(editorCornerA, editorCornerB)
    zone = zone and zoneCopy(zone) or {}
    zone.name = trimString(zone.name) ~= "" and zone.name or string.format("Zone %d", #browserZones + 1)
    zone.id = trimString(zone.id)
    zone.mins = vectorToTable(mins)
    zone.maxs = vectorToTable(maxs)
    zone.holdTime = tonumber(zone.holdTime) or DEFAULT_HOLD_TIME
    zone.targetName = trimString(zone.targetName)
    zone.inputName = trimString(zone.inputName) ~= "" and zone.inputName or DEFAULT_INPUT
    zone.parameter = trimString(zone.parameter)
    zone.delay = tonumber(zone.delay) or 0
    zone.once = boolOrDefault(zone.once, DEFAULT_ZONE_ONCE)
    zone.enabled = boolOrDefault(zone.enabled, DEFAULT_ZONE_ENABLED)
    zone.allowCombinePlayers = boolOrDefault(zone.allowCombinePlayers, DEFAULT_ZONE_ALLOW_COMBINE)
    zone.allowGordonSolo = boolOrDefault(zone.allowGordonSolo, DEFAULT_ZONE_ALLOW_GORDON)
    zone.rememberStage = boolOrDefault(zone.rememberStage, DEFAULT_ZONE_REMEMBER_STAGE)
    return applyPrimaryStageFields(zone, zoneStageList(zone))
end

local function updateCornerLabel(frame)
    if not IsValid(frame) or not IsValid(frame.CornerLabel) then return end

    local aText = isvector(editorCornerA) and string.format("A %.0f %.0f %.0f", editorCornerA.x, editorCornerA.y, editorCornerA.z) or "A unset"
    local bText = isvector(editorCornerB) and string.format("B %.0f %.0f %.0f", editorCornerB.x, editorCornerB.y, editorCornerB.z) or "B unset"
    frame.CornerLabel:SetText(aText .. " | " .. bText)
end

local buildStageFromPanel
local collectStagesFromTabs
local getActiveStagePanel
local rebuildStageTabs

local function populateForm(frame, zone)
    if not IsValid(frame) then return end

    local stages = zone and zoneStageList(zone) or zoneStageList(nil)

    frame.NameEntry:SetValue(zone and zone.name or "")
    frame.OnceCheck:SetChecked(zone and boolOrDefault(zone.once, DEFAULT_ZONE_ONCE) or DEFAULT_ZONE_ONCE)
    frame.EnabledCheck:SetChecked(zone and boolOrDefault(zone.enabled, DEFAULT_ZONE_ENABLED) or DEFAULT_ZONE_ENABLED)
    frame.CombineCheck:SetChecked(zone and boolOrDefault(zone.allowCombinePlayers, DEFAULT_ZONE_ALLOW_COMBINE) or DEFAULT_ZONE_ALLOW_COMBINE)
    frame.GordonCheck:SetChecked(zone and boolOrDefault(zone.allowGordonSolo, DEFAULT_ZONE_ALLOW_GORDON) or DEFAULT_ZONE_ALLOW_GORDON)
    frame.RememberStageCheck:SetChecked(zone and boolOrDefault(zone.rememberStage, DEFAULT_ZONE_REMEMBER_STAGE) or DEFAULT_ZONE_REMEMBER_STAGE)
    rebuildStageTabs(frame, stages, 1)
end

local function applyForm(frame)
    local zone = selectedZone()
    if not zone then
        addClientStatus("Select a zone first.")
        return false
    end

    local stages, stageError = collectStagesFromTabs(frame, true)
    if not stages then
        addClientStatus(stageError)
        return false
    end

    zone.name = trimString(frame.NameEntry:GetValue())
    zone.once = frame.OnceCheck:GetChecked()
    zone.enabled = frame.EnabledCheck:GetChecked()
    zone.allowCombinePlayers = frame.CombineCheck:GetChecked()
    zone.allowGordonSolo = frame.GordonCheck:GetChecked()
    zone.rememberStage = frame.RememberStageCheck:GetChecked()
    applyPrimaryStageFields(zone, stages)
    return true
end

local function buildPrimaryStageFromForm(frame)
    local stagePanel = getActiveStagePanel(frame)
    if not IsValid(stagePanel) then
        return nil, "Select a stage first."
    end

    return buildStageFromPanel(stagePanel, true)
end

local function themedControlClass(nexusClass, fallbackClass)
    if istable(Nexus) and vgui.GetControlTable and vgui.GetControlTable(nexusClass) then
        return nexusClass
    end

    return fallbackClass
end

local function createEditorFrame(title, width, height)
    local maxWidth = math.max(720, ScrW() - 80)
    local maxHeight = math.max(560, ScrH() - 80)

    local frame = vgui.Create(themedControlClass("Nexus:Frame", "DFrame"))
    frame:SetTitle(title)
    frame:SetSize(math.min(width, maxWidth), math.min(height, maxHeight))
    frame:Center()
    frame:MakePopup()

    if frame.SetSizable then
        frame:SetSizable(true)
    end

    return frame
end

local function setEditorFrameMinimums(frame, width, height)
    if frame.SetMinWidth then
        frame:SetMinWidth(math.min(width, math.max(720, ScrW() - 80)))
    end

    if frame.SetMinHeight then
        frame:SetMinHeight(math.min(height, math.max(560, ScrH() - 80)))
    end
end

local function createEditorButton(parent, text)
    local button = vgui.Create(themedControlClass("Nexus:Button", "DButton"), parent)
    button:SetText(text)
    return button
end

local function stageTabTitle(stageIndex)
    return string.format("Stage %d", stageIndex)
end

local function stageOutputRowText(output)
    output = normalizeStageOutput(output)

    return {
        output.targetName ~= "" and output.targetName or "-",
        output.inputName ~= "" and output.inputName or DEFAULT_INPUT,
        output.parameter ~= "" and output.parameter or "-",
        formatStageTime(output.delay),
    }
end

local function setStageOutputFields(stagePanel, output)
    output = output and normalizeStageOutput(output) or normalizeStageOutput(nil)
    stagePanel.TargetEntry:SetValue(output.targetName)
    stagePanel.InputEntry:SetValue(output.inputName)
    stagePanel.ParamEntry:SetValue(output.parameter)
    stagePanel.DelayEntry:SetValue(formatStageTime(output.delay))
end

local function selectStageOutput(stagePanel, index)
    if index and stagePanel.Outputs[index] then
        stagePanel.SelectedOutputIndex = index
        setStageOutputFields(stagePanel, stagePanel.Outputs[index])
    else
        stagePanel.SelectedOutputIndex = nil
        setStageOutputFields(stagePanel, nil)
    end

    if IsValid(stagePanel.OutputStatusLabel) then
        if stagePanel.SelectedOutputIndex then
            stagePanel.OutputStatusLabel:SetText(string.format("Editing output %d of %d.", stagePanel.SelectedOutputIndex, #stagePanel.Outputs))
        else
            stagePanel.OutputStatusLabel:SetText("Fill the fields below, then add or update an output.")
        end
    end
end

local function refreshStageOutputList(stagePanel)
    if not IsValid(stagePanel) or not IsValid(stagePanel.OutputList) then return end

    stagePanel.OutputList:Clear()
    for outputIndex, output in ipairs(stagePanel.Outputs) do
        local columns = stageOutputRowText(output)
        local line = stagePanel.OutputList:AddLine(columns[1], columns[2], columns[3], columns[4])
        line.OutputIndex = outputIndex
    end

    if stagePanel.SelectedOutputIndex and not stagePanel.Outputs[stagePanel.SelectedOutputIndex] then
        stagePanel.SelectedOutputIndex = nil
    end

    if IsValid(stagePanel.OutputCountLabel) then
        stagePanel.OutputCountLabel:SetText(string.format("%d output(s) in this stage.", #stagePanel.Outputs))
    end

    selectStageOutput(stagePanel, stagePanel.SelectedOutputIndex)
end

local function readStageOutputFields(stagePanel)
    local targetName = trimString(stagePanel.TargetEntry:GetValue())
    if targetName == "" then
        return nil, string.format("Stage %d output target name is required.", stagePanel.StageIndex or 1)
    end

    return normalizeStageOutput({
        targetName = targetName,
        inputName = trimString(stagePanel.InputEntry:GetValue()),
        parameter = trimString(stagePanel.ParamEntry:GetValue()),
        delay = math.max(0, tonumber(stagePanel.DelayEntry:GetValue()) or 0),
    })
end

local function appendStageOutput(stagePanel)
    local output, err = readStageOutputFields(stagePanel)
    if not output then
        addClientStatus(err)
        return false
    end

    stagePanel.Outputs[#stagePanel.Outputs + 1] = output
    stagePanel.SelectedOutputIndex = #stagePanel.Outputs
    refreshStageOutputList(stagePanel)
    return true
end

local function updateSelectedStageOutput(stagePanel)
    if not stagePanel.SelectedOutputIndex or not stagePanel.Outputs[stagePanel.SelectedOutputIndex] then
        addClientStatus(string.format("Select an output in %s first.", stageTabTitle(stagePanel.StageIndex or 1)))
        return false
    end

    local output, err = readStageOutputFields(stagePanel)
    if not output then
        addClientStatus(err)
        return false
    end

    stagePanel.Outputs[stagePanel.SelectedOutputIndex] = output
    refreshStageOutputList(stagePanel)
    return true
end

local function removeSelectedStageOutput(stagePanel)
    if not stagePanel.SelectedOutputIndex or not stagePanel.Outputs[stagePanel.SelectedOutputIndex] then
        addClientStatus(string.format("Select an output in %s first.", stageTabTitle(stagePanel.StageIndex or 1)))
        return false
    end

    table.remove(stagePanel.Outputs, stagePanel.SelectedOutputIndex)

    if #stagePanel.Outputs == 0 then
        stagePanel.SelectedOutputIndex = nil
    else
        stagePanel.SelectedOutputIndex = math.Clamp(stagePanel.SelectedOutputIndex, 1, #stagePanel.Outputs)
    end

    refreshStageOutputList(stagePanel)
    return true
end

buildStageFromPanel = function(stagePanel, strict)
    local holdTime = math.max(0, tonumber(stagePanel.HoldEntry:GetValue()) or DEFAULT_HOLD_TIME)
    local outputs = {}

    for _, output in ipairs(stagePanel.Outputs or {}) do
        if trimString(output.targetName) ~= "" then
            outputs[#outputs + 1] = normalizeStageOutput(output)
        end
    end

    if strict and #outputs == 0 then
        return nil, string.format("%s needs at least one output.", stageTabTitle(stagePanel.StageIndex or 1))
    end

    return normalizeStage({
        holdTime = holdTime,
        outputs = outputs,
    }, holdTime)
end

collectStagesFromTabs = function(frame, strict)
    local stages = {}

    for _, stagePanel in ipairs(frame.StagePanels or {}) do
        local stage, err = buildStageFromPanel(stagePanel, strict)
        if not stage then
            return nil, err
        end

        stages[#stages + 1] = stage
    end

    if #stages == 0 then
        stages[1] = normalizeStage(nil, DEFAULT_HOLD_TIME)
    end

    return stages
end

local function getActiveStageIndex(frame)
    if not IsValid(frame) or not IsValid(frame.StageSheet) then return 1 end

    local activeTab = frame.StageSheet.GetActiveTab and frame.StageSheet:GetActiveTab() or nil
    if not IsValid(activeTab) then
        return 1
    end

    for stageIndex, item in ipairs(frame.StageSheet.Items or {}) do
        if item.Tab == activeTab then
            return stageIndex
        end
    end

    return 1
end

getActiveStagePanel = function(frame)
    local stageIndex = getActiveStageIndex(frame)
    return frame.StagePanels and frame.StagePanels[stageIndex] or nil
end

local function createStagePanel(frame, stage, stageIndex)
    stage = normalizeStage(stage, DEFAULT_HOLD_TIME)

    local stagePanel = vgui.Create("DPanel", frame.StageSheet)
    stagePanel:DockPadding(8, 8, 8, 8)
    stagePanel.Paint = nil
    stagePanel.StageIndex = stageIndex
    stagePanel.Outputs = {}

    for _, output in ipairs(stageOutputList(stage)) do
        if trimString(output.targetName) ~= "" then
            stagePanel.Outputs[#stagePanel.Outputs + 1] = normalizeStageOutput(output)
        end
    end

    local holdPanel = vgui.Create("DPanel", stagePanel)
    holdPanel:Dock(TOP)
    holdPanel:SetTall(50)
    holdPanel.Paint = nil

    local holdLabel = vgui.Create("DLabel", holdPanel)
    holdLabel:SetText("Hold Time")

    local holdEntry = vgui.Create("DTextEntry", holdPanel)
    holdEntry:SetValue(formatStageTime(stage.holdTime or DEFAULT_HOLD_TIME))

    local outputCountLabel = vgui.Create("DLabel", holdPanel)
    outputCountLabel:SetText("")

    holdPanel.PerformLayout = function(_, width)
        holdLabel:SetPos(0, 0)
        holdLabel:SetSize(120, 18)
        holdEntry:SetPos(0, 20)
        holdEntry:SetSize(96, 24)
        outputCountLabel:SetPos(110, 20)
        outputCountLabel:SetSize(math.max(0, width - 110), 24)
    end

    local outputList = vgui.Create("DListView", stagePanel)
    outputList:Dock(FILL)
    outputList:SetMultiSelect(false)
    outputList:AddColumn("Target")
    outputList:AddColumn("Input")
    outputList:AddColumn("Parameter")
    outputList:AddColumn("Delay")
    outputList.OnRowSelected = function(_, _, row)
        selectStageOutput(stagePanel, row.OutputIndex)
    end

    local editorPanel = vgui.Create("DPanel", stagePanel)
    editorPanel:Dock(BOTTOM)
    editorPanel:SetTall(112)
    editorPanel.Paint = nil

    local targetLabel = vgui.Create("DLabel", editorPanel)
    targetLabel:SetText("Target")
    local inputLabel = vgui.Create("DLabel", editorPanel)
    inputLabel:SetText("Input")
    local paramLabel = vgui.Create("DLabel", editorPanel)
    paramLabel:SetText("Parameter")
    local delayLabel = vgui.Create("DLabel", editorPanel)
    delayLabel:SetText("Delay")

    local targetEntry = vgui.Create("DTextEntry", editorPanel)
    targetEntry:SetPlaceholderText("logic_relay_name")
    local inputEntry = vgui.Create("DTextEntry", editorPanel)
    inputEntry:SetPlaceholderText(DEFAULT_INPUT)
    local paramEntry = vgui.Create("DTextEntry", editorPanel)
    paramEntry:SetPlaceholderText("Optional")
    local delayEntry = vgui.Create("DTextEntry", editorPanel)
    delayEntry:SetPlaceholderText("0")

    local outputStatusLabel = vgui.Create("DLabel", editorPanel)
    outputStatusLabel:SetText("")

    local addOutputButton = createEditorButton(editorPanel, "Add Output")
    addOutputButton.DoClick = function()
        appendStageOutput(stagePanel)
    end

    local updateOutputButton = createEditorButton(editorPanel, "Update Selected")
    updateOutputButton.DoClick = function()
        updateSelectedStageOutput(stagePanel)
    end

    local removeOutputButton = createEditorButton(editorPanel, "Remove Selected")
    removeOutputButton.DoClick = function()
        removeSelectedStageOutput(stagePanel)
    end

    local clearOutputButton = createEditorButton(editorPanel, "Clear Fields")
    clearOutputButton.DoClick = function()
        stagePanel.SelectedOutputIndex = nil
        selectStageOutput(stagePanel, nil)
    end

    editorPanel.PerformLayout = function(_, width)
        local gap = 8
        local delayWidth = 70
        local inputWidth = math.max(120, math.floor(width * 0.18))
        local targetWidth = math.max(220, math.floor(width * 0.38))
        local paramWidth = math.max(120, width - targetWidth - inputWidth - delayWidth - gap * 3)
        local targetX = 0
        local inputX = targetX + targetWidth + gap
        local paramX = inputX + inputWidth + gap
        local delayX = paramX + paramWidth + gap

        targetLabel:SetPos(targetX, 0)
        targetLabel:SetSize(targetWidth, 18)
        inputLabel:SetPos(inputX, 0)
        inputLabel:SetSize(inputWidth, 18)
        paramLabel:SetPos(paramX, 0)
        paramLabel:SetSize(paramWidth, 18)
        delayLabel:SetPos(delayX, 0)
        delayLabel:SetSize(delayWidth, 18)

        targetEntry:SetPos(targetX, 20)
        targetEntry:SetSize(targetWidth, 24)
        inputEntry:SetPos(inputX, 20)
        inputEntry:SetSize(inputWidth, 24)
        paramEntry:SetPos(paramX, 20)
        paramEntry:SetSize(paramWidth, 24)
        delayEntry:SetPos(delayX, 20)
        delayEntry:SetSize(delayWidth, 24)

        outputStatusLabel:SetPos(0, 52)
        outputStatusLabel:SetSize(width, 18)

        local buttonWidth = math.floor((width - gap * 3) / 4)
        addOutputButton:SetPos(0, 78)
        addOutputButton:SetSize(buttonWidth, 28)
        updateOutputButton:SetPos(buttonWidth + gap, 78)
        updateOutputButton:SetSize(buttonWidth, 28)
        removeOutputButton:SetPos((buttonWidth + gap) * 2, 78)
        removeOutputButton:SetSize(buttonWidth, 28)
        clearOutputButton:SetPos((buttonWidth + gap) * 3, 78)
        clearOutputButton:SetSize(buttonWidth, 28)
    end

    stagePanel.HoldEntry = holdEntry
    stagePanel.OutputList = outputList
    stagePanel.TargetEntry = targetEntry
    stagePanel.InputEntry = inputEntry
    stagePanel.ParamEntry = paramEntry
    stagePanel.DelayEntry = delayEntry
    stagePanel.OutputCountLabel = outputCountLabel
    stagePanel.OutputStatusLabel = outputStatusLabel

    refreshStageOutputList(stagePanel)
    selectStageOutput(stagePanel, stagePanel.Outputs[1] and 1 or nil)

    return stagePanel
end

rebuildStageTabs = function(frame, stages, activeIndex)
    if not IsValid(frame) or not IsValid(frame.StageSheet) then return end

    stages = istable(stages) and stages or { normalizeStage(nil, DEFAULT_HOLD_TIME) }
    activeIndex = math.Clamp(tonumber(activeIndex) or 1, 1, math.max(#stages, 1))

    if frame.StageSheet.Clear then
        frame.StageSheet:Clear()
    end

    frame.StagePanels = {}

    for stageIndex, stage in ipairs(stages) do
        local stagePanel = createStagePanel(frame, stage, stageIndex)
        local sheet = frame.StageSheet:AddSheet(stageTabTitle(stageIndex), stagePanel, nil)
        if sheet and sheet.Tab then
            sheet.Tab.StageIndex = stageIndex
        end
        frame.StagePanels[stageIndex] = stagePanel
    end

    local item = frame.StageSheet.Items and frame.StageSheet.Items[activeIndex]
    if item and item.Tab and frame.StageSheet.SetActiveTab then
        frame.StageSheet:SetActiveTab(item.Tab)
    end
end

refreshZoneList = function(frame)
    if not IsValid(frame) or not IsValid(frame.ZoneList) then return end

    frame.ZoneList:Clear()
    for index, zone in ipairs(browserZones) do
        local stages = zoneStageList(zone)
        local primaryStage = stages[1]

        frame.ZoneList:AddLine(
            zone.name,
            primaryStage.targetName ~= "" and primaryStage.targetName or "-",
            string.format("%.1f", tonumber(primaryStage.holdTime) or DEFAULT_HOLD_TIME),
            primaryStage.inputName ~= "" and primaryStage.inputName or DEFAULT_INPUT,
            zone.enabled ~= false and "ON" or "OFF",
            string.format("%s x%d", zone.once ~= false and "once" or "repeat", #stages)
        ).ZoneIndex = index
    end

    if selectedIndex and browserZones[selectedIndex] then
        populateForm(frame, browserZones[selectedIndex])
    else
        populateForm(frame, nil)
    end

    updateCornerLabel(frame)
    if IsValid(frame.PathLabel) then
        frame.PathLabel:SetText(zoneDataPathLabel)
    end
end

local function referencePosLabel(reference)
    local pos = zoneVector(reference.pos)
    return string.format("%.0f %.0f %.0f", pos.x, pos.y, pos.z)
end

local function selectedReference()
    return selectedReferenceIndex and browserReferences[selectedReferenceIndex] or nil
end

local function graphMatchesReference(graph, reference)
    return istable(graph)
        and istable(reference)
        and trimString(graph.name) == trimString(reference.name)
        and trimString(graph.className) == trimString(reference.className)
end

local function isDoorReference(reference)
    return istable(reference) and DOOR_REFERENCE_CLASSES[trimString(reference.className)] == true
end

local function stageOutputKey(output)
    output = normalizeStageOutput(output)

    return table.concat({
        output.targetName,
        output.inputName,
        output.parameter,
        tostring(output.delay),
    }, "\n")
end

local function appendUniqueStageOutput(stagePanel, output, existing)
    output = normalizeStageOutput(output)
    if output.targetName == "" or output.inputName == "" then return false end

    existing = existing or {}
    local key = stageOutputKey(output)
    if existing[key] then
        return false
    end

    existing[key] = true
    stagePanel.Outputs[#stagePanel.Outputs + 1] = output
    return true
end

local function refreshReferenceList(frame)
    if not IsValid(frame) or not IsValid(frame.ReferenceList) then return end

    local filter = string.lower(trimString(IsValid(frame.SearchEntry) and frame.SearchEntry:GetValue() or ""))
    frame.ReferenceList:Clear()

    for index, reference in ipairs(browserReferences) do
        local haystack = string.lower(reference.name .. " " .. reference.className .. " " .. tostring(reference.suggestedInput or ""))
        if filter ~= "" and not string.find(haystack, filter, 1, true) then
            continue
        end

        frame.ReferenceList:AddLine(
            reference.name,
            reference.className,
            reference.suggestedInput ~= "" and reference.suggestedInput or "-",
            tostring(reference.count or 1),
            referencePosLabel(reference)
        ).ReferenceIndex = index
    end

    if IsValid(frame.DetailLabel) then
        local reference = selectedReference()
        if reference then
            local detail = string.format("%s (%s) | suggested input: %s | matches: %d", reference.name, reference.className, reference.suggestedInput ~= "" and reference.suggestedInput or "manual", reference.count or 1)

            if graphMatchesReference(selectedReferenceGraph, reference) then
                detail = detail .. string.format(" | overlay links: %d", #(selectedReferenceGraph.links or {}))
            else
                detail = detail .. " | select row to draw graph"
            end

            frame.DetailLabel:SetText(detail)
        else
            frame.DetailLabel:SetText("Select a named map entity to inspect its targetname, suggested input, and graph overlay.")
        end
    end
end

local function applyReferenceToZone(reference)
    if not reference then
        addClientStatus("Select a reference first.")
        return
    end

    if not IsValid(browserFrame) then
        addClientStatus("Open the zone browser first.")
        return
    end

    if not selectedZone() then
        addClientStatus("Select a zone first.")
        return
    end

    local stagePanel = getActiveStagePanel(browserFrame)
    if not IsValid(stagePanel) then
        addClientStatus("Select a stage first.")
        return
    end

    stagePanel.SelectedOutputIndex = nil
    stagePanel.TargetEntry:SetValue(reference.name)
    stagePanel.InputEntry:SetValue(trimString(reference.suggestedInput) ~= "" and reference.suggestedInput or DEFAULT_INPUT)
    stagePanel.ParamEntry:SetValue("")
    stagePanel.DelayEntry:SetValue("0")

    if appendStageOutput(stagePanel) then
        addClientStatus(string.format("Added '%s' (%s) to %s. Apply or save the zone to persist it.", reference.name, reference.className, stageTabTitle(stagePanel.StageIndex or 1)))
    end
end

local function applyReferenceGraphToZone(reference)
    if not reference then
        addClientStatus("Select a reference first.")
        return
    end

    if not IsValid(browserFrame) then
        addClientStatus("Open the zone browser first.")
        return
    end

    if not selectedZone() then
        addClientStatus("Select a zone first.")
        return
    end

    local stagePanel = getActiveStagePanel(browserFrame)
    if not IsValid(stagePanel) then
        addClientStatus("Select a stage first.")
        return
    end

    if not graphMatchesReference(selectedReferenceGraph, reference) then
        requestReferenceGraph(reference)
        addClientStatus("Reference graph is not loaded yet. Select the row and try again in a moment.")
        return
    end

    local existing = {}
    for _, output in ipairs(stagePanel.Outputs or {}) do
        existing[stageOutputKey(output)] = true
    end

    local addedCount = 0
    local skippedCount = 0

    for _, link in ipairs(selectedReferenceGraph.links or {}) do
        local output = normalizeStageOutput({
            targetName = link.targetName,
            inputName = link.inputName,
            parameter = link.parameter,
            delay = link.delay,
        })

        if output.targetName == "" or output.inputName == "" then
            skippedCount = skippedCount + 1
            continue
        end

        if existing[stageOutputKey(output)] then
            skippedCount = skippedCount + 1
            continue
        end

        existing[stageOutputKey(output)] = true
        stagePanel.Outputs[#stagePanel.Outputs + 1] = output
        addedCount = addedCount + 1
    end

    if addedCount == 0 then
        addClientStatus(string.format("Reference '%s' had no new graph outputs to import.", reference.name))
        return
    end

    stagePanel.SelectedOutputIndex = #stagePanel.Outputs
    refreshStageOutputList(stagePanel)
    selectStageOutput(stagePanel, stagePanel.SelectedOutputIndex)

    local skippedSuffix = skippedCount > 0 and string.format(" Skipped %d duplicate/empty link(s).", skippedCount) or ""
    addClientStatus(string.format("Imported %d graph output(s) from '%s' into %s.%s Apply or save the zone to persist them.", addedCount, reference.name, stageTabTitle(stagePanel.StageIndex or 1), skippedSuffix))
end

local function applyDoorHelperToZone(reference, openSeconds)
    if not reference then
        addClientStatus("Select a reference first.")
        return
    end

    if not isDoorReference(reference) then
        addClientStatus("Select a door reference first.")
        return
    end

    if not IsValid(browserFrame) then
        addClientStatus("Open the zone browser first.")
        return
    end

    if not selectedZone() then
        addClientStatus("Select a zone first.")
        return
    end

    local stagePanel = getActiveStagePanel(browserFrame)
    if not IsValid(stagePanel) then
        addClientStatus("Select a stage first.")
        return
    end

    local duration = math.Clamp(tonumber(openSeconds) or 5, 0.1, 600)
    local existing = {}
    for _, output in ipairs(stagePanel.Outputs or {}) do
        existing[stageOutputKey(output)] = true
    end

    local addedCount = 0
    local presets = {
        { targetName = reference.name, inputName = "Unlock", delay = 0 },
        { targetName = reference.name, inputName = "Open", delay = 0 },
        { targetName = reference.name, inputName = "Close", delay = duration },
        { targetName = reference.name, inputName = "Lock", delay = duration + 0.1 },
    }

    for _, output in ipairs(presets) do
        if appendUniqueStageOutput(stagePanel, output, existing) then
            addedCount = addedCount + 1
        end
    end

    if addedCount == 0 then
        addClientStatus(string.format("Door helper found no new outputs to add for '%s'.", reference.name))
        return
    end

    stagePanel.SelectedOutputIndex = #stagePanel.Outputs
    refreshStageOutputList(stagePanel)
    selectStageOutput(stagePanel, stagePanel.SelectedOutputIndex)
    addClientStatus(string.format("Added timed door helper for '%s' in %s. It will unlock/open now and close/lock after %.1fs. Apply or save the zone to persist it.", reference.name, stageTabTitle(stagePanel.StageIndex or 1), duration))
end

local function openReferenceBrowser()
    if IsValid(referenceFrame) then
        referenceFrame:MakePopup()
        referenceFrame:MoveToFront()
        refreshReferenceList(referenceFrame)
        return
    end

    local frame = createEditorFrame("Sequence Helper References", 980, 620)
    setEditorFrameMinimums(frame, 760, 420)

    local content = vgui.Create("DPanel", frame)
    content:Dock(FILL)
    content:DockMargin(12, 12, 12, 12)
    content.Paint = nil

    local searchEntry = vgui.Create("DTextEntry", content)
    searchEntry:Dock(TOP)
    searchEntry:SetTall(28)
    searchEntry:DockMargin(0, 0, 0, 8)
    searchEntry:SetPlaceholderText("Filter by targetname, class, or suggested input")
    searchEntry.OnChange = function()
        refreshReferenceList(frame)
    end

    local buttonRow = vgui.Create("DPanel", content)
    buttonRow:Dock(BOTTOM)
    buttonRow:SetTall(32)
    buttonRow.Paint = nil

    local doorSecondsEntry = vgui.Create("DTextEntry", buttonRow)
    doorSecondsEntry:Dock(RIGHT)
    doorSecondsEntry:SetWide(64)
    doorSecondsEntry:SetValue("5")

    local doorSecondsLabel = vgui.Create("DLabel", buttonRow)
    doorSecondsLabel:Dock(RIGHT)
    doorSecondsLabel:DockMargin(0, 7, 8, 0)
    doorSecondsLabel:SetWide(118)
    doorSecondsLabel:SetText("Door open sec")

    local detailLabel = vgui.Create("DLabel", content)
    detailLabel:Dock(BOTTOM)
    detailLabel:SetTall(22)
    detailLabel:DockMargin(0, 8, 0, 8)
    detailLabel:SetText("Select a named map entity to inspect its targetname, suggested input, and graph overlay.")

    local referenceList = vgui.Create("DListView", content)
    referenceList:Dock(FILL)
    referenceList:SetMultiSelect(false)
    referenceList:AddColumn("Target Name")
    referenceList:AddColumn("Class")
    referenceList:AddColumn("Suggested Input")
    referenceList:AddColumn("Count")
    referenceList:AddColumn("Sample Pos")
    referenceList.OnRowSelected = function(_, _, row)
        selectedReferenceIndex = row.ReferenceIndex
        refreshReferenceList(frame)
        requestReferenceGraph(selectedReference())
    end
    referenceList.DoDoubleClick = function(_, _, row)
        selectedReferenceIndex = row.ReferenceIndex
        applyReferenceToZone(selectedReference())
    end

    local applyButton = createEditorButton(buttonRow, "Add To Active Stage")
    applyButton:Dock(LEFT)
    applyButton:DockMargin(0, 0, 8, 0)
    applyButton:SetWide(180)
    applyButton.DoClick = function()
        applyReferenceToZone(selectedReference())
    end

    local importGraphButton = createEditorButton(buttonRow, "Import Graph Outputs")
    importGraphButton:Dock(LEFT)
    importGraphButton:DockMargin(0, 0, 8, 0)
    importGraphButton:SetWide(190)
    importGraphButton.DoClick = function()
        applyReferenceGraphToZone(selectedReference())
    end

    local doorHelperButton = createEditorButton(buttonRow, "Add Timed Door Helper")
    doorHelperButton:Dock(LEFT)
    doorHelperButton:DockMargin(0, 0, 8, 0)
    doorHelperButton:SetWide(210)
    doorHelperButton.DoClick = function()
        applyDoorHelperToZone(selectedReference(), IsValid(doorSecondsEntry) and doorSecondsEntry:GetValue() or "5")
    end

    local copyNameButton = createEditorButton(buttonRow, "Copy Target Name")
    copyNameButton:Dock(LEFT)
    copyNameButton:DockMargin(0, 0, 8, 0)
    copyNameButton:SetWide(150)
    copyNameButton.DoClick = function()
        local reference = selectedReference()
        if not reference then
            addClientStatus("Select a reference first.")
            return
        end

        if SetClipboardText then
            SetClipboardText(reference.name)
        end

        addClientStatus(string.format("Copied '%s' to clipboard.", reference.name))
    end

    local refreshButton = createEditorButton(buttonRow, "Refresh List")
    refreshButton:Dock(LEFT)
    refreshButton:SetWide(140)
    refreshButton.DoClick = requestReferenceData

    frame.SearchEntry = searchEntry
    frame.ReferenceList = referenceList
    frame.DetailLabel = detailLabel

    referenceFrame = frame
    refreshReferenceList(frame)
end

local refreshChromiumPresetList

local function applyChromiumPresetAsNewZone(preset)
    if not IsValid(browserFrame) then
        addClientStatus("Open the zone browser first.")
        return
    end

    local zone = makeZoneFromChromiumPreset(preset, {
        name = trimString(istable(preset) and preset.name),
        once = DEFAULT_ZONE_ONCE,
        enabled = DEFAULT_ZONE_ENABLED,
        allowCombinePlayers = DEFAULT_ZONE_ALLOW_COMBINE,
        allowGordonSolo = DEFAULT_ZONE_ALLOW_GORDON,
        rememberStage = DEFAULT_ZONE_REMEMBER_STAGE,
    }, false)
    if not zone then return end

    browserZones[#browserZones + 1] = zone
    selectedIndex = #browserZones
    persistZoneChanges(browserFrame, string.format("Imported Chromium spawner '%s' as zone '%s'.", trimString(preset.name), zone.name))
end

local function applyChromiumPresetBoundsToSelectedZone(preset)
    if not IsValid(browserFrame) then
        addClientStatus("Open the zone browser first.")
        return
    end

    local zone = selectedZone()
    if not zone then
        addClientStatus("Select a zone first.")
        return
    end

    local updatedZone = makeZoneFromChromiumPreset(preset, zone, true)
    if not updatedZone then return end

    browserZones[selectedIndex] = updatedZone
    persistZoneChanges(browserFrame, string.format("Updated zone '%s' to Chromium spawner '%s' bounds.", updatedZone.name, trimString(preset.name)))
end

refreshChromiumPresetList = function(frame)
    if not IsValid(frame) or not IsValid(frame.PresetList) then return end

    local filter = string.lower(trimString(IsValid(frame.SearchEntry) and frame.SearchEntry:GetValue() or ""))
    frame.PresetList:Clear()

    for index, preset in ipairs(browserChromiumPresets) do
        local haystack = string.lower(table.concat({
            trimString(preset.name),
            chromiumPresetOriginLabel(preset),
            chromiumPresetSizeLabel(preset),
        }, " "))

        if filter ~= "" and not string.find(haystack, filter, 1, true) then
            continue
        end

        frame.PresetList:AddLine(
            trimString(preset.name),
            tostring(math.max(0, tonumber(preset.areaCount) or 0)),
            preset.enabled ~= false and "ON" or "OFF",
            preset.autoStart and "AUTO" or "-",
            chromiumPresetSizeLabel(preset),
            chromiumPresetOriginLabel(preset)
        ).PresetIndex = index
    end

    if IsValid(frame.DetailLabel) then
        local preset = selectedChromiumPreset()
        if preset then
            frame.DetailLabel:SetText(string.format("%s | %d area(s) | new import defaults to Spawn -> %s | 'Use Preset Bounds' keeps current stage outputs.", trimString(preset.name), math.max(0, tonumber(preset.areaCount) or 0), trimString(preset.name)))
        else
            frame.DetailLabel:SetText("Select a Chromium spawner preset to import its bounds into Sequence Helper.")
        end
    end

    if IsValid(frame.PathLabel) then
        frame.PathLabel:SetText(chromiumPresetDataPathLabel ~= "" and chromiumPresetDataPathLabel or "Chromium spawner data path unavailable.")
    end
end

local function openChromiumPresetBrowser()
    if IsValid(chromiumPresetFrame) then
        chromiumPresetFrame:MakePopup()
        chromiumPresetFrame:MoveToFront()
        refreshChromiumPresetList(chromiumPresetFrame)
        return
    end

    local frame = createEditorFrame("Sequence Helper Chromium Spawners", 1040, 620)
    setEditorFrameMinimums(frame, 820, 420)

    local content = vgui.Create("DPanel", frame)
    content:Dock(FILL)
    content:DockMargin(12, 12, 12, 12)
    content.Paint = nil

    local searchEntry = vgui.Create("DTextEntry", content)
    searchEntry:Dock(TOP)
    searchEntry:SetTall(28)
    searchEntry:DockMargin(0, 0, 0, 8)
    searchEntry:SetPlaceholderText("Filter by preset name, bounds, or origin")
    searchEntry.OnChange = function()
        refreshChromiumPresetList(frame)
    end

    local buttonRow = vgui.Create("DPanel", content)
    buttonRow:Dock(BOTTOM)
    buttonRow:SetTall(32)
    buttonRow.Paint = nil

    local infoPanel = vgui.Create("DPanel", content)
    infoPanel:Dock(BOTTOM)
    infoPanel:SetTall(46)
    infoPanel:DockMargin(0, 8, 0, 8)
    infoPanel.Paint = nil

    local detailLabel = vgui.Create("DLabel", infoPanel)
    detailLabel:SetWrap(true)
    detailLabel:SetText("Select a Chromium spawner preset to import its bounds into Sequence Helper.")

    local pathLabel = vgui.Create("DLabel", infoPanel)
    pathLabel:SetWrap(true)
    pathLabel:SetText("")

    infoPanel.PerformLayout = function(_, width)
        detailLabel:SetPos(0, 0)
        detailLabel:SetSize(width, 18)
        pathLabel:SetPos(0, 22)
        pathLabel:SetSize(width, 18)
    end

    local presetList = vgui.Create("DListView", content)
    presetList:Dock(FILL)
    presetList:SetMultiSelect(false)
    presetList:AddColumn("Preset")
    presetList:AddColumn("Areas")
    presetList:AddColumn("Enabled")
    presetList:AddColumn("Auto")
    presetList:AddColumn("Bounds")
    presetList:AddColumn("Origin")
    presetList.OnRowSelected = function(_, _, row)
        selectedChromiumPresetIndex = row.PresetIndex
        refreshChromiumPresetList(frame)
    end
    presetList.DoDoubleClick = function(_, _, row)
        selectedChromiumPresetIndex = row.PresetIndex
        applyChromiumPresetAsNewZone(selectedChromiumPreset())
    end

    local importButton = createEditorButton(buttonRow, "New Zone From Preset")
    importButton:Dock(LEFT)
    importButton:DockMargin(0, 0, 8, 0)
    importButton:SetWide(180)
    importButton.DoClick = function()
        applyChromiumPresetAsNewZone(selectedChromiumPreset())
    end

    local boundsButton = createEditorButton(buttonRow, "Use Preset Bounds")
    boundsButton:Dock(LEFT)
    boundsButton:DockMargin(0, 0, 8, 0)
    boundsButton:SetWide(170)
    boundsButton.DoClick = function()
        applyChromiumPresetBoundsToSelectedZone(selectedChromiumPreset())
    end

    local copyNameButton = createEditorButton(buttonRow, "Copy Target Name")
    copyNameButton:Dock(LEFT)
    copyNameButton:DockMargin(0, 0, 8, 0)
    copyNameButton:SetWide(150)
    copyNameButton.DoClick = function()
        local preset = selectedChromiumPreset()
        if not preset then
            addClientStatus("Select a Chromium spawner preset first.")
            return
        end

        if SetClipboardText then
            SetClipboardText(trimString(preset.name))
        end

        addClientStatus(string.format("Copied Chromium spawner target '%s' to clipboard.", trimString(preset.name)))
    end

    local refreshButton = createEditorButton(buttonRow, "Refresh Presets")
    refreshButton:Dock(LEFT)
    refreshButton:SetWide(140)
    refreshButton.DoClick = requestChromiumPresetData

    frame.SearchEntry = searchEntry
    frame.PresetList = presetList
    frame.DetailLabel = detailLabel
    frame.PathLabel = pathLabel

    chromiumPresetFrame = frame
    refreshChromiumPresetList(frame)
end

local function openZoneBrowser()
    if IsValid(browserFrame) then
        browserFrame:MakePopup()
        browserFrame:MoveToFront()
        refreshZoneList(browserFrame)
        return
    end

    local frame = createEditorFrame("Sequence Helper", 1320, 860)
    setEditorFrameMinimums(frame, 920, 700)

    local content = vgui.Create("DPanel", frame)
    content:Dock(FILL)
    content:DockMargin(12, 12, 12, 12)
    content.Paint = nil

    local leftPanel = vgui.Create("DPanel", content)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(420)
    leftPanel:DockMargin(0, 0, 12, 0)
    leftPanel.Paint = nil

    local rightPanel = vgui.Create("DPanel", content)
    rightPanel:Dock(FILL)
    rightPanel.Paint = nil

    local zoneList = vgui.Create("DListView", leftPanel)
    zoneList:Dock(FILL)
    zoneList:SetMultiSelect(false)
    zoneList:AddColumn("Zone")
    zoneList:AddColumn("Target")
    zoneList:AddColumn("Hold")
    zoneList:AddColumn("Input")
    zoneList:AddColumn("Enabled")
    zoneList:AddColumn("Mode")
    zoneList.OnRowSelected = function(_, _, row)
        selectedIndex = row.ZoneIndex
        populateForm(frame, browserZones[selectedIndex])
    end

    local generalPanel = vgui.Create("DPanel", rightPanel)
    generalPanel:Dock(TOP)
    generalPanel:SetTall(194)
    generalPanel:DockMargin(0, 0, 0, 8)
    generalPanel.Paint = nil

    local nameLabel = vgui.Create("DLabel", generalPanel)
    nameLabel:SetText("Zone Name")
    local nameEntry = vgui.Create("DTextEntry", generalPanel)

    local onceCheck = vgui.Create("DCheckBoxLabel", generalPanel)
    onceCheck:SetText("Fire once per map load")
    onceCheck:SizeToContents()
    onceCheck:SetValue(DEFAULT_ZONE_ONCE and 1 or 0)

    local enabledCheck = vgui.Create("DCheckBoxLabel", generalPanel)
    enabledCheck:SetText("Enabled")
    enabledCheck:SizeToContents()
    enabledCheck:SetValue(1)

    local combineCheck = vgui.Create("DCheckBoxLabel", generalPanel)
    combineCheck:SetText("Allow Combine and Metrocop players")
    combineCheck:SizeToContents()
    combineCheck:SetValue(DEFAULT_ZONE_ALLOW_COMBINE and 1 or 0)

    local gordonCheck = vgui.Create("DCheckBoxLabel", generalPanel)
    gordonCheck:SetText("Allow Gordon players")
    gordonCheck:SizeToContents()
    gordonCheck:SetValue(DEFAULT_ZONE_ALLOW_GORDON and 1 or 0)

    local rememberStageCheck = vgui.Create("DCheckBoxLabel", generalPanel)
    rememberStageCheck:SetText("Remember stage when zone empties")
    rememberStageCheck:SizeToContents()
    rememberStageCheck:SetValue(DEFAULT_ZONE_REMEMBER_STAGE and 1 or 0)

    local cornerLabel = vgui.Create("DLabel", generalPanel)
    cornerLabel:SetWrap(true)
    cornerLabel:SetText("")

    local pathLabel = vgui.Create("DLabel", generalPanel)
    pathLabel:SetWrap(true)
    pathLabel:SetText("")

    local statusLabel = vgui.Create("DLabel", generalPanel)
    statusLabel:SetWrap(true)
    statusLabel:SetText("")

    generalPanel.PerformLayout = function(_, width)
        nameLabel:SetPos(0, 0)
        nameLabel:SetSize(160, 18)
        nameEntry:SetPos(0, 20)
        nameEntry:SetSize(math.max(260, width - 8), 24)

        onceCheck:SetPos(0, 54)
        enabledCheck:SetPos(260, 54)
        combineCheck:SetPos(0, 78)
        gordonCheck:SetPos(260, 78)
        rememberStageCheck:SetPos(0, 102)

        cornerLabel:SetPos(0, 130)
        cornerLabel:SetSize(width, 18)
        pathLabel:SetPos(0, 150)
        pathLabel:SetSize(width, 18)
        statusLabel:SetPos(0, 170)
        statusLabel:SetSize(width, 18)
    end

    local stageToolbar = vgui.Create("DPanel", rightPanel)
    stageToolbar:Dock(TOP)
    stageToolbar:SetTall(32)
    stageToolbar:DockMargin(0, 0, 0, 8)
    stageToolbar.Paint = nil

    local addStageButton = createEditorButton(stageToolbar, "Add Stage")
    addStageButton:Dock(LEFT)
    addStageButton:DockMargin(0, 0, 8, 0)
    addStageButton:SetWide(120)
    addStageButton.DoClick = function()
        if not selectedZone() then
            addClientStatus("Select a zone first.")
            return
        end

        local stages = collectStagesFromTabs(frame, false) or zoneStageList(selectedZone())
        stages[#stages + 1] = normalizeStage(nil, DEFAULT_HOLD_TIME)
        rebuildStageTabs(frame, stages, #stages)
    end

    local removeStageButton = createEditorButton(stageToolbar, "Remove Current Stage")
    removeStageButton:Dock(LEFT)
    removeStageButton:DockMargin(0, 0, 8, 0)
    removeStageButton:SetWide(170)
    removeStageButton.DoClick = function()
        if not selectedZone() then
            addClientStatus("Select a zone first.")
            return
        end

        local stages = collectStagesFromTabs(frame, false) or zoneStageList(selectedZone())
        if #stages <= 1 then
            addClientStatus("Each zone needs at least one stage.")
            return
        end

        local activeStageIndex = getActiveStageIndex(frame)
        table.remove(stages, activeStageIndex)
        rebuildStageTabs(frame, stages, math.max(1, activeStageIndex - 1))
    end

    local referenceButton = createEditorButton(stageToolbar, "Reference List")
    referenceButton:Dock(LEFT)
    referenceButton:DockMargin(0, 0, 8, 0)
    referenceButton:SetWide(140)
    referenceButton.DoClick = requestReferenceData

    local chromiumButton = createEditorButton(stageToolbar, "Chromium Spawners")
    chromiumButton:Dock(LEFT)
    chromiumButton:DockMargin(0, 0, 8, 0)
    chromiumButton:SetWide(170)
    chromiumButton.DoClick = requestChromiumPresetData

    local testButton = createEditorButton(stageToolbar, "Test Current Stage")
    testButton:Dock(LEFT)
    testButton:SetWide(150)
    testButton.DoClick = function()
        local zone = selectedZone()
        if not zone then
            addClientStatus("Select a zone first.")
            return
        end

        local stage, stageError = buildPrimaryStageFromForm(frame)
        if not stage then
            addClientStatus(stageError)
            return
        end

        local hasTarget = false
        for _, output in ipairs(stageOutputList(stage)) do
            if trimString(output.targetName) ~= "" then
                hasTarget = true
                break
            end
        end

        if not hasTarget then
            addClientStatus("Add at least one output to the current stage first.")
            return
        end

        local zoneName = trimString(frame.NameEntry:GetValue())
        if zoneName == "" then
            zoneName = zone.name
        end

        requestStageTest(zoneName, stage)
        addClientStatus("Sent current stage to the server for a manual test fire.")
    end

    local stageSheet = vgui.Create("DPropertySheet", rightPanel)
    stageSheet:Dock(FILL)
    if stageSheet.SetFadeTime then
        stageSheet:SetFadeTime(0)
    end

    local bottomPanel = vgui.Create("DPanel", rightPanel)
    bottomPanel:Dock(BOTTOM)
    bottomPanel:SetTall(72)
    bottomPanel:DockMargin(0, 8, 0, 0)
    bottomPanel.Paint = nil

    local primaryButtonRow = vgui.Create("DPanel", bottomPanel)
    primaryButtonRow:Dock(TOP)
    primaryButtonRow:SetTall(32)
    primaryButtonRow.Paint = nil

    local secondaryButtonRow = vgui.Create("DPanel", bottomPanel)
    secondaryButtonRow:Dock(BOTTOM)
    secondaryButtonRow:SetTall(32)
    secondaryButtonRow.Paint = nil

    local applyButton = createEditorButton(primaryButtonRow, "Apply Fields")
    applyButton:Dock(LEFT)
    applyButton:DockMargin(0, 0, 8, 0)
    applyButton:SetWide(140)
    applyButton.DoClick = function()
        if not applyForm(frame) then
            return
        end

        persistZoneChanges(frame, "Applied and saved zone fields.")
    end

    local saveButton = createEditorButton(primaryButtonRow, "Save Zones")
    saveButton:Dock(LEFT)
    saveButton:DockMargin(0, 0, 8, 0)
    saveButton:SetWide(140)
    saveButton.DoClick = function()
        if selectedZone() and not applyForm(frame) then
            return
        end

        saveZoneData()
    end

    local refreshButton = createEditorButton(primaryButtonRow, "Reload From Disk")
    refreshButton:Dock(LEFT)
    refreshButton:SetWide(150)
    refreshButton.DoClick = requestZoneData

    local useCornersButton = createEditorButton(secondaryButtonRow, "Use Current Corners")
    useCornersButton:Dock(LEFT)
    useCornersButton:DockMargin(0, 0, 8, 0)
    useCornersButton:SetWide(160)
    useCornersButton.DoClick = function()
        local zone = selectedZone()
        if not zone then
            addClientStatus("Select a zone first.")
            return
        end

        browserZones[selectedIndex] = makeZoneFromCorners(zone)
        persistZoneChanges(frame, "Updated zone bounds and saved changes.")
    end

    local newButton = createEditorButton(secondaryButtonRow, "New From Corners")
    newButton:Dock(LEFT)
    newButton:DockMargin(0, 0, 8, 0)
    newButton:SetWide(150)
    newButton.DoClick = function()
        local zone = makeZoneFromCorners({
            name = string.format("Zone %d", #browserZones + 1),
            inputName = DEFAULT_INPUT,
            once = DEFAULT_ZONE_ONCE,
            enabled = DEFAULT_ZONE_ENABLED,
            allowCombinePlayers = DEFAULT_ZONE_ALLOW_COMBINE,
            allowGordonSolo = DEFAULT_ZONE_ALLOW_GORDON,
            rememberStage = DEFAULT_ZONE_REMEMBER_STAGE,
        })
        if not zone then return end
        browserZones[#browserZones + 1] = zone
        selectedIndex = #browserZones
        persistZoneChanges(frame, string.format("Created and saved zone '%s'.", zone.name))
    end

    local deleteButton = createEditorButton(secondaryButtonRow, "Delete Zone")
    deleteButton:Dock(LEFT)
    deleteButton:SetWide(140)
    deleteButton.DoClick = function()
        if not selectedIndex or not browserZones[selectedIndex] then
            addClientStatus("Select a zone first.")
            return
        end

        local deletedName = browserZones[selectedIndex].name
        table.remove(browserZones, selectedIndex)
        selectedIndex = nil
        persistZoneChanges(frame, string.format("Deleted and saved zone '%s'.", deletedName))
    end

    frame.ZoneList = zoneList
    frame.NameEntry = nameEntry
    frame.OnceCheck = onceCheck
    frame.EnabledCheck = enabledCheck
    frame.CombineCheck = combineCheck
    frame.GordonCheck = gordonCheck
    frame.RememberStageCheck = rememberStageCheck
    frame.CornerLabel = cornerLabel
    frame.PathLabel = pathLabel
    frame.StatusLabel = statusLabel
    frame.StageSheet = stageSheet
    frame.StagePanels = {}

    browserFrame = frame
    refreshZoneList(frame)
end

local function openSequenceHelperBrowser()
    requestZoneData()
end

local function openSequenceHelperReferences()
    requestReferenceData()
end

concommand.Add(CLIENT_BROWSER_COMMAND, openSequenceHelperBrowser)
concommand.Add(LEGACY_BROWSER_COMMAND, openSequenceHelperBrowser)

concommand.Add(CLIENT_REFERENCES_COMMAND, openSequenceHelperReferences)
concommand.Add(LEGACY_REFERENCES_COMMAND, openSequenceHelperReferences)

net.Receive(NET_SEND_DATA, function()
    local json = tostring(net.ReadString() or "[]")
    zoneDataPathLabel = "Data path: " .. tostring(net.ReadString() or "")

    local parsed = util.JSONToTable(json)
    browserZones = {}
    if istable(parsed) then
        for index, zone in ipairs(parsed) do
            browserZones[index] = zoneCopy(zone)
        end
    end

    openZoneBrowser()
end)

net.Receive(NET_SEND_REFERENCES, function()
    local json = tostring(net.ReadString() or "[]")
    local parsed = util.JSONToTable(json)

    browserReferences = {}
    selectedReferenceIndex = nil
    selectedReferenceGraph = nil

    if istable(parsed) then
        for index, reference in ipairs(parsed) do
            browserReferences[index] = {
                name = trimString(reference.name),
                className = trimString(reference.className),
                suggestedInput = trimString(reference.suggestedInput),
                count = tonumber(reference.count) or 1,
                pos = reference.pos or vectorToTable(vector_origin),
            }
        end
    end

    openReferenceBrowser()
end)

net.Receive(NET_SEND_CHROMIUM_PRESETS, function()
    local json = tostring(net.ReadString() or "[]")
    chromiumPresetDataPathLabel = "Chromium data path: " .. tostring(net.ReadString() or "")

    local parsed = util.JSONToTable(json)
    browserChromiumPresets = {}
    selectedChromiumPresetIndex = nil

    if istable(parsed) then
        for index, preset in ipairs(parsed) do
            browserChromiumPresets[index] = {
                name = trimString(preset.name),
                areaCount = math.max(0, tonumber(preset.areaCount) or 0),
                enabled = boolOrDefault(preset.enabled, true),
                autoStart = boolOrDefault(preset.autoStart, false),
                mins = preset.mins or vectorToTable(vector_origin),
                maxs = preset.maxs or vectorToTable(vector_origin),
                origin = preset.origin or vectorToTable(vector_origin),
            }
        end
    end

    openChromiumPresetBrowser()
end)

net.Receive(NET_SEND_REFERENCE_GRAPH, function()
    local json = tostring(net.ReadString() or "{}")
    local parsed = util.JSONToTable(json)
    local reference = selectedReference()

    if not istable(parsed) or not graphMatchesReference(parsed, reference) then
        return
    end

    selectedReferenceGraph = parsed

    if IsValid(referenceFrame) then
        refreshReferenceList(referenceFrame)
    end
end)

net.Receive(NET_EDITOR_STATE, function()
    editorCornerA = net.ReadBool() and net.ReadVector() or nil
    editorCornerB = net.ReadBool() and net.ReadVector() or nil

    if IsValid(browserFrame) then
        updateCornerLabel(browserFrame)
    end
end)

net.Receive(NET_ZONE_PROGRESS, function()
    local zoneId = trimString(net.ReadString())
    local hasPayload = net.ReadBool()

    if zoneId == "" then return end

    if not hasPayload then
        zoneProgressStates[zoneId] = nil
        return
    end

    local parsed = util.JSONToTable(tostring(net.ReadString() or "{}"))
    if not istable(parsed) then
        zoneProgressStates[zoneId] = nil
        return
    end

    parsed.updatedAt = CurTime()
    parsed.expiresAt = parsed.updatedAt + THINK_INTERVAL * 4
    zoneProgressStates[zoneId] = parsed
end)

net.Receive(NET_STATUS, function()
    addClientStatus(net.ReadString())
end)

local function bestZoneProgressState()
    local now = CurTime()
    local bestState
    local bestRemaining = math.huge
    local bestUpdatedAt = -math.huge

    for zoneId, state in pairs(zoneProgressStates) do
        if not istable(state) then
            zoneProgressStates[zoneId] = nil
            continue
        end

        if now > (tonumber(state.expiresAt) or 0) then
            zoneProgressStates[zoneId] = nil
            continue
        end

        local duration = math.max(0, tonumber(state.duration) or 0)
        if duration <= 0 then
            continue
        end

        local updatedAt = tonumber(state.updatedAt) or now
        local elapsed = math.Clamp((tonumber(state.elapsed) or 0) + math.max(0, now - updatedAt), 0, duration)
        local remaining = math.max(0, duration - elapsed)

        if not bestState or remaining < bestRemaining or (remaining == bestRemaining and updatedAt > bestUpdatedAt) then
            bestState = table.Copy(state)
            bestState.elapsed = elapsed
            bestState.remaining = remaining
            bestState.duration = duration
            bestRemaining = remaining
            bestUpdatedAt = updatedAt
        end
    end

    return bestState
end

hook.Add("HUDPaint", "ZC_SequenceHelper_Progress", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local progressState = bestZoneProgressState()
    if not progressState then
        return
    end

    local weapon = ply:GetActiveWeapon()
    local toolActive = IsValid(weapon) and weapon:GetClass() == TOOL_WEAPON_CLASS
    local width = math.min(460, math.floor(ScrW() * 0.36))
    local height = 22
    local x = math.floor((ScrW() - width) * 0.5)
    local y = ScrH() - (toolActive and 152 or 104)
    local progress = progressState.duration > 0 and math.Clamp(progressState.elapsed / progressState.duration, 0, 1) or 1

    draw.RoundedBox(8, x - 10, y - 34, width + 20, 68, Color(8, 8, 12, 210))
    draw.SimpleTextOutlined(string.format("%s | Stage %d/%d", trimString(progressState.zoneName) ~= "" and progressState.zoneName or "Sequence Zone", tonumber(progressState.stageIndex) or 1, tonumber(progressState.stageCount) or 1), "Trebuchet18", x + width * 0.5, y - 20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    surface.SetDrawColor(34, 34, 44, 230)
    surface.DrawRect(x, y, width, height)
    surface.SetDrawColor(235, 132, 28, 245)
    surface.DrawRect(x + 2, y + 2, math.max(0, math.floor((width - 4) * progress)), height - 4)
    draw.SimpleTextOutlined(string.format("%.1fs remaining", math.max(0, tonumber(progressState.remaining) or 0)), "Trebuchet18", x + width * 0.5, y + height * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end)

hook.Add("PostDrawTranslucentRenderables", "ZC_SequenceHelper_Draw", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local weapon = ply:GetActiveWeapon()
    local toolActive = IsValid(weapon) and weapon:GetClass() == TOOL_WEAPON_CLASS
    local graphActive = IsValid(referenceFrame) and referenceFrame:IsVisible() and istable(selectedReferenceGraph) and istable(selectedReferenceGraph.sources)

    if not toolActive and not graphActive then
        return
    end

    local function drawBounds(mins, maxs, color)
        local center = (mins + maxs) * 0.5
        render.DrawWireframeBox(center, angle_zero, mins - center, maxs - center, color, true)
    end

    if toolActive then
        for _, zone in ipairs(browserZones) do
            local mins = zoneVector(zone.mins)
            local maxs = zoneVector(zone.maxs)
            drawBounds(mins, maxs, zone.enabled ~= false and Color(0, 200, 120) or Color(200, 80, 80))
        end

        if isvector(editorCornerA) and isvector(editorCornerB) then
            local mins, maxs = orderedBounds(editorCornerA, editorCornerB)
            drawBounds(mins, maxs, Color(255, 220, 0))
        end
    end

    if not graphActive then
        return
    end

    local sourceColor = Color(80, 220, 255)
    local targetColor = Color(255, 170, 60)
    local lineColor = Color(255, 235, 90)

    local function graphBounds(node)
        local mins = zoneVector(node.mins)
        local maxs = zoneVector(node.maxs)
        if (maxs - mins):LengthSqr() < 1 then
            mins = Vector(-6, -6, -6)
            maxs = Vector(6, 6, 6)
        end
        return mins, maxs
    end

    local function graphLabelPos(node)
        local pos = zoneVector(node.pos)
        local _, maxs = graphBounds(node)
        return pos + Vector(0, 0, maxs.z + 10)
    end

    local function drawGraphNode(node, color)
        local pos = zoneVector(node.pos)
        local mins, maxs = graphBounds(node)
        render.DrawWireframeBox(pos, tableToAngle(node.ang), mins, maxs, color, true)
        render.DrawWireframeSphere(graphLabelPos(node), 3, 8, 8, color)
    end

    local primarySource = selectedReferenceGraph.sources[1]

    for _, source in ipairs(selectedReferenceGraph.sources or {}) do
        drawGraphNode(source, sourceColor)
    end

    if not primarySource then
        return
    end

    local sourceLabelPos = graphLabelPos(primarySource)
    local lineCount = 0

    for _, link in ipairs(selectedReferenceGraph.links or {}) do
        for _, target in ipairs(link.targets or {}) do
            drawGraphNode(target, targetColor)
            render.DrawLine(sourceLabelPos, graphLabelPos(target), lineColor, true)
            lineCount = lineCount + 1
            if lineCount >= 96 then
                return
            end
        end
    end
end)

hook.Add("HUDPaint", "ZC_SequenceHelper_Help", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local weapon = ply:GetActiveWeapon()
    local toolActive = IsValid(weapon) and weapon:GetClass() == TOOL_WEAPON_CLASS
    local graphActive = IsValid(referenceFrame) and referenceFrame:IsVisible() and istable(selectedReferenceGraph) and istable(selectedReferenceGraph.sources)

    if not toolActive and not graphActive then
        return
    end

    local function drawWorldLabel(pos, text, color)
        local screen = pos:ToScreen()
        if not screen.visible then return end

        draw.SimpleTextOutlined(text, "Trebuchet18", screen.x, screen.y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
    end

    if toolActive then
        local x = ScrW() * 0.5
        local y = ScrH() - 98
        draw.SimpleTextOutlined("Primary: set corner A | Secondary: set corner B | Reload: zone browser", "Trebuchet18", x, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
        draw.SimpleTextOutlined("Sequence Helper data persists at garrysmod/data/zcity/sequence_helper/<map>.json", "Trebuchet18", x, y + 22, Color(140, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    end

    if not graphActive then
        return
    end

    local sourceColor = Color(80, 220, 255)
    local targetColor = Color(255, 170, 60)
    local lineColor = Color(255, 235, 90)

    local function graphBounds(node)
        local mins = zoneVector(node.mins)
        local maxs = zoneVector(node.maxs)
        if (maxs - mins):LengthSqr() < 1 then
            mins = Vector(-6, -6, -6)
            maxs = Vector(6, 6, 6)
        end
        return mins, maxs
    end

    local function graphLabelPos(node)
        local pos = zoneVector(node.pos)
        local _, maxs = graphBounds(node)
        return pos + Vector(0, 0, maxs.z + 10)
    end

    local primarySource = selectedReferenceGraph.sources[1]
    if not primarySource then
        return
    end

    for _, source in ipairs(selectedReferenceGraph.sources or {}) do
        drawWorldLabel(graphLabelPos(source), string.format("%s [%s]", source.name ~= "" and source.name or "(unnamed)", source.className ~= "" and source.className or "entity"), sourceColor)
    end

    local sourcePos = graphLabelPos(primarySource)
    local labelCount = 0

    for _, link in ipairs(selectedReferenceGraph.links or {}) do
        for _, target in ipairs(link.targets or {}) do
            local targetPos = graphLabelPos(target)
            local midpoint = LerpVector(0.5, sourcePos, targetPos)
            drawWorldLabel(targetPos, string.format("%s [%s]", target.name ~= "" and target.name or link.targetName, target.className ~= "" and target.className or "entity"), targetColor)
            drawWorldLabel(midpoint, string.format("%s -> %s", link.outputName ~= "" and link.outputName or "OnTrigger", link.inputName ~= "" and link.inputName or "Trigger"), lineColor)
            labelCount = labelCount + 1
            if labelCount >= 32 then
                return
            end
        end
    end
end)