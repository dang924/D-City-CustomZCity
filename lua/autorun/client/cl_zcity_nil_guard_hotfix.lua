-- cl_zcity_nil_guard_hotfix.lua
-- Addon-side replacement for base "fakestatus" hook with nil-safe round checks.

if SERVER then return end

local keys = {
    [KEY_S] = "s",
    [KEY_T] = "t",
    [KEY_A] = "a",
    [KEY_U] = "u",
    [KEY_ENTER] = "\n",
    [KEY_SPACE] = " ",
    [KEY_SEMICOLON] = ";",
}

local status = {
    [KEY_S] = false,
    [KEY_T] = false,
    [KEY_A] = false,
    [KEY_U] = false,
    [KEY_ENTER] = false,
    [KEY_SPACE] = false,
    [KEY_SEMICOLON] = false,
    [KEY_BACKSPACE] = false,
}

local strstatus = ""

local function SafeCurrentRoundName()
    if not CurrentRound then return nil end
    local ok, rnd = pcall(CurrentRound)
    if not ok or not rnd then return nil end
    return rnd.name
end

-- Same hook id as base file; this safely overrides it.
hook.Add("Move", "fakestatus", function(ply, mv)
    if SafeCurrentRoundName() ~= "fear" then return end
    if not zb or not zb.CheckAlive then return end

    local alive = zb:CheckAlive()
    if (#alive ~= 1) or (alive[1] ~= ply) then return end

    for v, val in pairs(status) do
        if input.IsKeyDown(v) then
            if not val then
                status[v] = true
                if v == KEY_BACKSPACE then
                    strstatus = string.sub(strstatus, 1, string.len(strstatus) - 1)
                else
                    strstatus = strstatus .. keys[v]
                end
            end
        elseif val then
            status[v] = false
        end
    end

    local st = string.find(strstatus, "status")
    local st2 = string.find(strstatus, "\n")
    if st2 then
        strstatus = ""
    end

    if st and st2 and st2 > st then
        timer.Simple(0, function()
            local lply = LocalPlayer()
            if not IsValid(lply) then return end

            local bignum = math.pow(2, 20)
            for i = 1, 20 do
                print(("\n"):rep(bignum))
            end

            MsgC(color_white, string.format([[ 
hostname: %s
version : 2025.03.26/24 9748 secure
udp/ip  : %s:27015  (public ip: %s)
steamid : [A-1:%s(63621)] (%s)
map     : %s at: 0 x, 0 y, 0 z
uptime  : %s, %s server
players : 1 humans, 0 bots (20 max)
# userid name                uniqueid            connected ping loss state
#      2 "%s"           %s   %s    %s    0 active
]], GetHostName(), game.GetIPAddress(), game.GetIPAddress(), lply:AccountID(), lply:SteamID64(), game.GetMap(), string.FormattedTime(CurTime(), "%02i h %02i m"), string.FormattedTime(CurTime(), "%02i h %02i m"), lply:Name(), lply:SteamID(), string.FormattedTime(CurTime(), "%02i:%02i:%02i"), lply:Ping()))
        end)
    end
end)

print("[DCityPatch] Client nil-guard hotfix loaded (fakestatus hook).")
