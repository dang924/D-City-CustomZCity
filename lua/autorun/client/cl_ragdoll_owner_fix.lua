if SERVER then return end

-- Fix: hg.RagdollOwner on the client only checks ply:GetNWEntity("FakeRagdoll") == ragdoll,
-- but since the ZCity update the NWEntity can lag or be NULL briefly while the player is still
-- alive and ragdolled. This causes the right-click "alive player" menu options to not appear,
-- leaving only the dead-body options instead.
-- We patch RagdollOwner to also fall back to the local ply.FakeRagdoll table field.

hook.Add("InitPostEntity", "DCityPatch_RagdollOwnerFix", function()
    timer.Simple(0, function()
        if not hg or not hg.RagdollOwner then return end

        local original = hg.RagdollOwner

        function hg.RagdollOwner(ragdoll)
            if not IsValid(ragdoll) then return end

            -- Original check: NWEntity match
            local ply = ragdoll:GetNWEntity("ply")
            if IsValid(ply) and ply:GetNWEntity("FakeRagdoll") == ragdoll then
                return ply
            end

            -- Fallback: check ply.FakeRagdoll table field directly
            -- This catches the case where the NWEntity hasn't synced yet
            if IsValid(ply) and ply.FakeRagdoll == ragdoll then
                return ply
            end

            -- Secondary fallback: scan all players
            -- (handles edge cases where ragdoll.ply NWEntity is also stale)
            for _, p in ipairs(player.GetAll()) do
                if p.FakeRagdoll == ragdoll then
                    return p
                end
            end
        end
    end)
end)
