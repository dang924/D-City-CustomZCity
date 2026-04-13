util.AddNetworkString("hg_wep_tuner_apply")

local function CanTune(ply)
    return IsValid(ply) and ply:IsPlayer() and (ply:IsAdmin() or game.SinglePlayer())
end

local function ClampNumber(v, minV, maxV, fallback)
    v = tonumber(v)
    if v == nil then v = fallback or 0 end
    return math.Clamp(v, minV, maxV)
end

local function ApplyVec3(wep, field, tbl, minV, maxV)
    if wep[field] == nil or not istable(tbl) then return end
    local cur = wep[field]
    wep[field] = Vector(
        ClampNumber(tbl.x, minV, maxV, cur[1] or 0),
        ClampNumber(tbl.y, minV, maxV, cur[2] or 0),
        ClampNumber(tbl.z, minV, maxV, cur[3] or 0)
    )
end

local function ApplyAng3(wep, field, tbl, minV, maxV)
    if wep[field] == nil or not istable(tbl) then return end
    local cur = wep[field]
    wep[field] = Angle(
        ClampNumber(tbl.p, minV, maxV, cur[1] or 0),
        ClampNumber(tbl.y, minV, maxV, cur[2] or 0),
        ClampNumber(tbl.r, minV, maxV, cur[3] or 0)
    )
end

net.Receive("hg_wep_tuner_apply", function(_, ply)
    if not CanTune(ply) then return end

    local cfg = net.ReadTable() or {}
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end

    if isstring(cfg.class) and cfg.class ~= "" and wep:GetClass() ~= cfg.class then
        return
    end

    ApplyVec3(wep, "ZoomPos", cfg.ZoomPos, -64, 64)
    ApplyVec3(wep, "FakePos", cfg.FakePos, -64, 64)
    ApplyAng3(wep, "FakeAng", cfg.FakeAng, -180, 180)
    ApplyVec3(wep, "AttachmentPos", cfg.AttachmentPos, -32, 32)
    ApplyAng3(wep, "AttachmentAng", cfg.AttachmentAng, -180, 180)
    ApplyVec3(wep, "LocalMuzzlePos", cfg.LocalMuzzlePos, -64, 64)
    ApplyAng3(wep, "LocalMuzzleAng", cfg.LocalMuzzleAng, -180, 180)

    if wep.TraceAngOffset ~= nil and istable(cfg.TraceAngOffset) then
        local tr = cfg.TraceAngOffset
        local pitch = ClampNumber(tr.p, -30, 30, wep.TraceAngOffset[1] or 0)
        local yaw = ClampNumber(tr.y, -30, 30, wep.TraceAngOffset[2] or 0)

        wep.TraceAngOffset = Angle(pitch, yaw, 0)

        if wep.GarandTracePitch ~= nil then wep.GarandTracePitch = pitch end
        if wep.GarandTraceYaw ~= nil then wep.GarandTraceYaw = yaw end

        wep:SetNWFloat("GarandTracePitch", pitch)
        wep:SetNWFloat("GarandTraceYaw", yaw)
        ply:SetNWFloat("GarandTracePitch", pitch)
        ply:SetNWFloat("GarandTraceYaw", yaw)
    end

    if wep.GarandTraceMultiplier ~= nil and cfg.GarandTraceMultiplier ~= nil then
        local mul = ClampNumber(cfg.GarandTraceMultiplier, 0.1, 20, wep.GarandTraceMultiplier)
        wep.GarandTraceMultiplier = mul
        wep:SetNWFloat("GarandTraceMultiplier", mul)
        ply:SetNWFloat("GarandTraceMultiplier", mul)
    end

    if wep.GarandUseADSTrace ~= nil and cfg.GarandUseADSTrace ~= nil then
        local v = tobool(cfg.GarandUseADSTrace)
        wep.GarandUseADSTrace = v
        wep:SetNWBool("GarandUseADSTrace", v)
    end

    if wep.GarandEnableTraceOffset ~= nil and cfg.GarandEnableTraceOffset ~= nil then
        local v = tobool(cfg.GarandEnableTraceOffset)
        wep.GarandEnableTraceOffset = v
        wep:SetNWBool("GarandEnableTraceOffset", v)
    end
end)
