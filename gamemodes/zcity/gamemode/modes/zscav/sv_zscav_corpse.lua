-- ZScav corpse containers, death presentation, and protected-death recovery.

local ctx = ZSCAV and ZSCAV.CorpseContext or {}

local CopyItemEntry = ctx.CopyItemEntry
local SyncInventory = ctx.SyncInventory
local Notice = ctx.Notice
local findFreeSpotAR = ctx.findFreeSpotAR
local DeliverToPlayerMailbox = ctx.DeliverToPlayerMailbox
local SyncMailboxUnread = ctx.SyncMailboxUnread
local CORPSE_CONTAINER_CLASS = tostring(ctx.CORPSE_CONTAINER_CLASS or "Corpse")
local LIVE_LOOT_CONTAINER_CLASS = tostring(ctx.LIVE_LOOT_CONTAINER_CLASS or "LiveLoot")

if not (isfunction(CopyItemEntry)
    and isfunction(SyncInventory)
    and isfunction(Notice)
    and isfunction(findFreeSpotAR)) then
    ErrorNoHalt("[ZScav] Corpse module missing context.\n")
    return
end

local function CorpseContainers()
    ZSCAV.CorpseContainers = ZSCAV.CorpseContainers or {}
    return ZSCAV.CorpseContainers
end

local function GetCorpseContainer(uid)
    uid = tostring(uid or "")
    if uid == "" then return nil end

    local record = CorpseContainers()[uid]
    if not istable(record) then return nil end
    if not IsValid(record.ragdoll) then
        CorpseContainers()[uid] = nil
        return nil
    end

    return record
end

local function ResolveCorpseInventorySlotID(slotID)
    slotID = tostring(slotID or "")
    if slotID == "tactical_rig" then return "vest" end
    return slotID
end

local function BuildCorpseAnchorVisualState(record)
    local visualInv = {
        gear = {},
        weapons = {},
        pocket = {},
        vest = {},
        backpack = {},
        secure = {},
    }
    local armors = {}

    for _, entry in ipairs(record and record.contents or {}) do
        if not (istable(entry) and entry.class) then continue end

        local kind = tostring(entry.corpse_slot_kind or "")
        local slotID = tostring(entry.corpse_slot_id or "")
        if kind == "gear" and slotID ~= "" then
            local invSlot = ResolveCorpseInventorySlotID(slotID)
            visualInv.gear[invSlot] = CopyItemEntry(entry, {
                slot = invSlot,
            }) or { class = entry.class, slot = invSlot }

            if ZSCAV:IsArmorEntityClass(entry.class) then
                local placement = ZSCAV:GetArmorPlacement(entry.class)
                local armorName = tostring(ZSCAV:GetArmorEntityName(entry.class) or "")
                if placement and armorName ~= "" then
                    armors[placement] = armorName
                end
            end
        elseif kind == "weapon" and slotID ~= "" then
            visualInv.weapons[slotID] = CopyItemEntry(entry, {
                slot = slotID,
            }) or { class = entry.class, slot = slotID }
        end
    end

    return visualInv, armors
end

local function ApplyCorpseAnchorVisualState(record)
    if not istable(record) then return end
    if record.live_owner == true then return end

    local anchor = record.ragdoll
    if not IsValid(anchor) then return end

    local visualInv, armors = BuildCorpseAnchorVisualState(record)
    record.visual_inv = visualInv
    record.visual_armors = armors

    if anchor.SetNetVar then
        anchor:SetNetVar("ZScavInv", visualInv)
        anchor:SetNetVar("Armor", armors)
        anchor:SetNetVar("HideArmorRender", false)
    end

    anchor.armors = armors
end

function ZSCAV:RebindCorpseContainerAnchor(oldEnt, newEnt)
    if not (IsValid(oldEnt) and IsValid(newEnt)) then return false end

    local rootUID = tostring(oldEnt.zscav_corpse_root_uid or "")
    if rootUID == "" then return false end

    local record = GetCorpseContainer(rootUID)
    if not record then return false end

    record.ragdoll = newEnt
    newEnt.zscav_corpse_root_uid = rootUID
    ApplyCorpseAnchorVisualState(record)

    return true
end

local function NewCorpseContainerUID(ragdoll)
    return string.format("zc_corpse_%d_%d_%06x", os.time(), IsValid(ragdoll) and ragdoll:EntIndex() or 0, math.random(0, 0xFFFFFF))
end

local function FindLivingRagdollOwner(ent)
    if not IsValid(ent) then return nil, nil end

    if ent:IsPlayer() then
        if not ent:Alive() then return nil, nil end

        local ragdoll = ent.FakeRagdoll or ent:GetNWEntity("FakeRagdoll")
        if IsValid(ragdoll) and ragdoll:IsRagdoll() then
            return ent, ragdoll
        end

        return nil, nil
    end

    if not ent:IsRagdoll() then return nil, nil end

    local candidates = {
        ent.ply,
        ent.GetNWEntity and ent:GetNWEntity("ply") or nil,
        ent.GetNWEntity and ent:GetNWEntity("RagdollOwner") or nil,
    }

    if hg and hg.RagdollOwner then
        local ok, owner = pcall(hg.RagdollOwner, ent)
        if ok then
            candidates[#candidates + 1] = owner
        end
    end

    for _, owner in ipairs(candidates) do
        if IsValid(owner) and owner:IsPlayer() and owner:Alive() then
            local ragdoll = owner.FakeRagdoll or owner:GetNWEntity("FakeRagdoll")
            if ragdoll == ent then
                return owner, ragdoll
            end
        end
    end

    for _, owner in player.Iterator() do
        if IsValid(owner) and owner:Alive() then
            local ragdoll = owner.FakeRagdoll or owner:GetNWEntity("FakeRagdoll")
            if ragdoll == ent then
                return owner, ragdoll
            end
        end
    end

    return nil, nil
end

local function BuildLiveLootLayout(inv)
    local grids = ZSCAV:GetEffectiveGrids(inv or {}) or {}
    local pocket = grids.pocket or { w = 4, h = 1 }
    local vest = grids.vest or { w = 0, h = 0 }
    local backpack = grids.backpack or { w = 0, h = 0 }
    local gap = 1
    local sections = {}
    local blocks = {}

    local leftWidth = 0
    local nextLeftY = 0

    if pocket.w > 0 and pocket.h > 0 then
        sections.pocket = { grid = "pocket", x = 0, y = 0, w = pocket.w, h = pocket.h }
        blocks[#blocks + 1] = table.Copy(sections.pocket)
        leftWidth = math.max(leftWidth, pocket.w)
        nextLeftY = pocket.h + gap
    end

    if vest.w > 0 and vest.h > 0 then
        sections.vest = { grid = "vest", x = 0, y = nextLeftY, w = vest.w, h = vest.h }
        blocks[#blocks + 1] = table.Copy(sections.vest)
        leftWidth = math.max(leftWidth, vest.w)
        nextLeftY = nextLeftY + vest.h + gap
    end

    if backpack.w > 0 and backpack.h > 0 then
        local backpackX = leftWidth > 0 and (leftWidth + gap) or 0
        sections.backpack = { grid = "backpack", x = backpackX, y = 0, w = backpack.w, h = backpack.h }
        blocks[#blocks + 1] = table.Copy(sections.backpack)
    end

    local width = 1
    local height = 1
    for _, block in ipairs(blocks) do
        width = math.max(width, block.x + block.w)
        height = math.max(height, block.y + block.h)
    end

    return sections, blocks, width, height
end

local function ResolveLiveLootSection(record, entry)
    local sections = istable(record) and record.live_sections or nil
    if not istable(sections) or not istable(entry) then return nil end

    local entryW = math.max(tonumber(entry.w) or 1, 1)
    local entryH = math.max(tonumber(entry.h) or 1, 1)
    local entryX = tonumber(entry.x) or 0
    local entryY = tonumber(entry.y) or 0
    local preferred = tostring(entry.live_grid or "")

    local function resolveSection(section)
        if not istable(section) then return nil end

        local localX = entryX - (tonumber(section.x) or 0)
        local localY = entryY - (tonumber(section.y) or 0)
        if localX < 0 or localY < 0 then return nil end
        if localX + entryW > (tonumber(section.w) or 0) then return nil end
        if localY + entryH > (tonumber(section.h) or 0) then return nil end
        return localX, localY
    end

    if preferred ~= "" then
        local localX, localY = resolveSection(sections[preferred])
        if localX ~= nil then
            return preferred, localX, localY
        end
    end

    for _, gridName in ipairs({ "pocket", "vest", "backpack" }) do
        local localX, localY = resolveSection(sections[gridName])
        if localX ~= nil then
            return gridName, localX, localY
        end
    end

    return nil
end

local function ApplyLiveLootProxyContents(record)
    if not (istable(record) and record.live_owner == true and IsValid(record.owner)) then return false end

    local inv = ZSCAV:GetInventory(record.owner)
    if not inv then return false end

    local nextLists = {
        pocket = {},
        vest = {},
        backpack = {},
    }

    for _, entry in ipairs(record.contents or {}) do
        if not (istable(entry) and entry.class) then continue end

        local gridName, localX, localY = ResolveLiveLootSection(record, entry)
        if not gridName then continue end

        local restored = CopyItemEntry(entry, {
            x = localX,
            y = localY,
        }) or { class = entry.class, x = localX, y = localY }
        restored.live_grid = nil
        nextLists[gridName][#nextLists[gridName] + 1] = restored
    end

    inv.pocket = nextLists.pocket
    inv.vest = nextLists.vest
    inv.backpack = nextLists.backpack
    SyncInventory(record.owner)

    return true
end

local function BuildLiveLootProxyContainer(ragdoll, owner)
    if not (IsValid(ragdoll) and IsValid(owner) and owner:Alive()) then return nil end

    local inv = ZSCAV:GetInventory(owner)
    if not istable(inv) then return nil end

    local sections, blocks, width, height = BuildLiveLootLayout(inv)
    local rootUID = tostring(ragdoll.zscav_corpse_root_uid or "")
    if rootUID == "" then
        rootUID = NewCorpseContainerUID(ragdoll)
        ragdoll.zscav_corpse_root_uid = rootUID
    end

    local contents = {}
    for _, gridName in ipairs({ "pocket", "vest", "backpack" }) do
        local section = sections[gridName]
        if not istable(section) then continue end

        for _, entry in ipairs(inv[gridName] or {}) do
            local copied = CopyItemEntry(entry, {
                x = (tonumber(section.x) or 0) + (tonumber(entry.x) or 0),
                y = (tonumber(section.y) or 0) + (tonumber(entry.y) or 0),
                live_grid = gridName,
            })
            if copied and copied.class then
                contents[#contents + 1] = copied
            end
        end
    end

    CorpseContainers()[rootUID] = {
        uid = rootUID,
        class = LIVE_LOOT_CONTAINER_CLASS,
        gw = width,
        gh = height,
        contents = contents,
        layout = blocks,
        live_sections = sections,
        ragdoll = ragdoll,
        owner = owner,
        live_owner = true,
        has_tracked_head_gear = false,
    }

    return rootUID
end

local function SuppressDeathDroppedWeaponEntity(wep)
    if not (IsValid(wep) and wep:IsWeapon()) then return false end
    if wep.zscav_death_drop_suppressed then return true end

    local phys = wep.GetPhysicsObject and wep:GetPhysicsObject() or nil
    if IsValid(phys) then
        phys:SetVelocity(vector_origin)
        phys:EnableMotion(false)
        phys:Sleep()
    end

    if wep.SetMoveType then
        wep:SetMoveType(MOVETYPE_NONE)
    end

    if wep.SetNotSolid then
        wep:SetNotSolid(true)
    end

    if wep.AddSolidFlags then
        wep:AddSolidFlags(FSOLID_NOT_SOLID)
    end

    if wep.SetCollisionGroup then
        wep:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    end

    if wep.SetNoDraw then
        wep:SetNoDraw(true)
    end

    wep.zscav_pickup_claimed = true
    wep.zscav_death_drop_suppressed = true
    wep.zscav_ignore_until = CurTime() + 3600

    return true
end

local function TrackSuppressedDeathWeapon(ply, wep)
    if not (IsValid(ply) and IsValid(wep)) then return end

    local suppressed = ply.zscav_suppressed_death_weapons or {}
    suppressed[wep:EntIndex()] = wep
    ply.zscav_suppressed_death_weapons = suppressed
end

local function CleanupSuppressedDeathWeapons(ply)
    local suppressed = IsValid(ply) and ply.zscav_suppressed_death_weapons or nil
    if not istable(suppressed) then return end

    ply.zscav_suppressed_death_weapons = nil

    for _, wep in pairs(suppressed) do
        if IsValid(wep) then
            wep:Remove()
        end
    end
end

local function IsDeathDropSuppressionActive(ply)
    if not IsValid(ply) then return false end
    if (tonumber(ply.zscav_death_drop_pending_until) or 0) > CurTime() then
        return true
    end
    if istable(ply.zscav_death_inventory_snapshot) then
        return true
    end
    if not ply:Alive() then
        return true
    end

    return IsValid(ply:GetNWEntity("RagdollDeath"))
end

local function NormalizeCorpseEntry(entry, overrides)
    local out = CopyItemEntry(entry, overrides)
    if not out or not out.class then return nil end

    local size = ZSCAV:GetItemSize(out) or { w = out.w or 1, h = out.h or 1 }
    out.w = math.max(tonumber(out.w) or tonumber(size.w) or 1, 1)
    out.h = math.max(tonumber(out.h) or tonumber(size.h) or 1, 1)
    out.x = nil
    out.y = nil
    out.slot = nil
    return out
end

local function BuildMailboxDeathTransferEntries(inv)
    if not istable(inv) then return {} end

    local entries = {}
    local backpackStored = false
    local vestStored = false

    local function addMailboxEntry(entry, overrides)
        local normalized = NormalizeCorpseEntry(entry, overrides)
        if normalized then
            entries[#entries + 1] = normalized
        end
    end

    for slotID, entry in pairs(inv.gear or {}) do
        if slotID ~= "secure_container" and istable(entry) and entry.class then
            local def = ZSCAV:GetGearDef(entry.class)
            local uid = tostring(entry.uid or "")

            if slotID == "backpack" then
                if uid == "" and def then
                    uid = tostring(ZSCAV:CreateBag(entry.class) or "")
                    entry.uid = uid
                end
                if uid ~= "" then
                    backpackStored = true
                    ZSCAV:SaveBag(uid, entry.class, inv.backpack or {})
                end
            elseif (slotID == "tactical_rig" or slotID == "vest") and def and def.compartment then
                if uid == "" then
                    uid = tostring(ZSCAV:CreateBag(entry.class) or "")
                    entry.uid = uid
                end
                if uid ~= "" then
                    vestStored = true
                    ZSCAV:SaveBag(uid, entry.class, inv.vest or {})
                end
            end

            addMailboxEntry(entry, {
                uid = uid ~= "" and uid or nil,
            })
        end
    end

    for _, entry in pairs(inv.weapons or {}) do
        if istable(entry) and entry.class then
            addMailboxEntry(entry)
        end
    end

    for _, entry in ipairs(inv.pocket or {}) do
        addMailboxEntry(entry)
    end

    if not vestStored then
        for _, entry in ipairs(inv.vest or {}) do
            addMailboxEntry(entry)
        end
    end

    if not backpackStored then
        for _, entry in ipairs(inv.backpack or {}) do
            addMailboxEntry(entry)
        end
    end

    return entries
end

function ZSCAV:BuildMailboxTransferEntries(inv)
    return BuildMailboxDeathTransferEntries(inv)
end

function ZSCAV:DeliverInventoryToMailbox(ply, options)
    if not (IsValid(ply) and isfunction(DeliverToPlayerMailbox)) then return false, 0, "invalid_player" end

    local ownerSID64 = tostring(ply:SteamID64() or "")
    if ownerSID64 == "" then return false, 0, "missing_sid64" end

    options = istable(options) and options or {}

    local inv = istable(options.inv) and options.inv or ply.zscav_inv
    local entries = BuildMailboxDeathTransferEntries(inv)
    return DeliverToPlayerMailbox(ownerSID64, {
        entries = entries,
        source = tostring(options.source or "ZScav"),
        subject = tostring(options.subject or "ZScav Recovery"),
        message = tostring(options.message or "Items were sent to your mailbox."),
        notify = options.notify == true,
    })
end

local ZSCAV_SAFEZONE_RESPAWN_FADE_IN = 0.14
local ZSCAV_SAFEZONE_RESPAWN_DELAY = 0.24
local ZSCAV_SAFEZONE_MAILBOX_FALLBACK = "Mailbox recovery failed. Field loot remains on your body."
local ZSCAV_FIELD_DEATH_RECOVERY = "Return to lobby to respawn at ZSCAV_SAFESPAWN. Field loot remains on your body."

local function SendZScavDeathFade(ply, fadeInDuration)
    if not IsValid(ply) then return end

    net.Start("ZScavDeathFade")
        net.WriteFloat(math.max(tonumber(fadeInDuration) or ZSCAV_SAFEZONE_RESPAWN_FADE_IN, 0.01))
    net.Send(ply)
end

local function SendZScavDeathOverlay(ply, recoveryLine)
    if not IsValid(ply) then return end

    local summary = istable(ply.zscav_death_summary) and ply.zscav_death_summary or nil

    net.Start("ZScavDeathOpen")
        net.WriteString(tostring(summary and summary.attacker or "Unknown"))
        net.WriteString(tostring(summary and summary.cause or "Unknown cause"))
        net.WriteString(tostring(recoveryLine or ZSCAV_FIELD_DEATH_RECOVERY))
    net.Send(ply)
end

local function QueueSafeZoneInstantRespawn(ply)
    if not IsValid(ply) then return end

    SendZScavDeathFade(ply, ZSCAV_SAFEZONE_RESPAWN_FADE_IN)

    timer.Simple(ZSCAV_SAFEZONE_RESPAWN_DELAY, function()
        if not (IsValid(ply) and ZSCAV:IsActive()) then return end
        if ply:Alive() then return end
        if ply:Team() == TEAM_SPECTATOR then return end

        ZSCAV:QueueSafeSpawn(ply)
        ply:Spawn()
    end)
end

local function DivertSafeZoneDeathToMailbox(ply, ragdoll)
    local pending = istable(ply.zscav_safezone_death_mailbox_pending)
        and ply.zscav_safezone_death_mailbox_pending
        or nil
    local zoneName = tostring(pending and pending.zone_name or "")
    local inv = istable(ply.zscav_death_inventory_snapshot) and ply.zscav_death_inventory_snapshot or ply.zscav_inv
    local ok, count = ZSCAV:DeliverInventoryToMailbox(ply, {
        inv = inv,
        source = zoneName ~= "" and (zoneName .. " Safe Zone") or "Safe Zone",
        subject = zoneName ~= "" and ("Protected Recovery: " .. zoneName) or "Protected Recovery",
        message = zoneName ~= "" and ("Items were recovered after a protected death in " .. zoneName .. ".")
            or "Items were recovered after a protected death.",
        notify = false,
    })

    if not ok then return false end

    CleanupSuppressedDeathWeapons(ply)
    ply.zscav_death_drop_pending_until = nil
    ply.zscav_death_inventory_snapshot = nil
    ply.zscav_safezone_death_mailbox_pending = nil

    if IsValid(ragdoll) then
        ragdoll.zscav_safezone_unlootable = true
        ragdoll.zscav_corpse_root_uid = nil
        timer.Simple(0, function()
            if IsValid(ragdoll) then
                ragdoll:Remove()
            end
        end)
    end

    if isfunction(SyncMailboxUnread) then
        SyncMailboxUnread(ply)
    end

    if count > 0 then
        Notice(ply, string.format("Safe-zone recovery sent %d item%s to your mailbox.", count, count == 1 and "" or "s"))
    else
        Notice(ply, "Safe-zone recovery found nothing to mail.")
    end

    QueueSafeZoneInstantRespawn(ply)

    return true
end

local function FormatDeathDisplayLabel(value)
    value = tostring(value or "")
    if value == "" then return "Unknown" end

    value = string.Replace(value, "weapon_", "")
    value = string.Replace(value, "ent_", "")
    value = string.Replace(value, "npc_", "")
    value = string.Replace(value, "sent_", "")
    return string.NiceName(value)
end

local function DescribeDeathActor(ply, attacker)
    if IsValid(attacker) then
        if attacker == ply then
            return "Yourself"
        end

        if attacker:IsPlayer() then
            return tostring(attacker:Nick() or "Player")
        end

        local printName = tostring(attacker.PrintName or "")
        if printName ~= "" and printName ~= attacker:GetClass() then
            return printName
        end

        return FormatDeathDisplayLabel(attacker:GetClass())
    end

    return "Environment"
end

local function DescribeDeathCause(ply, attacker, inflictor)
    if IsValid(inflictor) then
        if inflictor == ply then
            return "Suicide"
        end

        local printName = tostring(inflictor.PrintName or "")
        if printName ~= "" and printName ~= inflictor:GetClass() then
            return printName
        end

        return FormatDeathDisplayLabel(inflictor:GetClass())
    end

    if IsValid(attacker) then
        if attacker == ply then
            return "Suicide"
        end

        if attacker:IsPlayer() then
            local activeWeapon = attacker.GetActiveWeapon and attacker:GetActiveWeapon() or nil
            if IsValid(activeWeapon) then
                return FormatDeathDisplayLabel(activeWeapon:GetClass())
            end

            return "Unknown weapon"
        end

        return FormatDeathDisplayLabel(attacker:GetClass())
    end

    return "Unknown cause"
end

local function PackCorpseEntries(entries, minW, minH)
    local packed = {}
    local width = math.max(tonumber(minW) or 4, 4)
    local height = math.max(tonumber(minH) or 4, 4)

    for _, entry in ipairs(entries) do
        width = math.max(width, tonumber(entry.w) or 1)
    end

    table.sort(entries, function(left, right)
        local leftArea = (tonumber(left.w) or 1) * (tonumber(left.h) or 1)
        local rightArea = (tonumber(right.w) or 1) * (tonumber(right.h) or 1)
        if leftArea ~= rightArea then
            return leftArea > rightArea
        end
        return tostring(left.class or "") < tostring(right.class or "")
    end)

    for _, entry in ipairs(entries) do
        local x, y, wasRotated = findFreeSpotAR(packed, width, height, entry.w, entry.h)
        while not x do
            height = height + 1
            x, y, wasRotated = findFreeSpotAR(packed, width, height, entry.w, entry.h)
        end

        packed[#packed + 1] = CopyItemEntry(entry, {
            x = x,
            y = y,
            w = wasRotated and entry.h or entry.w,
            h = wasRotated and entry.w or entry.h,
            slot = nil,
        })
    end

    return width, height, packed
end

local corpseHeadGearSlots = {
    helmet = true,
    face_cover = true,
    ears = true,
}

local function CorpseHasTrackedHeadGear(record)
    for _, entry in ipairs(record and record.contents or {}) do
        if tostring(entry and entry.corpse_slot_kind or "") == "gear"
            and corpseHeadGearSlots[tostring(entry and entry.corpse_slot_id or "")] == true then
            return true
        end
    end

    return false
end

local function IsCorpseHeadAmputated(ragdoll, owner)
    local ragdollOrg = IsValid(ragdoll) and ragdoll.organism or nil
    local ownerOrg = IsValid(owner) and owner.organism or nil

    return (IsValid(ragdoll) and ragdoll.headexploded == true)
        or (istable(ragdollOrg) and ragdollOrg.headamputated == true)
        or (istable(ownerOrg) and ownerOrg.headamputated == true)
end

local function ShouldSkipCorpseGearSlot(ragdoll, owner, slotID)
    slotID = tostring(slotID or "")
    return corpseHeadGearSlots[slotID] == true and IsCorpseHeadAmputated(ragdoll, owner)
end

local function PruneDetachedCorpseHeadGear(rootUID, ragdoll, owner)
    local corpse = GetCorpseContainer(rootUID)
    if not corpse then return false end
    if corpse.has_tracked_head_gear == false then return false end
    if not IsCorpseHeadAmputated(ragdoll, owner) then return false end

    local changed = false
    local filtered = {}

    for _, entry in ipairs(corpse.contents or {}) do
        local isHeadGear = tostring(entry and entry.corpse_slot_kind or "") == "gear"
            and corpseHeadGearSlots[tostring(entry and entry.corpse_slot_id or "")] == true

        if isHeadGear then
            changed = true
        else
            filtered[#filtered + 1] = entry
        end
    end

    if not changed then
        corpse.has_tracked_head_gear = CorpseHasTrackedHeadGear(corpse)
        return false
    end

    corpse.contents = filtered
    corpse.has_tracked_head_gear = CorpseHasTrackedHeadGear(corpse)
    ApplyCorpseAnchorVisualState(corpse)

    return true
end

local function ScheduleCorpseHeadGearPrune(ragdoll)
    if not IsValid(ragdoll) then return false end

    local rootUID = tostring(ragdoll.zscav_corpse_root_uid or "")
    if rootUID == "" then return false end

    local corpse = GetCorpseContainer(rootUID)
    if not corpse or corpse.has_tracked_head_gear == false then return false end
    if corpse.head_gear_prune_pending then return true end

    corpse.head_gear_prune_pending = true
    timer.Simple(0, function()
        local liveCorpse = GetCorpseContainer(rootUID)
        if not liveCorpse then return end

        liveCorpse.head_gear_prune_pending = nil
        PruneDetachedCorpseHeadGear(rootUID, liveCorpse.ragdoll, liveCorpse.owner)
    end)

    return true
end

local function BuildCorpseRootContainer(ragdoll, owner)
    if not (IsValid(ragdoll) and IsValid(owner)) then return nil end

    local inv = istable(owner.zscav_death_inventory_snapshot) and owner.zscav_death_inventory_snapshot or owner.zscav_inv
    if not istable(inv) then return nil end

    local entries = {}
    local seenSlots = {}
    local seenWeaponSlots = {}
    local grids = ZSCAV:GetEffectiveGrids(inv)
    local pocketGrid = grids and grids.pocket or { w = 4, h = 4 }

    local function normalizeCorpseSlotID(slotID)
        slotID = tostring(slotID or "")
        if slotID == "vest" then return "tactical_rig" end
        return slotID
    end

    local function addCorpseEntry(entry, overrides)
        local normalized = NormalizeCorpseEntry(entry, overrides)
        if normalized then
            entries[#entries + 1] = normalized
        end
    end

    local gearOrder = {
        "helmet",
        "face_cover",
        "ears",
        "body_armor",
        "tactical_rig",
        "vest",
        "backpack",
    }

    local weaponOrder = {
        "primary",
        "secondary",
        "sidearm",
        "sidearm2",
    }

    for _, slotID in ipairs(gearOrder) do
        local entry = inv.gear and inv.gear[slotID]
        if istable(entry) and entry.class and slotID ~= "secure_container" then
            if ShouldSkipCorpseGearSlot(ragdoll, owner, slotID) then
                seenSlots[slotID] = true
                continue
            end

            seenSlots[slotID] = true

            local corpseSlotID = normalizeCorpseSlotID(slotID)
            local corpseSection = "body"
            if corpseSlotID == "tactical_rig" then
                corpseSection = "tactical_rig"
            elseif corpseSlotID == "backpack" then
                corpseSection = "backpack"
            end

            local def = ZSCAV:GetGearDef(entry.class)
            local uid = tostring(entry.uid or "")
            if uid == "" and def and (slotID == "backpack" or def.compartment) then
                uid = tostring(ZSCAV:CreateBag(entry.class) or "")
                entry.uid = uid
            end

            if uid ~= "" then
                if slotID == "backpack" then
                    ZSCAV:SaveBag(uid, entry.class, inv.backpack or {})
                elseif (slotID == "tactical_rig" or slotID == "vest") and def and def.compartment then
                    ZSCAV:SaveBag(uid, entry.class, inv.vest or {})
                end
            end

            addCorpseEntry(entry, {
                uid = uid ~= "" and uid or nil,
                slot = nil,
                corpse_slot_kind = "gear",
                corpse_slot_id = corpseSlotID,
                corpse_section = corpseSection,
            })
        end
    end

    for slotID, entry in pairs(inv.gear or {}) do
        if not seenSlots[slotID] and slotID ~= "secure_container" and istable(entry) and entry.class then
            if ShouldSkipCorpseGearSlot(ragdoll, owner, slotID) then continue end

            addCorpseEntry(entry, {
                slot = nil,
                corpse_slot_kind = "gear",
                corpse_slot_id = normalizeCorpseSlotID(slotID),
                corpse_section = "extra",
            })
        end
    end

    for _, slotID in ipairs(weaponOrder) do
        local entry = inv.weapons and inv.weapons[slotID]
        if istable(entry) and entry.class then
            seenWeaponSlots[slotID] = true
            addCorpseEntry(entry, {
                slot = nil,
                corpse_slot_kind = "weapon",
                corpse_slot_id = tostring(slotID),
                corpse_section = "body",
            })
        end
    end

    for slotID, entry in pairs(inv.weapons or {}) do
        if seenWeaponSlots[slotID] then continue end
        if slotID == "melee" or slotID == "scabbard" then continue end
        if istable(entry) and entry.class then
            addCorpseEntry(entry, {
                slot = nil,
                corpse_slot_kind = "weapon",
                corpse_slot_id = tostring(slotID),
                corpse_section = "extra",
            })
        end
    end

    for _, entry in ipairs(inv.pocket or {}) do
        addCorpseEntry(entry, {
            slot = nil,
            corpse_section = "pocket",
            corpse_grid = "pocket",
            corpse_grid_x = tonumber(entry.x) or 0,
            corpse_grid_y = tonumber(entry.y) or 0,
        })
    end

    local width, height, packed = PackCorpseEntries(entries, pocketGrid.w, pocketGrid.h)
    local rootUID = tostring(ragdoll.zscav_corpse_root_uid or "")
    if rootUID == "" then
        rootUID = NewCorpseContainerUID(ragdoll)
        ragdoll.zscav_corpse_root_uid = rootUID
    end

    local corpse = {
        uid = rootUID,
        class = CORPSE_CONTAINER_CLASS,
        gw = width,
        gh = height,
        contents = packed,
        ragdoll = ragdoll,
        owner = owner,
    }
    corpse.has_tracked_head_gear = CorpseHasTrackedHeadGear(corpse)
    CorpseContainers()[rootUID] = corpse

    ApplyCorpseAnchorVisualState(corpse)

    -- Head explosions mark the ragdoll on the next tick, after PostPlayerDeath
    -- has already snapshot the corpse inventory. Prune those detached slots once
    -- the ragdoll state settles so the corpse view cannot duplicate dropped gear.
    PruneDetachedCorpseHeadGear(rootUID, ragdoll, owner)
    timer.Simple(0, function()
        if not IsValid(ragdoll) then return end
        PruneDetachedCorpseHeadGear(rootUID, ragdoll, owner)
    end)

    CleanupSuppressedDeathWeapons(owner)
    owner.zscav_death_drop_pending_until = nil
    owner.zscav_death_inventory_snapshot = nil

    return rootUID
end

hook.Add("OnHeadExplode", "ZSCAV_PruneDetachedCorpseHeadGear", function(_owner, ragdoll)
    if not (IsValid(ragdoll) and ragdoll:IsRagdoll()) then return end
    ScheduleCorpseHeadGearPrune(ragdoll)
end)

hook.Add("PlayerDroppedWeapon", "ZSCAV_RecordDeathDroppedWeapon", function(ply, wep)
    if not (IsValid(ply) and IsValid(wep) and ZSCAV:IsActive()) then return end
    if not IsDeathDropSuppressionActive(ply) then return end

    if not SuppressDeathDroppedWeaponEntity(wep) then return end

    TrackSuppressedDeathWeapon(ply, wep)
    timer.Simple(0, function()
        if IsValid(wep) and wep.zscav_death_drop_suppressed then
            wep:Remove()
        end
    end)
end)

function ZSCAV:OpenCorpseLootForPlayer(ply, ent)
    if not (IsValid(ply) and IsValid(ent) and self:IsActive()) then return false end

    local liveOwner, liveRagdoll = FindLivingRagdollOwner(ent)
    if IsValid(liveOwner) and IsValid(liveRagdoll) then
        local rootUID = BuildLiveLootProxyContainer(liveRagdoll, liveOwner)
        if rootUID == nil or rootUID == "" then return false end

        self:OpenContainerForPlayer(ply, rootUID, LIVE_LOOT_CONTAINER_CLASS, liveRagdoll)
        return true
    end

    local ragdoll = ent
    if ent:IsPlayer() then
        local deathRagdoll = ent:GetNWEntity("RagdollDeath")
        if IsValid(deathRagdoll) then
            ragdoll = deathRagdoll
        else
            for _, record in pairs(CorpseContainers()) do
                if istable(record) and record.owner == ent and IsValid(record.ragdoll) then
                    ragdoll = record.ragdoll
                    break
                end
            end
        end
    end

    if not IsValid(ragdoll) then return false end

    if ragdoll.zscav_safezone_unlootable then
        Notice(ply, "This body was protected by a safe zone. Its gear was recovered by mailbox.")
        return false
    end

    local rootUID = tostring(ragdoll.zscav_corpse_root_uid or "")
    if rootUID == "" or not GetCorpseContainer(rootUID) then
        return false
    end

    self:OpenContainerForPlayer(ply, rootUID, CORPSE_CONTAINER_CLASS, ragdoll)
    return true
end

hook.Add("EntityRemoved", "ZSCAV_ClearCorpseContainerState", function(ent)
    local rootUID = tostring(ent and ent.zscav_corpse_root_uid or "")
    if rootUID ~= "" then
        local record = CorpseContainers()[rootUID]
        if istable(record) and record.ragdoll == ent then
            if record.live_owner ~= true then
                for _, entry in ipairs(record.contents or {}) do
                    local uid = tostring(entry and entry.uid or "")
                    if uid ~= "" then
                        ZSCAV:DeleteBag(uid)
                    end
                end
            end
            CorpseContainers()[rootUID] = nil
        end
    end
end)

-- Periodic safety net while ZScav is the active round.
timer.Create("ZSCAV_StateReconcileLoop", 0.5, 0, function()
    if not ZSCAV or not ZSCAV.IsActive or not ZSCAV:IsActive() then return end

    for rootUID, record in pairs(CorpseContainers()) do
        if not istable(record) then
            CorpseContainers()[rootUID] = nil
        elseif not IsValid(record.ragdoll) then
            CorpseContainers()[rootUID] = nil
        elseif record.live_owner ~= true and record.has_tracked_head_gear ~= false and IsCorpseHeadAmputated(record.ragdoll, record.owner) then
            PruneDetachedCorpseHeadGear(rootUID, record.ragdoll, record.owner)
        end
    end

    for _, ply in player.Iterator() do
        if IsValid(ply) then
            ZSCAV:ReconcileWeapons(ply)
            ZSCAV:ReconcileArmor(ply)
            ZSCAV:ApplyWeightToOrganism(ply)
            ZSCAV:ProcessGrenadeThrowConsumption(ply)
        end
    end
end)

ZSCAV.CorpseModule = {
    GetCorpseContainer = GetCorpseContainer,
    ApplyLiveLootProxyContents = ApplyLiveLootProxyContents,
    ApplyCorpseAnchorVisualState = ApplyCorpseAnchorVisualState,
    CorpseHasTrackedHeadGear = CorpseHasTrackedHeadGear,
    DescribeDeathActor = DescribeDeathActor,
    DescribeDeathCause = DescribeDeathCause,
    SendZScavDeathOverlay = SendZScavDeathOverlay,
    DivertSafeZoneDeathToMailbox = DivertSafeZoneDeathToMailbox,
    BuildCorpseRootContainer = BuildCorpseRootContainer,
    SafeZoneMailboxFallback = ZSCAV_SAFEZONE_MAILBOX_FALLBACK,
}