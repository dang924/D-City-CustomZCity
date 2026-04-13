-- John Wick vs Everyone — ULX Module
-- Place in: lua/ulx/modules/sh/sh_ulx_jwick.lua
-- Commands: ulx jwick, ulx jwickset, ulx jwickend

if not ulx then return end

local CATEGORY_NAME = "John Wick Event"

-- ── ulx jwick — random assignment ────────────────────────────────────────────

local function ulxJwick(calling_ply)
    if not CurrentRound or CurrentRound().name ~= "event" then
        ULib.tsay(calling_ply, "[J.WICK] This command can only be used during the event gamemode.")
        return
    end
        local alive = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then table.insert(alive, ply) end
    end

    if #alive < 2 then
        ULib.tsay(calling_ply, "[J.WICK] Need at least 2 alive players.")
        return
    end

    -- Shuffle and pick John and VIP
    for i = #alive, 2, -1 do
        local j = math.random(i)
        alive[i], alive[j] = alive[j], alive[i]
    end

    local johnPly = alive[1]
    local vipPly  = alive[2]

    -- Trigger server assignment via the same logic as the chat command
    -- We call AssignRoles indirectly by faking the HG_PlayerSay hook result
    -- or directly since this is the ULX module (server-only block)
    if SERVER then
        AssignRoles(johnPly, vipPly)
        ulx.fancyLogAdmin(calling_ply, "#A started John Wick event — John: " ..
            johnPly:Nick() .. ", VIP: " .. vipPly:Nick())
    end
end

local cmdJwick = ulx.command(CATEGORY_NAME, "ulx jwick", ulxJwick, "!jwick")
cmdJwick:defaultAccess(ULib.ACCESS_ADMIN)
cmdJwick:help("Start John Wick event with random John and VIP selection.")

-- ── ulx jwickset — manual assignment ─────────────────────────────────────────

local function ulxJwickSet(calling_ply, john_ply, vip_ply)
    if not CurrentRound or CurrentRound().name ~= "event" then
        ULib.tsay(calling_ply, "[J.WICK] This command can only be used during the event gamemode.")
        return
    end
        if not IsValid(john_ply) or not IsValid(vip_ply) then
        ULib.tsay(calling_ply, "[J.WICK] Invalid player selection.")
        return
    end
    if john_ply == vip_ply then
        ULib.tsay(calling_ply, "[J.WICK] John and VIP must be different players.")
        return
    end
    if not john_ply:Alive() or not vip_ply:Alive() then
        ULib.tsay(calling_ply, "[J.WICK] Both players must be alive.")
        return
    end

    if SERVER then
        AssignRoles(john_ply, vip_ply)
        ulx.fancyLogAdmin(calling_ply, "#A set John Wick event — John: " ..
            john_ply:Nick() .. ", VIP: " .. vip_ply:Nick())
    end
end

local cmdJwickSet = ulx.command(CATEGORY_NAME, "ulx jwickset", ulxJwickSet, "!jwickset")
cmdJwickSet:addParam{ type = ULib.cmds.PlayerArg, hint = "John Wick player" }
cmdJwickSet:addParam{ type = ULib.cmds.PlayerArg, hint = "VIP player" }
cmdJwickSet:defaultAccess(ULib.ACCESS_ADMIN)
cmdJwickSet:help("Manually assign John Wick and VIP roles.")

-- ── ulx jwickend — end event ──────────────────────────────────────────────────

local function ulxJwickEnd(calling_ply)
    if SERVER then
        if not CurrentRound or CurrentRound().name ~= "event" then
            ULib.tsay(calling_ply, "[J.WICK] This command can only be used during the event gamemode.")
            return
        end
        if not JWick or not JWick.Active then
            ULib.tsay(calling_ply, "[J.WICK] No event is currently active.")
            return
        end
        JWick.Active = false
        JWick.John   = nil
        JWick.VIP    = nil
        for _, ply in ipairs(player.GetAll()) do
            ply.JWickRole = nil
        end
        net.Start("JWick_End") net.WriteString("manual") net.Broadcast()
        PrintMessage(HUD_PRINTTALK, "[J.WICK] Event ended by " .. calling_ply:Nick())
        ulx.fancyLogAdmin(calling_ply, "#A ended the John Wick event.")
    end
end

local cmdJwickEnd = ulx.command(CATEGORY_NAME, "ulx jwickend", ulxJwickEnd, "!jwickend")
cmdJwickEnd:defaultAccess(ULib.ACCESS_ADMIN)
cmdJwickEnd:help("End the John Wick event.")
