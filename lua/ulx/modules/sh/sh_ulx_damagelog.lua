-- sh_ulx_damagelog.lua — ULX commands for the damage log viewer.
-- Place in: lua/ulx/modules/sh/

if not SERVER then return end
if not ulx or not ULib then return end

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

-- HG_PlayerSay intercept so ZChat doesn't swallow the commands before ULX sees them.
local lastDLogChat = {}
hook.Add("HG_PlayerSay", "ZC_DamageLog_ChatCommand", function(ply, txtTbl, text)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local raw = string.Trim(tostring(text or ""))
    local lower = string.lower(raw)

    -- !damagelog / /damagelog
    if lower == "!damagelog" or lower == "/damagelog" then
        if istable(txtTbl) then txtTbl[1] = "" end
        if not ULib.ucl or not ULib.ucl.query or not ULib.ucl.query(ply, "ulx damagelog") then return "" end
        local key = ply:SteamID64() .. ":dl"
        local now = CurTime()
        if (lastDLogChat[key] or 0) > now then return "" end
        lastDLogChat[key] = now + 1.0
        ulxDamageLog(ply)
        return ""
    end

    -- !dlog / /dlog <keyword> [date]
    local dlogRest = string.match(raw, "^[!/][Dd][Ll][Oo][Gg]%s+(.+)$")
    if dlogRest then
        if istable(txtTbl) then txtTbl[1] = "" end
        if not ULib.ucl or not ULib.ucl.query or not ULib.ucl.query(ply, "ulx dlog") then return "" end
        local key = ply:SteamID64() .. ":dlog"
        local now = CurTime()
        if (lastDLogChat[key] or 0) > now then return "" end
        lastDLogChat[key] = now + 1.0
        -- Split optional trailing YYYY-MM-DD date from the keyword
        local keyword, date = string.match(dlogRest, "^(.-)%s+(%d%d%d%d%-%d%d%-%d%d)$")
        if not keyword then keyword = dlogRest; date = "" end
        ulxDLog(ply, keyword, date)
        return ""
    end
end)
