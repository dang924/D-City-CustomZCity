player_manager.AddValidModel( "CG's Milky", "models/conventionalgoofball/milky/milky.mdl" )
player_manager.AddValidHands( "CG's Milky", "models/conventionalgoofball/milky/milkycarms.mdl", 0, "00000000", "True" )
list.Set( "PlayerOptionsModel", "CG's Milky", "models/conventionalgoofball/milky/milky.mdl" )

local Category = "Wemi"        

local NPC =
{
	Name = "CG's Milky (Friendly)",                         
	Class = "npc_citizen",                           
	Health = "100",                                  
	KeyValues = { citizentype = 4 },                 
	Model = "models/conventionalgoofball/milky/milky_npc.mdl",  
	Weapons = { "weapon_ar2","weapon_smg1","weapon_pistol","weapon_shotgun","weapon_annabelle","weapon_alyxgun","weapon_rpg","weapon_357" },         
	Category = Category
}

list.Set( "NPC", "CG's Milky (Friendly)", NPC )                       

local NPC =
{
	Name = "CG's Milky (Hostile)",                          
	Class = "npc_combine_s",                         
	Health = "100",                                 
	Numgrenades = "4",                               
	Model = "models/conventionalgoofball/milky/milky_npc_hostile.mdl",   
	Weapons = { "weapon_ar2","weapon_smg1","weapon_pistol","weapon_shotgun","weapon_annabelle","weapon_alyxgun","weapon_rpg","weapon_357" },         
	Category = Category
}

list.Set( "NPC", "CG's Milky (Hostile)", NPC )  

