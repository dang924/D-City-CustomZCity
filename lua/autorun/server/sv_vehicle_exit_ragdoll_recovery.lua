-- sv_vehicle_exit_ragdoll_recovery.lua
-- DCityPatchPack
--
-- Problem:
--   When a player exits a fast-moving vehicle (ragdoll velocity > 200 u/s) while the
--   Homigrad FakeRagdoll system is active, the base "allowweapons" PlayerLeaveVehicle
--   hook intentionally skips hg.FakeUp() and instead just removes welds + unparents the
--   ragdoll prop.  The player entity remains invisible/NOCLIP and the Think loop in
--   sv_control.lua tracks it to the ragdoll's head bone every tick.  If the ragdoll
--   sticks in mid-air (stuck physics after unparenting from a moving vehicle), the player
--   entity floats indefinitely.
--
-- Fix:
--   Hook PlayerLeaveVehicle at HOOK_LOW (after the base "allowweapons" hook runs).
--   If the player still has an active FakeRagdoll (i.e. the fast path was taken),
--   schedule a forced hg.FakeUp() after a short delay so they always recover.
--   Also add a safety net: if a player exits any vehicle and still has MOVETYPE_NOCLIP
--   without a FakeRagdoll (engine failed to reset movetype), reset it ourselves.

if CLIENT then return end

local TAG = "DCityPatch_VehicleExitRagdollRecovery"

-- How long to let the ejected ragdoll fly before forcing the player back up.
-- 0.5 s gives a brief "thrown from vehicle" feel without leaving the player stuck.
local RECOVERY_DELAY = 0.5

-- ── fast-exit ragdoll recovery ──────────────────────────────────────────────

-- Run after every other PlayerLeaveVehicle hook (HOOK_LOW).
hook.Add("PlayerLeaveVehicle", TAG, function(ply, veh)
    if not IsValid(ply) then return end

    -- Use timer.Simple(0) so this check runs in the next tick, after all default-
    -- priority PLV hooks (Homigrad "allowweapons", Glide "Glide.OnExitSeat") have
    -- finished modifying ply state.
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if not ply:Alive() then return end
        if ply:InVehicle() then return end  -- player re-entered a vehicle immediately

        -- Case 1: still ragdolled after exit (fast path skipped hg.FakeUp).
        if IsValid(ply.FakeRagdoll) then
            timer.Simple(RECOVERY_DELAY, function()
                if not IsValid(ply) then return end
                if not ply:Alive() then return end
                if ply:InVehicle() then return end
                -- Only act if still ragdolled; player may have pressed 'fake' key
                -- themselves during the delay and already recovered.
                if not IsValid(ply.FakeRagdoll) then return end
                if hg and hg.FakeUp then
                    hg.FakeUp(ply, true)
                end
            end)
            return
        end

        -- Case 2: not ragdolled, but MOVETYPE_NOCLIP still set (engine/hook race).
        -- Reset to MOVETYPE_WALK so the player falls normally.
        if ply:GetMoveType() == MOVETYPE_NOCLIP then
            ply:SetMoveType(MOVETYPE_WALK)
            -- Restore standard player hull in case it was shrunk to ragdoll size.
            ply:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72))
            ply:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36))
            ply:SetViewOffset(Vector(0, 0, 64))
            ply:SetViewOffsetDucked(Vector(0, 0, 28))
        end
    end)
end, HOOK_LOW)
