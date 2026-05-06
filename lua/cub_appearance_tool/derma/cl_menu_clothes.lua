if SERVER then return end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool
local Menu = TOOLMODULE.Menu or {}

function Menu.OpenClothes(panel, part, anchor)
    if not IsValid(panel) or not isfunction(panel.OpenPartSelector) then return nil end
    return panel:OpenPartSelector(part, anchor)
end

