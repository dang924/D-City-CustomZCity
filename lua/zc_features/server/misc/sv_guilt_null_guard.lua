-- Z-City Guilt System NULL Entity Guard
-- Prevents "Tried to use a NULL entity" errors in the guilt system
-- This occurs when the guilt system tries to apply guilt to invalid/removed entities

if CLIENT then return end

-- Guard against NULL entity access in guilt system
hook.Add("InitPostEntity", "ZC_Guilt_NullEntityGuard", function()
    -- Patch Z-City's guilt hooks to validate entity before use
    if not _G.hg then return end
    
    -- Override any guilt application to check entity validity first
    local originalAddGuiltyHook = hook.GetTable()["EntityTakeDamage"]
    
    -- Store original EntityTakeDamage hook
    _G.ZC_OriginalEntityTakeDamage = _G.ZC_OriginalEntityTakeDamage or {}
    
    -- Wrap the entity damage handler to catch NULL entity operations
    hook.Add("EntityTakeDamage", "ZC_Guilt_Guard", function(ent, dmgInfo)
        if not IsValid(ent) then
            -- Entity is not valid, skip guilt calculations
            return false
        end
        
        local attacker = dmgInfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() then
            -- Safe to proceed - both entities are valid
            return
        end
        
        -- Invalid attacker, skip
        return false
    end)
end)

-- Clean up disconnected players from guilt tracking
hook.Add("PlayerDisconnected", "ZC_Guilt_CleanupOnDisconnect", function(ply)
    if not IsValid(ply) then return end
    
    -- Clear any pending guilt operations for this player
    if _G.zb and _G.zb.HarmDoneDetailed then
        -- Remove this player from all harm tracking
        for entIdx, harmData in pairs(zb.HarmDoneDetailed) do
            if istable(harmData) then
                for steamId, data in pairs(harmData) do
                    if steamId == ply:SteamID() then
                        harmData[steamId] = nil
                    end
                end
            end
        end
    end
    
    print("[DCityPatch] Cleaned up guilt data for " .. ply:Nick())
end)

-- Prevent guilt errors during round transitions
hook.Add("ZB_StartRound", "ZC_Guilt_RoundStart_Guard", function()
    if not _G.zb or not _G.zb.HarmDoneDetailed then return end
    
    -- Clear out invalid entity references at round start
    -- This prevents: "attempt to index field 'harm' (a nil value)"
    for entIdx = 1, #zb.HarmDoneDetailed do
        local harmData = zb.HarmDoneDetailed[entIdx]
        if istable(harmData) then
            -- Check if the entity this harm data references is still valid
            local ent = ents.GetByIndex(entIdx)
            if not IsValid(ent) then
                zb.HarmDoneDetailed[entIdx] = nil
            end
        end
    end
    
    print("[DCityPatch] Validated guilt system at round start")
end)

-- Error handler for guilt system NULL entity issues
local function SafeGuiltyOperation(fn, ply, ...)
    if not IsValid(ply) then
        print("[DCityPatch] Skipped guilty operation for invalid player")
        return
    end
    
    local ok, err = pcall(fn, ply, ...)
    if not ok then
        print("[DCityPatch] Guilt operation error (suppressed): " .. tostring(err))
    end
end

_G.ZC_SafeGuiltyOperation = SafeGuiltyOperation

local function InstallGuiltSpawnGuard()
    if not (_G.zb and _G.zb.GuiltSQL and _G.zb.GuiltSQL.PlayerInstances and mysql) then
        return false
    end

    local plyMeta = FindMetaTable("Player")
    if not plyMeta then return false end

    if not plyMeta._ZC_OrigGuiltGetValue then
        plyMeta._ZC_OrigGuiltGetValue = plyMeta.guilt_GetValue
        function plyMeta:guilt_GetValue()
            if not IsValid(self) then return 100 end
            local steamID64 = self:SteamID64()
            local instance = zb.GuiltSQL.PlayerInstances[steamID64]
            return instance and instance.value or 100
        end
    end

    if _G.ZC_GuiltSpawnGuardInstalled then
        return true
    end

    hook.Remove("PlayerInitialSpawn", "ZB_GuiltSQL")
    hook.Add("PlayerInitialSpawn", "ZB_GuiltSQL", function(ply)
        if not IsValid(ply) then return end

        local name = ply:Name()
        local steamID64 = ply:SteamID64()

        local query = mysql:Select("zb_guilt")
        query:Select("value")
        query:Where("steamid", steamID64)
        query:Callback(function(result)
            zb.GuiltSQL.PlayerInstances[steamID64] = zb.GuiltSQL.PlayerInstances[steamID64] or {}

            if istable(result) and #result > 0 and result[1].value then
                local updateQuery = mysql:Update("zb_guilt")
                updateQuery:Update("steam_name", name)
                updateQuery:Where("steamid", steamID64)
                updateQuery:Execute()

                zb.GuiltSQL.PlayerInstances[steamID64].value = tonumber(result[1].value) or 100
            else
                local insertQuery = mysql:Insert("zb_guilt")
                insertQuery:Insert("steamid", steamID64)
                insertQuery:Insert("steam_name", name)
                insertQuery:Insert("value", 100)
                insertQuery:Execute()

                zb.GuiltSQL.PlayerInstances[steamID64].value = 100
            end

            if not IsValid(ply) then return end

            ply.Karma = ply:guilt_GetValue()
            ply:SetNetVar("Karma", ply.Karma)

            if zb.GuiltSQL.PlayerInstances[steamID64].value < 0 then
                ply:guilt_SetValue(10)
                local karma = ply.Karma

                ply.Karma = 10
                ply:SetNetVar("Karma", ply.Karma)

                timer.Simple(0, function()
                    if not IsValid(ply) then return end
                    ply:Ban(5, false)
                    ply:Kick("Your karma is too low: " .. math.Round(karma, 0) .. ". Try again in 5 minutes.")
                end)
            end
        end)
        query:Execute()
    end)

    _G.ZC_GuiltSpawnGuardInstalled = true
    print("[DCityPatch] Installed safe guilt spawn callback")
    return true
end

timer.Create("ZC_GuiltSpawnGuardInstall", 1, 0, function()
    if InstallGuiltSpawnGuard() then
        timer.Remove("ZC_GuiltSpawnGuardInstall")
    end
end)

timer.Simple(0, function()
    if InstallGuiltSpawnGuard() then
        timer.Remove("ZC_GuiltSpawnGuardInstall")
    end
end)
