-- ZScav: Tarkov-style scavenger gamemode for ZCity.
--
-- This file declares the mode and the SHARED item-size catalog used to
-- decide how big each item is on the inventory grid. Every value here is
-- safe to edit / hot-reload at runtime.
--
-- Iteration 1 scope: gear inventory + grid + replace Homigrad's gear/pickup
-- system. The "health" tab and looted-container right panel are stubbed.

local MODE = MODE

MODE.name        = "zscav"
MODE.PrintName   = "ZScav"
MODE.LootSpawn   = false
MODE.GuiltDisabled = true
MODE.randomSpawns  = false
MODE.OverrideSpawn = true
MODE.ROUND_TIME = 2100

-- Don't auto-pick this mode; it is selected manually via zb_setround zscav
-- (or whatever round-pick command the host already uses).
MODE.ForBigMaps = false
MODE.Chance     = 0

-- Round ends when only one combatant is left. Overridable later.
MODE.EndLogicType = 2

MODE.Description = "Tarkov-style scavenger mode with grid inventory."

zb = zb or {}
zb.Points = zb.Points or {}

zb.Points.ZSCAV_SAFESPAWN = zb.Points.ZSCAV_SAFESPAWN or {}
zb.Points.ZSCAV_SAFESPAWN.Color = Color(60, 190, 110)
zb.Points.ZSCAV_SAFESPAWN.Name = "ZSCAV_SAFESPAWN"

zb.Points.ZSCAV_SAFEBACK = zb.Points.ZSCAV_SAFEBACK or {}
zb.Points.ZSCAV_SAFEBACK.Color = Color(246, 132, 84)
zb.Points.ZSCAV_SAFEBACK.Name = "ZSCAV_SAFEBACK"

zb.Points.ZSCAV_PAD = zb.Points.ZSCAV_PAD or {}
zb.Points.ZSCAV_PAD.Color = Color(90, 200, 255)
zb.Points.ZSCAV_PAD.Name = "ZSCAV_PAD"

zb.Points.ZSCAV_EXTRACT = zb.Points.ZSCAV_EXTRACT or {}
zb.Points.ZSCAV_EXTRACT.Color = Color(245, 188, 72)
zb.Points.ZSCAV_EXTRACT.Name = "ZSCAV_EXTRACT"

if SERVER then
    AddCSLuaFile("cl_zscav_raid.lua")
    AddCSLuaFile("cl_zscav_death.lua")
elseif CLIENT then
    include("cl_zscav_raid.lua")
    include("cl_zscav_death.lua")
end

function MODE:CanLaunch()
    return true
end

if SERVER then
    local function getSafeSpawnVectors(pointGroup)
        if not (zb and zb.GetMapPoints) then return {} end

        local points = zb.GetMapPoints(pointGroup) or {}
        if zb.TranslatePointsToVectors then
            return zb.TranslatePointsToVectors(points)
        end

        local vectors = {}
        for _, point in ipairs(points) do
            if istable(point) and isvector(point.pos) then
                vectors[#vectors + 1] = point.pos
            elseif isvector(point) then
                vectors[#vectors + 1] = point
            end
        end

        return vectors
    end

    function MODE:GetTeamSpawn()
        local safeSpawns = getSafeSpawnVectors("ZSCAV_SAFESPAWN")
        if #safeSpawns <= 0 then
            safeSpawns = getSafeSpawnVectors("SAFE_SPAWN")
        end
        if #safeSpawns <= 0 then
            safeSpawns = getSafeSpawnVectors("Spawnpoint")
        end

        return safeSpawns, safeSpawns
    end

    function MODE:Intermission()
        game.CleanUpMap()
        for _, ply in player.Iterator() do
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ApplyAppearance then ApplyAppearance(ply) end
            ply:SetupTeam(0)
        end
    end

    function MODE:CheckAlivePlayers()
        local out = {}
        for _, ply in player.Iterator() do
            if not ply:Alive() then continue end
            if ply.organism and ply.organism.incapacitated then continue end
            out[#out + 1] = ply
        end
        return out
    end

    function MODE:ShouldRoundEnd()
        return false
    end

    function MODE:RoundStart()
        for _, ply in player.Iterator() do
            if not ply:Alive() then continue end
            ply:SetSuppressPickupNotices(true)
            ply.noSound = true
            ply:Give("weapon_hands_sh")
            ply:SelectWeapon("weapon_hands_sh")
            timer.Simple(0.1, function()
                if IsValid(ply) then ply.noSound = false end
            end)
            ply:SetSuppressPickupNotices(false)
            if zb.GiveRole then
                zb.GiveRole(ply, "Scavenger", Color(190, 150, 60))
            end
        end
    end

    function MODE:GiveWeapons() end
    function MODE:GiveEquipment() end
    function MODE:RoundThink() end
end

-- =====================================================================
-- ZSCAV global namespace (shared)
-- =====================================================================
ZSCAV = ZSCAV or {}
ZSCAV.MODE_NAME = "zscav"

-- Default grid sizes. Tunable per server; clients receive these sizes via
-- inventory sync so the UI auto-resizes.
ZSCAV.Grid = {
    Backpack = { w = 6, h = 8 },  -- main storage
    Pocket   = { w = 1, h = 4 },  -- single pocket grid
    LootView = { w = 8, h = 10 }, -- container being looted (right panel)
}

-- Gear slots displayed on the left panel. Order is preserved in the UI.
ZSCAV.GearSlots = {
    { id = "ears",       label = "Ears" },
    { id = "helmet",     label = "Helmet" },
    { id = "face_cover", label = "Face" },
    { id = "body_armor", label = "Body Armor" },
    { id = "tactical_rig", label = "Tactical Rig" },
    { id = "backpack",   label = "Backpack" },
    { id = "primary",    label = "On Back" },
    { id = "secondary",  label = "On Sling" },
    { id = "sidearm",    label = "Sidearm" },
    { id = "sidearm2",   label = "Sidearm 2" },
    { id = "melee",      label = "Scabbard" },
}

ZSCAV.CustomHotbarBase = 4
ZSCAV.CustomHotbarCount = 7
ZSCAV.CustomHotbarMax = ZSCAV.CustomHotbarBase + ZSCAV.CustomHotbarCount - 1

function ZSCAV:GetCustomHotbarKeyLabel(slotNumber)
    slotNumber = math.floor(tonumber(slotNumber) or 0)
    if slotNumber <= 0 then return "" end
    if slotNumber == 10 then return "0" end
    return tostring(slotNumber)
end

local function ZSCAV_ArmIsUsable(org, prefix)
    if not istable(org) then return true end
    if org[prefix .. "amputated"] then return false end
    return (tonumber(org[prefix]) or 0) < 1
end

function ZSCAV:GetPlayerInventoryBlockReason(ply)
    if not IsValid(ply) then return "invalid" end
    if not ply:Alive() then return "dead" end

    local org = (istable(ply.organism) and ply.organism)
        or (istable(ply.new_organism) and ply.new_organism)
        or nil

    if org then
        if org.otrub then return "otrub" end
        local leftArmUsable = ZSCAV_ArmIsUsable(org, "larm")
        local rightArmUsable = ZSCAV_ArmIsUsable(org, "rarm")
        if not leftArmUsable and not rightArmUsable then return "arms" end
    end

    return nil
end

function ZSCAV:CanPlayerUseInventory(ply)
    return self:GetPlayerInventoryBlockReason(ply) == nil
end

-- =====================================================================
-- Item size catalog
-- =====================================================================
-- ZSCAV.ItemSizes[class] = { w = X, h = Y }
-- Anything not listed falls back to ZSCAV:GuessItemSize(class) which uses
-- weapon.Category / class-name heuristics. Add entries here to override.
ZSCAV.ItemSizes = ZSCAV.ItemSizes or {}

-- Pistols / sidearms (1x2)
local pistols = {
    "weapon_glock17", "weapon_glock18c", "weapon_hk_usp", "weapon_p22",
    "weapon_cz75", "weapon_deagle", "weapon_revolver357",
}
for _, c in ipairs(pistols) do ZSCAV.ItemSizes[c] = { w = 1, h = 2 } end

-- SMGs / compact (2x2)
local smgs = { "weapon_mp5", "weapon_mp7" }
for _, c in ipairs(smgs) do ZSCAV.ItemSizes[c] = { w = 2, h = 2 } end

-- Shotguns / rifles (2x3)
local rifles = {
    "weapon_doublebarrel", "weapon_doublebarrel_short",
    "weapon_remington870", "weapon_xm1014",
    "weapon_sks", "weapon_akm",
}
for _, c in ipairs(rifles) do ZSCAV.ItemSizes[c] = { w = 2, h = 3 } end

-- Long / heavy weapons (3x5)
local longarms = {
    "weapon_m98b", "weapon_sr25", "weapon_ptrd", "weapon_hg_rpg",
}
for _, c in ipairs(longarms) do ZSCAV.ItemSizes[c] = { w = 3, h = 5 } end

-- Melee
local melee = {
    "weapon_leadpipe", "weapon_hg_crowbar", "weapon_tomahawk",
    "weapon_hatchet", "weapon_hg_axe", "weapon_kabar",
    "weapon_pocketknife", "weapon_melee",
}
for _, c in ipairs(melee) do ZSCAV.ItemSizes[c] = { w = 1, h = 2 } end

-- Grenades / throwables (1x1)
local nades = {
    "weapon_hg_molotov_tpik", "weapon_hg_pipebomb_tpik",
    "weapon_hg_f1_tpik", "weapon_hg_grenade_tpik",
    "weapon_hg_flashbang_tpik", "weapon_hg_hl2nade_tpik",
    "weapon_hg_m18_tpik", "weapon_hg_mk2_tpik",
    "weapon_hg_smokenade_tpik", "weapon_hg_rgd_tpik",
    "weapon_hg_type59_tpik",
    "weapon_hg_legacy_grenade_shg", "weapon_claymore",
    "weapon_traitor_ied", "weapon_hg_slam",
}
for _, c in ipairs(nades) do ZSCAV.ItemSizes[c] = { w = 1, h = 1 } end

-- Default category-based guesses for anything not in the table above.
local CATEGORY_DEFAULTS = {
    ["Pistol"]      = { w = 1, h = 2 },
    ["Pistols"]     = { w = 1, h = 2 },
    ["Sidearm"]     = { w = 1, h = 2 },
    ["SMG"]         = { w = 2, h = 2 },
    ["Shotgun"]     = { w = 2, h = 3 },
    ["Rifle"]       = { w = 2, h = 3 },
    ["Assault"]     = { w = 2, h = 3 },
    ["DMR"]         = { w = 3, h = 4 },
    ["Sniper"]      = { w = 3, h = 5 },
    ["LMG"]         = { w = 3, h = 4 },
    ["Launcher"]    = { w = 3, h = 5 },
    ["Melee"]       = { w = 1, h = 2 },
    ["Grenade"]     = { w = 1, h = 1 },
    ["Throwable"]   = { w = 1, h = 1 },
}

-- Compute a fallback size for any class. Honours weapon.Category, then
-- name heuristics. Returns a fresh table.
function ZSCAV:GuessItemSize(class)
    if istable(class) then
        class = class.actual_class or class.class
    elseif IsValid(class) then
        class = class:GetClass()
    end
    class = tostring(class or ""):lower()
    if self.GetCanonicalItemClass then
        local canonical = tostring(self:GetCanonicalItemClass(class) or ""):lower()
        if canonical ~= "" then
            class = canonical
        end
    elseif self.GetWeaponBaseClass then
        local canonical = tostring(self:GetWeaponBaseClass(class) or ""):lower()
        if canonical ~= "" then
            class = canonical
        end
    end
    if class == "" then return { w = 1, h = 1 } end

    local wep = weapons.Get(class)
    if wep and wep.Category and CATEGORY_DEFAULTS[wep.Category] then
        local s = CATEGORY_DEFAULTS[wep.Category]
        return { w = s.w, h = s.h }
    end

    local cat = wep and tostring(wep.Category or ""):lower() or ""
    local hold = wep and tostring(wep.HoldType or ""):lower() or ""
    if cat:find("smg") or cat:find("submachine") or cat:find("compact") or cat:find("pdw")
        or hold == "smg"
        or class:find("smg") or class:find("mp5") or class:find("mp7")
        or class:find("p90") or class:find("uzi") or class:find("vector") then
        return { w = 2, h = 2 }
    end

    -- Map by inferred slot when category is missing or unknown.
    if ZSCAV.GetEquipWeaponSlot then
        local slot = ZSCAV:GetEquipWeaponSlot(class)
        if slot == "sidearm" then return { w = 1, h = 2 } end
        if slot == "scabbard" then return { w = 1, h = 2 } end
        if slot == "grenade" then return { w = 1, h = 1 } end
        if slot == "medical" then return { w = 1, h = 1 } end
        if slot == "primary"   then return { w = 2, h = 3 } end
    end

    if class:find("ammo")    then return { w = 1, h = 1 } end
    if class:find("grenade") then return { w = 1, h = 1 } end
    if class:find("nade")    then return { w = 1, h = 1 } end
    if class:find("med")     then return { w = 1, h = 1 } end
    if class:find("bandage") then return { w = 1, h = 1 } end
    if class:find("pistol")  then return { w = 1, h = 2 } end
    if class:find("revolver")then return { w = 1, h = 2 } end
    if class:find("shotgun") then return { w = 2, h = 3 } end
    if class:find("rifle")   then return { w = 2, h = 3 } end
    if class:find("sniper")  then return { w = 3, h = 5 } end
    if class:find("knife")   or class:find("axe") or class:find("bat") then
        return { w = 1, h = 2 }
    end

    return { w = 1, h = 2 }
end

-- Public size accessor. Always returns {w,h} (never nil).
function ZSCAV:GetItemSize(class)
    local lookupClass = class
    if istable(lookupClass) then
        lookupClass = lookupClass.actual_class or lookupClass.class
    elseif IsValid(lookupClass) then
        lookupClass = lookupClass:GetClass()
    end

    lookupClass = tostring(lookupClass or ""):lower()
    if self.GetCanonicalItemClass then
        local canonical = tostring(self:GetCanonicalItemClass(lookupClass) or ""):lower()
        if canonical ~= "" then
            lookupClass = canonical
        end
    elseif self.GetWeaponBaseClass then
        local canonical = tostring(self:GetWeaponBaseClass(lookupClass) or ""):lower()
        if canonical ~= "" then
            lookupClass = canonical
        end
    end

    local s = ZSCAV.ItemSizes[lookupClass]
    if s then return { w = s.w, h = s.h } end
    return self:GuessItemSize(class)
end

-- Tiny helper for "is the active round ZScav" used everywhere else.
function ZSCAV:IsActive()
    local modeName = tostring(self.MODE_NAME or "zscav")
    if zb and (zb.CROUND == modeName or zb.CROUND_MAIN == modeName) then
        return true
    end

    if isfunction(CurrentRound) then
        local round = CurrentRound()
        if istable(round) and tostring(round.name or "") == modeName then
            return true
        end
    end

    return false
end

local PLAYER = FindMetaTable("Player")
if PLAYER and not PLAYER.ZSCAV_OriginalIsSprinting then
    PLAYER.ZSCAV_OriginalIsSprinting = PLAYER.IsSprinting

    function PLAYER:IsSprinting()
        local original = PLAYER.ZSCAV_OriginalIsSprinting
        if not (ZSCAV and ZSCAV.IsActive and ZSCAV:IsActive()) then
            return original and original(self) or false
        end

        if not (IsValid(self) and self:IsPlayer() and self:Alive()) then
            return false
        end

        if not self.zscav_disable_stamina_move_debuff then
            return original and original(self) or false
        end

        if IsValid(self.FakeRagdoll) or self:Crouching() then
            return false
        end

        if self.zscav_weight_block_sprint or self.zscav_weight_stamina_sprint_blocked then
            return false
        end

        local currentSpeed = math.max(tonumber(self.CurrentSpeed) or self:GetVelocity():Length2D(), 0)
        local walkSpeed = math.max(tonumber(self:GetWalkSpeed()) or 1, 1)
        local sprintThreshold = math.max(walkSpeed * 1.08, 140)

        return self:KeyDown(IN_SPEED)
            and self:KeyDown(IN_FORWARD)
            and currentSpeed > sprintThreshold
    end
end
