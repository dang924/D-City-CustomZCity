if not ATTACHMENT then
	ATTACHMENT = {}
end

ATTACHMENT.Name = "M1905 Bayonet"
--ATTACHMENT.ID = "base" -- normally this is just your filename
ATTACHMENT.Description = {TFA.AttachmentColors["+"], "Can stab", TFA.AttachmentColors["-"], "2% lower movespeed"}
ATTACHMENT.Icon = "entities/blast_m1garand_bayonet.png" --Revers to label, please give it an icon though!  This should be the path to a png, like "entities/tfa_ammo_match.png"
ATTACHMENT.ShortName = "Bayonet"

ATTACHMENT.WeaponTable = {
	["VElements"] = {
		["m1_bayonet"] = {
			["active"] = true
		}
		},
	["WElements"] = {
		["m1_bayonet"] = {
			["active"] = true
		}
		},	
	["MoveSpeed"] = function( wep, val) return val * 0.98 end,
	["IronSightsMovespeed"] = function( wep, val) return val * 0.98 end,
	["Secondary"] = {
		["CanBash"] = true
	}
}

if not TFA_ATTACHMENT_ISUPDATING then
	TFAUpdateAttachments()
end