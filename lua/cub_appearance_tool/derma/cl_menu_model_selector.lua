if SERVER then return end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool
local Menu = TOOLMODULE.Menu or {}

local function OpenModelSelector(panel, anchor)
    if not IsValid(panel) or not isfunction(panel.OpenModelSelector) then return nil end
    return panel:OpenModelSelector(anchor)
end

Menu.RegisterAction("model_selector", {
    label = "Model Selector",
    open = OpenModelSelector
})

