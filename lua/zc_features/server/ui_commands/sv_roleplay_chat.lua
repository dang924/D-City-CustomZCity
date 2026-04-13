if CLIENT then return end

local RP_RADIUS = 700

util.AddNetworkString("DCityPatch_RPChatLine")

local function splitCommand(raw)
    local trimmed = string.Trim(raw or "")
    local lower = string.lower(trimmed)

    if string.sub(lower, 1, 4) == "/me " then
        return "me", string.Trim(string.sub(trimmed, 5))
    end

    if lower == "/me" then
        return "me", ""
    end

    if string.sub(lower, 1, 4) == "/it " then
        return "it", string.Trim(string.sub(trimmed, 5))
    end

    if lower == "/it" then
        return "it", ""
    end

    return nil, nil
end

local function broadcastLocalRoleplay(source, message)
    if not IsValid(source) then return end

    local radiusSqr = RP_RADIUS * RP_RADIUS
    local sourcePos = source:GetPos()
    local pcol = source.GetPlayerColor and source:GetPlayerColor() or Vector(1, 1, 1)
    local r = math.Clamp(math.floor((pcol.x or 1) * 255), 0, 255)
    local g = math.Clamp(math.floor((pcol.y or 1) * 255), 0, 255)
    local b = math.Clamp(math.floor((pcol.z or 1) * 255), 0, 255)

    for _, ply in ipairs(player.GetHumans()) do
        if not IsValid(ply) then continue end
        if ply:GetPos():DistToSqr(sourcePos) > radiusSqr then continue end

        net.Start("DCityPatch_RPChatLine")
            net.WriteUInt(r, 8)
            net.WriteUInt(g, 8)
            net.WriteUInt(b, 8)
            net.WriteString(message)
        net.Send(ply)
    end
end

local function getInGameName(ply)
    if not IsValid(ply) then return "Unknown" end

    if ply.GetPlayerName then
        local n = tostring(ply:GetPlayerName() or "")
        if n ~= "" then return n end
    end

    local nw = tostring(ply:GetNWString("PlayerName", "") or "")
    if nw ~= "" then return nw end

    return ply:Nick()
end

hook.Add("HG_PlayerSay", "DCityPatch_RoleplayChat", function(ply, txtTbl, text)
    local cmd, body = splitCommand(text)
    if not cmd then return end

    txtTbl[1] = ""

    if body == "" then
        if cmd == "me" then
            ply:ChatPrint("[RP] Usage: /me <action>")
        else
            ply:ChatPrint("[RP] Usage: /it <action>")
        end
        return ""
    end

    if cmd == "it" and not ply:IsAdmin() then
        ply:ChatPrint("[RP] Staff only: /it")
        return ""
    end

    local line
    if cmd == "it" then
        line = body
    else
        line = getInGameName(ply) .. " " .. body
    end

    broadcastLocalRoleplay(ply, line)

    return ""
end)
