if not CLIENT then return end

language.Add("tool.zcity_zscav_extract.name", "ZScav Extract Tool")
language.Add("tool.zcity_zscav_extract.desc", "Place named raid extracts and link them to existing ZScav spawn groups on this map.")

hook.Add("AddToolMenuCategories", "ZScavExtract_RegisterCategory", function()
    spawnmenu.AddToolCategory("Utilities", "ZCity", "ZCity")
end)

local function patchToolMetadata()
    local toolWeapon = weapons.GetStored("gmod_tool")
    local tools = istable(toolWeapon) and toolWeapon.Tool or nil
    local our = istable(tools) and tools["zcity_zscav_extract"] or nil
    if not istable(our) then return end

    our.Tab = "Utilities"
    our.Name = "ZScav Extract Tool"
    our.Category = "ZCity"
end

timer.Simple(0, patchToolMetadata)
hook.Add("PopulateToolMenu", "ZScavExtract_PatchMetadata", patchToolMetadata)
hook.Add("InitPostEntity", "ZScavExtract_PatchMetadata_Late", function()
    timer.Simple(1, patchToolMetadata)
end)