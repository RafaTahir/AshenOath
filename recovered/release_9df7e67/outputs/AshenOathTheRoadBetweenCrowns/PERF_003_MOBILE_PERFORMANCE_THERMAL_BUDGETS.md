# PERF-003 - Mobile Performance and Thermal Budgets

## Changes

- First-run touch devices select Potato mode; saved visual choices are preserved.
- Native `1.0` 3D scale remains mandatory because Intel/ANGLE performs substantially worse with viewport scaling.
- Balanced outdoor local lights are capped at two and clouds at two; Potato uses one cloud layer.
- Kael's skeleton evaluates at 30 Hz; NPC and monster skeletons evaluate at 20 Hz while physics, input, collision, and camera updates remain authoritative.
- Hidden NPCs and dormant enemies suspend animation, AI, navigation, collision, and schedule work completely.
- Wychwood enemies remain five distinct opponents but reveal serially, one per wave, with wider collision spacing to prevent pileups.
- Ghoulkin, Stalker, and Brute source rigs now export as one lower-density skinned mesh with no more than six material surfaces instead of dozens of separate mesh objects.
- Runtime interaction, compass, camera collision/focus, audio pools, settings sampling, and zone collision caches avoid redundant per-frame allocation and tree walks.
- Balanced uses cached albedo surfaces on Intel/ANGLE; normals, ORM, and triplanar detail remain a Quality-tier option.
- The source Blender build remains repeatable through `tools/build_character_real_assets.py`.

## Verification

- `verify_perf_003.gd` validates mobile defaults, native scaling, saved-choice preservation, and the optimized monster rig budgets.
- `verify_perf_001.gd` enforces native `1280x720`, at least 32 FPS average, at least 30 FPS 1% low, 450 MB static memory, 350 ms warm transitions, and 900 ms cold fallback transitions.
- Balanced graphical result on the Dell 7280 / Intel HD 620 / ANGLE:

| Sample | Average FPS | 1% low FPS |
|---|---:|---:|
| Greyfen | 55.1 | 30.5 |
| Wychwood | 60.0 | 49.9 |
| Wychwood combat | 59.6 | 37.8 |
| Castle courtyard | 60.0 | 56.3 |
| Record Hall | 60.0 | 54.7 |
| Hart Glade | 60.0 | 52.8 |

- Potato passed the same gate. Its Greyfen result was 56.1 / 34.6, and it retained lower draw-call and primitive budgets in the heavy exterior zones.
- Maximum measured cold transition was 561 ms; warm return was 191 ms. Peak static memory was approximately 79.4 MB.
- Targeted `perf_003`, combat, motion, AI, Oathfire, navigation, river, lifecycle, and zone-budget gates pass.

## Payload

The three optimized monster GLBs replace their previous versions and shrink from approximately 5.13 MB to 2.59 MB combined. No new runtime asset family was added.

## Running

Run `Run_AshenOath_Web.bat`, then open `http://127.0.0.1:8787/?v=perf003`. Touch devices use the safe first-run preset; desktop users can select Potato, Balanced, or Quality in Settings.
