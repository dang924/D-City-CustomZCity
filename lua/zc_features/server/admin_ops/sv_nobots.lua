-- sv_nobots.lua — kicks bots on join during coop, toggleable via ULX.
-- Place in: lua/autorun/server/

if CLIENT then return end

ZC_NoBots = ZC_NoBots ~= nil and ZC_NoBots or true  -- enabled by default

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("PlayerInitialSpawn", "ZC_NoBots", function(ply)
    if not ply:IsBot() then return end
    if not ZC_NoBots then return end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if not IsCoopRoundActive() then return end
        ply:Kick("Bots are not allowed during coop.")
    end)
end)
