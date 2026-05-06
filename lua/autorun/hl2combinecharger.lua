
local Category = "Combine"

local NPC = {
	Name = "Combine Wallhammer",
	Class = "npc_combine_s",
	Model = "models/hl2_combine_wallhammer.mdl",
	Category = Category,
	Health = "500",
	Weapons = { "weapon_ar2", "weapon_smg1", "weapon_shotgun" }
}
list.Set( "NPC", "npc_hl_wallhammer", NPC )