AddCSLuaFile()


if SERVER then return end


if not ConVarExists("cl_kaito_nvg_ir_illum_slidervalue") then
    CreateClientConVar("cl_kaito_nvg_ir_illum_slidervalue", 0.40, true, false, "Change IR Illumination")
end

if not ConVarExists("cl_kaito_nvg_ir_size_slidervalue") then
    CreateClientConVar("cl_kaito_nvg_ir_size_slidervalue", 400, true, false, "Change IR's Light Size")
end

hook.Add( "AddToolMenuCategories", "KaitoCustomNVGMenu", function()
	spawnmenu.AddToolCategory( "Options", "KaitoNVGMenu", "#Nightvision Options" )
end )

hook.Add( "PopulateToolMenu", "KaitoCustomNVGMenu", function()
    spawnmenu.AddToolMenuOption( "Options", "KaitoNVGMenu", "KS_NVGOptions", "#Server Options", "", "", function( panel )
        panel:ClearControls()
        panel:CheckBox("Remove necessity from entity for all.", "sv_kaito_free_nvg")
        panel:CheckBox("Remove necessity from entity for NVG","sv_kaito_free_nightvision_only")
        panel:CheckBox("Remove necessity from entity for Thermals","sv_kaito_free_thermal_only")
    end )

    spawnmenu.AddToolMenuOption( "Options", "KaitoNVGMenu", "KC_NVGOptions", "#Client Settings", "", "", function( panel )
        panel:ClearControls()
        panel:NumSlider("NVG IR Illumination", "cl_kaito_nvg_ir_illum_slidervalue", 0.10, 2.5, 2)
        panel:NumSlider("NVG IR Light's Size", "cl_kaito_nvg_ir_size_slidervalue", 100, 1500, 0)
    end )
end)



