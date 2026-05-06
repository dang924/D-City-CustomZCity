if SERVER then return end

local gradient_d = Material("vgui/gradient-d")
local SpectateHideNick = false
local keyOld = false

net.Receive("ZCity_Spectator_Health_Sync", function()
    local count = net.ReadUInt(8)
    for i = 1, count do
        local ply = net.ReadEntity()
        local health = net.ReadFloat()
        if IsValid(ply) then
            ply.ZCitySpectatorHealth = health
        end
    end
end)

hook.Add("HUDPaint", "ZCity_Spectate_ALT_ESP", function()
    local lply = LocalPlayer()
    
    if lply:Alive() and lply:GetObserverMode() == OBS_MODE_NONE then return end

    local key = input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
    if keyOld ~= key and key then 
        SpectateHideNick = not SpectateHideNick 
    end 
    keyOld = key 

    draw.SimpleText("Disable / Enable display of nicknames on ALT", "Trebuchet18", 15, ScrH() - 15, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

    if not SpectateHideNick then 
        for _, v in ipairs(player.GetAll()) do
            if not v:Alive() or v == lply then continue end 

            local ent = IsValid(v:GetNWEntity("Ragdoll")) and v:GetNWEntity("Ragdoll") or v 
            local screenPosition = ent:GetPos():ToScreen() 
            local x, y = screenPosition.x, screenPosition.y 
            local teamColor = v:GetPlayerColor():ToColor() 
            local distance = lply:GetPos():Distance(v:GetPos()) 
            local factor = 1 - math.Clamp(distance / 1024, 0, 1) 
            local size = math.max(10, 32 * factor) 
            local alpha = math.max(255 * factor, 80) 

            local text = v:Name() 
            surface.SetFont("Trebuchet18") 
            local tw, th = surface.GetTextSize(text) 

            surface.SetDrawColor(teamColor.r, teamColor.g, teamColor.b, alpha * 0.5) 
            surface.SetMaterial(gradient_d) 
            surface.DrawTexturedRect(x - size / 2 - tw / 2, y - th / 2, size + tw, th) 

            surface.SetTextColor(255, 255, 255, alpha) 
            surface.SetTextPos(x - tw / 2, y - th / 2) 
            surface.DrawText(text) 

            local playerHealth = v.ZCitySpectatorHealth or v:Health()
            
            local healthFrac = math.Clamp(playerHealth / 100, 0, 1)
            
            local maxBarWidth = size + tw
            local barWidth = healthFrac * maxBarWidth 
            
            local r = 255 * (1 - healthFrac)
            local g = 255 * healthFrac

            surface.SetDrawColor(r, g, 0, alpha) 
            
            surface.DrawRect(x - (barWidth / 2), y + th / 1.5, barWidth, ScreenScale(1)) 
        end 
    end 
end)
