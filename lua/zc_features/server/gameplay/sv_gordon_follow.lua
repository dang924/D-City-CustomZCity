-- Forces friendly NPCs to only follow Gordon.
-- Non-Gordon players who try to USE friendly NPCs are met with a voice
-- response and a chat message. No escalation or punishment system.

if CLIENT then return end

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    local FOLLOWER_CLASSES = {
        ["npc_alyx"]                    = true,
        ["npc_barney"]                  = true,
        ["npc_citizen"]                 = true,
        ["npc_vortigaunt"]              = true,
        ["npc_eli"]                     = true,
        ["npc_monk"]                    = true,
        ["npc_dog"]                     = true,
        ["npc_odessa"]                  = true,
        ["npc_turret_floor_resistance"] = true,
    }

    local NPC_LINES = {
        ["npc_barney"] = {
            "npc/barney/ba_notfreeman.wav",
            "npc/barney/ba_nothim.wav",
            "npc/barney/ba_wait.wav",
        },
        ["npc_alyx"] = {
            "npc/alyx/alyx_comeback01.wav",
            "npc/alyx/alyx_nope.wav",
            "npc/alyx/alyx_notfreeman01.wav",
        },
        default = {
            "vo/npc/male01/mygut02.wav",
            "vo/npc/male01/pain01.wav",
            "vo/npc/male01/pain02.wav",
        },
    }

    local SOUND_COOLDOWN = 1.5
    local LOG_COOLDOWN   = 2

    -- ── Main hook: block non-Gordon players from using friendly NPCs ──────────────

    hook.Add("PlayerUse", "ZCity_GordonOnlyFollow", function(ply, ent)
        if not IsValid(ent) or not ent:IsNPC() then return end
        if not FOLLOWER_CLASSES[ent:GetClass()] then return end
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if ply.PlayerClassName == "Gordon" then return end

        local now = CurTime()

        -- NPC voice response with cooldown
        ply.ZCFollowSoundCD = ply.ZCFollowSoundCD or 0
        if now > ply.ZCFollowSoundCD then
            local lines = NPC_LINES[ent:GetClass()] or NPC_LINES["default"]
            ent:EmitSound(lines[math.random(#lines)], 80, 100)
            ply.ZCFollowSoundCD = now + SOUND_COOLDOWN
        end

        ply:ChatPrint("[ZCity] Only Gordon can command friendly NPCs.")

        -- Server log with cooldown
        ply.ZCFollowLogCD = ply.ZCFollowLogCD or 0
        if now > ply.ZCFollowLogCD then
            ply.ZCFollowLogCD = now + LOG_COOLDOWN
        end

        return false
    end)

    -- When Gordon spawns, release NPCs from any non-Gordon follow
    hook.Add("Player Spawn", "ZCity_GordonOnlyFollow", function(ply)
        if ply.PlayerClassName ~= "Gordon" then return end
        timer.Simple(1, function()
            if not IsValid(ply) or not ply:Alive() then return end
            for _, npc in ipairs(ents.FindByClass("npc_*")) do
                if not IsValid(npc) or not FOLLOWER_CLASSES[npc:GetClass()] then continue end
                local followTarget = npc.GetFollowTarget and npc:GetFollowTarget()
                if IsValid(followTarget) and followTarget ~= ply then
                    npc:Fire("StopFollowing")
                end
            end
        end)
    end)

    -- When Gordon dies, stop all NPC following
    hook.Add("PlayerDeath", "ZCity_GordonOnlyFollow", function(ply)
        if ply.PlayerClassName ~= "Gordon" then return end
        for _, npc in ipairs(ents.FindByClass("npc_*")) do
            if not IsValid(npc) or not FOLLOWER_CLASSES[npc:GetClass()] then continue end
            npc:Fire("StopFollowing")
        end
    end)

    -- Clean up on disconnect
    hook.Add("PlayerDisconnected", "ZCity_GordonOnlyFollow", function(ply)
        ply.ZCFollowSoundCD = nil
        ply.ZCFollowLogCD   = nil
    end)

end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svgordonfollow", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)
hook.Add("Think", "ZC_CoopInit_svgordonfollow_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svgordonfollow_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)

