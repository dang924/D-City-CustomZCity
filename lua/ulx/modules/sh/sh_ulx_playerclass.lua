-- sh_ulx_playerclass.lua — !playerclass command for superadmins.
-- Switches any player to any registered ZCity playerclass dynamically.
-- No hardcoded list — reads directly from player.classList so all
-- custom classes are automatically supported.
-- Usage: !playerclass <player> <classname>
-- Place in: lua/ulx/modules/sh/

local CATEGORY_NAME = "ZCity"

local function ulxPlayerClass(calling_ply, target_ply, classname)
    if SERVER then
        local key = string.Trim(classname)

        -- Check against registered classes (case-insensitive)
        local matched = nil
        for name in pairs(player.classList or {}) do
            if string.lower(name) == string.lower(key) then
                matched = name
                break
            end
        end

        if not matched then
            -- Build available list from registered classes
            local available = {}
            for name in pairs(player.classList or {}) do
                table.insert(available, name)
            end
            table.sort(available)
            if IsValid(calling_ply) then
                calling_ply:ChatPrint("[PlayerClass] Unknown class '" .. key .. "'. Available: " .. table.concat(available, ", "))
            end
            return
        end

        if not IsValid(target_ply) then return end

        target_ply:SetPlayerClass(matched)

        local msg = (IsValid(calling_ply) and calling_ply:Nick() or "Console")
            .. " set " .. target_ply:Nick() .. "'s class to " .. matched

        ULib.tsay(_, "[PlayerClass] " .. msg)
        ulx.logString(msg)
    end
end

local cmd = ulx.command(CATEGORY_NAME, "ulx playerclass", ulxPlayerClass, "!playerclass")
cmd:addParam{ type = ULib.cmds.PlayerArg }
cmd:addParam{ type = ULib.cmds.StringArg, hint = "classname" }
cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
cmd:help("Set a player's ZCity playerclass. Usage: !playerclass <player> <class>")
