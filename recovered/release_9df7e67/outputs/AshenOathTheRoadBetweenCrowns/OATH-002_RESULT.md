# OATH-002 Result

## Changes
- Consolidated Oathfire transitions behind one state contract: `sheathing` -> `charging` -> `releasing` -> `redrawing` -> idle.
- Transition locking now cancels an active cast exactly once, restores the sword, hides charge effects, clears the locked direction, and records the cancellation reason.
- The initial flattened facing is reused for the player pose, hand-origin sphere, release signal, collision resolver, beam endpoint, and impact feedback. Zero/invalid directions fall back to the player forward.
- Added `PlayerController.get_oathfire_state()` for truthful runtime inspection.
- Cast telemetry now records the collision-clipped endpoint distance.
- Added `tools/verify_oath_002.gd` for hand-origin charge, sheathing, initial-facing lock, one-shot release, stamina/cooldown state, wall clipping, transition cancellation, and VFX cleanup.

## Verification
- `verify_oath_002.gd`: run in the current development workspace.
- `verify_oath_001.gd`: existing regression gate remains required.
- `verify_runtime.gd`, `verify_combat_001.gd`, and `verify_content_integrity.py` remain the compact regression set for this ticket.

## Running steps
Hold `C`, wait for the hands to charge, release, and rotate the camera during charge. The release remains aimed at the direction captured on initial press. To exercise the browser build, enter Greyfen, face the road, hold `C` for about one second, rotate the camera, and release. Crossing a gate or opening a menu during charge cancels safely.
