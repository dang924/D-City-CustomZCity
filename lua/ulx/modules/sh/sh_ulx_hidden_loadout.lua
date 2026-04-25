local CATEGORY_NAME = "Hidden"

if not ulx then return end

local function getHiddenRoundState()
    local round = CurrentRound and CurrentRound()
    if not round or round.name ~= "hidden" then
        return nil, "This command only works during the Hidden round."
    end

    return round, nil
end

local function isHiddenPrepActive(round)
    if not round then return false end
    if round.HiddenPrepActive ~= nil then
        return round.HiddenPrepActive and true or false
    end

    return round.IsHiddenPreparationPhase and round:IsHiddenPreparationPhase() or false
end

local function openHiddenLoadoutFor(calling_ply, target_ply)
    local round, err = getHiddenRoundState()
    if not round then
        if IsValid(calling_ply) then
            ULib.tsay(calling_ply, err)
        else
            Msg("[Hidden] " .. err .. "\n")
        end
        return
    end

    local target = target_ply or calling_ply
    if not IsValid(target) then return end

    if target ~= calling_ply and not IsValid(calling_ply) then
        Msg("[Hidden] Console must specify a valid player target.\n")
        return
    end

    if IsValid(calling_ply) and target ~= calling_ply and not calling_ply:IsAdmin() then
        ULib.tsay(calling_ply, "You can only open the Hidden loadout menu for yourself.")
        return
    end

    if target:Team() ~= 1 then
        if IsValid(calling_ply) then
            ULib.tsay(calling_ply, target:Nick() .. " is not on IRIS.")
        end
        return
    end

    if not isHiddenPrepActive(round) then
        if IsValid(calling_ply) then
            ULib.tsay(calling_ply, "The Hidden loadout editor is only available during prep.")
        end
        return
    end

    if not round.SendHiddenLoadoutData then
        if IsValid(calling_ply) then
            ULib.tsay(calling_ply, "Hidden loadout UI is not loaded on the server yet.")
        end
        return
    end

    round:SendHiddenLoadoutData(target, true)

    if IsValid(calling_ply) and target ~= calling_ply then
        ulx.logString(calling_ply:Nick() .. " opened Hidden loadout for " .. target:Nick())
    elseif IsValid(calling_ply) then
        ulx.logString(calling_ply:Nick() .. " opened Hidden loadout")
    end
end

hook.Add("HG_PlayerSay", "ZC_HiddenLoadout_ChatCommand", function(ply, txtTbl, text)
    local cmd = string.lower(string.Trim(text or ""))
    if cmd ~= "!hiddenloadout" and cmd ~= "/hiddenloadout" then return end

    txtTbl[1] = ""

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        openHiddenLoadoutFor(ply, ply)
    end)

    return ""
end)

local cmd = ulx.command(CATEGORY_NAME, "ulx hiddenloadout", openHiddenLoadoutFor, "!hiddenloadout")
cmd:addParam{
    type = ULib.cmds.PlayerArg,
    ULib.cmds.optional,
    ULib.cmds.allowSelf,
}
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Open the Hidden loadout editor during Hidden prep. Admins can target another IRIS player.")