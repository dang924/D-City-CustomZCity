JMod.DayZArmorTable = JMod.DayZArmorTable or {}

if CLIENT then
	list.Set("ContentCategoryIcons", "JMod - EZ DayZ Armor", "jmod_icon_dayzarmor.png")
end


JMod.ArmorSlotNiceNames = {
	eyes = "Eyes",
	mouthnose = "Mouth & Nose",
	ears = "Ears",
	head = "Head",
	chest = "Chest",
	back = "Back",
	abdomen = "Abdomen",
	pelvis = "Pelvis",
	waist = "Waist",
	leftthigh = "Left Thigh",
	leftcalf = "Left Calf",
	rightthigh = "Right Thigh",
	rightcalf = "Right Calf",
	rightshoulder = "Right Shoulder",
	rightforearm = "Right Forearm",
	leftshoulder = "Left Shoulder",
	leftforearm = "Left Forearm",
	vestattachment = "Vest Attachment",
	vestattachmentup = "Vest Attachment Up",
	vestattachmentdown = "Vest Attachment Down",
	visor = "Visor"
}

local StabVestProtectionProfile = {
	[DMG_BUCKSHOT] = .2,
	[DMG_CLUB] = .6,
	[DMG_SLASH] = .6,
	[DMG_BULLET] = .2,
	[DMG_BLAST] = .2,
	[DMG_SNIPER] = .1,
	[DMG_AIRBOAT] = .2,
	[DMG_CRUSH] = .3,
	[DMG_VEHICLE] = .2,
	[DMG_BURN] = .2,
	[DMG_PLASMA] = .1,
	[DMG_ACID] = .1
}

local BallisticArmorProtectionProfile = {
	[DMG_BUCKSHOT] = .45,
	[DMG_BLAST] = .35,
	[DMG_BULLET] = .55,
	[DMG_SNIPER] = .2,
	[DMG_AIRBOAT] = .45,
	[DMG_CLUB] = .5,
	[DMG_SLASH] = .5,
	[DMG_CRUSH] = .5,
	[DMG_VEHICLE] = .25,
	[DMG_BURN] = .25,
	[DMG_PLASMA] = .45,
	[DMG_ACID] = .45
}

local PlateCarrierProtectionProfile = {
	[DMG_BUCKSHOT] = .5,
	[DMG_BLAST] = .4,
	[DMG_BULLET] = .5,
	[DMG_SNIPER] = .3,
	[DMG_AIRBOAT] = .75,
	[DMG_CLUB] = .75,
	[DMG_SLASH] = .8,
	[DMG_CRUSH] = .75,
	[DMG_VEHICLE] = .4,
	[DMG_BURN] = .35,
	[DMG_PLASMA] = .75,
	[DMG_ACID] = .75
}

local KnightshitProtectionProfile = {
	[DMG_BUCKSHOT] = .45,
	[DMG_BLAST] = .35,
	[DMG_BULLET] = .55,
	[DMG_SNIPER] = .2,
	[DMG_AIRBOAT] = .45,
	[DMG_CLUB] = .9,
	[DMG_SLASH] = .9,
	[DMG_CRUSH] = .5,
	[DMG_VEHICLE] = .25,
	[DMG_BURN] = .25,
	[DMG_PLASMA] = .45,
	[DMG_ACID] = .45
}


local NonArmorProtectionProfile = {
	[DMG_BUCKSHOT] = .05,
	[DMG_BLAST] = .05,
	[DMG_BULLET] = .05,
	[DMG_SNIPER] = .05,
	[DMG_AIRBOAT] = .05,
	[DMG_CLUB] = .05,
	[DMG_SLASH] = .05,
	[DMG_CRUSH] = .05,
	[DMG_VEHICLE] = .05,
	[DMG_BURN] = .05,
	[DMG_PLASMA] = .05,
	[DMG_ACID] = .05
}

JMod.DayZArmorTable = {


-- NVG


	["NVG with strap"] = {
		PrintName = "[NVG] NVG with strap",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/eyes/nvg_strap.mdl",
		slots = {
			eyes = 1
		},
		def = NonArmorProtectionProfile,
		clrForced = true,
		bon = "ValveBiped.Bip01_Head1",
		siz = Vector(1, 1, 1),
		pos = Vector(1.2, 2.7, 0),
		ang = Angle(-80, 0, -90),
		wgt = 5,
		dur = 15,
		chrg = {
			power = 50
		},
		mskmat = "mats_jack_gmod_sprites/vignette.png",
		eqsnd = "snds_jack_gmod/tinycapcharge.ogg",
		ent = "ent_jack_gmod_ezarmor_nvg_strap",
			bdg = {
				[1] = 1
			},
		eff = {
			nightVision = true
		},
		blackvisionwhendead = true,
		tgl = {
			blackvisionwhendead = false,
			bdg = {
				[1] = 0
			},
		pos = Vector(1.2, 2.7, 0),
		ang = Angle(-80, 0, -90),
			mskmat = "",
			eff = {},
			slots = {
				eyes = 0
			}
		}
	},
	
	
-- TORSO
	["Chestplate"] = {
		PrintName = "[VT] Chestplate",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_chestplate.mdl",
		slots = {
			chest = 1,
			abdomen = 0.9
		},
		storage = 0,
		def = KnightshitProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(-3.7, 0, 0),
		ang = Angle(-87, 0, 90),
		wgt = 30,
		dur = 200,
		ent = "ent_jack_gmod_ezarmor_chestplate"
	},
	
			["Chest Holster"] = {
		PrintName = "[VT] Chest Holster",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_chest_holster.mdl",
		slots = {
			chest = 0,
			abdomen = 0
		},
		storage = 2,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.2, 0.9, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_chestholster"
	},

			["Reflective Vest"] = {
		PrintName = "[VT] Reflective Vest",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_reflective_vest.mdl",
		slots = {
			chest = 0,
			abdomen = 0
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.2, 0.9, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_reflective"
	},
	
			["Hunter Vest"] = {
		PrintName = "[VT] Hunter Vest",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_hunter_vest.mdl",
		slots = {
			chest = 0,
			abdomen = 0
		},
		storage = 5,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.2, 0.2, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_huntervest"
	},
	
			["Hunter Vest Winter"] = {
		PrintName = "[VT] Hunter Vest (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_hunter_vest.mdl",
		mat = "models/jmod_dayz/vest/hunter_vest/hunter_vest_winter",
		slots = {
			chest = 0,
			abdomen = 0
		},
		storage = 5,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.2, 0.2, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_huntervest_winter"
	},

			["Stab Vest"] = {
		PrintName = "[VT] Stab Vest",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_stab_vest.mdl",
		slots = {
			chest = .4,
			abdomen = .3
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(0.96, 0.96, 1),
		pos = Vector(-3, 0, 0),
		ang = Angle(-87, 0, 90),
		wgt = 10,
		dur = 75,
		ent = "ent_jack_gmod_ezarmor_stab"
	},
	
			["Ballistic Vest"] = {
		PrintName = "[VT] Ballistic Vest",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_press_vest.mdl",
		slots = {
			chest = .6,
			abdomen = .4
		},
		storage = 5,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(0.98, 0.97, 0.98),
		pos = Vector(-3.4, 0.9, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_press"
	},
	
			["Assault Vest"] = {
		PrintName = "[VT] Assault Vest",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_assault_vest.mdl",
		slots = {
			chest = 0,
			abdomen = 0
		},
		storage = 10,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.5, -2, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_assault"
	},
	
			["Tactical Vest Olive"] = {
		PrintName = "[VT] Tactical Vest (olive)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_tactical_vest_olive.mdl",
		slots = {
			chest = .4,
			abdomen = .2
		},
		storage = 10,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(0.99, 0.96, 1),
		pos = Vector(-3.4, 0, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_tacticalolive"
	},
	
			["Tactical Vest Black"] = {
		PrintName = "[VT] Tactical Vest (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_tactical_vest_black.mdl",
		slots = {
			chest = .4,
			abdomen = .2
		},
		storage = 10,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(0.99, 0.96, 1),
		pos = Vector(-3.4, 0, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_tacticalblack"
	},
	
			["Field Vest Olive"] = {
		PrintName = "[VT] Field Vest (olive)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_field_vest.mdl",
		slots = {
			chest = .4,
			abdomen = .2
		},
		storage = 10,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.4, 1.4, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_field_olive"
	},
	
			["Field Vest Black"] = {
		PrintName = "[VT] Field Vest (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_field_vest.mdl",
		mat = "models/jmod_dayz/vest/field_vest/field_vest_black",
		slots = {
			chest = .4,
			abdomen = .2
		},
		storage = 10,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.4, 1.4, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_field_black"
	},
	
				["Field Vest Khaki"] = {
		PrintName = "[VT] Field Vest (khaki)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_field_vest.mdl",
		mat = "models/jmod_dayz/vest/field_vest/field_vest_khaki",
		slots = {
			chest = .4,
			abdomen = .2
		},
		storage = 10,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.4, 1.4, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_field_khaki"
	},
	
			["Field Vest Camo"] = {
		PrintName = "[VT] Field Vest (camo)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_field_vest.mdl",
		mat = "models/jmod_dayz/vest/field_vest/field_vest_camo",
		slots = {
			chest = .4,
			abdomen = .2
		},
		storage = 10,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.4, 1.4, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_field_camo"
	},
	
			["Field Vest Winter"] = {
		PrintName = "[VT] Field Vest (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_field_vest.mdl",
		mat = "models/jmod_dayz/vest/field_vest/field_vest_winter",
		slots = {
			chest = .4,
			abdomen = .2
		},
		storage = 10,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.4, 1.4, 0),
		ang = Angle(-87, 0, 90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_field_winter"
	},
	
			["Plate Carrier Tan"] = {
		PrintName = "[VT] Plate Carrier (tan)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_plate_carrier_tan.mdl",
		slots = {
			chest = 1,
			abdomen = 0.9
		},
		storage = 0,
		def = PlateCarrierProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.1, 2.6, 0),
		ang = Angle(-87, 0, 90),
		wgt = 20,
		dur = 300,
		ent = "ent_jack_gmod_ezarmor_platetan"
	},
	
			["Plate Carrier Black"] = {
		PrintName = "[VT] Plate Carrier (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_plate_carrier_tan.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_black",
		slots = {
			chest = 1,
			abdomen = 0.9
		},
		storage = 0,
		def = PlateCarrierProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.1, 2.6, 0),
		ang = Angle(-87, 0, 90),
		wgt = 20,
		dur = 300,
		ent = "ent_jack_gmod_ezarmor_plateblack"
	},
	
			["Plate Carrier Camo"] = {
		PrintName = "[VT] Plate Carrier (camo)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_plate_carrier_tan.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_camo",
		slots = {
			chest = 1,
			abdomen = 0.9
		},
		storage = 0,
		def = PlateCarrierProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.1, 2.6, 0),
		ang = Angle(-87, 0, 90),
		wgt = 20,
		dur = 300,
		ent = "ent_jack_gmod_ezarmor_platecamo"
	},
	
			["Plate Carrier Olive"] = {
		PrintName = "[VT] Plate Carrier (olive)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_plate_carrier_tan.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_olive",
		slots = {
			chest = 1,
			abdomen = 0.9
		},
		storage = 0,
		def = PlateCarrierProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.1, 2.6, 0),
		ang = Angle(-87, 0, 90),
		wgt = 20,
		dur = 300,
		ent = "ent_jack_gmod_ezarmor_plateolive"
	},
	
			["Plate Carrier Winter"] = {
		PrintName = "[VT] Plate Carrier (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/vt_plate_carrier_tan.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_winter",
		slots = {
			chest = 1,
			abdomen = 0.9
		},
		storage = 0,
		def = PlateCarrierProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-3.1, 2.6, 0),
		ang = Angle(-87, 0, 90),
		wgt = 20,
		dur = 300,
		ent = "ent_jack_gmod_ezarmor_platewinter"
	},

-- VEST ATTACHMENTS

			["Plate Carrier Pouches Tan"] = {
		PrintName = "[VA] Plate Carrier Pouches (tan)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_pouches.mdl",
		slots = {
			vestattachment = 0,
		},
		storage = 3,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-11, -2, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_platepouchestan"
	},
	
			["Plate Carrier Pouches Camo"] = {
		PrintName = "[VA] Plate Carrier Pouches (camo)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_pouches.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_camo",
		slots = {
			vestattachment = 0,
		},
		storage = 3,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-11, -2, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_platepouchescamo"
	},
	
			["Plate Carrier Pouches Black"] = {
		PrintName = "[VA] Plate Carrier Pouches (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_pouches.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_black",
		slots = {
			vestattachment = 0,
		},
		storage = 3,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-11, -2, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_platepouchesblack"
	},
	
			["Plate Carrier Pouches Olive"] = {
		PrintName = "[VA] Plate Carrier Pouches (olive)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_pouches.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_olive",
		slots = {
			vestattachment = 0,
		},
		storage = 3,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-11, -2, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_platepouchesolive"
	},
	
			["Plate Carrier Pouches Winter"] = {
		PrintName = "[VA] Plate Carrier Pouches (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_pouches.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_winter",
		slots = {
			vestattachment = 0,
		},
		storage = 3,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-11, -2, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_platepoucheswinter"
	},
	
			["Plate Carrier Holster Tan"] = {
		PrintName = "[VA] Plate Carrier Holster (tan)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_holster.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_tan",
		slots = {
			vestattachmentup = 0,
		},
		storage = 1,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-10, 4.5, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_plateholstertan"
	},
	
			["Plate Carrier Holster Black"] = {
		PrintName = "[VA] Plate Carrier Holster (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_holster.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_black",
		slots = {
			vestattachmentup = 0,
		},
		storage = 1,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-10, 4.5, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_plateholsterblack"
	},
	
			["Plate Carrier Holster Olive"] = {
		PrintName = "[VA] Plate Carrier Holster (olive)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_holster.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_olive",
		slots = {
			vestattachmentup = 0,
		},
		storage = 1,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-10, 4.5, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_plateholsterolive"
	},
	
			["Plate Carrier Holster Camo"] = {
		PrintName = "[VA] Plate Carrier Holster (camo)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_holster.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_camo",
		slots = {
			vestattachmentup = 0,
		},
		storage = 1,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-10, 4.5, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_plateholstercamo"
	},
	
			["Plate Carrier Holster Winter"] = {
		PrintName = "[VA] Plate Carrier Holster (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_plate_carrier_holster.mdl",
		mat = "models/jmod_dayz/vest/plate_carrier/plate_carrier_winter",
		slots = {
			vestattachmentup = 0,
		},
		storage = 1,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-10, 4.5, 0),
		ang = Angle(-87, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_plateholsterwinter"
	},
	
			["Utility Buttpack"] = {
		PrintName = "[VA] Utility Buttpack",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/vest/va_utility_buttpack.mdl",
		slots = {
			vestattachmentdown = 0,
		},
		storage = 20,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(5, -18	, 0),
		ang = Angle(-75, 0, 90),
		wgt = 5,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_smershbutt"
	},
	
-- BULLETPROOF HELMETS

			["Combat Helmet"] = {
		PrintName = "[HLM] Combat Helmet",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_ssh68.mdl",
		slots = {
			head = 0.8,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(2.2, 2.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 95,
		ent = "ent_jack_gmod_ezarmor_combathelmet"
	},
	
			["Ballistic Helmet Green"] = {
		PrintName = "[HLM] Ballistic Helmet (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_ballistic_helmet.mdl",
		slots = {
			head = 0.9,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(1, 2.6, 0),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_ballistichelmet"
	},
	
			["Ballistic Helmet Black"] = {
		PrintName = "[HLM] Ballistic Helmet (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_ballistic_helmet.mdl",
		mat = "models/jmod_dayz/helmets/ballistic_helmet/ballistic_helmet_black",
		slots = {
			head = 0.9,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(1, 2.6, 0),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_ballistichelmetblack"
	},
	
			["Ballistic Helmet UN"] = {
		PrintName = "[HLM] Ballistic Helmet (UN)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_ballistic_helmet.mdl",
		mat = "models/jmod_dayz/helmets/ballistic_helmet/ballistic_helmet_un",
		slots = {
			head = 0.9,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(1, 2.6, 0),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_ballistichelmetun"
	},
	
			["Tactical Helmet"] = {
		PrintName = "[HLM] Tactical Helmet",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_tactical_helmet.mdl",
		slots = {
			head = 0.9,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 2.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_tacticalhelmet"
	},
	
			["Camouflage Helmet Woodland"] = {
		PrintName = "[HLM] Camouflage Helmet (woodland)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_camouflage_helmet.mdl",
		slots = {
			head = 0.9,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_camohelmwoodland"
	},
	
			["Camouflage Helmet BDU"] = {
		PrintName = "[HLM] Camouflage Helmet (bdu)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_camouflage_helmet.mdl",
		mat = "models/jmod_dayz/helmets/camouflage_helmet/camouflage_helmet_bdu",
		slots = {
			head = 0.9,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_camohelmbdu"
	},
	
			["Camouflage Helmet Desert"] = {
		PrintName = "[HLM] Camouflage Helmet (desert)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_camouflage_helmet.mdl",
		mat = "models/jmod_dayz/helmets/camouflage_helmet/camouflage_helmet_desert",
		slots = {
			head = 0.9,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_camohelmdesert"
	},
	
			["Camouflage Helmet Navy"] = {
		PrintName = "[HLM] Camouflage Helmet (navy)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_camouflage_helmet.mdl",
		mat = "models/jmod_dayz/helmets/camouflage_helmet/camouflage_helmet_navy",
		slots = {
			head = 0.9,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_camohelmnavy"
	},
	
			["Camouflage Helmet Winter"] = {
		PrintName = "[HLM] Camouflage Helmet (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_camouflage_helmet.mdl",
		mat = "models/jmod_dayz/helmets/camouflage_helmet/camouflage_helmet_winter",
		slots = {
			head = 0.9,
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_camohelmwinter"
	},
	
			["Assault Helmet"] = {
		PrintName = "[HLM] Assault Helmet",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_assault_helmet.mdl",
		slots = {
			head = 1,
			ears = 0.9
		},
		storage = 0,
		def = PlateCarrierProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 2, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 20,
		dur = 230,
		ent = "ent_jack_gmod_ezarmor_assaulthelmet"
	},
	
			["Flight Helmet"] = {
		PrintName = "[HLM] Flight Helmet",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_helohelmet.mdl",
		slots = {
			head = 0.6,
			ears = 0.6,
			eyes = 0.2
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 20,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_helohelm",
		mskmat = "vision_sprites_dayz/helivisor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 1,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = ""
		}
	},
	
			["Tanker Helmet"] = {
		PrintName = "[HLM] Tanker Helmet",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_tanker_helmet.mdl",
		slots = {
			head = 0.2,
			ears = 0.2
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(0.6, 2.5, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 95,
		ent = "ent_jack_gmod_ezarmor_tankerhelmet"
	},
	
			["Great Helm"] = {
		PrintName = "[EHLM] Great Helm",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_great_helm.mdl",
		slots = {
			head = 1,
			eyes = 1,
			mouthnose =1,
			ears = 1
		},
		storage = 0,
		def = KnightshitProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.05, 1, 1),
		pos = Vector(0.8, 2.8, 0),
		ang = Angle(-80, 0, -90),
		wgt = 25,
		dur = 140,
		mskmat = "vision_sprites_dayz/greathelm.png",
		ent = "ent_jack_gmod_ezarmor_greathelm"
	},
	
			["Norsehelm"] = {
		PrintName = "[EHLM] Norsehelm",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_norsehelm.mdl",
		slots = {
			head = 0.9,
			eyes = 0.9,
			ears = 0.9
		},
		storage = 0,
		def = KnightshitProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.07, 1, 1),
		pos = Vector(0.9, 2, 0),
		ang = Angle(-80, 0, -90),
		wgt = 25,
		dur = 140,
		mskmat = "vision_sprites_dayz/norsehelm.png",
		ent = "ent_jack_gmod_ezarmor_norsehelm"
	},
	
-- DEFAULT HELMETS

			["Motobiker Helmet Red"] = {
		PrintName = "[CHLM] Motobiker Helmet (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_motohelmet_red.mdl",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.6, 2.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_motored",
		mskmat = "vision_sprites_dayz/motovisor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 1,
			mouthnose = 1,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = "vision_sprites_dayz/motovisorup.png"
		}
	},
	
			["Motobiker Helmet Yellow"] = {
		PrintName = "[CHLM] Motobiker Helmet (yellow)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_motohelmet_yellow.mdl",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.6, 2.5, -0.1),
		ang = Angle(-80, 0, -92),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_motoyellow",
		mskmat = "vision_sprites_dayz/motovisor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 1,
				mouthnose = 1,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = "vision_sprites_dayz/motovisorup.png"
		}
	},
	
			["Motobiker Helmet Black"] = {
		PrintName = "[CHLM] Motobiker Helmet (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_motohelmet_black.mdl",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.6, 2.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_motoblack",
		mskmat = "vision_sprites_dayz/motovisor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 1,
				mouthnose = 1,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = "vision_sprites_dayz/motovisorup.png"
		}
	},
	
			["Motobiker Helmet Grey"] = {
		PrintName = "[CHLM] Motobiker Helmet (grey)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_motohelmet_grey.mdl",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.6, 2.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_motogrey",
		mskmat = "vision_sprites_dayz/motovisor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 1,
				mouthnose = 1,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = "vision_sprites_dayz/motovisorup.png"
		}
	},
	
			["Motobiker Helmet Lime"] = {
		PrintName = "[CHLM] Motobiker Helmet (lime)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_motohelmet_lime.mdl",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.6, 2.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_motolime",
		mskmat = "vision_sprites_dayz/motovisor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 1,
				mouthnose = 1,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = "vision_sprites_dayz/motovisorup.png"
		}
	},
	
			["Motobiker Helmet White"] = {
		PrintName = "[CHLM] Motobiker Helmet (white)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_motohelmet_white.mdl",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.6, 2.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_motowhite",
		mskmat = "vision_sprites_dayz/motovisor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 1,
				mouthnose = 1,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = "vision_sprites_dayz/motovisorup.png"
		}
	},
	
			["Motobiker Helmet Green"] = {
		PrintName = "[CHLM] Motobiker Helmet (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_motohelmet_green.mdl",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.6, 2.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_motogreen",
		mskmat = "vision_sprites_dayz/motovisor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 1,
				mouthnose = 1,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = "vision_sprites_dayz/motovisorup.png"
		}
	},
	
			["Motobiker Helmet Blue"] = {
		PrintName = "[CHLM] Motobiker Helmet (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_motohelmet_blue.mdl",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.6, 2.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 15,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_motoblue",
		mskmat = "vision_sprites_dayz/motovisor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 1,
				mouthnose = 1,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = "vision_sprites_dayz/motovisorup.png"
		}
	},
	
		["Welding Mask Dayz"] = {
		PrintName = "[CHLM] Welding Mask",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_welding_mask.mdl",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = BallisticArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1.03, 1),
		pos = Vector(0.9, 3, 0.01),
		ang = Angle(-80, 0, -90),
		wgt = 20,
		dur = 130,
		ent = "ent_jack_gmod_ezarmor_weldingdayz",
		mskmat = "vision_sprites_dayz/welding_visor.png",
		bdg = {
			[1] = 0
		},
		tgl = {
			slots = {
				head = 1,
				ears = 0,
				mouthnose = 0,
				eyes = 0
			},
			bdg = {
				[1] = 1
			},
			mskmat = ""
		}
	},
	
			["Skate Helmet Black"] = {
		PrintName = "[CHLM] Skate Helmet (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_skate_helmet.mdl",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 2.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 95,
		ent = "ent_jack_gmod_ezarmor_skateblack"
	},
	
			["Skate Helmet Green"] = {
		PrintName = "[CHLM] Skate Helmet (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_skate_helmet.mdl",
		mat = "models/jmod_dayz/helmets/skate_helmet/skate_helmet_green",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 2.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 95,
		ent = "ent_jack_gmod_ezarmor_skategreen"
	},
	
			["Skate Helmet Blue"] = {
		PrintName = "[CHLM] Skate Helmet (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_skate_helmet.mdl",
		mat = "models/jmod_dayz/helmets/skate_helmet/skate_helmet_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 2.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 95,
		ent = "ent_jack_gmod_ezarmor_skateblue"
	},
	
			["Skate Helmet Red"] = {
		PrintName = "[CHLM] Skate Helmet (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_skate_helmet.mdl",
		mat = "models/jmod_dayz/helmets/skate_helmet/skate_helmet_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.6, 2.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 95,
		ent = "ent_jack_gmod_ezarmor_skatered"
	},
	
			["Hockey Helmet White"] = {
		PrintName = "[CHLM] Hockey Helmet (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hockey_helmet.mdl",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(1, 1.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_hockeywhite"
	},
	
			["Hockey Helmet Red"] = {
		PrintName = "[CHLM] Hockey Helmet (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hockey_helmet.mdl",
		mat = "models/jmod_dayz/helmets/hockey_helmet/hockey_helmet_red",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(1, 1.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_hockeyred"
	},
	
			["Hockey Helmet Blue"] = {
		PrintName = "[CHLM] Hockey Helmet (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hockey_helmet.mdl",
		mat = "models/jmod_dayz/helmets/hockey_helmet/hockey_helmet_blue",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(1, 1.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_hockeyblue"
	},
	
			["Hockey Helmet Black"] = {
		PrintName = "[CHLM] Hockey Helmet (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hockey_helmet.mdl",
		mat = "models/jmod_dayz/helmets/hockey_helmet/hockey_helmet_black",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(1, 1.5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_hockeyblack"
	},
	
			["Enduro Helmet Green"] = {
		PrintName = "[CHLM] Enduro Helmet (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet.mdl",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurogreen"
	},
	
			["Enduro Helmet Red"] = {
		PrintName = "[CHLM] Enduro Helmet (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_red",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurored"
	},
	
			["Enduro Helmet Black"] = {
		PrintName = "[CHLM] Enduro Helmet (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_black",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_enduroblack"
	},
	
			["Enduro Helmet Blue"] = {
		PrintName = "[CHLM] Enduro Helmet (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_blue",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_enduroblue"
	},
	
			["Enduro Helmet Chernarus"] = {
		PrintName = "[CHLM] Enduro Helmet (chernarus)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_chernarus",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurochernarus"
	},
	
			["Enduro Helmet Khaki"] = {
		PrintName = "[CHLM] Enduro Helmet (khaki)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_khaki",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurokhaki"
	},
	
			["Enduro Helmet Police"] = {
		PrintName = "[CHLM] Enduro Helmet (police)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_police",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_enduropolice"
	},
	
			["Enduro Helmet Visor Green"] = {
		PrintName = "[CHLM] Enduro Helmet Visor (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_visor.mdl",
		slots = {
			visor = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurovisorgreen"
	},
	
			["Enduro Helmet Visor Red"] = {
		PrintName = "[CHLM] Enduro Helmet Visor (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_visor.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_red",
		slots = {
			visor = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurovisorred"
	},
	
			["Enduro Helmet Visor Black"] = {
		PrintName = "[CHLM] Enduro Helmet Visor (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_visor.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_black",
		slots = {
			visor = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurovisorblack"
	},
	
			["Enduro Helmet Visor Khaki"] = {
		PrintName = "[CHLM] Enduro Helmet Visor (khaki)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_visor.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_khaki",
		slots = {
			visor = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurovisorkhaki"
	},
	
			["Enduro Helmet Visor Blue"] = {
		PrintName = "[CHLM] Enduro Helmet Visor (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_visor.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_blue",
		slots = {
			visor = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurovisorblue"
	},
	
			["Enduro Helmet Visor Chernarus"] = {
		PrintName = "[CHLM] Enduro Helmet Visor (chernarus)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_visor.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_chernarus",
		slots = {
			visor = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_endurovisorchernarus"
	},
	
			["Enduro Helmet Mouthguard Green"] = {
		PrintName = "[CHLM] Enduro Helmet Mouthguard (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_mouth.mdl",
		slots = {
			mouthnose = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_enduromouthgreen"
	},
	
			["Enduro Helmet Mouthguard Black"] = {
		PrintName = "[CHLM] Enduro Helmet Mouthguard (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_mouth.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_black",
		slots = {
			mouthnose = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_enduromouthblack"
	},
	
			["Enduro Helmet Mouthguard Blue"] = {
		PrintName = "[CHLM] Enduro Helmet Mouthguard (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_mouth.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_blue",
		slots = {
			mouthnose = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_enduromouthblue"
	},
	
			["Enduro Helmet Mouthguard Red"] = {
		PrintName = "[CHLM] Enduro Helmet Mouthguard (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_mouth.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_red",
		slots = {
			mouthnose = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_enduromouthred"
	},
	
			["Enduro Helmet Mouthguard Khaki"] = {
		PrintName = "[CHLM] Enduro Helmet Mouthguard (khaki)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_mouth.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_khaki",
		slots = {
			mouthnose = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_enduromouthkhaki"
	},
	
			["Enduro Helmet Mouthguard Chernarus"] = {
		PrintName = "[CHLM] Enduro Helmet Mouthguard (chernarus)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_enduro_helmet_mouth.mdl",
		mat = "models/jmod_dayz/helmets/enduro_helmet/enduro_helmet_chernarus",
		slots = {
			mouthnose = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(0.7, 1.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_enduromouthchernarus"
	},
	
			["Hard Helmet Yellow"] = {
		PrintName = "[CHLM] Hard Helmet Yellow (yellow)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hard_hat.mdl",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.1, 5.4, 0),
		ang = Angle(-73, 0, -90),
		wgt = 10,
		dur = 90,
		ent = "ent_jack_gmod_ezarmor_hardyellow"
	},
	
			["Hard Helmet White"] = {
		PrintName = "[CHLM] Hard Helmet Yellow (white)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hard_hat.mdl",
		mat = "models/jmod_dayz/helmets/hard_helmet/hard_hat_white",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.1, 5.4, 0),
		ang = Angle(-73, 0, -90),
		wgt = 10,
		dur = 90,
		ent = "ent_jack_gmod_ezarmor_hardwhite"
	},
	
			["Hard Helmet Red"] = {
		PrintName = "[CHLM] Hard Helmet Yellow (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hard_hat.mdl",
		mat = "models/jmod_dayz/helmets/hard_helmet/hard_hat_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.1, 5.4, 0),
		ang = Angle(-73, 0, -90),
		wgt = 10,
		dur = 90,
		ent = "ent_jack_gmod_ezarmor_hardred"
	},
	
			["Hard Helmet Blue"] = {
		PrintName = "[CHLM] Hard Helmet Yellow (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hard_hat.mdl",
		mat = "models/jmod_dayz/helmets/hard_helmet/hard_hat_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.1, 5.4, 0),
		ang = Angle(-73, 0, -90),
		wgt = 10,
		dur = 90,
		ent = "ent_jack_gmod_ezarmor_hardblue"
	},
	
			["Hard Helmet Lime"] = {
		PrintName = "[CHLM] Hard Helmet Yellow (lime)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hard_hat.mdl",
		mat = "models/jmod_dayz/helmets/hard_helmet/hard_hat_lime",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.1, 5.4, 0),
		ang = Angle(-73, 0, -90),
		wgt = 10,
		dur = 90,
		ent = "ent_jack_gmod_ezarmor_hardlime"
	},
	
			["Hard Helmet Orange"] = {
		PrintName = "[CHLM] Hard Helmet Yellow (orange)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_hard_hat.mdl",
		mat = "models/jmod_dayz/helmets/hard_helmet/hard_hat_orange",
		slots = {
			head = 1,
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.04, 1, 1),
		pos = Vector(0.1, 5.4, 0),
		ang = Angle(-73, 0, -90),
		wgt = 10,
		dur = 90,
		ent = "ent_jack_gmod_ezarmor_hardorange"
	},
	
			["Firefighter Helmet Red"] = {
		PrintName = "[CHLM] Firefighter Helmet (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_firehelmet_red.mdl",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(0.1, 3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_firered"
	},

			["Firefighter Helmet Yellow"] = {
		PrintName = "[CHLM] Firefighter Helmet (yellow)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_firehelmet_yellow.mdl",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(0.1, 3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_fireyellow"
	},
	
			["Firefighter Helmet White"] = {
		PrintName = "[CHLM] Firefighter Helmet (white)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/helmets/ht_firehelmet_white.mdl",
		slots = {
			head = 1,
			ears = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(0.1, 3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_firewhite"
	},
	
-- FACE

	["NBC Gasmask"] = {
		PrintName = "[GM] NBC Gasmask",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/face/fe_nbc_respirator.mdl",
		slots = {
			eyes = 1,
			mouthnose = 1
		},
		def = table.Inherit({
			[DMG_NERVEGAS] = 1,
			[DMG_RADIATION] = .75
		}, NonArmorProtectionProfile),
		dur = 2,
		chrg = {
			chemicals = 25
		},
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(2.6, 1.8, 0),
		ang = Angle(100, 180, 90),
		wgt = 5,
		dur = 50,
		mskmat = "vision_sprites_dayz/gasmask.png",
		sndlop = "snds_jack_gmod/mask_breathe.ogg",
		ent = "ent_jack_gmod_ezarmor_nbcgas",
	},

			["Combat Gas Mask"] = {
		PrintName = "[GM] Combat Gas Mask",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/face/fe_combat_gasmask.mdl",
		slots = {
			eyes = 1,
			mouthnose = 1
		},
		def = table.Inherit({
			[DMG_NERVEGAS] = 1,
			[DMG_RADIATION] = .75
		}, NonArmorProtectionProfile),
		dur = 2,
		chrg = {
			chemicals = 25
		},
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1.03),
		pos = Vector(1.3, 2.1, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 50,
		mskmat = "vision_sprites_dayz/gasmask.png",
		sndlop = "snds_jack_gmod/mask_breathe.ogg",
		ent = "ent_jack_gmod_ezarmor_combatgas"
	},
	
			["Gas Mask"] = {
		PrintName = "[GM] Gas Mask",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/face/fe_gp5.mdl",
		slots = {
			mouthnose = 1,
			eyes = 1
		},
		def = table.Inherit({
			[DMG_NERVEGAS] = 1,
			[DMG_RADIATION] = .75
		}, NonArmorProtectionProfile),
		dur = 2,
		chrg = {
			chemicals = 25
		},

		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1.02, 1.03),
		pos = Vector(2.5, 2.6, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 50,
		mskmat = "vision_sprites_dayz/gasmask.png",
		sndlop = "snds_jack_gmod/mask_breathe.ogg",
		ent = "ent_jack_gmod_ezarmor_gp5"
	},
	
			["Hockey Mask"] = {
		PrintName = "[FE] Hockey Mask",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/face/fe_hockey_mask.mdl",
		slots = {
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = StabVestProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(1.6, 3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hockeymask"
	},
	
			["Mime Mask Male"] = {
		PrintName = "[FE] Mime Mask (male)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/face/fe_mime_mask.mdl",
		slots = {
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(1.8, 2.5, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_mime_mask_male"
	},
	
			["Mime Mask Female"] = {
		PrintName = "[FE] Mime Mask (female)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/face/fe_mime_mask.mdl",
		mat = "models/jmod_dayz/face/mime_mask/mime_mask_female",
		slots = {
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(1.8, 2.5, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_mime_mask_female"
	},
	
-- BACKPACKS


			["Canvas Bag"] = {
		PrintName = "[BP] Canvas Bag",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_canvas_bag.mdl",
		slots = {
			back = 1,
		},
		storage = 25,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1.1, 1, 1),
		pos = Vector(-3, -4, 0),
		ang = Angle(-90, 0, 80),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_canvas"
	},
	
			["Canvas Bag Med"] = {
		PrintName = "[BP] Canvas Bag (med)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_canvas_bag.mdl",
		mat = "models/jmod_dayz/backpacks/canvas_bag/canvas_bag_med",
		slots = {
			back = 1,
		},
		storage = 25,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1.1, 1, 1),
		pos = Vector(-3, -4, 0),
		ang = Angle(-90, 0, 80),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_canvasmed"
	},
	
			["Duffel Bag"] = {
		PrintName = "[BP] Duffel Bag",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_duffel_bag.mdl",
		slots = {
			back = 1,
		},
		storage = 25,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(5, -11, -2),
		ang = Angle(-90, 0, 80),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_duffel"
	},
	
			["Duffel Bag Camo"] = {
		PrintName = "[BP] Duffel Bag (camo)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_duffel_bag.mdl",
		mat = "models/jmod_dayz/backpacks/duffel_bag/duffel_bag_camo",
		slots = {
			back = 1,
		},
		storage = 25,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(5, -11, -2),
		ang = Angle(-90, 0, 80),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_duffelcamo"
	},
	
			["Duffel Bag Med"] = {
		PrintName = "[BP] Duffel Bag (med)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_duffel_bag.mdl",
		mat = "models/jmod_dayz/backpacks/duffel_bag/duffel_bag_med",
		slots = {
			back = 1,
		},
		storage = 25,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(5, -11, -2),
		ang = Angle(-90, 0, 80),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_duffelmed"
	},
	
			["Mountain Backpack Green"] = {
		PrintName = "[BP] Mountain Backpack (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_mountain_backpack.mdl",
		slots = {
			back = 1,
		},
		storage = 56,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 1.2, 0),
		ang = Angle(-80, 0, 90),
		wgt = 15,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_mountaingreen"
	},
	
			["Mountain Backpack Red"] = {
		PrintName = "[BP] Mountain Backpack (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_mountain_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/mountain_backpack/mountain_backpack_red",
		slots = {
			back = 1,
		},
		storage = 56,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 1.2, 0),
		ang = Angle(-80, 0, 90),
		wgt = 15,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_mountainred"
	},
	
			["Mountain Backpack Blue"] = {
		PrintName = "[BP] Mountain Backpack (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_mountain_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/mountain_backpack/mountain_backpack_blue",
		slots = {
			back = 1,
		},
		storage = 56,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 1.2, 0),
		ang = Angle(-80, 0, 90),
		wgt = 15,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_mountainblue"
	},
	
			["Mountain Backpack Orange"] = {
		PrintName = "[BP] Mountain Backpack (orange)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_mountain_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/mountain_backpack/mountain_backpack_orange",
		slots = {
			back = 1,
		},
		storage = 56,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 1.2, 0),
		ang = Angle(-80, 0, 90),
		wgt = 15,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_mountainorange"
	},
	
			["Hunter Backpack"] = {
		PrintName = "[BP] Hunter Backpack",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_hunter_backpack.mdl",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, -0.9, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hunterbackpack"
	},
	
			["Hannah's Hunter Backpack"] = {
		PrintName = "[BP] Hannah's Hunter Backpack",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_hannahs_hunter_backpack.mdl",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, -0.9, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hannahshunter"
	},
	
			["Hiking Backpack Green"] = {
		PrintName = "[BP] Hiking Backpack (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_hiking_backpack.mdl",
		slots = {
			back = 1,
		},
		storage = 20,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6, 0.5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 15,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hikinggreen"
	},
	
			["Hiking Backpack Orange"] = {
		PrintName = "[BP] Hiking Backpack (orange)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_hiking_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/hiking_backpack/hiking_backpack_orange",
		slots = {
			back = 1,
		},
		storage = 20,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6, 0.5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 15,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hikingorange"
	},
	
			["Hiking Backpack Blue"] = {
		PrintName = "[BP] Hiking Backpack (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_hiking_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/hiking_backpack/hiking_backpack_blue",
		slots = {
			back = 1,
		},
		storage = 20,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6, 0.5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 15,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hikingblue"
	},
	
			["Hiking Backpack Violet"] = {
		PrintName = "[BP] Hiking Backpack (violet)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_hiking_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/hiking_backpack/hiking_backpack_violet",
		slots = {
			back = 1,
		},
		storage = 20,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6, 0.5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 15,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hikingviolet"
	},
	
			["School Backpack Red"] = {
		PrintName = "[BP] School Backpack (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_school_backpack.mdl",
		slots = {
			back = 1,
		},
		storage = 24,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(5, 5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_schoolred"
	},
	
			["School Backpack Blue"] = {
		PrintName = "[BP] School Backpack (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_school_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/school_backpack/school_backpack_blue",
		slots = {
			back = 1,
		},
		storage = 24,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(5, 5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_schoolblue"
	},
	
			["School Backpack Green"] = {
		PrintName = "[BP] School Backpack (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_school_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/school_backpack/school_backpack_green",
		slots = {
			back = 1,
		},
		storage = 24,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(5, 5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_schoolgreen"
	},
	
			["Assault Backpack Green"] = {
		PrintName = "[BP] Assault Backpack (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_assault_backpack.mdl",
		slots = {
			back = 1,
		},
		storage = 36,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6, 2, 0),
		ang = Angle(-85, 0, 90),
		wgt = 18,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_assaultbackpackgreen"
	},
	
			["Assault Backpack TTsKO"] = {
		PrintName = "[BP] Assault Backpack (ttsko)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_assault_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/assault_backpack/assault_backpack_ttsko",
		slots = {
			back = 1,
		},
		storage = 36,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6, 2, 0),
		ang = Angle(-85, 0, 90),
		wgt = 18,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_assaultbackpackttsko"
	},
	
			["Assault Backpack Black"] = {
		PrintName = "[BP] Assault Backpack (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_assault_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/assault_backpack/assault_backpack_black",
		slots = {
			back = 1,
		},
		storage = 36,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6, 2, 0),
		ang = Angle(-85, 0, 90),
		wgt = 18,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_assaultbackpackblack"
	},
	
			["Assault Backpack Winter"] = {
		PrintName = "[BP] Assault Backpack (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_assault_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/assault_backpack/assault_backpack_winter",
		slots = {
			back = 1,
		},
		storage = 36,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6, 2, 0),
		ang = Angle(-85, 0, 90),
		wgt = 18,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_assaultbackpackwinter"
	},
	
			["Field Backpack Green"] = {
		PrintName = "[BP] Field Backpack (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_field_backpack.mdl",
		slots = {
			back = 1,
		},
		storage = 64,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 1.4, 0),
		ang = Angle(-85, 0, 90),
		wgt = 25,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_fieldbackpackgreen"
	},
	
			["Field Backpack Black"] = {
		PrintName = "[BP] Field Backpack (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_field_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/field_backpack/field_backpack_black",
		slots = {
			back = 1,
		},
		storage = 64,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 1.4, 0),
		ang = Angle(-85, 0, 90),
		wgt = 25,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_fieldbackpackblack"
	},
	
			["Field Backpack Camo"] = {
		PrintName = "[BP] Field Backpack (camo)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_field_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/field_backpack/field_backpack_camo",
		slots = {
			back = 1,
		},
		storage = 64,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 1.4, 0),
		ang = Angle(-85, 0, 90),
		wgt = 25,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_fieldbackpackcamo"
	},
	
			["Dry Backpack Blue"] = {
		PrintName = "[BP] Dry Backpack (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_drybag_backpack.mdl",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 0.7, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_drybagblue"
	},
	
			["Dry Backpack Black"] = {
		PrintName = "[BP] Dry Backpack (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_drybag_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/drybag_backpack/drybag_black",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 0.7, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_drybagblack"
	},

			["Dry Backpack Orange"] = {
		PrintName = "[BP] Dry Backpack (orange)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_drybag_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/drybag_backpack/drybag_orange",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 0.7, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_drybagorange"
	},
	
			["Dry Backpack Red"] = {
		PrintName = "[BP] Dry Backpack (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_drybag_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/drybag_backpack/drybag_red",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 0.7, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_drybagred"
	},
	
			["Dry Backpack Yellow"] = {
		PrintName = "[BP] Dry Backpack (yellow)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_drybag_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/drybag_backpack/drybag_yellow",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 0.7, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_drybagyellow"
	},
	
			["Dry Backpack Green"] = {
		PrintName = "[BP] Dry Backpack (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_drybag_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/drybag_backpack/drybag_green",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(7, 0.7, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_drybaggreen"
	},
	
			["Tactical Backpack Tan"] = {
		PrintName = "[BP] Tactical Backpack (tan)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_tactical_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/tactical_backpack/tactical_backpack_tan",
		slots = {
			back = 1,
		},
		storage = 56,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6.3, 0.9, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_tacticalbackpack_tan"
	},
	
			["Tactical Backpack Green"] = {
		PrintName = "[BP] Tactical Backpack (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_tactical_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/tactical_backpack/tactical_backpack_green",
		slots = {
			back = 1,
		},
		storage = 56,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6.3, 0.9, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_tacticalbackpack_green"
	},
	
			["Tactical Backpack Winter"] = {
		PrintName = "[BP] Tactical Backpack (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_tactical_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/tactical_backpack/tactical_backpack_winter",
		slots = {
			back = 1,
		},
		storage = 56,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6.3, 0.9, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_tacticalbackpack_winter"
	},
	
			["Combat Backpack Green"] = {
		PrintName = "[BP] Combat Backpack (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_combat_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/combat_backpack/combat_backpack_green",
		slots = {
			back = 1,
		},
		storage = 56,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6.8, -0.6, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_combatbackpack_green"
	},
	
			["Combat Backpack Winter"] = {
		PrintName = "[BP] Combat Backpack (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_combat_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/combat_backpack/combat_backpack_winter",
		slots = {
			back = 1,
		},
		storage = 56,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(6.8, -0.6, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_combatbackpack_winter"
	},
	
			["Burlap Backpack"] = {
		PrintName = "[BP] Burlap Backpack",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_burlap_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/burlap_backpack/burlap_backpack",
		slots = {
			back = 1,
		},
		storage = 35,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(4.5, -0.5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_burlapbackpack"
	},
	
			["Burlap Backpack Fur"] = {
		PrintName = "[BP] Fur Backpack",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_burlap_backpack.mdl",
		mat = "models/jmod_dayz/backpacks/burlap_backpack/burlap_backpack_fur",
		slots = {
			back = 1,
		},
		storage = 35,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(4.5, -0.5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_burlapbackpack_fur"
	},
	
			["Burlap courier Bag"] = {
		PrintName = "[BP] Burlap courier Bag",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_burlap_courier_bag.mdl",
		mat = "models/jmod_dayz/backpacks/burlap_courier_bag/burlap_courier_bag",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(4.5, -0.5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_burlapcourier"
	},
	
			["Fur courier Bag"] = {
		PrintName = "[BP] Fur courier Bag",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_burlap_courier_bag.mdl",
		mat = "models/jmod_dayz/backpacks/burlap_courier_bag/fur_courier_bag",
		slots = {
			back = 1,
		},
		storage = 30,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(4.5, -0.5, 0),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_furcourier"
	},
	
			["Slung Bag Black"] = {
		PrintName = "[BP] Slung Bag (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_sling_bag.mdl",
		mat = "models/jmod_dayz/backpacks/sling_bag/sling_bag_black",
		slots = {
			back = 1,
		},
		storage = 20,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(4.5, -5, -0.3),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_slingbag_black"
	},
	
			["Slung Bag Brown"] = {
		PrintName = "[BP] Slung Bag (brown)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_sling_bag.mdl",
		mat = "models/jmod_dayz/backpacks/sling_bag/sling_bag_brown",
		slots = {
			back = 1,
		},
		storage = 20,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(4.5, -5, -0.3),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_slingbag_brown"
	},
	
			["Slung Bag Gray"] = {
		PrintName = "[BP] Slung Bag (gray)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bp_sling_bag.mdl",
		mat = "models/jmod_dayz/backpacks/sling_bag/sling_bag_gray",
		slots = {
			back = 1,
		},
		storage = 20,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(4.5, -5, -0.3),
		ang = Angle(-85, 0, 90),
		wgt = 10,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_slingbag_gray"
	},
	
-- RADIO

			["Walkie Talkie hip"] = {
		PrintName = "[CD] Walkie Talkie",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/radio/cd_walkie_talkie.mdl",
		slots = {
			pelvis = 1
		},
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Pelvis",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(1, 6, -5),
		ang = Angle(-6, 50, -90),
		wgt = 2,
		dur = 15,
		chrg = {
			power = 35
		},
		ent = "ent_jack_gmod_ezarmor_walkie_talkie_hip",
		eff = {
			teamComms = true,
			earPro = true
		},
		tgl = {
			eff = {},
			slots = {
				pelvis = 1
			},
		}
	},
	
			["Field Transceiver"] = {
		PrintName = "[CD] Field Transceiver",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/radio/cd_field_transceiver.mdl",
		slots = {
			back = 1,
		},
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Spine2",
		clrForced = true,
		bdg = {
			[0] = 1
		},
		siz = Vector(1, 1, 1),
		pos = Vector(7, 1, 0),
		ang = Angle(-90, 0, 90),
		wgt = 10,
		dur = 120,
		chrg = {
			power = 100
		},
		ent = "ent_jack_gmod_ezarmor_field_transceiver",
		eff = {
			teamComms = true,
			earPro = true
		},
		tgl = {
			eff = {},
			slots = {
				pelvis = 1
			},
		}
	},

-- BELTS


			["Hip Pack Black"] = {
		PrintName = "[BT] Hip Pack Black (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bt_hip_pack.mdl",
		slots = {
			pelvis = 1,
		},
		storage = 8,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Pelvis",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(0.6, 0, -0.5),
		ang = Angle(-0, -85, -90),
		wgt = 5,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hippackblack"
	},
	
			["Hip Pack Green"] = {
		PrintName = "[BT] Hip Pack Black (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bt_hip_pack.mdl",
		mat = "models/jmod_dayz/belts/hip_pack/hip_pack_green",
		slots = {
			pelvis = 1,
		},
		storage = 8,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Pelvis",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(0.6, 0, -0.5),
		ang = Angle(-0, -85, -90),
		wgt = 5,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hippackgreen"
	},

			["Hip Pack Party"] = {
		PrintName = "[BT] Hip Pack Black (party)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bt_hip_pack.mdl",
		mat = "models/jmod_dayz/belts/hip_pack/hip_pack_party",
		slots = {
			pelvis = 1,
		},
		storage = 8,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Pelvis",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(0.6, 0, -0.5),
		ang = Angle(-0, -85, -90),
		wgt = 5,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hippackparty"
	},
	
			["Hip Pack med"] = {
		PrintName = "[BT] Hip Pack Black (med)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/backpacks/bt_hip_pack.mdl",
		mat = "models/jmod_dayz/belts/hip_pack/hip_pack_med",
		slots = {
			pelvis = 1,
		},
		storage = 8,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Pelvis",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(0.6, 0, -0.5),
		ang = Angle(-0, -85, -90),
		wgt = 5,
		dur = 120,
		ent = "ent_jack_gmod_ezarmor_hippackmed"
	},
	
-- MISC

			["Burlap Sack"] = {
		PrintName = "[MS] Burlap Sack",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/misc/ms_burlap_sack.mdl",
		mskmat = "vision_sprites_dayz/burlap_sack.png",
		slots = {
			head = 1,
			ears = 1,
			mouthnose = 1,
			eyes = 1
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1, 1),
		pos = Vector(1.2, 3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_burlapsack"
	},

-- GHILLIE

			["Ghille Hood Green"] = {
		PrintName = "[GH] Ghille Hood Green (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hs_ghillie_hood.mdl",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(1, 1, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_ghillegreen"
	},
	

-- HATS

	
			["Baseball Cap Black"] = {
		PrintName = "[HW] Baseball Cap (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_baseball_cap.mdl",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-0.16, 5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_baseballcap_black"
	},
	
			["Baseball Cap olive"] = {
		PrintName = "[HW] Baseball Cap (olive)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_baseball_cap.mdl",
		mat = "models/jmod_dayz/hats/baseball_cap/baseball_cap_olive",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-0.2, 5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_baseballcap_olive"
	},
	
			["Baseball Cap blue"] = {
		PrintName = "[HW] Baseball Cap (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_baseball_cap.mdl",
		mat = "models/jmod_dayz/hats/baseball_cap/baseball_cap_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-0.2, 5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_baseballcap_blue"
	},
	
			["Baseball Cap beige"] = {
		PrintName = "[HW] Baseball Cap (beige)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_baseball_cap.mdl",
		mat = "models/jmod_dayz/hats/baseball_cap/baseball_cap_beige",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-0.2, 5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_baseballcap_beige"
	},
	
			["Baseball Cap camo"] = {
		PrintName = "[HW] Baseball Cap (camo)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_baseball_cap.mdl",
		mat = "models/jmod_dayz/hats/baseball_cap/baseball_cap_camo",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-0.2, 5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_baseballcap_camo"
	},
	
			["Baseball Cap pink"] = {
		PrintName = "[HW] Baseball Cap (pink)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_baseball_cap.mdl",
		mat = "models/jmod_dayz/hats/baseball_cap/baseball_cap_pink",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-0.2, 5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_baseballcap_pink"
	},
	
			["Baseball Cap red"] = {
		PrintName = "[HW] Baseball Cap (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_baseball_cap.mdl",
		mat = "models/jmod_dayz/hats/baseball_cap/baseball_cap_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-0.2, 5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_baseballcap_red"
	},
	
			["Baseball Cap cmmg black"] = {
		PrintName = "[HW] Baseball Cap (cmmg black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_baseball_cap.mdl",
		mat = "models/jmod_dayz/hats/baseball_cap/baseball_cap_cmmg_black",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-0.2, 5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_baseballcap_cmmg_black"
	},
	
			["Baseball Cap cmmg pink"] = {
		PrintName = "[HW] Baseball Cap (cmmg pink)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_baseball_cap.mdl",
		mat = "models/jmod_dayz/hats/baseball_cap/baseball_cap_cmmg_pink",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 1, 1),
		pos = Vector(-0.2, 5, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_baseballcap_cmmg_pink"
	},
	
			["Boonie Hat Black"] = {
		PrintName = "[HW] Boonie Hat (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_black"
	},
	
			["Boonie Hat blue"] = {
		PrintName = "[HW] Boonie Hat (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_blue"
	},
	
			["Boonie Hat navyblue"] = {
		PrintName = "[HW] Boonie Hat (navy blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_navyblue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_navyblue"
	},
	
			["Boonie Hat orange"] = {
		PrintName = "[HW] Boonie Hat (orange)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_orange",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_orange"
	},
	
			["Boonie Hat red"] = {
		PrintName = "[HW] Boonie Hat (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_red"
	},
	
			["Boonie Hat olive"] = {
		PrintName = "[HW] Boonie Hat (olive)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_olive",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_olive"
	},
	
			["Boonie Hat tan"] = {
		PrintName = "[HW] Boonie Hat (tan)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_tan",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_tan"
	},
	
			["Boonie Hat winter"] = {
		PrintName = "[HW] Boonie Hat (winter)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_winter",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_winter"
	},
	
			["Boonie Hat dubok"] = {
		PrintName = "[HW] Boonie Hat (dubok)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_dubok",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_dubok"
	},
	
			["Boonie Hat dpm"] = {
		PrintName = "[HW] Boonie Hat (dpm)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_dpm",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_dpm"
	},
	
			["Boonie Hat flecktarn"] = {
		PrintName = "[HW] Boonie Hat (flecktarn)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_boonie_hat.mdl",
		mat = "models/jmod_dayz/hats/boonie_hat/boonie_hat_flecktarn",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1., 1, 1),
		pos = Vector(0.1, 5.3, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_boonie_flecktarn"
	},
	
			["beanie black"] = {
		PrintName = "[HW] Beanie (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_black",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_black"
	},
	
			["beanie blue"] = {
		PrintName = "[HW] Beanie (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_blue"
	},
	
			["beanie brown"] = {
		PrintName = "[HW] Beanie (brown)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_brown",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_brown"
	},
	
			["beanie beige"] = {
		PrintName = "[HW] Beanie (beige)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_beige",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_beige"
	},
	
			["beanie red"] = {
		PrintName = "[HW] Beanie (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_red"
	},
	
			["beanie green"] = {
		PrintName = "[HW] Beanie (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_green",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_green"
	},
	
			["beanie brown"] = {
		PrintName = "[HW] Beanie (brown)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_brown",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_brown"
	},
	
			["beanie gray"] = {
		PrintName = "[HW] Beanie (gray)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_gray",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_gray"
	},
	
			["beanie pink"] = {
		PrintName = "[HW] Beanie (pink)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_pink",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_pink"
	},
	
			["beanie red"] = {
		PrintName = "[HW] Beanie (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_beanie.mdl",
		mat = "models/jmod_dayz/hats/beanie/beanie_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.02, 1, 1),
		pos = Vector(-0.3, 4.4, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_beanie_red"
	},
	
			["Cowboy Hat black"] = {
		PrintName = "[HW] Cowboy Hat (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_cowboy_hat.mdl",
		mat = "models/jmod_dayz/hats/cowboy_hat/cowboy_hat_black",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(-0.3, 6, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_cowboy_black"
	},
	
			["Cowboy Hat brown"] = {
		PrintName = "[HW] Cowboy Hat (brown)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_cowboy_hat.mdl",
		mat = "models/jmod_dayz/hats/cowboy_hat/cowboy_hat_brown",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(-0.3, 6, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_cowboy_brown"
	},
	
			["Cowboy Hat darkbrown"] = {
		PrintName = "[HW] Cowboy Hat (dark brown)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_cowboy_hat.mdl",
		mat = "models/jmod_dayz/hats/cowboy_hat/cowboy_hat_darkbrown",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(-0.3, 6, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_cowboy_darkbrown"
	},
	
			["Cowboy Hat green"] = {
		PrintName = "[HW] Cowboy Hat (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_cowboy_hat.mdl",
		mat = "models/jmod_dayz/hats/cowboy_hat/cowboy_hat_green",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(-0.3, 6, -0.1),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_cowboy_green"
	},
	
			["Ushanka green"] = {
		PrintName = "[HW] Ushanka (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_ushanka.mdl",
		mat = "models/jmod_dayz/hats/ushanka/ushanka_green",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 0.9, 0.9),
		pos = Vector(0.3, 4.3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_ushanka_green"
	},
	
			["Ushanka black"] = {
		PrintName = "[HW] Ushanka (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_ushanka.mdl",
		mat = "models/jmod_dayz/hats/ushanka/ushanka_black",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 0.9, 0.9),
		pos = Vector(0.3, 4.3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_ushanka_black"
	},
	
			["Ushanka blue"] = {
		PrintName = "[HW] Ushanka (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_ushanka.mdl",
		mat = "models/jmod_dayz/hats/ushanka/ushanka_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 0.9, 0.9),
		pos = Vector(0.3, 4.3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_ushanka_blue"
	},
	
			["Flat cap black"] = {
		PrintName = "[HW] Flat Cap (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_flat_cap.mdl",
		mat = "models/jmod_dayz/hats/flat_cap/flat_cap_black",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 0.9, 1),
		pos = Vector(-0.2, 6.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_flatcap_black"
	},
	
			["Flat cap blue"] = {
		PrintName = "[HW] Flat Cap (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_flat_cap.mdl",
		mat = "models/jmod_dayz/hats/flat_cap/flat_cap_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 0.9, 1),
		pos = Vector(-0.2, 6.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_flatcap_blue"
	},
	
			["Flat cap black_check"] = {
		PrintName = "[HW] Flat Cap (black check)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_flat_cap.mdl",
		mat = "models/jmod_dayz/hats/flat_cap/flat_cap_black_check",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 0.9, 1),
		pos = Vector(-0.2, 6.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_flatcap_black_check"
	},
	
			["Flat cap brown"] = {
		PrintName = "[HW] Flat Cap (brown)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_flat_cap.mdl",
		mat = "models/jmod_dayz/hats/flat_cap/flat_cap_brown",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 0.9, 1),
		pos = Vector(-0.2, 6.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_flatcap_brown"
	},
	
			["Flat cap brown_check"] = {
		PrintName = "[HW] Flat Cap (brown check)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_flat_cap.mdl",
		mat = "models/jmod_dayz/hats/flat_cap/flat_cap_brown_check",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 0.9, 1),
		pos = Vector(-0.2, 6.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_flatcap_brown_check"
	},
	
			["Flat cap gray"] = {
		PrintName = "[HW] Flat Cap (gray)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_flat_cap.mdl",
		mat = "models/jmod_dayz/hats/flat_cap/flat_cap_gray",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 0.9, 1),
		pos = Vector(-0.2, 6.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_flatcap_gray"
	},
	
			["Flat cap gray_check"] = {
		PrintName = "[HW] Flat Cap (gray check)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_flat_cap.mdl",
		mat = "models/jmod_dayz/hats/flat_cap/flat_cap_gray_check",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 0.9, 1),
		pos = Vector(-0.2, 6.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_flatcap_gray_check"
	},
	
			["Flat cap red"] = {
		PrintName = "[HW] Flat Cap (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_flat_cap.mdl",
		mat = "models/jmod_dayz/hats/flat_cap/flat_cap_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1, 0.9, 1),
		pos = Vector(-0.2, 6.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_flatcap_red"
	},
	
			["Sherpa Hat Black"] = {
		PrintName = "[HW] Sherpa Hat (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_sherpa_hat.mdl",
		mat = "models/jmod_dayz/hats/sherpa_hat/sherpa_hat_black",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1, 1),
		pos = Vector(0, 3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_sherpa_black"
	},
	
			["Sherpa Hat blue"] = {
		PrintName = "[HW] Sherpa Hat (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_sherpa_hat.mdl",
		mat = "models/jmod_dayz/hats/sherpa_hat/sherpa_hat_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1, 1),
		pos = Vector(0, 3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_sherpa_blue"
	},
	
			["Sherpa Hat red"] = {
		PrintName = "[HW] Sherpa Hat (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_sherpa_hat.mdl",
		mat = "models/jmod_dayz/hats/sherpa_hat/sherpa_hat_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1, 1),
		pos = Vector(0, 3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_sherpa_red"
	},
	
			["Zimovka black"] = {
		PrintName = "[HW] Zimovka (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_zimovka.mdl",
		mat = "models/jmod_dayz/hats/zimovka/zimovka_black",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1, 1),
		pos = Vector(0, 4.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_zimovka_black"
	},
	
			["Zimovka blue"] = {
		PrintName = "[HW] Zimovka (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_zimovka.mdl",
		mat = "models/jmod_dayz/hats/zimovka/zimovka_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1, 1),
		pos = Vector(0, 4.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_zimovka_blue"
	},
	
			["Zimovka brown"] = {
		PrintName = "[HW] Zimovka (brown)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_zimovka.mdl",
		mat = "models/jmod_dayz/hats/zimovka/zimovka_brown",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1, 1),
		pos = Vector(0, 4.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_zimovka_brown"
	},
	
			["Zimovka green"] = {
		PrintName = "[HW] Zimovka (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_zimovka.mdl",
		mat = "models/jmod_dayz/hats/zimovka/zimovka_green",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1, 1),
		pos = Vector(0, 4.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_zimovka_green"
	},
	
			["Zimovka red"] = {
		PrintName = "[HW] Zimovka (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_zimovka.mdl",
		mat = "models/jmod_dayz/hats/zimovka/zimovka_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.06, 1, 1),
		pos = Vector(0, 4.4, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_zimovka_red"
	},
	
			["Wolf Headdress"] = {
		PrintName = "[HW] Wolf Headdress",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_headdress.mdl",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.1, 0.9, 0.9),
		pos = Vector(-0.2, 2, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_headdress"
	},
	
			["Radar Cap Black"] = {
		PrintName = "[HW] Radar Cap (black)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_radar_cap.mdl",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.07, 1, 1),
		pos = Vector(-0.1, 4.3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_radar_cap_black"
	},
	
			["Radar Cap blue"] = {
		PrintName = "[HW] Radar Cap (blue)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_radar_cap.mdl",
		mat = "models/jmod_dayz/hats/radar_cap/radar_cap_blue",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.07, 1, 1),
		pos = Vector(-0.1, 4.3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_radar_cap_blue"
	},
	
			["Radar Cap brown"] = {
		PrintName = "[HW] Radar Cap (brown)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_radar_cap.mdl",
		mat = "models/jmod_dayz/hats/radar_cap/radar_cap_brown",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.07, 1, 1),
		pos = Vector(-0.1, 4.3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_radar_cap_brown"
	},
	
			["Radar Cap green"] = {
		PrintName = "[HW] Radar Cap (green)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_radar_cap.mdl",
		mat = "models/jmod_dayz/hats/radar_cap/radar_cap_green",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.07, 1, 1),
		pos = Vector(-0.1, 4.3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_radar_cap_green"
	},
	
			["Radar Cap red"] = {
		PrintName = "[HW] Radar Cap (red)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_radar_cap.mdl",
		mat = "models/jmod_dayz/hats/radar_cap/radar_cap_red",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.07, 1, 1),
		pos = Vector(-0.1, 4.3, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_radar_cap_red"
	},
	
			["Snowstorm Ushanka Brown"] = {
		PrintName = "[HW] Snowstorm Ushanka (brown)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_snowstorm_ushanka.mdl",
		mat = "models/jmod_dayz/hats/snowstorm_ushanka/snowstorm_ushanka_brown",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(1, 2, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_snowshtorm_ushanka_brown"
	},
	
			["Snowstorm Ushanka navy"] = {
		PrintName = "[HW] Snowstorm Ushanka (navy)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_snowstorm_ushanka.mdl",
		mat = "models/jmod_dayz/hats/snowstorm_ushanka/snowstorm_ushanka_navy",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(1, 2, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_snowshtorm_ushanka_navy"
	},
	
			["Snowstorm Ushanka olive"] = {
		PrintName = "[HW] Snowstorm Ushanka (olive)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_snowstorm_ushanka.mdl",
		mat = "models/jmod_dayz/hats/snowstorm_ushanka/snowstorm_ushanka_olive",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(1, 2, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_snowshtorm_ushanka_olive"
	},
	
			["Snowstorm Ushanka white"] = {
		PrintName = "[HW] Snowstorm Ushanka (white)",
		Category = "JMod - EZ DayZ Armor",
		mdl = "models/gruchk/jmod_dayz/hats/hw_snowstorm_ushanka.mdl",
		mat = "models/jmod_dayz/hats/snowstorm_ushanka/snowstorm_ushanka_white",
		slots = {
			head = 1,
		},
		storage = 0,
		def = NonArmorProtectionProfile,
		bon = "ValveBiped.Bip01_Head1",
		clrForced = true,
		siz = Vector(1.03, 1, 1),
		pos = Vector(1, 2, 0),
		ang = Angle(-80, 0, -90),
		wgt = 10,
		dur = 100,
		ent = "ent_jack_gmod_ezarmor_snowshtorm_ushanka_white"
	},
}



JMod.GenerateArmorEntities(JMod.DayZArmorTable)

local function LoadDayZArmor()
	if JMod.DayZArmorTable then
		table.Merge(JMod.ArmorTable, JMod.DayZArmorTable)
		JMod.GenerateArmorEntities(JMod.DayZArmorTable)
	end
end

hook.Add("Initialize", "JMod_LoadDayZArmor", LoadDayZArmor)

LoadDayZArmor()