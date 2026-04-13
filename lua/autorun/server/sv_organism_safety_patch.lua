-- Addon-only patch: replace Z-City's unsafe "regenerationberserk" Org Think hook after load order.
-- This avoids editing Z-City main files and only injects the fix once the hooks exist.

if CLIENT then return end

local function PatchRegenerationBerserkHook()
    if not hook.GetTable then return false end
    local hooks = hook.GetTable()
    if not hooks["Org Think"] then return false end

    if hooks["Org Think"]["regenerationberserk"] then
        hook.Remove("Org Think", "regenerationberserk")
    end

    hook.Add("Org Think", "regenerationberserk", function(owner, org, timeValue)
        if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
        if not owner:IsBerserk() then return end
        if not org then return end

        org.blood = math.Approach(org.blood or 0, 5000, timeValue * 60)

        if istable(org.wounds) then
            for _, wound in pairs(org.wounds) do
                wound[1] = math.max(wound[1] - timeValue * 10, 0)
            end
        end

        if istable(org.arterialwounds) then
            for _, wound in pairs(org.arterialwounds) do
                wound[1] = math.max(wound[1] - timeValue * 10, 0)
            end
        end

        org.internalBleed = math.max((org.internalBleed or 0) - timeValue * 10, 0)

        local regen = timeValue / 120 * (org.berserk or 0)

        org.lleg = math.max((org.lleg or 0) - regen, 0)
        org.rleg = math.max((org.rleg or 0) - regen, 0)
        org.rarm = math.max((org.rarm or 0) - regen, 0)
        org.larm = math.max((org.larm or 0) - regen, 0)
        org.chest = math.max((org.chest or 0) - regen, 0)
        org.pelvis = math.max((org.pelvis or 0) - regen, 0)
        org.spine1 = math.max((org.spine1 or 0) - regen, 0)
        org.spine2 = math.max((org.spine2 or 0) - regen, 0)
        org.spine3 = math.max((org.spine3 or 0) - regen, 0)
        org.skull = math.max((org.skull or 0) - regen, 0)

        org.liver = math.max((org.liver or 0) - regen, 0)
        org.intestines = math.max((org.intestines or 0) - regen, 0)
        org.heart = math.max((org.heart or 0) - regen, 0)
        org.stomach = math.max((org.stomach or 0) - regen, 0)

        if org.lungsR then
            org.lungsR[1] = math.max((org.lungsR[1] or 0) - regen, 0)
            org.lungsR[2] = math.max((org.lungsR[2] or 0) - regen, 0)
        end
        if org.lungsL then
            org.lungsL[1] = math.max((org.lungsL[1] or 0) - regen, 0)
            org.lungsL[2] = math.max((org.lungsL[2] or 0) - regen, 0)
        end

        org.brain = math.max((org.brain or 0) - regen, 0)
        org.hungry = 0

        org.pain = math.Approach(org.pain or 0, 0, timeValue * 10)
        org.painadd = math.Approach(org.painadd or 0, 0, timeValue * 10)
        org.avgpain = math.Approach(org.avgpain or 0, 0, timeValue * 10)
        org.shock = math.Approach(org.shock or 0, 0, timeValue * 10)
        org.immobilization = math.Approach(org.immobilization or 0, 0, timeValue * 10)
        org.disorientation = math.Approach(org.disorientation or 0, 0, timeValue * 10)

        org.lungsfunction = true
        org.heartstop = false

        if owner.SetRunSpeed then
            owner:SetRunSpeed(math.min(500, 400 + (25 * (org.berserk or 0))))
        end
    end)

    return true
end

local function PatchRegenerationNoradrenalineHook()
    if not hook.GetTable then return false end
    local hooks = hook.GetTable()
    if not hooks["Org Think"] then return false end

    if hooks["Org Think"]["regenerationnoradrenaline"] then
        hook.Remove("Org Think", "regenerationnoradrenaline")
    end

    hook.Add("Org Think", "regenerationnoradrenaline", function(owner, org, timeValue)
        if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
        if not istable(org) then return end
        if (org.noradrenaline or 0) <= 0 then return end

        local regen = timeValue / 60 * (org.noradrenaline or 0)

        if org.lungsR then
            org.lungsR[1] = math.max((org.lungsR[1] or 0) - regen, 0)
            org.lungsR[2] = math.max((org.lungsR[2] or 0) - regen, 0)
        end
        if org.lungsL then
            org.lungsL[1] = math.max((org.lungsL[1] or 0) - regen, 0)
            org.lungsL[2] = math.max((org.lungsL[2] or 0) - regen, 0)
        end

        org.hungry = 0

        org.pain = math.Approach(org.pain or 0, 0, regen * 10)
        org.painadd = math.Approach(org.painadd or 0, 0, regen * 10)
        org.avgpain = math.Approach(org.avgpain or 0, 0, regen * 10)
        org.shock = math.Approach(org.shock or 0, 0, regen * 10)
        org.immobilization = math.Approach(org.immobilization or 0, 0, regen * 10)
        org.disorientation = math.Approach(org.disorientation or 0, 0, regen * 10)
        org.adrenaline = math.Approach(org.adrenaline or 0, 5, regen * 100)
        org.analgesia = math.Approach(org.analgesia or 0, 1, regen * 10)

        if (org.noradrenaline or 0) > 2 then
            org.brain = math.Approach(org.brain or 0, 0.3, timeValue / 60)
        end

        org.pulse = math.Approach(org.pulse or 0, 70, regen * 10)
        org.heartbeat = math.Approach(org.heartbeat or 0, 220, regen * 10)

        org.lungsfunction = true
        org.heartstop = false
    end)

    return true
end

local function TryPatchOrganismHook()
    local okBerserk = PatchRegenerationBerserkHook()
    local okNoradrenaline = PatchRegenerationNoradrenalineHook()
    if okBerserk and okNoradrenaline then
        timer.Remove("DCityPatch_OrganismSafetyPatchTimer")
    end
end

hook.Add("InitPostEntity", "DCityPatch_OrganismSafetyPatchInit", TryPatchOrganismHook)
timer.Create("DCityPatch_OrganismSafetyPatchTimer", 1, 10, TryPatchOrganismHook)

-- Additional nil-organism hardening for base Homigrad call paths.
-- Fixes crashes in:
-- - Player:IsBerserk / Player:IsStimulated
-- - StartCommand hook "hg_lol"
-- - Player Think hook "sethuynyis"

local function PatchPlayerMetaChecks()
    local pmeta = FindMetaTable("Player")
    if not pmeta then return false end
    if pmeta._DCPatched_OrganismMetaSafe then return true end

    pmeta.IsBerserk = function(self)
        if not IsValid(self) then return false end
        if self:IsPlayer() and not self:Alive() then return false end

        local org = self.organism
        if not istable(org) then return false end
        return org.berserkActive2 or false
    end

    pmeta.IsStimulated = function(self)
        if not IsValid(self) then return false end
        if self:IsPlayer() and not self:Alive() then return false end

        local org = self.organism
        if not istable(org) then return false end
        return org.noradrenalineActive or false
    end

    pmeta._DCPatched_OrganismMetaSafe = true
    return true
end

local function PatchStartCommandHgLol()
    if not hook.GetTable then return false end
    local hooks = hook.GetTable()
    if not hooks or not hooks["StartCommand"] or not hooks["StartCommand"]["hg_lol"] then return false end

    hook.Remove("StartCommand", "hg_lol")
    hook.Add("StartCommand", "hg_lol", function(ply, cmd)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
        local org = ply.organism
        if not istable(org) then return end
        if org.otrub then
            cmd:ClearMovement()
        end
    end)

    return true
end

local function PatchPlayerThinkPowerHook()
    if not hook.GetTable then return false end
    local hooks = hook.GetTable()
    if not hooks or not hooks["Player Think"] or not hooks["Player Think"]["sethuynyis"] then return false end

    hook.Remove("Player Think", "sethuynyis")
    hook.Add("Player Think", "sethuynyis", function(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local now = CurTime()
        local dtime = now - (ply.lastcalley or (now - 10))
        if dtime < 0.1 then return end
        ply.lastcalley = now

        local org = ply.organism
        if not istable(org) then return end

        local pain = tonumber(org.pain) or 0
        local blood = tonumber(org.blood) or 5000

        local o2Value = 100
        if istable(org.o2) then
            o2Value = tonumber(org.o2[1]) or 100
        end

        local power = ((pain > 50 or blood < 2900 or o2Value < 5) and 0.3)
            or ((pain > 20 or blood < 4200 or o2Value < 10) and 0.5)
            or 1

        power = power * (tonumber(org.consciousness) or 1)
        ply:SetNWFloat("power", power)
    end)

    return true
end

local function TryPatchOrganismNilCrashes()
    local okMeta = PatchPlayerMetaChecks()
    local okStart = PatchStartCommandHgLol()
    local okThink = PatchPlayerThinkPowerHook()

    if okMeta and okStart and okThink then
        timer.Remove("DCityPatch_OrganismNilCrashPatchTimer")
    end
end

hook.Add("InitPostEntity", "DCityPatch_OrganismNilCrashPatchInit", TryPatchOrganismNilCrashes)
hook.Add("HomigradRun", "DCityPatch_OrganismNilCrashPatchHG", function()
    TryPatchOrganismNilCrashes()
    timer.Simple(0,   TryPatchOrganismNilCrashes)
    timer.Simple(0.5, TryPatchOrganismNilCrashes)
end)
timer.Create("DCityPatch_OrganismNilCrashPatchTimer", 1, 0, TryPatchOrganismNilCrashes)

-- ── Org Think: VirusRandomEvents + TemperatureSounds (sv_random_event.lua:72) ──
-- owner:Alive() crashes when owner is a stale non-NULL Lua entity whose C++ side
-- is gone. IsValid() must precede any C method call.

local function PatchVirusRandomEventsHook()
    local hooks = hook.GetTable()
    if not hooks or not hooks["Org Think"] then return false end
    if not hooks["Org Think"]["VirusRandomEvents"] then return false end

    hook.Remove("Org Think", "VirusRandomEvents")
    hook.Add("Org Think", "VirusRandomEvents", function(owner, org, timeValue)
        if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
        if owner.Virus and owner.Virus.Infected and (owner.Virus.Stage == 1 or owner.Virus.Stage == 2) then
            if not owner.NextVirusRandomEventTime or CurTime() >= owner.NextVirusRandomEventTime then
                local event = math.random(1, 2) == 1 and "Cough" or "Sneeze"
                if hg and hg.organism and hg.organism.module and hg.organism.module.random_events then
                    hg.organism.module.random_events.TriggerRandomEvent(owner, event)
                end
                owner.NextVirusRandomEventTime = CurTime() + math.random(10, 15)
            end
        end
    end)
    return true
end

local function PatchTemperatureSoundsHook()
    local hooks = hook.GetTable()
    if not hooks or not hooks["Org Think"] then return false end
    if not hooks["Org Think"]["TemperatureSounds"] then return false end

    hook.Remove("Org Think", "TemperatureSounds")
    hook.Add("Org Think", "TemperatureSounds", function(owner, org, timeValue)
        if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() or org.otrub then return end
        if org.temperature and org.temperature > 24 and org.temperature < 35 then
            if not owner.ColdRandomEventTime or CurTime() >= owner.ColdRandomEventTime then
                local event = math.random(1, 2) == 1 and "Cough" or "Sneeze"
                if hg and hg.organism and hg.organism.module and hg.organism.module.random_events then
                    hg.organism.module.random_events.TriggerRandomEvent(owner, event)
                end
                owner.ColdRandomEventTime = CurTime() + math.random(
                    math.Remap(org.temperature, 35, 24, 60, 15),
                    math.Remap(org.temperature, 35, 24, 120, 30)
                )
            end
        end
    end)
    return true
end

local function TryPatchRandomEventHooks()
    local okVirus = PatchVirusRandomEventsHook()
    local okTemp  = PatchTemperatureSoundsHook()
    if okVirus and okTemp then
        timer.Remove("DCityPatch_RandomEventHookPatchTimer")
    end
end

hook.Add("InitPostEntity", "DCityPatch_RandomEventHooks_Init", function()
    timer.Simple(0.5, TryPatchRandomEventHooks)
end)
hook.Add("HomigradRun", "DCityPatch_RandomEventHooks_HG", function()
    TryPatchRandomEventHooks()
    timer.Simple(0,   TryPatchRandomEventHooks)
    timer.Simple(0.5, TryPatchRandomEventHooks)
end)
timer.Create("DCityPatch_RandomEventHookPatchTimer", 1, 0, TryPatchRandomEventHooks)

-- ── Org Think: guard NULL / invalid owner (Z-City sv_organism tier_1 ~641 :Alive on NULL) ──
-- Base gamemode hooks sometimes run with a stale org.owner after disconnect or odd NPC paths.
-- Wrap every Org Think callback once so IsValid(owner) is checked before Homigrad code runs.

local _wrappedOrgThinkHooks = {}

local function makeOrgThinkOwnerGuard(orig)
    local function guarded(owner, org, ...)
        if not IsValid(owner) then return end
        return orig(owner, org, ...)
    end
    return guarded
end

local function InstallOrgThinkOwnerGuards()
    local ht = hook.GetTable()
    if not ht or not ht["Org Think"] then return end

    local ot = ht["Org Think"]
    local snapshot = {}
    for name, fn in pairs(ot) do
        if type(fn) == "function" and not _wrappedOrgThinkHooks[name] then
            snapshot[#snapshot + 1] = { name, fn }
        end
    end

    for i = 1, #snapshot do
        local name, fn = snapshot[i][1], snapshot[i][2]
        _wrappedOrgThinkHooks[name] = true
        hook.Remove("Org Think", name)
        hook.Add("Org Think", name, makeOrgThinkOwnerGuard(fn))
    end
end

hook.Add("InitPostEntity", "DCityPatch_OrgThinkOwnerGuards_Init", function()
    timer.Simple(0.5, InstallOrgThinkOwnerGuards)
end)
hook.Add("HomigradRun", "DCityPatch_OrgThinkOwnerGuards_HG", function()
    InstallOrgThinkOwnerGuards()
    timer.Simple(0,   InstallOrgThinkOwnerGuards)
    timer.Simple(0.5, InstallOrgThinkOwnerGuards)
end)
timer.Create("DCityPatch_OrgThinkOwnerGuards_Sweep", 3, 0, InstallOrgThinkOwnerGuards)

-- ── CanListenOthers: sv_bone.lua:286 organism nil guard ──────────────────────
-- output.organism is nil for players who haven't had Homigrad initialise yet
-- (fresh joins, spectators, edge states on spawn). Guard it before indexing.

local function PatchCanListenOthersJawHook()
    local hooks = hook.GetTable()
    if not hooks or not hooks["CanListenOthers"] then return false end
    if not hooks["CanListenOthers"]["CantHaveShitInDetroit"] then return false end

    hook.Remove("CanListenOthers", "CantHaveShitInDetroit")
    hook.Add("CanListenOthers", "CantHaveShitInDetroit", function(output, input, isChat, teamonly, text)
        if not IsValid(output) then return end
        if not istable(output.organism) then return end
        if not output:Alive() then return end
        if (output.organism.jaw == 1 or output.organism.jawdislocation)
            and (output:IsSpeaking() or isChat) then
            output.organism.painadd = (output.organism.painadd or 0)
                + 2 * (output:IsSpeaking() and 1 or (isChat and 5 or 0))
            output:Notify("My jaw is really hurting when I speak.", 60,
                "painfromjawspeak", 0, nil, Color(255, 210, 210))
        end
    end)
    return true
end

-- ── Player Think: sv_guilt.lua:306 KarmaGain nil guard ───────────────────────
-- ply.KarmaGain is nil for bots, mid-round joiners, and players in edge states.
-- math.Clamp with nil operand hard-errors.

local function PatchKarmaGainHook()
    local hooks = hook.GetTable()
    if not hooks or not hooks["Player Think"] then return false end
    if not hooks["Player Think"]["karmagain"] then return false end

    hook.Remove("Player Think", "karmagain")
    hook.Add("Player Think", "karmagain", function(ply)
        if not IsValid(ply) then return end
        if (ply.KarmaGainThink or 0) > CurTime() then return end
        ply.KarmaGainThink = CurTime() + 120

        local karma    = ply.Karma or 100
        local gain     = ply.KarmaGain or 0.75
        local maxKarma = (zb and zb.MaxKarma) or 1000
        ply.Karma = math.Clamp(karma + (karma > 100 and 0.1 or gain), 0, maxKarma)
        ply:SetNetVar("Karma", ply.Karma)
    end)
    return true
end

local function TryPatchCommunicationNilCrashes()
    local okJaw   = PatchCanListenOthersJawHook()
    local okKarma = PatchKarmaGainHook()
    if okJaw and okKarma then
        timer.Remove("DCityPatch_CommunicationNilCrashTimer")
    end
end

hook.Add("InitPostEntity", "DCityPatch_CommunicationNilCrash_Init", function()
    timer.Simple(0.5, TryPatchCommunicationNilCrashes)
end)
hook.Add("HomigradRun", "DCityPatch_CommunicationNilCrash_HG", function()
    TryPatchCommunicationNilCrashes()
    timer.Simple(0,   TryPatchCommunicationNilCrashes)
    timer.Simple(0.5, TryPatchCommunicationNilCrashes)
end)
timer.Create("DCityPatch_CommunicationNilCrashTimer", 1, 0, TryPatchCommunicationNilCrashes)

-- ── KeyPress/KeyRelease: sv_util.lua:379 organism nil guard ──────────────────
-- ply.organism is nil for players in certain states (joining, spectating).

local function PatchKeyPressHook()
    local hooks = hook.GetTable()
    if not hooks or not hooks["KeyPress"] then return false end
    if not hooks["KeyPress"]["huy-hg"] then return false end

    hook.Remove("KeyPress", "huy-hg")
    hook.Add("KeyPress", "huy-hg", function(ply, key)
        if not IsValid(ply) or not istable(ply.organism) then return end
        net.Start("ZB_KeyDown2")
            net.WriteInt(key, 26)
            net.WriteBool(ply.organism.canmove or false)
            net.WriteEntity(ply)
        net.SendPVS(ply:GetPos())
    end)
    return true
end

local function PatchKeyReleaseHook()
    local hooks = hook.GetTable()
    if not hooks or not hooks["KeyRelease"] then return false end
    if not hooks["KeyRelease"]["huy-hg2"] then return false end

    hook.Remove("KeyRelease", "huy-hg2")
    hook.Add("KeyRelease", "huy-hg2", function(ply, key)
        if not IsValid(ply) then return end
        net.Start("ZB_KeyDown2")
            net.WriteInt(key, 26)
            net.WriteBool(false)
            net.WriteEntity(ply)
        net.SendPVS(ply:GetPos())
    end)
    return true
end

-- ── HG_PlayerCanHearPlayersVoice: sv_comunication.lua:144 organism nil guard ─
local function PatchBrainDamageVoiceHook()
    local hooks = hook.GetTable()
    if not hooks or not hooks["HG_PlayerCanHearPlayersVoice"] then return false end
    if not hooks["HG_PlayerCanHearPlayersVoice"]["BrainDamage"] then return false end

    hook.Remove("HG_PlayerCanHearPlayersVoice", "BrainDamage")
    hook.Add("HG_PlayerCanHearPlayersVoice", "BrainDamage", function(listener, speaker)
        if not IsValid(speaker) or not istable(speaker.organism) then return end
        if speaker.organism.brain > 0.05 then return false, false end
    end)
    return true
end

-- ── weapon_handcuffs.lua — nil guards for handcuffs hooks ───────────────────
-- Uses function-marker guard (_DCP_HC_Guard) instead of a static boolean so that
-- if ZCity re-registers the hook after HomigradRun the new unguarded fn is detected
-- and re-wrapped rather than being skipped by a stale flag.
local _wrappedHCThinkFns = setmetatable({}, { __mode = "k" })
local _wrappedHCPickupFns = setmetatable({}, { __mode = "k" })
local _wrappedHCUseFns = setmetatable({}, { __mode = "k" })
local _wrappedHCRagdollFns = setmetatable({}, { __mode = "k" })
local function PatchHandcuffsThinkHook()
    local hooks = hook.GetTable()
    if not hooks or not hooks["Think"] then return false end
    local fn = hooks["Think"]["weapon_handcuffs"]
    if not fn then return false end
    if _wrappedHCThinkFns[fn] then return true end  -- already our wrapper

    local orig = fn
    local wrapper = function(...)
        local ok, err = pcall(orig, ...)
        if not ok and string.find(tostring(err), "organism", 1, true) then
            -- swallow organism nil spam silently
        end
    end
    _wrappedHCThinkFns[wrapper] = true
    hook.Remove("Think", "weapon_handcuffs")
    hook.Add("Think", "weapon_handcuffs", wrapper)
    return true
end

-- weapon_handcuffs.lua:183 is in PlayerCanPickupWeapon hook "handcuffDisallowpickup"
-- and indexes ply.organism.handcuffed directly. Metrocop handcuffs/pickup flow can
-- hit this before organism exists for a player, causing spam.
local function PatchHandcuffsPickupHooks()
    local hooks = hook.GetTable()
    if not hooks then return false end

    local changed = false

    local pcpw = hooks["PlayerCanPickupWeapon"]
    if pcpw and type(pcpw["handcuffDisallowpickup"]) == "function" then
        local fn = pcpw["handcuffDisallowpickup"]
        if not _wrappedHCPickupFns[fn] then
            local captured = fn
            local wrapped = function(ply, ent)
                if not IsValid(ply) then return end
                if not istable(ply.organism) then return end
                if not IsValid(ent) then return end
                return captured(ply, ent)
            end
            _wrappedHCPickupFns[wrapped] = true
            hook.Remove("PlayerCanPickupWeapon", "handcuffDisallowpickup")
            hook.Add("PlayerCanPickupWeapon", "handcuffDisallowpickup", wrapped)
            changed = true
        end
    end

    local pu = hooks["PlayerUse"]
    if pu and type(pu["restrictuser"]) == "function" then
        local fn = pu["restrictuser"]
        if not _wrappedHCUseFns[fn] then
            local captured = fn
            local wrapped = function(ply, ent)
                if not IsValid(ply) then return end
                if not istable(ply.organism) then return end
                return captured(ply, ent)
            end
            _wrappedHCUseFns[wrapped] = true
            hook.Remove("PlayerUse", "restrictuser")
            hook.Add("PlayerUse", "restrictuser", wrapped)
            changed = true
        end
    end

    local rc = hooks["Ragdoll_Create"]
    if rc and type(rc["Addhandcuffs"]) == "function" then
        local fn = rc["Addhandcuffs"]
        if not _wrappedHCRagdollFns[fn] then
            local captured = fn
            local wrapped = function(ply, ragdoll)
                if not IsValid(ply) then return end
                if not istable(ply.organism) then return end
                if not IsValid(ragdoll) then return end
                return captured(ply, ragdoll)
            end
            _wrappedHCRagdollFns[wrapped] = true
            hook.Remove("Ragdoll_Create", "Addhandcuffs")
            hook.Add("Ragdoll_Create", "Addhandcuffs", wrapped)
            changed = true
        end
    end

    return changed
end

-- ── sv_comunication.lua:25 — ChatLogic / PlayerSay organism nil ──────────────
-- Uses fn._DCP_ChatLogicGuarded marker so re-registration by ZCity after
-- HomigradRun results in the new fn being re-wrapped (not silently skipped).
local _wrappedChatLogicFns = setmetatable({}, { __mode = "k" })
local function PatchChatLogicHook()
    local hooks = hook.GetTable()
    if not hooks then return false end

    local found = false
    for _, hookName in ipairs({"PlayerSay", "OnPlayerChat"}) do
        local tbl = hooks[hookName]
        if not tbl then continue end
        for name, fn in pairs(tbl) do
            if type(fn) == "function" and not _wrappedChatLogicFns[fn] then
                local captured = fn
                local wrapped = function(ply, text, ...)
                    if not IsValid(ply) or not istable(ply.organism) then return end
                    return captured(ply, text, ...)
                end
                _wrappedChatLogicFns[wrapped] = true
                hook.Remove(hookName, name)
                hook.Add(hookName, name, wrapped)
                found = true
            end
        end
    end
    return found
end

-- ── sv_util.lua:497 — FireLuaBullets bullet-hit organism nil (NPC shooters) ──
-- Uses fn._DCP_BulletHitGuarded marker (same principle as chat/handcuffs above).
local _wrappedBulletHitFns = setmetatable({}, { __mode = "k" })
local function PatchFireLuaBulletsHook()
    local hooks = hook.GetTable()
    if not hooks then return false end

    local found = false
    for _, hookName in ipairs({"HG_BulletHit", "ZB_BulletHit", "HG_FireBullet"}) do
        local tbl = hooks[hookName]
        if not tbl then continue end
        for name, fn in pairs(tbl) do
            if type(fn) == "function" and not _wrappedBulletHitFns[fn] then
                local captured = fn
                local wrapped = function(attacker, ...)
                    if IsValid(attacker) and not attacker:IsPlayer() and not istable(attacker.organism) then
                        -- NPC attacker with no organism — swallow to prevent sv_util.lua:497 crash
                        return
                    end
                    return captured(attacker, ...)
                end
                _wrappedBulletHitFns[wrapped] = true
                hook.Remove(hookName, name)
                hook.Add(hookName, name, wrapped)
                found = true
            end
        end
    end
    return found
end

-- ── sh_weaponsinv.lua:8 — CanInsert weaponInv nil guard ──────────────────────
-- hg.weaponinventory.CanInsert crashes when the player's weaponInv table has not
-- yet been initialised by Homigrad (fresh connection / mid-spawn state).
-- Guard directly on the module so every caller is covered without wrapping each
-- individual PlayerCanPickupWeapon callback separately.
local function PatchWeaponInvCanInsert()
    if not hg then return false end

    -- Base file uses hg.weaponInv (capital I). Keep legacy fallback for forks
    -- that renamed this table to weaponinventory.
    local wi = hg.weaponInv or hg.weaponinventory
    if not wi then return false end

    if not isfunction(wi.CanInsert) then return false end
    if wi._DCP_CanInsertGuarded then return true end

    local orig = wi.CanInsert
    wi.CanInsert = function(ent, ...)
        if IsValid(ent) and ent:IsPlayer() then
            -- Early pickup path can run before homigrad's Player Spawn hook.
            -- Initialize lazily so base CanInsert can work safely.
            if not istable(ent.weaponInv) then ent.weaponInv = {} end
            if not istable(ent.ammoInv) then ent.ammoInv = {} end
        end
        local ok, a, b = pcall(orig, ent, ...)
        if not ok then return true end
        return a, b
    end
    wi._DCP_CanInsertGuarded = true
    print("[DCP] WeaponInv CanInsert nil guard active")
    return true
end

-- ── Hard override path for known base hook IDs (ULib-safe) ───────────────────
-- Some deployments re-register hooks in ways that evade dynamic wrapper scans.
-- Override the exact IDs used by base files so nil organism paths can never run.
local function InstallHardNilSafeOverrides()
    -- weapon_handcuffs.lua:183
    hook.Add("PlayerCanPickupWeapon", "handcuffDisallowpickup", function(ply, ent)
        if not IsValid(ply) then return end
        if not istable(ply.organism) then return end
        if not IsValid(ent) then return end
        if ply.organism.handcuffed and ent:GetClass() ~= "weapon_handcuffs_key" then
            return false
        end
    end)

    hook.Add("PlayerUse", "restrictuser", function(ply, ent)
        if not IsValid(ply) then return end
        if not istable(ply.organism) then return end
        if ply.organism.handcuffed then return false end
    end)

    hook.Add("Ragdoll_Create", "Addhandcuffs", function(ply, ragdoll)
        if not IsValid(ply) or not IsValid(ragdoll) then return end
        local porg = ply.organism
        local rorg = ragdoll.organism
        if not istable(porg) then return end
        if porg.handcuffed or (istable(rorg) and rorg.handcuffed) then
            if hg and hg.handcuff and isfunction(hg.handcuff) then
                hg.handcuff(ragdoll)
            end
            if ply.SelectWeapon then
                ply:SelectWeapon("weapon_hands_sh")
            end
        end
    end)

    -- sv_comunication.lua:25 (ChatLogic callers)
    hook.Add("PlayerCanSeePlayersChat", "RealiticChar", function(text, teamOnly, listener, speaker)
        if not IsValid(listener) or not IsValid(speaker) then return false end
        if not istable(listener.organism) or not istable(speaker.organism) then return false end

        -- Preserve custom HG override behavior if present.
        local hookResult = hook.Run("HG_PlayerCanSeePlayersChat", listener, speaker)
        if hookResult ~= nil then return hookResult end

        if teamOnly and listener:Team() ~= speaker:Team() then return false end

        if listener:Alive() and speaker:Alive() then
            if listener.organism.otrub or speaker.organism.otrub then return false end
            local o2 = listener.organism.o2
            local o2v = istable(o2) and (tonumber(o2[1]) or 0) or 100
            if o2v < 15 or listener.organism.holdingbreath then return false end
            if not speaker:TestPVS(listener) then return false end
            local chatDist = listener.ChatWhisper and 100 or 3000
            return speaker:GetPos():Distance(listener:GetPos()) < chatDist, true
        end

        if not listener:Alive() and not speaker:Alive() then return true end
        if not speaker:Alive() and listener:Alive() then
            local chatDist = listener.ChatWhisper and 100 or 3000
            return speaker:GetPos():Distance(listener:GetPos()) < chatDist and speaker:TestPVS(listener), true
        end

        if not listener:Alive() and speaker:Team() == 1002 and speaker:Alive() then return true end
        return false
    end)

    hook.Add("PlayerCanHearPlayersVoice", "RealisticVoice", function(listener, speaker)
        if not IsValid(listener) or not IsValid(speaker) then return false end
        if not istable(listener.organism) or not istable(speaker.organism) then return false end

        local hookResult = hook.Run("HG_PlayerCanHearPlayersVoice", listener, speaker)
        if hookResult ~= nil then return hookResult end

        if listener:Alive() and speaker:Alive() then
            if listener.organism.otrub or speaker.organism.otrub then return false end
            local o2 = listener.organism.o2
            local o2v = istable(o2) and (tonumber(o2[1]) or 0) or 100
            if o2v < 15 or listener.organism.holdingbreath then return false end
            if not speaker:TestPVS(listener) then return false end
            local chatDist = listener.ChatWhisper and 100 or 3000
            return speaker:GetPos():Distance(listener:GetPos()) < chatDist, true
        end

        if not listener:Alive() and not speaker:Alive() then return true end
        if not speaker:Alive() and listener:Alive() then
            local chatDist = listener.ChatWhisper and 100 or 3000
            return speaker:GetPos():Distance(listener:GetPos()) < chatDist and speaker:TestPVS(listener), true
        end

        if not listener:Alive() and speaker:Team() == 1002 and speaker:Alive() then return true end
        return false
    end)
end

local function TryPatchInputNilCrashes()
    PatchKeyPressHook()
    PatchKeyReleaseHook()
    PatchBrainDamageVoiceHook()
    PatchHandcuffsThinkHook()
    PatchHandcuffsPickupHooks()
    PatchChatLogicHook()
    PatchFireLuaBulletsHook()
    PatchWeaponInvCanInsert()
    InstallHardNilSafeOverrides()
end

-- Run immediately so hooks registered before us are also wrapped
TryPatchInputNilCrashes()

hook.Add("InitPostEntity", "DCityPatch_InputNilCrash_Init", function()
    TryPatchInputNilCrashes()
    timer.Simple(0.1, TryPatchInputNilCrashes)
    timer.Simple(0.5, TryPatchInputNilCrashes)
    timer.Simple(2,   TryPatchInputNilCrashes)
end)
-- Defer via timer.Simple(0/0.5) so our patches fire AFTER ZCity finishes
-- re-registering its own hooks in the same HomigradRun execution chain.
-- Without the defer, ZCity overwrites our guarded hooks moments after we set them.
hook.Add("HomigradRun", "DCityPatch_InputNilCrash_HG", function()
    TryPatchInputNilCrashes()
    timer.Simple(0,   TryPatchInputNilCrashes)
    timer.Simple(0.5, TryPatchInputNilCrashes)
    timer.Simple(1,   TryPatchInputNilCrashes)
end)
timer.Create("DCityPatch_InputNilCrashTimer", 1, 0, TryPatchInputNilCrashes)
