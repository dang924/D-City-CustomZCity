-- sv_vehicle_seat_switch_safety.lua
-- DCityPatch1.1
--
-- Prevent seat-switch ejection/ragdoll loops caused by Homigrad vehicle hooks
-- when mods switch seats via ExitVehicle() + EnterVehicle().

if CLIENT then return end

local TAG = "DCityPatch_SeatSwitchSafety"
local ENTER_RAG_TIMER_PREFIX = "EnterVehicleRag"

local SWITCH_INTENT_WINDOW = 0.7
local SWITCH_CLEAR_DELAY = 0.9

local function LowerClass(ent)
    if not IsValid(ent) then return "" end
    return string.lower(ent:GetClass() or "")
end

local function ResolveSeatParent(seat)
    if not IsValid(seat) then return NULL end
    local parent = seat:GetParent()
    if IsValid(parent) then return parent end
    return seat
end

local function IsGlideSeat(seat)
    if not IsValid(seat) then return false end
    if seat.GlideSeatIndex ~= nil then return true end

    local parent = seat:GetParent()
    return IsValid(parent) and parent.IsGlideVehicle == true
end

local function IsSimfphysSeat(ply, seat)
    if IsValid(ply) and ply.IsDrivingSimfphys and ply:IsDrivingSimfphys() then
        return true
    end

    local parent = IsValid(seat) and seat:GetParent() or NULL
    if not IsValid(parent) then return false end

    local cls = LowerClass(parent)
    if string.find(cls, "gmod_sent_vehicle_fphysics", 1, true) then
        return true
    end

    if simfphys and simfphys.IsCar and simfphys.IsCar(parent) then
        return true
    end

    return false
end

local function IsWACSeat(seat)
    if not IsValid(seat) then return false end

    local seatClass = LowerClass(seat)
    if string.find(seatClass, "wac_", 1, true) then return true end

    local parent = seat:GetParent()
    local parentClass = LowerClass(parent)
    if string.find(parentClass, "wac_", 1, true) then return true end

    -- WAC Glide aircraft often use helicopter/plane class prefixes.
    if string.find(parentClass, "sent_v19", 1, true) then return true end

    return false
end

local function NeedsSeatSwitchSafety(ply, seat)
    return IsGlideSeat(seat) or IsSimfphysSeat(ply, seat) or IsWACSeat(seat)
end

local function SeatSwitchTimerName(ply)
    return TAG .. "_ClearSwitch_" .. tostring(ply:EntIndex())
end

local function MarkSeatSwitchIntent(ply, seat)
    if not IsValid(ply) then return end
    if not NeedsSeatSwitchSafety(ply, seat) then return end

    ply.switchingseat = true
    ply._ZCSeatSwitchUntil = CurTime() + SWITCH_INTENT_WINDOW
    ply._ZCSeatSwitchParent = ResolveSeatParent(seat)

    timer.Create(SeatSwitchTimerName(ply), SWITCH_CLEAR_DELAY, 1, function()
        if not IsValid(ply) then return end

        local untilAt = tonumber(ply._ZCSeatSwitchUntil) or 0
        if untilAt <= CurTime() then
            ply.switchingseat = nil
        end
    end)
end

local function IsSeatSwitchingNow(ply, seat)
    if not IsValid(ply) then return false end

    local untilAt = tonumber(ply._ZCSeatSwitchUntil) or 0
    if untilAt <= CurTime() then return false end

    local fromParent = ply._ZCSeatSwitchParent
    local toParent = ResolveSeatParent(seat)

    if not IsValid(fromParent) or not IsValid(toParent) then
        return true
    end

    return fromParent == toParent
end

local function RemoveUnsafeHooks()
    hook.Remove("CanPlayerEnterVehicle", "fake_enterveh")
    hook.Remove("PlayerEnteredVehicle", "allowweapons")
    hook.Remove("PlayerLeaveVehicle", "allowweapons")
    hook.Remove("CanExitVehicle", "huyhuy")
end

local function InstallSafeHooks()
    RemoveUnsafeHooks()

    hook.Add("CanExitVehicle", TAG .. "_MarkIntent", function(ply, seat)
        MarkSeatSwitchIntent(ply, seat)
    end)

    hook.Add("CanPlayerEnterVehicle", TAG .. "_EnterGate", function(ply, seat)
        if hg and hg.RemoveDeadBodies and hg.RemoveDeadBodies(seat) then
            return false
        end

        local switching = ply.switchingseat or IsSeatSwitchingNow(ply, seat)

        local parent = IsValid(seat) and seat:GetParent() or NULL
        if IsValid(parent) and parent:GetVelocity():LengthSqr() > 256 * 256 and not switching then
            return false
        end

        if switching then
            ply.switchingseat = true
            ply._ZCSeatSwitchUntil = CurTime() + SWITCH_INTENT_WINDOW
        end

        return true
    end)

    hook.Add("PlayerEnteredVehicle", TAG .. "_OnEnter", function(ply, seat)
        if not IsValid(ply) then return end

        ply:SetEyeAngles(angle_zero)

        local switching = ply.switchingseat or IsSeatSwitchingNow(ply, seat)
        local enterTimer = ENTER_RAG_TIMER_PREFIX .. tostring(ply:EntIndex())

        if switching then
            timer.Remove(enterTimer)
            ply._ZCSeatSwitchUntil = CurTime() + SWITCH_INTENT_WINDOW
        else
            local delay = (IsValid(seat) and seat:GetVehicleClass() == "Pod") and 0.5 or 1
            timer.Create(enterTimer, delay, 1, function()
                if not IsValid(ply) then return end
                if not ply:InVehicle() then return end

                ply:SetEyeAngles(angle_zero)
                if hg and hg.Fake then
                    hg.Fake(ply, nil, nil, true)
                end

                if IsValid(ply) then
                    ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
                end
            end)
        end

        ply:SetAllowWeaponsInVehicle(true)
    end)

    hook.Add("PlayerLeaveVehicle", TAG .. "_OnLeave", function(ply, seat)
        if not IsValid(ply) then return end

        ply:SetAllowWeaponsInVehicle(false)

        local enterTimer = ENTER_RAG_TIMER_PREFIX .. tostring(ply:EntIndex())
        if timer.Exists(enterTimer) then
            timer.Remove(enterTimer)
        end

        if NeedsSeatSwitchSafety(ply, seat) then
            MarkSeatSwitchIntent(ply, seat)
        end

        local switching = ply.switchingseat or IsSeatSwitchingNow(ply, seat)

        local ragdoll = ply.FakeRagdoll
        local fast = IsValid(ragdoll) and ragdoll:GetVelocity():Length() > 200

        if (not fast or switching) and ply:Alive() then
            if hg and hg.FakeUp then
                hg.FakeUp(ply, true, switching)
            end
        else
            if IsValid(ragdoll) then
                ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
                ragdoll.removingwelds = true

                if ragdoll.welds then
                    for _, weld in pairs(ragdoll.welds) do
                        if IsValid(weld) then weld:Remove() end
                    end
                end

                ragdoll.welds = nil
                ragdoll.removingwelds = nil
                ragdoll:SetParent()

                if fast then
                    local phys = ragdoll:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:ApplyForceCenter(ragdoll:GetVelocity():GetNormalized() * 10000)
                        phys:ApplyForceCenter(vector_up * 10000)
                    end

                    if IsValid(seat) then
                        seat:EmitSound("zbattle/glass_shatter.ogg")
                    end
                end
            else
                ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
            end
        end

        hg.fallfromveh = nil
    end)
end

local function TryInstall()
    InstallSafeHooks()
end

TryInstall()

hook.Add("InitPostEntity", TAG .. "_InitPostEntity", function()
    timer.Create(TAG .. "_Reapply", 0.5, 20, function()
        TryInstall()
    end)
end)

print("[DCityPatch] Vehicle seat-switch safety active.")
