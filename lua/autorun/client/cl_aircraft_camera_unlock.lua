-- cl_aircraft_camera_unlock.lua
-- DCityPatch1.1
--
-- Prevent view lock on Glide aircraft and vehicles by allowing
-- HG.InputMouseApply to skip fakeCameraAngles2 chain when occupying
-- a Glide or SimFPhys vehicle. The lock happens because fakeCameraAngles2
-- forces angle_zero when InVehicle() is true.

if SERVER then return end

local function IsInGlideVehicle()
    local lply = LocalPlayer()
    if not IsValid(lply) then return false end
    
    -- Check if player has a Glide vehicle via GlideGetVehicle()
    if lply.GlideGetVehicle and IsValid(lply:GlideGetVehicle()) then
        return true
    end
    
    -- Backup: check network variable
    if lply:GetNWEntity("GlideVehicle") and IsValid(lply:GetNWEntity("GlideVehicle")) then
        return true
    end
    
    return false
end

local function IsInSimfphysVehicle()
    local lply = LocalPlayer()
    if not IsValid(lply) then return false end

    if lply.IsDrivingSimfphys and lply:IsDrivingSimfphys() then
        return true
    end

    if not lply:InVehicle() then return false end

    local seat = lply:GetVehicle()
    if not IsValid(seat) then return false end

    local parent = seat:GetParent()
    if not IsValid(parent) then return false end

    local cls = string.lower(parent:GetClass() or "")
    if string.find(cls, "gmod_sent_vehicle_fphysics", 1, true) then
        return true
    end

    if simfphys and simfphys.IsCar and simfphys.IsCar(parent) then
        return true
    end
    
    return false
end

local function IsInNativeVehicle()
    local lply = LocalPlayer()
    if not IsValid(lply) then return false end
    if not lply:InVehicle() then return false end

    local veh = lply:GetVehicle()
    if not IsValid(veh) then return false end

    local cls = veh:GetClass()
    return cls == "prop_vehicle_airboat" or cls == "prop_vehicle_jeep"
end

local function InstallViewUnlock()
    if not hg or not hg.InputMouseApply then return false end
    
    local hookName = "DCityPatch_CameraViewUnlock"
    
    -- Install at HOOK_HIGH to run BEFORE fakeCameraAngles2
    hook.Add("HG.InputMouseApply", hookName, function(tbl)
        if IsInGlideVehicle() or IsInSimfphysVehicle() or IsInNativeVehicle() then
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
