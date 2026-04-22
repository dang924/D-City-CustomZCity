if CLIENT then return end

local TAG = "DCityPatch_VehicleImpulseSafety"

local CV_MAX_EXIT_SPEED = "zc_glide_exit_max_speed"
local cvMaxExitSpeed = ConVarExists(CV_MAX_EXIT_SPEED)
    and GetConVar(CV_MAX_EXIT_SPEED)
    or CreateConVar(CV_MAX_EXIT_SPEED, "1800", FCVAR_ARCHIVE, "Maximum allowed player speed after Glide vehicle exits.", 200, 6000)

local CV_ENTRY_LOCK_WINDOW = "zc_glide_entry_lock_window"
local cvEntryLockWindow = ConVarExists(CV_ENTRY_LOCK_WINDOW)
    and GetConVar(CV_ENTRY_LOCK_WINDOW)
    or CreateConVar(CV_ENTRY_LOCK_WINDOW, "1.2", FCVAR_ARCHIVE, "Seconds to lock hidden player position to Glide vehicle center after seat entry.", 0.2, 3)

local CV_MAX_SEATED_CRASH_DAMAGE = "zc_glide_seated_crash_damage_max"
local cvMaxSeatedCrashDamage = ConVarExists(CV_MAX_SEATED_CRASH_DAMAGE)
    and GetConVar(CV_MAX_SEATED_CRASH_DAMAGE)
    or CreateConVar(CV_MAX_SEATED_CRASH_DAMAGE, "25", FCVAR_ARCHIVE, "Maximum crush/vehicle collision damage while seated in Glide vehicles.", 0, 200)

local function IsGlideSeat(ent)
    if not IsValid(ent) then return false end
    if ent:GetClass() ~= "prop_vehicle_prisoner_pod" then return false end

    local parent = ent:GetParent()
    return IsValid(parent) and parent.IsGlideVehicle == true
end

local function IsGlideRelated(ent)
    if not IsValid(ent) then return false end
    if ent.IsGlideVehicle then return true end
    if IsGlideSeat(ent) then return true end

    local parent = ent:GetParent()
    if IsValid(parent) and parent.IsGlideVehicle then return true end

    return false
end

local function IsVehicleLike(ent)
    if not IsValid(ent) then return false end
    if ent:IsVehicle() then return true end
    if ent.IsGlideVehicle == true then return true end

    local cls = string.lower(ent:GetClass() or "")
    if cls == "prop_vehicle_prisoner_pod" then return true end
    if string.find(cls, "vehicle", 1, true) then return true end
    if string.find(cls, "simfphys", 1, true) then return true end
    if string.find(cls, "gmod_sent_vehicle_fphysics", 1, true) then return true end
    if string.find(cls, "glide", 1, true) then return true end
    if string.find(cls, "wac_", 1, true) then return true end
    if string.find(cls, "lunasflightschool", 1, true) then return true end

    local parent = ent:GetParent()
    if not IsValid(parent) or parent == ent then return false end

    if parent:IsVehicle() then return true end
    if parent.IsGlideVehicle == true then return true end

    local pcls = string.lower(parent:GetClass() or "")
    if string.find(pcls, "vehicle", 1, true) then return true end
    if string.find(pcls, "simfphys", 1, true) then return true end
    if string.find(pcls, "gmod_sent_vehicle_fphysics", 1, true) then return true end
    if string.find(pcls, "glide", 1, true) then return true end

    return false
end

local function ClampVectorLength(vec, maxLen)
    local len = vec:Length()
    if len <= maxLen or len <= 0 then return vec end

    local out = Vector(vec.x, vec.y, vec.z)
    out:Mul(maxLen / len)
    return out
end

local function GetGlideVehicleFromSeat(seat)
    if not IsValid(seat) then return nil end
    local parent = seat:GetParent()
    if not (IsValid(parent) and parent.IsGlideVehicle) then return nil end
    return parent
end

-- Keep hidden player origin anchored to the vehicle center during the vulnerable
-- entry window before EnterVehicleRag (0.5-1.0s) fully stabilizes fake-ragdoll state.
hook.Add("PlayerEnteredVehicle", TAG .. "_EntryLock", function(ply, seat)
    if not IsValid(ply) then return end

    local vehicle = GetGlideVehicleFromSeat(seat)
    if not IsValid(vehicle) then return end

    local lockWindow = cvEntryLockWindow and cvEntryLockWindow:GetFloat() or 1.2
    lockWindow = math.Clamp(lockWindow, 0.2, 3)

    local timerName = TAG .. "_EntryLock_" .. tostring(ply:EntIndex())
    timer.Remove(timerName)

    local reps = math.max(1, math.floor(lockWindow / 0.05))
    timer.Create(timerName, 0.05, reps, function()
        if not IsValid(ply) or not ply:Alive() then
            timer.Remove(timerName)
            return
        end

        if not ply:InVehicle() then
            timer.Remove(timerName)
            return
        end

        local currentSeat = ply:GetVehicle()
        local currentVehicle = GetGlideVehicleFromSeat(currentSeat)
        if not IsValid(currentVehicle) then
            timer.Remove(timerName)
            return
        end

        ply:SetPos(currentVehicle:WorldSpaceCenter())

        -- Any managed-spawn anchor is stale once the player is seated.
        ply.ZC_ManagedSpawnUntil = nil
        ply.ZC_ManagedSpawnPos = nil
        ply.ZC_ManagedSpawnAng = nil
    end)
end)

-- Clamp crush spikes while seated so invisible brush/PVS border collisions do
-- not nearly kill players in a single frame.
hook.Add("EntityTakeDamage", TAG .. "_SeatedCrashClamp", function(target, dmgInfo)
    if not IsValid(target) or not target:IsPlayer() then return end
    if not target:InVehicle() then return end

    local seat = target:GetVehicle()
    local vehicle = GetGlideVehicleFromSeat(seat)
    if not IsValid(vehicle) then return end

    local inflictor = dmgInfo:GetInflictor()
    if IsValid(inflictor) and inflictor:GetClass() == "trigger_hurt" then
        dmgInfo:SetDamage(0)
        return true
    end

    if not (dmgInfo:IsDamageType(DMG_CRUSH) or dmgInfo:IsDamageType(DMG_VEHICLE)) then return end

    local maxDamage = cvMaxSeatedCrashDamage and cvMaxSeatedCrashDamage:GetFloat() or 25
    if dmgInfo:GetDamage() > maxDamage then
        dmgInfo:SetDamage(maxDamage)
    end
end)

-- Patch homigrad's destructive OnCrazyPhysics fallback for players/Glide entities.
-- Base code teleports physics to world origin and removes constrained entities,
-- which matches the observed "vehicle disappears" behavior.
local function InstallCrazyPhysicsSafety()
    if not hook.GetTable then return false end

    local ht = hook.GetTable()
    if not ht or not ht["OnCrazyPhysics"] then return false end
    if not ht["OnCrazyPhysics"]["crazy_physics"] then return false end

    hook.Remove("OnCrazyPhysics", "crazy_physics")
    hook.Add("OnCrazyPhysics", "crazy_physics", function(ent, physobj)
        if not IsValid(ent) then return end

        local protect = ent:IsPlayer() or IsGlideRelated(ent) or IsVehicleLike(ent)
        if protect then
            if IsValid(physobj) then
                physobj:EnableMotion(true)
                physobj:SetVelocity(vector_origin)
                physobj:SetAngleVelocity(vector_origin)
                physobj:Wake()
            end

            if ent:IsPlayer() then
                ent:SetLocalVelocity(vector_origin)
            end

            -- Do not snap to origin and do not remove constrained entities.
            return
        end

        -- Keep original destructive behavior for non-player/non-Glide entities.
        ent:CollisionRulesChanged()

        if IsValid(physobj) then
            physobj:EnableMotion(false)
            physobj:Sleep()
            physobj:SetPos(vector_origin)
            physobj:SetAngles(angle_zero)
            physobj:SetVelocity(vector_origin)
            physobj:SetAngleVelocity(vector_origin)
        end

        ent:SetLocalAngularVelocity(angle_zero)
        ent:SetVelocity(vector_origin)
        ent:SetLocalVelocity(vector_origin)

        if SERVER then
            local constrained = constraint.GetAllConstrainedEntities(ent)
            for _, v in next, constrained or {} do
                local nested = constraint.GetAllConstrainedEntities(v)
                for _, vv in next, nested or {} do
                    if ent ~= vv and IsValid(vv) and not vv.__removed__ then
                        vv.__removed__ = true
                        vv:Remove()
                    end
                end

                if IsValid(v) and not v.__removed__ then
                    v.__removed__ = true
                    v:Remove()
                end
            end
        end
    end)

    return true
end

-- Clamp player state after leaving Glide seats to prevent huge impulse spikes
-- from throwing players across the map when a weld/seat transition goes bad.
hook.Add("PlayerLeaveVehicle", TAG .. "_ClampExit", function(ply, seat)
    if not IsValid(ply) then return end

    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if ply:InVehicle() then return end

        local parent = IsValid(seat) and seat:GetParent() or NULL
        if not (IsValid(parent) and parent.IsGlideVehicle) then return end

        local maxExitSpeed = cvMaxExitSpeed and cvMaxExitSpeed:GetFloat() or 1800
        local curVel = ply:GetVelocity()
        local clamped = ClampVectorLength(curVel, maxExitSpeed)

        if clamped:DistToSqr(curVel) > 1 then
            ply:SetLocalVelocity(clamped)
        end

        local seatIndex = seat.GlideSeatIndex or 0
        local exitPos = parent.GetSeatExitPos and parent:GetSeatExitPos(seatIndex) or parent:WorldSpaceCenter()

        if not util.IsInWorld(ply:GetPos()) or ply:GetPos():DistToSqr(exitPos) > (3000 * 3000) then
            ply:SetPos(exitPos + Vector(0, 0, 6))
            ply:SetLocalVelocity(vector_origin)
        end
    end)
end, HOOK_LOW)

-- ---------------------------------------------------------------------------
-- SimFPhys velocity cap
-- rectwrap_wrap_sv.lua's TeleportGroupKeepMotion preserves vehicle velocity
-- after map boundary wraps, causing infinite out-of-bounds runaway loops.
-- This timer catches and kills runaway speed within one tick after any wrap.
-- ---------------------------------------------------------------------------
local CV_MAX_SIMFPHYS_SPEED = "zc_simfphys_max_speed"
local cvMaxSimfphysSpeed = ConVarExists(CV_MAX_SIMFPHYS_SPEED)
    and GetConVar(CV_MAX_SIMFPHYS_SPEED)
    or CreateConVar(CV_MAX_SIMFPHYS_SPEED, "2500", FCVAR_ARCHIVE,
        "Max allowed physics speed for SimFPhys vehicles (u/s). 0=disabled.", 0, 10000)

local simfphysClasses = {
    ["gmod_sent_vehicle_fphysics_base"] = true,
}

-- Tracks consecutive OOW ticks per entity (EntIndex → count).
local oowStreak = {}
-- Entities currently in a physics-frozen recovery (avoid re-triggering).
local recovering  = {}

local function getSimfphysDriver(ent)
    if isfunction(ent.GetDriver) then
        local d = ent:GetDriver()
        if IsValid(d) then return d end
    end
    for _, ply in ipairs(player.GetAll()) do
        if not ply:InVehicle() then continue end
        local seat = ply:GetVehicle()
        if IsValid(seat) and (seat == ent or seat:GetParent() == ent) then
            return ply
        end
    end
    return NULL
end

local function zeroSimfphysVelocity(ent, phys)
    phys:SetVelocity(vector_origin)
    phys:SetAngleVelocity(vector_origin)
    phys:Wake()
    ent:SetVelocity(vector_origin)
    ent:SetLocalVelocity(vector_origin)
    if ent.simfphys then
        if ent.simfphys.Velocity        then ent.simfphys.Velocity        = Vector(0, 0, 0) end
        if ent.simfphys.AngularVelocity then ent.simfphys.AngularVelocity = Vector(0, 0, 0) end
    end
end

local function findSafeRecoveryPos(ent)
    local bestPos
    local bestDist = math.huge
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        local pp = ply:GetPos()
        if not util.IsInWorld(pp) then continue end
        local d = pp:DistToSqr(ent:GetPos())
        if d < bestDist then bestDist = d; bestPos = pp end
    end

    local base = bestPos or Vector(0, 0, 0)
    -- Trace from high above the target player down to find solid ground.
    local traceStart = base + Vector(0, 0, 600)
    local traceEnd   = base - Vector(0, 0, 200)
    local tr = util.TraceLine({
        start  = traceStart,
        endpos = traceEnd,
        mask   = MASK_SOLID_BRUSHONLY,
    })
    if tr.Hit then
        return tr.HitPos + Vector(0, 0, 100)  -- 100 units above ground
    end
    return base + Vector(0, 0, 300)
end

local function doOOWRecovery(ent, phys, idx)
    if recovering[idx] then return end
    recovering[idx] = true

    local dest = findSafeRecoveryPos(ent)

    -- Freeze physics during teleport to prevent collision-impulse spikes.
    phys:EnableMotion(false)
    phys:SetVelocity(vector_origin)
    phys:SetAngleVelocity(vector_origin)
    phys:SetPos(dest)
    ent:SetPos(dest)

    local driver = getSimfphysDriver(ent)
    if IsValid(driver) then
        driver:ChatPrint("[Safety] Vehicle was out-of-world — teleporting back.")
    end
    print(string.format("[DCityPatch_VehicleImpulseSafety] OOW recovery: ent=%s (%s) dest=%s",
        tostring(idx), ent:GetClass(), tostring(dest)))

    -- Re-enable physics after a short freeze so the engine settles the car
    -- onto the ground without building a collision impulse.
    local capturedEnt = ent
    local capturedIdx = idx
    timer.Simple(0.5, function()
        recovering[capturedIdx] = nil
        if not IsValid(capturedEnt) then return end
        local p = capturedEnt:GetPhysicsObject()
        if not IsValid(p) then return end
        p:SetVelocity(vector_origin)
        p:SetAngleVelocity(vector_origin)
        p:EnableMotion(true)
        p:Wake()
    end)
end

-- ── Think hook: zero OOW velocity BEFORE rectwrap can preserve it ────────────
-- rectwrap_wrap_sv.lua hooks the same Think event at default priority.
-- Running at HOOK_HIGH means we fire first and zero velocity so rectwrap's
-- TeleportGroupKeepMotion copies zero instead of the runaway speed.
hook.Add("Think", TAG .. "_SimfphysOOWPreZero", function()
    for cls in pairs(simfphysClasses) do
        for _, ent in ipairs(ents.FindByClass(cls)) do
            if not IsValid(ent) then continue end
            if util.IsInWorld(ent:GetPos()) then continue end
            if recovering[ent:EntIndex()] then continue end
            local phys = ent:GetPhysicsObject()
            if not IsValid(phys) then continue end
            if phys:GetVelocity():LengthSqr() < 1 then continue end
            phys:SetVelocity(vector_origin)
            phys:SetAngleVelocity(vector_origin)
            ent:SetVelocity(vector_origin)
        end
    end
end, HOOK_HIGH)

-- ── 0.1s timer: velocity cap + OOW streak recovery ───────────────────────────
timer.Create(TAG .. "_SimfphysVelCap", 0.1, 0, function()
    local maxSpeed = cvMaxSimfphysSpeed and cvMaxSimfphysSpeed:GetFloat() or 2500

    for cls in pairs(simfphysClasses) do
        for _, ent in ipairs(ents.FindByClass(cls)) do
            if not IsValid(ent) then continue end

            local idx = ent:EntIndex()
            if recovering[idx] then continue end

            local phys = ent:GetPhysicsObject()
            if not IsValid(phys) then continue end

            local pos     = ent:GetPos()
            local speed   = phys:GetVelocity():Length()
            local inWorld = util.IsInWorld(pos)

            -- Velocity cap (catches cases where rectwrap fires before our Think hook).
            if maxSpeed > 0 and speed > maxSpeed then
                zeroSimfphysVelocity(ent, phys)
                oowStreak[idx] = nil

                local driver = getSimfphysDriver(ent)
                if IsValid(driver) then
                    driver:ChatPrint("[Safety] SimFPhys velocity reset (was " .. math.floor(speed) .. " u/s)")
                end
                print(string.format("[DCityPatch_VehicleImpulseSafety] vel capped: ent=%s speed=%.1f",
                    tostring(idx), speed))
                speed = 0
            end

            -- OOW: always zero any remaining velocity and track for recovery.
            if not inWorld then
                if speed > 1 then
                    zeroSimfphysVelocity(ent, phys)
                end
                oowStreak[idx] = (oowStreak[idx] or 0) + 1
                -- Trigger recovery after 1 s of being stationary OOW.
                if oowStreak[idx] >= 10 then
                    oowStreak[idx] = nil
                    doOOWRecovery(ent, phys, idx)
                end
            else
                oowStreak[idx] = nil
            end
        end
    end
end)

local function Bootstrap()
    InstallCrazyPhysicsSafety()
end

hook.Add("InitPostEntity", TAG .. "_Init", function()
    Bootstrap()
    timer.Simple(0, Bootstrap)
    timer.Simple(0.5, Bootstrap)
end)

hook.Add("HomigradRun", TAG .. "_HG", function()
    Bootstrap()
    timer.Simple(0, Bootstrap)
    timer.Simple(0.5, Bootstrap)
end)

timer.Create(TAG .. "_Retry", 1, 0, Bootstrap)
