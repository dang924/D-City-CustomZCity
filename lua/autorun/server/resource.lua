if not SERVER then return end

local mapResources = {
    "maps/hdn_decay.bsp",
    "maps/hdn_derelict.bsp",
    "maps/hdn_discovery.bsp",
    "maps/hdn_docks.bsp",
    "maps/hdn_executive.bsp",
    "maps/hdn_highrise.bsp",
    "maps/hdn_origin.bsp",
    "maps/hdn_sewers.bsp",
    "maps/hdn_staklyard.bsp",
    "maps/hdn_traindepot.bsp",
    "maps/ovr_derelict.bsp",
    "maps/ovr_docks.bsp",
    "maps/ovr_executive.bsp",
}

for _, filePath in ipairs(mapResources) do
    resource.AddFile(filePath)
end