-- sh_ulx_csteams.lua — ULX wrappers for CS team system commands.
-- Bridges ULX's access control and logging into the COMMANDS-based cs_teams system.

local CATEGORY_NAME = "ZCity"

-- ── Player commands ───────────────────────────────────────────────────────────

function ulx.csinfo(calling_ply)
    if SERVER and IsValid(calling_ply) then
        COMMAND_Input(calling_ply, { "csinfo" })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csinfo", ulx.csinfo, "!csinfo")
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("List all CS team commands.")

function ulx.csteamlist(calling_ply)
    if SERVER and IsValid(calling_ply) then
        COMMAND_Input(calling_ply, { "csteamlist" })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csteamlist", ulx.csteamlist, "!csteamlist")
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("List all registered CS teams.")

function ulx.csteamstatus(calling_ply)
    if SERVER and IsValid(calling_ply) then
        COMMAND_Input(calling_ply, { "csteamstatus" })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csteamstatus", ulx.csteamstatus, "!csteamstatus")
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Show your current team and match status.")

function ulx.csmatchscore(calling_ply)
    if SERVER and IsValid(calling_ply) then
        COMMAND_Input(calling_ply, { "csmatchscore" })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csmatchscore", ulx.csmatchscore, "!csmatchscore")
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Show the current match score.")

function ulx.csteamleave(calling_ply)
    if SERVER and IsValid(calling_ply) then
        COMMAND_Input(calling_ply, { "csteamleave" })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csteamleave", ulx.csteamleave, "!csteamleave")
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Leave your current CS team.")

function ulx.csteamaccept(calling_ply)
    if SERVER and IsValid(calling_ply) then
        COMMAND_Input(calling_ply, { "csteamaccept" })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csteamaccept", ulx.csteamaccept, "!csteamaccept")
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Accept a pending team join request.")

function ulx.csteamdeny(calling_ply)
    if SERVER and IsValid(calling_ply) then
        COMMAND_Input(calling_ply, { "csteamdeny" })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csteamdeny", ulx.csteamdeny, "!csteamdeny")
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Deny a pending team join request.")

function ulx.csteamregister(calling_ply, name, size)
    if SERVER and IsValid(calling_ply) then
        local args = {}
        for part in string.gmatch(tostring(name or ""), "%S+") do
            table.insert(args, part)
        end
        table.insert(args, tostring(size or ""))
        COMMAND_Input(calling_ply, table.Add({ "csteamregister" }, args))
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csteamregister", ulx.csteamregister, "!csteamregister")
cmd:addParam{ type = ULib.cmds.StringArg, hint = "team name", ULib.cmds.takeRestOfLine }
cmd:addParam{ type = ULib.cmds.NumArg,    hint = "size (2 or 5)", min = 2, max = 5 }
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Register a new CS team.")

function ulx.csteamjoin(calling_ply, name)
    if SERVER and IsValid(calling_ply) then
        COMMAND_Input(calling_ply, { "csteamjoin", tostring(name or "") })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csteamjoin", ulx.csteamjoin, "!csteamjoin")
cmd:addParam{ type = ULib.cmds.StringArg, hint = "team name", ULib.cmds.takeRestOfLine }
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Request to join a CS team.")

-- ── Admin commands ────────────────────────────────────────────────────────────

function ulx.csmatch(calling_ply, team1, team2)
    if SERVER and IsValid(calling_ply) then
        ulx.logString(calling_ply:Nick() .. " started a CS match: " .. tostring(team1) .. " vs " .. tostring(team2))
        COMMAND_Input(calling_ply, { "csmatch", tostring(team1 or ""), tostring(team2 or "") })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csmatch", ulx.csmatch, "!csmatch")
cmd:addParam{ type = ULib.cmds.StringArg, hint = "team 1 name" }
cmd:addParam{ type = ULib.cmds.StringArg, hint = "team 2 name" }
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Start a match between two registered CS teams.")

function ulx.csendmatch(calling_ply)
    if SERVER and IsValid(calling_ply) then
        ulx.logString(calling_ply:Nick() .. " ended the CS match.")
        COMMAND_Input(calling_ply, { "csendmatch" })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csendmatch", ulx.csendmatch, "!csendmatch")
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("End the current CS match and record the result.")

function ulx.csteamdisband(calling_ply, name)
    if SERVER and IsValid(calling_ply) then
        ulx.logString(calling_ply:Nick() .. " disbanded CS team: " .. tostring(name))
        COMMAND_Input(calling_ply, { "csteamdisband", tostring(name or "") })
    end
end
local cmd = ulx.command(CATEGORY_NAME, "ulx csteamdisband", ulx.csteamdisband, "!csteamdisband")
cmd:addParam{ type = ULib.cmds.StringArg, hint = "team name", ULib.cmds.takeRestOfLine }
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Forcibly disband a CS team.")
