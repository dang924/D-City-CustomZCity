-- ZScav Bodycam System - per-player camera entity management.
-- Spawns one invisible gmod_ultimate_rtcam parented to each consenting player,
-- rewrites the camera's ID each director tick to point at a monitor slot.

local BC = ZSCAV.Bodycam

BC.PlyCam = BC.PlyCam or {}  -- [steamID64] = camera entity

local CAMERA_FOV = 80
local ZERO_VECTOR = Vector(0, 0, 0)
local ZERO_ANGLE = Angle(0, 0, 0)
local RAGDOLL_FACE_FORWARD_DIST = 6
local RAGDOLL_FACE_DOWN_OFFSET = 3
local RAGDOLL_FACE_BONE_CANDIDATES = {
    "ValveBiped.Bip01_Head1",
    "ValveBiped.Bip01_Neck1",
    "ValveBiped.Bip01_Spine4",
}

local cvMountBone = CreateConVar(
    "zscav_bodycam_mount_bone",
    tostring(BC.CAMERA_BONE or "ValveBiped.Bip01_Spine4"),
    FCVAR_ARCHIVE,
    "Preferred bodycam mount bone name. Falls back through the built-in spine list when unavailable."
)
local cvOffsetForward = CreateConVar(
    "zscav_bodycam_offset_forward",
    tostring((BC.CAMERA_OFFSET and BC.CAMERA_OFFSET.x) or 8),
    FCVAR_ARCHIVE,
    "Bodycam forward offset in mount-bone local space."
)
local cvOffsetRight = CreateConVar(
    "zscav_bodycam_offset_right",
    tostring((BC.CAMERA_OFFSET and BC.CAMERA_OFFSET.y) or 0),
    FCVAR_ARCHIVE,
    "Bodycam right offset in mount-bone local space."
)
local cvOffsetUp = CreateConVar(
    "zscav_bodycam_offset_up",
    tostring((BC.CAMERA_OFFSET and BC.CAMERA_OFFSET.z) or -4),
    FCVAR_ARCHIVE,
    "Bodycam up offset in mount-bone local space."
)
local cvCrouchOffsetForward = CreateConVar(
    "zscav_bodycam_crouch_offset_forward",
    tostring((BC.CAMERA_CROUCH_OFFSET and BC.CAMERA_CROUCH_OFFSET.x) or 0),
    FCVAR_ARCHIVE,
    "Extra forward offset applied while the player is crouching."
)
local cvCrouchOffsetRight = CreateConVar(
    "zscav_bodycam_crouch_offset_right",
    tostring((BC.CAMERA_CROUCH_OFFSET and BC.CAMERA_CROUCH_OFFSET.y) or 0),
    FCVAR_ARCHIVE,
    "Extra right offset applied while the player is crouching."
)
local cvCrouchOffsetUp = CreateConVar(
    "zscav_bodycam_crouch_offset_up",
    tostring((BC.CAMERA_CROUCH_OFFSET and BC.CAMERA_CROUCH_OFFSET.z) or 0),
    FCVAR_ARCHIVE,
    "Extra up offset applied while the player is crouching."
)

function BC:GetConfiguredMountBone()
    return string.Trim(tostring(cvMountBone:GetString() or ""))
end

function BC:GetCameraBaseOffset()
    return Vector(
        cvOffsetForward:GetFloat(),
        cvOffsetRight:GetFloat(),
        cvOffsetUp:GetFloat()
    )
end

function BC:GetCameraCrouchOffset()
    return Vector(
        cvCrouchOffsetForward:GetFloat(),
        cvCrouchOffsetRight:GetFloat(),
        cvCrouchOffsetUp:GetFloat()
    )
end

function BC:GetCameraTuneState()
    return {
        mountBone = self:GetConfiguredMountBone(),
        baseOffset = self:GetCameraBaseOffset(),
        crouchOffset = self:GetCameraCrouchOffset(),
    }
end

function BC:GetDefaultCameraTuneState()
    return {
        mountBone = tostring(self.CAMERA_BONE or "ValveBiped.Bip01_Spine4"),
        baseOffset = Vector(
            tonumber(self.CAMERA_OFFSET and self.CAMERA_OFFSET.x) or 8,
            tonumber(self.CAMERA_OFFSET and self.CAMERA_OFFSET.y) or 0,
            tonumber(self.CAMERA_OFFSET and self.CAMERA_OFFSET.z) or -4
        ),
        crouchOffset = Vector(
            tonumber(self.CAMERA_CROUCH_OFFSET and self.CAMERA_CROUCH_OFFSET.x) or 0,
            tonumber(self.CAMERA_CROUCH_OFFSET and self.CAMERA_CROUCH_OFFSET.y) or 0,
            tonumber(self.CAMERA_CROUCH_OFFSET and self.CAMERA_CROUCH_OFFSET.z) or 0
        ),
    }
end

function BC:SetCameraTuneState(state)
    state = state or {}

    local baseOffset = state.baseOffset or self:GetCameraBaseOffset()
    local crouchOffset = state.crouchOffset or self:GetCameraCrouchOffset()
    local mountBone = string.Trim(tostring(state.mountBone or self:GetConfiguredMountBone() or ""))

    RunConsoleCommand("zscav_bodycam_offset_forward", tostring(tonumber(baseOffset.x) or 0))
    RunConsoleCommand("zscav_bodycam_offset_right", tostring(tonumber(baseOffset.y) or 0))
    RunConsoleCommand("zscav_bodycam_offset_up", tostring(tonumber(baseOffset.z) or 0))
    RunConsoleCommand("zscav_bodycam_crouch_offset_forward", tostring(tonumber(crouchOffset.x) or 0))
    RunConsoleCommand("zscav_bodycam_crouch_offset_right", tostring(tonumber(crouchOffset.y) or 0))
    RunConsoleCommand("zscav_bodycam_crouch_offset_up", tostring(tonumber(crouchOffset.z) or 0))

    if mountBone ~= "" then
        RunConsoleCommand("zscav_bodycam_mount_bone", mountBone)
    end

    return self:GetCameraTuneState()
end

function BC:ResetCameraTuneState()
    return self:SetCameraTuneState(self:GetDefaultCameraTuneState())
end

function BC:GetCameraActiveOffset(ply)
    local offset = self:GetCameraBaseOffset()
    if IsValid(ply) and ply:Crouching() then
        offset = offset + self:GetCameraCrouchOffset()
    end

    return offset
end

function BC:GetCameraFallbackOffset(ply)
    local baseOffset = self.CAMERA_FALLBACK_OFFSET or Vector(20, 0, 35)
    local height = baseOffset.z

    if IsValid(ply) and ply.GetViewOffset and ply.GetViewOffsetDucked then
        local viewOffset = ply:Crouching() and ply:GetViewOffsetDucked() or ply:GetViewOffset()
        height = math.max((tonumber(viewOffset.z) or baseOffset.z) * 0.6, 18)
    end

    return Vector(baseOffset.x, baseOffset.y, height)
end

function BC:GetCameraMountEntity(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return nil end

    if hg and isfunction(hg.GetCurrentCharacter) then
        local currentCharacter = hg.GetCurrentCharacter(ply)
        if IsValid(currentCharacter) then
            return currentCharacter
        end
    end

    if IsValid(ply.FakeRagdoll) then
        return ply.FakeRagdoll
    end

    return ply
end

function BC:GetMountBoneCandidates()
    local names = {}
    local preferred = self:GetConfiguredMountBone()

    if preferred ~= "" then
        names[#names + 1] = preferred
    end

    for _, boneName in ipairs(self.CAMERA_BONE_FALLBACKS or {}) do
        if isstring(boneName) and boneName ~= "" and boneName ~= preferred then
            names[#names + 1] = boneName
        end
    end

    return names
end

local function getBoneWorldTransform(ent, boneIndex)
    if not (IsValid(ent) and isnumber(boneIndex) and boneIndex >= 0) then return nil end

    local matrix = ent:GetBoneMatrix(boneIndex)
    if matrix then
        return matrix:GetTranslation(), matrix:GetAngles()
    end

    local bonePos, boneAng = ent:GetBonePosition(boneIndex)
    if isvector(bonePos) and isangle(boneAng) then
        return bonePos, boneAng
    end

    return nil
end

local function resolveRagdollFaceAnchor(mount)
    local mountEnt = mount and mount.entity or nil
    if not (IsValid(mountEnt) and mountEnt:IsRagdoll()) then return nil end

    if mountEnt.SetupBones then
        mountEnt:SetupBones()
    end

    for _, boneName in ipairs(RAGDOLL_FACE_BONE_CANDIDATES) do
        local boneIndex = mountEnt:LookupBone(boneName)
        local bonePos, boneAng = getBoneWorldTransform(mountEnt, boneIndex)
        if isvector(bonePos) then
            return {
                pos = bonePos,
                ang = boneAng or ZERO_ANGLE,
                boneName = boneName,
                boneIndex = boneIndex,
                entity = mountEnt,
                fallback = false,
                ragdollFace = true,
            }
        end
    end

    return nil
end

function BC:ResolveCameraMount(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return nil end

    local mountEnt = self:GetCameraMountEntity(ply)
    if not IsValid(mountEnt) then return nil end

    if mountEnt.SetupBones then
        mountEnt:SetupBones()
    end

    for _, boneName in ipairs(self:GetMountBoneCandidates()) do
        local boneIndex = mountEnt:LookupBone(boneName)
        if not (isnumber(boneIndex) and boneIndex >= 0) then continue end

        local bonePos, boneAng = getBoneWorldTransform(mountEnt, boneIndex)
        if isvector(bonePos) then
            return {
                pos = bonePos,
                ang = boneAng or ZERO_ANGLE,
                boneName = boneName,
                boneIndex = boneIndex,
                entity = mountEnt,
                fallback = false,
            }
        end
    end

    local bodyAng = mountEnt:GetAngles()
    bodyAng.p = 0
    bodyAng.r = 0

    return {
        pos = mountEnt:GetPos(),
        ang = bodyAng,
        boneName = "origin_fallback",
        boneIndex = -1,
        entity = mountEnt,
        fallback = true,
    }
end

function BC:GetCameraTransform(ply)
    local mount = self:ResolveCameraMount(ply)
    if not mount then return nil end

    local ragdollFaceAnchor = resolveRagdollFaceAnchor(mount)
    if ragdollFaceAnchor then
        local eyeAng = ply:EyeAngles()
        eyeAng.r = 0

        local worldPos = ragdollFaceAnchor.pos
            + eyeAng:Forward() * RAGDOLL_FACE_FORWARD_DIST
            - eyeAng:Up() * RAGDOLL_FACE_DOWN_OFFSET
        return worldPos, eyeAng, ragdollFaceAnchor, ZERO_VECTOR
    end

    local offset = mount.fallback and self:GetCameraFallbackOffset(ply) or self:GetCameraActiveOffset(ply)
    local worldPos = LocalToWorld(offset, ZERO_ANGLE, mount.pos, mount.ang)
    local worldAng = ply:EyeAngles()

    return worldPos, worldAng, mount, offset
end

local function detachCameraFromOwner(cam)
    if not IsValid(cam) then return end

    if IsValid(cam:GetParent()) then
        cam:SetParent(nil)
    end

    cam.zscav_bodycam_follow_bone = nil
    cam.zscav_bodycam_attached = false
end

local function applyBodycamEntityState(cam)
    if not IsValid(cam) then return end

    cam:SetNoDraw(true)
    cam:AddEffects(EF_NODRAW)
    cam:DrawShadow(false)
    cam:SetRenderMode(RENDERMODE_NONE)
    cam:SetColor(Color(255, 255, 255, 0))
    if cam.zscav_bodycam_ghost_state_applied then return end

    cam:SetCollisionGroup(COLLISION_GROUP_WORLD)
    cam:SetSolid(SOLID_NONE)
    if cam.SetNotSolid then
        cam:SetNotSolid(true)
    end
    if cam.SetTrigger then
        cam:SetTrigger(false)
    end
    cam:SetMoveType(MOVETYPE_NONE)
    cam:SetCollisionBounds(ZERO_VECTOR, ZERO_VECTOR)
    if cam.PhysicsDestroy then
        cam:PhysicsDestroy()
    end

    local phys = cam:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    cam.zscav_bodycam_ghost_state_applied = true
end

local function ensureCameraFollowBone(cam, ply, mount)
    if not (IsValid(cam) and IsValid(ply) and mount) then return false end
    if mount.fallback then return false end
    if IsValid(mount.entity) and mount.entity:IsRagdoll() then return false end
    if not (isnumber(mount.boneIndex) and mount.boneIndex >= 0) then return false end
    if not isfunction(cam.FollowBone) then return false end

    local mountEnt = mount.entity
    if not IsValid(mountEnt) then return false end

    if cam:GetParent() ~= mountEnt
        or cam.zscav_bodycam_follow_bone ~= mount.boneIndex
        or cam.zscav_bodycam_follow_parent ~= mountEnt then
        detachCameraFromOwner(cam)
        cam:SetParent(mountEnt)
        cam:FollowBone(mountEnt, mount.boneIndex)
        cam.zscav_bodycam_follow_bone = mount.boneIndex
        cam.zscav_bodycam_follow_parent = mountEnt
    end

    cam.zscav_bodycam_attached = true
    return true
end

local function applyCameraTransform(cam, ply)
    if not (IsValid(cam) and IsValid(ply)) then return false end

    applyBodycamEntityState(cam)

    local pos, ang, mount, offset = BC:GetCameraTransform(ply)
    if not pos then return false end

    local attached = ensureCameraFollowBone(cam, ply, mount)

    cam.zscav_bodycam_mount_bone = mount and mount.boneName or nil
    cam.zscav_bodycam_mount_index = mount and mount.boneIndex or nil
    cam.zscav_bodycam_mount_entity = IsValid(mount and mount.entity) and mount.entity or nil
    cam.zscav_bodycam_mount_fallback = mount and mount.fallback or nil
    cam.zscav_bodycam_mount_offset = offset

    if attached then
        cam:SetLocalPos(offset)
        local _, localAng = WorldToLocal(ZERO_VECTOR, ang, ZERO_VECTOR, mount.ang)
        cam:SetLocalAngles(localAng)
    else
        detachCameraFromOwner(cam)
        cam:SetPos(pos)
        cam:SetAngles(ang)
    end

    return true
end

local function makeBodycamForPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local sid = ply:SteamID64()
    if not sid then return end

    -- Reuse existing if valid
    local existing = BC.PlyCam[sid]
    if IsValid(existing) then return existing end

    local cam = ents.Create("gmod_ultimate_rtcam")
    if not IsValid(cam) then return end

    cam:SetPos(ply:GetPos() + Vector(0, 0, 50))
    cam:SetAngles(ply:EyeAngles())
    cam:Spawn()
    cam:Activate()

    -- Hide the camera prop and strip collision immediately so it never renders
    -- or intercepts bullet traces while mounted to the owner.
    applyBodycamEntityState(cam)

    -- Anchor the RT camera to the owner's torso bone so it rides the player
    -- like worn equipment instead of dragging behind world-position updates.
    cam.zscav_bodycam_owner = ply

    cam:SetFOV(CAMERA_FOV)
    cam:SetActualID("bodycam_" .. sid)
    cam:SetIDMode(0)  -- ID_MODE_GLOBAL: we manage IDs directly
    cam:SetID(BC:InactiveCamID(ply))  -- starts idle (no monitor will pick it up)

    -- Tag so we can recognize our own entities later (cleanup, hooks, etc.)
    cam.IsZScavBodycam = true
    cam.zscav_bodycam_owner_sid = sid

    BC.PlyCam[sid] = cam
    applyCameraTransform(cam, ply)
    return cam
end

local function destroyBodycamForPlayer(ply_or_sid)
    local sid = isstring(ply_or_sid) and ply_or_sid
        or (IsValid(ply_or_sid) and ply_or_sid:SteamID64())
        or nil
    if not sid then return end
    local cam = BC.PlyCam[sid]
    if IsValid(cam) then cam:Remove() end
    BC.PlyCam[sid] = nil
end

function BC:EnsureCamera(ply)
    return makeBodycamForPlayer(ply)
end

function BC:RemoveCamera(ply_or_sid)
    destroyBodycamForPlayer(ply_or_sid)
end

function BC:GetCamera(ply)
    if not IsValid(ply) then return nil end
    local cam = self.PlyCam[ply:SteamID64()]
    if IsValid(cam) then return cam end
    return nil
end

-- Per-tick: resolve a torso-bone mount, apply the tunable bodycam offset, and
-- keep the capture angle tied to the player's view. Position is bone-followed
-- so the camera rides the player instead of lagging as a free world entity.
hook.Add("Think", "ZScav_Bodycam_AlignCameras", function()
    if not BC:IsActive() then return end
    for sid, cam in pairs(BC.PlyCam) do
        if not IsValid(cam) then BC.PlyCam[sid] = nil continue end
        local ply = cam.zscav_bodycam_owner
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end

        applyCameraTransform(cam, ply)
    end
end)

-- Cleanup on player death: tear down their bodycam camera entity. The director
-- will remove their slot assignment on the next tick.
hook.Add("PlayerDeath", "ZScav_Bodycam_CleanOnDeath", function(ply)
    if not IsValid(ply) then return end
    BC:RemoveCamera(ply)
end)

hook.Add("PlayerDisconnected", "ZScav_Bodycam_CleanOnLeave", function(ply)
    if not IsValid(ply) then return end
    BC:RemoveCamera(ply)
end)

-- Mode change / map cleanup: nuke all bodycam cameras.
hook.Add("PostCleanupMap", "ZScav_Bodycam_PurgeOnCleanup", function()
    for sid, cam in pairs(BC.PlyCam) do
        if IsValid(cam) then cam:Remove() end
        BC.PlyCam[sid] = nil
    end
end)

-- Public: forcibly clear all bodycam cameras (called when consent state is reset
-- e.g. between raids, or when ZScav is disabled).
function BC:ClearAllCameras()
    for sid, _ in pairs(self.PlyCam) do
        destroyBodycamForPlayer(sid)
    end
end
