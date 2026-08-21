# BOSS-006 Result

## Checkpoint

Development checkpoint on `codex/soul-rebuild`, 2026-08-21. Halvern is now a
reload-safe parry/testimony encounter slice; this is not production approval.

## Changes

- Extended the Halvern definition with an authored undercroft arena,
  checkpoint objective, phase actions, and peaceful-resolution metadata.
- Corrected the Halvern runtime mapping from the missing legacy alias to the
  connected `gravebound_knight_creature` source.
- Added a Vargan cuirass, grave-seal, asymmetric shoulder armor, and broken
  banner identity layer under the boss visual root.
- Added a `parry_window_opened` enemy signal. A successful player parry now
  records the Halvern guard break, completes the real guard-break objective,
  shows the testimony guidance, and preserves the existing combat feedback.
- Verified phase-two checkpoint/health restoration and negotiated testimony
  resolution. A resolved Halvern remains absent after an undercroft reload.
- Added three fresh 1280x720 Compatibility captures for the gate stance,
  parry window, and refusal phase.

## Verification

- `verify_boss_006.gd`: PASS - connected mapping, identity, animation driver,
  real parry, guard-break objective, phase checkpoint/health restore,
  testimony resolution, and no-respawn reload.
- `capture_boss_006.gd`: PASS - fresh native-720p nonblank frames.
- `tools/gate_profiles.json`: parsed successfully; BOSS-006 is registered in
  spectacle and `boss_halvern`.
- `git diff --check`: PASS.

The isolated Godot process still emits known shutdown-only renderer/RID/ObjectDB
cleanup diagnostics after assertions pass. They remain ENGINE-004 lifecycle
debt and are not suppressed.

## Screenshots

- `Development_Gallery/screenshots/BOSS-006_01_Halvern_TheGate_20260821_095819.png`
- `Development_Gallery/screenshots/BOSS-006_02_Halvern_ParryWindow_20260821_095819.png`
- `Development_Gallery/screenshots/BOSS-006_03_Halvern_TheRefusal_20260821_095819.png`

## Known limitation

The undercroft lighting remains too dark for final visual acceptance and the
connected Gravebound family remains an interim low-poly monster/armor source.
The next lighting/material pass must improve readable face, armor, and arena
contrast without changing the combat state machine.

## Running steps

```powershell
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --log-file "$PWD\.release-gate\boss_006_verify.godot.log" --headless --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/verify_boss_006.gd
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --log-file "$PWD\.release-gate\boss_006_capture.godot.log" --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/capture_boss_006.gd
```

## Release status

No Web export, `main` push, `web/` synchronization, or Vercel deployment was
performed. Production remains on the prior verified build.
