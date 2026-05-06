if SERVER then return end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool
local Menu = TOOLMODULE.Menu or {}

Menu.RegisterAction("showcase", {
    label = "Showcase",
    open = function(panel)
        if IsValid(panel) and isfunction(panel.OpenShowcase) then
            return panel:OpenShowcase()
        end
    end
})

Menu.RegisterAction("all_facemaps", {
    label = "All Facemaps",
    open = function(panel)
        if IsValid(panel) and isfunction(panel.OpenAllFacemaps) then
            return panel:OpenAllFacemaps()
        end
    end
})

Menu.RegisterAction("bodygroups", {
    label = "Bodygroups",
    open = function(panel)
        if IsValid(panel) and isfunction(panel.OpenBodygroupsShowcase) then
            return panel:OpenBodygroupsShowcase()
        end
    end
})

