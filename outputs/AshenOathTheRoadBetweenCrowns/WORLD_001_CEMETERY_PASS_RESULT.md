# WORLD-001 Cemetery Architecture Pass

Status: retained partial implementation/evidence, **not WORLD-001 acceptance**.
Recovery remains **27/37 accepted**. Production is unchanged.

## Changes

- Four deterministic runtime meshes replace the chapel's overlapping masonry,
  competing roof planes, mismatched bell posts/hood, solid cone bell and nine
  floating box row markers. The chapel now has fitted tiled roofing, masonry
  gables and a clear west doorway; the bell has a hollow mouth and rim.
- Existing Quaternius Medieval Village CC0 modules supply walls, roofs and
  supports. Bell/grave geometry is original project assembly, not a claimed
  third-party model. Source hashes and the kit license remain explicit.
- Total compressed geometry: **97,863 bytes**, seven surfaces across four
  resources. Runtime hashes, explicit base-pack ownership and production/QA/base
  filters pass. Raw OBJ sources are not added to the bootstrap export.
- Original prop reservation, river positioning and collision policy remains
  through `make_reserved_collision_box`, which calls the same prop path with
  rendering disabled. Floor, altar, sealed door, clue/quest IDs, actors, doorway,
  bell state keys, rope/clapper, shrine state and physical approaches are retained.
- Retired chapel-overlay builders are deleted, not left available for later
  spawns. The legacy WORLD-014 contract checks actual complete baked geometry
  and materials rather than obsolete individual facade node names.
- Capture waits for actual complete opening detail, foregrounds native 1280x720
  and identifies its staged quest setup as visual evidence, not player progression.

## Runtime Files

| Resource | Bytes | SHA-256 |
|---|---:|---|
| Cemetery_chapel_Authored.res | 48230 | 44625271685283e72968e06e1478fedad809c47f4ee343f01880fc9bb6d41c31 |
| Cemetery_bell_frame_Authored.res | 33402 | 707f91233bf63604ab16a2df4c71776ac764025cb504240d20c21aa6f7f7720f |
| Cemetery_bell_Authored.res | 11687 | 912e02155db2e782301fc32b67507414f9474971fe5ff7b0453180b2a3d18506 |
| Cemetery_grave_rows_Authored.res | 4544 | 55d399e495fd3f5eef689912f1b92f855e35aa22792e87b302837aa944d2c529 |

## Verification

Logs under `D:/Temp/AshenOath/`:

- `world001_cemetery_bake_20260927`: PASS four source-derived/original meshes.
- `world001_cemetery_contract_20260927`: resource contract and partial/compact/
  full/idempotent stage construction PASS. The old integration sequence emitted
  an active gate error after PASS; that run is rejected, not a clean pass.
- Integration v2/v3/v4 are rejected fixture iterations: the Widow's Bell variant
  wasn't rebuilt, a full rebuild was incorrectly waiting on fast-boot metadata,
  then a helper needed explicit GDScript Node typing. No gate was weakened or
  gameplay change made to accommodate these failures.
- `world001_cemetery_native_v4_20260927.verify_cemetery_architecture`: PASS
  source/runtime identity, finite geometry, materials, budgets, open doorway,
  supported frame, complete grounded rows and genuinely hollow bell mouth.
- `world001_cemetery_native_v5_20260927`: PASS complete actual cemetery builder,
  five required interactions, six headstones, route-service checks and retained
  node/mesh budgets. The integration now waits for New Game before constructing
  its quest-specific full-zone variant. Clean process exit and shutdown.
- `world001_cemetery_visual_20260927`: four fresh native 1280x720 views PASS
  capture and clean shutdown. Codex inspected every image; ANGLE advisory only.
- `world001_cemetery_real_input_20260927`: PASS keyboard Continue from a copy of
  the genuine `chapel_pier_route` autosave, retained open chapel/shrine/boss state,
  physical entrance alignment, eastward movement through the doorway, actual
  focus/E/dialogue choice, cleansed consequence and clean shutdown. No teleport,
  flag mutation or direct interaction handler. This is a continuation leg, not
  a fresh full campaign or browser route. Original user/test saves are untouched.

## Camera Review

Current images: `.release-gate/world001_cemetery_candidate/`, suffix
`20260927_191404.png`:

| View | SHA-256 |
|---|---|
| WORLD-014_01_Cemetery_Approach | 9da33e8e526e3653fd23f63d78f4a65bfb866fc9e11112cc0bed0573cf7313e3 |
| WORLD-014_02_Grave_Court_Crows | 76d8a22f3c5aa3897f229028ad6413aa771c6dd905e8e70c84b35cbd40459941 |
| WORLD-014_03_Ruined_Crow_Chapel | c23ea1a232fa423cff360850a41abbd8a9be413c13f30c35d007002a0ad7e97c |
| WORLD-014_04_Bell_and_Shrine | 94d916ecf93659756a89abdcbc267e19c066022c01c270bb5664e732155e9d72 |

Preserved WORLD-014 images dated 20260923_101916 supply historical matching-camera
chapel/bell comparison. They are not fabricated current-source before captures;
terrain/horizon changes also intervene, so no whole-scene causal attribution or
perceptual baseline approval is claimed.

Retain fitted roof/walls, connected frame, complete bell, grounded row geometry.
**Reject full cemetery appearance:** emissive window is conspicuously flat/green;
grave clue cylinders, dark rectangles, large boundary walls and sparse landscape
remain provisional. An actor in staged stills appears elevated; these frames do
not establish actor grounding/anatomical approval. No whole-art approval is added.
Native real-input grounding is separately proven on the physical shrine leg.

## Running Steps / Remaining Work

## Follow-up Composition - 2026-09-27

Eleven deterministic meshes now total **135,161 bytes / twenty surfaces**. The
original four resources are unchanged. Pointed low-emission glazing, memorial
bell/cloth/iron evidence, irregular soil and four fitted boundary parts replace
the flat window, capsule clues and rectangular grave patches. Boundary visuals
follow the actual original river-safe collision transforms, not nominal builder
coordinates. Moss follows the same corrected north-wall transform. Horizontal
soil now has XZ UVs instead of the degenerate XY strip that looked like timber.

Elna's two visual-role aliases incorrectly selected a male hooded crowd body
despite her female asset database entry. Both now select the already accepted
`villager_female_human` mapping; actor ID, dialogue, animation and collision stay
unchanged. An intermediate `widow_elna` visual alias produced an explicit
diagnostic-fallback warning and is rejected. No missing acceptance record was
invented to silence it.

The apparent elevated-actor question is resolved at bounded diagnostic scope:
CPU-skinned geometry spans Y=-0.043..1.622, foot bones are near Y=0.051, and
actual fixed-camera projection places the cemetery approach feet at Y-pixel
436. Private Skin, full LOD and identical uncompressed mesh copies did not alter
the picture; original geometry is already uncompressed. The bell-view root
projects to pixel (259.71,534.57), where the feet appear, with foreground grave
occlusion making contact ambiguous. These experiments do not establish a
renderer fault or full character visual approval. No experimental character
resource or import changes are retained. The failed unavailable `surface_get_lods`
diagnostic is rejected and its exact owned process was interrupted safely.

Latest checks under `D:/Temp/AshenOath/`:

- `world001_cemetery_soil_bake_20260927`: PASS eleven resources.
- `world001_cemetery_soil_contract_20260927.verify_cemetery_architecture`: PASS
  exact source/asset hashes, 150 KB budget, materials and horizontal soil UVs.
- `world001_cemetery_final_20260927.contract`: PASS actual complete builder,
  role alias, fitted boundary/collider envelopes, five interactions, routes and
  budgets (849 nodes, 193 meshes), clean exit without fallback or renderer error.
- `world001_cemetery_final_20260927.visual`: PASS four current native 1280x720
  captures, explicitly staged art evidence, clean shutdown. All four inspected.
- `world001_cemetery_final_route_20260927`: FAIL; shrine dialogue did not record
  a choice although the helper printed interaction PASS. Preserved as failed.
- `world001_cemetery_final_route_v2_20260927`: PASS genuine copied save,
  keyboard Continue, physical doorway, focus/E, actual dialogue and cleansed
  choice, clean shutdown. Helper now waits for the current visibility validator
  and interaction guard, and requires dialogue to open for dialogue interactions.
  No teleport, story mutation, direct interaction handler or save editing.

Current reviewed frames: `.release-gate/world001_cemetery_final/`:

| Image (20260927_201219.png) | SHA-256 |
|---|---|
| WORLD-014_01_Cemetery_Approach | 3b399be9282f667994d06bac516c04c59dc8361303d0c62b1aaeba7bf2f6dcc9 |
| WORLD-014_02_Grave_Court_Crows | 014a56b90d5371ea0715af052f0553ec75f85d91364bc65a8178d606c9a9c6ce |
| WORLD-014_03_Ruined_Crow_Chapel | 0fe56ae69bf2290fb770ec4340b42d40f9cb7e3ded3f3f3bf4e3ec48059f988e |
| WORLD-014_04_Bell_and_Shrine | 47e80196e64411dfa6db0f604c15bd5954e809c53b6e6dde076fbed9745c00ab |

Retain this coherent correction. Full scene remains unaccepted: sparse smooth
horizons, simple row/piers and generic green glazing still limit composition.
These four images supersede the earlier rejected boundary-placement and soil
captures for this implementation, not broader campaign or performance evidence.

Next closure work is Wychwood's scene-level terrain and meaningful investigation
presentation. Shared PERF-001 remains red; no Web export or production change.

## Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, use isolated
APPDATA/LOCALAPPDATA under `D:/Temp/AshenOath`, never the normal player profile:

```powershell
$godot = 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/build_cemetery_architecture.gd
& $godot --headless --path . --script res://tools/verify_cemetery_architecture.gd
& $godot --headless --path . --script res://tools/verify_world_014.gd
& $godot --path . --resolution 1280x720 --script res://tools/capture_world_014.gd -- --output-dir=res://.release-gate/world001_cemetery_candidate
# Continue only from an isolated copy of the genuine chapel checkpoint:
& $godot --path . --script res://tools/verify_opening_real_input_native.gd -- --continue-cemetery
```

Next: remaining opening composition at scene scope, then the shared first-control
performance dependency. PERF-001 remains red; settled-only results cannot certify
hydration. No Web export, commit, push, merge or deployment occurs here.
