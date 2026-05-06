local path = "/weapons/blast_m1garand/"
local pref = "blast_m1garand"
local hudcolor = Color(255, 255, 255, 255)

TFA.AddFireSound(pref .. ".1", {path .. "shoot.wav"}, true, ")")
TFA.AddWeaponSound(pref .. ".draw", path .. "draw.wav")
TFA.AddWeaponSound(pref .. ".holster", path .. "holster.wav")
TFA.AddWeaponSound(pref .. ".clipout", path .. "ping.wav")
TFA.AddWeaponSound(pref .. ".boltclose", path .. "boltclose.wav")
TFA.AddWeaponSound(pref .. ".boltback", path .. "boltback.wav")
TFA.AddWeaponSound(pref .. ".clipin", path .. "clipin.wav")
TFA.AddWeaponSound(pref .. ".dryfire", path .. "dryfire.wav")

if killicon and killicon.Add then
	killicon.Add("tfa_blast_m1garand", "vgui/killicons/tfa_blast_m1garand", hudcolor)
end