-- sh_zrp.lua — ZRP (persistent survival/roleplay) mode — shared definitions.
-- Loaded on both server and client by the mode loader.

local MODE = MODE

-- ── MODE header ───────────────────────────────────────────────────────────────

MODE.name       = "zrp"
MODE.PrintName  = "ZRP"
MODE.Chance     = 0       -- staff-launched only; never random-selected
MODE.LootSpawn  = false   -- ZRP has its own container loot system
MODE.GuiltDisabled = false
MODE.randomSpawns  = false
MODE.ForBigMaps    = true
MODE.OverrideSpawn = true  -- prevent GM:PlayerSpawn from auto-balancing teams on respawn

-- ── ZRP namespace ─────────────────────────────────────────────────────────────

ZRP = ZRP or {}
ZRP.WorldContainerData  = ZRP.WorldContainerData  or {}  -- persisted adopted world props
ZRP.WorldContainerState = ZRP.WorldContainerState or {}  -- runtime state per adopted prop

-- ── SAFE_SPAWN point group ────────────────────────────────────────────────────
-- Place SAFE_SPAWN points on a map with the Point Editor tool.
-- ZRP respawns at a randomly chosen SAFE_SPAWN after player death.

zb = zb or {}
zb.Points = zb.Points or {}

zb.Points.SAFE_SPAWN = zb.Points.SAFE_SPAWN or {}
zb.Points.SAFE_SPAWN.Color = Color(50, 200, 80)
zb.Points.SAFE_SPAWN.Name  = "SAFE_SPAWN"

-- ── Net strings ───────────────────────────────────────────────────────────────

if SERVER then
    util.AddNetworkString("ZRP_Start")
    util.AddNetworkString("ZRP_End")
    util.AddNetworkString("ZRP_RespawnTimer")   -- float: when the player respawns
    util.AddNetworkString("ZRP_LootSync")       -- full loot table to staff
    util.AddNetworkString("ZRP_LootAdd")        -- client → server: add item
    util.AddNetworkString("ZRP_LootRemove")     -- client → server: remove item by index
    util.AddNetworkString("ZRP_LootSetWeight")  -- client → server: change item weight
    util.AddNetworkString("ZRP_LootSetBlacklist") -- client → server: toggle blacklist
    util.AddNetworkString("ZRP_LootSetWhitelist") -- client → server: toggle whitelist
    util.AddNetworkString("ZRP_ContainerSync")    -- full container list to staff
    util.AddNetworkString("ZRP_ContainerSetActive") -- client → server: enable/disable container by id
    util.AddNetworkString("ZRP_ContainerActivate")  -- client → server: force activate/reset container by id
    util.AddNetworkString("ZRP_ContainerRequestSync") -- client → server: refresh container/world lists
    util.AddNetworkString("ZRP_WorldPropSync")    -- scanned world props + adopted list to staff
    util.AddNetworkString("ZRP_OpenEditor")       -- server tells client to open the editor panel
    -- Custom PlayerClass builder
    util.AddNetworkString("ZRP_ClassListSync")    -- server → client: list of custom + built-in classes
    util.AddNetworkString("ZRP_ClassSave")        -- client → server: save (create or update) a custom class
    util.AddNetworkString("ZRP_ClassDelete")      -- client → server: delete a custom class by name
    util.AddNetworkString("ZRP_ClassTestOnSelf")  -- client → server: apply a class to the requesting admin
    util.AddNetworkString("ZRP_OpenClassBuilder") -- server tells client to open the class builder panel
end

if CLIENT then
    hook.Add("SpawnMenuOpen", "SpawnMenuWhitelist", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return end
        if ply:IsAdmin() then return end

        if zb and zb.CROUND == "zrp" and ply:GetNWBool("ZRP_BuildAccess", false) then
            return
        end

        return false
    end)
end
