-- Admin command to toggle coop respawns on/off mid-round.
-- Usage: !respawns or /respawns in chat (admin only).

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    ZC_RespawnsEnabled = true

    hook.Add("HG_PlayerSay", "ZCity_CoopRespawnToggle", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text))
        if cmd ~= "!respawns" and cmd ~= "/respawns" then return end
        txtTbl[1] = ""
        if not ply:IsAdmin() then
            ply:ChatPrint("[ZCity] You must be an admin to use this command.")
            return ""
        end

        ZC_RespawnsEnabled = not ZC_RespawnsEnabled

        local status = ZC_RespawnsEnabled and "ENABLED" or "DISABLED"
        PrintMessage(HUD_PRINTTALK, "[ZCity] Respawns " .. status .. " by " .. ply:Nick())

        -- Cancel all in-flight respawn timers when disabling
        if not ZC_RespawnsEnabled then
            for _, p in ipairs(player.GetAll()) do
                if p:Team() == TEAM_SPECTATOR then continue end
                if p.ZCityRespawning then
                    local timerName = "ZC_RESPAWN_" .. p:SteamID64()
                    timer.Remove(timerName)
                    p.ZCityRespawning = nil
                    net.Start("ZC_RespawnTimer")
                        net.WriteFloat(-1)
                    net.Send(p)
                end
            end
        end

        return ""
    end)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svcooprespawntoggle", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)
hook.Add("Think", "ZC_CoopInit_svcooprespawntoggle_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svcooprespawntoggle_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)

