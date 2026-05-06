local CLASS = player.RegClass("arcsecuritygrunt")
local random_lines = {"vo/k_lab/ba_cantlook.wav", "vo/k_lab/ba_careful01.wav", "vo/k_lab/ba_careful02.wav", "vo/k_lab/ba_dontblameyou.wav", "vo/k_lab/ba_forgetthatthing.wav", "vo/k_lab/ba_getitoff01.wav", "vo/k_lab/ba_getoutofsight02.wav", "vo/k_lab/ba_getoutofsight01.wav", "vo/k_lab/ba_guh.wav", "vo/k_lab/ba_headhumper02.wav", "vo/k_lab/ba_hesback01.wav", "vo/k_lab/ba_hesback02.wav", "vo/k_lab/ba_ishehere.wav", "vo/k_lab/ba_itsworking01.wav", "vo/k_lab/ba_itsworking02.wav", "vo/k_lab/ba_itsworking03.wav", "vo/k_lab/ba_itsworking04.wav", "vo/k_lab/ba_longer.wav", "vo/k_lab/ba_myshift01.wav", "vo/k_lab/ba_myshift02.wav", "vo/k_lab/ba_notime.wav", "vo/k_lab/ba_nottoosoon01.wav", "vo/k_lab/ba_saidlasttime.wav", "vo/k_lab/ba_sarcastic02.wav", "vo/k_lab/ba_sarcastic03.wav", "vo/k_lab/ba_thatpest.wav", "vo/k_lab/ba_thereheis.wav", "vo/k_lab/ba_thereyouare.wav", "vo/k_lab/ba_thingaway01.wav", "vo/k_lab/ba_thingaway03.wav", "vo/k_lab/ba_whatthehell.wav", "vo/k_lab/ba_whoops.wav", "vo/k_lab2/ba_getgoing.wav", "vo/k_lab2/ba_goodnews.wav", "vo/k_lab2/ba_goodnews_c.wav", "vo/k_lab2/ba_incoming.wav", "vo/npc/barney/ba_bringiton.wav", "vo/npc/barney/ba_damnit.wav", "vo/npc/barney/ba_danger02.wav", "vo/npc/barney/ba_downyougo.wav", "vo/npc/barney/ba_duck.wav", "vo/npc/barney/ba_followme02.wav", "vo/npc/barney/ba_getaway.wav", "vo/npc/barney/ba_getdown.wav", "vo/npc/barney/ba_getoutofway.wav", "vo/npc/barney/ba_goingdown.wav", "vo/npc/barney/ba_hereitcomes.wav", "vo/npc/barney/ba_hurryup.wav", "vo/npc/barney/ba_imwithyou.wav", "vo/npc/barney/ba_laugh01.wav", "vo/npc/barney/ba_laugh02.wav", "vo/npc/barney/ba_laugh03.wav", "vo/npc/barney/ba_laugh04.wav", "vo/npc/barney/ba_letsdoit.wav", "vo/npc/barney/ba_letsgo.wav", "vo/npc/barney/ba_lookout.wav", "vo/npc/barney/ba_losttouch.wav", "vo/npc/barney/ba_ohyeah.wav", "vo/npc/barney/ba_yell.wav"}
local pain_lines = {"vo/k_lab/ba_thingaway02.wav", "vo/npc/barney/ba_no01.wav", "vo/npc/barney/ba_no02.wav", "vo/npc/barney/ba_ohshit03.wav", "vo/npc/barney/ba_pain01.wav", "vo/npc/barney/ba_pain02.wav", "vo/npc/barney/ba_pain03.wav", "vo/npc/barney/ba_pain04.wav", "vo/npc/barney/ba_pain05.wav", "vo/npc/barney/ba_pain06.wav", "vo/npc/barney/ba_pain07.wav", "vo/npc/barney/ba_pain08.wav", "vo/npc/barney/ba_pain09.wav", "vo/npc/barney/ba_pain10.wav", "vo/npc/barney/ba_wounded02.wav", "vo/npc/barney/ba_wounded03.wav"}
function CLASS.Off(self)
    if CLIENT then return end
end
function CLASS.Guilt(self, Victim)
    if CLIENT then return end
    if Victim:GetPlayerClass() == self:GetPlayerClass() then return 1 end
    return 1
end
hook.Add("HG_PlayerFootstep", "arcsecuritygrunt_footsteps", function(ply, pos, foot, sound, volume, rf)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply.PlayerClassName ~= "arcsecuritygrunt" then return end
    local ent = hg.GetCurrentCharacter(ply)
    if not (ply:IsWalking() or ply:Crouching()) and ent == ply then
        local snd = "zcitysnd/" .. string.Replace(sound, "player/footsteps", "player/footsteps_military/")
        if SoundDuration(snd) <= 0 then snd = sound end
        EmitSound(snd, pos, ply:EntIndex(), CHAN_AUTO, volume, 75, nil, math.random(95, 105))
        return true
    end
end)
local function giveRandomColor(ply)
    local color = math.random(1,2)
    if color == 1 then
        ply:SetPlayerColor(Color(8,0,129):ToVector())
    elseif color == 2 then
        ply:SetPlayerColor(Color(132,108,0):ToVector())
        ply:SetSkin(1)
    end
end
local function giveRandomGun(ply)
local primary = math.random(1,16)
if primary == 1 then
local m4a1 = ply:Give("weapon_m4a1")
if m4a1 then
ply:GiveAmmo(m4a1:GetMaxClip1() * 3.3, m4a1:GetPrimaryAmmoType(), true)
end
end
if primary == 2 then
local m16a2 = ply:Give("weapon_m16a2")
if m16a2 then
ply:GiveAmmo(m16a2:GetMaxClip1() * 3.3, m16a2:GetPrimaryAmmoType(), true)
end
end
if primary == 3 then
local hk416 = ply:Give("weapon_hk416")
if hk416 then
ply:GiveAmmo(hk416:GetMaxClip1() * 3.3, hk416:GetPrimaryAmmoType(), true)
end
end
if primary == 4 then
local ar15 = ply:Give("weapon_ar15")
if ar15 then
ply:GiveAmmo(ar15:GetMaxClip1() * 3.3, ar15:GetPrimaryAmmoType(), true)
end
end
if primary == 5 then
local mac11 = ply:Give("weapon_mac11")
if mac11 then
ply:GiveAmmo(mac11:GetMaxClip1() * 3.3, mac11:GetPrimaryAmmoType(), true)
end
end
if primary == 6 then
local mp7 = ply:Give("weapon_mp7")
if mp7 then
ply:GiveAmmo(mp7:GetMaxClip1() * 3.3, mp7:GetPrimaryAmmoType(), true)
end
end
if primary == 7 then
local mp5 = ply:Give("weapon_mp5")
if mp5 then
ply:GiveAmmo(mp5:GetMaxClip1() * 3.3, mp5:GetPrimaryAmmoType(), true)
end
end
if primary == 8 then
local p90 = ply:Give("weapon_p90")
if p90 then
ply:GiveAmmo(p90:GetMaxClip1() * 3.3, p90:GetPrimaryAmmoType(), true)
end
end
if primary == 9 then
local tmp = ply:Give("weapon_tmp")
if tmp then
ply:GiveAmmo(tmp:GetMaxClip1() * 3.3, tmp:GetPrimaryAmmoType(), true)
end
end
if primary == 10 then
local uzi = ply:Give("weapon_uzi")
if uzi then
ply:GiveAmmo(uzi:GetMaxClip1() * 3.3, uzi:GetPrimaryAmmoType(), true)
end
end
if primary == 11 then
local skorpion = ply:Give("weapon_skorpion")
if skorpion then
ply:GiveAmmo(skorpion:GetMaxClip1() * 3.3, skorpion:GetPrimaryAmmoType(), true)
end
end
if primary == 12 then
local spas12 = ply:Give("weapon_spas12")
if spas12 then
ply:GiveAmmo(spas12:GetMaxClip1() * 3.3, spas12:GetPrimaryAmmoType(), true)
end
end
if primary == 13 then
local m590a1 = ply:Give("weapon_m590a1")
if m590a1 then
ply:GiveAmmo(m590a1:GetMaxClip1() * 3.3, m590a1:GetPrimaryAmmoType(), true)
end
end
if primary == 14 then
local remington870 = ply:Give("weapon_remington870")
if remington870 then
ply:GiveAmmo(remington870:GetMaxClip1() * 3.3, remington870:GetPrimaryAmmoType(), true)
end
end
if primary == 15 then
local saiga12 = ply:Give("weapon_saiga12")
if saiga12 then
ply:GiveAmmo(saiga12:GetMaxClip1() * 3.3, saiga12:GetPrimaryAmmoType(), true)
end
end
if primary == 16 then
local xm1014 = ply:Give("weapon_xm1014")
if xm1014 then
ply:GiveAmmo(xm1014:GetMaxClip1() * 3.3, xm1014:GetPrimaryAmmoType(), true)
end
end
end
function CLASS.On(self, data)
    if CLIENT then return end
    ApplyAppearance(self, nil, nil, nil, true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AClothes = ""
    self:SetNetVar("Accessories", "")
    self:SetSubMaterial()
    self.CurAppearance = Appearance
    self:SetModel("models/arcmansecurity/arcsecurity.mdl")
    local inv = self:GetNetVar("Inventory", {})
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_sling"] = true
    self:SetNetVar("Inventory", inv)
    self:SetBodygroup(1,0)
    self:SetBodygroup(2,3)
    giveRandomColor(self)
giveRandomGun(self)
local glock17 = self:Give("weapon_glock17")
if glock17 then
self:GiveAmmo(glock17:GetMaxClip1() * 2.35, glock17:GetPrimaryAmmoType(), true)
end
self:Give("weapon_walkie_talkie")
self:Give("weapon_hg_tonfa")
self:Give("weapon_handcuffs")
self:Give("weapon_handcuffs_key")
    hg.AddArmor(self, "ent_armor_vest1")
    hg.AddArmor(self, "ent_armor_helmet3")
self:SyncArmor()
end
hook.Add("HG_ReplacePhrase", "ARCSecurityGruntPhrases", function(ent, phrase, pitch)
    local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
    if not IsValid(ply) or ply.PlayerClassName ~= "arcsecuritygrunt" then return end
    local org = ply.organism
    local inpainscream = org and org.pain > 60 and org.pain < 100
    local inpain = org and org.pain > 100
    local new_phrase
    if inpainscream or inpain then
        new_phrase = table.Random(pain_lines)
    else
        new_phrase = table.Random(random_lines)
    end
    ply._nextSound = inpain and (inpainscream and table.Random(pain_lines)) or table.Random(random_lines)
    return ent, new_phrase, muffed, pitch
end)
return CLASS