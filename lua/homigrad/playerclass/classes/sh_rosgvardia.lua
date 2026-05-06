local CLASS = player.RegClass("rosgvardia")
local random_lines = {}
for i = 1, 240 do random_lines[i] = "playerclasses/rosgvardia/Gappoi-" .. i .. ".wav" end
local pain_lines = {}
for i = 1, 235 do pain_lines[i] = "playerclasses/rosgvardia/Pain-" .. i .. ".wav" end
function CLASS.Off(self)
    if CLIENT then return end
end
function CLASS.Guilt(self, Victim)
    if CLIENT then return end
    if Victim:GetPlayerClass() == self:GetPlayerClass() then return 1 end
    return 1
end
hook.Add("HG_PlayerFootstep", "rosgvardia_footsteps", function(ply, pos, foot, sound, volume, rf)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply.PlayerClassName ~= "rosgvardia" then return end
    local ent = hg.GetCurrentCharacter(ply)
    if not (ply:IsWalking() or ply:Crouching()) and ent == ply then
        local snd = "zcitysnd/" .. string.Replace(sound, "player/footsteps", "player/footsteps_military/")
        if SoundDuration(snd) <= 0 then snd = sound end
        EmitSound(snd, pos, ply:EntIndex(), CHAN_AUTO, volume, 75, nil, math.random(95, 105))
        return true
    end
end)
local male_names = {
    "Nikolai", "Artyom", "Vanya", "Petya", "Dimitri", "Oleg", "Aleksey"
}
function CLASS.On(self, data)
    if CLIENT then return end
    ApplyAppearance(self, nil, nil, nil, true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AClothes = ""
    self:SetNetVar("Accessories", "")
    self:SetSubMaterial()
    self.CurAppearance = Appearance
    local models = {"models/rosgvardia/male_02.mdl", "models/rosgvardia/male_04.mdl", "models/rosgvardia/male_06.mdl", "models/rosgvardia/male_07.mdl", "models/rosgvardia/male_08.mdl", "models/rosgvardia/male_09.mdl"}
local model = table.Random(models)
    self:SetModel(model)
    local inv = self:GetNetVar("Inventory", {})
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_sling"] = true
    self:SetNetVar("Inventory", inv)
self:SetPlayerColor(Color(8,0,129):ToVector())
local name = table.Random(male_names)
    self:SetNWString("PlayerName", name)
self:SetBodygroup(1,5)
self:SetBodygroup(2,1)
local pm = self:Give("weapon_makarov")
if pm then
self:GiveAmmo(pm:GetMaxClip1() * 2.35, pm:GetPrimaryAmmoType(), true)
end
local ak74 = self:Give("weapon_ak74")
if ak74 then
self:GiveAmmo(ak74:GetMaxClip1() * 2.35, ak74:GetPrimaryAmmoType(), true)
end
self:Give("weapon_walkie_talkie")
self:Give("weapon_hg_tonfa")
self:Give("weapon_handcuffs")
self:Give("weapon_handcuffs_key")
    local nade = self:Give("weapon_hg_rgd_tpik")
    if nade then nade.count = 3 end
    hg.AddArmor(self, "ent_armor_vest2")
    hg.AddArmor(self, "ent_armor_helmet5")
self:SyncArmor()
end
hook.Add("HG_ReplacePhrase", "rosgvardiaPhrases", function(ent, phrase, pitch)
    local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
    if not IsValid(ply) or ply.PlayerClassName ~= "rosgvardia" then return end
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