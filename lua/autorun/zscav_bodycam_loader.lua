-- ZScav Bodycam System - module loader
-- Loads all bodycam files in the correct order and AddCSLuaFiles client files.
-- Files live under lua/zscav_bodycam/.

local PATH = "zscav_bodycam/"

local SHARED = {
    "sh_bodycam_net.lua",
}

local SERVER_FILES = {
    "sv_bodycam_camera.lua",
    "sv_bodycam_consent.lua",
    "sv_bodycam_director.lua",
    "sv_bodycam_audio.lua",
    "sv_bodycam_voice.lua",
    "sv_bodycam_debug.lua",
}

local CLIENT_FILES = {
    "cl_bodycam_consent_ui.lua",
    "cl_bodycam_audio_recv.lua",
    "cl_bodycam_overlay.lua",
    "cl_bodycam_offset_ui.lua",
}

if SERVER then
    for _, f in ipairs(SHARED) do AddCSLuaFile(PATH .. f) end
    for _, f in ipairs(CLIENT_FILES) do AddCSLuaFile(PATH .. f) end
    for _, f in ipairs(SHARED) do include(PATH .. f) end
    for _, f in ipairs(SERVER_FILES) do include(PATH .. f) end
else
    for _, f in ipairs(SHARED) do include(PATH .. f) end
    for _, f in ipairs(CLIENT_FILES) do include(PATH .. f) end
end
