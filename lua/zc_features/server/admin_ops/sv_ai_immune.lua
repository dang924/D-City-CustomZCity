-- sv_ai_immune.lua — server-side notarget / AI immunity system.
--
-- Three layers are needed for full immunity:
--
--   1. FL_NOTARGET       — stops NPCs initiating targeting at the AI engine level
--   2. npc_bullseye hide — ZCity parents an npc_bullseye to each player; NPCs
--                          target that proxy, not the player directly. We move it
--                          out of the world (EF_NODRAW + move far away) on enable
--                          and restore it on disable.
--   3. Damage block      — ZCity routes all player damage through its own
--                          HomigradDamage hook, not standard EntityTakeDamage.
--                          We block both to cover all sources.
--
-- Also cloaks the player via ZCity's SetMaterial("NULL") so other players
-- see nothing rather than a semi-transparent ghost.
--
-- ULX: !notarget <player>  (admin+)

if CLIENT then return end

ZC_NoTarget = ZC_NoTarget or {}

local notargetNPCRegistry = {}

local function TrackNotargetNPC(ent)
    if IsValid(ent) and ent:IsNPC() then
        notargetNPCRegistry[ent:EntIndex()] = ent
    end
end

hook.Add("InitPostEntity", "ZC_NotTarget_NPCRegistry_Init", function()
    notargetNPCRegistry = {}
    for _, e in ipairs(ents.GetAll()) do
        TrackNotargetNPC(e)
    end
end)

hook.Add("OnEntityCreated", "ZC_NotTarget_NPCRegistry_Add", function(ent)
    timer.Simple(0, function()
        TrackNotargetNPC(ent)
    end)
end)

hook.Add("EntityRemoved", "ZC_NotTarget_NPCRegistry_Remove", function(ent)
    if not IsValid(ent) then return end
    notargetNPCRegistry[ent:EntIndex()] = nil
end)

-- ── Bullseye helpers ──────────────────────────────────────────────────────────

local function FindBullseye(ply)
    for _, ent in ipairs(ents.FindByClass("npc_bullseye")) do
        if IsValid(ent) and ent:GetParent() == ply then
            return ent
        end
    end
end

local function HideBullseye(ply)
    local bs = FindBullseye(ply)
    if not IsValid(bs) then return end
    bs.ZC_OrigPos = bs:GetPos()
    bs:SetPos(Vector(0, 0, -32768))
    bs:AddEffects(EF_NODRAW)
    bs:SetSolid(SOLID_NONE)
    for idx, npc in pairs(notargetNPCRegistry) do
        if not IsValid(npc) then
            notargetNPCRegistry[idx] = nil
        elseif npc:GetEnemy() == bs or npc:GetEnemy() == ply then
            npc:ClearEnemyMemory()
            npc:SetEnemy(NULL)
        end
    end
end

local function RestoreBullseye(ply)
    local bs = FindBullseye(ply)
    if not IsValid(bs) then return end
    bs:SetPos(bs.ZC_OrigPos or ply:GetPos())
    bs:RemoveEffects(EF_NODRAW)
    bs:SetSolid(SOLID_BBOX)
    bs.ZC_OrigPos = nil
end

-- ── Main toggle ───────────────────────────────────────────────────────────────

local function SetNotTarget(ply, enabled)
    if not IsValid(ply) then return end

    ZC_NoTarget[ply:SteamID()] = enabled or nil

    if enabled then
        ply:AddFlags(FL_NOTARGET)
        ply.ZC_NotTargetGod = true

        ply.cloak = true
        ply:SetMaterial("NULL")
        ply:DrawShadow(false)

        -- Hide the bullseye proxy immediately, then again after 1.5s in case
        -- ZCity recreates it shortly after (it spawns ~1s after player spawn)
        HideBullseye(ply)
        timer.Simple(1.5, function()
            if IsValid(ply) and IsNoTarget(ply) then HideBullseye(ply) end
        end)

        ply:ChatPrint("[NotTarget] ON — invisible to NPCs and players, immune to damage.")
    else
        ply:RemoveFlags(FL_NOTARGET)
        ply.ZC_NotTargetGod = nil

        ply.cloak = false
        ply:SetMaterial(nil)
        ply:DrawShadow(true)

        RestoreBullseye(ply)

        ply:ChatPrint("[NotTarget] OFF — you are visible again and can take damage.")
    end
end

function IsNoTarget(ply)
    return ZC_NoTarget[ply:SteamID()] == true
end

-- ── Damage blocks ─────────────────────────────────────────────────────────────
-- ZCity's organism damage fires through HomigradDamage, bypassing the standard
-- EntityTakeDamage path. Block both to cover all damage sources.

hook.Add("EntityTakeDamage", "ZC_NotTarget_GodMode", function(ent, dmgInfo)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    if ent.ZC_NotTargetGod then return true end
end)

hook.Add("HomigradDamage", "ZC_NotTarget_GodMode", function(victim, dmgInfo)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if victim.ZC_NotTargetGod then return true end
end)

-- ── Re-apply on spawn ─────────────────────────────────────────────────────────
-- ZCity's spawn hook resets FL_NOTARGET and materials. Re-apply notarget and
-- re-hide the bullseye (which gets recreated ~1s after spawn).

hook.Add("Player Spawn", "ZC_NotTarget_Restore", function(ply)
    if not IsNoTarget(ply) then return end
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        SetNotTarget(ply, true)
    end)
end)

-- ── Clean up on disconnect ────────────────────────────────────────────────────

hook.Add("PlayerDisconnected", "ZC_NotTarget_Clear", function(ply)
    ZC_NoTarget[ply:SteamID()] = nil
end)

-- ── Global toggle used by ULX !notarget ──────────────────────────────────────

function ZC_ToggleNotTarget(ply)
    if not IsValid(ply) then return end
    SetNotTarget(ply, not IsNoTarget(ply))
    return IsNoTarget(ply)
end

-- ── Mirror godmode organism protections (no ragdoll, no amputation, no stun) ──
-- EntityTakeDamage / HomigradDamage above prevent raw HP loss, but ZCity's
-- "homigrad-damage" EntityTakeDamage hook fires first and queues amputations /
-- ragdolls via timers before our block gets a chance to run.  Wrap ZCity's own
-- hook + the key helper functions post-load, just like sv_godmode.lua does.

local function isNTTarget(ent)
    return IsValid(ent) and ent:IsPlayer() and ent.ZC_NotTargetGod
end

local function WrapZCityFunctions_NT()
    -- 1. Wrap homigrad-damage so organism processing is skipped for NT players
    local dmgHooks = hook.GetTable()["EntityTakeDamage"]
    local origDmg  = dmgHooks and dmgHooks["homigrad-damage"]
    if origDmg then
        hook.Remove("EntityTakeDamage", "homigrad-damage")
        hook.Add("EntityTakeDamage", "homigrad-damage", function(ent, dmgInfo)
            if isNTTarget(ent) then
                dmgInfo:SetDamage(0)
                return true
            end
            return origDmg(ent, dmgInfo)
        end)
    end

    -- 2. Block ragdoll / fake
    if hg and hg.Fake then
        local orig = hg.Fake
        hg.Fake = function(ply, ...)
            if isNTTarget(ply) then return end
            return orig(ply, ...)
        end
    end

    -- 3. Block stun
    if hg and hg.StunPlayer then
        local orig = hg.StunPlayer
        hg.StunPlayer = function(ply, ...)
            if isNTTarget(ply) then return end
            return orig(ply, ...)
        end
    end

    if hg and hg.LightStunPlayer then
        local orig = hg.LightStunPlayer
        hg.LightStunPlayer = function(ply, ...)
            if isNTTarget(ply) then return end
            return orig(ply, ...)
        end
    end

    -- 4. Block limb amputation
    if hg and hg.organism and hg.organism.AmputateLimb then
        local orig = hg.organism.AmputateLimb
        hg.organism.AmputateLimb = function(org, limb)
            if org and org.owner and isNTTarget(org.owner) then return end
            return orig(org, limb)
        end
    end
end

local function TryWrap_NT()
    if hg and hg.Fake and hg.organism and hg.organism.AmputateLimb then
        WrapZCityFunctions_NT()
        hook.Remove("InitPostEntity", "ZC_NotTarget_WrapHooks")
        timer.Remove("ZC_NotTarget_WrapRetry")
        return true
    end
end

if not TryWrap_NT() then
    hook.Add("InitPostEntity", "ZC_NotTarget_WrapHooks", TryWrap_NT)
    timer.Create("ZC_NotTarget_WrapRetry", 1, 10, TryWrap_NT)
end

-- Normalize organism state each tick for notarget players (keeps vitals clean
-- in case anything slips through — gas, fire, secondary damage, etc.)
hook.Add("Org Think", "ZC_NotTarget_Normalize", function(owner, org)
    if not IsValid(owner) or not owner:IsPlayer() then return end
    if not owner.ZC_NotTargetGod then return end

    org.alive          = true
    org.otrub          = false
    org.needotrub      = false
    org.needfake       = false

    org.blood          = 5000
    org.bleed          = 0
    org.internalBleed  = 0

    org.pain           = 0
    org.painadd        = 0
    org.avgpain        = 0
    org.shock          = 0
    org.immobilization = 0

    org.heartstop      = false
    org.lungsfunction  = true
    org.consciousness  = 1

    org.pulse          = 70
    org.heartbeat      = 70

    org.brain          = 0
    org.disorientation = 0
    org.fear           = 0
    org.fearadd        = 0
    org.adrenaline     = 0

    org.lleg           = 0
    org.rleg           = 0
    org.larm           = 0
    org.rarm           = 0
    org.chest          = 0
    org.pelvis         = 0
    org.spine1         = 0
    org.spine2         = 0
    org.spine3         = 0
    org.skull          = 0
    org.stomach        = 0
    org.intestines     = 0

    org.CO             = 0

    if owner:Health() < 100 then
        owner:SetHealth(100)
    end
end)
