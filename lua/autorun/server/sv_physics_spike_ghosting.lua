if CLIENT then return end

-- Temporarily ghosts physics offenders when server frametime spikes.
-- Targets props and ragdolls only; vehicles are excluded because some
-- vehicle bases (notably simfphys) can misbehave when collision groups
-- are toggled during active physics simulation.

local CV_ENABLE = CreateConVar("zc_phys_spike_ghost_enable", "1", FCVAR_ARCHIVE,
    "Enable temporary ghosting for physics offenders during frametime spikes")
local CV_FRAME_MS = CreateConVar("zc_phys_spike_frame_ms", "55", FCVAR_ARCHIVE,
    "Frametime spike threshold in milliseconds")
local CV_MIN_SCORE = CreateConVar("zc_phys_spike_min_score", "8", FCVAR_ARCHIVE,
    "Minimum offender score to ghost")
local CV_MAX_GHOST = CreateConVar("zc_phys_spike_max_ghost", "6", FCVAR_ARCHIVE,
    "Maximum entities to ghost per spike burst")
local CV_GHOST_SEC = CreateConVar("zc_phys_spike_ghost_sec", "1.75", FCVAR_ARCHIVE,
    "How long offenders stay ghosted")
local CV_COOLDOWN = CreateConVar("zc_phys_spike_cooldown_sec", "0.35", FCVAR_ARCHIVE,
    "Minimum time between spike mitigation bursts")
local CV_DEBUG = CreateConVar("zc_phys_spike_debug", "0", FCVAR_ARCHIVE,
    "Print debug logs for spike ghosting")

local offenders = {} -- [ent] = {score=number, lastHit=CurTime()}
local ghosted = {}   -- [ent] = state
local nextBurstAt = 0

local trackedClasses = {
    ["prop_physics"] = true,
    ["prop_physics_multiplayer"] = true,
    ["prop_ragdoll"] = true,
}

local vehicleLinkedCache = {} -- [ent] = {value=bool, untilTime=CurTime()+ttl}

local function dbg(fmt, ...)
    if not CV_DEBUG:GetBool() then return end
    print("[ZC SpikeGhost] " .. string.format(fmt, ...))
end

local function getFrameTimeSec()
    local rft = RealFrameTime and RealFrameTime() or 0
    if rft and rft > 0 then return rft end
    return FrameTime()
end

local function isVehicleClass(class)
    class = string.lower(tostring(class or ""))
    if class == "" then return false end
    if string.find(class, "gmod_sent_vehicle_fphysics", 1, true) then return true end
    if string.find(class, "prop_vehicle", 1, true) then return true end
    if string.find(class, "simfphys", 1, true) then return true end
    if string.find(class, "wac_", 1, true) then return true end
    if string.find(class, "aircraft", 1, true) then return true end
    if string.find(class, "plane", 1, true) then return true end
    if string.find(class, "heli", 1, true) then return true end
    return false
end

local function isVehicleLinkedEntity(ent)
    if not IsValid(ent) then return false end

    local now = CurTime()
    local cached = vehicleLinkedCache[ent]
    if cached and now < (cached.untilTime or 0) then
        return cached.value == true
    end

    local linked = false

    if ent.IsVehicle and ent:IsVehicle() then
        linked = true
    end

    if not linked and isVehicleClass(ent:GetClass()) then
        linked = true
    end

    if not linked and ent.GetDriver then
        local drv = ent:GetDriver()
        if IsValid(drv) then
            linked = true
        end
    end

    if not linked then
        local parent = ent.GetParent and ent:GetParent() or nil
        local depth = 0
        while IsValid(parent) and depth < 5 do
            if (parent.IsVehicle and parent:IsVehicle()) or isVehicleClass(parent:GetClass()) then
                linked = true
                break
            end
            parent = parent.GetParent and parent:GetParent() or nil
            depth = depth + 1
        end
    end

    if not linked and constraint and constraint.GetAllConstrainedEntities then
        local constrained = constraint.GetAllConstrainedEntities(ent)
        if istable(constrained) then
            for linkedEnt, _ in pairs(constrained) do
                if IsValid(linkedEnt) and linkedEnt ~= ent then
                    if (linkedEnt.IsVehicle and linkedEnt:IsVehicle()) or isVehicleClass(linkedEnt:GetClass()) then
                        linked = true
                        break
                    end
                end
            end
        end
    end

    vehicleLinkedCache[ent] = {
        value = linked,
        untilTime = now + (linked and 2.0 or 0.8),
    }

    return linked
end

local function isTrackable(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() or ent:IsNPC() then return false end
    if ent:GetClass() == "prop_vehicle_prisoner_pod" then return false end

    local class = ent:GetClass()
    if isVehicleClass(class) then return false end
    if trackedClasses[class] then return true end
    return false
end

local function addOffenderScore(ent, amount)
    if not isTrackable(ent) then return end

    local data = offenders[ent]
    if not data then
        data = {score = 0, lastHit = CurTime()}
        offenders[ent] = data
    end

    data.score = math.min(data.score + amount, 250)
    data.lastHit = CurTime()
end

local function setAllPhysCollisions(ent, enabled)
    if not IsValid(ent) then return end

    local count = ent.GetPhysicsObjectCount and ent:GetPhysicsObjectCount() or 0
    if count > 0 then
        for i = 0, count - 1 do
            local po = ent:GetPhysicsObjectNum(i)
            if IsValid(po) then
                po:EnableCollisions(enabled)
            end
        end
        return
    end

    local po = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil
    if IsValid(po) then
        po:EnableCollisions(enabled)
    end
end

local function ghostEntity(ent, untilTime)
    if not IsValid(ent) then return false end
    if isVehicleLinkedEntity(ent) then return false end

    local state = ghosted[ent]
    if state then
        state.untilTime = math.max(state.untilTime or 0, untilTime)
        return true
    end

    state = {
        untilTime = untilTime,
        oldGroup = ent.GetCollisionGroup and ent:GetCollisionGroup() or COLLISION_GROUP_NONE,
        oldNotSolid = ent.GetNotSolid and ent:GetNotSolid() or false,
    }

    ghosted[ent] = state

    setAllPhysCollisions(ent, false)
    if ent.SetNotSolid then ent:SetNotSolid(true) end
    if ent.SetCollisionGroup then ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER) end

    return true
end

local function restoreEntity(ent)
    local state = ghosted[ent]
    if not state then return end
    ghosted[ent] = nil

    if not IsValid(ent) then return end

    setAllPhysCollisions(ent, true)
    if ent.SetNotSolid then ent:SetNotSolid(state.oldNotSolid == true) end
    if ent.SetCollisionGroup then ent:SetCollisionGroup(state.oldGroup or COLLISION_GROUP_NONE) end
end

local function collectWorstOffenders()
    local now = CurTime()
    local minScore = math.max(0, CV_MIN_SCORE:GetFloat())
    local list = {}

    for ent, data in pairs(offenders) do
        if not IsValid(ent) then
            offenders[ent] = nil
            vehicleLinkedCache[ent] = nil
        else
            if isVehicleLinkedEntity(ent) then
                offenders[ent] = nil
            else
                -- Decay old collision influence quickly.
                local age = now - (data.lastHit or now)
                if age > 4 then
                    offenders[ent] = nil
                else
                    local decayed = data.score * math.max(0, 1 - age * 0.22)
                    if decayed >= minScore then
                        local physSpeed = 0
                        local po = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil
                        if IsValid(po) then
                            physSpeed = po:GetVelocity():Length()
                        end

                        list[#list + 1] = {
                            ent = ent,
                            score = decayed + math.min(physSpeed / 250, 6),
                        }
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b)
        return a.score > b.score
    end)

    return list
end

hook.Add("PhysicsCollide", "ZC_SpikeGhost_Track", function(ent, data)
    if not CV_ENABLE:GetBool() then return end
    if not data then return end

    local speed = tonumber(data.Speed) or 0
    local dt = tonumber(data.DeltaTime) or 0.016
    local impulse = speed * math.max(dt, 0.005)

    if speed < 180 then return end

    local score = math.min(speed / 130, 10) + math.min(impulse / 18, 10)

    addOffenderScore(ent, score)

    local hitEnt = data.HitEntity
    if IsValid(hitEnt) then
        addOffenderScore(hitEnt, score * 0.9)
    end
end)

hook.Add("Think", "ZC_SpikeGhost_Manager", function()
    local now = CurTime()

    -- Restore expired ghost states.
    for ent, state in pairs(ghosted) do
        if not IsValid(ent) then
            ghosted[ent] = nil
        elseif now >= (state.untilTime or 0) then
            restoreEntity(ent)
        end
    end

    if not CV_ENABLE:GetBool() then return end
    if now < nextBurstAt then return end

    local frameMs = getFrameTimeSec() * 1000
    if frameMs < math.max(1, CV_FRAME_MS:GetFloat()) then return end

    local candidates = collectWorstOffenders()
    if #candidates == 0 then
        nextBurstAt = now + math.max(0.05, CV_COOLDOWN:GetFloat())
        return
    end

    local limit = math.max(1, math.floor(CV_MAX_GHOST:GetFloat()))
    local untilTime = now + math.max(0.2, CV_GHOST_SEC:GetFloat())
    local applied = 0

    for i = 1, math.min(limit, #candidates) do
        local ent = candidates[i].ent
        if IsValid(ent) and ghostEntity(ent, untilTime) then
            applied = applied + 1
            offenders[ent] = nil
        end
    end

    nextBurstAt = now + math.max(0.05, CV_COOLDOWN:GetFloat())

    if applied > 0 then
        dbg("frametime spike %.1fms -> ghosted %d entities", frameMs, applied)
    end
end)

hook.Add("EntityRemoved", "ZC_SpikeGhost_Cleanup", function(ent)
    offenders[ent] = nil
    ghosted[ent] = nil
    vehicleLinkedCache[ent] = nil
end)
