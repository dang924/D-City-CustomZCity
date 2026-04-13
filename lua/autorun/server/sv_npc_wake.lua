-- Wakes dormant NPCs so they participate in scripted sequences and combat.
-- Replaces the harmful npc_dormancy_watchdog.lua from AI_PATCH.
-- Only wakes NPCs — never sets schedules, enemies, or targets.

if CLIENT then return end

local wakeNPCRegistry = {}

local function TrackWakeNPC(ent)
    if IsValid(ent) and ent:IsNPC() then
        wakeNPCRegistry[ent:EntIndex()] = ent
    end
end

hook.Add("InitPostEntity", "ZCity_NPCWake_RegistryInit", function()
    wakeNPCRegistry = {}
    for _, e in ipairs(ents.GetAll()) do
        TrackWakeNPC(e)
    end
end)

hook.Add("OnEntityCreated", "ZCity_NPCWake_RegistryAdd", function(ent)
    timer.Simple(0, function()
        TrackWakeNPC(ent)
    end)
end)

hook.Add("EntityRemoved", "ZCity_NPCWake_RegistryRemove", function(ent)
    if not IsValid(ent) then return end
    wakeNPCRegistry[ent:EntIndex()] = nil
end)

local function WakeNPC(npc)
    if not IsValid(npc) then return end
    if type(npc.IsAsleep) ~= "function" then return end
    if npc:IsAsleep() then
        npc:SetAsleep(false)
    end
end

hook.Add("OnEntityCreated", "ZCity_NPCWake_Spawn", function(ent)
    if not IsValid(ent) or not ent:IsNPC() then return end
    timer.Simple(0.5, function() WakeNPC(ent) end)
end)

local wakeCheckTime = 0
hook.Add("Think", "ZCity_NPCWake_Think", function()
    if wakeCheckTime > CurTime() then return end
    wakeCheckTime = CurTime() + 7
    for idx, npc in pairs(wakeNPCRegistry) do
        if not IsValid(npc) then
            wakeNPCRegistry[idx] = nil
        else
            WakeNPC(npc)
        end
    end
end)

print("[ZCity] NPC wake system loaded")
