if SERVER then return end

local CARRY_ANCHOR_BONE = "ValveBiped.Bip01_Spine2"
local VIEW_OFFSET = Vector(-8, 0, 10)
local LERP_SPEED = 14

local smoothedPos = nil

local function GetCarrierAnchorPos(carrier)
    if not IsValid(carrier) then return nil end

    local anchorPos = carrier:GetPos() + Vector(0, 0, 56)
    local boneIndex = carrier:LookupBone(CARRY_ANCHOR_BONE)
    if boneIndex then
        local bonePos = carrier:GetBonePosition(boneIndex)
        if isvector(bonePos) and bonePos ~= vector_origin then
            anchorPos = bonePos
        end
    end

    return anchorPos
end

hook.Add("CalcView", "DCityPatch_BackCarryViewStabilizer", function(ply, origin, angles, fov, znear, zfar)
    if ply ~= LocalPlayer() then return end

    local carrier = ply:GetNWEntity("ZCBackCarrier")
    if not IsValid(carrier) then
        smoothedPos = nil
        return
    end

    local anchorPos = GetCarrierAnchorPos(carrier)
    if not anchorPos then return end

    local targetPos = anchorPos
        + carrier:GetForward() * VIEW_OFFSET.x
        + carrier:GetRight() * VIEW_OFFSET.y
        + carrier:GetUp() * VIEW_OFFSET.z

    local lerpT = math.Clamp(FrameTime() * LERP_SPEED, 0, 1)
    if not smoothedPos then
        smoothedPos = targetPos
    else
        smoothedPos = LerpVector(lerpT, smoothedPos, targetPos)
    end

    return {
        origin = smoothedPos,
        angles = angles,
        fov = fov,
        znear = znear,
        zfar = zfar,
        drawviewer = false,
    }
end)
