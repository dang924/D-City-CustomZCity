if not CLIENT then return end

language.Add("tool.zcity_safe_zone.name", "ZCity Safe Zone Tool")
language.Add("tool.zcity_safe_zone.desc", "Create and manage persisted safe-zone boxes for stashes, traders, team finding, and loadout staging.")
language.Add("tool.zcity_safe_zone.left", "Set the first corner of a safe zone box")
language.Add("tool.zcity_safe_zone.right", "Create a safe zone from the stored first corner to the point you are aiming at")
language.Add("tool.zcity_safe_zone.reload", "Select the safe zone under your crosshair")
language.Add("tool.zcity_safe_zone.name_label", "Zone Name")
language.Add("tool.zcity_safe_zone.height", "Zone Height")

list.Set("ContentCategoryIcons", "ZCity", "icon16/map.png")

local function PatchSafeZoneToolMetadata()
    local toolWeapon = weapons.GetStored("gmod_tool")
    local tools = istable(toolWeapon) and toolWeapon.Tool or nil
    local safeZoneTool = istable(tools) and tools["zcity_safe_zone"] or nil
    if not istable(safeZoneTool) then return end

    safeZoneTool.Tab = "Utilities"
    safeZoneTool.Name = "ZCity Safe Zone Tool"
    safeZoneTool.Category = "ZCity"
end

timer.Simple(0, PatchSafeZoneToolMetadata)

hook.Add("AddToolMenuCategories", "ZCitySafeZones_RegisterToolCategory", function()
    spawnmenu.AddToolCategory("Utilities", "ZCity", "ZCity")
end)

hook.Add("PopulateToolMenu", "ZCitySafeZones_PatchSafeZoneToolMetadata", PatchSafeZoneToolMetadata)