-- ZScav Bodycam System - admin debug utilities.
-- Use these to figure out why a feed isn't lighting up:
--   zscav_bodycam_debug                    -- dump full state
--   zscav_bodycam_force <player|all>       -- force-consent, score-spike, ignore safe-zone
--   zscav_bodycam_unforce <player|all>     -- clear forced state
--   zscav_bodycam_score <player> <amount>  -- bump activity score for testing
--   zscav_bodycam_offset_set ...           -- live-tune bodycam mount offsets
--   zscav_bodycam_offset_print [player]    -- print current mount config/effective transform
--   zscav_bodycam_offset_reset             -- restore default mount config

local BC = ZSCAV.Bodycam

local function adminOnly(ply)
    if not IsValid(ply) then return true end
    if ply:IsAdmin() or ply:IsSuperAdmin() then return true end
    ply:ChatPrint("[Bodycam] Admin only.")
    return false
end

local function emit(ply, msg)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end

local function fmtVec(vec)
    if not isvector(vec) then return "(nil)" end
    return string.format("(%.2f, %.2f, %.2f)", vec.x, vec.y, vec.z)
end

local function syncOffsetStateNet(ply)
    if not IsValid(ply) then return end

    local state = BC.GetCameraTuneState and BC:GetCameraTuneState() or {
        mountBone = tostring(BC.CAMERA_BONE or ""),
        baseOffset = BC.CAMERA_OFFSET or Vector(0, 0, 0),
        crouchOffset = BC.CAMERA_CROUCH_OFFSET or Vector(0, 0, 0),
    }

    net.Start("ZScav_Bodycam_OffsetStateSync")
        net.WriteString(tostring(state.mountBone or ""))
        net.WriteVector(state.baseOffset or Vector(0, 0, 0))
        net.WriteVector(state.crouchOffset or Vector(0, 0, 0))
    net.Send(ply)
end

local function printOffsetState(ply, target)
    local baseOffset = BC.GetCameraBaseOffset and BC:GetCameraBaseOffset() or BC.CAMERA_OFFSET or Vector(0, 0, 0)
    local crouchOffset = BC.GetCameraCrouchOffset and BC:GetCameraCrouchOffset() or BC.CAMERA_CROUCH_OFFSET or Vector(0, 0, 0)
    local mountBone = BC.GetConfiguredMountBone and BC:GetConfiguredMountBone() or tostring(BC.CAMERA_BONE or "")

    emit(ply, string.format(
        "[Bodycam] mountBone=%s baseOffset=%s crouchOffset=%s",
        mountBone ~= "" and mountBone or "<auto>",
        fmtVec(baseOffset),
        fmtVec(crouchOffset)
    ))
    emit(ply, string.format(
        "[Bodycam] tune cmd: zscav_bodycam_offset_set %.2f %.2f %.2f %.2f %.2f %.2f %s",
        baseOffset.x, baseOffset.y, baseOffset.z,
        crouchOffset.x, crouchOffset.y, crouchOffset.z,
        mountBone ~= "" and mountBone or tostring(BC.CAMERA_BONE or "ValveBiped.Bip01_Spine4")
    ))

    if not IsValid(target) then return end
    if not BC.GetCameraTransform then return end

    local pos, ang, mount, offset = BC:GetCameraTransform(target)
    if not pos then return end

    local mountEnt = mount and mount.entity or nil
    local mountEntLabel = IsValid(mountEnt) and string.format("%s#%d", mountEnt:GetClass(), mountEnt:EntIndex()) or "nil"

    emit(ply, string.format(
        "[Bodycam] %s crouching=%s mount=%s mountEnt=%s offsetUsed=%s fallback=%s",
        target:Nick(),
        tostring(target:Crouching()),
        mount and mount.boneName or "?",
        mountEntLabel,
        fmtVec(offset),
        tostring(mount and mount.fallback or false)
    ))
    emit(ply, string.format(
        "[Bodycam] %s camPos=%s eyeAng=(%.1f, %.1f, %.1f)",
        target:Nick(),
        fmtVec(pos),
        ang.p,
        ang.y,
        ang.r
    ))
end

net.Receive("ZScav_Bodycam_OffsetStateRequest", function(_len, ply)
    if not adminOnly(ply) then return end
    syncOffsetStateNet(ply)
end)

net.Receive("ZScav_Bodycam_OffsetStateApply", function(_len, ply)
    if not adminOnly(ply) then return end

    local mountBone = string.sub(string.Trim(net.ReadString() or ""), 1, 128)
    local baseOffset = net.ReadVector()
    local crouchOffset = net.ReadVector()
    local shouldPrint = net.ReadBool()

    if BC.SetCameraTuneState then
        BC:SetCameraTuneState({
            mountBone = mountBone,
            baseOffset = baseOffset,
            crouchOffset = crouchOffset,
        })
    end

    syncOffsetStateNet(ply)

    if shouldPrint then
        printOffsetState(ply, IsValid(ply) and ply or nil)
    end
end)

local function findPlayer(token)
    if token == "all" or token == "*" then return "all" end
    if token == "me" then return nil end  -- caller handles "me"
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), string.lower(token), 1, true) then
            return p
        end
        if p:SteamID() == token or p:SteamID64() == token then return p end
    end
    return nil
end

-- =========================================================================
-- zscav_bodycam_debug
-- =========================================================================
concommand.Add("zscav_bodycam_debug", function(ply)
    if not adminOnly(ply) then return end

    emit(ply, string.format("[Bodycam] === DEBUG STATE === active=%s",
        tostring(BC:IsActive())))
    printOffsetState(ply, IsValid(ply) and ply or nil)

    -- Consent map
    local consenters = 0
    for sid, state in pairs(BC.Consent) do
        local p = player.GetBySteamID64(sid)
        local nick = IsValid(p) and p:Nick() or sid
        emit(ply, string.format("  consent[%s] = %d  alive=%s  inSafe=%s",
            nick, state,
            IsValid(p) and tostring(p:Alive()) or "?",
            IsValid(p) and tostring(BC:IsPlayerInSafeZone(p)) or "?"))
        if state == BC.CONSENT_ALLOW then consenters = consenters + 1 end
    end
    emit(ply, string.format("  -> %d ALLOW", consenters))

    -- Cameras
    local cams = 0
    for sid, cam in pairs(BC.PlyCam) do
        if IsValid(cam) then
            cams = cams + 1
            local mountEnt = cam.zscav_bodycam_mount_entity
            local mountEntLabel = IsValid(mountEnt) and string.format("%s#%d", mountEnt:GetClass(), mountEnt:EntIndex()) or "nil"
            emit(ply, string.format("  camera[%s] id=%s pos=%s mount=%s attached=%s fallback=%s",
                sid,
                cam:GetID(),
                tostring(cam:GetPos()),
                tostring(cam.zscav_bodycam_mount_bone or "?") .. " @ " .. mountEntLabel,
                tostring(cam.zscav_bodycam_attached or false),
                tostring(cam.zscav_bodycam_mount_fallback or false)))
        end
    end
    emit(ply, string.format("  -> %d cameras alive", cams))

    -- Scores
    local scoreCount = 0
    for sid, s in pairs(BC.Scores) do
        scoreCount = scoreCount + 1
        local p = player.GetBySteamID64(sid)
        local nick = IsValid(p) and p:Nick() or sid
        emit(ply, string.format("  score[%s] = %.1f", nick, s))
    end
    emit(ply, string.format("  -> %d scoring", scoreCount))

    -- Assignments
    emit(ply, "  --- monitor slot assignments ---")
    for idx = 1, BC.MONITOR_COUNT do
        local slot = BC.Assigns[idx]
        if slot then
            local p = player.GetBySteamID64(slot.sid64)
            local nick = IsValid(p) and p:Nick() or slot.sid64
            emit(ply, string.format("    slot %d -> %s  audio=%s  expectedID=%s",
                idx, nick, tostring(slot.audio), BC:MonitorID(idx)))
        else
            emit(ply, string.format("    slot %d : (empty)", idx))
        end
    end

    -- Monitor entities found in world
    emit(ply, "  --- world monitor entities matching expected IDs ---")
    if SERVER then
        local found = {}
        for _, ent in ipairs(ents.FindByClass("gmod_ultimate_rttv")) do
            local actual = ent:GetActualID()
            for idx = 1, BC.MONITOR_COUNT do
                if actual == BC:MonitorActualID(idx) then
                    found[idx] = ent
                end
            end
        end
        local missing = {}
        local privateWarnings = {}
        for idx = 1, BC.MONITOR_COUNT do
            local m = found[idx]
            if m then
                local full = m:GetID() or ""
                local mode = "GLOBAL"
                if full:sub(1, 2) == "P_"  then mode = "PRIVATE" end
                if full:sub(1, 3) == "CP_" then mode = "LOCAL/CONTRAPTION" end
                if mode == "PRIVATE" or mode == "LOCAL/CONTRAPTION" then
                    privateWarnings[#privateWarnings + 1] = idx
                end
                emit(ply, string.format("    monitor %d FOUND  fullID=%s  mode=%s",
                    idx, full, mode))
            else
                missing[#missing + 1] = idx
            end
        end
        if #missing > 0 then
            emit(ply, string.format("    MISSING monitors for slots: %s",
                table.concat(missing, ", ")))
            emit(ply, "    (place gmod_ultimate_rttv with ID Mode = Global,")
            emit(ply, "     ID = zscavmonitor1 ... zscavmonitor12)")
        end
        if #privateWarnings > 0 then
            emit(ply, string.format(
                "    WARNING: monitors %s are in PRIVATE/LOCAL mode -- they only render for the player who placed them.",
                table.concat(privateWarnings, ", ")))
            emit(ply, "    For safe-zone broadcasts, re-place those monitors with ID Mode = Global.")
        end
    end

    emit(ply, "[Bodycam] === END DEBUG ===")
end)

-- =========================================================================
-- zscav_bodycam_force <ply|all>
-- Force-grants consent, ignores safe-zone gating, and pumps a high activity
-- score so the target appears on a monitor immediately.
-- =========================================================================
concommand.Add("zscav_bodycam_force", function(ply, _cmd, args)
    if not adminOnly(ply) then return end
    local arg = args[1]
    if not arg or arg == "" then
        emit(ply, "Usage: zscav_bodycam_force <playername|me|all>")
        return
    end

    local function force(target)
        if not IsValid(target) then return end
        BC:SetConsent(target, true)
        BC.Scores[target:SteamID64()] = 9999
        target.zscav_bodycam_force = true
        emit(ply, string.format("[Bodycam] Forced consent + max score for %s.", target:Nick()))
    end

    if arg == "me" then force(ply)
    elseif arg == "all" then
        for _, p in ipairs(player.GetAll()) do force(p) end
    else
        local target = findPlayer(arg)
        if target == "all" then
            for _, p in ipairs(player.GetAll()) do force(p) end
        elseif IsValid(target) then force(target)
        else emit(ply, "[Bodycam] Player not found: " .. arg) end
    end
end)

concommand.Add("zscav_bodycam_unforce", function(ply, _cmd, args)
    if not adminOnly(ply) then return end
    local arg = args[1] or "all"

    local function unforce(target)
        if not IsValid(target) then return end
        target.zscav_bodycam_force = nil
        BC:SetConsent(target, false)
        BC.Scores[target:SteamID64()] = nil
        emit(ply, string.format("[Bodycam] Cleared force for %s.", target:Nick()))
    end

    if arg == "me" then unforce(ply)
    elseif arg == "all" then
        for _, p in ipairs(player.GetAll()) do unforce(p) end
    else
        local target = findPlayer(arg)
        if IsValid(target) then unforce(target)
        else emit(ply, "[Bodycam] Player not found: " .. arg) end
    end
end)

-- =========================================================================
-- zscav_bodycam_score <ply|me> <amount>
-- =========================================================================
concommand.Add("zscav_bodycam_score", function(ply, _cmd, args)
    if not adminOnly(ply) then return end
    local who = args[1] or "me"
    local amt = tonumber(args[2] or "100") or 100

    local target = (who == "me") and ply or findPlayer(who)
    if not IsValid(target) then
        emit(ply, "[Bodycam] Player not found: " .. tostring(who))
        return
    end

    BC.Scores[target:SteamID64()] = (BC.Scores[target:SteamID64()] or 0) + amt
    emit(ply, string.format("[Bodycam] %s score now %.1f.", target:Nick(), BC.Scores[target:SteamID64()]))
end)

concommand.Add("zscav_bodycam_offset_print", function(ply, _cmd, args)
    if not adminOnly(ply) then return end

    local who = args[1] or "me"
    local target = nil

    if who == "me" then
        target = ply
    elseif who ~= "" and who ~= "all" then
        target = findPlayer(who)
    end

    if who ~= "me" and who ~= "" and who ~= "all" and not IsValid(target) then
        emit(ply, "[Bodycam] Player not found: " .. tostring(who))
        return
    end

    printOffsetState(ply, target)
end)

concommand.Add("zscav_bodycam_offset_set", function(ply, _cmd, args)
    if not adminOnly(ply) then return end

    local fwd = tonumber(args[1])
    local right = tonumber(args[2])
    local up = tonumber(args[3])
    local crouchFwd = tonumber(args[4]) or 0
    local crouchRight = tonumber(args[5]) or 0
    local crouchUp = tonumber(args[6]) or 0
    local boneName = string.Trim(tostring(args[7] or ""))

    if not fwd or not right or not up then
        emit(ply, "Usage: zscav_bodycam_offset_set <forward> <right> <up> [crouchForward] [crouchRight] [crouchUp] [bone]")
        return
    end

    if BC.SetCameraTuneState then
        BC:SetCameraTuneState({
            mountBone = boneName,
            baseOffset = Vector(fwd, right, up),
            crouchOffset = Vector(crouchFwd, crouchRight, crouchUp),
        })
    end

    printOffsetState(ply, IsValid(ply) and ply or nil)
    syncOffsetStateNet(ply)
end)

concommand.Add("zscav_bodycam_offset_reset", function(ply)
    if not adminOnly(ply) then return end

    if BC.ResetCameraTuneState then
        BC:ResetCameraTuneState()
    end

    printOffsetState(ply, IsValid(ply) and ply or nil)
    syncOffsetStateNet(ply)
end)

