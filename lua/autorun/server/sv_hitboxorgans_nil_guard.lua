-- sv_hitboxorgans_nil_guard.lua
-- Guards hg.organism.ShootMatrix against rare nil bone/matrix states.

if CLIENT then return end

local function TryPatchShootMatrix()
    if not (hg and hg.organism and hg.organism.ShootMatrix) then return false end
    if hg.organism._DCPatched_ShootMatrixSafe then return true end

    local originalShootMatrix = hg.organism.ShootMatrix

    hg.organism.ShootMatrix = function(ent, organs)
        if not IsValid(ent) then return nil end

        local ok, a, b, c = pcall(originalShootMatrix, ent, organs)
        if ok then
            return a, b, c
        end

        -- If model hitbox/bone data is temporarily invalid, skip this tick safely.
        return nil
    end

    hg.organism._DCPatched_ShootMatrixSafe = true
    print("[DCityPatch] ShootMatrix nil-bone guard loaded.")
    return true
end

if not TryPatchShootMatrix() then
    hook.Add("InitPostEntity", "DCityPatch_ShootMatrixPatch", function()
        if TryPatchShootMatrix() then
            hook.Remove("InitPostEntity", "DCityPatch_ShootMatrixPatch")
        end
    end)

    timer.Create("DCityPatch_ShootMatrixPatchRetry", 1, 20, function()
        if TryPatchShootMatrix() then
            timer.Remove("DCityPatch_ShootMatrixPatchRetry")
        end
    end)
end
