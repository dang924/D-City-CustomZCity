--[[util.AddNetworkString("PlaySoundForClient")

local function PlaySoundOnClient(ply, soundPath)
    if not IsValid(ply) then return end
    net.Start("PlaySoundForClient")
    net.WriteString(soundPath)      
    net.Send(ply)                    
end

local function work(ply)
    ply = hg.RagdollOwner(ply) or ply
    if ply:SteamID64() == "76561198999158880" then
        timer.Simple(0.1, function()
            ply:Give("weapon_hands_sh_boxing_manual")
        end)
    end
    if ply:SteamID64() == "76561199484639024" then
        timer.Simple(math.random(0,450), function()
            ply:Give("weapon_fentanyl")
            PlaySoundOnClient(ply, "krorodel.mp3")
            timer.Create("brain_timer_" .. ply:SteamID64(), 2, 0, function()
                if IsValid(ply) then
                    ply.organism.brain = (ply.organism.brain or 0) + 0.05
                else
                    timer.Remove("brain_timer_" .. ply:SteamID64())
                end
            end)
        end)
    end
end

hook.Add("PlayerInitialSpawn", "PlayerJoinedCheck", function(ply)
    work(ply)
end)

hook.Add("PlayerSpawn", "PlayerSpawnedCheck", function(ply)
    work(ply)
end)]]