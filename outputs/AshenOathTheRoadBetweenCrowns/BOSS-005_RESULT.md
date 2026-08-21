# BOSS-005 Result

## Checkpoint

Development checkpoint on `codex/soul-rebuild`, 2026-08-21. Ashwing is now a
reload-safe Old Mill boss slice; this is not production approval.

## Changes

- Extended the Ashwing definition with an authored mill arena, checkpoint
  objective, three named phase actions, and explicit non-peaceful resolution.
- Added an Ashwing identity layer: charred harness, emissive ash core, and
  scorched wing roots parented to the boss visual root.
- Added `interrupt_boss_windup()` to the enemy boss contract. It clears the
  active special attack, enters stagger recovery, records the reason, and
  emits an interruption signal.
- Routed the actual Oathfire hit list through Ashwing interruption. A beam hit
  during `ash_breath` now breaks the windup and gives the player feedback.
- Added a runtime verifier for spawn, identity, animation driver, Oathfire
  interruption, phase two/three checkpoints, health restore, defeat state, and
  no-respawn reload behavior.
- Added three fresh 1280x720 Compatibility captures for perceived, scorched,
  and breaking-perch states.

## Verification

- `verify_boss_005.gd`: PASS.
- `capture_boss_005.gd`: PASS; all frames are native 1280x720 and nonblank.
- `tools/gate_profiles.json`: parsed successfully; BOSS-005 is registered in
  the spectacle and `boss_ashwing` profiles.
- `git diff --check`: PASS.

The isolated Godot process still emits known shutdown-only null-material and
RID/ObjectDB cleanup diagnostics after the assertions pass. These remain an
ENGINE-004 release blocker and are not suppressed or counted as a clean
production release.

## Screenshots

- `Development_Gallery/screenshots/BOSS-005_01_Ashwing_Perceived_20260821_095107.png`
- `Development_Gallery/screenshots/BOSS-005_02_Ashwing_Scorched_20260821_095107.png`
- `Development_Gallery/screenshots/BOSS-005_03_Ashwing_BreakingPerch_20260821_095107.png`

## Known limitation

Ashwing currently reuses the optimized animated Dragon runtime source. The
identity layer makes the encounter readable and functional, but the body is
still low-poly/interim and does not satisfy the final cohesive monster-family
visual bar from MON-002.

## Running steps

```powershell
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --log-file "$PWD\.release-gate\boss_005_verify.godot.log" --headless --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/verify_boss_005.gd
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --log-file "$PWD\.release-gate\boss_005_capture.godot.log" --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/capture_boss_005.gd
```

## Release status

No Web export, `main` push, `web/` synchronization, or Vercel deployment was
performed. Production remains on the prior verified build until the complete
visual, lifecycle, campaign, and release gates pass.
