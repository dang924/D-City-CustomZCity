-- sv_coast04_ent_fixes.lua
-- Runtime entity patches for d2_coast_04 variants.
-- Applied on InitPostEntity; no VMF edits required.

if not SERVER then return end

local function isCoast04()
    return game.GetMap():find("coast_04") ~= nil
end

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function removeInRadius(pos, radius, classPredicate, label)
    local removed = 0
    for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
        if IsValid(ent) and classPredicate(ent:GetClass()) then
            ent:Remove()
            removed = removed + 1
        end
    end
    if removed > 0 then
        print("[Coast04Fix] Removed " .. removed .. " entity/entities near " .. label)
    else
        print("[Coast04Fix] WARNING: found 0 matching entities near " .. label)
    end
end

-- ─────────────────────────────────────────────
-- Fix 1 – Blackscreen / death trigger groups
-- Remove entities whose origin is within 64 units of the exact known positions.
-- No class filter — we own these positions; nothing else should be here.
-- ─────────────────────────────────────────────
local TRIGGER_KILL_POSITIONS = {
    { pos = Vector(0, 5888, 688), label = "trigger_group_A (0,5888,688)" },
    { pos = Vector(0, 6784, 704), label = "trigger_group_B (0,6784,704)" },
}

local function fixTriggers()
    for _, entry in ipairs(TRIGGER_KILL_POSITIONS) do
        local removed = 0
        for _, ent in ipairs(ents.FindInSphere(entry.pos, 64)) do
            if IsValid(ent) then
                ent:Remove()
                removed = removed + 1
            end
        end
        if removed > 0 then
            print("[Coast04Fix] Removed " .. removed .. " entity/entities near " .. entry.label)
        else
            print("[Coast04Fix] WARNING: found 0 entities near " .. entry.label)
        end
    end
end

-- ─────────────────────────────────────────────
-- Fix 2 – Crane ladder (causes server crash)
-- ─────────────────────────────────────────────
local LADDER_POS = Vector(4488, -1728, 500)

local function fixCraneLadder()
    removeInRadius(LADDER_POS, 128, function(cls)
        return cls == "func_useableladder" or cls == "func_ladder"
    end, "func_useableladder (4488,-1728,500)")
end

-- ─────────────────────────────────────────────
-- Fix 3 – Lock the vehicle crane on spawn
-- ─────────────────────────────────────────────
local CRANE_POS   = Vector(4385, -1485, 1370)
local CRANE_RADIUS = 300

local function fixCraneLock()
    local found = false
    for _, ent in ipairs(ents.FindInSphere(CRANE_POS, CRANE_RADIUS)) do
        if IsValid(ent) and ent:GetClass() == "prop_vehicle_crane" then
            ent:Fire("Lock", "", 0)
            found = true
            print("[Coast04Fix] Locked prop_vehicle_crane at " .. tostring(ent:GetPos()))
        end
    end
    if not found then
        print("[Coast04Fix] WARNING: prop_vehicle_crane not found near " .. tostring(CRANE_POS))
    end
end

-- ─────────────────────────────────────────────
-- Fix 4 – Remove problematic func_physbox at crane bridge
-- Replacement bridge is a permaprop placed manually in-game.
-- ─────────────────────────────────────────────
local PHYSBOX_POS = Vector(5024, -2688, 542)

local function fixPhysbox()
    removeInRadius(PHYSBOX_POS, 128, function(cls)
        return cls == "func_physbox" or cls == "func_physbox_multiplayer"
    end, "func_physbox (5024,-2688,542)")
end

-- ─────────────────────────────────────────────
-- Entry point
-- ─────────────────────────────────────────────
hook.Add("InitPostEntity", "DCityPatch_Coast04EntFixes", function()
    if not isCoast04() then return end

    -- Slight delay to ensure all entities are fully spawned and activated
    timer.Simple(0.5, function()
        fixTriggers()
        fixCraneLadder()
        fixCraneLock()
        fixPhysbox()
        print("[Coast04Fix] All coast_04 entity fixes applied.")
    end)
end)
