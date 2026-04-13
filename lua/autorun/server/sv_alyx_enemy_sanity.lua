-- sv_alyx_enemy_sanity.lua
-- DCityPatch1.1
--
-- Prevent Alyx from getting stuck targeting npc_bullseye proxies.

if CLIENT then return end

local REACQUIRE_RADIUS = 3000

local HOSTILE_NPC = {
    npc_combine_s = true,
    npc_metropolice = true,
    npc_hunter = true,
    npc_manhack = true,
    npc_rollermine = true,
    npc_clawscanner = true,
    npc_turret_floor = true,
    npc_zombie = true,
    npc_fastzombie = true,
    npc_poisonzombie = true,
    npc_headcrab = true,
    npc_headcrab_fast = true,
    npc_headcrab_poison = true,
    npc_antlion = true,
    npc_antlionguard = true,
}

local function hasLiveEnemy(ent)
    if not IsValid(ent) then return false end
    if type(ent.GetClass) == "function" and ent:GetClass() == "npc_bullseye" then return false end
    if type(ent.GetNPCState) == "function" and ent:GetNPCState() == NPC_STATE_DEAD then return false end
    if type(ent.Alive) == "function" then return ent:Alive() end
    if type(ent.Health) == "function" then return ent:Health() > 0 end
    return true
end

local function isValidTargetForAlyx(alyx, ent)
    if not IsValid(ent) or ent == alyx then return false end
    if ent:GetClass() == "npc_bullseye" then return false end
    if not hasLiveEnemy(ent) then return false end

    if ent:IsNPC() and HOSTILE_NPC[ent:GetClass()] then
        return true
    end

    if ent:IsNPC() and type(alyx.Disposition) == "function" then
        return alyx:Disposition(ent) == D_HT
    end

    return false
end

local function acquireTargetLikeRebel(alyx)
    local origin = alyx:WorldSpaceCenter()
    local best, bestDist = nil, math.huge

    for _, ent in ipairs(ents.FindInSphere(origin, REACQUIRE_RADIUS)) do
        if not isValidTargetForAlyx(alyx, ent) then continue end

        local targetPos = ent:WorldSpaceCenter()
        local dist = origin:DistToSqr(targetPos)
        if dist >= bestDist then continue end

        local tr = util.TraceLine({
            start = origin,
            endpos = targetPos,
            filter = { alyx, ent },
            mask = MASK_SOLID_BRUSHONLY,
        })
        if tr.Hit then continue end

        best = ent
        bestDist = dist
    end

    return best
end

local function sanitizeAlyxEnemy(alyx)
    if not IsValid(alyx) then return end
    if alyx:GetClass() ~= "npc_alyx" then return end
    if type(alyx.GetEnemy) ~= "function" then return end

    -- Optional per-entity pause flag for map/sequence transitions.
    if type(alyx.GetNWBool) == "function" and alyx:GetNWBool("ZC_AlyxSanityPause", false) then
        return
    end

    -- Never interfere with scripted scenes.
    local npcState = type(alyx.GetNPCState) == "function" and alyx:GetNPCState() or nil
    if npcState == NPC_STATE_SCRIPT then
        return
    end

    -- Only sanitize enemies while Alyx is actively in combat.
    -- This avoids stomping map-forced schedules (forced-go, scripted move, etc).
    if npcState ~= NPC_STATE_COMBAT then
        return
    end

    local enemy = alyx:GetEnemy()
    local invalidEnemy = not hasLiveEnemy(enemy) or (IsValid(enemy) and enemy:GetClass() == "npc_bullseye")
    if not invalidEnemy then return end

    if type(alyx.ClearEnemyMemory) == "function" then
        alyx:ClearEnemyMemory()
    end
    if type(alyx.SetEnemy) == "function" then
        alyx:SetEnemy(NULL)
    end

    local best = acquireTargetLikeRebel(alyx)
    if not IsValid(best) then return end

    if type(alyx.UpdateEnemyMemory) == "function" then
        alyx:UpdateEnemyMemory(best, best:WorldSpaceCenter())
    end
    if type(alyx.SetEnemy) == "function" then
        alyx:SetEnemy(best)
    end
end

timer.Create("ZC_AlyxEnemySanity", 0.35, 0, function()
    for _, alyx in ipairs(ents.FindByClass("npc_alyx")) do
        sanitizeAlyxEnemy(alyx)
    end
end)
