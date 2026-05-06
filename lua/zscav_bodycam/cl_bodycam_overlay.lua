-- ZScav Bodycam System - client overlay for safe-zone monitors.
-- Draws an EKG strip + heart-rate label over each monitor when its broadcaster
-- is in critical condition (low HP or otrub/bleeding-out).
--
-- Hooks PostDrawTranslucentRenderables so we render after the monitor's own
-- 3D2D pass (which runs in the entity's Draw / opaque pass) but before
-- post-process. Reuses each monitor model's RTMonitorModels meta for
-- positioning so the overlay sits flush on the screen.

local BC = ZSCAV.Bodycam

local CRITICAL_HP_RATIO = 0.20  -- below this, draw EKG even if not otrub

surface.CreateFont("ZScavBodycamEKG", {
    font = "Trebuchet MS",
    size = 32,
    weight = 700,
    antialias = true,
})

local function shouldShowEKG(slot)
    if not slot then return false end
    if slot.otrub then return true end
    if slot.hp <= CRITICAL_HP_RATIO then return true end
    return false
end

-- A continuous EKG trace. Speed and amplitude vary by state:
--   otrub        : fast, irregular, bright red
--   low HP only  : moderate, regular, amber
local function drawEKG(slot, baseW, baseH)
    local color, hzMul, ampMul, label
    if slot.otrub then
        color  = Color(220, 38, 38, 230)
        hzMul  = 1.6
        ampMul = 1.0
        label  = "BLEEDOUT"
    else
        color  = Color(245, 158, 11, 230)
        hzMul  = 1.0
        ampMul = 0.7
        label  = "CRITICAL"
    end

    -- Strip at the bottom 18% of the monitor's drawn area.
    local stripH = baseH * 0.18
    local stripY = baseH * 0.5 - stripH  -- bottom edge in 3D2D (centered coords)
    local stripX = -baseW * 0.5
    local stripW = baseW

    -- Background: dark translucent bar
    surface.SetDrawColor(0, 0, 0, 170)
    surface.DrawRect(stripX, stripY, stripW, stripH)

    -- Sample a synthetic ECG waveform across the strip
    local t = CurTime() * hzMul
    local segments = 80
    local prevX, prevY
    for i = 0, segments do
        local x = stripX + (i / segments) * stripW
        -- Walk a phase that wraps into PQRST-ish bumps
        local phase = (i / segments) * 6 + t * 4
        local frac = phase - math.floor(phase)
        local y
        if frac < 0.10 then
            y = -math.sin(frac / 0.10 * math.pi) * 0.15  -- P wave
        elseif frac < 0.16 then
            y = (frac - 0.10) / 0.06 * -1.0              -- Q dip
        elseif frac < 0.20 then
            y = -1.0 + (frac - 0.16) / 0.04 * 2.4        -- R spike
        elseif frac < 0.26 then
            y = 1.4 - (frac - 0.20) / 0.06 * 2.0         -- S
        elseif frac < 0.42 then
            y = -0.6 + (frac - 0.26) / 0.16 * 0.6        -- back to baseline
        elseif frac < 0.55 then
            y = math.sin((frac - 0.42) / 0.13 * math.pi) * 0.4  -- T wave
        else
            y = 0
        end
        if slot.otrub then
            -- Add jitter to feel agonal
            y = y + (math.Rand(-0.15, 0.15))
        end

        local pixelY = stripY + stripH * 0.5 - y * (stripH * 0.4) * ampMul
        if prevX then
            surface.SetDrawColor(color.r, color.g, color.b, color.a)
            surface.DrawLine(prevX, prevY, x, pixelY)
            -- thickness via parallel lines
            surface.DrawLine(prevX, prevY + 1, x, pixelY + 1)
        end
        prevX, prevY = x, pixelY
    end

    -- Status label, top-left of the strip
    draw.SimpleText(label, "ZScavBodycamEKG", stripX + 16, stripY + 8, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- HP percentage, top-right of the strip
    local hpPct = math.floor((slot.hp or 0) * 100)
    draw.SimpleText(hpPct .. "%", "ZScavBodycamEKG", stripX + stripW - 16, stripY + 8, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

-- The monitor's Draw method already calls cam.Start3D2D with the model meta;
-- by the time we run, that pass is done. We open a fresh 3D2D pass with the
-- same meta to draw the overlay.
local function getMonitorMeta(monitor)
    if not list or not list.GetEntry then return nil end
    return list.GetEntry("RTMonitorModels", monitor:GetModel())
end

local function drawOverlayForMonitor(idx, monitor, slot)
    if not shouldShowEKG(slot) then return end
    local meta = getMonitorMeta(monitor)
    if not meta then return end

    local origin = monitor:LocalToWorld(meta.offset)
    local angles = monitor:LocalToWorldAngles(meta.ang)

    local baseW = 512 * (meta.ratio or 1)
    local baseH = 512

    cam.Start3D2D(origin, angles, meta.scale)
        drawEKG(slot, baseW, baseH)
    cam.End3D2D()
end

-- Cached lookup of monitors by index; refreshed every 2s or when the cache
-- entry goes invalid (entity removed / not yet spawned).
local monitorCache = {}
local nextScan = 0

local function getMonitor(idx)
    local actualID = BC:MonitorActualID(idx)
    local cached = monitorCache[idx]
    if IsValid(cached) and cached:GetActualID() == actualID then
        return cached
    end
    monitorCache[idx] = nil

    local now = RealTime()
    if now < nextScan and cached == false then return nil end
    nextScan = now + 2

    for _, ent in ipairs(ents.FindByClass("gmod_ultimate_rttv")) do
        if ent:GetActualID() == actualID then
            monitorCache[idx] = ent
            ent.IsActive = true  -- force-on so it renders without USE
            return ent
        end
    end
    monitorCache[idx] = false  -- mark missing so we don't rescan immediately
    return nil
end

hook.Add("PostDrawTranslucentRenderables", "ZScav_Bodycam_Overlay", function(_depth, _skybox, _3dskybox)
    if _skybox or _3dskybox then return end
    local slots = BC._slots
    if not slots then return end

    for idx = 1, BC.MONITOR_COUNT do
        local slot = slots[idx]
        if not slot then continue end
        if not IsValid(slot.camOwner) then continue end
        local monitor = getMonitor(idx)
        if not IsValid(monitor) then continue end
        drawOverlayForMonitor(idx, monitor, slot)
    end
end)
