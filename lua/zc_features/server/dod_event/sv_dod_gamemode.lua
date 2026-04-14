-- sv_dod_gamemode.lua — Day of Defeat-style flag capture gamemode.
-- Loaded through the ZC feature bootstrap and activated via !dodstart.

if CLIENT then return end

-- Send DoD client/shared files directly to avoid autorun shim double-loads.
AddCSLuaFile("zc_features/shared/dod_event/sh_dod_gamemode.lua")
AddCSLuaFile("zc_features/client/dod_event/cl_dod_mode.lua")
AddCSLuaFile("zc_features/client/dod_event/cl_dod_classes.lua")
AddCSLuaFile("zc_features/client/dod_event/cl_dod_loadout_editor.lua")
AddCSLuaFile("zc_features/client/dod_event/cl_dod_config_menu.lua")
-- Per-map settings and flag definitions. If a map is not listed here, the mode
-- will fall back to map point editor points (DOD_FLAG_1 through DOD_FLAG_8)

DOD_MAP_CONFIG = DOD_MAP_CONFIG or {}

-- ── Defaults ──────────────────────────────────────────────────────────────────

local DEFAULT_WAVE_INTERVAL = 15
local DEFAULT_ROUND_TIME    = 600   -- 10 minutes
local DEFAULT_NEUTRAL_CAPTURE_TIME = 6   -- 2+ players: neutral (0 -> owned) total time
local DEFAULT_ENEMY_CAPTURE_TIME   = 10  -- 2+ players: enemy-owned (enemy -> your owned) total time
local DEFAULT_RADIUS        = 200
local DEFAULT_REQUIRED_PLAYERS = 2

local DEFAULT_SINGLE_CAP_FLAGS = {
    CP4 = true,
    CP5 = true,
}

-- ── Runtime state ─────────────────────────────────────────────────────────────

local flags        = {}
local waveTimer    = 0
local roundEndTime = 0
local mapCfg       = {}
local matchScore   = { [0] = 0, [1] = 0 }
local dodAutoBalanceEnabled = true

function DOD_ApplyBlackScreenAll(holdTime)
    local hold = holdTime or 8
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0, 255), 0.25, hold)
    end
end

-- ── Persistence ───────────────────────────────────────────────────────────────

local SCORE_PATH = "zcity/dod_match_score.json"
local MAPCFG_PATH = "zcity/dod_runtime_mapcfg.json"
local MAPCFG_PRESET_DIR = "zcity/dodcfg_presets"
local CLASSCFG_PATH = "zcity/dod_class_loadouts.json"
local FLAGENTS_PATH = "zcity/dod_flag_entities.json"
local DOD_RUNTIME_MAPCFG = DOD_RUNTIME_MAPCFG or {}
local DOD_CLASS_LOADOUT_CFG = DOD_CLASS_LOADOUT_CFG or {}
local DOD_CLASS_DEFAULTS = DOD_CLASS_DEFAULTS or {}
local DOD_FLAG_ENTS = DOD_FLAG_ENTS or {}

local function EnsureDataDir()
    if not file.IsDir("zcity", "DATA") then file.CreateDir("zcity") end
end

local function EnsurePresetDir()
    EnsureDataDir()
    if not file.IsDir(MAPCFG_PRESET_DIR, "DATA") then
        file.CreateDir(MAPCFG_PRESET_DIR)
    end
end

local function SanitizePresetName(name)
    local s = string.Trim(tostring(name or ""))
    s = string.lower(s)
    s = string.gsub(s, "[^%w_%-.]", "_")
    s = string.gsub(s, "_+", "_")
    s = string.sub(s, 1, 64)
    return s
end

local function SanitizeMapName(name)
    local s = string.Trim(tostring(name or ""))
    s = string.lower(s)
    s = string.gsub(s, "[^%w_%-]", "")
    s = string.sub(s, 1, 96)
    return s
end

local function SanitizeClassId(name)
    local s = string.Trim(tostring(name or ""))
    s = string.lower(s)
    s = string.gsub(s, "[^%w_%-]", "")
    s = string.sub(s, 1, 64)
    return s
end

local function NormalizeAttachmentKey(name)
    local s = string.Trim(tostring(name or ""))
    s = string.lower(s)
    s = string.gsub(s, "^ent_att_", "")
    s = string.gsub(s, "^att_", "")
    s = string.gsub(s, "[^%w_%-]", "")
    s = string.sub(s, 1, 64)
    return s
end

local function NormalizeLoadoutTeam(token)
    local s = string.lower(string.Trim(tostring(token or "")))
    if s == "axis" or s == "0" or s == "t" then return 0 end
    if s == "allies" or s == "1" or s == "ct" or s == "us" then return 1 end
    return nil
end

local function ParseLoadoutList(raw, isAttachmentList)
    local text = string.Trim(tostring(raw or ""))
    if text == "" then return {} end

    local out = {}
    for token in string.gmatch(text, "[^,%s]+") do
        local item = token
        if isAttachmentList then
            item = NormalizeAttachmentKey(item)
        end
        if item ~= "" and not table.HasValue(out, item) then
            out[#out + 1] = item
        end
    end
    return out
end

local function PresetPath(name)
    return MAPCFG_PRESET_DIR .. "/" .. name .. ".json"
end

local function LoadFlagEntData()
    if not file.Exists(FLAGENTS_PATH, "DATA") then
        DOD_FLAG_ENTS = {}
        return
    end

    local raw = file.Read(FLAGENTS_PATH, "DATA") or ""
    if raw == "" then
        DOD_FLAG_ENTS = {}
        return
    end

    local ok, data = pcall(util.JSONToTable, raw)
    if not ok or not istable(data) then
        DOD_FLAG_ENTS = {}
        return
    end

    DOD_FLAG_ENTS = data
end

local function SaveFlagEntData()
    EnsureDataDir()
    file.Write(FLAGENTS_PATH, util.TableToJSON(DOD_FLAG_ENTS, true))
end

local function GetPlacedFlagsForMap(mapName)
    local t = DOD_FLAG_ENTS[mapName]
    if not istable(t) then return {} end
    return t
end

local function SetPlacedFlagsForMap(mapName, rows)
    DOD_FLAG_ENTS[mapName] = rows or {}
    SaveFlagEntData()
end

local function SpawnPlacedFlagEnt(row, idx)
    if not istable(row) then return nil end

    local ent = ents.Create("zc_dod_flagpoint")
    if not IsValid(ent) then return nil end

    local pos = Vector(tonumber(row.x) or 0, tonumber(row.y) or 0, tonumber(row.z) or 0)
    local ang = Angle(tonumber(row.p) or 0, tonumber(row.yaw) or 0, tonumber(row.r) or 0)
    local name = tostring(row.name or ("CP" .. tostring(idx or 1)))
    local radius = math.max(64, tonumber(row.radius) or DEFAULT_RADIUS)
    local owner = tonumber(row.initOwner)
    if owner ~= 0 and owner ~= 1 then owner = -1 end

    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:Activate()

    ent.DODPersistent = true
    ent.DODMap = game.GetMap()
    ent:SetFlagName(name)
    ent:SetCaptureRadius(radius)
    ent:SetInitialOwner(owner)
    ent:SetFlagOwnerState(owner)

    return ent
end

local function SpawnPlacedFlagsForCurrentMap()
    local mapName = game.GetMap()
    for _, ent in ipairs(ents.FindByClass("zc_dod_flagpoint")) do
        if IsValid(ent) and ent.DODPersistent then
            ent:Remove()
        end
    end

    local rows = GetPlacedFlagsForMap(mapName)
    for i, row in ipairs(rows) do
        SpawnPlacedFlagEnt(row, i)
    end
end

local function SerializePlacedFlagEntsForCurrentMap()
    local mapName = game.GetMap()
    local rows = {}
    for _, ent in ipairs(ents.FindByClass("zc_dod_flagpoint")) do
        if not IsValid(ent) then continue end
        rows[#rows + 1] = {
            name = ent:GetFlagName(),
            x = ent:GetPos().x,
            y = ent:GetPos().y,
            z = ent:GetPos().z,
            p = ent:GetAngles().p,
            yaw = ent:GetAngles().y,
            r = ent:GetAngles().r,
            radius = ent:GetCaptureRadius(),
            initOwner = ent:GetInitialOwner(),
        }
    end

    table.sort(rows, function(a, b)
        local an = tostring(a.name or "")
        local bn = tostring(b.name or "")
        if an == bn then
            return (tonumber(a.x) or 0) < (tonumber(b.x) or 0)
        end
        return an < bn
    end)

    SetPlacedFlagsForMap(mapName, rows)
    return rows
end

local function SnapshotDefaultClassLoadouts()
    for _, cls in ipairs(DOD_CLASSES or {}) do
        local classId = SanitizeClassId(cls.id)
        if classId == "" or DOD_CLASS_DEFAULTS[classId] then continue end
        DOD_CLASS_DEFAULTS[classId] = {
            weapons = table.Copy(cls.weapons or {}),
            attachments = table.Copy(cls.attachments or {}),
            armor = table.Copy(cls.armor or {}),
        }
    end
end

local function EnsureClassLoadoutCfg(classId)
    DOD_CLASS_LOADOUT_CFG[classId] = DOD_CLASS_LOADOUT_CFG[classId] or {
        weapons = {},
        attachments = {},
        armor = {},
    }
    local cfg = DOD_CLASS_LOADOUT_CFG[classId]
    cfg.weapons = cfg.weapons or {}
    cfg.attachments = cfg.attachments or {}
    cfg.armor = cfg.armor or {}
    return cfg
end

local function SaveClassLoadoutCfg()
    EnsureDataDir()
    file.Write(CLASSCFG_PATH, util.TableToJSON(DOD_CLASS_LOADOUT_CFG, true))
end

local function ApplyClassLoadoutOverrides()
    SnapshotDefaultClassLoadouts()

    for _, cls in ipairs(DOD_CLASSES or {}) do
        local classId = SanitizeClassId(cls.id)
        local defaults = DOD_CLASS_DEFAULTS[classId] or {}
        cls.weapons = table.Copy(defaults.weapons or cls.weapons or {})
        cls.attachments = table.Copy(defaults.attachments or cls.attachments or {})
        cls.armor = table.Copy(defaults.armor or cls.armor or {})

        local override = DOD_CLASS_LOADOUT_CFG[classId]
        if istable(override) then
            for teamKey, list in pairs(override.weapons or {}) do
                local teamIdx = tonumber(teamKey)
                if teamIdx ~= nil and istable(list) then
                    cls.weapons[teamIdx] = table.Copy(list)
                end
            end
            for teamKey, list in pairs(override.attachments or {}) do
                local teamIdx = tonumber(teamKey)
                if teamIdx ~= nil and istable(list) then
                    cls.attachments[teamIdx] = table.Copy(list)
                end
            end
            if istable(override.armor) then
                cls.armor = table.Copy(override.armor)
            end
        end
    end
end

local function LoadClassLoadoutCfg()
    SnapshotDefaultClassLoadouts()
    if not file.Exists(CLASSCFG_PATH, "DATA") then
        ApplyClassLoadoutOverrides()
        return
    end

    local raw = file.Read(CLASSCFG_PATH, "DATA") or ""
    if raw == "" then
        ApplyClassLoadoutOverrides()
        return
    end

    local ok, data = pcall(util.JSONToTable, raw)
    if not ok or not istable(data) then
        ApplyClassLoadoutOverrides()
        return
    end

    DOD_CLASS_LOADOUT_CFG = {}
    for classId, override in pairs(data) do
        local cleanClassId = SanitizeClassId(classId)
        if cleanClassId == "" or not DOD_CLASS_BY_ID[cleanClassId] or not istable(override) then continue end

        local dst = EnsureClassLoadoutCfg(cleanClassId)

        for teamKey, list in pairs(override.weapons or {}) do
            local teamIdx = tonumber(teamKey)
            if teamIdx ~= 0 and teamIdx ~= 1 then continue end
            if istable(list) then
                dst.weapons[teamIdx] = ParseLoadoutList(table.concat(list, ","), false)
            end
        end

        for teamKey, list in pairs(override.attachments or {}) do
            local teamIdx = tonumber(teamKey)
            if teamIdx ~= 0 and teamIdx ~= 1 then continue end
            if istable(list) then
                local cleaned = {}
                for _, item in ipairs(list) do
                    local attKey = NormalizeAttachmentKey(item)
                    if attKey ~= "" and not table.HasValue(cleaned, attKey) then
                        cleaned[#cleaned + 1] = attKey
                    end
                end
                dst.attachments[teamIdx] = cleaned
            end
        end

        if istable(override.armor) then
            dst.armor = ParseLoadoutList(table.concat(override.armor, ","), false)
        end
    end

    ApplyClassLoadoutOverrides()
end

local function EnsureMapRuntimeCfg(mapName)
    DOD_RUNTIME_MAPCFG[mapName] = DOD_RUNTIME_MAPCFG[mapName] or {}
    local cfg = DOD_RUNTIME_MAPCFG[mapName]
    cfg.flag_requirements = cfg.flag_requirements or {}
    cfg.single_cap_flags = cfg.single_cap_flags or {}
    cfg.init_owner_overrides = cfg.init_owner_overrides or {}
    return cfg
end

local function EnsureMapConfig(mapName)
    DOD_MAP_CONFIG[mapName] = DOD_MAP_CONFIG[mapName] or {}
    local cfg = DOD_MAP_CONFIG[mapName]
    cfg.flag_requirements = cfg.flag_requirements or {}
    cfg.single_cap_flags = cfg.single_cap_flags or {}
    cfg.init_owner_overrides = cfg.init_owner_overrides or {}
    return cfg
end

local function SaveRuntimeMapCfg()
    EnsureDataDir()
    file.Write(MAPCFG_PATH, util.TableToJSON(DOD_RUNTIME_MAPCFG, true))
end

local function ExportMapPreset(presetName, mapName, cfg)
    EnsurePresetDir()

    local clean = SanitizePresetName(presetName)
    if clean == "" then return false, "invalid preset name" end

    local payload = {
        map = mapName,
        neutral_capture_time = tonumber(cfg.neutral_capture_time) or DEFAULT_NEUTRAL_CAPTURE_TIME,
        enemy_capture_time = tonumber(cfg.enemy_capture_time) or DEFAULT_ENEMY_CAPTURE_TIME,
        wave_interval = tonumber(cfg.wave_interval) or DEFAULT_WAVE_INTERVAL,
        round_time = tonumber(cfg.round_time) or DEFAULT_ROUND_TIME,
        flag_requirements = table.Copy(cfg.flag_requirements or {}),
        single_cap_flags = table.Copy(cfg.single_cap_flags or {}),
        init_owner_overrides = table.Copy(cfg.init_owner_overrides or {}),
    }

    file.Write(PresetPath(clean), util.TableToJSON(payload, true))
    return true, clean
end

local function ImportMapPreset(presetName, targetMap)
    local clean = SanitizePresetName(presetName)
    if clean == "" then return false, "invalid preset name" end

    local path = PresetPath(clean)
    if not file.Exists(path, "DATA") then
        return false, "preset not found"
    end

    local raw = file.Read(path, "DATA") or ""
    local ok, payload = pcall(util.JSONToTable, raw)
    if not ok or not istable(payload) then
        return false, "could not parse preset"
    end

    local cfg = EnsureMapConfig(targetMap)
    local rt = EnsureMapRuntimeCfg(targetMap)

    cfg.neutral_capture_time = tonumber(payload.neutral_capture_time) or DEFAULT_NEUTRAL_CAPTURE_TIME
    cfg.enemy_capture_time = tonumber(payload.enemy_capture_time) or DEFAULT_ENEMY_CAPTURE_TIME
    cfg.wave_interval = tonumber(payload.wave_interval) or DEFAULT_WAVE_INTERVAL
    cfg.round_time = tonumber(payload.round_time) or DEFAULT_ROUND_TIME

    rt.neutral_capture_time = cfg.neutral_capture_time
    rt.enemy_capture_time = cfg.enemy_capture_time
    rt.wave_interval = cfg.wave_interval
    rt.round_time = cfg.round_time

    cfg.flag_requirements = {}
    rt.flag_requirements = {}
    for k, v in pairs(payload.flag_requirements or {}) do
        local n = tonumber(v)
        if n then
            n = math.max(1, math.floor(n))
            cfg.flag_requirements[k] = n
            rt.flag_requirements[k] = n
        end
    end

    cfg.single_cap_flags = {}
    rt.single_cap_flags = {}
    for k, v in pairs(payload.single_cap_flags or {}) do
        local b = tobool(v)
        if b then
            cfg.single_cap_flags[k] = true
            rt.single_cap_flags[k] = true
        end
    end

    cfg.init_owner_overrides = {}
    rt.init_owner_overrides = {}
    for k, v in pairs(payload.init_owner_overrides or {}) do
        local n = tonumber(v)
        if n ~= nil then
            n = math.floor(n)
            if n < -1 then n = -1 end
            if n > 1 then n = 1 end
            cfg.init_owner_overrides[k] = n
            rt.init_owner_overrides[k] = n
        end
    end

    SaveRuntimeMapCfg()
    return true, clean
end

local function LoadRuntimeMapCfg()
    if not file.Exists(MAPCFG_PATH, "DATA") then return end
    local raw = file.Read(MAPCFG_PATH, "DATA") or ""
    if raw == "" then return end
    local ok, data = pcall(util.JSONToTable, raw)
    if not ok or not istable(data) then return end
    DOD_RUNTIME_MAPCFG = data

    for mapName, rt in pairs(DOD_RUNTIME_MAPCFG) do
        if not istable(rt) then continue end
        local cfg = EnsureMapConfig(mapName)
        cfg.neutral_capture_time = tonumber(rt.neutral_capture_time) or cfg.neutral_capture_time
        cfg.enemy_capture_time = tonumber(rt.enemy_capture_time) or cfg.enemy_capture_time
        cfg.wave_interval = tonumber(rt.wave_interval) or cfg.wave_interval
        cfg.round_time = tonumber(rt.round_time) or cfg.round_time

        cfg.flag_requirements = cfg.flag_requirements or {}
        for k, v in pairs(rt.flag_requirements or {}) do
            local n = tonumber(v)
            if n then cfg.flag_requirements[k] = math.max(1, math.floor(n)) end
        end

        cfg.single_cap_flags = cfg.single_cap_flags or {}
        for k, v in pairs(rt.single_cap_flags or {}) do
            cfg.single_cap_flags[k] = tobool(v)
        end

        cfg.init_owner_overrides = cfg.init_owner_overrides or {}
        for k, v in pairs(rt.init_owner_overrides or {}) do
            local n = tonumber(v)
            if n ~= nil then
                n = math.floor(n)
                if n < -1 then n = -1 end
                if n > 1 then n = 1 end
                cfg.init_owner_overrides[k] = n
            end
        end
    end
end

local function SaveMatchScore()
    EnsureDataDir()
    file.Write(SCORE_PATH, util.TableToJSON(matchScore, true))
end

local function LoadMatchScore()
    if not file.Exists(SCORE_PATH, "DATA") then return end
    local ok, t = pcall(util.JSONToTable, file.Read(SCORE_PATH, "DATA") or "")
    if ok and t then
        matchScore[0] = t[0] or t["0"] or 0
        matchScore[1] = t[1] or t["1"] or 0
    end
end

-- ── Flag helpers ──────────────────────────────────────────────────────────────

local function MakeFlag(name, pos, radius, initOwner, requiredPlayers)
    local owner    = initOwner
    local progress = 0.0
    if owner == 0 then progress = -1.0 end
    if owner == 1 then progress =  1.0 end
    return {
        name     = name,
        pos      = pos,
        radius   = radius or DEFAULT_RADIUS,
        initialOwner = owner,
        owner    = owner,
        progress = progress,
        requiredPlayers = math.max(1, math.floor(requiredPlayers or DEFAULT_REQUIRED_PLAYERS)),
    }
end

local function NormalizeFlagKey(name)
    if not name then return "" end
    return string.upper(string.gsub(name, "%s+", ""))
end

local function ResolveRequiredPlayersForFlag(flagName, flagIndex)
    if mapCfg and mapCfg.flag_requirements then
        local key = NormalizeFlagKey(flagName)
        local req = mapCfg.flag_requirements[flagName]
            or mapCfg.flag_requirements[key]
            or mapCfg.flag_requirements[flagIndex]
        if isnumber(req) then
            return math.max(1, math.floor(req))
        end
    end

    if mapCfg and mapCfg.single_cap_flags then
        local key = NormalizeFlagKey(flagName)
        if mapCfg.single_cap_flags[flagName]
            or mapCfg.single_cap_flags[key]
            or mapCfg.single_cap_flags[flagIndex] then
            return 1
        end
    end

    if DEFAULT_SINGLE_CAP_FLAGS[NormalizeFlagKey(flagName)] then
        return 1
    end

    return DEFAULT_REQUIRED_PLAYERS
end

local function ResolveInitialOwnerForFlag(flagName, flagIndex, fallbackOwner)
    local owner = fallbackOwner
    if mapCfg and mapCfg.init_owner_overrides then
        local key = NormalizeFlagKey(flagName)
        local raw = mapCfg.init_owner_overrides[flagName]
            or mapCfg.init_owner_overrides[key]
            or mapCfg.init_owner_overrides[flagIndex]

        local n = tonumber(raw)
        if n ~= nil then
            n = math.floor(n)
            if n < -1 then n = -1 end
            if n > 1 then n = 1 end
            owner = (n == -1) and nil or n
        end
    end
    return owner
end

local function ApplyRuntimeCfgToLiveFlags()
    for i, f in ipairs(flags) do
        f.requiredPlayers = ResolveRequiredPlayersForFlag(f.name, i)
    end
end

local function BuildDoDConfigMenuState()
    local mapName = game.GetMap()
    local cfg = EnsureMapConfig(mapName)

    local state = {
        map = mapName,
        neutral_capture_time = tonumber(cfg.neutral_capture_time) or DEFAULT_NEUTRAL_CAPTURE_TIME,
        enemy_capture_time = tonumber(cfg.enemy_capture_time) or DEFAULT_ENEMY_CAPTURE_TIME,
        wave_interval = tonumber(cfg.wave_interval) or DEFAULT_WAVE_INTERVAL,
        round_time = tonumber(cfg.round_time) or DEFAULT_ROUND_TIME,
        flags = {},
    }

    local menuFlags = {}
    local placed = ents.FindByClass("zc_dod_flagpoint")

    if #placed > 0 then
        table.sort(placed, function(a, b)
            local an = IsValid(a) and a:GetFlagName() or ""
            local bn = IsValid(b) and b:GetFlagName() or ""
            if an == bn then
                return a:EntIndex() < b:EntIndex()
            end
            return an < bn
        end)

        for i, ent in ipairs(placed) do
            if not IsValid(ent) then continue end

            local name = ent:GetFlagName()
            local req = ResolveRequiredPlayersForFlag(name, i)
            local rawOwner = ent:GetInitialOwner()
            local fallbackOwner = (rawOwner == -1) and nil or rawOwner
            local initOwner = ResolveInitialOwnerForFlag(name, i, fallbackOwner)

            menuFlags[#menuFlags + 1] = {
                idx = i,
                name = name,
                requiredPlayers = req,
                originalOwner = initOwner == nil and -1 or initOwner,
            }
        end
    else
        for i, f in ipairs(flags) do
            local initOwner = ResolveInitialOwnerForFlag(f.name, i, f.initialOwner)
            menuFlags[#menuFlags + 1] = {
                idx = i,
                name = f.name,
                requiredPlayers = ResolveRequiredPlayersForFlag(f.name, i),
                originalOwner = initOwner == nil and -1 or initOwner,
            }
        end
    end

    for _, row in ipairs(menuFlags) do
        local i = row.idx
        local key = NormalizeFlagKey(row.name)
        state.flags[#state.flags + 1] = {
            idx = i,
            name = row.name,
            requiredPlayers = row.requiredPlayers,
            originalOwner = row.originalOwner,
            singleCap = row.requiredPlayers <= 1
                or (cfg.single_cap_flags and (cfg.single_cap_flags[i] or cfg.single_cap_flags[key] or cfg.single_cap_flags[row.name]))
                or false,
        }
    end

    return state
end

local function SendDoDConfigMenuState(ply)
    if not IsValid(ply) then return end
    net.Start("DOD_ConfigMenu_State")
        net.WriteTable(BuildDoDConfigMenuState())
    net.Send(ply)
end

local function BuildEffectiveMapCfg(manualCfg, extractedCfg)
    local eff = {
        flag_requirements = {},
        single_cap_flags = {},
        init_owner_overrides = {},
    }

    if istable(extractedCfg) then
        eff.wave_interval = extractedCfg.wave_interval
        eff.round_time = extractedCfg.round_time
        eff.neutral_capture_time = extractedCfg.neutral_capture_time
        eff.enemy_capture_time = extractedCfg.enemy_capture_time
        for k, v in pairs(extractedCfg.flag_requirements or {}) do
            eff.flag_requirements[k] = v
        end
        for k, v in pairs(extractedCfg.single_cap_flags or {}) do
            eff.single_cap_flags[k] = v
        end
        for k, v in pairs(extractedCfg.init_owner_overrides or {}) do
            eff.init_owner_overrides[k] = v
        end
    end

    if istable(manualCfg) then
        eff.wave_interval = tonumber(manualCfg.wave_interval) or eff.wave_interval
        eff.round_time = tonumber(manualCfg.round_time) or eff.round_time
        eff.neutral_capture_time = tonumber(manualCfg.neutral_capture_time) or eff.neutral_capture_time
        eff.enemy_capture_time = tonumber(manualCfg.enemy_capture_time) or eff.enemy_capture_time
        for k, v in pairs(manualCfg.flag_requirements or {}) do
            eff.flag_requirements[k] = v
        end
        for k, v in pairs(manualCfg.single_cap_flags or {}) do
            eff.single_cap_flags[k] = v
        end
        for k, v in pairs(manualCfg.init_owner_overrides or {}) do
            eff.init_owner_overrides[k] = v
        end
    end

    return eff
end

local function PlayersOnFlag(flag, teamIndex)
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        if ply:Team() ~= teamIndex then continue end
        if ply:GetPos():Distance(flag.pos) <= flag.radius then
            count = count + 1
        end
    end
    return count
end

local function OwnerFromProgress(progress)
    if progress <= -1.0 then return 0
    elseif progress >= 1.0 then return 1
    else return nil end
end

local function BroadcastFlagSync()
    local data = {}
    for i, f in ipairs(flags) do
        data[i] = { owner = f.owner, progress = f.progress }
        if IsValid(f.sourceEnt) then
            f.sourceEnt:SetFlagOwnerState(f.owner == nil and -1 or f.owner)
        end
    end
    net.Start("DOD_FlagSync")
        net.WriteUInt(#data, 6)
        for _, d in ipairs(data) do
            net.WriteInt(d.owner == nil and -1 or d.owner, 4)
            net.WriteFloat(d.progress)
        end
    net.Broadcast()
end

local function BroadcastMatchScore()
    net.Start("DOD_MatchScore")
        net.WriteUInt(matchScore[0], 8)
        net.WriteUInt(matchScore[1], 8)
    net.Broadcast()
end

-- ── Flag initialisation ───────────────────────────────────────────────────────

local function InitFlags()
    flags = {}
    local mapName = game.GetMap()

    local cfg = DOD_MAP_CONFIG and DOD_MAP_CONFIG[mapName]
    local extracted = DOD_MapData and DOD_MapData[mapName]

    local cfgHasFlags = istable(cfg) and istable(cfg.flags) and #cfg.flags > 0
    local extractedHasFlags = istable(extracted) and istable(extracted.flags) and #extracted.flags > 0

    mapCfg = BuildEffectiveMapCfg(cfg, extracted)

    local placed = ents.FindByClass("zc_dod_flagpoint")
    if #placed > 0 then
        table.sort(placed, function(a, b)
            local an = IsValid(a) and a:GetFlagName() or ""
            local bn = IsValid(b) and b:GetFlagName() or ""
            if an == bn then
                return a:EntIndex() < b:EntIndex()
            end
            return an < bn
        end)

        for i, ent in ipairs(placed) do
            if not IsValid(ent) then continue end
            local name = ent:GetFlagName()
            local req = ResolveRequiredPlayersForFlag(name, i)
            local rawOwner = ent:GetInitialOwner()
            local fallbackOwner = (rawOwner == -1) and nil or rawOwner
            local initOwner = ResolveInitialOwnerForFlag(name, i, fallbackOwner)
            local f = MakeFlag(name, ent:GetPos(), ent:GetCaptureRadius(), initOwner, req)
            f.sourceEnt = ent
            table.insert(flags, f)
        end

    elseif cfgHasFlags then
        for i, fd in ipairs(cfg.flags) do
            local req = fd.requiredPlayers or ResolveRequiredPlayersForFlag(fd.name, i)
            local initOwner = ResolveInitialOwnerForFlag(fd.name, i, fd.initOwner)
            table.insert(flags, MakeFlag(fd.name, fd.pos, fd.radius, initOwner, req))
        end

    elseif extractedHasFlags then
        for i, fd in ipairs(extracted.flags) do
            local req = fd.requiredPlayers or ResolveRequiredPlayersForFlag(fd.name, i)
            local initOwner = ResolveInitialOwnerForFlag(fd.name, i, fd.initOwner)
            table.insert(flags, MakeFlag(fd.name, fd.pos, fd.radius, initOwner, req))
        end

    else
        local tmpFlags = {}
        for i = 1, 8 do
            local pts = zb.GetMapPoints("DOD_FLAG_" .. i)
            if not pts or #pts == 0 then break end
            table.insert(tmpFlags, { _tmpPos = pts[1].pos, _tmpIdx = i })
        end
        local n = #tmpFlags
        for i, f in ipairs(tmpFlags) do
            local initOwner = nil
            if n > 1 and i == 1 then initOwner = 0
            elseif i == n then initOwner = 1 end
            local fname = "Flag " .. f._tmpIdx
            local req = ResolveRequiredPlayersForFlag(fname, i)
            initOwner = ResolveInitialOwnerForFlag(fname, i, initOwner)
            table.insert(flags, MakeFlag(fname, f._tmpPos, DEFAULT_RADIUS, initOwner, req))
        end
    end

    if #flags == 0 then
        print("[DoD] WARNING: No DoD flags found (placed entities / map config / extracted / DOD_FLAG points).")
    end

    for _, f in ipairs(flags) do
        if IsValid(f.sourceEnt) then
            local owner = f.owner == nil and -1 or f.owner
            f.sourceEnt:SetFlagOwnerState(owner)
            f.sourceEnt:SetCaptureRadius(f.radius)
            f.sourceEnt:SetFlagName(f.name)
            f.sourceEnt:SetInitialOwner(f.initialOwner == nil and -1 or f.initialOwner)
        end
    end

    net.Start("DOD_FlagInit")
        net.WriteUInt(#flags, 6)
        for _, f in ipairs(flags) do
            net.WriteString(f.name)
            net.WriteVector(f.pos)
            net.WriteFloat(f.radius)
            net.WriteInt(f.owner == nil and -1 or f.owner, 4)
            net.WriteFloat(f.progress)
        end
    net.Broadcast()
end

LoadClassLoadoutCfg()
LoadRuntimeMapCfg()
LoadFlagEntData()

hook.Add("InitPostEntity", "DOD_SpawnPlacedFlags", function()
    timer.Simple(0.2, SpawnPlacedFlagsForCurrentMap)
end)

hook.Add("PostCleanupMap", "DOD_SpawnPlacedFlags_Rebuild", function()
    timer.Simple(0.2, SpawnPlacedFlagsForCurrentMap)
end)

-- ── Wave respawn ──────────────────────────────────────────────────────────────

local ApplyDoDClass
local SendClassState
local deadPlayers = {}

local function StartWaveTimer()
    local interval = (mapCfg and mapCfg.wave_interval) or DEFAULT_WAVE_INTERVAL
    waveTimer = CurTime() + interval
end

local function RespawnPlayerDoD(ply, fadeIn)
    if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then return false end

    ply.gottarespawn = true
    ply:Spawn()

    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end

        local cur = CurrentRound and CurrentRound()
        if cur and cur.GetPlySpawn then
            cur:GetPlySpawn(ply)
        end

        if ApplyDoDClass then
            ApplyDoDClass(ply)
        end

        if fadeIn then
            ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 0.35, 0)
        end
    end)

    return true
end

local function DoWaveRespawn()
    local interval = (mapCfg and mapCfg.wave_interval) or DEFAULT_WAVE_INTERVAL
    local spawned = 0
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if ply:Alive() then continue end
        if RespawnPlayerDoD(ply, false) then
            spawned = spawned + 1
        end
    end
    deadPlayers = {}
    waveTimer = CurTime() + interval

    net.Start("DOD_WaveCountdown")
        net.WriteFloat(interval)
        net.WriteFloat(waveTimer)
    net.Broadcast()

    if spawned > 0 then
        print(string.format("[DoD] Wave respawn — %d players", spawned))
    end
end

-- ── Flag capture think ────────────────────────────────────────────────────────

local flagSyncTimer = 0

local function FlagThink(dt)
    for _, f in ipairs(flags) do
        local t0 = PlayersOnFlag(f, 0)
        local t1 = PlayersOnFlag(f, 1)

        local req = f.requiredPlayers or DEFAULT_REQUIRED_PLAYERS

        -- 2+ cap zones: solo presence does nothing at all (no drain/decap).
        -- 1-cap zones are instant pop when uncontested.
        local attackers = nil
        if t0 >= req and t1 == 0 then
            attackers = 0
        elseif t1 >= req and t0 == 0 then
            attackers = 1
        end

        if attackers == nil then continue end

        if req <= 1 then
            local newProgress = attackers == 0 and -1.0 or 1.0
            local oldOwner = f.owner
            local oldProgress = f.progress
            f.progress = newProgress
            f.owner = attackers

            if oldOwner ~= f.owner or oldProgress ~= f.progress then
                local ownerName = DOD_TEAM[attackers] and DOD_TEAM[attackers].name or ("Team " .. attackers)
                local oldName = oldOwner == nil and "neutral"
                    or (DOD_TEAM[oldOwner] and DOD_TEAM[oldOwner].name or ("Team " .. oldOwner))
                PrintMessage(HUD_PRINTTALK, string.format(
                    "[DoD] %s captured by %s (was: %s)", f.name, ownerName, oldName))
            end

            continue
        end

        if f.owner == attackers then
            continue
        end

        -- Neutral capture (0 -> +/-1): 6s total.
        -- Enemy capture (+/-1 -> opposite): 10s total across full bar flip.
        local capTime = (f.owner == nil)
            and ((mapCfg and mapCfg.neutral_capture_time) or DEFAULT_NEUTRAL_CAPTURE_TIME)
            or ((mapCfg and mapCfg.enemy_capture_time) or DEFAULT_ENEMY_CAPTURE_TIME)

        local progressPerSecond = (f.owner == nil) and (1 / capTime) or (2 / capTime)
        local delta = (attackers == 0 and -1 or 1) * progressPerSecond * dt

        if delta ~= 0 then
            f.progress = math.Clamp(f.progress + delta, -1.0, 1.0)

            local newOwner = OwnerFromProgress(f.progress)
            if newOwner ~= f.owner then
                local oldOwner = f.owner
                f.owner = newOwner
                local ownerName = newOwner == nil and "neutral"
                    or (DOD_TEAM[newOwner] and DOD_TEAM[newOwner].name or ("Team " .. newOwner))
                local oldName = oldOwner == nil and "neutral"
                    or (DOD_TEAM[oldOwner] and DOD_TEAM[oldOwner].name or ("Team " .. oldOwner))
                PrintMessage(HUD_PRINTTALK, string.format(
                    "[DoD] %s captured by %s (was: %s)", f.name, ownerName, oldName))
            end
        end
    end

    flagSyncTimer = flagSyncTimer + dt
    if flagSyncTimer >= 0.2 then
        flagSyncTimer = 0
        BroadcastFlagSync()
    end
end

-- ── Win condition ─────────────────────────────────────────────────────────────

local function CountFlagsByOwner()
    local counts = { [0] = 0, [1] = 0, neutral = 0 }
    for _, f in ipairs(flags) do
        if f.owner == 0 then counts[0] = counts[0] + 1
        elseif f.owner == 1 then counts[1] = counts[1] + 1
        else counts.neutral = counts.neutral + 1 end
    end
    return counts
end

local function CheckWinCondition()
    if #flags == 0 then return nil end
    local counts = CountFlagsByOwner()
    local aliveByTeam = { [0] = 0, [1] = 0 }
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        local tm = ply:Team()
        if tm == 0 or tm == 1 then
            aliveByTeam[tm] = aliveByTeam[tm] + 1
        end
    end
    local anyoneAlive = (aliveByTeam[0] + aliveByTeam[1]) > 0

    -- On tiny maps (0/1 flag), skip instant ownership victory to keep wave gameplay meaningful.
    if anyoneAlive and #flags >= 2 then
        if counts[0] == #flags then return 0 end
        if counts[1] == #flags then return 1 end
    end

    local rt = (mapCfg and mapCfg.round_time) or DEFAULT_ROUND_TIME
    if rt > 0 and CurTime() >= roundEndTime then
        if counts[0] > counts[1] then return 0
        elseif counts[1] > counts[0] then return 1
        else return -1 end
    end

    return nil
end

-- ── Class assignment ──────────────────────────────────────────────────────────

local function CountClassOnTeam(classId, teamIndex)
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Team() == teamIndex and ply.DOD_classId == classId then
            count = count + 1
        end
    end
    return count
end

ApplyDoDClass = function(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local classId = ply.DOD_classId or "rifleman"
    local cls     = DOD_CLASS_BY_ID[classId] or DOD_CLASS_BY_ID["rifleman"]
    local teamIdx = ply:Team()
    local td      = DOD_TEAM[teamIdx]

    ply:SetSuppressPickupNotices(true)
    ply.noSound = true

    ply:SetPlayerClass(td and td.playerclass or "terrorist")
    zb.GiveRole(ply, cls.name .. " (" .. (td and td.name or "?") .. ")",
        td and td.roleColor or Color(200, 200, 200))

    local inv = ply:GetNetVar("Inventory", {})
    inv["Weapons"] = inv["Weapons"] or {}
    inv.Attachments = inv.Attachments or {}
    inv["Weapons"]["hg_sling"]      = true
    inv["Weapons"]["hg_flashlight"] = true

    local attList = (cls.attachments and (cls.attachments[teamIdx] or cls.attachments[0])) or {}
    for _, attKey in ipairs(attList) do
        local normalized = NormalizeAttachmentKey(attKey)
        if normalized ~= "" and not table.HasValue(inv.Attachments, normalized) then
            inv.Attachments[#inv.Attachments + 1] = normalized
        end
    end

    ply:SetNetVar("Inventory", inv)

    local wepList = cls.weapons[teamIdx] or cls.weapons[0] or {}
    for _, wclass in ipairs(wepList) do
        local wep = ply:Give(wclass)
        if IsValid(wep) and wep.GetPrimaryAmmoType then
            ply:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType(), true)
        end
    end

    if cls.armor then
        hg.AddArmor(ply, cls.armor)
    end

    ply:Give("weapon_melee")
    local hands = ply:Give("weapon_hands_sh")
    ply:SelectWeapon("weapon_hands_sh")

    local radio = ply:Give("weapon_walkie_talkie")
    if IsValid(radio) then
        radio.Frequency = (teamIdx == 1 and math.Round(math.Rand(88, 95), 1))
            or math.Round(math.Rand(100, 108), 1)
    end

    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        ply.noSound = false
        ply:SetSuppressPickupNotices(false)
    end)
end

net.Receive("DOD_SelectClass", function(len, ply)
    if not IsValid(ply) then return end

    local classId = net.ReadString()

    if classId == "__request_state__" then
        SendClassState(ply)
        net.Start("DOD_OpenClassPicker")
        net.Send(ply)
        return
    end

    if not (zb and zb.CROUND == "dod") then return end

    local cls = DOD_CLASS_BY_ID[classId]
    if not cls then return end

    if cls.maxPerTeam then
        local cur = CountClassOnTeam(classId, ply:Team())
        local selfCount = (ply.DOD_classId == classId) and 1 or 0
        if (cur - selfCount) >= cls.maxPerTeam then
            ply:ChatPrint("[DoD] " .. cls.name .. " is full for your team (" .. cls.maxPerTeam .. " max).")
            return
        end
    end

    ply.DOD_classId = classId
    ply:ChatPrint("[DoD] Class set to " .. cls.name .. ".")

    -- During DoD, spawn immediately after class pick so players can enter the round.
    if ply:Team() ~= TEAM_SPECTATOR and not ply:Alive() then
        RespawnPlayerDoD(ply, true)
    end
end)

SendClassState = function(ply)
    local counts = {}
    for _, cls in ipairs(DOD_CLASSES) do
        counts[cls.id] = {
            [0] = CountClassOnTeam(cls.id, 0),
            [1] = CountClassOnTeam(cls.id, 1),
        }
    end
    net.Start("DOD_ClassState")
        net.WriteTable(counts)
        net.WriteString(ply.DOD_classId or "rifleman")
    net.Send(ply)
end

local function GetSpawnForTeam(teamIdx)
    local groupName = teamIdx == 0 and "HMCD_TDM_T" or "HMCD_TDM_CT"
    local pts = zb.GetMapPoints(groupName)
    if pts and #pts > 0 then
        return zb.TranslatePointsToVectors(pts)
    end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ply:Team() == teamIdx then
            return { ply:GetPos() }
        end
    end
    return nil
end

-- ── MODE table ────────────────────────────────────────────────────────────────

MODE = MODE or {}  -- use global so ZCity's loader/hook system can find it
local MODE = MODE
MODE.name     = "dod"
MODE.PrintName = "Day of Defeat"
MODE.base     = "tdm"

MODE.ROUND_TIME  = DEFAULT_ROUND_TIME
MODE.start_time  = 40
MODE.ForBigMaps  = true
MODE.buymenu     = false

function MODE:CanLaunch()
    local mapName = game.GetMap()
    local cfg = DOD_MAP_CONFIG and DOD_MAP_CONFIG[mapName]
    local extracted = DOD_MapData and DOD_MapData[mapName]
    local placedRows = GetPlacedFlagsForMap(mapName)

    if istable(cfg) and istable(cfg.flags) and #cfg.flags > 0 then return true end
    if istable(extracted) and istable(extracted.flags) and #extracted.flags > 0 then return true end
    if istable(placedRows) and #placedRows > 0 then return true end

    local firstFlag = zb.GetMapPoints("DOD_FLAG_1")
    if firstFlag and #firstFlag > 0 then return true end

    local t = zb.GetMapPoints("HMCD_TDM_T")
    local ct = zb.GetMapPoints("HMCD_TDM_CT")
    return t and #t > 0 and ct and #ct > 0
end

function MODE:OverrideBalance()
    return true
end

function MODE:OverrideSpawn()
    return true
end

local pendingPick = {}
local BroadcastTeamCounts

local function GetTeamCounts()
    local c = { [0] = 0, [1] = 0 }
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if ply:Team() == 0 or ply:Team() == 1 then
            c[ply:Team()] = c[ply:Team()] + 1
        end
    end
    return c
end

local function TeamNameById(teamIdx)
    return (DOD_TEAM[teamIdx] and DOD_TEAM[teamIdx].name) or ("team " .. tostring(teamIdx))
end

local function CanJoinTeamByCount(ply, targetTeam)
    if targetTeam ~= 0 and targetTeam ~= 1 then
        return false, "[DoD] Invalid team."
    end

    local c = GetTeamCounts()
    if IsValid(ply) and ply:Team() == 0 then c[0] = math.max(0, c[0] - 1) end
    if IsValid(ply) and ply:Team() == 1 then c[1] = math.max(0, c[1] - 1) end

    local total = c[0] + c[1]
    local afterJoin = c[targetTeam] + 1
    local maxAllowed = math.ceil((total + 1) / 2)
    if afterJoin > maxAllowed and total > 1 then
        return false, "[DoD] That team is already larger. Join the other team to keep things balanced."
    end

    return true
end

local function SwitchPlayerToDoDTeam(ply, targetTeam)
    if not IsValid(ply) then return false, "[DoD] Invalid player." end
    if not (zb and zb.CROUND == "dod") then return false, "[DoD] DoD is not active." end
    if targetTeam ~= 0 and targetTeam ~= 1 then return false, "[DoD] Invalid team." end
    if ply:Team() == targetTeam then
        return false, "[DoD] You are already on " .. TeamNameById(targetTeam) .. "."
    end

    local ok, err = CanJoinTeamByCount(ply, targetTeam)
    if not ok then return false, err end

    ply:SetTeam(targetTeam)
    pendingPick[ply:SteamID64()] = nil
    BroadcastTeamCounts()

    -- Always reopen class picker after a successful team change.
    -- This guarantees players can re-pick class every time they switch teams.
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        SendClassState(ply)
        net.Start("DOD_OpenClassPicker")
        net.Send(ply)

        -- Fallback resend in case client was still transitioning UI focus.
        timer.Simple(0.35, function()
            if not IsValid(ply) then return end
            SendClassState(ply)
            net.Start("DOD_OpenClassPicker")
            net.Send(ply)
        end)
    end)

    if zb.ROUND_STATE == 0 then
        return true, "[DoD] Switched to " .. TeamNameById(targetTeam) .. ". Now pick your class!"
    end

    if ply:Alive() then
        ply:KillSilent()
    end
    ply.gottarespawn = true

    return true, "[DoD] Switched to " .. TeamNameById(targetTeam) .. ". Pick class now; you will spawn on next wave."
end

BroadcastTeamCounts = function()
    local c = GetTeamCounts()
    net.Start("DOD_TeamCounts")
        net.WriteUInt(c[0], 8)
        net.WriteUInt(c[1], 8)
    net.Broadcast()
end

local function OpenTeamPickerFor(ply)
    if not IsValid(ply) then return end
    local c = GetTeamCounts()
    net.Start("DOD_OpenTeamPicker")
        net.WriteUInt(c[0], 8)
        net.WriteUInt(c[1], 8)
    net.Send(ply)
end

local function DoAutoBalance()
    if not dodAutoBalanceEnabled then return end

    local c = GetTeamCounts()
    local total = c[0] + c[1]
    if total < 2 then return end

    local maxAllowed = math.ceil(total / 2)
    local bigTeam, smallTeam
    if c[0] > maxAllowed then bigTeam, smallTeam = 0, 1
    elseif c[1] > maxAllowed then bigTeam, smallTeam = 1, 0
    else return end

    local excess = (bigTeam == 0 and c[0] or c[1]) - maxAllowed

    local dead, alive = {}, {}
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or ply:Team() ~= bigTeam then continue end
        if not ply:Alive() then
            table.insert(dead, ply)
        else
            table.insert(alive, ply)
        end
    end

    local moved = 0
    for _, ply in ipairs(dead) do
        if moved >= excess then break end
        ply:SetTeam(smallTeam)
        ply:ChatPrint("[DoD] You were moved to " ..
            (DOD_TEAM[smallTeam] and DOD_TEAM[smallTeam].name or "the other team") ..
            " to balance teams.")
        moved = moved + 1
    end
    for _, ply in ipairs(alive) do
        if moved >= excess then break end
        ply:SetTeam(smallTeam)
        ply:ChatPrint("[DoD] You were moved to " ..
            (DOD_TEAM[smallTeam] and DOD_TEAM[smallTeam].name or "the other team") ..
            " to balance teams.")
        moved = moved + 1
    end

    if moved > 0 then
        PrintMessage(HUD_PRINTTALK, string.format("[DoD] Autobalance moved %d player(s).", moved))
        BroadcastTeamCounts()
    end
end

function MODE:Intermission()
    game.CleanUpMap()
    LoadMatchScore()

    flags       = {}
    waveTimer   = 0
    pendingPick = {}

    local mapName  = game.GetMap()
    local manualCfg = DOD_MAP_CONFIG and DOD_MAP_CONFIG[mapName]
    local extracted = DOD_MapData  and DOD_MapData[mapName]
    local rt = (manualCfg and manualCfg.round_time)
            or (extracted and extracted.round_time and extracted.round_time > 0 and extracted.round_time)
            or DEFAULT_ROUND_TIME
    roundEndTime = rt > 0 and (CurTime() + rt + MODE.start_time) or 0

    DOD_ApplyBlackScreenAll(MODE.start_time + 8)

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        ply:SetTeam(TEAM_SPECTATOR)
        if ply:Alive() then ply:KillSilent() end
        pendingPick[ply:SteamID64()] = true
    end

    timer.Simple(1, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then OpenTeamPickerFor(ply) end
        end
    end)

    InitFlags()
    BroadcastMatchScore()
    BroadcastTeamCounts()

    print("[DoD] Intermission — " .. #flags .. " flag(s) on " .. game.GetMap())
end

function MODE:RoundStart()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if pendingPick[ply:SteamID64()] then
            local c = GetTeamCounts()
            local assigned = (c[0] <= c[1]) and 0 or 1
            ply:SetTeam(assigned)
            ply:ChatPrint("[DoD] Auto-assigned to " ..
                (DOD_TEAM[assigned] and DOD_TEAM[assigned].name or "a team") .. ".")
            pendingPick[ply:SteamID64()] = nil
        end
    end

    DoAutoBalance()

    -- Ensure everyone on a valid DoD team is alive when round starts.
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if ply:Team() ~= 0 and ply:Team() ~= 1 then continue end
        if not ply:Alive() then
            RespawnPlayerDoD(ply, false)
        end
    end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then ply:Freeze(false) end
    end
    StartWaveTimer()

    local interval = (mapCfg and mapCfg.wave_interval) or DEFAULT_WAVE_INTERVAL
    net.Start("DOD_WaveCountdown")
        net.WriteFloat(interval)
        net.WriteFloat(waveTimer)
    net.Broadcast()
end

function MODE:GiveEquipment()
    timer.Simple(0.1, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                ApplyDoDClass(ply)
            end
        end
    end)
end

function MODE:GetTeamSpawn()
    return zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_T")),
           zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_CT"))
end

function MODE:GetPlySpawn(ply)
    local teamIdx   = ply:Team()
    local extracted = DOD_MapData and DOD_MapData[game.GetMap()]
    local spawns

    if extracted then
        local rawSpawns = (teamIdx == 0) and extracted.axisSpawns or extracted.alliesSpawns
        if rawSpawns and #rawSpawns > 0 then
            local sp = rawSpawns[math.random(#rawSpawns)]
            ply:SetPos(sp.pos)
            ply:SetEyeAngles(sp.ang)
            return
        end
    end

    spawns = GetSpawnForTeam(teamIdx)
    if spawns and #spawns > 0 then
        ply:SetPos(spawns[math.random(#spawns)])
    end
end

function MODE:CanSpawn()
    return false
end

function MODE:PlayerDeath(ply)
    deadPlayers[ply:SteamID64()] = true
end

function MODE:ShouldRoundEnd()
    if CurTime() < (zb.ROUND_START or 0) + 5 then return false end
    return CheckWinCondition() ~= nil
end

function MODE:RoundThink()
    local now = CurTime()
    local dt  = FrameTime()

    FlagThink(dt)

    if waveTimer > 0 and now >= waveTimer then
        DoWaveRespawn()
    end
end

function MODE:EndRound()
    local winner = CheckWinCondition()

    local winnerName
    if winner == -1 or winner == nil then
        winnerName = "Nobody (Draw)"
    else
        winnerName = (DOD_TEAM[winner] and DOD_TEAM[winner].name) or ("Team " .. winner)
        matchScore[winner] = (matchScore[winner] or 0) + 1
        SaveMatchScore()
    end

    local counts = CountFlagsByOwner()
    PrintMessage(HUD_PRINTTALK, string.format(
        "[DoD] Round over — %s wins!  Flags: Axis %d / Allies %d  |  Match: Axis %d - %d Allies",
        winnerName, counts[0], counts[1], matchScore[0], matchScore[1]))

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if winner ~= nil and winner ~= -1 and ply:Team() == winner then
            ply:GiveExp(math.random(15, 30))
            ply:GiveSkill(math.Rand(0.1, 0.15))
        else
            ply:GiveSkill(-math.Rand(0.05, 0.1))
        end
    end

    net.Start("DOD_RoundResult")
        net.WriteInt(winner == nil and -1 or winner, 4)
        net.WriteString(winnerName)
        net.WriteUInt(counts[0], 6)
        net.WriteUInt(counts[1], 6)
    net.Broadcast()

    BroadcastMatchScore()

    timer.Simple(2, function()
        net.Start("tdm_roundend")
        net.Broadcast()
    end)
end

hook.Add("PlayerInitialSpawn", "DOD_NewPlayerTeamPick", function(ply)
    if IsValid(ply) and not ply.DOD_InfoInit then
        ply:SetNWBool("DOD_ShowInfo", true)
        ply.DOD_InfoInit = true
    end

    timer.Simple(2, function()
        if not IsValid(ply) then return end
        if not (zb and zb.CROUND == "dod") then return end
        if zb.ROUND_STATE ~= 0 then return end
        ply:SetTeam(TEAM_SPECTATOR)
        pendingPick[ply:SteamID64()] = true
        OpenTeamPickerFor(ply)
    end)
end)

hook.Add("PlayerDisconnected", "DOD_TeamPickCleanup", function(ply)
    pendingPick[ply:SteamID64()] = nil
end)

net.Receive("DOD_JoinTeam", function(len, ply)
    if not IsValid(ply) then return end
    if not (zb and zb.CROUND == "dod") then return end
    if zb.ROUND_STATE ~= 0 then
        ply:ChatPrint("[DoD] Teams are locked once the round starts.")
        return
    end

    local teamIdx = net.ReadUInt(2)
    if teamIdx ~= 0 and teamIdx ~= 1 then return end

    local ok, msg = SwitchPlayerToDoDTeam(ply, teamIdx)
    ply:ChatPrint(msg or "[DoD] Team change failed.")
    if not ok then return end
end)

local function SendDoDLoadoutList(admin)
    net.Start("DOD_LoadoutEditor_List")
        net.WriteUInt(#DOD_CLASSES, 8)
        for _, cls in ipairs(DOD_CLASSES) do
            net.WriteString(cls.id or "")
            net.WriteString(cls.name or "")
            net.WriteString(cls.desc or "")
            net.WriteUInt(cls.maxPerTeam or 0, 8)

            for _, teamIdx in ipairs({ 0, 1 }) do
                local weps = cls.weapons[teamIdx] or {}
                net.WriteUInt(#weps, 8)
                for _, item in ipairs(weps) do
                    net.WriteString(item)
                end
            end

            for _, teamIdx in ipairs({ 0, 1 }) do
                local atts = (cls.attachments and cls.attachments[teamIdx]) or {}
                net.WriteUInt(#atts, 8)
                for _, item in ipairs(atts) do
                    net.WriteString(item)
                end
            end

            local armor = cls.armor or {}
            net.WriteUInt(#armor, 8)
            for _, item in ipairs(armor) do
                net.WriteString(item)
            end
        end
    net.Send(admin)
end

local function OpenDoDLoadoutEditorFor(admin)
    if not IsValid(admin) or not admin:IsAdmin() then return end
    SendDoDLoadoutList(admin)
    net.Start("DOD_LoadoutEditor_Open")
    net.Send(admin)
end

local function PushDoDLoadoutEditorToAdmins()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:IsAdmin() then continue end
        SendDoDLoadoutList(ply)
        net.Start("DOD_LoadoutEditor_Saved")
        net.Send(ply)
    end
end

net.Receive("DOD_LoadoutEditor_Edit", function(len, admin)
    if not IsValid(admin) or not admin:IsAdmin() then return end

    local op = net.ReadString()
    local classId = SanitizeClassId(net.ReadString())
    local teamIdx = net.ReadInt(3)
    local arg = net.ReadString()
    local cls = DOD_CLASS_BY_ID[classId]

    if not cls then
        admin:ChatPrint("[DoD] Unknown class id.")
        return
    end

    if op == "reset" then
        DOD_CLASS_LOADOUT_CFG[classId] = nil
        ApplyClassLoadoutOverrides()
        SaveClassLoadoutCfg()
        PushDoDLoadoutEditorToAdmins()
        admin:ChatPrint("[DoD] Reset loadout overrides for " .. classId .. ".")
        return
    end

    local cfg = EnsureClassLoadoutCfg(classId)

    if op == "addweapon" then
        if teamIdx ~= 0 and teamIdx ~= 1 then return end
        local weaponId = string.Trim(arg)
        if weaponId == "" then return end
        cfg.weapons[teamIdx] = cfg.weapons[teamIdx] or table.Copy(cls.weapons[teamIdx] or {})
        cfg.weapons[teamIdx][#cfg.weapons[teamIdx] + 1] = weaponId
    elseif op == "removeweapon" then
        if teamIdx ~= 0 and teamIdx ~= 1 then return end
        local index = tonumber(arg)
        cfg.weapons[teamIdx] = cfg.weapons[teamIdx] or table.Copy(cls.weapons[teamIdx] or {})
        if not index or not cfg.weapons[teamIdx][index] then return end
        table.remove(cfg.weapons[teamIdx], index)
    elseif op == "addattachment" then
        if teamIdx ~= 0 and teamIdx ~= 1 then return end
        local attKey = NormalizeAttachmentKey(arg)
        if attKey == "" then return end
        cfg.attachments[teamIdx] = cfg.attachments[teamIdx] or table.Copy((cls.attachments and cls.attachments[teamIdx]) or {})
        cfg.attachments[teamIdx][#cfg.attachments[teamIdx] + 1] = attKey
    elseif op == "removeattachment" then
        if teamIdx ~= 0 and teamIdx ~= 1 then return end
        local index = tonumber(arg)
        cfg.attachments[teamIdx] = cfg.attachments[teamIdx] or table.Copy((cls.attachments and cls.attachments[teamIdx]) or {})
        if not index or not cfg.attachments[teamIdx][index] then return end
        table.remove(cfg.attachments[teamIdx], index)
    elseif op == "addarmor" then
        local armorKey = string.Trim(arg)
        if armorKey == "" then return end
        cfg.armor = cfg.armor or table.Copy(cls.armor or {})
        cfg.armor[#cfg.armor + 1] = armorKey
    elseif op == "removearmor" then
        local index = tonumber(arg)
        cfg.armor = cfg.armor or table.Copy(cls.armor or {})
        if not index or not cfg.armor[index] then return end
        table.remove(cfg.armor, index)
    else
        admin:ChatPrint("[DoD] Unknown loadout edit op.")
        return
    end

    ApplyClassLoadoutOverrides()
    SaveClassLoadoutCfg()
    PushDoDLoadoutEditorToAdmins()
end)

net.Receive("DOD_ConfigMenu_Request", function(_, admin)
    if not IsValid(admin) or not admin:IsAdmin() then return end
    SendDoDConfigMenuState(admin)
end)

net.Receive("DOD_ConfigMenu_Open", function(_, admin)
    if not IsValid(admin) or not admin:IsAdmin() then return end
    net.Start("DOD_ConfigMenu_Open")
    net.Send(admin)
    SendDoDConfigMenuState(admin)
end)

net.Receive("DOD_ConfigMenu_Apply", function(_, admin)
    if not IsValid(admin) or not admin:IsAdmin() then return end

    local payload = net.ReadTable()
    if not istable(payload) then return end

    local mapName = game.GetMap()
    local cfg = EnsureMapConfig(mapName)
    local rt = EnsureMapRuntimeCfg(mapName)

    local neutral = tonumber(payload.neutral_capture_time)
    local enemy = tonumber(payload.enemy_capture_time)
    local wave = tonumber(payload.wave_interval)
    local round = tonumber(payload.round_time)

    if neutral and neutral > 0 then
        cfg.neutral_capture_time = neutral
        rt.neutral_capture_time = neutral
    end
    if enemy and enemy > 0 then
        cfg.enemy_capture_time = enemy
        rt.enemy_capture_time = enemy
    end
    if wave and wave > 0 then
        cfg.wave_interval = wave
        rt.wave_interval = wave
        mapCfg.wave_interval = wave
    end
    if round and round > 0 then
        cfg.round_time = round
        rt.round_time = round
        mapCfg.round_time = round
        if zb and zb.CROUND == "dod" then
            roundEndTime = CurTime() + round
        end
    end

    cfg.flag_requirements = cfg.flag_requirements or {}
    rt.flag_requirements = rt.flag_requirements or {}
    cfg.single_cap_flags = cfg.single_cap_flags or {}
    rt.single_cap_flags = rt.single_cap_flags or {}
    cfg.init_owner_overrides = cfg.init_owner_overrides or {}
    rt.init_owner_overrides = rt.init_owner_overrides or {}

    if istable(payload.flags) then
        for _, row in ipairs(payload.flags) do
            if not istable(row) then continue end

            local idx = tonumber(row.idx)
            local req = tonumber(row.requiredPlayers)
            if idx and idx >= 1 and req then
                req = math.max(1, math.floor(req))
                local name = (flags[idx] and flags[idx].name) or (row.name and tostring(row.name)) or ("CP" .. idx)
                local key = NormalizeFlagKey(name)
                local isSingle = tobool(row.singleCap) or req <= 1
                local finalReq = isSingle and 1 or req

                cfg.flag_requirements[idx] = finalReq
                rt.flag_requirements[idx] = finalReq
                cfg.flag_requirements[key] = finalReq
                rt.flag_requirements[key] = finalReq
                cfg.flag_requirements[name] = finalReq
                rt.flag_requirements[name] = finalReq

                if isSingle then
                    cfg.single_cap_flags[idx] = true
                    rt.single_cap_flags[idx] = true
                    cfg.single_cap_flags[key] = true
                    rt.single_cap_flags[key] = true
                    cfg.single_cap_flags[name] = true
                    rt.single_cap_flags[name] = true
                else
                    cfg.single_cap_flags[idx] = nil
                    rt.single_cap_flags[idx] = nil
                    cfg.single_cap_flags[key] = nil
                    rt.single_cap_flags[key] = nil
                    cfg.single_cap_flags[name] = nil
                    rt.single_cap_flags[name] = nil
                end

                local ownerRaw = tonumber(row.originalOwner)
                if ownerRaw ~= nil then
                    ownerRaw = math.floor(ownerRaw)
                    if ownerRaw < -1 then ownerRaw = -1 end
                    if ownerRaw > 1 then ownerRaw = 1 end

                    cfg.init_owner_overrides[idx] = ownerRaw
                    rt.init_owner_overrides[idx] = ownerRaw
                    cfg.init_owner_overrides[key] = ownerRaw
                    rt.init_owner_overrides[key] = ownerRaw
                    cfg.init_owner_overrides[name] = ownerRaw
                    rt.init_owner_overrides[name] = ownerRaw

                    if flags[idx] then
                        local liveOwner = (ownerRaw == -1) and nil or ownerRaw
                        flags[idx].initialOwner = liveOwner
                        flags[idx].owner = liveOwner
                        flags[idx].progress = (liveOwner == 0 and -1.0) or (liveOwner == 1 and 1.0) or 0.0
                    end
                end
            end
        end
    end

    mapCfg = BuildEffectiveMapCfg(cfg, mapCfg)
    ApplyRuntimeCfgToLiveFlags()
    BroadcastFlagSync()
    SaveRuntimeMapCfg()

    admin:ChatPrint("[DoD] Config menu changes applied for " .. mapName .. ".")
    SendDoDConfigMenuState(admin)
end)

COMMANDS.dodclass = {function(ply, args)
    SendClassState(ply)
    net.Start("DOD_OpenClassPicker")
    net.Send(ply)
end, 0, "— open class picker"}

COMMANDS.dodscore = {function(ply, args)
    LoadMatchScore()
    ply:ChatPrint(string.format("[DoD] Match score — Axis: %d  Allies: %d",
        matchScore[0], matchScore[1]))
end, 0}

COMMANDS.dodteam = {function(ply, args)
    if not IsValid(ply) then return end
    if not (zb and zb.CROUND == "dod") then
        ply:ChatPrint("[DoD] DoD is not active.")
        return
    end

    local token = string.lower(tostring(args[1] or ""))
    local curTeam = ply:Team()
    local targetTeam = nil

    if token == "" or token == "swap" or token == "switch" then
        if curTeam == 0 then targetTeam = 1
        elseif curTeam == 1 then targetTeam = 0
        else
            local c = GetTeamCounts()
            targetTeam = (c[0] <= c[1]) and 0 or 1
        end
    elseif token == "axis" or token == "0" or token == "t" then
        targetTeam = 0
    elseif token == "allies" or token == "1" or token == "ct" then
        targetTeam = 1
    else
        ply:ChatPrint("[DoD] Usage: !dodteam [axis|allies|swap]")
        return
    end

    local ok, msg = SwitchPlayerToDoDTeam(ply, targetTeam)
    ply:ChatPrint(msg or "[DoD] Team change failed.")
end, 0, "[axis/allies/swap] — switch team if playercount allows"}

COMMANDS.dodbalance = {function(ply, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("[DoD] Admins only.") end
        return
    end

    local token = string.lower(tostring(args[1] or ""))
    local nextVal = nil

    if token == "" or token == "toggle" then
        nextVal = not dodAutoBalanceEnabled
    elseif token == "on" or token == "1" or token == "true" then
        nextVal = true
    elseif token == "off" or token == "0" or token == "false" then
        nextVal = false
    elseif token == "status" then
        ply:ChatPrint("[DoD] Autobalance is currently " .. (dodAutoBalanceEnabled and "enabled" or "disabled") .. ".")
        return
    else
        ply:ChatPrint("[DoD] Usage: !dodbalance [on|off|toggle|status]")
        return
    end

    dodAutoBalanceEnabled = nextVal
    PrintMessage(HUD_PRINTTALK, "[DoD] Autobalance " .. (nextVal and "enabled" or "disabled") .. " by " .. ply:Nick() .. ".")

    if nextVal then
        DoAutoBalance()
    end
end, 1, "[on/off/toggle/status] — control DoD autobalance"}

COMMANDS.dodloadout = {function(ply, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("[DoD] Admins only.") end
        return
    end

    OpenDoDLoadoutEditorFor(ply)
end, 1, "— open DoD loadout editor"}

COMMANDS.dodcfgmenu = {function(ply, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("[DoD] Admins only.") end
        return
    end

    net.Start("DOD_ConfigMenu_Open")
    net.Send(ply)
    SendDoDConfigMenuState(ply)
end, 1, "— open DoD flag config menu"}

local function ParseOwnerToken(token)
    local t = string.lower(string.Trim(tostring(token or "")))
    if t == "" or t == "neutral" or t == "none" or t == "-1" then return -1 end
    if t == "axis" or t == "0" or t == "t" then return 0 end
    if t == "allies" or t == "1" or t == "ct" then return 1 end
    return nil
end

COMMANDS.dodflag_place = {function(ply, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("[DoD] Admins only.") end
        return
    end

    local tr = ply:GetEyeTrace()
    if not tr or not tr.HitPos then
        ply:ChatPrint("[DoD] Could not find a valid placement point.")
        return
    end

    local owner = ParseOwnerToken(args[3])
    if owner == nil then owner = -1 end

    local radius = tonumber(args[2]) or DEFAULT_RADIUS
    radius = math.Clamp(radius, 64, 1024)

    local existing = ents.FindByClass("zc_dod_flagpoint")
    local name = string.Trim(tostring(args[1] or ""))
    if name == "" then
        name = "CP" .. tostring(#existing + 1)
    end

    local ent = ents.Create("zc_dod_flagpoint")
    if not IsValid(ent) then
        ply:ChatPrint("[DoD] Failed to create flag entity.")
        return
    end

    ent:SetPos(tr.HitPos + Vector(0, 0, 8))
    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ent:Spawn()
    ent:Activate()

    ent.DODPersistent = true
    ent.DODMap = game.GetMap()
    ent:SetFlagName(name)
    ent:SetCaptureRadius(radius)
    ent:SetInitialOwner(owner)
    ent:SetFlagOwnerState(owner)

    -- If DoD is already running, rebuild live flags so this new point
    -- immediately captures and appears in client HUD flag bars.
    if zb and zb.CROUND == "dod" then
        InitFlags()
        BroadcastFlagSync()
    end

    ply:ChatPrint(string.format("[DoD] Placed flag entity '%s' (radius %d, owner %d).", name, radius, owner))
end, 1, "[name] [radius] [neutral|axis|allies] — place DoD flagpoint entity"}

COMMANDS.dodflag_save = {function(ply, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("[DoD] Admins only.") end
        return
    end

    local rows = SerializePlacedFlagEntsForCurrentMap()
    ply:ChatPrint(string.format("[DoD] Saved %d flag entities for map %s.", #rows, game.GetMap()))
end, 1, "— save current DoD flagpoint entities for this map"}

COMMANDS.dodflag_reload = {function(ply, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("[DoD] Admins only.") end
        return
    end

    LoadFlagEntData()
    SpawnPlacedFlagsForCurrentMap()
    if zb and zb.CROUND == "dod" then
        InitFlags()
        BroadcastFlagSync()
    end

    local count = #ents.FindByClass("zc_dod_flagpoint")
    ply:ChatPrint(string.format("[DoD] Reloaded %d flag entities for %s.", count, game.GetMap()))
end, 1, "— reload DoD flagpoint entities from saved file"}

COMMANDS.dodflag_clear = {function(ply, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("[DoD] Admins only.") end
        return
    end

    local n = 0
    for _, ent in ipairs(ents.FindByClass("zc_dod_flagpoint")) do
        if not IsValid(ent) then continue end
        ent:Remove()
        n = n + 1
    end

    SetPlacedFlagsForMap(game.GetMap(), {})
    if zb and zb.CROUND == "dod" then
        InitFlags()
        BroadcastFlagSync()
    end

    ply:ChatPrint(string.format("[DoD] Removed %d placed flag entities and cleared saved data for this map.", n))
end, 1, "— remove and clear saved DoD flagpoint entities for this map"}

COMMANDS.dodresetscore = {function(ply, args)
    if not ply:IsAdmin() then ply:ChatPrint("Admins only.") return end
    matchScore = { [0] = 0, [1] = 0 }
    SaveMatchScore()
    BroadcastMatchScore()
    PrintMessage(HUD_PRINTTALK, "[DoD] Match score reset by " .. ply:Nick() .. ".")
end, 1}

COMMANDS.dodinfo = {function(ply, args)
    local cur = ply:GetNWBool("DOD_ShowInfo", true)
    local desired = nil
    local a1 = args[1] and string.lower(args[1]) or nil
    if a1 == "on" or a1 == "1" or a1 == "true" then desired = true end
    if a1 == "off" or a1 == "0" or a1 == "false" then desired = false end

    local nextVal = desired
    if nextVal == nil then nextVal = not cur end
    ply:SetNWBool("DOD_ShowInfo", nextVal)
    ply:ChatPrint("[DoD] Command overlay " .. (nextVal and "enabled" or "disabled") .. ".")
end, 0, "[on/off] — toggle DoD command overlay"}

COMMANDS.dodconfig = {function(ply, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("[DoD] Admins only.") end
        return
    end

    local mapName = game.GetMap()
    local cfg = EnsureMapConfig(mapName)
    local rt = EnsureMapRuntimeCfg(mapName)

    local function usage()
        ply:ChatPrint("[DoD] !dodconfig show")
        ply:ChatPrint("[DoD] !dodconfig req <cpN|flagName|index> <players>")
        ply:ChatPrint("[DoD] !dodconfig single <cpN|flagName|index> <on|off>")
        ply:ChatPrint("[DoD] !dodconfig neutral <seconds>")
        ply:ChatPrint("[DoD] !dodconfig enemy <seconds>")
        ply:ChatPrint("[DoD] !dodconfig wave <seconds>")
        ply:ChatPrint("[DoD] !dodconfig round <seconds>")
        ply:ChatPrint("[DoD] !dodconfig presets")
        ply:ChatPrint("[DoD] !dodconfig export <preset>")
        ply:ChatPrint("[DoD] !dodconfig import <preset> [map]")
        ply:ChatPrint("[DoD] !dodconfig preload <map> <preset>")
        ply:ChatPrint("[DoD] !dodconfig save")
    end

    local sub = args[1] and string.lower(args[1]) or "show"
    local function normFlagToken(token)
        local raw = token or ""
        local up = NormalizeFlagKey(raw)
        local idx = tonumber(raw) or tonumber(up:match("^CP(%d+)$")) or tonumber(up:match("^FLAG(%d+)$"))
        if idx then
            return idx, "CP" .. idx
        end
        return nil, up
    end

    if sub == "help" then
        usage()
        return
    elseif sub == "show" or sub == "list" then
        ply:ChatPrint("[DoD] Config for " .. mapName .. ":")
        ply:ChatPrint(string.format("  neutral=%ss enemy=%ss wave=%ss round=%ss",
            tostring(cfg.neutral_capture_time or DEFAULT_NEUTRAL_CAPTURE_TIME),
            tostring(cfg.enemy_capture_time or DEFAULT_ENEMY_CAPTURE_TIME),
            tostring(cfg.wave_interval or DEFAULT_WAVE_INTERVAL),
            tostring(cfg.round_time or DEFAULT_ROUND_TIME)))
        if #flags > 0 then
            for i, f in ipairs(flags) do
                ply:ChatPrint(string.format("  %s (idx %d): req=%d", f.name, i, f.requiredPlayers or DEFAULT_REQUIRED_PLAYERS))
            end
        end
        return
    elseif sub == "req" then
        local token = args[2]
        local req = tonumber(args[3] or "")
        if not token or not req then usage() return end
        req = math.max(1, math.floor(req))
        local idx, key = normFlagToken(token)
        cfg.flag_requirements[key] = req
        rt.flag_requirements[key] = req
        if idx then
            cfg.flag_requirements[idx] = req
            rt.flag_requirements[idx] = req
        end
        if req == 1 then
            cfg.single_cap_flags[key] = true
            rt.single_cap_flags[key] = true
            if idx then
                cfg.single_cap_flags[idx] = true
                rt.single_cap_flags[idx] = true
            end
        else
            cfg.single_cap_flags[key] = nil
            rt.single_cap_flags[key] = nil
            if idx then
                cfg.single_cap_flags[idx] = nil
                rt.single_cap_flags[idx] = nil
            end
        end
        ApplyRuntimeCfgToLiveFlags()
        SaveRuntimeMapCfg()
        ply:ChatPrint(string.format("[DoD] %s requirement set to %d.", key, req))
        return
    elseif sub == "single" then
        local token = args[2]
        local val = args[3] and string.lower(args[3])
        if not token or (val ~= "on" and val ~= "off" and val ~= "1" and val ~= "0" and val ~= "true" and val ~= "false") then usage() return end
        local on = (val == "on" or val == "1" or val == "true")
        local idx, key = normFlagToken(token)
        cfg.single_cap_flags[key] = on or nil
        rt.single_cap_flags[key] = on or nil
        cfg.flag_requirements[key] = on and 1 or nil
        rt.flag_requirements[key] = on and 1 or nil
        if idx then
            cfg.single_cap_flags[idx] = on or nil
            rt.single_cap_flags[idx] = on or nil
            cfg.flag_requirements[idx] = on and 1 or nil
            rt.flag_requirements[idx] = on and 1 or nil
        end
        ApplyRuntimeCfgToLiveFlags()
        SaveRuntimeMapCfg()
        ply:ChatPrint(string.format("[DoD] %s single-cap %s.", key, on and "enabled" or "disabled"))
        return
    elseif sub == "neutral" then
        local t = tonumber(args[2] or "")
        if not t or t <= 0 then usage() return end
        cfg.neutral_capture_time = t
        rt.neutral_capture_time = t
        mapCfg.neutral_capture_time = t
        SaveRuntimeMapCfg()
        ply:ChatPrint(string.format("[DoD] Neutral capture time set to %.2fs.", t))
        return
    elseif sub == "enemy" then
        local t = tonumber(args[2] or "")
        if not t or t <= 0 then usage() return end
        cfg.enemy_capture_time = t
        rt.enemy_capture_time = t
        mapCfg.enemy_capture_time = t
        SaveRuntimeMapCfg()
        ply:ChatPrint(string.format("[DoD] Enemy capture time set to %.2fs.", t))
        return
    elseif sub == "wave" then
        local t = tonumber(args[2] or "")
        if not t or t <= 0 then usage() return end
        cfg.wave_interval = t
        rt.wave_interval = t
        mapCfg.wave_interval = t
        SaveRuntimeMapCfg()
        ply:ChatPrint(string.format("[DoD] Wave interval set to %.2fs.", t))
        return
    elseif sub == "round" then
        local t = tonumber(args[2] or "")
        if not t or t <= 0 then usage() return end
        cfg.round_time = t
        rt.round_time = t
        mapCfg.round_time = t
        SaveRuntimeMapCfg()
        ply:ChatPrint(string.format("[DoD] Round time set to %.2fs.", t))
        return
    elseif sub == "presets" then
        EnsurePresetDir()
        local files = file.Find(MAPCFG_PRESET_DIR .. "/*.json", "DATA") or {}
        if #files == 0 then
            ply:ChatPrint("[DoD] No presets found.")
            return
        end
        ply:ChatPrint("[DoD] Presets:")
        for _, fn in ipairs(files) do
            ply:ChatPrint("  - " .. string.StripExtension(fn))
        end
        return
    elseif sub == "export" then
        local preset = args[2]
        if not preset then usage() return end
        local ok, res = ExportMapPreset(preset, mapName, cfg)
        if not ok then
            ply:ChatPrint("[DoD] Export failed: " .. tostring(res))
            return
        end
        ply:ChatPrint("[DoD] Exported preset '" .. res .. "' from map " .. mapName .. ".")
        return
    elseif sub == "import" then
        local preset = args[2]
        if not preset then usage() return end
        local targetMap = SanitizeMapName(args[3])
        if targetMap == "" then targetMap = mapName end
        local ok, res = ImportMapPreset(preset, targetMap)
        if not ok then
            ply:ChatPrint("[DoD] Import failed: " .. tostring(res))
            return
        end
        if targetMap == mapName and (mapCfg == cfg or (zb and zb.CROUND == "dod")) then
            mapCfg = EnsureMapConfig(mapName)
            ApplyRuntimeCfgToLiveFlags()
        end
        ply:ChatPrint("[DoD] Imported preset '" .. res .. "' into map " .. targetMap .. ".")
        return
    elseif sub == "preload" then
        local targetMap = SanitizeMapName(args[2])
        local preset = args[3]
        if targetMap == "" or not preset then usage() return end
        local ok, res = ImportMapPreset(preset, targetMap)
        if not ok then
            ply:ChatPrint("[DoD] Preload failed: " .. tostring(res))
            return
        end
        if targetMap == mapName and (mapCfg == cfg or (zb and zb.CROUND == "dod")) then
            mapCfg = EnsureMapConfig(mapName)
            ApplyRuntimeCfgToLiveFlags()
        end
        ply:ChatPrint("[DoD] Preloaded preset '" .. res .. "' for map " .. targetMap .. ".")
        return
    elseif sub == "save" then
        SaveRuntimeMapCfg()
        ply:ChatPrint("[DoD] Runtime map config saved.")
        return
    end

    usage()
end, 1, "show/req/single/neutral/enemy/wave/round/presets/export/import/preload/save"}

MODE.Chance = 0

local function RegisterDoDMode()
    if not (zb and zb.modes) then return false end
    if zb.modes["dod"] then return true end  -- already registered

    -- Replicate what ZCity's InitMode() does in loader.lua
    if MODE.base and zb.modes[MODE.base] then
        table.Inherit(MODE, zb.modes[MODE.base])
        for i, tbl in pairs(MODE) do
            if istable(MODE[i]) and istable(zb.modes[MODE.base][i]) then
                local tbl2 = {}
                table.CopyFromTo(MODE[i], tbl2)
                MODE[i] = tbl2
            end
        end
        if MODE.AfterBaseInheritance then MODE:AfterBaseInheritance() end
    end

    zb.modes["dod"] = MODE
    zb.ModesChances = zb.ModesChances or {}
    zb.ModesChances["dod"] = zb.ModesChances["dod"] or MODE.Chance or 0

    -- Register hooks so ZCity's hook.Call override dispatches to our functions
    zb.modesHooks = zb.modesHooks or {}
    zb.modesHooks["dod"] = zb.modesHooks["dod"] or {}
    for k, v in pairs(MODE) do
        if isfunction(v) then zb.modesHooks["dod"][k] = v end
    end

    print("[DoD] Mode registered into zb.modes.")
    return true
end

-- Expose registration for ULX command safety checks.
_G.DOD_RegisterMode = RegisterDoDMode

if not RegisterDoDMode() then
    -- Retry after core gamemode tables exist.
    hook.Add("Think", "DOD_RegisterModeDeferred", function()
        if RegisterDoDMode() then
            hook.Remove("Think", "DOD_RegisterModeDeferred")
            print("[DoD] Registered mode table after deferred init.")
        end
    end)
end

print("[DoD] Server gamemode loaded (waiting for activation via !dodstart)")
