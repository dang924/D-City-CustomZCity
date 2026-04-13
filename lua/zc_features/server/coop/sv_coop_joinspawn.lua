-- Allows newly connected players to spawn in mid-round via chat command.
-- Usage: !join or /join in chat.

if not ZC_IsPatchRebelPlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    util.AddNetworkString("ZC_RequestJoinSpawn")

    net.Receive("ZC_RequestJoinSpawn", function(len, ply)
        if not IsValid(ply) then return end
        if ply:Alive() then return end
        if ply:Team() == TEAM_SPECTATOR then return end
        if ply.ZCityRespawning then return end

        if not CurrentRound or CurrentRound().name ~= "coop" then return end

        if hg and hg.MapCompleted then
            ply:ChatPrint("[ZCity] Cannot join — the map has already been completed.")
            return
        end
        if not ZC_IsPatchRebelPlayer(ply) then
            ply:ChatPrint("[ZCity] Your current class cannot use coop rebel respawns.")
            return
        end

        local gordon = GetGordon()
        if not IsValid(gordon) or not gordon:Alive() then
            ply:ChatPrint("[ZCity] Cannot join — Gordon is not active.")
            return
        end

        SpawnAsRebel(ply, gordon)
    end)

    hook.Add("HG_PlayerSay", "ZCity_CoopStuck", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text))
        if cmd ~= "!stuck" and cmd ~= "/stuck" then return end
        txtTbl[1] = ""

        if not ZC_IsPatchRebelPlayer(ply) then
            ply:ChatPrint("[ZCity] This class cannot use /stuck.")
            return ""
        end

        local gordon = GetGordon()
        if not IsValid(gordon) or not gordon:Alive() then
            ply:ChatPrint("[ZCity] Cannot unstick: no active Gordon found.")
            return ""
        end

        local offset = Vector(math.Rand(-60, 60), math.Rand(-60, 60), 0)
        ply:SetPos(gordon:GetPos() + offset)
        ply:SetLocalVelocity(Vector(0, 0, 0))
        ply:ChatPrint("[ZCity] Teleported to Gordon.")

        return ""
    end)

    hook.Add("HG_PlayerSay", "ZCity_CoopJoinSpawn", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text))
        if cmd ~= "!join" and cmd ~= "/join" then return end
        txtTbl[1] = ""
        if ply:Alive() then
            ply:ChatPrint("[ZCity] You are already in the game.")
            return ""
        end
        if ply.ZCityRespawning then
            ply:ChatPrint("[ZCity] You are already queued to respawn.")
            return ""
        end
        if not CurrentRound or CurrentRound().name ~= "coop" then
            ply:ChatPrint("[ZCity] Join is only available during a coop round.")
            return ""
        end
        if not ZC_RespawnsEnabled then
            ply:ChatPrint("[ZCity] Respawns are currently disabled.")
            return ""
        end

        if hg and hg.MapCompleted then
            ply:ChatPrint("[ZCity] Cannot join — the map has already been completed.")
            return ""
        end
        if not ZC_IsPatchRebelPlayer(ply) then
            ply:ChatPrint("[ZCity] Your current class cannot use coop rebel respawns.")
            return ""
        end

        local gordon = GetGordon()
        if not IsValid(gordon) or not gordon:Alive() then
            ply:ChatPrint("[ZCity] Cannot join — Gordon is not active.")
            return ""
        end

        SpawnAsRebel(ply, gordon)
        return ""
    end)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svcoopjoinspawn", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)

hook.Add("Think", "ZC_CoopInit_svcoopjoinspawn_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svcoopjoinspawn_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)
