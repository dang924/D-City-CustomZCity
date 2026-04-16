-- sv_carstuck_cmd.lua
--
-- !carstuck  — anyone can use.
-- * If you ARE Gordon: teleport to your crosshair.
-- * If you are NOT Gordon and Gordon is alive: teleport to Gordon.
-- * Otherwise (no Gordon alive): teleport to your crosshair.
--
-- Hooks PlayerSay at HOOK_HIGH so it fires before ULX's own !cmd handler.
-- Returns "" to suppress the message from chat and prevent ULX's
-- "Invalid command" error.

if CLIENT then return end

local CMD = "!carstuck"

local function DoCarStuck(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- Find Gordon (alive, different player)
    local gordon = nil
    if ply.PlayerClassName ~= "Gordon" then
        for _, p in player.Iterator() do
            if IsValid(p) and p:Alive() and p.PlayerClassName == "Gordon" and p ~= ply then
                gordon = p
                break
            end
        end
    end

    if IsValid(gordon) then
        ply:SetPos(gordon:GetPos())
        ply:ChatPrint("[carstuck] Teleported to Gordon.")
    else
        local tr = util.TraceLine({
            start  = ply:EyePos(),
            endpos = ply:EyePos() + ply:GetAimVector() * 4096,
            filter = ply,
            mask   = MASK_PLAYERSOLID_BRUSHONLY,
        })
        local dest = tr.HitPos
        if tr.Hit then dest = dest + tr.HitNormal * 2 end
        ply:SetPos(dest)
        ply:ChatPrint("[carstuck] Teleported to crosshair.")
    end
end

hook.Add("PlayerSay", "DCityPatch_CarStuck", function(ply, text)
    if string.lower(string.Trim(text)) ~= CMD then return end
    DoCarStuck(ply)
    return ""  -- suppress chat message and block ULX from seeing it
end, HOOK_HIGH)
