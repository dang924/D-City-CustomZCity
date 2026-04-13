if CLIENT then return end

util.AddNetworkString("ZC_RequestCombineResistanceConfig")
util.AddNetworkString("ZC_SendCombineResistanceConfig")
util.AddNetworkString("ZC_SaveCombineResistanceConfig")

CreateConVar(
    "zc_combine_resist_reference_players",
    "8",
    FCVAR_ARCHIVE,
    "Reference active-player count used for faction resistance scaling.",
    0,
    128
)
CreateConVar(
    "zc_combine_resist_min_scale",
    "0.05",
    FCVAR_ARCHIVE,
    "Minimum damage scale allowed for faction resistance tuning.",
    0,
    2
)
CreateConVar(
    "zc_combine_resist_max_scale",
    "1.00",
    FCVAR_ARCHIVE,
    "Maximum damage scale allowed for faction resistance tuning.",
    0,
    2
)
CreateConVar(
    "zc_combine_damage_scale_base",
    "0.20",
    FCVAR_ARCHIVE,
    "Armored-hit damage scale for player Combine at the reference player count. Lower is tankier.",
    0,
    2
)
CreateConVar(
    "zc_combine_damage_scale_per_player",
    "0.00",
    FCVAR_ARCHIVE,
    "Additional player Combine armored-hit damage scale applied per active-player delta from the reference count.",
    -0.25,
    0.25
)
CreateConVar(
    "zc_metrocop_damage_scale_base",
    "0.20",
    FCVAR_ARCHIVE,
    "Armored-hit damage scale for player Metrocop at the reference player count. Lower is tankier.",
    0,
    2
)
CreateConVar(
    "zc_metrocop_damage_scale_per_player",
    "0.00",
    FCVAR_ARCHIVE,
    "Additional player Metrocop armored-hit damage scale applied per active-player delta from the reference count.",
    -0.25,
    0.25
)
CreateConVar(
    "zc_combine_npc_damage_scale_base",
    "0.20",
    FCVAR_ARCHIVE,
    "Armored-hit damage scale for NPC Combine at the reference player count. Lower is tankier.",
    0,
    2
)
CreateConVar(
    "zc_combine_npc_damage_scale_per_player",
    "0.00",
    FCVAR_ARCHIVE,
    "Additional NPC Combine armored-hit damage scale applied per active-player delta from the reference count.",
    -0.25,
    0.25
)
CreateConVar(
    "zc_metrocop_npc_damage_scale_base",
    "0.20",
    FCVAR_ARCHIVE,
    "Armored-hit damage scale for NPC Metrocop at the reference player count. Lower is tankier.",
    0,
    2
)
CreateConVar(
    "zc_metrocop_npc_damage_scale_per_player",
    "0.00",
    FCVAR_ARCHIVE,
    "Additional NPC Metrocop armored-hit damage scale applied per active-player delta from the reference count.",
    -0.25,
    0.25
)
CreateConVar(
    "zc_rebel_npc_damage_scale_base",
    "1.00",
    FCVAR_ARCHIVE,
    "Damage scale for rebel NPCs at the reference player count. Lower is tankier.",
    0,
    2
)
CreateConVar(
    "zc_rebel_npc_damage_scale_per_player",
    "0.00",
    FCVAR_ARCHIVE,
    "Additional rebel NPC damage scale applied per active-player delta from the reference count.",
    -0.25,
    0.25
)
CreateConVar(
    "zc_gordon_damage_scale_base",
    "0.20",
    FCVAR_ARCHIVE,
    "Armored-hit damage scale for Gordon at the reference player count. Lower is tankier.",
    0,
    2
)
CreateConVar(
    "zc_gordon_damage_scale_per_player",
    "0.00",
    FCVAR_ARCHIVE,
    "Additional Gordon armored-hit damage scale applied per active-player delta from the reference count.",
    -0.25,
    0.25
)

local REBEL_NPC_CLASSES = {
    ["npc_alyx"] = true,
    ["npc_barney"] = true,
    ["npc_citizen"] = true,
    ["npc_eli"] = true,
    ["npc_fisherman"] = true,
    ["npc_kleiner"] = true,
    ["npc_magnusson"] = true,
    ["npc_mossman"] = true,
    ["npc_odessa"] = true,
    ["npc_rollermine_hacked"] = true,
    ["npc_turret_floor_resistance"] = true,
    ["npc_vortigaunt"] = true,
}

local function readFloat(name, fallback)
    local cv = GetConVar(name)
    if not cv then return fallback end
    return tonumber(cv:GetFloat()) or fallback
end

local function readInt(name, fallback)
    local cv = GetConVar(name)
    if not cv then return fallback end
    return tonumber(cv:GetInt()) or fallback
end

local function getActivePlayerCount()
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        count = count + 1
    end
    return count
end

local function getResistanceConfig()
    return {
        referencePlayers = math.max(0, readInt("zc_combine_resist_reference_players", 8)),
        minScale = math.Clamp(readFloat("zc_combine_resist_min_scale", 0.05), 0, 2),
        maxScale = math.Clamp(readFloat("zc_combine_resist_max_scale", 1), 0, 2),
        combinePlayer = {
            base = math.Clamp(readFloat("zc_combine_damage_scale_base", 0.2), 0, 2),
            perPlayer = math.Clamp(readFloat("zc_combine_damage_scale_per_player", 0), -0.25, 0.25),
        },
        metrocopPlayer = {
            base = math.Clamp(readFloat("zc_metrocop_damage_scale_base", 0.2), 0, 2),
            perPlayer = math.Clamp(readFloat("zc_metrocop_damage_scale_per_player", 0), -0.25, 0.25),
        },
        combineNpc = {
            base = math.Clamp(readFloat("zc_combine_npc_damage_scale_base", 0.2), 0, 2),
            perPlayer = math.Clamp(readFloat("zc_combine_npc_damage_scale_per_player", 0), -0.25, 0.25),
        },
        metrocopNpc = {
            base = math.Clamp(readFloat("zc_metrocop_npc_damage_scale_base", 0.2), 0, 2),
            perPlayer = math.Clamp(readFloat("zc_metrocop_npc_damage_scale_per_player", 0), -0.25, 0.25),
        },
        rebelNpc = {
            base = math.Clamp(readFloat("zc_rebel_npc_damage_scale_base", 1), 0, 2),
            perPlayer = math.Clamp(readFloat("zc_rebel_npc_damage_scale_per_player", 0), -0.25, 0.25),
        },
        gordon = {
            base = math.Clamp(readFloat("zc_gordon_damage_scale_base", 0.2), 0, 2),
            perPlayer = math.Clamp(readFloat("zc_gordon_damage_scale_per_player", 0), -0.25, 0.25),
        },
    }
end

local SCALE_KINDS = {
    "combinePlayer", "metrocopPlayer", "combineNpc", "metrocopNpc", "rebelNpc", "gordon",
}

local scaleCacheExpire = 0
local scaleCachePacked = {}
local SCALE_CACHE_TTL = 0.2

local function rebuildScaleCache()
    local cfg = getResistanceConfig()
    local minScale = math.min(cfg.minScale, cfg.maxScale)
    local maxScale = math.max(cfg.minScale, cfg.maxScale)
    local activePlayers = getActivePlayerCount()
    local delta = activePlayers - cfg.referencePlayers

    for _, kind in ipairs(SCALE_KINDS) do
        local entry = cfg[kind]
        if entry then
            scaleCachePacked[kind] = math.Clamp(entry.base + (delta * entry.perPlayer), minScale, maxScale)
        else
            scaleCachePacked[kind] = 1
        end
    end

    scaleCacheExpire = CurTime() + SCALE_CACHE_TTL
end

local function getScaledDamageScale(kind)
    if CurTime() >= scaleCacheExpire then
        rebuildScaleCache()
    end
    return scaleCachePacked[kind] or 1
end

hook.Add("PostCleanupMap", "ZC_CombineResist_InvalidateScaleCache", function()
    scaleCacheExpire = 0
end)

_G.ZC_GetCombineResistanceConfig = getResistanceConfig
_G.ZC_GetCombineResistanceScale = function(kind)
    return getScaledDamageScale(kind)
end

local function sendResistanceConfig(ply)
    if not IsValid(ply) then return end
    net.Start("ZC_SendCombineResistanceConfig")
    net.WriteTable(getResistanceConfig())
    net.Send(ply)
end

net.Receive("ZC_RequestCombineResistanceConfig", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    sendResistanceConfig(ply)
end)

net.Receive("ZC_SaveCombineResistanceConfig", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local payload = net.ReadTable() or {}
    local referencePlayers = math.Clamp(math.floor(tonumber(payload.referencePlayers) or 8), 0, 128)
    local minScale = math.Clamp(tonumber(payload.minScale) or 0.05, 0, 2)
    local maxScale = math.Clamp(tonumber(payload.maxScale) or 1.0, 0, 2)
    local combinePlayer = payload.combinePlayer or {}
    local metrocopPlayer = payload.metrocopPlayer or {}
    local combineNpc = payload.combineNpc or {}
    local metrocopNpc = payload.metrocopNpc or {}
    local rebelNpc = payload.rebelNpc or {}
    local gordon = payload.gordon or {}

    RunConsoleCommand("zc_combine_resist_reference_players", tostring(referencePlayers))
    RunConsoleCommand("zc_combine_resist_min_scale", string.format("%.3f", minScale))
    RunConsoleCommand("zc_combine_resist_max_scale", string.format("%.3f", maxScale))
    RunConsoleCommand("zc_combine_damage_scale_base", string.format("%.3f", math.Clamp(tonumber(combinePlayer.base) or 0.2, 0, 2)))
    RunConsoleCommand("zc_combine_damage_scale_per_player", string.format("%.3f", math.Clamp(tonumber(combinePlayer.perPlayer) or 0, -0.25, 0.25)))
    RunConsoleCommand("zc_metrocop_damage_scale_base", string.format("%.3f", math.Clamp(tonumber(metrocopPlayer.base) or 0.2, 0, 2)))
    RunConsoleCommand("zc_metrocop_damage_scale_per_player", string.format("%.3f", math.Clamp(tonumber(metrocopPlayer.perPlayer) or 0, -0.25, 0.25)))
    RunConsoleCommand("zc_combine_npc_damage_scale_base", string.format("%.3f", math.Clamp(tonumber(combineNpc.base) or 0.2, 0, 2)))
    RunConsoleCommand("zc_combine_npc_damage_scale_per_player", string.format("%.3f", math.Clamp(tonumber(combineNpc.perPlayer) or 0, -0.25, 0.25)))
    RunConsoleCommand("zc_metrocop_npc_damage_scale_base", string.format("%.3f", math.Clamp(tonumber(metrocopNpc.base) or 0.2, 0, 2)))
    RunConsoleCommand("zc_metrocop_npc_damage_scale_per_player", string.format("%.3f", math.Clamp(tonumber(metrocopNpc.perPlayer) or 0, -0.25, 0.25)))
    RunConsoleCommand("zc_rebel_npc_damage_scale_base", string.format("%.3f", math.Clamp(tonumber(rebelNpc.base) or 1, 0, 2)))
    RunConsoleCommand("zc_rebel_npc_damage_scale_per_player", string.format("%.3f", math.Clamp(tonumber(rebelNpc.perPlayer) or 0, -0.25, 0.25)))
    RunConsoleCommand("zc_gordon_damage_scale_base", string.format("%.3f", math.Clamp(tonumber(gordon.base) or 0.2, 0, 2)))
    RunConsoleCommand("zc_gordon_damage_scale_per_player", string.format("%.3f", math.Clamp(tonumber(gordon.perPlayer) or 0, -0.25, 0.25)))

    scaleCacheExpire = 0
    sendResistanceConfig(ply)
end)

local installed = false

local function applyPunchEffects(org, dmg, dmgInfo)
    local owner = istable(org) and org.owner or nil
    if not IsValid(owner) or not owner:IsPlayer() then return end
    if not org.alive then return end
    if not dmgInfo:IsDamageType(DMG_BUCKSHOT + DMG_BULLET) then return end

    owner:ViewPunch(AngleRand(-30, 30))
    owner:EmitSound("homigrad/physics/shield/bullet_hit_shield_0" .. math.random(7) .. ".wav", 80, math.random(95, 105))
    owner:AddTinnitus(3, true)

    net.Start("AddFlash")
        net.WriteVector(hg.eye(owner) + owner:GetForward() * 3)
        net.WriteFloat(3)
        net.WriteInt(100, 20)
    net.Send(owner)

    hg.ExplosionDisorientation(owner, 6, 6)
    if hg.organism and hg.organism.input_list and hg.organism.input_list.spine3 then
        hg.organism.input_list.spine3(org, nil, (dmg / 100) * math.Rand(0, 0.1), dmgInfo)
    end
end

local function runPatchedArmor(org, dmg, dmgInfo, placement, armorName, damageScale, punch, ...)
    if not istable(org) or not IsValid(org.owner) then return 0 end

    force = true

    local owner = org.owner
    owner.armors_health = owner.armors_health or {}

    local inflictor = dmgInfo:GetInflictor()
    local bullet = IsValid(inflictor) and inflictor.bullet or nil
    local penetration = (bullet and bullet.Penetration) or 1

    local armorData = hg and hg.armor and hg.armor[placement] and hg.armor[placement][armorName] or nil
    local prot = (armorData and armorData.protection or 10) - penetration
    prot = prot * (owner.armors_health[armorName] or 1)

    local _, _, hit = ...

    if punch then
        applyPunchEffects(org, dmg, dmgInfo)
    end

    if hg and hg.ArmorEffect then
        hg.ArmorEffect(placement, armorName, dmgInfo, org, hit, prot)
    end

    if prot < 0 then
        return 0
    end

    dmgInfo:SetDamageType(DMG_CLUB)
    dmgInfo:SetDamageForce(dmgInfo:GetDamageForce() * 0.4)
    dmgInfo:ScaleDamage(math.Clamp(damageScale, 0, 2))

    return 0.9
end

local function getArmorResistanceKind(owner)
    if not IsValid(owner) then return nil end

    if owner:IsPlayer() then
        if owner.PlayerClassName == "Combine" then return "combinePlayer" end
        if owner.PlayerClassName == "Metrocop" then return "metrocopPlayer" end
        if owner.PlayerClassName == "Gordon" then return "gordon" end
        return nil
    end

    if owner:IsNPC() then
        local class = owner:GetClass()
        if class == "npc_combine_s" then return "combineNpc" end
        if class == "npc_metropolice" then return "metrocopNpc" end
    end

    return nil
end

local function patchArmorCallback(callbackName, placement, armorName, punch)
    local original = hg.organism.input_list[callbackName]
    if not original then return end

    hg.organism.input_list[callbackName] = function(org, bone, dmg, dmgInfo, ...)
        local owner = istable(org) and org.owner or nil
        local kind = getArmorResistanceKind(owner)
        if not kind then
            return original(org, bone, dmg, dmgInfo, ...)
        end

        return runPatchedArmor(org, dmg, dmgInfo, placement, armorName, getScaledDamageScale(kind), punch, ...)
    end
end

local function installResistancePatch()
    if installed then return true end
    if not hg or not hg.organism or not hg.organism.input_list then return false end

    patchArmorCallback("cmb_armor", "torso", "cmb_armor", false)
    patchArmorCallback("cmb_helmet", "head", "cmb_helmet", true)
    patchArmorCallback("cmb_arm_armor_left", "arm", "cmb_arm_armor_left", false)
    patchArmorCallback("cmb_arm_armor_right", "arm", "cmb_arm_armor_right", false)
    patchArmorCallback("cmb_leg_armor_left", "leg", "cmb_leg_armor_left", false)
    patchArmorCallback("cmb_leg_armor_right", "leg", "cmb_leg_armor_right", false)

    patchArmorCallback("metrocop_armor", "torso", "metrocop_armor", false)
    patchArmorCallback("metrocop_helmet", "head", "metrocop_helmet", true)

    patchArmorCallback("gordon_helmet", "head", "gordon_helmet", false)
    patchArmorCallback("gordon_armor", "torso", "gordon_armor", false)
    patchArmorCallback("gordon_arm_armor_left", "arm", "gordon_arm_armor_left", false)
    patchArmorCallback("gordon_arm_armor_right", "arm", "gordon_arm_armor_right", false)
    patchArmorCallback("gordon_leg_armor_left", "leg", "gordon_leg_armor_left", false)
    patchArmorCallback("gordon_leg_armor_right", "leg", "gordon_leg_armor_right", false)
    patchArmorCallback("gordon_calf_armor_left", "leg", "gordon_calf_armor_left", false)
    patchArmorCallback("gordon_calf_armor_right", "leg", "gordon_calf_armor_right", false)

    installed = true
    print("[ZC CombineResistance] Installed tunable faction resistance handlers (cached scales)")
    return true
end

hook.Add("EntityTakeDamage", "ZC_RebelNPCResistance", function(target, dmgInfo)
    if not IsValid(target) or not target:IsNPC() then return end
    if not REBEL_NPC_CLASSES[target:GetClass()] then return end

    dmgInfo:ScaleDamage(getScaledDamageScale("rebelNpc"))
end)

hook.Add("InitPostEntity", "ZC_InstallCombineResistancePatch", function()
    if installResistancePatch() then return end

    timer.Create("ZC_InstallCombineResistancePatch", 1, 10, function()
        if installResistancePatch() then
            timer.Remove("ZC_InstallCombineResistancePatch")
        end
    end)
end)