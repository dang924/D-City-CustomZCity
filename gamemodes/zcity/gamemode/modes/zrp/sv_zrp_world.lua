-- sv_zrp_world.lua — ZRP world-prop container system (server-only).
-- Handles scanning and adoption of map-native props as persistent loot containers.
-- Loaded by the mode loader after sv_zrp.lua (alphabetically later).

local WORLD_CONTAINER_DIR = "zbattle/zrp/worldcontainers"
local WORLD_SNAP_RADIUS   = 48     -- units: tolerance when matching saved positions to live entities
local DEFAULT_RESET_TIME  = 900    -- seconds; matches CONTAINER_RESET_TIME in sv_zrp.lua
local WORLD_INVENTORY_CHECK_INTERVAL = 0.25

local function WorldContainerPath()
    return WORLD_CONTAINER_DIR .. "/" .. game.GetMap() .. ".json"
end

local function EnsureWorldContainerDir()
    if not file.Exists("zbattle",           "DATA") then file.CreateDir("zbattle") end
    if not file.Exists("zbattle/zrp",       "DATA") then file.CreateDir("zbattle/zrp") end
    if not file.Exists(WORLD_CONTAINER_DIR, "DATA") then file.CreateDir(WORLD_CONTAINER_DIR) end
end

-- ── Persistence ───────────────────────────────────────────────────────────────

function ZRP.SaveWorldContainers()
    EnsureWorldContainerDir()
    local out = {}
    for i, d in ipairs(ZRP.WorldContainerData) do
        if d.auto then continue end
        out[i] = {
            model        = d.model,
            pos          = { d.pos.x, d.pos.y, d.pos.z },
            respawnDelay = d.respawnDelay,
            lootOverride = d.lootOverride or {},
        }
    end
    file.Write(WorldContainerPath(), util.TableToJSON(out, true))
    print("[ZRP] World containers saved (" .. #out .. ").")
end

local function IsLootableWorldProp(ent)
    if not IsValid(ent) then return false end
    if ent:GetClass() == "zrp_container" then return false end

    local mdl = string.lower(tostring(ent:GetModel() or ""))
    if mdl == "" then return false end

    if ent.ZRP_AdoptedByEvent then
        return true
    end

    if ent.CPPIGetOwner then
        local owner = ent:CPPIGetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            return true
        end
    end

    local owner = ent.Getowning_ent and ent:Getowning_ent() or nil
    if IsValid(owner) and owner:IsPlayer() then
        return true
    end

    return hg and hg.loot_boxes and hg.loot_boxes[mdl] ~= nil
end

local function HasWorldContainerEntryFor(ent, data, radius)
    local entPos = ent:GetPos()
    local entModel = string.lower(tostring(ent:GetModel() or ""))

    for _, d in ipairs(data or {}) do
        if string.lower(tostring(d.model or "")) ~= entModel then continue end
        if not isvector(d.pos) then continue end
        if d.pos:Distance(entPos) <= radius then
            return true
        end
    end

    return false
end

function ZRP.RebuildAutoWorldContainers(respawnDelay)
    ZRP.WorldContainerData = ZRP.WorldContainerData or {}

    local keep = {}
    for _, d in ipairs(ZRP.WorldContainerData) do
        if not d.auto then
            keep[#keep + 1] = d
        end
    end

    for _, ent in ipairs(ents.GetAll()) do
        if not IsLootableWorldProp(ent) then continue end
        if HasWorldContainerEntryFor(ent, keep, WORLD_SNAP_RADIUS) then continue end

        keep[#keep + 1] = {
            model = string.lower(tostring(ent:GetModel() or "")),
            pos = ent:GetPos(),
            respawnDelay = respawnDelay,
            lootOverride = {},
            auto = true,
        }
    end

    ZRP.WorldContainerData = keep
end

function ZRP.LoadWorldContainers()
    EnsureWorldContainerDir()
    ZRP.WorldContainerData = {}
    local raw = file.Read(WorldContainerPath(), "DATA")
    if not raw or raw == "" then return end
    local t = util.JSONToTable(raw)
    if not t then return end
    for _, d in ipairs(t) do
        local p = d.pos or { 0, 0, 0 }
        ZRP.WorldContainerData[#ZRP.WorldContainerData + 1] = {
            model        = d.model or "",
            pos          = Vector(p[1], p[2], p[3]),
            respawnDelay = d.respawnDelay,
            lootOverride = d.lootOverride or {},
        }
    end
    print("[ZRP] World containers loaded (" .. #ZRP.WorldContainerData ..
          " for " .. game.GetMap() .. ").")
end

-- Adopt a single map prop as a ZRP world container. Shared between the
-- ZRP LootEditor toolgun (RMB) and the Event mode container manager menu so
-- both code paths produce identical state.
-- Returns: ok (bool), message (string), idx (number or nil)
function ZRP.AdoptWorldProp(ent, ply)
    if not IsValid(ent) then return false, "Invalid entity" end
    if ent:GetClass() == "zrp_container" then
        return false, "Already a ZRP container"
    end
    local mdl = ent:GetModel()
    if not mdl or mdl == "" then return false, "Prop has no model" end
    local lower = string.lower(mdl)
    if not (hg and hg.loot_boxes and hg.loot_boxes[lower]) then
        return false, "Model is not in hg.loot_boxes"
    end
    if ent.ZRP_WorldContainerIdx then
        return false, "Already adopted as world container #" .. ent.ZRP_WorldContainerIdx
    end

    ZRP.WorldContainerData = ZRP.WorldContainerData or {}
    local idx = #ZRP.WorldContainerData + 1
    ZRP.WorldContainerData[idx] = {
        model        = lower,
        pos          = ent:GetPos(),
        respawnDelay = nil,
        lootOverride = {},
    }

    if ZRP.SaveWorldContainers then ZRP.SaveWorldContainers() end
    if ZRP.ActivateWorldContainers then ZRP.ActivateWorldContainers() end

    return true, "World container #" .. idx .. " adopted.", idx
end

-- ── Activation ────────────────────────────────────────────────────────────────
-- Called each RoundStart, and incrementally whenever new world containers are
-- adopted. Builds the entindex mapping in WorldContainerState.
--
-- IMPORTANT: This function is NON-DESTRUCTIVE for entities whose mapping does
-- not change. Previously every call wiped every world container's inventory,
-- which silently emptied loot mid-pickup whenever a refill, adoption, or
-- container-list send re-ran activation. Now it only clears markers/inventory
-- on entities that are no longer mapped to their previous WorldContainerData
-- index, and it preserves looted/resetAt/inventory for stable mappings.

function ZRP.ActivateWorldContainers()
    local previousState = ZRP.WorldContainerState or {}
    local previousByEnt = {}
    for idx, st in pairs(previousState) do
        if st and st.entindex and st.entindex > 0 then
            previousByEnt[st.entindex] = idx
        end
    end

    local newState  = {}
    local nowMapped = {}  -- entindex -> idx for all entities now mapped

    for idx, data in ipairs(ZRP.WorldContainerData or {}) do
        local best, bestDist = nil, WORLD_SNAP_RADIUS
        for _, ent in ipairs(ents.GetAll()) do
            if not IsValid(ent) then continue end
            local mdl = ent:GetModel()
            if not mdl or mdl == "" then continue end
            if ent:GetClass() == "zrp_container" then continue end
            if string.lower(mdl) ~= string.lower(data.model or "") then continue end
            local d = ent:GetPos():Distance(data.pos)
            if d < bestDist then bestDist = d; best = ent end
        end

        if IsValid(best) then
            local entindex = best:EntIndex()
            local prevIdxForEnt = previousByEnt[entindex]
            local prev          = previousState[idx]
            local sameMapping   = prevIdxForEnt == idx and prev and prev.entindex == entindex

            best.ZRP_WorldContainerIdx = idx
            best.ZRP_WorldLootOverride = (#(data.lootOverride or {}) > 0) and data.lootOverride or nil
            best:SetUseType(SIMPLE_USE)

            if sameMapping then
                -- Preserve existing inventory + looted/resetAt state.
                newState[idx] = {
                    entindex = entindex,
                    looted   = prev.looted or false,
                    resetAt  = prev.resetAt or 0,
                }
            else
                -- Brand new mapping (or remapped to a different ent): start fresh.
                best.ZRP_WorldLootGenerated = false
                if ZRP.ClearContainerInventory then
                    ZRP.ClearContainerInventory(best)
                end
                newState[idx] = {
                    entindex = entindex,
                    looted   = false,
                    resetAt  = 0,
                }
            end

            nowMapped[entindex] = idx
        end
    end

    -- Clear markers + inventory on entities that were previously mapped but
    -- are no longer mapped to any WorldContainerData entry (only those).
    for entindex, prevIdx in pairs(previousByEnt) do
        if nowMapped[entindex] == prevIdx then continue end
        local ent = ents.GetByIndex(entindex)
        if not IsValid(ent) then continue end
        if nowMapped[entindex] then continue end -- still mapped, just to a different idx
        if ent.ZRP_WorldContainerIdx == nil then continue end

        ent.ZRP_WorldContainerIdx  = nil
        ent.ZRP_WorldLootOverride  = nil
        ent.ZRP_WorldLootGenerated = false
        if ZRP.ClearContainerInventory then
            ZRP.ClearContainerInventory(ent)
        end
    end

    ZRP.WorldContainerState = newState

    local activated = table.Count(ZRP.WorldContainerState)
    print("[ZRP] World containers activated: " .. activated .. "/" ..
          #(ZRP.WorldContainerData or {}))
end

-- Cancel all world container reset timers (called by EndRound in sv_zrp.lua).
function ZRP.CancelWorldContainerTimers()
    for id = 1, #ZRP.WorldContainerData do
        timer.Remove("ZRP_WCReset_" .. id)
        timer.Remove("ZRP_WCWatch_" .. id)
    end

    -- Clear world-container markers so non-ZRP rounds behave normally.
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        if ent.ZRP_WorldContainerIdx then
            ent.ZRP_WorldContainerIdx = nil
            ent.ZRP_WorldLootOverride = nil
            ent.ZRP_WorldLootGenerated = false
            if ZRP.ClearContainerInventory then
                ZRP.ClearContainerInventory(ent)
            end
        end
    end

    ZRP.WorldContainerState = {}
end

local function MarkWorldContainerLooted(idx, ent)
    local state = ZRP.WorldContainerState[idx]
    if not state or state.looted then return end

    local delay = (ZRP.WorldContainerData[idx] and ZRP.WorldContainerData[idx].respawnDelay)
        or DEFAULT_RESET_TIME

    state.looted = true
    state.resetAt = CurTime() + delay

    if IsValid(ent) then
        ent.ZRP_WorldLootGenerated = false
        if ZRP.ClearContainerInventory then
            ZRP.ClearContainerInventory(ent)
        end
    end

    timer.Remove("ZRP_WCReset_" .. idx)
    timer.Create("ZRP_WCReset_" .. idx, delay, 1, function()
        local resetState = ZRP.WorldContainerState[idx]
        if not resetState then return end

        resetState.looted = false
        resetState.resetAt = 0

        if IsValid(ent) then
            ent.ZRP_WorldLootGenerated = false
            if ZRP.ClearContainerInventory then
                ZRP.ClearContainerInventory(ent)
            end
        end
    end)
end

local function StartWorldContainerWatch(idx, ent)
    local timerName = "ZRP_WCWatch_" .. idx
    timer.Remove(timerName)
    timer.Create(timerName, WORLD_INVENTORY_CHECK_INTERVAL, 0, function()
        local state = ZRP.WorldContainerState[idx]
        if not state or state.looted or not IsValid(ent) then
            timer.Remove(timerName)
            return
        end

        if ZRP.IsInventoryEmpty(ent.inventory, ent.armors) then
            MarkWorldContainerLooted(idx, ent)
            timer.Remove(timerName)
        end
    end)
end

-- ── PlayerUse hook ────────────────────────────────────────────────────────────

local function IsWorldContainerModeActive()
    if not zb or zb.ROUND_STATE ~= 1 then return false end

    if zb.CROUND == "zrp" then
        return true
    end

    if zb.CROUND == "event" and isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) and round.name == "event" and round.LootEnabled then
            return true
        end
    end

    return false
end

hook.Add("PlayerUse", "ZRP_WorldContainerUse", function(ply, ent)
    if not IsWorldContainerModeActive() then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsValid(ent) or not ent.ZRP_WorldContainerIdx then return end

    local idx   = ent.ZRP_WorldContainerIdx
    local state = ZRP.WorldContainerState[idx]
    if not state then return false end

    if state.looted then
        ply:ChatPrint("[ZRP] This container is empty.  Check back later.")
        return false
    end

    if not ent.ZRP_WorldLootGenerated then
        ZRP.GenerateContainerInventory(ent, ent:GetModel(), ent.ZRP_WorldLootOverride)
        ent.ZRP_WorldLootGenerated = true
    end

    if ZRP.IsInventoryEmpty(ent.inventory, ent.armors) then
        ply:ChatPrint("[ZRP] Container is empty.")
        return false
    end

    ply:OpenInventory(ent)
    ent:EmitSound("items/ammocrate_open.wav")
    StartWorldContainerWatch(idx, ent)
    return false  -- suppress default Use so the prop doesn't do anything else
end)

-- ── Sync to admin ─────────────────────────────────────────────────────────────

local function GetAdoptedPositions()
    local out = {}
    for _, d in ipairs(ZRP.WorldContainerData) do out[#out + 1] = d.pos end
    return out
end

function ZRP.SyncWorldContainersToPlayer(ply)
    -- Build "scanned": map props matching hg.loot_boxes that are NOT yet adopted.
    local adoptedPos = GetAdoptedPositions()
    local scanned    = {}

    if hg and hg.loot_boxes then
        for _, ent in ipairs(ents.GetAll()) do
            if not IsValid(ent) then continue end
            local mdl = ent:GetModel()
            if not mdl or mdl == "" then continue end
            if not hg.loot_boxes[string.lower(mdl)] then continue end
            if ent:GetClass() == "zrp_container" then continue end  -- already a ZRP container entity

            -- Skip if already adopted (within snap radius of an existing world container).
            local already = false
            for _, ap in ipairs(adoptedPos) do
                if ent:GetPos():Distance(ap) < WORLD_SNAP_RADIUS then already = true; break end
            end
            if already then continue end

            scanned[#scanned + 1] = {
                entindex = ent:EntIndex(),
                model    = mdl,
                pos      = { ent:GetPos().x, ent:GetPos().y, ent:GetPos().z },
            }
        end
    end

    -- Build "adopted": persisted world containers with current runtime state.
    local adopted = {}
    for idx, data in ipairs(ZRP.WorldContainerData) do
        local state = ZRP.WorldContainerState[idx] or { looted = false, resetAt = 0, entindex = 0 }
        adopted[idx] = {
            idx          = idx,
            entindex     = state.entindex or 0,
            model        = data.model,
            pos          = { data.pos.x, data.pos.y, data.pos.z },
            respawnDelay = data.respawnDelay,
            looted       = state.looted,
            lootOverride = data.lootOverride or {},
        }
    end

    net.Start("ZRP_WorldPropSync")
    net.WriteTable({ scanned = scanned, adopted = adopted })
    net.Send(ply)
end

-- ── Staff commands ────────────────────────────────────────────────────────────

-- Adopt a world prop by entity index (toolgun RMB or editor panel).
concommand.Add("zrp_adopt_worldprop", function(ply, _, args, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local entidx = tonumber(args[1])
    if not entidx then ply:ChatPrint("[ZRP] Usage: zrp_adopt_worldprop <entindex>"); return end

    local ent = ents.GetByIndex(entidx)
    if not IsValid(ent) then ply:ChatPrint("[ZRP] Entity not found."); return end

    local mdl = ent:GetModel()
    if not mdl or mdl == "" then ply:ChatPrint("[ZRP] Entity has no model."); return end

    -- Prevent double-adoption.
    if ent.ZRP_WorldContainerIdx then
        ply:ChatPrint("[ZRP] This prop is already world container #" .. ent.ZRP_WorldContainerIdx)
        return
    end

    local idx = #ZRP.WorldContainerData + 1
    ZRP.WorldContainerData[idx] = {
        model        = string.lower(mdl),
        pos          = ent:GetPos(),
        respawnDelay = nil,
        lootOverride = {},
    }
    ZRP.SaveWorldContainers()

    -- Activate immediately (no need to wait for next RoundStart).
    ent.ZRP_WorldContainerIdx = idx
    ent.ZRP_WorldLootOverride = nil
    ent:SetUseType(SIMPLE_USE)
    ZRP.WorldContainerState[idx] = { entindex = ent:EntIndex(), looted = false, resetAt = 0 }

    if zb.CROUND == "zrp" and zb.ROUND_STATE == 1 then
        ZRP.ActivateWorldContainers()
    end
    ZRP.SyncWorldContainersToPlayer(ply)
    ply:ChatPrint("[ZRP] World container #" .. idx .. " adopted: " .. mdl)
end)

-- Remove an adopted world container.
concommand.Add("zrp_remove_worldprop", function(ply, _, args, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local idx = tonumber(args[1])
    if not idx or not ZRP.WorldContainerData[idx] then
        ply:ChatPrint("[ZRP] Invalid world container ID.")
        return
    end

    -- Deactivate the live entity if present.
    local state = ZRP.WorldContainerState[idx]
    if state and (state.entindex or 0) ~= 0 then
        local ent = ents.GetByIndex(state.entindex)
        if IsValid(ent) then
            ent.ZRP_WorldContainerIdx = nil
            ent.ZRP_WorldLootOverride = nil
        end
    end

    timer.Remove("ZRP_WCReset_" .. idx)
    table.remove(ZRP.WorldContainerData, idx)

    -- Re-index runtime states after removal.
    local newState = {}
    for k, v in pairs(ZRP.WorldContainerState) do
        if     k > idx then newState[k - 1] = v
        elseif k ~= idx then newState[k]     = v end
    end
    ZRP.WorldContainerState = newState

    ZRP.SaveWorldContainers()
    if zb.CROUND == "zrp" and zb.ROUND_STATE == 1 then
        ZRP.ActivateWorldContainers()
    end
    ZRP.SyncWorldContainersToPlayer(ply)
    ply:ChatPrint("[ZRP] World container #" .. idx .. " removed.")
end)

-- Set reset delay for an adopted world container.
concommand.Add("zrp_worldprop_setdelay", function(ply, _, args, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local idx   = tonumber(args[1])
    local delay = tonumber(args[2])
    if not idx or not ZRP.WorldContainerData[idx] or not delay then
        ply:ChatPrint("[ZRP] Usage: zrp_worldprop_setdelay <id> <seconds>")
        return
    end
    ZRP.WorldContainerData[idx].respawnDelay = math.max(1, delay)
    ZRP.SaveWorldContainers()
    ZRP.SyncWorldContainersToPlayer(ply)
    ply:ChatPrint("[ZRP] World container #" .. idx .. " delay set to " .. delay .. "s.")
end)
