-- Makes key HL2 NPCs invincible while a Gordon player is alive.
--
-- FL_GODMODE is ineffective in ZCity because all damage is routed through
-- the organism system which ignores that flag. Instead we intercept
-- EntityTakeDamage directly and return true to cancel the damage.
--
-- Alyx is also set to the resistance squad so she correctly targets
-- Combine players rather than looping companion AI schedules.

if CLIENT then return end

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    local PROTECTED_NPCS = {
        ["npc_alyx"]    = true,
        ["npc_kleiner"] = true,
        ["npc_eli"]     = true,
        ["npc_mossman"] = true,
        ["npc_barney"]  = true,
        ["npc_dog"]     = true,
        ["npc_monk"]    = true,
        ["npc_breen"]   = true,
    }

    -- Story-critical NPCs that must never be killed; checked by targetname (entity name).
    -- Keeping these alive prevents scene entities from losing their actors, which
    -- causes the CSceneEntity I/O loop that crashes the server.
    local PROTECTED_NPC_NAMES = {
        ["citizen_2_ct"] = true,
    }

    local function GetGordon()
        for _, ply in ipairs(player.GetAll()) do
            if ply.PlayerClassName == "Gordon" and ply:Alive() then
                return ply
            end
        end
    end

    -- Cancel any damage to protected NPCs (by class) while Gordon is alive,
    -- and always cancel damage to story-critical NPCs protected by name.
    hook.Add("EntityTakeDamage", "AllyNPCsInvincible", function(ent, dmgInfo)
        if PROTECTED_NPC_NAMES[ent:GetName()] then return true end
        if not PROTECTED_NPCS[ent:GetClass()] then return end
        if IsValid(GetGordon()) then return true end
    end)


end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svalyxinvincible", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)
hook.Add("Think", "ZC_CoopInit_svalyxinvincible_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svalyxinvincible_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)

-- ── Scene-actor loop guard ──────────────────────────────────────────────────
-- When a logic_choreographed_scene cannot find its actor NPC it fires
-- OnCanceled, which is usually wired to re-trigger the scene.  This creates
-- an infinite I/O loop that spams CSceneEntity errors and crashes the server.
-- After map init, find scene entities whose named actors are absent and
-- cancel them so the I/O chain is broken.
local SCENE_ACTOR_GUARD_NAMES = {
    "citizen_2_ct",
}

local function CancelOrphanedSceneEntities()
    local missingActors = {}
    for _, name in ipairs(SCENE_ACTOR_GUARD_NAMES) do
        if #ents.FindByName(name) == 0 then
            missingActors[name] = true
        end
    end
    if not next(missingActors) then return end

    local cancelled = 0
    for _, scene in ipairs(ents.FindByClass("logic_choreographed_scene")) do
        if not IsValid(scene) then continue end
        -- Cancel the current run; this breaks the OnCanceled → relay → retrigger loop.
        scene:Fire("Cancel", "", 0)
        -- Disable the scene entirely so it cannot restart.
        scene:Fire("Disable", "", 0)
        cancelled = cancelled + 1
    end

    for name in pairs(missingActors) do
        print("[DCityPatch] SceneActorGuard: actor '" .. name ..
              "' not found — cancelled " .. cancelled .. " logic_choreographed_scene entities.")
    end
end

hook.Add("InitPostEntity", "DCityPatch_SceneActorGuard", function()
    -- Run after all map entities have had time to spawn and activate.
    timer.Simple(2, CancelOrphanedSceneEntities)
end)

hook.Add("PostCleanupMap", "DCityPatch_SceneActorGuard", function()
    timer.Simple(2, CancelOrphanedSceneEntities)
end)

