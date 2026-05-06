AddCSLuaFile()



if SERVER then
    util.AddNetworkString("kaito_net_remove_nvgs")
    util.AddNetworkString("kaito_net_remove_thermals")
    
end

if not ConVarExists("sv_kaito_free_nvg") then
    CreateConVar("sv_kaito_free_nvg", 0, 524288, "Player's do not need to use entity")
end
if not ConVarExists("sv_kaito_free_thermal_only") then
    CreateConVar("sv_kaito_free_thermal_only", 0, 524288, "Thermals will not need entity only")
end

if not ConVarExists("sv_kaito_free_nightvision_only") then
    CreateConVar("sv_kaito_free_nightvision_only", 0, 524288, "Nightvision will not need entity only")
end


if SERVER then
    concommand.Add("kaito_remove_nvgs", function(ply,cmd,args,argStr)
        local nvg_remove = "[KNTS] NVGs have been removed."
        local thermal_remove = "[KNTS] Thermals have been removed."
        local error_nothing_equipped = "[KNTS] You have nothing equipped."
        local isNVGEquipped = ply:GetNWInt("nvg_equipped",0)
        local isThermalEquipped = ply:GetNWInt("thermal_equipped", 0)
        local spawnPos =  ply:GetPos() + (ply:GetForward() * 50) 

        
        if (isNVGEquipped != 0) then
            ply:SetNWInt("nvg_equipped", 0)
            ply:ChatPrint(nvg_remove)
            local nvg = ents.Create("nightvision")
            nvg:SetPos(spawnPos)
            nvg:Spawn()
            net.Start("kaito_net_remove_nvgs", false)
                net.WriteEntity(ply)
            net.Broadcast() 
        end 
        if (isThermalEquipped != 0) then
            ply:SetNWInt("thermal_equipped", 0)
            ply:ChatPrint(thermal_remove)
            local thermal = ents.Create("thermalvision")
            thermal:SetPos(spawnPos)
            thermal:Spawn()
            net.Start("kaito_net_remove_thermals", false)
                net.WriteEntity(ply)
            net.Broadcast() 
        end    
    end)
end



local visionNocturneActive = false
local luminositeLocaleActive = false
local visionThermiqueActive = false
local timeout = -1


local errorAlreadyActive = "[KNTS] Error, please use only one system at any given time."
local errorNotEquipped = "[KNTS] Error, please equip the corresponding entity (press E on it)."



local nvgBloomSettings = {
    darken = 0.70,
    multiply = 0.2,
    sizex = 4,
    sizey = 4,
    passes = 1,
    colormultiply = 1,
    red = 1,
    green = 1,
    blue = 1,
}


local function activerVisionNocturne()
    local isNVGFree = GetConVar("sv_kaito_free_nightvision_only"):GetInt()
    local isFree = GetConVar("sv_kaito_free_nvg"):GetInt()
    if SERVER then return end
    local isNVGEquipped = LocalPlayer():GetNWInt("nvg_equipped",0)
    

    if isFree == 0 then
        if isNVGFree == 0 then
            if isNVGEquipped == 0 then
                surface.PlaySound("kaito/knts/activation_error.mp3")
                LocalPlayer():ChatPrint(errorNotEquipped)
                return
            end
        end
    end 
    

    if visionThermiqueActive == true then
        surface.PlaySound("kaito/knts/activation_error.mp3")
        LocalPlayer():ChatPrint(errorAlreadyActive)
        return
    end
    LocalPlayer():ScreenFade(1, Color(0,0,0), 9, 0)
    visionNocturneActive = true
    surface.PlaySound("kaito/knts/nvg_power_on.mp3")
    kAmbiantSound = LocalPlayer():StartLoopingSound("kaito/knts/tactical_goggles_on_ambiant.wav")

    -- Appliquer un filtre vert
    hook.Add("RenderScreenspaceEffects", "VisionNocturneFiltreVert", function()
        local tab = {}
        tab[ "$pp_colour_addr" ] = -1
        tab[ "$pp_colour_addg" ] = 0 -- Ajustez la valeur verte en fonction de vos besoins
        tab[ "$pp_colour_addb" ] = -1
        tab[ "$pp_colour_brightness" ] = 0.01 -- Ajustez la luminosité en fonction de vos besoins
        tab[ "$pp_colour_contrast" ] = 4.5
        tab[ "$pp_colour_colour" ] = 1
        tab[ "$pp_colour_mulr" ] = 0
        tab[ "$pp_colour_mulg" ] = 0
        tab[ "$pp_colour_mulb" ] = 0

        DrawColorModify(tab)


        local dlight = DynamicLight(LocalPlayer():EntIndex())
        local dlightBrightness = GetConVar("cl_kaito_nvg_ir_illum_slidervalue"):GetFloat() 
        local dlightSize = GetConVar("cl_kaito_nvg_ir_size_slidervalue"):GetInt()
        if dlight then
            dlight.brightness = dlightBrightness
            dlight.Size = dlightSize
            dlight.r = 255
            dlight.g = 255
            dlight.b = 255
            dlight.Decay = 950
            dlight.Pos = EyePos()
            dlight.DieTime = CurTime() + 0.1
        end

        DrawBloom(nvgBloomSettings.darken,nvgBloomSettings.multiply,nvgBloomSettings.sizex,nvgBloomSettings.sizey,nvgBloomSettings.passes,nvgBloomSettings.colormultiply,nvgBloomSettings.red,nvgBloomSettings.green,nvgBloomSettings.blue)

    end)


    hook.Add("HUDPaint", "kaitoDrawNVGOverlay", function ()

        DrawMaterialOverlay("effects/combine_binocoverlay", -0.06)
    
        /**local drawMaterial = Material("hud/kaito/nightvision.png")

        surface.SetDrawColor(255,255,255)
        surface.SetMaterial(drawMaterial)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())**/

    end)
end
    

-- Fonction pour désactiver la vision nocturne
local function desactiverVisionNocturne()
    if visionThermiqueActive then return end
    if visionNocturneActive then
        LocalPlayer():StopLoopingSound(kAmbiantSound)
    end
    
    visionNocturneActive = false
    surface.PlaySound("kaito/knts/nvg_power_off.mp3")
    -- Supprimer les effets de filtre vert et de pixellisation
    LocalPlayer():ScreenFade(1, Color(0,0,0), 9, 0)
    hook.Remove("RenderScreenspaceEffects", "VisionNocturneFiltreVert")
    hook.Remove("RenderScreenspaceEffects", "VisionNocturneShader")
    hook.Remove("HUDPaint", "kaitoDrawNVGOverlay")
end
-- Ajoutez une commande pour activer et désactiver la vision nocturne

if CLIENT then
    concommand.Add("enable_night_vision", function()
        if timeout < CurTime() then

            if not visionNocturneActive then
                activerVisionNocturne()
                timeout = CurTime()+2
            else
                desactiverVisionNocturne()
                timeout = CurTime()+2
            end
        end
    end)   
end





--=================================================================================================


local thermalMat = Material("pp/texturize/plain.png")


local thermalBloomSettings = {
    darken = 0,
    multiply = 1,
    sizex = 4,
    sizey = 4,
    passes = 1,
    colormultiply = 1,
    red = 1,
    green = 1,
    blue = 1,
}


local function activerVisionThermique()
    
    local isFree = GetConVar("sv_kaito_free_nvg"):GetInt()
    local isThermalFree = GetConVar("sv_kaito_free_thermal_only"):GetInt()
    if SERVER then return end
    local isThermalEquipped = LocalPlayer():GetNWInt("thermal_equipped", 0)
    
    if isFree == 0 then
        if isThermalFree == 0 then
            if isThermalEquipped == 0 then
                surface.PlaySound("kaito/knts/activation_error.mp3")
                LocalPlayer():ChatPrint(errorNotEquipped)
                return
            end
        end
    end
    

    if visionNocturneActive then
        surface.PlaySound("kaito/knts/activation_error.mp3")
        LocalPlayer():ChatPrint(errorAlreadyActive)
        return
    end
    LocalPlayer():ScreenFade(1, Color(0,0,0), 9, 0)
    visionThermiqueActive = true
    surface.PlaySound("kaito/knts/tactical_goggles_on.mp3")
    kAmbiantSound = LocalPlayer():StartLoopingSound("kaito/knts/tactical_goggles_on_ambiant.wav")



    hook.Add("PreDrawEffects", "kaitoThermalOutlineEffect", function()

        local cur_pos_player = LocalPlayer():GetPos()
        TMWalls = 0
	    TMRange = 25000000
        local extraGlowEnts = {}
	
	    render.ClearStencil()
	
	    render.SetStencilEnable(true)
		render.SetStencilWriteMask(255)
		render.SetStencilTestMask(255)
		render.SetStencilReferenceValue(1)
		
		for _, ent in ipairs(ents.GetAll()) do
			if (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then
				if (ent == LocalPlayer()) then
					if (!ent:Alive()) then
						ThermalVisionActive = false
						
						hook.Remove("PreDrawViewModel", "ThermalVisionViewmodelColorON")
						hook.Remove("PostDrawTranslucentRenderables", "ThermalVisionToggleON")
						
						return
					end
				else
					if TMRange != 0 then
						if (ent:GetPos():DistToSqr(cur_pos_player) > TMRange) then continue end
					end
					
					render.SetStencilCompareFunction(STENCIL_ALWAYS)
					
					if (TMWalls == 1) then
						render.SetStencilZFailOperation(STENCIL_REPLACE)
					else
						render.SetStencilZFailOperation(STENCIL_KEEP)
					end
					
					render.SetStencilPassOperation(STENCIL_REPLACE)
					render.SetStencilFailOperation(STENCIL_KEEP)
					ent:DrawModel()
					
					render.SetStencilCompareFunction(STENCIL_EQUAL)
					render.SetStencilZFailOperation(STENCIL_KEEP)
					render.SetStencilPassOperation(STENCIL_KEEP)
					render.SetStencilFailOperation(STENCIL_KEEP)
					
					cam.Start2D()
						surface.SetDrawColor(234, 234, 234)
						surface.DrawRect(0, 0, ScrW(), ScrH())
					cam.End2D()
					
					table.insert(extraGlowEnts, ent)
				end
			end
		end
		
		if (TMWalls == 1) then
			halo.Add(extraGlowEnts, Color(255, 255, 255), 1, 1, 1, true, true)
		else
			halo.Add(extraGlowEnts, Color(255, 255, 255), 1, 1, 1, true, false)
		end
		
		render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
	    render.SetStencilEnable(false)

    end)

    hook.Add("RenderScreenspaceEffects", "VisionThermiqueBase", function()
        local thermalColorSettings = {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.05,
            ["$pp_colour_contrast"] = 0.5,
            ["$pp_colour_colour"] = 0,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        }

        DrawColorModify(thermalColorSettings)

        local dlight = DynamicLight(LocalPlayer():EntIndex())

        if dlight then
            dlight.brightness = 1
            dlight.Size = 900
            dlight.r = 255
            dlight.g = 255
            dlight.b = 255
            dlight.Decay = 1000
            dlight.Pos = EyePos()
            dlight.DieTime = CurTime() + 0.1
        end

        DrawBloom(thermalBloomSettings.darken,thermalBloomSettings.multiply,thermalBloomSettings.sizex,thermalBloomSettings.sizey,thermalBloomSettings.passes,thermalBloomSettings.colormultiply,thermalBloomSettings.red,thermalBloomSettings.green,thermalBloomSettings.blue)
        DrawTexturize(1, thermalMat)

    end)


end


local function desactiverVisionThermique()
    if visionNocturneActive then return end
    if visionThermiqueActive then
        LocalPlayer():StopLoopingSound(kAmbiantSound)
    end
    visionThermiqueActive = false

    surface.PlaySound("kaito/knts/tactical_goggles_off.mp3")
    LocalPlayer():ScreenFade(1, Color(0,0,0), 9, 0)
    hook.Remove("RenderScreenspaceEffects", "VisionThermiqueBase")
    hook.Remove("PreDrawEffects", "kaitoThermalOutlineEffect")
end


if CLIENT then
    concommand.Add("enable_thermal_vision", function()
        if timeout < CurTime() then
            if not visionThermiqueActive then
                activerVisionThermique()
                timeout = CurTime() + 2
            else
                desactiverVisionThermique()
                timeout = CurTime() + 2
            end
        end
    end)    
end



net.Receive("kaito_net_remove_nvgs", function()
    if net.ReadEntity() == LocalPlayer() then
        desactiverVisionNocturne()
    end
end)

net.Receive("kaito_net_remove_thermals", function()
    if net.ReadEntity() == LocalPlayer() then
        desactiverVisionThermique()
    end
end)