if CLIENT then return end

local function GetCurrentRoundSafe()
    if not CurrentRound then return nil end

    local ok, round = pcall(CurrentRound)
    if not ok or not istable(round) then return nil end

    return round
end

local function ShouldSkipManagedSpawn(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    return (ply.ZC_ManagedSpawnUntil or 0) > CurTime()
end

local function ResolveRebelManagedSpawn()
    local gordon = _G.GetGordon and _G.GetGordon()
    if IsValid(gordon) and gordon:Alive() then
        local offset = Vector(math.Rand(-60, 60), math.Rand(-60, 60), 0)
        return gordon:GetPos() + offset, gordon:GetAngles()
    end

    local spawnEntry = _G.ZC_GetRebelSpawnEntry and _G.ZC_GetRebelSpawnEntry()
    if spawnEntry and spawnEntry.pos then
        local offset = Vector(math.Rand(-60, 60), math.Rand(-60, 60), 0)
        return spawnEntry.pos + offset, spawnEntry.ang
    end

    return nil
end

local function ApplyManagedSpawnSafe(ply, pos, ang, duration)
    if not IsValid(ply) or not pos then return end

    if _G.ZC_ApplyManagedSpawn then
        _G.ZC_ApplyManagedSpawn(ply, pos, ang, duration)
        return
    end

    ply:SetPos(pos)
    if ang then
        ply:SetEyeAngles(ang)
    end
    ply:SetLocalVelocity(Vector(0, 0, 0))
end

local GORDON_ONLY_ARMOR = {
    gordon_helmet = true,
    gordon_armor = true,
    gordon_arm_armor_left = true,
    gordon_arm_armor_right = true,
    gordon_leg_armor_left = true,
    gordon_leg_armor_right = true,
    gordon_calf_armor_left = true,
    gordon_calf_armor_right = true,
}

local function ScrubGordonArmorForNonGordon(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if tostring(ply.PlayerClassName or "") == "Gordon" then return end
    if not istable(ply.armors) then return end

    local changed = false
    for slot, armorKey in pairs(ply.armors) do
        armorKey = string.lower(tostring(armorKey or ""))
        if GORDON_ONLY_ARMOR[armorKey] then
            ply.armors[slot] = nil
            changed = true
        end
    end

    if not changed then return end

    if istable(ply.armors_health) then
        for armorKey in pairs(GORDON_ONLY_ARMOR) do
            ply.armors_health[armorKey] = nil
            ply:SetNWString("ArmorMaterials" .. armorKey, "")
            ply:SetNWInt("ArmorSkins" .. armorKey, 0)
        end
    end

    if ply.SyncArmor then
        pcall(function() ply:SyncArmor() end)
    end
end

local function PatchCoopPersistenceMidRoundSpawn()
    if _G.ZC_CoopPersistenceMidRoundSpawnPatched then return true end
    if not hg or not hg.CoopPersistence then return false end

    hook.Remove("PlayerSpawn", "CoopPersistence_MidRoundSpawn")
    hook.Add("PlayerSpawn", "CoopPersistence_MidRoundSpawn", function(ply)
        local round = GetCurrentRoundSafe()
        if not round or round.name ~= "coop" then return end
        if not zb or zb.ROUND_STATE ~= 1 then return end
        if ShouldSkipManagedSpawn(ply) then return end

        timer.Simple(0.5, function()
            if not IsValid(ply) or not ply:Alive() then return end
            if ShouldSkipManagedSpawn(ply) then return end

            local currentRound = GetCurrentRoundSafe()
            if not currentRound or currentRound.name ~= "coop" then return end

            local hasWeapons = #ply:GetWeapons() > 1
            if hasWeapons then return end

            local managedSpawnPos, managedSpawnAng = ResolveRebelManagedSpawn()
            if not managedSpawnPos and currentRound.GetPlySpawn then
                currentRound:GetPlySpawn(ply)
            end

            local steamid = ply:SteamID()
            local savedData = hg.CoopPersistence.GetPlayerData(steamid)

            local function ApplyGordonClassForCurrentMap(playerClass, options)
                options = options or {}
                if _G.ZC_ApplyCoopClassLoadout then
                    _G.ZC_ApplyCoopClassLoadout(ply, {
                        className = "Gordon",
                        playerEquipment = playerClass,
                        bRestored = options.bRestored == true,
                        queueManagedRetry = true,
                        retryDelay = 0.1,
                        maxAttempts = 12,
                    })
                    return
                end

                local useManaged = false
                if _G.ZC_ShouldUseManagedGordonLoadout then
                    local ok, managed = pcall(_G.ZC_ShouldUseManagedGordonLoadout)
                    useManaged = ok and managed == true
                end

                if useManaged then
                    ply:SetPlayerClass("Gordon", {
                        bRestored = options.bRestored == true,
                    })
                    if _G.ZC_EnsureManagedGordonLoadout then
                        _G.ZC_EnsureManagedGordonLoadout(ply, 0.1, 12)
                    end
                    return
                end

                ply:SetPlayerClass("Gordon", {
                    equipment = tostring(playerClass or "rebel"),
                    bRestored = options.bRestored == true,
                })
            end

            if savedData then
                local restored, data = hg.CoopPersistence.RestorePlayerData(ply)

                if restored and data then
                    local savedPlayerClass = data.PlayerClass
                    local savedRole = data.Role
                    local savedRoleColor = data.RoleColor and Color(data.RoleColor[1], data.RoleColor[2], data.RoleColor[3]) or Color(255, 155, 0)
                    local savedSubClass = data.SubClass

                    local currentMap = game.GetMap()
                    local mapData = currentRound.Maps[currentMap] or { PlayerEqipment = "rebel" }
                    local playerClass = mapData.PlayerEqipment

                    if savedPlayerClass == "Gordon" or savedRole == "Freeman" then
                        ApplyGordonClassForCurrentMap(playerClass, { bRestored = true })
                        zb.GiveRole(ply, "Freeman", Color(255, 155, 0))
                    elseif savedSubClass == "medic" then
                        ply.subClass = "medic"
                        if _G.ZC_ApplyCoopClassLoadout then
                            _G.ZC_ApplyCoopClassLoadout(ply, {
                                className = savedPlayerClass or "Rebel",
                                subClass = "medic",
                            })
                        else
                            ply:SetPlayerClass(savedPlayerClass or "Rebel", { bNoEquipment = true })
                        end
                        zb.GiveRole(ply, "Medic", Color(190, 0, 0))
                    else
                        if _G.ZC_ApplyCoopClassLoadout then
                            _G.ZC_ApplyCoopClassLoadout(ply, {
                                className = savedPlayerClass or "Rebel",
                            })
                        else
                            ply:SetPlayerClass(savedPlayerClass or "Rebel", { bNoEquipment = true })
                        end
                        zb.GiveRole(ply, savedRole or "Rebel", savedRoleColor)
                    end

                    ScrubGordonArmorForNonGordon(ply)

                    hg.CoopPersistence.MarkPlayerRestored(steamid)

                    ply:Give("weapon_hands_sh")
                    ply:SelectWeapon("weapon_hands_sh")

                    if managedSpawnPos then
                        ApplyManagedSpawnSafe(ply, managedSpawnPos, managedSpawnAng, 1.5)
                    end
                end
            else
                local currentMap = game.GetMap()
                local mapData = currentRound.Maps[currentMap] or { PlayerEqipment = "rebel" }
                local playerClass = mapData.PlayerEqipment

                local inv = ply:GetNetVar("Inventory", {})
                inv["Weapons"] = inv["Weapons"] or {}
                inv["Weapons"]["hg_sling"] = true
                inv["Weapons"]["hg_flashlight"] = true
                ply:SetNetVar("Inventory", inv)

                if playerClass == "refugee" or playerClass == "citizen" then
                    if _G.ZC_ApplyCoopClassLoadout then
                        _G.ZC_ApplyCoopClassLoadout(ply, {
                            className = "Refugee",
                            skipNativeEquipment = playerClass == "citizen",
                        })
                    else
                        ply:SetPlayerClass("Refugee", { bNoEquipment = playerClass == "citizen" })
                    end
                    zb.GiveRole(ply, "Refugee", Color(255, 155, 0))
                elseif playerClass == "rebel" then
                    if _G.ZC_ApplyCoopClassLoadout then
                        _G.ZC_ApplyCoopClassLoadout(ply, {
                            className = "Rebel",
                        })
                    else
                        ply:SetPlayerClass("Rebel")
                    end
                    zb.GiveRole(ply, "Rebel", Color(255, 155, 0))
                end

                ScrubGordonArmorForNonGordon(ply)

                ply:Give("weapon_hands_sh")
                ply:SelectWeapon("weapon_hands_sh")

                if managedSpawnPos then
                    ApplyManagedSpawnSafe(ply, managedSpawnPos, managedSpawnAng, 1.5)
                end
            end
        end)
    end)

    _G.ZC_CoopPersistenceMidRoundSpawnPatched = true
    print("[DCityPatch] CoopPersistence managed-spawn guard loaded.")
    return true
end

local function TryPatchCoopPersistenceMidRoundSpawn()
    if PatchCoopPersistenceMidRoundSpawn() then
        timer.Remove("DCityPatch_CoopPersistenceMidRoundSpawnTimer")
    end
end

hook.Add("InitPostEntity", "DCityPatch_CoopPersistenceMidRoundSpawnInit", TryPatchCoopPersistenceMidRoundSpawn)
hook.Add("HomigradRun", "DCityPatch_CoopPersistenceMidRoundSpawnHG", function()
    TryPatchCoopPersistenceMidRoundSpawn()
    timer.Simple(0, TryPatchCoopPersistenceMidRoundSpawn)
    timer.Simple(1, TryPatchCoopPersistenceMidRoundSpawn)
end)
timer.Create("DCityPatch_CoopPersistenceMidRoundSpawnTimer", 1, 0, TryPatchCoopPersistenceMidRoundSpawn)
