-- Makes bandages, morphine, and painkillers have unlimited uses,
-- and ensures all players receive them on spawn.
-- Intercepts depletion before the weapon removes itself by resetting
-- modeValues and disabling ShouldDeleteOnFullUse on equip.

if CLIENT then return end

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    local UNLIMITED_WEAPONS = {
        ["weapon_bandage_sh"] = {refill = 40},  -- matches modeValuesdef[1][1]
        ["weapon_morphine"]   = {refill = 1, cooldown = 60},  -- max once per 60 seconds
        ["weapon_bloodbag"]   = {refill = 1, giveOnSpawn = false},
    }

    local morphineCooldowns = {}  -- [SteamID64] = next allowed refill time
    local nextRefillCheck = 0
    local REFILL_INTERVAL = 0.25

    -- Gordon uses HEV medicine and should not receive these consumables.
    local EXEMPT_CLASSES = {
        ["Gordon"] = true,
    }

    -- Give all unlimited consumables to a player if they don't already have them
    local function GiveConsumables(ply)
        if not IsValid(ply) then return end
        if not ply:Alive() then return end
        if EXEMPT_CLASSES[ply.PlayerClassName] then return end

        for class, cfg in pairs(UNLIMITED_WEAPONS) do
            if cfg.giveOnSpawn == false then continue end
            if not IsValid(ply:GetWeapon(class)) then
                ply:Give(class)
            end
        end

        -- Ensure hands are always present
        if not IsValid(ply:GetWeapon("weapon_hands_sh")) then
            ply:Give("weapon_hands_sh")
        end
    end

    -- Use "Player Spawn" (ZCity's custom event) rather than GMod's PlayerSpawn
    -- so it fires after SetPlayerClass and GiveEquipment have both completed.
    -- Small defer so GiveEquipment's own timer.Simple(0) calls finish first.
    hook.Add("Player Spawn", "ZC_UnlimitedConsumables_Give", function(ply)
        timer.Simple(0.2, function()
            GiveConsumables(ply)
        end)
    end)

    local function MakeUnlimited(wep)
        if not IsValid(wep) then return end
        local cfg = UNLIMITED_WEAPONS[wep:GetClass()]
        if not cfg then return end

        wep.ShouldDeleteOnFullUse = false

    end

    -- Apply on equip — covers both initial give and picking up from the ground
    hook.Add("WeaponEquip", "ZC_UnlimitedConsumables", function(wep, ply)
        MakeUnlimited(wep)
    end)

    hook.Add("PlayerDisconnected", "ZC_UnlimitedConsumables_Cleanup", function(ply)
        morphineCooldowns[ply:SteamID64()] = nil
    end)

    -- Refill on Think the moment the weapon hits empty.
    -- This fires before the weapon's own depletion+remove check each tick.
    hook.Add("Think", "ZC_UnlimitedConsumables", function()
        local now = CurTime()
        if now < nextRefillCheck then return end
        nextRefillCheck = now + REFILL_INTERVAL

        for class, cfg in pairs(UNLIMITED_WEAPONS) do
            for _, wep in ipairs(ents.FindByClass(class)) do
                if not IsValid(wep) then continue end
                if not wep.modeValues then continue end
                if (wep.modeValues[1] or 1) <= 0 then
                    wep.modeValues[1] = cfg.refill
                    wep:SetNetVar("modeValues", wep.modeValues)
                    local owner = wep:GetOwner()
                    if IsValid(owner) and class == "weapon_morphine" then
                        local sid = owner:SteamID64()
                        if (morphineCooldowns[sid] or 0) > now then
                            -- On cooldown — keep the weapon at 0 so it can't be used
                            wep.modeValues[1] = 0
                            wep:SetNetVar("modeValues", wep.modeValues)
                        else
                            morphineCooldowns[sid] = now + cfg.cooldown
                            print("[ZC] Morphine refilled for " .. owner:Nick() .. " at " .. os.date("%H:%M:%S"))
                        end
                    end
                end
            end
        end
    end)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svunlimitedconsumables", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)
hook.Add("Think", "ZC_CoopInit_svunlimitedconsumables_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svunlimitedconsumables_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)

