player_manager.AddValidModel( "CG's Expie", "models/conventionalgoofball/expie/expie.mdl" )
player_manager.AddValidHands( "CG's Expie", "models/conventionalgoofball/expie/expiecarms.mdl", 0, "00000000", "True" )
list.Set( "PlayerOptionsModel", "CG's Expie", "models/conventionalgoofball/expie/expie.mdl" )

local Category = "Wemi"        

local NPC =
{
	Name = "CG's Expie (Friendly)",                         
	Class = "npc_citizen",                           
	Health = "100",                                  
	KeyValues = { citizentype = 4 },                 
	Model = "models/conventionalgoofball/expie/expie_npc.mdl",  
	Weapons = { "weapon_ar2","weapon_smg1","weapon_pistol","weapon_shotgun","weapon_annabelle","weapon_alyxgun","weapon_rpg","weapon_357" },         
	Category = Category
}

list.Set( "NPC", "CG's Expie (Friendly)", NPC )                       

local NPC =
{
	Name = "CG's Expie (Hostile)",                          
	Class = "npc_combine_s",                         
	Health = "100",                                 
	Numgrenades = "4",                               
	Model = "models/conventionalgoofball/expie/expie_npc_hostile.mdl",   
	Weapons = { "weapon_ar2","weapon_smg1","weapon_pistol","weapon_shotgun","weapon_annabelle","weapon_alyxgun","weapon_rpg","weapon_357" },         
	Category = Category
}

list.Set( "NPC", "CG's Expie (Hostile)", NPC )  