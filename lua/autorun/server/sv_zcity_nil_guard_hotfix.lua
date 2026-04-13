-- sv_zcity_nil_guard_hotfix.lua
-- Addon-side safety overrides for base hooks that assume CurrentRound() is always valid.

if CLIENT then return end

local function SafeCurrentRoundName()
    if not CurrentRound then return nil end
    local ok, rnd = pcall(CurrentRound)
    if not ok or not rnd then return nil end
    return rnd.name
end

-- Override base hook with the same id, but nil-safe.
hook.Add("ZB_RoundStart", "RTSoff", function()
    if SafeCurrentRoundName() ~= "coop" then return end

    for _, ply in player.Iterator() do
        ply.RTSUses = 0
    end
end)

-- Override base hook with the same id, but nil-safe.
hook.Add("PostCleanupMap", "RTScleanup", function()
    if SafeCurrentRoundName() ~= "coop" then return end

    for _, ply in player.Iterator() do
        ply.RTSUses = 0
    end
end)

-- Override base hook with the same id, but nil-safe.
hook.Add("OnEntityCreated", "CoopAlyxWeapon", function(ent)
    if SafeCurrentRoundName() ~= "coop" then return end

    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if ent:GetClass() ~= "npc_alyx" then return end

        timer.Simple(0.1, function()
            if not IsValid(ent) then return end

            local currentWeapon = ent:GetActiveWeapon()
            if IsValid(currentWeapon) then
                currentWeapon:Remove()
            end

            ent:Give("weapon_pl15")
        end)
    end)
end)

print("[DCityPatch] Server nil-guard hotfixes loaded (coop hooks).")
