-- ZScav safe-zone inventory persistence and restore.

local ctx = ZSCAV and ZSCAV.SafeZoneContext or {}

local NewInventory = ctx.NewInventory
local GetPlayerSecureState = ctx.GetPlayerSecureState
local SavePlayerSecureState = ctx.SavePlayerSecureState
local EnsureSecureContainerForInventory = ctx.EnsureSecureContainerForInventory
local MigrateLegacyGrids = ctx.MigrateLegacyGrids
local SyncInventory = ctx.SyncInventory
local Notice = ctx.Notice
local BackpackEquip = ctx.BackpackEquip
local VestEquip = ctx.VestEquip
local CopyItemEntry = ctx.CopyItemEntry
local EnsureWeaponEntryRuntime = ctx.EnsureWeaponEntryRuntime
local GiveWeaponInstance = ctx.GiveWeaponInstance
local CopyCorpseEntryList = ctx.CopyCorpseEntryList
local CopyCorpseEntryMap = ctx.CopyCorpseEntryMap

if not (isfunction(NewInventory)
    and isfunction(GetPlayerSecureState)
    and isfunction(SavePlayerSecureState)
    and isfunction(EnsureSecureContainerForInventory)
    and isfunction(MigrateLegacyGrids)
    and isfunction(SyncInventory)
    and isfunction(Notice)
    and isfunction(BackpackEquip)
    and isfunction(VestEquip)
    and isfunction(CopyItemEntry)
    and isfunction(EnsureWeaponEntryRuntime)
    and isfunction(GiveWeaponInstance)
    and isfunction(CopyCorpseEntryList)
    and isfunction(CopyCorpseEntryMap)) then
    ErrorNoHalt("[ZScav] Safe-zone module missing context.\n")
    return
end

function ZSCAV:GetPlayerSafeZoneContext(ply)
    if not IsValid(ply) then return false, nil end

    local lib = rawget(_G, "ZCitySafeZones")
    if istable(lib) and isfunction(lib.FindZoneAtPos) then
        local zone = lib.FindZoneAtPos(ply:GetPos(), lib.ServerZones or {}, 0)
        if zone then
            return true, zone
        end
    end

    if ply:GetNWBool("ZCityInSafeZone", false) then
        return true, {
            id = tostring(ply:GetNWString("ZCitySafeZoneID", "") or ""),
            name = tostring(ply:GetNWString("ZCitySafeZoneName", "") or ""),
        }
    end

    return false, nil
end

function ZSCAV:BuildSafeZoneInventorySnapshot(inv)
    if not istable(inv) then return nil end

    return {
        gear = CopyCorpseEntryMap(inv.gear),
        weapons = CopyCorpseEntryMap(inv.weapons),
        pocket = CopyCorpseEntryList(inv.pocket),
        vest = CopyCorpseEntryList(inv.vest),
        backpack = CopyCorpseEntryList(inv.backpack),
        secure = CopyCorpseEntryList(inv.secure),
        quickslots = CopyCorpseEntryMap(inv.quickslots),
        grids = table.Copy(inv.grids or {}),
        updated = os.time(),
    }
end

local ZSCAV_SAFEZONE_INV_DATA_DIR = "zscav_safezone_inventory"
local ZSCAV_SAFEZONE_INV_TABLE = "zscav_safezone_inventory"
local ZSCAV_SAFEZONE_INV_SCHEMA = [[
CREATE TABLE IF NOT EXISTS zscav_safezone_inventory (
    owner_sid64  TEXT PRIMARY KEY,
    snapshot_json TEXT NOT NULL,
    updated      INTEGER NOT NULL DEFAULT 0
)
]]

local function NormalizeSafeZoneInventorySnapshot(snapshot)
    if not istable(snapshot) then return nil end

    return {
        gear = CopyCorpseEntryMap(snapshot.gear),
        weapons = CopyCorpseEntryMap(snapshot.weapons),
        pocket = CopyCorpseEntryList(snapshot.pocket),
        vest = CopyCorpseEntryList(snapshot.vest),
        backpack = CopyCorpseEntryList(snapshot.backpack),
        secure = CopyCorpseEntryList(snapshot.secure),
        quickslots = CopyCorpseEntryMap(snapshot.quickslots),
        grids = table.Copy(snapshot.grids or {}),
        updated = tonumber(snapshot.updated) or os.time(),
    }
end

local function GetSafeZoneInventorySnapshotKey(snapshot)
    local comparable = NormalizeSafeZoneInventorySnapshot(snapshot)
    if not comparable then return "" end

    comparable.updated = nil
    return util.CRC(util.TableToJSON(comparable, false) or "{}")
end

local function EnsureSafeZoneInventoryDataDir()
    if not file.IsDir(ZSCAV_SAFEZONE_INV_DATA_DIR, "DATA") then
        file.CreateDir(ZSCAV_SAFEZONE_INV_DATA_DIR)
    end
end

local function EnsureSafeZoneInventorySchema()
    if sql.TableExists(ZSCAV_SAFEZONE_INV_TABLE) then return true end

    local ok = sql.Query(ZSCAV_SAFEZONE_INV_SCHEMA)
    if ok == false then
        ErrorNoHalt("[ZScav] Failed to create safezone inventory table: " .. tostring(sql.LastError()) .. "\n")
        return false
    end

    return true
end

local function GetSafeZoneInventorySnapshotPath(ownerSID64)
    ownerSID64 = string.Trim(tostring(ownerSID64 or ""))
    if ownerSID64 == "" then return "" end

    EnsureSafeZoneInventoryDataDir()
    return ZSCAV_SAFEZONE_INV_DATA_DIR .. "/" .. ownerSID64 .. ".json"
end

local function SaveSafeZoneInventorySnapshotLocal(ownerSID64, snapshot)
    ownerSID64 = string.Trim(tostring(ownerSID64 or ""))
    snapshot = NormalizeSafeZoneInventorySnapshot(snapshot)
    if ownerSID64 == "" or not snapshot then return false end

    local path = GetSafeZoneInventorySnapshotPath(ownerSID64)
    if path == "" then return false end

    file.Write(path, util.TableToJSON(snapshot, false) or "{}")
    return true
end

local function LoadSafeZoneInventorySnapshotLocal(ownerSID64)
    local path = GetSafeZoneInventorySnapshotPath(ownerSID64)
    if path == "" then return nil end

    local raw = file.Read(path, "DATA")
    if not raw or raw == "" then return nil end

    return NormalizeSafeZoneInventorySnapshot(util.JSONToTable(raw) or nil)
end

local function DeleteSafeZoneInventorySnapshotLocal(ownerSID64)
    local path = GetSafeZoneInventorySnapshotPath(ownerSID64)
    if path == "" then return false end
    if not file.Exists(path, "DATA") then return true end

    file.Delete(path)
    return not file.Exists(path, "DATA")
end

local function DeleteSafeZoneInventorySnapshotSQL(ownerSID64)
    ownerSID64 = string.Trim(tostring(ownerSID64 or ""))
    if ownerSID64 == "" then return false end
    if not sql.TableExists(ZSCAV_SAFEZONE_INV_TABLE) and not EnsureSafeZoneInventorySchema() then return false end

    return sql.Query(
        "DELETE FROM " .. ZSCAV_SAFEZONE_INV_TABLE .. " WHERE owner_sid64 = " .. SQLStr(ownerSID64)
    ) ~= false
end

function ZSCAV:ClearSafeZoneInventorySnapshots(plyOrSID64)
    local ownerSID64 = ""
    local ply = nil

    if IsValid(plyOrSID64) then
        ply = plyOrSID64
        ownerSID64 = tostring(ply:SteamID64() or "")
    else
        ownerSID64 = string.Trim(tostring(plyOrSID64 or ""))
    end

    if ownerSID64 == "" then return false end

    DeleteSafeZoneInventorySnapshotLocal(ownerSID64)
    DeleteSafeZoneInventorySnapshotSQL(ownerSID64)

    if IsValid(ply) then
        ply.zscav_safezone_inventory_restore_pending = nil
        ply.zscav_safezone_inventory_restore_in_progress = nil
        ply.zscav_safezone_inventory_snapshot_crc = nil
    end

    return true
end

local function StripSafeZoneRestoreWeapons(ply)
    if not IsValid(ply) then return end

    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and tostring(wep:GetClass() or "") ~= "weapon_hands_sh" then
            ply:StripWeapon(wep:GetClass())
        end
    end
end

local function ClearSafeZoneRestoreArmor(ply)
    if not IsValid(ply) then return end

    ply.armors = ply.armors or ply:GetNetVar("Armor", {}) or {}
    for _, equipment in pairs(table.Copy(ply.armors or {})) do
        ZSCAV:RemoveArmorNoDrop(ply, equipment)
    end

    ply.armors = {}
    if ply.SyncArmor then
        ply:SyncArmor()
    end
    if ply.SetNetVar then
        ply:SetNetVar("Armor", {})
    end
    if ply.SetArmor then
        ply:SetArmor(0)
    end
end

local function PersistSafeZoneContainerBag(entry, contents)
    if not istable(entry) then return "" end

    local class = tostring(entry.class or "")
    local uid = tostring(entry.uid or "")
    if class == "" then return "" end
    if uid == "" then
        uid = tostring(ZSCAV:CreateBag(class) or "")
    end
    if uid == "" then return "" end

    ZSCAV:SaveBag(uid, class, CopyCorpseEntryList(contents))
    return uid
end

local function RestoreSafeZoneSimpleGearSlot(ply, inv, slotID, entry, secureContents)
    if not (IsValid(ply) and istable(inv) and istable(entry)) then return false end

    local class = tostring(entry.class or "")
    local def = ZSCAV:GetGearDef(class)
    if class == "" or not def then return false end

    local restoredEntry = CopyItemEntry(entry, {
        slot = slotID,
    }) or {
        class = class,
        slot = slotID,
    }

    local uid = tostring(restoredEntry.uid or "")
    if def.secure == true then
        uid = PersistSafeZoneContainerBag(restoredEntry, secureContents)
        restoredEntry.uid = uid
    end

    if ZSCAV:IsArmorEntityClass(class) then
        local placement = ZSCAV:GetArmorPlacement(class)
        local equipped = hg and hg.AddArmor and hg.AddArmor(ply, class)
        if not (equipped or (placement and ply.armors and ply.armors[placement])) then
            return false
        end
    end

    inv.gear[slotID] = restoredEntry

    if def.secure == true then
        local loaded = ZSCAV:LoadBag(tostring(uid or ""))
        inv.secure = CopyCorpseEntryList((loaded and loaded.contents) or secureContents)

        local sid = tostring(ply:SteamID64() or "")
        local st = GetPlayerSecureState(sid)
        if st then
            st.issued = 1
            st.status = "equipped"
            st.class = class
            st.uid = tostring(uid or "")
            SavePlayerSecureState(st)
        end
    end

    return true
end

local function RestoreSafeZoneContainerGear(ply, inv, entry, contents)
    if not (IsValid(ply) and istable(inv) and istable(entry)) then return false end

    local class = tostring(entry.class or "")
    if class == "" then return false end

    local uid = PersistSafeZoneContainerBag(entry, contents)
    if uid == "" then return false end

    if ZSCAV:IsArmorEntityClass(class) then
        local placement = ZSCAV:GetArmorPlacement(class)
        local equipped = hg and hg.AddArmor and hg.AddArmor(ply, class)
        if not (equipped or (placement and ply.armors and ply.armors[placement])) then
            return false
        end
    end

    if ZSCAV:GetGearDef(class) and ZSCAV:GetGearDef(class).slot == "backpack" then
        inv.backpack = {}
        BackpackEquip(ply, inv, class, uid)
        return true
    end

    inv.vest = {}
    VestEquip(ply, inv, class, uid)
    return true
end

function ZSCAV:QueueSafeZoneInventoryRestore(ply, snapshot, options)
    if not IsValid(ply) then return false end

    snapshot = NormalizeSafeZoneInventorySnapshot(snapshot)
    if not snapshot then return false end

    options = istable(options) and options or {}
    ply.zscav_safezone_inventory_restore_pending = {
        snapshot = snapshot,
        source = tostring(options.source or ""),
        owner_sid64 = tostring(options.owner_sid64 or ply:SteamID64() or ""),
    }

    return true
end

function ZSCAV:PersistSafeZoneInventorySnapshot(ply, options)
    if not IsValid(ply) then return false end

    options = istable(options) and options or {}
    if not options.allow_inactive and not self:IsActive() then return false end
    if ply.zscav_safezone_inventory_restore_in_progress then return false end
    if not options.allow_raid and ply.zscav_raid_active then return false end

    local pending = options.use_pending_restore
        and istable(ply.zscav_safezone_inventory_restore_pending)
        and ply.zscav_safezone_inventory_restore_pending
        or nil
    local inSafeZone = select(1, self:GetPlayerSafeZoneContext(ply))
    if not inSafeZone and not pending then
        ply.zscav_safezone_inventory_snapshot_crc = nil
        return false
    end

    local ownerSID64 = tostring(ply:SteamID64() or "")
    if ownerSID64 == "" then return false end

    local snapshot = NormalizeSafeZoneInventorySnapshot(options.snapshot)
    if not snapshot and pending then
        snapshot = NormalizeSafeZoneInventorySnapshot(pending.snapshot)
    end
    if not snapshot then
        snapshot = self:BuildSafeZoneInventorySnapshot(options.inventory or self:GetInventory(ply))
    end
    if not snapshot then return false end

    local snapshotKey = GetSafeZoneInventorySnapshotKey(snapshot)
    local snapshotPath = GetSafeZoneInventorySnapshotPath(ownerSID64)
    local hasLocalSnapshot = snapshotPath ~= "" and file.Exists(snapshotPath, "DATA")

    if not options.force_write
        and snapshotKey ~= ""
        and hasLocalSnapshot
        and ply.zscav_safezone_inventory_snapshot_crc == snapshotKey then
        return true
    end

    local saved = SaveSafeZoneInventorySnapshotLocal(ownerSID64, snapshot)
    if saved and snapshotKey ~= "" then
        ply.zscav_safezone_inventory_snapshot_crc = snapshotKey
    end

    return saved
end

function ZSCAV:MaybeSnapshotSafeZoneInventory(ply)
    return self:PersistSafeZoneInventorySnapshot(ply)
end

function ZSCAV:ApplyQueuedSafeZoneInventoryRestore(ply)
    if not (IsValid(ply) and self:IsActive() and ply:Alive()) then return false end

    local pending = istable(ply.zscav_safezone_inventory_restore_pending)
        and ply.zscav_safezone_inventory_restore_pending
        or nil
    if not pending then return false end

    local snapshot = NormalizeSafeZoneInventorySnapshot(pending.snapshot)
    if not snapshot then
        ply.zscav_safezone_inventory_restore_pending = nil
        return false
    end

    ply.zscav_safezone_inventory_restore_pending = nil
    ply.zscav_safezone_inventory_restore_in_progress = true

    local inv = NewInventory()
    inv.gear = {}
    inv.weapons = {}
    inv.pocket = CopyCorpseEntryList(snapshot.pocket)
    inv.vest = {}
    inv.backpack = {}
    inv.secure = {}
    inv.quickslots = CopyCorpseEntryMap(snapshot.quickslots)
    inv.grids = table.Copy(snapshot.grids or {})
    MigrateLegacyGrids(ply, inv)

    StripSafeZoneRestoreWeapons(ply)
    ClearSafeZoneRestoreArmor(ply)

    ply.zscav_inv = inv

    local restoredGear = snapshot.gear or {}
    local handledGear = {}

    for _, slotID in ipairs({ "secure_container", "ears", "helmet", "face_cover", "body_armor" }) do
        local entry = restoredGear[slotID]
        if istable(entry) then
            RestoreSafeZoneSimpleGearSlot(ply, inv, slotID, entry, snapshot.secure)
            handledGear[slotID] = true
        end
    end

    local torsoEntry = restoredGear.tactical_rig or restoredGear.vest
    if istable(torsoEntry) then
        RestoreSafeZoneContainerGear(ply, inv, torsoEntry, snapshot.vest)
        handledGear.tactical_rig = true
        handledGear.vest = true
    end

    if istable(restoredGear.backpack) then
        RestoreSafeZoneContainerGear(ply, inv, restoredGear.backpack, snapshot.backpack)
        handledGear.backpack = true
    end

    for slotID, entry in pairs(restoredGear) do
        if not handledGear[slotID] and istable(entry) then
            RestoreSafeZoneSimpleGearSlot(ply, inv, tostring(slotID), entry, snapshot.secure)
        end
    end

    if not istable(restoredGear.secure_container) then
        EnsureSecureContainerForInventory(ply, inv)
    end

    for slotID, entry in pairs(snapshot.weapons or {}) do
        if not (istable(entry) and tostring(entry.class or "") ~= "") then
            continue
        end

        local restoredEntry = CopyItemEntry(entry, {
            slot = tostring(slotID),
        }) or {
            class = tostring(entry.class or ""),
            slot = tostring(slotID),
        }

        EnsureWeaponEntryRuntime(restoredEntry)
        local weapon = GiveWeaponInstance(ply, restoredEntry)
        if IsValid(weapon) then
            inv.weapons[tostring(slotID)] = restoredEntry
        else
            self:TryAddItemEntry(ply, restoredEntry)
        end
    end

    inv.quickslots = CopyCorpseEntryMap(snapshot.quickslots)
    ply.zscav_safezone_inventory_restore_in_progress = nil
    SyncInventory(ply)

    timer.Simple(0, function()
        if not (IsValid(ply) and ZSCAV:IsActive()) then return end

        ZSCAV:ReconcileWeapons(ply)
        ZSCAV:ReconcileArmor(ply)
        ZSCAV:ApplyWeightToOrganism(ply)

        DeleteSafeZoneInventorySnapshotLocal(tostring(pending.owner_sid64 or ply:SteamID64() or ""))
        ply.zscav_safezone_inventory_snapshot_crc = nil

        if tostring(pending.source or "") == "local_disconnect" then
            Notice(ply, "Safe-zone inventory restored after reconnect.")
        end
    end)

    return true
end

local function QueueSafeZoneInventoryRestoreFromLocal(ply, source)
    if not IsValid(ply) then return false end
    if istable(ply.zscav_safezone_inventory_restore_pending) then return true end

    local ownerSID64 = tostring(ply:SteamID64() or "")
    if ownerSID64 == "" then return false end

    local snapshot = LoadSafeZoneInventorySnapshotLocal(ownerSID64)
    if not snapshot then return false end

    return ZSCAV:QueueSafeZoneInventoryRestore(ply, snapshot, {
        source = tostring(source or "local_disconnect"),
        owner_sid64 = ownerSID64,
    })
end

hook.Add("PlayerDisconnected", "ZSCAV_SafeZoneDisconnectPersistInventory", function(ply)
    if not (IsValid(ply) and ZSCAV:IsActive()) then return end

    local inSafeZone = select(1, ZSCAV:GetPlayerSafeZoneContext(ply))
    if not inSafeZone then return end

    local ownerSID64 = tostring(ply:SteamID64() or "")
    if ownerSID64 == "" then return end

    local snapshot = LoadSafeZoneInventorySnapshotLocal(ownerSID64)
    if not snapshot then
        snapshot = ZSCAV:BuildSafeZoneInventorySnapshot(ply.zscav_inv or ZSCAV:GetInventory(ply))
    end
    if not snapshot then return end

    SaveSafeZoneInventorySnapshotLocal(ownerSID64, snapshot)
end)

hook.Add("PlayerInitialSpawn", "ZSCAV_SafeZoneInventoryQueueRestore", function(ply)
    if not IsValid(ply) then return end

    QueueSafeZoneInventoryRestoreFromLocal(ply, "local_disconnect")
end)

hook.Add("PlayerSpawn", "ZSCAV_SafeZoneInventoryRestoreOnSpawn", function(ply)
    if not (IsValid(ply) and ZSCAV:IsActive() and ply:Alive()) then return end

    if not istable(ply.zscav_safezone_inventory_restore_pending) then
        QueueSafeZoneInventoryRestoreFromLocal(ply, "local_resume")
    end

    if not istable(ply.zscav_safezone_inventory_restore_pending) then return end

    timer.Simple(0, function()
        if not (IsValid(ply) and ZSCAV:IsActive() and ply:Alive()) then return end
        ZSCAV:ApplyQueuedSafeZoneInventoryRestore(ply)
    end)
end)

hook.Add("ZB_EndRound", "ZSCAV_SafeZonePersistOnRoundEnd", function()
    if not ZSCAV:IsActive() then return end

    for _, ply in player.Iterator() do
        ZSCAV:PersistSafeZoneInventorySnapshot(ply, {
            allow_inactive = true,
            use_pending_restore = true,
        })
    end
end)