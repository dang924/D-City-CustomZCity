if CLIENT then return end

-- Stable override for base handcuffs hooks that index ply.organism without nil checks.
-- This file intentionally re-applies on timers/Homigrad reloads to survive hook churn.

local cvEnable = CreateConVar(
    "zc_handcuffs_nil_guard",
    "1",
    FCVAR_ARCHIVE,
    "Enable nil-safe handcuffs hook overrides.",
    0,
    1
)

local function InstallHandcuffGuards()
    if not cvEnable:GetBool() then return end

    -- Base ID from weapon_handcuffs.lua
    hook.Add("PlayerCanPickupWeapon", "handcuffDisallowpickup", function(ply, ent)
        if not IsValid(ply) then return end
        if not istable(ply.organism) then return end
        if not IsValid(ent) then return end

        if ply.organism.handcuffed and ent:GetClass() ~= "weapon_handcuffs_key" then
            return false
        end
    end)

    -- Base ID from weapon_handcuffs.lua
    hook.Add("PlayerUse", "restrictuser", function(ply, ent)
        if not IsValid(ply) then return end
        if not istable(ply.organism) then return end

        if ply.organism.handcuffed then
            return false
        end
    end)

    -- Base ID from weapon_handcuffs.lua
    hook.Add("Ragdoll_Create", "Addhandcuffs", function(ply, ragdoll)
        if not IsValid(ply) then return end
        if not IsValid(ragdoll) then return end
        if not istable(ply.organism) then return end

        local ragOrg = ragdoll.organism
        if ply.organism.handcuffed or (istable(ragOrg) and ragOrg.handcuffed) then
            if hg and hg.handcuff and isfunction(hg.handcuff) then
                hg.handcuff(ragdoll)
            end
            if ply.SelectWeapon then
                ply:SelectWeapon("weapon_hands_sh")
            end
        end
    end)
end

hook.Add("InitPostEntity", "DCP_HandcuffsStability_Init", function()
    InstallHandcuffGuards()
    timer.Simple(0.5, InstallHandcuffGuards)
    timer.Simple(2, InstallHandcuffGuards)
end)

hook.Add("HomigradRun", "DCP_HandcuffsStability_HG", function()
    InstallHandcuffGuards()
    timer.Simple(0, InstallHandcuffGuards)
    timer.Simple(0.5, InstallHandcuffGuards)
end)

timer.Create("DCP_HandcuffsStability_KeepAlive", 2, 0, InstallHandcuffGuards)
