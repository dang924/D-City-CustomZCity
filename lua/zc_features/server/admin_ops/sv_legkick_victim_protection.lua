if CLIENT then return end

-- Kick victim protection disabled until camera/vehicle issues are resolved.
local ENABLE_LEGKICK_VICTIM_PROTECTION = false
if not ENABLE_LEGKICK_VICTIM_PROTECTION then return end

local PROTECT_DURATION = 0.8
local DEBUG_CVAR = GetConVar("zc_debug_commands") or CreateConVar("zc_debug_commands", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED), "Master toggle for debug console commands (0=off, 1=on)")
local KICK_DETECT_GRACE = 0.2
local KICK_DETECT_RANGE_SQR = 140 * 140

local protectedVictims = {}

local function isSupportedRound()
    if not CurrentRound then return true end
    local round = CurrentRound()
    if not istable(round) then return true end
    local name = round.name
    return name == "coop" or name == "event"
end

local function isInVehicle(ply)
    if not IsValid(ply) then return false end
    -- SimFPhys: player entity is tracked directly by the addon
    if ply.IsDrivingSimfphys and ply:IsDrivingSimfphys() then return true end
    -- Glide: NW seat index is set on the player entity even when ragdolled via hg.Fake
    if ply.GlideGetVehicle and IsValid(ply:GlideGetVehicle()) then return true end
    -- Standard GMod vehicle seat (non-ragdoll vehicle mods)
    if ply:InVehicle() then return true end
    return false
end

local function dbg(fmt, ...)
    if not DEBUG_CVAR:GetBool() then return end
    print("[KickDebug:Protect] " .. string.format(fmt, ...))
end

local function resolvePlayerFromEntity(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then return ent end

    if IsValid(ent.ply) and ent.ply:IsPlayer() then
        return ent.ply
    end

    if hg and hg.RagdollOwner then
        local owner = hg.RagdollOwner(ent)
        if IsValid(owner) and owner:IsPlayer() then
            return owner
        end
    end

    if ent.GetNWEntity then
        local owner = ent:GetNWEntity("RagdollOwner")
        if IsValid(owner) and owner:IsPlayer() then
            return owner
        end
    end

    if ent.GetOwner then
        local owner = ent:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            return owner
        end
    end

    return nil
end

local function isProtectedVictim(ply)
    local data = protectedVictims[ply]
    return data and CurTime() <= data.untilTime
end

local function isHandsInflictor(inflictor)
    if not IsValid(inflictor) then return true end
    if not inflictor.IsWeapon or not inflictor:IsWeapon() then return true end

    local class = inflictor:GetClass()
    return class == "weapon_hands_sh" or class == "weapon_hg_coolhands"
end

local function isPlayerKickDamage(victim, dmginfo)
    local rawAttacker = dmginfo:GetAttacker()
    local rawInflictor = dmginfo:GetInflictor()
    local attacker = resolvePlayerFromEntity(rawAttacker) or resolvePlayerFromEntity(rawInflictor)
    local victimPly = resolvePlayerFromEntity(victim)

    if DEBUG_CVAR:GetBool() and IsValid(attacker) and attacker:IsPlayer() and attacker:GetNWFloat("InLegKick", 0) > CurTime() then
        dbg(
            "candidate hit: atk=%s victimEnt=%s victimPly=%s inf=%s dmg=%.2f",
            attacker:Nick(),
            IsValid(victim) and victim:GetClass() or "nil",
            IsValid(victimPly) and victimPly:Nick() or "nil",
            IsValid(rawInflictor) and rawInflictor:GetClass() or "nil",
            dmginfo:GetDamage()
        )
    end

    if not IsValid(attacker) or not attacker:IsPlayer() then
        dbg("reject: invalid attacker (%s)", tostring(rawAttacker))
        return false
    end
    if not IsValid(victimPly) then
        dbg("reject: could not resolve victim player from %s", IsValid(victim) and victim:GetClass() or tostring(victim))
        return false
    end

    -- Never run kick-protection in vehicle contexts; this avoids interfering
    -- with seat/weld/camera behavior for simfphys, Glide, and pods.
    if isInVehicle(victimPly) or isInVehicle(attacker) then
        dbg("reject: vehicle context attacker=%s victim=%s", attacker:Nick(), victimPly:Nick())
        return false
    end

    if attacker == victimPly then
        dbg("reject: self kick attempt by %s", attacker:Nick())
        return false
    end

    if attacker:GetNWFloat("InLegKick", 0) <= CurTime() then
        dbg("reject: attacker not in InLegKick window attacker=%s", attacker:Nick())
        return false
    end
    if not isHandsInflictor(dmginfo:GetInflictor()) then
        local inf = dmginfo:GetInflictor()
        dbg("warning: non-hand inflictor attacker=%s inflictor=%s (continuing due kick window)", attacker:Nick(), IsValid(inf) and inf:GetClass() or "nil")
    end

    dbg("accept kick: attacker=%s victim=%s dmg=%.2f", attacker:Nick(), victimPly:Nick(), dmginfo:GetDamage())
    return true, victimPly, attacker
end

local function tryForceStand(ply)
    if not IsValid(ply) then return end
    if not (hg and hg.FakeUp) then return end

    if IsValid(ply.FakeRagdoll) or (ply.organism and ply.organism.otrub) then
        hg.FakeUp(ply, true, true)
    end
end

hook.Add("EntityTakeDamage", "DCityPatch_LegKickVictimProtection", function(victim, dmginfo)
    if not isKickProtectionEnabled() then return end
    if not isSupportedRound() then return end
    local ok, victimPly, attacker = isPlayerKickDamage(victim, dmginfo)
    if not ok then return end
    -- Intentionally avoid monkey-patching hg.Fake/hg.AddForceRag here.
    -- Those global overrides are unsafe and can interfere with vehicle state/camera flow.

    local now = CurTime()
    protectedVictims[victimPly] = {
        untilTime = now + PROTECT_DURATION,
        velocity = victimPly:GetVelocity(),
    }
    dbg("protect start: victim=%s attacker=%s until=%.2f bot=%s", victimPly:Nick(), IsValid(attacker) and attacker:Nick() or "?", now + PROTECT_DURATION, tostring(victimPly:IsBot()))

    -- Neutralize impulse from damage force where possible.
    dmginfo:SetDamageForce(vector_origin)

    timer.Simple(0, function()
        if not IsValid(victimPly) then return end
        dbg("force stand tick: victim=%s fake=%s otrub=%s", victimPly:Nick(), tostring(IsValid(victimPly.FakeRagdoll)), tostring(victimPly.organism and victimPly.organism.otrub))
        tryForceStand(victimPly)
    end)
end)

hook.Add("SetupMove", "DCityPatch_LegKickVictimNoMove", function(ply, mv, cmd)
    if not isKickProtectionEnabled() then return end
    local data = protectedVictims[ply]
    if not data then return end

    local now = CurTime()
    if now > data.untilTime then
        protectedVictims[ply] = nil
        dbg("protect end (SetupMove): victim=%s", ply:Nick())
        return
    end

    if isInVehicle(ply) then
        protectedVictims[ply] = nil
        dbg("protect cleared (vehicle): victim=%s", ply:Nick())
        return
    end

    local desired = data.velocity or vector_origin
    mv:SetVelocity(desired)
    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
    mv:SetUpSpeed(0)

    if cmd then
        cmd:RemoveKey(IN_MOVELEFT)
        cmd:RemoveKey(IN_MOVERIGHT)
        cmd:RemoveKey(IN_FORWARD)
        cmd:RemoveKey(IN_BACK)
        cmd:RemoveKey(IN_JUMP)
    end
end)

hook.Add("Think", "DCityPatch_LegKickVictimVelocityClamp", function()
    if not isKickProtectionEnabled() then return end
    local now = CurTime()

    for ply, data in pairs(protectedVictims) do
        if not IsValid(ply) then
            protectedVictims[ply] = nil
            continue
        end

        if now > data.untilTime then
            protectedVictims[ply] = nil
            dbg("protect end (Think): victim=%s", ply:Nick())
            continue
        end

        if isInVehicle(ply) then
            protectedVictims[ply] = nil
            dbg("protect cleared (vehicle/Think): victim=%s", ply:Nick())
            continue
        end

        local desired = data.velocity or vector_origin
        local delta = desired - ply:GetVelocity()
        ply:SetVelocity(delta)
        tryForceStand(ply)
    end
end)

hook.Add("PlayerDisconnected", "DCityPatch_LegKickVictimCleanup", function(ply)
    if not isKickProtectionEnabled() then return end
    protectedVictims[ply] = nil
    dbg("cleanup: disconnected=%s", IsValid(ply) and ply:Nick() or "unknown")
end)
