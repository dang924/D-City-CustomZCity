-- sv_coop_subclass.lua
-- Lets players choose their own subclass via !rebelclass in chat.
-- Applies immediately if alive. Only applies to Rebel and Refugee classes.
--
-- Medic cap: scales with player count and applies to explicit player choices.
-- Players without a preference remain default Soldier on spawn.
-- Formula: max(1, floor(rebelCount / 4)), hard capped at floor(32/4) = 8.

if CLIENT then return end
if not ZC_IsPatchRebelPlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true

    local VALID_SUBCLASSES = {
        ["default"]   = "Soldier",
        ["medic"]     = "Medic",
        ["sniper"]    = "Sniper",
        ["grenadier"] = "Grenadier",
    }

    local clr_rebel     = Color(255, 155, 0)
    local clr_medic     = Color(190, 0, 0)
    local clr_sniper    = Color(100, 180, 255)
    local clr_grenadier = Color(190, 90, 0)

    local SUBCLASS_COLORS = {
        ["default"]   = clr_rebel,
        ["medic"]     = clr_medic,
        ["sniper"]    = clr_sniper,
        ["grenadier"] = clr_grenadier,
    }

    -- Medic cap: 1 per 4 rebels, min 1, max 8
    local function GetRebelCount()
        local n = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ply.PlayerClassName == "Gordon" then continue end
            if ZC_IsPatchRebelPlayer(ply) then n = n + 1 end
        end
        return n
    end

    local function GetMaxMedics()
        local base = math.Clamp(math.floor(GetRebelCount() / 4), 1, 8)
        local mult = ZC_GetSubclassSlotMultiplier and ZC_GetSubclassSlotMultiplier("rebel", "medic", 1) or 1
        return math.Clamp(math.floor(base * math.max(mult, 0) + 0.5), 0, 16)
    end

    local function GetMaxGrenadiers()
        local base = math.min(3, math.floor(GetRebelCount() / 6))
        local mult = ZC_GetSubclassSlotMultiplier and ZC_GetSubclassSlotMultiplier("rebel", "grenadier", 1) or 1
        return math.Clamp(math.floor(base * math.max(mult, 0) + 0.5), 0, 12)
    end

    local function CountCurrentMedics(exclude)
        local n = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply == exclude then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ply.subClass == "medic" then
                n = n + 1
            end
        end
        return n
    end

    local function CountCurrentGrenadiers(exclude)
        local n = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply == exclude then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ply.subClass == "grenadier" then
                n = n + 1
            end
        end
        return n
    end

    local function MedicCapReached(exclude)
        return CountCurrentMedics(exclude) >= GetMaxMedics()
    end

    local function GrenadierCapReached(exclude)
        return CountCurrentGrenadiers(exclude) >= GetMaxGrenadiers()
    end

    local function PrintSubclassHelp(ply)
        local maxMedics = GetMaxMedics()
        local curMedics = CountCurrentMedics(ply)
        local maxGrenadiers = GetMaxGrenadiers()
        local curGrenadiers = CountCurrentGrenadiers(ply)
        ply:ChatPrint("[ZCity] Available subclasses:")
        for key, name in SortedPairs(VALID_SUBCLASSES) do
            local note = ""
            if key == "medic" then
                note = string.format("  (%d/%d slots)", curMedics, maxMedics)
            elseif key == "grenadier" then
                note = string.format("  (%d/%d slots)", curGrenadiers, maxGrenadiers)
            end
            ply:ChatPrint("  !rebelclass " .. key .. " -- " .. name .. note)
        end
        ply:ChatPrint("[ZCity] Base classes (map-determined by default):")
        ply:ChatPrint("  !rebelclass rebel -- Switch to Rebel")
        ply:ChatPrint("  !rebelclass refugee -- Switch to Refugee")
        ply:ChatPrint("[ZCity] Changes apply immediately if you are alive.")
    end

    local function RefreshClassAppearance(ply, className, subClass)
        if not IsValid(ply) then return end

        local resolvedClass = tostring(className or ply.PlayerClassName or "")
        if resolvedClass == "" then return end

        local function IsValidPlayerModel(mdl)
            mdl = string.lower(tostring(mdl or ""))
            return mdl ~= "" and util.IsValidModel(mdl)
        end

        local function EnsureValidPlayerModel()
            local current = tostring(ply:GetModel() or "")
            if IsValidPlayerModel(current) then return end

            local fallbackByClass = {
                Refugee = "models/player/group03m/male_07.mdl",
                Rebel = "models/player/group03/male_07.mdl",
            }

            local fallback = fallbackByClass[resolvedClass] or "models/player/group03/male_07.mdl"
            if IsValidPlayerModel(fallback) then
                ply:SetModel(fallback)
                return
            end

            -- Last resort on odd content packs.
            ply:SetModel("models/player/kleiner.mdl")
        end

        local resolvedSubClass = (subClass == "default") and nil or subClass

        -- Re-run the class On() path with the intended subclass already set.
        -- Rebel medic model selection happens there before the class clears subClass.
        ply.subClass = resolvedSubClass
        ply:SetPlayerClass(resolvedClass, { bNoEquipment = true })
        ply.subClass = resolvedSubClass

        -- Refugee medic does not currently swap in the base class file, so patch it here.
        if resolvedSubClass == "medic" and resolvedClass == "Refugee" then
            local mdl = string.lower(tostring(ply:GetModel() or ""))
            local remapped = mdl
            remapped = string.gsub(remapped, "models/player/group01/", "models/player/group03m/")
            remapped = string.gsub(remapped, "models/humans/group01/", "models/humans/group03m/")
            remapped = string.gsub(remapped, "/rebels_standart/", "/")
            if IsValidPlayerModel(remapped) then
                ply:SetModel(remapped)
            end
        end

        EnsureValidPlayerModel()
    end

    _G.ZC_RefreshCoopClassAppearance = RefreshClassAppearance

    -- Strip + re-equip in place, no respawn needed
    local function ApplyLoadoutInPlace(ply, subClass)
        if not IsValid(ply) then return end
        local sub = subClass == "default" and nil or subClass
        ply.subClass = sub

        RefreshClassAppearance(ply, ply.PlayerClassName, subClass)

        ply:SetSuppressPickupNotices(true)
        ply.noSound = true
        ply:StripWeapons()

        local inv = ply:GetNetVar("Inventory", {})
        inv["Weapons"] = { ["hg_sling"] = true, ["hg_flashlight"] = true }
        ply:SetNetVar("Inventory", inv)

        if ZC_RefreshWeaponInvLimits then
            ZC_RefreshWeaponInvLimits(ply)
        end

        -- Try to apply coop loadout preset for this subclass and current class
        local customApplied = false
        local className = tostring(ply.PlayerClassName or "")
        local baseClass = (className == "Refugee" or className == "Citizen") and "Refugee" or "Rebel"
        if ZC_ApplyCoopLoadout then
            customApplied, _ = ZC_ApplyCoopLoadout(ply, subClass, baseClass)
        end

        -- Fallback to native GiveEquipment if no custom preset applied
        if not customApplied then
            local ok, err = pcall(function() ply:PlayerClassEvent("GiveEquipment", sub) end)
            if not ok then
                print("[ZC SubClass] GiveEquipment error for " .. ply:Nick() .. ": " .. tostring(err))
            end
        end

        local name  = VALID_SUBCLASSES[subClass] or "Soldier"
        local color = SUBCLASS_COLORS[subClass]  or clr_rebel
        zb.GiveRole(ply, name, color)

        if not customApplied then
            ply:Give("weapon_hands_sh")
            ply:SelectWeapon("weapon_hands_sh")
        end

        timer.Simple(0.1, function()
            if IsValid(ply) then
                ply.noSound = false
                ply:SetSuppressPickupNotices(false)
            end
        end)
    end

    -- Chat command
    hook.Add("HG_PlayerSay", "ZCity_SubclassSelect", function(ply, txtTbl, text)
        local args = string.Split(string.lower(string.Trim(text)), " ")
        if args[1] ~= "!rebelclass" and args[1] ~= "/rebelclass" then return end
        txtTbl[1] = ""

        if not args[2] then PrintSubclassHelp(ply); return "" end

        local chosen = args[2]
    
        -- Check if this is a base class selection (rebel/refugee)
        if chosen == "rebel" or chosen == "refugee" then
            -- Base class selection
            local classStr = (chosen == "rebel" and "Rebel") or "Refugee"
            if not ply:Alive() then
                ply:ChatPrint("[ZCity] You must be alive to change class.")
                return ""
            end
            if ply.PlayerClassName == "Gordon" then
                ply:ChatPrint("[ZCity] Gordon cannot change class.")
                return ""
            end
        
            ply.ZC_PickedRebelClass = classStr
            print("[ZC] " .. ply:Nick() .. " changed class to " .. classStr)
            RefreshClassAppearance(ply, classStr, ply.subClass or "default")
        
            -- Apply loadout immediately with current subclass
            local subClass = ply.subClass or "default"
            if ZC_ApplyCoopLoadout then
                local customApplied = ZC_ApplyCoopLoadout(ply, subClass, classStr)
                if not customApplied then
                    ply:Give("weapon_hands_sh")
                    ply:SelectWeapon("weapon_hands_sh")
                end
            end
        
            ply:ChatPrint("[ZCity] Class changed to " .. classStr .. ". Loadout applied.")
            return ""
        end
    
        -- Otherwise handle as subclass selection
        if not VALID_SUBCLASSES[chosen] then
            ply:ChatPrint("[ZCity] Unknown class or subclass '" .. chosen .. "'.")
            PrintSubclassHelp(ply)
            return ""
        end

        if ply:Alive() and not ZC_IsPatchRebelPlayer(ply) then
            ply:ChatPrint("[ZCity] Subclasses are only available for rebel-aligned classes.")
            return ""
        end

        if chosen == "medic" and ply:Alive() and MedicCapReached(ply) then
            ply:ChatPrint(string.format(
                "[ZCity] Medic slots are full (%d/%d). Try a different subclass.",
                CountCurrentMedics(ply), GetMaxMedics()
            ))
            return ""
        end

        if ply.PlayerClassName == "Gordon" then
            ply:ChatPrint("[ZCity] Gordon does not use Rebel subclasses.")
            return ""
        end

        if chosen == "grenadier" and ply:Alive() and GrenadierCapReached(ply) then
            ply:ChatPrint(string.format(
                "[ZCity] Grenadier slots are full (%d/%d). Try a different subclass.",
                CountCurrentGrenadiers(ply), GetMaxGrenadiers()
            ))
            return ""
        end

        -- Store preference ("default" = clear preference, revert to Soldier)
        ply.ZCPreferredSubClass = (chosen ~= "default") and chosen or nil

        if ply:Alive() and ZC_IsPatchRebelPlayer(ply) then
            ApplyLoadoutInPlace(ply, chosen)
            ply:ChatPrint("[ZCity] Subclass changed to " .. VALID_SUBCLASSES[chosen] .. " immediately.")
        else
            ply:ChatPrint("[ZCity] Subclass set to " .. VALID_SUBCLASSES[chosen] .. ". Takes effect on next respawn.")
        end

        return ""
    end)

    -- Respawn restore: re-apply stored preference after each spawn.
    -- Only runs when a player has an explicit preference; players without one
    -- remain default Soldier in sv_coop_respawn.
    hook.Add("Player Spawn", "ZCity_SubclassRestore", function(ply)
        if ply:Team() == TEAM_SPECTATOR then return end
        if ply.PlayerClassName == "Gordon" then return end
        if not ZC_IsPatchRebelPlayer(ply) then return end

        local pref = ply.ZCPreferredSubClass
        if not pref then return end  -- no preference; let sv_coop_respawn handle it

        timer.Simple(0.05, function()
            if not IsValid(ply) or not ply:Alive() then return end
            if not ZC_IsPatchRebelPlayer(ply) then return end

            local subClass = pref
            -- Re-check medic cap at spawn time in case roster changed
            if pref == "medic" and MedicCapReached(ply) then
                ply:ChatPrint("[ZCity] Medic slots full -- spawning as Soldier. Use !rebelclass to change.")
                subClass = "default"
            elseif pref == "grenadier" and GrenadierCapReached(ply) then
                ply:ChatPrint("[ZCity] Grenadier slots full -- spawning as Soldier. Use !rebelclass to change.")
                subClass = "default"
            end

            ApplyLoadoutInPlace(ply, subClass)
        end)
    end)

    hook.Add("PlayerDisconnected", "ZCity_SubclassCleanup", function(ply)
        ply.ZCPreferredSubClass = nil
        ply.subClass = nil
    end)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svcoopsubclass", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)

hook.Add("Think", "ZC_CoopInit_svcoopsubclass_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svcoopsubclass_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)
