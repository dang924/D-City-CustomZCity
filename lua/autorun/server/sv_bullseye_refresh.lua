-- Handles rebel NPC relationships toward players on class change,
-- and npc_sniper nerf/friendly-fire filter.

if CLIENT then return end
if not ZC_IsPatchRebelPlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

local bullseyeNPCRegistry = {}

local function TrackBullseyeNPC(ent)
    if IsValid(ent) and ent:IsNPC() then
        bullseyeNPCRegistry[ent:EntIndex()] = ent
    end
end

hook.Add("InitPostEntity", "ZCity_BullseyeNPCRegistry_Init", function()
    bullseyeNPCRegistry = {}
    for _, e in ipairs(ents.GetAll()) do
        TrackBullseyeNPC(e)
    end
end)

hook.Add("OnEntityCreated", "ZCity_BullseyeNPCRegistry_Add", function(ent)
    timer.Simple(0, function()
        TrackBullseyeNPC(ent)
    end)
end)

hook.Add("EntityRemoved", "ZCity_BullseyeNPCRegistry_Remove", function(ent)
    if not IsValid(ent) then return end
    bullseyeNPCRegistry[ent:EntIndex()] = nil
end)

local LIKELY_COMBINE_PLAYER_CLASSES = {
    ["combine"]  = true,
    ["metrocop"] = true,
}

local LIKELY_FRIENDLY_NPCS = {
    ["npc_alyx"]                      = true,
    ["npc_barney"]                    = true,
    ["npc_citizen"]                   = true,
    ["npc_dog"]                       = true,
    ["npc_eli"]                       = true,
    ["npc_kleiner"]                   = true,
    ["npc_magnusson"]                 = true,
    ["npc_monk"]                      = true,
    ["npc_mossman"]                   = true,
    ["npc_odessa"]                    = true,
    ["npc_rollermine_hacked"]         = true,
    ["npc_turret_floor_resistance"]   = true,
    ["npc_vortigaunt"]                = true,
}

local LIKELY_HOSTILE_NPCS = {
    ["npc_clawscanner"]     = true,
    ["npc_combine_camera"]  = true,
    ["npc_combinedropship"] = true,
    ["npc_combinegunship"]  = true,
    ["npc_combine_s"]       = true,
    ["npc_cscanner"]        = true,
    ["npc_helicopter"]      = true,
    ["npc_hunter"]          = true,
    ["npc_manhack"]         = true,
    ["npc_metropolice"]     = true,
    ["npc_rollermine"]      = true,
    ["npc_sniper"]          = true,
    ["npc_stalker"]         = true,
    ["npc_strider"]         = true,
    ["npc_turret_ceiling"]  = true,
    ["npc_turret_floor"]    = true,
}

local FRIENDLY_CLASS_TOKENS = {
    "rebel", "resistance", "citizen", "barney", "alyx", "vort",
    "kleiner", "eli", "odessa", "mossman", "magnusson", "dog",
    "fisherman", "_ally", "ally_"
}

local HOSTILE_CLASS_TOKENS = {
    "combine", "metrocop", "overwatch", "civil_protection",
    "civilprotection", "scanner", "manhack", "hunter", "strider",
    "gunship", "dropship", "stalker", "advisor", "sniper"
}

local FRIENDLY_VJ_CLASS_TAGS = {
    ["class_citizen_passive"]    = true,
    ["class_citizen_rebel"]      = true,
    ["class_player_ally"]        = true,
    ["class_player_ally_vital"]  = true,
    ["class_vortigaunt"]         = true,
}

local HOSTILE_VJ_CLASS_TAGS = {
    ["class_clawscanner"]      = true,
    ["class_combine"]          = true,
    ["class_combine_gunship"]  = true,
    ["class_hunter"]           = true,
    ["class_manhack"]          = true,
    ["class_metropolice"]      = true,
    ["class_scanner"]          = true,
    ["class_stalker"]          = true,
}

local function LowerString(value)
    return isstring(value) and string.lower(value) or nil
end

local function HasAnyToken(value, tokens)
    local lowered = LowerString(value)
    if not lowered then return false end

    for _, token in ipairs(tokens) do
        if string.find(lowered, token, 1, true) then
            return true
        end
    end

    return false
end

local function TableHasLookupValue(values, lookup)
    local lowered = LowerString(values)
    if lowered then return lookup[lowered] or false end
    if not istable(values) then return false end

    for _, value in pairs(values) do
        lowered = LowerString(value)
        if lowered and lookup[lowered] then
            return true
        end
    end

    return false
end

local function TableHasAnyToken(values, tokens)
    if HasAnyToken(values, tokens) then return true end
    if not istable(values) then return false end

    for _, value in pairs(values) do
        if HasAnyToken(value, tokens) then
            return true
        end
    end

    return false
end

local function IsLikelyCombinePlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    return not ZC_IsPatchRebelPlayer(ply)
end

local function GetLikelyNPCFaction(npc)
    if not IsValid(npc) then return nil end

    local className = LowerString(npc:GetClass()) or ""
    if npc.PlayerFriendly == true or npc.FriendsWithAllPlayerAllies == true then
        return "friendly"
    end
    if npc.PlayerFriendly == false then
        return "hostile"
    end

    if LIKELY_FRIENDLY_NPCS[className] then return "friendly" end
    if LIKELY_HOSTILE_NPCS[className] then return "hostile" end

    local vjClass = npc.VJ_NPC_Class
    if TableHasLookupValue(vjClass, FRIENDLY_VJ_CLASS_TAGS)
        or TableHasAnyToken(vjClass, FRIENDLY_CLASS_TOKENS)
        or HasAnyToken(className, FRIENDLY_CLASS_TOKENS) then
        return "friendly"
    end

    if TableHasLookupValue(vjClass, HOSTILE_VJ_CLASS_TAGS)
        or TableHasAnyToken(vjClass, HOSTILE_CLASS_TOKENS)
        or HasAnyToken(className, HOSTILE_CLASS_TOKENS) then
        return "hostile"
    end

    -- VJ SNPC naming convention: _h suffix = hostile variant, _a suffix = ally variant
    if string.sub(className, -2) == "_h" then return "hostile" end
    if string.sub(className, -2) == "_a" then return "friendly" end

    return nil
end

local function ApplyInferredRelationship(npc, ply)
    if not IsValid(npc) or not IsValid(ply) or not npc.AddEntityRelationship then return end
    if IsValid(npc:GetParent()) then return end  -- child turrets/parented sub-entities; parent NPC handles its own relationships

    local npcFaction = GetLikelyNPCFaction(npc)
    if not npcFaction then return end

    local playerIsCombine = IsLikelyCombinePlayer(ply)
    if npcFaction == "friendly" then
        npc:AddEntityRelationship(ply, playerIsCombine and D_HT or D_LI, playerIsCombine and 99 or 0)
        return
    end

    npc:AddEntityRelationship(ply, playerIsCombine and D_LI or D_HT, playerIsCombine and 0 or 99)
end

local function RefreshEntityRelationships(npc)
    if not IsValid(npc) or not npc.AddEntityRelationship then return end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ApplyInferredRelationship(npc, ply)
        end
    end
end

-- Refresh inferred NPC relationships toward a player after their class changes.
local function RefreshBullseye(ply)
    if not IsValid(ply) then return end
    local now = CurTime()
    if ply.ZC_NextBullseyeRefresh and ply.ZC_NextBullseyeRefresh > now then return end
    ply.ZC_NextBullseyeRefresh = now + 1.5

    local function SetRelationships()
        if not IsValid(ply) then return end

        for idx, npc in pairs(bullseyeNPCRegistry) do
            if not IsValid(npc) then
                bullseyeNPCRegistry[idx] = nil
            else
                ApplyInferredRelationship(npc, ply)
            end
        end
    end

    -- Start at 0.5 — avoids touching unparented VJ sub-entities during a concurrent spawn.
    timer.Simple(0.5, SetRelationships)
    timer.Simple(1.5, SetRelationships)
end

local function ResolvePlayerTarget(ent)
    if not IsValid(ent) then return NULL end
    if ent:IsPlayer() then return ent end

    local targetPly = ent.ply
    if IsValid(targetPly) and targetPly:IsPlayer() then
        return targetPly
    end

    targetPly = ent:GetOwner()
    if IsValid(targetPly) and targetPly:IsPlayer() then
        return targetPly
    end

    targetPly = ent:GetParent()
    if IsValid(targetPly) and targetPly:IsPlayer() then
        return targetPly
    end

    return NULL
end

-- Metatable override must be set at file load — not inside a coop-gated function —
-- because SetPlayerClass is called during round transitions on all gamemodes.
local Player = FindMetaTable("Player")
local originalSetPlayerClass = Player.SetPlayerClass
function Player:SetPlayerClass(value, data)
    originalSetPlayerClass(self, value, data)
    if SERVER and IsValid(self) and self:IsPlayer() then
        RefreshBullseye(self)
    end
end

hook.Add("PlayerSpawn", "ZCity_RefreshBullseyeOnSpawn", function(ply)
    RefreshBullseye(ply)
end)

hook.Add("PlayerInitialSpawn", "ZCity_RefreshBullseyeOnInitialSpawn", function(ply)
    RefreshBullseye(ply)
end)

hook.Add("OnEntityCreated", "ZCity_RefreshBullseyeOnNPCSpawn", function(ent)
    -- Delay long enough for VJ's own timer.Simple(0) parenting to finish before
    -- we check GetParent() — otherwise we lose the race and corrupt child turret AI.
    timer.Simple(0.5, function()
        if not IsValid(ent) or not ent.AddEntityRelationship then return end
        RefreshEntityRelationships(ent)
    end)
end)

-- ── npc_sniper nerf and friendly-fire filter ──────────────────────────────────
-- Only active in coop — wrapped in InitPostEntity guard.

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    local SNIPER_PAINT_INTERVAL = 2.0
    local SNIPER_MISSES         = 1
    local SNIPER_MIN_DIST       = 512
    local SNIPER_MIN_DIST_SQR   = SNIPER_MIN_DIST * SNIPER_MIN_DIST
    local SNIPER_SHOOT_COOLDOWN = 4.0
    local SNIPER_THINK_INTERVAL = 0.2
    local nextSniperThink       = 0

    hook.Add("OnEntityCreated", "ZCity_SniperNerf", function(ent)
        timer.Simple(0.1, function()
            if not IsValid(ent) or ent:GetClass() ~= "npc_sniper" then return end
            ent:SetKeyValue("PaintInterval",         tostring(SNIPER_PAINT_INTERVAL))
            ent:SetKeyValue("PaintIntervalVariance", "0.5")
            ent:SetKeyValue("misses",                tostring(SNIPER_MISSES))
            ent.ZC_NextShot = 0
        end)
    end)

    hook.Add("Think", "ZCity_SniperFriendlyFire", function()
        local now = CurTime()
        if now < nextSniperThink then return end
        nextSniperThink = now + SNIPER_THINK_INTERVAL

        local validTargets = {}
        for _, ply in ipairs(player.GetAll()) do
            if not ply:Alive() then continue end
            if not ZC_IsPatchRebelPlayer(ply) then continue end
            table.insert(validTargets, ply)
        end

        for _, sniper in ipairs(ents.FindByClass("npc_sniper")) do
            if not IsValid(sniper) then continue end
            local enemy = sniper:GetEnemy()
            if not IsValid(enemy) then continue end
            local targetPly = ResolvePlayerTarget(enemy)

            if IsValid(targetPly) and not ZC_IsPatchRebelPlayer(targetPly) then
                sniper:ClearEnemyMemory()
                local best, bestDist = nil, math.huge
                for _, ply in ipairs(validTargets) do
                    local dist = sniper:GetPos():DistToSqr(ply:GetPos())
                    if dist < bestDist then bestDist = dist; best = ply end
                end
                if IsValid(best) then sniper:SetEnemy(best) end
                continue
            end

            if IsValid(targetPly) then
                if sniper:GetPos():DistToSqr(targetPly:GetPos()) < SNIPER_MIN_DIST_SQR then
                    sniper:ClearEnemyMemory()
                    continue
                end
            end

            sniper.ZC_NextShot = sniper.ZC_NextShot or 0
            if now < sniper.ZC_NextShot then
                sniper:SetKeyValue("misses", "99")
            else
                sniper:SetKeyValue("misses", tostring(SNIPER_MISSES))
                sniper.ZC_NextShot = now + SNIPER_SHOOT_COOLDOWN
            end
        end
    end)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svbullseyerefresh", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)
hook.Add("Think", "ZC_CoopInit_svbullseyerefresh_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svbullseyerefresh_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)

