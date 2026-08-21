# BOSS-004 Result

## Checkpoint

Development checkpoint on `codex/soul-rebuild`, 2026-08-21. Rootbound
Colossus is implemented as a reload-safe Deep Wood encounter slice; this is
not production approval.

## Changes

- Extended the Rootbound definition with a bounded memory-clearing arena,
  phase actions, checkpoint objective, and explicit non-peaceful resolution.
- Added a visible Rootbound identity layer: bark harness, root arms and
  branches, bark plate, and an emissive exposed oathwood heart.
- Made the heart phase-reactive and made the identity layer pulse as the
  encounter advances.
- Added a player-state verifier and a graphical Compatibility capture for
  buried, uprooted, and exposed-heart phases.

## Verification

- `verify_boss_004.gd`: PASS - spawn trigger, runtime actor contract, identity
  pieces, phase 2/3, checkpoint health restore, defeat flag, and no respawn.
- `capture_boss_004.gd`: PASS - fresh 1280x720 Compatibility frames.
- JSON parsing and `git diff --check`: PASS.
- Known Godot shutdown-only renderer/RID/ObjectDB diagnostics remain visible
  after isolated verifier/capture processes exit; they are not suppressed and
  remain a release blocker for the final lifecycle gate.

## Screenshots

- `Development_Gallery/screenshots/BOSS-004_01_Rootbound_Buried_20260821_094435.png`
- `Development_Gallery/screenshots/BOSS-004_02_Rootbound_Uprooted_20260821_094435.png`
- `Development_Gallery/screenshots/BOSS-004_03_Rootbound_ExposedHeart_20260821_094435.png`

## Remaining

Rootbound uses the current optimized connected monster source with procedural
identity dressing, so it remains below the final high-fidelity monster bar.
Full real-input campaign play, all-boss acceptance, final visual review, Web
export, and deployment remain open.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/verify_boss_004.gd
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/capture_boss_004.gd
```
