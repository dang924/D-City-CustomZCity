if SERVER then return end

-- Prevent client camera/view code from crashing when player.organism is briefly nil.
-- Some Homigrad camera paths assume organism exists and index fields directly.

local function EnsureOrganismTable(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    if ply.organism == nil then
        ply.organism = {
            pain = 0,
            holdingbreath = false,
            adrenaline = 0,
            immobilization = 0,
            otrub = false,
            canmove = true,
        }
        return
    end

    if type(ply.organism) ~= "table" then
        ply.organism = {
            pain = 0,
            holdingbreath = false,
            adrenaline = 0,
            immobilization = 0,
            otrub = false,
            canmove = true,
        }
        return
    end

    -- Backfill common fields used in camera/HUD math paths.
    if ply.organism.pain == nil then ply.organism.pain = 0 end
    if ply.organism.holdingbreath == nil then ply.organism.holdingbreath = false end
    if ply.organism.adrenaline == nil then ply.organism.adrenaline = 0 end
    if ply.organism.immobilization == nil then ply.organism.immobilization = 0 end
    if ply.organism.otrub == nil then ply.organism.otrub = false end
    if ply.organism.canmove == nil then ply.organism.canmove = true end
end

hook.Add("Think", "DCityPatch_OrganismNilGuard", function()
    local lply = LocalPlayer()
    if not IsValid(lply) then return end

    EnsureOrganismTable(lply)
end)

hook.Add("NetworkEntityCreated", "DCityPatch_OrganismNilGuard", function(ent)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    EnsureOrganismTable(ent)
end)

print("[DCityPatch] organism nil guard loaded")
