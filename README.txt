DCityPatchPack (test folder build)
==================================

Full copy of DCityPatch1.1 with:
  - Per-module toggles: ConVar zc_dcp_feat_<key> (default 1)
  - Mode gate unchanged: most gameplay hooks only run in coop/event unless zc_patch_force_all_modes 1
  - "Always on" safety/list files still skip coop gate but honor zc_dcp_feat_* unless disabled

Install
-------
  addons/test/DCityPatchPack   (or symlink this folder into garrysmod/addons/)

Disable the original DCityPatch1.1 addon when using this pack (avoid duplicate hooks).

ULX (superadmin)
----------------
  ulx dcitypackfeatlist          — index, key name, state; use with dcpf<N>
  ulx dcitypackfeat <key> <0|1>  — toggle by key string (see list)
  ulx dcpf<N> <0|1>              — one command per module, N = index from featlist
  ulx dcitypackfeatalle <0|1>    — flip every module (dangerous)
  ulx dcityallmodes <0|1>        — existing: run gated gameplay outside coop/event

Gameplay intent (ZCity)
-----------------------
  Coop: Rebels + Gordon vs Combine NPCs; protect friendly/scripted NPCs.
  After Gordon dies: Combine players spawn and cooperate with Combine NPCs vs remaining Rebels.

Key files (examples)
--------------------
  autorun_server_sv_npc_relationships — Combine NPC targeting / rebel acquisition
  autorun_server_sv_bullseye_refresh    — Faction relationships / sniper filter
  autorun_server_sv_patch_player_factions — Rebel vs Combine player detection
  autorun_server_sv_default_coop_bootstrap — round flow

Regenerate feature key list if you add/remove .lua files under lua/:
  Rebuild lua/dcitypack/dcp_feat_keys.lua (same pattern: path after lua/ with slashes -> underscores).
