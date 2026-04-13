if SERVER then return end
if _G.ZC_ClientDoDConfigMenuLoaded then return end
_G.ZC_ClientDoDConfigMenuLoaded = true
include("zc_features/client/dod_event/cl_dod_config_menu.lua")
