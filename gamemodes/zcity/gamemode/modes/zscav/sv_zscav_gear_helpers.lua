ZSCAV = ZSCAV or {}
ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}

local helpers = ZSCAV.ServerHelpers
local SyncInventory = helpers.SyncInventory
local Notice = helpers.Notice
local getGridLayoutBlocks = helpers.getGridLayoutBlocks
local FilterToFitGrid = helpers.FilterToFitGrid
local PackIntoGrid = helpers.PackIntoGrid
local findFreeSpotAR = helpers.findFreeSpotAR
local CopyItemEntry = helpers.CopyItemEntry

local function SpawnGenericWorldItem(ply, entry)
    local worldLoot = ZSCAV and ZSCAV.WorldLoot or nil
    if not (worldLoot and worldLoot.GetWorldModelForEntry) then return NULL end

    local class = string.lower(string.Trim(tostring(entry and entry.class or "")))
    if class == "" then return NULL end
    if worldLoot.IsWorldItemClass and not worldLoot:IsWorldItemClass(class) then
        return NULL
    end

    local model = tostring(worldLoot:GetWorldModelForEntry(entry) or "")
    if model == "" then return NULL end

    local pos = ply:EyePos() + ply:GetAimVector() * 32
    local ent = ents.Create("ent_zscav_world_item")
    if not IsValid(ent) then return NULL end

    ent:SetPos(pos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ent.zscav_pack_class = tostring(entry.class or "")
    ent.zscav_pack_uid = tostring(entry.uid or "")
    ent.zscav_world_model = model
    ent.zscav_world_entry = CopyItemEntry(entry) or table.Copy(entry)
    ent.IsSpawned = false
    ent.init = false
    ent:Spawn()

    return ent
end

local function SpawnDroppedClass(ply, class, uid, entry)
    local droppedEntry = CopyItemEntry(entry) or {
        class = class,
        uid = uid,
    }
    droppedEntry.class = tostring(droppedEntry.class or class or "")
    if droppedEntry.uid == nil and uid ~= nil then
        droppedEntry.uid = uid
    end

    local generic = SpawnGenericWorldItem(ply, droppedEntry)
    if IsValid(generic) then
        return generic
    end

    -- Backpacks: spawn the ragdoll form so the dropped bag drops onto
    -- its bone hulls just like a fresh world spawn does.
    local def = ZSCAV:GetGearDef(class)
    if def and def.slot == "backpack" then
        local pos = ply:EyePos() + ply:GetAimVector() * 32
        local ang = Angle(0, ply:EyeAngles().y, 0)
        return ZSCAV:SpawnPackRagdoll(class, pos, ang, uid)
    end

    if scripted_ents.GetStored(class) or weapons.GetStored(class) then
        local pos = ply:EyePos() + ply:GetAimVector() * 32
        local ent = ents.Create(class)
        if IsValid(ent) then
            ent:SetPos(pos)
            ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
            ent.zscav_pack_class = class
            if uid and uid ~= "" then
                ent.zscav_pack_uid = uid
            end
            -- Bag-class entities get their UID assigned BEFORE Spawn so the
            -- ENT:Initialize CreateBag fallback doesn't allocate a new row.
            if uid and uid ~= "" and ent.SetBagUID then
                ent:SetBagUID(uid)
            end
            ent.IsSpawned = false
            ent.init = false
            ent:Spawn()

            if istable(droppedEntry) and ent:IsWeapon() and ZSCAV.CopyItemEntry then
                ent.zscav_world_entry = ZSCAV:CopyItemEntry(droppedEntry)
                ent.zscav_weapon_uid = tostring(droppedEntry.weapon_uid or ent.zscav_weapon_uid or "")
            end

            if IsValid(ent) and ent:IsWeapon() and istable(droppedEntry) and ZSCAV.ApplyWeaponState then
                timer.Simple(0, function()
                    if IsValid(ent) then
                        ZSCAV:ApplyWeaponState(ply, ent, droppedEntry)
                    end
                end)
            end

            return ent
        end
    end

    return NULL
end

-- Snapshot the player's worn-backpack inventory state into the bag's SQL
-- record. We persist everything that lives in inv.backpack while the
-- pack is worn (the bag IS the backpack grid expansion). Items in
-- pockets-only (the base 2x2) are deduced afterwards.
local function SerializeWornBackpack(inv)
    local out = {}
    for _, it in ipairs(inv.backpack or {}) do
        local entry = CopyItemEntry(it)
        out[#out + 1] = entry
    end
    return out
end

local function VestEquip(ply, inv, class, uid)
    inv.gear = inv.gear or {}
    inv.gear.tactical_rig = { class = class, uid = uid, slot = "tactical_rig" }
    inv.gear.vest = nil

    if IsValid(ply) then
        ply:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(95, 105), 1, CHAN_ITEM)
        if ply.DoAnimationEvent and ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND then
            ply:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND)
            ply:ViewPunch(Angle(1, -2, 1))
        end
    end

    local grids = ZSCAV:GetEffectiveGrids(inv)
    local vg = grids.vest or { w = 0, h = 0 }
    local vestLayout = getGridLayoutBlocks(inv, "vest")

    local existing = inv.vest or {}
    local fromBag = {}
    if uid and uid ~= "" then
        local bag = ZSCAV:LoadBag(uid)
        if bag then
            for _, it in ipairs(bag.contents or {}) do fromBag[#fromBag + 1] = it end
        end
    end

    local kept, evicted = FilterToFitGrid(existing, vg.w, vg.h, vestLayout)
    inv.vest = kept

    local merged = {}
    for _, it in ipairs(fromBag) do merged[#merged + 1] = it end
    for _, it in ipairs(evicted) do merged[#merged + 1] = it end

    local placed, leftover = PackIntoGrid(merged, vg.w, vg.h, vestLayout)
    for _, it in ipairs(placed) do
        local x, y, wasRotated = findFreeSpotAR(inv.vest, vg.w, vg.h, it.w, it.h, vestLayout)
        if x then
            local ew = wasRotated and it.h or it.w
            local eh = wasRotated and it.w or it.h
            inv.vest[#inv.vest + 1] = CopyItemEntry(it, {
                x = x,
                y = y,
                w = ew,
                h = eh,
            })
        else
            leftover[#leftover + 1] = it
        end
    end

    if uid and uid ~= "" then
        ZSCAV:SaveBag(uid, class, leftover)
    end

    SyncInventory(ply)
end

local function VestUnequip(ply, inv)
    inv.gear = inv.gear or {}
    local entry = inv.gear.tactical_rig or inv.gear.vest
    if not entry then return end

    if ply.zscav_vest_unequip_lock then return end
    ply.zscav_vest_unequip_lock = true

    local class = entry.class
    local uid = entry.uid

    if IsValid(ply) then
        ply:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(95, 105), 1, CHAN_ITEM)
        if ply.DoAnimationEvent and ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND then
            ply:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND)
            ply:ViewPunch(Angle(1, -2, 1))
        end
    end

    if ZSCAV:IsArmorEntityClass(class) then
        ZSCAV:RemoveArmorNoDrop(ply, class)
    end

    inv.gear.tactical_rig = nil
    inv.gear.vest = nil

    if uid and uid ~= "" then
        ZSCAV:SaveBag(uid, class, inv.vest or {})
    elseif #(inv.vest or {}) > 0 then
        for _, it in ipairs(inv.vest) do
            SpawnDroppedClass(ply, it.class, it.uid, it)
        end
    end
    inv.vest = {}

    local grids = ZSCAV:GetEffectiveGrids(inv)
    for _, gridName in ipairs({ "backpack", "pocket" }) do
        local grid = grids[gridName]
        local list = inv[gridName]
        local index = 1
        while index <= #list do
            local it = list[index]
            if grid.w == 0 or grid.h == 0 or it.x + it.w > grid.w or it.y + it.h > grid.h then
                SpawnDroppedClass(ply, it.class, it.uid, it)
                table.remove(list, index)
                Notice(ply, "Overflow: " .. it.class .. " dropped.")
            else
                index = index + 1
            end
        end
    end

    SpawnDroppedClass(ply, class, uid, entry)
    SyncInventory(ply)
    ply.zscav_vest_unequip_lock = nil
end

local function BackpackEquip(ply, inv, class, uid)
    uid = tostring(uid or "")
    if uid == "" then
        uid = tostring(ZSCAV:CreateBag(class) or "")
    end

    inv.gear = inv.gear or {}
    inv.gear.backpack = { class = class, uid = uid, slot = "backpack" }

    if IsValid(ply) then
        ply:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(95, 105), 1, CHAN_ITEM)
        if ply.DoAnimationEvent and ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND then
            ply:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND)
            ply:ViewPunch(Angle(1, -2, 1))
        end
    end

    local grids = ZSCAV:GetEffectiveGrids(inv)
    local bp = grids.backpack or { w = 0, h = 0 }
    local bpLayout = getGridLayoutBlocks(inv, "backpack")

    local existing = inv.backpack or {}
    local fromBag = {}

    if uid and uid ~= "" then
        local bag = ZSCAV:LoadBag(uid)
        if bag then
            for _, it in ipairs(bag.contents or {}) do fromBag[#fromBag + 1] = it end
        end
    end

    local kept, evicted = FilterToFitGrid(existing, bp.w, bp.h, bpLayout)
    inv.backpack = kept

    local merged = {}
    for _, it in ipairs(fromBag) do merged[#merged + 1] = it end
    for _, it in ipairs(evicted) do merged[#merged + 1] = it end

    local placed, leftover = PackIntoGrid(merged, bp.w, bp.h, bpLayout)
    for _, it in ipairs(placed) do
        local x, y, wasRotated = findFreeSpotAR(inv.backpack, bp.w, bp.h, it.w, it.h, bpLayout)
        if x then
            local ew = wasRotated and it.h or it.w
            local eh = wasRotated and it.w or it.h
            inv.backpack[#inv.backpack + 1] = CopyItemEntry(it, {
                x = x,
                y = y,
                w = ew,
                h = eh,
            })
        else
            leftover[#leftover + 1] = it
        end
    end

    if uid and uid ~= "" then
        ZSCAV:SaveBag(uid, class, leftover)
    end

    SyncInventory(ply)
end

local function BackpackUnequip(ply, inv)
    inv.gear = inv.gear or {}
    local entry = inv.gear.backpack
    if not entry then return end

    if ply.zscav_unequip_lock then return end
    ply.zscav_unequip_lock = true

    local class = entry.class
    local uid = entry.uid

    if IsValid(ply) then
        ply:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(95, 105), 1, CHAN_ITEM)
        if ply.DoAnimationEvent and ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND then
            ply:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND)
            ply:ViewPunch(Angle(1, -2, 1))
        end
    end

    inv.gear.backpack = nil
    local newGrids = ZSCAV:GetEffectiveGrids(inv)
    local bp = newGrids.backpack or { w = 0, h = 0 }

    local kept, evicted = FilterToFitGrid(inv.backpack or {}, bp.w, bp.h)
    inv.backpack = kept

    if uid and uid ~= "" then
        ZSCAV:SaveBag(uid, class, evicted)
    elseif #evicted > 0 then
        for _, it in ipairs(evicted) do
            SpawnDroppedClass(ply, it.class, it.uid, it)
        end
    end

    SpawnDroppedClass(ply, class, uid, entry)
    SyncInventory(ply)
    ply.zscav_unequip_lock = nil
end

local function StashOrDrop(ply, class, uid)
    local item = nil
    if istable(class) then
        item = CopyItemEntry(class)
    else
        item = CopyItemEntry({
            class = class,
            uid = uid,
        })
    end

    if not item or not item.class then return end

    local ok = ZSCAV.TryAddItemEntry and ZSCAV:TryAddItemEntry(ply, item) or ZSCAV:TryAddItem(ply, item)
    if not ok then
        SpawnDroppedClass(ply, item.class, item.uid, item)
        Notice(ply, "No room: " .. item.class .. " dropped to ground.")
    end
end

helpers.SpawnDroppedClass = SpawnDroppedClass
helpers.SerializeWornBackpack = SerializeWornBackpack
helpers.VestEquip = VestEquip
helpers.VestUnequip = VestUnequip
helpers.BackpackEquip = BackpackEquip
helpers.BackpackUnequip = BackpackUnequip
helpers.StashOrDrop = StashOrDrop
