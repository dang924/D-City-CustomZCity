if CLIENT then return end

-- Prevent transient trigger_hurt contacts (common around optimization/vis borders)
-- from instantly dissolving or killing players.

local GRACE_SECONDS = 0.75
local STALE_SECONDS = 1.5

local touchState = {}

local function getPlayerFromTarget(target)
    if not IsValid(target) then return nil end

    if target:IsPlayer() then
        return target
    end

    if target.IsRagdoll and target:IsRagdoll() and hg and hg.RagdollOwner then
        local owner = hg.RagdollOwner(target)
        if IsValid(owner) and owner:IsPlayer() then
            return owner
        end
    end

    return nil
end

local function keyFor(ply, inflictor)
    return tostring(ply:EntIndex()) .. ":" .. tostring(inflictor:EntIndex())
end

hook.Add("EntityTakeDamage", "ZC_TriggerHurtSafety", function(target, dmgInfo)
    local inflictor = dmgInfo:GetInflictor()
    if not IsValid(inflictor) then return end
    if inflictor:GetClass() ~= "trigger_hurt" then return end

    local ply = getPlayerFromTarget(target)
    if not IsValid(ply) then return end

    -- Do not let trigger_hurt instantly shred seated players during brush streaming edges.
    if ply:InVehicle() then
        dmgInfo:SetDamage(0)
        return true
    end

    local now = CurTime()
    local key = keyFor(ply, inflictor)
    local state = touchState[key]

    if not state or (now - (state.lastSeen or 0)) > STALE_SECONDS then
        state = {
            startedAt = now,
            lastSeen = now,
        }
        touchState[key] = state
    else
        state.lastSeen = now
    end

    local elapsed = now - state.startedAt
    if elapsed < GRACE_SECONDS then
        -- Block the initial spike window (including DMG_DISSOLVE) from transient overlaps.
        dmgInfo:SetDamage(0)
        return true
    end
end)

hook.Add("Think", "ZC_TriggerHurtSafety_Cleanup", function()
    local now = CurTime()

    for key, state in pairs(touchState) do
        if not state or (now - (state.lastSeen or 0)) > STALE_SECONDS then
            touchState[key] = nil
        end
    end
end)
