local CLASS = player.RegClass("expie")
local random_lines = {}
for i = 1, 5 do random_lines[i] = "playerclasses/expie/random" .. i .. ".wav" end
local pain_lines = {}
for i = 1, 13 do pain_lines[i] = "playerclasses/expie/pain" .. i .. ".wav" end
local steps = {}
for i = 1, 4 do steps[i] = "playerclasses/expie/steps" .. i .. ".wav" end
local moan_lines = {}
for i = 1, 3 do moan_lines[i] = "playerclasses/expie/moan" .. i .. ".wav" end
function CLASS.Off(self)
    if CLIENT then return end
    if self.oldRunSpeed then
        self:SetRunSpeed(self.oldRunSpeed)
        self.oldRunSpeed = nil
    end
    self.StaminaExhaustMul = nil
    self.SpeedGainClassMul = nil
end
function CLASS.Guilt(self, Victim)
    if CLIENT then return end
end
hook.Add("HG_PlayerFootstep", "expie_footsteps", function(ply, pos, foot, sound, volume, rf)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply.PlayerClassName ~= "expie" then return end
    local ent = hg.GetCurrentCharacter(ply)
    if ent == ply then
        if #steps == 0 then return end
        local random_sound = steps[math.random(#steps)]
        local final_volume = math.Clamp(volume * 1.5, 0.5, 1.0)
        EmitSound(random_sound, pos, ply:EntIndex(), CHAN_BODY, final_volume, 100, 0, math.random(95, 105))
        return true
    end
end)
local function giveRandomRace(ply)
    local race = math.random(1,2)
    if race == 1 then
        ply:SetNWString("PlayerName","Expie")
        ply:SetSkin(0)
    elseif race == 2 then
        ply:SetNWString("PlayerName","Albino")
        ply:SetSkin(1)
    end
end
local function giveRandomGender(ply)
    local gender = math.random(1,2)
    if gender == 1 then
        ply:SetModel("models/conventionalgoofball/expie/expie.mdl")
    elseif gender == 2 then
        ply:SetModel("models/conventionalgoofball/milky/milky.mdl")
    end
end
local function giveRandomAccessory(ply)
    local warmers = math.random(1,5)
    if warmers == 1 then
        ply:SetBodygroup(2,0)
        ply:SetBodygroup(3,0)
    elseif warmers == 2 then
        ply:SetBodygroup(2,1)
        ply:SetBodygroup(3,1)
    elseif warmers == 3 then
        ply:SetBodygroup(2,2)
        ply:SetBodygroup(3,2)
    elseif warmers == 4 then
        ply:SetBodygroup(2,3)
        ply:SetBodygroup(3,3)
    elseif warmers == 5 then
        ply:SetBodygroup(2,4)
        ply:SetBodygroup(3,4)
    end
    local hoodie = math.random(1,3)
    if hoodie == 1 then
        ply:SetBodygroup(4,0)
    elseif hoodie == 2 then
        ply:SetBodygroup(4,1)
    elseif hoodie == 3 then
        ply:SetBodygroup(4,2)
    end
    local backpack = math.random(1,3)
    if backpack == 1 then
        ply:SetBodygroup(5,0)
    elseif backpack == 2 then
        ply:SetBodygroup(5,1)
    elseif backpack == 3 then
        ply:SetBodygroup(5,2)
    end
    local legpouch = math.random(1,3)
    if legpouch == 1 then
        ply:SetBodygroup(6,0)
    elseif legpouch == 2 then
        ply:SetBodygroup(6,1)
    elseif legpouch == 3 then
        ply:SetBodygroup(6,2)
    end
    local scarf = math.random(1,3)
    if scarf == 1 then
        ply:SetBodygroup(7,0)
    elseif scarf == 2 then
        ply:SetBodygroup(7,1)
    elseif scarf == 3 then
        ply:SetBodygroup(7,2)
    end
    ply:SetBodygroup(1,0)
    ply:SetPlayerColor(Color(math.random(0,255),math.random(0,255),math.random(0,255)):ToVector())
end
if SERVER then
    function CLASS.On(self, data)
        ApplyAppearance(self, nil, nil, nil, true)
        local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
        Appearance.AAttachments = ""
        Appearance.AClothes = ""
        self:SetNetVar("Accessories", "")
        self:SetSubMaterial()
        self.CurAppearance = Appearance
        giveRandomGender(self)
        giveRandomRace(self)
        giveRandomAccessory(self)
self.oldRunSpeed = self.oldRunSpeed or self:GetRunSpeed()
self:SetRunSpeed(self.oldRunSpeed * 1.19)
self.StaminaExhaustMul = 1.25
self.SpeedGainClassMul = 1.2
        if ThatPlyIsFemale(self) then
            self.VoicePitch = 130
        end
end
end
hook.Add("HG_ReplacePhrase", "ExpiePhrases", function(ent, phrase, pitch)
    local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
    if not IsValid(ply) or ply.PlayerClassName ~= "expie" then return end
    local org = ply.organism
    local inpainscream = org and org.pain > 60 and org.pain < 100
    local inpain = org and org.pain > 100
    local new_phrase
    if inpainscream then
        new_phrase = table.Random(pain_lines)
    elseif inpain then
        new_phrase = table.Random(moan_lines)
    else
        new_phrase = table.Random(random_lines)
    end
    ply._nextSound = inpain and (inpainscream and table.Random(pain_lines) or table.Random(moan_lines)) or table.Random(random_lines)
    return ent, new_phrase, muffed, pitch
end)
hook.Add("HG_ReplaceBurnPhrase", "ExpieBurnPhrases", function(ply, phrase)
    if ply.PlayerClassName ~= "expie" then return end
    return ply, table.Random(pain_lines)
end)
return CLASS