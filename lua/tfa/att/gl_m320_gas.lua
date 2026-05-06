if not ATTACHMENT then
	ATTACHMENT = {}
end

ATTACHMENT.Name = "40mm GAS Grenade"
--ATTACHMENT.ID = "base" -- normally this is just your filename
ATTACHMENT.Description = {
	TFA.AttachmentColors["-"], "GAS",
}
ATTACHMENT.Icon = "entities/ammo.grenadelauncher.smoke.png" --Revers to label, please give it an icon though!  This should be the path to a png, like "entities/tfa_ammo_match.png"
ATTACHMENT.ShortName = "GAS"

ATTACHMENT.WeaponTable = {
	["Primary"] = {
		["Damage"] = 50,
		["Projectile"] = "arccw_fes_chemical",
		["ProjectileVelocity"] = 1000,
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
