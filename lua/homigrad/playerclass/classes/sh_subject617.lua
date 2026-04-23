local CLASS = player.RegClass("subject617")

local SUBJECT617_MODEL = "models/player/hidden/hidden.mdl"
local SUBJECT617_MATERIAL = "models/effects/vol_light001"
local SUBJECT617_BERSERK = 0.4
local SUBJECT617_COLOR = Color(255, 255, 255, 28)
local SUBJECT617_COLOR_SOLID = Color(255, 255, 255, 255)
local SUBJECT617_ROLE_COLOR = Color(170, 30, 30)
local SUBJECT617_SOUND_ROOT = "hidden/subject617/"

local SUBJECT617_PHRASES = {
    SUBJECT617_SOUND_ROOT .. "behindyou.mp3",
    SUBJECT617_SOUND_ROOT .. "behindyou01.mp3",
    SUBJECT617_SOUND_ROOT .. "behindyou02.mp3",
    SUBJECT617_SOUND_ROOT .. "comingforyou01.mp3",
    SUBJECT617_SOUND_ROOT .. "comingforyou02.mp3",
    SUBJECT617_SOUND_ROOT .. "comingforyou03.mp3",
    SUBJECT617_SOUND_ROOT .. "freshmeat01.mp3",
    SUBJECT617_SOUND_ROOT .. "freshmeat02.mp3",
    SUBJECT617_SOUND_ROOT .. "freshmeat03.mp3",
    SUBJECT617_SOUND_ROOT .. "imhere.mp3",
    SUBJECT617_SOUND_ROOT .. "imhere01.mp3",
    SUBJECT617_SOUND_ROOT .. "imhere02.mp3",
    SUBJECT617_SOUND_ROOT .. "imhere03.mp3",
    SUBJECT617_SOUND_ROOT .. "imhere04.mp3",
    SUBJECT617_SOUND_ROOT .. "iseeyou.mp3",
    SUBJECT617_SOUND_ROOT .. "iseeyou01.mp3",
    SUBJECT617_SOUND_ROOT .. "iseeyou02.mp3",
    SUBJECT617_SOUND_ROOT .. "iseeyou03.mp3",
    SUBJECT617_SOUND_ROOT .. "lookup.mp3",
    SUBJECT617_SOUND_ROOT .. "lookup01.mp3",
    SUBJECT617_SOUND_ROOT .. "lookup02.mp3",
    SUBJECT617_SOUND_ROOT .. "lookup03.mp3",
    SUBJECT617_SOUND_ROOT .. "overhere01.mp3",
    SUBJECT617_SOUND_ROOT .. "overhere02.mp3",
    SUBJECT617_SOUND_ROOT .. "overhere03.mp3",
    SUBJECT617_SOUND_ROOT .. "turnaround01.mp3",
    SUBJECT617_SOUND_ROOT .. "turnaround02.mp3",
    SUBJECT617_SOUND_ROOT .. "you'renext01.mp3",
    SUBJECT617_SOUND_ROOT .. "you'renext02.mp3",
}

local SUBJECT617_MELEE_SOUNDS = {
    SUBJECT617_SOUND_ROOT .. "pigstick01.mp3",
    SUBJECT617_SOUND_ROOT .. "pigstick02.mp3",
    SUBJECT617_SOUND_ROOT .. "pigstick03.mp3",
    SUBJECT617_SOUND_ROOT .. "pigstick04.mp3",
}

local SUBJECT617_PAIN_SOUNDS = {
    SUBJECT617_SOUND_ROOT .. "pain04.mp3",
}

local SUBJECT617_DEATH_SOUNDS = {
    SUBJECT617_SOUND_ROOT .. "death01.mp3",
    SUBJECT617_SOUND_ROOT .. "death02.mp3",
    SUBJECT617_SOUND_ROOT .. "death03.mp3",
    SUBJECT617_SOUND_ROOT .. "death04.mp3",
    SUBJECT617_SOUND_ROOT .. "death05.mp3",
    SUBJECT617_SOUND_ROOT .. "death06.mp3",
}

local SUBJECT617_AMBIENT_SOUND = SUBJECT617_SOUND_ROOT .. "scarytheme.mp3"

local function canSubject617PickupWeapon(wep)
    if not IsValid(wep) then return false end

    local class = wep:GetClass()
    if class == "weapon_hands_sh" then
        return true
    end

    if wep.ismelee or wep.ismelee2 or wep.Base == "weapon_melee" then
        return true
    end

    if isfunction(wep.Throw) then
        return true
    end

    return false
end

local function getSubject617Organism(ply)
    if not IsValid(ply) then return end

    local organism = ply.organism
    if not istable(organism) then return end

    return organism
end

local function getSubject617Ragdoll(ply)
    if not IsValid(ply) then return end

    if IsValid(ply.FakeRagdoll) then
        return ply.FakeRagdoll
    end

    local ragdoll = ply:GetNWEntity("FakeRagdoll")
    if IsValid(ragdoll) then
        return ragdoll
    end
end

local function getSubject617Corpse(ply)
    if not IsValid(ply) then return end

    local ragdoll = ply:GetNWEntity("RagdollDeath")
    if IsValid(ragdoll) then
        return ragdoll
    end

    if IsValid(ply.RagdollDeath) then
        return ply.RagdollDeath
    end
end

local function setSubject617WeaponShadow(ply, state)
    if not IsValid(ply) or not ply.GetActiveWeapon then return end

    local weapon = ply:GetActiveWeapon()
    if IsValid(weapon) then
        weapon:DrawShadow(state)
    end
end

local function applySubject617EntityVisuals(ent)
    if not IsValid(ent) then return end
    if ent.ZCSubject617Cloaked then
        ent:DrawShadow(false)
        return
    end

    ent.ZCSubject617Cloaked = true
    ent:SetMaterial(SUBJECT617_MATERIAL)
    ent:SetRenderMode(RENDERMODE_TRANSALPHA)
    ent:SetColor(SUBJECT617_COLOR)
    ent:DrawShadow(false)
end

local function clearSubject617EntityVisuals(ent)
    if not IsValid(ent) then return end
    if not ent.ZCSubject617Cloaked and ent:GetMaterial() == "" then
        ent:DrawShadow(true)
        return
    end

    ent.ZCSubject617Cloaked = nil
    ent:SetMaterial("")
    ent:SetRenderMode(RENDERMODE_NORMAL)
    ent:SetColor(SUBJECT617_COLOR_SOLID)
    ent:DrawShadow(true)
end

local function updateSubject617Visuals(ply)
    if not IsValid(ply) then return end

    applySubject617EntityVisuals(ply)
    applySubject617EntityVisuals(getSubject617Ragdoll(ply))
    clearSubject617EntityVisuals(getSubject617Corpse(ply))
    setSubject617WeaponShadow(ply, false)
end

local function clearSubject617Visuals(ply)
    if not IsValid(ply) then return end

    clearSubject617EntityVisuals(ply)
    clearSubject617EntityVisuals(getSubject617Ragdoll(ply))
    clearSubject617EntityVisuals(getSubject617Corpse(ply))
    setSubject617WeaponShadow(ply, true)
end

local function applySubject617Berserk(ply)
    if CLIENT then return end

    local organism = getSubject617Organism(ply)
    if not organism then return end

    organism.berserk = math.max(organism.berserk or 0, SUBJECT617_BERSERK)
    organism.berserkActive = true
    organism.berserkActive2 = true
end

local function clearSubject617Berserk(ply)
    if CLIENT then return end

    local organism = getSubject617Organism(ply)
    if not organism then return end

    organism.berserk = 0
    organism.berserkActive = false
    organism.berserkActive2 = false
    ply.BerserkKills = nil
end

function CLASS.On(self)
    if SERVER then
        if IsValid(self.FakeRagdoll) then
            hg.FakeUp(self, nil, nil, true)
        end

        self.Subject617SavedAppearance = self.Subject617SavedAppearance or (self.CurAppearance and table.Copy(self.CurAppearance) or nil)

        ApplyAppearance(self, nil, nil, nil, true)

        if not self.Subject617SavedAppearance and self.CurAppearance then
            self.Subject617SavedAppearance = table.Copy(self.CurAppearance)
        end

        local appearance = table.Copy(self.CurAppearance or hg.Appearance.GetRandomAppearance())
        appearance.AAttachments = ""
        appearance.AColthes = ""
        self.CurAppearance = appearance

        self:SetNetVar("Accessories", "")
        self:SetModel(SUBJECT617_MODEL)
        self:SetSubMaterial()

        if zb.GiveRole then
            zb.GiveRole(self, "Subject 617", SUBJECT617_ROLE_COLOR)
        end
    end

    applySubject617Berserk(self)
    updateSubject617Visuals(self)
end

function CLASS.Off(self)
    clearSubject617Berserk(self)
    clearSubject617Visuals(self)

    if CLIENT then return end

    local savedAppearance = self.Subject617SavedAppearance
    self.Subject617SavedAppearance = nil

    if savedAppearance and hg.Appearance and hg.Appearance.ForceApplyAppearance then
        self.CurAppearance = table.Copy(savedAppearance)
        hg.Appearance.ForceApplyAppearance(self, savedAppearance)
    else
        ApplyAppearance(self, nil, nil, nil, true)
    end
end

function CLASS.Think(self)
    applySubject617Berserk(self)
    updateSubject617Visuals(self)
end

function CLASS.PlayerDeath(self)
    clearSubject617Berserk(self)
    clearSubject617Visuals(self)
end

if SERVER then
    hook.Add("RagdollDeath", "Subject617_ClearCloak", function(ply, ragdoll)
        if not IsValid(ply) or ply.PlayerClassName != "subject617" then return end
        clearSubject617EntityVisuals(ragdoll)
    end)

    hook.Add("HG_ReplacePhrase", "Subject617Phrases", function(ply, phrase, muffed, pitch)
        if not IsValid(ply) or ply.PlayerClassName != "subject617" then return end

        local inpain = ply.organism and ply.organism.pain > 60
        local sounds = inpain and SUBJECT617_PAIN_SOUNDS or SUBJECT617_PHRASES

        return ply, sounds[math.random(#sounds)], false, pitch
    end)

    hook.Add("HG_ReplaceBurnPhrase", "Subject617BurnPhrases", function(ply, phrase)
        if not IsValid(ply) or ply.PlayerClassName != "subject617" then return end

        return ply, SUBJECT617_DEATH_SOUNDS[math.random(#SUBJECT617_DEATH_SOUNDS)]
    end)

    hook.Add("PlayerDeath", "Subject617DeathSound", function(ply)
        if not IsValid(ply) or ply.PlayerClassName != "subject617" then return end

        ply:EmitSound(SUBJECT617_DEATH_SOUNDS[math.random(#SUBJECT617_DEATH_SOUNDS)], 85, ply.VoicePitch or 100)
    end)

    hook.Add("Org Think", "Subject617PainSounds", function(owner, org, timeValue)
        if owner.PlayerClassName != "subject617" then return end
        if (owner.lastPainSoundCD or 0) > CurTime() then return end
        if org.otrub or org.pain < 30 then return end
        if math.random(1, 50) != 1 then return end

        local phrase = SUBJECT617_PAIN_SOUNDS[math.random(#SUBJECT617_PAIN_SOUNDS)]
        owner:EmitSound(phrase, 80, owner.VoicePitch or 100)
        owner.lastPainSoundCD = CurTime() + math.Rand(10, 20)
        owner.lastPhr = phrase
    end)

    hook.Add("Org Think", "Subject617AmbientSounds", function(owner, org, timeValue)
        if owner.PlayerClassName != "subject617" then return end
        if (owner.Subject617AmbientSoundCD or 0) > CurTime() then return end
        if org.otrub or org.pain >= 30 then return end
        if math.random(1, 160) != 1 then return end

        owner:EmitSound(SUBJECT617_AMBIENT_SOUND, 75, owner.VoicePitch or 100, 0.75)
        owner.Subject617AmbientSoundCD = CurTime() + math.Rand(20, 35)
    end)

    hook.Add("HarmDone", "Subject617StabSound", function(attacker, victim, amt)
        if not IsValid(attacker) or attacker.PlayerClassName != "subject617" then return end
        if not IsValid(victim) or not victim:IsPlayer() then return end
        if attacker == victim or amt < 0.5 then return end
        if (attacker.Subject617StabSoundCD or 0) > CurTime() then return end

        attacker:EmitSound(SUBJECT617_MELEE_SOUNDS[math.random(#SUBJECT617_MELEE_SOUNDS)], 80, attacker.VoicePitch or 100)
        attacker.Subject617StabSoundCD = CurTime() + 0.4
    end)

    hook.Add("PlayerCanPickupWeapon", "Subject617PickupRestriction", function(ply, wep)
        if not IsValid(ply) or ply.PlayerClassName != "subject617" then return end

        if canSubject617PickupWeapon(wep) then
            return
        end

        return false
    end)
end