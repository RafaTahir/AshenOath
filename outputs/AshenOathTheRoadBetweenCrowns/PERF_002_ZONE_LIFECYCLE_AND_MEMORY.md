# PERF-002 — Zone Lifecycle and Memory

## Files Changed

- `scripts/game.gd`
- `scripts/asset_spawn_helper.gd`
- `scripts/world_material_library.gd`
- `tools/verify_engine_003.gd`
- `tools/verify_perf_002.gd`

## Implementation

- Bounded the route cache to one inactive zone.
- Added explicit active, cached, and retiring ownership states.
- Removed HUD-only quest tracking from the world-state cache signature.
- Added staged zone retirement and complete render-material validation.
- Replaced the malformed legacy animated Skeleton FBX and unstable temporary
  monster GLTF with a proven CC0 shared rig. Horror materials and role
  silhouettes remain temporary until `MON-001`.
- Split renderer disposal into hide, quiesce, detach, synchronize, and free
  stages. Hidden geometry is rebound to a game-owned retirement material before
  detachment so ANGLE never observes a null material RID.
- Retain at most one disabled skinned instance per shared mesh resource and a
  bounded set of material references. No AI, active animation, collision, or
  complete zone remains resident through this workaround.
- Added bounded transition history and lifecycle metrics for nodes, skeletons,
  navigation regions, static memory, cache size, and anchor count.

## Performance Contract

- Cache: at most one inactive zone.
- Shared skinned-resource anchors: at most eight.
- Retired material references: at most sixty-four.
- Transition history: at most sixteen samples.
- Repeated-route static-memory growth: at most 16 MB.
- No duplicate active navigation regions.
- At least one measured warm return completes within 350 ms in the verifier.

## Known Limitation

The shared enemy body is intentionally temporary. `MON-001` remains responsible
for final Ghoulkin family meshes, materials, silhouettes, and distinct animation.

## Latest Measurement

- Greyfen: 33.2 FPS average, 24.4 FPS 1% low.
- Wychwood: 40.1 FPS average, 34.7 FPS 1% low.
- Castle courtyard: 41.9 FPS average, 36.9 FPS 1% low.
- Record Hall: 47.1 FPS average, 41.3 FPS 1% low.
- Hart Glade: 48.6 FPS average, 38.2 FPS 1% low.
- Warm cached return: 120.3 ms.
- Repeated-route static-memory growth: 15.1 MB.

## Running

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://tools/verify_perf_002.gd
```
