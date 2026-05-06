if not ATTACHMENT then
	ATTACHMENT = {}
end

ATTACHMENT.Name = "40mm Incendiary Grenade"
--ATTACHMENT.ID = "base" -- normally this is just your filename
ATTACHMENT.Description = {
	TFA.AttachmentColors["-"], "Incendiary",
}
ATTACHMENT.Icon = "entities/ammo.grenadelauncher.smoke.png" --Revers to label, please give it an icon though!  This should be the path to a png, like "entities/tfa_ammo_match.png"
ATTACHMENT.ShortName = "Incendiary"

ATTACHMENT.WeaponTable = {
	["Primary"] = {
		["Damage"] = 50,
		["Projectile"] = "arccw_uc_40mm_incendiary",
	},
}


function ATTACHMENT:Attach(wep)
	wep:Unload()
end

function ATTACHMENT:Detach(wep)
	wep:Unload()
end



if not TFA_ATTACHMENT_ISUPDATING then
	TFAUpdateAttachments()
end
