if CLIENT then return end

local COMBINE_POSSESS_CVAR = "zb_coop_rts_cmb"

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

local function IsGordonLikePlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local className = string.lower(tostring(ply.PlayerClassName or ""))
    if className == "gordon" or className == "freeman" then
        return true
    end

    local roleName = string.lower(tostring((ply.GetNWString and ply:GetNWString("Role", "")) or ply.Role or ""))
    return roleName == "freeman" or roleName == "gordon"
end

local function IsAnyGordonAlive()
    for _, ply in ipairs(player.GetAll()) do
        if IsGordonLikePlayer(ply) and ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then
            return true
        end
    end

    return false
end

local function SetCombinePossessEnabled(enabled, reason)
    local cv = GetConVar(COMBINE_POSSESS_CVAR)
    if not cv then return end

    local target = enabled and "1" or "0"
    if cv:GetString() == target then return end

    RunConsoleCommand(COMBINE_POSSESS_CVAR, target)
    print("[ZC Coop] " .. COMBINE_POSSESS_CVAR .. "=" .. target .. (reason and (" [" .. reason .. "]") or ""))
end

local function RefreshCombinePossessGate(reason)
    if not IsCoopRoundActive() then return end

    SetCombinePossessEnabled(not IsAnyGordonAlive(), reason)
end

hook.Add("InitPostEntity", "ZC_CoopCombinePossessGate_Init", function()
    timer.Simple(0.5, function()
        RefreshCombinePossessGate("init")
    end)
end)

hook.Add("ZB_PreRoundStart", "ZC_CoopCombinePossessGate_RoundStart", function()
    timer.Simple(0.25, function()
        SetCombinePossessEnabled(false, "roundstart")
        RefreshCombinePossessGate("roundstart-refresh")
    end)
end)

hook.Add("PlayerSpawn", "ZC_CoopCombinePossessGate_PlayerSpawn", function(ply)
    if not IsValid(ply) then return end

    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        if not IsGordonLikePlayer(ply) then return end

        RefreshCombinePossessGate("gordon-spawn")
    end)
end)

hook.Add("PlayerDeath", "ZC_CoopCombinePossessGate_PlayerDeath", function(ply)
    if not IsValid(ply) then return end
    if not IsGordonLikePlayer(ply) then return end

    timer.Simple(0, function()
        RefreshCombinePossessGate("gordon-death")
    end)
end)

hook.Add("PlayerDisconnected", "ZC_CoopCombinePossessGate_PlayerDisconnected", function(ply)
    if not IsValid(ply) then return end
    if not IsGordonLikePlayer(ply) then return end

    timer.Simple(0, function()
        RefreshCombinePossessGate("gordon-disconnect")
    end)
end)
