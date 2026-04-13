-- Place this file in: lua/ulx/modules/sh/sh_ulx_setcoop.lua
-- ULX loads all files in lua/ulx/modules/sh/ automatically after initialising.

local CATEGORY_NAME = "ZCity"

function ulx.setcoop(calling_ply)
    if zb then
        -- Lock the entire round queue to coop only
        zb.nextround = "coop"
        zb.RoundList = {}
        for i = 1, 20 do
            zb.RoundList[i] = "coop"
        end
        -- Persist via convar so map changes stay locked
        if GetConVar("zb_forcemode") then
            RunConsoleCommand("zb_forcemode", "coop")
        end
    end

    NextRound("coop")

    if zb and zb.EndRound then
        zb:EndRound()
    end

    local msg = "Gamemode set to COOP"
    if IsValid(calling_ply) then
        msg = msg .. " by " .. calling_ply:Nick()
    end

    ULib.tsay(_, msg)
    ulx.logString(msg)
    Msg(msg .. "\n")
end

local setcoop = ulx.command(CATEGORY_NAME, "ulx setcoop", ulx.setcoop, "!setcoop")
setcoop:defaultAccess(ULib.ACCESS_ADMIN)
setcoop:help("Forces coop mode and locks the round queue to coop only.")
