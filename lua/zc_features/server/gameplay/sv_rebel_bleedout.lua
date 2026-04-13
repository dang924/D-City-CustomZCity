-- Kills a downed Rebel player if they remain incapacitated for too long.
-- Uses ZCity's HG_OnOtrub / HG_OnWakeOtrub hooks and org.uncon_timer.

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    local BLEEDOUT_TIME = 15  -- seconds before a downed player dies

    -- Only Gordon stays down indefinitely — all other classes bleed out
    local EXEMPT_CLASSES = {
        ["Gordon"] = true,
    }

    local function IsHeadcrabbed(ply)
        -- org.headcrabon is set by AddHeadcrab() and cleared on transformation/death
        return ply.organism and ply.organism.headcrabon ~= nil
    end

    local function GetTimerName(ply)
        return "ZC_BleedOut_" .. ply:SteamID64()
    end

    hook.Add("HG_OnOtrub", "ZCity_RebelBleedOut", function(ply)
        if not IsValid(ply) then return end
        if EXEMPT_CLASSES[ply.PlayerClassName] then return end

        local timerName = GetTimerName(ply)
        timer.Remove(timerName)

        timer.Create(timerName, BLEEDOUT_TIME, 1, function()
            if not IsValid(ply) then return end
            if not ply:Alive() then return end
            if not ply.organism or not ply.organism.otrub then return end

            -- Don't kill headcrabbed players — let the infection run its course
            if IsHeadcrabbed(ply) then
                return
            end

            ply:Kill()
        end)
    end)

    -- Cancel the timer if a teammate revives them in time
    hook.Add("HG_OnWakeOtrub", "ZCity_RebelBleedOut", function(ply)
        if not IsValid(ply) then return end
        local timerName = GetTimerName(ply)
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end)

    -- Clean up if they die by other means while down
    hook.Add("PlayerDeath", "ZCity_RebelBleedOut", function(ply)
        timer.Remove(GetTimerName(ply))
    end)

    -- Clean up on disconnect
    hook.Add("PlayerDisconnected", "ZCity_RebelBleedOut", function(ply)
        timer.Remove(GetTimerName(ply))
    end)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svrebelbleedout", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)
hook.Add("Think", "ZC_CoopInit_svrebelbleedout_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svrebelbleedout_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)

