# SOUL REBUILD Actual Completion Checkpoint

## Status

This is a development checkpoint for the current uncommitted recovery work.
It is not a claim that all 62 Soul Rebuild tickets or the final production
release are complete. The deployed production baseline remains unchanged.

## Completed In This Checkpoint

- Added idempotent resource shutdown and cache clearing for zone, material,
  visual, streaming, and runtime-pack services.
- Retired zone roots through scene-tree ownership instead of direct renderer
  teardown, and extended the lifecycle verifier to exercise final shutdown.
- Corrected the Oathblade hilt/base/tip markers to the modeled blade axis and
  reduced the custom blade scale so sword readability and contact traces share
  one authoritative geometry.
- Corrected Anwen's acceptance check to measure the rendered visual forward
  direction rather than the calibrated actor wrapper basis.
- Repaired face-verifier cleanup so test-owned scenes are queued and released
  through the scene tree without active null-material errors.
- Made the authored sky backdrop visible during outdoor day, dusk, and night
  phases. Day now renders soft layered cloud formations and a restrained solar
  disc; night renders the moon and stars; interior sky remains suppressed.
- Removed the legacy 3D cloud cards from the rendered path on Compatibility /
  ANGLE while retaining their deterministic quality accounting.
- Updated sky verifiers to assert the rendered authored backdrop contract rather
  than treating hidden legacy cloud-card nodes as visual proof.
- Corrected project-state and release-document headers so historical release
  claims cannot be mistaken for this uncommitted source state.
- Replaced the floating rectangular crow-wing proxies with small connected
  body/head/beak/wing/tail silhouettes that receive shared bird motion and no
  longer read as detached geometry around Kael.
- Added a bone-attached, world-upright staff treatment for Sister Anwen so the
  prop follows her hand without becoming a horizontal chest bar. The character
  bounds verifier now excludes declared equipment sockets from body-height
  measurements rather than accepting a false giant actor.
- Extended the authored Greyfen roof treatment into Balanced mode using the
  existing modular roof source, while retaining a lightweight Potato fallback.
  Boss silhouette dressing now uses capsule/cylinder forms instead of the old
  hard rectangular add-ons.
- Added visible directional current ribbons to the river surface. They animate
  with the existing river controller and remain a lightweight Compatibility-safe
  fallback rather than changing bridge-only navigation or recovery.
- Brightened and reshaped the Oathblade material and ready pose so the modeled
  sword is visible from the gameplay-facing side. Animation capture now refreshes
  the hand-attached pose after seeking clips and frames the visible front.
- Added deterministic cleanup to the combat, Oathfire, water, world, animation,
  and character capture paths. A deferred autosave is now cancelled at the
  resource-shutdown boundary, and normal saves still reject invalid live actors.

## Verification

The following targeted gates passed after the code changes:

- `run_ticket_gate.ps1 -Profiles characters -NoCache`
- `run_ticket_gate.ps1 -Profiles combat -NoCache`
- `run_ticket_gate.ps1 -Profiles world -NoCache`
- Direct `verify_oath_001.gd` after the deferred-autosave fix.
- Direct `verify_engine_003.gd` after the save/lifecycle fix.
- Graphical `capture_sky_003.gd` on Godot Compatibility / ANGLE at 1280x720.
- Graphical `capture_water_002.gd`, `capture_world_001.gd`,
  `capture_character_real_portraits.gd`, and `capture_anim_003.gd` all produced
  fresh nonblank evidence.

Fresh sky evidence is in:

`Development_Gallery/screenshots/SKY-003_*_20260821_073334.png`

The crow cleanup is visible in the fresh Greyfen frames:

`Development_Gallery/screenshots/WORLD_001_*_20260821_073732.png`

Additional current evidence includes:

- `Development_Gallery/screenshots/WATER-002_01_Greyfen_Bridge_Current_20260821_080026.png`
- `Development_Gallery/screenshots/WATER-002_02_Wychwood_Bridge_Current_20260821_080026.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_sister_anwen.png`
- `Development_Gallery/screenshots/ANIM_003_07_Shared_Presentation_Contact_Sheet.png`

The graphical capture produced nonblank 1280x720 Greyfen, Wychwood, Castle,
and Record Hall frames. Isolated Godot process exit still prints shutdown-only
allocator/RID/ObjectDB diagnostics; those are not active-frame renderer errors
but remain a lifecycle cleanup item for the final release gate.

## Remaining Release Blockers

- Monster and boss mappings still include interim low-poly/fallback sources;
  the final cohesive asset pipeline and visual acceptance are unfinished.
- Anwen's staff, the river current, house roofs, boss dressing, and sword
  readability are improved in this checkpoint, but they are not substitutes for
  the approved final character, monster, building, and boss asset families.
- Later campaign architecture, river/bridge composition, and Hart Glade still
  need the locked visual standard and fresh full-route evidence.
- The full campaign, ending, save-permutation, and browser route have not been
  re-proven from this exact source state.
- A fresh Web export, packed startup, local/live PCK comparison, Git push, and
  Vercel deployment have not been run after these edits.
- Godot still reports shutdown-only RID/ObjectDB allocator diagnostics after
  isolated process exit. Active-frame targeted gates are clean, but final release
  must either eliminate or formally classify these diagnostics.

## Exact Local Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
$env:GODOT_BIN = "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe"
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles characters -NoCache
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles combat -NoCache
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles world -NoCache
& $env:GODOT_BIN --path . --script tools\capture_sky_003.gd --display-driver windows --rendering-method gl_compatibility --rendering-driver opengl3
```

Do not use this checkpoint as production deployment evidence until the
remaining visual, full-route, export, and live-hash gates pass.
