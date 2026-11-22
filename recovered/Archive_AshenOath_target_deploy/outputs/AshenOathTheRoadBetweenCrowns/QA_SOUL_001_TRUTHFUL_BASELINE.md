# QA-SOUL-001 Truthful Baseline

Generated 2026-08-13 from the current `codex/soul-rebuild` workspace on the Dell 7280 Intel HD 620 ANGLE Compatibility path.

## Historical evidence

The before-state uses preserved gallery images and repository history. It is **not an original-state recapture** and does not claim that old source can be reconstructed from the current workspace.

| View | Preserved before evidence | Current identical-view evidence |
|---|---|---|
| Menu | `UI_001_Main_Menu_Prestige_2026-06-22_121334.png` | `QA-SOUL-001_01_Main_Menu_20260813_181721.png` |
| Kael | `Capture_62_polish_kael_character_2026-07-06_004051.png` | `QA-SOUL-001_02_Kael_20260813_181721.png` |
| Anwen | `15_Phase1G_shrine_sister_anwen_2026-06-21_161132.png` | `QA-SOUL-001_03_Anwen_20260813_181721.png` |
| Greyfen | `13_Phase1G_greyfen_spawn_2026-06-21_161128.png` | `QA-SOUL-001_04_Greyfen_20260813_181721.png` |
| River | `Capture_70_greyfen_river_bridge_2026-07-07_123747.png` | `QA-SOUL-001_05_River_20260813_181721.png` |
| Wychwood | `02_PrePhase_forest_trail_2026-06-18_164814.png` | `QA-SOUL-001_06_Wychwood_20260813_181721.png` |
| Combat | `03_PrePhase_combat_clearing_2026-06-18_164816.png` | `QA-SOUL-001_07_Combat_20260813_181721.png` |
| Castle | `Capture_36_vargan_approach_2026-07-05_134705.png` | `QA-SOUL-001_08_Castle_20260813_181721.png` |
| Hart | `Capture_41_white_hart_glade_2026-07-05_134705.png` | `QA-SOUL-001_09_Hart_20260813_181721.png` |

All paths are under `Development_Gallery/screenshots/`.

## Current measurements

| Measurement | Result | Target | Status |
|---|---:|---:|---|
| Scene/menu ready | 9285 ms | <= 15000 ms cold | Pass, but too slow for the 750 ms first-paint ambition |
| New Game | 6205 ms | <= 750 ms | Fail |
| Wychwood transition | 716 ms | <= 900 ms cold / <= 350 ms warm | Cold pass; warm fail |
| Castle approach transition | 371 ms | <= 350 ms warm | Fail |
| Hart Glade transition | 366 ms | <= 350 ms warm | Fail |
| Greyfen average / 1% low | 55.7 / 28.6 FPS | >= 32 / >= 30 FPS | 1% low fail |
| Wychwood average / 1% low | 52.7 / 26.0 FPS | >= 32 / >= 30 FPS | 1% low fail |
| Static memory after route | 84.6 MB | < 450 MB | Pass |
| Greyfen nodes / draws / primitives | 1301 / 243 / 240674 | Baseline only | Recorded |
| Wychwood nodes / draws / primitives | 1745 / 99 / 32658 | Baseline only | Recorded |
| Final unique active materials | 108 | Baseline only | Recorded |

The compact sampling window is a recovery baseline, not a substitute for the later sustained performance gate.

## Current visual debt

- Menu hierarchy is readable, but the backdrop remains sparse and strongly geometric.
- Kael and Anwen are not reliably face-readable in live-world framing. The Anwen baseline is obstructed by a large black prop and therefore fails presentation acceptance.
- Several player poses read as crouched or contorted when the capture camera is detached from normal gameplay framing.
- Greyfen still exposes box buildings, hard terrain seams, floating light motes, sparse horizons, and oversized HUD coverage.
- River motion is visible, but the water channel, banks, rails, and bridge remain geometric and weakly integrated.
- Wychwood uses repeated low-detail tree silhouettes, flat forest-floor treatment, and visible rectangular dressing.
- Combat has readable participants and spacing, but monster identity and contact presentation remain basic.
- Castle Vargan is visibly blockout-grade with primitive columns, empty ground, and minimal architectural hierarchy.
- The White Hart remains a procedural placeholder and the glade lacks finale-grade composition.
- The runtime emitted a river MultiMesh interpolation warning during active capture.
- Graphical shutdown still emits GLES material, mesh, shader, buffer, RID, and ObjectDB cleanup diagnostics. They are recorded debt, not hidden as a pass.

## Baseline use

Future Soul Rebuild visual tickets must retain these camera IDs and compare their changed views against this evidence. A ticket may improve one view without claiming unrelated views are approved.
