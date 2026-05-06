-- ZScav server: per-player grid inventory, pickup intercept, net actions.
--
-- Active only when ZScav is the round (ZSCAV:IsActive()). Outside ZScav
-- this file is inert so other modes keep their default behaviour.

include("sv_zscav_bootstrap.lua")
include("sv_zscav_core_helpers.lua")
include("sv_zscav_bags.lua")
include("sv_zscav_interaction_helpers.lua")
include("sv_zscav_layout_helpers.lua")
include("sv_zscav_inventory_helpers.lua")
include("sv_zscav_gear_helpers.lua")
include("sv_zscav_slot_container_helpers.lua")
include("sv_zscav_stash.lua")
include("sv_zscav_mailbox.lua")
include("sv_zscav_config.lua")
include("sv_zscav_raid.lua")
include("sv_zscav_weight.lua")

local ZScavServerHelpers = ZSCAV.ServerHelpers or {}
local NewInventory = ZScavServerHelpers.NewInventory
local SECURE_DEFAULT_CLASS = ZScavServerHelpers.SECURE_DEFAULT_CLASS
local IsSecureClass = ZScavServerHelpers.IsSecureClass
local GetPlayerSecureState = ZScavServerHelpers.GetPlayerSecureState
local SavePlayerSecureState = ZScavServerHelpers.SavePlayerSecureState
local EnsureSecureContainerForInventory = ZScavServerHelpers.EnsureSecureContainerForInventory
local MigrateLegacyGrids = ZScavServerHelpers.MigrateLegacyGrids
local SyncInventory = ZScavServerHelpers.SyncInventory
local FlushSecurePersistence = ZScavServerHelpers.FlushSecurePersistence
local Notice = ZScavServerHelpers.Notice
local getGridLayoutBlocks = ZScavServerHelpers.getGridLayoutBlocks
local getContainerLayoutBlocks = ZScavServerHelpers.getContainerLayoutBlocks
local fitsAt = ZScavServerHelpers.fitsAt
local findFreeSpot = ZScavServerHelpers.findFreeSpot
local findFreeSpotAR = ZScavServerHelpers.findFreeSpotAR
local GetPlayerGridInsertBlockReason = ZScavServerHelpers.GetPlayerGridInsertBlockReason
local CanStoreItemInPlayerGrid = ZScavServerHelpers.CanStoreItemInPlayerGrid
local routeOrder = ZScavServerHelpers.routeOrder
local FilterToFitGrid = ZScavServerHelpers.FilterToFitGrid
local PackIntoGrid = ZScavServerHelpers.PackIntoGrid
local ResolveWeaponEquipSlot = ZScavServerHelpers.ResolveWeaponEquipSlot
local SpawnDroppedClass = ZScavServerHelpers.SpawnDroppedClass
local SerializeWornBackpack = ZScavServerHelpers.SerializeWornBackpack
local VestEquip = ZScavServerHelpers.VestEquip
local VestUnequip = ZScavServerHelpers.VestUnequip
local BackpackEquip = ZScavServerHelpers.BackpackEquip
local BackpackUnequip = ZScavServerHelpers.BackpackUnequip
local ResolveContainerPlacement = ZScavServerHelpers.ResolveContainerPlacement
local BagContainsUIDRecursive = ZScavServerHelpers.BagContainsUIDRecursive
local GetEquippedContainerForSlot = ZScavServerHelpers.GetEquippedContainerForSlot
local CopyItemEntry = ZScavServerHelpers.CopyItemEntry
local EnsureWeaponEntryRuntime = ZScavServerHelpers.EnsureWeaponEntryRuntime
local GiveWeaponInstance = ZScavServerHelpers.GiveWeaponInstance
local SelectWeaponEntry = ZScavServerHelpers.SelectWeaponEntry
local StripWeaponEntry = ZScavServerHelpers.StripWeaponEntry
local GetWeaponBaseClass = ZScavServerHelpers.GetWeaponBaseClass
local MAILBOX_CLASS = ZScavServerHelpers.MAILBOX_CLASS or "zscav_mailbox_container"
local GetCanonicalPlayerMailboxUID = ZScavServerHelpers.GetCanonicalPlayerMailboxUID
local IsPlayerMailboxUID = ZScavServerHelpers.IsPlayerMailboxUID
local MarkPlayerMailboxRead = ZScavServerHelpers.MarkPlayerMailboxRead
local CanAccessMailbox = ZScavServerHelpers.CanAccessMailbox
local DeliverToPlayerMailbox = ZScavServerHelpers.DeliverToPlayerMailbox
local SyncMailboxUnread = ZScavServerHelpers.SyncMailboxUnread
local VENDOR_TICKET_CLASS = "zscav_vendor_ticket"

local function GetServerHelper(name)
    local helpers = ZSCAV and ZSCAV.ServerHelpers or nil
    local helper = helpers and helpers[name] or nil
    if isfunction(helper) then
        return helper
    end
    return nil
end

local function StartPendingBagOpen(...)
    local helper = GetServerHelper("StartPendingBagOpen")
    if not helper then return end
    return helper(...)
end

local function HandleUnconfiguredPickup(...)
    local helper = GetServerHelper("HandleUnconfiguredPickup")
    if not helper then return false end
    return helper(...)
end

local function StashOrDrop(...)
    local helper = GetServerHelper("StashOrDrop")
    if not helper then return false end
    return helper(...)
end

local function SlotEntryForDrag(...)
    local helper = GetServerHelper("SlotEntryForDrag")
    if not helper then return nil end
    return helper(...)
end

local function RemoveFromSlotForDrag(...)
    local helper = GetServerHelper("RemoveFromSlotForDrag")
    if not helper then return false end
    return helper(...)
end

local function PlaceSlotEntryIntoGrid(...)
    local helper = GetServerHelper("PlaceSlotEntryIntoGrid")
    if not helper then return false end
    return helper(...)
end

local function PlaceSlotEntryIntoContainer(...)
    local helper = GetServerHelper("PlaceSlotEntryIntoContainer")
    if not helper then return false end
    return helper(...)
end

local function IsVendorTicketEntry(entry)
    return istable(entry) and tostring(entry.class or "") == VENDOR_TICKET_CLASS
end


function ZSCAV:ClearInventory(ply)
    if not IsValid(ply) then return end
    ply.zscav_inv = NewInventory()
    EnsureSecureContainerForInventory(ply, ply.zscav_inv)
    SyncInventory(ply)
end

local function GetZScavSafeSpawnPoints()
    local pts = zb.GetMapPoints("ZSCAV_SAFESPAWN") or {}
    if #pts > 0 then return pts end

    pts = zb.GetMapPoints("SAFE_SPAWN") or {}
    if #pts > 0 then return pts end

    return zb.GetMapPoints("Spawnpoint") or {}
end

local function GetZScavSafeBackPoints()
    local pts = zb.GetMapPoints("ZSCAV_SAFEBACK") or {}
    if #pts > 0 then return pts end

    return GetZScavSafeSpawnPoints()
end

function ZSCAV:GetRandomSafeSpawnPoint()
    local pts = GetZScavSafeSpawnPoints()
    if #pts == 0 then return nil end
    return pts[math.random(#pts)]
end

function ZSCAV:GetRandomSafeBackPoint()
    local pts = GetZScavSafeBackPoints()
    if #pts == 0 then return nil end
    return pts[math.random(#pts)]
end

function ZSCAV:QueueSafeSpawn(ply, point)
    if not IsValid(ply) then return false end

    point = point or self:GetRandomSafeSpawnPoint()
    if not istable(point) or not isvector(point.pos) then return false end

    ply.zscav_pending_spawn_pos = point.pos
    ply.zscav_pending_spawn_ang = point.ang or Angle(0, tonumber(point.yaw) or 0, 0)
    return true
end

local function ApplyQueuedZScavSpawn(ply)
    if not IsValid(ply) then return end

    local pos = ply.zscav_pending_spawn_pos
    if not isvector(pos) then return end

    local ang = ply.zscav_pending_spawn_ang
    ply.zscav_pending_spawn_pos = nil
    ply.zscav_pending_spawn_ang = nil

    timer.Simple(0, function()
        if not (IsValid(ply) and ply:Alive() and ZSCAV:IsActive()) then return end
        ply:SetPos(pos)
        if isangle(ang) then
            ply:SetAngles(ang)
            ply:SetEyeAngles(Angle(0, ang.y, 0))
        end
        ply:SetVelocity(-ply:GetVelocity())
    end)
end

function ZSCAV:SendPlayerToSafeZone(ply, point)
    if not IsValid(ply) then return false, "invalid_player" end
    if not self:QueueSafeSpawn(ply, point) then return false, "missing_safe_spawn" end

    if ply:Team() == TEAM_SPECTATOR and ply.SetupTeam then
        ply:SetupTeam(0)
    end

    ply:UnSpectate()
    ply:SetMoveType(MOVETYPE_WALK)

    if ply:Alive() then
        ApplyQueuedZScavSpawn(ply)
        return true, "teleported"
    end

    ply:Spawn()
    return true, "spawned"
end

function ZSCAV:ShouldBypassInventoryPickup(wep)
    if not IsValid(wep) then return true end

    local class = GetWeaponBaseClass(wep)
    if class == "weapon_hands_sh" or class == "weapon_zombclaws" then return true end
    if class == "hg_sling" or class == "hg_brassknuckles" or class == "hg_flashlight" then return true end
    if class == "gmod_tool" or class == "weapon_physcannon" or class == "weapon_physgun" then return true end

    -- Time-bound suppression. Set to CurTime() + N seconds when we want
    -- the engine to skip our pickup intercept for a brief window (e.g.
    -- right after a drop, so the dropper doesn't immediately re-acquire
    -- it before they walk away). After the window passes the weapon goes
    -- back to flowing through the inventory system like any other.
    if (wep.zscav_ignore_until or 0) > CurTime() then return true end

    -- Legacy boolean flag kept for compat with code paths that expect
    -- permanent suppression (worn pack ragdolls, etc). Plain weapons
    -- should NEVER use this -- use zscav_ignore_until instead.
    if wep.zscav_permanent_bypass then return true end

    return false
end

function ZSCAV:RemoveArmorNoDrop(ply, equipment)
    if not IsValid(ply) then return false end

    equipment = tostring(equipment or ""):lower()
    equipment = string.Replace(equipment, "ent_armor_", "")
    local placement = hg and hg.GetArmorPlacement and hg.GetArmorPlacement(equipment) or nil
    if not placement then return false end

    ply.armors = ply.armors or ply:GetNetVar("Armor", {}) or {}
    if ply.armors[placement] ~= equipment then
        return false
    end

    local armorTbl = hg and hg.armor and hg.armor[placement] and hg.armor[placement][equipment] or nil
    if armorTbl and armorTbl.voice_change and eightbit and eightbit.EnableEffect and ply.UserID then
        eightbit.EnableEffect(ply:UserID(), ply.PlayerClassName == "furry" and eightbit.EFF_PROOT or 0)
    end

    if placement == "face" and ply:GetNetVar("zableval_masku", false) then
        ply:SetNetVar("zableval_masku", false)
    end

    ply.armors[placement] = nil
    if ply.SyncArmor then ply:SyncArmor() end
    return true
end

hook.Add("PlayerSpawnedSWEP", "ZSCAV_MarkSpawnedSWEP", function(_ply, wep)
    if not IsValid(wep) then return end
    -- Spawnmenu/admin spawn: brief grace so the spawner can pick it up
    -- immediately without the inventory intercept stealing it. After the
    -- grace expires anyone (including the spawner) goes through the
    -- inventory system normally.
    wep.zscav_ignore_until = CurTime() + 1.5
end)

local function PlayerHasAnyRagdoll(ply)
    if not IsValid(ply) then return false end
    if IsValid(ply.FakeRagdoll) then return true end
    if IsValid(ply:GetNWEntity("FakeRagdoll")) then return true end
    if IsValid(ply:GetNWEntity("FakeRagdollOld")) then return true end
    if IsValid(ply:GetNWEntity("RagdollDeath")) then return true end
    local rg = ply.GetRagdollEntity and ply:GetRagdollEntity() or nil
    if IsValid(rg) then return true end
    return false
end

local GRENADE_CLASS_SET = {
    ["weapon_hg_molotov_tpik"] = true,
    ["weapon_hg_pipebomb_tpik"] = true,
    ["weapon_hg_f1_tpik"] = true,
    ["weapon_hg_grenade_tpik"] = true,
    ["weapon_hg_flashbang_tpik"] = true,
    ["weapon_hg_hl2nade_tpik"] = true,
    ["weapon_hg_m18_tpik"] = true,
    ["weapon_hg_mk2_tpik"] = true,
    ["weapon_hg_smokenade_tpik"] = true,
    ["weapon_hg_rgd_tpik"] = true,
    ["weapon_hg_type59_tpik"] = true,
    ["weapon_hg_legacy_grenade_shg"] = true,
    ["weapon_claymore"] = true,
    ["weapon_traitor_ied"] = true,
    ["weapon_hg_slam"] = true,
}

function ZSCAV:IsGrenadeClass(class)
    class = tostring(class or ""):lower()
    if class == "" then return false end
    if GRENADE_CLASS_SET[class] then return true end
    if class:find("flashbang", 1, true) then return true end
    if class:find("grenade", 1, true) then return true end
    if class:find("nade", 1, true) then return true end
    if class:find("molotov", 1, true) then return true end
    if class:find("pipebomb", 1, true) then return true end
    if class:find("claymore", 1, true) then return true end
    if class:find("ied", 1, true) then return true end
    return false
end

local function ResolveGiveableGrenadeWeaponClass(class)
    class = tostring(class or ""):lower()
    if class == "" then return nil end

    if ZSCAV:IsGrenadeClass(class) and weapons.GetStored(class) then
        return class
    end

    if not scripted_ents.GetStored(class) then
        return nil
    end

    for weaponClass in pairs(GRENADE_CLASS_SET) do
        local stored = weapons.GetStored(weaponClass)
        local entClass = tostring(stored and stored.ENT or ""):lower()
        if entClass == class then
            return weaponClass
        end
    end

    return nil
end

function ZSCAV:ResolveGrenadeInventoryClass(entry)
    if not istable(entry) then return nil end

    local candidates = {}
    local seen = {}

    local function push(class)
        class = tostring(class or ""):lower()
        if class == "" or seen[class] then return end
        seen[class] = true
        candidates[#candidates + 1] = class
    end

    push(entry.class)
    push(entry.actual_class)

    if self.GetCanonicalItemClass then
        push(self:GetCanonicalItemClass(entry))
        push(self:GetCanonicalItemClass(entry.class))
        push(self:GetCanonicalItemClass(entry.actual_class))
    end

    if self.GetWeaponBaseClass then
        push(self:GetWeaponBaseClass(entry.class))
        push(self:GetWeaponBaseClass(entry.actual_class))
    end

    for _, class in ipairs(candidates) do
        local weaponClass = ResolveGiveableGrenadeWeaponClass(class)
        if weaponClass then
            return weaponClass
        end
    end

    return nil
end

local function PlayerHasGrenadeClass(ply, class)
    class = tostring(class or ""):lower()
    if class == "" or not IsValid(ply) then return false end
    if ply:HasWeapon(class) then return true end

    for _, wep in ipairs(ply:GetWeapons()) do
        if not IsValid(wep) then continue end

        local actualClass = tostring(wep:GetClass() or ""):lower()
        if actualClass == class then
            return true
        end

        local baseClass = tostring(GetWeaponBaseClass(wep) or ""):lower()
        if baseClass == class then
            return true
        end
    end

    return false
end

local PlayerHasBackedGrenadeInventoryClass

local function ForceGiveGrenadeHotbarWeapon(ply, class)
    class = tostring(class or ""):lower()
    if class == "" or not IsValid(ply) then return false end
    if not weapons.GetStored(class) then return false end

    local weapon = ents.Create(class)
    if not IsValid(weapon) then return false end

    weapon:SetPos(ply:GetPos())
    weapon:SetAngles(ply:GetAngles())
    weapon:Spawn()
    weapon:Activate()

    if not (IsValid(weapon) and weapon:IsWeapon()) then
        if IsValid(weapon) then weapon:Remove() end
        return false
    end

    ply:PickupWeapon(weapon, false)

    timer.Simple(0, function()
        if IsValid(weapon) and weapon:GetOwner() ~= ply then
            weapon:Remove()
        end
    end)

    return PlayerHasGrenadeClass(ply, class)
end

function ZSCAV:GetInventoryGrenadeClasses(inv)
    local out = {}
    if not istable(inv) then return out end
    for _, gname in ipairs({ "pocket", "vest" }) do
        for _, it in ipairs(inv[gname] or {}) do
            local cls = self:ResolveGrenadeInventoryClass(it)
            if self:IsGrenadeClass(cls) then
                out[cls] = true
            end
        end
    end
    return out
end

function ZSCAV:ConsumeGrenadeFromInventory(ply, class)
    if not IsValid(ply) then return false end
    local inv = self:GetInventory(ply)
    if not inv then return false end
    class = tostring(class or ""):lower()
    if class == "" then return false end

    for _, gname in ipairs({ "pocket", "vest" }) do
        local list = inv[gname] or {}
        for i, it in ipairs(list) do
            if tostring(self:ResolveGrenadeInventoryClass(it) or "") == class then
                table.remove(list, i)
                return true
            end
        end
    end
    return false
end

function ZSCAV:SyncGrenadeHotbar(ply)
    if not IsValid(ply) or not self:IsActive() then return end
    if not ply:Alive() then return end

    local inv = self:GetInventory(ply)
    if not inv then return end
    local desired = self:GetInventoryGrenadeClasses(inv)

    -- `ply:Give` bypasses PlayerCanPickupWeapon, so a one-shot pickup
    -- allow flag would survive and accidentally authorize the next real
    -- world pickup of the same grenade class.
    if self:IsGrenadeClass(ply.zscav_allow_pickup_once) and desired[tostring(ply.zscav_allow_pickup_once or ""):lower()] then
        ply.zscav_allow_pickup_once = nil
    end

    ply.zscav_grenade_skip_until = ply.zscav_grenade_skip_until or {}
    ply.zscav_grenade_hotbar_grant_until = ply.zscav_grenade_hotbar_grant_until or {}
    local skip = ply.zscav_grenade_skip_until
    local grantUntil = ply.zscav_grenade_hotbar_grant_until

    -- Strip grenade weapons that no longer have a backing inventory item.
    for _, w in ipairs(ply:GetWeapons()) do
        if not IsValid(w) then continue end
        local cls = tostring(GetWeaponBaseClass(w) or ""):lower()
        if self:IsGrenadeClass(cls) and not desired[cls] then
            skip[cls] = CurTime() + 0.5
            ply:StripWeapon(cls)
        end
    end

    -- Ensure every grenade item present in pocket/rig appears in hotbar.
    for cls in pairs(desired) do
        local hasClass = PlayerHasGrenadeClass(ply, cls)
        if hasClass then
            grantUntil[cls] = nil
        elseif weapons.GetStored(cls) and (tonumber(grantUntil[cls]) or 0) <= CurTime() then
            local grenadeClass = cls
            local tokenUntil = CurTime() + 1
            grantUntil[grenadeClass] = tokenUntil
            ply:Give(cls)

            timer.Simple(0, function()
                if not (IsValid(ply) and ZSCAV:IsActive() and ply:Alive()) then return end
                if not PlayerHasBackedGrenadeInventoryClass or not PlayerHasBackedGrenadeInventoryClass(ply, grenadeClass) then
                    if ply.zscav_grenade_hotbar_grant_until then
                        ply.zscav_grenade_hotbar_grant_until[grenadeClass] = nil
                    end
                    return
                end
                if PlayerHasGrenadeClass(ply, grenadeClass) then
                    if ply.zscav_grenade_hotbar_grant_until
                        and ply.zscav_grenade_hotbar_grant_until[grenadeClass] == tokenUntil then
                        ply.zscav_grenade_hotbar_grant_until[grenadeClass] = nil
                    end
                    return
                end
                if ForceGiveGrenadeHotbarWeapon(ply, grenadeClass)
                    and ply.zscav_grenade_hotbar_grant_until
                    and ply.zscav_grenade_hotbar_grant_until[grenadeClass] == tokenUntil then
                    ply.zscav_grenade_hotbar_grant_until[grenadeClass] = nil
                end
            end)
        end
    end
end

local function FindBackedWeaponSlotEntry(ply, wep)
    if not (IsValid(ply) and IsValid(wep)) then return nil, nil end

    local weaponUID = tostring(wep.zscav_weapon_uid or "")
    if weaponUID == "" then return nil, nil end

    local inv = ZSCAV:GetInventory(ply)
    if not (inv and inv.weapons) then return nil, inv end

    for slot, entry in pairs(inv.weapons) do
        if entry and tostring(entry.weapon_uid or "") == weaponUID then
            return entry, inv
        end
    end

    return nil, inv
end

PlayerHasBackedGrenadeInventoryClass = function(ply, class)
    class = tostring(class or ""):lower()
    if class == "" or not IsValid(ply) then return false end

    local inv = ZSCAV:GetInventory(ply)
    if not istable(inv) then return false end

    for _, gridName in ipairs({ "pocket", "vest" }) do
        for _, entry in ipairs(inv[gridName] or {}) do
            if tostring(ZSCAV:ResolveGrenadeInventoryClass(entry) or "") == class then
                return true
            end
        end
    end

    return false
end

local function ConsumePendingGrenadeHotbarGrant(ply, class)
    class = tostring(class or ""):lower()
    if class == "" or not IsValid(ply) then return false end

    local grants = ply.zscav_grenade_hotbar_grant_until
    local expiresAt = istable(grants) and tonumber(grants[class]) or 0
    if expiresAt <= CurTime() then
        if istable(grants) then
            grants[class] = nil
        end
        return false
    end

    if not PlayerHasBackedGrenadeInventoryClass(ply, class) then
        return false
    end

    grants[class] = nil
    return true
end

local function BuildUnauthorizedPickupRestoreEntry(ply, wep)
    local entry = istable(wep.zscav_world_entry) and CopyItemEntry(wep.zscav_world_entry) or nil
    if not entry then
        local class = GetWeaponBaseClass(wep)
        entry = CopyItemEntry({ class = class }) or { class = class }
    end

    EnsureWeaponEntryRuntime(entry, wep)
    entry.weapon_state = ZSCAV:CaptureWeaponState(ply, wep, entry)
    return entry
end

local function UndoUnauthorizedWorldWeaponEquip(ply, wep)
    if not (IsValid(ply) and IsValid(wep) and wep:IsWeapon()) then return end
    if wep.zscav_undoing_world_pickup then return end

    local restoreEntry = BuildUnauthorizedPickupRestoreEntry(ply, wep)
    local restorePos = wep:GetPos()
    local restoreAng = wep:GetAngles()
    local actualClass = tostring(wep:GetClass() or "")

    wep.zscav_pickup_claimed = true
    wep.zscav_undoing_world_pickup = true

    timer.Simple(0, function()
        if IsValid(ply) and actualClass ~= "" and ply:HasWeapon(actualClass) then
            ply:StripWeapon(actualClass)
        end

        local respawned = IsValid(ply) and SpawnDroppedClass(ply, restoreEntry.class, restoreEntry.uid, restoreEntry) or NULL
        if IsValid(respawned) then
            respawned:SetPos(restorePos)
            respawned:SetAngles(restoreAng)
            respawned.zscav_ignore_until = CurTime() + 0.35

            local phys = respawned.GetPhysicsObject and respawned:GetPhysicsObject() or nil
            if IsValid(phys) then
                phys:SetVelocity(vector_origin)
                phys:Wake()
            end
        end

        if IsValid(ply) then
            Notice(ply, "Direct world weapon pickup blocked. Use the ZScav pickup prompt.")
            ZSCAV:ReconcileWeapons(ply)
            ZSCAV:ReconcileArmor(ply)
        end
    end)
end

function ZSCAV:ProcessGrenadeThrowConsumption(ply)
    if not IsValid(ply) or not self:IsActive() then return end

    local inv = self:GetInventory(ply)
    if not inv then return end

    ply.zscav_grenade_prev_has = ply.zscav_grenade_prev_has or {}
    ply.zscav_grenade_skip_until = ply.zscav_grenade_skip_until or {}
    local prev = ply.zscav_grenade_prev_has
    local skip = ply.zscav_grenade_skip_until

    local watch = {}
    for cls in pairs(prev) do watch[cls] = true end
    for cls in pairs(self:GetInventoryGrenadeClasses(inv)) do watch[cls] = true end

    local consumed = false
    local now = CurTime()

    for cls in pairs(watch) do
        local had = prev[cls] == true
        local has = ply:HasWeapon(cls)

        if had and not has and ply:Alive() and (skip[cls] or 0) <= now then
            if self:ConsumeGrenadeFromInventory(ply, cls) then
                consumed = true
            end
        end

        if has then
            prev[cls] = true
        else
            prev[cls] = nil
        end

        if (skip[cls] or 0) <= now then
            skip[cls] = nil
        end
    end

    if consumed then
        SyncInventory(ply)
    end

    self:SyncGrenadeHotbar(ply)
end

local WORLD_PICKUP_PROMPT_RADIUS_SQR = 120 * 120
local WORLD_WEAPON_PICKUP_COOLDOWN = 0.2
local WORLD_WEAPON_USE_INTENT_WINDOW = 0.35

local function MarkRecentWorldWeaponUseIntent(ply, wep)
    if not (IsValid(ply) and IsValid(wep)) then return end

    ply.zscav_recent_world_weapon_use = {
        weapon = wep,
        ent_index = wep:EntIndex(),
        expires_at = CurTime() + WORLD_WEAPON_USE_INTENT_WINDOW,
    }
end

local function HasRecentWorldWeaponUseIntent(ply, wep)
    if not (IsValid(ply) and IsValid(wep)) then return false end

    local recent = istable(ply.zscav_recent_world_weapon_use) and ply.zscav_recent_world_weapon_use or nil
    if not recent then return false end

    if (tonumber(recent.expires_at) or 0) <= CurTime() then
        ply.zscav_recent_world_weapon_use = nil
        return false
    end

    return recent.weapon == wep or tonumber(recent.ent_index) == wep:EntIndex()
end

local function TryBeginWorldWeaponPickup(ply, wep)
    if not IsValid(ply) then return false end
    if IsValid(ply.zscav_world_weapon_pickup_lock) then return false end
    if (ply.zscav_world_weapon_pickup_next_at or 0) > CurTime() then return false end

    ply.zscav_world_weapon_pickup_lock = wep
    return true
end

local function FinishWorldWeaponPickup(ply, wep, succeeded)
    if not IsValid(ply) then return end
    if ply.zscav_world_weapon_pickup_lock == wep then
        ply.zscav_world_weapon_pickup_lock = nil
    end

    if succeeded then
        ply.zscav_world_weapon_pickup_next_at = CurTime() + WORLD_WEAPON_PICKUP_COOLDOWN
    end
end

local function CanUseWorldPickupEntity(ply, ent)
    if not (IsValid(ply) and IsValid(ent)) then return false end
    return ent:GetPos():DistToSqr(ply:GetPos()) <= WORLD_PICKUP_PROMPT_RADIUS_SQR
end

local function SendWorldPickupPrompt(ply, ent, class, canEquip)
    if not CanUseWorldPickupEntity(ply, ent) then return false end

    local entIndex = math.max(ent:EntIndex(), 0)
    if ply:KeyDown(IN_USE) and ply.zscav_world_pickup_prompt_hold_entindex == entIndex then
        return true
    end

    ply.zscav_world_pickup_prompt_until = ply.zscav_world_pickup_prompt_until or {}
    local key = tostring(entIndex)
    if (ply.zscav_world_pickup_prompt_until[key] or 0) > CurTime() then
        return true
    end

    ply.zscav_world_pickup_prompt_until[key] = CurTime() + 0.2
    if ply:KeyDown(IN_USE) then
        ply.zscav_world_pickup_prompt_hold_entindex = entIndex
    end

    net.Start("ZScavWorldPickupPrompt")
        net.WriteUInt(entIndex, 16)
        net.WriteString(tostring(class or ent:GetClass() or ""))
        net.WriteBool(canEquip == true)
    net.Send(ply)

    return true
end

hook.Add("KeyRelease", "ZSCAV_WorldPickupPromptRelease", function(ply, key)
    if key ~= IN_USE or not IsValid(ply) then return end
    ply.zscav_world_pickup_prompt_hold_entindex = nil
end)

local function CanWorldWeaponOfferEquipPrompt(class)
    return tostring(ZSCAV:GetEquipWeaponSlot(class) or "") ~= "medical"
end

local function IsWorldEquippableGearClass(class)
    local def = ZSCAV:GetGearDef(class)
    local slot = tostring(def and def.slot or "")
    if slot == "" or slot == "world_container" then
        return false
    end

    return true
end

local function FinalizeWorldWeaponPickup(ply, wep)
    wep.zscav_pickup_claimed = true
    timer.Simple(0, function()
        if IsValid(wep) then wep:Remove() end
    end)
    ply:EmitSound("items/ammo_pickup.wav", 60, 100, 0.6)
end

local function HandleWorldWeaponPickupChoice(ply, wep, mode)
    if not (IsValid(ply) and IsValid(wep) and wep:IsWeapon()) then return false end
    if not CanUseWorldPickupEntity(ply, wep) then return false end
    if wep.zscav_death_drop_suppressed then return false end
    if wep.zscav_pickup_claimed then return false end
    if PlayerHasAnyRagdoll(ply) then return false end
    if ZSCAV:ShouldBypassInventoryPickup(wep) then return false end

    local class = GetWeaponBaseClass(wep)
    if HandleUnconfiguredPickup(ply, class, false) then return false end

    local weaponItem = CopyItemEntry({ class = class }) or { class = class }
    EnsureWeaponEntryRuntime(weaponItem, wep)
    weaponItem.weapon_state = ZSCAV:CaptureWeaponState(nil, wep, weaponItem)

    if not TryBeginWorldWeaponPickup(ply, wep) then return false end
    wep.zscav_pickup_claimed = true

    local function abortPickup()
        if IsValid(wep) then
            wep.zscav_pickup_claimed = nil
        end
        FinishWorldWeaponPickup(ply, wep, false)
        return false
    end

    mode = tostring(mode or "take")
    if mode == "equip" and not ZSCAV:IsGrenadeClass(class) then
        local ok, reason, slot = ZSCAV:TryAutoEquipWeapon(ply, weaponItem)
        if ok then
            FinalizeWorldWeaponPickup(ply, wep)
            FinishWorldWeaponPickup(ply, wep, true)
            Notice(ply, "Equipped to " .. tostring(slot) .. ".")
            return true
        end

        if reason == "slot_occupied" then
            Notice(ply, "Slot " .. tostring(slot or "?"):upper() .. " occupied. Drop or unequip first.")
        elseif reason == "not_weapon" then
            Notice(ply, "Cannot auto-equip: " .. tostring(class))
        elseif reason == "missing_class" then
            Notice(ply, "Server has no class: " .. tostring(class))
        elseif reason == "blocked_give" then
            Notice(ply, "Auto-equip blocked by another addon.")
        end
        return abortPickup()
    end

    local ok, where = ZSCAV:TryAddItemEntry(ply, weaponItem)
    if ok then
        FinalizeWorldWeaponPickup(ply, wep)
        FinishWorldWeaponPickup(ply, wep, true)
        return true
    end

    if where == "weight" then
        Notice(ply, "Too heavy to carry: " .. tostring(class))
    elseif ZSCAV:IsGrenadeClass(class) then
        Notice(ply, "No room for " .. tostring(class) .. " in pockets, rig, or backpack.")
    else
        Notice(ply, "No room for " .. tostring(class) .. ".")
    end

    return abortPickup()
end

local function HandleWorldWeaponUseIntent(ply, wep)
    if not ZSCAV:IsActive() then return end
    if not (IsValid(ply) and IsValid(wep) and wep:IsWeapon()) then return end
    if not CanUseWorldPickupEntity(ply, wep) then return false end
    if wep.zscav_death_drop_suppressed then return false end
    if wep.zscav_pickup_claimed then return false end
    if PlayerHasAnyRagdoll(ply) then return false end
    if ZSCAV:ShouldBypassInventoryPickup(wep) then return false end

    local useFrame = CurTime()
    local entIndex = wep:EntIndex()
    if ply.zscav_world_weapon_use_frame == useFrame and ply.zscav_world_weapon_use_entindex == entIndex then
        return false
    end
    ply.zscav_world_weapon_use_frame = useFrame
    ply.zscav_world_weapon_use_entindex = entIndex

    local class = GetWeaponBaseClass(wep)
    if HandleUnconfiguredPickup(ply, class, false) then
        return false
    end

    MarkRecentWorldWeaponUseIntent(ply, wep)

    if ply:KeyDown(IN_SPEED) then
        local quickPickupMode = (ZSCAV:IsGrenadeClass(class) or not CanWorldWeaponOfferEquipPrompt(class))
            and "take" or "equip"
        HandleWorldWeaponPickupChoice(ply, wep, quickPickupMode)
        return false
    end

    SendWorldPickupPrompt(ply, wep, class, CanWorldWeaponOfferEquipPrompt(class))
    return false
end

local function HandleWorldArmorPickupChoice(ply, ent, mode)
    if not (IsValid(ply) and IsValid(ent)) then return false end
    if not CanUseWorldPickupEntity(ply, ent) then return false end
    if PlayerHasAnyRagdoll(ply) then return false end
    if ent.zscav_pickup_claimed then return false end

    local class = ZSCAV:GetEntPackClass(ent) or ent:GetClass()
    local uid = ZSCAV:GetEntPackUID(ent)
    if not ZSCAV:IsArmorEntityClass(class) then return false end
    if HandleUnconfiguredPickup(ply, class, true) then return false end

    mode = tostring(mode or "take")
    if mode ~= "equip" then
        local ok, where = ZSCAV:TryAddItem(ply, class, uid)
        if ok then
            ent.zscav_pickup_claimed = true
            ent:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(90, 110), 1, CHAN_ITEM)
            timer.Simple(0, function()
                if IsValid(ent) then ent:Remove() end
            end)
            return true
        end

        Notice(ply, "No room for armor: " .. tostring(where or class))
        return false
    end

    local def = ZSCAV:GetGearDef(class)
    local placement = ZSCAV:GetArmorPlacement(class)
    local inv = ZSCAV:GetInventory(ply)
    if not (def and placement and inv) then
        Notice(ply, "Could not equip armor: " .. tostring(class))
        return false
    end

    inv.gear = inv.gear or {}
    ply.armors = ply.armors or {}

    if inv.gear[def.slot] ~= nil or ply.armors[placement] ~= nil then
        Notice(ply, "Slot " .. tostring(def.slot or placement or "armor"):upper() .. " occupied. Drop or unequip first.")
        return false
    end

    if not (hg and hg.AddArmor) then
        Notice(ply, "Could not equip armor: " .. tostring(class))
        return false
    end

    local equipped = hg.AddArmor(ply, class)
    if not (equipped or ply.armors[placement]) then
        Notice(ply, "Could not equip armor: " .. tostring(class))
        return false
    end

    if (def.slot == "tactical_rig" or def.slot == "vest") and def.compartment then
        ent.zscav_pickup_claimed = true
        VestEquip(ply, inv, class, (uid and uid ~= "") and uid or ZSCAV:CreateBag(class))
    else
        inv.gear[def.slot] = { class = class, uid = uid, slot = def.slot }
        ent.zscav_pickup_claimed = true
        SyncInventory(ply)
    end

    ent:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(90, 110), 1, CHAN_ITEM)
    timer.Simple(0, function()
        if IsValid(ent) then ent:Remove() end
    end)
    return true
end

local function GetWorldArmorQuickPickupMode(ply, class)
    local def = ZSCAV:GetGearDef(class)
    local placement = ZSCAV:GetArmorPlacement(class)
    local inv = ZSCAV:GetInventory(ply)
    if not (def and placement and inv) then
        return "take"
    end

    inv.gear = inv.gear or {}
    ply.armors = ply.armors or {}

    if inv.gear[def.slot] == nil and ply.armors[placement] == nil and hg and hg.AddArmor then
        return "equip"
    end

    return "take"
end

local function HandleWorldBackpackPickupChoice(ply, ent, mode)
    if not (IsValid(ply) and IsValid(ent)) then return false end
    if not CanUseWorldPickupEntity(ply, ent) then return false end
    if PlayerHasAnyRagdoll(ply) then return false end
    if ent.zscav_pickup_claimed then return false end

    local class = ZSCAV:GetEntPackClass(ent)
    if class and HandleUnconfiguredPickup(ply, class, true) then return false end
    local def = ZSCAV:GetGearDef(class)
    if not (def and def.slot == "backpack") then return false end

    local uid = ZSCAV:GetEntPackUID(ent)
    local inv = ZSCAV:GetInventory(ply)
    if not inv then return false end

    local can = ZSCAV:CanCarryMore(inv, { class = class, uid = uid }, uid)
    if not can then
        Notice(ply, "Too heavy to carry: " .. tostring(def.name or class))
        return false
    end

    mode = tostring(mode or "take")
    if mode ~= "equip" then
        local ok, where = ZSCAV:TryAddItem(ply, class, uid)
        if ok then
            ent.zscav_pickup_claimed = true
            ply:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(95, 105), 1, CHAN_ITEM)
            timer.Simple(0, function()
                if IsValid(ent) then ent:Remove() end
            end)
            return true
        end

        Notice(ply, "No room for backpack: " .. tostring(where or class))
        return false
    end

    inv.gear = inv.gear or {}
    if inv.gear.backpack ~= nil then
        Notice(ply, "Backpack slot occupied. Drop or unequip first.")
        return false
    end

    ent.zscav_pickup_claimed = true
    BackpackEquip(ply, inv, class, uid)
    timer.Simple(0, function()
        if IsValid(ent) then ent:Remove() end
    end)
    return true
end

local function GetWorldBackpackQuickPickupMode(ply)
    local inv = ZSCAV:GetInventory(ply)
    if not inv then
        return "take"
    end

    inv.gear = inv.gear or {}
    if inv.gear.backpack == nil then
        return "equip"
    end

    return "take"
end

local function HandleWorldGearPickupChoice(ply, ent, mode)
    if not (IsValid(ply) and IsValid(ent)) then return false end
    if not CanUseWorldPickupEntity(ply, ent) then return false end
    if PlayerHasAnyRagdoll(ply) then return false end
    if ent.zscav_pickup_claimed then return false end

    local class = tostring(ZSCAV:GetEntPackClass(ent) or ent:GetClass() or "")
    local def = ZSCAV:GetGearDef(class)
    if not (def and IsWorldEquippableGearClass(class)) then return false end
    if def.slot == "backpack" then
        return HandleWorldBackpackPickupChoice(ply, ent, mode)
    end
    if ZSCAV:IsArmorEntityClass(class) then
        return HandleWorldArmorPickupChoice(ply, ent, mode)
    end
    if HandleUnconfiguredPickup(ply, class, true) then return false end

    local entry = CopyItemEntry(ent.zscav_world_entry) or {
        class = class,
        uid = tostring(ZSCAV:GetEntPackUID(ent) or ent.zscav_pack_uid or ""),
    }
    entry.class = tostring(entry.class or class)
    entry.uid = tostring(entry.uid or ZSCAV:GetEntPackUID(ent) or ent.zscav_pack_uid or "")

    mode = tostring(mode or "take")
    if mode ~= "equip" then
        local ok, where = ZSCAV:TryAddItemEntry(ply, entry)
        if ok then
            ent.zscav_pickup_claimed = true
            ent:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(95, 105), 1, CHAN_ITEM)
            timer.Simple(0, function()
                if IsValid(ent) then ent:Remove() end
            end)
            return true
        end

        if where == "weight" then
            Notice(ply, "Too heavy to carry: " .. tostring(def.name or class))
        else
            Notice(ply, "No room for gear: " .. tostring(where or class))
        end
        return false
    end

    local inv = ZSCAV:GetInventory(ply)
    if not inv then return false end

    inv.gear = inv.gear or {}
    if inv.gear[def.slot] ~= nil then
        Notice(ply, "Slot " .. tostring(def.slot or "gear"):upper() .. " occupied. Drop or unequip first.")
        return false
    end

    ent.zscav_pickup_claimed = true

    if (def.slot == "tactical_rig" or def.slot == "vest") and def.compartment then
        local uid = tostring(entry.uid or "")
        if uid == "" then
            uid = tostring(ZSCAV:CreateBag(class) or "")
        end

        if uid == "" then
            ent.zscav_pickup_claimed = nil
            Notice(ply, "Could not equip gear: " .. tostring(class))
            return false
        end

        ent:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(95, 105), 1, CHAN_ITEM)
        VestEquip(ply, inv, class, uid)
        timer.Simple(0, function()
            if IsValid(ent) then ent:Remove() end
        end)
        return true
    end

    local equipUID = tostring(entry.uid or "")
    if def.secure == true and equipUID == "" then
        equipUID = tostring(ZSCAV:CreateBag(entry.class) or "")
    end

    inv.gear[def.slot] = { class = entry.class, uid = equipUID, slot = def.slot }
    if def.secure == true then
        local loaded = ZSCAV:LoadBag(tostring(equipUID or ""))
        inv.secure = (loaded and loaded.contents) or {}
        local sid = tostring(ply:SteamID64() or "")
        local st = GetPlayerSecureState(sid)
        if st then
            st.issued = 1
            st.status = "equipped"
            st.class = tostring(entry.class)
            st.uid = tostring(equipUID or "")
            SavePlayerSecureState(st)
        end
    end

    ent:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(95, 105), 1, CHAN_ITEM)
    SyncInventory(ply)
    timer.Simple(0, function()
        if IsValid(ent) then ent:Remove() end
    end)
    return true
end

local function GetWorldGearQuickPickupMode(ply, class)
    local def = ZSCAV:GetGearDef(class)
    local inv = ZSCAV:GetInventory(ply)
    if not (def and inv and IsWorldEquippableGearClass(class)) then
        return "take"
    end

    inv.gear = inv.gear or {}
    if inv.gear[def.slot] ~= nil then
        return "take"
    end

    return "equip"
end

local function ResolveWorldGenericPickupEntry(ent)
    if not IsValid(ent) then return nil end

    local worldLoot = ZSCAV and ZSCAV.WorldLoot or nil
    if not istable(worldLoot) then return nil end
    if worldLoot.IsWorldContainerEntity and worldLoot.IsWorldContainerEntity(ent) then
        return nil
    end

    local entry = CopyItemEntry(ent.zscav_world_entry)
    if not istable(entry) then
        local packClass = tostring(ZSCAV:GetEntPackClass(ent) or "")
        if packClass ~= "" and worldLoot.IsWorldItemEntity and worldLoot.IsWorldItemEntity(ent) then
            entry = {
                class = packClass,
                uid = tostring(ZSCAV:GetEntPackUID(ent) or ""),
            }
        end
    end

    if not istable(entry) and worldLoot.GetWorldItemDefByModel then
        local itemDef = worldLoot.GetWorldItemDefByModel(ent.GetModel and ent:GetModel() or "")
        if istable(itemDef) then
            entry = {
                class = tostring(itemDef.item_class or ""),
                world_model = tostring(itemDef.model or ""),
            }
        end
    end

    if not istable(entry) then
        return nil
    end

    entry.class = tostring(entry.class or ZSCAV:GetEntPackClass(ent) or ent:GetClass() or "")
    if entry.class == "" then return nil end

    if not entry.world_model and worldLoot.GetWorldModelForEntry then
        local worldModel = tostring(worldLoot.GetWorldModelForEntry(entry) or "")
        if worldModel ~= "" then
            entry.world_model = worldModel
        end
    end

    if entry.uid ~= nil and tostring(entry.uid) == "" then
        entry.uid = nil
    end

    return entry
end

local function HandleWorldGenericItemPickupChoice(ply, ent, mode)
    if not (IsValid(ply) and IsValid(ent)) then return false end
    if not CanUseWorldPickupEntity(ply, ent) then return false end
    if PlayerHasAnyRagdoll(ply) then return false end
    if ent.zscav_pickup_claimed then return false end

    local entry = ResolveWorldGenericPickupEntry(ent)
    if not entry then return false end
    mode = tostring(mode or "take")

    local gearDef = ZSCAV:GetGearDef(entry.class)
    if gearDef and gearDef.slot == "backpack" then
        ent.zscav_pack_class = tostring(entry.class or ent.zscav_pack_class or "")
        ent.zscav_pack_uid = tostring(entry.uid or ent.zscav_pack_uid or "")
        return HandleWorldBackpackPickupChoice(ply, ent, mode)
    end

    if ZSCAV:IsArmorEntityClass(entry.class) then
        ent.zscav_pack_class = tostring(entry.class or ent.zscav_pack_class or "")
        ent.zscav_pack_uid = tostring(entry.uid or ent.zscav_pack_uid or "")
        return HandleWorldArmorPickupChoice(ply, ent, mode)
    end

    if IsWorldEquippableGearClass(entry.class) then
        ent.zscav_pack_class = tostring(entry.class or ent.zscav_pack_class or "")
        ent.zscav_pack_uid = tostring(entry.uid or ent.zscav_pack_uid or "")
        return HandleWorldGearPickupChoice(ply, ent, mode)
    end

    if HandleUnconfiguredPickup(ply, entry.class, false) then return false end

    local ok, where = ZSCAV:TryAddItemEntry(ply, entry)
    if not ok then
        if where == "weight" then
            Notice(ply, "Too heavy to carry: " .. tostring(entry.class))
        else
            Notice(ply, "No room for " .. tostring(entry.class) .. ".")
        end
        return false
    end

    ent.zscav_pickup_claimed = true
    ply:EmitSound("items/ammo_pickup.wav", 60, 100, 0.6)
    timer.Simple(0, function()
        if IsValid(ent) then
            ent:Remove()
        end
    end)

    return true
end

local function HandleWorldLootContainerUse(ply, ent)
    if not (IsValid(ply) and IsValid(ent)) then return false end
    if not CanUseWorldPickupEntity(ply, ent) then return false end
    if PlayerHasAnyRagdoll(ply) then return false end

    local worldLoot = ZSCAV and ZSCAV.WorldLoot or nil
    if not istable(worldLoot) then return false end

    if not (worldLoot.IsWorldContainerEntity and worldLoot.IsWorldContainerEntity(ent)) then
        local modelContainerDef = worldLoot.GetModelContainerDefByModel
            and worldLoot.GetModelContainerDefByModel(ent.GetModel and ent:GetModel() or "")
            or nil
        if not istable(modelContainerDef) then
            return false
        end

        local adopted = worldLoot.TryAdoptEntityFromCatalog and worldLoot.TryAdoptEntityFromCatalog(ent) or NULL
        if not IsValid(adopted) then
            return false
        end

        ent = adopted
    end

    local class = tostring(ZSCAV:GetEntPackClass(ent) or ent:GetClass() or "")
    local uid = tostring(ZSCAV:GetEntPackUID(ent) or "")
    if uid == "" and ZSCAV.CreateBag and ZSCAV.SaveBag then
        uid = tostring(ZSCAV:CreateBag(class) or "")
        if uid ~= "" then
            ent.zscav_pack_uid = uid
            if ent.SetBagUID then
                ent:SetBagUID(uid)
            end
            ZSCAV:SaveBag(uid, class, {})
        end
    end

    if uid == "" then
        Notice(ply, "Could not open loot container.")
        return false
    end

    ZSCAV:OpenContainerForPlayer(ply, uid, class, ent)
    return true
end

hook.Add("PlayerUse", "ZSCAV_ArmorPickupIntercept", function(ply, ent)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(ent) then return end
    -- Block pickups while ragdolled; E-hold-to-lift-head fires USE and
    -- would instantly re-pick the gear that was just dropped.
    if PlayerHasAnyRagdoll(ply) then return false end
    if ent.zscav_pickup_claimed then return false end

    local class = ent:GetClass()
    local uid = ZSCAV:GetEntPackUID(ent)
    if not ZSCAV:IsArmorEntityClass(class) then return end
    if HandleUnconfiguredPickup(ply, class, true) then return false end

    local def = ZSCAV:GetGearDef(class)

    -- ATTACK2+USE on compartment rigs opens the rig container without
    -- auto-equipping or moving it.
    if ply:KeyDown(IN_ATTACK2) and def and def.compartment then
        if not uid or uid == "" then
            uid = tostring(ZSCAV:CreateBag(class) or "")
            if uid ~= "" then
                ent.zscav_pack_uid = uid
                if ent.SetBagUID then
                    ent:SetBagUID(uid)
                end
                -- Ensure the bag row exists so open flow can load it.
                local existing = ZSCAV:LoadBag(uid)
                if not existing then
                    ZSCAV:SaveBag(uid, class, {})
                end
            end
        end

        if uid and uid ~= "" then
            StartPendingBagOpen(ply, uid, class, ent)
        else
            Notice(ply, "Could not open rig container.")
        end
        return false
    end

    if ply:KeyDown(IN_SPEED) then
        HandleWorldArmorPickupChoice(ply, ent, GetWorldArmorQuickPickupMode(ply, class))
        return false
    end

    SendWorldPickupPrompt(ply, ent, class, true)
    return false
end)

-- Backpack pickup intercept. Mirrors the armor flow but uses the pure
-- ZScav gear path (no hg.AddArmor) since packs are not armor entries.
-- - ATTACK2+USE: open the bag's container UI without equipping.
-- - SHIFT+USE: quick-pickup (equip if the slot is free, otherwise stash).
-- - Plain USE: open the take/equip prompt.
function ZSCAV:HandleWorldBackpackUseIntent(ply, ent)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(ent) then return end
    if PlayerHasAnyRagdoll(ply) then return false end
    if ent.zscav_pickup_claimed then return false end

    local useFrame = CurTime()
    local entIndex = ent:EntIndex()
    if ply.zscav_backpack_use_frame == useFrame and ply.zscav_backpack_use_entindex == entIndex then
        return false
    end
    ply.zscav_backpack_use_frame = useFrame
    ply.zscav_backpack_use_entindex = entIndex

    local class = ZSCAV:GetEntPackClass(ent)
    if class and HandleUnconfiguredPickup(ply, class, true) then return false end
    local def   = ZSCAV:GetGearDef(class)
    if not (def and def.slot == "backpack") then return end

    local uid = ZSCAV:GetEntPackUID(ent)
    if ply:KeyDown(IN_ATTACK2) and uid then
        StartPendingBagOpen(ply, uid, class, ent)
        return false
    end

    if ply:KeyDown(IN_SPEED) then
        HandleWorldBackpackPickupChoice(ply, ent, GetWorldBackpackQuickPickupMode(ply))
        return false
    end

    SendWorldPickupPrompt(ply, ent, class, true)
    return false
end

hook.Add("PlayerUse", "ZSCAV_BackpackPickupIntercept", function(ply, ent)
    -- Block pickups while ragdolled (E-hold-to-lift-head fires USE).
    return ZSCAV:HandleWorldBackpackUseIntent(ply, ent)
end)

-- Some server packs are real prop_ragdolls, and other PlayerUse hooks can
-- swallow USE before the backpack intercept sees it. Mirror the same logic
-- from a traced keypress so pack pickup/equip still works reliably.
hook.Add("KeyPress", "ZSCAV_BackpackPickupKeyPressFallback", function(ply, key)
    if key ~= IN_USE or not ZSCAV:IsActive() then return end
    if not IsValid(ply) then return end

    local trace = ply:GetEyeTrace()
    local ent = IsValid(trace.Entity) and trace.Entity or nil
    if not IsValid(ent) or not CanUseWorldPickupEntity(ply, ent) then return end

    local class = ZSCAV:GetEntPackClass(ent)
    local def = class and ZSCAV:GetGearDef(class) or nil
    if not (def and def.slot == "backpack") then return end

    if not (ent.IsZScavPack or ent.GetBagUID or ent:GetClass() == "prop_ragdoll") then return end

    return ZSCAV:HandleWorldBackpackUseIntent(ply, ent)
end)

hook.Add("PlayerUse", "ZSCAV_WorldLootContainerUse", function(ply, ent)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(ent) then return end

    if HandleWorldLootContainerUse(ply, ent) then
        return false
    end
end)

function ZSCAV:HandleWorldGenericUseIntent(ply, ent)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(ent) then return end
    if PlayerHasAnyRagdoll(ply) then return false end
    if ent.zscav_pickup_claimed then return false end

    local useFrame = CurTime()
    local entIndex = ent:EntIndex()
    if ply.zscav_world_item_use_frame == useFrame and ply.zscav_world_item_use_entindex == entIndex then
        return false
    end
    ply.zscav_world_item_use_frame = useFrame
    ply.zscav_world_item_use_entindex = entIndex

    local entry = ResolveWorldGenericPickupEntry(ent)
    if not entry then
        return
    end

    local class = tostring(entry.class or "")
    local gearDef = ZSCAV:GetGearDef(class)
    if gearDef and gearDef.slot == "backpack" then
        local uid = tostring(ZSCAV:GetEntPackUID(ent) or "")
        if ply:KeyDown(IN_ATTACK2) and uid ~= "" then
            StartPendingBagOpen(ply, uid, class, ent)
            return false
        end

        if ply:KeyDown(IN_SPEED) then
            HandleWorldBackpackPickupChoice(ply, ent, GetWorldBackpackQuickPickupMode(ply))
            return false
        end

        SendWorldPickupPrompt(ply, ent, class, true)
        return false
    end

    if ZSCAV:IsArmorEntityClass(class) then
        local def = ZSCAV:GetGearDef(class)
        local uid = tostring(ZSCAV:GetEntPackUID(ent) or "")
        if ply:KeyDown(IN_ATTACK2) and def and def.compartment and uid ~= "" then
            StartPendingBagOpen(ply, uid, class, ent)
            return false
        end

        if ply:KeyDown(IN_SPEED) then
            HandleWorldArmorPickupChoice(ply, ent, GetWorldArmorQuickPickupMode(ply, class))
            return false
        end

        SendWorldPickupPrompt(ply, ent, class, true)
        return false
    end

    if gearDef and IsWorldEquippableGearClass(class) then
        local uid = tostring(ZSCAV:GetEntPackUID(ent) or "")
        if ply:KeyDown(IN_ATTACK2) and gearDef.compartment and uid ~= "" then
            StartPendingBagOpen(ply, uid, class, ent)
            return false
        end

        if ply:KeyDown(IN_SPEED) then
            HandleWorldGearPickupChoice(ply, ent, GetWorldGearQuickPickupMode(ply, class))
            return false
        end

        SendWorldPickupPrompt(ply, ent, class, true)
        return false
    end

    if HandleUnconfiguredPickup(ply, class, false) then return false end

    if ply:KeyDown(IN_SPEED) then
        HandleWorldGenericItemPickupChoice(ply, ent, "take")
        return false
    end

    SendWorldPickupPrompt(ply, ent, class, false)
    return false
end

hook.Add("PlayerUse", "ZSCAV_WorldItemPickupIntercept", function(ply, ent)
    return ZSCAV:HandleWorldGenericUseIntent(ply, ent)
end)

hook.Add("KeyPress", "ZSCAV_WorldItemPickupKeyPressFallback", function(ply, key)
    if key ~= IN_USE or not ZSCAV:IsActive() then return end
    if not IsValid(ply) then return end

    local trace = ply:GetEyeTrace()
    local ent = IsValid(trace.Entity) and trace.Entity or nil
    if not IsValid(ent) or not CanUseWorldPickupEntity(ply, ent) then return end

    local entry = ResolveWorldGenericPickupEntry(ent)
    if not entry then return end

    local class = tostring(entry.class or "")
    local gearDef = ZSCAV:GetGearDef(class)
    if gearDef and gearDef.slot == "backpack" and ent:GetClass() ~= "ent_zscav_world_item" then
        return
    end

    return ZSCAV:HandleWorldGenericUseIntent(ply, ent)
end)

hook.Add("KeyPress", "ZSCAV_WorldWeaponPickupKeyPressFallback", function(ply, key)
    if key ~= IN_USE or not ZSCAV:IsActive() then return end
    if not IsValid(ply) then return end

    local trace = ply:GetEyeTrace()
    local wep = IsValid(trace.Entity) and trace.Entity or nil
    if not (IsValid(wep) and wep:IsWeapon()) then return end
    if not CanUseWorldPickupEntity(ply, wep) then return end

    return HandleWorldWeaponUseIntent(ply, wep)
end)

-- ---------------------------------------------------------------
-- Pickup intercept (only while ZScav round is active)
--
-- This is the SINGLE chokepoint that decides whether a weapon entity is
-- allowed to enter `ply:GetWeapons()`. Design contract:
--
--   * Walk-over contact pickup -> blocked, weapon is moved into the
--     player's ZScav inventory grid via TryAddItem. The weapon ent is
--     then removed from the world.
--   * Plain USE on a floor weapon -> same as walk-over (route to grid).
--   * SHIFT + USE on a floor weapon -> auto-equip into a free weapon
--     slot via TryAutoEquipWeapon. If no slot is free, the weapon is
--     blocked and a notice is printed.
--   * The ONLY path that actually returns true (allow engine pickup) is
--     a one-shot transfer authorized by `ply.zscav_allow_pickup_once`,
--     which is set by the inventory equip action and TryAutoEquipWeapon
--     immediately before they call ply:Give(class). Every other path
--     (other addons giving weapons, hg radial, scripts, etc) is blocked
--     so weapons cannot silently end up off-grid.
--
-- The bypass list (`ShouldBypassInventoryPickup`) is for things that
-- must stay engine-owned: hands, sling, physgun, gmod_tool, plus a
-- short post-drop / post-spawn grace window so the dropper isn't
-- instantly re-acquiring their own drop on contact.
-- ---------------------------------------------------------------
hook.Add("PlayerCanPickupWeapon", "ZSCAV_PickupIntercept", function(ply, wep)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(wep) then return end
    if wep.zscav_death_drop_suppressed then return false end
    -- Block weapon pickups while ragdolled.
    if PlayerHasAnyRagdoll(ply) then return false end

    -- Drop/spawn grace should suppress ZScav handling without letting
    -- the engine fall through to an actual walk-over pickup.
    if (wep.zscav_ignore_until or 0) > CurTime() then
        return false
    end

    if ZSCAV:ShouldBypassInventoryPickup(wep) then return end

    local class = GetWeaponBaseClass(wep)
    local weaponItem = CopyItemEntry({ class = class }) or { class = class }
    EnsureWeaponEntryRuntime(weaponItem, wep)
    weaponItem.weapon_state = ZSCAV:CaptureWeaponState(nil, wep, weaponItem)

    -- Authorized one-shot transfer (the inventory equip path opens this
    -- gate immediately before calling ply:Give). Consume and allow.
    if ply.zscav_allow_pickup_once == class then
        ply.zscav_allow_pickup_once = nil
        return -- nil = defer to engine default = allow
    end

    -- The hook fires every tick the player is in contact with the
    -- weapon ent (and the deferred wep:Remove() doesn't take effect
    -- until the next frame), so without this guard a single pickup
    -- attempt would call TryAddItem N times and dump N copies into the
    -- grid. Mark the ent the first time we touch it; subsequent ticks
    -- silently fall through.
    if wep.zscav_pickup_claimed then return false end

    -- Intentionally allow duplicate class pickups to stash into inventory
    -- grids even when the player currently has that class equipped.
    -- This enables Tarkov-like behavior (e.g. second AKM or extra grenade
    -- of the same class) as long as there is space/weight.

    -- ZScav has NO walk-over pickup. The player must explicitly hold
    -- USE on a weapon for it to be considered. SHIFT+USE stays the fast
    -- path; plain USE opens a small take/equip prompt.
    if not ply:KeyDown(IN_USE) then
        return false
    end

    return HandleWorldWeaponUseIntent(ply, wep)
end)

-- Block all walk-over ammo / item / battery pickups too. ZScav is a
-- USE-only loot system; the engine's auto-pickup-on-touch behaviour
-- bypasses our inventory entirely and would let players accumulate
-- ammo/health/armor outside the grid.
hook.Add("PlayerCanPickupItem", "ZSCAV_BlockWalkoverItem", function(ply, ent)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(ent) then return end
    if not ply:KeyDown(IN_USE) then return false end
end)

local function IsBlockedDirectUsePickupClass(class)
    class = tostring(class or "")
    if class == "ent_hg_molotov" or class == "ent_hg_smokenade" or class == "ent_hg_grenade_m18smokes" then
        return true
    end

    return class:find("ent_hg_grenade", 1, true) == 1
end

hook.Add("PlayerUse", "ZSCAV_BlockDirectUsePickup", function(ply, ent)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(ent) then return end

    if ent:IsWeapon() then
        if ZSCAV:ShouldBypassInventoryPickup(ent) then return end
        return false
    end

    if IsBlockedDirectUsePickupClass(ent:GetClass()) then
        return false
    end
end)

hook.Add("AllowPlayerPickup", "ZSCAV_BlockUsePhysicsPickup", function(ply, ent)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(ent) then return end
    return false
end)

hook.Add("OnPlayerPhysicsPickup", "ZSCAV_BlockWeaponPhysicsPickup", function(ply, ent)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(ent) then return end
    return false
end)

hook.Add("PlayerDroppedWeapon", "ZSCAV_SyncDroppedWeapon", function(ply, wep)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(wep) then return end

    -- Suppress the inventory pickup intercept for ~1s so the dropper
    -- doesn't immediately re-acquire the weapon they just dropped
    -- (PlayerCanPickupWeapon fires on contact, the dropper is standing
    -- on the spawn point). After the grace expires the weapon flows
    -- through the inventory system like any other ground weapon, so
    -- anyone -- including the dropper -- can pick it back up.
    wep.zscav_ignore_until = CurTime() + 1

    -- Do NOT clear the inv slot here unconditionally — Homigrad's "drop"
    -- can route the weapon onto hg_sling, leaving it in ply:GetWeapons().
    -- Reconcile next tick: if the player no longer has the class, the slot
    -- clears; if they still hold it (sling), the slot is preserved.
    timer.Simple(0, function()
        if IsValid(ply) then ZSCAV:ReconcileWeapons(ply) end
    end)
    -- Second pass after physics/strip settles.
    timer.Simple(0.25, function()
        if IsValid(ply) then ZSCAV:ReconcileWeapons(ply) end
    end)
end)

-- Catch out-of-band equips (admin give, base loadout, sling-recovery): adopt
-- weapons into the matching inv slot so the menu always reflects reality.
hook.Add("WeaponEquip", "ZSCAV_SyncEquippedWeapon", function(wep, ply)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not IsValid(wep) then return end

    local equipClass = tostring(GetWeaponBaseClass(wep) or ""):lower()
    if ZSCAV:IsGrenadeClass(equipClass) and ConsumePendingGrenadeHotbarGrant(ply, equipClass) then
        timer.Simple(0, function()
            if IsValid(ply) then
                ZSCAV:ReconcileWeapons(ply)
                ZSCAV:ReconcileArmor(ply)
            end
        end)
        return
    end

    local recentWorldUse = HasRecentWorldWeaponUseIntent(ply, wep)
    if recentWorldUse then
        ply.zscav_recent_world_weapon_use = nil
    end

    local isWorldWeapon = wep:IsWeapon() and (wep.IsSpawned == true or istable(wep.zscav_world_entry) or recentWorldUse)
    if isWorldWeapon and not ZSCAV:ShouldBypassInventoryPickup(wep) then
        local backedEntry = FindBackedWeaponSlotEntry(ply, wep)
        if not backedEntry then
            UndoUnauthorizedWorldWeaponEquip(ply, wep)
            return
        end
    end

    timer.Simple(0, function()
        if IsValid(ply) then
            ZSCAV:ReconcileWeapons(ply)
            ZSCAV:ReconcileArmor(ply)
        end
    end)
end)

local CORPSE_CONTAINER_CLASS = "Corpse"
local LIVE_LOOT_CONTAINER_CLASS = "LiveLoot"

local function CopyCorpseEntryList(list)
    local out = {}

    for _, entry in ipairs(list or {}) do
        local copied = CopyItemEntry(entry)
        if copied and copied.class then
            out[#out + 1] = copied
        end
    end

    return out
end

local function CopyCorpseEntryMap(entries)
    local out = {}

    for key, entry in pairs(entries or {}) do
        local copied = CopyItemEntry(entry, {
            slot = tostring(entry and entry.slot or key or ""),
        })

        if copied and copied.class then
            out[tostring(key or "")] = copied
        end
    end

    return out
end

local function BuildDeathInventorySnapshot(inv)
    if not istable(inv) then return nil end

    return {
        gear = CopyCorpseEntryMap(inv.gear),
        weapons = CopyCorpseEntryMap(inv.weapons),
        pocket = CopyCorpseEntryList(inv.pocket),
        vest = CopyCorpseEntryList(inv.vest),
        backpack = CopyCorpseEntryList(inv.backpack),
        secure = CopyCorpseEntryList(inv.secure),
        grids = table.Copy(inv.grids or {}),
        quickslots = CopyCorpseEntryMap(inv.quickslots),
        updated = os.time(),
    }
end

local ZScavSafeZoneContext = {
    NewInventory = NewInventory,
    GetPlayerSecureState = GetPlayerSecureState,
    SavePlayerSecureState = SavePlayerSecureState,
    EnsureSecureContainerForInventory = EnsureSecureContainerForInventory,
    MigrateLegacyGrids = MigrateLegacyGrids,
    SyncInventory = SyncInventory,
    Notice = Notice,
    BackpackEquip = BackpackEquip,
    VestEquip = VestEquip,
    CopyItemEntry = CopyItemEntry,
    EnsureWeaponEntryRuntime = EnsureWeaponEntryRuntime,
    GiveWeaponInstance = GiveWeaponInstance,
    CopyCorpseEntryList = CopyCorpseEntryList,
    CopyCorpseEntryMap = CopyCorpseEntryMap,
}

ZSCAV.SafeZoneContext = ZScavSafeZoneContext
include("sv_zscav_safezone.lua")
ZSCAV.SafeZoneContext = nil

local ZScavCorpseContext = {
    CopyItemEntry = CopyItemEntry,
    SyncInventory = SyncInventory,
    Notice = Notice,
    findFreeSpotAR = findFreeSpotAR,
    DeliverToPlayerMailbox = DeliverToPlayerMailbox,
    SyncMailboxUnread = SyncMailboxUnread,
    CORPSE_CONTAINER_CLASS = CORPSE_CONTAINER_CLASS,
    LIVE_LOOT_CONTAINER_CLASS = LIVE_LOOT_CONTAINER_CLASS,
}

ZSCAV.CorpseContext = ZScavCorpseContext
ZSCAV.CorpseModule = nil
include("sv_zscav_corpse.lua")
local ZScavCorpseModule = ZSCAV.CorpseModule or {}
ZSCAV.CorpseContext = nil

local GetCorpseContainer = ZScavCorpseModule.GetCorpseContainer
local ApplyLiveLootProxyContents = ZScavCorpseModule.ApplyLiveLootProxyContents
local ApplyCorpseAnchorVisualState = ZScavCorpseModule.ApplyCorpseAnchorVisualState
local CorpseHasTrackedHeadGear = ZScavCorpseModule.CorpseHasTrackedHeadGear
local DescribeDeathActor = ZScavCorpseModule.DescribeDeathActor
local DescribeDeathCause = ZScavCorpseModule.DescribeDeathCause
local SendZScavDeathOverlay = ZScavCorpseModule.SendZScavDeathOverlay
local DivertSafeZoneDeathToMailbox = ZScavCorpseModule.DivertSafeZoneDeathToMailbox
local BuildCorpseRootContainer = ZScavCorpseModule.BuildCorpseRootContainer
local ZSCAV_SAFEZONE_MAILBOX_FALLBACK = ZScavCorpseModule.SafeZoneMailboxFallback
    or "Mailbox recovery failed. Field loot remains on your body."

-- ---------------------------------------------------------------
-- Round lifecycle
-- ---------------------------------------------------------------

-- ---------------------------------------------------------------
-- Round lifecycle
-- ---------------------------------------------------------------
hook.Add("DoPlayerDeath", "ZSCAV_MarkDeathDropSuppression", function(ply)
    if not (IsValid(ply) and ZSCAV:IsActive()) then return end
    ply.zscav_death_drop_pending_until = CurTime() + 2
end)

hook.Add("PlayerSpawn", "ZSCAV_FreshInventory", function(ply)
    if not ZSCAV:IsActive() then return end

    local preserveInventory = (ply.zscav_preserve_inventory_spawn_until or 0) > CurTime()
    ply.zscav_preserve_inventory_spawn_until = nil

    if preserveInventory then
        -- FakeUp uses Spawn() to stand the player up again; keep the live
        -- ZScav inventory intact and just resync after the new player entity settles.
        timer.Simple(0, function()
            if not (IsValid(ply) and ZSCAV:IsActive()) then return end
            SyncInventory(ply)
            ZSCAV:ReconcileWeapons(ply)
            ZSCAV:ReconcileArmor(ply)
            ZSCAV:ApplyWeightToOrganism(ply)
        end)
    else
        ZSCAV:ClearInventory(ply)
    end

    ZSCAV:ResetWeightState(ply)
    ply.zscav_grenade_prev_has = {}
    ply.zscav_grenade_skip_until = {}
    ply.zscav_death_drop_pending_until = nil
    ply.zscav_death_inventory_snapshot = nil
    ply.zscav_death_summary = nil
    ply.zscav_suppressed_death_weapons = nil
    ply.zscav_safezone_death_mailbox_pending = nil
end)

hook.Add("PlayerSpawn", "ZSCAV_SpawnSetup", function(ply)
    if not (IsValid(ply) and ZSCAV:IsActive() and ply:Alive()) then return end

    ply.zscav_return_lobby_until = nil

    net.Start("ZScavDeathClose")
    net.Send(ply)

    ply:SuppressHint("OpeningMenu")
    ply:SuppressHint("Annoy1")
    ply:SuppressHint("Annoy2")
    ply.viewmode = 3
    ply:UnSpectate()
    ply:SetMoveType(MOVETYPE_WALK)

    if ApplyAppearance then
        ApplyAppearance(ply, nil, nil, nil, true)
    end

    ply:SetSuppressPickupNotices(true)
    ply.noSound = true
    if not ply:HasWeapon("weapon_hands_sh") then
        ply:Give("weapon_hands_sh")
    end
    ply:SelectWeapon("weapon_hands_sh")
    timer.Simple(0.1, function()
        if IsValid(ply) then
            ply.noSound = false
        end
    end)
    ply:SetSuppressPickupNotices(false)

    if zb.GiveRole then
        zb.GiveRole(ply, "Scavenger", Color(190, 150, 60))
    end

    if not isvector(ply.zscav_pending_spawn_pos) then
        ZSCAV:QueueSafeSpawn(ply)
    end

    ApplyQueuedZScavSpawn(ply)
end)

hook.Add("PlayerDeath", "ZSCAV_CloseInvOnDeath", function(ply)
    if not IsValid(ply) then return end
    ZSCAV:ResetWeightState(ply)
    ply.zscav_grenade_prev_has = {}
    ply.zscav_grenade_skip_until = {}
    net.Start("ZScavInvClose")
    net.Send(ply)
end)

hook.Add("PlayerDeath", "ZSCAV_HandleDeathPresentation", function(ply, inflictor, attacker)
    if not (IsValid(ply) and ZSCAV:IsActive()) then return end

    local inv = ply.zscav_inv or ZSCAV:GetInventory(ply)
    ply.zscav_death_inventory_snapshot = BuildDeathInventorySnapshot(inv)
    ply.zscav_death_summary = {
        attacker = DescribeDeathActor(ply, attacker),
        cause = DescribeDeathCause(ply, attacker, inflictor),
    }

    local inSafeZone, zone = ZSCAV:GetPlayerSafeZoneContext(ply)
    if inSafeZone then
        ply.zscav_safezone_death_mailbox_pending = {
            zone_id = tostring(zone and zone.id or ""),
            zone_name = tostring(zone and zone.name or ""),
        }
        return
    end

    ply.zscav_safezone_death_mailbox_pending = nil
    SendZScavDeathOverlay(ply)
end)

hook.Add("PostPlayerDeath", "ZSCAV_BuildCorpseRootContainer", function(ply)
    if not (IsValid(ply) and ZSCAV:IsActive()) then return end

    local ragdoll = ply:GetNWEntity("RagdollDeath")
    if not IsValid(ragdoll) then return end

    if ply.zscav_safezone_death_mailbox_pending then
        if DivertSafeZoneDeathToMailbox(ply, ragdoll) then
            return
        end

        SendZScavDeathOverlay(ply, ZSCAV_SAFEZONE_MAILBOX_FALLBACK)
    end

    BuildCorpseRootContainer(ragdoll, ply)
end)

net.Receive("ZScavDeathReturnLobby", function(_, ply)
    if not (IsValid(ply) and ZSCAV:IsActive()) then return end
    if ply:Alive() then return end
    if ply:Team() == TEAM_SPECTATOR then return end

    local blockUntil = tonumber(ply.zscav_return_lobby_until) or 0
    if blockUntil > CurTime() then return end
    ply.zscav_return_lobby_until = CurTime() + 1

    ZSCAV:QueueSafeSpawn(ply)
    ply:Spawn()
end)

-- ---------------------------------------------------------------
-- Action handlers
-- ---------------------------------------------------------------
ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}
local ZScavActionState = ZSCAV.ServerHelpers.ActionState or {}
ZSCAV.ServerHelpers.ActionState = ZScavActionState

do
local Actions = ZScavActionState.Actions or {}
ZScavActionState.Actions = Actions
local ATTACHMENT_INSERT_ORDER = { "backpack", "pocket", "vest", "secure" }
local function ContainerSizeFor(...)
    local helper = ZScavActionState.ContainerSizeFor
    if not helper then return 0, 0, nil end
    return helper(...)
end

local function SaveContainerContents(...)
    local helper = ZScavActionState.SaveContainerContents
    if not helper then return false end
    return helper(...)
end

local function SendContainerSnapshotForUID(...)
    local helper = ZScavActionState.SendContainerSnapshotForUID
    if not helper then return false end
    return helper(...)
end

local function ContainerInChain(...)
    local helper = ZScavActionState.ContainerInChain
    if not helper then return false end
    return helper(...)
end

local CUSTOM_HOTBAR_COUNT = math.max(math.floor(tonumber(ZSCAV.CustomHotbarCount) or 7), 1)

local function NormalizeQuickslotIndex(index)
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > CUSTOM_HOTBAR_COUNT then return nil end
    return index
end

local function GetQuickslotTable(inv)
    if not istable(inv) then return {} end
    inv.quickslots = istable(inv.quickslots) and inv.quickslots or {}
    return inv.quickslots
end

local function IsQuickslotBindableEntry(entry)
    if not (istable(entry) and entry.class) then return false end
    if ZSCAV.ResolveGrenadeInventoryClass and ZSCAV:ResolveGrenadeInventoryClass(entry) then
        return true
    end
    return tostring(ZSCAV:GetEquipWeaponSlot(entry.class) or "") ~= ""
end

local function GetQuickslotBindingBlockReason(entry, meta)
    if not IsQuickslotBindableEntry(entry) then
        return "That item cannot be assigned to the hotbar."
    end

    if tostring(ZSCAV:GetEquipWeaponSlot(entry.class) or "") == "medical" then
        local preferredGrid = tostring(meta and meta.preferred_grid or "")
        if preferredGrid ~= "pocket" and preferredGrid ~= "vest" then
            return "Medical hotkeys only accept meds from pockets or tactical rig."
        end
    end

    return nil
end

local function CollectQuickslotClassTokens(source)
    local out = {}
    local seen = {}

    local function push(class)
        class = tostring(class or ""):lower()
        if class == "" or seen[class] then return end
        seen[class] = true
        out[#out + 1] = class
    end

    if istable(source) then
        push(source.class)
        push(source.actual_class)

        if ZSCAV.GetCanonicalItemClass then
            push(ZSCAV:GetCanonicalItemClass(source))
            push(ZSCAV:GetCanonicalItemClass(source.class))
            push(ZSCAV:GetCanonicalItemClass(source.actual_class))
        end

        if GetWeaponBaseClass then
            push(GetWeaponBaseClass(source.class))
            push(GetWeaponBaseClass(source.actual_class))
        end

        if ZSCAV.ResolveGrenadeInventoryClass then
            push(ZSCAV:ResolveGrenadeInventoryClass(source))
        end
    else
        push(source)

        if ZSCAV.GetCanonicalItemClass then
            push(ZSCAV:GetCanonicalItemClass(source))
        end

        if GetWeaponBaseClass then
            push(GetWeaponBaseClass(source))
        end
    end

    return out
end

local function CopyQuickslotRef(entry, overrides)
    if not (istable(entry) and entry.class) then return nil end

    local out = {
        class = tostring(entry.class or ""),
    }

    local actualClass = tostring(entry.actual_class or "")
    if actualClass ~= "" then
        out.actual_class = actualClass
    end

    local weaponUID = tostring(entry.weapon_uid or "")
    if weaponUID ~= "" then
        out.weapon_uid = weaponUID
    end

    local uid = tostring(entry.uid or "")
    if uid ~= "" then
        out.uid = uid
    end

    local quickslotKind = tostring(ZSCAV:GetEquipWeaponSlot(entry) or "")
    if quickslotKind ~= "" then
        out.kind = quickslotKind
    end

    if istable(overrides) then
        local preferredGrid = tostring(overrides.preferred_grid or "")
        if preferredGrid ~= "" then
            out.preferred_grid = preferredGrid
        end

        local preferredSlot = tostring(overrides.preferred_slot or "")
        if preferredSlot ~= "" then
            out.preferred_slot = preferredSlot
        end
    end

    return out
end

local function QuickslotEntryMatches(ref, entry)
    if not (istable(ref) and istable(entry) and entry.class) then return false end

    local refUID = tostring(ref.uid or "")
    if refUID ~= "" and tostring(entry.uid or "") == refUID then
        return true
    end

    local refWeaponUID = tostring(ref.weapon_uid or "")
    if refWeaponUID ~= "" and tostring(entry.weapon_uid or "") == refWeaponUID then
        return true
    end

    local wanted = {}
    for _, token in ipairs(CollectQuickslotClassTokens(ref)) do
        wanted[token] = true
    end

    if next(wanted) == nil then return false end

    for _, token in ipairs(CollectQuickslotClassTokens(entry)) do
        if wanted[token] then
            return true
        end
    end

    return false
end

local function ResolveQuickslotBoundEntry(inv, ref)
    if not (istable(inv) and istable(ref) and ref.class) then return nil end

    inv.weapons = inv.weapons or {}

    local preferredSlot = tostring(ref.preferred_slot or "")
    if preferredSlot ~= "" then
        local entry = inv.weapons[preferredSlot]
        if entry and QuickslotEntryMatches(ref, entry) then
            return {
                entry = entry,
                location = "weapon",
                slot = preferredSlot,
            }
        end
    end

    for slotName, entry in pairs(inv.weapons) do
        if entry and QuickslotEntryMatches(ref, entry) then
            return {
                entry = entry,
                location = "weapon",
                slot = slotName,
            }
        end
    end

    local hasStableIdentity = tostring(ref.uid or "") ~= "" or tostring(ref.weapon_uid or "") ~= ""
    local preferredGrid = tostring(ref.preferred_grid or "")

    local function scanGrid(gridName)
        local list = inv[gridName]
        if not istable(list) then return nil end

        for index, entry in ipairs(list) do
            if entry and QuickslotEntryMatches(ref, entry) then
                return {
                    entry = entry,
                    location = "grid",
                    grid = gridName,
                    index = index,
                }
            end
        end

        return nil
    end

    if hasStableIdentity and preferredGrid ~= "" then
        local found = scanGrid(preferredGrid)
        if found then return found end
    end

    for _, gridName in ipairs({ "pocket", "vest", "backpack", "secure" }) do
        if not (hasStableIdentity and gridName == preferredGrid) then
            local found = scanGrid(gridName)
            if found then return found end
        end
    end

    return nil
end

local function SelectOrRestoreWeaponEntry(ply, entry)
    if not (IsValid(ply) and istable(entry) and entry.class) then return false end

    if SelectWeaponEntry and select(1, SelectWeaponEntry(ply, entry)) then
        return true
    end

    if not GiveWeaponInstance then return false end

    local wep = GiveWeaponInstance(ply, entry)
    if not IsValid(wep) then return false end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if SelectWeaponEntry then
            SelectWeaponEntry(ply, entry)
        end
    end)

    return true
end

local function SelectHandsWeapon(ply)
    if not IsValid(ply) then return false end

    local hands = ply:GetWeapon("weapon_hands_sh")
    if not IsValid(hands) then
        hands = ply:Give("weapon_hands_sh")
    end

    if not (IsValid(hands) or ply:HasWeapon("weapon_hands_sh")) then
        return false
    end

    ply:SelectWeapon("weapon_hands_sh")
    return true
end

local function EntryMatchesActiveWeapon(ply, entry)
    local activeWeapon = IsValid(ply) and ply:GetActiveWeapon() or NULL
    if not (IsValid(activeWeapon) and istable(entry) and entry.class) then return false end

    local activeWeaponUID = tostring(activeWeapon.zscav_weapon_uid or "")
    if activeWeaponUID ~= "" and activeWeaponUID == tostring(entry.weapon_uid or "") then
        return true
    end

    local activeActualClass = tostring(activeWeapon:GetClass() or "")
    if activeActualClass ~= "" and activeActualClass == tostring(entry.actual_class or "") then
        return true
    end

    local activeBaseClass = tostring(GetWeaponBaseClass(activeWeapon) or "")
    return activeBaseClass ~= "" and activeBaseClass == tostring(GetWeaponBaseClass(entry.class) or "")
end

local function WeaponMatchesEntry(wep, entry)
    if not (IsValid(wep) and istable(entry) and entry.class) then return false end

    local weaponUID = tostring(wep.zscav_weapon_uid or "")
    if weaponUID ~= "" and weaponUID == tostring(entry.weapon_uid or "") then
        return true
    end

    local actualClass = tostring(wep:GetClass() or "")
    if actualClass ~= "" and actualClass == tostring(entry.actual_class or "") then
        return true
    end

    local baseClass = tostring(GetWeaponBaseClass(wep) or "")
    return baseClass ~= "" and baseClass == tostring(GetWeaponBaseClass(entry.class) or "")
end

local function GetActiveWeaponSlot(ply, inv, slotA, slotB)
    local activeWeapon = IsValid(ply) and ply:GetActiveWeapon() or NULL
    if not (IsValid(activeWeapon) and istable(inv) and istable(inv.weapons)) then return nil end

    local activeWeaponUID = tostring(activeWeapon.zscav_weapon_uid or "")
    local activeActualClass = tostring(activeWeapon:GetClass() or "")
    local activeBaseClass = tostring(GetWeaponBaseClass(activeWeapon) or "")

    local function matches(slotName)
        local entry = inv.weapons[slotName]
        if not (entry and entry.class) then return false end

        if activeWeaponUID ~= "" and tostring(entry.weapon_uid or "") == activeWeaponUID then
            return true
        end

        if activeActualClass ~= "" and tostring(entry.actual_class or "") == activeActualClass then
            return true
        end

        return activeBaseClass ~= "" and tostring(GetWeaponBaseClass(entry.class) or "") == activeBaseClass
    end

    if slotA and matches(slotA) then return slotA end
    if slotB and matches(slotB) then return slotB end
    return nil
end

hook.Add("PlayerSwitchWeapon", "ZSCAV_StoreScabbardOnSwitch", function(ply, oldWep, newWep)
    if not ZSCAV:IsActive() then return end
    if not (IsValid(ply) and IsValid(oldWep)) then return end
    if IsValid(newWep) and oldWep == newWep then return end

    local inv = ZSCAV:GetInventory(ply)
    if not (istable(inv) and istable(inv.weapons)) then return end

    local slotName = nil
    local entry = nil
    for _, candidate in ipairs({ "melee", "scabbard" }) do
        local slotEntry = inv.weapons[candidate]
        if WeaponMatchesEntry(oldWep, slotEntry) then
            slotName = candidate
            entry = slotEntry
            break
        end
    end

    if not (slotName and istable(entry) and entry.class) then return end

    local storedEntry = CopyItemEntry(entry, {
        slot = tostring(slotName),
    }) or {
        class = entry.class,
        slot = tostring(slotName),
    }

    if not (StripWeaponEntry and select(1, StripWeaponEntry(ply, storedEntry))) then return end

    inv.weapons[slotName] = storedEntry
    SyncInventory(ply)
end)

local function ActivateSidearmHotbar(ply, inv)
    inv.weapons = inv.weapons or {}

    local primarySidearm = inv.weapons.sidearm
    local secondarySidearm = inv.weapons.sidearm2
    if not primarySidearm and not secondarySidearm then return false end

    local activeSlot = GetActiveWeaponSlot(ply, inv, "sidearm", "sidearm2")
    if activeSlot == "sidearm" and not secondarySidearm then
        return SelectHandsWeapon(ply)
    end
    if activeSlot == "sidearm2" and not primarySidearm then
        return SelectHandsWeapon(ply)
    end

    local targetSlot = nil

    if activeSlot == "sidearm" and secondarySidearm then
        targetSlot = "sidearm2"
    elseif activeSlot == "sidearm2" and primarySidearm then
        targetSlot = "sidearm"
    elseif tostring(ply.zscav_sidearm_last_slot or "") == "sidearm" and secondarySidearm then
        targetSlot = "sidearm2"
    elseif tostring(ply.zscav_sidearm_last_slot or "") == "sidearm2" and primarySidearm then
        targetSlot = "sidearm"
    else
        targetSlot = primarySidearm and "sidearm" or "sidearm2"
    end

    local entry = inv.weapons[targetSlot]
    if not entry then return false end

    local selected = SelectOrRestoreWeaponEntry(ply, entry)
    if selected then
        ply.zscav_sidearm_last_slot = targetSlot
    end

    return selected
end

local function MoveInventoryEntryBetweenPlayerGrids(ply, inv, fromGrid, fromIndex, targets)
    local fromList = inv and inv[fromGrid]
    local entry = fromList and fromIndex and fromList[fromIndex]
    if not entry then return false end

    local grids = ZSCAV:GetEffectiveGrids(inv)
    local blockedReason = nil

    for _, toGrid in ipairs(targets or {}) do
        if toGrid ~= fromGrid then
            local insertBlockReason = GetPlayerGridInsertBlockReason and GetPlayerGridInsertBlockReason(toGrid, entry) or nil
            if insertBlockReason then
                blockedReason = blockedReason or insertBlockReason
                continue
            end

            local toList = inv[toGrid]
            local grid = grids and grids[toGrid] or nil
            if toList and grid and (tonumber(grid.w) or 0) > 0 and (tonumber(grid.h) or 0) > 0 then
                local layout = getGridLayoutBlocks(inv, toGrid)
                local x, y, wasRotated = findFreeSpotAR(toList, tonumber(grid.w) or 0, tonumber(grid.h) or 0, entry.w, entry.h, layout)
                if x then
                    table.remove(fromList, fromIndex)

                    local entryW = wasRotated and entry.h or entry.w
                    local entryH = wasRotated and entry.w or entry.h
                    toList[#toList + 1] = CopyItemEntry(entry, {
                        x = x,
                        y = y,
                        w = entryW,
                        h = entryH,
                    })
                    SyncInventory(ply)
                    return true, toGrid
                end
            end
        end
    end

    return false, blockedReason or "No room in quick-move destinations."
end

local function ReadyGrenadeInventoryTarget(ply, inv, target)
    if not (IsValid(ply) and istable(inv) and istable(target)) then return false end

    local entry = target.entry
    if not entry and target.location == "grid" then
        local list = inv[target.grid]
        entry = list and target.index and list[target.index] or nil
    end

    local grenadeClass = entry and ZSCAV:ResolveGrenadeInventoryClass(entry) or nil
    if not grenadeClass then return false end

    local hasReadyGrenade = PlayerHasBackedGrenadeInventoryClass and PlayerHasBackedGrenadeInventoryClass(ply, grenadeClass)
    if target.location == "grid" and target.grid ~= "pocket" and target.grid ~= "vest" and not hasReadyGrenade then
        local moved, moveReason = MoveInventoryEntryBetweenPlayerGrids(ply, inv, target.grid, target.index, { "pocket", "vest" })
        if not moved then
            Notice(ply, moveReason or "Grenade must be in your pockets or rig.")
            return false
        end

        inv = ZSCAV:GetInventory(ply) or inv
    end

    if not (PlayerHasBackedGrenadeInventoryClass and PlayerHasBackedGrenadeInventoryClass(ply, grenadeClass)) then
        Notice(ply, "Grenade must be in your pockets or rig.")
        return false
    end

    ZSCAV:SyncGrenadeHotbar(ply)

    if not PlayerHasGrenadeClass(ply, grenadeClass) and not ForceGiveGrenadeHotbarWeapon(ply, grenadeClass) then
        ply:Give(grenadeClass)
    end

    timer.Simple(0, function()
        if not (IsValid(ply) and ZSCAV:IsActive() and ply:Alive()) then return end
        if PlayerHasGrenadeClass(ply, grenadeClass) then
            ply:SelectWeapon(grenadeClass)
        else
            Notice(ply, "Could not ready grenade.")
        end
    end)

    return true
end

local function ActivateGrenadeQuickslot(ply, inv, ref, target)
    local entry = target and target.entry or nil
    local grenadeClass = entry and ZSCAV:ResolveGrenadeInventoryClass(entry) or nil
    if not grenadeClass then return false end

    local activeWeapon = IsValid(ply) and ply:GetActiveWeapon() or NULL
    local activeBaseClass = IsValid(activeWeapon) and tostring(GetWeaponBaseClass(activeWeapon) or "") or ""
    if activeBaseClass ~= "" and activeBaseClass == grenadeClass then
        return SelectHandsWeapon(ply)
    end

    return ReadyGrenadeInventoryTarget(ply, inv, target)
end

local function ActivateQuickslotBinding(ply, inv, quickslotIndex)
    local ref = GetQuickslotTable(inv)[quickslotIndex]
    if not (istable(ref) and ref.class) then return false end

    local target = ResolveQuickslotBoundEntry(inv, ref)
    if not target then
        Notice(ply, "Quickslot item is no longer available.")
        return false
    end

    if target.location == "weapon" then
        if EntryMatchesActiveWeapon(ply, target.entry) then
            return SelectHandsWeapon(ply)
        end
        return SelectOrRestoreWeaponEntry(ply, target.entry)
    end

    if ZSCAV:ResolveGrenadeInventoryClass(target.entry) then
        return ActivateGrenadeQuickslot(ply, inv, ref, target)
    end

    local equipSlotType = tostring(ZSCAV:GetEquipWeaponSlot(target.entry.class) or "")
    if equipSlotType == "medical" then
        if target.location ~= "grid" or (target.grid ~= "pocket" and target.grid ~= "vest") then
            Notice(ply, "Medical hotkeys require the item to stay in pockets or tactical rig.")
            return false
        end

        -- Hand off to whichever addon owns the medical items. The handler
        -- picks an appropriate body part itself (most damaged, most bleed,
        -- etc.) so the player doesn't have to open the Health tab. Return
        -- contract mirrors ZSCAV_UseMedicalTarget:
        --   true   = consumed silently
        --   string = consumed, send the string as a Notice
        --   false  = consumed, no further handling
        --   nil    = no handler ran (fall through to default notice below)
        local handled = hook.Run("ZSCAV_UseMedicalQuickslot", ply, inv, {
            entry = target.entry,
            grid  = target.grid,
            index = target.index,
        })
        if handled == true then return true end
        if handled == false then return false end
        if isstring(handled) and handled ~= "" then
            Notice(ply, handled)
            return true
        end

        Notice(ply, "No quickslot handler is registered for " .. tostring(target.entry.class) .. ".")
        return false
    end

    if target.location == "grid" and equipSlotType ~= "" and equipSlotType ~= "grenade" and equipSlotType ~= "medical" then
        Actions.equip_weapon(ply, inv, {
            grid = target.grid,
            index = target.index,
        })
        return true
    end

    Notice(ply, "Quickslot item cannot be activated yet.")
    return false
end

local function ResolveQuickslotBindingSource(inv, args)
    if not (istable(inv) and istable(args)) then return nil end

    local fromQuickslot = NormalizeQuickslotIndex(args.from_quickslot)
    if fromQuickslot then
        local existing = GetQuickslotTable(inv)[fromQuickslot]
        if existing and existing.class then
            return existing, {
                preferred_grid = tostring(existing.preferred_grid or ""),
                preferred_slot = tostring(existing.preferred_slot or ""),
                from_quickslot = fromQuickslot,
            }
        end
    end

    local slot = tostring(args.from_slot or args.slot or "")
    if slot ~= "" then
        inv.weapons = inv.weapons or {}
        local entry = inv.weapons[slot]
        if entry and entry.class then
            return entry, {
                preferred_slot = slot,
            }
        end
    end

    local grid = tostring(args.from_grid or args.grid or "")
    local index = tonumber(args.from_index or args.index)
    local list = inv[grid]
    local entry = list and index and list[index]
    if entry and entry.class then
        return entry, {
            preferred_grid = grid,
        }
    end

    return nil
end

local function ResolveWeaponActionEntry(inv, args)
    if not istable(inv) or not istable(args) then return nil end

    inv.weapons = inv.weapons or {}
    local weaponUID = tostring(args.weapon_uid or "")
    if weaponUID ~= "" then
        for slotName, entry in pairs(inv.weapons) do
            if entry and tostring(entry.weapon_uid or "") == weaponUID then
                return entry, inv.weapons, slotName, true, slotName
            end
        end

        for _, gridName in ipairs({ "vest", "backpack", "pocket", "secure" }) do
            local list = inv[gridName]
            if istable(list) then
                for index, entry in ipairs(list) do
                    if entry and tostring(entry.weapon_uid or "") == weaponUID then
                        return entry, list, index, false, gridName
                    end
                end
            end
        end
    end

    local slot = tostring(args.slot or "")
    if slot ~= "" then
        local entry = inv.weapons[slot]
        if entry and entry.class then
            return entry, inv.weapons, slot, true, slot
        end
    end

    local grid = tostring(args.grid or "")
    local index = tonumber(args.index)
    if grid == "" or not index then return nil end

    local list = inv[grid]
    local entry = list and list[index]
    if entry and entry.class then
        return entry, list, index, false, grid
    end

    return nil
end

local function ResolveMedicalTargetAction(inv, args)
    if not (istable(inv) and istable(args)) then return nil end

    local partID = tostring(args.body_part or ""):lower()
    if partID == "" then return nil end

    local partDef = ZSCAV.GetHealthPartDef and ZSCAV:GetHealthPartDef(partID) or nil
    if not partDef then return nil end

    local grid = tostring(args.from_grid or args.grid or "")
    local index = tonumber(args.from_index or args.index)
    if grid == "" or not index then return nil end

    local list = inv[grid]
    local entry = list and list[index]
    if not (istable(entry) and entry.class) then return nil end
    if tostring(ZSCAV:GetEquipWeaponSlot(entry.class) or "") ~= "medical" then return nil end

    return {
        part = partDef,
        grid = grid,
        index = index,
        entry = entry,
        profile = ZSCAV.GetMedicalUseProfile and ZSCAV:GetMedicalUseProfile(entry.class) or nil,
    }
end

local function ResolveMedicalActionPatient(ply)
    if not IsValid(ply) then return nil end

    local chain = ply.zscav_container_chain
    local rootUID = istable(chain) and tostring(chain[1] or "") or ""
    if rootUID == "" then return ply end

    local record = GetCorpseContainer(rootUID)
    if not (istable(record) and record.live_owner == true and tostring(record.class or "") == LIVE_LOOT_CONTAINER_CLASS) then
        return ply
    end

    local owner = record.owner
    if not (IsValid(owner) and owner:IsPlayer() and owner:Alive()) then
        return ply
    end

    return owner
end

local ActionResolverHelpers = {}

function ActionResolverHelpers.ResolveAttachmentActionEntry(inv, args)
    if not istable(inv) or not istable(args) then return nil end

    local grid = tostring(args.attachment_grid or "")
    local index = tonumber(args.attachment_index)
    if grid == "" or not index then return nil end

    local list = inv[grid]
    local entry = list and list[index]
    if not (istable(entry) and ZSCAV:IsAttachmentItemClass(entry)) then
        return nil
    end

    return entry, list, index, grid
end

function ActionResolverHelpers.AttachmentInstallRequiresPlayerInventory(args)
    if not istable(args) then return false end
    if tostring(args.from_uid or "") ~= "" then return true end
    if tostring(args.target_uid or args.to_uid or "") ~= "" then return true end
    return false
end

local ATTACHMENT_SOURCE_GRIDS = { "vest", "backpack", "pocket", "secure" }

function ActionResolverHelpers.FindLooseAttachmentInEntryList(list, attKey, state)
    if not istable(list) then return nil end

    state = state or {}
    local seenUIDs = state.seenUIDs or {}

    for index, entry in ipairs(list) do
        if not istable(entry) then
            continue
        end

        if ZSCAV:IsAttachmentItemClass(entry) and ZSCAV:NormalizeAttachmentKey(entry) == attKey then
            return {
                list = list,
                index = index,
                entry = entry,
                gridName = tostring(state.gridName or ""),
                containerUID = tostring(state.currentUID or ""),
                containerClass = tostring(state.currentClass or ""),
                containerLive = state.currentLive == true,
            }
        end

        local uid = tostring(entry.uid or "")
        if uid ~= "" and not seenUIDs[uid] then
            seenUIDs[uid] = true

            local bag = ZSCAV:LoadBag(uid)
            if istable(bag) and istable(bag.contents) then
                local found = ActionResolverHelpers.FindLooseAttachmentInEntryList(bag.contents, attKey, {
                    seenUIDs = seenUIDs,
                    currentUID = uid,
                    currentClass = tostring(bag.class or entry.class or ""),
                    currentLive = false,
                })
                if found then
                    return found
                end
            end
        end
    end

    return nil
end

function ActionResolverHelpers.CommitAttachmentSourceMutation(ply, inv, source)
    if not (IsValid(ply) and istable(source)) then return end

    local containerUID = tostring(source.containerUID or "")
    if containerUID ~= "" then
        SaveContainerContents(ply, containerUID, source.containerClass, source.list)
        if source.containerLive then
            SyncInventory(ply)
        end
        if ContainerInChain and ContainerInChain(ply, containerUID) then
            SendContainerSnapshotForUID(ply, containerUID)
        end
        return
    end

    if tostring(source.gridName or "") ~= "" then
        SyncInventory(ply)
        return
    end

    if istable(inv) then
        SyncInventory(ply)
    end
end

function ActionResolverHelpers.ResolveExactContainerAttachmentSource(ply, args)
    if not (IsValid(ply) and istable(args)) then return nil end

    local fromUID = tostring(args.from_uid or "")
    if fromUID == "" or not ContainerInChain(ply, fromUID) then return nil end

    local _, _, bag = ContainerSizeFor(ply, fromUID)
    if not bag then return nil end

    local index = tonumber(args.from_index)
    local entry = index and bag.contents and bag.contents[index]
    if not (istable(entry) and ZSCAV:IsAttachmentItemClass(entry)) then
        return nil
    end

    return {
        list = bag.contents,
        index = index,
        entry = entry,
        containerUID = fromUID,
        containerClass = tostring(bag.class or ""),
        containerLive = bag._live == true,
    }
end

function ActionResolverHelpers.ResolveExactInventoryAttachmentSource(inv, args)
    local entry, list, index, grid = ActionResolverHelpers.ResolveAttachmentActionEntry(inv, args)
    if not entry then return nil end

    return {
        list = list,
        index = index,
        entry = entry,
        gridName = grid,
    }
end

function ActionResolverHelpers.ResolveFallbackAttachmentSource(ply, inv, args)
    if not (IsValid(ply) and istable(args)) then return nil end

    local attKey = ZSCAV:NormalizeAttachmentKey(args.attachment_key)
    if attKey == "" then return nil end

    local orderedUIDs = {}
    local queued = {}
    local preferredUID = tostring(args.from_uid or "")

    local function queueUID(uid)
        uid = tostring(uid or "")
        if uid == "" or queued[uid] then return end
        if not ContainerInChain(ply, uid) then return end
        queued[uid] = true
        orderedUIDs[#orderedUIDs + 1] = uid
    end

    queueUID(preferredUID)
    for _, uid in ipairs(ply.zscav_container_chain or {}) do
        queueUID(uid)
    end

    for _, uid in ipairs(orderedUIDs) do
        local _, _, bag = ContainerSizeFor(ply, uid)
        if istable(bag) and istable(bag.contents) then
            local found = ActionResolverHelpers.FindLooseAttachmentInEntryList(bag.contents, attKey, {
                seenUIDs = { [uid] = true },
                currentUID = uid,
                currentClass = tostring(bag.class or ""),
                currentLive = bag._live == true,
            })
            if found then
                return found
            end
        end
    end

    if not istable(inv) then return nil end

    local seenUIDs = {}
    for _, gridName in ipairs(ATTACHMENT_SOURCE_GRIDS) do
        local found = ActionResolverHelpers.FindLooseAttachmentInEntryList(inv[gridName], attKey, {
            seenUIDs = seenUIDs,
            gridName = gridName,
        })
        if found then
            return found
        end
    end

    return nil
end

function ActionResolverHelpers.ResolveAttachmentInstallSource(ply, inv, args)
    if not (IsValid(ply) and istable(inv) and istable(args)) then return nil end

    local source = ActionResolverHelpers.ResolveExactContainerAttachmentSource(ply, args)
        or ActionResolverHelpers.ResolveExactInventoryAttachmentSource(inv, args)
        or ActionResolverHelpers.ResolveFallbackAttachmentSource(ply, inv, args)
    if not (istable(source) and istable(source.entry) and source.entry.class) then
        return nil
    end

    local cachedAttachment = CopyItemEntry(source.entry) or { class = source.entry.class }
    local sourceIndex = tonumber(source.index) or 0

    local function resolveLiveList()
        if tostring(source.containerUID or "") ~= "" then
            local _, _, bag = ContainerSizeFor(ply, source.containerUID)
            if not bag then return nil end

            source.list = bag.contents
            source.containerClass = tostring(bag.class or source.containerClass or "")
            source.containerLive = bag._live == true
            return bag.contents
        end

        if tostring(source.gridName or "") ~= "" then
            inv[source.gridName] = inv[source.gridName] or source.list or {}
            source.list = inv[source.gridName]
            return source.list
        end

        return source.list
    end

    return cachedAttachment,
        function()
            local liveList = resolveLiveList()
            if not istable(liveList) or sourceIndex < 1 then
                return false
            end

            local liveEntry = liveList[sourceIndex]
            if not (istable(liveEntry) and liveEntry.class) then
                return false
            end

            table.remove(liveList, sourceIndex)
            ActionResolverHelpers.CommitAttachmentSourceMutation(ply, inv, source)
            return true
        end,
        function()
            local liveList = resolveLiveList()
            if not istable(liveList) then return end

            local restoreEntry = CopyItemEntry(cachedAttachment) or { class = cachedAttachment.class }
            local restoreIndex = math.Clamp(sourceIndex, 1, #liveList + 1)
            table.insert(liveList, restoreIndex, restoreEntry)
            ActionResolverHelpers.CommitAttachmentSourceMutation(ply, inv, source)
        end
end

function ActionResolverHelpers.ResolveContainerWeaponActionEntry(ply, args)
    if not (IsValid(ply) and istable(args)) then return nil end

    local weaponUID = tostring(args.weapon_uid or "")
    local targetUID = tostring(args.target_uid or args.to_uid or "")
    local targetIndex = tonumber(args.target_index or args.to_index)

    local function matchWeaponEntry(entry)
        if not (istable(entry) and entry.class) then return false end
        if weaponUID ~= "" and tostring(entry.weapon_uid or "") ~= weaponUID then
            return false
        end
        return true
    end

    local function resolveFromUID(uid)
        if uid == "" or not ContainerInChain(ply, uid) then return nil end

        local _, _, bag = ContainerSizeFor(ply, uid)
        if not bag then return nil end

        local list = bag.contents or {}
        if targetIndex then
            local entry = list[targetIndex]
            if matchWeaponEntry(entry) then
                return entry, list, targetIndex, uid, bag
            end
        end

        if weaponUID ~= "" then
            for index, entry in ipairs(list) do
                if matchWeaponEntry(entry) then
                    return entry, list, index, uid, bag
                end
            end
        end

        return nil
    end

    if targetUID ~= "" then
        local entry, list, index, uid, bag = resolveFromUID(targetUID)
        if entry then
            return entry, list, index, uid, bag
        end
    end

    if weaponUID ~= "" then
        for _, uid in ipairs(ply.zscav_container_chain or {}) do
            if uid ~= targetUID then
                local entry, list, index, foundUID, bag = resolveFromUID(uid)
                if entry then
                    return entry, list, index, foundUID, bag
                end
            end
        end
    end

    return nil
end

function ZSCAV.ResolveWeaponInstallTarget(ply, inv, args)
    local entry, list, key, isSlot = ResolveWeaponActionEntry(inv, args)
    if entry then
        return {
            entry = entry,
            list = list,
            key = key,
            isSlot = isSlot == true,
            isContainer = false,
        }
    end

    local cEntry, cList, cIndex, cUID, cBag = ActionResolverHelpers.ResolveContainerWeaponActionEntry(ply, args)
    if cEntry then
        return {
            entry = cEntry,
            list = cList,
            key = cIndex,
            isSlot = false,
            isContainer = true,
            containerUID = cUID,
            containerBag = cBag,
        }
    end

    return nil
end

function ZSCAV.EnsureWeaponEntryAttachments(entry)
    if not (istable(entry) and entry.class) then return nil end

    EnsureWeaponEntryRuntime(entry)
    entry.weapon_state = ZSCAV:CopyWeaponState(entry.weapon_state)
    entry.weapon_state.attachments = ZSCAV:NormalizeWeaponAttachments(entry.class, entry.weapon_state.attachments)
    return entry.weapon_state.attachments
end

function ZSCAV.WeaponAllowsAttachment(className, placement, attKey)
    local optionsByPlacement = ZSCAV:BuildWeaponAttachmentOptions(className)
    for _, option in ipairs(optionsByPlacement[tostring(placement or "")] or {}) do
        if ZSCAV:NormalizeAttachmentKey(option.key) == ZSCAV:NormalizeAttachmentKey(attKey) then
            return true
        end
    end

    return false
end

function ZSCAV.InsertItemIntoGrids(inv, item, order)
    item = CopyItemEntry(item)
    if not item or not item.class then return false end

    local class = GetWeaponBaseClass(item.class)
    local uid = item.uid
    item.class = class

    local ok = ZSCAV:CanCarryMore(inv, item, uid)
    if not ok then return false, "weight" end

    local size = ZSCAV:GetItemSize(item)
    local grids = ZSCAV:GetEffectiveGrids(inv)

    for _, gridName in ipairs(order or routeOrder(class)) do
        local canStoreInGrid = true
        if CanStoreItemInPlayerGrid then
            canStoreInGrid = select(1, CanStoreItemInPlayerGrid(gridName, item))
        end

        if not canStoreInGrid then
            continue
        end

        local grid = grids[gridName]
        local canFitGrid = grid and (
            (grid.w >= size.w and grid.h >= size.h)
            or (grid.w >= size.h and grid.h >= size.w)
        )
        if canFitGrid then
            local list = inv[gridName] or {}
            inv[gridName] = list
            local layoutBlocks = getGridLayoutBlocks and getGridLayoutBlocks(inv, gridName) or nil
            local x, y, wasRotated = findFreeSpotAR(list, grid.w, grid.h, size.w, size.h, layoutBlocks)
            if x then
                list[#list + 1] = CopyItemEntry(item, {
                    x = x,
                    y = y,
                    w = wasRotated and size.h or size.w,
                    h = wasRotated and size.w or size.h,
                })
                return true, gridName
            end
        end
    end

    return false, "space"
end

function ZSCAV.StashAttachmentItem(inv, attKey)
    local className = ZSCAV:GetAttachmentItemClass(attKey)
    if className == "" then return true end
    return ZSCAV.InsertItemIntoGrids(inv, { class = className }, ATTACHMENT_INSERT_ORDER)
end

function ZSCAV.ApplyEntryStateToHeldWeapon(ply, entry)
    if not (IsValid(ply) and istable(entry) and entry.class and ZSCAV.FindHeldWeaponForEntry) then
        return
    end

    local wep = ZSCAV:FindHeldWeaponForEntry(ply, entry)
    if not IsValid(wep) then return end

    EnsureWeaponEntryRuntime(entry, wep)
    ZSCAV:ApplyWeaponState(ply, wep, entry)
end

function ZSCAV.SyncResolvedWeaponContainerTarget(ply, target)
    if not (istable(target) and target.isContainer and target.containerUID and target.containerBag) then
        return
    end

    SaveContainerContents(ply, target.containerUID, target.containerBag.class, target.containerBag.contents)
    SendContainerSnapshotForUID(ply, target.containerUID)
end

function ZSCAV.CommitResolvedWeaponTargetState(ply, target, entry)
    if not (istable(target) and istable(target.list) and target.key ~= nil and istable(entry) and entry.class) then
        return entry
    end

    local overrides = nil
    if target.isSlot and tostring(target.key or "") ~= "" then
        overrides = {
            slot = tostring(target.key),
        }
    end

    local committedEntry = CopyItemEntry(entry, overrides) or entry
    target.list[target.key] = committedEntry
    target.entry = committedEntry

    ZSCAV.ApplyEntryStateToHeldWeapon(ply, committedEntry)
    ZSCAV.SyncResolvedWeaponContainerTarget(ply, target)
    SyncInventory(ply)

    return committedEntry
end

function ZSCAV.InstallAttachmentIntoWeaponEntry(ply, inv, args, attachmentEntry, consumeAttachment, restoreAttachment)
    if not (istable(attachmentEntry) and attachmentEntry.class) then
        Notice(ply, "Attachment item not found.")
        return false
    end

    if consumeAttachment and consumeAttachment() == false then
        Notice(ply, "Attachment item not found.")
        return false
    end

    local target = ZSCAV.ResolveWeaponInstallTarget(ply, inv, args)
    if not target then
        if restoreAttachment then
            restoreAttachment()
        end
        Notice(ply, "Weapon target not found.")
        return false
    end

    local entry = target.entry
    local placement = tostring(args.placement or ""):lower()
    local attachments = ZSCAV.EnsureWeaponEntryAttachments(entry)
    if placement == "" or not attachments then
        if restoreAttachment then
            restoreAttachment()
        end
        Notice(ply, "Weapon target not found.")
        return false
    end

    local attKey = ZSCAV:NormalizeAttachmentKey(attachmentEntry)
    if attKey == "" or not ZSCAV.WeaponAllowsAttachment(entry.class, placement, attKey) then
        if restoreAttachment then
            restoreAttachment()
        end
        Notice(ply, "That attachment does not fit this slot.")
        return false
    end

    local currentKey = ZSCAV:NormalizeAttachmentKey(attachments[placement])
    if currentKey == attKey then
        if restoreAttachment then
            restoreAttachment()
        end
        Notice(ply, ZSCAV:GetAttachmentName(attKey) .. " is already installed.")
        return false
    end

    if currentKey ~= "" and not ZSCAV:CanRemoveWeaponAttachment(entry.class, placement) then
        if restoreAttachment then
            restoreAttachment()
        end
        Notice(ply, "That attachment slot cannot be modified.")
        return false
    end

    if currentKey ~= "" then
        local ok = ZSCAV.StashAttachmentItem(inv, currentKey)
        if not ok then
            if restoreAttachment then
                restoreAttachment()
            end
            Notice(ply, "No room to swap the current attachment.")
            return false
        end
    end

    attachments[placement] = attKey
    entry.weapon_state.attachments = ZSCAV:NormalizeWeaponAttachments(entry.class, attachments)
    ZSCAV.CommitResolvedWeaponTargetState(ply, target, entry)

    return true
end

function ZSCAV.DropWeaponActionEntry(ply, inv, args)
    local target = ZSCAV.ResolveWeaponInstallTarget(ply, inv, args)
    if not target then return false end

    local entry = target.entry
    local list = target.list
    local key = target.key
    local isSlot = target.isSlot

    local droppedEntry = CopyItemEntry(entry) or { class = entry.class }
    if isSlot then
        StripWeaponEntry(ply, droppedEntry)
        list[key] = nil
    else
        table.remove(list, key)
    end

    ZSCAV.SyncResolvedWeaponContainerTarget(ply, target)
    SyncInventory(ply)
    SpawnDroppedClass(ply, droppedEntry.class, droppedEntry.uid, droppedEntry)
    return true
end

function Actions.drop(ply, inv, args)
    local list  = inv[args.grid]
    local entry = list and list[args.index]
    if not entry then return end
    if IsSecureClass(entry.class) then
        Notice(ply, "Secure containers cannot be dropped.")
        return
    end

    if IsVendorTicketEntry(entry) then
        if args.confirm_ticket_destroy ~= true then
            Notice(ply, "Vendor tickets must be discarded from their confirmation prompt.")
            return
        end

        table.remove(list, args.index)
        SyncInventory(ply)
        Notice(ply, "Vendor ticket discarded.")
        return
    end

    table.remove(list, args.index)
    SyncInventory(ply)
    -- Bag items: spawn the entity with the same UID so contents persist.
    SpawnDroppedClass(ply, entry.class, entry.uid, entry)
end

function Actions.move(ply, inv, args)
    local fromList = inv[args.from_grid]
    local toList   = inv[args.to_grid]
    if not fromList or not toList then return end

    local entry = fromList[args.from_index]
    if not entry then return end

    if args.to_grid ~= args.from_grid and GetPlayerGridInsertBlockReason then
        local blockedReason = GetPlayerGridInsertBlockReason(args.to_grid, entry)
        if blockedReason then
            Notice(ply, blockedReason)
            return
        end
    end

    local grids  = ZSCAV:GetEffectiveGrids(inv)
    local target = grids[args.to_grid]
    local targetLayout = getGridLayoutBlocks(inv, args.to_grid)
    local sourceLayout = getGridLayoutBlocks(inv, args.from_grid)
    if not target then return end

    -- Client may report a rotated shape (R pressed mid-drag). Accept
    -- only if the rotation is genuine (swap of the original w/h) so a
    -- malicious payload can't fabricate arbitrary footprints.
    local desiredW, desiredH = entry.w, entry.h
    if args.rotated and entry.w ~= entry.h then
        desiredW, desiredH = entry.h, entry.w
    end

    local function resolveMoveFootprint(listRef, ignoreIdx, layout)
        if fitsAt(listRef, args.x, args.y, desiredW, desiredH,
            target.w, target.h, ignoreIdx, layout) then
            return desiredW, desiredH
        end
        if desiredW ~= desiredH and fitsAt(listRef, args.x, args.y, desiredH, desiredW,
            target.w, target.h, ignoreIdx, layout) then
            return desiredH, desiredW
        end
        return nil, nil
    end

    if args.from_grid == args.to_grid then
        local fw, fh = resolveMoveFootprint(fromList, args.from_index, sourceLayout)
        if not fw then return end
        entry.x, entry.y = args.x, args.y
        entry.w, entry.h = fw, fh
        SyncInventory(ply)
        return
    end

    local fw, fh = resolveMoveFootprint(toList, nil, targetLayout)
    if not fw then return end
    table.remove(fromList, args.from_index)
    entry.x, entry.y = args.x, args.y
    entry.w, entry.h = fw, fh
    toList[#toList + 1] = entry
    SyncInventory(ply)
end

-- Rotate an item already placed in a grid (no drag). Swaps w/h and
-- validates the new footprint still fits at the same x,y. Square items
-- are no-ops.
function Actions.rotate(ply, inv, args)
    local list  = inv[args.grid]
    local entry = list and list[args.index]
    if not entry then return end
    if entry.w == entry.h then return end

    local grids  = ZSCAV:GetEffectiveGrids(inv)
    local target = grids[args.grid]
    local layout = getGridLayoutBlocks(inv, args.grid)
    if not target then return end

    if not fitsAt(list, entry.x, entry.y, entry.h, entry.w,
            target.w, target.h, args.index, layout) then
        Notice(ply, "No room to rotate here.")
        return
    end
    entry.w, entry.h = entry.h, entry.w
    SyncInventory(ply)
end

function Actions.equip_gear(ply, inv, args)
    local list  = inv[args.grid]
    local entry = list and list[args.index]
    if not entry then return end
    local def = ZSCAV:GetGearDef(entry.class)
    if not def then Notice(ply, "Not a gear item.") return end

    inv.gear = inv.gear or {}
    if inv.gear[def.slot] then
        Notice(ply, "Slot occupied: " .. def.slot)
        return
    end

    -- Backpack-class: route through the SQL bag transfer flow so contents
    -- come along when you put the bag on.
    if def.slot == "backpack" then
        local class, uid = entry.class, entry.uid
        table.remove(list, args.index)
        BackpackEquip(ply, inv, class, uid)
        return
    end

    -- Vest with compartment: route through VestEquip so inv.vest is loaded
    -- from SQL. Generate a UID now if the item doesn't already have one.
    if (def.slot == "tactical_rig" or def.slot == "vest") and def.compartment then
        local class = entry.class
        local uid   = entry.uid
        if not uid or uid == "" then uid = ZSCAV:CreateBag(class) end
        if ZSCAV:IsArmorEntityClass(class) then
            local ok = hg and hg.AddArmor and hg.AddArmor(ply, class)
            if not ok then
                Notice(ply, "Could not equip armor: " .. tostring(class))
                return
            end
        end
        table.remove(list, args.index)
        VestEquip(ply, inv, class, uid)
        return
    end

    if ZSCAV:IsArmorEntityClass(entry.class) then
        local ok = hg and hg.AddArmor and hg.AddArmor(ply, entry.class)
        if not ok then
            Notice(ply, "Could not equip armor: " .. tostring(entry.class))
            return
        end
    end

    table.remove(list, args.index)
    local equipUID = entry.uid
    if def.secure == true and (not equipUID or equipUID == "") then
        equipUID = ZSCAV:CreateBag(entry.class)
    end
    inv.gear[def.slot] = { class = entry.class, uid = equipUID, slot = def.slot }
    if def.secure == true then
        local loaded = ZSCAV:LoadBag(tostring(equipUID or ""))
        inv.secure = (loaded and loaded.contents) or {}
        local sid = tostring(ply:SteamID64() or "")
        local st = GetPlayerSecureState(sid)
        if st then
            st.issued = 1
            st.status = "equipped"
            st.class = tostring(entry.class)
            st.uid = tostring(equipUID or "")
            SavePlayerSecureState(st)
        end
    end
    SyncInventory(ply)
end

function Actions.unequip_gear(ply, inv, args)
    inv.gear    = inv.gear or {}
    local entry = inv.gear[args.slot]
    if not entry then return end

    if args.slot == "secure_container" then
        if not IsSecureClass(entry.class) then
            Notice(ply, "Only secure containers can use this slot.")
            return
        end

        local secureUID = tostring(entry.uid or "")
        if secureUID == "" then
            secureUID = tostring(ZSCAV:CreateBag(entry.class) or "")
        end
        if secureUID == "" then
            Notice(ply, "Could not allocate secure container storage.")
            return
        end
        if not ZSCAV:SaveBag(secureUID, entry.class, inv.secure or {}) then
            Notice(ply, "Could not save secure container.")
            return
        end

        local sid = tostring(ply:SteamID64() or "")
        local stashUID, stashErr
        if ZSCAV.GetAccessiblePlayerStashUID then
            stashUID, stashErr = ZSCAV:GetAccessiblePlayerStashUID(ply)
        else
            stashUID, stashErr = ZSCAV:GetCanonicalPlayerStashUID(sid, true)
        end
        if tostring(stashErr or "") == "stash_loading" then
            Notice(ply, "Stash is still loading. Try again in a moment.")
            return
        end
        stashUID = tostring(stashUID or "")
        if stashUID == "" then
            Notice(ply, "Could not resolve your stash.")
            return
        end

        local stash = ZSCAV:LoadBag(stashUID)
        if not stash then
            Notice(ply, "Stash is not ready yet.")
            return
        end

        local sw, sh = ZSCAV:GetContainerGridSize(stash.class)
        sw, sh = tonumber(sw) or 4, tonumber(sh) or 4

        local sz = ZSCAV:GetItemSize(entry)
        local iw, ih = tonumber(sz.w) or 2, tonumber(sz.h) or 2
        local x, y, wasRotated = findFreeSpotAR(stash.contents or {}, sw, sh, iw, ih)
        if not x then
            Notice(ply, "No room in stash for secure container.")
            return
        end

        local ew = wasRotated and ih or iw
        local eh = wasRotated and iw or ih
        stash.contents = stash.contents or {}
        stash.contents[#stash.contents + 1] = CopyItemEntry(entry, {
            x = x,
            y = y,
            w = ew,
            h = eh,
            uid = secureUID,
            slot = tostring(args.slot or "secure_container"),
        })
        ZSCAV:SaveBag(stashUID, stash.class, stash.contents)

        inv.gear[args.slot] = nil
        inv.secure = {}

        local st = GetPlayerSecureState(sid)
        if st then
            st.issued = 1
            st.status = "stash"
            st.class = tostring(entry.class)
            st.uid = tostring(secureUID)
            SavePlayerSecureState(st)
        end

        SyncInventory(ply)
        return
    end

    -- Backpack-class: snapshot worn contents into the bag's SQL row and
    -- spawn the bag entity carrying its UID. Pocket items that still fit
    -- the post-removal grid stay with the player.
    if args.slot == "backpack" then
        BackpackUnequip(ply, inv)
        return
    end

    -- Vest with compartment: save vest contents and spawn vest entity.
    if args.slot == "tactical_rig" or args.slot == "vest" then
        local def = entry and ZSCAV:GetGearDef(entry.class)
        if def and def.compartment then
            VestUnequip(ply, inv)
            return
        end
    end

    if ZSCAV:IsArmorEntityClass(entry.class) then
        local removed = ZSCAV:RemoveArmorNoDrop(ply, entry.class)
        if not removed then
            -- If the armor is already absent on the player (e.g. removed by
            -- external Drop Equipment path), treat this as a desync and clear
            -- only the slot -- do not spawn/stash a duplicate item.
            local armorKey = tostring(ZSCAV:GetArmorEntityName(entry.class) or ""):lower()
            local placement = ZSCAV:GetArmorPlacement(entry.class)
            ply.armors = ply.armors or ply:GetNetVar("Armor", {}) or {}
            local stillWorn = placement and tostring(ply.armors[placement] or ""):lower() == armorKey
            if not stillWorn then
                inv.gear[args.slot] = nil
                SyncInventory(ply)
                Notice(ply, "Armor desync fixed: " .. tostring(entry.class))
                return
            end

            Notice(ply, "Could not remove armor cleanly: " .. tostring(entry.class))
            return
        end
    end

    inv.gear[args.slot] = nil
    -- Recompute grids AFTER removal so we honour the newly shrunk space;
    -- evict items that no longer fit.
    local grids = ZSCAV:GetEffectiveGrids(inv)
    for _, gn in ipairs({ "backpack", "pocket" }) do
        local g    = grids[gn]
        local list = inv[gn]
        local i = 1
        while i <= #list do
            local it = list[i]
            if g.w == 0 or g.h == 0 or it.x + it.w > g.w or it.y + it.h > g.h then
                SpawnDroppedClass(ply, it.class, it.uid, it)
                table.remove(list, i)
                Notice(ply, "Overflow: " .. it.class .. " dropped.")
            else
                i = i + 1
            end
        end
    end

    SyncInventory(ply)
    StashOrDrop(ply, CopyItemEntry(entry, { slot = tostring(args.slot or "") }))
end

function Actions.equip_weapon(ply, inv, args)
    local list  = inv[args.grid]
    local entry = list and list[args.index]
    if not entry then return end

    if ZSCAV:ResolveGrenadeInventoryClass(entry) then
        return ReadyGrenadeInventoryTarget(ply, inv, {
            entry = entry,
            location = "grid",
            grid = tostring(args.grid or ""),
            index = tonumber(args.index),
        })
    end

    local slot = ResolveWeaponEquipSlot(inv, entry.class)
    if not slot then
        Notice(ply, "Not equippable: " .. entry.class)
        return
    end

    inv.weapons = inv.weapons or {}
    if inv.weapons[slot] then
        Notice(ply, "Weapon slot occupied: " .. slot .. " (right-click to unholster)")
        return
    end

    -- Sanity: weapon must actually be installed on the server.
    if not (weapons.GetStored(entry.class) or scripted_ents.GetStored(entry.class)) then
        Notice(ply, "Server has no class: " .. entry.class)
        return
    end

    table.remove(list, args.index)
    local equippedEntry = CopyItemEntry(entry, { slot = slot }) or { class = entry.class, slot = slot }
    EnsureWeaponEntryRuntime(equippedEntry)
    inv.weapons[slot] = equippedEntry

    local wepEnt = GiveWeaponInstance(ply, equippedEntry)
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        local selected = SelectWeaponEntry and select(1, SelectWeaponEntry(ply, equippedEntry))
        if selected then
            return
        else
            Notice(ply, "Equip failed: another addon blocked it.")
            -- Roll back so the inventory state isn't desynced from reality.
            inv.weapons[slot] = nil
            ZSCAV:TryAddItemEntry(ply, equippedEntry)
        end
    end)

    SyncInventory(ply)
end

function Actions.use_medical_target(ply, inv, args)
    local target = ResolveMedicalTargetAction(inv, args)
    if not target then
        Notice(ply, "Medical item not found.")
        return
    end

    target.patient = ResolveMedicalActionPatient(ply)

    local profile = target.profile
    if not (istable(profile) and profile.health_tab == true) then
        Notice(ply, "That medical item has no ZScav health-tab profile yet.")
        return
    end

    if ZSCAV.DoesMedicalProfileSupportHealthPart and not ZSCAV:DoesMedicalProfileSupportHealthPart(profile, target.part.id) then
        Notice(ply, "That medical item cannot treat " .. string.lower(tostring(target.part.label or target.part.id)) .. ".")
        return
    end

    local handled = hook.Run("ZSCAV_UseMedicalTarget", ply, inv, target, profile, args)
    if handled == true or handled == false then
        return
    end

    if isstring(handled) and handled ~= "" then
        Notice(ply, handled)
        return
    end

    Notice(ply, "No ZScav medical handler is registered for " .. tostring(target.entry.class) .. ".")
end

function Actions.unequip_weapon(ply, inv, args)
    inv.weapons = inv.weapons or {}
    local entry = inv.weapons[args.slot]
    if not entry then return end

    local storedEntry = CopyItemEntry(entry, { slot = tostring(args.slot or "") }) or { class = entry.class, slot = tostring(args.slot or "") }
    StripWeaponEntry(ply, storedEntry)
    inv.weapons[args.slot] = nil
    SyncInventory(ply)
    StashOrDrop(ply, storedEntry)
end

function Actions.unequip_slot_to_grid(ply, inv, args)
    local s = SlotEntryForDrag(inv, args.kind, args.slot)
    if not s then return end

    local toGrid = tostring(args.to_grid or "")
    local toList = inv[toGrid]
    if not toList then return end

    if GetPlayerGridInsertBlockReason then
        local blockedReason = GetPlayerGridInsertBlockReason(toGrid, s)
        if blockedReason then
            Notice(ply, blockedReason)
            return
        end
    end

    if s.kind == "gear" and s.slot == "secure_container" then
        Notice(ply, "Secure container can only be moved to stash.")
        return
    end

    if s.kind == "gear" and s.slot == "backpack" and toGrid == "backpack" then
        Notice(ply, "Cannot move a backpack into its own storage.")
        return
    end

    if s.kind == "gear" and (s.slot == "tactical_rig" or s.slot == "vest") and toGrid == "vest" then
        local rigDef = ZSCAV:GetGearDef(s.class)
        if rigDef and rigDef.compartment then
            Notice(ply, "Cannot move a rig into its own storage.")
            return
        end
    end

    local x = math.floor(tonumber(args.x) or 0)
    local y = math.floor(tonumber(args.y) or 0)
    local w, h = s.w, s.h
    if args.rotated and w ~= h then w, h = h, w end

    local grids = ZSCAV:GetEffectiveGrids(inv)
    local target = grids[toGrid]
    local layout = getGridLayoutBlocks(inv, toGrid)
    if not target then
        Notice(ply, "No room in target grid.")
        return
    end

    local px, py, pw, ph = x, y, w, h
    if not fitsAt(toList, px, py, pw, ph, target.w, target.h, nil, layout) then
        if pw ~= ph and fitsAt(toList, px, py, ph, pw, target.w, target.h, nil, layout) then
            pw, ph = ph, pw
        else
            local fx, fy, wasRotated = findFreeSpotAR(toList, target.w, target.h, w, h, layout)
            if not fx then
                Notice(ply, "No room in target grid.")
                return
            end
            px, py = fx, fy
            pw = wasRotated and h or w
            ph = wasRotated and w or h
        end
    end

    if not fitsAt(toList, px, py, pw, ph, target.w, target.h, nil, layout) then
        Notice(ply, "No room in target grid.")
        return
    end

    if s.kind == "gear" and s.slot == "backpack" then
        local bpUID = tostring(s.uid or "")
        if bpUID == "" then
            bpUID = tostring(ZSCAV:CreateBag(s.class) or "")
        end
        if bpUID == "" then
            Notice(ply, "Could not allocate backpack storage.")
            return
        end

        local packed = SerializeWornBackpack(inv)
        if not ZSCAV:SaveBag(bpUID, s.class, packed) then
            Notice(ply, "Could not save backpack contents.")
            return
        end

        inv.gear.backpack = nil
        inv.backpack = {}

        toList[#toList + 1] = CopyItemEntry(s, {
            uid = bpUID,
            x = px,
            y = py,
            w = pw,
            h = ph,
        })
        SyncInventory(ply)
        return
    end

    -- Allow dragging a worn compartment rig directly into grids by
    -- persisting its nested contents first, then clearing the slot.
    if s.kind == "gear" and (s.slot == "tactical_rig" or s.slot == "vest") then
        local rigDef = ZSCAV:GetGearDef(s.class)
        if rigDef and rigDef.compartment then
            local rigUID = tostring(s.uid or "")
            if rigUID == "" then
                rigUID = tostring(ZSCAV:CreateBag(s.class) or "")
            end
            if rigUID == "" then
                Notice(ply, "Could not allocate rig storage.")
                return
            end

            if ZSCAV:IsArmorEntityClass(s.class) then
                if not ZSCAV:RemoveArmorNoDrop(ply, s.class) then
                    Notice(ply, "Could not remove armor cleanly: " .. tostring(s.class))
                    return
                end
            end

            if not ZSCAV:SaveBag(rigUID, s.class, inv.vest or {}) then
                Notice(ply, "Could not save rig contents.")
                return
            end

            inv.gear.tactical_rig = nil
            inv.gear.vest = nil
            inv.vest = {}

            toList[#toList + 1] = CopyItemEntry(s, {
                uid = rigUID,
                x = px,
                y = py,
                w = pw,
                h = ph,
            })
            SyncInventory(ply)
            return
        end
    end

    if not RemoveFromSlotForDrag(ply, inv, s) then return end

    toList[#toList + 1] = CopyItemEntry(s, {
        x = px,
        y = py,
        w = pw,
        h = ph,
    })
    SyncInventory(ply)
end

function Actions.unequip_slot_to_container(ply, inv, args)
    local s = SlotEntryForDrag(inv, args.kind, args.slot)
    if not s then return end

    local targetUID = tostring(args.target_uid or "")
    if targetUID == "" then return end

    local inChain = false
    for _, uid in ipairs(ply.zscav_container_chain or {}) do
        if uid == targetUID then inChain = true break end
    end
    if not inChain then
        Notice(ply, "Container is not open.")
        return
    end

    local bag = ZSCAV:LoadBag(targetUID)
    if not bag then return end

    local gw, gh = 0, 0
    if ZSCAV and ZSCAV.GetContainerGridSize then
        gw, gh = ZSCAV:GetContainerGridSize(bag.class)
    end
    if not (isnumber(gw) and isnumber(gh) and gw > 0 and gh > 0) then
        local def = ZSCAV:GetGearDef(bag.class) or {}
        local internal = def.internal or { w = 4, h = 4 }
        gw, gh = tonumber(internal.w) or 4, tonumber(internal.h) or 4
    end

    local x = math.floor(tonumber(args.x) or 0)
    local y = math.floor(tonumber(args.y) or 0)
    local w, h = s.w, s.h
    if args.rotated and w ~= h then w, h = h, w end

    local sid = tostring(ply:SteamID64() or "")

    local function placeIntoTarget(item, w, h)
        bag.contents = bag.contents or {}
        local layoutBlocks = getContainerLayoutBlocks(bag.class, gw, gh)
        local pw, ph = w, h
        if not fitsAt(bag.contents, x, y, pw, ph, gw, gh, nil, layoutBlocks) then
            if pw ~= ph and fitsAt(bag.contents, x, y, ph, pw, gw, gh, nil, layoutBlocks) then
                pw, ph = ph, pw
            else
                Notice(ply, "No room in target slot.")
                return false
            end
        end

        bag.contents[#bag.contents + 1] = CopyItemEntry(item, {
            x = x,
            y = y,
            w = pw,
            h = ph,
        })
        if not ZSCAV:SaveBag(targetUID, bag.class, bag.contents) then
            Notice(ply, "Could not save target container.")
            return false
        end
        return true
    end

    -- Backpack drag preserves nested contents by serializing the currently
    -- worn backpack grid into its UID before moving the item.
    if s.kind == "gear" and s.slot == "backpack" then
        local bpUID = tostring(s.uid or "")
        if bpUID == "" then
            bpUID = tostring(ZSCAV:CreateBag(s.class) or "")
        end
        if bpUID == "" then
            Notice(ply, "Could not allocate backpack storage.")
            return
        end

        for _, openUID in ipairs(ply.zscav_container_chain or {}) do
            if openUID == bpUID then
                Notice(ply, "Cannot move a backpack into itself or one of its open descendants.")
                return
            end
        end

        local packed = SerializeWornBackpack(inv)
        if not ZSCAV:SaveBag(bpUID, s.class, packed) then
            Notice(ply, "Could not save backpack contents.")
            return
        end

        if not placeIntoTarget({ class = s.class, uid = bpUID }, w, h) then return end

        inv.gear.backpack = nil
        inv.backpack = {}
        SyncInventory(ply)
        return
    end

    if s.kind == "gear" and (s.slot == "tactical_rig" or s.slot == "vest") then
        local rigDef = ZSCAV:GetGearDef(s.class)
        if rigDef and rigDef.compartment then
            local rigUID = tostring(s.uid or "")
            if rigUID == "" then
                rigUID = tostring(ZSCAV:CreateBag(s.class) or "")
            end
            if rigUID == "" then
                Notice(ply, "Could not allocate rig storage.")
                return
            end

            for _, openUID in ipairs(ply.zscav_container_chain or {}) do
                if openUID == rigUID then
                    Notice(ply, "Cannot move a rig into itself or one of its open descendants.")
                    return
                end
            end

            if ZSCAV:IsArmorEntityClass(s.class) then
                if not ZSCAV:RemoveArmorNoDrop(ply, s.class) then
                    Notice(ply, "Could not remove armor cleanly: " .. tostring(s.class))
                    return
                end
            end

            if not ZSCAV:SaveBag(rigUID, s.class, inv.vest or {}) then
                Notice(ply, "Could not save rig contents.")
                return
            end

            if not placeIntoTarget({ class = s.class, uid = rigUID }, w, h) then return end

            inv.gear.tactical_rig = nil
            inv.gear.vest = nil
            inv.vest = {}
            SyncInventory(ply)
            return
        end
    end

    if s.kind == "gear" and s.slot == "secure_container" then
        local stashUID = tostring(ZSCAV:GetCanonicalPlayerStashUID(sid, false) or "")
        if targetUID ~= stashUID then
            Notice(ply, "Secure container can only be moved to stash.")
            return
        end

        local secureUID = tostring(s.uid or "")
        if secureUID == "" then
            secureUID = tostring(ZSCAV:CreateBag(s.class) or "")
        end
        if secureUID == "" then
            Notice(ply, "Could not allocate secure container storage.")
            return
        end
        if not ZSCAV:SaveBag(secureUID, s.class, inv.secure or {}) then
            Notice(ply, "Could not save secure container.")
            return
        end
        s.uid = secureUID
    end

    if not RemoveFromSlotForDrag(ply, inv, s) then return end

    if not placeIntoTarget(s, w, h) then
        -- Roll back the removal when we couldn't place into target.
        if s.kind == "weapon" then
            inv.weapons = inv.weapons or {}
            local rollbackEntry = CopyItemEntry(s) or { class = s.class, uid = s.uid }
            EnsureWeaponEntryRuntime(rollbackEntry)
            inv.weapons[s.slot] = rollbackEntry
            GiveWeaponInstance(ply, rollbackEntry)
        else
            if ZSCAV:IsArmorEntityClass(s.class) then
                local _ = hg and hg.AddArmor and hg.AddArmor(ply, s.class)
            end
            inv.gear = inv.gear or {}
            inv.gear[s.slot] = { class = s.class, uid = s.uid, slot = s.slot }
        end
        SyncInventory(ply)
        return
    end

    if s.kind == "gear" and s.slot == "secure_container" then
        inv.secure = {}
        local st = GetPlayerSecureState(sid)
        if st then
            st.issued = 1
            st.status = "stash"
            st.class = tostring(s.class)
            st.uid = tostring(s.uid or "")
            SavePlayerSecureState(st)
        end
    end

    SyncInventory(ply)
    SendContainerSnapshotForUID(ply, targetUID)
end

function ZSCAV.EquippedContainerTargetIsOpen(ply, targetUID)
    targetUID = tostring(targetUID or "")
    if targetUID == "" then return false end

    for _, openUID in ipairs(ply.zscav_container_chain or {}) do
        if openUID == targetUID then
            return true
        end
    end

    return false
end

function Actions.move_to_slot_container(ply, inv, args)
    local fromGrid = tostring(args.from_grid or "")
    local fromIdx = tonumber(args.from_index)
    local slotID = tostring(args.slot or "")
    if fromGrid == "" or not fromIdx or slotID == "" then return end

    local fromList = inv[fromGrid]
    local entry = fromList and fromList[fromIdx]
    if not entry then return end

    local target = GetEquippedContainerForSlot(inv, slotID)
    if not target then
        Notice(ply, "No equipped container in that slot.")
        return
    end
    if target.w <= 0 or target.h <= 0 then
        Notice(ply, "Target container has no storage space.")
        return
    end

    if fromList == target.list then
        return
    end

    if IsSecureClass(entry.class) then
        Notice(ply, "Secure containers can only be moved into your stash.")
        return
    end

    local itemUID = tostring(entry.uid or "")
    if itemUID ~= "" then
        if itemUID == target.uid or BagContainsUIDRecursive(itemUID, target.uid) then
            Notice(ply, "Cannot create container cycle.")
            return
        end
    end

    local x, y, wasRotated = findFreeSpotAR(target.list, target.w, target.h, entry.w, entry.h, target.layout)
    if not x then
        Notice(ply, "No room in target container.")
        return
    end
    local ew = wasRotated and entry.h or entry.w
    local eh = wasRotated and entry.w or entry.h

    table.remove(fromList, fromIdx)
    target.list[#target.list + 1] = CopyItemEntry(entry, {
        x = x,
        y = y,
        w = ew,
        h = eh,
    })
    SyncInventory(ply)
    if ZSCAV.EquippedContainerTargetIsOpen(ply, target.uid) then
        SendContainerSnapshotForUID(ply, target.uid)
    end
end

function Actions.move_slot_to_slot_container(ply, inv, args)
    local kind = tostring(args.kind or "")
    local slot = tostring(args.slot or "")
    local targetSlotID = tostring(args.target_slot or "")
    if kind == "" or slot == "" or targetSlotID == "" then return end

    local s = SlotEntryForDrag(inv, kind, slot)
    if not s then return end

    local target = GetEquippedContainerForSlot(inv, targetSlotID)
    if not target then
        Notice(ply, "No equipped container in that slot.")
        return
    end
    if target.w <= 0 or target.h <= 0 then
        Notice(ply, "Target container has no storage space.")
        return
    end

    if IsSecureClass(s.class) then
        Notice(ply, "Secure containers can only be moved into your stash.")
        return
    end

    local itemUID = tostring(s.uid or "")
    if itemUID ~= "" then
        if itemUID == target.uid or BagContainsUIDRecursive(itemUID, target.uid) then
            Notice(ply, "Cannot create container cycle.")
            return
        end
    end

    local x, y, wasRotated = findFreeSpotAR(target.list, target.w, target.h, s.w, s.h, target.layout)
    if not x then
        Notice(ply, "No room in target container.")
        return
    end
    local ew = wasRotated and s.h or s.w
    local eh = wasRotated and s.w or s.h

    if not RemoveFromSlotForDrag(ply, inv, s) then return end

    target.list[#target.list + 1] = CopyItemEntry(s, {
        x = x,
        y = y,
        w = ew,
        h = eh,
    })
    SyncInventory(ply)
    if ZSCAV.EquippedContainerTargetIsOpen(ply, target.uid) then
        SendContainerSnapshotForUID(ply, target.uid)
    end
end

function Actions.set_quickslot(ply, inv, args)
    local quickslotIndex = NormalizeQuickslotIndex(args.quickslot)
    if not quickslotIndex then return end

    local entry, meta = ResolveQuickslotBindingSource(inv, args)
    if not entry then return end

    local blockReason = GetQuickslotBindingBlockReason(entry, meta)
    if blockReason then
        Notice(ply, blockReason)
        return
    end

    local ref = CopyQuickslotRef(entry, meta)
    if not ref then return end

    local quickslots = GetQuickslotTable(inv)
    quickslots[quickslotIndex] = ref

    local fromQuickslot = NormalizeQuickslotIndex(args.from_quickslot)
    if fromQuickslot and fromQuickslot ~= quickslotIndex and args.move == true then
        quickslots[fromQuickslot] = nil
    end

    SyncInventory(ply)
end

function Actions.clear_quickslot(ply, inv, args)
    local quickslotIndex = NormalizeQuickslotIndex(args.quickslot)
    if not quickslotIndex then return end

    local quickslots = GetQuickslotTable(inv)
    if quickslots[quickslotIndex] == nil then return end

    quickslots[quickslotIndex] = nil
    SyncInventory(ply)
end

function Actions.activate_hotbar_slot(ply, inv, args)
    local slotNumber = math.floor(tonumber(args.slot) or 0)
    if slotNumber <= 0 then return end

    inv.weapons = inv.weapons or {}

    if slotNumber == 1 then
        local entry = inv.weapons.primary
        if entry then
            if GetActiveWeaponSlot(ply, inv, "primary") == "primary" then
                SelectHandsWeapon(ply)
            else
                SelectOrRestoreWeaponEntry(ply, entry)
            end
        end
        return
    end

    if slotNumber == 2 then
        local entry = inv.weapons.secondary
        if entry then
            if GetActiveWeaponSlot(ply, inv, "secondary") == "secondary" then
                SelectHandsWeapon(ply)
            else
                SelectOrRestoreWeaponEntry(ply, entry)
            end
        end
        return
    end

    if slotNumber == 3 then
        ActivateSidearmHotbar(ply, inv)
        return
    end

    local quickslotIndex = NormalizeQuickslotIndex(slotNumber - 3)
    if not quickslotIndex then return end

    ActivateQuickslotBinding(ply, inv, quickslotIndex)
end

function Actions.reload(ply, _inv, _args)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then Notice(ply, "No active weapon.") return end
    ply:ConCommand("+reload")
    timer.Simple(0.05, function()
        if IsValid(ply) then ply:ConCommand("-reload") end
    end)
end

function Actions.unload(ply, _inv, _args)
    Notice(ply, "Unload: not yet implemented.")
end

function Actions.inspect_unload(ply, _inv, _args)
    Notice(ply, "Unload: not yet implemented.")
end

function Actions.inspect_toggle_equip(ply, inv, args)
    if tostring(args.slot or "") ~= "" then
        return Actions.unequip_weapon(ply, inv, { slot = args.slot })
    end

    local target = ZSCAV.ResolveWeaponInstallTarget(ply, inv, args)
    if not target then return end

    if target.isContainer then
        local chosenSlot = ResolveWeaponEquipSlot(inv, target.entry.class)
        if not chosenSlot then
            Notice(ply, "Not equippable: " .. tostring(target.entry.class))
            return
        end

        return CActions.equip_from_container(ply, {
            from_uid = target.containerUID,
            from_index = target.key,
            kind = "weapon",
            slot = chosenSlot,
        })
    end

    return Actions.equip_weapon(ply, inv, {
        grid = args.grid,
        index = args.index,
    })
end

function Actions.inspect_drop_weapon(ply, inv, args)
    local ok = ZSCAV.DropWeaponActionEntry(ply, inv, args)
    if not ok then
        Notice(ply, "Could not drop that weapon.")
    end
end

function Actions.inspect_attach_install(ply, inv, args)
    if ActionResolverHelpers.AttachmentInstallRequiresPlayerInventory(args) then
        Notice(ply, "Move the weapon and attachment into your inventory to modify attachments.")
        return
    end

    local attachmentEntry, attachmentList, attachmentIndex = ActionResolverHelpers.ResolveAttachmentActionEntry(inv, args)
    if not attachmentEntry then
        Notice(ply, "Attachment item not found.")
        return
    end

    ZSCAV.InstallAttachmentIntoWeaponEntry(
        ply,
        inv,
        args,
        attachmentEntry,
        function()
            table.remove(attachmentList, attachmentIndex)
            return true
        end,
        function()
            table.insert(attachmentList, attachmentIndex, attachmentEntry)
        end
    )
end

function Actions.inspect_attach_detach(ply, inv, args)
    local target = ZSCAV.ResolveWeaponInstallTarget(ply, inv, args)
    if not target then return end

    local entry = target.entry

    local placement = tostring(args.placement or ""):lower()
    local attachments = ZSCAV.EnsureWeaponEntryAttachments(entry)
    if placement == "" or not attachments then return end

    local currentKey = ZSCAV:NormalizeAttachmentKey(attachments[placement])
    if currentKey == "" then return end

    if not ZSCAV:CanRemoveWeaponAttachment(entry.class, placement) then
        Notice(ply, "That attachment slot cannot be modified.")
        return
    end

    local ok = ZSCAV.StashAttachmentItem(inv, currentKey)
    if not ok then
        Notice(ply, "No room to detach that attachment.")
        return
    end

    attachments[placement] = ""
    entry.weapon_state.attachments = ZSCAV:NormalizeWeaponAttachments(entry.class, attachments)
    ZSCAV.CommitResolvedWeaponTargetState(ply, target, entry)
end

function Actions.inspect_attach_detach_all(ply, inv, args)
    local target = ZSCAV.ResolveWeaponInstallTarget(ply, inv, args)
    if not target then return end

    local entry = target.entry

    local attachments = ZSCAV.EnsureWeaponEntryAttachments(entry)
    if not attachments then return end

    local detachable = {}
    for _, placement in ipairs(ZSCAV:GetWeaponAttachmentSlots()) do
        local attKey = ZSCAV:NormalizeAttachmentKey(attachments[placement])
        if attKey ~= "" and ZSCAV:CanRemoveWeaponAttachment(entry.class, placement) then
            detachable[#detachable + 1] = {
                placement = placement,
                key = attKey,
            }
        end
    end

    if #detachable == 0 then
        Notice(ply, "No removable attachments are installed.")
        return
    end

    local scratch = table.Copy(inv)
    for _, item in ipairs(detachable) do
        local ok = ZSCAV.StashAttachmentItem(scratch, item.key)
        if not ok then
            Notice(ply, "No room to detach all attachments.")
            return
        end
    end

    inv.backpack = scratch.backpack or inv.backpack
    inv.pocket = scratch.pocket or inv.pocket
    inv.vest = scratch.vest or inv.vest

    for _, item in ipairs(detachable) do
        attachments[item.placement] = ""
    end

    entry.weapon_state.attachments = ZSCAV:NormalizeWeaponAttachments(entry.class, attachments)
    ZSCAV.CommitResolvedWeaponTargetState(ply, target, entry)
end

function Actions.inspect(ply, inv, args)
    local entry = inv[args.grid] and inv[args.grid][args.index]
    if not entry then
        entry = select(1, ActionResolverHelpers.ResolveContainerWeaponActionEntry(ply, args))
    end
    if not entry then return end
    local m   = ZSCAV:GetItemMeta(entry) or {}
    local wep = weapons.Get(entry.class)
    Notice(ply, string.format("%s | %dx%d | %.2fkg",
        (wep and wep.PrintName) or entry.class, entry.w, entry.h, m.weight or 0))
end

-- ---------------------------------------------------------------
-- Net dispatcher
-- ---------------------------------------------------------------
ZScavActionState.InventoryActionCooldown = ZScavActionState.InventoryActionCooldown or {}

net.Receive("ZScavInvAction", function(_, ply)
    if not IsValid(ply) or not ZSCAV:IsActive() then return end
    if ZSCAV.CanPlayerUseInventory and not ZSCAV:CanPlayerUseInventory(ply) then return end
    local now = CurTime()
    if (ZScavActionState.InventoryActionCooldown[ply] or 0) > now then return end
    ZScavActionState.InventoryActionCooldown[ply] = now + 0.05

    local action = net.ReadString()
    local args   = net.ReadTable() or {}
    local handler = Actions[action]
    if not handler then return end

    local inv = ZSCAV:GetInventory(ply)
    handler(ply, inv, args)
end)

-- ---------------------------------------------------------------
-- Debug / staff helpers
-- ---------------------------------------------------------------
concommand.Add("zscav_giveitem", function(ply, _, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    if not ZSCAV:IsActive() then ply:ChatPrint("ZScav not active.") return end
    local class = tostring(args[1] or ""):lower()
    if class == "" then ply:ChatPrint("usage: zscav_giveitem <class>") return end
    local ok, where = ZSCAV:TryAddItem(ply, class)
    ply:ChatPrint(ok and ("Added to " .. where) or "No room.")
end)

end

-- ---------------------------------------------------------------
-- Container sessions (open bag-on-ground / nested bag).
--
-- Each player tracks a chain of bag UIDs they currently have open,
-- e.g. { worldBagUID, nestedBagUID, ... }. The "active" container is
-- the top of the chain. Take/Put/Move actions operate on it. Open-nested
-- pushes another UID onto the stack; Close-one pops; Close-all clears.
--
-- Access rules:
--   - Root UID must be either reachable in the player's own inventory
--     (worn pack, stashed pack item, etc.) OR a world entity within
--     reasonable distance.
--   - Any deeper UID must appear inside the contents of its parent.
-- ---------------------------------------------------------------
do
local Actions = ZScavActionState.Actions or {}
ZScavActionState.Actions = Actions
ZScavActionState.CONTAINER_RANGE_SQR = ZScavActionState.CONTAINER_RANGE_SQR or (200 * 200)
local function ContainerSizeFor(...)
    local helper = ZScavActionState.ContainerSizeFor
    if not helper then return 0, 0, nil end
    return helper(...)
end

local function SaveContainerContents(...)
    local helper = ZScavActionState.SaveContainerContents
    if not helper then return false end
    return helper(...)
end

local function SendContainerSnapshotForUID(...)
    local helper = ZScavActionState.SendContainerSnapshotForUID
    if not helper then return false end
    return helper(...)
end

function ZScavActionState.GetContainerGridSizeForClass(class)
    if ZSCAV and ZSCAV.GetContainerGridSize then
        local w, h = ZSCAV:GetContainerGridSize(class)
        if isnumber(w) and isnumber(h) and w > 0 and h > 0 then
            return w, h
        end
    end

    local def = ZSCAV:GetGearDef(class) or {}
    local internal = def.internal or { w = 4, h = 4 }
    return tonumber(internal.w) or 4, tonumber(internal.h) or 4
end

function ZScavActionState.ContainerAllowsPlayerInsert(class)
    local def = ZSCAV:GetGearDef(class) or {}
    if def.player_insert_restricted == true then return false end
    if def.playerInsertRestricted == true then return false end
    if def.no_player_insert == true then return false end
    if def.noPlayerInsert == true then return false end
    if def.player_insert == false then return false end
    return true
end

function ZScavActionState.PlayerOwnsUID(ply, uid)
    if isfunction(IsPlayerMailboxUID) and IsPlayerMailboxUID(ply, uid) then
        return true
    end

    local sid64 = IsValid(ply) and tostring(ply:SteamID64() or "") or ""
    if sid64 ~= "" then
        local stashUID = ""
        local stashUIDByOwner = ZSCAV and ZSCAV.PlayerStashUIDByOwner or nil
        local cachedStash = istable(stashUIDByOwner) and stashUIDByOwner[sid64] or nil
        if istable(cachedStash) then
            stashUID = tostring(cachedStash.uid or "")
        end
        if stashUID == "" and isfunction(ZSCAV.GetCanonicalPlayerStashUID) then
            stashUID = tostring(ZSCAV:GetCanonicalPlayerStashUID(sid64, false) or "")
        end
        if stashUID ~= "" and stashUID == uid then
            return true
        end
    end

    local inv = ZSCAV:GetInventory(ply)
    if not inv then return false end
    if inv.gear then
        for _, entry in pairs(inv.gear) do
            if istable(entry) and entry.uid == uid then return true end
        end
    end
    for _, gn in ipairs({ "backpack", "pocket", "vest" }) do
        for _, it in ipairs(inv[gn] or {}) do
            if it.uid == uid then return true end
        end
    end
    return false
end

function ZScavActionState.FindWorldBag(ply, uid)
    if not uid or uid == "" then return nil end
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 200)) do
        if tostring(ent.zscav_corpse_root_uid or "") == uid then
            return ent
        end
        if ZSCAV:GetEntPackUID(ent) == uid then return ent end
    end
    return nil
end

function ZScavActionState.ContainerHasChild(parentUID, childUID, ply)
    local contents = nil
    local corpse = GetCorpseContainer(parentUID)
    if corpse then
        contents = corpse.contents or {}
    else
        local live = IsValid(ply)
            and isfunction(ZScavActionState.GetEquippedContainerForUID)
            and ZScavActionState.GetEquippedContainerForUID(ply, parentUID)
            or nil
        if live then
            contents = live.list or {}
        else
            local bag = ZSCAV:LoadBag(parentUID)
            if not bag then return false end
            contents = bag.contents or {}
        end
    end

    for _, it in ipairs(contents) do
        if it.uid == childUID then return true end
    end
    return false
end

function ZScavActionState.GetEquippedContainerForUID(ply, uid)
    uid = tostring(uid or "")
    if uid == "" then return nil end

    local inv = ZSCAV:GetInventory(ply)
    if not inv or not inv.gear then return nil end

    for _, slotID in ipairs({ "backpack", "tactical_rig", "vest", "secure_container" }) do
        local eq = inv.gear[slotID]
        if istable(eq) and tostring(eq.uid or "") == uid then
            return GetEquippedContainerForSlot(inv, slotID)
        end
    end

    return nil
end

ZScavActionState.ContainerSizeFor = function(ply, uid)
    local corpse = GetCorpseContainer(uid)
    if corpse then
        return corpse.gw, corpse.gh, corpse
    end

    local live = ZScavActionState.GetEquippedContainerForUID(ply, uid)
    if live then
        return live.w, live.h, {
            class = live.class,
            contents = live.list,
            layout = live.layout,
            slotID = live.slotID,
            _live = true,
        }
    end

    local bag = ZSCAV:LoadBag(uid)
    if not bag then return 0, 0, nil end
    local gw, gh = ZScavActionState.GetContainerGridSizeForClass(bag.class)
    return gw, gh, bag
end

ZScavActionState.SaveContainerContents = function(_ply, uid, class, contents)
    local corpse = GetCorpseContainer(uid)
    if corpse then
        corpse.class = tostring(class or corpse.class or CORPSE_CONTAINER_CLASS)
        corpse.contents = contents or {}
        if corpse.live_owner == true then
            return ApplyLiveLootProxyContents(corpse)
        end
        corpse.has_tracked_head_gear = CorpseHasTrackedHeadGear(corpse)
        ApplyCorpseAnchorVisualState(corpse)
        return true
    end

    return ZSCAV:SaveBag(uid, class, contents)
end

-- Send a ZScavContainerOpen snapshot for a specific uid already in the chain.
ZScavActionState.SendContainerSnapshotForUID = function(ply, uid)
    local gw, gh, bag = ContainerSizeFor(ply, uid)
    if not bag then return false end
    local layoutBlocks = bag.layout or getContainerLayoutBlocks(bag.class, gw, gh)
    local chain = ply.zscav_container_chain or {}
    local payload = util.TableToJSON({
        chain    = chain,
        uid      = uid,
        class    = bag.class,
        gw       = gw,
        gh       = gh,
        layoutBlocks = layoutBlocks,
        contents = bag.contents,
        owned    = ply.zscav_next_owned and true or nil,
        health_target_entindex = (bag.live_owner == true and IsValid(bag.owner)) and bag.owner:EntIndex() or nil,
        health_target_name = (bag.live_owner == true and IsValid(bag.owner)) and tostring(bag.owner:Nick() or "") or nil,
    }) or "{}"
    net.Start("ZScavContainerOpen")
        net.WriteUInt(#payload, 32)
        net.WriteData(payload, #payload)
    net.Send(ply)
    return true
    end

ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}
ZSCAV.ServerHelpers.SendContainerSnapshotForUID = ZScavActionState.SendContainerSnapshotForUID

function ZScavActionState.SendContainerSnapshot(ply)
    local chain = ply.zscav_container_chain
    if not chain or #chain == 0 then
        net.Start("ZScavContainerClose") net.WriteString("") net.Send(ply)
        return
    end
    local uid = chain[#chain]
    if not SendContainerSnapshotForUID(ply, uid) then
        ply.zscav_container_chain = nil
        net.Start("ZScavContainerClose") net.WriteString("") net.Send(ply)
    end
end

local function OpenOwnedContainerChain(ply, primaryUID, secondaryUID)
    primaryUID = tostring(primaryUID or "")
    secondaryUID = tostring(secondaryUID or "")
    if primaryUID == "" then return false end

    local chain = ply.zscav_container_chain
    if chain then
        for i = #chain, 1, -1 do
            local closedUID = table.remove(chain)
            net.Start("ZScavContainerClose")
                net.WriteString(closedUID)
            net.Send(ply)
        end
    end

    ply.zscav_container_chain = nil
    ply.zscav_next_owned = nil

    net.Start("ZScavContainerClose")
        net.WriteString("")
    net.Send(ply)

    if secondaryUID ~= "" and secondaryUID ~= primaryUID then
        ply.zscav_container_chain = { primaryUID, secondaryUID }
        SendContainerSnapshotForUID(ply, primaryUID)
        SendContainerSnapshotForUID(ply, secondaryUID)
    else
        ply.zscav_container_chain = { primaryUID }
        ZScavActionState.SendContainerSnapshot(ply)
    end

    return true
end

function Actions.open_mailbox(ply, _inv, _args)
    if not isfunction(GetCanonicalPlayerMailboxUID) then return end

    if isfunction(CanAccessMailbox) and not CanAccessMailbox(ply) then
        Notice(ply, "Mailbox can only be accessed inside a safe zone.")
        return
    end

    local ownerSID64 = tostring(ply:SteamID64() or "")
    if ownerSID64 == "" then return end

    local uid = tostring(GetCanonicalPlayerMailboxUID(ownerSID64, true) or "")
    if uid == "" then
        Notice(ply, "Could not access mailbox.")
        return
    end

    local stashUID = ""
    if ZSCAV.GetAccessiblePlayerStashUID then
        local resolvedStashUID, stashErr = ZSCAV:GetAccessiblePlayerStashUID(ply)
        if tostring(stashErr or "") ~= "stash_loading" then
            stashUID = tostring(resolvedStashUID or "")
        end
    else
        stashUID = tostring(ZSCAV:GetCanonicalPlayerStashUID(ownerSID64, true) or "")
    end

    if isfunction(MarkPlayerMailboxRead) then
        MarkPlayerMailboxRead(ownerSID64)
    end

    OpenOwnedContainerChain(ply, stashUID ~= "" and stashUID or uid, stashUID ~= "" and stashUID ~= uid and uid or "")

    if isfunction(SyncMailboxUnread) then
        SyncMailboxUnread(ply)
    end
end

function Actions.open_stash(ply, _inv, _args)
    if isfunction(CanAccessMailbox) and not CanAccessMailbox(ply) then
        Notice(ply, "Stash can only be accessed inside a safe zone.")
        return
    end

    local ownerSID64 = tostring(ply:SteamID64() or "")
    if ownerSID64 == "" then return end

    local uid = ""
    if ZSCAV.GetAccessiblePlayerStashUID then
        local resolvedUID, stashErr = ZSCAV:GetAccessiblePlayerStashUID(ply)
        if tostring(stashErr or "") == "stash_loading" then
            Notice(ply, "Stash is still loading. Try again in a moment.")
            return
        end
        uid = tostring(resolvedUID or "")
    else
        uid = tostring(ZSCAV:GetCanonicalPlayerStashUID(ownerSID64, true) or "")
    end

    if uid == "" then
        Notice(ply, "Could not access stash.")
        return
    end

    OpenOwnedContainerChain(ply, uid)
end

function ZSCAV:OpenContainerForPlayer(ply, uid, _class, ent)
    if not IsValid(ply) or not uid or uid == "" then return end

    -- Validate access: owned (any depth) or world-bag within range.
    local owned = ZScavActionState.PlayerOwnsUID(ply, uid)
    local worldOK = false
    if not owned then
        local worldEnt = ent or ZScavActionState.FindWorldBag(ply, uid)
        if IsValid(worldEnt) and worldEnt:GetPos():DistToSqr(ply:GetPos()) <= ZScavActionState.CONTAINER_RANGE_SQR then
            worldOK = true
        end
    end
    if not (owned or worldOK) then
        Notice(ply, "Bag out of reach.")
        return
    end

    ply.zscav_container_chain = { uid }
    ZScavActionState.SendContainerSnapshot(ply)
end

-- ---------------------------------------------------------------
-- Container action handlers (cl -> sv)
-- ---------------------------------------------------------------
function ZScavActionState.ContainerCurrent(ply)
    local chain = ply.zscav_container_chain
    if not chain or #chain == 0 then return nil end
    return chain[#chain]
end

local CActions = {}

function CActions.close_one(ply)
    local chain = ply.zscav_container_chain
    if not chain then return end
    table.remove(chain)
    if #chain == 0 then ply.zscav_container_chain = nil end
    ZScavActionState.SendContainerSnapshot(ply)
end

function CActions.close_all(ply)
    local chain = ply.zscav_container_chain
    ply.zscav_container_chain = nil
    if chain then
        for _, uid in ipairs(chain) do
            net.Start("ZScavContainerClose") net.WriteString(uid) net.Send(ply)
        end
    end
    net.Start("ZScavContainerClose") net.WriteString("") net.Send(ply)
end

function CActions.close_window(ply, args)
    local targetUID = tostring(args.uid or "")
    if targetUID == "" then CActions.close_all(ply) return end
    local chain = ply.zscav_container_chain
    if not chain then return end
    -- Find the position of targetUID in the chain.
    local idx = nil
    for i, uid in ipairs(chain) do
        if uid == targetUID then idx = i break end
    end
    if not idx then return end
    -- Remove this entry and all descendants (entries at idx and beyond).
    while #chain >= idx do
        local closedUID = table.remove(chain)  -- removes from tail
        net.Start("ZScavContainerClose") net.WriteString(closedUID) net.Send(ply)
    end
    if #chain == 0 then ply.zscav_container_chain = nil end
end

function CActions.open_nested(ply, args)
    local chain = ply.zscav_container_chain
    if not chain or #chain == 0 then return end

    local parent = tostring(args.target_uid or "")
    local parentInChain = false
    if parent ~= "" then
        for _, uid in ipairs(chain) do
            if uid == parent then
                parentInChain = true
                break
            end
        end
    end
    if parent == "" or not parentInChain then
        parent = ZScavActionState.ContainerCurrent(ply)
    end
    if not parent then return end

    local childUID = tostring(args.uid or "")
    if childUID == "" then
        local _, _, parentBag = ContainerSizeFor(ply, parent)
        if not parentBag then return end

        local idx = tonumber(args.index)
        local entry = idx and parentBag.contents and parentBag.contents[idx]
        if not (entry and entry.class) then return end

        local def = ZSCAV:GetGearDef(entry.class)
        if not (def and (def.slot == "backpack" or def.compartment or def.secure)) then
            Notice(ply, "That item has no container.")
            return
        end

        childUID = tostring(entry.uid or "")
        if childUID == "" then
            childUID = tostring(ZSCAV:CreateBag(entry.class) or "")
            if childUID == "" then
                Notice(ply, "Could not allocate nested storage.")
                return
            end
            entry.uid = childUID
            SaveContainerContents(ply, parent, parentBag.class, parentBag.contents)
            if parentBag._live then
                SyncInventory(ply)
            end
            SendContainerSnapshotForUID(ply, parent)
        end
    end
    if childUID == "" then return end

    if not ZScavActionState.ContainerHasChild(parent, childUID, ply) then
        -- Be forgiving when the client focus drifts: allow opening from any
        -- currently open container that actually owns this nested bag UID.
        local resolvedParent = nil
        for i = #chain, 1, -1 do
            local uid = chain[i]
            if ZScavActionState.ContainerHasChild(uid, childUID, ply) then
                resolvedParent = uid
                break
            end
        end
        if not resolvedParent then
            Notice(ply, "Bag not in this container.")
            return
        end
        parent = resolvedParent
    end

    -- If already open in chain, just refresh its window.
    for _, uid in ipairs(chain) do
        if uid == childUID then
            SendContainerSnapshotForUID(ply, childUID)
            return
        end
    end

    -- Keep ordering sane when opening a child from a container that isn't the
    -- current chain tail.
    local parentIdx
    for i, uid in ipairs(chain) do
        if uid == parent then
            parentIdx = i
            break
        end
    end
    if parentIdx and parentIdx < #chain then
        for i = #chain, parentIdx + 1, -1 do
            local closedUID = table.remove(chain)
            net.Start("ZScavContainerClose") net.WriteString(closedUID) net.Send(ply)
        end
    end

    table.insert(chain, childUID)
    -- Send snapshot for the newly opened window; parent stays visible.
    SendContainerSnapshotForUID(ply, childUID)
end

-- Open a bag the player already carries (in any of their inv grids or
-- gear slot). Used by the right-click "Open bag" path. Validation goes
-- through PlayerOwnsUID so we can't open arbitrary world bags this way.
function CActions.open_owned(ply, args)
    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end

    local uid = tostring(args.uid or "")
    local slotID = tostring(args.slot or "")

    if uid == "" and slotID ~= "" then
        inv.gear = inv.gear or {}
        local eq = inv.gear[slotID]
        if not (istable(eq) and eq.class) then
            Notice(ply, "No item equipped in that slot.")
            return
        end

        local def = ZSCAV:GetGearDef(eq.class)
        if not (def and (slotID == "backpack" or def.compartment or def.secure)) then
            Notice(ply, "That item has no container.")
            return
        end

        local eqUID = tostring(eq.uid or "")
        if eqUID == "" then
            eqUID = tostring(ZSCAV:CreateBag(eq.class) or "")
            if eqUID == "" then
                Notice(ply, "Could not allocate container storage.")
                return
            end
            eq.uid = eqUID
        end

        local liveList = {}
        if slotID == "backpack" then
            liveList = inv.backpack or {}
        elseif slotID == "tactical_rig" or slotID == "vest" then
            liveList = inv.vest or {}
        elseif slotID == "secure_container" then
            liveList = inv.secure or {}
        end

        ZSCAV:SaveBag(eqUID, eq.class, liveList)
        uid = eqUID
        SyncInventory(ply)
    end

    if uid == "" then
        local fromGrid = tostring(args.from_grid or "")
        local fromIdx = tonumber(args.from_index)
        local list = inv[fromGrid]
        local entry = list and fromIdx and list[fromIdx]
        if not entry or not entry.class then return end

        local def = ZSCAV:GetGearDef(entry.class)
        if not (def and (def.slot == "backpack" or def.compartment or def.secure)) then
            Notice(ply, "That item has no container.")
            return
        end

        local itemUID = tostring(entry.uid or "")
        if itemUID == "" then
            itemUID = tostring(ZSCAV:CreateBag(entry.class) or "")
            if itemUID == "" then
                Notice(ply, "Could not allocate container storage.")
                return
            end
            entry.uid = itemUID
            SyncInventory(ply)
        end
        uid = itemUID
    end

    if uid == "" or not ZScavActionState.PlayerOwnsUID(ply, uid) then
        Notice(ply, "You don't carry that bag.")
        return
    end
    ply.zscav_container_chain = { uid }
    -- Mark as owned so the client opens it as a floating window, not the right panel.
    ply.zscav_next_owned = true
    ZScavActionState.SendContainerSnapshot(ply)
    ply.zscav_next_owned = nil
end

-- Returns the uid if it is in the player's open chain, else nil.
ZScavActionState.ContainerInChain = function(ply, uid)
    if not uid or uid == "" then return false end
    local chain = ply.zscav_container_chain
    if not chain then return false end
    for _, chUID in ipairs(chain) do
        if chUID == uid then return true end
    end
    return false
end

-- Resolve target uid from args.target_uid, falling back to top of chain.
function ZScavActionState.ResolveContainerUID(ply, args)
    local uid = tostring(args.target_uid or "")
    if uid ~= "" and ZScavActionState.ContainerInChain(ply, uid) then return uid end
    return ZScavActionState.ContainerCurrent(ply)
end

function ZScavActionState.QuickPutFromGridToContainer(ply, inv, fromGrid, fromIndex, targetUID, rotated, suppressNotice)
    fromGrid = tostring(fromGrid or "")
    fromIndex = tonumber(fromIndex)
    targetUID = tostring(targetUID or "")
    if fromGrid == "" or not fromIndex or targetUID == "" then return false end

    local list = inv and inv[fromGrid]
    local entry = list and list[fromIndex]
    if not entry then return false end

    local gw, gh, bag = ContainerSizeFor(ply, targetUID)
    if not bag then
        if not suppressNotice then Notice(ply, "No open container.") end
        return false
    end

    if not ZScavActionState.ContainerAllowsPlayerInsert(bag.class) then
        if not suppressNotice then Notice(ply, "That container does not accept player inserts.") end
        return false
    end

    if IsSecureClass(entry.class) then
        local sid = tostring(ply:SteamID64() or "")
        local stashUID = tostring(ZSCAV:GetCanonicalPlayerStashUID(sid, false) or "")
        if targetUID ~= stashUID then
            if not suppressNotice then Notice(ply, "Secure containers can only be moved into your stash.") end
            return false
        end
    end

    local itemUID = tostring(entry.uid or "")
    if itemUID ~= "" then
        if itemUID == targetUID or BagContainsUIDRecursive(itemUID, targetUID) then
            if not suppressNotice then Notice(ply, "Cannot create container cycle.") end
            return false
        end
    end

    local layout = bag.layout or getContainerLayoutBlocks(bag.class, gw, gh)
    local iw, ih = entry.w, entry.h
    if rotated and iw ~= ih then
        iw, ih = ih, iw
    end

    local x, y, wasRotated = findFreeSpotAR(bag.contents, gw, gh, iw, ih, layout)
    if not x then
        if not suppressNotice then Notice(ply, "No room in target container.") end
        return false
    end

    local ew = wasRotated and ih or iw
    local eh = wasRotated and iw or ih

    table.remove(list, fromIndex)
    bag.contents[#bag.contents + 1] = CopyItemEntry(entry, {
        x = x,
        y = y,
        w = ew,
        h = eh,
    })

    SaveContainerContents(ply, targetUID, bag.class, bag.contents)
    SyncInventory(ply)
    SendContainerSnapshotForUID(ply, targetUID)

    -- If the source grid is backed by an equipped container window, refresh it
    -- too so clients don't see stale contents that look like duplication.
    local srcUID = ""
    if fromGrid == "backpack" then
        srcUID = tostring(inv.gear and inv.gear.backpack and inv.gear.backpack.uid or "")
    elseif fromGrid == "vest" then
        local rig = inv.gear and (inv.gear.tactical_rig or inv.gear.vest)
        srcUID = tostring(rig and rig.uid or "")
    elseif fromGrid == "secure" then
        srcUID = tostring(inv.gear and inv.gear.secure_container and inv.gear.secure_container.uid or "")
    end
    if srcUID ~= "" and srcUID ~= targetUID and ZScavActionState.ContainerInChain(ply, srcUID) then
        SendContainerSnapshotForUID(ply, srcUID)
    end

    return true
end

function ZScavActionState.QuickPutSlotToContainer(ply, inv, kind, slot, targetUID, suppressNotice)
    kind = tostring(kind or "")
    slot = tostring(slot or "")
    targetUID = tostring(targetUID or "")
    if kind == "" or slot == "" or targetUID == "" then return false end

    local s = SlotEntryForDrag(inv, kind, slot)
    if not s then return false end

    local gw, gh, bag = ContainerSizeFor(ply, targetUID)
    if not bag then
        if not suppressNotice then Notice(ply, "No open container.") end
        return false
    end

    if not ZScavActionState.ContainerAllowsPlayerInsert(bag.class) then
        if not suppressNotice then Notice(ply, "That container does not accept player inserts.") end
        return false
    end

    if IsSecureClass(s.class) then
        local sid = tostring(ply:SteamID64() or "")
        local stashUID = tostring(ZSCAV:GetCanonicalPlayerStashUID(sid, false) or "")
        if targetUID ~= stashUID then
            if not suppressNotice then Notice(ply, "Secure containers can only be moved into your stash.") end
            return false
        end
    end

    local itemUID = tostring(s.uid or "")
    if itemUID ~= "" then
        if itemUID == targetUID or BagContainsUIDRecursive(itemUID, targetUID) then
            if not suppressNotice then Notice(ply, "Cannot create container cycle.") end
            return false
        end
    end

    local layout = bag.layout or getContainerLayoutBlocks(bag.class, gw, gh)
    local x, y, wasRotated = findFreeSpotAR(bag.contents, gw, gh, s.w, s.h, layout)
    if not x then
        if not suppressNotice then Notice(ply, "No room in target container.") end
        return false
    end

    Actions.unequip_slot_to_container(ply, inv, {
        kind = kind,
        slot = slot,
        target_uid = targetUID,
        x = x,
        y = y,
        rotated = wasRotated and true or false,
    })

    return SlotEntryForDrag(inv, kind, slot) == nil
end

-- Take an item from a specific open container window into the player's inv.
function CActions.take(ply, args)
    local uid = ZScavActionState.ResolveContainerUID(ply, args)
    if not uid then return end
    local _, _, bag = ContainerSizeFor(ply, uid)
    if not bag then return end

    local idx = tonumber(args.index)
    local entry = idx and bag.contents[idx]
    if not entry then return end

    if IsSecureClass(entry.class) then
        local sid = tostring(ply:SteamID64() or "")
        local stashUID = tostring(ZSCAV:GetCanonicalPlayerStashUID(sid, false) or "")
        if uid ~= stashUID then
            Notice(ply, "Secure containers can only be managed from your stash.")
            return
        end

        local inv = ZSCAV:GetInventory(ply)
        inv.gear = inv.gear or {}
        if inv.gear.secure_container then
            Notice(ply, "Secure container slot is occupied.")
            return
        end

        table.remove(bag.contents, idx)
        SaveContainerContents(ply, uid, bag.class, bag.contents)

        local secureUID = tostring(entry.uid or "")
        if secureUID == "" then
            secureUID = tostring(ZSCAV:CreateBag(entry.class) or "")
        end
        inv.gear.secure_container = { class = entry.class, uid = secureUID, slot = "secure_container" }
        local loaded = ZSCAV:LoadBag(secureUID)
        inv.secure = (loaded and loaded.contents) or {}
        local st = GetPlayerSecureState(sid)
        if st then
            st.issued = 1
            st.status = "equipped"
            st.class = tostring(entry.class)
            st.uid = tostring(secureUID)
            SavePlayerSecureState(st)
        end

        SyncInventory(ply)
        SendContainerSnapshotForUID(ply, uid)
        return
    end

    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end

    -- Weight gate: take counts toward your carry cap (incl. nested weight).
    local can = ZSCAV:CanCarryMore(inv, entry, entry.uid)
    if not can then
        Notice(ply, "Too heavy to take: " .. tostring(entry.class))
        return
    end

    local toGrid = tostring(args.to_grid or "")
    if toGrid ~= "" then
        local toList = inv[toGrid]
        local grids = ZSCAV:GetEffectiveGrids(inv)
        local target = grids and grids[toGrid] or nil
        if not toList or not target then
            Notice(ply, "Bad target grid.")
            return
        end

        if GetPlayerGridInsertBlockReason then
            local blockedReason = GetPlayerGridInsertBlockReason(toGrid, entry)
            if blockedReason then
                Notice(ply, blockedReason)
                return
            end
        end

        local can = ZSCAV:CanCarryMore(inv, entry, entry.uid)
        if not can then
            Notice(ply, "Too heavy to take: " .. tostring(entry.class))
            return
        end

        local x = math.floor(tonumber(args.x) or -1)
        local y = math.floor(tonumber(args.y) or -1)
        if x < 0 or y < 0 then
            Notice(ply, "Invalid target cell.")
            return
        end

        local ew, eh = entry.w, entry.h
        if args.rotated and ew ~= eh then
            ew, eh = eh, ew
        end

        local layout = getGridLayoutBlocks(inv, toGrid)
        if not fitsAt(toList, x, y, ew, eh, target.w, target.h, nil, layout) then
            if ew ~= eh and fitsAt(toList, x, y, eh, ew, target.w, target.h, nil, layout) then
                ew, eh = eh, ew
            else
                Notice(ply, "No room in target slot.")
                return
            end
        end

        table.remove(bag.contents, idx)
        toList[#toList + 1] = CopyItemEntry(entry, {
            x = x,
            y = y,
            w = ew,
            h = eh,
        })

        SaveContainerContents(ply, uid, bag.class, bag.contents)
        SyncInventory(ply)
        SendContainerSnapshotForUID(ply, uid)
        return
    end

    -- For gear items, try to auto-equip if slot is available before trying grids.
    local def = ZSCAV:GetGearDef(entry.class)
    if def and def.slot then
        inv.gear = inv.gear or {}
        if not inv.gear[def.slot] then
            if def.slot == "secure_container" then
                -- Secure container already handled above; shouldn't reach here
                Notice(ply, "Secure container must be taken differently.")
                return
            end

            -- Backpack-class: route through BackpackEquip so SQL bag contents
            -- are loaded into the live backpack grid on equip.
            if def.slot == "backpack" then
                local class, itemUID = entry.class, entry.uid
                table.remove(bag.contents, idx)
                SaveContainerContents(ply, uid, bag.class, bag.contents)
                BackpackEquip(ply, inv, class, itemUID)
                SendContainerSnapshotForUID(ply, uid)
                return
            end

            -- Compartment rigs must use VestEquip and armor validation first.
            if (def.slot == "tactical_rig" or def.slot == "vest") and def.compartment then
                local class = entry.class
                local itemUID = tostring(entry.uid or "")
                if itemUID == "" then
                    itemUID = tostring(ZSCAV:CreateBag(class) or "")
                end
                if itemUID == "" then
                    Notice(ply, "Could not allocate rig storage.")
                    return
                end

                if ZSCAV:IsArmorEntityClass(class) then
                    local ok = hg and hg.AddArmor and hg.AddArmor(ply, class)
                    if not ok then
                        Notice(ply, "Could not equip armor: " .. tostring(class))
                        return
                    end
                end

                table.remove(bag.contents, idx)
                SaveContainerContents(ply, uid, bag.class, bag.contents)
                VestEquip(ply, inv, class, itemUID)
                SendContainerSnapshotForUID(ply, uid)
                return
            end

            -- Non-compartment armor must successfully apply before removal from stash.
            if ZSCAV:IsArmorEntityClass(entry.class) then
                local ok = hg and hg.AddArmor and hg.AddArmor(ply, entry.class)
                if not ok then
                    Notice(ply, "Could not equip armor: " .. tostring(entry.class))
                    return
                end
            end

            table.remove(bag.contents, idx)
            SaveContainerContents(ply, uid, bag.class, bag.contents)

            local equipUID = entry.uid
            if def.secure == true and (not equipUID or equipUID == "") then
                equipUID = ZSCAV:CreateBag(entry.class)
            end
            inv.gear[def.slot] = { class = entry.class, uid = equipUID, slot = def.slot }

            if def.secure == true then
                local sid = tostring(ply:SteamID64() or "")
                local loaded = ZSCAV:LoadBag(tostring(equipUID or ""))
                inv.secure = (loaded and loaded.contents) or {}
                local st = GetPlayerSecureState(sid)
                if st then
                    st.issued = 1
                    st.status = "equipped"
                    st.class = tostring(entry.class)
                    st.uid = tostring(equipUID or "")
                    SavePlayerSecureState(st)
                end
            end

            SyncInventory(ply)
            SendContainerSnapshotForUID(ply, uid)
            return
        end
        -- Slot occupied; fall through to grid placement
    end

    local ok = ZSCAV:TryAddItem(ply, entry)
    if not ok then
        Notice(ply, "No room for " .. tostring(entry.class))
        return
    end
    table.remove(bag.contents, idx)
    SaveContainerContents(ply, uid, bag.class, bag.contents)
    SyncInventory(ply)
    SendContainerSnapshotForUID(ply, uid)
end

function CActions.quick_take_to_inventory(ply, args)
    local uid = ZScavActionState.ResolveContainerUID(ply, args)
    if not uid then return end
    local _, _, bag = ContainerSizeFor(ply, uid)
    if not bag then return end

    local idx = tonumber(args.index)
    local entry = idx and bag.contents[idx]
    if not entry then return end

    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end

    local can = ZSCAV:CanCarryMore(inv, entry, entry.uid)
    if not can then
        Notice(ply, "Too heavy to take: " .. tostring(entry.class))
        return
    end

    local ok, reason = ZSCAV:TryAddItem(ply, entry)
    if not ok then
        if reason == "weight" then
            Notice(ply, "Too heavy to take: " .. tostring(entry.class))
        else
            Notice(ply, "No room in inventory for " .. tostring(entry.class))
        end
        return
    end

    table.remove(bag.contents, idx)
    SaveContainerContents(ply, uid, bag.class, bag.contents)
    SyncInventory(ply)
    SendContainerSnapshotForUID(ply, uid)
end

function CActions.quick_equip(ply, args)
    local uid = ZScavActionState.ResolveContainerUID(ply, args)
    if not uid then return end
    local _, _, bag = ContainerSizeFor(ply, uid)
    if not bag then return end

    local idx = tonumber(args.index)
    local entry = idx and bag.contents[idx]
    if not entry then return end

    if ZSCAV:ResolveGrenadeInventoryClass(entry) then
        CActions.quick_take_to_inventory(ply, args)
        return
    end

    local def = ZSCAV:GetGearDef(entry.class)
    if def and def.slot then
        CActions.equip_from_container(ply, {
            from_uid = uid,
            from_index = idx,
            kind = "gear",
            slot = tostring(def.slot),
        })
        return
    end

    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end
    local slot = ResolveWeaponEquipSlot(inv, entry.class)
    if not slot then
        Notice(ply, "No open equip slot for " .. tostring(entry.class))
        return
    end

    CActions.equip_from_container(ply, {
        from_uid = uid,
        from_index = idx,
        kind = "weapon",
        slot = tostring(slot),
    })
end

-- Push an item from the player's inv into a specific open container window.
function CActions.put(ply, args)
    local uid = ZScavActionState.ResolveContainerUID(ply, args)
    if not uid then return end
    local gw, gh, bag = ContainerSizeFor(ply, uid)
    if not bag then return end
    if not ZScavActionState.ContainerAllowsPlayerInsert(bag.class) then
        Notice(ply, "That container does not accept player inserts.")
        return
    end
    local layoutBlocks = bag.layout or getContainerLayoutBlocks(bag.class, gw, gh)

    local inv = ZSCAV:GetInventory(ply)
    local list = inv and inv[args.from_grid]
    local entry = list and list[args.from_index]
    if not entry then return end

    if IsSecureClass(entry.class) then
        local sid = tostring(ply:SteamID64() or "")
        local stashUID = tostring(ZSCAV:GetCanonicalPlayerStashUID(sid, false) or "")
        if uid ~= stashUID then
            Notice(ply, "Secure containers can only be moved into your stash.")
            return
        end
    end

    -- Don't allow stuffing a bag into itself or its own ancestors (cycle).
    if entry.uid then
        for _, parentUID in ipairs(ply.zscav_container_chain or {}) do
            if parentUID == entry.uid then
                Notice(ply, "Cannot stuff a bag into itself.")
                return
            end
        end
    end

    local x = math.floor(tonumber(args.x) or -1)
    local y = math.floor(tonumber(args.y) or -1)
    if x < 0 or y < 0 then
        Notice(ply, "Invalid target cell.")
        return
    end

    -- Respect rotation hint first; allow opposite orientation if that fits.
    local ew, eh = entry.w, entry.h
    if args.rotated and ew ~= eh then
        ew, eh = eh, ew
    end
    if not fitsAt(bag.contents, x, y, ew, eh, gw, gh, nil, layoutBlocks) then
        if ew ~= eh and fitsAt(bag.contents, x, y, eh, ew, gw, gh, nil, layoutBlocks) then
            ew, eh = eh, ew
        else
            Notice(ply, "No room in target slot.")
            return
        end
    end

    table.remove(list, args.from_index)
    bag.contents[#bag.contents + 1] = CopyItemEntry(entry, {
        x = x,
        y = y,
        w = ew,
        h = eh,
    })
    SaveContainerContents(ply, uid, bag.class, bag.contents)
    SyncInventory(ply)
    SendContainerSnapshotForUID(ply, uid)
end

function CActions.quick_put_from_grid(ply, args)
    local uid = ZScavActionState.ResolveContainerUID(ply, args)
    if not uid then
        Notice(ply, "No open container.")
        return
    end

    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end

    ZScavActionState.QuickPutFromGridToContainer(
        ply,
        inv,
        tostring(args.from_grid or ""),
        tonumber(args.from_index),
        uid,
        args.rotated and true or false,
        false
    )
end

function CActions.quick_transfer_to_container(ply, args)
    local fromUID = tostring(args.from_uid or "")
    local targetUID = ZScavActionState.ResolveContainerUID(ply, args)
    local fromIndex = tonumber(args.from_index)
    if fromUID == "" or targetUID == nil or targetUID == "" or not fromIndex then return end
    if fromUID == targetUID then return end
    if not ZScavActionState.ContainerInChain(ply, fromUID)
        or not ZScavActionState.ContainerInChain(ply, targetUID) then
        return
    end

    local _, _, fromBag = ContainerSizeFor(ply, fromUID)
    local targetW, targetH, targetBag = ContainerSizeFor(ply, targetUID)
    if not fromBag or not targetBag then return end
    if not ZScavActionState.ContainerAllowsPlayerInsert(targetBag.class) then
        Notice(ply, "That container does not accept player inserts.")
        return
    end

    local entry = fromBag.contents[fromIndex]
    if not entry then return end

    if IsSecureClass(entry.class) then
        Notice(ply, "Secure containers cannot be transferred.")
        return
    end

    local itemUID = tostring(entry.uid or "")
    if itemUID ~= "" and (itemUID == targetUID or BagContainsUIDRecursive(itemUID, targetUID)) then
        Notice(ply, "Cannot create container cycle.")
        return
    end

    local layoutBlocks = targetBag.layout or getContainerLayoutBlocks(targetBag.class, targetW, targetH)
    local x, y, wasRotated = findFreeSpotAR(targetBag.contents, targetW, targetH, entry.w, entry.h, layoutBlocks)
    if not x then
        Notice(ply, "No room in target container.")
        return
    end

    local placedW = wasRotated and entry.h or entry.w
    local placedH = wasRotated and entry.w or entry.h

    table.remove(fromBag.contents, fromIndex)
    targetBag.contents[#targetBag.contents + 1] = CopyItemEntry(entry, {
        x = x,
        y = y,
        w = placedW,
        h = placedH,
    })

    SaveContainerContents(ply, fromUID, fromBag.class, fromBag.contents)
    SaveContainerContents(ply, targetUID, targetBag.class, targetBag.contents)
    SendContainerSnapshotForUID(ply, fromUID)
    SendContainerSnapshotForUID(ply, targetUID)
end

function CActions.quick_move_slot_to_container(ply, args)
    local uid = ZScavActionState.ResolveContainerUID(ply, args)
    if not uid then
        Notice(ply, "No open container.")
        return
    end

    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end
    ZScavActionState.QuickPutSlotToContainer(
        ply,
        inv,
        args.kind,
        args.slot,
        uid,
        false
    )
end

function Actions.quick_move_slot(ply, inv, args)
    local kind = tostring(args.kind or "")
    local slot = tostring(args.slot or "")
    local s = SlotEntryForDrag(inv, kind, slot)
    if not s then return end

    local chain = ply.zscav_container_chain
    local activeUID = chain and chain[#chain] or nil

    if IsSecureClass(s.class) then
        if activeUID and activeUID ~= "" then
            ZScavActionState.QuickPutSlotToContainer(ply, inv, kind, slot, activeUID, false)
        else
            Notice(ply, "Secure container can only be moved to stash.")
        end
        return
    end

    if activeUID and activeUID ~= "" then
        local movedToContainer = ZScavActionState.QuickPutSlotToContainer(
            ply,
            inv,
            kind,
            slot,
            activeUID,
            true
        )
        if movedToContainer then return end
    end

    local grids = ZSCAV:GetEffectiveGrids(inv)
    local targets = { "vest", "pocket", "backpack", "secure" }
    local skipGrid = nil
    local blockedSecureReason = nil

    if s.kind == "gear" then
        if s.slot == "backpack" then
            skipGrid = "backpack"
        elseif s.slot == "tactical_rig" or s.slot == "vest" then
            skipGrid = "vest"
        elseif s.slot == "secure_container" then
            skipGrid = "secure"
        end
    end

    for _, toGrid in ipairs(targets) do
        if toGrid ~= skipGrid then
            local blockedReason = GetPlayerGridInsertBlockReason and GetPlayerGridInsertBlockReason(toGrid, s) or nil
            if blockedReason then
                blockedSecureReason = blockedSecureReason or blockedReason
                continue
            end

            local toList = inv[toGrid]
            local g = grids and grids[toGrid] or nil
            if toList and g and (tonumber(g.w) or 0) > 0 and (tonumber(g.h) or 0) > 0 then
                local layout = getGridLayoutBlocks(inv, toGrid)
                local x, y, wasRotated = findFreeSpotAR(
                    toList,
                    tonumber(g.w) or 0,
                    tonumber(g.h) or 0,
                    s.w,
                    s.h,
                    layout
                )
                if x then
                    Actions.unequip_slot_to_grid(ply, inv, {
                        kind = kind,
                        slot = slot,
                        to_grid = toGrid,
                        x = x,
                        y = y,
                        rotated = wasRotated and true or false,
                    })
                    return
                end
            end
        end
    end

    Notice(ply, blockedSecureReason or "No room in quick-move destinations.")
end

function Actions.quick_move_inventory(ply, inv, args)
    local fromGrid = tostring(args.from_grid or "")
    local fromIdx = tonumber(args.from_index)
    local fromList = inv and inv[fromGrid]
    local entry = fromList and fromIdx and fromList[fromIdx]
    if not entry then return end

    local chain = ply.zscav_container_chain
    local activeUID = chain and chain[#chain] or nil
    if activeUID and activeUID ~= "" then
        local movedToContainer = ZScavActionState.QuickPutFromGridToContainer(
            ply,
            inv,
            fromGrid,
            fromIdx,
            activeUID,
            false,
            true
        )
        if movedToContainer then return end
        -- If an active container is open but insertion failed, continue with
        -- internal quick-move fallback across player grids.
    end

    local grids = ZSCAV:GetEffectiveGrids(inv)
    local targets = ZSCAV:ResolveGrenadeInventoryClass(entry)
        and { "pocket", "vest", "backpack" }
        or { "vest", "pocket", "backpack", "secure" }
    local blockedSecureReason = nil

    for _, toGrid in ipairs(targets) do
        if toGrid ~= fromGrid then
            local blockedReason = GetPlayerGridInsertBlockReason and GetPlayerGridInsertBlockReason(toGrid, entry) or nil
            if blockedReason then
                blockedSecureReason = blockedSecureReason or blockedReason
                continue
            end

            local toList = inv[toGrid]
            local g = grids and grids[toGrid] or nil
            if toList and g and (tonumber(g.w) or 0) > 0 and (tonumber(g.h) or 0) > 0 then
                local layout = getGridLayoutBlocks(inv, toGrid)
                local x, y, wasRotated = findFreeSpotAR(toList, tonumber(g.w) or 0, tonumber(g.h) or 0, entry.w, entry.h, layout)
                if x then
                    table.remove(fromList, fromIdx)
                    local ew = wasRotated and entry.h or entry.w
                    local eh = wasRotated and entry.w or entry.h
                    toList[#toList + 1] = CopyItemEntry(entry, {
                        x = x,
                        y = y,
                        w = ew,
                        h = eh,
                    })
                    SyncInventory(ply)
                    return
                end
            end
        end
    end

    Notice(ply, blockedSecureReason or "No room in quick-move destinations.")
end

function Actions.world_pickup(ply, _inv, args)
    local ent = Entity(tonumber(args.ent_index) or -1)
    if not IsValid(ent) or not CanUseWorldPickupEntity(ply, ent) then return end

    local mode = tostring(args.mode or "take")
    if ent:IsWeapon() then
        HandleWorldWeaponPickupChoice(ply, ent, mode)
        return
    end

    local packClass = ZSCAV:GetEntPackClass(ent)
    local def = ZSCAV:GetGearDef(packClass)
    if def and def.slot == "backpack" then
        HandleWorldBackpackPickupChoice(ply, ent, mode)
        return
    end

    if ZSCAV:IsArmorEntityClass(ent:GetClass()) then
        HandleWorldArmorPickupChoice(ply, ent, mode)
        return
    end

    if ResolveWorldGenericPickupEntry(ent) then
        HandleWorldGenericItemPickupChoice(ply, ent, mode)
    end
end

-- Equip directly from an open container window into an equipment slot.
function CActions.equip_from_container(ply, args)
    local fromUID = tostring(args.from_uid or "")
    if fromUID == "" or not ZScavActionState.ContainerInChain(ply, fromUID) then return end

    local _, _, bag = ContainerSizeFor(ply, fromUID)
    if not bag then return end

    local idx = tonumber(args.from_index)
    local entry = idx and bag.contents[idx]
    if not entry then return end

    local kind = tostring(args.kind or "")
    local slot = tostring(args.slot or "")
    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end

    if kind == "weapon" then
        local expect = ZSCAV:GetEquipWeaponSlot(entry.class)
        if not (ZSCAV.IsWeaponSlotCompatible and ZSCAV:IsWeaponSlotCompatible(expect, slot)) then
            Notice(ply, "Wrong weapon slot for " .. tostring(entry.class))
            return
        end

        inv.weapons = inv.weapons or {}
        local chosenSlot = ResolveWeaponEquipSlot(inv, entry.class, slot)
        if not chosenSlot then
            Notice(ply, "Not equippable: " .. tostring(entry.class))
            return
        end

        if inv.weapons[chosenSlot] then
            Notice(ply, "Weapon slot occupied: " .. slot .. " (right-click to unholster)")
            return
        end

        if not (weapons.GetStored(entry.class) or scripted_ents.GetStored(entry.class)) then
            Notice(ply, "Server has no class: " .. tostring(entry.class))
            return
        end

        table.remove(bag.contents, idx)
        SaveContainerContents(ply, fromUID, bag.class, bag.contents)

        local equippedEntry = CopyItemEntry(entry, { slot = chosenSlot }) or { class = entry.class, slot = chosenSlot }
        EnsureWeaponEntryRuntime(equippedEntry)
        inv.weapons[chosenSlot] = equippedEntry
        local wepEnt = GiveWeaponInstance(ply, equippedEntry)
        timer.Simple(0, function()
            if not IsValid(ply) then return end

            local selected = SelectWeaponEntry and select(1, SelectWeaponEntry(ply, equippedEntry))
            if selected then
                return
            else
                Notice(ply, "Equip failed: another addon blocked it.")
                inv.weapons[chosenSlot] = nil
                local _, _, rollbackBag = ContainerSizeFor(ply, fromUID)
                if rollbackBag then
                    local gw, gh = ZScavActionState.GetContainerGridSizeForClass(rollbackBag.class)
                    local rbLayout = rollbackBag.layout or getContainerLayoutBlocks(rollbackBag.class, gw, gh)
                    local x, y, wasRotated = findFreeSpotAR(rollbackBag.contents, gw, gh, entry.w, entry.h, rbLayout)
                    if x then
                        local ew = wasRotated and entry.h or entry.w
                        local eh = wasRotated and entry.w or entry.h
                        rollbackBag.contents[#rollbackBag.contents + 1] = CopyItemEntry(entry, {
                            x = x,
                            y = y,
                            w = ew,
                            h = eh,
                        })
                        SaveContainerContents(ply, fromUID, rollbackBag.class, rollbackBag.contents)
                    end
                    SendContainerSnapshotForUID(ply, fromUID)
                end
                SyncInventory(ply)
            end
        end)

        SyncInventory(ply)
        SendContainerSnapshotForUID(ply, fromUID)
        return
    end

    if kind ~= "gear" then return end

    local def = ZSCAV:GetGearDef(entry.class)
    if not def then
        Notice(ply, "Not a gear item.")
        return
    end

    if def.slot ~= slot then
        Notice(ply, "Wrong gear slot for " .. tostring(entry.class))
        return
    end

    inv.gear = inv.gear or {}
    if inv.gear[slot] then
        Notice(ply, "Slot occupied: " .. slot)
        return
    end

    if slot == "secure_container" then
        local sid = tostring(ply:SteamID64() or "")
        local stashUID = tostring(ZSCAV:GetCanonicalPlayerStashUID(sid, false) or "")
        if fromUID ~= stashUID then
            Notice(ply, "Secure container can only be equipped from stash.")
            return
        end
    end

    -- Enforce carry cap when equipping backpacks from containers.
    if slot == "backpack" then
        local can = ZSCAV:CanCarryMore(inv, entry, entry.uid)
        if not can then
            Notice(ply, "Too heavy to carry: " .. tostring(def.name or entry.class))
            return
        end
    end

    if ZSCAV:IsArmorEntityClass(entry.class) then
        local ok = hg and hg.AddArmor and hg.AddArmor(ply, entry.class)
        if not ok then
            Notice(ply, "Could not equip armor: " .. tostring(entry.class))
            return
        end
    end

    table.remove(bag.contents, idx)
    SaveContainerContents(ply, fromUID, bag.class, bag.contents)

    if slot == "backpack" then
        BackpackEquip(ply, inv, entry.class, entry.uid)
        SendContainerSnapshotForUID(ply, fromUID)
        return
    end

    if (slot == "tactical_rig" or slot == "vest") and def.compartment then
        local equipUID = tostring(entry.uid or "")
        if equipUID == "" then equipUID = tostring(ZSCAV:CreateBag(entry.class) or "") end
        if equipUID == "" then
            Notice(ply, "Could not allocate rig storage.")
            return
        end
        VestEquip(ply, inv, entry.class, equipUID)
        SendContainerSnapshotForUID(ply, fromUID)
        return
    end

    local equipUID = entry.uid
    if def.secure == true and (not equipUID or equipUID == "") then
        equipUID = ZSCAV:CreateBag(entry.class)
    end
    inv.gear[slot] = { class = entry.class, uid = equipUID, slot = slot }

    if def.secure == true then
        local sid = tostring(ply:SteamID64() or "")
        local loaded = ZSCAV:LoadBag(tostring(equipUID or ""))
        inv.secure = (loaded and loaded.contents) or {}
        local st = GetPlayerSecureState(sid)
        if st then
            st.issued = 1
            st.status = "equipped"
            st.class = tostring(entry.class)
            st.uid = tostring(equipUID or "")
            SavePlayerSecureState(st)
        end
    end

    SyncInventory(ply)
    SendContainerSnapshotForUID(ply, fromUID)
end

function CActions.move(ply, args)
    local uid = ZScavActionState.ResolveContainerUID(ply, args)
    if not uid then return end
    local gw, gh, bag = ContainerSizeFor(ply, uid)
    if not bag then return end
    local layoutBlocks = bag.layout or getContainerLayoutBlocks(bag.class, gw, gh)

    local idx = tonumber(args.index)
    local entry = idx and bag.contents[idx]
    if not entry then return end

    local nx, ny = tonumber(args.x) or 0, tonumber(args.y) or 0
    -- Support rotation during drag (R key). Validate it's a genuine transpose.
    local desiredW, desiredH = entry.w, entry.h
    if args.rotated and entry.w ~= entry.h then
        desiredW, desiredH = entry.h, entry.w
    end
    if not fitsAt(bag.contents, nx, ny, desiredW, desiredH, gw, gh, idx, layoutBlocks) then
        if desiredW ~= desiredH and fitsAt(bag.contents, nx, ny, desiredH, desiredW, gw, gh, idx, layoutBlocks) then
            desiredW, desiredH = desiredH, desiredW
        else
            return
        end
    end
    entry.x, entry.y = nx, ny
    entry.w, entry.h = desiredW, desiredH
    SaveContainerContents(ply, uid, bag.class, bag.contents)
    SendContainerSnapshotForUID(ply, uid)
end

-- Rotate an item in place inside a container (R key, no drag). Swaps w/h and
-- validates the new footprint still fits. Square items are no-ops.
function CActions.rotate(ply, args)
    local uid = ZScavActionState.ResolveContainerUID(ply, args)
    if not uid then return end
    local gw, gh, bag = ContainerSizeFor(ply, uid)
    if not bag then return end
    local layoutBlocks = bag.layout or getContainerLayoutBlocks(bag.class, gw, gh)

    local idx = tonumber(args.index)
    local entry = idx and bag.contents[idx]
    if not entry or entry.w == entry.h then return end

    if not fitsAt(bag.contents, entry.x, entry.y, entry.h, entry.w, gw, gh, idx, layoutBlocks) then
        Notice(ply, "No room to rotate here.")
        return
    end
    entry.w, entry.h = entry.h, entry.w
    SaveContainerContents(ply, uid, bag.class, bag.contents)
    SendContainerSnapshotForUID(ply, uid)
end

function CActions.drop_to_floor(ply, args)
    local uid = ZScavActionState.ResolveContainerUID(ply, args)
    if not uid then return end
    local _, _, bag = ContainerSizeFor(ply, uid)
    if not bag then return end

    local idx = tonumber(args.index)
    local entry = idx and bag.contents[idx]
    if not entry then return end

    if IsSecureClass(entry.class) then
        local sid = tostring(ply:SteamID64() or "")
        local stashUID = tostring(ZSCAV:GetCanonicalPlayerStashUID(sid, false) or "")
        if uid ~= stashUID then
            Notice(ply, "Secure containers cannot be dropped.")
            return
        end

        table.remove(bag.contents, idx)
        SaveContainerContents(ply, uid, bag.class, bag.contents)
        if entry.uid and entry.uid ~= "" then
            ZSCAV:DeleteBag(entry.uid)
        end

        local st = GetPlayerSecureState(sid)
        if st then
            st.issued = 1
            st.status = "destroyed"
            st.class = tostring(entry.class)
            st.uid = ""
            SavePlayerSecureState(st)
        end

        Notice(ply, "Secure container destroyed.")
        SendContainerSnapshotForUID(ply, uid)
        return
    end

    if IsVendorTicketEntry(entry) then
        if args.confirm_ticket_destroy ~= true then
            Notice(ply, "Vendor tickets must be discarded from their confirmation prompt.")
            return
        end

        table.remove(bag.contents, idx)
        SaveContainerContents(ply, uid, bag.class, bag.contents)
        Notice(ply, "Vendor ticket discarded.")
        SendContainerSnapshotForUID(ply, uid)
        return
    end

    table.remove(bag.contents, idx)
    SaveContainerContents(ply, uid, bag.class, bag.contents)
    SpawnDroppedClass(ply, entry.class, entry.uid, entry)
    SendContainerSnapshotForUID(ply, uid)
end

-- Transfer an item directly between two open container windows.
function CActions.transfer(ply, args)
    local fromUID = tostring(args.from_uid or "")
    local toUID   = tostring(args.to_uid or "")
    local fromIdx = tonumber(args.from_index)
    if fromUID == "" or toUID == "" or not fromIdx then return end
    if not ZScavActionState.ContainerInChain(ply, fromUID)
        or not ZScavActionState.ContainerInChain(ply, toUID) then
        return
    end

    local _, _, fromBag = ContainerSizeFor(ply, fromUID)
    local toGW, toGH, toBag = ContainerSizeFor(ply, toUID)
    if not fromBag or not toBag then return end
    if not ZScavActionState.ContainerAllowsPlayerInsert(toBag.class) then
        Notice(ply, "That container does not accept player inserts.")
        return
    end
    local toLayout = toBag.layout or getContainerLayoutBlocks(toBag.class, toGW, toGH)

    local entry = fromBag.contents[fromIdx]
    if not entry then return end

    if IsSecureClass(entry.class) then
        Notice(ply, "Secure containers cannot be transferred.")
        return
    end

    -- Anti-cycle: cannot put a bag into a container that it already contains (itself).
    if entry.uid then
        for _, uid in ipairs(ply.zscav_container_chain or {}) do
            if uid == entry.uid then
                Notice(ply, "Cannot create container cycle.")
                return
            end
        end
    end

    function CActions.inspect_attach_install(ply, args)
        local inv = ZSCAV:GetInventory(ply)
        if not inv then return end

        if ActionResolverHelpers.AttachmentInstallRequiresPlayerInventory(args) then
            Notice(ply, "Move the weapon and attachment into your inventory to modify attachments.")
            return
        end

        local attachmentEntry, attachmentList, attachmentIndex = ActionResolverHelpers.ResolveAttachmentActionEntry(inv, args)
        if not attachmentEntry then
            Notice(ply, "Attachment item not found.")
            return
        end

        ZSCAV.InstallAttachmentIntoWeaponEntry(
            ply,
            inv,
            args,
            attachmentEntry,
            function()
                table.remove(attachmentList, attachmentIndex)
                return true
            end,
            function()
                table.insert(attachmentList, attachmentIndex, attachmentEntry)
            end
        )
    end

    local x = math.floor(tonumber(args.x) or -1)
    local y = math.floor(tonumber(args.y) or -1)
    if x < 0 or y < 0 then
        Notice(ply, "Invalid target cell.")
        return
    end

    local ew, eh = entry.w, entry.h
    if args.rotated and ew ~= eh then
        ew, eh = eh, ew
    end
    if not fitsAt(toBag.contents, x, y, ew, eh, toGW, toGH, nil, toLayout) then
        if ew ~= eh and fitsAt(toBag.contents, x, y, eh, ew, toGW, toGH, nil, toLayout) then
            ew, eh = eh, ew
        else
            Notice(ply, "No room in target slot.")
            return
        end
    end

    table.remove(fromBag.contents, fromIdx)
    toBag.contents[#toBag.contents + 1] = CopyItemEntry(entry, {
        x = x,
        y = y,
        w = ew,
        h = eh,
    })
    SaveContainerContents(ply, fromUID, fromBag.class, fromBag.contents)
    SaveContainerContents(ply, toUID, toBag.class, toBag.contents)
    SendContainerSnapshotForUID(ply, fromUID)
    if toUID ~= fromUID then
        SendContainerSnapshotForUID(ply, toUID)
    end
end

function CActions.put_into_owned_item(ply, args)
    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end

    local targetGrid = tostring(args.target_grid or "")
    local targetIdx = tonumber(args.target_index)
    local targetList = inv[targetGrid]
    local targetEntry = targetList and targetIdx and targetList[targetIdx]
    if not targetEntry or not targetEntry.class then return end

    local targetDef = ZSCAV:GetGearDef(targetEntry.class)
    local targetCanHold = targetEntry.uid and targetEntry.uid ~= ""
    if not targetCanHold then
        targetCanHold = targetDef and (targetDef.slot == "backpack" or targetDef.compartment or targetDef.secure) or false
    end
    if not targetCanHold then
        Notice(ply, "That item has no container.")
        return
    end

    local targetUID = tostring(targetEntry.uid or "")
    local createdTargetUID = false
    if targetUID == "" then
        targetUID = tostring(ZSCAV:CreateBag(targetEntry.class) or "")
        if targetUID == "" then
            Notice(ply, "Could not allocate item container.")
            return
        end
        targetEntry.uid = targetUID
        createdTargetUID = true
    end

    local targetBag = ZSCAV:LoadBag(targetUID)
    if not targetBag and createdTargetUID then
        targetBag = { class = targetEntry.class, contents = {} }
    end
    if not targetBag then
        Notice(ply, "Target container is not ready.")
        return
    end
    targetBag.contents = targetBag.contents or {}

    local targetW, targetH = ZScavActionState.GetContainerGridSizeForClass(targetBag.class or targetEntry.class)
    local targetLayout = getContainerLayoutBlocks(targetBag.class or targetEntry.class, targetW, targetH)

    local sourceFromUID = tostring(args.from_uid or "")
    local sourceFromGrid = tostring(args.from_grid or "")
    local sourceIdx = tonumber(args.from_index)
    if not sourceIdx then return end

    local sourceEntry, sourceBag, sourceList = nil, nil, nil
    if sourceFromUID ~= "" then
        if not ZScavActionState.ContainerInChain(ply, sourceFromUID) then
            Notice(ply, "Container is not open.")
            return
        end
        local _, _, sb = ContainerSizeFor(ply, sourceFromUID)
        if not sb then return end
        sourceBag = sb
        sourceEntry = sourceBag.contents[sourceIdx]
    else
        sourceList = inv[sourceFromGrid]
        sourceEntry = sourceList and sourceList[sourceIdx]
    end

    if not sourceEntry then return end

    if IsSecureClass(sourceEntry.class) then
        Notice(ply, "Secure containers can only be moved into your stash.")
        return
    end

    if sourceFromGrid ~= "" and sourceFromGrid == targetGrid and sourceIdx == targetIdx then
        return
    end

    local itemUID = tostring(sourceEntry.uid or "")
    if itemUID ~= "" then
        if itemUID == targetUID or BagContainsUIDRecursive(itemUID, targetUID) then
            Notice(ply, "Cannot create container cycle.")
            return
        end
    end

    local sw, sh = sourceEntry.w, sourceEntry.h
    if args.rotated and sw ~= sh then
        sw, sh = sh, sw
    end

    local x, y = findFreeSpot(targetBag.contents, targetW, targetH, sw, sh, targetLayout)
    local ew, eh = sw, sh
    if not x and sw ~= sh then
        x, y = findFreeSpot(targetBag.contents, targetW, targetH, sh, sw, targetLayout)
        if x then
            ew, eh = sh, sw
        end
    end
    if not x then
        Notice(ply, "No room in target container.")
        return
    end

    local sourceRemoved = nil
    if sourceBag then
        sourceRemoved = table.remove(sourceBag.contents, sourceIdx)
    else
        sourceRemoved = table.remove(sourceList, sourceIdx)
    end

    if not sourceRemoved then return end

    targetBag.contents[#targetBag.contents + 1] = CopyItemEntry(sourceRemoved, {
        x = x,
        y = y,
        w = ew,
        h = eh,
    })

    local targetSaved = ZSCAV:SaveBag(targetUID, targetBag.class or targetEntry.class, targetBag.contents)
    if not targetSaved then
        table.remove(targetBag.contents, #targetBag.contents)
        if sourceBag then
            table.insert(sourceBag.contents, sourceIdx, sourceRemoved)
        else
            table.insert(sourceList, sourceIdx, sourceRemoved)
        end
        Notice(ply, "Could not save target container.")
        return
    end

    if sourceBag then
        local sourceSaved = SaveContainerContents(ply, sourceFromUID, sourceBag.class, sourceBag.contents)
        if sourceSaved == false then
            -- Roll back both sides to avoid deletion/duplication on save failure.
            table.remove(targetBag.contents, #targetBag.contents)
            ZSCAV:SaveBag(targetUID, targetBag.class or targetEntry.class, targetBag.contents)
            table.insert(sourceBag.contents, sourceIdx, sourceRemoved)
            SaveContainerContents(ply, sourceFromUID, sourceBag.class, sourceBag.contents)
            Notice(ply, "Could not save source container.")
            return
        end
    end

    SyncInventory(ply)
    if sourceBag then
        SendContainerSnapshotForUID(ply, sourceFromUID)
    end
end

function CActions.put_to_owned_slot(ply, args)
    local fromUID = tostring(args.from_uid or "")
    local slotID = tostring(args.slot or "")
    local fromIdx = tonumber(args.from_index)
    if fromUID == "" or slotID == "" or not fromIdx then return end
    if not ZScavActionState.ContainerInChain(ply, fromUID) then return end

    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end

    local target = GetEquippedContainerForSlot(inv, slotID)
    if not target then
        Notice(ply, "No equipped container in that slot.")
        return
    end
    if target.w <= 0 or target.h <= 0 then
        Notice(ply, "Target container has no storage space.")
        return
    end

    if target.uid == fromUID then
        return
    end

    local _, _, fromBag = ContainerSizeFor(ply, fromUID)
    if not fromBag then return end

    local entry = fromBag.contents[fromIdx]
    if not entry then return end

    if GetPlayerGridInsertBlockReason then
        local blockedReason = GetPlayerGridInsertBlockReason(target.gridName, entry)
        if blockedReason then
            Notice(ply, blockedReason)
            return
        end
    end

    if IsSecureClass(entry.class) then
        Notice(ply, "Secure containers can only be moved into your stash.")
        return
    end

    local itemUID = tostring(entry.uid or "")
    if itemUID ~= "" then
        if itemUID == target.uid or BagContainsUIDRecursive(itemUID, target.uid) then
            Notice(ply, "Cannot create container cycle.")
            return
        end
    end

    local x, y, wasRotated = findFreeSpotAR(target.list, target.w, target.h, entry.w, entry.h, target.layout)
    if not x then
        Notice(ply, "No room in target container.")
        return
    end
    local ew = wasRotated and entry.h or entry.w
    local eh = wasRotated and entry.w or entry.h

    table.remove(fromBag.contents, fromIdx)
    SaveContainerContents(ply, fromUID, fromBag.class, fromBag.contents)

    target.list[#target.list + 1] = CopyItemEntry(entry, {
        x = x,
        y = y,
        w = ew,
        h = eh,
    })

    SyncInventory(ply)
    if ZSCAV.EquippedContainerTargetIsOpen(ply, target.uid) then
        SendContainerSnapshotForUID(ply, target.uid)
    end
    SendContainerSnapshotForUID(ply, fromUID)
end

ZSCAV.ContainerActionCooldown = ZSCAV.ContainerActionCooldown or {}

net.Receive("ZScavContainerAction", function(_, ply)
    if not IsValid(ply) or not ZSCAV:IsActive() then return end
    local now = CurTime()
    if (ZSCAV.ContainerActionCooldown[ply] or 0) > now then return end
    ZSCAV.ContainerActionCooldown[ply] = now + 0.05

    local action = net.ReadString()
    local sz = net.ReadUInt(16)

    local isCloseAction = action == "close_all" or action == "close_window"
    if not isCloseAction and ZSCAV.CanPlayerUseInventory and not ZSCAV:CanPlayerUseInventory(ply) then return end

    local args = {}
    if sz > 0 and sz < 16384 then
        args = util.JSONToTable(net.ReadData(sz) or "") or {}
    end

    -- Periodically re-validate that the chain root is still reachable.
    local chain = ply.zscav_container_chain
    if chain and chain[1] then
        local root = chain[1]
        if not (ZScavActionState.PlayerOwnsUID(ply, root) or ZScavActionState.FindWorldBag(ply, root)) then
            ply.zscav_container_chain = nil
            net.Start("ZScavContainerClose") net.WriteString("") net.Send(ply)
            return
        end
    end

    local h = CActions[action]
    if h then h(ply, args) end
end)

net.Receive("ZScavContainerClose", function(_, ply)
    if not IsValid(ply) then return end
    ply.zscav_container_chain = nil
end)

-- Close any open container session on death / disconnect.
hook.Add("PlayerDeath", "ZSCAV_ContainerCloseOnDeath", function(ply)
    if IsValid(ply) then ply.zscav_container_chain = nil end
end)
hook.Add("PlayerDisconnected", "ZSCAV_ContainerCloseOnLeave", function(ply)
    if IsValid(ply) then ply.zscav_container_chain = nil end
end)
end

-- ---------------------------------------------------------------
-- Drop-equipment radial bridge: client clicks a backpack row in the
-- hg armor menu, this unequips it via the standard BackpackUnequip path
-- so the SQL bag is repacked and a fresh ragdoll is spawned in front of
-- the player.
-- ---------------------------------------------------------------
ZScavActionState.DropEquipmentCooldown = ZScavActionState.DropEquipmentCooldown or {}
net.Receive("ZScavBackpackDrop", function(_len, ply)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) then return end
    -- Hard rate-limit: even with the BackpackUnequip re-entrancy lock,
    -- a spammy client could fire this faster than the SyncInventory
    -- round-trip resets `inv.gear.backpack` on their end, so guard at
    -- the net boundary too.
    local now = CurTime()
    if (ZScavActionState.DropEquipmentCooldown[ply] or 0) > now then return end
    ZScavActionState.DropEquipmentCooldown[ply] = now + 0.5

    if ply.zscav_unequip_lock then return end
    local inv = ZSCAV:GetInventory(ply)
    if not inv then return end
    if not (inv.gear and inv.gear.backpack) then return end
    BackpackUnequip(ply, inv)
end)
