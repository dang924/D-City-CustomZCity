-- sv_alyx_npc_weapon_fix.lua
-- DCityPatch1.1
--
-- Ensures all npc_alyx instances across all maps use weapon_npc_alyxgun,
-- which prevents the ground-firing magdump behavior that occurs
-- on weapon_pl15 when there is no valid enemy.

if CLIENT then return end

local function SwapAlyxWeapon(alyx)
    if not IsValid(alyx) or alyx:GetClass() ~= "npc_alyx" then
        return
    end

    -- Delay swap to let Z-City spawn hooks finish
    timer.Simple(0.2, function()
        if not IsValid(alyx) then return end

        local currentWep = alyx:GetActiveWeapon()
        local currentClass = IsValid(currentWep) and currentWep:GetClass() or "NONE"

        if currentClass ~= "weapon_npc_alyxgun" then
            if IsValid(currentWep) then
                currentWep:Remove()
            end
            alyx:Give("weapon_npc_alyxgun")
            print(string.format("[ZC AlrxWeaponFix] Gave weapon_npc_alyxgun to npc_alyx (replaced %s)", currentClass))
        end
    end)
end

hook.Add("OnEntityCreated", "ZC_GlobalAlyxWeaponFix", function(ent)
    if IsValid(ent) and ent:GetClass() == "npc_alyx" then
        SwapAlyxWeapon(ent)
    end
end)

print("[ZC AlrxWeaponFix] Loaded - all npc_alyx will use weapon_npc_alyxgun")
