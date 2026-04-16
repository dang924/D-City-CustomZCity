-- During coop rounds, removes player-blocking collision from all ragdolls
-- (player corpses, NPC corpses — antlions, zombies, combine, etc.) so they
-- don't obstruct movement. Ragdolls still settle on the floor normally.
-- Controlled by convar zc_ragdoll_nocollide (default 1).

if CLIENT then return end

local cv = CreateConVar("zc_ragdoll_nocollide", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Remove player-blocking collision from ragdolls during coop (0 = off)")

local function IsCoop()
    if not CurrentRound then return false end
    local ok, round = pcall(CurrentRound)
    return ok and istable(round) and round.name == "coop"
end

hook.Add("OnEntityCreated", "ZC_RagdollNoCollide", function(ent)
    if not cv:GetBool() then return end
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "prop_ragdoll" then return end
    if not IsCoop() then return end

    -- Defer one tick so the ragdoll is fully initialized before we change its
    -- collision group (setting it during entity creation can be a no-op).
    timer.Simple(0, function()
        if IsValid(ent) then
            ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        end
    end)
end)
