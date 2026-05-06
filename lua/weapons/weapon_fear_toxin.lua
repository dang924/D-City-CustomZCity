if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Fear Toxin"
SWEP.Instructions = "Experimental Fury-13 derivative. One full dose causes escalating fear syndrome and cardiac arrest in ~3 minutes. A second dose triggers immediate arrest. RMB to inject into someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_adrenaline.mdl"

if CLIENT then
    SWEP.WepSelectIcon = Material("entities/zcity/fury13.png")
    SWEP.IconOverride = "entities/zcity/fury13.png"
    SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(3, -2.5, -1)
SWEP.offsetAng = Angle(-30, 20, -90)
SWEP.ModelScale = 0.65
SWEP.Color = Color(35, 35, 35)
SWEP.modeNames = {
    [1] = "fear toxin dose",
}

local HG_HEAL_ANIMS = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

local HORROR = {
    Duration = 180,
    FearAddCap = 2.8,
    FearCap = 0.98,
    PulseFxTail = 2.6,
    LineIntervalMin = 1.8,
    LineIntervalMax = 6.5,
    LongTrackDuration = 128.09,
    LongTrackEndLead = 4.0,
}

function SWEP:InitializeAdd()
    self:SetHold(self.HoldType)
    self.modeValues = {
        [1] = 1,
    }
end

SWEP.modeValuesdef = {
    [1] = 1,
}

SWEP.DeploySnd = ""
SWEP.HolsterSnd = ""
SWEP.showstats = false

function SWEP:Think()
    self:SetBodyGroups("11")
    if not self:GetOwner():KeyDown(IN_ATTACK) and HG_HEAL_ANIMS:GetBool() then
        self:SetHolding(math.max(self:GetHolding() - 4, 0))
    end
end

function SWEP:Animation()
    local hold = self:GetHolding()
    self:BoneSet("r_upperarm", vector_origin, Angle(0, -hold + (100 * (hold / 100)), 0))
    self:BoneSet("r_forearm", vector_origin, Angle(-hold / 6, -hold * 2, -15))
end

function SWEP:OwnerChanged()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:IsNPC() then
        self:Remove()
    end
end

if SERVER then
    local function getNightTerrorKillTimerId(victim)
        if not IsValid(victim) then return nil end
        return "ZC_Fury13NightTerrorKill_" .. tostring(victim:EntIndex())
    end

    local function forceKillVictim(victim)
        if not IsValid(victim) or not victim:IsPlayer() then return end

        victim:SetHealth(0)
        if victim:Alive() then victim:Kill() end
        if victim:Alive() then victim:KillSilent() end

        if victim:Alive() then
            local dmg = DamageInfo()
            dmg:SetAttacker(game.GetWorld())
            dmg:SetInflictor(game.GetWorld())
            dmg:SetDamageType(DMG_DIRECT)
            dmg:SetDamage(5000)
            victim:TakeDamageInfo(dmg)
        end
    end

    local function clearNightTerrorState(victim, org)
        if not IsValid(victim) then return end

        local targetOrg = org
        if not istable(targetOrg) then
            targetOrg = victim.organism
        end

        if istable(targetOrg) then
            targetOrg.ZCFury13HorrorStartAt = nil
            targetOrg.ZCFury13HorrorEndAt = nil
            targetOrg.ZCFury13KillAt = nil
            targetOrg.ZCFury13NextLineAt = nil
            targetOrg.ZCFury13DoseCount = nil
            targetOrg.ZCFury13HorrorOwner = nil
            if targetOrg.ZCFury13KillTimerId then
                timer.Remove(targetOrg.ZCFury13KillTimerId)
                targetOrg.ZCFury13KillTimerId = nil
            end
        end

        victim:SetNWFloat("ZCFury13LobotomyUntil", 0)
        victim:SetNWFloat("ZCFury13LobotomyStrength", 0)
        victim:SetNWFloat("ZCFury13HallucinateUntil", 0)
        victim:SetNWFloat("ZCFury13HallucinateStrength", 0)
        victim:SetNWFloat("Subject617FearFXUntil", 0)
        victim:SetNWFloat("Subject617FearFXStrength", 0)
        victim:SetNWFloat("ZCFury13SongStartAt", 0)
        victim:SetNWFloat("ZCFury13DeathAt", 0)
        victim:SetNWFloat("ZCFury13ActiveUntil", 0)
        victim:SetNWFloat("ZCFury13Progress", 0)
        victim.ZCFury13HardDeathAt = nil
    end

    local function induceCardiacArrest(victim, org)
        if not IsValid(victim) or not istable(org) then return end

        org.heartstop = true
        org.brain = math.max(org.brain or 0, 0.72)
        org.heartbeat = 0
        org.pulse = math.min(org.pulse or 0, 1)
        org.painadd = math.min((org.painadd or 0) + 120, 150)
        org.disorientation = 10
        org.shock = math.max(org.shock or 0, 85)
        org.consciousness = 0
        org.needotrub = true
        org.alive = false
        org.fear = math.max(org.fear or 0, 0.95)
        org.fearadd = math.max(org.fearadd or 0, 2.5)
        org.Subject617FearHeartbeatBoost = math.max(org.Subject617FearHeartbeatBoost or 0, 95)
        org.Subject617FearHeartbeatUntil = CurTime() + 4
        victim:SetNWFloat("Subject617FearFXUntil", CurTime() + 5)
        victim:SetNWFloat("Subject617FearFXStrength", 1)
        victim:SetNWFloat("ZCFury13LobotomyUntil", CurTime() + 6)
        victim:SetNWFloat("ZCFury13LobotomyStrength", 1)
        victim:SetNWFloat("ZCFury13HallucinateUntil", CurTime() + 5)
        victim:SetNWFloat("ZCFury13HallucinateStrength", 1)

        if istable(hg) and istable(hg.DynaMusic) and isfunction(hg.DynaMusic.AddPanic) then
            hg.DynaMusic:AddPanic(victim, 2.4)
        end

        forceKillVictim(victim)

        clearNightTerrorState(victim, org)
    end

    local function applyNightTerrorDose(victim, injector)
        if not IsValid(victim) or not victim:IsPlayer() then return end
        if not victim:Alive() then return end

        local org = victim.organism
        if not istable(org) then return end

        local now = CurTime()
        local active = (org.ZCFury13HorrorEndAt or 0) > now

        if active then
            org.ZCFury13DoseCount = (org.ZCFury13DoseCount or 1) + 1
            if org.ZCFury13DoseCount >= 2 then
                induceCardiacArrest(victim, org)
            end
            return
        end

        org.ZCFury13DoseCount = 1
        org.ZCFury13HorrorStartAt = now
        org.ZCFury13HorrorEndAt = now + HORROR.Duration
        org.ZCFury13KillAt = now + HORROR.Duration
        org.ZCFury13KillTimerId = getNightTerrorKillTimerId(victim)
        org.ZCFury13HorrorOwner = IsValid(injector) and injector or nil
        victim:SetNWFloat("ZCFury13DeathAt", now + HORROR.Duration)
        victim.ZCFury13HardDeathAt = now + HORROR.Duration
        victim:SetNWFloat(
            "ZCFury13SongStartAt",
            now + math.max(HORROR.Duration - HORROR.LongTrackDuration + HORROR.LongTrackEndLead, 0)
        )
        victim:SetNWFloat("ZCFury13ActiveUntil", now + HORROR.Duration)
        victim:SetNWFloat("ZCFury13Progress", 0)

        org.fear = math.max(org.fear or 0, 0.26)
        org.fearadd = math.max(org.fearadd or 0, 0.75)
        org.painadd = math.min((org.painadd or 0) + 18, 150)
        org.disorientation = math.min((org.disorientation or 0) + 1.2, 10)
        org.shock = math.max(org.shock or 0, 8)
        org.Subject617FearHeartbeatBoost = math.max(org.Subject617FearHeartbeatBoost or 0, 28)
        org.Subject617FearHeartbeatUntil = now + 3
        victim:SetNWFloat("Subject617FearFXUntil", now + 4)
        victim:SetNWFloat("Subject617FearFXStrength", 0.52)

        if istable(hg) and istable(hg.DynaMusic) and isfunction(hg.DynaMusic.AddPanic) then
            hg.DynaMusic:AddPanic(victim, 0.8)
        end

        if org.ZCFury13KillTimerId then
            timer.Remove(org.ZCFury13KillTimerId)
            timer.Create(org.ZCFury13KillTimerId, HORROR.Duration, 1, function()
                if not IsValid(victim) then return end
                local liveOrg = victim.organism
                if not istable(liveOrg) then return end

                induceCardiacArrest(victim, liveOrg)
            end)
        end
    end

    function SWEP:Heal(ent)
        if not IsValid(ent) then return end

        if ent:IsNPC() then
            self:SpawnGarbage(nil, nil, nil, self.Color, "2211")
            self:Remove()
            return
        end

        local org = ent.organism
        if not org then return end
        if self.modeValues[1] <= 0 then return end

        local owner = self:GetOwner()
        if ent == hg.GetCurrentCharacter(owner) and HG_HEAL_ANIMS:GetBool() then
            self:SetHolding(math.min(self:GetHolding() + 4, 100))
            if self:GetHolding() < 100 then return end
        end

        local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
        entOwner:EmitSound("snd_jack_hmcd_needleprick.wav", 75, math.random(90, 105), 1, CHAN_AUTO)
        entOwner:EmitSound("snd_jack_sss.wav", 60, 5200, 0.08, CHAN_AUTO)

        self.modeValues[1] = 0
        applyNightTerrorDose(org.owner or ent, owner)
        owner:SelectWeapon("weapon_hands_sh")
        self:SpawnGarbage(nil, nil, nil, self.Color, "2211")
        self:Remove()
    end

    hook.Add("Org Think", "ZC_Fury13NightTerrorProgress", function(owner, org, timeValue)
        if not IsValid(owner) or not owner:IsPlayer() then return end
        if not istable(org) then return end

        local now = CurTime()
        local endAt = org.ZCFury13HorrorEndAt or 0
        local killAt = org.ZCFury13KillAt or endAt
        if killAt > 0 and now >= killAt then
            induceCardiacArrest(owner, org)
            return
        end

        if endAt <= now then
            if endAt > 0 then
                induceCardiacArrest(owner, org)
            end
            return
        end

        local startAt = org.ZCFury13HorrorStartAt or (endAt - HORROR.Duration)
        local progress = math.Clamp((now - startAt) / HORROR.Duration, 0, 1)
        local rampProgress = math.Clamp(progress * 1.45, 0, 1)

        owner:SetNWFloat("ZCFury13ActiveUntil", endAt)
        owner:SetNWFloat("ZCFury13Progress", rampProgress)

        local fearAddRate = Lerp(rampProgress, 0.08, 0.24)
        org.fearadd = math.min((org.fearadd or 0) + fearAddRate * timeValue, HORROR.FearAddCap)

        local fearRate = Lerp(rampProgress, 0.036, 0.092)
        org.fear = math.min((org.fear or 0) + fearRate * timeValue, HORROR.FearCap)

        local painRate = Lerp(rampProgress, 4.5, 18)
        org.painadd = math.min((org.painadd or 0) + painRate * timeValue, 150)

        local disorientationRate = Lerp(rampProgress, 0.35, 2.6)
        org.disorientation = math.min((org.disorientation or 0) + disorientationRate * timeValue, 10)

        org.shock = math.min(math.max(org.shock or 0, 6 + rampProgress * 14) + Lerp(rampProgress, 0.5, 4.5) * timeValue, 100)
        org.adrenalineAdd = math.max(org.adrenalineAdd or 0, 0.4 + rampProgress * 1.6)

        local brainRate = Lerp(rampProgress, 0.0005, 0.0062)
        org.brain = math.min((org.brain or 0) + brainRate * timeValue, 0.72)

        local heartRate = Lerp(rampProgress, 0.0004, 0.0038)
        org.heart = math.min((org.heart or 0) + heartRate * timeValue, 0.5)

        local bpmBoost = Lerp(rampProgress, 26, 98)
        org.Subject617FearHeartbeatBoost = math.max(org.Subject617FearHeartbeatBoost or 0, bpmBoost)
        org.Subject617FearHeartbeatUntil = now + 1.9

        local fxStrength = math.Clamp(0.35 + rampProgress * 0.65, 0, 1)
        owner:SetNWFloat("Subject617FearFXUntil", now + HORROR.PulseFxTail)
        owner:SetNWFloat("Subject617FearFXStrength", fxStrength)

        if rampProgress > 0.42 then
            local phase = math.Clamp((rampProgress - 0.42) / 0.58, 0, 1)
            owner:SetNWFloat("ZCFury13LobotomyUntil", now + 2.2)
            owner:SetNWFloat("ZCFury13LobotomyStrength", phase)
            owner:SetNWFloat("ZCFury13HallucinateUntil", now + 2.2)
            owner:SetNWFloat("ZCFury13HallucinateStrength", phase)

            if istable(hg) and istable(hg.DynaMusic) and isfunction(hg.DynaMusic.AddPanic) then
                hg.DynaMusic:AddPanic(owner, 0.05 + (phase * 0.22))
            end
        end
    end)

    hook.Add("PlayerSpawn", "ZC_Fury13NightTerrorReset", function(ply)
        clearNightTerrorState(ply)
    end)

    hook.Add("PlayerDeath", "ZC_Fury13NightTerrorReset", function(ply)
        clearNightTerrorState(ply)
    end)

    local function clearAllNightTerrorStates()
        for _, ply in player.Iterator() do
            clearNightTerrorState(ply)
        end
    end

    hook.Add("ZB_PreRoundStart", "ZC_Fury13NightTerrorReset", clearAllNightTerrorStates)
    hook.Add("ZB_StartRound", "ZC_Fury13NightTerrorReset", clearAllNightTerrorStates)
    hook.Add("ZB_RoundStart", "ZC_Fury13NightTerrorReset", clearAllNightTerrorStates)
    hook.Add("ZB_RoundEnd", "ZC_Fury13NightTerrorReset", clearAllNightTerrorStates)
    hook.Add("PostCleanupMap", "ZC_Fury13NightTerrorReset", clearAllNightTerrorStates)

    hook.Add("Think", "ZC_Fury13NightTerrorKillFailsafe", function()
        local now = CurTime()
        for _, ply in player.Iterator() do
            if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
            local org = ply.organism
            local killAt = 0

            if istable(org) then
                killAt = org.ZCFury13KillAt or 0
            end

            killAt = math.max(
                killAt,
                tonumber(ply.ZCFury13HardDeathAt) or 0,
                ply:GetNWFloat("ZCFury13DeathAt", 0)
            )

            if killAt > 0 and now >= killAt then
                if not istable(org) then
                    org = ply.organism
                end
                if not istable(org) then
                    forceKillVictim(ply)
                    clearNightTerrorState(ply)
                    continue
                end
                induceCardiacArrest(ply, org)
            end
        end
    end)
end

if CLIENT then
    local FEAR_TOXIN_LONG_TRACK = "feartoxin/heavenly_army_long.mp3"
    local FEAR_TOXIN_WHISPERS = {
        "feartoxin/evil_mouth_ensemble.mp3",
        "feartoxin/wind_spirit_realm.mp3",
        "feartoxin/ghost_whispers.mp3",
    }

    local FEAR_TOXIN_STINGERS = {
        "feartoxin/possessed_laugh.mp3",
        "feartoxin/sinister_laughter.mp3",
    }

    local HALLUCINATION_ARCHETYPES = {
        { model = "models/zombie/fast.mdl", scaleMin = 0.92, scaleMax = 1.06, weight = 5 },
        { model = "models/zombie/classic.mdl", scaleMin = 0.94, scaleMax = 1.08, weight = 2 },
        { model = "models/player/charple.mdl", scaleMin = 0.9, scaleMax = 1.1, weight = 3 },
    }

    local ATTACK_SOUNDS = {
        "npc/zombie/claw_strike1.wav",
        "npc/zombie/claw_strike2.wav",
        "npc/zombie/claw_strike3.wav",
        "npc/fast_zombie/fz_scream1.wav",
        "npc/fast_zombie/fz_scream2.wav",
        "feartoxin/possessed_laugh.mp3",
        "feartoxin/sinister_laughter.mp3",
    }

    local ghosts = {}
    local nextGhostAt = 0
    local nextFlashAt = 0
    local nextAmbientAt = 0
    local fearToxinMusicStartedFor = 0
    local fearToxinWasActive = false
    local fearToxinMusicChannel = nil
    local fearToxinTransientChannels = {}
    local fearToxinClassMusicSuppressed = false
    local fearToxinRestoreDynaMusicValue = nil
    local fearToxinRestoreWaveMusicValue = nil
    local hgDynaMusicCVar = GetConVar("hg_dmusic")
    local waveMusicCVar = GetConVar("cl_wavemusic")

    local function stopCompetingCombatMusic(hardStop)
        if istable(hg) and istable(hg.DynaMusic) and isfunction(hg.DynaMusic.Stop) then
            hg.DynaMusic:Stop()
        end

        if istable(hg) and istable(hg.DynamicMusicV2) and istable(hg.DynamicMusicV2.Player) and isfunction(hg.DynamicMusicV2.Player.Stop) then
            hg.DynamicMusicV2.Player.Stop(true)
        end

        if hardStop then
            RunConsoleCommand("stopsound")
        end
    end

    local function stopFearToxinTransientChannels()
        for i = #fearToxinTransientChannels, 1, -1 do
            local ch = fearToxinTransientChannels[i]
            if IsValid(ch) then
                ch:Stop()
            end
            fearToxinTransientChannels[i] = nil
        end
    end

    local function setClassMusicSuppressed(suppress)
        suppress = suppress and true or false
        if suppress == fearToxinClassMusicSuppressed then return end

        fearToxinClassMusicSuppressed = suppress

        if suppress then
            if hgDynaMusicCVar and isfunction(hgDynaMusicCVar.GetString) then
                fearToxinRestoreDynaMusicValue = hgDynaMusicCVar:GetString()
                if fearToxinRestoreDynaMusicValue ~= "0" then
                    RunConsoleCommand("hg_dmusic", "0")
                end
            end

            if waveMusicCVar and isfunction(waveMusicCVar.GetString) then
                fearToxinRestoreWaveMusicValue = waveMusicCVar:GetString()
                if fearToxinRestoreWaveMusicValue ~= "0" then
                    RunConsoleCommand("cl_wavemusic", "0")
                end
            end

            stopCompetingCombatMusic(true)
            return
        end

        if hgDynaMusicCVar and isfunction(hgDynaMusicCVar.GetString) and fearToxinRestoreDynaMusicValue ~= nil then
            RunConsoleCommand("hg_dmusic", fearToxinRestoreDynaMusicValue)
        end
        if waveMusicCVar and isfunction(waveMusicCVar.GetString) and fearToxinRestoreWaveMusicValue ~= nil then
            RunConsoleCommand("cl_wavemusic", fearToxinRestoreWaveMusicValue)
        end
        fearToxinRestoreDynaMusicValue = nil
        fearToxinRestoreWaveMusicValue = nil
    end

    local function playFearToxinOneShot(path, volume, fallbackPitch)
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local sndPath = "sound/" .. tostring(path)
        sound.PlayFile(sndPath, "noplay noblock", function(channel)
            if not IsValid(channel) then
                lp:EmitSound(path, 75, fallbackPitch or 100, volume or 0.7, CHAN_AUTO)
                return
            end

            channel:SetVolume(math.Clamp(volume or 0.7, 0, 1))
            channel:Play()
            fearToxinTransientChannels[#fearToxinTransientChannels + 1] = channel
        end)
    end

    local function stopFearToxinMusic()
        if IsValid(fearToxinMusicChannel) then
            fearToxinMusicChannel:Stop()
        end
        fearToxinMusicChannel = nil
        fearToxinMusicStartedFor = 0
        stopFearToxinTransientChannels()
    end

    local function startFearToxinMusic(volume, songStartAt)
        volume = math.Clamp(volume or 0, 0, 1)

        fearToxinMusicStartedFor = songStartAt or CurTime()
        sound.PlayFile("sound/" .. FEAR_TOXIN_LONG_TRACK, "noplay noblock", function(channel)
            if not IsValid(channel) then
                local lp = LocalPlayer()
                if IsValid(lp) then
                    lp:EmitSound(FEAR_TOXIN_LONG_TRACK, 75, 100, volume, CHAN_STATIC)
                end
                return
            end

            fearToxinMusicChannel = channel
            channel:SetVolume(volume)
            channel:Play()
        end)
    end

    local function pickHallucinationArchetype()
        local total = 0
        for i = 1, #HALLUCINATION_ARCHETYPES do
            total = total + (HALLUCINATION_ARCHETYPES[i].weight or 1)
        end

        local roll = math.Rand(0, total)
        local sum = 0
        for i = 1, #HALLUCINATION_ARCHETYPES do
            local entry = HALLUCINATION_ARCHETYPES[i]
            sum = sum + (entry.weight or 1)
            if roll <= sum then
                return entry
            end
        end

        return HALLUCINATION_ARCHETYPES[#HALLUCINATION_ARCHETYPES]
    end

    local function clearGhosts()
        for i = #ghosts, 1, -1 do
            local data = ghosts[i]
            if IsValid(data.model) then
                data.model:Remove()
            end
            ghosts[i] = nil
        end
    end

    local function spawnGhost(lp, strength)
        local archetype = pickHallucinationArchetype()
        local mdl = ClientsideModel(archetype.model or "models/player/charple.mdl", RENDERGROUP_OPAQUE)
        if not IsValid(mdl) and archetype.model ~= "models/player/charple.mdl" then
            mdl = ClientsideModel("models/player/charple.mdl", RENDERGROUP_OPAQUE)
        end
        if not IsValid(mdl) then return end

        mdl:SetNoDraw(true)
        mdl:SetModelScale(math.Rand(archetype.scaleMin or 0.92, archetype.scaleMax or 1.08), 0)
        mdl:SetMaterial("models/debug/debugwhite")
        mdl:SetColor(Color(0, 0, 0, math.floor(155 + strength * 90)))

        local runSeq = mdl:SelectWeightedSequence(ACT_RUN)
        if isnumber(runSeq) and runSeq >= 0 then
            mdl:ResetSequence(runSeq)
            mdl:SetCycle(math.Rand(0, 1))
            mdl:SetPlaybackRate(math.Rand(0.9, 1.3))
        end

        local ang = Angle(0, math.random(0, 359), 0)
        local dist = math.Rand(180, 420)
        local startPos = lp:GetPos() + ang:Forward() * dist + Vector(0, 0, 2)
        local targetPos = lp:GetPos() + lp:GetForward() * math.Rand(-20, 35)

        ghosts[#ghosts + 1] = {
            model = mdl,
            pos = startPos,
            target = targetPos,
            born = CurTime(),
            die = CurTime() + math.Rand(0.8, 2.2),
            speed = math.Rand(280, 600) + strength * 200,
            behavior = math.random(1, 3),
            orbitDir = math.random(0, 1) == 1 and 1 or -1,
            retargetAt = CurTime() + math.Rand(0.08, 0.24),
        }
    end

    hook.Add("Think", "ZC_Fury13NightTerrorGhostThink", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then
            clearGhosts()
            stopFearToxinMusic()
            setClassMusicSuppressed(false)
            return
        end

        local untilAt = lp:GetNWFloat("ZCFury13HallucinateUntil", 0)
        local strength = math.Clamp(lp:GetNWFloat("ZCFury13HallucinateStrength", 0), 0, 1)
        local songStartAt = lp:GetNWFloat("ZCFury13SongStartAt", 0)
        local deathAt = lp:GetNWFloat("ZCFury13DeathAt", 0)
        local activeUntil = lp:GetNWFloat("ZCFury13ActiveUntil", 0)
        local progress = math.Clamp(lp:GetNWFloat("ZCFury13Progress", 0), 0, 1)

        if activeUntil <= CurTime() then
            clearGhosts()
            stopFearToxinMusic()
            setClassMusicSuppressed(false)
            fearToxinWasActive = false
            return
        end

        if not fearToxinWasActive then
            fearToxinWasActive = true
            setClassMusicSuppressed(true)
            playFearToxinOneShot(FEAR_TOXIN_WHISPERS[math.random(#FEAR_TOXIN_WHISPERS)], 0.62, math.random(94, 106))
        end

        if songStartAt > 0 and CurTime() >= songStartAt and fearToxinMusicStartedFor ~= songStartAt then
            startFearToxinMusic(math.Clamp(0.14 + progress * 0.5, 0.14, 0.64), songStartAt)
        end

        if fearToxinClassMusicSuppressed then
            stopCompetingCombatMusic(false)
        end

        if deathAt > 0 and CurTime() > deathAt + HORROR.LongTrackEndLead + 2 then
            stopFearToxinMusic()
        end

        if CurTime() >= nextAmbientAt then
            local ambientPool = progress > 0.55 and math.random(1, 3) == 1 and FEAR_TOXIN_STINGERS or FEAR_TOXIN_WHISPERS
            playFearToxinOneShot(
                ambientPool[math.random(#ambientPool)],
                math.Clamp(0.38 + progress * 0.38, 0.38, 0.76),
                math.random(94, 108)
            )
            nextAmbientAt = CurTime() + Lerp(progress, 12, 3.8)
        end

        if (deathAt > 0 and CurTime() >= deathAt + 0.25) or untilAt <= CurTime() or strength <= 0.05 or progress < 0.33 then
            clearGhosts()
            if deathAt > 0 and CurTime() >= deathAt + 0.25 then
                stopFearToxinMusic()
            end
            return
        end

        if #ghosts > math.floor(1 + strength * 3) then
            local data = table.remove(ghosts, 1)
            if data and IsValid(data.model) then
                data.model:Remove()
            end
        end

        if CurTime() >= nextGhostAt then
            spawnGhost(lp, strength)
            nextGhostAt = CurTime() + Lerp(progress, 1.8, 0.42)
        end

        for i = #ghosts, 1, -1 do
            local data = ghosts[i]
            if not data or not IsValid(data.model) then
                table.remove(ghosts, i)
                continue
            end

            if data.die <= CurTime() then
                data.model:Remove()
                table.remove(ghosts, i)
                continue
            end

            if CurTime() >= (data.retargetAt or 0) then
                local base = lp:GetPos() + Vector(0, 0, 4)
                local near = base + lp:GetForward() * math.Rand(-16, 28)
                if data.behavior == 1 then
                    data.target = near + lp:GetRight() * math.Rand(-22, 22)
                elseif data.behavior == 2 then
                    data.target = near + lp:GetRight() * (data.orbitDir * math.Rand(44, 110))
                else
                    data.target = base - lp:GetForward() * math.Rand(8, 58) + lp:GetRight() * math.Rand(-80, 80)
                end
                data.retargetAt = CurTime() + math.Rand(0.08, 0.24)
            end

            local toTarget = data.target - data.pos
            local step = math.min(toTarget:Length(), data.speed * FrameTime())
            if step > 0.01 then
                data.pos = data.pos + toTarget:GetNormalized() * step
            end

            local alpha = math.Clamp((data.die - CurTime()) * 200, 20, 235)
            data.model:SetColor(Color(0, 0, 0, alpha))
            data.model:SetPos(data.pos)
            data.model:SetAngles((data.target - data.pos):Angle())

            if data.pos:DistToSqr(lp:GetPos()) < 55 * 55 then
                lp:EmitSound(ATTACK_SOUNDS[math.random(#ATTACK_SOUNDS)], 70, math.random(96, 108), math.Clamp(0.4 + strength * 0.3, 0.4, 0.8), CHAN_AUTO)
                data.model:Remove()
                table.remove(ghosts, i)
            end
        end
    end)

    hook.Add("PostDrawOpaqueRenderables", "ZC_Fury13NightTerrorGhostDraw", function()
        if #ghosts == 0 then return end

        render.SuppressEngineLighting(true)
        render.SetColorModulation(0.01, 0.01, 0.01)
        render.SetBlend(1)

        for i = 1, #ghosts do
            local data = ghosts[i]
            if data and IsValid(data.model) then
                data.model:SetupBones()
                data.model:FrameAdvance(FrameTime() * 1.8)
                data.model:DrawModel()
            end
        end

        render.SetColorModulation(1, 1, 1)
        render.SuppressEngineLighting(false)
    end)

    hook.Add("RenderScreenspaceEffects", "ZC_Fury13NightTerrorScreenFX", function()
        local lp = LocalPlayer()
        if not IsValid(lp) or not lp:Alive() then return end

        local untilAt = lp:GetNWFloat("ZCFury13LobotomyUntil", 0)
        local strength = math.Clamp(lp:GetNWFloat("ZCFury13LobotomyStrength", 0), 0, 1)
        if untilAt <= CurTime() or strength <= 0.05 then return end

        local fade = math.Clamp((untilAt - CurTime()) / 2.2, 0, 1)
        local amp = strength * fade

        DrawColorModify({
            ["$pp_colour_addr"] = amp * 0.18,
            ["$pp_colour_addg"] = -amp * 0.04,
            ["$pp_colour_addb"] = -amp * 0.04,
            ["$pp_colour_brightness"] = -amp * 0.2,
            ["$pp_colour_contrast"] = 1 + amp * 0.45,
            ["$pp_colour_colour"] = 1 - amp * 0.55,
            ["$pp_colour_mulr"] = amp * 0.1,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        })

        DrawMotionBlur(0.08, 0.45 + amp * 1.1, 0.01)
        DrawMaterialOverlay("effects/tp_eyefx/tunnel", amp * 0.26)

        if CurTime() >= nextFlashAt then
            if istable(hg) and isfunction(hg.AddFlash) then
                local eyePos = lp:EyePos()
                local flashPos = eyePos + lp:GetAimVector() * math.random(48, 96)
                hg.AddFlash(eyePos, 1, flashPos, math.Rand(0.18, 0.42), math.random(1700, 4200))
            end
            nextFlashAt = CurTime() + Lerp(amp, 0.6, 0.12)
        end
    end)

    hook.Add("PlayerDeath", "ZC_Fury13NightTerrorStopMusic", function(ply)
        if ply == LocalPlayer() then
            stopFearToxinMusic()
            setClassMusicSuppressed(false)
        end
    end)

    hook.Add("PostCleanupMap", "ZC_Fury13NightTerrorStopMusic", function()
        clearGhosts()
        stopFearToxinMusic()
        setClassMusicSuppressed(false)
        fearToxinWasActive = false
    end)
end
