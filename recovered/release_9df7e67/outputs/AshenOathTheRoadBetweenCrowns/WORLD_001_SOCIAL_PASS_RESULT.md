# WORLD-001 Greyfen Social Quarter

Retained partial implementation/evidence, 2026-09-27. WORLD-001 remains pending;
recovery remains 27/37 accepted. This is not full scene, browser or release approval.

## Changes

- Replaced proxy tables, unsupported chair panels and Mira's slab canopy/crates
  with existing CC0 Quaternius Fantasy Props MegaKit geometry.
- Three grounded, compressed two-surface meshes: common table 36,480 bytes/1,978
  triangles; barrel board 36,504/1,978; apothecary 83,054/4,618. Total 156,038 bytes.
- Measured the native countertop at 0.7771 m. Five bottles rest 3 mm above it;
  their frontage and cloth coloring are readable in the final camera comparison.
- Preserved board cells, opponents, markers, actors, interaction areas, shop
  transactions, collision, quests, saves and routes. No collision bodies added.
- Recorded licenses/hashes/bytes and explicit production/QA/base-pack ownership.
  Source OBJ files are not newly included in the base export.
- Added `greyfen_social` targeted profile and mandatory milestone resource checks.
- Captures now foreground their native window, matching other graphical fixtures.
  Removed the temporary batch of readiness diagnostics after the final capture.

## Evidence

All command logs below are under `D:/Temp/AshenOath/`.

- `world001_social_fit_20260927`: bake, resource/support and complete-dressing
  minigame contracts PASS; normal exit without parser/renderer/shutdown errors.
- `world001_social_owned_20260927`: provenance, nonnull materials, finite geometry,
  grounded supports, stock fit, license and base-export ownership PASS. Repeated
  bake produces identical SHA-256 hashes for all three meshes.
- `world001_social_baseline_20260927` and `world001_social_final_20260927`: clean
  graphical captures. The unsuccessful background capture is retained as failed
  evidence, not substituted for the final pass. ANGLE driver advisory only.
- Codex actually inspected the three before/after 1280x720 views. Native chair
  legs/rung backs replace floating panels; cloth is supported; stock is visible.
  This bounded composition is retained. World-wide terrain, banks, horizons and
  character-pose polish are NOT approved by these images.
- `world001_social_perf_20260927.report.json`: FAIL. Settled Greyfen 55.653 FPS
  average/33.654 FPS 1% low, 263 draws, 99,337 primitives, 1,130 nodes, 83,499,261
  memory bytes. Post-control hydration 10.794/0.725 FPS over 13,619 ms, worst
  frame 1,721.773 ms. Warm New Game handoff 150.48 ms. The settled sample is not
  full PERF-001 acceptance or a controlled attribution of performance gains.

## Image Identity

Before: `.release-gate/world001_social_baseline/`.
Retained final: `.release-gate/world001_social_final/`.

| Image | SHA-256 |
|---|---|
| WORLD_001_Social_Spawn.png | ab1e888661b694b276e6520af1bdf1bbe586cd5c563f4c13c634897e8f360bf8 |
| WORLD_001_Social_Table.png | 879ed58ba4f0693d66787772a2af62511fb8983e67352fa73e3ecbc16bc979b0 |
| WORLD_001_Social_Apothecary.png | 8b688a615025cf7eeeb5e959bd089cd836c7747e71d48564587afef7a719e24d |

These staged visual frames are not player-route proof or QA-003 gallery approvals.
The runtime mesh hashes are recorded in `runtime_asset_manifest.json`; subsequent
metadata/test-only changes did not change the rendered meshes or composition.

## Running Steps

Project: `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`.

```powershell
$godot = 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/build_greyfen_social.gd
& $godot --headless --path . --script res://tools/verify_greyfen_social.gd
& $godot --headless --path . --script res://tools/verify_minigame_presentation.gd
& $godot --path . --script res://tools/capture_world_012.gd -- --social-only --output-dir=res://.release-gate/world001_social_final
& $godot --path . --script res://tools/verify_perf_001.gd -- --zone=greyfen
```

Use an isolated `D:/Temp/AshenOath/` QA user-data directory for tests. No checkpoint
commit, push, merge, export or deployment. Cumulative work is preserved. Next:
remaining authored opening composition and first-control performance, then
source-aligned browser certification. Production remains unchanged.
