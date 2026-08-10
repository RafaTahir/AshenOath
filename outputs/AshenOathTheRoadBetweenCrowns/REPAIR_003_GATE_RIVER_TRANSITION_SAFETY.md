# REPAIR-003 — Gate, River, And Transition Safety

## Files Changed

- `scripts/game.gd`
- `scripts/zone_spatial_service.gd`
- `scripts/zones/castle_vargan_section.gd`
- `tools/verify_gate_transitions.gd`
- `tools/verify_navigation_001.gd`
- `tools/verify_river_swimming.gd` (verification only when updated in the branch)

## Fixes

- Reserved Castle approach, courtyard, and Record Hall corridors before scenery placement.
- Removed the solid Castle gatehouse slab and lowered/opaque portcullis obstruction; the visual gate now has open passage geometry.
- Prevented generated trees and solid props from occupying reserved gate/route corridors.
- Added player-sized capsule sweeps to every real gate approach in both travel directions.
- Preserved bridge-only river traversal and same-bank recovery through the shared spatial service.

## Verification

- `tools/verify_gate_transitions.gd` — PASS, including capsule-swept approaches and bidirectional released-zone travel.
- `tools/verify_navigation_001.gd` — PASS.
- `tools/verify_river_swimming.gd` — PASS.
- `tools/verify_castle_vargan.gd` — PASS.

## Running Steps

```powershell
cd outputs/AshenOathTheRoadBetweenCrowns
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_gate_transitions.gd
```

## Remaining Issues

- Visual gate landmarks still need the Milestone 2 world-presentation pass.
- Headless dummy renderer teardown warnings remain diagnostic noise after successful route completion.

## Development Checkpoint

Pending the Milestone 1 development branch commit.
