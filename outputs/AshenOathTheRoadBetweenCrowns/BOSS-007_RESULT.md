# BOSS-007 Result

## Checkpoint

Development checkpoint on `codex/soul-rebuild`, 2026-08-21. The White Hart
encounter slice is implemented and targeted-verified; this is not production
approval.

## Changes

- Added a data-driven White Hart arena, phase actions, checkpoint objective,
  peaceful-resolution contract, reward, and aftermath state.
- Added a restrained memory-covenant identity layer: ground halo, chest oath
  mark, phase-reactive memory rings, and existing bone-attached antler crown.
- Added a dedicated `white_hart_boss` role contract at 3.60 m with a corrected
  3.30 m collision capsule, same-source legacy compatibility, and a measured
  -1.90 m imported Wolf ground offset. The encounter and witness display now
  share the same focal scale instead of shrinking the creature at runtime.
- Added phase-specific White Hart colors and motion while preserving the
  connected animated wolf source, leash, collision, and existing ending handoff.
- Added Mercy/Witness/Duty/Ash covenant normalization through the existing
  peaceful-resolution and combat-ending paths.
- Added a verifier for identity, animation, phase transitions, checkpoint
  restore, peaceful Mercy resolution, objective completion, save reload, and
  no-respawn behavior.
- Added three fresh native-720p Compatibility captures for the Witness, Mercy,
  and Debt phases.

## Verification

- `verify_boss_007.gd`: targeted pass required for the White Hart contract,
  phase checkpoints, Mercy resolution, save reload, and no respawn.
- `capture_boss_007.gd`: targeted pass required for three fresh nonblank
  1280x720 frames.
- `tools/gate_profiles.json`: parsed successfully; BOSS-007 is registered in
  spectacle and `boss_white_hart`.
- `git diff --check`: required to pass.

The isolated Godot process may still emit known shutdown-only renderer/RID/
ObjectDB cleanup diagnostics after assertions pass. They remain ENGINE-004
lifecycle debt and are not suppressed.

## Screenshots

- `Development_Gallery/screenshots/BOSS-007_01_Hart_Witness_20260821_141248.png`
- `Development_Gallery/screenshots/BOSS-007_02_Hart_Mercy_20260821_141248.png`
- `Development_Gallery/screenshots/BOSS-007_03_Hart_Debt_20260821_141248.png`

## Known limitation

The current Wolf-derived body with antler crown is a connected, animated
interim Hart source. It is now grounded and readable at gameplay distance,
but it is not the final supernatural stag; the final visual gate still requires
a more distinctive creature-family asset/material treatment and stronger Hart
Glade architecture.

## Running steps

```powershell
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --log-file "$PWD\.release-gate\boss_007_verify.godot.log" --headless --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/verify_boss_007.gd
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64.exe" --log-file "$PWD\.release-gate\boss_007_capture.godot.log" --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/capture_boss_007.gd
```

## Release status

No Web export, `main` push, `web/` synchronization, or Vercel deployment was
performed. Production remains on the prior verified build.
