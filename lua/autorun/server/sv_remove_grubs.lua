-- sv_remove_grubs.lua
-- Removes npc_antlion_grub entities as they spawn.
-- In multiplayer these serve no gameplay purpose and the "Dormant entity
-- is thinking" warning they generate in bulk can cause memory pressure
-- and server instability on ep2 maps.

if CLIENT then return end

hook.Add("OnEntityCreated", "ZC_RemoveAntlionGrubs", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "npc_antlion_grub" then return end
    ent:Remove()
end)
