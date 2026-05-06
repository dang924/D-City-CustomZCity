-- ZScav admin config: live-edit catalog grid sizes, item meta, gear meta.
--
-- Admin-gated via ply:IsAdmin() (or ply:IsSuperAdmin() depending on host).
-- Persists to data/zscav_catalog.json and reapplies on boot.

util.AddNetworkString("ZScavCfgOpen")
util.AddNetworkString("ZScavCfgApply")
util.AddNetworkString("ZScavCfgFocus")
util.AddNetworkString("ZScavDisplaySync") -- broadcast pack display tuning to all clients
util.AddNetworkString("ZScavBaseGridsSync") -- broadcast updated BaseGrids to all clients
util.AddNetworkString("ZScavGearItemsSync") -- broadcast layout blocks and compartment changes to all clients

local CFG_FILE = "zscav_catalog.json"
local InferInternalFromLayout
local BuildNormalizedItemMetaSnapshot

local function IsAuthorized(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    if ply:IsAdmin() then return true end
    return false
end

-- ----------------------------------------------------------------------
-- Snapshot / apply / persist
-- ----------------------------------------------------------------------
local function Snapshot()
    -- No auto-seeding defaults: snapshot should reflect only explicit
    -- configured values so data/zscav_catalog.json remains source-of-truth.
    local itemSnap = BuildNormalizedItemMetaSnapshot(ZSCAV.ItemMeta or {})
    local gearSnap = table.Copy(ZSCAV.GearItems or {})
    for _, def in pairs(gearSnap) do
        if istable(def) then
            local out = {}
            if istable(def.compartments) then
                for _, c in ipairs(def.compartments) do
                    if istable(c) and isstring(c.name) and c.name ~= "" then
                        local cw = math.max(0, math.floor((tonumber(c.w) or 0) + 0.5))
                        local ch = math.max(0, math.floor((tonumber(c.h) or 0) + 0.5))
                        out[#out + 1] = {
                            name = c.name,
                            w = math.min(cw, 32),
                            h = math.min(ch, 32),
                        }
                    end
                end
            end
            if #out == 0 and istable(def.grants) then
                local keys = {}
                for gname in pairs(def.grants) do keys[#keys + 1] = gname end
                table.sort(keys)
                for _, gname in ipairs(keys) do
                    local g = def.grants[gname]
                    if isstring(gname) and istable(g) then
                        local gw = math.max(0, math.floor((tonumber(g.w) or 0) + 0.5))
                        local gh = math.max(0, math.floor((tonumber(g.h) or 0) + 0.5))
                        out[#out + 1] = {
                            name = gname,
                            w = math.min(gw, 32),
                            h = math.min(gh, 32),
                        }
                    end
                end
            end
            def.compartments = out
            if istable(def.layoutBlocks) then
                local clean = {}
                local inferred = InferInternalFromLayout(def.layoutBlocks, def.internal)
                local gw = inferred.w
                local gh = inferred.h
                for _, b in ipairs(def.layoutBlocks) do
                    if istable(b) then
                        local bw = math.max(1, math.floor((tonumber(b.w) or 0) + 0.5))
                        local bh = math.max(1, math.floor((tonumber(b.h) or 0) + 0.5))
                        local bx = math.max(0, math.floor((tonumber(b.x) or 0) + 0.5))
                        local by = math.max(0, math.floor((tonumber(b.y) or 0) + 0.5))
                        bw = math.min(bw, 8)
                        bh = math.min(bh, 8)
                        bx = math.min(bx, gw - 1)
                        by = math.min(by, gh - 1)
                        if bx + bw <= gw and by + bh <= gh then
                            clean[#clean + 1] = { x = bx, y = by, w = bw, h = bh }
                        end
                    end
                end
                def.layoutBlocks = clean
            else
                def.layoutBlocks = nil
            end
        end
    end

    return {
        BaseGrids      = table.Copy(ZSCAV.BaseGrids or {}),
        ItemMeta       = itemSnap,
        GearItems      = gearSnap,
        MaxCarryWeight = ZSCAV.MaxCarryWeight or 35,
    }
end

local function clampInt(n, lo, hi)
    n = tonumber(n) or 0
    n = math.floor(n + 0.5)
    if n < lo then n = lo end
    if n > hi then n = hi end
    return n
end

local function clampNum(n, lo, hi)
    n = tonumber(n) or 0
    if n < lo then n = lo end
    if n > hi then n = hi end
    return n
end

local function NormalizeItemMetaClass(class)
    class = tostring(class or ""):lower()
    if class == "" then return "" end

    if ZSCAV.GetCanonicalItemClass then
        local canonical = tostring(ZSCAV:GetCanonicalItemClass(class) or ""):lower()
        if canonical ~= "" then
            return canonical
        end
    elseif ZSCAV.GetWeaponBaseClass then
        local canonical = tostring(ZSCAV:GetWeaponBaseClass(class) or ""):lower()
        if canonical ~= "" then
            return canonical
        end
    end

    return class
end

local NormalizeItemMetaSlot

local function SanitizeItemMetaVariants(variants)
    local out = {}
    if not istable(variants) then return out end

    for key, variant in pairs(variants) do
        key = tostring(key or ""):lower()
        if key ~= "" and istable(variant) then
            local clean = {}
            if variant.w ~= nil then clean.w = clampInt(variant.w, 1, 16) end
            if variant.h ~= nil then clean.h = clampInt(variant.h, 1, 16) end
            if variant.dw ~= nil then clean.dw = clampInt(variant.dw, -16, 16) end
            if variant.dh ~= nil then clean.dh = clampInt(variant.dh, -16, 16) end
            if variant.weight ~= nil then clean.weight = clampNum(variant.weight, 0, 100) end
            if variant.slot ~= nil and isstring(variant.slot) and variant.slot ~= "" then
                local slot = NormalizeItemMetaSlot and NormalizeItemMetaSlot(variant.slot) or tostring(variant.slot):lower()
                if slot ~= "" then clean.slot = slot end
            end
            if next(clean) ~= nil then
                out[key] = clean
            end
        end
    end

    return out
end

NormalizeItemMetaSlot = function(slot)
    slot = tostring(slot or "")
    if slot == "" then return "" end
    if ZSCAV.NormalizeWeaponRegistrationSlot then
        return tostring(ZSCAV:NormalizeWeaponRegistrationSlot(slot) or "")
    end
    return slot:lower()
end

local function SanitizeItemMetaDef(def)
    local out = {}
    if not istable(def) then return out end

    if def.w ~= nil then out.w = clampInt(def.w, 1, 16) end
    if def.h ~= nil then out.h = clampInt(def.h, 1, 16) end
    if def.weight ~= nil then out.weight = clampNum(def.weight, 0, 100) end
    if def.slot ~= nil and isstring(def.slot) and def.slot ~= "" then
        local slot = NormalizeItemMetaSlot(def.slot)
        if slot ~= "" then out.slot = slot end
    end

    local variants = SanitizeItemMetaVariants(def.size_variants)
    if next(variants) ~= nil then
        out.size_variants = variants
    end

    return out
end

local function ChooseNormalizedItemMetaBase(variants)
    local bestClass = nil
    local bestDef = nil

    for class, def in pairs(variants or {}) do
        if istable(def) then
            if not bestDef then
                bestClass = class
                bestDef = def
            else
                local curW = tonumber(def.w) or math.huge
                local curH = tonumber(def.h) or math.huge
                local bestW = tonumber(bestDef.w) or math.huge
                local bestH = tonumber(bestDef.h) or math.huge
                local curArea = curW * curH
                local bestArea = bestW * bestH

                if curArea < bestArea
                    or (curArea == bestArea and curW < bestW)
                    or (curArea == bestArea and curW == bestW and curH < bestH)
                    or (curArea == bestArea and curW == bestW and curH == bestH and class < bestClass) then
                    bestClass = class
                    bestDef = def
                end
            end
        end
    end

    return bestDef and table.Copy(bestDef) or nil
end

local function BuildItemMetaVariantModifier(base, variant)
    if not istable(variant) then return nil end

    local out = {}
    local baseW = tonumber(base and base.w)
    local baseH = tonumber(base and base.h)
    local variantW = tonumber(variant.w)
    local variantH = tonumber(variant.h)

    if variantW ~= nil then
        if baseW ~= nil then
            local dw = clampInt(variantW - baseW, -16, 16)
            if dw ~= 0 then out.dw = dw end
        else
            out.w = clampInt(variantW, 1, 16)
        end
    end

    if variantH ~= nil then
        if baseH ~= nil then
            local dh = clampInt(variantH - baseH, -16, 16)
            if dh ~= 0 then out.dh = dh end
        else
            out.h = clampInt(variantH, 1, 16)
        end
    end

    local baseWeight = tonumber(base and base.weight)
    local variantWeight = tonumber(variant.weight)
    if variantWeight ~= nil and variantWeight ~= baseWeight then
        out.weight = clampNum(variantWeight, 0, 100)
    end

    local baseSlot = NormalizeItemMetaSlot(base and base.slot or "")
    local variantSlot = NormalizeItemMetaSlot(variant.slot or "")
    if variantSlot ~= "" and variantSlot ~= baseSlot then
        out.slot = variantSlot
    end

    return next(out) ~= nil and out or nil
end

BuildNormalizedItemMetaSnapshot = function(source)
    local grouped = {}
    if not istable(source) then return grouped end

    for class, def in pairs(source) do
        if isstring(class) and istable(def) then
            local rawClass = tostring(class):lower()
            local canonicalClass = NormalizeItemMetaClass(rawClass)
            if canonicalClass ~= "" then
                local group = grouped[canonicalClass]
                if not group then
                    group = {
                        base = nil,
                        variants = {},
                    }
                    grouped[canonicalClass] = group
                    end

                local clean = SanitizeItemMetaDef(def)
                if rawClass == canonicalClass then
                    group.base = clean
                else
                    group.variants[rawClass] = clean
                end
            end
        end
    end

    local out = {}
    for canonicalClass, group in pairs(grouped) do
        local base = group.base or ChooseNormalizedItemMetaBase(group.variants) or {}
        local merged = table.Copy(base)
        merged.size_variants = SanitizeItemMetaVariants(merged.size_variants)
        if next(merged.size_variants or {}) == nil then
            merged.size_variants = nil
        end

        for variantClass, variantDef in pairs(group.variants or {}) do
            local modifier = BuildItemMetaVariantModifier(base, variantDef)
            if modifier then
                merged.size_variants = merged.size_variants or {}
                merged.size_variants[variantClass] = modifier
            end
        end

        out[canonicalClass] = merged
    end

    return out
end

local function NormalizeLiveItemMetaTable()
    ZSCAV.ItemMeta = BuildNormalizedItemMetaSnapshot(ZSCAV.ItemMeta or {})
end

local function BuildCompartmentList(def)
    local out = {}
    if not istable(def) then return out end

    if istable(def.compartments) then
        for _, c in ipairs(def.compartments) do
            if istable(c) and isstring(c.name) and c.name ~= "" then
                out[#out + 1] = {
                    name = c.name,
                    w = clampInt(c.w, 0, 32),
                    h = clampInt(c.h, 0, 32),
                }
            end
        end
        if #out > 0 then return out end
    end

    if istable(def.grants) then
        local keys = {}
        for gname in pairs(def.grants) do keys[#keys + 1] = gname end
        table.sort(keys)
        for _, gname in ipairs(keys) do
            local g = def.grants[gname]
            if isstring(gname) and istable(g) then
                out[#out + 1] = {
                    name = gname,
                    w = clampInt(g.w, 0, 32),
                    h = clampInt(g.h, 0, 32),
                }
            end
        end
    end
    return out
end

InferInternalFromLayout = function(layoutBlocks, internal)
    local out = {
        w = clampInt((internal or {}).w, 1, 32),
        h = clampInt((internal or {}).h, 1, 32),
    }
    if not istable(layoutBlocks) or #layoutBlocks == 0 then
        return out
    end

    local maxW, maxH = 1, 1
    for _, b in ipairs(layoutBlocks) do
        if istable(b) then
            local bx = clampInt(b.x, 0, 31)
            local by = clampInt(b.y, 0, 31)
            local bw = clampInt(b.w, 1, 8)
            local bh = clampInt(b.h, 1, 8)
            maxW = math.max(maxW, bx + bw)
            maxH = math.max(maxH, by + bh)
        end
    end

    if not istable(internal) or internal.w == nil or tonumber(internal.w) <= 0 then
        out.w = clampInt(maxW, 1, 32)
    end
    if not istable(internal) or internal.h == nil or tonumber(internal.h) <= 0 then
        out.h = clampInt(maxH, 1, 32)
    end
    return out
end

local function SanitizeLayoutBlocks(layoutBlocks, internal)
    local out = {}
    if not istable(layoutBlocks) then return out end

    local gw = clampInt((internal or {}).w, 1, 32)
    local gh = clampInt((internal or {}).h, 1, 32)
    for _, b in ipairs(layoutBlocks) do
        if istable(b) then
            local bw = clampInt(b.w, 1, 8)
            local bh = clampInt(b.h, 1, 8)
            local bx = clampInt(b.x, 0, gw - 1)
            local by = clampInt(b.y, 0, gh - 1)
            if bx + bw <= gw and by + bh <= gh then
                out[#out + 1] = { x = bx, y = by, w = bw, h = bh }
            end
        end
    end

    return out
end

local function ApplyOverrides(data)
    if not istable(data) then return end

    if istable(data.BaseGrids) then
        for k, v in pairs(data.BaseGrids) do
            if ZSCAV.BaseGrids[k] and istable(v) then
                ZSCAV.BaseGrids[k].w = clampInt(v.w, 0, 32)
                ZSCAV.BaseGrids[k].h = clampInt(v.h, 0, 32)
            end
        end
    end

    if data.MaxCarryWeight ~= nil then
        ZSCAV.MaxCarryWeight = clampNum(data.MaxCarryWeight, 1, 500)
    end

    if istable(data.ItemMeta) then
        for class, v in pairs(data.ItemMeta) do
            if isstring(class) and istable(v) then
                local rawClass = tostring(class):lower()
                local cur = ZSCAV.ItemMeta[rawClass] or {}
                if v.w      ~= nil then cur.w      = clampInt(v.w, 1, 16) end
                if v.h      ~= nil then cur.h      = clampInt(v.h, 1, 16) end
                if v.weight ~= nil then cur.weight = clampNum(v.weight, 0, 100) end
                if v.slot   ~= nil and isstring(v.slot) and v.slot ~= "" then
                    local slot = NormalizeItemMetaSlot(v.slot)
                    if slot ~= "" then cur.slot = slot end
                end
                local variants = SanitizeItemMetaVariants(v.size_variants)
                if next(variants) ~= nil then
                    cur.size_variants = variants
                end
                ZSCAV.ItemMeta[rawClass] = cur
            end
        end
    end

    if istable(data.GearItems) then
        for class, v in pairs(data.GearItems) do
            if isstring(class) and istable(v) then
                local cur = ZSCAV.GearItems[class]
                -- Create missing entry so saved overrides for dynamically-added
                -- gear classes (armor entities, custom vests) survive restarts.
                if not istable(cur) then
                    local def = ZSCAV:GetGearDef(class)
                    if def then
                        cur = {}
                        if isstring(def.name)  then cur.name  = def.name  end
                        if isstring(def.slot)  then cur.slot  = def.slot  end
                        if def.compartment     then cur.compartment = true end
                        ZSCAV.GearItems[class] = cur
                    end
                end
                if cur then
                    if v.w      ~= nil then cur.w      = clampInt(v.w, 1, 16) end
                    if v.h      ~= nil then cur.h      = clampInt(v.h, 1, 16) end
                    if v.weight ~= nil then cur.weight = clampNum(v.weight, 0, 100) end
                    if v.compartment ~= nil then cur.compartment = tobool(v.compartment) end

                    if istable(v.compartments) then
                        cur.compartments = {}
                        cur.grants = {}
                        for _, c in ipairs(v.compartments) do
                            if istable(c) and isstring(c.name) and ZSCAV.BaseGrids[c.name] then
                                local cw = clampInt(c.w, 0, 32)
                                local ch = clampInt(c.h, 0, 32)
                                cur.compartments[#cur.compartments + 1] = {
                                    name = c.name,
                                    w = cw,
                                    h = ch,
                                }
                                cur.grants[c.name] = { w = cw, h = ch }
                            end
                        end
                        if #cur.compartments == 0 then
                            cur.compartments = nil
                            cur.grants = nil
                        end
                    end

                    -- Allow tuning per-grid grants for gear that grants
                    -- inventory space (chest rigs, plate carriers, packs).
                    if not istable(v.compartments) and istable(v.grants) then
                        cur.grants = cur.grants or {}
                        for gname, g in pairs(v.grants) do
                            if isstring(gname) and istable(g) and ZSCAV.BaseGrids[gname] then
                                cur.grants[gname] = cur.grants[gname] or { w = 0, h = 0 }
                                if g.w ~= nil then cur.grants[gname].w = clampInt(g.w, 0, 16) end
                                if g.h ~= nil then cur.grants[gname].h = clampInt(g.h, 0, 16) end
                            end
                        end
                        cur.compartments = BuildCompartmentList(cur)
                    end
                    -- Internal grid (container size when bag is on ground / nested).
                    if istable(v.internal) then
                        cur.internal = cur.internal or { w = 4, h = 4 }
                        if v.internal.w ~= nil then cur.internal.w = clampInt(v.internal.w, 1, 32) end
                        if v.internal.h ~= nil then cur.internal.h = clampInt(v.internal.h, 1, 32) end
                    end
                    if istable(v.layoutBlocks) then
                        cur.internal = InferInternalFromLayout(v.layoutBlocks, cur.internal)
                        local clean = SanitizeLayoutBlocks(v.layoutBlocks, cur.internal)
                        cur.layoutBlocks = (#clean > 0) and clean or nil
                        if cur.layoutBlocks then
                            cur.compartment = true
                        end
                    end
                    -- On-body display (bonemerge offsets).
                    if istable(v.display) then
                        cur.display = cur.display or {}
                        if isstring(v.display.bone) then cur.display.bone = v.display.bone end
                        if istable(v.display.pos) then
                            cur.display.pos = cur.display.pos or { x = 0, y = 0, z = 0 }
                            if v.display.pos.x ~= nil then cur.display.pos.x = clampNum(v.display.pos.x, -64, 64) end
                            if v.display.pos.y ~= nil then cur.display.pos.y = clampNum(v.display.pos.y, -64, 64) end
                            if v.display.pos.z ~= nil then cur.display.pos.z = clampNum(v.display.pos.z, -64, 64) end
                        end
                        if istable(v.display.ang) then
                            cur.display.ang = cur.display.ang or { p = 0, y = 0, r = 0 }
                            if v.display.ang.p ~= nil then cur.display.ang.p = clampNum(v.display.ang.p, -180, 180) end
                            if v.display.ang.y ~= nil then cur.display.ang.y = clampNum(v.display.ang.y, -180, 180) end
                            if v.display.ang.r ~= nil then cur.display.ang.r = clampNum(v.display.ang.r, -180, 180) end
                        end
                        if v.display.scale ~= nil then cur.display.scale = clampNum(v.display.scale, 0.1, 5) end
                    end
                end
            end
        end
    end

    NormalizeLiveItemMetaTable()
end

-- Broadcast updated BaseGrids to all clients after an admin apply.
local function BroadcastBaseGridsSync()
    local raw = util.TableToJSON(ZSCAV.BaseGrids or {}) or "{}"
    net.Start("ZScavBaseGridsSync")
        net.WriteUInt(#raw, 32)
        net.WriteData(raw, #raw)
    net.Broadcast()
end

-- Broadcast every pack class's current display to all clients so the
-- bonemerged on-body model updates live without restarting the round.
local function BroadcastDisplaySync()
    local payload = {}
    if ZSCAV.GetPackClasses then
        for _, class in ipairs(ZSCAV:GetPackClasses()) do
            local def = ZSCAV.GearItems[class]
            if def and def.display then payload[class] = def.display end
        end
    else
        for class, def in pairs(ZSCAV.GearItems or {}) do
            if def.slot == "backpack" and def.display then payload[class] = def.display end
        end
    end
    local raw = util.TableToJSON(payload) or "{}"
    net.Start("ZScavDisplaySync")
        net.WriteUInt(#raw, 32)
        net.WriteData(raw, #raw)
    net.Broadcast()
end

-- Broadcast updated GearItems (layout blocks, internal sizes, compartments) to all clients.
local function BroadcastGearItemsSync()
    local payload = table.Copy(ZSCAV.GearItems or {})
    -- Keep only layout/compartment data, strip anything else not needed for runtime.
    for class, def in pairs(payload) do
        if istable(def) then
            local cleaned = {
                layoutBlocks = def.layoutBlocks,
                internal = def.internal,
                compartment = def.compartment,
                compartments = def.compartments,
            }
            payload[class] = cleaned
        end
    end
    local raw = util.TableToJSON(payload) or "{}"
    net.Start("ZScavGearItemsSync")
        net.WriteUInt(#raw, 32)
        net.WriteData(raw, #raw)
    net.Broadcast()
end

hook.Add("PlayerInitialSpawn", "ZSCAV_DisplaySyncJoin", function(ply)
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        local payload = {}
        for class, def in pairs(ZSCAV.GearItems or {}) do
            if def.slot == "backpack" and def.display then payload[class] = def.display end
        end
        local raw = util.TableToJSON(payload) or "{}"
        net.Start("ZScavDisplaySync")
            net.WriteUInt(#raw, 32)
            net.WriteData(raw, #raw)
        net.Send(ply)
            -- Also sync current BaseGrids so the client's shared table is up to date.
            local bgRaw = util.TableToJSON(ZSCAV.BaseGrids or {}) or "{}"
            net.Start("ZScavBaseGridsSync")
                net.WriteUInt(#bgRaw, 32)
                net.WriteData(bgRaw, #bgRaw)
            net.Send(ply)
    end)
end)

local function Persist()
    file.Write(CFG_FILE, util.TableToJSON(Snapshot(), true))
end

local function RebuildConfiguredSets(data)
    ZSCAV.ConfiguredItemMetaClasses = {}
    ZSCAV.ConfiguredGearClasses = {}

    local itemMeta = BuildNormalizedItemMetaSnapshot((istable(data) and data.ItemMeta) or (ZSCAV and ZSCAV.ItemMeta) or {})
    for class, v in pairs(itemMeta) do
        if isstring(class) and istable(v) then
            ZSCAV.ConfiguredItemMetaClasses[tostring(class):lower()] = true
        end
    end

    if istable(data) and istable(data.GearItems) then
        for class, v in pairs(data.GearItems) do
            if isstring(class) and istable(v) then
                ZSCAV.ConfiguredGearClasses[NormalizeItemMetaClass(class)] = true
            end
        end
    else
        for class, v in pairs(ZSCAV.GearItems or {}) do
            if isstring(class) and istable(v) then
                ZSCAV.ConfiguredGearClasses[NormalizeItemMetaClass(class)] = true
            end
        end
    end
end

local function LoadPersisted()
    local raw = file.Read(CFG_FILE, "DATA")
    if not raw or raw == "" then
        RebuildConfiguredSets({ ItemMeta = {}, GearItems = {} })
        return
    end
    local data = util.JSONToTable(raw)
    if istable(data) then
        ApplyOverrides(data)
        RebuildConfiguredSets(data)
    else
        RebuildConfiguredSets({ ItemMeta = {}, GearItems = {} })
    end
end

-- Apply persisted overrides after the catalog has loaded.
hook.Add("Initialize", "ZSCAV_LoadCatalogOverrides", function()
    if ZSCAV and ZSCAV.BaseGrids then LoadPersisted() end
end)

-- Re-apply saved overrides at every round start so catalog resets (on map
-- change the loader re-runs sh_zscav_catalog.lua, resetting GearItems to
-- hardcoded defaults while Initialize does NOT re-fire).
hook.Add("ZB_PreRoundStart", "ZSCAV_ReloadCatalogOverrides", function()
    if ZSCAV and ZSCAV.BaseGrids then LoadPersisted() end
end)

-- ----------------------------------------------------------------------
-- Network: open + apply
-- ----------------------------------------------------------------------
local function SendSnapshot(ply)
    local payload = util.TableToJSON(Snapshot())
    net.Start("ZScavCfgOpen")
        net.WriteUInt(#payload, 32)
        net.WriteData(payload, #payload)
    net.Send(ply)
end

local function EnsureConfigEntryForClass(class)
    class = tostring(class or ""):lower()
    if class == "" then return nil, false end

    if ZSCAV:IsArmorEntityClass(class) or ZSCAV:IsGearItem(class) then
        local created = false
        local cur = ZSCAV.GearItems[class]
        if not istable(cur) then
            cur = {}
            local def = ZSCAV:GetGearDef(class)
            if def then
                if isstring(def.name) and def.name ~= "" then cur.name = def.name end
                if isstring(def.slot) and def.slot ~= "" then cur.slot = def.slot end
                if def.compartment then cur.compartment = true end
            end
            ZSCAV.GearItems[class] = cur
            created = true
        end
        return "gear", created
    end

    local created = false
    if not istable(ZSCAV.ItemMeta[class]) then
        ZSCAV.ItemMeta[class] = {}
        created = true
    end
    return "item", created
end

function ZSCAV:OpenConfigForClass(ply, class)
    if not IsAuthorized(ply) then return end
    local tab, created = EnsureConfigEntryForClass(class)
    class = tostring(class or ""):lower()

    net.Start("ZScavCfgFocus")
        net.WriteString(class)
        net.WriteString(tab or "")
    net.Send(ply)

    SendSnapshot(ply)
    if created then Persist() end
end

concommand.Add("zscav_config", function(ply)
    if not IsAuthorized(ply) then
        if IsValid(ply) then ply:ChatPrint("[ZScav] Admin only.") end
        return
    end
    SendSnapshot(ply)
end)

net.Receive("ZScavCfgApply", function(_len, ply)
    if not IsAuthorized(ply) then return end
    local sz = net.ReadUInt(32)
    if sz <= 0 or sz > 200000 then return end
    local raw = net.ReadData(sz)
    local data = util.JSONToTable(raw or "")
    if not istable(data) then return end
    ApplyOverrides(data)
    RebuildConfiguredSets(data)
    Persist()
    BroadcastDisplaySync()
    BroadcastBaseGridsSync()
    BroadcastGearItemsSync()
    ply:ChatPrint("[ZScav] Catalog updated.")
end)
