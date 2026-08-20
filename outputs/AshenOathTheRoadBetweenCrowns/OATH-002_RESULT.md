# OATH-002 Result

## Changes
- Preserved the existing single Oathfire state machine and initial-facing lock.
- Added endpoint-specific impact feedback using the same collision-clipped endpoint as the beam resolver.
- Sword sheathing, hand-origin charge, release timing, cancellation, stamina, cooldown, and cleanup remain under the existing PlayerController contract.

## Verification
- Existing `verify_oath_001.gd` remains the regression gate.
- Endpoint feedback is covered by the combat feedback source contract; a fresh charge/release capture is still required after Godot runtime startup is repaired.

## Running steps
Hold `C`, wait for the hands to charge, release, and rotate the camera during charge. The release remains aimed at the direction captured on initial press.
