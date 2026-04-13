-- sh_ulx_notarget.lua - ULX !notarget command.
-- Toggles FL_NOTARGET and ZCity cloak on a player.
-- Usage: !notarget <player>
-- Place in: lua/ulx/modules/sh/

if not SERVER then return end
if not ulx or not ULib then return end

local CATEGORY_NAME = "ZCity"
local lastNotargetChat = {}

local function ulxNotTarget(calling_ply, target_ply)
    if not IsValid(target_ply) then return end

    local enabled = ZC_ToggleNotTarget(target_ply)
    local stateText = enabled and "ON" or "OFF"

    if ulx.fancyLogAdmin and IsValid(calling_ply) then
        ulx.fancyLogAdmin(calling_ply, "#A toggled notarget #s for #T", stateText, target_ply)
    else
        local actor = IsValid(calling_ply) and calling_ply:Nick() or "Console"
        local msg = actor .. " toggled NotTarget " .. stateText .. " for " .. target_ply:Nick()
        ulx.logString(msg)
        print(msg)
    end
end

local cmd = ulx.command(CATEGORY_NAME, "ulx notarget", ulxNotTarget, "!notarget")
cmd:addParam{ type = ULib.cmds.PlayerArg }
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Toggles NPC invisibility (FL_NOTARGET + cloak) on a player.")

-- ZChat can swallow PlayerSay before ULX sees it. Intercept here once and consume.
hook.Add("HG_PlayerSay", "ZC_NotTarget_ChatCommand", function(ply, txtTbl, text)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local raw = string.Trim(tostring(text or ""))
    local cmdLower, arg = string.match(string.lower(raw), "^([!/][%w_]+)%s*(.*)$")
    if cmdLower ~= "!notarget" and cmdLower ~= "/notarget" then return end

    if istable(txtTbl) then txtTbl[1] = "" end

    if not ULib.ucl or not ULib.ucl.query or not ULib.ucl.query(ply, "ulx notarget") then
        return ""
    end

    local needle = string.Trim(tostring(arg or ""))
    if needle == "" then
        ply:ChatPrint("[NotTarget] Usage: !notarget <player>")
        return ""
    end

    local target
    local lname = string.lower(needle)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), lname, 1, true) then
            target = p
            break
        end
    end

    if not IsValid(target) then
        ply:ChatPrint("[NotTarget] Target not found: " .. needle)
        return ""
    end

    local key = ply:SteamID64() .. ":" .. target:SteamID64()
    local now = CurTime()
    if (lastNotargetChat[key] or 0) > now then
        return ""
    end

    lastNotargetChat[key] = now + 0.25
    ulxNotTarget(ply, target)
    return ""
end)
