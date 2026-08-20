# TARGET-001 Result

## Changes
- Kept target lock optional: the normal camera remains fully free until the player presses `T` or R3.
- Filtered targets by life, encounter activation, range, and two-height line-of-sight checks. Dormant Wychwood enemies can no longer steal focus.
- Added a 0.42-second obstruction grace so a tree or moving actor does not immediately drop the lock; sustained obstruction restores free camera control.
- Added angular target ordering for predictable cycling, mouse-wheel cycling, right-stick cycling, and semantic gamepad axis actions.
- Added gentle camera framing toward the locked enemy without forcing player movement or combat balance changes.
- Added `LOCKED | enemy | distance` HUD feedback and lifecycle cleanup on pause, death, and zone travel.
- Added a graphical target-only capture path and a dedicated `targeting` ticket-gate profile.

## Verification
- `content_integrity`: PASS.
- `runtime_smoke`: PASS.
- `verify_target_001`: PASS.
- `verify_combat_005`: PASS.
- Target-only graphical capture: PASS at native 1280x720 Compatibility rendering.
- Fresh capture inspected by Codex: `Development_Gallery/screenshots/Capture_74_target_001_soft_lock_2026-08-20_161713.png`.
- `git diff --check`: PASS.

The graphical run still reports the repository's known Godot renderer/RID/ObjectDB teardown warnings after successful capture. They are recorded, not suppressed, and are outside the target-lock runtime path. No Web export or production deployment was run for this ordinary development ticket.

## Running steps
1. Start the project from `C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns` with Godot 4.6.3 Compatibility renderer.
2. Start New Game and enter Wychwood.
3. Press `T` to lock the nearest visible active enemy. The marker and `LOCKED | name | distance` readout appear.
4. Press `Y` or `U`, use the mouse wheel, or push the right stick left/right to cycle targets.
5. Move behind scenery to test the brief obstruction grace. Hold the obstruction until the lock clears and free camera returns.
6. Press `T` again, pause, or cross a gate to confirm the lock and marker are cleaned up.

## Checkpoint
Development branch: `codex/soul-rebuild`. Production `main`, tracked `web/`, and Vercel were intentionally left unchanged for this ordinary ticket.
