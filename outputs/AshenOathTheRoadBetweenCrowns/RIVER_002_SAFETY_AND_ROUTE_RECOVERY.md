# RIVER-002 - River Safety and Route Recovery

## Changes
- Converted Greyfen and Wychwood rivers to scenic bridge-only landmarks.
- Removed player swimming, breath, current, and water combat states.
- Narrowed both channels and rebuilt bridge approaches, rails, bank barriers, and recovery volumes.
- Limited recovery volumes to moving characters so static river collision cannot be relocated.
- Added nearest-bank recovery for accidental entry, under-bridge falls, and legacy saves.
- Sanitized interactions, enemies, NPC schedules, grass, trees, deadfalls, terrain overlays, and collision props against the river corridor.
- Kept all route objectives and the complete Wychwood encounter on dry reachable ground.

## Verification
- `tools/verify_river_swimming.gd` now checks bridge-only behavior, barriers, clear approaches, spatial conflicts, NPC routes, enemy positions, save migration, and forced recovery.
- `tools/verify_runtime.gd` confirms the complete Road of Crows route still works.

## Player Experience
Use the plank bridge to cross. The banks prevent accidental entry. If geometry or an old save places Kael in the channel, he is returned immediately to the nearest bank without damage.
