-- sh_ulx_setdod.lua — ULX command to activate Day of Defeat event-based gamemode.
-- DoD is loaded as an event system in autorun (not as a registered mode).

if not ulx then return end

local CATEGORY_NAME = "ZCity"

function ulx.setdod(calling_ply)
    if not (NextRound and zb) then
        local msg = "[DoD] System not ready — try again in a moment."
        if IsValid(calling_ply) then calling_ply:ChatPrint(msg) end
        return
    end

    -- Ensure DoD mode is actually registered before touching round state.
    if DOD_RegisterMode then
        DOD_RegisterMode()
    end
    if not (zb.modes and zb.modes["dod"]) then
        local msg = "[DoD] Mode is not registered yet. Wait 2-3 seconds and try !setdod again."
        if IsValid(calling_ply) then calling_ply:ChatPrint(msg) end
        return
    end

    -- Call the global NextRound function to switch to DoD
    NextRound("dod")

    if DOD_ApplyBlackScreenAll then
        DOD_ApplyBlackScreenAll(10)
    end

    -- If a round is currently live, end it now so DoD starts immediately.
    if zb.ROUND_STATE == 1 and zb.EndRound then
        zb:EndRound()
    end

    local msg = "🚩 GAMEMODE SET TO: DAY OF DEFEAT"
    if IsValid(calling_ply) then
        msg = msg .. " (by " .. calling_ply:Nick() .. ")"
    end

    ULib.tsay(_, msg)
    if IsValid(calling_ply) then
        ulx.fancyLogAdmin(calling_ply, "#A activated Day of Defeat gamemode")
    else
        Msg("[DoD] Auto activation requested by server (dod_* map)\n")
    end
    Msg("[DoD] " .. msg .. "\n")
end

local setdod = ulx.command(CATEGORY_NAME, "ulx setdod", ulx.setdod, "!setdod")
setdod:defaultAccess(ULib.ACCESS_ADMIN)
setdod:help("Activate Day of Defeat event-based gamemode for the next round.")

if SERVER then
    hook.Add("InitPostEntity", "DOD_AutoSetDoDOnMapPrefix", function()
        local mapName = string.lower(game.GetMap() or "")
        if not string.StartWith(mapName, "dod_") then return end

        timer.Create("DOD_AutoSetDoDRetry", 2, 8, function()
            if not (NextRound and zb) then return end
            if zb and zb.CROUND == "dod" then
                timer.Remove("DOD_AutoSetDoDRetry")
                return
            end

            ulx.setdod(nil)

            timer.Simple(0.25, function()
                if zb and zb.CROUND == "dod" then
                    timer.Remove("DOD_AutoSetDoDRetry")
                end
            end)
        end)
    end)
end
