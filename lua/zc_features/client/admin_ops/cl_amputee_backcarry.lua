local SCAN_RANGE = 130
local HOLD_TIME = 0.35
local FADE_SPEED = 8
local COL_KEY = Color(255, 220, 80)
local COL_TEXT = Color(255, 255, 255)
local COL_NAME = Color(180, 230, 255)

local alpha = 0
local targetName = ""
local progress = 0

local function IsZScavBackCarryDisabled()
    return ZSCAV and ZSCAV.IsActive and ZSCAV:IsActive()
end

local function CanBackCarryNow(ply)
    if IsZScavBackCarryDisabled() then return false end
    if not IsValid(ply) or not ply:Alive() then return false end
    if ply:InVehicle() then return false end
    if IsValid(ply.FakeRagdoll) then return false end
    if ply.organism and ply.organism.otrub then return false end
    if IsValid(ply:GetNetVar("carryent")) or IsValid(ply:GetNetVar("carryent2")) then return false end
    return not IsValid(ply:GetNWEntity("ZCBackCarryRagdoll"))
end

local function ResolveCarryableFakeRagdoll(target, ragdoll)
    if not IsValid(target) or not target:IsPlayer() then return nil end
    if not target:Alive() then return nil end

    local fakeRagdoll = target.FakeRagdoll or target:GetNWEntity("FakeRagdoll")
    if not IsValid(fakeRagdoll) or not fakeRagdoll:IsRagdoll() then return nil end
    if IsValid(ragdoll) and fakeRagdoll ~= ragdoll then return nil end

    return fakeRagdoll
end

local function GetRagdollOwner(ragdoll)
    if not IsValid(ragdoll) then return nil end

    if hg and hg.RagdollOwner then
        local ok, owner = pcall(hg.RagdollOwner, ragdoll)
        if ok and IsValid(owner) and owner:IsPlayer() then
            return owner
        end
    end

    local candidate = ragdoll:GetNWEntity("ply")
    if IsValid(candidate) and candidate:IsPlayer() then
        return candidate
    end

    for _, p in ipairs(player.GetAll()) do
        if p.FakeRagdoll == ragdoll or p:GetNWEntity("FakeRagdoll") == ragdoll then
            return p
        end
    end

    return nil
end

local function ResolveEntityTarget(ply, ent)
    if not IsValid(ent) then return nil end

    local target = nil
    local ragdoll = nil

    if ent:IsPlayer() then
        target = ent
        ragdoll = ent.FakeRagdoll or ent:GetNWEntity("FakeRagdoll")
    elseif ent:IsRagdoll() then
        ragdoll = ent
        target = GetRagdollOwner(ent)
    elseif IsValid(ent.ply) and ent.ply:IsPlayer() then
        target = ent.ply
        ragdoll = ent
    end

    if not IsValid(target) or target == ply then return nil end
    ragdoll = ResolveCarryableFakeRagdoll(target, ragdoll)
    if not IsValid(ragdoll) then return nil end

    local carrier = target:GetNWEntity("ZCBackCarrier")
    if IsValid(carrier) and carrier ~= ply then return nil end

    if ragdoll:GetPos():Distance(ply:GetPos()) > SCAN_RANGE then return nil end

    return target, ragdoll
end

local function FindCarryTarget(ply)
    if not CanBackCarryNow(ply) or not hg or not hg.eyeTrace then return nil end

    local tr = hg.eyeTrace(ply)
    local target, ragdoll = ResolveEntityTarget(ply, tr and tr.Entity or nil)
    if IsValid(target) then
        return target, ragdoll
    end

    local bestTarget = nil
    local bestRagdoll = nil
    local bestDist = SCAN_RANGE

    for _, p in ipairs(player.GetAll()) do
        if p == ply then continue end
        local candidateRagdoll = p.FakeRagdoll or p:GetNWEntity("FakeRagdoll")
        local candidateTarget, resolvedRagdoll = ResolveEntityTarget(ply, candidateRagdoll)
        if not IsValid(candidateTarget) then continue end

        local dist = resolvedRagdoll:GetPos():Distance(ply:GetPos())
        if dist > bestDist then continue end

        bestDist = dist
        bestTarget = candidateTarget
        bestRagdoll = resolvedRagdoll
    end

    return bestTarget, bestRagdoll
end

hook.Add("HUDPaint", "ZC_AmputeeBackCarryIndicator", function()
    local ply = LocalPlayer()
    if IsZScavBackCarryDisabled() or not IsValid(ply) or not ply:Alive() then
        alpha = 0
        progress = 0
        return
    end

    local carried = ply:GetNWEntity("ZCBackCarryRagdoll")
    local carrier = ply:GetNWEntity("ZCBackCarrier")
    local target = nil
    local showDrop = IsValid(carried)

    if not showDrop then
        target = FindCarryTarget(ply)
    end

    local desired = (showDrop or IsValid(target)) and 1 or 0
    alpha = math.Clamp(alpha + (desired - alpha) * FADE_SPEED * FrameTime(), 0, 1)

    if alpha <= 0.01 then return end

    if IsValid(target) then
        targetName = target.GetPlayerName and target:GetPlayerName() or target:Nick()
    elseif showDrop then
        local carriedTarget = ply:GetNWEntity("ZCBackCarryTarget")
        if IsValid(carriedTarget) then
            targetName = carriedTarget.GetPlayerName and carriedTarget:GetPlayerName() or carriedTarget:Nick()
        else
            targetName = "Carried target"
        end
    end

    local holdStart = ply:GetNWFloat("ZCBackCarryHoldStart", 0)
    if not showDrop and holdStart > 0 and ply:KeyDown(IN_USE) and IsValid(target) then
        progress = math.Clamp((CurTime() - holdStart) / HOLD_TIME, 0, 1)
    else
        progress = 0
    end

    local sw, sh = ScrW(), ScrH()
    local cx = sw / 2
    local cy = sh * 0.75  -- Moved down to avoid overlap with revive prompt at 0.62
    local a = math.floor(alpha * 255)
    local action = showDrop and "Drop" or "Hold Back Carry"

    draw.RoundedBox(4, cx - 15, cy - 15, 30, 30, Color(40, 40, 40, a))
    draw.SimpleText("E", "HomigradFontMedium", cx, cy, Color(COL_KEY.r, COL_KEY.g, COL_KEY.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(action, "HomigradFontMedium", cx + 24, cy, Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(targetName, "HomigradFontSmall", cx, cy + 18, Color(COL_NAME.r, COL_NAME.g, COL_NAME.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if IsValid(carrier) then
        draw.SimpleText("Type !getoff to drop off", "HomigradFontVSmall", cx, cy + 34, Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if progress > 0 and not showDrop then
        local barW, barH = 120, 6
        local x, y = cx - barW / 2, cy + 32
        draw.RoundedBox(3, x, y, barW, barH, Color(0, 0, 0, math.floor(a * 0.7)))
        draw.RoundedBox(3, x + 1, y + 1, (barW - 2) * progress, barH - 2, Color(COL_KEY.r, COL_KEY.g, COL_KEY.b, a))
    end
end)