-- ZScav Bodycam System - shared constants and net string registration.

ZSCAV = ZSCAV or {}
ZSCAV.Bodycam = ZSCAV.Bodycam or {}
local BC = ZSCAV.Bodycam

-- ----- Tunables (read by both sides; only changed in one place) -----
-- IMPORTANT: monitors must be placed with ID Mode = Global. urtcams stores the
-- monitor's full ID as "G_<actualID>" when global. Our camera IDs must match
-- that prefixed form, NOT the raw actualID, or urtcam.CamByID lookup misses.
BC.MONITOR_ID_PREFIX  = "G_zscavmonitor"      -- monitor full IDs: "G_zscavmonitor1".."G_zscavmonitor12"
BC.MONITOR_ACTUAL_ID  = "zscavmonitor"        -- the user-typed ID in the tool (no prefix)
BC.MONITOR_COUNT      = 12
BC.MAX_VISUAL_FEEDS   = 12                    -- == MONITOR_COUNT
BC.MAX_AUDIO_FEEDS    = 4                     -- only top N broadcasters relay audio
BC.TICK_INTERVAL      = 0.5                   -- director tick rate (seconds)
BC.SCORE_DECAY        = 0.85                  -- per-tick multiplicative decay
BC.MIN_LOCK_TIME      = 3.0                   -- seconds a monitor stays on a player after assignment
BC.INCUMBENT_BONUS    = 15                    -- score bonus for being currently on-screen (anti-flicker)
BC.WAKE_THRESHOLD     = 25                    -- minimum score for a monitor to come out of standby
BC.GUNSHOT_RATE_LIMIT = 0.075                 -- seconds; min interval between relayed shots per source

BC.CAMERA_BONE        = "ValveBiped.Bip01_Spine4"
BC.CAMERA_BONE_FALLBACKS = {
    "ValveBiped.Bip01_Spine4",
    "ValveBiped.Bip01_Spine2",
    "ValveBiped.Bip01_Spine1",
    "ValveBiped.Bip01_Spine",
}
BC.CAMERA_OFFSET      = Vector(-10.34, 19.44, 2.94) -- bodycam mount offset, in mount-bone local space
BC.CAMERA_CROUCH_OFFSET = Vector(5.50, -5.34, 3.31) -- extra offset applied while crouched
BC.CAMERA_FALLBACK_OFFSET = Vector(20, 0, 35) -- legacy origin-space fallback if no torso bone resolves
BC.INACTIVE_ID_PREFIX = "zscav_bodycam_idle_" -- prefix for cameras not currently routed to a monitor

-- Score weights for activity events
BC.SCORE_WEIGHTS = {
    fire     = 100,
    damage   = 80,
    kill     = 120,
    sprint   = 5,        -- per tick while sprinting
    interact = 20,
    otrub    = 60,       -- one-shot bump when going down (also EKG-triggers visually)
}

-- Consent states (network-friendly small ints)
BC.CONSENT_PENDING = 0
BC.CONSENT_DENY    = 1
BC.CONSENT_ALLOW   = 2

-- ----- Net strings -----
if SERVER then
    util.AddNetworkString("ZScav_Bodycam_RequestConsent")  -- sv -> cl: open popup
    util.AddNetworkString("ZScav_Bodycam_ConsentReply")    -- cl -> sv: popup answer
    util.AddNetworkString("ZScav_Bodycam_ToggleConsent")   -- cl -> sv: inventory button toggle
    util.AddNetworkString("ZScav_Bodycam_DirectorUpdate")  -- sv -> cl (broadcast safe-zone): monitor->camera mapping + state
    util.AddNetworkString("ZScav_Bodycam_RelaySound")      -- sv -> cl (safe-zone listeners): play a sound at monitor N
    util.AddNetworkString("ZScav_Bodycam_HUDState")        -- sv -> cl (single ply): "REC" indicator on/off
    util.AddNetworkString("ZScav_Bodycam_OffsetStateRequest")
    util.AddNetworkString("ZScav_Bodycam_OffsetStateSync")
    util.AddNetworkString("ZScav_Bodycam_OffsetStateApply")
end

-- ----- Helpers -----
-- Full prefixed ID, matching what urtcam.CamByID is keyed by. Use this for
-- camera:SetID() so a monitor with ActualID "zscavmonitor1" picks us up.
function BC:MonitorID(idx)
    return self.MONITOR_ID_PREFIX .. tostring(idx)
end

-- Unprefixed ID, matching monitor:GetActualID(). Use this when iterating world
-- monitor entities to find the one for a given slot index.
function BC:MonitorActualID(idx)
    return self.MONITOR_ACTUAL_ID .. tostring(idx)
end

function BC:InactiveCamID(ply)
    if not IsValid(ply) then return self.INACTIVE_ID_PREFIX .. "void" end
    return self.INACTIVE_ID_PREFIX .. ply:SteamID64()
end

-- Returns true if ZScav mode is currently active. Falls back to false if the
-- mode global isn't ready yet (e.g. very early server boot).
function BC:IsActive()
    if not (ZSCAV and ZSCAV.IsActive) then return false end
    return ZSCAV:IsActive()
end

-- Returns true if a player is in any safe zone (server or client side).
function BC:IsPlayerInSafeZone(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return false end
    if not ZCitySafeZones then return false end
    if SERVER and ZCitySafeZones.IsPlayerProtected then
        return ZCitySafeZones.IsPlayerProtected(ply)
    end
    -- Client-side: do the lookup against ClientZones
    if ZCitySafeZones.FindZoneAtPos and ZCitySafeZones.GetZones then
        return ZCitySafeZones.FindZoneAtPos(ply:GetPos(), ZCitySafeZones.GetZones(), 0) ~= nil
    end
    return false
end
