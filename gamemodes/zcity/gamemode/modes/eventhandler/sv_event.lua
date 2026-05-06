local MODE = MODE

MODE.name = "event"
MODE.PrintName = "Event"
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.randomSpawns = true

MODE.ForBigMaps = true
MODE.Chance = 0

MODE.EndLogicType = 2 
MODE.EventersList = {} 
MODE.LootEnabled = true
MODE.ContainerAutoRefillEnabled = true
MODE.CustomWildcardGroups = MODE.CustomWildcardGroups or {}
MODE.WildcardOverrides   = MODE.WildcardOverrides   or {}
MODE.ModelLootProfiles = MODE.ModelLootProfiles or {}
MODE.ModelLootCaps = MODE.ModelLootCaps or {}
MODE.ModelLootMins = MODE.ModelLootMins or {}
MODE.ContainerLootOverrides = MODE.ContainerLootOverrides or {}
MODE.ContainerModelWhitelist = MODE.ContainerModelWhitelist or {}
-- Per-class blacklist / whitelist for the GLOBAL event loot pool. Mirrors
-- ZRP LootEditor's per-class toggles. Blacklisted classes never roll;
-- if any whitelist entry exists, only whitelisted classes may roll.
MODE.LootBlacklist = MODE.LootBlacklist or {}
MODE.LootWhitelist = MODE.LootWhitelist or {}

-- Seeded the first time we load (or whenever the saved whitelist is empty).
-- Only props on this list will be auto-adopted as containers when staff spawn
-- them during an event round. Admins can extend the list at runtime via the
-- Container Manager menu.
MODE.ContainerModelWhitelistDefaults = {
    "models/props/cs_office/shelves_metal3.mdl",
    "models/props/cs_office/shelves_metal1.mdl",
    "models/props/cs_office/shelves_metal2.mdl",
    "models/props_industrial/warehouse_shelf001.mdl",
    "models/props_industrial/warehouse_shelf002.mdl",
    "models/props_industrial/warehouse_shelf003.mdl",
    "models/props_industrial/warehouse_shelf004.mdl",
    "models/props/de_nuke/crate_extralarge.mdl",
    "models/props/de_nuke/crate_extrasmall.mdl",
    "models/props/de_nuke/crate_large.mdl",
    "models/props/cs_militia/crate_extralargemill.mdl",
    "models/props/cs_militia/crate_extrasmallmill.mdl",
    "models/props/de_prodigy/prodcratesb.mdl",
    "models/props/cs_militia/footlocker01_closed.mdl",
    "models/props/cs_office/file_cabinet1_group.mdl",
    "models/props/de_nuke/file_cabinet1_group.mdl",
    "models/props/cs_office/file_cabinet1.mdl",
    "models/props_c17/woodbarrel001.mdl",
    "models/props_c17/oildrum001.mdl",
    "models/props_junk/wood_crate001a.mdl",
    "models/props_junk/wood_crate001a_damaged.mdl",
    "models/props_junk/wood_crate001a_damagedmax.mdl",
    "models/props_junk/cardboard_box001a.mdl",
    "models/props_junk/cardboard_box001a_gib01.mdl",
    "models/props_junk/cardboard_box003a.mdl",
    "models/props_junk/cardboard_box003a_gib01.mdl",
    "models/props_junk/trashdumpster01a.mdl",
    "models/props_lab/filecabinet02.mdl",
    "models/props_wasteland/controlroom_filecabinet001a.mdl",
    "models/props_wasteland/controlroom_filecabinet002a.mdl",
    "models/props_wasteland/controlroom_storagecloset001a.mdl",
    "models/props_wasteland/controlroom_storagecloset001b.mdl",
    "models/props_c17/furniturestove001a.mdl",
    "models/props_junk/wood_crate002a.mdl",
    "models/props_wasteland/kitchen_fridge001a.mdl",
    "models/props_c17/lockers001a.mdl",
    "models/props/de_train/lockers_long.mdl",
}

function MODE:NormalizeContainerModel(model)
    local m = string.lower(string.Trim(tostring(model or "")))
    m = string.gsub(m, "\\\\", "/")
    return m
end

function MODE:IsContainerModelWhitelisted(model)
    model = self:NormalizeContainerModel(model)
    if model == "" then return false end
    return self.ContainerModelWhitelist[model] == true
end

function MODE:SeedContainerModelWhitelistIfEmpty()
    if next(self.ContainerModelWhitelist) ~= nil then return end
    for _, mdl in ipairs(self.ContainerModelWhitelistDefaults or {}) do
        local norm = self:NormalizeContainerModel(mdl)
        if norm ~= "" then
            self.ContainerModelWhitelist[norm] = true
        end
    end
end

local radius = nil
local mapsize = 7500
local EVENT_CONTAINER_REFILL_INTERVAL = 300
local EVENT_CONTAINER_REFILL_TIMER = "EventContainerRefillTimer"

util.AddNetworkString("event_start")
util.AddNetworkString("event_end")
util.AddNetworkString("event_eventers_update")
util.AddNetworkString("event_loot_update")
util.AddNetworkString("event_loot_sync")
util.AddNetworkString("event_loot_add")
util.AddNetworkString("event_loot_remove")
util.AddNetworkString("event_loot_request")
util.AddNetworkString("event_loot_settings_sync")
util.AddNetworkString("event_loot_settings_set")
util.AddNetworkString("event_loot_wildcards_sync")
util.AddNetworkString("event_loot_wildcard_set")
util.AddNetworkString("event_loot_wildcard_remove")
util.AddNetworkString("event_loot_wildcard_overrides_sync")
util.AddNetworkString("event_loot_wildcard_contents_request")
util.AddNetworkString("event_loot_wildcard_contents_sync")
util.AddNetworkString("event_loot_wildcard_contents_set")
util.AddNetworkString("event_container_list_request")
util.AddNetworkString("event_container_list_sync")
util.AddNetworkString("event_container_action")
util.AddNetworkString("event_loot_blacklist_set")
util.AddNetworkString("event_loot_whitelist_set")
util.AddNetworkString("event_loot_bw_sync")
util.AddNetworkString("event_container_set_loot")
util.AddNetworkString("event_model_loot_profiles_sync")
util.AddNetworkString("event_model_loot_profile_set")
util.AddNetworkString("event_model_loot_profile_remove")
util.AddNetworkString("event_model_loot_cap_set")
util.AddNetworkString("event_model_loot_min_set")
util.AddNetworkString("event_container_whitelist_set")
util.AddNetworkString("ZC_EventRespawnTimer")

local eventRespawnsEnabled = ConVarExists("zb_event_respawns")
    and GetConVar("zb_event_respawns")
    or CreateConVar("zb_event_respawns", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Enable timed player respawns during Event mode.", 0, 1)

local eventRespawnDelay = ConVarExists("zb_event_respawn_delay")
    and GetConVar("zb_event_respawn_delay")
    or CreateConVar("zb_event_respawn_delay", "10", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Respawn delay in seconds for Event mode when zb_event_respawns=1.", 0, 120)

local function EventRespawnTimerName(ply)
    return "EventRespawn_" .. tostring(IsValid(ply) and ply:EntIndex() or 0)
end

local function IsEventRoundPlaying()
    return CurrentRound and CurrentRound() and CurrentRound().name == "event" and zb.ROUND_STATE == 1
end

local function SendEventRespawnTimer(ply, timeRemaining)
    if not IsValid(ply) then return end
    net.Start("ZC_EventRespawnTimer")
        net.WriteFloat(timeRemaining)
    net.Send(ply)
end

function MODE:GetEventRespawnPoint(excludePos)
    local points = zb.GetMapPoints("EVENT_SPAWN") or {}
    if #points == 0 then
        points = zb.GetMapPoints("Spawnpoint") or {}
    end
    if #points == 0 then
        points = zb.GetMapPoints("RandomSpawns") or {}
    end

    if #points == 0 then return nil, nil end

    local candidates = {}
    for _, point in ipairs(points) do
        if istable(point) and isvector(point.pos) then
            if not isvector(excludePos) or point.pos:DistToSqr(excludePos) > 4 then
                candidates[#candidates + 1] = point
            end
        end
    end

    local pool = (#candidates > 0) and candidates or points
    local pick = table.Random(pool)
    if not istable(pick) then return nil, nil end

    return pick.pos, pick.ang
end

function MODE:CanLaunch()
    return true
end

function MODE:Intermission()
	game.CleanUpMap()

	for k, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then
			continue
		end
		
		ApplyAppearance(ply)
		ply:SetupTeam(0)
	end

	local rndpoints = zb.GetMapPoints("RandomSpawns")
	zonepoint = table.Random(rndpoints)

	net.Start("event_start")
	net.Broadcast()
end

function MODE:CheckAlivePlayers()
	local AlivePlyTbl = {}
	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		if ply.organism and ply.organism.incapacitated then continue end
		AlivePlyTbl[#AlivePlyTbl + 1] = ply
	end
	return AlivePlyTbl
end

function MODE:ShouldRoundEnd()
    if self.EndLogicType == 1 then
        local aliveCount = 0
        local eventerCount = 0
        
        for _, ply in ipairs(zb:CheckAlive(true)) do
            aliveCount = aliveCount + 1
            if self.EventersList[ply:SteamID()] then
                eventerCount = eventerCount + 1
            end
        end
        
        return (aliveCount == eventerCount)
    elseif self.EndLogicType == 2 then
        return (#zb:CheckAlive(true) <= 1)
    elseif self.EndLogicType == 3 then
        return false
    end
    
    return (#zb:CheckAlive(true) <= 1) 
end

function MODE:RoundStart()
    self.EventersList = {}
    for _, ply in player.Iterator() do
        if ply:IsAdmin() then
            self.EventersList[ply:SteamID()] = true
        end
    end
    
    net.Start("event_eventers_update")
    local data = {}
    for id, _ in pairs(self.EventersList) do
        table.insert(data, id)
    end
    net.WriteTable(data)
    net.Broadcast()

    local lastSpawnPos = nil

	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end

        local spawnPos, spawnAng = self:GetEventRespawnPoint(lastSpawnPos)
        if isvector(spawnPos) then
            ply:SetPos(spawnPos)
            ply:SetLocalVelocity(vector_origin)
            lastSpawnPos = spawnPos
        end
        if isangle(spawnAng) then
            ply:SetEyeAngles(spawnAng)
        end

		ply:SetSuppressPickupNotices(true)
		ply.noSound = true
		local hands = ply:Give("weapon_hands_sh")
		ply:SelectWeapon("weapon_hands_sh")

		timer.Simple(0.1,function()
			ply.noSound = false
		end)

		ply:SetSuppressPickupNotices(false)
        
        if self.EventersList[ply:SteamID()] then
            zb.GiveRole(ply, "Eventer", Color(50, 200, 50))
        else
            zb.GiveRole(ply, GetGlobalString("ZB_EventRole","Player"), Color(190,15,15))
        end
	end

    if self.LootEnabled then
        self:RefreshContainerLoot(true)
    end

    self:ConfigureContainerRefillTimer()
end

function MODE:GiveWeapons()
end

function MODE:GiveEquipment()
end

function MODE:RoundThink()
	if (zb.ROUND_START or 0) + 20 < CurTime() then
		-- radius = (mapsize * math.max(( (zb.ROUND_START + 300) - CurTime()) / 300,0.025))
		-- for _, ent in ents.Iterator() do
		-- 	if ent:GetPos():Distance( zonepoint and zonepoint.pos or Vector(0,0,0)) > radius then
		-- 		MakeDissolver( ent, ent:GetPos(), 0 )
		-- 	end
		-- end
	end
end

MODE.LootTable = {
    {50, {
        {4,"weapon_leadpipe"},
        {3,"weapon_hg_crowbar"},
        {2,"weapon_tomahawk"},
        {2,"weapon_hatchet"},
        {1,"weapon_hg_axe"},
        {1,"weapon_hg_crossbow"},
    }},
    {50, {
        {9,"*ammo*"},
        {9,"weapon_hk_usp"},
        {8,"weapon_revolver357"},
        {8,"weapon_deagle"},
        {8,"weapon_doublebarrel_short"},
        {8,"weapon_doublebarrel"},
        {8,"weapon_remington870"},
        {8,"weapon_glock18c"},
        {7,"weapon_mp5"},
        {6,"weapon_xm1014"},
        {6,"ent_armor_vest3"},
        {5,"ent_armor_helmet1"},
        {5,"weapon_mp7"},
        {5,"weapon_sks"},
        {5,"ent_armor_vest4"},
        {5,"weapon_hg_molotov_tpik"},
        {5,"weapon_hg_pipebomb_tpik"},
        {5,"weapon_claymore"},
        {5,"weapon_hg_f1_tpik"},
        {5,"weapon_traitor_ied"},
        {5,"weapon_hg_slam"},
        {5,"weapon_hg_legacy_grenade_shg"},
        {5,"weapon_hg_grenade_tpik"},
        {5,"weapon_ptrd"},
        {5,"weapon_akm"},
        {5,"weapon_m98b"},
        {2,"weapon_hg_rpg"},
        {3,"weapon_sr25"},
    }},
}

MODE.CustomLootTable = {
    {50, {}}
}

function MODE:GetLootTable()
    if self.CustomLootTable[1][2] and #self.CustomLootTable[1][2] > 0 then
        return self.CustomLootTable[1][2]
    end
    
    return self.LootTable[2][2]
end

function MODE:NormalizeWildcardToken(token)
    local t = string.lower(string.Trim(tostring(token or "")))
    t = string.gsub(t, "^%*", "")
    t = string.gsub(t, "%*$", "")
    t = string.gsub(t, "[^%w_]", "")
    if t == "" then return nil end
    return "*" .. t .. "*"
end

function MODE:NormalizeWildcardEntries(entries)
    local out = {}
    local seen = {}

    for _, className in ipairs(entries or {}) do
        className = string.lower(string.Trim(tostring(className or "")))
        if className == "" then continue end
        if string.match(className, "^%*[%w_]+%*$") then continue end
        if seen[className] then continue end
        seen[className] = true
        out[#out + 1] = className
    end

    table.sort(out)
    return out
end

function MODE:NormalizeLootEntries(entries)
    local out = {}
    for _, row in ipairs(entries or {}) do
        local weight = tonumber(row[1]) or tonumber(row.weight) or 0
        local className = string.lower(string.Trim(tostring(row[2] or row.class or "")))
        if weight > 0 and className ~= "" then
            out[#out + 1] = { math.Round(weight), className }
        end
    end
    return out
end

function MODE:ExpandLootEntries(entries, allowFallback)
    local filtered = {}

    for _, entry in ipairs(self:NormalizeLootEntries(entries)) do
        local weight = tonumber(entry[1]) or 0
        local className = string.lower(string.Trim(tostring(entry[2] or "")))

        local isWildcard = string.match(className, "^%*[%w_]+%*$")

        -- 1. Manual wildcard override (admin-edited contents take priority).
        if weight > 0 and isWildcard and istable(self.WildcardOverrides[className])
            and #self.WildcardOverrides[className] > 0 then
            for _, groupedClass in ipairs(self.WildcardOverrides[className]) do
                filtered[#filtered + 1] = { weight, groupedClass }
            end
        elseif weight > 0 and isWildcard and self.CustomWildcardGroups[className] then
            for _, groupedClass in ipairs(self.CustomWildcardGroups[className]) do
                filtered[#filtered + 1] = { weight, groupedClass }
            end
        elseif weight > 0 and (
            string.StartWith(className, "weapon_")
            or string.StartWith(className, "ent_ammo_")
            or string.StartWith(className, "ent_armor_")
            or string.StartWith(className, "ent_att_")
            or className == "*ammo*"
            or className == "*attachments*"
            or className == "*sight*"
            or className == "*barrel*"
            or isWildcard
        ) then
            filtered[#filtered + 1] = { weight, className }
        end
    end

    if allowFallback and #filtered == 0 then
        filtered = table.Copy(self.LootTable[2][2] or {})
    end

    -- Apply per-class blacklist/whitelist filters for the GLOBAL pool only.
    -- (Per-model and per-container overrides are intentionally exempt so admins
    -- can intentionally include a class for a single container even if it's
    -- globally blacklisted.) `allowFallback` is set to true exclusively from
    -- BuildContainerLootData, which is the global-pool entry point.
    if allowFallback then
        local hasWL = next(self.LootWhitelist or {}) ~= nil
        local out = {}
        for _, e in ipairs(filtered) do
            local cls = string.lower(string.Trim(tostring(e[2] or "")))
            if cls == "" then continue end
            if self.LootBlacklist and self.LootBlacklist[cls] then continue end
            if hasWL and not self.LootWhitelist[cls] then continue end
            out[#out + 1] = e
        end
        filtered = out
    end

    return filtered
end

function MODE:GetContainerKey(kind, idx)
    return tostring(kind) .. ":" .. tostring(tonumber(idx) or 0)
end

-- Mark every prop_physics* with a non-empty model that lives in the world
-- during an event round as event-adopted, then ensure WorldContainerData has
-- an entry at its position. Returns the number of newly adopted props.
-- Does not touch any networked vars (safe to call from anywhere).
function MODE:ScanAndAdoptStaffContainers()
    if not ZRP then return 0 end
    if not IsEventRoundPlaying() then return 0 end
    if not self.ContainerAutoRefillEnabled then return 0 end

    ZRP.WorldContainerData = ZRP.WorldContainerData or {}

    local added = 0
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        local class = ent:GetClass()
        if class ~= "prop_physics" and class ~= "prop_physics_multiplayer"
            and class ~= "prop_physics_override" then continue end

        local model = string.lower(tostring(ent:GetModel() or ""))
        if model == "" then continue end

        local hasOwner = false
        if ent.CPPIGetOwner then
            local o = ent:CPPIGetOwner()
            if IsValid(o) and o:IsPlayer() then hasOwner = true end
        end
        if not hasOwner and ent.Getowning_ent then
            local o = ent:Getowning_ent()
            if IsValid(o) and o:IsPlayer() then hasOwner = true end
        end
        if not hasOwner and not ent.ZRP_AdoptedByEvent then continue end

        -- Only adopt props on the container model whitelist so spawning
        -- furniture, ragdolls, decoration etc. doesn't turn them into loot.
        if not self:IsContainerModelWhitelisted(model) then continue end

        ent.ZRP_AdoptedByEvent = true

        local pos = ent:GetPos()
        local foundIdx = nil
        for idx, d in ipairs(ZRP.WorldContainerData) do
            if string.lower(tostring(d.model or "")) == model
                and isvector(d.pos) and d.pos:Distance(pos) <= 48 then
                foundIdx = idx
                break
            end
        end

        if not foundIdx then
            ZRP.WorldContainerData[#ZRP.WorldContainerData + 1] = {
                model        = model,
                pos          = pos,
                respawnDelay = EVENT_CONTAINER_REFILL_INTERVAL,
                lootOverride = {},
                auto         = true,
            }
            added = added + 1
        end
    end

    if added > 0 and ZRP.ActivateWorldContainers then
        ZRP.ActivateWorldContainers()
    end

    return added
end

function MODE:SyncEventContainerTracking(spawnStaticContainers)
    if not ZRP then return end

    if (not istable(ZRP.Containers) or #ZRP.Containers == 0) and ZRP.LoadContainers then
        ZRP.LoadContainers()
    end

    if (not istable(ZRP.WorldContainerData) or #ZRP.WorldContainerData == 0) and ZRP.LoadWorldContainers then
        ZRP.LoadWorldContainers()
    end

    if ZRP.RebuildAutoWorldContainers then
        ZRP.RebuildAutoWorldContainers(EVENT_CONTAINER_REFILL_INTERVAL)
    end

    if ZRP.ActivateWorldContainers then
        ZRP.ActivateWorldContainers()
    end

    if spawnStaticContainers and ZRP.SpawnAllContainers and IsEventRoundPlaying() then
        local hasActive = false
        for _, ent in pairs(ZRP.ActiveContainers or {}) do
            if IsValid(ent) then
                hasActive = true
                break
            end
        end
        if not hasActive then
            ZRP.SpawnAllContainers()
        end
    end
end

function MODE:ResolveWorldContainerEntity(idx)
    local data = ZRP and ZRP.WorldContainerData and ZRP.WorldContainerData[idx] or nil
    if not data then return nil end

    local state = ZRP.WorldContainerState and ZRP.WorldContainerState[idx] or nil
    local ent = state and ents.GetByIndex(state.entindex or 0) or NULL
    if IsValid(ent) then return ent end

    local model = string.lower(tostring(data.model or ""))
    if model == "" or not isvector(data.pos) then return nil end

    local best, bestDist = nil, 96
    for _, cand in ipairs(ents.GetAll()) do
        if not IsValid(cand) then continue end
        if cand:GetClass() == "zrp_container" then continue end
        if string.lower(tostring(cand:GetModel() or "")) ~= model then continue end
        local d = cand:GetPos():Distance(data.pos)
        if d < bestDist then
            bestDist = d
            best = cand
        end
    end

    return best
end

function MODE:SendModelLootProfiles(ply)
    if IsValid(ply) and not ply:IsAdmin() and not self.EventersList[ply:SteamID()] then return end

    net.Start("event_model_loot_profiles_sync")
    net.WriteTable(self.ModelLootProfiles or {})
    net.WriteTable(self.ModelLootCaps or {})
    net.WriteTable(self.ContainerModelWhitelist or {})
    net.WriteTable(self.ModelLootMins or {})
    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

-- Per-class blacklist/whitelist sync (ZRP LootEditor parity).
function MODE:SendLootBlacklistWhitelist(ply)
    if IsValid(ply) and not ply:IsAdmin() and not self.EventersList[ply:SteamID()] then return end

    net.Start("event_loot_bw_sync")
    net.WriteTable(self.LootBlacklist or {})
    net.WriteTable(self.LootWhitelist or {})
    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

-- Sanitises a per-model max-items cap. nil/<=0 means no cap (use defaults).
function MODE:NormalizeLootCap(value)
    local n = tonumber(value)
    if not n then return nil end
    n = math.floor(n)
    if n <= 0 then return nil end
    if n > 64 then n = 64 end
    return n
end

function MODE:BuildContainerAdminList()
    -- IMPORTANT: pure read. Do NOT call SyncEventContainerTracking or anything
    -- that ends up invoking SetNetVar / ClearContainerInventory here, because
    -- this function is called from inside `SendContainerList` and any nested
    -- SetNetVar fires its own net.Start("zbNetVarSet") and corrupts our
    -- in-progress net message. Sync must be performed by the caller before
    -- invoking SendContainerList.

    local out = {}

    for idx, cfg in ipairs((ZRP and ZRP.Containers) or {}) do
        local ent = ZRP.ActiveContainers and ZRP.ActiveContainers[idx] or nil
        local pos = isvector(cfg.pos) and cfg.pos or (IsValid(ent) and ent:GetPos() or Vector(0, 0, 0))
        local key = self:GetContainerKey("c", idx)
        out[#out + 1] = {
            key = key,
            kind = "container",
            index = idx,
            model = string.lower(tostring(cfg.model or "")),
            pos = pos,
            hasEntity = IsValid(ent),
            lootOverride = table.Copy(self.ContainerLootOverrides[key] or {}),
        }
    end

    for idx, data in ipairs((ZRP and ZRP.WorldContainerData) or {}) do
        local ent = self:ResolveWorldContainerEntity(idx)
        local key = self:GetContainerKey("w", idx)
        out[#out + 1] = {
            key = key,
            kind = "world",
            index = idx,
            model = string.lower(tostring(data.model or "")),
            pos = isvector(data.pos) and data.pos or (IsValid(ent) and ent:GetPos() or Vector(0, 0, 0)),
            hasEntity = IsValid(ent),
            lootOverride = table.Copy(self.ContainerLootOverrides[key] or {}),
        }
    end

    table.sort(out, function(a, b)
        if a.kind == b.kind then
            return (tonumber(a.index) or 0) < (tonumber(b.index) or 0)
        end
        return a.kind < b.kind
    end)

    return out
end

function MODE:SendContainerList(ply)
    if IsValid(ply) and not ply:IsAdmin() and not self.EventersList[ply:SteamID()] then return end

    -- Pure build (no SetNetVar side effects). Caller is responsible for any
    -- pre-sync / adoption work before invoking SendContainerList.
    local list = self:BuildContainerAdminList()

    net.Start("event_container_list_sync")
    net.WriteTable(list)
    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

function MODE:SendWildcardGroups(ply)
    if IsValid(ply) and not ply:IsAdmin() and not self.EventersList[ply:SteamID()] then return end

    net.Start("event_loot_wildcards_sync")
    net.WriteTable(self.CustomWildcardGroups or {})
    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

function MODE:SendWildcardOverrides(ply)
    if IsValid(ply) and not ply:IsAdmin() and not self.EventersList[ply:SteamID()] then return end

    net.Start("event_loot_wildcard_overrides_sync")
    net.WriteTable(self.WildcardOverrides or {})
    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

-- Default expansions for built-in wildcard tokens. Returns an alphabetically
-- sorted list of concrete classnames that the token would normally pick from
-- at runtime (sourced from hg.* tables that drive ZRP loot rolls).
function MODE:GetBuiltInWildcardDefaults(token)
    token = string.lower(string.Trim(tostring(token or "")))
    local out = {}
    local seen = {}

    local function add(cls)
        cls = string.lower(string.Trim(tostring(cls or "")))
        if cls == "" or seen[cls] then return end
        seen[cls] = true
        out[#out + 1] = cls
    end

    if token == "*ammo*" then
        if hg and istable(hg.ammoents) then
            for k, _ in pairs(hg.ammoents) do
                if tostring(k) ~= "" then add("ent_ammo_" .. tostring(k)) end
            end
        end
    elseif token == "*attachments*" then
        if hg and istable(hg.validattachments) then
            for _, group in pairs(hg.validattachments) do
                if istable(group) then
                    for k, _ in pairs(group) do
                        add("ent_att_" .. tostring(k))
                    end
                end
            end
        end
    elseif token == "*sight*" then
        local g = hg and hg.validattachments and hg.validattachments.sight
        if istable(g) then
            for k, _ in pairs(g) do add("ent_att_" .. tostring(k)) end
        end
    elseif token == "*barrel*" then
        local g = hg and hg.validattachments and hg.validattachments.barrel
        if istable(g) then
            for k, _ in pairs(g) do add("ent_att_" .. tostring(k)) end
        end
    end

    table.sort(out)
    return out
end

function MODE:IsBuiltInWildcard(token)
    token = string.lower(string.Trim(tostring(token or "")))
    return token == "*ammo*" or token == "*attachments*"
        or token == "*sight*" or token == "*barrel*"
end

function MODE:BuildContainerLootData()
    local filtered = self:ExpandLootEntries(self:GetLootTable() or {}, true)

    return {
        items = filtered,
        blacklist = {},
        whitelist = {},
    }
end

function MODE:ApplyLootToContainers(resetContainers)
    if not ZRP or not istable(ZRP.Containers) then return false, "ZRP container system unavailable" end

    local globalItems = self:BuildContainerLootData().items

    for id, cfg in ipairs(ZRP.Containers) do
        local key = self:GetContainerKey("c", id)
        local modelKey = string.lower(string.Trim(tostring(cfg.model or "")))
        local modelItems = self:ExpandLootEntries(self.ModelLootProfiles[modelKey] or {}, false)
        local specificItems = self:ExpandLootEntries(self.ContainerLootOverrides[key] or {}, false)
        local chosenItems = (#specificItems > 0 and specificItems)
            or (#modelItems > 0 and modelItems)
            or globalItems

        local lootData = {
            items = table.Copy(chosenItems),
            blacklist = {},
            whitelist = {},
        }

        cfg.lootData = table.Copy(lootData)
        cfg.lootOverride = cfg.lootData.items
        cfg.respawnDelay = EVENT_CONTAINER_REFILL_INTERVAL

        local ent = ZRP.ActiveContainers and ZRP.ActiveContainers[id] or nil
        if IsValid(ent) then
            ent.ZRP_LootData = table.Copy(cfg.lootData)
            ent.ZRP_LootOverride = ent.ZRP_LootData.items
            ent.ZRP_ResetDelay = EVENT_CONTAINER_REFILL_INTERVAL
            ent.ZRP_RespawnDelay = EVENT_CONTAINER_REFILL_INTERVAL
            ent.ZRP_LootMaxItems = self.ModelLootCaps[modelKey]
            ent.ZRP_LootMinItems = self.ModelLootMins[modelKey]

            local isEmpty = (not ZRP.IsInventoryEmpty)
                or ZRP.IsInventoryEmpty(ent.inventory, ent.armors)

            -- Only reset / regenerate when the container is already empty so
            -- the periodic refill never wipes loot a player is mid-pickup.
            if resetContainers and isEmpty then
                if ent.ZRP_Reset then ent:ZRP_Reset() end
                if ZRP and ZRP.GenerateContainerInventory then
                    ZRP.GenerateContainerInventory(ent, ent:GetModel(), ent.ZRP_LootData or ent.ZRP_LootOverride)
                end
            elseif isEmpty then
                if ZRP and ZRP.GenerateContainerInventory then
                    ZRP.GenerateContainerInventory(ent, ent:GetModel(), ent.ZRP_LootData or ent.ZRP_LootOverride)
                end
            end
        end
    end

    if ZRP.SaveContainers then
        ZRP.SaveContainers()
    end

    return true
end

function MODE:RefreshContainerLoot(resetContainers)
    if not self.LootEnabled then return end

    self:SyncEventContainerTracking(true)

    local globalItems = table.Copy((self:BuildContainerLootData().items) or {})
    for idx, data in ipairs((ZRP and ZRP.WorldContainerData) or {}) do
        local key = self:GetContainerKey("w", idx)
        local modelKey = string.lower(string.Trim(tostring(data.model or "")))
        local modelItems = self:ExpandLootEntries(self.ModelLootProfiles[modelKey] or {}, false)
        local specificItems = self:ExpandLootEntries(self.ContainerLootOverrides[key] or {}, false)
        local chosenItems = (#specificItems > 0 and specificItems)
            or (#modelItems > 0 and modelItems)
            or globalItems

        data.lootOverride = table.Copy(chosenItems)
        data.respawnDelay = EVENT_CONTAINER_REFILL_INTERVAL

        local state = ZRP.WorldContainerState and ZRP.WorldContainerState[idx] or nil
        local ent = state and ents.GetByIndex(state.entindex or 0) or self:ResolveWorldContainerEntity(idx)
        if IsValid(ent) then
            ent.ZRP_WorldLootOverride = table.Copy(chosenItems)
            ent.ZRP_LootMaxItems = self.ModelLootCaps[modelKey]
            ent.ZRP_LootMinItems = self.ModelLootMins[modelKey]
            local isEmpty = (not ZRP.IsInventoryEmpty)
                or ZRP.IsInventoryEmpty(ent.inventory, ent.armors)
            if resetContainers and isEmpty then
                -- Only re-roll empty containers on the periodic refill so we
                -- never wipe loot a player is currently picking up. Marked
                -- "looted" containers also become eligible since they were
                -- already cleared at the time they were depleted.
                ent.ZRP_WorldLootGenerated = false
                if ZRP.ClearContainerInventory then
                    ZRP.ClearContainerInventory(ent)
                end
                if ZRP and ZRP.GenerateContainerInventory then
                    ZRP.GenerateContainerInventory(ent, ent:GetModel(), ent.ZRP_WorldLootOverride)
                end
                if state then
                    state.looted = false
                    state.resetAt = 0
                end
                timer.Remove("ZRP_WCReset_" .. idx)
            elseif not ent.ZRP_WorldLootGenerated then
                -- First-time generation for a freshly adopted container.
                if ZRP and ZRP.GenerateContainerInventory then
                    ZRP.GenerateContainerInventory(ent, ent:GetModel(), ent.ZRP_WorldLootOverride)
                    ent.ZRP_WorldLootGenerated = true
                end
            end
        end
    end

    self:ApplyLootToContainers(resetContainers)
end

function MODE:SendLootSettings(ply)
    if IsValid(ply) and not ply:IsAdmin() and not self.EventersList[ply:SteamID()] then return end

    net.Start("event_loot_settings_sync")
    net.WriteBool(self.ContainerAutoRefillEnabled and true or false)
    net.WriteFloat(EVENT_CONTAINER_REFILL_INTERVAL)
    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

function MODE:ConfigureContainerRefillTimer()
    timer.Remove(EVENT_CONTAINER_REFILL_TIMER)

    if not self.LootEnabled then return end
    if not self.ContainerAutoRefillEnabled then return end

    timer.Create(EVENT_CONTAINER_REFILL_TIMER, EVENT_CONTAINER_REFILL_INTERVAL, 0, function()
        if not MODE.LootEnabled then return end
        if not IsEventRoundPlaying() then return end
        MODE:RefreshContainerLoot(true)
    end)
end

net.Receive("event_loot_request", function(len, ply)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end
    
    net.Start("event_loot_sync")
    net.WriteTable(MODE.CustomLootTable[1][2] or {})
    net.Send(ply)

    MODE:SendLootSettings(ply)
    MODE:SendWildcardGroups(ply)
    MODE:SendWildcardOverrides(ply)
    MODE:SendModelLootProfiles(ply)
    MODE:SendLootBlacklistWhitelist(ply)
    MODE:SendContainerList(ply)
end)

net.Receive("event_container_list_request", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end
    -- Adoption + state mutation BEFORE sending the list, so the in-progress
    -- net frame in SendContainerList sees no SetNetVar interference.
    MODE:SyncEventContainerTracking(false)
    MODE:ScanAndAdoptStaffContainers()
    MODE:SendContainerList(ply)
    MODE:SendModelLootProfiles(ply)
end)

-- Per-class blacklist toggle (parity with ZRP LootEditor).
net.Receive("event_loot_blacklist_set", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local cls = string.lower(string.Trim(tostring(net.ReadString() or "")))
    local enabled = net.ReadBool()
    if cls == "" then return end

    MODE.LootBlacklist = MODE.LootBlacklist or {}
    if enabled then
        MODE.LootBlacklist[cls] = true
    else
        MODE.LootBlacklist[cls] = nil
    end
    MODE:SaveLootTable()
    MODE:RefreshContainerLoot(true)
    MODE:SendLootBlacklistWhitelist()
end)

-- Per-class whitelist toggle (parity with ZRP LootEditor).
net.Receive("event_loot_whitelist_set", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local cls = string.lower(string.Trim(tostring(net.ReadString() or "")))
    local enabled = net.ReadBool()
    if cls == "" then return end

    MODE.LootWhitelist = MODE.LootWhitelist or {}
    if enabled then
        MODE.LootWhitelist[cls] = true
    else
        MODE.LootWhitelist[cls] = nil
    end
    MODE:SaveLootTable()
    MODE:RefreshContainerLoot(true)
    MODE:SendLootBlacklistWhitelist()
end)

net.Receive("event_model_loot_profile_set", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local modelKey = string.lower(string.Trim(tostring(net.ReadString() or "")))
    local lootItems = MODE:NormalizeLootEntries(net.ReadTable() or {})
    if modelKey == "" then return end

    if #lootItems == 0 then
        MODE.ModelLootProfiles[modelKey] = nil
    else
        MODE.ModelLootProfiles[modelKey] = lootItems
    end

    MODE:SaveLootTable()
    MODE:RefreshContainerLoot(true)
    MODE:SendModelLootProfiles()
    MODE:SendContainerList()
end)

net.Receive("event_model_loot_profile_remove", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local modelKey = string.lower(string.Trim(tostring(net.ReadString() or "")))
    if modelKey == "" then return end

    MODE.ModelLootProfiles[modelKey] = nil
    MODE.ModelLootCaps[modelKey] = nil
    MODE.ModelLootMins[modelKey] = nil
    MODE:SaveLootTable()
    MODE:RefreshContainerLoot(true)
    MODE:SendModelLootProfiles()
    MODE:SendContainerList()
end)

net.Receive("event_model_loot_cap_set", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local modelKey = string.lower(string.Trim(tostring(net.ReadString() or "")))
    local cap = MODE:NormalizeLootCap(net.ReadFloat())
    if modelKey == "" then return end

    MODE.ModelLootCaps[modelKey] = cap

    MODE:SaveLootTable()
    MODE:RefreshContainerLoot(true)
    MODE:SendModelLootProfiles()
    MODE:SendContainerList()

    if cap then
        ply:ChatPrint("[Event] Max items for " .. modelKey .. " set to " .. cap .. ".")
    else
        ply:ChatPrint("[Event] Max items for " .. modelKey .. " cleared (uses defaults).")
    end
end)

net.Receive("event_model_loot_min_set", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local modelKey = string.lower(string.Trim(tostring(net.ReadString() or "")))
    local minVal = MODE:NormalizeLootCap(net.ReadFloat())
    if modelKey == "" then return end

    MODE.ModelLootMins[modelKey] = minVal

    MODE:SaveLootTable()
    MODE:RefreshContainerLoot(true)
    MODE:SendModelLootProfiles()
    MODE:SendContainerList()

    if minVal then
        ply:ChatPrint("[Event] Min items for " .. modelKey .. " set to " .. minVal .. ".")
    else
        ply:ChatPrint("[Event] Min items for " .. modelKey .. " cleared (defaults to half of max).")
    end
end)

net.Receive("event_container_whitelist_set", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local modelKey = MODE:NormalizeContainerModel(net.ReadString())
    local enabled = net.ReadBool()
    if modelKey == "" then return end

    if enabled then
        MODE.ContainerModelWhitelist[modelKey] = true
        ply:ChatPrint("[Event] Whitelisted container model: " .. modelKey)
    else
        MODE.ContainerModelWhitelist[modelKey] = nil
        ply:ChatPrint("[Event] Removed container model from whitelist: " .. modelKey)
    end

    MODE:SaveLootTable()
    MODE:SendModelLootProfiles()
    MODE:SendContainerList()
end)

net.Receive("event_container_set_loot", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local key = string.Trim(tostring(net.ReadString() or ""))
    local lootItems = MODE:NormalizeLootEntries(net.ReadTable() or {})
    if key == "" then return end

    if #lootItems == 0 then
        MODE.ContainerLootOverrides[key] = nil
    else
        MODE.ContainerLootOverrides[key] = lootItems
    end

    MODE:SaveLootTable()
    MODE:RefreshContainerLoot(true)
    MODE:SendContainerList()
end)

net.Receive("event_container_action", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local key = string.Trim(tostring(net.ReadString() or ""))
    local action = string.lower(string.Trim(tostring(net.ReadString() or "")))
    local kind, idx = string.match(key, "^(%a):(%d+)$")
    idx = tonumber(idx or 0)
    if not kind or idx <= 0 then
        ply:ChatPrint("[Event] Invalid container selection.")
        return
    end

    if action == "goto" then
        local pos = nil
        if kind == "c" then
            local cfg = ZRP and ZRP.Containers and ZRP.Containers[idx] or nil
            pos = cfg and cfg.pos or nil
        elseif kind == "w" then
            local cfg = ZRP and ZRP.WorldContainerData and ZRP.WorldContainerData[idx] or nil
            local ent = MODE:ResolveWorldContainerEntity(idx)
            pos = (IsValid(ent) and ent:GetPos()) or (cfg and cfg.pos or nil)
        end
        if isvector(pos) then
            ply:SetPos(pos + Vector(0, 0, 32))
        else
            ply:ChatPrint("[Event] Could not find container position.")
        end
        return
    end

    if action == "refill" then
        if kind == "c" then
            local ent = ZRP and ZRP.ActiveContainers and ZRP.ActiveContainers[idx] or nil
            if not IsValid(ent) and ZRP and ZRP.SpawnContainer then
                ent = ZRP.SpawnContainer(idx)
            end
            if IsValid(ent) and ent.ZRP_Reset then
                ent:ZRP_Reset()
                if ZRP and ZRP.GenerateContainerInventory then
                    ZRP.GenerateContainerInventory(ent, ent:GetModel(), ent.ZRP_LootData or ent.ZRP_LootOverride)
                end
                ply:ChatPrint("[Event] Container refilled.")
            else
                ply:ChatPrint("[Event] Failed to refill container.")
            end
        elseif kind == "w" then
            MODE:SyncEventContainerTracking(false)
            local state = ZRP and ZRP.WorldContainerState and ZRP.WorldContainerState[idx] or nil
            local ent = state and ents.GetByIndex(state.entindex or 0) or MODE:ResolveWorldContainerEntity(idx)
            if state then
                state.looted = false
                state.resetAt = 0
            end
            if IsValid(ent) then
                ent.ZRP_WorldLootGenerated = false
                if ZRP and ZRP.ClearContainerInventory then
                    ZRP.ClearContainerInventory(ent)
                end
                if ZRP and ZRP.GenerateContainerInventory then
                    ZRP.GenerateContainerInventory(ent, ent:GetModel(), ent.ZRP_WorldLootOverride)
                end
                ply:ChatPrint("[Event] World container refilled.")
            else
                ply:ChatPrint("[Event] Failed to refill world container.")
            end
        end
        MODE:SendContainerList()
        return
    end

    if action == "delete" then
        MODE.ContainerLootOverrides[key] = nil

        if kind == "c" then
            if ZRP and ZRP.ActiveContainers and IsValid(ZRP.ActiveContainers[idx]) then
                ZRP.ActiveContainers[idx]:Remove()
            end
            if ZRP and ZRP.Containers then
                table.remove(ZRP.Containers, idx)
            end
            if ZRP and ZRP.ActiveContainers then
                table.remove(ZRP.ActiveContainers, idx)
            end
            if ZRP and ZRP.SaveContainers then
                ZRP.SaveContainers()
            end
        elseif kind == "w" then
            if ZRP and ZRP.WorldContainerData then
                table.remove(ZRP.WorldContainerData, idx)
            end
            if ZRP and ZRP.SaveWorldContainers then
                ZRP.SaveWorldContainers()
            end
            if ZRP and ZRP.ActivateWorldContainers then
                ZRP.ActivateWorldContainers()
            end
        end

        MODE:SaveLootTable()
        MODE:RefreshContainerLoot(true)
        MODE:SendContainerList()
        MODE:SendModelLootProfiles()
        ply:ChatPrint("[Event] Container deleted.")
        return
    end

    if action == "setdelay" then
        -- Custom per-container respawn delay (seconds). Mirrors the ZRP
        -- LootEditor 'Set Respawn Delay' option so admins can have ZRP
        -- containers spawned via the toolgun honour bespoke timers in event
        -- mode without having to rely on the global 5-minute refill.
        local secs = tonumber(net.ReadString() or "")
        if not secs then
            ply:ChatPrint("[Event] Invalid delay.")
            return
        end
        secs = math.Clamp(math.floor(secs), 1, 86400)

        if kind == "c" then
            local cfg = ZRP and ZRP.Containers and ZRP.Containers[idx] or nil
            if cfg then
                cfg.respawnDelay = secs
                local ent = ZRP.ActiveContainers and ZRP.ActiveContainers[idx] or nil
                if IsValid(ent) then
                    ent.ZRP_RespawnDelay = secs
                    ent.ZRP_ResetDelay = secs
                end
                if ZRP.SaveContainers then ZRP.SaveContainers() end
                ply:ChatPrint("[Event] Container respawn delay set to " .. secs .. "s.")
            else
                ply:ChatPrint("[Event] Container not found.")
            end
        elseif kind == "w" then
            local data = ZRP and ZRP.WorldContainerData and ZRP.WorldContainerData[idx] or nil
            if data then
                data.respawnDelay = secs
                if ZRP.SaveWorldContainers then ZRP.SaveWorldContainers() end
                ply:ChatPrint("[Event] World container respawn delay set to " .. secs .. "s.")
            else
                ply:ChatPrint("[Event] World container not found.")
            end
        end
        MODE:SendContainerList()
        return
    end

    if action == "adopt" then
        -- Adopt a scanned-but-not-adopted lootable map prop as a ZRP world
        -- container in event mode. Mirrors the ZRP LootEditor "Adopt as ZRP
        -- Container" right-click action.
        local entIdx = tonumber(net.ReadString() or "")
        if not entIdx then return end
        local ent = ents.GetByIndex(entIdx)
        if not IsValid(ent) then
            ply:ChatPrint("[Event] Prop not found.")
            return
        end
        if ZRP and ZRP.AdoptWorldProp then
            local ok, msg = ZRP.AdoptWorldProp(ent, ply)
            ply:ChatPrint("[Event] " .. (msg or (ok and "Adopted." or "Adoption failed.")))
        else
            ply:ChatPrint("[Event] ZRP world-prop adoption unavailable.")
        end
        MODE:SyncEventContainerTracking(false)
        MODE:SendContainerList()
        if ZRP and ZRP.SyncWorldContainersToPlayer then
            ZRP.SyncWorldContainersToPlayer(ply)
        end
    end
end)

net.Receive("event_loot_wildcard_set", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local token = MODE:NormalizeWildcardToken(net.ReadString())
    local entries = MODE:NormalizeWildcardEntries(net.ReadTable() or {})
    if not token then return end

    if #entries == 0 then
        ply:ChatPrint("[Event] Wildcard creation failed: no valid classes selected.")
        return
    end

    MODE.CustomWildcardGroups[token] = entries
    MODE:SaveLootTable()
    MODE:SendWildcardGroups()
    MODE:RefreshContainerLoot(true)

    ply:ChatPrint("[Event] Wildcard " .. token .. " saved with " .. tostring(#entries) .. " classes.")
end)

net.Receive("event_loot_wildcard_remove", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local token = MODE:NormalizeWildcardToken(net.ReadString())
    if not token then return end
    if not MODE.CustomWildcardGroups[token] then return end

    MODE.CustomWildcardGroups[token] = nil
    MODE:SaveLootTable()
    MODE:SendWildcardGroups()
    MODE:RefreshContainerLoot(true)

    ply:ChatPrint("[Event] Removed wildcard " .. token)
end)

net.Receive("event_loot_wildcard_contents_request", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local token = MODE:NormalizeWildcardToken(net.ReadString())
    if not token then return end

    local defaults = MODE:GetBuiltInWildcardDefaults(token)
    local current = {}

    if istable(MODE.WildcardOverrides[token]) and #MODE.WildcardOverrides[token] > 0 then
        current = MODE.WildcardOverrides[token]
    elseif istable(MODE.CustomWildcardGroups[token]) then
        current = MODE.CustomWildcardGroups[token]
    elseif #defaults > 0 then
        current = defaults
    end

    net.Start("event_loot_wildcard_contents_sync")
    net.WriteString(token)
    net.WriteBool(MODE:IsBuiltInWildcard(token))
    net.WriteBool(MODE.CustomWildcardGroups[token] ~= nil)
    net.WriteTable(defaults)
    net.WriteTable(current)
    net.Send(ply)
end)

net.Receive("event_loot_wildcard_contents_set", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    local token = MODE:NormalizeWildcardToken(net.ReadString())
    if not token then return end

    local entries = MODE:NormalizeWildcardEntries(net.ReadTable() or {})

    if MODE.CustomWildcardGroups[token] then
        -- Editing a known custom wildcard: rewrite its entries (remove if empty).
        if #entries == 0 then
            MODE.CustomWildcardGroups[token] = nil
            ply:ChatPrint("[Event] Custom wildcard " .. token .. " emptied and removed.")
        else
            MODE.CustomWildcardGroups[token] = entries
            ply:ChatPrint("[Event] Custom wildcard " .. token .. " updated (" .. #entries .. " classes).")
        end
        MODE.WildcardOverrides[token] = nil
    elseif MODE:IsBuiltInWildcard(token) then
        -- Built-in token (has runtime expansion): store override or reset.
        if #entries == 0 then
            MODE.WildcardOverrides[token] = nil
            ply:ChatPrint("[Event] Reset built-in wildcard " .. token .. " to defaults.")
        else
            MODE.WildcardOverrides[token] = entries
            ply:ChatPrint("[Event] Built-in wildcard " .. token .. " override saved (" .. #entries .. " classes).")
        end
    else
        -- Placeholder token (e.g. *snipers*, *pistols*) with no backing data
        -- yet. Save into CustomWildcardGroups so it expands at runtime.
        if #entries == 0 then
            MODE.CustomWildcardGroups[token] = nil
            MODE.WildcardOverrides[token] = nil
            ply:ChatPrint("[Event] Wildcard " .. token .. " cleared.")
        else
            MODE.CustomWildcardGroups[token] = entries
            MODE.WildcardOverrides[token] = nil
            ply:ChatPrint("[Event] Wildcard " .. token .. " saved (" .. #entries .. " classes).")
        end
    end

    MODE:SaveLootTable()
    MODE:SendWildcardGroups()
    MODE:SendWildcardOverrides()
    MODE:RefreshContainerLoot(true)
end)

net.Receive("event_loot_settings_set", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end

    MODE.ContainerAutoRefillEnabled = net.ReadBool()
    MODE:ConfigureContainerRefillTimer()
    MODE:SaveLootTable()
    MODE:SendLootSettings()

    ply:ChatPrint("[Event] Container auto-refill " .. (MODE.ContainerAutoRefillEnabled and "enabled" or "disabled") .. " (5 minute interval).")
end)

local serverIdentifier = string.Trim(string.lower(GetConVar("hostname"):GetString()))
serverIdentifier = string.gsub(serverIdentifier, "[^%w]", "_")

function MODE:SaveLootTable()
    if not file.Exists("zbattle", "DATA") then
        file.CreateDir("zbattle")
    end
    
    if not file.Exists("zbattle/event_loot", "DATA") then
        file.CreateDir("zbattle/event_loot")
    end
    
    local payload = {
        lootTable = self.CustomLootTable,
        containerAutoRefillEnabled = self.ContainerAutoRefillEnabled and true or false,
        customWildcardGroups = self.CustomWildcardGroups or {},
        wildcardOverrides = self.WildcardOverrides or {},
        modelLootProfiles = self.ModelLootProfiles or {},
        modelLootCaps = self.ModelLootCaps or {},
        modelLootMins = self.ModelLootMins or {},
        containerLootOverrides = self.ContainerLootOverrides or {},
        containerModelWhitelist = self.ContainerModelWhitelist or {},
        lootBlacklist = self.LootBlacklist or {},
        lootWhitelist = self.LootWhitelist or {},
    }
    local data = util.TableToJSON(payload)
    file.Write("zbattle/event_loot/loot_table_" .. serverIdentifier .. ".txt", data)
    print("[Event Mode] Loot table saved for server: " .. serverIdentifier)
end

function MODE:LoadLootTable()
    if not file.Exists("zbattle/event_loot/loot_table_" .. serverIdentifier .. ".txt", "DATA") then
        print("[Event Mode] No saved loot table found for server: " .. serverIdentifier)
        self.CustomLootTable = { {50, {}} }
        self.CustomWildcardGroups = {}
        self.WildcardOverrides = {}
        self.ModelLootProfiles = {}
        self.ModelLootCaps = {}
        self.ModelLootMins = {}
        self.ContainerLootOverrides = {}
        self.ContainerModelWhitelist = {}
        self.LootBlacklist = {}
        self.LootWhitelist = {}
        self:SeedContainerModelWhitelistIfEmpty()
        return
    end
    
    local data = file.Read("zbattle/event_loot/loot_table_" .. serverIdentifier .. ".txt", "DATA")
    if not data or data == "" then
        print("[Event Mode] Empty or corrupt loot table file for server: " .. serverIdentifier)
        self.CustomLootTable = { {50, {}} }
        self.CustomWildcardGroups = {}
        self.WildcardOverrides = {}
        self.ModelLootProfiles = {}
        self.ModelLootCaps = {}
        self.ModelLootMins = {}
        self.ContainerLootOverrides = {}
        self.ContainerModelWhitelist = {}
        self.LootBlacklist = {}
        self.LootWhitelist = {}
        self:SeedContainerModelWhitelistIfEmpty()
        return
    end
    
    local success, loadedTable = pcall(util.JSONToTable, data)
    if not success or not loadedTable then
        print("[Event Mode] Failed to parse loot table JSON for server: " .. serverIdentifier)
        self.CustomLootTable = { {50, {}} }
        self.CustomWildcardGroups = {}
        self.WildcardOverrides = {}
        self.ModelLootProfiles = {}
        self.ModelLootCaps = {}
        self.ModelLootMins = {}
        self.ContainerLootOverrides = {}
        self.ContainerModelWhitelist = {}
        self.LootBlacklist = {}
        self.LootWhitelist = {}
        self:SeedContainerModelWhitelistIfEmpty()
        return
    end
    
    if istable(loadedTable.lootTable) then
        self.CustomLootTable = loadedTable.lootTable
        if loadedTable.containerAutoRefillEnabled == nil then
            self.ContainerAutoRefillEnabled = true
        else
            self.ContainerAutoRefillEnabled = loadedTable.containerAutoRefillEnabled and true or false
        end
        self.CustomWildcardGroups = {}
        for token, entries in pairs(loadedTable.customWildcardGroups or {}) do
            local normToken = self:NormalizeWildcardToken(token)
            if normToken then
                self.CustomWildcardGroups[normToken] = self:NormalizeWildcardEntries(entries)
            end
        end

        self.WildcardOverrides = {}
        for token, entries in pairs(loadedTable.wildcardOverrides or {}) do
            local normToken = self:NormalizeWildcardToken(token)
            if normToken then
                local normalized = self:NormalizeWildcardEntries(entries)
                if #normalized > 0 then
                    self.WildcardOverrides[normToken] = normalized
                end
            end
        end

        self.ModelLootProfiles = {}
        for modelKey, entries in pairs(loadedTable.modelLootProfiles or {}) do
            local normModel = string.lower(string.Trim(tostring(modelKey or "")))
            if normModel ~= "" then
                local normalized = self:NormalizeLootEntries(entries)
                if #normalized > 0 then
                    self.ModelLootProfiles[normModel] = normalized
                end
            end
        end

        self.ModelLootCaps = {}
        for modelKey, capValue in pairs(loadedTable.modelLootCaps or {}) do
            local normModel = string.lower(string.Trim(tostring(modelKey or "")))
            if normModel ~= "" then
                local normalized = self:NormalizeLootCap(capValue)
                if normalized then
                    self.ModelLootCaps[normModel] = normalized
                end
            end
        end

        self.ModelLootMins = {}
        for modelKey, minValue in pairs(loadedTable.modelLootMins or {}) do
            local normModel = string.lower(string.Trim(tostring(modelKey or "")))
            if normModel ~= "" then
                local normalized = self:NormalizeLootCap(minValue)
                if normalized then
                    self.ModelLootMins[normModel] = normalized
                end
            end
        end

        self.ContainerLootOverrides = {}
        for key, entries in pairs(loadedTable.containerLootOverrides or {}) do
            key = string.Trim(tostring(key or ""))
            if key ~= "" then
                local normalized = self:NormalizeLootEntries(entries)
                if #normalized > 0 then
                    self.ContainerLootOverrides[key] = normalized
                end
            end
        end

        self.ContainerModelWhitelist = {}
        for modelKey, flag in pairs(loadedTable.containerModelWhitelist or {}) do
            local norm = self:NormalizeContainerModel(modelKey)
            if norm ~= "" and flag then
                self.ContainerModelWhitelist[norm] = true
            end
        end
        self:SeedContainerModelWhitelistIfEmpty()

        -- Per-class global blacklist / whitelist (ZRP LootEditor parity).
        self.LootBlacklist = {}
        for cls, flag in pairs(loadedTable.lootBlacklist or {}) do
            cls = string.lower(string.Trim(tostring(cls or "")))
            if cls ~= "" and flag then
                self.LootBlacklist[cls] = true
            end
        end
        self.LootWhitelist = {}
        for cls, flag in pairs(loadedTable.lootWhitelist or {}) do
            cls = string.lower(string.Trim(tostring(cls or "")))
            if cls ~= "" and flag then
                self.LootWhitelist[cls] = true
            end
        end
    else
        -- Backward compatibility with legacy format that only stored the loot table.
        self.CustomLootTable = loadedTable
        self.CustomWildcardGroups = self.CustomWildcardGroups or {}
        self.WildcardOverrides = self.WildcardOverrides or {}
        self.ModelLootProfiles = self.ModelLootProfiles or {}
        self.ModelLootCaps = self.ModelLootCaps or {}
        self.ModelLootMins = self.ModelLootMins or {}
        self.ContainerLootOverrides = self.ContainerLootOverrides or {}
        self.ContainerModelWhitelist = self.ContainerModelWhitelist or {}
        self.LootBlacklist = self.LootBlacklist or {}
        self.LootWhitelist = self.LootWhitelist or {}
        self:SeedContainerModelWhitelistIfEmpty()
    end

    self:ConfigureContainerRefillTimer()
    print("[Event Mode] Loot table loaded for server: " .. serverIdentifier .. " with " .. #self.CustomLootTable[1][2] .. " items")
end

hook.Add("Initialize", "ZB_EventLoadLootTable", function()
    timer.Simple(1, function()
        if SERVER and MODE and MODE.LoadLootTable then
            MODE:LoadLootTable()
        end
    end)
end)

net.Receive("event_loot_add", function(len, ply)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end
    
    local itemData = net.ReadTable()
    
    if not itemData or not itemData.weight or not itemData.class then return end
    
    table.insert(MODE.CustomLootTable[1][2], {itemData.weight, itemData.class})
    
    MODE:SaveLootTable()
    
    local recipients = {}
    for _, p in player.Iterator() do
        if p:IsAdmin() or MODE.EventersList[p:SteamID()] then
            table.insert(recipients, p)
        end
    end
    
    net.Start("event_loot_sync")
    net.WriteTable(MODE.CustomLootTable[1][2])
    net.Send(recipients)

    MODE:RefreshContainerLoot(true)
    
    ply:ChatPrint("Added item: " .. itemData.class .. " with weight " .. itemData.weight)
end)

net.Receive("event_loot_remove", function(len, ply)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end
    
    local itemIndex = net.ReadUInt(16)
    
    if not MODE.CustomLootTable[1][2][itemIndex] then return end
    
    local removedItem = MODE.CustomLootTable[1][2][itemIndex][2]
    table.remove(MODE.CustomLootTable[1][2], itemIndex)
    
    MODE:SaveLootTable()
    
    local recipients = {}
    for _, p in player.Iterator() do
        if p:IsAdmin() or MODE.EventersList[p:SteamID()] then
            table.insert(recipients, p)
        end
    end
    
    net.Start("event_loot_sync")
    net.WriteTable(MODE.CustomLootTable[1][2])
    net.Send(recipients)

    MODE:RefreshContainerLoot(true)
    
    ply:ChatPrint("Removed item: " .. removedItem)
end)

concommand.Add("zb_event_loot_reset", function(ply, _, _, _)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end
    
    MODE.CustomLootTable = {
        {50, {}}
    }
    
    MODE:SaveLootTable()
    
    local recipients = {}
    for _, p in player.Iterator() do
        if p:IsAdmin() or MODE.EventersList[ply:SteamID()] then
            table.insert(recipients, p)
        end
    end
    
    net.Start("event_loot_sync")
    net.WriteTable(MODE.CustomLootTable[1][2])
    net.Send(recipients)

    MODE:RefreshContainerLoot(true)
    
    ply:ChatPrint("Loot table has been reset")
end)

concommand.Add("zb_event_loot_save", function(ply, _, _, _)
    if not ply:IsAdmin() then return end
    
    MODE:SaveLootTable()
    ply:ChatPrint("Loot table saved for server: " .. serverIdentifier)
end)

concommand.Add("zb_event_lootpoll", function(ply, _, _, _)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then
        ply:ChatPrint("You don't have access to this command")
        return
    end
    
    net.Start("event_loot_request")
    net.Send(ply)
end)

concommand.Add("zb_event_dump_loot_groups", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local groups = (ZRP and ZRP.BuildRegisteredLootGroups and ZRP.BuildRegisteredLootGroups()) or {}
    local payload = {
        generatedAt = os.date("%Y-%m-%d %H:%M:%S"),
        map = game.GetMap(),
        groups = groups,
    }

    if not file.Exists("zbattle", "DATA") then
        file.CreateDir("zbattle")
    end
    if not file.Exists("zbattle/event_loot", "DATA") then
        file.CreateDir("zbattle/event_loot")
    end

    local outPath = "zbattle/event_loot/registered_loot_groups_" .. serverIdentifier .. ".json"
    file.Write(outPath, util.TableToJSON(payload, true) or "{}")

    local msg = "[Event] Wrote grouped loot registry: data/" .. outPath
    print(msg)
    if IsValid(ply) then
        ply:ChatPrint(msg)
    end
end)

concommand.Add("zb_event_name", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    SetGlobalString("ZB_EventName", args)
end)

concommand.Add("zb_event_role", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    SetGlobalString("ZB_EventRole", args)
end)

concommand.Add("zb_event_objective", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    SetGlobalString("ZB_EventObjective", args)
end)

concommand.Add("zb_event_endlogic", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    local logicType = tonumber(args) or 2
    logicType = math.Clamp(logicType, 1, 3)
    MODE.EndLogicType = logicType
    ply:ChatPrint("Event end logic set to: " .. logicType)
end)

concommand.Add("zb_event_loot", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    
    local enabled = tonumber(args) == 1
    MODE.LootEnabled = enabled
    MODE.LootSpawn = false

    if enabled then
        MODE:RefreshContainerLoot(true)
    end

    MODE:ConfigureContainerRefillTimer()
    
    ply:ChatPrint("Event loot " .. (enabled and "enabled" or "disabled"))
end)

hook.Add("PlayerInitialSpawn", "ZB_EventLootSync", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) and (ply:IsAdmin() or MODE.EventersList[ply:SteamID()]) then
            net.Start("event_loot_sync")
            net.WriteTable(MODE.CustomLootTable[1][2] or {})
            net.Send(ply)
            
        end
    end)
end)

-- Late-join hint: when a player connects mid-event-round, tell them how to
-- spawn into the event. Without this hint, players who arrive after the round
-- has started (especially when timed respawns are disabled) have no obvious
-- way to know that "!join" is what gets them into the action.
hook.Add("PlayerInitialSpawn", "ZB_EventJoinHint", function(ply)
    timer.Simple(7, function()
        if not IsValid(ply) then return end
        if not IsEventRoundPlaying() then return end
        if ply:IsAdmin() then return end
        if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then return end

        ply:ChatPrint("[Event] An event round is in progress. Type !join in chat to spawn in.")
        if ply:Team() == TEAM_SPECTATOR then
            ply:ChatPrint("[Event] You are spectating â€” press F3 to leave spectator first, then type !join.")
        end
    end)
end)

hook.Add("HG_PlayerSay", "ZB_EventLootCommand", function(ply, txtTbl, text)
    if string.lower(text) == "!eventloot" and (ply:IsAdmin() or MODE.EventersList[ply:SteamID()]) then
        ply:ConCommand("zb_event_loot_menu")
        txtTbl[1] = ""
    end
end)

hook.Add("HG_PlayerSay", "ZB_EventJoinChat", function(ply, txtTbl, text)
    local cmd = string.lower(string.Trim(text or ""))
    if cmd ~= "!join" and cmd ~= "/join" then return end

    txtTbl[1] = ""

    if not IsEventRoundPlaying() then
        ply:ChatPrint("[Event] !join is only available during a live event round.")
        return ""
    end
    if ply:Team() == TEAM_SPECTATOR then
        ply:ChatPrint("[Event] Leave spectator mode first (press F3).")
        return ""
    end
    if ply:Alive() then
        ply:ChatPrint("[Event] You are already alive.")
        return ""
    end

    local spawnPos, spawnAng = MODE:GetEventRespawnPoint(nil)
    if not spawnPos then
        ply:ChatPrint("[Event] No spawn points found â€” ask an admin to add EVENT_SPAWN points to the map.")
        return ""
    end

    ply.gottarespawn = true
    ply:Spawn()

    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end
        ply:SetPos(spawnPos)
        if spawnAng then ply:SetEyeAngles(spawnAng) end
        ply:SetLocalVelocity(vector_origin)
        ply._lastEventRespawnPos = spawnPos
    end)

    if MODE.EventersList[ply:SteamID()] then
        zb.GiveRole(ply, "Eventer", Color(50, 200, 50))
    else
        zb.GiveRole(ply, GetGlobalString("ZB_EventRole", "Player"), Color(190, 15, 15))
    end

    return ""
end)

hook.Add("InitPostEntity", "ZB_EventLootInitCheck", function()
    timer.Simple(3, function()
        print("[Event Mode] Checking loot system status...")
        if MODE.LootEnabled then
            print("[Event Mode] Container loot system is enabled")
            MODE:RefreshContainerLoot(false)
            MODE:ConfigureContainerRefillTimer()
        else
            print("[Event Mode] Loot system is disabled")
        end
    end)
end)

concommand.Add("zb_event_eventer_add", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    local target = player.GetBySteamID(args) or player.GetByID(tonumber(args) or 0)
    
    if IsValid(target) then
        MODE.EventersList[target:SteamID()] = true
        ply:ChatPrint("Added " .. target:Nick() .. " as an eventer")
        
        if zb.ROUND_PLAYING then
            zb.GiveRole(target, "Eventer", Color(50, 200, 50))
        end
        
        net.Start("event_eventers_update")
        local data = {}
        for id, _ in pairs(MODE.EventersList) do
            table.insert(data, id)
        end
        net.WriteTable(data)
        net.Broadcast()
    end
end)

concommand.Add("zb_event_eventer_remove", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    local target = player.GetBySteamID(args) or player.GetByID(tonumber(args) or 0)
    
    if IsValid(target) then
        MODE.EventersList[target:SteamID()] = nil
        ply:ChatPrint("Removed " .. target:Nick() .. " as an eventer")
        
        if zb.ROUND_PLAYING then
            zb.GiveRole(target, GetGlobalString("ZB_EventRole","Player"), Color(190,15,15))
        end
        
        net.Start("event_eventers_update")
        local data = {}
        for id, _ in pairs(MODE.EventersList) do
            table.insert(data, id)
        end
        net.WriteTable(data)
        net.Broadcast()
    end
end)

concommand.Add("zb_event_end", function(ply, _, _, _)
    if not ply:IsAdmin() then return end
    
    if zb.ROUND_PLAYING then
        MODE:EndRound()
        ply:ChatPrint("Ending the event round...")
    else
        ply:ChatPrint("No event round is currently active.")
    end
end)

concommand.Add("zb_event_respawns", function(ply, _, _, args)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local value = tonumber(args and args[1])
    if value == nil then
        if IsValid(ply) then
            ply:ChatPrint("[Event] zb_event_respawns is " .. (eventRespawnsEnabled:GetBool() and "1" or "0"))
        end
        return
    end

    value = value ~= 0 and 1 or 0
    RunConsoleCommand("zb_event_respawns", tostring(value))

    local actor = IsValid(ply) and ply:Nick() or "Console"
    PrintMessage(HUD_PRINTTALK, "[Event] Respawns " .. (value == 1 and "enabled" or "disabled") .. " by " .. actor .. ".")
end)

concommand.Add("zb_event_respawn_delay", function(ply, _, _, args)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local value = tonumber(args and args[1])
    if value == nil then
        if IsValid(ply) then
            ply:ChatPrint("[Event] zb_event_respawn_delay is " .. tostring(eventRespawnDelay:GetFloat()))
        end
        return
    end

    value = math.Clamp(value, 0, 120)
    RunConsoleCommand("zb_event_respawn_delay", tostring(value))

    local actor = IsValid(ply) and ply:Nick() or "Console"
    PrintMessage(HUD_PRINTTALK, "[Event] Respawn delay set to " .. tostring(value) .. "s by " .. actor .. ".")
end)

if SERVER and ulx and ULib then
    function ulx.eventrespawns(calling_ply, enabled)
        local value = enabled and 1 or 0
        RunConsoleCommand("zb_event_respawns", tostring(value))

        local actor = IsValid(calling_ply) and calling_ply:Nick() or "Console"
        ulx.fancyLogAdmin(calling_ply, "#A " .. (value == 1 and "enabled" or "disabled") .. " event respawns")
        PrintMessage(HUD_PRINTTALK, "[Event] Respawns " .. (value == 1 and "enabled" or "disabled") .. " by " .. actor .. ".")
    end

    local eventRespawnsCmd = ulx.command("ZCity", "ulx eventrespawns", ulx.eventrespawns, "!eventrespawns")
    eventRespawnsCmd:addParam{ type = ULib.cmds.BoolArg, hint = "enable" }
    eventRespawnsCmd:defaultAccess(ULib.ACCESS_ADMIN)
    eventRespawnsCmd:help("Enable or disable timed respawns in Event mode.")

    function ulx.eventrespawndelay(calling_ply, seconds)
        local value = math.Clamp(tonumber(seconds) or 10, 0, 120)
        RunConsoleCommand("zb_event_respawn_delay", tostring(value))

        ulx.fancyLogAdmin(calling_ply, "#A set event respawn delay to #i seconds", math.floor(value + 0.5))
        local actor = IsValid(calling_ply) and calling_ply:Nick() or "Console"
        PrintMessage(HUD_PRINTTALK, "[Event] Respawn delay set to " .. tostring(value) .. "s by " .. actor .. ".")
    end

    local eventRespawnDelayCmd = ulx.command("ZCity", "ulx eventrespawndelay", ulx.eventrespawndelay, "!eventrespawndelay")
    eventRespawnDelayCmd:addParam{ type = ULib.cmds.NumArg, min = 0, max = 120, hint = "seconds", ULib.cmds.round }
    eventRespawnDelayCmd:defaultAccess(ULib.ACCESS_ADMIN)
    eventRespawnDelayCmd:help("Set timed respawn delay for Event mode in seconds.")
end

local function QueueEventRespawn(ply)
    if not eventRespawnsEnabled:GetBool() then return end
    if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then return end
    if not IsEventRoundPlaying() then return end

    local timerName = EventRespawnTimerName(ply)
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end

    local delay = math.max(0, eventRespawnDelay:GetFloat())
    SendEventRespawnTimer(ply, delay)

    timer.Create(timerName, delay, 1, function()
        if not IsValid(ply) or ply:Alive() then return end
        if ply:Team() == TEAM_SPECTATOR then return end
        if not IsEventRoundPlaying() then return end

        SendEventRespawnTimer(ply, -1)

        local spawnPos, spawnAng = MODE:GetEventRespawnPoint(ply._lastEventRespawnPos)
        ply.gottarespawn = true
        ply:Spawn()

        timer.Simple(0, function()
            if not IsValid(ply) or not ply:Alive() then return end
            if isvector(spawnPos) then
                ply:SetPos(spawnPos)
                ply._lastEventRespawnPos = spawnPos
            end
            if isangle(spawnAng) then
                ply:SetEyeAngles(spawnAng)
            end
            ply:SetLocalVelocity(vector_origin)
        end)
    end)
end

function MODE:PlayerDeath(ply)
    QueueEventRespawn(ply)
end

hook.Add("PlayerDeath", "ZB_EventRespawn_Fallback", function(ply)
    QueueEventRespawn(ply)
end)

-- Death hint: if timed respawns are disabled, dead players need to use !join
-- to come back. Surface that as a chat hint a moment after death so they don't
-- assume they're stuck spectating.
hook.Add("PlayerDeath", "ZB_EventJoinHint_OnDeath", function(ply)
    if not IsValid(ply) then return end
    if not IsEventRoundPlaying() then return end
    if eventRespawnsEnabled:GetBool() then return end
    if ply:Team() == TEAM_SPECTATOR then return end

    timer.Simple(2, function()
        if not IsValid(ply) then return end
        if ply:Alive() then return end
        if not IsEventRoundPlaying() then return end
        if eventRespawnsEnabled:GetBool() then return end
        ply:ChatPrint("[Event] Type !join in chat to respawn into the event.")
    end)
end)

function MODE:CanSpawn()
end

function MODE:PlayerSpawn(ply)
    local timerName = EventRespawnTimerName(ply)
    if timer.Exists(timerName) then
        timer.Remove(timerName)
        SendEventRespawnTimer(ply, -1)
    end
end

function MODE:EndRound()
    for _, ply in player.Iterator() do
        local timerName = EventRespawnTimerName(ply)
        if timer.Exists(timerName) then
            timer.Remove(timerName)
            SendEventRespawnTimer(ply, -1)
        end
    end

    timer.Remove(EVENT_CONTAINER_REFILL_TIMER)
    
    timer.Simple(2, function()
        net.Start("event_end")
        local ent = zb:CheckAlive(true)[1]
        net.WriteEntity(IsValid(ent) and ent:Alive() and ent or NULL)
        net.Broadcast()
    end)
end
-- â”€â”€ Event-mode auto-adoption of admin-spawned container props â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- When staff spawn props (e.g. wood crates) during an event round with loot
-- enabled, automatically register them as world containers, mark them so the
-- world-container detector keeps them adopted, generate loot immediately, and
-- push the updated list to the admin container manager.

function MODE:AdoptSpawnedContainerProp(ent)
    if not IsValid(ent) then return end
    if not IsEventRoundPlaying() then return end
    if not self.ContainerAutoRefillEnabled then return end
    if not ZRP then return end

    local model = string.lower(tostring(ent:GetModel() or ""))
    if model == "" then return end

    -- Only adopt whitelisted container models. Random furniture / decor /
    -- ragdoll props spawned by staff stay normal props.
    if not self:IsContainerModelWhitelisted(model) then return end

    local class = ent:GetClass()
    if class == "zrp_container" then return end
    if class ~= "prop_physics" and class ~= "prop_physics_multiplayer"
        and class ~= "prop_physics_override" then
        return
    end

    ent.ZRP_AdoptedByEvent = true

    ZRP.WorldContainerData = ZRP.WorldContainerData or {}

    local pos = ent:GetPos()
    local foundIdx = nil
    for idx, d in ipairs(ZRP.WorldContainerData) do
        if string.lower(tostring(d.model or "")) == model
            and isvector(d.pos) and d.pos:Distance(pos) <= 48 then
            foundIdx = idx
            break
        end
    end

    if not foundIdx then
        ZRP.WorldContainerData[#ZRP.WorldContainerData + 1] = {
            model        = model,
            pos          = pos,
            respawnDelay = EVENT_CONTAINER_REFILL_INTERVAL,
            lootOverride = {},
            auto         = true,
        }
        foundIdx = #ZRP.WorldContainerData
    end

    if ZRP.ActivateWorldContainers then
        ZRP.ActivateWorldContainers()
    end

    local key      = self:GetContainerKey("w", foundIdx)
    local globals  = self:ExpandLootEntries(self:GetLootTable() or {}, true)
    local modelIts = self:ExpandLootEntries(self.ModelLootProfiles[model] or {}, false)
    local specific = self:ExpandLootEntries(self.ContainerLootOverrides[key] or {}, false)
    local chosen   = (#specific > 0 and specific)
        or (#modelIts > 0 and modelIts)
        or globals

    local data = ZRP.WorldContainerData[foundIdx]
    if data then
        data.lootOverride = table.Copy(chosen)
        data.respawnDelay = EVENT_CONTAINER_REFILL_INTERVAL
    end

    ent.ZRP_WorldLootOverride  = table.Copy(chosen)
    ent.ZRP_WorldLootGenerated = false
    if ZRP.ClearContainerInventory then
        ZRP.ClearContainerInventory(ent)
    end
    if ZRP.GenerateContainerInventory then
        ZRP.GenerateContainerInventory(ent, ent:GetModel(), ent.ZRP_WorldLootOverride)
    end

    -- Defer broadcast so we never run inside another net frame and so
    -- multiple rapid spawns coalesce into the next-tick refresh.
    if not self._ContainerListPushQueued then
        self._ContainerListPushQueued = true
        timer.Simple(0, function()
            MODE._ContainerListPushQueued = false
            MODE:SendContainerList()
        end)
    end
end

hook.Add("PlayerSpawnedProp", "ZC_EventAutoAdoptContainer", function(ply, model, ent)
    if not IsValid(ent) then return end
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        MODE:AdoptSpawnedContainerProp(ent)
    end)
end)

-- Fallback for prop spawns that don't go through PlayerSpawnedProp
-- (ULX !prop, duplicator pastes, advanced dupe, admin-only spawners, etc.).
-- Any prop_physics created during an active event round with auto-refill on
-- gets flagged + adopted on the next tick (so CPPI ownership has time to set).
hook.Add("OnEntityCreated", "ZC_EventAutoAdoptContainerFallback", function(ent)
    if not IsValid(ent) then return end
    local class = ent:GetClass()
    if class ~= "prop_physics" and class ~= "prop_physics_multiplayer"
        and class ~= "prop_physics_override" then return end
    timer.Simple(0.1, function()
        if not IsValid(ent) then return end
        if not IsEventRoundPlaying() then return end
        if not MODE.ContainerAutoRefillEnabled then return end
        if ent.ZRP_AdoptedByEvent then return end
        local mdl = tostring(ent:GetModel() or "")
        if mdl == "" then return end
        MODE:AdoptSpawnedContainerProp(ent)
    end)
end)

hook.Add("PhysgunDrop", "ZC_EventReactivateAdoptedContainer", function(ply, ent)
    if not IsValid(ent) then return end
    if not ent.ZRP_AdoptedByEvent then return end
    if not IsEventRoundPlaying() then return end
    if not MODE.ContainerAutoRefillEnabled then return end

    -- Update saved position so it tracks moved props, then re-resolve.
    if ZRP and ZRP.WorldContainerData and ent.ZRP_WorldContainerIdx then
        local data = ZRP.WorldContainerData[ent.ZRP_WorldContainerIdx]
        if data then data.pos = ent:GetPos() end
    end
    if ZRP and ZRP.ActivateWorldContainers then
        ZRP.ActivateWorldContainers()
    end
    if not MODE._ContainerListPushQueued then
        MODE._ContainerListPushQueued = true
        timer.Simple(0, function()
            MODE._ContainerListPushQueued = false
            MODE:SendContainerList()
        end)
    end
end)

