if CLIENT then return end

-- Kick abuse tracking disabled until camera/vehicle issues are resolved.
local ENABLE_LEGKICK_ABUSE_TRACKING = false
if not ENABLE_LEGKICK_ABUSE_TRACKING then return end

local WINDOW_SECONDS = 10
local MAX_KICKS_IN_WINDOW = 3
local QUICK_CHAIN_SECONDS = 2.5
local QUICK_CHAIN_LIMIT = 2
local PUNISH_COOLDOWN = 20
local BROADCAST_RADIUS = 700
local DEBUG_CVAR = GetConVar("zc_debug_commands") or CreateConVar("zc_debug_commands", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED), "Master toggle for debug console commands (0=off, 1=on)")

local kickAbuse = {}

local function dbg(fmt, ...)
    if not DEBUG_CVAR:GetBool() then return end
    print("[KickDebug:Abuse] " .. string.format(fmt, ...))
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

local CHARACTER_LINES = {
    Gordon = {
        "Gordon: Too many kicks... my leg just gave out.",
        "Gordon: I pushed it too far. Leg is done.",
        "Gordon: Overdid it. My leg snapped.",
    },
    John = {
        "John: Sloppy. Blew my own leg out.",
        "John: Too many kicks. I just wrecked my leg.",
        "John: Bad chain. My leg is gone.",
    },
    default = {
        "You spammed kicks and blew out your leg.",
        "Your leg buckles from excessive kicking.",
        "Too many kicks in a short time. Your leg is broken.",
    },
}

local function isSupportedRound()
    if not CurrentRound then return true end
    local round = CurrentRound()
    if not istable(round) then return true end
    local name = round.name
    return name == "coop" or name == "event"
end

local function isHandsInflictor(inflictor)
    if not IsValid(inflictor) then return true end
    if not inflictor.IsWeapon or not inflictor:IsWeapon() then return true end

    local class = inflictor:GetClass()
    return class == "weapon_hands_sh" or class == "weapon_hg_coolhands"
end

local function isKickDamage(victim, dmginfo)
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
        dbg("reject: non-hand inflictor attacker=%s inflictor=%s", attacker:Nick(), IsValid(inf) and inf:GetClass() or "nil")
        return false
    end

    -- Kick traces may arrive with varying damage flags depending on state/modifiers.
    dbg("accept kick: attacker=%s victim=%s dmg=%.2f", attacker:Nick(), victimPly:Nick(), dmginfo:GetDamage())
    return true, victimPly, attacker
end

local function pickMessageForCharacter(ply)
    local className = ply.PlayerClassName
    local pool = CHARACTER_LINES[className] or CHARACTER_LINES.default
    return pool[math.random(#pool)]
end

local function broadcastNearbyTalk(source, message)
    if not IsValid(source) then return end

    local radiusSqr = BROADCAST_RADIUS * BROADCAST_RADIUS
    local sourcePos = source:GetPos()
    local line = "[Kick] " .. source:Nick() .. ": " .. message

    for _, ply in ipairs(player.GetHumans()) do
        if not IsValid(ply) then continue end
        if ply:GetPos():DistToSqr(sourcePos) > radiusSqr then continue end
        ply:ChatPrint(line)
    end
end

local function breakLeg(ply)
    local org = ply.organism
    if not org then
        broadcastNearbyTalk(ply, "I over-kicked, but my organism state is unavailable.")
        return
    end

    if math.random(1, 2) == 1 then
        org.llegdislocation = true
        dbg("punish leg break: attacker=%s side=left", ply:Nick())
    else
        org.rlegdislocation = true
        dbg("punish leg break: attacker=%s side=right", ply:Nick())
    end

    if hg and hg.send_organism then
        hg.send_organism(org, ply)
    end

    broadcastNearbyTalk(ply, pickMessageForCharacter(ply))
end

local function registerKickHit(attacker, victimPly)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if not IsValid(victimPly) or not victimPly:IsPlayer() then return end

    local key = attacker:SteamID64() or tostring(attacker:EntIndex())
    local now = CurTime()

    local data = kickAbuse[key]
    if not data then
        data = {
            count = 0,
            windowStart = now,
            punishedUntil = 0,
            quickChain = 0,
            lastKickTime = 0,
            lastVictim = "",
            lastEventAt = 0,
            lastEventVictim = "",
        }
        kickAbuse[key] = data
    end

    local victimKey = victimPly:SteamID64() or tostring(victimPly:EntIndex())
    if data.lastEventVictim == victimKey and (now - data.lastEventAt) <= 0.08 then
        dbg("skip duplicate event: attacker=%s victim=%s", attacker:Nick(), victimPly:Nick())
        return
    end
    data.lastEventAt = now
    data.lastEventVictim = victimKey

    if now - data.windowStart > WINDOW_SECONDS then
        data.count = 0
        data.windowStart = now
    end

    data.count = data.count + 1

    if victimKey == data.lastVictim and (now - data.lastKickTime) <= QUICK_CHAIN_SECONDS then
        data.quickChain = data.quickChain + 1
    else
        data.quickChain = 1
    end
    data.lastVictim = victimKey
    data.lastKickTime = now

    dbg("track: attacker=%s victim=%s count=%d quick=%d cooldown=%.2f", attacker:Nick(), victimPly:Nick(), data.count, data.quickChain, math.max(0, data.punishedUntil - now))

    if now < data.punishedUntil then
        dbg("skip punish: cooldown attacker=%s remain=%.2f", attacker:Nick(), data.punishedUntil - now)
        return
    end
    if data.quickChain < QUICK_CHAIN_LIMIT and data.count < MAX_KICKS_IN_WINDOW then
        dbg("skip punish: thresholds not met attacker=%s", attacker:Nick())
        return
    end

    data.count = 0
    data.quickChain = 0
    data.windowStart = now
    data.punishedUntil = now + PUNISH_COOLDOWN

    breakLeg(attacker)
end

hook.Add("EntityTakeDamage", "DCityPatch_LegKickAbuse", function(victim, dmginfo)
    if not isKickProtectionEnabled() then return end
    if not isSupportedRound() then return end
    local ok, victimPly, attacker = isKickDamage(victim, dmginfo)
    if not ok then return end
    registerKickHit(attacker, victimPly)
end)

hook.Add("DCityPatch_OnPlayerKickHit", "DCityPatch_LegKickAbuseSynthetic", function(attacker, victimPly)
    if not isKickProtectionEnabled() then return end
    if not isSupportedRound() then return end
    dbg("synthetic kick event: attacker=%s victim=%s", IsValid(attacker) and attacker:Nick() or "?", IsValid(victimPly) and victimPly:Nick() or "?")
    registerKickHit(attacker, victimPly)
end)

hook.Add("PlayerDisconnected", "DCityPatch_LegKickAbuseCleanup", function(ply)
    if not isKickProtectionEnabled() then return end
    local key = ply:SteamID64() or tostring(ply:EntIndex())
    kickAbuse[key] = nil
    dbg("cleanup: disconnected=%s", IsValid(ply) and ply:Nick() or "unknown")
end)
