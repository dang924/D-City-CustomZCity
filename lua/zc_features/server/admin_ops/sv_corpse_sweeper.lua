if CLIENT then return end

local CV_ENABLE = CreateConVar(
    "zc_corpse_sweeper_enable",
    "1",
    FCVAR_ARCHIVE,
    "Enable periodic cleanup of NPC corpses and dead player bodies."
)

local CV_INTERVAL = CreateConVar(
    "zc_corpse_sweeper_interval",
    "180",
    FCVAR_ARCHIVE,
    "Seconds between corpse sweeps."
)

local function BuildProtectedRagdollSet()
    local protected = {}
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end

        if IsValid(ply.FakeRagdoll) then
            protected[ply.FakeRagdoll] = true
        end

        if IsValid(ply.GlideRagdoll) then
            protected[ply.GlideRagdoll] = true
        end

        if ply.GetNWEntity then
            local nwRag = ply:GetNWEntity("FakeRagdoll")
            if IsValid(nwRag) then
                protected[nwRag] = true
            end
        end
    end
    return protected
end

local function IsAlivePlayerRagdoll(ragdoll, protectedSet)
    if not IsValid(ragdoll) or ragdoll:GetClass() ~= "prop_ragdoll" then return false end

    if protectedSet and protectedSet[ragdoll] then
        return true
    end

    if hg and hg.RagdollOwner then
        local owner = hg.RagdollOwner(ragdoll)
        if IsValid(owner) and owner:IsPlayer() and owner:Alive() then
            return true
        end
    end

    if ragdoll.GetNWEntity then
        local owner = ragdoll:GetNWEntity("RagdollOwner")
        if IsValid(owner) and owner:IsPlayer() and owner:Alive() then
            return true
        end

        local ply = ragdoll:GetNWEntity("ply")
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
            if ply:GetNWEntity("FakeRagdoll") == ragdoll or ply.FakeRagdoll == ragdoll then
                return true
            end
        end
    end

    return false
end

local function SweepCorpses(reason)
    local removedRagdolls = 0
    local protectedRagdolls = 0
    local removedDeadNpc = 0
    local removedDroppedWeapons = 0
    local protectedNpcComponents = 0
    local protectedSet = BuildProtectedRagdollSet()

    local function IsProtectedNpcComponent(ent)
        if IsValid(ent:GetParent()) then return true end

        local owner = ent.GetOwner and ent:GetOwner() or nil
        if IsValid(owner) and (owner:IsNPC() or owner:IsVehicle() or owner:IsPlayer()) then
            return true
        end

        -- A lot of legacy SNPC parts are "alive" but use StartHealth=0.
        if ent.Dead == false then
            return true
        end

        return false
    end

    local function IsClearlyDeadNpc(ent)
        if ent.Dead == true then return true end
        if ent.GetNWBool and ent:GetNWBool("Dead", false) then return true end
        if ent.GetInternalVariable then
            local lifeState = ent:GetInternalVariable("m_lifeState")
            if isnumber(lifeState) and lifeState ~= 0 then
                return true
            end
        end

        return false
    end

    -- Most dead NPC/player bodies resolve to prop_ragdoll.
    for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
        if not IsValid(ent) then continue end

        -- Keep map-authored ragdolls (set-dressing) intact.
        if ent.MapCreationID and ent:MapCreationID() ~= -1 then continue end

        if IsAlivePlayerRagdoll(ent, protectedSet) then
            protectedRagdolls = protectedRagdolls + 1
        else
            ent:Remove()
            removedRagdolls = removedRagdolls + 1
        end
    end

    -- Safety pass for dead NPC entities that did not convert to ragdolls.
    for _, ent in ipairs(ents.FindByClass("npc_*")) do
        if not IsValid(ent) or not ent:IsNPC() then continue end

        if IsProtectedNpcComponent(ent) then
            protectedNpcComponents = protectedNpcComponents + 1
            continue
        end

        if ent:Health() > 0 then continue end
        if not IsClearlyDeadNpc(ent) then continue end

        ent:Remove()
        removedDeadNpc = removedDeadNpc + 1
    end

    -- Remove dropped floor weapons, but keep physcannon intact.
    for _, ent in ipairs(ents.FindByClass("weapon_*")) do
        if not IsValid(ent) or not ent:IsWeapon() then continue end

        local className = string.lower(tostring(ent:GetClass() or ""))
        if className == "weapon_physcannon" then continue end

        -- Keep map-authored pickups and anything still attached/owned.
        if ent.MapCreationID and ent:MapCreationID() ~= -1 then continue end
        if IsValid(ent:GetParent()) then continue end

        local owner = ent.GetOwner and ent:GetOwner() or nil
        if IsValid(owner) then continue end

        ent:Remove()
        removedDroppedWeapons = removedDroppedWeapons + 1
    end

    if removedRagdolls > 0 or removedDeadNpc > 0 or removedDroppedWeapons > 0 then
        print(string.format(
            "[ZC corpse sweep] %s | removed ragdolls=%d dead_npc=%d dropped_weapons=%d protected_living_ragdolls=%d protected_npc_components=%d",
            tostring(reason or "timer"),
            removedRagdolls,
            removedDeadNpc,
            removedDroppedWeapons,
            protectedRagdolls,
            protectedNpcComponents
        ))
    end
end

local nextSweep = 0

hook.Add("InitPostEntity", "ZC_CorpseSweeper_Init", function()
    nextSweep = CurTime() + math.max(30, CV_INTERVAL:GetFloat())
end)

hook.Add("PostCleanupMap", "ZC_CorpseSweeper_PostCleanupMap", function()
    nextSweep = CurTime() + math.max(30, CV_INTERVAL:GetFloat())
end)

hook.Add("Think", "ZC_CorpseSweeper_Think", function()
    if not CV_ENABLE:GetBool() then return end
    if CurTime() < nextSweep then return end

    SweepCorpses("timer")
    nextSweep = CurTime() + math.max(30, CV_INTERVAL:GetFloat())
end)

concommand.Add("zc_corpse_sweep_now", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    SweepCorpses(IsValid(ply) and ("manual:" .. ply:Nick()) or "manual:server")
    nextSweep = CurTime() + math.max(30, CV_INTERVAL:GetFloat())
end)
