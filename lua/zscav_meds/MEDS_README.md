# ZScav Meds (testing-branch native)

EFT-style medical items for the ZScav gamemode. Lives entirely inside
the ZCity testing branch — no separate workshop addon needed for the
lua side. Asset content (models/materials/sounds) comes from the
existing `eftmeds` workshop addon.

## What was added / patched in this branch

### New files

```
lua/autorun/sh_zscav_meds.lua                       ← shared autorun
lua/zscav_meds/sv_handler.lua                       ← hook handlers + picker
lua/zscav_meds/MEDS_README.md                       ← this file
(lua/zscav_meds/sh_swep_base.lua is DEPRECATED — superseded by the canonical
 base SWEP at lua/weapons/weapon_zscav_med_base.lua. Safe to delete.)

lua/weapons/weapon_zscav_med_base.lua               ← non-spawnable base SWEP
lua/weapons/weapon_zscav_med_ai2.lua
lua/weapons/weapon_zscav_med_car.lua
lua/weapons/weapon_zscav_med_salewa.lua
lua/weapons/weapon_zscav_med_ifak.lua
lua/weapons/weapon_zscav_med_afak.lua
lua/weapons/weapon_zscav_med_grizzly.lua
lua/weapons/weapon_zscav_med_bandage.lua
lua/weapons/weapon_zscav_med_armybandage.lua
lua/weapons/weapon_zscav_med_esmarch.lua
lua/weapons/weapon_zscav_med_cat.lua
lua/weapons/weapon_zscav_med_alusplint.lua
lua/weapons/weapon_zscav_med_surgicalkit.lua

gamemodes/zcity/gamemode/modes/zscav/sh_zscav_meds_catalog.lua
```

### Patched files

```
gamemodes/zcity/gamemode/modes/zscav/sv_zscav.lua
  Replaced the `Notice(ply, "Medical quickslots are setup-only right now.")`
  stub inside ActivateQuickslotBinding with a hook.Run("ZSCAV_UseMedicalQuickslot")
  call. The pocket/vest binding restriction is unchanged.
```

## Required content pack

This package depends on the **eftmeds** workshop addon (the EFT medical
items SWEP pack the user already had at `nutscript shi/eftmeds`). It
provides the model + sound + material assets that the SWEPs reference.

**Steam Workshop**: subscribe / mount the eftmeds addon on the server
(workshop.cfg or `+host_workshop_collection`). Clients auto-download.

**Local install**: drop the `eftmeds` folder into `garrysmod/addons/` on
the server. Same on each client, OR set up FastDL (see "FastDL notes"
below) to push the files at connect time.

### Asset paths the SWEPs reference

If you ever swap content packs, these are the paths each SWEP expects.
Change the SWEP file's `ViewModel`/`WorldModel`/sound-alias paths to
whatever your replacement pack uses.

```
Models (.mdl + .vvd + .phy + .vtx LODs):
  models/weapons/sweps/eft/anaglin/{v,w}_meds_anaglin.mdl
  models/weapons/sweps/eft/salewa/{v,w}_meds_salewa.mdl
  models/weapons/sweps/eft/afak/{v,w}_meds_afak.mdl
  models/weapons/sweps/eft/grizzly/{v,w}_meds_grizzly.mdl
  models/weapons/sweps/eft/cat/{v,w}_meds_cat.mdl
  models/weapons/sweps/eft/esmarch/{v,w}_meds_esmarch.mdl
  models/weapons/sweps/eft/alusplint/{v,w}_meds_alusplint.mdl
  models/weapons/sweps/eft/surgicalkit/{v,w}_meds_surgicalkit.mdl

Sounds (.wav):
  weapons/eft/medkit/item_medkit_ai_00_draw.wav
  weapons/eft/medkit/item_medkit_ai_01_open.wav
  weapons/eft/medkit/item_medkit_ai_04_injection.wav
  weapons/eft/medkit/item_medkit_ai_06_putaway.wav
  weapons/eft/bandage/item_bandage_01_open.wav
  weapons/eft/bandage/item_bandage_03_use.wav
  weapons/eft/bandage/item_bandage_04_end.wav
  weapons/eft/salewa/item_medkit_salewa_01_open.wav
  weapons/eft/salewa/item_medkit_salewa_03_use.wav
  weapons/eft/salewa/item_medkit_salewa_04_end.wav
  weapons/eft/grizzly/item_medkit_grizzly_00_draw.wav
  weapons/eft/grizzly/item_medkit_grizzly_01_open.wav
  weapons/eft/grizzly/item_medkit_grizzly_02_medtake.wav
  weapons/eft/cat/item_cat_00_draw.wav
  weapons/eft/cat/item_cat_01_use.wav
  weapons/eft/cat/item_cat_02_fasten.wav
  weapons/eft/splint/item_splint_00_start.wav
  weapons/eft/splint/item_splint_01_middle.wav
  weapons/eft/splint/item_splint_02_end.wav
  weapons/eft/surgicalkit/item_surgicalkit_00_draw.wav
  weapons/eft/surgicalkit/item_surgicalkit_08_stapler_use.wav
  weapons/eft/surgicalkit/item_surgicalkit_10_close.wav

Inventory icons (.vmt + .vtf, optional but referenced by SWEP files):
  materials/vgui/hud/vgui_salewa.{vmt,vtf}
  materials/vgui/hud/vgui_afak.{vmt,vtf}
  materials/vgui/hud/vgui_grizzly.{vmt,vtf}
  materials/vgui/hud/vgui_cat.{vmt,vtf}
  materials/vgui/hud/vgui_surgicalkit.{vmt,vtf}
  (eftmeds DOES NOT ship icons for AI-2 / Car / IFAK / Bandages; those
   four will show a missing-icon placeholder until you add textures or
   change the WepSelectIcon line in their SWEP files)
```

## FastDL notes (skip if using Workshop)

If you're not mounting eftmeds via Workshop, the server needs to push
these assets to clients on connect via FastDL. The eftmeds addon should
already include `resource.AddFile` calls for its own content; if not,
add a small server autorun that registers each path. Example skeleton:

```lua
-- lua/autorun/server/sv_zscav_meds_resources.lua  (OPTIONAL — skip if using Workshop)
if not SERVER then return end

local function addModel(base)
    for _, ext in ipairs({ ".mdl", ".vvd", ".phy", ".dx80.vtx", ".dx90.vtx", ".sw.vtx" }) do
        resource.AddSingleFile(base .. ext)
    end
end

addModel("models/weapons/sweps/eft/anaglin/v_meds_anaglin")
addModel("models/weapons/sweps/eft/anaglin/w_meds_anaglin")
-- ...repeat for salewa, afak, grizzly, cat, esmarch, alusplint, surgicalkit
-- + resource.AddSingleFile each .wav and .vmt/.vtf path listed above
```

We're not shipping that resource registration script in this branch
because (a) most servers run eftmeds via Workshop and don't need it,
and (b) duplicating the eftmeds author's content list inside our
testing branch would be brittle to upstream changes.

## How the system works

Two entry points trigger healing:

1. **Health tab (drag-drop)** — `Actions.use_medical_target` →
   `ZSCAV_UseMedicalTarget` hook → `ZScavMeds.ApplyMedical(...)`.
   Player picks a body part precisely.

2. **Hotbar (one-key)** — `ActivateQuickslotBinding` →
   `ZSCAV_UseMedicalQuickslot` hook → `ZScavMeds.PickBestPartForItem(...)`
   chooses the part automatically (most-bleed for tourniquets,
   most-damaged for medkits, blacked-out for surgical, etc.) →
   `ZScavMeds.ApplyMedical(...)`.

Both share the same healing pipeline:

1. Stop heavy bleed (highest priority — blood loss is lethal)
2. Stop light bleed
3. Fix fracture
4. Restore blacked-out limb (Surgical Kit only; introduces light bleed)
5. Heal HP from pool, weighted toward the dominant damaged organ on
   the part
6. If pool / use counter is exhausted, remove the item from the grid
7. SyncInventory to push the new state to the client

EFT-canonical values live in `ZSCAV.MedicalEFT` at the top of
`gamemodes/zcity/gamemode/modes/zscav/sh_zscav_meds_catalog.lua`. Edit
HP pools, use times, and status costs there and `lua_reload` — no SWEP
or handler changes needed.

## Items (EFT-exact)

| Class | Item | Pool / Uses | Use time | Statuses cleared |
| ----- | ---- | ----------- | -------- | ---------------- |
| `weapon_zscav_med_ai2`         | AI-2 Medkit                | 100 HP  | 2.0s | — |
| `weapon_zscav_med_car`         | Car First Aid Kit          | 220 HP  | 4.0s | light bleed (50) |
| `weapon_zscav_med_salewa`      | Salewa First Aid Kit       | 400 HP (+85 instant) | 3.0s | light bleed (45) |
| `weapon_zscav_med_ifak`        | IFAK Personal Tactical Kit | 300 HP  | 3.0s | light bleed (30), contusion |
| `weapon_zscav_med_afak`        | AFAK Tactical Trauma Kit   | 400 HP  | 4.0s | light bleed (30), heavy bleed (170), contusion |
| `weapon_zscav_med_grizzly`     | Grizzly Medical Kit        | 1800 HP | 4.5s | light + heavy bleed, fracture, contusion, pain |
| `weapon_zscav_med_bandage`     | Aseptic Bandage            | single  | 4.0s | light bleed |
| `weapon_zscav_med_armybandage` | Army Bandage               | 400 HP (+5 instant) | 6.0s | light bleed (50) |
| `weapon_zscav_med_esmarch`     | Esmarch Tourniquet         | 8 uses  | 4.0s | heavy bleed (limbs only) |
| `weapon_zscav_med_cat`         | CAT Tourniquet             | 12 uses | 4.0s | heavy bleed (limbs only) |
| `weapon_zscav_med_alusplint`   | Aluminium Splint           | 8 uses  | 16.0s | fracture (limbs only) |
| `weapon_zscav_med_surgicalkit` | CMS Surgical Kit           | 260 HP  | 16.0s | revives blacked-out limb (introduces light bleed) |

## Hooks for other addons

```
ZSCAV_UseMedicalTarget    (ply, inv, target, profile, args)
ZSCAV_UseMedicalQuickslot (ply, inv, target)
```

Return contract for both:

- `true`   = consumed silently
- `string` = consumed, send the string as a Notice
- `false`  = consumed, no further handling
- `nil`    = no handler ran (gamemode falls through to default error)

Third-party medical addons can register their own handlers for their
own item classes — return `nil` for items you don't own and the
ZScavMeds handler will run next.

## Not in this iteration

- Stims & painkillers (Morphine, Adrenaline, Propital, SJ1, eTG-c, L1,
  Analgin, Augmentin) — they need timed buff / regen plumbing.
- Server-side use-time gating. The SWEP `next-fire` cooldown +
  drag-drop interaction time act as the rate limit today.
- Inventory icons for AI-2 / Car / IFAK / Bandages (eftmeds doesn't
  ship them; placeholder shows missing-icon until you add textures or
  change `WepSelectIcon`).
- Hold-to-pick-part hotbar mode (long-press opens part picker).
