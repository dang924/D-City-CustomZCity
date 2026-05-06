if not SERVER then return end

util.AddNetworkString("ZCity_Spectator_Health_Sync")

local nextSync = 0

hook.Add("Think", "ZCity_Spectator_Health_Sync_Think", function()
    if CurTime() < nextSync then return end
    nextSync = CurTime() + 0.5

    local spectators = {}
    for _, ply in ipairs(player.GetAll()) do
        if not ply:Alive() or ply:GetObserverMode() ~= OBS_MODE_NONE then
            table.insert(spectators, ply)
        end
    end

    if #spectators == 0 then return end

    local alivePlayers = {}
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE then
            local health = ply:Health()
            
            if ply.organism and ply.organism.blood then
                health = ply.organism.blood / 50 
            end
            
            table.insert(alivePlayers, {ply = ply, health = math.Clamp(health, 0, 100)})
        end
    end

    if #alivePlayers == 0 then return end

    net.Start("ZCity_Spectator_Health_Sync")
    net.WriteUInt(#alivePlayers, 8)
    for _, data in ipairs(alivePlayers) do
        net.WriteEntity(data.ply)
        net.WriteFloat(data.health)
    end
    net.Send(spectators)
end)