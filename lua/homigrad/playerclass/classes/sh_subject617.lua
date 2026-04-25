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

local IRIS_PANIC_PHRASES = {
    "Oh fuck, oh fuck, it's him.",
    "God damn it, I don't get paid enough for this.",
    "Did you see him?!",
    "He's... he's right there!",
    "Oh my god, oh my god...",
    "This wasn't in the briefing!",
    "Fall back! FALL BACK!",
    "Where the hell is he?!",
    "I can't see him!",
    "Stay calm... just stay calm...",
    "No no no no...",
}

local IRIS_KILL_WITNESS_PHRASES = {
    "Oh.. his head is gone..",
    "He just... obliterated him.",
    "No no no no NO!",
    "He got Jenkins!",
    "Everyone scatter!",
    "He's making his move!",
    "Did anyone else see that?!",
    "We're sitting ducks!",
}

local IRIS_RELOAD_PHRASES = {
    "FUCK.. I think I hit him at least once.",
    "no no no no NO NO NO NO",
    "Stupid fucking gun...",
    "Lord have mercy on me..",
    "Come on, come on, COME ON!",
    "Reloading! Cover me!",
    "This better work...",
    "Where is he? WHERE?!",
}

local IRIS_DEATH_PHRASES = {
    "Holy shit, he can die?",
    "I think I'm still alive...",
    "Where's everyone else...?",
    "He's so... white.",
    "That was insane.",
    "Did we actually get him?",
    "Is it over? Is it really over?",
    "I need a drink after that.",
}

local IRIS_LAST_ALIVE_PHRASES = {
    "I'm the last one standing...",
    "No no no no this isn't how it ends.",
    "Everyone's gone. Everyone.",
    "Oh my god, I'm alone.",
    "Is anyone still listening?",
    "Don't look back. Don't look back.",
    "I can't do this alone.",
    "Team? TEAM?! Answer me!",
}

local SUBJECT617_HIDDEN_CONFIG = {
    HiddenHealth = 325,
    HiddenRunSpeed = 360,
    HiddenWalkSpeed = 250,
    HiddenJumpPower = 240,
    HiddenGravity = 0.75,
    LeapCooldown = 6,
    LeapForce = 925,
    LeapUpForce = 260,
    LeapDuration = 0.7,
    LeapImpactGrace = 0.9,
    LeapRange = 80,
    LeapDamage = 95,
}

local SUBJECT617_FEAR_PULSE = {
    Radius = 750,
    Interval = 0.9,
    FearAdd = 0.12,           -- gradually builds fear over time (organism system handles conversion to fear)
    FearAddMaxPerPlayer = 1.5, -- cap total fearadd contribution from 617 at half of organism max (3.0)
    PanicAdd = 0.5,
}

local SUBJECT617_THERMAL_CONFIG = {
    MaxTicks   = 12,   -- seconds of thermal vision available at full charge
    DrainRate  = 1,    -- ticks drained per second while active
    RegenRate  = 0.25, -- ticks regened per second while inactive (full regen ~48s)
}

local SUBJECT617_MELEE_LOADOUT = {
    "weapon_kabar",
}

local SUBJECT617_UTILITY_LOADOUT = {
    "weapon_hg_pipebomb_tpik",
    "weapon_traitor_ied",
}

local function isSubject617Player(ply)
    return IsValid(ply) and ply:IsPlayer() and ply.PlayerClassName == "subject617"
end

local function isSubject617FearImmune(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    return isSubject617Player(ply) or tostring(ply.PlayerClassName or "") == "subject617"
end

function ZC_IsSubject617Player(ply)
    return isSubject617Player(ply)
end

function ZC_ShouldSuppressSubject617BerserkFX(ply)
    return isSubject617Player(ply)
end

function ZC_IsSubject617LeapProtected(ply)
    return isSubject617Player(ply) and (ply.HiddenLeapImpactProtectUntil or 0) > CurTime()
end

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

local function applySubject617FearPulse(hunter)
    if CLIENT then return end
    if not isSubject617Player(hunter) then return end
    if not hunter:Alive() then return end

    local now = CurTime()
    if (hunter.Subject617FearPulseAt or 0) > now then return end

    hunter.Subject617FearPulseAt = now + SUBJECT617_FEAR_PULSE.Interval

    for _, target in ipairs(ents.FindInSphere(hunter:GetPos(), SUBJECT617_FEAR_PULSE.Radius)) do
        if not IsValid(target) or not target:IsPlayer() then continue end
        if target == hunter then continue end
        if target:Team() == TEAM_SPECTATOR then continue end
        if not target:Alive() then continue end
        if isSubject617FearImmune(target) then continue end

        local organism = target.organism
        if not istable(organism) then continue end

        -- Gradually increase fear via fearadd (capped at half of organism max 3.0)
        local currentFearadd = organism.fearadd or 0
        if currentFearadd < SUBJECT617_FEAR_PULSE.FearAddMaxPerPlayer then
            organism.fearadd = math.min(currentFearadd + SUBJECT617_FEAR_PULSE.FearAdd, SUBJECT617_FEAR_PULSE.FearAddMaxPerPlayer)
        end

        target.Subject617FearPulseLastAt = now
        target.Subject617FearPulseHits = (target.Subject617FearPulseHits or 0) + 1

        if istable(hg) and istable(hg.DynaMusic) and isfunction(hg.DynaMusic.AddPanic) then
            hg.DynaMusic:AddPanic(target, SUBJECT617_FEAR_PULSE.PanicAdd)
        end
    end
end

local function getSubject617BaseAppearance(ply)
    if IsValid(ply) and istable(ply.CurAppearance) then
        return table.Copy(ply.CurAppearance)
    end

    if istable(hg) and istable(hg.Appearance) and isfunction(hg.Appearance.GetRandomAppearance) then
        local ok, appearance = pcall(hg.Appearance.GetRandomAppearance)
        if ok and istable(appearance) then
            return table.Copy(appearance)
        end
    end

    return {
        AAttachments = "",
        AColthes = "",
    }
end

local function safeApplySubject617DefaultAppearance(ply)
    if not IsValid(ply) or not isfunction(ApplyAppearance) then return false end

    local ok = pcall(ApplyAppearance, ply, nil, nil, nil, true)
    return ok == true
end

local function safeRestoreSubject617Appearance(ply, appearance)
    if not IsValid(ply) or not istable(appearance) then return false end
    if not istable(hg) or not istable(hg.Appearance) or not isfunction(hg.Appearance.ForceApplyAppearance) then return false end

    local ok = pcall(hg.Appearance.ForceApplyAppearance, ply, appearance)
    return ok == true
end

local function applySubject617LeapImpactProtection(ply)
    if not IsValid(ply) then return end

    local untilTime = CurTime() + (SUBJECT617_HIDDEN_CONFIG.LeapDuration or 0) + (SUBJECT617_HIDDEN_CONFIG.LeapImpactGrace or 0)
    ply.HiddenLeapImpactProtectUntil = math.max(ply.HiddenLeapImpactProtectUntil or 0, untilTime)
end

local function clearSubject617LeapImpactProtection(ply, hardClear)
    if not IsValid(ply) then return end
    if hardClear or (ply.HiddenLeapImpactProtectUntil or 0) <= CurTime() then
        ply.HiddenLeapImpactProtectUntil = 0
    end
end

local function resetSubject617LeapState(ply)
    if not IsValid(ply) then return end

    ply.HiddenLeapEndsAt = 0
    ply.HiddenLeapHit = false
    ply:SetNWFloat("HiddenNextLeap", 0)
    clearSubject617LeapImpactProtection(ply, true)
end

local function shouldAutoEquipSubject617(data)
    if data and data.bNoEquipment then
        return false
    end

    local round = CurrentRound and CurrentRound()
    if round and round.name == "hidden" then
        return false
    end

    return true
end

local function applySubject617CombatProfile(ply)
    if CLIENT or not IsValid(ply) then return end

    ply:SetHealth(SUBJECT617_HIDDEN_CONFIG.HiddenHealth)
    ply:SetMaxHealth(SUBJECT617_HIDDEN_CONFIG.HiddenHealth)
    ply:SetRunSpeed(SUBJECT617_HIDDEN_CONFIG.HiddenRunSpeed)
    ply:SetWalkSpeed(SUBJECT617_HIDDEN_CONFIG.HiddenWalkSpeed)
    ply:SetJumpPower(SUBJECT617_HIDDEN_CONFIG.HiddenJumpPower)
    ply:SetGravity(SUBJECT617_HIDDEN_CONFIG.HiddenGravity)
    ply:SetNoTarget(true)

    if isfunction(ply.SetNetVar) then
        ply:SetNetVar("CurPluv", "pluvboss")
    end
end

local function applySubject617CombatEquipment(ply)
    if CLIENT or not IsValid(ply) or not ply:Alive() then return end

    ply:StripWeapons()
    ply:StripAmmo()

    if isfunction(ply.SetSuppressPickupNotices) then
        ply:SetSuppressPickupNotices(true)
    end

    ply.noSound = true

    local selectedWeapon = ply:Give("weapon_hands_sh")

    for _, className in ipairs(SUBJECT617_MELEE_LOADOUT) do
        local weapon = ply:Give(className)
        if IsValid(weapon) then
            selectedWeapon = weapon
            break
        end
    end

    for _, className in ipairs(SUBJECT617_UTILITY_LOADOUT) do
        ply:Give(className)
    end

    if IsValid(selectedWeapon) then
        ply:SelectWeapon(selectedWeapon:GetClass())
    end

    timer.Simple(0.1, function()
        if not IsValid(ply) then return end

        ply.noSound = false
        if isfunction(ply.SetSuppressPickupNotices) then
            ply:SetSuppressPickupNotices(false)
        end
    end)
end

function CLASS.On(self, data)
    if SERVER then
        if IsValid(self.FakeRagdoll) and istable(hg) and isfunction(hg.FakeUp) then
            hg.FakeUp(self, true, true)
        end

        if not self.Subject617SavedAppearance and istable(self.CurAppearance) then
            self.Subject617SavedAppearance = table.Copy(self.CurAppearance)
        end

        safeApplySubject617DefaultAppearance(self)

        if not self.Subject617SavedAppearance and istable(self.CurAppearance) then
            self.Subject617SavedAppearance = table.Copy(self.CurAppearance)
        end

        local appearance = getSubject617BaseAppearance(self)
        appearance.AAttachments = ""
        appearance.AColthes = ""
        self.CurAppearance = appearance

        if isfunction(self.SetNetVar) then
            self:SetNetVar("Accessories", "")
        end
        self:SetModel(SUBJECT617_MODEL)
        self:SetSubMaterial()
        resetSubject617LeapState(self)
        applySubject617CombatProfile(self)

        if shouldAutoEquipSubject617(data) then
            applySubject617CombatEquipment(self)
        end

        if istable(zb) and isfunction(zb.GiveRole) then
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

    resetSubject617LeapState(self)
    self:SetNoTarget(false)
    self:SetNWBool("Subject617ThermalActive", false)
    self:SetNWFloat("Subject617ThermalTicks", SUBJECT617_THERMAL_CONFIG.MaxTicks)

    local savedAppearance = self.Subject617SavedAppearance
    self.Subject617SavedAppearance = nil

    if istable(savedAppearance) then
        self.CurAppearance = table.Copy(savedAppearance)
    end

    if not safeRestoreSubject617Appearance(self, savedAppearance) then
        safeApplySubject617DefaultAppearance(self)
    end

    self.Subject617FearPulseAt = nil
end

function CLASS.Think(self)
    applySubject617Berserk(self)
    updateSubject617Visuals(self)

    if SERVER then
        if (self.HiddenLeapImpactProtectUntil or 0) > 0 and (self.HiddenLeapImpactProtectUntil or 0) <= CurTime() then
            clearSubject617LeapImpactProtection(self, true)
        end

        local ft       = FrameTime()
        local isActive = self:GetNWBool("Subject617ThermalActive", false)
        local ticks    = self:GetNWFloat("Subject617ThermalTicks", SUBJECT617_THERMAL_CONFIG.MaxTicks)

        if isActive then
            ticks = ticks - SUBJECT617_THERMAL_CONFIG.DrainRate * ft
            if ticks <= 0 then
                ticks = 0
                self:SetNWBool("Subject617ThermalActive", false)
            end
        elseif ticks < SUBJECT617_THERMAL_CONFIG.MaxTicks then
            ticks = math.min(ticks + SUBJECT617_THERMAL_CONFIG.RegenRate * ft, SUBJECT617_THERMAL_CONFIG.MaxTicks)
        end

        self:SetNWFloat("Subject617ThermalTicks", ticks)
    end
end

function CLASS.PlayerDeath(self)
    clearSubject617Berserk(self)
    clearSubject617Visuals(self)

    if SERVER then
        resetSubject617LeapState(self)
        self:SetNoTarget(false)
        self:SetNWBool("Subject617ThermalActive", false)
        self:SetNWFloat("Subject617ThermalTicks", SUBJECT617_THERMAL_CONFIG.MaxTicks)
        self.Subject617FearPulseAt = nil
    end
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

    hook.Add("KeyPress", "Subject617Leap", function(ply, key)
        if key != IN_RELOAD then return end
        if not isSubject617Player(ply) then return end
        if not ply:Alive() then return end

        local now = CurTime()
        if ply:GetNWFloat("HiddenNextLeap", 0) > now then return end

        ply.HiddenLeapEndsAt = now + SUBJECT617_HIDDEN_CONFIG.LeapDuration
        ply.HiddenLeapHit = false
        applySubject617LeapImpactProtection(ply)
        ply:SetNWFloat("HiddenNextLeap", now + SUBJECT617_HIDDEN_CONFIG.LeapCooldown)
        ply:SetVelocity(ply:GetAimVector() * SUBJECT617_HIDDEN_CONFIG.LeapForce + Vector(0, 0, SUBJECT617_HIDDEN_CONFIG.LeapUpForce))
    end)

    hook.Add("Think", "Subject617LeapThink", function()
        local now = CurTime()

        for _, hunter in player.Iterator() do
            if not isSubject617Player(hunter) then continue end

            if (hunter.HiddenLeapImpactProtectUntil or 0) > 0 and (hunter.HiddenLeapImpactProtectUntil or 0) <= now then
                clearSubject617LeapImpactProtection(hunter, true)
            end

            if not hunter:Alive() then continue end
            if (hunter.HiddenLeapEndsAt or 0) < now then continue end
            if hunter.HiddenLeapHit then continue end

            for _, target in ipairs(ents.FindInSphere(hunter:GetPos(), SUBJECT617_HIDDEN_CONFIG.LeapRange)) do
                if not IsValid(target) or not target:IsPlayer() then continue end
                if target == hunter or target:Team() == TEAM_SPECTATOR then continue end
                if not target:Alive() or isSubject617Player(target) then continue end

                local dmg = DamageInfo()
                dmg:SetAttacker(hunter)
                dmg:SetInflictor(hunter)
                dmg:SetDamage(SUBJECT617_HIDDEN_CONFIG.LeapDamage)
                dmg:SetDamageType(DMG_SLASH)
                dmg:SetDamageForce(hunter:GetAimVector() * 900)

                target:TakeDamageInfo(dmg)
                hunter.HiddenLeapHit = true
                break
            end
        end
    end)

    hook.Add("Think", "Subject617FearPulseThink", function()
        for _, hunter in player.Iterator() do
            if not isSubject617Player(hunter) then continue end
            applySubject617FearPulse(hunter)
        end
    end)

    hook.Add("EntityTakeDamage", "Subject617LeapImpactProtection", function(ent, dmginfo)
        if not ZC_IsSubject617LeapProtected(ent) then return end

        local damageType = dmginfo:GetDamageType()
        if bit.band(damageType, DMG_FALL) == 0 and bit.band(damageType, DMG_CRUSH) == 0 then return end

        dmginfo:SetDamage(0)
        return true
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

    hook.Add("KeyPress", "Subject617ThermalToggle", function(ply, key)
        if key != IN_ZOOM then return end
        if not isSubject617Player(ply) then return end
        if not ply:Alive() then return end

        local isActive = ply:GetNWBool("Subject617ThermalActive", false)
        local ticks    = ply:GetNWFloat("Subject617ThermalTicks", SUBJECT617_THERMAL_CONFIG.MaxTicks)

        -- Can't activate with no charge remaining
        if not isActive and ticks <= 0 then return end

        ply:SetNWBool("Subject617ThermalActive", not isActive)
    end)

    -- IRIS panic chatter when afraid or near 617
    hook.Add("Org Think", "Subject617IRISPanic", function(owner, org, timeValue)
        if not IsValid(owner) or not owner:IsPlayer() then return end
        if isSubject617Player(owner) then return end
        if owner:Team() == TEAM_SPECTATOR or not owner:Alive() then return end

        local fearLevel = org.fear or 0
        local fearAdd = org.fearadd or 0
        local hasNearby617 = false

        for _, hunter in ipairs(player.GetAll()) do
            if isSubject617Player(hunter) and hunter:Alive() then
                if owner:GetPos():DistToSqr(hunter:GetPos()) < (SUBJECT617_FEAR_PULSE.Radius * SUBJECT617_FEAR_PULSE.Radius) then
                    hasNearby617 = true
                    break
                end
            end
        end

        if not hasNearby617 or (fearLevel < 0.5 and fearAdd < 1) then return end

        -- Random panic chatter
        if math.random(1, 200) == 1 then
            owner:Notify(IRIS_PANIC_PHRASES[math.random(#IRIS_PANIC_PHRASES)], 2, "ir_panic", 5)
            owner.LastPanicPhraseAt = CurTime()
        end
    end)

    -- IRIS reload panic near 617 (uses KeyPress IN_RELOAD; non-617 only)
    hook.Add("KeyPress", "Subject617ReloadPanic", function(ply, key)
        if key != IN_RELOAD then return end
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if isSubject617Player(ply) then return end
        if not ply:Alive() then return end
        if (ply.LastReloadPanicAt or 0) > CurTime() then return end

        local hasNearby617 = false
        local plyPos = ply:GetPos()
        for _, hunter in player.Iterator() do
            if isSubject617Player(hunter) and hunter:Alive() then
                if plyPos:DistToSqr(hunter:GetPos()) < (SUBJECT617_FEAR_PULSE.Radius * SUBJECT617_FEAR_PULSE.Radius) then
                    hasNearby617 = true
                    break
                end
            end
        end

        if hasNearby617 and math.random(1, 3) == 1 then
            ply:Notify(IRIS_RELOAD_PHRASES[math.random(#IRIS_RELOAD_PHRASES)], 2, "ir_reload", 4)
            ply.LastReloadPanicAt = CurTime() + 8
        end
    end)

    -- IRIS witness 617 kill (PlayerDeath attacker check; players aren't EntityRemoved on death)
    hook.Add("PlayerDeath", "Subject617KillWitness", function(victim, inflictor, attacker)
        if not IsValid(victim) or not victim:IsPlayer() then return end
        if isSubject617Player(victim) then return end
        if not IsValid(attacker) or not attacker:IsPlayer() or not isSubject617Player(attacker) then return end

        local victimPos = victim:GetPos()
        for _, witness in player.Iterator() do
            if IsValid(witness) and witness:IsPlayer() and witness:Alive() and witness != victim and not isSubject617Player(witness) then
                if witness:GetPos():DistToSqr(victimPos) < (600 * 600) and math.random(1, 2) == 1 then
                    witness:Notify(IRIS_KILL_WITNESS_PHRASES[math.random(#IRIS_KILL_WITNESS_PHRASES)], 2, "ir_witness", 5)
                end
            end
        end
    end)

    -- IRIS death voice lines
    hook.Add("PlayerDeath", "Subject617DeathChatter", function(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if isSubject617Player(ply) then return end

        local aliveCount = 0
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:IsPlayer() and p:Alive() and not isSubject617Player(p) then
                aliveCount = aliveCount + 1
            end
        end

        if aliveCount <= 1 then
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:IsPlayer() and p:Alive() and not isSubject617Player(p) then
                    p:Notify(IRIS_LAST_ALIVE_PHRASES[math.random(#IRIS_LAST_ALIVE_PHRASES)], 3, "ir_last", 6)
                end
            end
        end
    end)

    -- Subject 617 dies - everyone reacts
    hook.Add("PlayerDeath", "Subject617Death", function(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if not isSubject617Player(ply) then return end

        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:IsPlayer() and p:Alive() and not isSubject617Player(p) then
                p:Notify(IRIS_DEATH_PHRASES[math.random(#IRIS_DEATH_PHRASES)], 3, "ir_617death", 6)
            end
        end
    end)
end

if CLIENT then
    local thermalMat  = Material("pp/texturize/plain.png")
    local thermalBloom = {
        darken = 0, multiply = 1, sizex = 4, sizey = 4,
        passes = 1, colormultiply = 1, red = 1, green = 1, blue = 1,
    }

    local function enableSubject617Thermal()
        hook.Add("PreDrawEffects", "Subject617ThermalOutline", function()
            local lp = LocalPlayer()
            if not IsValid(lp) or not lp:Alive() then return end

            local curPos = lp:GetPos()
            render.ClearStencil()
            render.SetStencilEnable(true)
            render.SetStencilWriteMask(255)
            render.SetStencilTestMask(255)
            render.SetStencilReferenceValue(1)

            local glowEnts = {}
            for _, ent in ipairs(ents.GetAll()) do
                if not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then continue end
                if ent == lp then continue end
                if ent:IsPlayer() then
                    if not ent:Alive() then continue end
                    if ent:Team() == TEAM_SPECTATOR then continue end
                end
                if ent:GetPos():DistToSqr(curPos) > 25000000 then continue end

                render.SetStencilCompareFunction(STENCIL_ALWAYS)
                render.SetStencilZFailOperation(STENCIL_KEEP)
                render.SetStencilPassOperation(STENCIL_REPLACE)
                render.SetStencilFailOperation(STENCIL_KEEP)
                ent:DrawModel()

                render.SetStencilCompareFunction(STENCIL_EQUAL)
                render.SetStencilZFailOperation(STENCIL_KEEP)
                render.SetStencilPassOperation(STENCIL_KEEP)
                render.SetStencilFailOperation(STENCIL_KEEP)

                cam.Start2D()
                    surface.SetDrawColor(234, 234, 234)
                    surface.DrawRect(0, 0, ScrW(), ScrH())
                cam.End2D()

                table.insert(glowEnts, ent)
            end

            halo.Add(glowEnts, Color(255, 255, 255), 1, 1, 1, true, false)

            render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
            render.SetStencilZFailOperation(STENCIL_KEEP)
            render.SetStencilPassOperation(STENCIL_KEEP)
            render.SetStencilFailOperation(STENCIL_KEEP)
            render.SetStencilEnable(false)
        end)

        hook.Add("RenderScreenspaceEffects", "Subject617ThermalScreenFX", function()
            DrawColorModify({
                ["$pp_colour_addr"]       = 0,
                ["$pp_colour_addg"]       = 0,
                ["$pp_colour_addb"]       = 0,
                ["$pp_colour_brightness"] = 0.05,
                ["$pp_colour_contrast"]   = 0.5,
                ["$pp_colour_colour"]     = 0,
                ["$pp_colour_mulr"]       = 0,
                ["$pp_colour_mulg"]       = 0,
                ["$pp_colour_mulb"]       = 0,
            })

            local dlight = DynamicLight(LocalPlayer():EntIndex())
            if dlight then
                dlight.brightness = 1
                dlight.Size       = 900
                dlight.r          = 255
                dlight.g          = 255
                dlight.b          = 255
                dlight.Decay      = 1000
                dlight.Pos        = EyePos()
                dlight.DieTime    = CurTime() + 0.1
            end

            DrawBloom(thermalBloom.darken, thermalBloom.multiply, thermalBloom.sizex, thermalBloom.sizey,
                thermalBloom.passes, thermalBloom.colormultiply, thermalBloom.red, thermalBloom.green, thermalBloom.blue)
            DrawTexturize(1, thermalMat)
        end)
    end

    local function disableSubject617Thermal()
        hook.Remove("PreDrawEffects", "Subject617ThermalOutline")
        hook.Remove("RenderScreenspaceEffects", "Subject617ThermalScreenFX")
    end

    local thermalWasActive = false

    hook.Add("Think", "Subject617ThermalClientSync", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local isActive = isSubject617Player(lp) and lp:Alive() and lp:GetNWBool("Subject617ThermalActive", false)

        if isActive and not thermalWasActive then
            enableSubject617Thermal()
            surface.PlaySound("kaito/knts/tactical_goggles_on.mp3")
            thermalWasActive = true
        elseif not isActive and thermalWasActive then
            disableSubject617Thermal()
            surface.PlaySound("kaito/knts/tactical_goggles_off.mp3")
            thermalWasActive = false
        end
    end)

    hook.Add("HUDPaint", "Subject617ThermalBar", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if not isSubject617Player(lp) then return end
        if not lp:Alive() then return end

        local maxTicks = SUBJECT617_THERMAL_CONFIG.MaxTicks
        local ticks    = lp:GetNWFloat("Subject617ThermalTicks", maxTicks)
        local fraction = math.Clamp(ticks / maxTicks, 0, 1)
        local isActive = lp:GetNWBool("Subject617ThermalActive", false)

        local sw, sh = ScrW(), ScrH()
        local bx, by, bw, bh = sw * 0.35, sh * 0.875, sw * 0.30, 18

        surface.SetDrawColor(10, 10, 10, 180)
        surface.DrawRect(bx, by, bw, bh)

        local fillCol = isActive and Color(220, 220, 255, 220) or Color(80, 160, 220, 180)
        local fillW   = math.floor((bw - 2) * fraction)
        if fillW > 0 then
            surface.SetDrawColor(fillCol.r, fillCol.g, fillCol.b, fillCol.a)
            surface.DrawRect(bx + 1, by + 1, fillW, bh - 2)
        end

        surface.SetDrawColor(255, 255, 255, 35)
        surface.DrawOutlinedRect(bx, by, bw, bh, 1)
    end)

    -- IRIS fear screen effects (panic/dread visual feedback when afraid of 617)
    hook.Add("RenderScreenspaceEffects", "Subject617IRISFearFX", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if lp:Team() == TEAM_SPECTATOR or not lp:Alive() then return end
        if isSubject617Player(lp) then return end

        local org = lp.organism
        if not istable(org) then return end

        local fearLevel = math.Clamp(org.fear or 0, 0, 1)
        if fearLevel < 0.1 then return end

        -- Red tint + desaturation increases with fear, creates panic effect
        local intensity = fearLevel * 0.8
        DrawColorModify({
            ["$pp_colour_addr"]       = intensity * 0.15,
            ["$pp_colour_addg"]       = -intensity * 0.05,
            ["$pp_colour_addb"]       = -intensity * 0.05,
            ["$pp_colour_brightness"] = -intensity * 0.2,
            ["$pp_colour_contrast"]   = 1 + (intensity * 0.3),
            ["$pp_colour_colour"]     = 1 - (intensity * 0.4),
            ["$pp_colour_mulr"]       = 1 + (intensity * 0.2),
            ["$pp_colour_mulg"]       = 1 - (intensity * 0.1),
            ["$pp_colour_mulb"]       = 1 - (intensity * 0.1),
        })

        -- Bloom effect increases with panic/fearadd threshold
        if (org.fearadd or 0) > 0.5 then
            local panicIntensity = math.Clamp((org.fearadd or 0) / 1.5, 0, 1)
            DrawBloom(0.5, panicIntensity * 3, 6, 6, 1, 1, panicIntensity / 20, 0.3, 0.1)
        end
    end)
end