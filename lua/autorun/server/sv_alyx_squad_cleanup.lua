-- Clears npc_alyx from player_squad on round end.
-- GMod has a bug where squad references accumulate across round restarts
-- when npc_alyx is repeatedly spawned, eventually overflowing player_squad
-- and causing crashes. Extracted from AI_PATCH npc_dormancy_zcity_patch.lua.

if CLIENT then return end

hook.Add("ZB_EndRound", "ZCity_AlyxSquadCleanup", function()
    for _, alyx in ipairs(ents.FindByClass("npc_alyx")) do
        if IsValid(alyx) then
            alyx:Fire("ClearPlayerSquad")
        end
    end
end)
