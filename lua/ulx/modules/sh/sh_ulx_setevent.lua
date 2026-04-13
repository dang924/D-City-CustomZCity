-- Place this file in: lua/ulx/modules/sh/sh_ulx_setevent.lua
-- ULX loads all files in lua/ulx/modules/sh/ automatically after initialising.

local CATEGORY_NAME = "ZCity"

function ulx.setevent(calling_ply)
    if zb then
        -- Lock the entire round queue to event only
        zb.nextround = "event"
        zb.RoundList = {}
        for i = 1, 20 do
            zb.RoundList[i] = "event"
        end
        -- Persist via convar so map changes stay locked
        if GetConVar("zb_forcemode") then
            RunConsoleCommand("zb_forcemode", "event")
        end
    end

    NextRound("event")

    if zb and zb.EndRound then
        zb:EndRound()
    end

    local msg = "Gamemode set to EVENT"
    if IsValid(calling_ply) then
        msg = msg .. " by " .. calling_ply:Nick()
    end

    ULib.tsay(_, msg)
    ulx.logString(msg)
    Msg(msg .. "\n")
end

local setevent = ulx.command(CATEGORY_NAME, "ulx setevent", ulx.setevent, "!setevent")
setevent:defaultAccess(ULib.ACCESS_ADMIN)
setevent:help("Forces event mode and locks the round queue to event only.")
