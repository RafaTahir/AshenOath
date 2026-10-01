# BOSS-001 Result - Accepted Boss Runtime Framework

Status: scoped boss runtime acceptance restored on 2026-09-26; not production release approval.

Fresh Halvern review found a missing weapon and a face-obscuring oath effect.
The authored hand-bone sword, calibrated grip and lower effect now pass the
scoped native equipment gate and current visual review (`BOSS-006_*_20260926_132908`).
Bell-Eater's baked hollow bell and torso-bound harness replace its root-mounted
proxy anatomy. Current phase images (`BOSS-003_*_20260926_134249`) and graphical
phase/checkpoint/death/reward/aftermath checks pass. Both role manifests now record
their actual approved dependencies. Capture fixtures were corrected to retain
physical floor support and prevent scene managers from moving actors during review.

Rootbound's corrected facing and mesh-fitted chest-bone wound now pass the clean
`rootbound_approved_native.log` check and reviewed three-phase captures
`BOSS-004_*_20260926_143330.png`. Runtime file/license/hash validation passes.
Ashwing's harness/core now follows its imported Body bone. Its dedicated phase
scale no longer gets overwritten by generic sigil logic, and emission no longer
clips to yellow or washes out the body. All three `BOSS-005_*_20260926_144009.png`
frames were reviewed; `ashwing_final_20260926/verify_boss_005.log` passes graphical
interruption, phase, checkpoint, reward, aftermath and no-respawn checks.
`ashwing_approved_native.log` passes cleanly and actual asset/license/hash checks
pass. All four reopened runtime policy discrepancies are resolved. Unaffected
mechanics and real-input boss-defeat evidence are retained. No combat rules or
saved choices changed. Full campaign/browser/performance acceptance remains open.

## Delivered

- Bell-Eater, Rootbound Colossus, Ashwing, Halvern, and the White Hart use
  declared complete runtime bodies, authored arena centers, phase telegraphs,
  health checkpoints, reload-safe state, rewards, and persistent aftermath.
- Halvern and the White Hart preserve peaceful resolutions without duplicate
  reward emission; combat resolutions remain available where authored.
- Every declared reward token and aftermath state is now applied exactly once
  by the shared boss-resolution contract and survives ordinary save state.
- Bell-Eater's chest harness was reduced to a readable bell silhouette.
  Ashwing moved from inside the mill roof sightline to an unobstructed east-yard
  arena. Rootbound, Halvern, and the Hart received collision-free arena framing.
- The finale verifier now requires the approved native 38-bone stag and rejects
  the removed root-mounted identity layer and proxy antlers.

## Verification

- `tools/verify_boss_001.gd`: PASS for finale combat handoff.
- `tools/verify_boss_002.gd`: PASS for data, phases, checkpoints, peaceful
  resolution, persistence, and feedback integration.
- `tools/verify_boss_003.gd` through `tools/verify_boss_007.gd`: PASS with zero
  parser, compile, or runtime errors after the final arena and reward changes.
- `tools/verify_boss_resolution.gd`: PASS for malformed-state rejection,
  one-shot peaceful resolution, reward idempotence, and resolved-state reload.
- `tools/verify_hart_stag.gd`: PASS for the grounded 3.6 m native stag,
  authored materials, complete animation set, and 38-bone skeleton.
- Fresh 1280x720 phase evidence is stored in
  `Development_Gallery/screenshots/BOSS-003_*_20260921_015356.png` through
  `BOSS-007_*_20260921_015532.png`.
- Detailed strict logs are under `D:\Temp\AshenOath` with the prefixes
  `boss001_batch_`, `boss001_repair_v2_`, `boss001_resolution_`, and
  `boss001_visual_final_`.

## Remaining Scope

The boss bodies, readable combat spaces, and encounter contracts are accepted.
Final building, terrain, vegetation, water, sky, and interior art remain owned
by `WORLD-001`, `WORLD-002`, and `PRES-001`; their current blockout-grade areas
are not claimed as final environment art by this ticket.

## Running Steps

```powershell
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --script tools/verify_boss_003.gd
& $godot --headless --path . --script tools/verify_boss_004.gd
& $godot --headless --path . --script tools/verify_boss_005.gd
& $godot --headless --path . --script tools/verify_boss_006.gd
& $godot --headless --path . --script tools/verify_boss_007.gd
& $godot --headless --path . --script tools/verify_boss_resolution.gd
& $godot --headless --path . --script tools/verify_hart_stag.gd
```
