-- sh_ulx_damagelog.lua — ULX commands for the damage log viewer.
-- Place in: lua/ulx/modules/sh/

local CATEGORY_NAME = "ZCity"

-- !damagelog — opens the full viewer panel (admin+)
local function ulxDamageLog(calling_ply)
    if SERVER then
        if not IsValid(calling_ply) then
            Msg("[DamageLog] Console cannot open the panel — use zc_damagelog instead.\n")
            return
        end
        if not calling_ply:IsAdmin() then
            calling_ply:ChatPrint("[DamageLog] Admin only.")
            return
        end
        net.Start("ZC_DamageLog_Open")
        net.Send(calling_ply)
        ulx.logString(calling_ply:Nick() .. " opened the damage log viewer.")
    end
end

local cmdLog = ulx.command(CATEGORY_NAME, "ulx damagelog", ulxDamageLog, "!damagelog")
cmdLog:defaultAccess(ULib.ACCESS_ADMIN)
cmdLog:help("Opens the damage log viewer panel showing the last 30 minutes of damage.")

-- !dlog <name/steamid> [date] — quick console-style search, prints to chat (superadmin+)
local function ulxDLog(calling_ply, keyword, date)
    if SERVER then
        if not IsValid(calling_ply) then
            Msg("[DamageLog] Use zc_damagelog from console instead.\n")
            return
        end
        if not calling_ply:IsSuperAdmin() then
            calling_ply:ChatPrint("[DamageLog] Superadmin only.")
            return
        end
        -- Proxy to the concommand handler
        RunConsoleCommand("zc_damagelog", keyword, date or "")
        ulx.logString(calling_ply:Nick() .. " searched damage logs for: " .. keyword)
    end
end

local cmdDLog = ulx.command(CATEGORY_NAME, "ulx dlog", ulxDLog, "!dlog")
cmdDLog:addParam{ type = ULib.cmds.StringArg, hint = "name or steamid fragment" }
cmdDLog:addParam{ type = ULib.cmds.StringArg, hint = "date YYYY-MM-DD (optional)", optional = true, default = "" }
cmdDLog:defaultAccess(ULib.ACCESS_SUPERADMIN)
cmdDLog:help("Search damage logs by name or SteamID. Usage: !dlog <name> [YYYY-MM-DD]")
