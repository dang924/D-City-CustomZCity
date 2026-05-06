
local Category = "Combine"

local NPC = {
	Name = "Combine Ordinal",
	Class = "npc_combine_s",
	Model = "models/hl2_combine_ordinal.mdl",
	Category = Category,
	Health = "70",
	Weapons = { "weapon_ar2", "weapon_smg1", "weapon_shotgun" }
}
list.Set( "NPC", "npc_hl_ordinal", NPC )

--local currenthealth = ply:GetMaxHealth()
local healthboost = 10

CreateConVar("propint_enabled", "1", {FCVAR_NONE}, "", 0, 1)

hook.Add("OnPlayerPhysicsPickup", "propinteractions", function(ply, ent)
	if GetConVar("propint_enabled"):GetString() == "0" then return false end
	if ent:GetModel() == "models/props_junk/PopCan01a.mdl" then
	ply:Give("weapon_crowbar")
	ply:SelectWeapon("weapon_crowbar")
	ply:SetMaxHealth(ply:GetMaxHealth() + healthboost)
	ply:SetHealth(ply:Health() + healthboost)
	ent:EmitSound("items/smallmedkit1.wav")
	ent:Remove()
	end
end)