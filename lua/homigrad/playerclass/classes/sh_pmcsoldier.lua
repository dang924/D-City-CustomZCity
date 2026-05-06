local CLASS = player.RegClass("pmc")

function CLASS.Off(self)
	if CLIENT then return end
	self.subClass = nil
end
local prefix = {
	"Soldier", "Fighter", "Safer", "Veteran"
}
--[[local keys = {
    "Fighter1","Fighter2","Fighter3","Fighter4","Fighter5","Fighter6","RusFigher1","RusFigher2","RusFigher3","Stormtrooper4",
    "Stormtrooper3", "Stormtrooper2", "Stormtrooper1","Veteran","Machinegunner","RusMachinegunner1","RusMachinegunner2","Sniper"
}]]
local equipers = {
	["Fighter1"] = {
		primaryswep = {
			swep = "weapon_hk416",
			sights = {"holo17","holo8","holo1","holo9","optic9","holo15"},
			suppressor = "supressor2"
		},
		armor = {"ent_armor_helmet21","ent_armor_headphones1","ent_armor_vest32"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Fighter2"] = {
		primaryswep = {
			swep = "weapon_m4a1",
			sights = {"holo17","holo8","holo1","holo9","optic9","holo15"},
			suppressor = "supressor2"
		},
		armor = {"ent_armor_helmet22","ent_armor_vest26"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_bigbandage_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Fighter3"] = {
		primaryswep = {
			swep = "weapon_sg552",
			sights = {"holo17","holo8","holo1","holo9","optic9","holo15"},
			suppressor = "supressor2"
		},
		armor = {"ent_armor_helmet20","ent_armor_headphones3","ent_armor_vest20"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_bigbandage_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Fighter4"] = {
		primaryswep = {
			swep = "weapon_lr300",
			sights = {"holo17","holo8","holo1","holo9","optic9","holo15"},
			suppressor = "supressor2"
		},
		armor = {"ent_armor_helmet5","ent_armor_headphones2","ent_armor_vest28"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_bigbandage_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Fighter5"] = {
		primaryswep = {
			swep = "weapon_scarh",
			sights = {"holo17","holo8","holo1","holo9","optic9","holo15"},
			suppressor = "supressor7"
		},
		armor = {"ent_armor_helmet5","ent_armor_headphones2","ent_armor_vest28"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_bigbandage_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Fighter6"] = {
		primaryswep = {
			swep = "weapon_famasf1",
			sights = {"holo17","holo8","holo1","holo9","optic9","holo15"},
			suppressor = "supressor7"
		},
		armor = {"ent_armor_helmet5","ent_armor_headphones2","ent_armor_vest28"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_bigbandage_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["RusFigher1"] = {
		primaryswep = {
			swep = "weapon_ak200",
			sights = {"holo12","holo8","holo1","holo9","holo13","holo15"},
			suppressor = "supressor1"
		},
		armor = {"ent_armor_helmet15","ent_armor_headphones4","ent_armor_vest18"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_bigbandage_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["RusFigher2"] = {
		primaryswep = {
			swep = "weapon_asval",
			sights = {"holo6", "", ""},
		},
		armor = {"ent_armor_helmet8","ent_armor_headphones4","ent_armor_vest19"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_bigbandage_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["RusFigher3"] = {
		primaryswep = {
			swep = "weapon_akalpha",
			sights = {"holo12","holo8","holo1","holo9","holo13","holo15"},
		},
		armor = {"ent_armor_helmet10","ent_armor_headphones4","ent_armor_vest10"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_bigbandage_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Stormtrooper1"] = {
		primaryswep = {
			swep = "weapon_mp7",
			sights = {"holo9","holo7"},
		},
		armor = {"ent_armor_helmet23","ent_armor_headphones3","ent_armor_vest31"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Stormtrooper2"] = {
		primaryswep = {
			swep = "weapon_tmp",
			sights = {"holo9","holo7"},
		},
		armor = {"ent_armor_helmet5","ent_armor_headphones2","ent_armor_vest15"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Stormtrooper3"] = {
		primaryswep = {
			swep = "weapon_vector",
			sights = {"holo9","holo7"},
		},
		armor = {"ent_armor_helmet5","ent_armor_headphones2","ent_armor_vest15"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Stormtrooper4"] = {
		primaryswep = {
			swep = "weapon_p90",
			sights = {"holo4","holo2"},
		},
		armor = {"ent_armor_helmet5","ent_armor_headphones2","ent_armor_vest15"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_grenade_tpik"}
	},
	["Veteran"] = {
		primaryswep = {
			swep = "weapon_m60",
		},
		armor = {"ent_armor_helmet20","ent_armor_headphones1","ent_armor_vest30"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_morphine","weapon_bigbandage_sh","weapon_smallconsumable","weapon_walkie_talkie","weapon_hg_smokenade_tpik"}
	},
	["Machinegunner"] = {
		primaryswep = {
			swep = "weapon_m249",
			sights = {"holo14","holo1"}
		},
		armor = {"ent_armor_helmet21","ent_armor_headphones1","ent_armor_vest12"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_smallconsumable","weapon_walkie_talkie"}
	},
	["RusMachinegunner1"] = {
		primaryswep = {
			swep = "weapon_rpk",
			sights = {"holo6","","","",""}
		},
		armor = {"ent_armor_helmet9","ent_armor_headphones4","ent_armor_vest24"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_smallconsumable","weapon_walkie_talkie"}
	},
	["RusMachinegunner2"] = {
		primaryswep = {
			swep = "weapon_pkm",
		},
		armor = {"ent_armor_vest5","ent_armor_helmet12"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_smallconsumable","weapon_walkie_talkie"}
	},
	["Sniper"] = {
		primaryswep = {
			swep = "weapon_sr25",
			sights = {"optic5","optic6"},
			suppressor = "supressor7"
		},
		armor = {"ent_armor_vest30","ent_armor_headphones2"},
		consum = {"weapon_melee", "weapon_medkit_sh","weapon_smallconsumable","weapon_walkie_talkie"}
	}
}

local function GetEquiper(ply)
	local inv = ply:GetNetVar("Inventory")    
	local Weapons = inv.Weapons    
	if inv and Weapons then
		Weapons.hg_sling = true
		ply:SetNetVar("Inventory", inv)
	end    
	local subclass = table.Random(equipers)    
	ply.subClass = subclass    
	timer.Simple(0.1, function()
		local primaryswep = subclass.primaryswep        
		if subclass and primaryswep then
			gun = ply:Give(primaryswep.swep)
		end        
		if not IsValid(ply) or not IsValid(gun) then return end        
		ply:GiveAmmo(gun:GetMaxClip1() * 5, gun:GetPrimaryAmmoType(), true)        
		local function AddAttachment(attachment)
			if attachment then
				hg.AddAttachmentForce(ply, gun, attachment)
			end
		end        
		AddAttachment(primaryswep.suppressor)        
		AddAttachment(primaryswep.unbar)        
		if primaryswep.sights and #primaryswep.sights > 0 then
			AddAttachment(table.Random(primaryswep.sights))
		end
	end)
	timer.Simple(0.2, function()
		if not IsValid(ply) then return end        
		local function Give(arg)
			local func = arg and hg.AddArmor or ply.Give
			for _, v in ipairs(arg and subclass.armor or subclass.consum) do
				func(ply, v)
			end
		end        
		Give()
		Give(true)                
		if subclass == "Veteran" then
			for i = 1,3 do
				ply:Give("weapon_hg_grenade_tpik")
			end
		end
	end)
	timer.Simple(0.1, function()
		if IsValid(ply) then
			ply:SelectWeapon("weapon_hands_sh")
		end
	end)
end


function CLASS.On(self)
	if CLIENT then return end
	ApplyAppearance(self,nil,nil,nil,true)
	local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
	self:SetNWString("PlayerName","")
	self:SetPlayerColor(Color(7,1,39):ToVector())
	self:SetModel("models/player/t_konni.mdl")
	Appearance.AAttachments = "none"
	self:SetNetVar("Accessories", Appearance.AAttachments or "none")
	for _,v in ipairs(self:GetBodyGroups()) do
		self:SetBodygroup(v.id, 1)
	end
	self:SetSubMaterial()
	Appearance.AColthes = ""
	self:SetNWString("PlayerName", prefix[math.random(#prefix)] .." ".. Appearance.AName )
	self.CurAppearance = Appearance
	GetEquiper(self)
end