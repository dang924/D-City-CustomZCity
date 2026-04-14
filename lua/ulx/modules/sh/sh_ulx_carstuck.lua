if not ulx then return end
if CLIENT then return end

local CATEGORY_NAME = "ZCity"

local function ulxCarStuck(calling_ply)
    if not IsValid(calling_ply) or not calling_ply:Alive() then return end

    -- Find Gordon (alive player with this class, not the caller)
    local gordon = nil
    if calling_ply.PlayerClassName ~= "Gordon" then
        for _, p in player.Iterator() do
            if IsValid(p) and p:Alive() and p.PlayerClassName == "Gordon" and p ~= calling_ply then
                gordon = p
                break
            end
        end
    end

    if IsValid(gordon) then
        calling_ply:SetPos(gordon:GetPos())
        ULib.tsay(calling_ply, "[carstuck] Teleported to Gordon.")
    else
        local tr = util.TraceLine({
            start  = calling_ply:EyePos(),
            endpos = calling_ply:EyePos() + calling_ply:GetAimVector() * 4096,
            filter = calling_ply,
            mask   = MASK_PLAYERSOLID_BRUSHONLY,
        })
        local dest = tr.HitPos
        if tr.Hit then dest = dest + tr.HitNormal * 2 end
        calling_ply:SetPos(dest)
        ULib.tsay(calling_ply, "[carstuck] Teleported to crosshair.")
    end
end

local cmd = ulx.command(CATEGORY_NAME, "ulx carstuck", ulxCarStuck, "!carstuck")
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Teleport to Gordon (or your crosshair if Gordon isn't alive/you are Gordon).")
