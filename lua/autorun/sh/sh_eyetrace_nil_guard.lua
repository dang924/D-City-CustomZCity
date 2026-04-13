-- Hardens hg.eyeTrace so callers always receive a trace table.
-- Prevents nil-index crashes in hooks that assume tr/eyetr is valid.

local function BuildFallbackTrace(ply, dist, ent, aimVector, startPos, filterOverride)
    local start = vector_origin
    local dir = vector_forward

    if IsValid(ply) and ply.EyePos then
        start = startPos or ply:EyePos()
        if not isvector(start) then
            start = ply:EyePos()
        end

        if isvector(aimVector) then
            dir = aimVector
        elseif ply.GetAimVector then
            dir = ply:GetAimVector()
        end
    elseif isvector(startPos) then
        start = startPos
        if isvector(aimVector) then
            dir = aimVector
        end
    end

    if not isvector(dir) or dir:LengthSqr() <= 0 then
        dir = vector_forward
    end

    local range = tonumber(dist) or 60
    if range < 1 then range = 1 end

    local tr = util.TraceLine({
        start = start,
        endpos = start + dir * range,
        filter = filterOverride or {ply, ent},
    })

    if not istable(tr) then
        tr = {}
    end

    tr.Entity = tr.Entity or NULL
    tr.StartPos = tr.StartPos or start
    tr.HitPos = tr.HitPos or (start + dir * range)
    tr.MatType = tr.MatType or MAT_CONCRETE

    return tr
end

local function InstallEyeTraceGuard()
    if not hg or not isfunction(hg.eyeTrace) then return false end
    if hg._DCPatch_EyeTraceNilGuard then return true end

    local originalEyeTrace = hg.eyeTrace

    hg.eyeTrace = function(ply, dist, ent, aimVector, startPos, filterOverride)
        local ok, tr, trace, headm = pcall(originalEyeTrace, ply, dist, ent, aimVector, startPos, filterOverride)

        if not ok then
            return BuildFallbackTrace(ply, dist, ent, aimVector, startPos, filterOverride)
        end

        if not istable(tr) then
            return BuildFallbackTrace(ply, dist, ent, aimVector, startPos, filterOverride), trace, headm
        end

        -- Normalize key fields expected by older hooks.
        tr.Entity = tr.Entity or NULL
        tr.HitPos = tr.HitPos or tr.StartPos or (isvector(startPos) and startPos or vector_origin)
        tr.MatType = tr.MatType or MAT_CONCRETE

        return tr, trace, headm
    end

    hg._DCPatch_EyeTraceNilGuard = true
    print("[DCityPatch] Installed hg.eyeTrace nil guard")
    return true
end

if not InstallEyeTraceGuard() then
    hook.Add("InitPostEntity", "DCityPatch_EyeTraceNilGuardInit", function()
        if InstallEyeTraceGuard() then return end

        timer.Create("DCityPatch_EyeTraceNilGuardRetry", 1, 20, function()
            if InstallEyeTraceGuard() then
                timer.Remove("DCityPatch_EyeTraceNilGuardRetry")
            end
        end)
    end)
end
