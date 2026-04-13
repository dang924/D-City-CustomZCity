# Z-City Merged TEST Reorganization Report

Date: 2026-04-13
Scope: TEST copy only

## What Changed

- Added a thin feature bootstrap loader:
  - `lua/autorun/zz_zc_feature_bootstrap.lua`
  - Loads files from `lua/zc_features/shared`, `lua/zc_features/server`, and `lua/zc_features/client`.
  - Server now explicitly `AddCSLuaFile` sends all moved client/shared files.

- Moved gameplay and optional patch modules out of heavy `autorun/server` and `autorun/client` roots into operation folders under `lua/zc_features/`:
  - `zc_features/server/admin_ops`
  - `zc_features/server/coop`
  - `zc_features/server/dod_event`
  - `zc_features/server/events_votes`
  - `zc_features/server/gameplay`
  - `zc_features/server/misc`
  - `zc_features/server/npc_ai`
  - `zc_features/server/ui_commands`
  - `zc_features/client/admin_ops`
  - `zc_features/client/coop`
  - `zc_features/client/dod_event`
  - `zc_features/client/events_votes`
  - `zc_features/client/gameplay`
  - `zc_features/client/misc`
  - `zc_features/client/npc_ai`
  - `zc_features/client/ui_commands`
  - `zc_features/shared/dod_event`
  - `zc_features/shared/misc`
  - `zc_features/shared/npc_ai`
  - `zc_features/shared/ui_commands`

- Autorun roots were thinned:
  - `autorun/server`: reduced to compatibility/safety-critical files.
  - `autorun/client`: reduced to compatibility/safety-critical files.

- Preserved existing feature toggle compatibility by path remap logic:
  - Updated `lua/autorun/aaa_zcity_dcp_feature_core.lua`.
  - Files now moved under `zc_features/*` still map to legacy feature keys such as:
    - `autorun_server_sv_*`
    - `autorun_client_cl_*`
    - `autorun_sh_*`
  - This keeps `zc_dcp_feat_*` convar naming stable for existing configs.

## What Did Not Change

- Core infrastructure remained in `lua/autorun/`:
  - `a_command_handler.lua`
  - `aa_dcity_mode_gate.lua`
  - `aa_zc_debug_command_gate.lua`
  - `aaa_zcity_dcp_feature_core.lua` (only compatibility mapping extension added)
  - `loader.lua`
  - `fire_creation.lua`, `fire_game_modifications.lua`, `fire_misc.lua`
  - `sh_glide.lua`, `sh_glide_gtav_helicopters.lua`
  - `wiltos_dynabase_loader.lua`
  - `shitdecals.lua`

- Always-on safety and compatibility modules intentionally remained in `autorun/server` and `autorun/client`.
  - Reason: `aa_dcity_mode_gate.lua` explicitly identifies these by source-path patterns and keeps them ungated.
  - Moving them would risk mode-gating critical nil guards and stability patches.

## Why This Layout

- Cleaner gameplay operations:
  - Coop, DoD/Event, NPC/AI, admin/debug, and UI/command systems are now grouped by purpose.

- Better compatibility:
  - Safety-critical files are still loaded from their known autorun paths.
  - Legacy feature convar names are preserved for existing server cfgs.

- Lower autorun surface area:
  - Autorun now focuses on core bootstrap + safety layer.
  - Feature modules are modularized under `zc_features` for easier maintenance.

## Quick Result Snapshot

- `autorun/server` Lua count: 24
- `autorun/client` Lua count: 11
- `zc_features/server` Lua count: 66
- `zc_features/client` Lua count: 34
- `zc_features/shared` Lua count: 5

## Known Follow-Up Suggestions

- If desired, add a small startup sanity log that warns if any expected `zc_features` category is empty.
- Optionally create per-category toggles (e.g. `zc_cat_coop`, `zc_cat_events_votes`) for fast staged testing.
