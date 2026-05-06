PATTextPresence = PATTextPresence or {}

if SERVER then
    AddCSLuaFile("autorun/client/cl_pat_textpresence.lua")
    return
end

PATTextPresence.MaxDistance = CreateClientConVar("pat_textpresence_max_distance", "900", true, false, "Max render distance for local speech text.", 200, 3000)
PATTextPresence.FadeDistance = CreateClientConVar("pat_textpresence_fade_distance", "700", true, false, "Distance where text starts fading harder.", 100, 3000)
PATTextPresence.WhisperDistanceScale = CreateClientConVar("pat_textpresence_whisper_distance_scale", "0.6", true, false, "Distance multiplier for whisper text visibility.", 0.2, 1)
PATTextPresence.RevealSpeed = CreateClientConVar("pat_textpresence_reveal_speed", "24", true, false, "Characters per second in the typewriter effect.", 8, 80)
PATTextPresence.LifeTime = CreateClientConVar("pat_textpresence_lifetime", "4.2", true, false, "How long finished speech stays above the head.", 1, 10)
PATTextPresence.PreviousLifeTime = CreateClientConVar("pat_textpresence_previous_lifetime", "2.4", true, false, "How long the faded previous line remains visible.", 0.5, 8)
PATTextPresence.WrapWidth = CreateClientConVar("pat_textpresence_wrap_width", "320", true, false, "Max width before speech text wraps.", 120, 640)
PATTextPresence.TypingOffset = CreateClientConVar("pat_textpresence_typing_offset", "14", true, false, "Extra height for the typing indicator.", 0, 40)
PATTextPresence.VisibilityCacheInterval = CreateClientConVar("pat_textpresence_visibility_cache_interval", "0.09", true, false, "Seconds to reuse the last visibility result before tracing again.", 0.01, 0.5)
PATTextPresence.VisibilityCacheMoveTolerance = CreateClientConVar("pat_textpresence_visibility_cache_move_tolerance", "18", true, false, "How far view/target positions may drift before visibility cache refreshes.", 2, 96)
