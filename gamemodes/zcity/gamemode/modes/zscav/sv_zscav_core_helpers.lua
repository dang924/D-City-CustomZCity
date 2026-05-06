ZSCAV = ZSCAV or {}
ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}

local helpers = ZSCAV.ServerHelpers

local function NewInventory()
    return {
        gear     = {},   -- [slotid] = { class = "..." }
        backpack = {},   -- [n] = { class, x, y, w, h }
        pocket   = {},   -- single pocket grid
        vest     = {},   -- vest compartment grid (if vest has compartment=true)
        secure   = {},   -- secure container internal grid (when equipped)
        weapons  = {},   -- [slotid] = { class = "..." } (primary/secondary/sidearm/sidearm2/melee physical slots)
        quickslots = {}, -- [1..7] = { class, uid?, weapon_uid?, actual_class? } for hotbar keys 4..0
    }
end

local SECURE_TABLE = "zscav_player_secure"
local SECURE_DEFAULT_CLASS = "zscav_alpha_container"

local SECURE_SCHEMA = [[
CREATE TABLE IF NOT EXISTS zscav_player_secure (
    owner_sid64 TEXT PRIMARY KEY,
    issued      INTEGER NOT NULL DEFAULT 0,
    status      TEXT    NOT NULL DEFAULT 'none',
    class       TEXT    NOT NULL DEFAULT 'zscav_alpha_container',
    uid         TEXT    NOT NULL DEFAULT '',
    updated     INTEGER NOT NULL DEFAULT 0
)
]]

local function EnsureSecureSchema()
    if sql.TableExists(SECURE_TABLE) then return true end
    local ok = sql.Query(SECURE_SCHEMA)
    if ok == false then
        ErrorNoHalt("[ZScav] Failed to create sqlite secure table: " .. tostring(sql.LastError()) .. "\n")
        return false
    end
    return true
end

local function IsSecureClass(class)
    local def = ZSCAV:GetGearDef(class)
    return istable(def) and def.secure == true
end

local function GetPlayerSecureState(ownerSID64)
    ownerSID64 = tostring(ownerSID64 or "")
    if ownerSID64 == "" then return nil end
    if not EnsureSecureSchema() then return nil end

    local row = sql.QueryRow("SELECT * FROM " .. SECURE_TABLE .. " WHERE owner_sid64 = " .. SQLStr(ownerSID64))
    if not istable(row) then
        return {
            owner_sid64 = ownerSID64,
            issued = 0,
            status = "none",
            class = SECURE_DEFAULT_CLASS,
            uid = "",
            updated = 0,
        }
    end

    return {
        owner_sid64 = ownerSID64,
        issued = tonumber(row.issued) or 0,
        status = tostring(row.status or "none"),
        class = tostring(row.class or SECURE_DEFAULT_CLASS),
        uid = tostring(row.uid or ""),
        updated = tonumber(row.updated) or 0,
    }
end

local function SavePlayerSecureState(st)
    if not istable(st) then return false end
    local sid = tostring(st.owner_sid64 or "")
    if sid == "" then return false end
    if not EnsureSecureSchema() then return false end

    local q = string.format(
        "INSERT OR REPLACE INTO %s (owner_sid64, issued, status, class, uid, updated) VALUES (%s, %d, %s, %s, %s, %d)",
        SECURE_TABLE,
        SQLStr(sid),
        (tonumber(st.issued) == 1) and 1 or 0,
        SQLStr(tostring(st.status or "none")),
        SQLStr(tostring(st.class or SECURE_DEFAULT_CLASS)),
        SQLStr(tostring(st.uid or "")),
        os.time()
    )
    return sql.Query(q) ~= false
end

local function EnsureSecureContainerForInventory(ply, inv)
    if not IsValid(ply) or not inv then return end

    inv.gear = inv.gear or {}
    inv.secure = inv.secure or {}
    local sid = tostring(ply:SteamID64() or "")
    if sid == "" then return end

    local current = inv.gear.secure_container
    if istable(current) and tostring(current.class or "") ~= "" then
        if tostring(current.uid or "") == "" then
            current.uid = ZSCAV:CreateBag(current.class)
        end
        local loaded = ZSCAV:LoadBag(tostring(current.uid or ""))
        inv.secure = (loaded and loaded.contents) or {}
        local st = GetPlayerSecureState(sid)
        if st then
            st.issued = 1
            st.status = "equipped"
            st.class = tostring(current.class)
            st.uid = tostring(current.uid or "")
            SavePlayerSecureState(st)
        end
        return
    end

    local st = GetPlayerSecureState(sid)
    if not st then return end

    -- Never re-grant after first issuance unless account data is wiped.
    if st.issued ~= 1 then
        local class = tostring(st.class or SECURE_DEFAULT_CLASS)
        if class == "" then class = SECURE_DEFAULT_CLASS end
        local uid = ZSCAV:CreateBag(class)
        inv.gear.secure_container = { class = class, uid = uid, slot = "secure_container" }
        st.issued = 1
        st.status = "equipped"
        st.class = class
        st.uid = tostring(uid or "")
        SavePlayerSecureState(st)
        return
    end

    if st.status == "equipped" and st.uid ~= "" and st.class ~= "" then
        inv.gear.secure_container = { class = st.class, uid = st.uid, slot = "secure_container" }
        local loaded = ZSCAV:LoadBag(st.uid)
        inv.secure = (loaded and loaded.contents) or {}
    else
        inv.secure = {}
    end
end

-- Migrate any pre-existing split-pocket grids into one `inv.pocket`.
local function MigrateLegacyGrids(_ply, inv)
    if not inv then return end
    local moved = false
    inv.pocket = inv.pocket or {}
    inv.vest    = inv.vest    or {}
    inv.secure  = inv.secure  or {}
    inv.quickslots = istable(inv.quickslots) and inv.quickslots or {}

    if inv.pocket1 then
        for _, it in ipairs(inv.pocket1) do inv.pocket[#inv.pocket + 1] = it end
        inv.pocket1 = nil
        moved = true
    end
    if inv.pocket2 then
        for _, it in ipairs(inv.pocket2) do inv.pocket[#inv.pocket + 1] = it end
        inv.pocket2 = nil
        moved = true
    end
    if inv.hotbar then
        for _, it in ipairs(inv.hotbar) do inv.pocket[#inv.pocket + 1] = it end
        inv.hotbar = nil
        moved = true
    end
    if inv.grenades then
        for _, it in ipairs(inv.grenades) do inv.pocket[#inv.pocket + 1] = it end
        inv.grenades = nil
        moved = true
    end
    return moved
end

local function BuildSecurePersistenceKey(inv)
    if not istable(inv) or not istable(inv.gear) then return "" end

    local secureGear = inv.gear.secure_container
    if not (istable(secureGear) and IsSecureClass(secureGear.class)) then
        return ""
    end

    local suid = tostring(secureGear.uid or "")
    if suid == "" then return "" end

    local payload = util.TableToJSON(inv.secure or {}, false) or "[]"
    return util.CRC(table.concat({ suid, tostring(secureGear.class or ""), payload }, "\n"))
end

local function SyncInventory(ply)
    if not IsValid(ply) then return end
    local inv = ply.zscav_inv
    if inv then
        -- Attach the server-computed vest grid size so the client can
        -- display the correct grid even without admin-configured GearItems data.
        local grids = ZSCAV:GetEffectiveGrids(inv)
        inv._vestGrid = grids.vest
        -- Also attach vest layout blocks if equipped (Option A: initial sync).
        local vestGear = inv and inv.gear and (inv.gear.tactical_rig or inv.gear.vest)
        if vestGear and vestGear.class then
            local vestDef = ZSCAV:GetGearDef(vestGear.class)
            if vestDef and istable(vestDef.layoutBlocks) then
                inv._vestLayoutBlocks = vestDef.layoutBlocks
            else
                inv._vestLayoutBlocks = nil
            end
        else
            inv._vestLayoutBlocks = nil
        end

        local backpackGear = inv and inv.gear and inv.gear.backpack
        if backpackGear and backpackGear.class then
            local bpDef = ZSCAV:GetGearDef(backpackGear.class)
            if bpDef and istable(bpDef.layoutBlocks) then
                inv._backpackLayoutBlocks = bpDef.layoutBlocks
            else
                inv._backpackLayoutBlocks = nil
            end
        else
            inv._backpackLayoutBlocks = nil
        end

        local secureGearDef = inv and inv.gear and inv.gear.secure_container
        if secureGearDef and secureGearDef.class then
            local scDef = ZSCAV:GetGearDef(secureGearDef.class)
            if scDef and istable(scDef.layoutBlocks) then
                inv._secureLayoutBlocks = scDef.layoutBlocks
            else
                inv._secureLayoutBlocks = nil
            end
        else
            inv._secureLayoutBlocks = nil
        end

        -- Keep secure container SQL row synchronized with live secure grid.
        local secureGear = inv.gear and inv.gear.secure_container
        if secureGear and IsSecureClass(secureGear.class) then
            local suid = tostring(secureGear.uid or "")
            if suid ~= "" then
                local secureKey = BuildSecurePersistenceKey(inv)
                if secureKey ~= "" and ply.zscav_secure_persist_key ~= secureKey then
                    if ZSCAV:SaveBag(suid, secureGear.class, inv.secure or {}) then
                        ply.zscav_secure_persist_key = secureKey
                    end
                end
            end
        else
            ply.zscav_secure_persist_key = nil
        end

        local gridCarryWeight = tonumber(ZSCAV:GetGridCarryWeight(inv)) or 0
        local totalWeight = gridCarryWeight

        for _, slotData in pairs(inv.gear or {}) do
            if slotData and slotData.class then
                totalWeight = totalWeight + (ZSCAV:GetItemWeight(slotData) or 0)
                if SERVER and slotData.uid and ZSCAV.GetBagStoredWeight then
                    totalWeight = totalWeight + ZSCAV:GetBagStoredWeight(slotData.uid)
                end
            end
        end

        for _, slotData in pairs(inv.weapons or {}) do
            if slotData and slotData.class then
                totalWeight = totalWeight + (ZSCAV:GetItemWeight(slotData) or 0)
            end
        end

        inv._gridCarryWeight = gridCarryWeight
        inv._totalWeight = tonumber(totalWeight) or 0
    end

    if ZSCAV and ZSCAV.MaybeSnapshotSafeZoneInventory then
        ZSCAV:MaybeSnapshotSafeZoneInventory(ply)
    end

    ply:SetNetVar("ZScavInv", ply.zscav_inv)

    if ZSCAV and ZSCAV.SyncLegacyAttachmentInventory then
        ZSCAV:SyncLegacyAttachmentInventory(ply)
    end

    if ZSCAV and ZSCAV.SyncGrenadeHotbar then
        ZSCAV:SyncGrenadeHotbar(ply)
    end
end

local function FlushSecurePersistence(ply)
    if not IsValid(ply) then return end
    local inv = ply.zscav_inv
    if not istable(inv) then return end

    inv.gear = inv.gear or {}
    local secureGear = inv.gear.secure_container
    if not (istable(secureGear) and IsSecureClass(secureGear.class)) then return end

    local sid = tostring(ply:SteamID64() or "")
    if sid == "" then return end

    local suid = tostring(secureGear.uid or "")
    if suid == "" then
        suid = tostring(ZSCAV:CreateBag(secureGear.class) or "")
        secureGear.uid = suid
    end
    if suid == "" then return end

    ZSCAV:SaveBag(suid, secureGear.class, inv.secure or {})

    local st = GetPlayerSecureState(sid)
    if st then
        st.issued = 1
        st.status = "equipped"
        st.class = tostring(secureGear.class or SECURE_DEFAULT_CLASS)
        st.uid = suid
        SavePlayerSecureState(st)
    end
end

local function Notice(ply, msg)
    if not IsValid(ply) then return end
    net.Start("ZScavInvNotice")
        net.WriteString(msg)
    net.Send(ply)
end

helpers.NewInventory = NewInventory
helpers.SECURE_DEFAULT_CLASS = SECURE_DEFAULT_CLASS
helpers.IsSecureClass = IsSecureClass
helpers.GetPlayerSecureState = GetPlayerSecureState
helpers.SavePlayerSecureState = SavePlayerSecureState
helpers.EnsureSecureContainerForInventory = EnsureSecureContainerForInventory
helpers.MigrateLegacyGrids = MigrateLegacyGrids
helpers.SyncInventory = SyncInventory
helpers.FlushSecurePersistence = FlushSecurePersistence
helpers.Notice = Notice