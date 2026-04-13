-- sv_npc_knockdown.lua
-- Knocks down Combine/Metrocop NPCs instead of killing them when their organism
-- reaches a critical state.
--
-- KEY MECHANISM: while an NPC is knocked down we set org.godmode = true.
-- ZCity's organism loop checks godmode BEFORE running any modules, so the entire
-- organism think (including the needfake -> TakeDamageInfo(10000) kill path) is
-- skipped. We restore godmode and reset organism state on recovery.
--
-- ORGANISM LIST CLEANUP: ZCity adds NPC organisms to hg.organism.list but never
-- removes them when the NPC entity is destroyed. We register a CallOnRemove on
-- every tracked NPC to call hg.organism.Remove, preventing NULL-owner spam in
-- the organism think loop.

if CLIENT then return end

local cvKnockdownEnable = CreateConVar(
    "zc_npc_knockdown_enable",
    "1",
    FCVAR_ARCHIVE,
    "Enable/disable DCity NPC ragdoll knockdown system (requires map restart).",
    0,
    1
)

if not cvKnockdownEnable:GetBool() then
    print("[ZCity] NPC knockdown system disabled via zc_npc_knockdown_enable=0")
    return
end

local cvMirrorIdleOnly = CreateConVar(
    "zc_npc_knockdown_mirror_idle_only",
    "1",
    FCVAR_ARCHIVE,
    "When enabled, downed NPCs only auto-play idle aim mirror recordings.",
    0,
    1
)

if not ZC_IsPatchCombinePlayer then
    include("autorun/server/sv_patch_player_factions.lua")
end

local KNOCKDOWN_CLASSES = {
    ["npc_combine_s"]   = true,
    ["npc_metropolice"] = true,
}

local HARM_THRESHOLD    = 2.10   -- single-hit harm (dmg/100) -> instant knockdown (base default; overridden by sv_npc_knockdown_config.lua at runtime)
local BLOOD_THRESHOLD   = 1900   -- org.blood below this -> knockdown (base default; overridden at runtime)
local LEG_THRESHOLD     = 0.85   -- org.lleg or org.rleg -> leg-shot knockdown (base default; overridden at runtime)

-- Returns live scaled thresholds from sv_npc_knockdown_config.lua if available,
-- otherwise falls back to local constants (safe during map load / before config loads).
local function GetLiveThresholds()
    if _G.ZC_GetKnockdownThresholds then
        return _G.ZC_GetKnockdownThresholds()
    end
    return { harm = HARM_THRESHOLD, blood = BLOOD_THRESHOLD, leg = LEG_THRESHOLD }
end
local KNOCKDOWN_RECOVER = 15     -- max seconds an NPC can stay down before forced recovery
local REVIVE_RADIUS     = 260    -- units; nearby standing ally revives them
local REVIVE_INTERVAL   = 0.5    -- seconds between revival scans
local REVIVE_SIGHT_DELAY = 2.0   -- seconds before allies are allowed to notice/revive a downed ally
local REVIVE_ROLL_INTERVAL = 0.6 -- seconds between revive chance rolls once allies can see target
local REVIVE_CHANCE = 0.65       -- chance per roll to perform revive when a valid ally sees target
local RECOVER_MIN_BLOOD = 2400   -- minimum blood required to stand up naturally
local RECOVER_SAFE_DELAY = 1.0   -- seconds without incoming damage required before stand-up
local RECOVER_TIMEOUT_EXTEND = 2.5
local RECOVER_TIMEOUT_MAX_EXTENDS = 8
local NPC_BASE_SPEED    = 220    -- default NPC walk speed (combine/metro)
local SPEED_UPDATE_INT  = 0.3    -- seconds between speed recalculations
local DOWNED_BURY_Z     = 52     -- push hidden NPC under ragdoll to prevent ghost movement/shots
-- Downed damage is intentionally softer than live NPC damage so they behave like
-- a "living" player ragdoll state instead of dying in 1-2 hits.
local DOWNED_BLOOD_MUL  = 1.35
local DOWNED_BLEED_MUL  = 0.0009
local DOWNED_FORCE_END_DAMAGE = 250 -- shared ragdoll damage needed to hard-end downed timer

local SIDEARM_HINTS = {
    ["pistol"] = true,
    ["handgun"] = true,
    ["revolver"] = true,
    ["deagle"] = true,
    ["glock"] = true,
    ["usp"] = true,
    ["beretta"] = true,
    ["m9"] = true,
    ["p228"] = true,
    ["fiveseven"] = true,
    ["357"] = true,
}

local function IsLikelySidearmClass(classname)
    local cls = string.lower(tostring(classname or ""))
    for hint in pairs(SIDEARM_HINTS) do
        if string.find(cls, hint, 1, true) then
            return true
        end
    end
    return false
end

local function NPCHasSidearm(npc)
    if not IsValid(npc) then return false end
    for _, wep in ipairs(npc:GetWeapons()) do
        if IsValid(wep) then
            if IsLikelySidearmClass(wep:GetClass()) then
                return true
            end
        end
    end
    return false
end

local function GetNPCPrimaryWeapon(npc)
    if not IsValid(npc) then return nil end

    local active = npc:GetActiveWeapon()
    if IsValid(active) and not IsLikelySidearmClass(active:GetClass()) then
        return active
    end

    for _, wep in ipairs(npc:GetWeapons()) do
        if IsValid(wep) and not IsLikelySidearmClass(wep:GetClass()) then
            return wep
        end
    end

    return IsValid(active) and active or nil
end

local function GetStandingFireProfile(wep)
    local p = (IsValid(wep) and wep.Primary) or {}

    local delay = tonumber(p.Delay)
    if (not delay or delay <= 0) and IsValid(wep) and isfunction(wep.GetFireRate) then
        delay = tonumber(wep:GetFireRate())
    end
    delay = math.Clamp(delay or 0.12, 0.05, 1.0)

    local cone = tonumber(p.Cone)
    cone = math.Clamp(cone or 0.03, 0, 0.2)

    local dmg = tonumber(p.Damage)
    dmg = math.max(1, dmg or 12)

    local num = tonumber(p.NumShots)
    num = math.Clamp(math.floor(num or 1), 1, 8)

    local tracer = tonumber(p.TracerNum)
    tracer = math.Clamp(math.floor(tracer or 1), 0, 4)

    return delay, cone, dmg, num, tracer
end

local WEAPON_MODEL_HINTS = {
    ar2 = "models/weapons/w_irifle.mdl",
    smg = "models/weapons/w_smg1.mdl",
    shotgun = "models/weapons/w_shotgun.mdl",
    pistol = "models/weapons/w_pistol.mdl",
    revolver = "models/weapons/w_357.mdl",
}

local WEAPON_SOUND_HINTS = {
    ar2 = "Weapon_AR2.Single",
    smg = "Weapon_SMG1.Single",
    shotgun = "Weapon_Shotgun.Single",
    pistol = "Weapon_Pistol.Single",
    revolver = "Weapon_357.Single",
}

local HAND_BONE_NAMES = {
    "ValveBiped.Bip01_R_Hand",
    "Bip01 R Hand",
}

local function ChooseHintedValue(classname, map, fallback)
    local cls = string.lower(tostring(classname or ""))
    if string.find(cls, "ar2", 1, true) then return map.ar2 or fallback end
    if string.find(cls, "smg", 1, true) then return map.smg or fallback end
    if string.find(cls, "shotgun", 1, true) then return map.shotgun or fallback end
    if string.find(cls, "357", 1, true) or string.find(cls, "revolver", 1, true) then return map.revolver or fallback end
    if string.find(cls, "pistol", 1, true) then return map.pistol or fallback end
    return fallback
end

local function GetDownedWeaponProxyModel(npc)
    if not IsValid(npc) then return "models/weapons/w_smg1.mdl" end

    local wep = GetNPCPrimaryWeapon(npc)
    if not IsValid(wep) then
        wep = npc:GetActiveWeapon()
    end

    if IsValid(wep) and isfunction(wep.GetWeaponWorldModel) then
        local mdl = tostring(wep:GetWeaponWorldModel() or "")
        if mdl ~= "" and util.IsValidModel(mdl) then
            return mdl
        end
    end
    if IsValid(wep) and isfunction(wep.GetModel) then
        local mdl = tostring(wep:GetModel() or "")
        if mdl ~= "" and util.IsValidModel(mdl) then
            return mdl
        end
    end

    local cls = IsValid(wep) and wep:GetClass() or ""
    return ChooseHintedValue(cls, WEAPON_MODEL_HINTS, "models/weapons/w_smg1.mdl")
end

local function GetDownedFireSound(wep, hasSidearm)
    if IsValid(wep) then
        return ChooseHintedValue(wep:GetClass(), WEAPON_SOUND_HINTS, hasSidearm and "Weapon_Pistol.Single" or "Weapon_SMG1.Single")
    end
    return hasSidearm and "Weapon_Pistol.Single" or "Weapon_SMG1.Single"
end

local function RemoveDownedWeaponProxy(npc)
    if not IsValid(npc) then return end
    if IsValid(npc.zc_weapon_proxy) then
        npc.zc_weapon_proxy:Remove()
    end
    npc.zc_weapon_proxy = nil
end

local function CreateDownedWeaponProxy(npc, rag)
    if not IsValid(npc) or not IsValid(rag) then return end

    RemoveDownedWeaponProxy(npc)

    local model = GetDownedWeaponProxyModel(npc)
    if not util.IsValidModel(model) then return end

    local proxy = ents.Create("prop_dynamic")
    if not IsValid(proxy) then return end

    proxy:SetModel(model)
    proxy:SetPos(rag:WorldSpaceCenter())
    proxy:SetAngles(rag:GetAngles())
    proxy:SetSolid(SOLID_NONE)
    proxy:SetMoveType(MOVETYPE_NONE)
    proxy:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    proxy:Spawn()
    proxy:Activate()

    proxy:SetParent(rag)
    for _, boneName in ipairs(HAND_BONE_NAMES) do
        local bone = rag:LookupBone(boneName)
        if bone and bone >= 0 and isfunction(proxy.FollowBone) then
            proxy:FollowBone(rag, bone)
            break
        end
    end
    proxy:SetLocalPos(Vector(3.5, 0.8, -1.2))
    proxy:SetLocalAngles(Angle(5, 95, 178))

    npc.zc_weapon_proxy = proxy
end

local function EmitDownedShotEffects(rag, src, dir, shotSound)
    if not IsValid(rag) then return end
    if isstring(shotSound) and shotSound ~= "" then
        rag:EmitSound(shotSound, 78, math.random(96, 104), 0.9, CHAN_WEAPON)
    end

    local fx = EffectData()
    fx:SetOrigin(src)
    fx:SetNormal(dir)
    fx:SetScale(1)
    util.Effect("MuzzleFlash", fx, true, true)
end

local function CanAllyReviveTarget(ally, npc)
    if not IsValid(ally) or not IsValid(npc) then return false end
    if not ally:IsNPC() or not npc:IsNPC() then return false end
    if ally == npc or ally.zc_knocked_down then return false end
    if not KNOCKDOWN_CLASSES[ally:GetClass()] then return false end

    local tr = util.TraceLine({
        start = ally:WorldSpaceCenter(),
        endpos = npc:WorldSpaceCenter(),
        filter = {ally, npc},
        mask = MASK_SOLID_BRUSHONLY
    })

    return not tr.Hit
end

local function IsDownedPoolDepleted(npc)
    if not IsValid(npc) then return false end
    if not npc.zc_knocked_down then return false end

    local org = npc.organism
    if not org then return false end

    -- Treat depleted blood (organism pool) as hard death while downed.
    if (org.blood or 0) <= 0 then return true end

    -- Safety: if base entity health has already collapsed, do not allow revive path.
    if (npc:Health() or 1) <= 0 then return true end

    return false
end

-- rawDmg must be pre-captured BEFORE homigrad's pipeline runs (it zeroes dmgInfo:GetDamage).
local function AddDownedDamageAndCheckFatal(npc, rawDmg)
    if not IsValid(npc) or not npc.zc_knocked_down then return false end
    if not rawDmg or rawDmg <= 0 then return false end

    npc.zc_downed_damage_total = (npc.zc_downed_damage_total or 0) + rawDmg
    if npc.zc_downed_damage_total >= DOWNED_FORCE_END_DAMAGE then
        return true
    end

    return false
end

local function IsDownedHeadshotFatal(hitgroup, rawDmg)
    return hitgroup == HITGROUP_HEAD
end

local function CanRecoverFromDowned(npc, now)
    if not IsValid(npc) or not npc.zc_knocked_down then return false end
    local org = npc.organism
    if not org then return false end
    if IsDownedPoolDepleted(npc) then return false end

    if (org.blood or 0) < RECOVER_MIN_BLOOD then
        return false
    end

    local t = now or CurTime()
    local lastHit = npc.zc_last_downed_hit or 0
    if (t - lastHit) < RECOVER_SAFE_DELAY then
        return false
    end

    if IsValid(npc.zc_ragdoll) and npc.zc_ragdoll:IsOnFire() then
        return false
    end
    if npc:IsOnFire() then
        return false
    end

    return true
end

local npcRegistry     = {}
local knockedRegistry = {}

local REVIVE_REASONS = {
    blood_restored = true,
    revived_by_ally = true,
    timeout = true,
    revive_window_timeout = true,
}

local function ApplyFatalDamage(npc)
    if not IsValid(npc) then return end

    local attacker = IsValid(npc.zc_last_attacker) and npc.zc_last_attacker
        or (IsValid(game.GetWorld()) and game.GetWorld())
        or npc

    local dmgInfo = DamageInfo()
    dmgInfo:SetDamage(10000)
    dmgInfo:SetDamageType(DMG_GENERIC)
    dmgInfo:SetAttacker(attacker)
    dmgInfo:SetInflictor(attacker)
    dmgInfo:SetDamagePosition(npc:WorldSpaceCenter())
    npc:TakeDamageInfo(dmgInfo)

    -- Fallback: if a scripted NPC ignores damage handling, force-remove it.
    timer.Simple(0, function()
        if IsValid(npc) and npc:Health() > 0 then
            npc:Fire("kill", "", 0)
        end
    end)
end

local function ForceKillNPC(npc)
    if not IsValid(npc) then return end
    if npc.zc_kill_in_progress then return end
    npc.zc_kill_in_progress = true

    -- Ensure knockdown state is fully detached before forcing kill.
    knockedRegistry[npc:EntIndex()] = nil
    npc.zc_knocked_down = false
    npc.zc_knockdown_until = nil
    npc.zc_next_downed_shot = nil
    npc.zc_revive_earliest = nil
    npc.zc_next_revive_roll = nil
    npc.zc_last_downed_hit = nil
    npc.zc_timeout_extensions = nil
    npc.zc_downed_damage_total = nil
    npc.zc_legshot_downed = nil
    if IsValid(npc.zc_ragdoll) and npc.zc_anim_mirror_recording and _G.RagdollAnimator and _G.RagdollAnimator.StopPlayback then
        _G.RagdollAnimator:StopPlayback(npc.zc_ragdoll, npc.zc_anim_mirror_recording)
    end
    npc.zc_anim_mirror_recording = nil
    RemoveDownedWeaponProxy(npc)
    timer.Remove("ZC_NPCDownedShoot_" .. npc:EntIndex())
    timer.Remove("ZC_NPCKnockdown_Anchor_" .. npc:EntIndex())

    if npc.organism then
        npc.organism.godmode = false
        npc.organism.needfake = false
        npc.organism.needotrub = false
        npc.organism.otrub = false
    end

    timer.Simple(0, function()
        if not IsValid(npc) then return end
        npc.zc_prev_collision_group = nil
        npc.zc_prev_solid = nil
        npc.zc_all_weapons = nil

        -- Keep the knockdown ragdoll as the visible corpse instead of removing it.
        -- Removing it first causes the body to vanish with no animation or sound.
        if IsValid(npc.zc_ragdoll) then
            -- Sync NPC position for accurate audio source before detaching.
            npc:SetPos(npc.zc_ragdoll:GetPos())
            npc:SetAngles(npc.zc_ragdoll:GetAngles())
            -- Play NPC death sound from the ragdoll's world position.
            local deathSnd = isfunction(npc.GetDeathSound) and npc:GetDeathSound() or ""
            if deathSnd ~= "" then
                sound.Play(deathSnd, npc.zc_ragdoll:GetPos(), 75, 100, 1)
            end
            -- Detach tracking so the ragdoll becomes a standalone corpse prop.
            npc.zc_ragdoll.organism   = nil
            npc.zc_ragdoll.zc_npc_ref = nil
            npc.zc_ragdoll = nil
        end

        -- Remove the hidden NPC entity directly (it is invisible/buried, no visual artifact).
        -- EntityRemoved fallback in sv_buy_menu.lua handles reward payout.
        -- CallOnRemove ZC_NPC_OrgCleanup fires automatically to clean up organism.
        if IsValid(npc) then
            npc:Remove()
        end
    end)
end

local function GetBuriedAnchorPos(rag)
    return rag:GetPos() - Vector(0, 0, DOWNED_BURY_Z)
end

local LIMB_FROM_HITGROUP = {
    [HITGROUP_LEFTARM] = "larm",
    [HITGROUP_RIGHTARM] = "rarm",
    [HITGROUP_LEFTLEG] = "lleg",
    [HITGROUP_RIGHTLEG] = "rleg",
    [HITGROUP_HEAD] = "head",
}

local AMPUTATION_SUPPORTED_LIMBS = {
    larm = true,
    rarm = true,
    lleg = true,
    rleg = true,
}

local GetRagdollHitGroup

function GetRagdollHitGroup(rag, dmgInfo)
    if not IsValid(rag) or not dmgInfo then return nil end
    if not hg or not hg.bonetohitgroup then return nil end

    -- Prefer native homigrad trace resolver used for player ragdolls.
    if hg.GetTraceDamage then
        local tr = hg.GetTraceDamage(rag, dmgInfo:GetDamagePosition(), dmgInfo:GetDamageForce())
        if tr and tr.Hit and isnumber(tr.PhysicsBone) then
            local bone = rag:TranslatePhysBoneToBone(tr.PhysicsBone)
            if bone and bone >= 0 then
                local boneName = rag:GetBoneName(bone)
                if boneName and hg.bonetohitgroup[boneName] then
                    return hg.bonetohitgroup[boneName]
                end
            end
        end
    end

    local dmgPos = dmgInfo:GetDamagePosition()
    if not isvector(dmgPos) then
        dmgPos = rag:WorldSpaceCenter()
    end

    local center = rag:GetPos() + rag:OBBCenter()
    local dir = (center - dmgPos)
    if dir:LengthSqr() < 0.001 then
        dir = rag:GetForward()
    end
    dir:Normalize()

    local tr = util.QuickTrace(dmgPos, dir * 140, rag)
    local physBone = tr.PhysicsBone

    -- Fallback for bullets/damage sources that don't provide PhysicsBone.
    if not isnumber(physBone) or physBone < 0 then
        local bestDist = math.huge
        local bestPhys = nil
        local count = rag:GetPhysicsObjectCount() or 0
        for i = 0, count - 1 do
            local phys = rag:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                local dist = phys:GetPos():DistToSqr(dmgPos)
                if dist < bestDist then
                    bestDist = dist
                    bestPhys = i
                end
            end
        end
        physBone = bestPhys
    end

    if not isnumber(physBone) or physBone < 0 then return nil end

    local bone = rag:TranslatePhysBoneToBone(physBone)
    if not bone or bone < 0 then return nil end

    local boneName = rag:GetBoneName(bone)
    if not boneName then return nil end

    return hg.bonetohitgroup[boneName]
end

local function IsLikelyHeadHitByPosition(rag, dmgInfo)
    if not IsValid(rag) or not dmgInfo then return false end

    local dmgPos = dmgInfo:GetDamagePosition()
    if not isvector(dmgPos) then return false end

    local headBone = rag:LookupBone("ValveBiped.Bip01_Head1")
        or rag:LookupBone("Bip01 Head")
        or rag:LookupBone("Head")

    if headBone and headBone >= 0 then
        local headPos = rag:GetBonePosition(headBone)
        if isvector(headPos) and headPos:DistToSqr(dmgPos) <= (20 * 20) then
            return true
        end
    end

    local localPos = rag:WorldToLocal(dmgPos)
    local maxs = rag:OBBMaxs()
    if isvector(localPos) and isvector(maxs) and localPos.z >= (maxs.z * 0.45) then
        return true
    end

    return false
end

local function GetDownedShotBasis(npc, rag)
    if not IsValid(rag) then return nil, nil end

    local att = rag:GetAttachment(1)
    local src = (att and att.Pos) or (rag:WorldSpaceCenter() + Vector(0, 0, 28))
    local dir = (att and att.Ang:Forward()) or rag:GetForward()

    local targetPos = nil
    if _G.RagdollAnimator and _G.RagdollAnimator.GetPreferredNPCBullseyeAimPosition then
        targetPos = _G.RagdollAnimator:GetPreferredNPCBullseyeAimPosition(npc)
    end

    if not isvector(targetPos) then
        local enemy = npc:GetEnemy()
        if IsValid(enemy) then
            targetPos = enemy:WorldSpaceCenter()
        end
    end

    if isvector(targetPos) then
        local toTarget = targetPos - src
        if toTarget:LengthSqr() > 0.001 then
            dir = toTarget:GetNormalized()
        end
    end

    if _G.RagdollAnimator and _G.RagdollAnimator.ApplyCapturedAimBias then
        local biased = _G.RagdollAnimator:ApplyCapturedAimBias(dir)
        if isvector(biased) and biased:LengthSqr() > 0.001 then
            dir = biased:GetNormalized()
        end
    end

    -- Spawn muzzle slightly forward so shots do not collide with the shooter ragdoll.
    src = src + dir * 18
    return src, dir
end

-- ── Organism list cleanup ─────────────────────────────────────────────────────
-- ZCity never removes NPC organisms from hg.organism.list on entity removal,
-- causing NULL-owner Org Think spam. We fix that here for every tracked NPC.
local function RegisterOrganismCleanup(npc)
    if not IsValid(npc) then return end
    -- Only register once
    if npc._ZC_OrgCleanupRegistered then return end
    npc._ZC_OrgCleanupRegistered = true
    npc:CallOnRemove("ZC_NPC_OrgCleanup", function(ent)
        -- Clean up knockdown state
        if ent.zc_knocked_down then
            knockedRegistry[ent:EntIndex()] = nil
            timer.Remove("ZC_NPCDownedShoot_" .. ent:EntIndex())
            timer.Remove("ZC_NPCKnockdown_Anchor_" .. ent:EntIndex())
            RemoveDownedWeaponProxy(ent)
            if IsValid(ent.zc_ragdoll) then
                -- NPC was removed externally (by ZCity's org.alive path or map cleanup)
                -- while in downed state. Detach the ragdoll as a standalone corpse
                -- rather than removing it; this preserves the visible body on the ground.
                ent.zc_ragdoll.zc_npc_ref = nil
                ent.zc_ragdoll.organism   = nil
                -- Do NOT call :Remove() — ragdoll stays in world as a corpse prop.
                ent.zc_ragdoll = nil
            end
        end
        -- Remove from organism list so Org Think stops iterating a NULL entity
        if hg and hg.organism and hg.organism.Remove then
            hg.organism.Remove(ent)
        end
    end)
end

local function TrackNPC(ent)
    if not IsValid(ent) then return end
    if not KNOCKDOWN_CLASSES[ent:GetClass()] then return end
    npcRegistry[ent:EntIndex()] = ent
    -- Register organism cleanup as soon as organism is ready (may be set by sv_npcstuff timer.Simple(0))
    timer.Simple(0.1, function()
        if IsValid(ent) then
            RegisterOrganismCleanup(ent)
            -- Capture base NPC speed for movement degradation
            local spd = isfunction(ent.GetMaxSpeed) and ent:GetMaxSpeed() or nil
            ent.zc_base_speed = (spd and spd > 10) and spd or NPC_BASE_SPEED
        end
    end)
end

local function UntrackNPC(ent)
    local idx = ent:EntIndex()
    npcRegistry[idx]     = nil
    knockedRegistry[idx] = nil
end

hook.Add("OnEntityCreated", "ZC_NPCKnockdown_Track",  function(ent) timer.Simple(0, function() TrackNPC(ent) end) end)
hook.Add("EntityRemoved",   "ZC_NPCKnockdown_Untrack", UntrackNPC)
hook.Add("InitPostEntity",  "ZC_NPCKnockdown_Init", function()
    npcRegistry = {}; knockedRegistry = {}
    for _, ent in ipairs(ents.GetAll()) do TrackNPC(ent) end
end)

-- ── Core knockdown/recovery ───────────────────────────────────────────────────

local function KnockDownNPC(npc, reason)
    if not IsValid(npc) then return end
    if npc.zc_knocked_down then return end
    if npc.zc_kill_in_progress then return end
    if npc:IsFlagSet(FL_NOTARGET) then return end

    -- Each NPC can only be revived once. Any later critical state is fatal.
    if npc.zc_revived_once then
        ForceKillNPC(npc)
        return
    end

    npc.zc_knocked_down = true
    npc.zc_knockdown_until = CurTime() + KNOCKDOWN_RECOVER
    npc.zc_revive_earliest = CurTime() + REVIVE_SIGHT_DELAY
    npc.zc_next_revive_roll = npc.zc_revive_earliest
    npc.zc_last_downed_hit = CurTime()
    npc.zc_timeout_extensions = 0
    npc.zc_downed_damage_total = 0
    npc.zc_legshot_downed = isstring(reason) and string.StartWith(string.lower(reason), "leg ")
    knockedRegistry[npc:EntIndex()] = npc

    if npc.organism then
        npc.organism.godmode   = true
        npc.organism.needfake  = false
        npc.organism.needotrub = true
        npc.organism.otrub     = true   -- flag as unconscious for medkit targeting
        npc.organism.fake      = false
        -- alive=true prevents ZCity's Org Think from calling owner:Kill() when blood=0.
        -- Without this, a one-shot NPC is killed by ZCity in the same frame we knock
        -- it down, which removes the NPC entity and (via ZC_NPC_OrgCleanup) destroys
        -- our knockdown ragdoll before it ever becomes a corpse.
        npc.organism.alive     = true
        -- Clamp blood below threshold so the blood_restored revival check never fires
        -- immediately for NPCs knocked by heavy_harm (who may have plenty of blood).
        npc.organism.blood = math.min(npc.organism.blood or BLOOD_THRESHOLD - 1, BLOOD_THRESHOLD - 1)
    end

    -- Lock movement: hidden NPC must not walk away from the ragdoll
    npc:SetMoveType(MOVETYPE_NONE)
    npc.zc_prev_collision_group = npc:GetCollisionGroup()
    npc.zc_prev_solid = npc:GetSolid()
    npc:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    npc:SetSolid(SOLID_NONE)

    -- Hide ALL weapons so none float visibly while the NPC is hidden.
    -- Store the full list so every weapon is restored on recovery.
    npc.zc_all_weapons = {}
    for _, wep in ipairs(npc:GetWeapons()) do
        if IsValid(wep) then
            wep:SetNoDraw(true)
            npc.zc_all_weapons[#npc.zc_all_weapons + 1] = wep
        end
    end

    -- Copy entity data from NPC (armor class, appearance, etc.) so impact decals show correct material.
    -- Mirrors player FakeRagdoll creation in sv_tier_0.lua which uses duplicator.CopyEntTable.
    local Data = duplicator.CopyEntTable(npc)
    local rag = ents.Create("prop_ragdoll")
    duplicator.DoGeneric(rag, Data)
    rag:SetPos(npc:GetPos())
    rag:SetAngles(npc:GetAngles())
    --rag:SetVelocity(npc:GetVelocity())
    rag:SetModel(npc:GetModel())
    rag.CurAppearance = table.Copy(npc.CurAppearance or {})  -- copy appearance for consistency
    rag:Spawn()
    rag:Activate()
    -- Critical: prevent damage forces and point traces from passing through the ragdoll.
    -- This stops particles/blood from floating weirdly and enables proper hit detection.
    rag:AddEFlags(EFL_NO_DAMAGE_FORCES + EFL_DONTBLOCKLOS)
    -- Match player Fake-style ragdoll collision behavior while remaining hittable.
    rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    rag:SetSolid(SOLID_VPHYSICS)
    rag:SetMoveType(MOVETYPE_VPHYSICS)
    rag:SetNotSolid(false)
    rag:SetSaveValue("m_takedamage", 2)
    -- prop_ragdoll defaults to DAMAGE_NO; giving it health enables EntityTakeDamage so
    -- bullet/explosion hits trigger the damage relay below.  The value is intentionally
    -- enormous so health depletion cannot remove the entity before the NPC recovers.
    rag:SetMaxHealth(9999999)
    rag:SetHealth(9999999)
    -- Apply appearance net vars (armor class, clothes) so impact effects show correct material.
    if hg and hg.Appearance and hg.Appearance.GetRandomAppearance then
        local appearance = npc.CurAppearance or hg.Appearance.GetRandomAppearance()
        rag:SetNWString("PlayerName", npc:GetNWString("PlayerName", "NPC"))
        if appearance and appearance.AName then
            rag:SetNWString("PlayerName", appearance.AName)
        end
        -- Sync armor/clothes appearance for proper decal rendering on combines/armor
        if appearance then
            rag:SetNetVar("Accessories", npc:GetNetVar("Accessories", ""))
            rag:SetNetVar("Armor", npc:GetNetVar("Armor", {}))
            rag:SetNetVar("HideArmorRender", npc:GetNetVar("HideArmorRender", false))
            -- Copy per-slot clothing appearance for visual consistency
            if hg.bonetohitgroup and type(hg.bonetohitgroup) == "table" then
                for i = 1, 5 do
                    local clothColor = npc:GetNWString("Colthes" .. i, "normal")
                    rag:SetNWString("Colthes" .. i, clothColor)
                end
            end
        end
    end
    -- Let physics settle naturally so the body actually drops instead of freezing upright.
    timer.Simple(0, function()
        if not IsValid(rag) then return end
        local count = rag:GetPhysicsObjectCount() or 0
        for i = 0, count - 1 do
            local phys = rag:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                phys:EnableMotion(true)
                phys:Wake()
                phys:AddVelocity(VectorRand() * 10 + Vector(0, 0, -45))
            end
        end
    end)
    rag.zc_npc_ref      = npc
    rag.organism        = npc.organism   -- proxy so medkits targeting ragdoll see organism
    npc.zc_ragdoll = rag
    CreateDownedWeaponProxy(npc, rag)

    -- Optional animator bridge: mirror a recorded player animation onto downed ragdolls.
    if _G.RagdollAnimator and _G.RagdollAnimator.PlayRecording then
        local mirrorName = nil
        if _G.RagdollAnimator.GetKnockdownMirrorRecordingForRagdoll then
            mirrorName = _G.RagdollAnimator:GetKnockdownMirrorRecordingForRagdoll(rag)
        elseif _G.RagdollAnimator.GetKnockdownMirrorRecording then
            mirrorName = _G.RagdollAnimator:GetKnockdownMirrorRecording()
        end
        if mirrorName and cvMirrorIdleOnly:GetBool() and _G.RagdollAnimator.GetRecordingMode then
            local mode = _G.RagdollAnimator:GetRecordingMode(mirrorName)
            if mode ~= "idle_aim_pose" then
                mirrorName = nil
            end
        end
        if mirrorName then
            local startDelay = (_G.RagdollAnimator.GetMirrorStartDelay and _G.RagdollAnimator:GetMirrorStartDelay()) or 0.65
            timer.Simple(startDelay, function()
                if not IsValid(npc) or not npc.zc_knocked_down then return end
                if not IsValid(rag) or npc.zc_ragdoll ~= rag then return end

                local ok = _G.RagdollAnimator:PlayRecording(mirrorName, rag, 1.0, true)
                if ok then
                    npc.zc_anim_mirror_recording = mirrorName
                end
            end)
        end
    end

    npc:SetNoDraw(true)
    npc:SetNotSolid(true)
    npc:SetPos(GetBuriedAnchorPos(rag))

    -- Anchor timer: Source NPC AI overrides MOVETYPE_NONE via internal SetAbsOrigin.
    -- This timer snaps the NPC back to the ragdoll and forces idle schedule so the
    -- hidden NPC entity cannot navigate or shoot from its skeleton position.
    local anchorIdx = npc:EntIndex()
    timer.Create("ZC_NPCKnockdown_Anchor_" .. anchorIdx, 0.05, 0, function()
        if not IsValid(npc) or not npc.zc_knocked_down then
            timer.Remove("ZC_NPCKnockdown_Anchor_" .. anchorIdx)
            return
        end
        if IsValid(npc.zc_ragdoll) then
            npc:SetPos(GetBuriedAnchorPos(npc.zc_ragdoll))
            npc:SetLocalVelocity(vector_origin)
        end
        npc:SetSchedule(SCHED_IDLE_STAND)
    end)

    print(string.format("[ZC Knockdown] %s knocked down (%s)", npc:GetClass(), reason or "?"))

    -- Suppressing fire while prone: low-rate, low-accuracy return fire that
    -- prefers sidearm-like behavior.
    -- Leg-shot exception: keep full primary pressure with standing weapon profile.
    timer.Create("ZC_NPCDownedShoot_" .. npc:EntIndex(), 0.35, 0, function()
        if not IsValid(npc) or not npc.zc_knocked_down then return end
        if not IsValid(rag) then return end

        local now = CurTime()
        if (npc.zc_next_downed_shot or 0) > now then return end

        if npc.zc_legshot_downed then
            local primaryWep = GetNPCPrimaryWeapon(npc)
            local src, dir = GetDownedShotBasis(npc, rag)
            if IsValid(primaryWep) and src and dir then

                local delay, cone, dmg, num, tracer = GetStandingFireProfile(primaryWep)
                rag:FireBullets({
                    Num = num,
                    Src = src,
                    Dir = dir,
                    Spread = Vector(cone, cone, 0),
                    Tracer = tracer,
                    Damage = dmg,
                    Attacker = npc,
                    Filter = { rag, npc },
                })
                EmitDownedShotEffects(rag, src, dir, GetDownedFireSound(primaryWep, false))

                npc.zc_next_downed_shot = now + delay
                return
            end
        end

        local hasSidearm = NPCHasSidearm(npc)
        local fireChance = hasSidearm and 0.86 or 0.72
        if math.random() > fireChance then
            npc.zc_next_downed_shot = now + (hasSidearm and math.Rand(0.9, 1.4) or math.Rand(1.2, 1.9))
            return
        end

        local src, dir = GetDownedShotBasis(npc, rag)
        if not src or not dir then return end

        local spread = hasSidearm and 0.14 or 0.18
        local dmgMin = hasSidearm and 7 or 6
        local dmgMax = hasSidearm and 11 or 9
        local primaryWep = GetNPCPrimaryWeapon(npc)
        local shotSound = GetDownedFireSound(primaryWep, hasSidearm)

        rag:FireBullets({
            Num = 1, Src = src,
            Dir = dir + VectorRand() * spread,
            Spread = Vector(spread, spread, 0),
            Tracer = hasSidearm and 1 or 0,
            Damage = math.random(dmgMin, dmgMax),
            Attacker = npc,
            Filter = { rag, npc },
        })
        EmitDownedShotEffects(rag, src, dir, shotSound)

        npc.zc_next_downed_shot = now + (hasSidearm and math.Rand(0.75, 1.3) or math.Rand(1.0, 1.7))
    end)

end

function RecoverNPC(npc, reason)
    if not IsValid(npc) then return end
    if not npc.zc_knocked_down then return end

    if REVIVE_REASONS[reason or ""] then
        npc.zc_revived_once = true
    end

    npc.zc_knocked_down = false
    npc.zc_knockdown_until = nil
    npc.zc_next_downed_shot = nil
    npc.zc_revive_earliest = nil
    npc.zc_next_revive_roll = nil
    npc.zc_last_downed_hit = nil
    npc.zc_timeout_extensions = nil
    npc.zc_downed_damage_total = nil
    npc.zc_legshot_downed = nil
    knockedRegistry[npc:EntIndex()] = nil

    -- Cancel position anchor and schedule suppression
    timer.Remove("ZC_NPCKnockdown_Anchor_" .. npc:EntIndex())

        if IsValid(npc.zc_ragdoll) and npc.zc_anim_mirror_recording and _G.RagdollAnimator and _G.RagdollAnimator.StopPlayback then
            _G.RagdollAnimator:StopPlayback(npc.zc_ragdoll, npc.zc_anim_mirror_recording)
        end
        RemoveDownedWeaponProxy(npc)
        npc.zc_anim_mirror_recording = nil

    -- Restore movement (speed will be recalculated by the speed-update loop)
    npc:SetMoveType(MOVETYPE_STEP)
    if isnumber(npc.zc_prev_collision_group) then
        npc:SetCollisionGroup(npc.zc_prev_collision_group)
    else
        npc:SetCollisionGroup(COLLISION_GROUP_NPC)
    end
    if isnumber(npc.zc_prev_solid) then
        npc:SetSolid(npc.zc_prev_solid)
    else
        npc:SetSolid(SOLID_BBOX)
    end
    npc.zc_prev_collision_group = nil
    npc.zc_prev_solid = nil

    -- Restore all hidden weapons
    if npc.zc_all_weapons then
        for _, wep in ipairs(npc.zc_all_weapons) do
            if IsValid(wep) then wep:SetNoDraw(false) end
        end
        npc.zc_all_weapons = nil
    end

    if npc.organism then
        npc.organism.godmode   = false
        -- Restore blood only to just above the knockdown threshold so they remain
        -- wounded; never full-reset to 3200 (that let them tank unlimited hits).
        npc.organism.blood     = math.max(npc.organism.blood or 0, BLOOD_THRESHOLD + 100)
        npc.organism.lleg      = 0
        npc.organism.rleg      = 0
        npc.organism.otrub     = false
        npc.organism.needotrub = false
        npc.organism.needfake  = false
        npc.organism.fake      = false
        npc.organism.spine1    = 0
        npc.organism.spine2    = 0
        npc.organism.spine3    = 0
    end

    if IsValid(npc.zc_ragdoll) then
        npc:SetPos(npc.zc_ragdoll:GetPos())
        npc:SetAngles(npc.zc_ragdoll:GetAngles())
        npc.zc_ragdoll.organism   = nil  -- detach organism proxy
        npc.zc_ragdoll.zc_npc_ref = nil  -- prevent RagdollCleanup from re-firing
        npc.zc_ragdoll:Remove()
    end
    npc.zc_ragdoll = nil
    npc:SetNoDraw(false)
    npc:SetNotSolid(false)

    timer.Remove("ZC_NPCDownedShoot_" .. npc:EntIndex())

    print(string.format("[ZC Knockdown] %s recovered (%s)", npc:GetClass(), reason or "?"))
end

-- If the visual ragdoll is removed externally (map cleanup, round end), recover the NPC
hook.Add("EntityRemoved", "ZC_NPCKnockdown_RagdollCleanup", function(ent)
    if not ent.zc_npc_ref then return end
    local npc = ent.zc_npc_ref
    if IsValid(npc) and npc.zc_knocked_down then
        RecoverNPC(npc, "ragdoll_removed")
    end
end)

-- ── Ragdoll damage relay ──────────────────────────────────────────────────────
-- Bullet/explosion hits on the visible ragdoll reduce the NPC's blood so
-- players can finish off (or medkit can race to revive) a downed enemy.
--
-- NOTE: ZCity's "homigrad-damage" EntityTakeDamage hook fires first on any entity
-- that has .organism set.  Because downed NPCs have org.godmode=true, that hook
-- returns `true` immediately, which stops the GMod hook chain and prevents this
-- relay from ever firing for ZCity weapon hits.
-- The WrapHomigradDamageForKnockdown() block below patches that race by replacing
-- "homigrad-damage" with a wrapper that intercepts NPC ragdoll hits *before* the
-- godmode check and calls RelayRagdollDamageToNPC directly.
-- This relay is kept as a fallback for any damage sources that bypass homigrad-damage.

-- rawDmgOverride should be passed from the homigrad wrapper (captured before orig runs);
-- the fallback standalone path reads dmgInfo directly since it hasn't been modified yet.
local function RelayRagdollDamageToNPC(rag, dmgInfo, rawDmgOverride)
    if IsValid(rag) then rag:SetHealth(9999999) end
    local npc = rag.zc_npc_ref
    if not IsValid(npc) or not npc.zc_knocked_down then return end
    if IsValid(dmgInfo:GetAttacker()) then
        npc.zc_last_attacker = dmgInfo:GetAttacker()
    end
    npc.zc_last_downed_hit = CurTime()

    -- Use pre-captured raw damage so homigrad zeroing dmgInfo after its pipeline
    -- doesn't cause the accumulator/headshot checks to always read 0.
    local rawDmg = rawDmgOverride or math.max(0, tonumber(dmgInfo:GetDamage()) or 0)
    local forceEndFromSharedDamage = AddDownedDamageAndCheckFatal(npc, rawDmg)

    local org = npc.organism
    if not org then return end

    local hitgroup = GetRagdollHitGroup(rag, dmgInfo)
    if hitgroup ~= HITGROUP_HEAD and IsLikelyHeadHitByPosition(rag, dmgInfo) then
        hitgroup = HITGROUP_HEAD
    end
    local forceEndFromHeadshot = IsDownedHeadshotFatal(hitgroup, rawDmg)
    local limb = hitgroup and LIMB_FROM_HITGROUP[hitgroup] or nil
    if limb then
        npc.zc_limb_damage = npc.zc_limb_damage or {}
        npc.zc_limb_damage[limb] = (npc.zc_limb_damage[limb] or 0) + rawDmg

        local shouldAmputate = dmgInfo:IsDamageType(DMG_BLAST) or npc.zc_limb_damage[limb] >= 85
        if limb == "head" and hitgroup == HITGROUP_HEAD and rawDmg >= 35 then
            shouldAmputate = true
        end
        local canAmputate = AMPUTATION_SUPPORTED_LIMBS[limb]
        if shouldAmputate and canAmputate and hg and hg.organism and hg.organism.AmputateLimb and not org[limb .. "amputated"] then
            local ok, err = pcall(hg.organism.AmputateLimb, org, limb)
            if not ok then
                print("[ZCity] NPC knockdown: amputate failed for limb '" .. tostring(limb) .. "': " .. tostring(err))
            end
        end

        -- Mirror basic limb trauma so revive decisions and movement penalties stay in sync.
        if limb == "lleg" or limb == "rleg" or limb == "larm" or limb == "rarm" then
            org[limb] = math.Clamp((org[limb] or 0) + rawDmg / 120, 0, 2.5)
        elseif limb == "head" then
            org.head = math.Clamp((org.head or 0) + rawDmg / 180, 0, 2.5)
        end
    end

    -- Keep downed NPCs finishable, but not paper-thin. Bias toward bleed over
    -- instant blood deletion to better mimic player fake-ragdoll survivability.
    local mul = DOWNED_BLOOD_MUL
    if hitgroup == HITGROUP_HEAD then
        mul = mul * 1.3
    elseif hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG then
        mul = mul * 0.9
    end

    org.blood = math.max(0, (org.blood or 3200) - rawDmg * mul)
    org.bleed = math.Clamp((org.bleed or 0) + (rawDmg * DOWNED_BLEED_MUL), 0, 2.5)

    if dmgInfo:IsDamageType(DMG_BLAST) then
        org.internalBleed = math.Clamp((org.internalBleed or 0) + (rawDmg * DOWNED_BLEED_MUL * 1.2), 0, 2.5)
    end

    -- Keep organism runtime state synced while downed so med/limb systems react
    -- immediately instead of only after true death conversion.
    if hg and hg.send_bareinfo then
        hg.send_bareinfo(org)
    end
    hook.Run("Org Think Call", npc, org)

    if forceEndFromHeadshot or forceEndFromSharedDamage or org.blood <= 0 then
        ForceKillNPC(npc)
    end
end

hook.Add("EntityTakeDamage", "ZC_NPCKnockdown_RagdollDamageRelay", function(ent, dmgInfo)
    -- Hidden source NPC should never consume damage while downed; only the ragdoll should.
    if IsValid(ent) and ent:IsNPC() and ent.zc_knocked_down then
        dmgInfo:SetDamage(0)
        return true
    end

    if not ent.zc_npc_ref then return end
    -- Fallback relay: normally the homigrad-damage wrapper below handles this
    -- before ZCity's godmode check can block it. This covers any damage source
    -- that bypasses the homigrad-damage path entirely.
    RelayRagdollDamageToNPC(ent, dmgInfo)
    return true
end)

-- ── homigrad-damage wrapper ───────────────────────────────────────────────────
-- ZCity's "homigrad-damage" EntityTakeDamage hook returns `true` (stopping the
-- hook chain) when org.godmode is set.  For our knockdown ragdolls that means
-- NO subsequent hook ever fires, so RelayRagdollDamageToNPC is never called.
-- We replace "homigrad-damage" with a wrapper: NPC ragdoll hits are intercepted
-- and relayed here; all other entities are passed to the original hook unchanged.

local zc_homigrad_damage_wrapped = false

local function WrapHomigradDamageForKnockdown()
    if zc_homigrad_damage_wrapped then return true end

    local t = hook.GetTable()["EntityTakeDamage"]
    if not t then return false end
    local orig = t["homigrad-damage"]
    if not orig then return false end

    hook.Remove("EntityTakeDamage", "homigrad-damage")

    local function patched(ent, dmgInfo)
        -- Intercept hits on our NPC knockdown ragdolls before ZCity's godmode check.
        -- We still run the original homigrad damage pipeline so wound visuals,
        -- blood impacts, and limb destruction happen the same way as native ragdolls.
        if IsValid(ent) and ent.zc_npc_ref and IsValid(ent.zc_npc_ref) and ent.zc_npc_ref.zc_knocked_down then
            local org = ent.organism
            if org then
                local prevGodmode = org.godmode
                -- Capture raw damage BEFORE homigrad's pipeline can zero dmgInfo:GetDamage().
                local rawDmg = math.max(0, tonumber(dmgInfo:GetDamage()) or 0)
                org.godmode = false
                ent.zc_npc_ref.zc_last_downed_hit = CurTime()

                local ok, err = pcall(orig, ent, dmgInfo)

                -- Always apply our downed relay after homigrad processing; pass pre-captured
                -- rawDmg so accumulator/headshot checks are not fooled by the zeroed dmgInfo.
                if IsValid(ent) and IsValid(ent.zc_npc_ref) and ent.zc_npc_ref.zc_knocked_down then
                    RelayRagdollDamageToNPC(ent, dmgInfo, rawDmg)
                end

                if IsValid(ent.zc_npc_ref) and ent.zc_npc_ref.zc_knocked_down then
                    -- Keep downed state locked after full damage processing.
                    org.godmode   = true
                    org.needfake  = false
                    org.fake      = false
                    org.otrub     = true
                    org.needotrub = true

                    -- If the downed pool is depleted, end revive window immediately
                    -- and force death instead of waiting for revive-think cadence.
                    if IsDownedPoolDepleted(ent.zc_npc_ref) then
                        ForceKillNPC(ent.zc_npc_ref)
                    end
                else
                    org.godmode = prevGodmode
                end

                if not ok then
                    print("[ZCity] NPC knockdown: homigrad-damage wrapper error: " .. tostring(err))
                    RelayRagdollDamageToNPC(ent, dmgInfo)
                end
            else
                RelayRagdollDamageToNPC(ent, dmgInfo)
            end
            return true
        end
        return orig(ent, dmgInfo)
    end

    hook.Add("EntityTakeDamage", "homigrad-damage", patched)
    zc_homigrad_damage_wrapped = true
    print("[ZCity] NPC knockdown: homigrad-damage wrapped for ragdoll relay")
    return true
end

local function TryWrapHomigrad()
    if WrapHomigradDamageForKnockdown() then
        hook.Remove("InitPostEntity", "ZC_NPCKnockdown_WrapHomigrad")
        timer.Remove("ZC_NPCKnockdown_WrapRetry")
    end
end

hook.Add("InitPostEntity", "ZC_NPCKnockdown_WrapHomigrad", TryWrapHomigrad)
timer.Create("ZC_NPCKnockdown_WrapRetry", 1, 10, TryWrapHomigrad)

-- ── Damage detection ──────────────────────────────────────────────────────────
-- HomigradDamage fires after the organism pipeline. harm = post-armor dmg/100.

hook.Add("HomigradDamage", "ZC_NPCKnockdown_Damage", function(ent, dmgInfo, hitgroup, charEnt, harm)
    if not IsValid(ent) or not ent:IsNPC() then return end
    if not KNOCKDOWN_CLASSES[ent:GetClass()] then return end
    if ent.zc_kill_in_progress then return end
    if ent.zc_knocked_down then return end
    if not ent.organism then return end

    local org = ent.organism

    local thresh = GetLiveThresholds()

    if (harm or 0) >= thresh.harm then
        KnockDownNPC(ent, string.format("heavy_harm=%.2f", harm or 0))
        return
    end

    if (org.blood or 5000) < thresh.blood then
        KnockDownNPC(ent, string.format("low_blood=%.0f", org.blood or 0))
        return
    end

    if (org.lleg or 0) >= thresh.leg or (org.rleg or 0) >= thresh.leg then
        KnockDownNPC(ent, string.format("leg l=%.2f r=%.2f", org.lleg or 0, org.rleg or 0))
        return
    end
end)

-- ── NPC movement speed degradation ──────────────────────────────────────────
-- Scale NPC speed based on blood and leg damage, mirroring the player formula
-- in sh_inertia.lua. Applied to all tracked (non-knocked-down) NPCs so damage
-- actually slows them before they go down.
local nextSpeedUpdate = 0
hook.Add("Think", "ZC_NPCKnockdown_SpeedUpdate", function()
    local now = CurTime()
    if now < nextSpeedUpdate then return end
    nextSpeedUpdate = now + SPEED_UPDATE_INT

    for idx, npc in pairs(npcRegistry) do
        if not IsValid(npc) then npcRegistry[idx] = nil; continue end
        if npc.zc_knocked_down then continue end   -- movement locked during knockdown
        local org = npc.organism
        if not org then continue end

        local baseSpeed = npc.zc_base_speed or NPC_BASE_SPEED

        -- Blood: full speed at 5000, 0 speed at 0  (clamp 0.2–1.0 so they still move)
        local bloodMul  = math.Clamp((org.blood or 5000) / 5000, 0.2, 1.0)

        -- Leg damage: each leg above 0.5 penalty penalises 40%, min 0.4
        local lleg = org.lleg or 0
        local rleg = org.rleg or 0
        local legMul = math.Clamp(
            (lleg >= 0.5 and (1 - lleg * 0.4) or 1) *
            (rleg >= 0.5 and (1 - rleg * 0.4) or 1),
            0.4, 1.0
        )

        local newSpeed = math.max(baseSpeed * bloodMul * legMul, 40)
        if not isfunction(npc.SetMaxSpeed) then continue end
        local currentSpeed = isfunction(npc.GetMaxSpeed) and npc:GetMaxSpeed() or baseSpeed
        if not isnumber(currentSpeed) then currentSpeed = baseSpeed end
        if math.abs(currentSpeed - newSpeed) > 5 then
            npc:SetMaxSpeed(newSpeed)
        end
    end
end)

-- ── Revival scan ─────────────────────────────────────────────────────────────
local nextRevive = 0

hook.Add("Think", "ZC_NPCKnockdown_ReviveThink", function()
    local now = CurTime()
    if now < nextRevive then return end
    nextRevive = now + REVIVE_INTERVAL

    for idx, npc in pairs(knockedRegistry) do
        if not IsValid(npc) then knockedRegistry[idx] = nil; continue end

        local org = npc.organism

        -- Zero pool while ragdolled should always win over timeout recovery.
        if IsDownedPoolDepleted(npc) then
            ForceKillNPC(npc)
            continue
        end

        -- Hard cap for revival window per NPC.
        if now >= (npc.zc_knockdown_until or 0) then
            if CanRecoverFromDowned(npc, now) then
                RecoverNPC(npc, "revive_window_timeout")
            else
                npc.zc_timeout_extensions = (npc.zc_timeout_extensions or 0) + 1
                if npc.zc_timeout_extensions > RECOVER_TIMEOUT_MAX_EXTENDS then
                    -- After a long downed window, prefer a natural stand-up if the
                    -- pool is still not depleted; only force-kill true zero-pool states.
                    if IsDownedPoolDepleted(npc) then
                        ForceKillNPC(npc)
                    else
                        RecoverNPC(npc, "revive_window_timeout")
                    end
                else
                    npc.zc_knockdown_until = now + RECOVER_TIMEOUT_EXTEND
                end
            end
            continue
        end

        -- Medkit restored enough blood: recover only if stabilized.
        if org and (org.blood or 0) >= GetLiveThresholds().blood and CanRecoverFromDowned(npc, now) then
            RecoverNPC(npc, "blood_restored")
            continue
        end

        -- Require a short delay before allies can "notice" and attempt a revive.
        if now < (npc.zc_revive_earliest or now) then
            continue
        end

        -- Throttle revive probability checks so nearby allies do not insta-chain revive.
        if now < (npc.zc_next_revive_roll or 0) then
            continue
        end
        npc.zc_next_revive_roll = now + REVIVE_ROLL_INTERVAL

        local canBeRevived = false
        for _, ally in ipairs(ents.FindInSphere(npc:GetPos(), REVIVE_RADIUS)) do
            if CanAllyReviveTarget(ally, npc) then
                canBeRevived = true
                break
            end
        end

        if canBeRevived and CanRecoverFromDowned(npc, now) and math.Rand(0, 1) <= REVIVE_CHANCE then
            RecoverNPC(npc, "revived_by_ally")
        end
    end
end)

-- ── Org Think: block fake/otrub kill path while knocked down ─────────────────
-- ZCity's NPC organism think does NOT respect org.godmode for NPCs.
-- Even with godmode=true, the pipeline re-sets needfake=true every tick when blood
-- is critical. We block it here explicitly so the body never drops during knockdown.
-- Note: sv_tier_0 skips the entire Org Think when org.godmode=true, so this hook
-- is a belt-and-suspenders guard for any path that re-enables godmode mid-tick.
hook.Add("Org Think", "ZC_NPCKnockdown_BlockFakePath", function(owner, org, timeValue)
    if not IsValid(owner) or owner:IsPlayer() then return end
    if not owner.zc_knocked_down then return end
    org.needfake  = false
    org.fake      = false
    org.otrub     = true   -- hold unconscious state for medkit proxy targeting
    org.godmode   = true
    -- Hold alive=true every tick so ZCity's kill path (not org.alive → owner:Kill())
    -- never fires while we are managing the downed state.
    org.alive     = true
end)

-- ── Round cleanup ─────────────────────────────────────────────────────────────
-- Recover all knocked-down NPCs at round end/start so state doesn't persist
local function RecoverAll()
    for idx, npc in pairs(knockedRegistry) do
        if IsValid(npc) then
            RecoverNPC(npc, "round_reset")
        else
            knockedRegistry[idx] = nil
        end
    end
end

hook.Add("ZB_PreRoundStart", "ZC_NPCKnockdown_RoundReset", RecoverAll)
hook.Add("ZB_EndRound",      "ZC_NPCKnockdown_RoundReset", RecoverAll)
hook.Add("PostCleanupMap",   "ZC_NPCKnockdown_RoundReset", RecoverAll)

-- ── Suppress ZCity death ragdoll for already-downed NPCs ─────────────────────
-- When org.alive breaks through our guard and ZCity calls owner:Kill() on a
-- downed NPC, Source fires CreateEntityRagdoll immediately. That death ragdoll
-- is redundant (our knockdown ragdoll is already the corpse) and may conflict
-- with it. Remove it instantly so only the knockdown ragdoll remains visible.
hook.Add("CreateEntityRagdoll", "ZC_NPCKnockdown_SuppressDeathRag", function(ent, rag)
    if not IsValid(ent) or not ent:IsNPC() then return end
    -- Only suppress when the NPC was actively in downed state.
    -- If knockdown state is already cleared (normal death path via ForceKillNPC
    -- → npc:Remove()) zc_knocked_down will be false so we leave the rag alone.
    if not ent.zc_knocked_down then return end
    if not KNOCKDOWN_CLASSES[ent:GetClass()] then return end
    timer.Simple(0, function()
        if IsValid(rag) then rag:Remove() end
    end)
end)

print("[ZCity] NPC knockdown system loaded")
