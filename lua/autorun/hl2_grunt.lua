
local Category = "Combine"

local NPC = {
	Name = "Combine Grunt",
	Class = "npc_combine_s",
	Model = "models/hl2_combine_grunt.mdl",
	Category = Category,
	Health = "40",
	Weapons = { "weapon_smg1", "weapon_pistol" }
}
list.Set( "NPC", "npc_hl_grunt", NPC )