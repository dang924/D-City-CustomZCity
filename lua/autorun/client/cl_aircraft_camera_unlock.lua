-- cl_aircraft_camera_unlock.lua
-- DCityPatch1.1
--
-- Prevent view lock on Glide aircraft and vehicles by allowing
-- HG.InputMouseApply to skip fakeCameraAngles2 chain when occupying
-- a Glide or SimFPhys vehicle. The lock happens because fakeCameraAngles2
-- forces angle_zero when InVehicle() is true.

if SERVER then return end

local function hasClassPart(ent, part)
    if not IsValid(ent) then return false end
    local cls = string.lower(ent:GetClass() or "")
    return string.find(cls, part, 1, true) ~= nil
end

local function isVehicleLike(ent)
    if not IsValid(ent) then return false end

    if ent:IsVehicle() then return true end
    if ent.IsGlideVehicle == true then return true end

    local checks = {
        "simfphys",
        "gmod_sent_vehicle_fphysics",
        "glide",
        "lunasflightschool",
        "wac_",
        "aircraft",
        "plane",
        "heli",
        "vehicle",
        "car",
    }

    for _, part in ipairs(checks) do
        if hasClassPart(ent, part) then return true end
    end

    return false
end

local function getSeatAndVehicle(ply)
    if not IsValid(ply) then return nil, nil end
    if not ply:InVehicle() then return nil, nil end

    local seat = ply:GetVehicle()
    if not IsValid(seat) then return nil, nil end

    local parent = seat:GetParent()
    if IsValid(parent) and parent ~= seat then
        return seat, parent
    end

    return seat, seat
end

local function isSupportedVehicleSeat(ply)
    if not IsValid(ply) then return false end

    local seat, veh = getSeatAndVehicle(ply)
    if not (IsValid(seat) and IsValid(veh)) then return false end

    if ply.GlideGetVehicle and IsValid(ply:GlideGetVehicle()) then
        return true
    end
    if ply.GetNWEntity and IsValid(ply:GetNWEntity("GlideVehicle")) then
        return true
    end

    if ply.IsDrivingSimfphys and ply:IsDrivingSimfphys() then
        return true
    end

    if simfphys and simfphys.IsCar and simfphys.IsCar(veh) then
        return true
    end

    if veh.IsAircraft == true then
        return true
    end

    if isVehicleLike(veh) or isVehicleLike(seat) then
        return true
    end

    local vehCls = veh:GetClass()
    if vehCls == "prop_vehicle_airboat" or vehCls == "prop_vehicle_jeep" then
        return true
    end

    if seat:GetClass() == "prop_vehicle_prisoner_pod" and IsValid(seat:GetParent()) then
        return true
    end

    return false
end

local function InstallViewUnlock()
    if not hook or not hook.Add then return false end
    
    local hookName = "DCityPatch_CameraViewUnlock"

    hook.Remove("HG.InputMouseApply", "ZC_SimfphysViewUnlock")
    hook.Remove("HG.InputMouseApply", "DCityAircraftCompat_PassengerCameraUnlock")
    hook.Remove("HG.InputMouseApply", hookName)
    
    -- Install at HOOK_HIGH to run BEFORE fakeCameraAngles2
    hook.Add("HG.InputMouseApply", hookName, function(tbl)
        local lply = LocalPlayer()
        if isSupportedVehicleSeat(lply) then
            -- Return true to short-circuit the rest of the hook chain,
            -- allowing normal mouse input to be processed.
            return true
        end
    end, HOOK_HIGH)
    
    return true
end

if not InstallViewUnlock() then
    timer.Simple(0.5, function()
        if InstallViewUnlock() then
            print("[DCityPatch] Camera view unlock installed.")
        end
    end)
else
    print("[DCityPatch] Camera view unlock installed.")
end
