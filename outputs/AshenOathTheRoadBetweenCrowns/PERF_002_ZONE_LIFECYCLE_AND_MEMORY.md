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
- Added a capped eight-branch compatibility anchor for the legacy animated FBX.
- Added bounded transition history and lifecycle metrics for nodes, skeletons,
  navigation regions, static memory, cache size, and anchor count.

## Performance Contract

- Cache: at most one inactive zone.
- Resource anchors: at most eight.
- Transition history: at most sixteen samples.
- Repeated-route static-memory growth: at most 16 MB.
- No duplicate active navigation regions.
- At least one measured warm return completes within 350 ms in the verifier.

## Known Limitation

Godot 4.6.3 Compatibility reports null-material and renderer cleanup warnings
when the quarantined `Skeleton_Animated_CC0.fbx` instances are destroyed at
process exit. Zone transitions do not destroy those anchors during play. The
legacy FBX is scheduled for replacement by `MON-001`; the warning is not
classified as an active gameplay renderer error.

## Running

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://tools/verify_perf_002.gd
```
