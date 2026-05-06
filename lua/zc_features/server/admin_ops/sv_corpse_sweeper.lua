if CLIENT then return end

local CV_ENABLE = CreateConVar(
    "zc_corpse_sweeper_enable",
    "1",
    FCVAR_ARCHIVE,
    "Enable periodic cleanup of NPC corpses and dead player bodies."
)

local CV_INTERVAL = CreateConVar(
    "zc_corpse_sweeper_interval",
    "180",
    FCVAR_ARCHIVE,
    "Seconds between corpse sweeps."
)

local CORPSE_LOOT_BOX_MODEL = "models/props_junk/cardboard_box003a.mdl"
local CORPSE_LOOT_BOX_DESPAWN_TIME = 300

local function IsRoundModeActive(modeName)
    if not CurrentRound then return false end
    local round = CurrentRound()
    if not round then return false end
    return string.lower(tostring(round.name or "")) == string.lower(tostring(modeName or ""))
end

local function IsZRPModeActive()
    return IsRoundModeActive("zrp")
end

local function IsEventModeActive()
    return IsRoundModeActive("event")
end

local function IsZScavModeActive()
    return IsRoundModeActive((ZSCAV and ZSCAV.MODE_NAME) or "zscav")
end

local function IsLootCorpseModeActive()
    return IsZRPModeActive() or IsEventModeActive()
end

local function FreezeDroppedWeaponForZScav(ent)
    if not (IsValid(ent) and ent:IsWeapon()) then return false end
    if ent.zc_corpse_sweep_frozen then return false end

    local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil
    if IsValid(phys) then
        phys:SetVelocity(vector_origin)

        local angVel = phys.GetAngleVelocity and phys:GetAngleVelocity() or nil
        if isvector(angVel) then
            phys:AddAngleVelocity(-angVel)
        end

        phys:EnableMotion(false)
        phys:Sleep()
    end

    if ent.SetMoveType then
        ent:SetMoveType(MOVETYPE_NONE)
    end

    if ent.SetCollisionGroup then
        ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    end

    ent.zc_corpse_sweep_frozen = true
    ent.zc_corpse_sweep_frozen_at = CurTime()

    return true
end

local function EnsureInventoryShape(inventory)
    inventory = istable(inventory) and inventory or {}
    inventory.Weapons = istable(inventory.Weapons) and inventory.Weapons or {}
    inventory.Ammo = istable(inventory.Ammo) and inventory.Ammo or {}
    inventory.Armor = istable(inventory.Armor) and inventory.Armor or {}
    inventory.Attachments = istable(inventory.Attachments) and inventory.Attachments or {}
    return inventory
end

local function HasAnyPositiveValue(tbl)
    if not istable(tbl) then return false end
    for _, value in pairs(tbl) do
        local n = tonumber(value)
        if n and n > 0 then
            return true
        end

        if istable(value) and next(value) ~= nil then
            return true
        end
    end

    return false
end

local function NormalizeWeaponEntriesForLootBox(inventory, stashPos)
    inventory = EnsureInventoryShape(inventory)
    local normalizedWeapons = {}

    for className, weaponData in pairs(inventory.Weapons) do
        if isentity(weaponData) then
            if IsValid(weaponData) and weaponData:IsWeapon() then
                local resolvedClass = string.lower(tostring(weaponData:GetClass() or className or ""))
                weaponData:SetParent(NULL)
                weaponData:SetNoDraw(true)
                weaponData:DrawShadow(false)
                weaponData:AddSolidFlags(FSOLID_NOT_SOLID)

                if stashPos then
                    weaponData:SetPos(stashPos)
                end

                if resolvedClass ~= "" then
                    normalizedWeapons[resolvedClass] = weaponData.GetInfo and weaponData:GetInfo() or true
                end
            else
                -- Preserve the class key so taking the entry can still spawn the weapon.
                local resolvedClass = string.lower(tostring(className or ""))
                if resolvedClass ~= "" then
                    normalizedWeapons[resolvedClass] = true
                end
            end
        else
            local resolvedClass = string.lower(tostring(className or ""))
            if resolvedClass ~= "" then
                normalizedWeapons[resolvedClass] = weaponData ~= nil and weaponData or true
            end
        end
    end

    inventory.Weapons = normalizedWeapons

    return inventory
end

local function HasAnyCorpseLoot(inventory, armors)
    inventory = EnsureInventoryShape(inventory)
    armors = istable(armors) and armors or {}

    for _, weaponData in pairs(inventory.Weapons) do
        if isentity(weaponData) then
            if IsValid(weaponData) and weaponData:IsWeapon() then
                return true
            end
        else
            return true
        end
    end

    if HasAnyPositiveValue(inventory.Ammo) then return true end
    if HasAnyPositiveValue(inventory.Armor) then return true end
    if next(inventory.Attachments) ~= nil then return true end
    if HasAnyPositiveValue(armors) or next(armors) ~= nil then return true end

    return false
end

local function IsCorpseLootBoxEmpty(ent)
    if not IsValid(ent) or not ent.ZC_CorpseSweepLootBox then return false end

    local inventory = ent.inventory
    if not istable(inventory) and ent.GetNetVar then
        inventory = ent:GetNetVar("Inventory", {})
    end

    local armors = ent.armors
    if not istable(armors) and ent.GetNetVar then
        armors = ent:GetNetVar("Armor", {})
    end

    return not HasAnyCorpseLoot(inventory, armors)
end

local function SpawnCorpseLootBoxFromRagdoll(ragdoll)
    if not IsValid(ragdoll) or not IsLootCorpseModeActive() then return false end

    local inventory = table.Copy(ragdoll.inventory or ragdoll:GetNetVar("Inventory", {}))
    local armors = table.Copy(ragdoll.armors or ragdoll:GetNetVar("Armor", {}))

    inventory = EnsureInventoryShape(inventory)
    inventory = NormalizeWeaponEntriesForLootBox(inventory, ragdoll:GetPos() + Vector(0, 0, -10000))
    armors = istable(armors) and armors or {}

    if not HasAnyCorpseLoot(inventory, armors) then
        return false
    end

    local box = ents.Create("prop_physics")
    if not IsValid(box) then return false end

    box:SetModel(CORPSE_LOOT_BOX_MODEL)
    box:SetPos(ragdoll:GetPos() + Vector(0, 0, 8))
    box:SetAngles(Angle(0, ragdoll:GetAngles().y, 0))
    box:Spawn()
    box:Activate()

    local phys = box:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    box.ZC_CorpseSweepLootBox = true
    box.was_opened = true
    box:SetMaxHealth(2147483647)
    box:SetHealth(2147483647)

    box.inventory = inventory
    box.armors = armors
    box:SetNetVar("Inventory", inventory)
    box:SetNetVar("Armor", armors)

    if box.SyncArmor then
        box:SyncArmor()
    end

    -- Safety: if transfer race leaves a box empty, remove it immediately.
    if IsCorpseLootBoxEmpty(box) then
        box:Remove()
        return false
    end

    timer.Simple(0, function()
        if IsValid(box) and IsCorpseLootBoxEmpty(box) then
            box:Remove()
        end
    end)

    timer.Simple(CORPSE_LOOT_BOX_DESPAWN_TIME, function()
        if IsValid(box) then
            box:Remove()
        end
    end)

    return true
end

local function IsZScavCorpseAnchor(ragdoll)
    return IsValid(ragdoll) and ragdoll:GetClass() == "prop_ragdoll" and tostring(ragdoll.zscav_corpse_root_uid or "") ~= ""
end

local function SpawnZScavCorpseLootBoxFromRagdoll(ragdoll)
    if not IsZScavCorpseAnchor(ragdoll) then return false end

    local box = ents.Create("prop_physics")
    if not IsValid(box) then return false end

    box:SetModel(CORPSE_LOOT_BOX_MODEL)
    box:SetPos(ragdoll:GetPos() + Vector(0, 0, 8))
    box:SetAngles(Angle(0, ragdoll:GetAngles().y, 0))
    box:Spawn()
    box:Activate()

    local phys = box:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    if not (ZSCAV and ZSCAV.RebindCorpseContainerAnchor and ZSCAV:RebindCorpseContainerAnchor(ragdoll, box)) then
        box:Remove()
        return false
    end

    box.ZC_CorpseSweepCorpseAnchorBox = true
    box.was_opened = true
    box.PhysgunDisabled = true
    box:SetMaxHealth(2147483647)
    box:SetHealth(2147483647)

    return true
end

hook.Add("EntityTakeDamage", "ZC_CorpseSweeper_ProtectLootBoxes", function(ent, dmg)
    if not IsValid(ent) then return end
    if not ent.ZC_CorpseSweepLootBox and not ent.ZC_CorpseSweepCorpseAnchorBox then return end
    dmg:SetDamage(0)
    return true
end)

local nextEmptyLootBoxSweep = 0
hook.Add("Think", "ZC_CorpseSweeper_RemoveEmptyLootBoxes", function()
    if CurTime() < nextEmptyLootBoxSweep then return end
    nextEmptyLootBoxSweep = CurTime() + 0.25

    for _, ent in ipairs(ents.FindByClass("prop_physics")) do
        if IsCorpseLootBoxEmpty(ent) then
            ent:Remove()
        end
    end
end)

local function BuildProtectedRagdollSet()
    local protected = {}
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end

        if IsValid(ply.FakeRagdoll) then
            protected[ply.FakeRagdoll] = true
        end

        if IsValid(ply.GlideRagdoll) then
            protected[ply.GlideRagdoll] = true
        end

        if ply.GetNWEntity then
            local nwRag = ply:GetNWEntity("FakeRagdoll")
            if IsValid(nwRag) then
                protected[nwRag] = true
            end
        end
    end
    return protected
end

local function IsAlivePlayerRagdoll(ragdoll, protectedSet)
    if not IsValid(ragdoll) or ragdoll:GetClass() ~= "prop_ragdoll" then return false end

    if protectedSet and protectedSet[ragdoll] then
        return true
    end

    if hg and hg.RagdollOwner then
        local owner = hg.RagdollOwner(ragdoll)
        if IsValid(owner) and owner:IsPlayer() and owner:Alive() then
            return true
        end
    end

    if ragdoll.GetNWEntity then
        local owner = ragdoll:GetNWEntity("RagdollOwner")
        if IsValid(owner) and owner:IsPlayer() and owner:Alive() then
            return true
        end

        local ply = ragdoll:GetNWEntity("ply")
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
            if ply:GetNWEntity("FakeRagdoll") == ragdoll or ply.FakeRagdoll == ragdoll then
                return true
            end
        end
    end

    return false
end

local function SweepCorpses(reason)
    local removedRagdolls = 0
    local spawnedLootBoxes = 0
    local protectedRagdolls = 0
    local zscavCorpseBoxes = 0
    local removedDeadNpc = 0
    local removedDroppedWeapons = 0
    local frozenDroppedWeapons = 0
    local protectedNpcComponents = 0
    local protectedSet = BuildProtectedRagdollSet()

    local function IsProtectedNpcComponent(ent)
        if IsValid(ent:GetParent()) then return true end

        local owner = ent.GetOwner and ent:GetOwner() or nil
        if IsValid(owner) and (owner:IsNPC() or owner:IsVehicle() or owner:IsPlayer()) then
            return true
        end

        -- A lot of legacy SNPC parts are "alive" but use StartHealth=0.
        if ent.Dead == false then
            return true
        end

        return false
    end

    local function IsClearlyDeadNpc(ent)
        if ent.Dead == true then return true end
        if ent.GetNWBool and ent:GetNWBool("Dead", false) then return true end
        if ent.GetInternalVariable then
            local lifeState = ent:GetInternalVariable("m_lifeState")
            if isnumber(lifeState) and lifeState ~= 0 then
                return true
            end
        end

        return false
    end

    -- Most dead NPC/player bodies resolve to prop_ragdoll.
    for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
        if not IsValid(ent) then continue end

        -- Keep map-authored ragdolls (set-dressing) intact.
        if ent.MapCreationID and ent:MapCreationID() ~= -1 then continue end

        -- ZScav backpack ground-form ragdolls. They look like loot
        -- corpses to this sweeper because they're prop_ragdolls with no
        -- player owner, but they hold their loot in the SQL bag table
        -- keyed by zscav_pack_uid -- swallowing them here both deletes
        -- the visible bag and orphans the SQL row (until PurgeUnowned
        -- gets it next round), making it look like the player's loot
        -- got duplicated into a generic loot box and then vanished.
        if ent.IsZScavPack then continue end

        if IsZScavCorpseAnchor(ent) then
            if SpawnZScavCorpseLootBoxFromRagdoll(ent) then
                zscavCorpseBoxes = zscavCorpseBoxes + 1
                removedRagdolls = removedRagdolls + 1
                ent:Remove()
            else
                protectedRagdolls = protectedRagdolls + 1
            end
            continue
        end

        if IsAlivePlayerRagdoll(ent, protectedSet) then
            protectedRagdolls = protectedRagdolls + 1
        else
            if SpawnCorpseLootBoxFromRagdoll(ent) then
                spawnedLootBoxes = spawnedLootBoxes + 1
            end
            ent:Remove()
            removedRagdolls = removedRagdolls + 1
        end
    end

    -- Safety pass for dead NPC entities that did not convert to ragdolls.
    for _, ent in ipairs(ents.FindByClass("npc_*")) do
        if not IsValid(ent) or not ent:IsNPC() then continue end

        if IsProtectedNpcComponent(ent) then
            protectedNpcComponents = protectedNpcComponents + 1
            continue
        end

        if ent:Health() > 0 then continue end
        if not IsClearlyDeadNpc(ent) then continue end

        ent:Remove()
        removedDeadNpc = removedDeadNpc + 1
    end

    -- In ZRP/Event, preserve dropped floor weapons.
    if not IsLootCorpseModeActive() then
        -- Remove dropped floor weapons, but keep physcannon intact.
        for _, ent in ipairs(ents.FindByClass("weapon_*")) do
            if not IsValid(ent) or not ent:IsWeapon() then continue end

            local className = string.lower(tostring(ent:GetClass() or ""))
            if className == "weapon_physcannon" then continue end

            -- Keep map-authored pickups and anything still attached/owned.
            if ent.MapCreationID and ent:MapCreationID() ~= -1 then continue end
            if IsValid(ent:GetParent()) then continue end

            local owner = ent.GetOwner and ent:GetOwner() or nil
            if IsValid(owner) then continue end

            if IsZScavModeActive() then
                if FreezeDroppedWeaponForZScav(ent) then
                    frozenDroppedWeapons = frozenDroppedWeapons + 1
                end
            else
                ent:Remove()
                removedDroppedWeapons = removedDroppedWeapons + 1
            end
        end
    end

    if removedRagdolls > 0 or removedDeadNpc > 0 or removedDroppedWeapons > 0 or frozenDroppedWeapons > 0 or spawnedLootBoxes > 0 or zscavCorpseBoxes > 0 then
        print(string.format(
            "[ZC corpse sweep] %s | removed ragdolls=%d dead_npc=%d removed_dropped_weapons=%d frozen_dropped_weapons=%d spawned_loot_boxes=%d zscav_corpse_boxes=%d protected_living_ragdolls=%d protected_npc_components=%d",
            tostring(reason or "timer"),
            removedRagdolls,
            removedDeadNpc,
            removedDroppedWeapons,
            frozenDroppedWeapons,
            spawnedLootBoxes,
            zscavCorpseBoxes,
            protectedRagdolls,
            protectedNpcComponents
        ))
    end
end

local nextSweep = 0

hook.Add("InitPostEntity", "ZC_CorpseSweeper_Init", function()
    nextSweep = CurTime() + math.max(30, CV_INTERVAL:GetFloat())
end)

hook.Add("PostCleanupMap", "ZC_CorpseSweeper_PostCleanupMap", function()
    nextSweep = CurTime() + math.max(30, CV_INTERVAL:GetFloat())
end)

hook.Add("Think", "ZC_CorpseSweeper_Think", function()
    if not CV_ENABLE:GetBool() then return end
    if CurTime() < nextSweep then return end

    SweepCorpses("timer")
    nextSweep = CurTime() + math.max(30, CV_INTERVAL:GetFloat())
end)

concommand.Add("zc_corpse_sweep_now", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    SweepCorpses(IsValid(ply) and ("manual:" .. ply:Nick()) or "manual:server")
    nextSweep = CurTime() + math.max(30, CV_INTERVAL:GetFloat())
end)
