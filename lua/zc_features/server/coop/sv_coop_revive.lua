-- provided the target has no amputated limbs.
-- Uses the same eyetrace pattern as ZCity's hg_fixdislocation concommand.

local initialized = false
local REVIVE_RANGE = 100
local REVIVE_COOLDOWN = 8

local REVIVER_CLASSES = {
    ["Gordon"] = true,
}

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

local function IsReviver(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if REVIVER_CLASSES[ply.PlayerClassName] then return true end
    if ply.subClass == "medic" then return true end
    return false
end

local function HasAmputatedLeg(org)
    -- Only block revive if legs are missing (back-carry only for leg amputees)
    -- Arm/head amputees can still be revived
    return org.llegamputated or org.rlegamputated
end

local function BackCarryWillHandle(reviver, target)
    return isfunction(ZC_BackCarryWouldHandle) and ZC_BackCarryWouldHandle(reviver, target) or false
end

local function ResolveUseTarget(ply, explicitTarget)
    local target = explicitTarget

    if IsValid(target) and not target:IsPlayer() and IsValid(target.ply) and target.ply:IsPlayer() then
        target = target.ply
    end

    if not IsValid(target) then
        if not hg or not hg.eyeTrace then return nil end

        local tr = hg.eyeTrace(ply)
        target = tr and tr.Entity or nil
        if IsValid(target) and not target:IsPlayer() and IsValid(target.ply) and target.ply:IsPlayer() then
            target = target.ply
        end
    end

    if not IsValid(target) or not target:IsPlayer() then return nil end
    if target == ply then return nil end
    if target:GetPos():Distance(ply:GetPos()) > REVIVE_RANGE then return nil end

    return target
end

local function RevivePlayer(reviver, target, options)
    options = options or {}

    if not IsValid(reviver) or not IsValid(target) then return false, "invalid" end
    if not reviver:Alive() or not target:Alive() then return false, "not_alive" end
    if not IsReviver(reviver) then return false, "not_reviver" end
    if not reviver.organism or reviver.organism.otrub then return false, "reviver_down" end

    local org = target.organism
    if not org then return false, "no_organism" end
    if not org.otrub then
        if not options.silentTargetState then
            reviver:ChatPrint("[ZCity] " .. target:Nick() .. " is not incapacitated.")
        end
        return false, "target_not_incapped"
    end

    -- Block if legs are amputated (back-carry only system for leg amputees)
    if HasAmputatedLeg(org) then
        reviver:ChatPrint("[ZCity] Cannot revive " .. target:Nick() .. " — missing leg(s). Use Back Carry instead.")
        target:ChatPrint("[ZCity] " .. reviver:Nick() .. " cannot revive you — you are missing leg(s). Use Back Carry.")
        return false, "missing_legs"
    end

    if (reviver.ZCReviveCooldown or 0) > CurTime() then
        local remaining = math.ceil(reviver.ZCReviveCooldown - CurTime())
        reviver:ChatPrint("[ZCity] Revive on cooldown for " .. remaining .. "s.")
        return false, "cooldown"
    end
    reviver.ZCReviveCooldown = CurTime() + REVIVE_COOLDOWN

    -- Reset the organism values that keep needotrub = true.
    -- Mirrors the thresholds checked in sv_organism.lua line ~100:
    -- otrub fires when: blood < 2900, consciousness <= 0.4, spine damage,
    -- both legs broken, or otrub already set.
    org.blood = math.max(org.blood, 3200)
    org.consciousness = 1
    org.spine1 = 0
    org.spine2 = 0
    org.spine3 = 0
    org.lleg = 0
    org.rleg = 0
    org.pain = math.min(org.pain, 20)
    org.shock = math.min(org.shock, 10)
    org.pulse = math.max(org.pulse, 40)
    org.heartstop = false
    org.needotrub = false
    org.otrub = false
    org.uncon_timer = 0

    if org.wounds then
        for _, wound in pairs(org.wounds) do
            wound[1] = math.min(wound[1], 0.3)
        end
    end

    hg.FakeUp(target, true)

    reviver:ChatPrint("[ZCity] You revived " .. target:Nick() .. ".")
    target:ChatPrint("[ZCity] You were revived by " .. reviver:Nick() .. ".")
    target:EmitSound("hl1/fvox/bell.wav", 70)

    local bleedoutTimer = "ZC_BleedOut_" .. target:SteamID64()
    if timer.Exists(bleedoutTimer) then
        timer.Remove(bleedoutTimer)
    end

    return true, "revived"
end

local function TryReviveUse(reviver, options)
    options = options or {}

    if not IsCoopRoundActive() then return false, "inactive_round" end
    if not IsValid(reviver) or not reviver:IsPlayer() or not reviver:Alive() then return false, "invalid_reviver" end
    if not IsReviver(reviver) then return false, "not_reviver" end
    if reviver.organism and reviver.organism.otrub then return false, "reviver_down" end

    local target = ResolveUseTarget(reviver, options.target)
    if not IsValid(target) then return false, "no_target" end
    if not target.organism or not target.organism.otrub then return false, "target_not_incapped" end
    if not options.ignoreBackCarry and BackCarryWillHandle(reviver, target) then
        return false, "backcarry_pending"
    end

    return RevivePlayer(reviver, target, options)
end

_G.ZC_CoopTryReviveUse = TryReviveUse

local function Initialize()
    if initialized then return end
    initialized = true

    hook.Add("KeyPress", "ZCity_Revive", function(ply, key)
        if key ~= IN_USE then return end
        TryReviveUse(ply)
    end)
end

hook.Add("InitPostEntity", "ZC_CoopInit_svcooprevive", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)

hook.Add("Think", "ZC_CoopInit_svcooprevive_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svcooprevive_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)
