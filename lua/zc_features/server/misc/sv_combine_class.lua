-- Lets Combine players choose their subclass via !combineclass in chat.
-- Elite is excluded from manual selection and assigned randomly at a low chance.
-- Elite soldiers receive enhanced organism stats comparable to Gordon.

if CLIENT then return end
if not ZC_IsPatchRebelClassName then
    include("autorun/server/sv_patch_player_factions.lua")
end

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    util.AddNetworkString("ZC_EliteSpawnMessage")

    local ELITE_MESSAGES = {
        "Failure is not an option.",
        "You were made for this.",
        "The Combine does not forget. Neither should you.",
        "Precision. Discipline. Dominance.",
        "You are the last line. Hold it.",
        "Resistance is a temporary condition.",
        "They will remember this day. Make sure they fear it.",
        "Your augmentations exist for moments like this.",
        "Overwatch is watching. Do not disappoint.",
        "One soldier. One outcome. Victory.",
        "You are beyond them. Prove it.",
        "The weak fall. You are not weak.",
    }

    -- Only Combine players can use this
    -- Subclasses available for manual selection (Elite is random-only)
    local MANUAL_SUBCLASSES = {
        ["default"]    = "Soldier",
        ["sniper"]     = "Sniper",
        ["shotgunner"] = "Shotgunner",
        ["metropolice"] = "Metropolice",
    }

    local ELITE_CHANCE   = 0.10  -- 10% chance of becoming Elite on respawn
    local SUBCLASS_DECAY = 0     -- 0 = preference persists until changed

    _G.ZC_GetCombineEliteChance = function()
        return ELITE_CHANCE
    end

    local function GetCombineCount()
        local n = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            local isCombine = ply.PlayerClassName == "Combine" or ply.PlayerClassName == "Metrocop"
            if isCombine then n = n + 1 end
        end
        return n
    end

    local function ScaleSlots(base, key, maxClamp)
        local mult = ZC_GetSubclassSlotMultiplier and ZC_GetSubclassSlotMultiplier("combine", key, 1) or 1
        return math.Clamp(math.floor(base * math.max(mult, 0) + 0.5), 0, maxClamp)
    end

    local function GetMaxSnipers()
        return ScaleSlots(math.Clamp(math.floor(GetCombineCount() / 4), 1, 4), "sniper", 12)
    end

    local function GetMaxShotgunners()
        return ScaleSlots(math.Clamp(math.floor(GetCombineCount() / 3), 1, 5), "shotgunner", 12)
    end

    local function GetMaxMetropolice()
        return ScaleSlots(math.Clamp(math.floor(GetCombineCount() / 5), 1, 3), "metropolice", 12)
    end

    local function CountSubclass(subClass, exclude)
        local n = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply == exclude then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            local isCombine = ply.PlayerClassName == "Combine" or ply.PlayerClassName == "Metrocop"
            if not isCombine then continue end
            if ply.subClass == subClass then
                n = n + 1
            end
        end
        return n
    end

    local function SubclassSlotsFull(subClass, ply)
        if subClass == "sniper" then
            return CountSubclass("sniper", ply) >= GetMaxSnipers(), CountSubclass("sniper", ply), GetMaxSnipers()
        elseif subClass == "shotgunner" then
            return CountSubclass("shotgunner", ply) >= GetMaxShotgunners(), CountSubclass("shotgunner", ply), GetMaxShotgunners()
        elseif subClass == "metropolice" then
            return CountSubclass("metropolice", ply) >= GetMaxMetropolice(), CountSubclass("metropolice", ply), GetMaxMetropolice()
        end

        return false, 0, 0
    end

    local function HasActiveElite()
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            local isCombine = ply.PlayerClassName == "Combine" or ply.PlayerClassName == "Metrocop"
            if IsValid(ply) and ply:Alive() and ply.subClass == "elite" and isCombine then
                return true
            end
        end
        return false
    end

    local clr_combine   = Color(89,  230, 255)
    local clr_elite     = Color(246, 13,  13)
    local clr_sniper    = Color(89,  230, 255)
    local clr_shotgun   = Color(220, 80,  80)

    local clr_metro     = Color(89,  180, 255)

    local SUBCLASS_COLORS = {
        ["default"]     = clr_combine,
        ["elite"]       = clr_elite,
        ["sniper"]      = clr_sniper,
        ["shotgunner"]  = clr_shotgun,
        ["metropolice"] = clr_metro,
    }

    local SUBCLASS_ROLES = {
        ["default"]     = "Soldier",
        ["elite"]       = "Elite",
        ["sniper"]      = "Sniper",
        ["shotgunner"]  = "Shotgunner",
        ["metropolice"] = "Officer",
    }

    -- Apply Elite organism enhancements — close to Gordon's HEV stats but
    -- representing augmented Combine biology rather than a suit
    local function ApplyEliteStats(ply)
        if not IsValid(ply) then return end
        local org = ply.organism
        if not org then return end

        -- Recoil control: Gordon is 0.2 at full HEV, Elite gets 0.3
        org.recoilmul    = 0.3

        -- Melee power: Gordon is 2.0, Elite gets 1.75
        org.meleespeed   = 1.75

        -- Stamina regen: Gordon gets up to 4x, Elite gets 2.5x
        if org.stamina then
            org.stamina.regen = 2.5
        end

        -- Stamina drain reduction (superfighter halves drain cost)
        org.superfighter = true

        -- Reduced bleeding — Combine augmentation slows blood loss
        org.bleedingmul  = 0.5

        -- Suppress pulse check notifications (no pain feedback like Gordon)
        org.CantCheckPulse = true

    end

    -- Remove Elite enhancements when class changes away from Elite
    local function RemoveEliteStats(ply)
        if not IsValid(ply) then return end
        local org = ply.organism
        if not org then return end

        org.recoilmul      = 0.6   -- standard Combine recoil
        org.meleespeed     = 1
        if org.stamina then
            org.stamina.regen = 1
        end
        org.superfighter   = false
        org.bleedingmul    = 1
        org.CantCheckPulse = nil
    end

    local function RefreshEliteClientState(ply)
        if not IsValid(ply) then return end
        local isCombineFaction = ply.PlayerClassName == "Combine" or ply.PlayerClassName == "Metrocop"
        local isElite = isCombineFaction and ply.subClass == "elite"
        ply:SetNWBool("ZC_IsCombineElite", isElite)
    end

    _G.ZC_RefreshCombineEliteClientState = RefreshEliteClientState
    _G.ZC_ApplyEliteStats  = ApplyEliteStats
    _G.ZC_RemoveEliteStats = RemoveEliteStats
    _G.ZC_EliteMessages    = ELITE_MESSAGES

    local function ApplySubclass(ply, subClass)
        if not IsValid(ply) then return end
        if ply.PlayerClassName ~= "Combine" then
            ply:ChatPrint("[ZCity] You must be a Combine soldier to use this command.")
            return
        end

        -- Remove old Elite stats if switching away
        if ply.subClass == "elite" and subClass ~= "elite" then
            RemoveEliteStats(ply)
        end

        ply.subClass              = subClass
        ply.ZCCombineSubClass     = subClass  -- persist across deaths
        local roleName            = SUBCLASS_ROLES[subClass]
        local roleColor           = SUBCLASS_COLORS[subClass]
        RefreshEliteClientState(ply)

        -- If alive, reapply loadout immediately
        if ply:Alive() then
            ply:SetSuppressPickupNotices(true)
            ply.noSound = true


            -- Do not strip weapons or block default loadout. Let ZCity/default system handle it.
            -- After default loadout, add bandages and morphine (except Gordon)
            timer.Simple(0.1, function()
                if not IsValid(ply) then return end
                if ply.PlayerClassName ~= "Gordon" then
                    if not ply:HasWeapon("weapon_bandage_sh") then ply:Give("weapon_bandage_sh") end
                    if not ply:HasWeapon("weapon_morphine") then ply:Give("weapon_morphine") end
                end
            end)

            -- Apply Elite stats after spawn hooks settle
            if subClass == "elite" then
                timer.Simple(0.1, function()
                    ApplyEliteStats(ply)
                    RefreshEliteClientState(ply)
                end)

                net.Start("ZC_EliteSpawnMessage")
                    net.WriteString(ELITE_MESSAGES[math.random(#ELITE_MESSAGES)])
                net.Send(ply)
            end

            timer.Simple(0.1, function()
                if IsValid(ply) then
                    ply.noSound = false
                    ply:SetSuppressPickupNotices(false)
                end
            end)

            ply:ChatPrint("[ZCity] Subclass changed to " .. roleName .. " immediately.")
        else
            ply:ChatPrint("[ZCity] Subclass set to " .. roleName .. ". Takes effect on next respawn.")
        end

    end

    local function PrintHelp(ply)
        ply:ChatPrint("[ZCity] Available Combine subclasses:")
        for key, name in pairs(MANUAL_SUBCLASSES) do
            ply:ChatPrint("  !combineclass " .. key .. " — " .. name)
        end
        ply:ChatPrint("  Elite is assigned randomly (" .. math.floor(ELITE_CHANCE * 100) .. "% chance on respawn)" .. (ply:IsSuperAdmin() and " — superadmins may force with !combineclass elite." or "."))
    end

    hook.Add("HG_PlayerSay", "ZCity_CombineClassSelect", function(ply, txtTbl, text)
        local args = string.Split(string.lower(string.Trim(text)), " ")
        if args[1] ~= "!combineclass" and args[1] ~= "/combineclass" then return end
        txtTbl[1] = ""

        if ply.PlayerClassName ~= "Combine" then
            ply:ChatPrint("[ZCity] Only Combine players can use !combineclass.")
            return ""
        end

        if not args[2] then
            PrintHelp(ply)
            return ""
        end

        local chosen = args[2]

        if chosen ~= "default" and chosen ~= "elite" then
            local full, used, maxAllowed = SubclassSlotsFull(chosen, ply)
            if full then
                ply:ChatPrint(string.format("[ZCity] %s slots are full (%d/%d).", string.upper(chosen), used, maxAllowed))
                return ""
            end
        end

        -- Block manual Elite selection unless superadmin
        if chosen == "elite" then
            if not ply:IsSuperAdmin() then
                ply:ChatPrint("[ZCity] Elite is a special assignment — it cannot be chosen manually.")
                return ""
            end
            -- Superadmins can force Elite even if one already exists
            if HasActiveElite() then
                ply:ChatPrint("[ZCity] Warning: an Elite is already active. Superadmin override applied.")
            else
                ply:ChatPrint("[ZCity] Superadmin override: assigning Elite.")
            end
        end

        if not MANUAL_SUBCLASSES[chosen] and chosen ~= "elite" then
            ply:ChatPrint("[ZCity] Unknown subclass '" .. chosen .. "'.")
            PrintHelp(ply)
            return ""
        end

        ApplySubclass(ply, chosen)
        return ""
    end)

    -- On spawn: roll for Elite, then restore saved subclass preference or default.
    -- Set ply.subClass BEFORE SetPlayerClass so ZCity's CLASS.On() reads it and
    -- runs giveSubClassLoadout natively — same pattern as the rebel fix.
    -- Never use bNoEquipment; that skips all weapon and armor assignment.
    hook.Add("Player Spawn", "ZCity_CombineClassRestore", function(ply)
        if ply:Team() == TEAM_SPECTATOR then return end
        local isCombineFaction = ply.PlayerClassName == "Combine" or ply.PlayerClassName == "Metrocop"
        if not isCombineFaction then return end

        timer.Simple(0.1, function()
            if not IsValid(ply) or not ply:Alive() then return end

            -- ── Elite roll ───────────────────────────────────────────────────────
            if math.random() < ELITE_CHANCE and not HasActiveElite() then
                ply.subClass = "elite"
                ply:SetPlayerClass("Combine")      -- ZCity equips via giveSubClassLoadout
                ply.subClass = "elite"              -- restore after CLASS.On clears it
                zb.GiveRole(ply, "Elite", clr_elite)
                ApplyEliteStats(ply)
                RefreshEliteClientState(ply)
                ply:ChatPrint("[ZCity] You have been selected as an Elite soldier.")
                net.Start("ZC_EliteSpawnMessage")
                    net.WriteString(ELITE_MESSAGES[math.random(#ELITE_MESSAGES)])
                net.Send(ply)
                return
            end

            -- ── Determine subclass ───────────────────────────────────────────────
            -- Use saved preference if it fits within current slot limits.
            local sub = "default"
            if ply.ZCCombineSubClass and MANUAL_SUBCLASSES[ply.ZCCombineSubClass] then
                local pref = ply.ZCCombineSubClass
                if pref == "default" then
                    sub = "default"
                elseif not SubclassSlotsFull(pref, ply) then
                    sub = pref
                else
                    sub = "default"
                    ply:ChatPrint("[ZCity] " .. (MANUAL_SUBCLASSES[pref] or pref) .. " slots are full — spawning as Soldier.")
                end
            end

            -- ── Apply class with subClass pre-set ────────────────────────────────
            ply.subClass = (sub == "default") and nil or sub

            if sub == "metropolice" then
                -- Metropolice is a separate ZCity playerclass; equip natively.
                ply:SetPlayerClass("Metrocop")
                ply.subClass = nil   -- Metrocop has no sub, CLASS.On cleared it
            else
                ply:SetPlayerClass("Combine")
                ply.subClass = (sub == "default") and nil or sub  -- restore after CLASS.On
            end

            RefreshEliteClientState(ply)
            zb.GiveRole(ply, SUBCLASS_ROLES[sub] or "Soldier", SUBCLASS_COLORS[sub] or clr_combine)
        end)
    end)

    -- Voice lines specifically for kill reports to Overwatch
    -- Chosen from the most fitting lines in the existing Combine pool
    local ELITE_KILL_REPORTS = {
        "npc/combine_soldier/vo/onedown.wav",
        "npc/combine_soldier/vo/contactconfirmprosecuting.wav",
        "npc/combine_soldier/vo/containmentproceeding.wav",
        "npc/combine_soldier/vo/overwatchconfirmhvtcontained.wav",
        "npc/combine_soldier/vo/engagedincleanup.wav",
        "npc/combine_soldier/vo/executingfullresponse.wav",
        "npc/combine_soldier/vo/reportingclear.wav",
        "npc/combine_soldier/vo/reportallpositionsclear.wav",
        "npc/combine_soldier/vo/prosecuting.wav",
        "npc/combine_soldier/vo/copythat.wav",
    }

    -- No dedicated laugh exists in HL2's combine VO — use the closest
    -- victory/clear callouts as the "last rebel down" response
    local LAUGH_LINES = {
        "npc/combine_soldier/vo/ripcordripcord.wav",
        "npc/combine_soldier/vo/reportallpositionsclear.wav",
        "npc/combine_soldier/vo/reportingclear.wav",
        "npc/combine_soldier/vo/overwatchconfirmhvtcontained.wav",
    }

    local KILL_REPORT_COOLDOWN = 3

    local function CountAliveRebels()
        local count = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ply:Alive() and ZC_IsPatchRebelClassName(ply.PlayerClassName) then
                count = count + 1
            end
        end
        return count
    end

    hook.Add("PlayerDeath", "ZCity_EliteKillReport", function(victim, inflictor, attacker)
        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        local isCombineFaction = attacker.PlayerClassName == "Combine" or attacker.PlayerClassName == "Metrocop"
        if not isCombineFaction then return end
        if attacker.subClass ~= "elite" then return end
        if not ZC_IsPatchRebelClassName(victim.PlayerClassName) then return end

        attacker.ZCEliteReportCD = attacker.ZCEliteReportCD or 0
        if CurTime() < attacker.ZCEliteReportCD then return end
        attacker.ZCEliteReportCD = CurTime() + KILL_REPORT_COOLDOWN

        local char = hg.GetCurrentCharacter(attacker)

        -- Check remaining rebels after this kill (victim is already dead)
        -- timer.Simple(0) lets the death fully process before counting
        timer.Simple(0, function()
            if not IsValid(attacker) then return end

            local rebelsLeft = CountAliveRebels()

            if rebelsLeft == 0 then
                -- Last rebel down — play victory callout
                local phrase = LAUGH_LINES[math.random(#LAUGH_LINES)]

                if IsValid(char) then
                    char:EmitSound(phrase, 80, attacker.VoicePitch or 100)
                else
                    attacker:EmitSound(phrase, 80, attacker.VoicePitch or 100)
                end

            else
                -- Regular kill report
                local line = ELITE_KILL_REPORTS[math.random(#ELITE_KILL_REPORTS)]
                if IsValid(char) then
                    char:EmitSound(line, 80, attacker.VoicePitch or 100)
                else
                    attacker:EmitSound(line, 80, attacker.VoicePitch or 100)
                end

            end
        end)
    end)

    -- Clean up on disconnect
    hook.Add("PlayerDisconnected", "ZCity_CombineClassRestore", function(ply)
        ply.ZCCombineSubClass = nil
    end)

    hook.Add("PlayerDisconnected", "ZCity_EliteKillReport", function(ply)
        ply.ZCEliteReportCD = nil
        if IsValid(ply) then
            ply:SetNWBool("ZC_IsCombineElite", false)
        end
    end)

    hook.Add("Player Spawn", "ZCity_CombineEliteClientState", function(ply)
        timer.Simple(0, function()
            if IsValid(ply) then
                RefreshEliteClientState(ply)
            end
        end)
    end)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svcombineclass", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)
hook.Add("Think", "ZC_CoopInit_svcombineclass_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svcombineclass_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)

