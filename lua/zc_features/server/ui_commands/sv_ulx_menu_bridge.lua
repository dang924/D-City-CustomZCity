if CLIENT then return end

if _G.ZC_ULXMenuBridgeInstalled then return end
_G.ZC_ULXMenuBridgeInstalled = true

local function hasMenuAccess(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    if ULib and ULib.ucl and ULib.ucl.query then
        return ULib.ucl.query(ply, "ulx menu")
    end

    return ply:IsAdmin()
end

local function openUlxMenuFromChat(ply, txtTbl)
    if not hasMenuAccess(ply) then
        if istable(txtTbl) then txtTbl[1] = "" end
        return true
    end

    if istable(txtTbl) then txtTbl[1] = "" end
    ply:ConCommand("ulx menu")
    return true
end

if ZC_RegisterExactChatCommand then
    ZC_RegisterExactChatCommand("!menu", openUlxMenuFromChat)
    ZC_RegisterExactChatCommand("/menu", openUlxMenuFromChat)
else
    hook.Add("HG_PlayerSay", "ZC_ULXMenuBridge", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text or ""))
        if cmd ~= "!menu" and cmd ~= "/menu" then return end
        return openUlxMenuFromChat(ply, txtTbl)
    end)
end
