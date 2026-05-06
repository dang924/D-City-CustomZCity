-- Register the ZScav Spawn Point tool under the ZCity category in Utilities.
-- We register the category ourselves (idempotent with the safe-zone tool's
-- registration) and patch tool metadata, so the tool shows up regardless of
-- whether the safe-zone autorun ran first.

if not CLIENT then return end

language.Add("tool.zcity_zscav_spawnpoint.name", "ZScav Spawn Point Tool")
language.Add("tool.zcity_zscav_spawnpoint.desc",
    "Place battlefield spawn points used by the ZScav spawn-pad raid trigger.")

-- Make sure the category exists. spawnmenu.AddToolCategory is idempotent.
hook.Add("AddToolMenuCategories", "ZScavSpawnPoint_RegisterCategory", function()
    spawnmenu.AddToolCategory("Utilities", "ZCity", "ZCity")
end)

local function patchToolMetadata()
    local toolWeapon = weapons.GetStored("gmod_tool")
    local tools = istable(toolWeapon) and toolWeapon.Tool or nil
    local our = istable(tools) and tools["zcity_zscav_spawnpoint"] or nil
    if not istable(our) then return end

    our.Tab      = "Utilities"
    our.Name     = "ZScav Spawn Point Tool"
    our.Category = "ZCity"
end

timer.Simple(0, patchToolMetadata)
hook.Add("PopulateToolMenu", "ZScavSpawnPoint_PatchMetadata", patchToolMetadata)
hook.Add("InitPostEntity", "ZScavSpawnPoint_PatchMetadata_Late", function()
    timer.Simple(1, patchToolMetadata)
end)
