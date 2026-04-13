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
local COMBINE_NPC_CLASSES = {
    "npc_combine_s",
    "npc_metropolice",
    "npc_hunter",
    "npc_clawscanner",
    "npc_combine_camera",
    "npc_stalker",
}

local cachedCombine = {}   -- all Combine-faction NPCs
local cacheTime     = 0
local nextThinkRun  = 0
local REL_THINK_INTERVAL = 0.1
local CACHE_INTERVAL = 1
local ACQUIRE_RETRY_INTERVAL_IDLE = 0.12
local ACQUIRE_RETRY_INTERVAL_ACTIVE = 0.22
local PUSH_MEMORY_INTERVAL = 0.25
local ACQUIRE_MAX_DIST_SQR = 12000 * 12000
local IS_SCRIPTED_MAP = SCRIPTED_MAPS[game.GetMap()] == true

local acquireSortReb = {}
local acquireSortDist = {}

local function IsNoTarget(ply)
    return ZC_NoTarget and ZC_NoTarget[ply:SteamID()] == true
end

hook.Add("Think", "ZCity_NPCRelationships", function()
    if IS_SCRIPTED_MAP then return end
    if not CurrentRound then return end
    local round = CurrentRound()
    if not round or round.name ~= "coop" then return end

    local now = CurTime()
    if now < nextThinkRun then return end
    nextThinkRun = now + REL_THINK_INTERVAL

    -- Keep cache refresh short so freshly spawned Combine acquire enemies fast.
    if now > cacheTime then
        cacheTime = now + CACHE_INTERVAL
        cachedCombine = {}
        -- npc_metropolice is already listed in COMBINE_NPC_CLASSES (old extra scan removed).

        for _, class in ipairs(COMBINE_NPC_CLASSES) do
            for _, npc in ipairs(ents.FindByClass(class)) do
                if IsValid(npc) then table.insert(cachedCombine, npc) end
            end
        end
    end

    -- Build rebel targets explicitly so Combine AI can reacquire even when
    -- bullseye routing fails to hand off a valid hostile enemy.
    local rebels = {}
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive() then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if IsNoTarget(ply) then continue end
        if not ZC_IsPatchRebelPlayer(ply) then continue end
        table.insert(rebels, ply)
    end

    if #rebels <= 0 then return end

    -- Conservative fix + fallback acquire:
    -- 1) clear direct friendly-fire targets
    -- 2) if no valid hostile enemy, assign nearest visible rebel player
    -- Do not force schedules/state; let native AI handle combat movement/fire.

    for _, npc in ipairs(cachedCombine) do
        if not IsValid(npc) then continue end
        if npc.GetNPCState and npc:GetNPCState() == NPC_STATE_SCRIPT then continue end

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
