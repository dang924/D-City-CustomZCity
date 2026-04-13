-- sh_alyx_debug_tools.lua
-- DCityPatch1.1
-- Reliable Alyx debug commands registered in shared autorun.

local CMD_DRAW = "zc_alyx_debug"
local CMD_FIRE = "zc_alyx_fire_debug"
local LEGACY_CMD_DRAW = "alyx_debug"
local LEGACY_CMD_FIRE = "alyx_fire_debug"

if SERVER then
    util.AddNetworkString("ZC_AlyxFireDebug_Toggle")
    util.AddNetworkString("ZC_AlyxFireDebug_Request")

    local fireDebugEnabled = false

    local function IsAllowed(ply)
        return not IsValid(ply) or ply:IsSuperAdmin()
    end

    local function SetFireDebug(enabled, byWho)
        fireDebugEnabled = enabled and true or false
        print(string.format("[AlyxFireDebug] %s by %s", fireDebugEnabled and "ENABLED" or "DISABLED", tostring(byWho or "console")))
    end

    concommand.Add(CMD_FIRE, function(ply, cmd, args)
        if not IsAllowed(ply) then return end

        local arg = tonumber(args[1] or "")
        if arg == 0 then
            SetFireDebug(false, IsValid(ply) and ply:Nick() or "console")
        elseif arg == 1 then
            SetFireDebug(true, IsValid(ply) and ply:Nick() or "console")
        else
            SetFireDebug(not fireDebugEnabled, IsValid(ply) and ply:Nick() or "console")
        end
    end)

    concommand.Add(LEGACY_CMD_FIRE, function(ply, cmd, args)
        if not IsAllowed(ply) then return end
        local arg = tonumber(args[1] or "")
        if arg == 0 then
            SetFireDebug(false, IsValid(ply) and ply:Nick() or "console")
        elseif arg == 1 then
            SetFireDebug(true, IsValid(ply) and ply:Nick() or "console")
        else
            SetFireDebug(not fireDebugEnabled, IsValid(ply) and ply:Nick() or "console")
        end
    end)

    net.Receive("ZC_AlyxFireDebug_Request", function(_, ply)
        if not IsAllowed(ply) then return end
        SetFireDebug(not fireDebugEnabled, IsValid(ply) and ply:Nick() or "console")
    end)

    -- Register draw command on server too so it is never "Unknown command".
    -- If a player runs it, server instructs only that player to toggle draw.
    concommand.Add(CMD_DRAW, function(ply, cmd, args)
        if not IsValid(ply) then
            print("[AlyxDebug] zc_alyx_debug is client-side. Run it in a player console.")
            return
        end
        net.Start("ZC_AlyxFireDebug_Toggle")
        net.Send(ply)
    end)

    concommand.Add(LEGACY_CMD_DRAW, function(ply, cmd, args)
        if not IsValid(ply) then
            print("[AlyxDebug] alyx_debug is client-side. Run it in a player console.")
            return
        end
        net.Start("ZC_AlyxFireDebug_Toggle")
        net.Send(ply)
    end)

    timer.Create("ZC_AlyxFireDebug_Log", 0.35, 0, function()
        if not fireDebugEnabled then return end

        for _, alyx in ipairs(ents.FindByClass("npc_alyx")) do
            if not IsValid(alyx) then continue end

            local wep = alyx:GetActiveWeapon()
            local wepClass = IsValid(wep) and wep:GetClass() or "NONE"
            local enemy = alyx.GetEnemy and alyx:GetEnemy() or NULL
            local hasEnemy = IsValid(enemy)
            local enemyClass = hasEnemy and enemy:GetClass() or "NONE"
            local enemyAlive = hasEnemy and ((enemy.Alive and enemy:Alive()) or (enemy.Health and enemy:Health() > 0)) or false
            local state = alyx.GetNPCState and alyx:GetNPCState() or -1

            print(string.format("[AlyxFireDebug] wep=%s state=%s enemy=%s alive=%s", tostring(wepClass), tostring(state), tostring(enemyClass), tostring(enemyAlive)))
        end
    end)

    print("[AlyxDebug] Commands registered: zc_alyx_debug, zc_alyx_fire_debug")
    return
end

-- CLIENT
local drawEnabled = false

concommand.Add(CMD_DRAW, function()
    drawEnabled = not drawEnabled
    print("[AlyxDebug] " .. (drawEnabled and "ENABLED" or "DISABLED"))
end)

concommand.Add(LEGACY_CMD_DRAW, function()
    RunConsoleCommand(CMD_DRAW)
end)

-- Register fire command on client too so it is never "Unknown command".
-- It forwards to the server command.
concommand.Add(CMD_FIRE, function(_, _, args)
    net.Start("ZC_AlyxFireDebug_Request")
    net.SendToServer()
    print("[AlyxFireDebug] Requested server toggle")
end)

concommand.Add(LEGACY_CMD_FIRE, function(_, _, args)
    RunConsoleCommand(CMD_FIRE, tostring(args and args[1] or ""))
end)

net.Receive("ZC_AlyxFireDebug_Toggle", function()
    drawEnabled = not drawEnabled
    print("[AlyxDebug] " .. (drawEnabled and "ENABLED" or "DISABLED") .. " (server request)")
end)

hook.Add("Think", "ZC_AlyxDebug_Draw", function()
    if not drawEnabled then return end

    for _, alyx in ipairs(ents.FindByClass("npc_alyx")) do
        if not IsValid(alyx) then continue end

        local pos = alyx:GetPos()
        local eyePos = alyx:EyePos()
        local forward = alyx:EyeAngles():Forward()
        local enemy = alyx.GetEnemy and alyx:GetEnemy() or NULL

        debugoverlay.Box(pos, Vector(-8, -8, 0), Vector(8, 8, 64), 0.05, Color(0, 255, 0))
        debugoverlay.Line(eyePos, eyePos + forward * 240, 0.05, Color(255, 0, 0), true)

        if IsValid(enemy) then
            local enemyPos = enemy:LocalToWorld(enemy:OBBCenter())
            debugoverlay.Line(eyePos, enemyPos, 0.05, Color(0, 255, 255), true)
            debugoverlay.Sphere(enemyPos, 8, 0.05, Color(0, 255, 255))
        end

        local wep = alyx:GetActiveWeapon()
        local wepClass = IsValid(wep) and wep:GetClass() or "NONE"
        local enemyText = IsValid(enemy) and enemy:GetClass() or "NONE"
        debugoverlay.Text(pos + Vector(0, 0, 82), "Wep: " .. wepClass, 0.05)
        debugoverlay.Text(pos + Vector(0, 0, 94), "Enemy: " .. enemyText, 0.05)
    end
end)

print("[AlyxDebug] Commands registered: zc_alyx_debug, zc_alyx_fire_debug")
