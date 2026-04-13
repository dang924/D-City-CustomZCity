-- sv_godmode.lua — Organism godmode for all players.
-- Wraps ZCity's own damage hooks + blocks Fake/Stun/Amputate after load order.

if CLIENT then return end

ZC_OrgGodMode = ZC_OrgGodMode or false

local function isGodTarget(ent)
    return ZC_OrgGodMode and IsValid(ent) and ent:IsPlayer()
end

-- Wrap core ZCity functions after they have been defined (post load order)
local function WrapZCityFunctions()
    -- 1. Wrap the main damage hook so no organism processing runs at all
    local dmgHooks = hook.GetTable()["EntityTakeDamage"]
    local origDmg  = dmgHooks and dmgHooks["homigrad-damage"]
    if origDmg then
        hook.Remove("EntityTakeDamage", "homigrad-damage")
        hook.Add("EntityTakeDamage", "homigrad-damage", function(ent, dmgInfo)
            if isGodTarget(ent) then
                dmgInfo:SetDamage(0)
                return true
            end
            return origDmg(ent, dmgInfo)
        end)
    end

    -- 2. Ragdoll / fake: allow even in godmode so players can go down and be
    -- stood up by admins as normal. Damage is already blocked upstream so the
    -- ragdoll won't be triggered by lethal hits — but voluntary/admin-triggered
    -- fakes and explosion knockdowns should still work.

    -- 3. Block stun
    if hg and hg.StunPlayer then
        local orig = hg.StunPlayer
        hg.StunPlayer = function(ply, ...)
            if isGodTarget(ply) then return end
            return orig(ply, ...)
        end
    end

    if hg and hg.LightStunPlayer then
        local orig = hg.LightStunPlayer
        hg.LightStunPlayer = function(ply, ...)
            if isGodTarget(ply) then return end
            return orig(ply, ...)
        end
    end

    -- 4. Block limb amputation
    if hg and hg.organism and hg.organism.AmputateLimb then
        local orig = hg.organism.AmputateLimb
        hg.organism.AmputateLimb = function(org, limb)
            if org and org.owner and isGodTarget(org.owner) then return end
            return orig(org, limb)
        end
    end
end

-- Try immediately (if ZCity already loaded), then retry via timer/hook
local function TryWrap()
    if hg and hg.Fake and hg.organism and hg.organism.AmputateLimb then
        WrapZCityFunctions()
        hook.Remove("InitPostEntity", "ZC_OrgGodMode_WrapHooks")
        timer.Remove("ZC_OrgGodMode_WrapRetry")
        return true
    end
end

if not TryWrap() then
    hook.Add("InitPostEntity", "ZC_OrgGodMode_WrapHooks", TryWrap)
    timer.Create("ZC_OrgGodMode_WrapRetry", 1, 10, TryWrap)
end

-- Safety net: after all Org Think hooks run, reset any state that slipped through
-- (e.g. bleed from sources other than direct damage, NPC fire, gas, etc.)
hook.Add("Org Think", "ZC_OrgGodMode_Normalize", function(owner, org, timeValue)
    if not ZC_OrgGodMode then return end
    if not IsValid(owner) or not owner:IsPlayer() then return end

    org.alive         = true
    org.otrub         = false
    org.needotrub     = false
    org.needfake      = false

    org.blood         = 5000
    org.bleed         = 0
    org.internalBleed = 0

    org.pain          = 0
    org.painadd       = 0
    org.avgpain       = 0
    org.shock         = 0
    org.immobilization = 0

    org.heartstop     = false
    org.lungsfunction = true
    org.consciousness = 1

    -- Normal resting heart rate
    org.pulse         = 70
    org.heartbeat     = 70

    org.brain         = 0
    org.disorientation = 0
    org.fear          = 0
    org.fearadd       = 0
    org.adrenaline    = 0

    -- Limb damage
    org.lleg          = 0
    org.rleg          = 0
    org.larm          = 0
    org.rarm          = 0
    org.chest         = 0
    org.pelvis        = 0
    org.spine1        = 0
    org.spine2        = 0
    org.spine3        = 0
    org.skull         = 0
    org.stomach       = 0
    org.intestines    = 0

    -- Atmosphere / poison
    org.CO            = 0

    -- Restore GMod HP in case anything bypassed organism pipeline
    if owner:Health() < 100 then
        owner:SetHealth(100)
    end
end)
