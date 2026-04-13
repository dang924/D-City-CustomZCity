-- Fixes npc_turret_floor allegiance for ZCity coop.
-- ZCity's class system can leave turret relationships incorrect for players.
-- We directly set relationships on all turrets whenever a player spawns or
-- a turret is created, using the map's ai_relationship setup as the source
-- of truth for which turrets are friendly vs hostile.
--

if not ZC_IsPatchRebelPlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

local initialized = false
local Initialize

hook.Add("Think", "ZCity_FriendlyTurrets_Late", function()
    if initialized then
        hook.Remove("Think", "ZCity_FriendlyTurrets_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)

hook.Add("InitPostEntity", "ZC_CoopInit_svfriendlyturrets", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)
function Initialize()
    if initialized then return end
    initialized = true
    local FRIENDLY_TURRET_NAMES = {
        ["ep2_outland_02"] = {
            ["turret_buddy_1"] = true,
            ["turret_buddy_2"] = true,
        },
    }

    -- Determine if a turret is friendly to rebels by checking its disposition
    -- toward a known rebel NPC, or via map-specific name override
    local function IsFriendlyTurret(turret)
        -- Map-specific name override
        local mapOverrides = FRIENDLY_TURRET_NAMES[game.GetMap()]
        if mapOverrides then
            local name = turret:GetName()
            if name and mapOverrides[name] then return true end
        end

        -- Check disposition toward rebel NPCs
        for _, class in ipairs({"npc_citizen", "npc_barney", "npc_alyx", "npc_vortigaunt"}) do
            for _, npc in ipairs(ents.FindByClass(class)) do
                if IsValid(npc) then
                    local disp = turret:Disposition(npc)
                    return disp == D_LI or disp == D_NU
                end
            end
        end

        -- No reference NPC found — default to hostile (safe assumption)
        return false
    end

    local function ApplyTurretRelationships(turret)
        if not IsValid(turret) then return end
        if turret:GetClass() ~= "npc_turret_floor" then return end

        local friendly = IsFriendlyTurret(turret)
        local name = turret:GetName()
        local label = (name and name ~= "") and name or ("turret#" .. turret:EntIndex())

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if ply:IsBot() then continue end

            local isRebel   = ZC_IsPatchRebelPlayer(ply)
            local isCombine = ZC_IsPatchCombinePlayer(ply)

            if friendly then
                -- Friendly turret: like rebels, hate Combine
                if isRebel then
                    turret:AddEntityRelationship(ply, D_LI, 0)
                    if IsValid(ply.bull) then turret:AddEntityRelationship(ply.bull, D_LI, 0) end
                elseif isCombine then
                    turret:AddEntityRelationship(ply, D_HT, 99)
                    if IsValid(ply.bull) then turret:AddEntityRelationship(ply.bull, D_HT, 99) end
                end
            else
                -- Hostile turret: hate rebels, like Combine
                if isRebel then
                    turret:AddEntityRelationship(ply, D_HT, 99)
                    if IsValid(ply.bull) then turret:AddEntityRelationship(ply.bull, D_HT, 99) end
                elseif isCombine then
                    turret:AddEntityRelationship(ply, D_LI, 0)
                    if IsValid(ply.bull) then turret:AddEntityRelationship(ply.bull, D_LI, 0) end
                end
            end

            turret:ClearEnemyMemory()
        end
    end

    local function ApplyAllTurrets()
        for _, turret in ipairs(ents.FindByClass("npc_turret_floor")) do
            ApplyTurretRelationships(turret)
        end
    end

    -- New turret spawned
    hook.Add("OnEntityCreated", "ZCity_FriendlyTurrets", function(ent)
        if ent:GetClass() ~= "npc_turret_floor" then return end
        timer.Simple(0.5, function()
            if IsValid(ent) then ApplyTurretRelationships(ent) end
        end)
    end)

    -- Player spawns or changes class
    hook.Add("PlayerSpawn", "ZCity_FriendlyTurrets", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then ApplyAllTurrets() end
        end)
    end)

    -- Map load and round restart
    hook.Add("InitPostEntity", "ZCity_FriendlyTurrets", function()
        timer.Simple(2, ApplyAllTurrets)
    end)

    hook.Add("PostCleanupMap", "ZCity_FriendlyTurrets", function()
        timer.Simple(2, ApplyAllTurrets)
    end)
end



