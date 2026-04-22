if CLIENT then return end

local TAG = "ZC_VehicleTeleportDebug"

local cvEnable = CreateConVar("zc_vdbg_enable", "0", FCVAR_ARCHIVE, "Enable vehicle teleport debug tracing.", 0, 1)
local cvJumpDist = CreateConVar("zc_vdbg_jump_dist", "900", FCVAR_ARCHIVE, "Distance in units between samples that is treated as a jump.", 64, 20000)
local cvVelSpike = CreateConVar("zc_vdbg_vel_spike", "5500", FCVAR_ARCHIVE, "Velocity spike threshold for logging.", 500, 50000)
local cvSample = CreateConVar("zc_vdbg_sample", "0.10", FCVAR_ARCHIVE, "Vehicle debug sample interval.", 0.03, 1.0)
local cvAutoTrackOccupied = CreateConVar("zc_vdbg_autotrack_occupied", "1", FCVAR_ARCHIVE, "Auto-track vehicles that currently have players seated.", 0, 1)
local cvFileLog = CreateConVar("zc_vdbg_filelog", "1", FCVAR_ARCHIVE, "Write debug events to data/zc_vehicle_teleport_debug.log.", 0, 1)
local cvAutoEnableOnWatch = CreateConVar("zc_vdbg_auto_enable_on_watch", "1", FCVAR_ARCHIVE, "Automatically enable zc_vdbg_enable when zc_vdbg_watch is used.", 0, 1)
local cvTraceSetPos = CreateConVar("zc_vdbg_trace_setpos", "1", FCVAR_ARCHIVE, "Trace Entity:SetPos and PhysObj:SetPos for watched vehicles and occupants.", 0, 1)
local cvTraceStack = CreateConVar("zc_vdbg_trace_stack", "0", FCVAR_ARCHIVE, "Include Lua stack snippets in SetPos trace logs.", 0, 1)
local cvPlayerJumpDist = CreateConVar("zc_vdbg_player_jump_dist", "300", FCVAR_ARCHIVE, "Player jump distance threshold while in watched vehicles.", 32, 10000)
local cvWrapProbeRadius = CreateConVar("zc_vdbg_wrap_probe_radius", "320", FCVAR_ARCHIVE, "Radius for nearby trigger/barrier probe logs around large teleport SetPos events.", 64, 2048)

local watched = {}
local nextSampleAt = 0
local trackedPlayers = {}

local function lowerClass(ent)
    if not IsValid(ent) then return "" end
    return string.lower(ent:GetClass() or "")
end

local function classLooksVehicle(cls)
    if cls == "" then return false end

    if string.find(cls, "vehicle", 1, true) then return true end
    if string.find(cls, "simfphys", 1, true) then return true end
    if string.find(cls, "gmod_sent_vehicle_fphysics", 1, true) then return true end
    if string.find(cls, "glide", 1, true) then return true end
    if string.find(cls, "lunasflightschool", 1, true) then return true end
    if string.find(cls, "wac_", 1, true) then return true end
    if string.find(cls, "aircraft", 1, true) then return true end
    if string.find(cls, "plane", 1, true) then return true end
    if string.find(cls, "heli", 1, true) then return true end
    if string.find(cls, "car", 1, true) then return true end

    return false
end

local function isVehicleLike(ent)
    if not IsValid(ent) then return false end
    if ent:IsVehicle() then return true end
    if ent.IsGlideVehicle == true then return true end

    local cls = lowerClass(ent)
    if cls == "prop_vehicle_prisoner_pod" then return true end
    if classLooksVehicle(cls) then return true end

    local parent = ent:GetParent()
    if not IsValid(parent) or parent == ent then return false end

    if parent:IsVehicle() then return true end
    if parent.IsGlideVehicle == true then return true end
    return classLooksVehicle(lowerClass(parent))
end

local function getVehicleRoot(ent)
    if not IsValid(ent) then return nil end

    if ent:IsVehicle() or ent.IsGlideVehicle == true then
        return ent
    end

    local parent = ent:GetParent()
    if IsValid(parent) and parent ~= ent then
        if parent:IsVehicle() or parent.IsGlideVehicle == true or classLooksVehicle(lowerClass(parent)) then
            return parent
        end
    end

    if isVehicleLike(ent) then return ent end
    return nil
end

local function findConstraintVehicle(ent)
    if not IsValid(ent) then return nil end
    if not constraint or not constraint.GetAllConstrainedEntities then return nil end

    local constrained = constraint.GetAllConstrainedEntities(ent)
    for cEnt in pairs(constrained or {}) do
        if IsValid(cEnt) and cEnt ~= ent and isVehicleLike(cEnt) then
            local root = getVehicleRoot(cEnt)
            if IsValid(root) then return root end
        end
    end

    return nil
end

local function collectCandidateRoots(ent)
    local out = {}
    local seen = {}

    local function add(e)
        if not IsValid(e) then return end
        local root = getVehicleRoot(e)
        if not IsValid(root) then return end

        local idx = root:EntIndex()
        if seen[idx] then return end
        seen[idx] = true
        out[#out + 1] = root
    end

    add(ent)

    if IsValid(ent) then
        local parent = ent:GetParent()
        add(parent)

        local cls = ent:GetClass() or ""
        if cls == "prop_vehicle_prisoner_pod" then
            local driver = ent.GetDriver and ent:GetDriver() or nil
            if IsValid(driver) then
                add(driver:GetVehicle())
                if driver.GlideGetVehicle then add(driver:GlideGetVehicle()) end
                if driver.GetNWEntity then add(driver:GetNWEntity("GlideVehicle")) end
            end

            add(findConstraintVehicle(ent))
        end
    end

    return out
end

local function who(ent)
    if not IsValid(ent) then return "[invalid]" end
    return string.format("#%d %s", ent:EntIndex(), ent:GetClass() or "?")
end

local function vecStr(v)
    if not isvector(v) then return "(nil)" end
    return string.format("(%.1f %.1f %.1f)", v.x, v.y, v.z)
end

local function isBarrierClass(cls)
    cls = string.lower(tostring(cls or ""))
    if cls == "" then return false end
    if string.find(cls, "trigger_", 1, true) == 1 then return true end
    if cls == "coop_mapend" then return true end
    if cls == "func_areaportal" then return true end
    if cls == "func_brush" then return true end
    if cls == "func_wall" then return true end
    if cls == "func_wall_toggle" then return true end
    if cls == "func_door" then return true end
    if cls == "func_door_rotating" then return true end
    return false
end

local function barrierEntInfo(ent, refPos)
    if not IsValid(ent) then return nil end
    local cls = ent:GetClass() or "?"
    if not isBarrierClass(cls) then return nil end

    local mn, mx = ent:WorldSpaceAABB()
    local center = mx - ((mx - mn) / 2)
    local dist = isvector(refPos) and center:Distance(refPos) or -1

    local name = ""
    if ent.GetName then name = tostring(ent:GetName() or "") end
    if name == "" then
        name = tostring(ent:GetInternalVariable("targetname") or "")
    end

    local hammer = -1
    if ent.MapCreationID then
        hammer = tonumber(ent:MapCreationID()) or -1
    end

    return {
        ent = ent,
        cls = cls,
        name = name,
        hammer = hammer,
        dist = dist,
        mins = mn,
        maxs = mx,
    }
end

local function logBarrierProbe(stage, pos)
    if not cvEnable:GetBool() then return end
    if not isvector(pos) then return end

    local radius = math.max(64, cvWrapProbeRadius:GetFloat())
    local found = {}
    for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
        local info = barrierEntInfo(ent, pos)
        if info then
            found[#found + 1] = info
        end
    end

    if #found == 0 then
        logLine(string.format("BARRIER_PROBE %s pos=%s radius=%.0f none", tostring(stage), vecStr(pos), radius))
        return
    end

    table.sort(found, function(a, b) return a.dist < b.dist end)
    local top = math.min(#found, 8)
    for i = 1, top do
        local f = found[i]
        logLine(string.format(
            "BARRIER_PROBE %s #%d %s name=%s hammer=%d dist=%.1f mins=%s maxs=%s",
            tostring(stage), f.ent:EntIndex(), f.cls, f.name ~= "" and f.name or "<none>",
            f.hammer, f.dist, vecStr(f.mins), vecStr(f.maxs)
        ))
    end
end

local function logLine(msg)
    local line = string.format("[%s] [%s] %s", os.date("%H:%M:%S"), TAG, msg)
    print(line)

    if cvFileLog:GetBool() then
        file.Append("zc_vehicle_teleport_debug.log", line .. "\n")
    end
end

local function isWatchedIndex(idx)
    return idx ~= nil and watched[idx] ~= nil
end

local function isWatchedRoot(ent)
    if not IsValid(ent) then return false end
    return isWatchedIndex(ent:EntIndex())
end

local function watchedVehicleForEntity(ent)
    if not IsValid(ent) then return nil end

    local roots = collectCandidateRoots(ent)
    for _, root in ipairs(roots) do
        if isWatchedRoot(root) then
            return root
        end
    end

    return nil
end

local function shortStack(skip)
    local s = debug.traceback("", (skip or 2))
    if not s then return "" end
    local lines = string.Explode("\n", s)
    local out = {}
    for i = 3, math.min(#lines, 8) do
        local line = string.Trim(lines[i] or "")
        if line ~= "" then
            out[#out + 1] = line
        end
    end
    return table.concat(out, " | ")
end

local function ensureWatched(ent, reason)
    local roots = collectCandidateRoots(ent)
    local primary = nil

    for _, root in ipairs(roots) do
        local idx = root:EntIndex()
        local snap = watched[idx]

        if snap then
            snap.ent = root
            snap.lastSeenAt = CurTime()
            snap.removedAt = nil
            if not primary then primary = root end
        else
            watched[idx] = {
                ent = root,
                idx = idx,
                className = root:GetClass() or "?",
                pos = root:GetPos(),
                vel = root:GetVelocity(),
                at = CurTime(),
                createdAt = CurTime(),
                lastSeenAt = CurTime(),
                removedAt = nil,
                removedLogged = false,
                lastJumpLog = 0,
                lastWorldLog = 0,
                lastVelLog = 0,
            }

            if cvEnable:GetBool() then
                logLine(string.format("TRACK start %s reason=%s pos=%s", who(root), reason or "manual", vecStr(root:GetPos())))
            end

            if not primary then primary = root end
        end
    end

    return primary
end

local function unwatch(ent, reason)
    local root = getVehicleRoot(ent)
    if not IsValid(root) then return end

    local idx = root:EntIndex()
    if watched[idx] then
        watched[idx] = nil
        if cvEnable:GetBool() then
            logLine(string.format("TRACK stop %s reason=%s", who(root), reason or "manual"))
        end
    end
end

local function sampleVehicle(snap, now)
    local ent = snap.ent
    if not IsValid(ent) then
        if not snap.removedLogged then
            snap.removedLogged = true
            snap.removedAt = snap.removedAt or now
            logLine(string.format("WATCH_LOST #%d %s", snap.idx or -1, snap.className or "?"))
        end
        return true
    end

    local pos = ent:GetPos()
    local vel = ent:GetVelocity()
    local dt = math.max(0.0001, now - snap.at)
    local dist = pos:Distance(snap.pos)

    if dist >= cvJumpDist:GetFloat() and (now - snap.lastJumpLog) >= 0.30 then
        local inWorld = util.IsInWorld(pos)
        local p = ent:GetParent()
        logLine(string.format(
            "JUMP %s dist=%.1f dt=%.3f old=%s new=%s vel=%s inWorld=%s parent=%s",
            who(ent), dist, dt, vecStr(snap.pos), vecStr(pos), vecStr(vel), tostring(inWorld), who(p)
        ))
        snap.lastJumpLog = now
    end

    if not util.IsInWorld(pos) and (now - snap.lastWorldLog) >= 0.50 then
        logLine(string.format("OUT_OF_WORLD %s pos=%s vel=%s", who(ent), vecStr(pos), vecStr(vel)))
        snap.lastWorldLog = now
    end

    if vel:Length() >= cvVelSpike:GetFloat() and (now - snap.lastVelLog) >= 0.25 then
        logLine(string.format("VEL_SPIKE %s speed=%.1f pos=%s", who(ent), vel:Length(), vecStr(pos)))
        snap.lastVelLog = now
    end

    snap.pos = pos
    snap.vel = vel
    snap.at = now
    snap.lastSeenAt = now
    snap.removedLogged = false
    return true
end

local function markPlayerTracked(ply, reason)
    if not IsValid(ply) then return end
    trackedPlayers[ply:EntIndex()] = {
        ply = ply,
        lastPos = ply:GetPos(),
        lastAt = CurTime(),
        reason = reason or "",
        lastJumpLog = 0,
    }
end

local function samplePlayers(now)
    for idx, info in pairs(trackedPlayers) do
        local ply = info.ply
        if not IsValid(ply) then
            trackedPlayers[idx] = nil
        else
            local pos = ply:GetPos()
            local dt = math.max(0.0001, now - (info.lastAt or now))
            local dist = pos:Distance(info.lastPos or pos)

            local seat = ply:InVehicle() and ply:GetVehicle() or nil
            local veh = watchedVehicleForEntity(seat)

            if not IsValid(veh) and not ply:InVehicle() and dt > 5 then
                trackedPlayers[idx] = nil
            else
                if dist >= cvPlayerJumpDist:GetFloat() and (now - (info.lastJumpLog or 0)) > 0.2 then
                    logLine(string.format(
                        "PLY_JUMP %s dist=%.1f dt=%.3f old=%s new=%s inVeh=%s veh=%s",
                        who(ply), dist, dt, vecStr(info.lastPos), vecStr(pos), tostring(ply:InVehicle()), who(veh)
                    ))
                    info.lastJumpLog = now
                end

                info.lastPos = pos
                info.lastAt = now
            end
        end
    end
end

local function autoTrackOccupiedVehicles()
    if not cvAutoTrackOccupied:GetBool() then return end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ply:InVehicle() then
            ensureWatched(ply:GetVehicle(), "occupied")
        end
    end
end

hook.Add("Think", TAG .. "_Think", function()
    if not cvEnable:GetBool() then return end

    local now = CurTime()
    if now < nextSampleAt then return end

    nextSampleAt = now + math.max(0.03, cvSample:GetFloat())
    autoTrackOccupiedVehicles()

    for idx, snap in pairs(watched) do
        if not sampleVehicle(snap, now) then
            watched[idx] = nil
        end
    end

    samplePlayers(now)
end)

hook.Add("PlayerEnteredVehicle", TAG .. "_Enter", function(ply, seat)
    if not cvEnable:GetBool() then return end
    local veh = ensureWatched(seat, "enter")
    if not IsValid(veh) then return end

    markPlayerTracked(ply, "enter")
    logLine(string.format("ENTER %s player=%s seat=%s", who(veh), IsValid(ply) and ply:Nick() or "?", who(seat)))
end)

hook.Add("PlayerLeaveVehicle", TAG .. "_Leave", function(ply, seat)
    if not cvEnable:GetBool() then return end
    local veh = getVehicleRoot(seat)
    if not IsValid(veh) then return end

    markPlayerTracked(ply, "leave")
    logLine(string.format("LEAVE %s player=%s seat=%s", who(veh), IsValid(ply) and ply:Nick() or "?", who(seat)))
end)

hook.Add("OnCrazyPhysics", TAG .. "_Crazy", function(ent, physobj)
    if not cvEnable:GetBool() then return end
    local veh = getVehicleRoot(ent)
    if not IsValid(veh) then return end

    ensureWatched(veh, "crazy_physics")
    local hasPhys = IsValid(physobj)
    logLine(string.format("CRAZY_PHYSICS ent=%s root=%s hasPhys=%s", who(ent), who(veh), tostring(hasPhys)))
end)

hook.Add("EntityTakeDamage", TAG .. "_Damage", function(target, dmg)
    if not cvEnable:GetBool() then return end

    local veh = nil
    if IsValid(target) and target:IsPlayer() and target:InVehicle() then
        veh = getVehicleRoot(target:GetVehicle())
    elseif isVehicleLike(target) then
        veh = getVehicleRoot(target)
    end

    if not IsValid(veh) then return end

    local infl = dmg:GetInflictor()
    local atk = dmg:GetAttacker()
    local infClass = IsValid(infl) and infl:GetClass() or "nil"
    local atkClass = IsValid(atk) and atk:GetClass() or "nil"

    logLine(string.format(
        "DAMAGE veh=%s target=%s dmg=%.1f type=%d inflictor=%s attacker=%s",
        who(veh), who(target), dmg:GetDamage(), dmg:GetDamageType(), infClass, atkClass
    ))
end)

hook.Add("EntityRemoved", TAG .. "_Removed", function(ent)
    if not ent or not ent.EntIndex then return end
    local idx = ent:EntIndex()
    local snap = watched[idx]
    if not snap then return end

    snap.ent = nil
    snap.removedAt = CurTime()
    if cvEnable:GetBool() then
        logLine(string.format("REMOVED #%d %s", idx, snap.className or "?"))
    end
end)

local function canUseCmd(ply)
    return not IsValid(ply) or ply:IsAdmin() or ply:IsSuperAdmin()
end

local function parseTargetFromArg(ply, arg)
    if not arg or arg == "" then return nil end

    local a = string.lower(arg)
    if a == "aim" and IsValid(ply) then
        local tr = ply:GetEyeTrace()
        return IsValid(tr.Entity) and tr.Entity or nil
    end

    local idx = tonumber(arg)
    if idx then
        local ent = Entity(math.floor(idx))
        return IsValid(ent) and ent or nil
    end

    return nil
end

concommand.Add("zc_vdbg_watch", function(ply, _, args)
    if not canUseCmd(ply) then return end

    local ent = parseTargetFromArg(ply, args[1])
    if not IsValid(ent) and IsValid(ply) and ply:InVehicle() then
        ent = ply:GetVehicle()
    end
    if not IsValid(ent) then
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, "[ZC_VDBG] No valid target. Use: zc_vdbg_watch <entindex|aim>\n") end
        return
    end

    if cvAutoEnableOnWatch:GetBool() and not cvEnable:GetBool() then
        cvEnable:SetBool(true)
        if IsValid(ply) then
            ply:PrintMessage(HUD_PRINTCONSOLE, "[ZC_VDBG] zc_vdbg_enable auto-set to 1.\n")
        end
    end

    local root = ensureWatched(ent, "manual")
    if not IsValid(root) then
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, "[ZC_VDBG] Target is not vehicle-like.\n") end
        return
    end

    if IsValid(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, string.format("[ZC_VDBG] Watching %s (#%d).\n", root:GetClass(), root:EntIndex()))
    end
end)

concommand.Add("zc_vdbg_unwatch", function(ply, _, args)
    if not canUseCmd(ply) then return end

    local ent = parseTargetFromArg(ply, args[1])
    if not IsValid(ent) and IsValid(ply) and ply:InVehicle() then
        ent = ply:GetVehicle()
    end
    if not IsValid(ent) then return end

    unwatch(ent, "manual")
end)

concommand.Add("zc_vdbg_clear", function(ply)
    if not canUseCmd(ply) then return end
    watched = {}
    if IsValid(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZC_VDBG] Cleared watch list.\n")
    end
end)

concommand.Add("zc_vdbg_list", function(ply)
    if not canUseCmd(ply) then return end

    local n = 0
    for _, snap in pairs(watched) do
        n = n + 1

        local line
        if IsValid(snap.ent) then
            line = string.format("[ZC_VDBG] #%d %s state=valid pos=%s\n", snap.ent:EntIndex(), snap.ent:GetClass(), vecStr(snap.ent:GetPos()))
        else
            line = string.format("[ZC_VDBG] #%d %s state=invalid removedAt=%.2f\n", snap.idx or -1, snap.className or "?", snap.removedAt or -1)
        end

        if IsValid(ply) then
            ply:PrintMessage(HUD_PRINTCONSOLE, line)
        else
            print(line)
        end
    end

    if n == 0 and IsValid(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZC_VDBG] Watch list is empty.\n")
    end
end)

do
    local entMeta = FindMetaTable("Entity")
    local oldSetPos = entMeta and entMeta.SetPos
    if entMeta and oldSetPos and not entMeta.__ZC_VDBG_SetPosWrapped then
        entMeta.__ZC_VDBG_SetPosWrapped = true
        entMeta.SetPos = function(self, pos, ...)
            local doTrace = cvEnable:GetBool() and cvTraceSetPos:GetBool()
            if doTrace and IsValid(self) then
                local veh = watchedVehicleForEntity(self)
                local isTrackedPlayer = self:IsPlayer() and trackedPlayers[self:EntIndex()] ~= nil
                if IsValid(veh) or isTrackedPlayer then
                    local from = self:GetPos()
                    local dist = isvector(from) and isvector(pos) and from:Distance(pos) or 0
                    local stack = cvTraceStack:GetBool() and shortStack(3) or ""
                    logLine(string.format(
                        "TRACE SetPos ent=%s from=%s to=%s veh=%s%s",
                        who(self), vecStr(from), vecStr(pos), who(veh), stack ~= "" and (" stack=" .. stack) or ""
                    ))

                    if IsValid(veh) and self == veh and dist >= cvJumpDist:GetFloat() then
                        logBarrierProbe("from", from)
                        logBarrierProbe("to", pos)
                    end
                end
            end

            return oldSetPos(self, pos, ...)
        end
    end

    local physMeta = FindMetaTable("PhysObj")
    local oldPhysSetPos = physMeta and physMeta.SetPos
    if physMeta and oldPhysSetPos and not physMeta.__ZC_VDBG_SetPosWrapped then
        physMeta.__ZC_VDBG_SetPosWrapped = true
        physMeta.SetPos = function(self, pos, ...)
            local doTrace = cvEnable:GetBool() and cvTraceSetPos:GetBool()
            if doTrace and self.GetEntity then
                local ent = self:GetEntity()
                if IsValid(ent) then
                    local veh = watchedVehicleForEntity(ent)
                    if IsValid(veh) then
                        local from = ent:GetPos()
                        local stack = cvTraceStack:GetBool() and shortStack(3) or ""
                        logLine(string.format(
                            "TRACE PhysSetPos ent=%s from=%s to=%s veh=%s%s",
                            who(ent), vecStr(from), vecStr(pos), who(veh), stack ~= "" and (" stack=" .. stack) or ""
                        ))
                    end
                end
            end

            return oldPhysSetPos(self, pos, ...)
        end
    end
end
