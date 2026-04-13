-- sh_ulx_nobots.lua — ULX toggle for bot kicking during coop.
-- Place in: lua/ulx/modules/sh/

local CATEGORY_NAME = "ZCity"

local function ulxNoBots(calling_ply, enabled)
    enabled = tonumber(enabled) == 1
    ZC_NoBots = enabled

    local state = enabled and "ENABLED" or "DISABLED"
    local msg   = "No-bots " .. state

    if IsValid(calling_ply) then
        msg = msg .. " by " .. calling_ply:Nick()
    end

    -- Kick any bots currently in the server if enabling during coop
    if enabled and CurrentRound and CurrentRound().name == "coop" then
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsBot() then
                ply:Kick("Bots are not allowed during coop.")
            end
        end
    end

    ULib.tsay(nil, msg)
    ulx.logString(msg)
    Msg(msg .. "\n")
end

local cmd = ulx.command(CATEGORY_NAME, "ulx nobots", ulxNoBots, "!nobots")
cmd:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "1 = kick bots, 0 = allow bots" }
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Toggles whether bots are kicked during coop. 1 = kick bots, 0 = allow bots.")
