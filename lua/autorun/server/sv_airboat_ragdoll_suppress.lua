-- sv_airboat_ragdoll_suppress.lua
-- DCityPatch1.1
--
-- Prevent hg.Fake ragdoll creation for native Source vehicles (prop_vehicle_airboat,
-- prop_vehicle_jeep). The homigrad EnterVehicleRag timer calls hg.Fake with force=true
-- 1 second after vehicle entry and tries to weld ragdoll bones to the vehicle entity.
-- For native Source vehicles this creates an unstable VPhysics constraint that causes
-- engine crashes.
--
-- Fix: hook PlayerEnteredVehicle at HOOK_LOW so it fires after the base "allowweapons"
-- hook has created the timer, then remove that timer for native vehicle classes.

if CLIENT then return end

local NATIVE_CLASSES = {
    ["prop_vehicle_airboat"] = true,
    ["prop_vehicle_jeep"]    = true,
}

local ENTER_RAG_PREFIX = "EnterVehicleRag"

hook.Add("PlayerEnteredVehicle", "DCityPatch_SuppressNativeVehicleRagdoll", function(ply, veh)
    if not IsValid(ply) or not IsValid(veh) then return end
    if not NATIVE_CLASSES[veh:GetClass()] then return end

    -- Remove the timer created by the base "allowweapons" hook so hg.Fake is never
    -- called with force=true for this vehicle entry.
    timer.Remove(ENTER_RAG_PREFIX .. ply:EntIndex())
end, HOOK_LOW)
