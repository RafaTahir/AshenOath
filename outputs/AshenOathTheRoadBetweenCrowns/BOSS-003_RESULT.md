# BOSS-003 Result

## Checkpoint

Development checkpoint on `codex/soul-rebuild`, 2026-08-21. Bell-Eater is
implemented as a reload-safe first boss slice; this is not production approval.

## Changes
- Bell-Eater uses a dedicated data definition with a bounded cemetery arena,
  three telegraphed phases, phase-specific action labels, optional Ghoulkin
  call, silent-bell aftermath flag, and a visible harness/chest-bell identity.
- Boss checkpoints now persist phase, checkpoint health ratio, health, and
  called-Ghoulkin metadata. Resolved bosses are suppressed on rebuild so a
  defeated encounter cannot silently respawn.
- Boss identity dressing is owned by one animated layer so chains, shoulders,
  bell, eyes, and phase sigil move together.
- Bell-Eater now uses a dedicated `bell_eater_boss` visual role normalized to a
  3.80 m focal-creature contract. Its collision capsule uses the same
  encounter scale instead of remaining human-sized under a second multiplier.
- The derived GhoulBrute source now faces Kael correctly and the old floating
  proxy torso/arm rods are removed. Jaw, teeth, horns, harness, chest bell,
  and phase light remain one identity layer.
- Sister Anwen and Widow Elna evacuate the cemetery arena while the boss is
  active and return to their saved positions after victory.

## Verification
- `verify_boss_002.gd`: PASS.
- `verify_boss_003.gd`: PASS - phase transitions, checkpoint health restore,
  aftermath, and no-respawn.
- `verify_mon_002.gd`: PASS.
- `verify_char_001.gd`: PASS after the explicit monster-facing contract.
- `verify_perf_003.gd`: PASS.
- `capture_boss_003.gd`: PASS - fresh 1280x720 Compatibility frames after the
  focal-creature scale and arena-clearance pass.

## Screenshots

- `Development_Gallery/screenshots/BOSS-003_01_BellEater_Harnessed_20260821_133853.png`
- `Development_Gallery/screenshots/BOSS-003_02_BellEater_Unchained_20260821_133853.png`
- `Development_Gallery/screenshots/BOSS-003_03_BellEater_HollowBell_20260821_133853.png`

## Remaining

The implementation slice now proves state, scale, facing, telegraph
presentation, and arena evacuation. The body is still an interim low-poly
family mapping and the surrounding cemetery remains below the final visual
bar. Full real-input campaign play, all-boss acceptance, final visual review,
Web export, and deployment remain pending. Godot still reports
renderer/RID/ObjectDB cleanup diagnostics when the isolated process exits;
those are recorded as lifecycle debt rather than suppressed.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/verify_boss_003.gd
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script tools/capture_boss_003.gd
```
