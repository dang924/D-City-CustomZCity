local HOLD_TIME = 0.35
local USE_RANGE = 110
local SCAN_RANGE = 130
local CARRY_ANCHOR_BONE = "ValveBiped.Bip01_Spine2"
-- Back-to-back chest weld pose from spine anchor.
local CARRY_OFFSET = Vector(-10, 0, 4)
local CARRY_ANGLE_OFFSET = Angle(0, 180, 0)

local function IsZScavBackCarryDisabled()
    return ZSCAV and ZSCAV.IsActive and ZSCAV:IsActive()
end

local CHEST_ANCHOR_BONE_PRIORITY = {
    "spine2",
    "spine3",
    "spine4",
    "spine1",
    "spine",
}

local function GetRagdollOwner(ent)
    if not IsValid(ent) then return nil end

    local candidates = {
        ent.ply,
        ent.GetNWEntity and ent:GetNWEntity("ply") or nil,
        ent.GetNWEntity and ent:GetNWEntity("RagdollOwner") or nil,
    }

    if hg and hg.RagdollOwner then
        local ok, owner = pcall(hg.RagdollOwner, ent)
        if ok then
            candidates[#candidates + 1] = owner
        end
    end

    for index = 1, #candidates do
        local candidate = candidates[index]
        if IsValid(candidate) and candidate:IsPlayer() then
            if candidate.FakeRagdoll == ent or candidate:GetNWEntity("FakeRagdoll") == ent then
                return candidate
            end
        end
    end

    for _, candidate in ipairs(player.GetAll()) do
        if candidate.FakeRagdoll == ent or candidate:GetNWEntity("FakeRagdoll") == ent then
            return candidate
        end
    end

    return nil
end

local function GetTargetRagdoll(target)
    if not IsValid(target) then return nil end
    return target.FakeRagdoll or target:GetNWEntity("FakeRagdoll")
end

local function ResolveCarryableFakeRagdoll(target, ragdoll)
    if not IsValid(target) or not target:IsPlayer() then return nil end
    if not target:Alive() then return nil end

    local fakeRagdoll = GetTargetRagdoll(target)
    if not IsValid(fakeRagdoll) or not fakeRagdoll:IsRagdoll() then return nil end
    if IsValid(ragdoll) and fakeRagdoll ~= ragdoll then return nil end

    return fakeRagdoll
end

local function CanCarryNow(ply)
    if IsZScavBackCarryDisabled() then return false end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
    if ply:InVehicle() then return false end
    if IsValid(ply.FakeRagdoll) then return false end
    if ply.organism and ply.organism.otrub then return false end
    if IsValid(ply:GetNetVar("carryent")) or IsValid(ply:GetNetVar("carryent2")) then return false end
    if IsValid(ply.ZCBackCarryRagdoll) then return false end
    return true
end

local function CanMaintainCarry(ply)
    if IsZScavBackCarryDisabled() then return false end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
    if ply:InVehicle() then return false end
    if IsValid(ply.FakeRagdoll) then return false end
    if ply.organism and ply.organism.otrub then return false end
    if IsValid(ply:GetNetVar("carryent")) or IsValid(ply:GetNetVar("carryent2")) then return false end
    return true
end

local function GetRagdollDistanceFromCarrier(ply, ragdoll)
    if not IsValid(ply) or not IsValid(ragdoll) then return math.huge end
    return ragdoll:GetPos():Distance(ply:GetPos())
end

local function ResolveEntityTarget(ply, ent)
    if not IsValid(ent) then return nil end

    local target = nil
    local ragdoll = nil

    if ent:IsPlayer() then
        target = ent
        ragdoll = GetTargetRagdoll(ent)
    elseif ent:IsRagdoll() then
        ragdoll = ent
        target = GetRagdollOwner(ent)
    elseif IsValid(ent.ply) and ent.ply:IsPlayer() then
        target = ent.ply
        ragdoll = ent
    end

    if not IsValid(target) or target == ply then return nil end
    ragdoll = ResolveCarryableFakeRagdoll(target, ragdoll)
    if not IsValid(ragdoll) then return nil end
    if GetRagdollDistanceFromCarrier(ply, ragdoll) > USE_RANGE then return nil end

    local carrier = IsValid(target.ZCBackCarrier) and target.ZCBackCarrier or nil
    if IsValid(carrier) and carrier ~= ply then return nil end

    return target, ragdoll
end

local function ResolveCarryTarget(ply)
    if not CanCarryNow(ply) then return nil end
    if not hg or not hg.eyeTrace then return nil end

    local tr = hg.eyeTrace(ply)
    local ent = tr and tr.Entity or nil
    local target, ragdoll = ResolveEntityTarget(ply, ent)
    if IsValid(target) and IsValid(ragdoll) then
        return target, ragdoll
    end

    local bestTarget = nil
    local bestRagdoll = nil
    local bestDist = SCAN_RANGE

    for _, candidate in ipairs(player.GetAll()) do
        if candidate == ply then continue end

        local candidateRagdoll = candidate.FakeRagdoll or candidate:GetNWEntity("FakeRagdoll")
        candidateRagdoll = ResolveCarryableFakeRagdoll(candidate, candidateRagdoll or GetTargetRagdoll(candidate))
        if not IsValid(candidateRagdoll) then continue end

        local carrier = IsValid(candidate.ZCBackCarrier) and candidate.ZCBackCarrier or nil
        if IsValid(carrier) and carrier ~= ply then continue end

        local dist = GetRagdollDistanceFromCarrier(ply, candidateRagdoll)
        if dist > bestDist then continue end

        bestDist = dist
        bestTarget = candidate
        bestRagdoll = candidateRagdoll
    end

    return bestTarget, bestRagdoll
end

function ZC_BackCarryWouldHandle(ply, target)
    if not IsValid(ply) or not IsValid(target) then return false end
    if not CanCarryNow(ply) then return false end
    if not target:IsPlayer() or target == ply then return false end

    local ragdoll = ResolveCarryableFakeRagdoll(target, GetTargetRagdoll(target))
    if not IsValid(ragdoll) then return false end

    return GetRagdollDistanceFromCarrier(ply, ragdoll) <= USE_RANGE
end

local function ClearPending(ply)
    if not IsValid(ply) then return end
    ply.ZCBackCarryPendingSince = nil
    ply.ZCBackCarryPendingTarget = nil
    ply.ZCBackCarryPendingRagdoll = nil
    ply:SetNWFloat("ZCBackCarryHoldStart", 0)
end

local function GetCarryTransform(ply)
    if not IsValid(ply) then return vector_origin, angle_zero end

    local basePos = ply:GetPos() + Vector(0, 0, 48)
    local anchorBone = ply:LookupBone(CARRY_ANCHOR_BONE)
    if anchorBone then
        local bonePos = ply:GetBonePosition(anchorBone)
        if isvector(bonePos) and bonePos ~= vector_origin then
            basePos = bonePos
        end
    end

    local baseAng = ply:GetAngles()
    local carryPos = basePos + baseAng:Forward() * CARRY_OFFSET[1] + baseAng:Right() * CARRY_OFFSET[2] + Vector(0, 0, CARRY_OFFSET[3])
    local carryAng = baseAng + CARRY_ANGLE_OFFSET

    return carryPos, carryAng
end

local function GetChestAnchorScore(boneName)
    local lowered = string.lower(tostring(boneName or ""))
    for index, token in ipairs(CHEST_ANCHOR_BONE_PRIORITY) do
        if string.find(lowered, token, 1, true) then
            return index
        end
    end

    return nil
end

local function BuildCarryAnchorData(ragdoll, carryPos, carryAng)
    if not IsValid(ragdoll) then return {} end

    local best = nil
    local firstValid = nil
    local physCount = ragdoll:GetPhysicsObjectCount() - 1

    for physIndex = 0, physCount do
        local phys = ragdoll:GetPhysicsObjectNum(physIndex)
        if not IsValid(phys) then continue end

        local boneIndex = ragdoll:TranslatePhysBoneToBone(physIndex)
        local boneName = boneIndex and boneIndex >= 0 and ragdoll:GetBoneName(boneIndex) or ""
        if not firstValid then
            firstValid = {
                physIndex = physIndex,
                score = math.huge,
            }
        end

        local score = GetChestAnchorScore(boneName)
        if not score then continue end
        if best and best.score <= score then continue end

        best = {
            physIndex = physIndex,
            score = score,
        }
    end

    if best then
        best.score = nil
        return {best}
    end

    if firstValid then
        firstValid.score = nil
        return {firstValid}
    end

    return {}
end

local SyncCarriedRagdollPosition

local function RestoreRagdollPhysics(ragdoll, velocity)
    if not IsValid(ragdoll) then return end

    ragdoll:SetMoveType(MOVETYPE_VPHYSICS)
    ragdoll:SetNotSolid(false)
    ragdoll:SetCollisionGroup(ragdoll.ZCBackCarryCollisionGroup or COLLISION_GROUP_NONE)
    ragdoll.ZCBackCarryCollisionGroup = nil
    ragdoll.ZCBackCarryCarrier = nil
    ragdoll.ZCBackCarryAnchors = nil

    local physCount = ragdoll:GetPhysicsObjectCount() - 1
    for physIndex = 0, physCount do
        local phys = ragdoll:GetPhysicsObjectNum(physIndex)
        if IsValid(phys) then
            phys:EnableMotion(true)
            if velocity then
                phys:SetVelocity(velocity)
            end
            phys:Wake()
        end
    end
end

local function DropCarriedRagdoll(ply, dropPos)
    local ragdoll = IsValid(ply) and ply.ZCBackCarryRagdoll or nil
    local target = IsValid(ply) and ply.ZCBackCarryTarget or nil
    if not IsValid(ragdoll) then
        if IsValid(ply) then
            ply.ZCBackCarryRagdoll = nil
            ply.ZCBackCarryTarget = nil
            ply:SetNWEntity("ZCBackCarryRagdoll", NULL)
            ply:SetNWEntity("ZCBackCarryTarget", NULL)
        end
        if IsValid(target) then
            target.ZCBackCarrier = nil
            target:SetNWEntity("ZCBackCarrier", NULL)
        end
        return false
    end

    local basePos = dropPos
    if not basePos and IsValid(ply) then
        basePos = ply:GetPos() + ply:GetForward() * 28 + Vector(0, 0, 14)
    end

    -- Don't inherit carrier velocity on drop to prevent launch
    ragdoll:SetPos(basePos or ragdoll:GetPos())
    ragdoll:SetAngles(IsValid(ply) and ply:GetAngles() or ragdoll:GetAngles())
    RestoreRagdollPhysics(ragdoll, vector_origin)

    if IsValid(target) then
        target.ZCBackCarrier = nil
        target:SetNWEntity("ZCBackCarrier", NULL)
    end

    if IsValid(ply) then
        ply.ZCBackCarryRagdoll = nil
        ply.ZCBackCarryTarget = nil
        ply:SetNWEntity("ZCBackCarryRagdoll", NULL)
        ply:SetNWEntity("ZCBackCarryTarget", NULL)
        ply:EmitSound("npc/roller/mine/rmine_blades_out1.wav", 60, 110)
    end

    return true
end

local function StartCarry(ply, target, ragdoll)
    if not CanCarryNow(ply) then return false end
    if not IsValid(target) or not IsValid(ragdoll) then return false end
    if IsValid(target.ZCBackCarrier) and target.ZCBackCarrier ~= ply then return false end

    if IsValid(ply.ZCBackCarryRagdoll) then
        DropCarriedRagdoll(ply)
    end

    ragdoll.ZCBackCarryCollisionGroup = ragdoll:GetCollisionGroup()
    ragdoll:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    ragdoll:SetMoveType(MOVETYPE_VPHYSICS)
    ragdoll:SetNotSolid(true)

    local carryPos, carryAng = GetCarryTransform(ply)
    ragdoll.ZCBackCarryAnchors = BuildCarryAnchorData(ragdoll, carryPos, carryAng)

    local physCount = ragdoll:GetPhysicsObjectCount() - 1
    local anchorIndex = ragdoll.ZCBackCarryAnchors[1] and ragdoll.ZCBackCarryAnchors[1].physIndex or nil
    for physIndex = 0, physCount do
        local phys = ragdoll:GetPhysicsObjectNum(physIndex)
        if IsValid(phys) then
            phys:SetVelocityInstantaneous(vector_origin)
            if anchorIndex ~= nil and physIndex == anchorIndex then
                phys:EnableMotion(false)
                phys:Sleep()
            else
                phys:EnableMotion(true)
                phys:Wake()
            end
        end
    end

    ragdoll.ZCBackCarryCarrier = ply
    ragdoll.ZCBackCarrySyncTime = CurTime()

    ply.ZCBackCarryRagdoll = ragdoll
    ply.ZCBackCarryTarget = target
    target.ZCBackCarrier = ply
    ply:SetNWEntity("ZCBackCarryRagdoll", ragdoll)
    ply:SetNWEntity("ZCBackCarryTarget", target)
    target:SetNWEntity("ZCBackCarrier", ply)

    ply:EmitSound("physics/body/body_medium_impact_soft5.wav", 65, 105)
    target:EmitSound("physics/body/body_medium_impact_soft5.wav", 55, 95)
    target:ChatPrint("[BackCarry] Type !getoff to drop off the carrier.")

    timer.Simple(0, function()
        if IsValid(ply) and IsValid(ragdoll) and ply.ZCBackCarryRagdoll == ragdoll then
            local syncPos, syncAng = GetCarryTransform(ply)
            SyncCarriedRagdollPosition(ply, ragdoll, syncPos, syncAng)
        end
    end)

    return true
end

SyncCarriedRagdollPosition = function(ply, ragdoll, carryPos, carryAng)
    if not IsValid(ply) or not IsValid(ragdoll) then return end

    carryPos = carryPos or select(1, GetCarryTransform(ply))
    carryAng = carryAng or select(2, GetCarryTransform(ply))

    -- Avoid origin teleports every tick (camera jitter); only correct large drift.
    if ragdoll:GetPos():DistToSqr(carryPos) > (48 * 48) then
        ragdoll:SetPos(carryPos)
    end

    for _, anchor in ipairs(ragdoll.ZCBackCarryAnchors or {}) do
        local phys = ragdoll:GetPhysicsObjectNum(anchor.physIndex)
        if IsValid(phys) then
            -- Hard chest weld target: force the chest physbone onto the carrier back transform.
            phys:SetPos(carryPos)
            phys:SetAngles(carryAng)
            phys:EnableMotion(false)
            phys:Sleep()
        end
    end
end

hook.Add("KeyPress", "ZC_AmputeeBackCarry_Pickup", function(ply, key)
    if key ~= IN_USE then return end
    if IsValid(ply.ZCBackCarryRagdoll) then
        DropCarriedRagdoll(ply)
        return
    end

    local target, ragdoll = ResolveCarryTarget(ply)
    if not IsValid(target) or not IsValid(ragdoll) then
        ClearPending(ply)
        return
    end

    ply.ZCBackCarryPendingSince = CurTime()
    ply.ZCBackCarryPendingTarget = target
    ply.ZCBackCarryPendingRagdoll = ragdoll
    ply:SetNWFloat("ZCBackCarryHoldStart", ply.ZCBackCarryPendingSince)
end)

hook.Add("KeyRelease", "ZC_AmputeeBackCarry_CancelHold", function(ply, key)
    if key ~= IN_USE then return end

    local pendingTarget = ply.ZCBackCarryPendingTarget
    local shouldAttemptRevive = ply.ZCBackCarryPendingSince ~= nil and IsValid(pendingTarget) and not IsValid(ply.ZCBackCarryRagdoll)

    ClearPending(ply)

    if shouldAttemptRevive and isfunction(_G.ZC_CoopTryReviveUse) then
        _G.ZC_CoopTryReviveUse(ply, {
            target = pendingTarget,
            ignoreBackCarry = true,
            silentTargetState = true,
        })
    end
end)

hook.Add("Think", "ZC_AmputeeBackCarry_Think", function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        if IsValid(ply.ZCBackCarryRagdoll) then
            local ragdoll = ply.ZCBackCarryRagdoll
            local target = ply.ZCBackCarryTarget

            local badState = not CanMaintainCarry(ply)
                or not IsValid(ragdoll)
                or not IsValid(target)
                or target.ZCBackCarrier ~= ply
                or not target:Alive()
                or GetTargetRagdoll(target) ~= ragdoll

            if badState then
                DropCarriedRagdoll(ply)
            else
                -- Sync position every frame to keep ragdoll on carrier's back
                SyncCarriedRagdollPosition(ply, ragdoll)
            end
        end

        if not ply.ZCBackCarryPendingSince then continue end

        if not ply:KeyDown(IN_USE) then
            ClearPending(ply)
            continue
        end

        if (CurTime() - ply.ZCBackCarryPendingSince) < HOLD_TIME then continue end

        local currentTarget, currentRagdoll = ResolveCarryTarget(ply)
        if currentTarget ~= ply.ZCBackCarryPendingTarget or currentRagdoll ~= ply.ZCBackCarryPendingRagdoll then
            ClearPending(ply)
            continue
        end

        StartCarry(ply, currentTarget, currentRagdoll)
        ClearPending(ply)
    end
end)

hook.Add("PlayerDeath", "ZC_AmputeeBackCarry_PlayerDeath", function(victim)
    ClearPending(victim)
    if IsValid(victim.ZCBackCarryRagdoll) then
        DropCarriedRagdoll(victim)
    end

    local carrier = IsValid(victim.ZCBackCarrier) and victim.ZCBackCarrier or nil
    if IsValid(carrier) then
        DropCarriedRagdoll(carrier)
    end
end)

hook.Add("PlayerDisconnected", "ZC_AmputeeBackCarry_PlayerDisconnected", function(ply)
    ClearPending(ply)
    if IsValid(ply.ZCBackCarryRagdoll) then
        DropCarriedRagdoll(ply)
    end

    local carrier = IsValid(ply.ZCBackCarrier) and ply.ZCBackCarrier or nil
    if IsValid(carrier) then
        DropCarriedRagdoll(carrier)
    end
end)

hook.Add("PlayerEnteredVehicle", "ZC_AmputeeBackCarry_EnteredVehicle", function(ply)
    ClearPending(ply)
    if IsValid(ply.ZCBackCarryRagdoll) then
        DropCarriedRagdoll(ply)
    end
end)

hook.Add("Player Spawn", "ZC_AmputeeBackCarry_PlayerSpawn", function(ply)
    ClearPending(ply)
    if IsValid(ply.ZCBackCarryRagdoll) then
        DropCarriedRagdoll(ply)
    end

    local carrier = IsValid(ply.ZCBackCarrier) and ply.ZCBackCarrier or nil
    if IsValid(carrier) then
        DropCarriedRagdoll(carrier)
    end
end)

hook.Add("HG_PlayerSay", "ZC_AmputeeBackCarry_GetOff", function(ply, txtTbl, text)
    local cmd = string.lower(string.Trim(text or ""))
    if cmd ~= "!getoff" and cmd ~= "/getoff" then return end

    txtTbl[1] = ""

    local carrier = IsValid(ply.ZCBackCarrier) and ply.ZCBackCarrier or nil
    if not IsValid(carrier) or carrier.ZCBackCarryTarget ~= ply then
        ply:ChatPrint("[BackCarry] You are not currently being carried.")
        return ""
    end

    DropCarriedRagdoll(carrier)

    if IsValid(ply) then
        ply:ChatPrint("[BackCarry] You got off the carrier.")
    end
    if IsValid(carrier) then
        carrier:ChatPrint("[BackCarry] " .. ply:Nick() .. " got off your back.")
    end

    return ""
end)