-- Displays a HUD hint to newly connected dead players telling them how to join.
-- Disappears once the player is alive.

local showHint    = false
local hintEndTime = nil
local HINT_DURATION = 30  -- seconds before the hint fades out on its own

local function HideHint()
    showHint    = false
    hintEndTime = nil
end

hook.Add("InitPostEntity", "ZCity_CoopJoinSpawn", function()
    timer.Simple(3, function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        if ply:Alive() then return end
        showHint    = true
        hintEndTime = CurTime() + HINT_DURATION
    end)
end)

-- Also show hint after a regular respawn so all players see the !stuck tip
hook.Add("player_spawn", "ZCity_CoopStuckHint", function(data)
    if not LocalPlayer or not IsValid(LocalPlayer()) then return end
    if data.userid ~= LocalPlayer():UserID() then return end
    timer.Simple(1, function()
        if not IsValid(LocalPlayer()) then return end
        showHint    = true
        hintEndTime = CurTime() + HINT_DURATION
    end)
end)

hook.Add("HUDPaint", "ZCity_CoopJoinSpawnHint", function()
    if not showHint then return end

    local ply = LocalPlayer()
    if ply:Alive() then
        HideHint()
        return
    end

    if CurTime() > hintEndTime then
        HideHint()
        return
    end

    local sw, sh  = ScrW(), ScrH()
    local alpha   = math.Clamp((hintEndTime - CurTime()) * 2, 0, 1) * 220
    local bw, bh  = 340, 54
    local x       = sw / 2 - bw / 2
    local y       = sh * 0.65

    draw.RoundedBox(6, x, y, bw, bh, Color(30, 30, 30, alpha * 0.9))

    draw.SimpleText(
        "Type !join in chat to spawn",
        "HomigradFontMedium",
        sw / 2, y + bh / 2 - 6,
        Color(255, 255, 255, alpha),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
        "Use !stuck to teleport to Gordon if you spawn in a bad area",
        "HomigradFontSmall",
        sw / 2, y + bh / 2 + 10,
        Color(180, 180, 180, alpha * 0.8),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
end)

hook.Add("ShutDown", "ZCity_CoopJoinSpawn_Cleanup", HideHint)
