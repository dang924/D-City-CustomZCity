-- ZScav Bodycam System - client-side audio playback at safe-zone monitors.
-- Receives "play sound at monitor N" and "director update" net messages, then
-- plays audio at the monitor entity's position with bodycam-style filtering
-- (lower pitch, reduced volume, extra noise floor).

local BC = ZSCAV.Bodycam

BC._slots = BC._slots or {}  -- [monitorIdx] = { camOwner, audio, hp, otrub }

-- Cached lookup of monitor entities by ID, refreshed lazily.
local monitorEntCache = {}
local function getMonitorEntByIndex(idx)
    local id = BC:MonitorID(idx)
    local cached = monitorEntCache[id]
    if IsValid(cached) and cached:GetClass() == "gmod_ultimate_rttv" then return cached end
    monitorEntCache[id] = nil
    local actualID = BC:MonitorActualID(idx)
    for _, ent in ipairs(ents.FindByClass("gmod_ultimate_rttv")) do
        if ent:GetActualID() == actualID then
            monitorEntCache[id] = ent
            -- Force-activate so the monitor renders without USE.
            ent.IsActive = true
            return ent
        end
    end
    return nil
end

-- =========================================================================
-- Director update receiver
-- =========================================================================
net.Receive("ZScav_Bodycam_DirectorUpdate", function()
    local count = net.ReadUInt(5)
    local slots = {}
    for i = 1, count do
        if net.ReadBool() then
            slots[i] = {
                camOwner = net.ReadEntity(),
                audio    = net.ReadBool(),
                hp       = net.ReadFloat(),
                otrub    = net.ReadBool(),
            }
        else
            slots[i] = nil
        end
    end
    BC._slots = slots
    hook.Run("ZScav_Bodycam_SlotsUpdated", slots)
end)

-- =========================================================================
-- Sound relay receiver
-- =========================================================================
net.Receive("ZScav_Bodycam_RelaySound", function()
    local idx       = net.ReadUInt(5)
    local soundName = net.ReadString()
    local kind      = net.ReadUInt(3)

    local monitor = getMonitorEntByIndex(idx)
    if not IsValid(monitor) then return end
    if soundName == "" then return end

    -- Bodycam-through-a-speaker preset
    local pitch  = 80
    local volume = 0.55
    if kind == 1 then  -- gunshot
        pitch  = 75 + math.random(-5, 5)
        volume = 0.6
    end

    -- Use sound.Play for explicit positional emit (path or scriptedsound table)
    local pos = monitor:GetPos()
    if isstring(soundName) then
        sound.Play(soundName, pos, 70, pitch, volume)
    end
end)

-- =========================================================================
-- Static loop manager
-- Each visible/active monitor with a current camOwner gets a continuous
-- low-volume static loop. We start/stop as slots come and go.
-- =========================================================================
local STATIC_SOUND = "ambient/levels/labs/teleport_active_loop1.wav"
-- Note: replace with a dedicated bodycam static asset if you ship one.
-- The above HL2 ambient is a serviceable hum/static placeholder.

local activeLoops = {}  -- [monitorIdx] = CSoundPatch

local function ensureLoop(idx, monitor)
    if activeLoops[idx] then return end
    if not IsValid(monitor) then return end
    local patch = CreateSound(monitor, STATIC_SOUND)
    if not patch then return end
    patch:SetSoundLevel(70)
    patch:PlayEx(0.18, 100)
    activeLoops[idx] = patch
end

local function killLoop(idx)
    local patch = activeLoops[idx]
    if patch then patch:Stop() end
    activeLoops[idx] = nil
end

hook.Add("ZScav_Bodycam_SlotsUpdated", "ZScav_Bodycam_StaticLoops", function(slots)
    for idx = 1, BC.MONITOR_COUNT do
        local slot = slots[idx]
        if slot and IsValid(slot.camOwner) then
            local monitor = getMonitorEntByIndex(idx)
            if IsValid(monitor) then ensureLoop(idx, monitor) else killLoop(idx) end
        else
            killLoop(idx)
        end
    end
end)

hook.Add("ShutDown", "ZScav_Bodycam_StaticCleanup", function()
    for idx in pairs(activeLoops) do killLoop(idx) end
end)
