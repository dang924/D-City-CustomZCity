-- sv_ragdoll_animator.lua
-- Tool for recording and playing back ragdoll animations
-- Captures bone positions/angles at intervals, supports playback with interpolation
-- Can record NPCs in knockdown state or any ragdoll entity

if CLIENT then return end

util.AddNetworkString("RagdollAnimator_RequestStatus")
util.AddNetworkString("RagdollAnimator_Status")
util.AddNetworkString("RagdollAnimator_RecordingStarted")
util.AddNetworkString("RagdollAnimator_RecordingStopped")
util.AddNetworkString("RagdollAnimator_FrameRecorded")

local RagdollAnimator = {}
local recordings = {}  -- storage: { [recordingName] = { frames = {...}, boneList = {...}, fps = 30 } }
local knockdownMirrorRecording = nil
local knockdownMirrorFrontRecording = nil
local knockdownMirrorBackRecording = nil
local MIRROR_START_DELAY = 0.65
local aimTool = {
    targetEnt = nil,
    capturePly = nil,
    samples = 0,
    sumYaw = 0,
    sumPitch = 0,
}

local UPPER_BODY_BONES = {
    "ValveBiped.Bip01_Head1",
    "ValveBiped.Bip01_Spine",
    "ValveBiped.Bip01_Spine2",
    "ValveBiped.Bip01_R_Shoulder",
    "ValveBiped.Bip01_R_Arm",
    "ValveBiped.Bip01_R_Forearm",
    "ValveBiped.Bip01_R_Hand",
    "ValveBiped.Bip01_L_Shoulder",
    "ValveBiped.Bip01_L_Arm",
    "ValveBiped.Bip01_L_Forearm",
    "ValveBiped.Bip01_L_Hand",
}

local function SendRecordingStartedNet(ply, recordingName)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    net.Start("RagdollAnimator_RecordingStarted")
    net.WriteString(recordingName or "")
    net.Send(ply)
end

local function SendRecordingStoppedNet(ply, recordingName, frameCount)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    net.Start("RagdollAnimator_RecordingStopped")
    net.WriteString(recordingName or "")
    net.WriteUInt(math.Clamp(tonumber(frameCount) or 0, 0, 65535), 16)
    net.Send(ply)
end

local function SendFrameRecordedNet(ply, frameCount)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    net.Start("RagdollAnimator_FrameRecorded")
    net.WriteUInt(math.Clamp(tonumber(frameCount) or 0, 0, 65535), 16)
    net.Send(ply)
end

local function BuildStatusSnapshot()
    local names = {}
    local activeRecording = ""
    for name, rec in pairs(recordings) do
        names[#names + 1] = name
        if rec and rec.isRecording and activeRecording == "" then
            activeRecording = name
        end
    end
    table.sort(names)

    local yawBias = 0
    local pitchBias = 0
    local samples = tonumber(aimTool.samples) or 0
    if samples > 0 then
        yawBias = (aimTool.sumYaw or 0) / samples
        pitchBias = (aimTool.sumPitch or 0) / samples
    end

    return {
        recordings = names,
        activeRecording = activeRecording,
        mirrorRecording = isstring(knockdownMirrorRecording) and knockdownMirrorRecording or "",
        mirrorRecordingFront = isstring(knockdownMirrorFrontRecording) and knockdownMirrorFrontRecording or "",
        mirrorRecordingBack = isstring(knockdownMirrorBackRecording) and knockdownMirrorBackRecording or "",
        hasAimTarget = IsValid(aimTool.targetEnt),
        isAimCapturing = IsValid(aimTool.capturePly),
        aimSamples = samples,
        aimYawBias = yawBias,
        aimPitchBias = pitchBias,
    }
end

local function SendStatus(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    net.Start("RagdollAnimator_Status")
    net.WriteTable(BuildStatusSnapshot())
    net.Send(ply)
end

local function RefreshStatusSoon(ply, delay)
    timer.Simple(delay or 0.15, function()
        if IsValid(ply) then
            SendStatus(ply)
        end
    end)
end

-- ── Bone tracking utilities ───────────────────────────────────────────────────

local function GetBoneState(rag, boneName)
    if not IsValid(rag) or not isstring(boneName) then return nil end
    if rag:GetClass() ~= "prop_ragdoll" then return nil end
    
    local bone = rag:LookupBone(boneName)
    if not bone or bone < 0 then return nil end

    if not isfunction(rag.TranslateBoneToPhysBone) or not isfunction(rag.GetPhysicsObjectNum) then return nil end

    local physBone = rag:TranslateBoneToPhysBone(bone)
    if not isnumber(physBone) or physBone < 0 then return nil end

    local phys = rag:GetPhysicsObjectNum(physBone)
    if not IsValid(phys) then return nil end

    local pos = phys:GetPos()
    local ang = phys:GetAngles()
    
    if not isvector(pos) or not isangle(ang) then return nil end
    
    return {
        pos = pos,
        ang = ang,
    }
end

local function GetSourceBoneState(ent, boneName)
    if not IsValid(ent) or not isstring(boneName) then return nil end

    if ent:GetClass() == "prop_ragdoll" then
        return GetBoneState(ent, boneName)
    end

    local bone = ent:LookupBone(boneName)
    if not bone or bone < 0 then return nil end

    local m = ent:GetBoneMatrix(bone)
    local pos = m and m:GetTranslation() or nil
    local ang = m and m:GetAngles() or nil

    if not isvector(pos) then
        local p = ent:GetBonePosition(bone)
        if isvector(p) then
            pos = p
        end
    end

    if not isangle(ang) then
        ang = ent:GetAngles()
    end

    if not isvector(pos) or not isangle(ang) then return nil end

    return {
        pos = pos,
        ang = ang,
    }
end

local function SetBoneState(rag, boneName, state)
    if not IsValid(rag) or not isstring(boneName) or not istable(state) then return false end
    if rag:GetClass() ~= "prop_ragdoll" then return false end
    
    local bone = rag:LookupBone(boneName)
    if not bone or bone < 0 then return false end

    if not isfunction(rag.TranslateBoneToPhysBone) or not isfunction(rag.GetPhysicsObjectNum) then return false end

    local physBone = rag:TranslateBoneToPhysBone(bone)
    if not isnumber(physBone) or physBone < 0 then return false end

    local phys = rag:GetPhysicsObjectNum(physBone)
    if not IsValid(phys) then return false end

    if isvector(state.pos) then
        phys:SetPos(state.pos)
    end
    if isangle(state.ang) then
        phys:SetAngles(state.ang)
    end

    return true
end

local function LerpVector(a, b, t)
    return a + (b - a) * t
end

local function LerpAngle(a, b, t)
    return Angle(
        Lerp(t, a.p, b.p),
        Lerp(t, a.y, b.y),
        Lerp(t, a.r, b.r)
    )
end

local function LerpBoneState(state1, state2, t)
    if not istable(state1) or not istable(state2) then return nil end
    
    return {
        pos = LerpVector(state1.pos, state2.pos, t),
        ang = LerpAngle(state1.ang, state2.ang, t),
    }
end

local function MakeAngleDelta(baseAng, currentAng)
    return Angle(
        math.AngleDifference(currentAng.p, baseAng.p),
        math.AngleDifference(currentAng.y, baseAng.y),
        math.AngleDifference(currentAng.r, baseAng.r)
    )
end

local function ApplyAngleDelta(baseAng, deltaAng)
    return Angle(
        baseAng.p + deltaAng.p,
        baseAng.y + deltaAng.y,
        baseAng.r + deltaAng.r
    )
end

local function FreezeBonePhysics(rag, boneName, frozen)
    if not IsValid(rag) or rag:GetClass() ~= "prop_ragdoll" then return end

    local bone = rag:LookupBone(boneName)
    if not bone or bone < 0 then return end
    if not isfunction(rag.TranslateBoneToPhysBone) or not isfunction(rag.GetPhysicsObjectNum) then return end

    local physBone = rag:TranslateBoneToPhysBone(bone)
    if not isnumber(physBone) or physBone < 0 then return end

    local phys = rag:GetPhysicsObjectNum(physBone)
    if not IsValid(phys) or not isfunction(phys.EnableMotion) then return end

    phys:EnableMotion(not frozen)
    if isfunction(phys.Wake) then
        phys:Wake()
    end
end

local ROOT_FRAME_BONES = {
    "ValveBiped.Bip01_Spine",
    "ValveBiped.Bip01_Spine2",
    "ValveBiped.Bip01_Pelvis",
    "Bip01 Spine",
    "Bip01 Pelvis",
}

local function GetRootFrame(ent)
    if not IsValid(ent) then
        return nil, nil
    end

    for _, boneName in ipairs(ROOT_FRAME_BONES) do
        local state = GetSourceBoneState(ent, boneName)
        if state and isvector(state.pos) and isangle(state.ang) then
            return state.pos, state.ang
        end
    end

    if ent:GetClass() == "prop_ragdoll" then
        return ent:WorldSpaceCenter(), ent:GetAngles()
    end

    return ent:GetPos(), ent:GetAngles()
end

local function ResolvePlayerRecordingSource(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return nil end
    if IsValid(ply.FakeRagdoll) then return ply.FakeRagdoll end
    if isfunction(ply.GetNWEntity) then
        local nwRag = ply:GetNWEntity("FakeRagdoll")
        if IsValid(nwRag) then return nwRag end
    end
    return nil
end

function RagdollAnimator:GetMirrorStartDelay()
    return MIRROR_START_DELAY
end

-- ── Recording functions ──────────────────────────────────────────────────────

-- List of bones to record by default for Combine/Metro NPCs
local DEFAULT_BONES = UPPER_BODY_BONES

function RagdollAnimator:GetActiveBones(rag, boneNameList)
    if not IsValid(rag) then return {} end
    
    local boneList = boneNameList or DEFAULT_BONES
    local activeBones = {}
    
    for _, boneName in ipairs(boneList) do
        if GetSourceBoneState(rag, boneName) then
            table.insert(activeBones, boneName)
        end
    end
    
    return activeBones
end

function RagdollAnimator:StartRecording(recordingName, rag, frameInterval, boneNameList, ownerPly)
    if not isstring(recordingName) or not IsValid(rag) then return false end
    
    frameInterval = math.Clamp(tonumber(frameInterval) or 0.05, 0.01, 1.0)
    local boneList = self:GetActiveBones(rag, boneNameList)
    
    if #boneList == 0 then
        print("[RagdollAnimator] No valid bones found on ragdoll")
        return false
    end
    
    recordings[recordingName] = {
        frames = {},
        boneList = boneList,
        fps = math.Round(1 / frameInterval),
        startTime = CurTime(),
        isRecording = true,
        owner = IsValid(ownerPly) and ownerPly or nil,
        baseFrame = nil,
        baseRootPos = nil,
        baseRootAng = nil,
        mode = "upper_body_floor_local",
    }
    
    print("[RagdollAnimator] Started recording '" .. recordingName .. "' (" .. #boneList .. " bones, " .. math.Round(1/frameInterval) .. " FPS)")
    SendRecordingStartedNet(recordings[recordingName].owner, recordingName)
    
    -- Capture frames on a timer
    local timerId = "RagdollAnimator_Record_" .. recordingName
    timer.Create(timerId, frameInterval, 0, function()
        if not recordings[recordingName] or not recordings[recordingName].isRecording then
            timer.Remove(timerId)
            return
        end
        
        if not IsValid(rag) then
            recordings[recordingName].isRecording = false
            timer.Remove(timerId)
            print("[RagdollAnimator] Source entity became invalid, stopping recording")
            SendRecordingStoppedNet(recordings[recordingName].owner, recordingName, #recordings[recordingName].frames)
            return
        end
        
        local frame = {}
        for _, boneName in ipairs(boneList) do
            frame[boneName] = GetSourceBoneState(rag, boneName)
        end

        local rec = recordings[recordingName]
        if not rec.baseFrame then
            rec.baseFrame = frame
            rec.baseRootPos, rec.baseRootAng = GetRootFrame(rag)
        end

        local currentRootPos, currentRootAng = GetRootFrame(rag)
        local deltaFrame = {}
        for _, boneName in ipairs(boneList) do
            local baseState = rec.baseFrame[boneName]
            local currentState = frame[boneName]
            if baseState and currentState then
                local baseLocalPos, baseLocalAng = WorldToLocal(
                    baseState.pos,
                    baseState.ang,
                    rec.baseRootPos or vector_origin,
                    rec.baseRootAng or angle_zero
                )
                local currentLocalPos, currentLocalAng = WorldToLocal(
                    currentState.pos,
                    currentState.ang,
                    currentRootPos,
                    currentRootAng
                )
                deltaFrame[boneName] = {
                    pos = currentLocalPos - baseLocalPos,
                    ang = MakeAngleDelta(baseLocalAng, currentLocalAng),
                }
            end
        end

        table.insert(rec.frames, deltaFrame)
        SendFrameRecordedNet(rec.owner, #rec.frames)
    end)
    
    return true
end

function RagdollAnimator:CaptureIdleAimPose(recordingName, rag, boneNameList, ownerPly)
    if not isstring(recordingName) or recordingName == "" or not IsValid(rag) then return false end

    local boneList = self:GetActiveBones(rag, boneNameList)
    if #boneList == 0 then
        print("[RagdollAnimator] Idle pose capture failed: no valid upper-body bones")
        return false
    end

    local rootPos, rootAng = GetRootFrame(rag)
    if not isvector(rootPos) or not isangle(rootAng) then
        return false
    end
    local idlePoseAngles = {}

    for _, boneName in ipairs(boneList) do
        local state = GetSourceBoneState(rag, boneName)
        if state and isangle(state.ang) then
            idlePoseAngles[boneName] = MakeAngleDelta(rootAng, state.ang)
        end
    end

    if table.Count(idlePoseAngles) <= 0 then
        print("[RagdollAnimator] Idle pose capture failed: no sampled bone angles")
        return false
    end

    recordings[recordingName] = {
        frames = {
            [1] = {},
        },
        boneList = boneList,
        fps = 20,
        startTime = CurTime(),
        isRecording = false,
        owner = IsValid(ownerPly) and ownerPly or nil,
        baseFrame = nil,
        mode = "idle_aim_pose",
        idlePoseAngles = idlePoseAngles,
    }

    print("[RagdollAnimator] Captured idle aim pose '" .. recordingName .. "' (" .. table.Count(idlePoseAngles) .. " bones)")
    SendRecordingStoppedNet(recordings[recordingName].owner, recordingName, 1)
    return true
end

function RagdollAnimator:StopRecording(recordingName)
    if not isstring(recordingName) or not recordings[recordingName] then return false end
    
    local recording = recordings[recordingName]
    recording.isRecording = false
    timer.Remove("RagdollAnimator_Record_" .. recordingName)
    
    local frameCount = #recording.frames
    print("[RagdollAnimator] Stopped recording '" .. recordingName .. "' (" .. frameCount .. " frames)")
    SendRecordingStoppedNet(recording.owner, recordingName, frameCount)
    
    return frameCount > 0
end

function RagdollAnimator:ListRecordings()
    local names = {}
    for name, rec in pairs(recordings) do
        table.insert(names, name)
    end
    return names
end

function RagdollAnimator:GetRecordingMode(recordingName)
    if not isstring(recordingName) or recordingName == "" then return nil end
    local rec = recordings[recordingName]
    if not rec then return nil end
    return rec.mode or "upper_body_floor"
end

-- ── Playback functions ────────────────────────────────────────────────────────

function RagdollAnimator:PlayRecording(recordingName, rag, speed, loop, onFinish)
    if not isstring(recordingName) or not IsValid(rag) then return false end
    if not recordings[recordingName] then
        print("[RagdollAnimator] Recording '" .. recordingName .. "' not found")
        return false
    end
    
    local recording = recordings[recordingName]
    if #recording.frames == 0 then
        print("[RagdollAnimator] Recording '" .. recordingName .. "' has no frames")
        return false
    end
    
    speed = tonumber(speed) or 1.0
    loop = loop == true
    onFinish = isfunction(onFinish) and onFinish or nil
    
    local playerId = "RagdollAnimator_Play_" .. rag:EntIndex() .. "_" .. recordingName

    if recording.mode == "idle_aim_pose" and istable(recording.idlePoseAngles) then
        local idleFrameInterval = math.max(0.02, (1 / (recording.fps or 20)) / speed)
        for _, boneName in ipairs(recording.boneList or {}) do
            FreezeBonePhysics(rag, boneName, true)
        end

        timer.Create(playerId, idleFrameInterval, 0, function()
            if not IsValid(rag) then
                for _, boneName in ipairs(recording.boneList or {}) do
                    FreezeBonePhysics(rag, boneName, false)
                end
                timer.Remove(playerId)
                if onFinish then onFinish() end
                return
            end

            local _, rootAng = GetRootFrame(rag)
            if not isangle(rootAng) then
                rootAng = rag:GetAngles()
            end
            for _, boneName in ipairs(recording.boneList or {}) do
                local offset = recording.idlePoseAngles[boneName]
                if isangle(offset) then
                    local current = GetBoneState(rag, boneName)
                    if current then
                        SetBoneState(rag, boneName, {
                            pos = current.pos,
                            ang = ApplyAngleDelta(rootAng, offset),
                        })
                    end
                end
            end

            if not loop then
                for _, boneName in ipairs(recording.boneList or {}) do
                    FreezeBonePhysics(rag, boneName, false)
                end
                timer.Remove(playerId)
                if onFinish then onFinish() end
            end
        end)

        print("[RagdollAnimator] Playing idle aim pose '" .. recordingName .. "' (loop: " .. tostring(loop) .. ")")
        return true
    end
    
    local playbackState = {
        recording = recording,
        currentFrame = 0,
        frameProgress = 0,  -- 0 to 1 between frames
        isPlaying = true,
        loop = loop,
        speed = speed,
        baseStates = {},
        baseLocalStates = {},
    }

    for _, boneName in ipairs(recording.boneList) do
        local state = GetBoneState(rag, boneName)
        if state then
            playbackState.baseStates[boneName] = {
                pos = state.pos,
                ang = state.ang,
            }

            if recording.mode == "upper_body_floor_local" then
                local rootPos, rootAng = GetRootFrame(rag)
                if not isvector(rootPos) or not isangle(rootAng) then
                    rootPos = rag:GetPos()
                    rootAng = rag:GetAngles()
                end
                local baseLocalPos, baseLocalAng = WorldToLocal(
                    state.pos,
                    state.ang,
                    rootPos,
                    rootAng
                )
                playbackState.baseLocalStates[boneName] = {
                    pos = baseLocalPos,
                    ang = baseLocalAng,
                }
            end

            FreezeBonePhysics(rag, boneName, true)
        end
    end
    
    local frameInterval = 1 / recording.fps / speed
    
    timer.Create(playerId, frameInterval, 0, function()
        if not IsValid(rag) or not playbackState.isPlaying then
            for _, boneName in ipairs(recording.boneList) do
                FreezeBonePhysics(rag, boneName, false)
            end
            timer.Remove(playerId)
            if onFinish then onFinish() end
            return
        end
        
        local frames = recording.frames
        local currentFrame = playbackState.currentFrame
        local nextFrame = currentFrame + 1
        
        -- Check if we've reached the end
        if nextFrame >= #frames then
            if loop then
                playbackState.currentFrame = 0
                nextFrame = 1
            else
                playbackState.isPlaying = false
                for _, boneName in ipairs(recording.boneList) do
                    FreezeBonePhysics(rag, boneName, false)
                end
                timer.Remove(playerId)
                if onFinish then onFinish() end
                return
            end
        end
        
        -- Apply interpolated state
        local frame1 = frames[currentFrame + 1]
        local frame2 = frames[nextFrame]
        
        if frame1 and frame2 then
            for _, boneName in ipairs(recording.boneList) do
                local state1 = frame1[boneName]
                local state2 = frame2[boneName]
                local baseState = playbackState.baseStates[boneName]
                
                if state1 and state2 and baseState then
                    local interpolated = LerpBoneState(state1, state2, 0.5)
                    if recording.mode == "upper_body_floor_local" then
                        local localBase = playbackState.baseLocalStates[boneName]
                        if localBase then
                            local rootPos, rootAng = GetRootFrame(rag)
                            if not isvector(rootPos) or not isangle(rootAng) then
                                rootPos = rag:GetPos()
                                rootAng = rag:GetAngles()
                            end
                            local finalLocalPos = localBase.pos + interpolated.pos
                            local finalLocalAng = ApplyAngleDelta(localBase.ang, interpolated.ang)
                            local worldPos, worldAng = LocalToWorld(
                                finalLocalPos,
                                finalLocalAng,
                                rootPos,
                                rootAng
                            )
                            SetBoneState(rag, boneName, {
                                pos = worldPos,
                                ang = worldAng,
                            })
                        end
                    else
                        SetBoneState(rag, boneName, {
                            pos = baseState.pos + interpolated.pos,
                            ang = ApplyAngleDelta(baseState.ang, interpolated.ang),
                        })
                    end
                end
            end
        end
        
        playbackState.currentFrame = nextFrame
    end)
    
    print("[RagdollAnimator] Playing '" .. recordingName .. "' (speed: " .. speed .. "x, loop: " .. tostring(loop) .. ")")
    
    return true
end

function RagdollAnimator:StopPlayback(rag, recordingName)
    if not IsValid(rag) then return false end
    
    local playerId = "RagdollAnimator_Play_" .. rag:EntIndex() .. "_" .. recordingName
    if timer.Exists(playerId) then
        timer.Remove(playerId)
        local recording = recordings[recordingName]
        if recording and recording.boneList then
            for _, boneName in ipairs(recording.boneList) do
                FreezeBonePhysics(rag, boneName, false)
            end
        end
        print("[RagdollAnimator] Stopped playback on entity " .. rag:EntIndex())
        return true
    end
    
    return false
end

-- ── Export/Import functions ──────────────────────────────────────────────────

function RagdollAnimator:ExportRecording(recordingName)
    if not recordings[recordingName] then return nil end
    
    local recording = recordings[recordingName]
    return {
        boneList = recording.boneList,
        fps = recording.fps,
        frames = recording.frames,
        baseFrame = recording.baseFrame,
        mode = recording.mode,
    }
end

function RagdollAnimator:ImportRecording(recordingName, data)
    if not isstring(recordingName) or not istable(data) then return false end
    if not istable(data.frames) or not istable(data.boneList) then return false end
    
    recordings[recordingName] = {
        frames = data.frames,
        boneList = data.boneList,
        fps = tonumber(data.fps) or 30,
        owner = nil,
        baseFrame = data.baseFrame,
        mode = data.mode or "upper_body_floor",
    }
    
    print("[RagdollAnimator] Imported recording '" .. recordingName .. "'")
    return true
end

function RagdollAnimator:SaveRecordingToFile(recordingName, fileName)
    local data = self:ExportRecording(recordingName)
    if not data then
        print("[RagdollAnimator] Recording '" .. recordingName .. "' not found")
        return false
    end
    
    fileName = fileName or ("ragdoll_" .. recordingName .. ".txt")
    local path = "data/ragdoll_animations/" .. fileName
    
    file.CreateDir("ragdoll_animations")
    
    local serialized = util.TableToJSON(data)
    file.Write(path, serialized)
    
    print("[RagdollAnimator] Saved recording to data/" .. path)
    return true
end

function RagdollAnimator:LoadRecordingFromFile(recordingName, fileName)
    fileName = fileName or ("ragdoll_" .. recordingName .. ".txt")
    local path = "data/ragdoll_animations/" .. fileName
    
    local content = file.Read(path, "DATA")
    if not content then
        print("[RagdollAnimator] File not found: " .. path)
        return false
    end
    
    local data = util.JSONToTable(content)
    if not data then
        print("[RagdollAnimator] Failed to parse JSON from " .. path)
        return false
    end
    
    return self:ImportRecording(recordingName, data)
end

function RagdollAnimator:DeleteRecording(recordingName)
    if not recordings[recordingName] then return false end
    
    recordings[recordingName] = nil
    print("[RagdollAnimator] Deleted recording '" .. recordingName .. "'")
    return true
end

function RagdollAnimator:SetKnockdownMirrorRecording(recordingName)
    if not isstring(recordingName) or recordingName == "" then
        knockdownMirrorRecording = nil
        knockdownMirrorFrontRecording = nil
        knockdownMirrorBackRecording = nil
        return false
    end
    if not recordings[recordingName] or #recordings[recordingName].frames <= 0 then
        return false
    end
    knockdownMirrorRecording = recordingName
    knockdownMirrorFrontRecording = recordingName
    knockdownMirrorBackRecording = recordingName
    return true
end

local function IsValidMirrorRecording(recordingName)
    return isstring(recordingName) and recordingName ~= "" and recordings[recordingName] and (#recordings[recordingName].frames > 0)
end

function RagdollAnimator:SetKnockdownMirrorRecordingForFallSide(side, recordingName)
    local normalizedSide = string.lower(tostring(side or ""))
    if normalizedSide ~= "front" and normalizedSide ~= "back" then
        return false, "invalid_side"
    end

    if not IsValidMirrorRecording(recordingName) then
        return false, "invalid_recording"
    end

    if normalizedSide == "front" then
        knockdownMirrorFrontRecording = recordingName
    else
        knockdownMirrorBackRecording = recordingName
    end

    if not IsValidMirrorRecording(knockdownMirrorRecording) then
        knockdownMirrorRecording = recordingName
    end

    return true
end

function RagdollAnimator:ClearKnockdownMirrorRecording()
    knockdownMirrorRecording = nil
    knockdownMirrorFrontRecording = nil
    knockdownMirrorBackRecording = nil
end

function RagdollAnimator:GetKnockdownMirrorRecording()
    if not isstring(knockdownMirrorRecording) then return nil end
    if not recordings[knockdownMirrorRecording] then return nil end
    if #recordings[knockdownMirrorRecording].frames <= 0 then return nil end
    return knockdownMirrorRecording
end

function RagdollAnimator:DetectRagdollFallSide(rag)
    if not IsValid(rag) or rag:GetClass() ~= "prop_ragdoll" then
        return "unknown"
    end

    local headBone = rag:LookupBone("ValveBiped.Bip01_Head1")
    if not headBone or headBone < 0 then
        headBone = rag:LookupBone("Bip01 Head")
    end

    if headBone and headBone >= 0 then
        local m = rag:GetBoneMatrix(headBone)
        local headAng = m and m:GetAngles() or nil
        if not isangle(headAng) then
            local _, fallbackAng = rag:GetBonePosition(headBone)
            if isangle(fallbackAng) then
                headAng = fallbackAng
            end
        end

        if isangle(headAng) then
            if headAng:Forward().z < 0 then
                return "front"
            end
            return "back"
        end
    end

    -- Fallback: upside-down-ish orientation usually means front-down in practice.
    if rag:GetUp().z < 0 then
        return "front"
    end

    return "back"
end

function RagdollAnimator:GetKnockdownMirrorRecordingForRagdoll(rag)
    local side = self:DetectRagdollFallSide(rag)

    if side == "front" and IsValidMirrorRecording(knockdownMirrorFrontRecording) then
        return knockdownMirrorFrontRecording, side
    end
    if side == "back" and IsValidMirrorRecording(knockdownMirrorBackRecording) then
        return knockdownMirrorBackRecording, side
    end

    if IsValidMirrorRecording(knockdownMirrorRecording) then
        return knockdownMirrorRecording, side
    end

    return nil, side
end

function RagdollAnimator:ApplyMirrorToCurrentDowned()
    local applied = 0
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:IsNPC() and ent.zc_knocked_down and IsValid(ent.zc_ragdoll) then
            local mirrorName = self:GetKnockdownMirrorRecordingForRagdoll(ent.zc_ragdoll)
            if not mirrorName then
                continue
            end
            if ent.zc_anim_mirror_recording and self.StopPlayback then
                self:StopPlayback(ent.zc_ragdoll, ent.zc_anim_mirror_recording)
            end
            if self:PlayRecording(mirrorName, ent.zc_ragdoll, 1.0, true) then
                ent.zc_anim_mirror_recording = mirrorName
                applied = applied + 1
            end
        end
    end

    return applied
end

local function StopAimCapture()
    timer.Remove("ZC_RagdollAnimator_AimCapture")
    aimTool.capturePly = nil
end

local function FindBullseyeForPlayer(ply)
    if not IsValid(ply) then return nil end
    for _, ent in ipairs(ents.FindByClass("npc_bullseye")) do
        if IsValid(ent) and ent:GetParent() == ply then
            return ent
        end
    end
    return nil
end

function RagdollAnimator:SpawnAimCalibrationTarget(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    if IsValid(aimTool.targetEnt) then
        aimTool.targetEnt:Remove()
        aimTool.targetEnt = nil
    end

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 3000,
        filter = ply,
    })

    local ent = ents.Create("npc_bullseye")
    if not IsValid(ent) then return false end
    ent:SetKeyValue("health", "99999")
    ent:SetPos((tr and tr.HitPos) or (ply:GetShootPos() + ply:GetAimVector() * 1200))
    ent:Spawn()
    ent:Activate()
    ent:SetNoDraw(false)
    ent:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    ent:SetSolid(SOLID_BBOX)
    ent:SetMoveType(MOVETYPE_NONE)

    aimTool.targetEnt = ent
    return true
end

function RagdollAnimator:RemoveAimCalibrationTarget()
    if IsValid(aimTool.targetEnt) then
        aimTool.targetEnt:Remove()
    end
    aimTool.targetEnt = nil
end

function RagdollAnimator:StartAimCapture(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false, "invalid_player" end
    if not IsValid(aimTool.targetEnt) then return false, "no_target" end

    StopAimCapture()
    aimTool.capturePly = ply
    aimTool.samples = 0
    aimTool.sumYaw = 0
    aimTool.sumPitch = 0

    timer.Create("ZC_RagdollAnimator_AimCapture", 0.05, 0, function()
        if not IsValid(aimTool.capturePly) or not IsValid(aimTool.targetEnt) then
            StopAimCapture()
            return
        end

        local p = aimTool.capturePly
        local shootPos = p:GetShootPos()
        local aimDir = p:GetAimVector()
        local tgtDir = (aimTool.targetEnt:WorldSpaceCenter() - shootPos)
        if tgtDir:LengthSqr() < 0.001 then return end
        tgtDir:Normalize()

        local aAim = aimDir:Angle()
        local aTgt = tgtDir:Angle()
        aimTool.sumYaw = aimTool.sumYaw + math.AngleDifference(aAim.y, aTgt.y)
        aimTool.sumPitch = aimTool.sumPitch + math.AngleDifference(aAim.p, aTgt.p)
        aimTool.samples = aimTool.samples + 1
    end)

    return true
end

function RagdollAnimator:StopAimCapture()
    StopAimCapture()
    return aimTool.samples
end

function RagdollAnimator:GetAimCaptureBias()
    if aimTool.samples <= 0 then
        return 0, 0, 0
    end
    return (aimTool.sumYaw / aimTool.samples), (aimTool.sumPitch / aimTool.samples), aimTool.samples
end

function RagdollAnimator:GetPreferredNPCBullseyeAimPosition(npc)
    if not IsValid(npc) then return nil end
    local enemy = npc:GetEnemy()
    if not IsValid(enemy) then return nil end

    if enemy:GetClass() == "npc_bullseye" then
        return enemy:WorldSpaceCenter()
    end

    if enemy:IsPlayer() then
        local bs = FindBullseyeForPlayer(enemy)
        if IsValid(bs) then
            return bs:WorldSpaceCenter()
        end
    end

    return enemy:WorldSpaceCenter()
end

function RagdollAnimator:ApplyCapturedAimBias(dir)
    if not isvector(dir) then return dir end
    local yawBias, pitchBias = self:GetAimCaptureBias()
    if yawBias == 0 and pitchBias == 0 then return dir end

    local a = dir:Angle()
    a:RotateAroundAxis(a:Up(), yawBias)
    a:RotateAroundAxis(a:Right(), pitchBias)
    return a:Forward()
end

function RagdollAnimator:GetAimToolStatus()
    local yawBias, pitchBias, samples = self:GetAimCaptureBias()
    return {
        hasTarget = IsValid(aimTool.targetEnt),
        targetEnt = IsValid(aimTool.targetEnt) and aimTool.targetEnt:EntIndex() or -1,
        capturing = IsValid(aimTool.capturePly),
        samples = samples,
        yawBias = yawBias,
        pitchBias = pitchBias,
    }
end

-- ── Entity validation ───────────────────────────────────────────────────────

local function IsValidBoneEntity(ent)
    if not IsValid(ent) then return false end
    if ent:GetClass() ~= "prop_ragdoll" then return false end
    if (ent:GetPhysicsObjectCount() or 0) <= 0 then return false end
    if not isfunction(ent.TranslateBoneToPhysBone) or not isfunction(ent.GetPhysicsObjectNum) then return false end

    -- Check if entity has bones we can work with
    local testBones = {
        "ValveBiped.Bip01_Head1",
        "Bip01 Head",
        "Head",
        "ValveBiped.Bip01_Spine",
        "Bip01 Spine",
        "Spine",
    }
    for _, boneName in ipairs(testBones) do
        local bone = ent:LookupBone(boneName)
        if bone and bone >= 0 then
            local physBone = ent:TranslateBoneToPhysBone(bone)
            if isnumber(physBone) and physBone >= 0 and IsValid(ent:GetPhysicsObjectNum(physBone)) then
                return true
            end
        end
    end
    return false
end

local function FindAnimatableEntity(ply, maxDist)
    maxDist = tonumber(maxDist) or 1000
    
    -- First try traceline
    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetForward() * maxDist,
        filter = ply,
    })
    
    if IsValidBoneEntity(tr.Entity) then
        return tr.Entity
    end
    
    -- Fallback: search nearby entities with bones
    local searchPos = ply:GetShootPos() + ply:GetForward() * (maxDist / 2)
    local nearby = ents.FindInSphere(searchPos, maxDist / 2)
    
    for _, ent in ipairs(nearby) do
        if ent == ply then continue end
        if IsValidBoneEntity(ent) then
            return ent
        end
    end
    
    return nil
end

-- ── Expose as global ─────────────────────────────────────────────────────────

_G.RagdollAnimator = RagdollAnimator

-- ── Console commands for testing ─────────────────────────────────────────────

concommand.Add("ragdoll_record_start", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end
    
    local recordName = args[1] or "test_record"
    local frameInterval = tonumber(args[2]) or 0.05

    local sourceArg = string.lower(tostring(args[3] or ""))
    local ent = nil
    if sourceArg == "player" or sourceArg == "self" or sourceArg == "me" then
        ent = ResolvePlayerRecordingSource(ply)
    else
        ent = FindAnimatableEntity(ply)
    end

    if not ent then
        ply:ChatPrint("[RagdollAnimator] No source found. Player mode requires you to be ragdolled.")
        return
    end

    local ok = RagdollAnimator:StartRecording(recordName, ent, frameInterval, nil, ply)
    if ok then
        ply:ChatPrint("[RagdollAnimator] Started: " .. recordName .. " on " .. tostring(ent:GetClass()) .. " #" .. ent:EntIndex())
    else
        ply:ChatPrint("[RagdollAnimator] Start failed: no recordable bones on target")
    end
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_record_stop", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end
    
    local recordName = args[1] or "test_record"
    local ok = RagdollAnimator:StopRecording(recordName)
    if ok then
        ply:ChatPrint("[RagdollAnimator] Stopped: " .. recordName)
    else
        ply:ChatPrint("[RagdollAnimator] Stop failed: recording not found or zero frames")
    end
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_record_player_start", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end

    local recordName = args[1] or "player_pose"
    local frameInterval = tonumber(args[2]) or 0.05
    local rag = ResolvePlayerRecordingSource(ply)
    if not IsValid(rag) then
        ply:ChatPrint("[RagdollAnimator] You must be ragdolled to record a floor animation.")
        RefreshStatusSoon(ply)
        return
    end

    local ok = RagdollAnimator:StartRecording(recordName, rag, frameInterval, nil, ply)
    if ok then
        ply:ChatPrint("[RagdollAnimator] Started recording PLAYER RAGDOLL movement: " .. recordName)
    else
        ply:ChatPrint("[RagdollAnimator] Start failed on player ragdoll")
    end
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_capture_idle_aim_pose", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end

    local recordName = tostring(args[1] or "player_pose")
    if recordName == "" then
        recordName = "player_pose"
    end

    local rag = ResolvePlayerRecordingSource(ply)
    if not IsValid(rag) then
        ply:ChatPrint("[RagdollAnimator] Idle pose capture needs your current fake ragdoll.")
        RefreshStatusSoon(ply)
        return
    end

    local ok = RagdollAnimator:CaptureIdleAimPose(recordName, rag, UPPER_BODY_BONES, ply)
    if ok then
        ply:ChatPrint("[RagdollAnimator] Captured idle upper-body aim pose: " .. recordName)
    else
        ply:ChatPrint("[RagdollAnimator] Idle pose capture failed")
    end
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_play", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end
    
    local recordName = args[1] or "test_record"
    local speed = tonumber(args[2]) or 1.0
    local loop = args[3] == "1" and true or false
    
    local ent = FindAnimatableEntity(ply)
    if not ent then
        ply:ChatPrint("[RagdollAnimator] No ragdoll/NPC entity found nearby")
        return
    end
    
    RagdollAnimator:PlayRecording(recordName, ent, speed, loop)
end)

concommand.Add("ragdoll_stop", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end
    
    local recordName = args[1] or "test_record"
    
    local ent = FindAnimatableEntity(ply)
    if not ent then
        ply:ChatPrint("[RagdollAnimator] No ragdoll/NPC entity found nearby")
        return
    end
    
    RagdollAnimator:StopPlayback(ent, recordName)
end)

concommand.Add("ragdoll_list", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end
    
    local names = RagdollAnimator:ListRecordings()
    if #names == 0 then
        ply:ChatPrint("[RagdollAnimator] No recordings available")
        return
    end
    
    ply:ChatPrint("[RagdollAnimator] Available recordings:")
    for _, name in ipairs(names) do
        local rec = recordings[name]
        if rec then
            ply:ChatPrint("  - " .. name .. " (" .. #rec.frames .. " frames @ " .. rec.fps .. " FPS)")
        end
    end
end)

concommand.Add("ragdoll_save", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end
    
    local recordName = args[1] or "test_record"
    RagdollAnimator:SaveRecordingToFile(recordName)
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_knockdown_mirror_set", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end

    local recordName = tostring(args[1] or "")
    if recordName == "" then
        ply:ChatPrint("[RagdollAnimator] Usage: ragdoll_knockdown_mirror_set <recording_name>")
        return
    end

    if RagdollAnimator:SetKnockdownMirrorRecording(recordName) then
        local applied = RagdollAnimator:ApplyMirrorToCurrentDowned()
        ply:ChatPrint("[RagdollAnimator] Knockdown mirror enabled: " .. recordName .. " (applied now to " .. tostring(applied) .. " downed NPCs)")
    else
        ply:ChatPrint("[RagdollAnimator] Mirror set failed: recording missing or empty")
    end
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_knockdown_mirror_front_set", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end

    local recordName = tostring(args[1] or "")
    if recordName == "" then
        ply:ChatPrint("[RagdollAnimator] Usage: ragdoll_knockdown_mirror_front_set <recording_name>")
        return
    end

    local ok, err = RagdollAnimator:SetKnockdownMirrorRecordingForFallSide("front", recordName)
    if ok then
        local applied = RagdollAnimator:ApplyMirrorToCurrentDowned()
        ply:ChatPrint("[RagdollAnimator] Front-fall mirror set: " .. recordName .. " (applied now to " .. tostring(applied) .. " downed NPCs)")
    else
        ply:ChatPrint("[RagdollAnimator] Front-fall mirror set failed: " .. tostring(err))
    end
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_knockdown_mirror_back_set", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end

    local recordName = tostring(args[1] or "")
    if recordName == "" then
        ply:ChatPrint("[RagdollAnimator] Usage: ragdoll_knockdown_mirror_back_set <recording_name>")
        return
    end

    local ok, err = RagdollAnimator:SetKnockdownMirrorRecordingForFallSide("back", recordName)
    if ok then
        local applied = RagdollAnimator:ApplyMirrorToCurrentDowned()
        ply:ChatPrint("[RagdollAnimator] Back-fall mirror set: " .. recordName .. " (applied now to " .. tostring(applied) .. " downed NPCs)")
    else
        ply:ChatPrint("[RagdollAnimator] Back-fall mirror set failed: " .. tostring(err))
    end
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_knockdown_mirror_clear", function(ply)
    if not ply:IsSuperAdmin() then return end
    RagdollAnimator:ClearKnockdownMirrorRecording()
    ply:ChatPrint("[RagdollAnimator] Knockdown mirror disabled")
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_knockdown_mirror_status", function(ply)
    if not ply:IsSuperAdmin() then return end
    local name = RagdollAnimator:GetKnockdownMirrorRecording()
    local front = IsValidMirrorRecording(knockdownMirrorFrontRecording) and knockdownMirrorFrontRecording or "none"
    local back = IsValidMirrorRecording(knockdownMirrorBackRecording) and knockdownMirrorBackRecording or "none"
    local fallback = name or "none"
    ply:ChatPrint("[RagdollAnimator] Knockdown mirrors: front=" .. front .. " | back=" .. back .. " | fallback=" .. fallback)
end)

concommand.Add("ragdoll_aim_target_spawn", function(ply)
    if not ply:IsSuperAdmin() then return end

    local ok = RagdollAnimator:SpawnAimCalibrationTarget(ply)
    if ok then
        ply:ChatPrint("[RagdollAnimator] Aim calibration target spawned at your crosshair")
    else
        ply:ChatPrint("[RagdollAnimator] Failed to spawn aim calibration target")
    end
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_aim_target_remove", function(ply)
    if not ply:IsSuperAdmin() then return end
    RagdollAnimator:RemoveAimCalibrationTarget()
    ply:ChatPrint("[RagdollAnimator] Aim calibration target removed")
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_aim_capture_start", function(ply)
    if not ply:IsSuperAdmin() then return end

    local ok, err = RagdollAnimator:StartAimCapture(ply)
    if ok then
        ply:ChatPrint("[RagdollAnimator] Aim data capture started")
    else
        ply:ChatPrint("[RagdollAnimator] Aim capture failed: " .. tostring(err))
    end
    RefreshStatusSoon(ply)
end)

concommand.Add("ragdoll_aim_capture_stop", function(ply)
    if not ply:IsSuperAdmin() then return end
    local samples = RagdollAnimator:StopAimCapture()
    local yawBias, pitchBias = RagdollAnimator:GetAimCaptureBias()
    ply:ChatPrint(string.format("[RagdollAnimator] Aim capture stopped: %d samples, yaw bias %.2f, pitch bias %.2f", samples, yawBias, pitchBias))
    RefreshStatusSoon(ply)
end)

net.Receive("RagdollAnimator_RequestStatus", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    SendStatus(ply)
end)

concommand.Add("ragdoll_aim_capture_status", function(ply)
    if not ply:IsSuperAdmin() then return end
    local s = RagdollAnimator:GetAimToolStatus()
    ply:ChatPrint(string.format("[RagdollAnimator] target=%s capturing=%s samples=%d yaw=%.2f pitch=%.2f", tostring(s.hasTarget), tostring(s.capturing), s.samples, s.yawBias, s.pitchBias))
end)

hook.Add("PlayerDisconnected", "ZC_RagdollAnimator_AimCaptureCleanup", function(ply)
    if IsValid(aimTool.capturePly) and aimTool.capturePly == ply then
        StopAimCapture()
    end
end)

hook.Add("PostCleanupMap", "ZC_RagdollAnimator_AimToolMapCleanup", function()
    StopAimCapture()
    RagdollAnimator:RemoveAimCalibrationTarget()
end)

print("[ZCity] Ragdoll Animator loaded")
