-- Group grenade/push logic
local lastGroupGrenadeTime = 0
local GROUP_GRENADE_COOLDOWN = 120
local GROUP_RADIUS_SQR = 900 * 900 -- 900 units
local MIN_GROUP_SIZE = 4
local combineRegistry = {}

local function CanGroupGrenade()
    return CurTime() - lastGroupGrenadeTime > GROUP_GRENADE_COOLDOWN
end

local function DoGroupGrenade()
    lastGroupGrenadeTime = CurTime()
    -- Find all groups of Combine within radius
    local processed = {}
    for _, npc in pairs(combineRegistry) do
        if not IsValid(npc) or processed[npc] then continue end
        local group = {npc}
        local pos = npc:GetPos()
        for _, mate in pairs(combineRegistry) do
            if mate ~= npc and IsValid(mate) and not processed[mate] and mate:GetPos():DistToSqr(pos) < GROUP_RADIUS_SQR then
                table.insert(group, mate)
            end
        end
        if #group >= MIN_GROUP_SIZE then
            -- All in group throw grenade if able
            for _, member in ipairs(group) do
                if member:Weapon_TranslateActivity(ACT_RANGE_ATTACK2) then
                    member:SetSchedule(SCHED_RANGE_ATTACK2) -- throw grenade
                end
                processed[member] = true
            end
            -- After a short delay, all push forward
            timer.Simple(2, function()
                for _, member in ipairs(group) do
                    if IsValid(member) then
                        member:SetSchedule(SCHED_CHASE_ENEMY)
                    end
                end
            end)
            break -- Only one group per cooldown
        end
    end
end

-- sv_combine_aggro.lua
-- ZCity Combine/Metrocop Aggro System (testing build)
-- Drops into lua/autorun/server/ in your DCityPatchPack test addon.
-- Handles aggro-based targeting, squad communication, and scripted sequence safety, with bullseye support.

if CLIENT then return end

local cv_enable_aggro_testing = CreateConVar(
    "zc_enable_combine_aggro_testing",
    "0",
    FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Enable legacy testing combine aggro system. Disabled by default because it can thrash AI pathing.",
    0,
    1
)

if not cv_enable_aggro_testing:GetBool() then
    print("[ZCity] Combine aggro testing system disabled (zc_enable_combine_aggro_testing=0).")
    return
end

-- Scripted sequence safety: skip on known maps
local SCRIPTED_MAPS = {
    ["d1_trainstation_01"] = true,
    ["d1_trainstation_02"] = true,
    ["d1_trainstation_03"] = true,
}
local IS_SCRIPTED_MAP = SCRIPTED_MAPS[game.GetMap()] == true

if IS_SCRIPTED_MAP then
    print("[ZCity] Combine aggro system disabled on scripted map.")
    return
end

local AGGRO_NPC_CLASSES = {
    ["npc_combine_s"] = true,
    ["npc_metropolice"] = true,
}
combineRegistry = combineRegistry or {}

-- Placeholder: Replace with your actual Combine player detection logic
local function IsCombinePlayer(ply)
    -- Example: return ply:Team() == TEAM_COMBINE
    if ZC_IsPatchCombinePlayer then
        return ZC_IsPatchCombinePlayer(ply)
    end
    return ply.IsCombinePlayer and ply:IsCombinePlayer() or false
end

-- Placeholder: Replace with your actual bullseye lookup logic
local function GetBullseyeForPlayer(ply)
    if ply.ZC_Bullseye and IsValid(ply.ZC_Bullseye) then
        return ply.ZC_Bullseye
    end
    return ply
end

local function TrackCombineNPC(ent)
    if IsValid(ent) and AGGRO_NPC_CLASSES[ent:GetClass()] then
        combineRegistry[ent:EntIndex()] = ent
        ent.zc_aggro = {}
    end
end

hook.Add("OnEntityCreated", "ZCity_Aggro_TrackCombine", function(ent)
    timer.Simple(0, function() TrackCombineNPC(ent) end)
end)
hook.Add("EntityRemoved", "ZCity_Aggro_RemoveCombine", function(ent)
    combineRegistry[ent:EntIndex()] = nil
end)
hook.Add("InitPostEntity", "ZCity_Aggro_InitRegistry", function()
    combineRegistry = {}
    for _, ent in ipairs(ents.GetAll()) do
        TrackCombineNPC(ent)
    end
end)

-- Threat assessment: armed, hostile, or high aggro
local function AssessThreat(npc, ply)
    if not IsValid(ply) or not ply:Alive() then return 0 end
    if IsCombinePlayer(ply) then return 0 end -- Don't treat Combine players as threats
    local threat = 0
    if ply:GetActiveWeapon() and ply:GetActiveWeapon():IsValid() then
        threat = threat + 10 -- armed
    end
    if npc.zc_aggro and npc.zc_aggro[ply] and npc.zc_aggro[ply] > 0 then
        threat = threat + npc.zc_aggro[ply]
    end
    -- Add more threat logic as needed
    return threat
end

-- Communicate with squad
local function AlertSquad(npc, ply, threat)
    local pos = npc:GetPos()
    for _, mate in pairs(combineRegistry) do
        if mate ~= npc and mate:GetPos():DistToSqr(pos) < (600^2) then -- 600 units radius
            mate.zc_aggro = mate.zc_aggro or {}
            mate.zc_aggro[ply] = (mate.zc_aggro[ply] or 0) + math.floor(threat * 0.5)
        end
    end
end


-- On sight: assess and alert (immediate engage if player is armed)
hook.Add("NPCEnemyChanged", "ZCity_Aggro_OnSeeTarget", function(npc, oldEnemy, newEnemy)
    if not AGGRO_NPC_CLASSES[npc:GetClass()] then return end
    if IsValid(newEnemy) and newEnemy:IsPlayer() then
        if IsCombinePlayer(newEnemy) then return end -- Don't alert squad about Combine players
        local wep = newEnemy:GetActiveWeapon()
        if IsValid(wep) then
            -- Player is armed: alert squad and set as enemy immediately
            AlertSquad(npc, newEnemy, 20)
            npc:AddEntityRelationship(newEnemy, D_HT, 99)
            npc:SetEnemy(newEnemy)
            return
        end
        local threat = AssessThreat(npc, newEnemy)
        if threat > 0 then
            AlertSquad(npc, newEnemy, threat)
        end
    end
end)

-- Add aggro when player damages NPC
hook.Add("EntityTakeDamage", "ZCity_Aggro_OnDamage", function(target, dmginfo)
    if not AGGRO_NPC_CLASSES[target:GetClass()] then return end
    local attacker = dmginfo:GetAttacker()
    if attacker:IsPlayer() then
        if IsCombinePlayer(attacker) then return end -- Don't aggro on Combine players
        target.zc_aggro = target.zc_aggro or {}
        target.zc_aggro[attacker] = (target.zc_aggro[attacker] or 0) + dmginfo:GetDamage()
    end
end)

if timer.Exists("ZCity_Aggro_Think") then timer.Remove("ZCity_Aggro_Think") end

local AGGRO_ENGAGE_DIST_SQR = 1200 * 1200
local AGGRO_SQUAD_RADIUS_SQR = 600 * 600
local AGGRO_THRESHOLD = 10
local AGGRO_DECAY = 1

timer.Create("ZCity_Aggro_Think", 0.2, 0, function()
    local now = CurTime()
    local hostileRebelNPCs = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and (ent:GetClass() == "npc_citizen" or ent:GetClass() == "npc_alyx" or ent:GetClass() == "npc_barney" or ent:GetClass() == "npc_vortigaunt") then
            hostileRebelNPCs[#hostileRebelNPCs + 1] = ent
        end
    end

    for _, npc in pairs(combineRegistry) do
        if not IsValid(npc) then continue end
        local aggro = npc.zc_aggro or {}
        -- Decay aggro
        for ply, score in pairs(aggro) do
            if not IsValid(ply) or not ply:Alive() or IsCombinePlayer(ply) then
                aggro[ply] = nil
            else
                aggro[ply] = math.max(0, score - AGGRO_DECAY)
            end
        end
        -- Find highest aggro
        local topPly, topScore = nil, 0
        for ply, score in pairs(aggro) do
            if score > topScore then
                topPly, topScore = ply, score
            end
        end
        -- Engage if in range or spotted (players)
        if topPly and topScore > AGGRO_THRESHOLD then
            local targetEnt = GetBullseyeForPlayer(topPly)
            if npc:Visible(targetEnt) and npc:GetPos():DistToSqr(targetEnt:GetPos()) < AGGRO_ENGAGE_DIST_SQR then
                if npc:GetEnemy() ~= targetEnt and now >= (npc.zc_nextForcedEnemy or 0) then
                    npc.zc_nextForcedEnemy = now + 0.6
                    npc:AddEntityRelationship(targetEnt, D_HT, 99)
                    npc:SetEnemy(targetEnt)
                end
            end
        end
        -- Always target hostile rebel NPCs
        for _, ent in ipairs(hostileRebelNPCs) do
            if npc:Visible(ent) and npc:GetPos():DistToSqr(ent:GetPos()) < AGGRO_ENGAGE_DIST_SQR then
                if npc:GetEnemy() ~= ent and now >= (npc.zc_nextForcedEnemy or 0) then
                    npc.zc_nextForcedEnemy = now + 0.6
                    npc:AddEntityRelationship(ent, D_HT, 99)
                    npc:SetEnemy(ent)
                end
            end
        end
    end

    -- Group grenade/push event
    if CanGroupGrenade() then
        DoGroupGrenade()
    end
end)

print("[ZCity] Combine aggro system loaded (testing build)")
