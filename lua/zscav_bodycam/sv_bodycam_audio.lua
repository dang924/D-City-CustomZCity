-- ZScav Bodycam System - audio relay.
-- Intercepts weapon-fire / damage sounds emitted near consenting players and
-- networks a "play this at monitor N" event to safe-zone clients. The actual
-- playback (with pitch/volume mangling for "bodycam-through-a-speaker" feel)
-- happens client-side in cl_bodycam_audio_recv.lua.

local BC = ZSCAV.Bodycam

BC._lastShotAt = BC._lastShotAt or {}    -- [sid64] = CurTime() of last relayed shot

-- =========================================================================
-- Helpers
-- =========================================================================
local function isWeaponSound(name)
    if not isstring(name) then return false end
    local lower = string.lower(name)
    if lower:find("weapons/", 1, true) then return true end
    if lower:find("weapon_", 1, true) then return true end
    if lower:find("/shoot", 1, true) then return true end
    if lower:find("_fire", 1, true) then return true end
    if lower:find("_shot", 1, true) then return true end
    return false
end

-- Resolve the player who "owns" a sound source (the shooter).
local function ownerPlayer(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then return ent end
    local owner = ent.GetOwner and ent:GetOwner() or nil
    if IsValid(owner) and owner:IsPlayer() then return owner end
    return nil
end

local function relayShotFromPlayer(ply, soundName)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if not sid then return end

    local slotIdx = BC:GetSlotForSID(sid)  -- nil if not a current audio feed
    if not slotIdx then return end

    -- Per-source rate limit so auto fire doesn't spam the network
    local now = CurTime()
    if (BC._lastShotAt[sid] or 0) + BC.GUNSHOT_RATE_LIMIT > now then return end
    BC._lastShotAt[sid] = now

    -- Send to every player currently in any safe zone.
    local recipients = RecipientFilter()
    for _, recv in ipairs(player.GetAll()) do
        if BC:IsPlayerInSafeZone(recv) then
            recipients:AddPlayer(recv)
        end
    end
    -- Also send to dead players (spectating from anywhere).
    for _, recv in ipairs(player.GetAll()) do
        if not recv:Alive() then recipients:AddPlayer(recv) end
    end
    if #recipients:GetPlayers() == 0 then return end

    net.Start("ZScav_Bodycam_RelaySound")
    net.WriteUInt(slotIdx, 5)
    net.WriteString(soundName or "")
    net.WriteUInt(1, 3)  -- type 1 = gunshot (pitch/volume preset)
    net.Send(recipients)
end

-- =========================================================================
-- Hooks
-- =========================================================================

-- Cleanest signal for "this player just fired a gun": EntityFireBullets.
-- We pull the active weapon's primary fire sound when possible.
hook.Add("EntityFireBullets", "ZScav_Bodycam_FireRelay", function(ent, _data)
    if not BC:IsActive() then return end
    local ply = ownerPlayer(ent)
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    local soundName = ""
    if IsValid(wep) and wep.Primary and wep.Primary.Sound then
        soundName = tostring(wep.Primary.Sound)
    end
    relayShotFromPlayer(ply, soundName)
end)

-- Catch-all: explicit gun sounds via EmitSound that aren't covered above
-- (e.g. some SWEPs emit sounds through the entity directly). We rate-limit
-- in relayShotFromPlayer so duplicates don't matter.
hook.Add("EntityEmitSound", "ZScav_Bodycam_SoundRelay", function(data)
    if not BC:IsActive() then return end
    if not data or not isWeaponSound(data.SoundName) then return end
    local owner = ownerPlayer(data.Entity)
    if not IsValid(owner) then return end
    relayShotFromPlayer(owner, data.SoundName)
end)
