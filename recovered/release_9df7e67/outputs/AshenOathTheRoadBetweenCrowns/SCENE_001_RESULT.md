# SCENE-001 Result

Status: accepted on 2026-09-19.

## Delivered

- Added `scenes/runtime/greyfen_gameplay_core.tscn` as a root-resident authored
  PackedScene rather than a marker shell.
- Packed four terrain collision slabs, one continuous bridge corridor, three
  road surfaces, routed berms, invisible world boundaries, and stable route
  anchors for spawn, Anwen, Wychwood, Deep Wood, Castle, shrine, and river.
- Made `ZoneBuildContext` register the authored ground/bounds contract and
  resolve interaction positions from scene anchors.
- Made Greyfen skip duplicate procedural ground, road, bridge-surface, and
  boundary construction when the authored core is present.
- Attached the same gameplay layer in cold activation and menu prewarm, with
  duplicate attachment rejected. Decoration, river rendering/audio, actors,
  quest state, and recovery signals remain safely deferred or runtime-owned.
- Included the core in production Web, QA Web, and standalone base-pack filters
  without moving the opening pack back onto the first-control critical path.

## Verification

- `verify_scene_001_opening_core.gd`: PASS with clean shutdown. It rejects a
  marker-only scene, missing collision, wrong bridge dimensions, missing route
  anchors, duplicate catalog attachment, and river-visual hydration drift.
- `verify_load_001.gd`: PASS. Greyfen authored-core prewarm built in 436 ms and
  the cached New Game handoff completed in 11.3 ms.
- `verify_river_swimming.gd -- --greyfen-only`: PASS. The actual Kael
  `CharacterBody3D` crossed centered and off-center in both directions without
  jump, snag, teleport, or river recovery.
- Static pack/readiness gates: `verify_load_qa_002.py`,
  `verify_web_preset_parity.py`, and `verify_runtime_packs.py` all PASS.
- v107 runtime packs: seven packs, 56.45 MB total.
- v107 QA Web candidate: 14 files, 96.5 MB; root PCK 8.6 MB; SHA-256
  `ecc7faba47764ef815c20b4d6a74f714dcfe5a60f8a139f4aeced6253b9d5f66`.
- Hardware Chrome/Intel HD 620 ANGLE D3D11: PASS, 24 real-input opening-route
  checkpoints, zero console errors/warnings, zero network failures, Greyfen to
  Wychwood fight and return completed. Evidence:
  `D:\Temp\AshenOath\recovery004_scene001_v107\chrome_opening_v107.json`.

## Scope Boundaries

- This ticket accepts Greyfen's gameplay-core scene contract; it does not claim
  the deferred village art is final. That remains `WORLD-001`.
- The broad river suite subsequently exposed an unchanged Wychwood return
  collision at `z=1.67`. Greyfen passed before that failure. The Wychwood defect
  remains under `TRAV-002` and was not hidden or folded into this ticket.
- No commit, push, merge, production sync, or deployment was performed here.

## Running Steps

```powershell
cd D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
& 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_scene_001_opening_core.gd
& 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_load_001.gd
& 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_river_swimming.gd -- --greyfen-only
```
