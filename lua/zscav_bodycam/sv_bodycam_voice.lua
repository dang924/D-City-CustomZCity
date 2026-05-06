-- ZScav Bodycam System - voice routing.
-- A safe-zone listener (or any dead player) hears any consenting talker who is
-- currently broadcasting to a monitor with audio enabled. Proximity voice
-- handling is unchanged; we only ADD audibility, never remove it.

local BC = ZSCAV.Bodycam

hook.Add("PlayerCanHearPlayersVoice", "ZScav_Bodycam_VoiceRoute", function(listener, talker)
    if not BC:IsActive() then return end
    if not IsValid(listener) or not IsValid(talker) then return end
    if listener == talker then return end

    -- Only override to ENABLE audibility. Returning nothing falls through to
    -- whatever proximity voice already decided.
    if not BC:IsConsenting(talker) then return end

    local talkerSID = talker:SteamID64()
    if not talkerSID then return end

    -- Talker must currently be on an audio-enabled monitor slot.
    local slotIdx = BC:GetSlotForSID(talkerSID)
    if not slotIdx then return end

    -- Listener must be in a safe zone OR be dead (spectating from anywhere).
    local listenerInSafe = BC:IsPlayerInSafeZone(listener)
    local listenerIsDead = not listener:Alive()
    if not (listenerInSafe or listenerIsDead) then return end

    return true
end)
