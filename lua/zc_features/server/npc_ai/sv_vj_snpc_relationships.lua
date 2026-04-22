-- sv_vj_snpc_relationships.lua
-- Fixes VJ Base SNPC faction targeting for ZCity coop with player-controlled factions.
--
-- Root cause: VJ Base's MaintainRelationships ignores GMod's AddEntityRelationship table.
-- It uses its own per-entity RelationshipMemory system. The correct API is:
--   npc:SetRelationshipMemory(ply, VJ.MEM_OVERRIDE_DISPOSITION, D_HT/D_LI)
-- VJ Base checks MEM_OVERRIDE_DISPOSITION first in MaintainRelationships, taking absolute
-- priority over class-based disposition, and persists permanently (VJ Base never resets it).
--
-- Problems solved:
--   1. Rebel VJ SNPCs (CLASS_PLAYER_ALLY / AlliedWithPlayerAllies) treat ALL players
--      as D_LI (including Combine players). Fix: D_HT for active Combine players via
--      SetRelationshipMemory so MaintainRelationships treats them hostile.
--
--   2. Combine VJ SNPCs (CLASS_COMBINE) are D_HT toward ALL players (including player-
--      controlled Combine). Fix: D_LI for Combine players via SetRelationshipMemory.
--
-- Relationship overrides are applied:
--   • When a VJ SNPC spawns (OnEntityCreated + 0.2s, after VJ Base's own Init timer)
--   • When a player spawns or initially joins (PlayerSpawn / PlayerInitialSpawn)
--   • In Think when player faction change is detected via playerFactionCache
--   • In Think as a fallback when ZC_VJ_RelApplied flag is missing
--
-- Enemy correction still runs in Think at 0.2s — clears wrong enemies and force-sets
-- valid ones, because VJ Base's MaintainRelationships auto-engages only entities already
-- in its RelationshipEnts table, which may not include late-joining players.

if CLIENT then return end
if not ZC_IsPatchRebelPlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

-- Default ON: apply VJ relationship overrides unless explicitly disabled.
local cv_enable_vj_rel = CreateConVar("zc_enable_vj_relationship_overrides", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Enable VJ SNPC relationship overrides for player factions.")
if not cv_enable_vj_rel:GetBool() then return end

-- ── Faction detection ─────────────────────────────────────────────────────────
-- Determined by VJ_NPC_Class table on the entity.

local REBEL_VJ_CLASS_SET = {
    ["class_citizen_passive"]   = true,
    ["class_citizen_rebel"]     = true,
    ["class_player_ally"]       = true,
    ["class_player_ally_vital"] = true,
    ["class_vortigaunt"]        = true,
}

local COMBINE_VJ_CLASS_SET = {
    ["class_clawscanner"]     = true,
    ["class_combine"]         = true,
    ["class_combine_gunship"] = true,
    ["class_hunter"]          = true,
    ["class_manhack"]         = true,
    ["class_metropolice"]     = true,
    ["class_scanner"]         = true,
    ["class_stalker"]         = true,
}

-- Returns "rebel", "combine", or nil. Only matches entities with a VJ_NPC_Class table.
local function GetVJFaction(npc)
    local vjClass = npc.VJ_NPC_Class
    if not istable(vjClass) then return nil end
    for _, cls in ipairs(vjClass) do
        if isstring(cls) then
            local lower = string.lower(cls)
            if REBEL_VJ_CLASS_SET[lower]   then return "rebel"   end
            if COMBINE_VJ_CLASS_SET[lower] then return "combine" end
        end
    end
    return nil
end

-- ── Timing constants ──────────────────────────────────────────────────────────

local REL_THINK_INTERVAL   = 0.2    -- Think loop cadence (matches sv_npc_relationships)
local CACHE_INTERVAL       = 1.0    -- NPC cache rebuild interval
local PUSH_MEMORY_INTERVAL = 0.25   -- UpdateEnemyMemory refresh for active targets
local ACQUIRE_MAX_DIST_SQR = 12000 * 12000

-- ── State ─────────────────────────────────────────────────────────────────────

local cachedRebelVJ   = {}
local cachedCombineVJ = {}
local cacheTime       = 0
local nextThinkRun    = 0

local cachedPlayerPos    = {}   -- pre-built each tick for LOD checks
local playerFactionCache = {}   -- [SteamID] = "combine"|"rebel" — detects class changes mid-round

local acquireSortEnt  = {}
local acquireSortDist = {}

-- Reuse zc_npc_lod_dist if sv_npc_relationships.lua already created it.
local cv_npc_lod = GetConVar("zc_npc_lod_dist")
    or CreateConVar("zc_npc_lod_dist", "4500", FCVAR_ARCHIVE + FCVAR_NOTIFY,
        "NPC combat LOD radius (units). NPCs beyond this from all players have enemies cleared. 0 = off.")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function IsNoTarget(ply)
    return ZC_NoTarget and ZC_NoTarget[ply:SteamID()] == true
end

local function GetNearestPlayerDistSqr(pos)
    local best = math.huge
    for i = 1, #cachedPlayerPos do
        local d = pos:DistToSqr(cachedPlayerPos[i])
        if d < best then best = d end
    end
    return best
end

-- Invalidate ZC_VJ_RelApplied on all cached VJ NPCs so the next Think tick
-- re-applies relationships (called when any player's faction changes).
local function InvalidateAllRelApplied()
    for _, npc in ipairs(cachedRebelVJ) do
        if IsValid(npc) then npc.ZC_VJ_RelApplied = nil end
    end
    for _, npc in ipairs(cachedCombineVJ) do
        if IsValid(npc) then npc.ZC_VJ_RelApplied = nil end
    end
end

-- Apply VJ Base relationship overrides for a single NPC against all current players.
--
-- Uses npc:SetRelationshipMemory(ply, VJ.MEM_OVERRIDE_DISPOSITION, D_HT/D_LI) — the
-- correct VJ Base API. This is checked first in MaintainRelationships, overriding
-- class-based disposition (AlliedWithPlayerAllies, VJ_NPC_Class, etc.).
-- Once set, it persists permanently; VJ Base never resets MEM_OVERRIDE_DISPOSITION.
--
-- Rebel VJ SNPC:
--   Combine players (active)  → D_HT  (MaintainRelationships will ForceSetEnemy)
--   Combine players (NoTarget)→ D_LI  (prevent VJ Base auto-attacking no-target players)
--   Rebel players             → D_LI  (explicit, defensive)
-- Combine VJ SNPC:
--   Combine players           → D_LI  (including NoTarget — they must not be attacked)
--   Rebel players             → omit  (VJ Base default D_HT applies naturally)
local function ApplyRelationshipsToNPC(npc, faction)
    if not IsValid(npc) then return end
    if not npc.SetRelationshipMemory then return end    -- guard: VJ Base NPCs only
    if not VJ or not VJ.MEM_OVERRIDE_DISPOSITION then return end  -- VJ Base not loaded yet

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        local isCombine = ZC_IsPatchCombinePlayer(ply)
        if faction == "rebel" then
            if isCombine then
                local disp = IsNoTarget(ply) and D_LI or D_HT
                npc:SetRelationshipMemory(ply, VJ.MEM_OVERRIDE_DISPOSITION, disp)
            else
                npc:SetRelationshipMemory(ply, VJ.MEM_OVERRIDE_DISPOSITION, D_LI)
            end
        elseif faction == "combine" then
            if isCombine then
                npc:SetRelationshipMemory(ply, VJ.MEM_OVERRIDE_DISPOSITION, D_LI)
            end
            -- Rebel players: leave unset — VJ Base's default D_HT applies.
        end
    end

    npc.ZC_VJ_RelApplied = true
end

-- Apply relationships for a single player across all currently cached VJ NPCs.
-- Called on PlayerSpawn/PlayerInitialSpawn to handle the new player.
local function ApplyRelationshipsForPlayer(ply)
    if not IsValid(ply) then return end
    InvalidateAllRelApplied()
    for _, npc in ipairs(cachedRebelVJ) do
        if IsValid(npc) then ApplyRelationshipsToNPC(npc, "rebel") end
    end
    for _, npc in ipairs(cachedCombineVJ) do
        if IsValid(npc) then ApplyRelationshipsToNPC(npc, "combine") end
    end
end

-- Nearest-visible acquire, mirrors sv_npc_relationships.lua logic.
local function AcquireNearest(npc, targets)
    local eyePos = npc:EyePos()
    local bestFallback, bestFallbackDist = nil, math.huge
    local nac = 0

    for _, tgt in ipairs(targets) do
        local dist = eyePos:DistToSqr(tgt:GetPos())
        if dist > ACQUIRE_MAX_DIST_SQR then continue end
        if dist < bestFallbackDist then
            bestFallback     = tgt
            bestFallbackDist = dist
        end
        nac = nac + 1
        acquireSortEnt[nac]  = tgt
        acquireSortDist[nac] = dist
    end

    if nac > 1 then
        for i = 2, nac do
            local ri, di = acquireSortEnt[i], acquireSortDist[i]
            local j = i
            while j > 1 and acquireSortDist[j - 1] > di do
                acquireSortEnt[j]  = acquireSortEnt[j - 1]
                acquireSortDist[j] = acquireSortDist[j - 1]
                j = j - 1
            end
            acquireSortEnt[j]  = ri
            acquireSortDist[j] = di
        end
    end

    for i = 1, nac do
        local tgt = acquireSortEnt[i]
        local tr = util.TraceLine({
            start  = eyePos,
            endpos = tgt:EyePos(),
            filter = { npc, tgt },
            mask   = MASK_BLOCKLOS,
        })
        if not tr.Hit then return tgt end
    end
    return bestFallback
end

-- ── Event hooks ───────────────────────────────────────────────────────────────

-- New VJ SNPC spawned: apply faction relationships after a 0.2s delay so that
-- VJ Base's own Init + hooks.lua timer (0.1s) has finished initializing RelationshipMemory.
hook.Add("OnEntityCreated", "ZCity_VJSNPCRelationships_Spawn", function(ent)
    if not IsValid(ent) then return end
    if not ent:IsNPC() then return end
    timer.Simple(0.2, function()
        if not IsValid(ent) then return end
        local faction = GetVJFaction(ent)
        if not faction then return end
        ApplyRelationshipsToNPC(ent, faction)
    end)
end)

-- Player respawns: delay 0.5s so the player's faction class is set before we read it.
hook.Add("PlayerSpawn", "ZCity_VJSNPCRelationships_PlayerSpawn", function(ply)
    timer.Simple(0.5, function() ApplyRelationshipsForPlayer(ply) end)
end)

-- Player first joins the server.
hook.Add("PlayerInitialSpawn", "ZCity_VJSNPCRelationships_PlayerInitialSpawn", function(ply)
    timer.Simple(1.0, function() ApplyRelationshipsForPlayer(ply) end)
end)

-- Clean up faction cache when a player disconnects.
hook.Add("PlayerDisconnected", "ZCity_VJSNPCRelationships_PlayerDisconnect", function(ply)
    if IsValid(ply) then playerFactionCache[ply:SteamID()] = nil end
end)

-- ── Main Think ────────────────────────────────────────────────────────────────

hook.Add("Think", "ZCity_VJSNPCRelationships", function()
    if not CurrentRound then return end
    local round = CurrentRound()
    if not round or round.name ~= "coop" then return end

    local now = CurTime()
    if now < nextThinkRun then return end
    nextThinkRun = now + REL_THINK_INTERVAL

    -- Rebuild VJ NPC cache once per second (single ents.GetAll pass).
    if now > cacheTime then
        cacheTime = now + CACHE_INTERVAL
        cachedRebelVJ   = {}
        cachedCombineVJ = {}
        for _, ent in ipairs(ents.GetAll()) do
            if not IsValid(ent) or not ent:IsNPC() then continue end
            local faction = GetVJFaction(ent)
            if faction == "rebel" then
                table.insert(cachedRebelVJ, ent)
            elseif faction == "combine" then
                table.insert(cachedCombineVJ, ent)
            end
        end
    end

    -- Build player faction lists + pre-cache positions for LOD checks.
    -- Detect faction changes via playerFactionCache (handles mid-round class switches
    -- without needing to hook Player:SetPlayerClass).
    local combinePlayers = {}
    local rebelPlayers   = {}
    cachedPlayerPos      = {}
    local factionChanged = false
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive()  then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        cachedPlayerPos[#cachedPlayerPos + 1] = ply:GetPos()

        local isCombine = ZC_IsPatchCombinePlayer(ply)
        local curFaction = isCombine and "combine" or "rebel"
        local sid = ply:SteamID()
        if playerFactionCache[sid] ~= curFaction then
            playerFactionCache[sid] = curFaction
            factionChanged = true
        end

        if IsNoTarget(ply) then continue end
        if isCombine then
            table.insert(combinePlayers, ply)
        else
            table.insert(rebelPlayers, ply)
        end
    end

    local hasCombinePlayers = #combinePlayers > 0
    local hasRebelPlayers   = #rebelPlayers > 0

    if not hasCombinePlayers and not hasRebelPlayers then return end

    -- If any player switched faction class this tick, invalidate all cached NPCs
    -- so ApplyRelationshipsToNPC runs for each one below.
    if factionChanged then
        InvalidateAllRelApplied()
    end

    local lodDist    = cv_npc_lod:GetFloat()
    local lodDistSqr = lodDist > 0 and (lodDist * lodDist) or 0

    -- ── 1. Rebel VJ SNPCs → target Combine players ───────────────────────────
    --
    -- SetRelationshipMemory sets MEM_OVERRIDE_DISPOSITION permanently. VJ Base's own
    -- MaintainRelationships then calls ForceSetEnemy when the hostile entity is visible
    -- in the sight cone. We also force SetEnemy directly to handle entities not yet in
    -- the NPC's RelationshipEnts table (e.g., late-joining players).

    if hasCombinePlayers then
        for _, npc in ipairs(cachedRebelVJ) do
            if not IsValid(npc) then continue end
            if npc.GetNPCState and npc:GetNPCState() == NPC_STATE_SCRIPT then continue end
            if npc.ZC_KnockedDown then continue end

            -- Apply relationships once per NPC (or once per faction change).
            if not npc.ZC_VJ_RelApplied then
                ApplyRelationshipsToNPC(npc, "rebel")
            end

            -- LOD: stagger per-NPC recheck to avoid tick spikes.
            if lodDistSqr > 0 and now >= (npc.ZC_VJR_NextLODCheck or 0) then
                npc.ZC_VJR_NextLODCheck = now + 0.75 + math.Rand(0, 0.2)
                if GetNearestPlayerDistSqr(npc:GetPos()) > lodDistSqr then
                    npc.ZC_VJR_LODActive = true
                    if IsValid(npc:GetEnemy()) then
                        npc:ClearEnemyMemory()
                        npc:SetEnemy(NULL)
                    end
                else
                    npc.ZC_VJR_LODActive = nil
                end
            end
            if npc.ZC_VJR_LODActive then continue end

            local shouldAcquire = false
            local enemy = npc:GetEnemy()
            if IsValid(enemy) then
                if enemy:IsPlayer() then
                    if not enemy:Alive() or IsNoTarget(enemy) then
                        shouldAcquire = true
                    elseif ZC_IsPatchCombinePlayer(enemy) then
                        -- Actively targeting a Combine player — keep memory pressure so
                        -- the NPC doesn't idle when LOS briefly breaks.
                        if now >= (npc.ZC_VJR_NextPushMemory or 0) then
                            npc.ZC_VJR_NextPushMemory = now + PUSH_MEMORY_INTERVAL + math.Rand(0, 0.08)
                            npc:SetLastPosition(enemy:GetPos())
                            npc:UpdateEnemyMemory(enemy, enemy:GetPos())
                        end
                        continue
                    else
                        -- Targeting a rebel player — rebel SNPC must never target rebels.
                        npc:ClearEnemyMemory()
                        npc:SetEnemy(NULL)
                        shouldAcquire = true
                    end
                else
                    -- Valid non-player enemy (zombie, antlion, etc.) — leave alone.
                    if enemy.Health and enemy:Health() > 0 then continue end
                    shouldAcquire = true
                end
            else
                shouldAcquire = true
            end

            if not shouldAcquire then continue end
            if now < (npc.ZC_VJR_NextAcquire or 0) then continue end
            npc.ZC_VJR_NextAcquire = now + 0.15 + math.Rand(0, 0.08)

            local best = AcquireNearest(npc, combinePlayers)
            if not IsValid(best) then continue end

            npc:SetLastPosition(best:GetPos())
            npc:UpdateEnemyMemory(best, best:GetPos())
            npc:SetEnemy(best)
        end
    end

    -- ── 2. Combine VJ SNPCs → don't target Combine players ───────────────────
    --
    -- MEM_OVERRIDE_DISPOSITION D_LI for Combine players stops MaintainRelationships
    -- from calling ForceSetEnemy on them. We also clear any already-acquired wrong enemy
    -- and redirect to a rebel player.

    if hasCombinePlayers then
        for _, npc in ipairs(cachedCombineVJ) do
            if not IsValid(npc) then continue end
            if npc.GetNPCState and npc:GetNPCState() == NPC_STATE_SCRIPT then continue end
            if npc.ZC_KnockedDown then continue end

            -- Apply relationships once per NPC (or once per faction change).
            if not npc.ZC_VJ_RelApplied then
                ApplyRelationshipsToNPC(npc, "combine")
            end

            -- LOD
            if lodDistSqr > 0 and now >= (npc.ZC_VJC_NextLODCheck or 0) then
                npc.ZC_VJC_NextLODCheck = now + 0.75 + math.Rand(0, 0.2)
                if GetNearestPlayerDistSqr(npc:GetPos()) > lodDistSqr then
                    npc.ZC_VJC_LODActive = true
                    if IsValid(npc:GetEnemy()) then
                        npc:ClearEnemyMemory()
                        npc:SetEnemy(NULL)
                    end
                else
                    npc.ZC_VJC_LODActive = nil
                end
            end
            if npc.ZC_VJC_LODActive then continue end

            local enemy = npc:GetEnemy()
            if IsValid(enemy) then
                if enemy:IsPlayer() then
                    if not enemy:Alive() or IsNoTarget(enemy) then
                        npc:ClearEnemyMemory()
                        npc:SetEnemy(NULL)
                    elseif ZC_IsPatchCombinePlayer(enemy) then
                        -- Targeting a Combine player — clear and redirect to a rebel.
                        npc:ClearEnemyMemory()
                        npc:SetEnemy(NULL)
                        if hasRebelPlayers then
                            if now >= (npc.ZC_VJC_NextAcquire or 0) then
                                npc.ZC_VJC_NextAcquire = now + 0.15 + math.Rand(0, 0.08)
                                local best = AcquireNearest(npc, rebelPlayers)
                                if IsValid(best) then
                                    npc:SetLastPosition(best:GetPos())
                                    npc:UpdateEnemyMemory(best, best:GetPos())
                                    npc:SetEnemy(best)
                                end
                            end
                        end
                    else
                        -- Targeting a rebel player or non-player — fine, keep it.
                        if now >= (npc.ZC_VJC_NextPushMemory or 0) and enemy:IsPlayer() then
                            npc.ZC_VJC_NextPushMemory = now + PUSH_MEMORY_INTERVAL + math.Rand(0, 0.08)
                            npc:SetLastPosition(enemy:GetPos())
                            npc:UpdateEnemyMemory(enemy, enemy:GetPos())
                        end
                    end
                end
                -- Non-player enemies left to VJ Base.
            else
                -- No current enemy: try to acquire a rebel player.
                if hasRebelPlayers then
                    if now >= (npc.ZC_VJC_NextAcquire or 0) then
                        npc.ZC_VJC_NextAcquire = now + 0.15 + math.Rand(0, 0.08)
                        local best = AcquireNearest(npc, rebelPlayers)
                        if IsValid(best) then
                            npc:SetLastPosition(best:GetPos())
                            npc:UpdateEnemyMemory(best, best:GetPos())
                            npc:SetEnemy(best)
                        end
                    end
                end
            end
        end
    end
end)
