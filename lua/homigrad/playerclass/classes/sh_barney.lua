local CLASS = player.RegClass("barneycalhoun")
local random_lines = {"vo/k_lab/ba_cantlook.wav", "vo/k_lab/ba_careful01.wav", "vo/k_lab/ba_careful02.wav", "vo/k_lab/ba_dontblameyou.wav", "vo/k_lab/ba_forgetthatthing.wav", "vo/k_lab/ba_getitoff01.wav", "vo/k_lab/ba_getoutofsight02.wav", "vo/k_lab/ba_getoutofsight01.wav", "vo/k_lab/ba_guh.wav", "vo/k_lab/ba_headhumper02.wav", "vo/k_lab/ba_hesback01.wav", "vo/k_lab/ba_hesback02.wav", "vo/k_lab/ba_ishehere.wav", "vo/k_lab/ba_itsworking01.wav", "vo/k_lab/ba_itsworking02.wav", "vo/k_lab/ba_itsworking03.wav", "vo/k_lab/ba_itsworking04.wav", "vo/k_lab/ba_longer.wav", "vo/k_lab/ba_myshift01.wav", "vo/k_lab/ba_myshift02.wav", "vo/k_lab/ba_notime.wav", "vo/k_lab/ba_nottoosoon01.wav", "vo/k_lab/ba_saidlasttime.wav", "vo/k_lab/ba_sarcastic02.wav", "vo/k_lab/ba_sarcastic03.wav", "vo/k_lab/ba_thatpest.wav", "vo/k_lab/ba_thereheis.wav", "vo/k_lab/ba_thereyouare.wav", "vo/k_lab/ba_thingaway01.wav", "vo/k_lab/ba_thingaway03.wav", "vo/k_lab/ba_whatthehell.wav", "vo/k_lab/ba_whoops.wav", "vo/k_lab2/ba_getgoing.wav", "vo/k_lab2/ba_goodnews.wav", "vo/k_lab2/ba_goodnews_c.wav", "vo/k_lab2/ba_incoming.wav", "vo/npc/barney/ba_bringiton.wav", "vo/npc/barney/ba_damnit.wav", "vo/npc/barney/ba_danger02.wav", "vo/npc/barney/ba_downyougo.wav", "vo/npc/barney/ba_duck.wav", "vo/npc/barney/ba_followme02.wav", "vo/npc/barney/ba_getaway.wav", "vo/npc/barney/ba_getdown.wav", "vo/npc/barney/ba_getoutofway.wav", "vo/npc/barney/ba_goingdown.wav", "vo/npc/barney/ba_hereitcomes.wav", "vo/npc/barney/ba_hurryup.wav", "vo/npc/barney/ba_imwithyou.wav", "vo/npc/barney/ba_laugh01.wav", "vo/npc/barney/ba_laugh02.wav", "vo/npc/barney/ba_laugh03.wav", "vo/npc/barney/ba_laugh04.wav", "vo/npc/barney/ba_letsdoit.wav", "vo/npc/barney/ba_letsgo.wav", "vo/npc/barney/ba_lookout.wav", "vo/npc/barney/ba_losttouch.wav", "vo/npc/barney/ba_ohyeah.wav", "vo/npc/barney/ba_yell.wav"}
local pain_lines = {"vo/k_lab/ba_thingaway02.wav", "vo/npc/barney/ba_no01.wav", "vo/npc/barney/ba_no02.wav", "vo/npc/barney/ba_ohshit03.wav", "vo/npc/barney/ba_pain01.wav", "vo/npc/barney/ba_pain02.wav", "vo/npc/barney/ba_pain03.wav", "vo/npc/barney/ba_pain04.wav", "vo/npc/barney/ba_pain05.wav", "vo/npc/barney/ba_pain06.wav", "vo/npc/barney/ba_pain07.wav", "vo/npc/barney/ba_pain08.wav", "vo/npc/barney/ba_pain09.wav", "vo/npc/barney/ba_pain10.wav", "vo/npc/barney/ba_wounded02.wav", "vo/npc/barney/ba_wounded03.wav"}
local footsteps = {}
for i = 1, 6 do footsteps[i] = "npc/metropolice/gear" .. i .. ".wav" end
if CLIENT then
    for _, snd in ipairs(footsteps) do
        util.PrecacheSound(snd)
    end
else
    for _, snd in ipairs(footsteps) do
        util.PrecacheSound(snd)
    end
end
function CLASS.Off(self)
    if CLIENT then return end
end
function CLASS.Guilt(self, Victim)
    if CLIENT then return end
end
hook.Add("HG_PlayerFootstep", "barneycalhoun_footsteps", function(ply, pos, foot, sound, volume, rf)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply.PlayerClassName ~= "barneycalhoun" then return end
    local ent = hg.GetCurrentCharacter(ply)
    if ent == ply then
        if #footsteps == 0 then return end
        local random_sound = footsteps[math.random(#footsteps)]
        local final_volume = math.Clamp(volume * 1.5, 0.5, 1.0)
        EmitSound(random_sound, pos, ply:EntIndex(), CHAN_BODY, final_volume, 100, 0, math.random(95, 105))
        return true
    end
end)
function CLASS.On(self, data)
    if CLIENT then return end
    ApplyAppearance(self, nil, nil, nil, true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AClothes = ""
    self:SetNetVar("Accessories", "")
    self:SetSubMaterial()
    self.CurAppearance = Appearance
    self:SetNWString("PlayerName","Barney Calhoun")
    self:SetPlayerColor(Color(40,40,40):ToVector())
    self:SetModel("models/player/barney.mdl")
    self.VoicePitch = 100
    local inv = self:GetNetVar("Inventory", {})
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_sling"] = true
    self:SetNetVar("Inventory", inv)
    hg.AddArmor(self, "ent_armor_vest2")
self:SyncArmor()
end
hook.Add("HG_ReplacePhrase", "BarneyCalhounPhrases", function(ent, phrase, pitch)
    local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
    if not IsValid(ply) or ply.PlayerClassName ~= "barneycalhoun" then return end
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