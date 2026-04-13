if not SERVER then return end
if not ulx or not ULib then return end

local CATEGORY_NAME = "ZCity"
local HANDS_CLASS = "weapon_hands_sh"

local function GiveHandsToPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local wep = ply:GetWeapon(HANDS_CLASS)
    if not IsValid(wep) then
        wep = ply:Give(HANDS_CLASS)
    end

    if not IsValid(wep) then
        return false
    end

    ply:SelectWeapon(HANDS_CLASS)
    return true
end

local function ulxHandsAll(calling_ply)
    local count = 0

    for _, ply in ipairs(player.GetAll()) do
        if GiveHandsToPlayer(ply) then
            count = count + 1
        end
    end

    if ulx.fancyLogAdmin and IsValid(calling_ply) then
        ulx.fancyLogAdmin(calling_ply, "#A gave " .. HANDS_CLASS .. " to " .. tostring(count) .. " player(s)")
    else
        local actor = IsValid(calling_ply) and calling_ply:Nick() or "Console"
        local msg = actor .. " gave " .. HANDS_CLASS .. " to " .. tostring(count) .. " player(s)"
        ulx.logString(msg)
        print(msg)
    end
end

local cmd = ulx.command(CATEGORY_NAME, "ulx handsall", ulxHandsAll, "!handsall")
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Give all players the hands weapon and select it.")
