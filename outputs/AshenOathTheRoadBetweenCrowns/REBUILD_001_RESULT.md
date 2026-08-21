# REBUILD-001 Result

## Scope

This development slice addresses the highest-impact visible/runtime defects
without adding unapproved external assets:

- Human locomotion now uses a retargeted neutral Walk/Sprint/Roll library.
- Root motion tracks are removed during animation retargeting.
- Player exploration starts with a back-mounted scabbard; combat draws and
  later re-sheathes the sword.
- Castle patrol movement drives the walk animation instead of sliding in idle.
- Castle Vargan named roles resolve to skeletal visuals instead of capsules.
- Guards, patrols, stewards, and record keepers receive role equipment.
- The ledger and post-victory token are physical readable world props.
- Quest beat lookup is wired to the active objective.
- The opening conversation has explicit Anwen response choices.
- Five-evidence investigation creates a visible safe combat edge and the
  post-victory token creates an inspectable narrative handoff.
- Recorded voice files no longer override subtitles with browser TTS. Scratch
  voice is classified as development material; browser speech is opt-in.
- Sun/cloud presentation is no longer a visible screen-space CanvasLayer.
- River water uses a subdivided flow surface with 30 Hz dressing updates.
- Castle approach/courtyard/Record Hall receive bounded architecture and
  occupancy dressing.
- Board games now exist at physical tables with chairs, opponents, pieces, and
  a proximity beckoning gesture; draughts exposes selected/legal destinations.
- Boss special attacks now have directional/laned hit rules and distinct
  release geometry.
- Monster definitions carry memory rules and motivations which surface on the
  first relevant defeat.

## Verification

Passing targeted checks on the development branch:

- `tools/verify_runtime.gd`
- `tools/verify_motion_quality.gd`
- `tools/verify_castle_vargan.gd`
- `tools/verify_sky_003.gd`
- `tools/verify_water_002.gd`
- `tools/verify_voice_001.gd`
- `tools/verify_char_006.gd`
- `tools/verify_char_007.gd`
- `tools/capture_anim_003.gd`
- `tools/capture_world_005.gd`

The graphical capture used the Intel HD Graphics 620 through ANGLE. Existing
Godot Compatibility shutdown RID/ObjectDB diagnostics remain after verifier
pass markers; they are tracked lifecycle debt, not active gameplay errors.

## Release Boundary

This is an ordinary development ticket on `codex/roadmap-ashen-rebuild`.
Tracked `web/`, `main`, and Vercel production are intentionally unchanged.
Production export and real-hardware campaign certification remain milestone
work after the new asset/package budget is measured.

## Still Open

- Final bespoke human wardrobe and facial diversity still require approved
  rigged assets.
- Final human voice acting is still required; existing WAVs are scratch TTS.
- Castle geometry is substantially improved but remains a procedural runtime
  composition until authored scene layers replace the remaining blockout.
- White Hart and several bosses still need bespoke production bodies.
- A full Dell 7280 30 FPS 1% low soak and final Web package comparison must
  run before any production merge.
