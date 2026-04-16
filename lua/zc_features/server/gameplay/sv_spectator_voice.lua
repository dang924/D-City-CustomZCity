-- Spectator proximity voice: dead/spectator players can be heard by nearby
-- alive players at the same range as normal chat (3000 units).
--
-- Uses the CanListenOthers hook (called at the top of ChatLogic in
-- sv_comunication.lua) so it short-circuits before the alive-only checks.
-- Returns true,true only for voice (isChat=false) so text chat is unaffected.

if CLIENT then return end

local SPEC_VOICE_DIST = 3000

hook.Add("CanListenOthers", "ZC_SpectatorProximityVoice", function(speaker, listener, isChat)
    if isChat then return end
    if not IsValid(speaker) or not IsValid(listener) then return end
    if speaker:Alive() then return end          -- alive speaker: normal path
    if not listener:Alive() then return end     -- dead-dead: normal path (both hear each other already)

    if listener:GetPos():Distance(speaker:GetPos()) < SPEC_VOICE_DIST
    and listener:TestPVS(speaker) then
        return true, true   -- heard in 3D
    end
    -- out of range: return nil, let ChatLogic return false as usual
end)
