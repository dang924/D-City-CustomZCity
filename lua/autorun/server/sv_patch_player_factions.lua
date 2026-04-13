if CLIENT then return end
if _G.ZC_SharedPatchPlayerFactionsLoaded then return end
_G.ZC_SharedPatchPlayerFactionsLoaded = true
include("zc_features/server/gameplay/sv_patch_player_factions.lua")
