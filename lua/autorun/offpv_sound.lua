AddCSLuaFile()

sound.Add( {
    name = "offpv.equip",
    channel = CHAN_WEAPON,
    volume = 1,
    level = 65,
    pitch = {95, 100},
    sound = {
        "weapons/stalker2/pda/SFX_PDA_Equip_01.mp3",
		"weapons/stalker2/pda/SFX_PDA_Equip_02.mp3",
		"weapons/stalker2/pda/SFX_PDA_Equip_03.mp3",
    } 
} )

sound.Add( {
    name = "offpv.unequip",
    channel = CHAN_WEAPON,
    volume = 1,
    level = 65,
    pitch = {95, 100},
    sound = {
        "weapons/stalker2/pda/SFX_PDA_Unequip_01.mp3",
		"weapons/stalker2/pda/SFX_PDA_Unequip_02.mp3",
		"weapons/stalker2/pda/SFX_PDA_Unequip_03.mp3",
    }
} )

sound.Add( {
    name = "offpv.deploy",
    channel = CHAN_WEAPON,
    volume = 1,
    level = 80,
    pitch = {95, 100},
    sound = "weapons/of_fpv/nightvisionon.wav"
} )

sound.Add( {
    name = "offpv.select",
    channel = CHAN_WEAPON,
    volume = 1,
    level = 65,
    pitch = {95, 100},
    sound = {
        "weapons/of_fpv/select_01.wav",
        "weapons/of_fpv/select_02.wav",
        "weapons/of_fpv/select_03.wav",
    }
} )

sound.Add( {
    name = "offpv.alert",
    channel = CHAN_WEAPON,
    volume = 1,
    level = 65,
    pitch = {95, 100},
    sound = "weapons/of_fpv/alert.wav"
} )

sound.Add( {
    name = "offpv.explosion",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 120,
	pitch = {95, 110},
    sound = {
        "weapons/of_fpv/c4_detonate_01.wav",
        "weapons/of_fpv/c4_detonate_02.wav",
        "weapons/of_fpv/c4_detonate_03.wav",
    }
} )

sound.Add( {
    name = "offpv.ring",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 100,
	pitch = {95, 110},
    sound = "weapons/of_fpv/ied_ring.wav"
} )

sound.Add(
{
    name = "offpv.loop",
    channel = CHAN_STATIC,
    volume = 1.0,
	level = 85,
	pitch = {95, 110},
    sound = "weapons/of_fpv/loop.wav"
})