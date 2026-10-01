# WORLD-002 Bandit Road Composition - 2026-09-28

## Current Follow-Up Verdict

The current retained candidate is under
`D:/Temp/AshenOath/bandit_road_art_retained_v4/` and
`D:/Temp/AshenOath/bandit_road_identity_retained_v4/`. A closer command tent,
table and two budgeted nighttime torch pools improve orientation; the tracker
atlas is now charcoal rather than Kael-like green. The unchanged player-sized
route and exact resource/hash contract passes after the moved tent was pulled
out of the diagonal sector lane. The checkpoint resource is 26,164 bytes;
the road landscape remains 5,682 bytes. Both graphical captures exit 0 with
only the two declared, unapproved bandit-role diagnostics.

This is still **not** a WORLD-002 or bandit-role acceptance. The identical-camera
day frame remains a broad flat plain with a small camp, and the night frame
does not reveal the road guards. Both actual guard close-ups still show the
same civilian peasant body despite distinct palettes and hand-attached
weapons. A twelve-patch road-wear layer was rejected because it rendered as
black holes. Quaternius knight helmets and shoulder pads were attached to
real head/spine bones and passed a structural fixture, but the 1280x720
close-ups at `D:/Temp/AshenOath/bandit_road_identity_v3/` show oversized masks
and worse silhouettes. Their runtime attachment and export references were
removed. The failed candidate images remain diagnostic evidence only.

Two different composition/identity treatments have failed the visual contract.
Park further Bandit Road prop tuning. Its next useful intervention is a
coherent authored terrain/architecture and role-specific skinned costume
pass, followed by one same-camera and real-input review. Native PERF-001 is
independent and remains the next release-critical dependency. No Web export,
commit, push, merge or deployment has occurred.

## Outcome

Retained partial native improvement, **not WORLD-002 acceptance**. Formal
Recovery-004 count remains 27/37 accepted, 9 pending, 1 visually rejected.
Production is unchanged.

## Changes

- Replaced the pale-green road mesh with a narrower, brown, slightly winding
  route and two darker wheel tracks. The playable floor and gate locations are
  unchanged.
- Replaced two scaled Castle towers with asymmetrical stone-and-timber road
  watchposts. A raised lintel, cloth standards, shoulder fencing and a moved
  camp make the checkpoint legible from the approach.
- Added the existing non-colliding far-terrain mesh to close the dark horizon.
  The camp, lintel and fences have matching authored collision; the former
  decorative ditch colliders were removed.
- Rebuilt the two affected campaign resources and updated their exact
  byte/hash/triangle records. Unrelated wilds resources rebaked byte-identical.

## Evidence

- Baseline: `D:/Temp/AshenOath/bandit_road_art_baseline/`.
- First candidate: `D:/Temp/AshenOath/bandit_road_art_candidate_v1/`.
- Retained source-backed candidate: `D:/Temp/AshenOath/bandit_road_art_candidate_v2/`.
  Each has 1280x720 arrival-day, arrival-night and checkpoint-day captures plus
  a camera/source-hash report. The arrival is from a copied genuine saved
  Continue; the fixed checkpoint camera is visual-only, not route proof.
- `build_campaign_wilds.gd`: seven resources baked cleanly. Bandit landscape
  5,682 bytes / 256 triangles; checkpoint 26,009 bytes / 1,730 triangles,
  below the unchanged 60,000-byte per-mesh contract.
- `verify_campaign_wilds_composition.gd`: owned exit 0, current resource/hash,
  material and player-capsule central, approach, diagonal and both gate sweeps
  pass. The one failed intermediate run was a mistyped manifest SHA and was
  corrected against the measured file hash, not waived.
- Current graphical Continue/capture: owned exit 0. The two explicit
  unapproved bandit-role warnings remain; no active resource/renderer error
  was observed in this capture.
- `verify_bandit_road_identity.gd` now loads the two actual Senn guards from
  the copied pre-fight save, not an isolated costume preview. Both have a
  65-bone Universal skeleton, active animation and an authored sword attached
  to `hand_r`; the tracker also has a wooden buckler attached to `hand_l`.
  Graphical 1280x720 gameplay and close images, source paths, socket names and
  image hashes are in `D:/Temp/AshenOath/bandit_road_identity/`. Import,
  identity capture, Halvern equipment regression and the unchanged campaign
  wilds/capsule contract all exit 0. The expected diagnostic-role warnings
  remain because these visuals are not yet release-approved.
- The character runtime-pack preset explicitly lists both new GLTF descriptors,
  their PNG atlases and the wooden shield. The roles reuse existing geometry
  buffers. This is static packaging only; no new Web artifact or packed-startup
  result is claimed while native PERF is red.

## Visual Verdict And Next Action

The green road, repeated miniature towers and void edge are improved. Codex
still rejects final campaign-world quality: the ground and road remain broad
and flat, the roadside population is sparse, and the night checkpoint is too
dim to communicate its actors and camp. The two bandits are now armed and have
different hair, palette and equipment, but still share the peasant silhouette;
the green tracker reads too close to Kael in the close frame. Do not mark
`WORLD-002` or either bandit runtime role approved, and do not silence the
diagnostic warning via manifest metadata. The next world pass requires
authored terrain, material and lighting treatment at campaign scope, with
a genuinely distinct hostile costume, not one more small prop.
`PERF-001` and the bandit-role acceptance also remain independent release
blockers. No Web export, commit, push or deployment was made.

## Running

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`:

```powershell
& 'C:/Temp/AshenOathGodot4.6.3/Godot_v4.6.3-stable_win64_console.exe' `
  --headless --path . --script res://tools/verify_campaign_wilds_composition.gd
```

Graphical capture uses `tools/capture_bandit_road_recovery.gd` with an isolated
copy of `D:/Temp/AshenOath/senn_fight_v1_fixture/AppData` and an `--output-dir`
under `D:/Temp/AshenOath`; it must not be described as a real-input route.
