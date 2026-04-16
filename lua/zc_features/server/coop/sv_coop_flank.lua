-- When Gordon dies mid-round, converts a balanced number of dead players
-- into Combine soldiers who spawn at map spawn points to flank the survivors.
-- Hard cap of 5 Combine players. Only fires mid-round, not at round start/end.
-- Elites have a 10% chance of spawning with the death squad (one at a time).
-- All rebels are warned when an Elite deploys.
--
-- Spawn-point logic updated to use the PointEditor helper shared with
-- sv_coop_respawn. Combine use HMCD_COOP_SPAWN points (or info_player_start
-- as a fallback), with full angle support. No proximity filter is applied —
-- Combine spawn at any available point to flank from unpredictable directions.

if CLIENT then return end
if not ZC_IsPatchRebelPlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    local MAX_COMBINE      = 5
    local FLANK_DELAY      = 10   -- seconds after Gordon's death before flankers spawn
    local RESPAWN_INTERVAL = 30   -- seconds between Combine respawn waves
    local function GetEliteChance()
        if ZC_GetCombineEliteChance then
            return tonumber(ZC_GetCombineEliteChance()) or 0.10
        end
        return 0.10
    end

    util.AddNetworkString("ZC_FlankWarning")

    local COMBINE_SUBCLASSES = {
        "default", "default", "default",
        "shotgunner",
        "sniper",
    }

    local clr_combine = Color(89, 230, 255)
    local clr_elite   = Color(246, 13, 13)
    local flankActive  = false
    local flankEnabled = true

    -- ── PointEditor spawn-point helper ────────────────────────────────────────────
    -- Combine spawn pool priority:
    -- 1) HMCD_TDM_T (if map provides explicit Terrorist/attacker spawns)
    -- 2) HMCD_COOP_SPAWN (generic coop pool)
    -- 3) info_player_start fallback
    -- Returns a random {pos, ang} entry; caller gets both position and facing.

    local function GetCombineSpawnEntry()
        local pts = {}

        if zb and zb.GetMapPoints then
            local tPts = zb.GetMapPoints("HMCD_TDM_T") or {}
            for _, v in pairs(tPts) do
                if v.pos then table.insert(pts, { pos = v.pos, ang = v.ang }) end
            end

            if #pts > 0 then
                return pts[math.random(#pts)]
            end

            local coopPts = zb.GetMapPoints("HMCD_COOP_SPAWN") or {}
            for _, v in pairs(coopPts) do
                if v.pos then table.insert(pts, { pos = v.pos, ang = v.ang }) end
            end
        end

        if #pts == 0 then
            for _, ent in ipairs(ents.FindByClass("info_player_start")) do
                table.insert(pts, { pos = ent:GetPos(), ang = ent:GetAngles() })
            end
        end

        if #pts == 0 then return nil end
        return pts[math.random(#pts)]
    end

    -- ── Helpers ───────────────────────────────────────────────────────────────────

    local function HasActiveElite()
        for _, p in ipairs(player.GetAll()) do
            if p:Team() == TEAM_SPECTATOR then continue end
            if IsValid(p) and p:Alive() and p.subClass == "elite" and ZC_IsPatchCombinePlayer(p) then
                return true
            end
        end
        return false
    end

    local function CountCombinePlayers()
        local count = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ZC_IsPatchCombinePlayer(ply) and ply:Alive() then count = count + 1 end
        end
        return count
    end

    -- SteamID (v2 format) of the player who always spawns first as Elite
    -- when the death squad is called and they are dead.
    local PRIORITY_ELITE_STEAMID = "STEAM_0:0:626268130"

    local function GetFlankCandidates()
        local dead     = {}
        local priority = nil
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ply:Alive() then continue end
            if ply.PlayerClassName == "Gordon" then continue end
            if not ZC_IsPatchRebelPlayer(ply) then continue end
            if ply:SteamID() == PRIORITY_ELITE_STEAMID then
                priority = ply
            else
                table.insert(dead, ply)
            end
        end
        -- Shuffle the rest, then insert the priority player at the front
        for i = #dead, 2, -1 do
            local j = math.random(i)
            dead[i], dead[j] = dead[j], dead[i]
        end
        if priority then table.insert(dead, 1, priority) end
        return dead
    end

    -- ── Spawn ─────────────────────────────────────────────────────────────────────

    local function SpawnAsCombine(ply)
        if not IsValid(ply) then return end
        if ply:Alive() then return end

        ply.ZCityRespawning = nil
        ply.ZC_InWaveQueue  = nil

        local sub
        if ply:SteamID() == PRIORITY_ELITE_STEAMID then
            -- Always Elite when the death squad is active and this priority player is dead.
            sub = "elite"
        elseif math.random() < GetEliteChance() and not HasActiveElite() then
            sub = "elite"
        else
            sub = COMBINE_SUBCLASSES[math.random(#COMBINE_SUBCLASSES)]
        end

        ply.subClass     = sub
        ply.gottarespawn = true

        -- Resolve spawn point before the deferred timer so it isn't recalculated
        -- mid-frame (important when multiple Combine spawn in the same wave tick).
        local spawnEntry = GetCombineSpawnEntry()

        -- Block the CoopPersistence 0.5s check from overriding our class assignment.
        -- SpawnAsRebel achieves this via ZC_ApplyManagedSpawn; we mirror that here
        -- so ShouldSkipManagedSpawn returns true while the Combine setup is in flight.
        ply.ZC_ManagedSpawnUntil = CurTime() + 3

        ply:Spawn()

        timer.Simple(0, function()
            if not IsValid(ply) then return end

            ply:SetSuppressPickupNotices(true)
            ply.noSound = true

            local inv = ply:GetNetVar("Inventory", {})
            inv["Weapons"] = inv["Weapons"] or {}
            inv["Weapons"]["hg_sling"]      = true
            inv["Weapons"]["hg_flashlight"] = true
            ply:SetNetVar("Inventory", inv)

            -- Set subClass BEFORE SetPlayerClass so ZCity's CLASS.On() reads it
            -- and giveSubClassLoadout runs the correct loadout natively.
            -- Never use bNoEquipment — that skips all weapon and armor assignment.
            ply.subClass = (sub == "default") and nil or sub

            print("[ZC DEBUG] SpawnAsCombine: Setting class to 'Combine' (sub=" .. sub .. ") for " .. ply:Nick())
            ply:SetPlayerClass("Combine")

            -- CLASS.On() clears self.subClass after reading it; restore for downstream
            ply.subClass = (sub == "default") and nil or sub

            if ZC_RefreshCombineEliteClientState then
                ZC_RefreshCombineEliteClientState(ply)
            end

            if sub == "elite" then
                zb.GiveRole(ply, "Elite", clr_elite)

                timer.Simple(0.1, function()
                    if not IsValid(ply) then return end
                    if ZC_ApplyEliteStats then ZC_ApplyEliteStats(ply) end
                    if ZC_RefreshCombineEliteClientState then ZC_RefreshCombineEliteClientState(ply) end
                end)

                local msgs = ZC_EliteMessages
                if msgs and util.NetworkStringToID("ZC_EliteSpawnMessage") ~= 0 then
                    net.Start("ZC_EliteSpawnMessage")
                        net.WriteString(msgs[math.random(#msgs)])
                    net.Send(ply)
                end

                for _, p in ipairs(player.GetAll()) do
                    if p:Team() == TEAM_SPECTATOR then continue end
                    if IsValid(p) and p:Alive() and ZC_IsPatchRebelPlayer(p) then
                        p:ChatPrint("[ZCity] WARNING: An Elite soldier has been deployed with the death squad.")
                    end
                end
            else
                zb.GiveRole(ply, "Soldier", clr_combine)
            end

            ply:Give("weapon_hands_sh")
            ply:SelectWeapon("weapon_hands_sh")

            -- Position from PointEditor entry (includes angle) or world origin fallback.
            -- ZC_ApplyManagedSpawn mirrors what SpawnAsRebel does: repeated placement
            -- at 0 / 0.15 / 0.6s and keeps ZC_ManagedSpawnUntil live so the
            -- CoopPersistence 0.5s check stays suppressed through the whole setup window.
            local spawnPos = spawnEntry and spawnEntry.pos or Vector(0, 0, 0)
            local spawnAng = spawnEntry and spawnEntry.ang or nil
            if _G.ZC_ApplyManagedSpawn then
                _G.ZC_ApplyManagedSpawn(ply, spawnPos, spawnAng, 2)
            else
                ply:SetPos(spawnPos)
                if spawnAng then ply:SetEyeAngles(spawnAng) end
                ply:SetLocalVelocity(Vector(0, 0, 0))
                ply.ZC_ManagedSpawnUntil = CurTime() + 2
            end

            timer.Simple(0.1, function()
                if IsValid(ply) then
                    ply.noSound = false
                    ply:SetSuppressPickupNotices(false)
                end
            end)

            -- Match Rebel respawn protection window.
            -- Damage blocking is handled by hooks in sv_coop_respawn.lua.
            ply.ZC_SpawnInvincible = true
            timer.Simple(5, function()
                if IsValid(ply) then
                    ply.ZC_SpawnInvincible = nil
                end
            end)
        end)
    end

    -- ── Wave logic ────────────────────────────────────────────────────────────────

    local function SpawnFlankWave()
        if not flankActive then return end
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        if not zb or zb.ROUND_STATE ~= 1 then return end

        local rebelsAlive = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            if not ply:Alive() then continue end
            if ZC_IsPatchRebelPlayer(ply) then rebelsAlive = rebelsAlive + 1 end
        end

        if rebelsAlive == 0 then flankActive = false; return end

        local currentCombine = CountCombinePlayers()
        local slots          = math.max(0, MAX_COMBINE - currentCombine)
        if slots == 0 then return end

        local waveSize   = math.max(1, math.min(slots, math.floor(rebelsAlive / 4)))
        local candidates = GetFlankCandidates()

        for i = 1, math.min(waveSize, #candidates) do
            SpawnAsCombine(candidates[i])
        end
    end

    local function StartFlankSystem()
        if not flankEnabled then return end
        if flankActive then return end
        flankActive = true

        net.Start("ZC_FlankWarning")
            net.WriteFloat(FLANK_DELAY)
        net.Broadcast()

        timer.Create("ZC_FlankFirstWave", FLANK_DELAY, 1, SpawnFlankWave)
        timer.Create("ZC_FlankWave", RESPAWN_INTERVAL, 0, SpawnFlankWave)
    end

    local function StopFlankSystem()
        if not flankActive then return end
        flankActive = false
        timer.Remove("ZC_FlankFirstWave")
        timer.Remove("ZC_FlankWave")
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if ZC_IsPatchCombinePlayer(ply) then continue end
            local sub = ply.subClass
            if sub == "default" or sub == "shotgunner" or sub == "sniper" or sub == "elite" then
                ply.subClass     = nil
                ply.gottarespawn = nil
            end
        end
    end

    -- ── Hooks ─────────────────────────────────────────────────────────────────────

    hook.Add("PlayerDeath", "ZCity_CombineFlank", function(ply)
        if ply.PlayerClassName ~= "Gordon" then return end
        if not CurrentRound or CurrentRound().name ~= "coop" then return end
        if not zb or zb.ROUND_STATE ~= 1 then return end
        StartFlankSystem()
    end)

    hook.Add("Player Spawn", "ZCity_CombineFlank", function(ply)
        if ply:Team() == TEAM_SPECTATOR then return end
        if ply.PlayerClassName ~= "Gordon" then return end
        StopFlankSystem()

        for _, p in ipairs(player.GetAll()) do
            if p:Team() == TEAM_SPECTATOR then continue end
            if ZC_IsPatchCombinePlayer(p) then
                SpawnAsRebel(p, ply)
            end
        end
    end)

    local FLANK_CLASSES  = { Combine = true, Metrocop = true }

    local function ClearPersistenceByClass(classes)
        if not hg or not hg.CoopPersistence then return end
        if hg.CoopPersistence.PendingSave then
            for steamid, data in pairs(hg.CoopPersistence.PendingSave) do
                if classes[data.PlayerClass] or classes[data.Role] then
                    hg.CoopPersistence.PendingSave[steamid] = nil
                end
            end
        end
        if hg.CoopPersistence.LoadedData then
            for steamid, data in pairs(hg.CoopPersistence.LoadedData) do
                if classes[data.PlayerClass] or classes[data.Role] then
                    hg.CoopPersistence.LoadedData[steamid] = nil
                end
            end
        end
    end

    local function ClearCombinePersistence()
        ClearPersistenceByClass(FLANK_CLASSES)
    end

    local function ClearGordonPersistence()
        ClearPersistenceByClass({ Gordon = true, Freeman = true })
    end

    local function StopAndClear()
        StopFlankSystem()
        ClearCombinePersistence()
        ClearGordonPersistence()
    end

    hook.Add("ZB_RoundStart",    "ZCity_CombineFlank", StopAndClear)
    hook.Add("ZB_PreRoundStart", "ZCity_CombineFlank", StopAndClear)
    hook.Add("ZB_EndRound",      "ZCity_CombineFlank", StopAndClear)
    hook.Add("PostCleanupMap",   "ZCity_CombineFlank", StopAndClear)

    hook.Add("HG_PlayerSay", "ZCity_DeathSquadToggle", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text))
        if cmd ~= "!deathsquad" and cmd ~= "/deathsquad" then return end
        txtTbl[1] = ""

        if not ply:IsSuperAdmin() then
            ply:ChatPrint("[ZCity] Only superadmins can toggle the death squad.")
            return
        end

        flankEnabled = not flankEnabled
        local state = flankEnabled and "ENABLED" or "DISABLED"
        PrintMessage(HUD_PRINTTALK, "[ZCity] Death squad system " .. state .. " by " .. ply:Nick() .. ".")

        if not flankEnabled and flankActive then
            StopFlankSystem()
            PrintMessage(HUD_PRINTTALK, "[ZCity] Active death squad wave cancelled.")
        end
    end)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svcoopflank", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)
hook.Add("Think", "ZC_CoopInit_svcoopflank_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svcoopflank_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)

