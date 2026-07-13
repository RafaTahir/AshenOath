# NAV-001 Navigation Foundation

## Files Changed

- `scripts/zone_spatial_service.gd`
- `scripts/greyfen_life_controller.gd`
- `scripts/enemy_ai.gd`
- `scripts/game.gd`
- `tools/verify_navigation_001.gd`
- `tools/run_release_gate.ps1`
- `PROJECT_STATE.md`

## Implementation

- Added authored, deterministic navigation polygons for Greyfen and Wychwood. No runtime baking is used.
- Centralized bridge anchors, gates, reserved corridors, exclusions, route validation, bank identity, occupancy checks, and recovery in `ZoneSpatialService`.
- Routed all seven retained Greyfen villagers through `NavigationAgent3D` with limited updates, pauses, and safe-stop behavior.
- Routed all five Wychwood enemies through navigation-aware pursuit and flanking without changing combat statistics, staging, leash distance, or attack timing.
- Rebound navigation agents when cached zones return and retained cached navigation regions to avoid transition hitches.
- Unified player spawn, loaded-position migration, enemy spawn, and river recovery with the active spatial service.
- Preserved a collider-tested Wychwood return-gate corridor through existing reserved-volume scenery checks.

## Verification

- `verify_navigation_001.gd`: PASS
- `verify_runtime.gd`: PASS
- `verify_river_swimming.gd`: PASS
- `verify_greyfen_life.gd`: PASS
- `verify_recovery_002_foundation.gd`: PASS
- `verify_asset_001.gd`: PASS
- Graphical 720p: PASS, 38.2 FPS average, 36.7 FPS minimum, 246 ms warm transition
- Temporary Web preview: PASS, 63.1 MB total, 26.8 MB PCK
- Packed Web startup: PASS

Headless and graphical shutdown still report the previously classified renderer/RID cleanup warnings. NAV-001 introduced no active parser, assertion, resource, navigation, or packed-startup error.

## Release State

This is development ticket 7. It is committed and pushed to `codex/studio-recovery-tranche-001`. Production Web files and Vercel are intentionally unchanged until ticket 10.

## Running Steps

The production build remains available at `https://ashenoath.vercel.app/`. To test source changes before ticket 10, run the project from Godot 4.6.3 with `scenes/main.tscn`, or create a temporary Web export and serve its folder with Python's `http.server`.
