-- sv_npc_relationships.lua
-- Fixes two NPC targeting problems in coop:
--
--   1. npc_metropolice neutrality toward rebel players — UpdateEnemyMemory
--      approach is used because AddRelationship/ai_relationship fail for the
--      "player" classname in GMod's Source build.
--
--   2. Combine NPCs (npc_combine_s, npc_metropolice, etc.) targeting
--      Combine/Metrocop players — cleared each Think tick so they never
--      lock onto a friendly player-controlled Combine.
--
-- NotTarget players are excluded from rebel lists and never assigned as
-- enemy targets by either system.
--
-- Performance notes:
--   • REL_THINK_INTERVAL is 0.2 s (not 0.1) — halves per-tick Lua overhead.
--   • Cache rebuild uses one ents.GetAll() pass instead of N FindByClass calls.
--   • zc_npc_lod_dist (default 4500 u): NPCs beyond this from all players have
--     their enemy cleared and are skipped in the acquire loop, suppressing
--     Source engine pathfinding + combat-AI overhead for out-of-range NPCs.
--     Per-NPC LOD rechecks are staggered ~0.75 s apart so they don't spike
--     on the same tick.

if CLIENT then return end
if not ZC_IsPatchRebelPlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

local SCRIPTED_MAPS = {
    ["d1_trainstation_01"] = true,
    ["d1_trainstation_02"] = true,
    ["d1_trainstation_03"] = true,
}

-- Infantry/ground Combine NPCs whose enemy can be safely cleared and redirected.
-- Vehicle-class and heavy NPCs (npc_strider, npc_combinegunship, npc_helicopter)
-- are intentionally excluded: calling ClearEnemyMemory()+SetEnemy(NULL) on them
-- mid-combat corrupts their AI state machine, causing them to self-destruct.
-- That death triggers ZCity's ragdoll cleanup and can leave players stuck
-- ragdolled or stuck upright.
-- Manhacks and cscanners are also excluded — they physics-glitch on enemy clear.
--
local COMBINE_NPC_CLASSES = {
    "npc_combine_s",
    "npc_metropolice",
    "npc_hunter",
    "npc_clawscanner",
    "npc_combine_camera",
    "npc_stalker",
}

-- Lookup set for the single ents.GetAll() cache pass (avoids N FindByClass calls).
local COMBINE_CLASS_SET = {}
for _, c in ipairs(COMBINE_NPC_CLASSES) do COMBINE_CLASS_SET[c] = true end

local cachedCombine = {}   -- all Combine-faction NPCs
local cacheTime     = 0
local nextThinkRun  = 0
local REL_THINK_INTERVAL          = 0.2   -- was 0.1; halved to cut per-tick Lua cost
local CACHE_INTERVAL              = 1
local ACQUIRE_RETRY_INTERVAL_IDLE   = 0.12
local ACQUIRE_RETRY_INTERVAL_ACTIVE = 0.22
local PUSH_MEMORY_INTERVAL        = 0.25
local ACQUIRE_MAX_DIST_SQR        = 12000 * 12000

-- Distance-based LOD: NPCs beyond this distance from all players have their enemy
-- cleared and are skipped — Source engine stops running pathfinding + combat AI for them.
-- Set to 0 to disable. Staggered per-NPC recheck at ~0.75 s prevents tick spikes.
local cv_npc_lod = CreateConVar("zc_npc_lod_dist", "4500", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "NPC combat LOD radius (units). NPCs beyond this from all players have enemies cleared. 0 = off.")

local IS_SCRIPTED_MAP = SCRIPTED_MAPS[game.GetMap()] == true

local acquireSortReb  = {}
local acquireSortDist = {}

-- Pre-cached positions of all alive non-spectator players; rebuilt each Think tick
-- so per-NPC LOD checks don't call player.GetAll() themselves.
local cachedPlayerPos = {}

local function IsNoTarget(ply)
    return ZC_NoTarget and ZC_NoTarget[ply:SteamID()] == true
end

-- Uses the pre-built cachedPlayerPos table (populated at the top of each Think tick).
local function GetNearestPlayerDistSqr(pos)
    local best = math.huge
    for i = 1, #cachedPlayerPos do
        local d = pos:DistToSqr(cachedPlayerPos[i])
        if d < best then best = d end
    end
    return best
end

hook.Add("Think", "ZCity_NPCRelationships", function()
    if IS_SCRIPTED_MAP then return end
    if not CurrentRound then return end
    local round = CurrentRound()
    if not round or round.name ~= "coop" then return end

    local now = CurTime()
    if now < nextThinkRun then return end
    nextThinkRun = now + REL_THINK_INTERVAL

    -- Single ents.GetAll() pass instead of N separate FindByClass calls.
    -- Keep cache refresh short so freshly spawned Combine acquire enemies fast.
    if now > cacheTime then
        cacheTime = now + CACHE_INTERVAL
        cachedCombine = {}
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent:IsNPC() and COMBINE_CLASS_SET[ent:GetClass()] then
                table.insert(cachedCombine, ent)
            end
        end
    end

    -- Build rebel targets and pre-cache all alive player positions for LOD checks.
    -- Both lists come from the same player.GetAll() pass to avoid a second iteration.
    local rebels = {}
    cachedPlayerPos = {}
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive() then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        cachedPlayerPos[#cachedPlayerPos + 1] = ply:GetPos()
        if IsNoTarget(ply) then continue end
        if not ZC_IsPatchRebelPlayer(ply) then continue end
        table.insert(rebels, ply)
    end

    if #rebels <= 0 then return end

    -- Compute LOD threshold once for this tick.
    local lodDist    = cv_npc_lod:GetFloat()
    local lodDistSqr = lodDist > 0 and (lodDist * lodDist) or 0

    -- Conservative fix + fallback acquire:
    -- 1) clear direct friendly-fire targets
    -- 2) if no valid hostile enemy, assign nearest visible rebel player
    -- Do not force schedules/state; let native AI handle combat movement/fire.

    for _, npc in ipairs(cachedCombine) do
        if not IsValid(npc) then continue end
        if npc.GetNPCState and npc:GetNPCState() == NPC_STATE_SCRIPT then continue end
        if npc.ZC_KnockedDown then continue end

        -- Distance-based LOD: stagger per-NPC recheck at ~0.75 s so not all
        -- NPCs evaluate on the same tick. When LOD is active the NPC's enemy is
        -- cleared and it is skipped below — Source stops pathfinding to the player.
        if lodDistSqr > 0 and now >= (npc.ZC_NextLODCheck or 0) then
            npc.ZC_NextLODCheck = now + 0.75 + math.Rand(0, 0.2)
            if GetNearestPlayerDistSqr(npc:GetPos()) > lodDistSqr then
                npc.ZC_LODActive = true
                if IsValid(npc:GetEnemy()) then
                    npc:ClearEnemyMemory()
                    npc:SetEnemy(NULL)
                end
            else
                npc.ZC_LODActive = nil
            end
        end
        if npc.ZC_LODActive then continue end

        local shouldAcquire = false

        local enemy = npc:GetEnemy()
        if IsValid(enemy) then
            if enemy:IsPlayer() then
                if not enemy:Alive() or IsNoTarget(enemy) then
                    shouldAcquire = true
                elseif not ZC_IsPatchRebelPlayer(enemy) then
                    npc:ClearEnemyMemory()
                    npc:SetEnemy(NULL)
                    shouldAcquire = true
                else
                    -- Keep pressure on known rebel targets so Combine keep pushing
                    -- instead of idling when LOS briefly breaks.
                    if now >= (npc.ZC_NextPushMemory or 0) then
                        npc.ZC_NextPushMemory = now + PUSH_MEMORY_INTERVAL + math.Rand(0, 0.08)
                        npc:SetLastPosition(enemy:GetPos())
                        npc:UpdateEnemyMemory(enemy, enemy:GetPos())
                        if SCHED_CHASE_ENEMY and npc.SetSchedule and npc.GetNPCState and npc:GetNPCState() == NPC_STATE_IDLE then
                            npc:SetSchedule(SCHED_CHASE_ENEMY)
                        end
                    end
                    continue
                end
            else
                -- Keep valid hostile NPC targets (antlions, zombies, etc.).
                if enemy.Health and enemy:Health() > 0 then
                    continue
                end
                shouldAcquire = true
            end
        else
            shouldAcquire = true
        end

        if not shouldAcquire then continue end
        if now < (npc.ZC_NextAcquire or 0) then continue end
        local retry = IsValid(enemy) and ACQUIRE_RETRY_INTERVAL_ACTIVE or ACQUIRE_RETRY_INTERVAL_IDLE
        npc.ZC_NextAcquire = now + retry + math.Rand(0, 0.08)

        local eyePos = npc:EyePos()
        local bestFallback, bestFallbackDist = nil, math.huge
        local nac = 0

        for _, rebel in ipairs(rebels) do
            local dist = eyePos:DistToSqr(rebel:GetPos())
            if dist > ACQUIRE_MAX_DIST_SQR then continue end

            if dist < bestFallbackDist then
                bestFallback = rebel
                bestFallbackDist = dist
            end

            nac = nac + 1
            acquireSortReb[nac] = rebel
            acquireSortDist[nac] = dist
        end

        if nac > 1 then
            for i = 2, nac do
                local ri, di = acquireSortReb[i], acquireSortDist[i]
                local j = i
                while j > 1 and acquireSortDist[j - 1] > di do
                    acquireSortReb[j] = acquireSortReb[j - 1]
                    acquireSortDist[j] = acquireSortDist[j - 1]
                    j = j - 1
                end
                acquireSortReb[j] = ri
                acquireSortDist[j] = di
            end
        end

        local bestVisible = nil
        for i = 1, nac do
            local rebel = acquireSortReb[i]
            local tr = util.TraceLine({
                start  = eyePos,
                endpos = rebel:EyePos(),
                filter = { npc, rebel },
                mask   = MASK_BLOCKLOS,
            })
            if not tr.Hit then
                bestVisible = rebel
                break
            end
        end

        local best = bestVisible or bestFallback
        if not IsValid(best) then continue end

        if npc.IsAsleep and npc:IsAsleep() then
            npc:SetAsleep(false)
        end

        npc:SetLastPosition(best:GetPos())
        npc:UpdateEnemyMemory(best, best:GetPos())
        npc:SetEnemy(best)
    end
end)
