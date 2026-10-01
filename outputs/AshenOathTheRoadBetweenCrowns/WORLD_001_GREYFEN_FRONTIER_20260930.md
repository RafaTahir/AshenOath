# WORLD-001 - Adjoining Landscape Native Decision

Retain the authored landscape; freeze the Greyfen boundary and shared cemetery
backdrop visual cells. Formal recovery remains 27/37. This is not a performance,
full-route, Web or release pass.

`greyfen_frontier.gd` owns one textured control-surface landscape, destination
track and the complete distant-tree population (40 Balanced, 24 Potato).
The four ridge strips are no longer instantiated. Trees share their ground's
height query. The mesh joins the actual 42x34 village floor at x=+/-21 and
z=+/-17, without collision, actors, interaction or processing changes.

Resource: 40,831 bytes, two surfaces, 3,464 triangles; SHA-256
`fd9ac033b74f7655ac70817939bfdb82873bed631fdefe143f399b8cea74b086`.
Textures are the existing licensed forest-ground and wet-mud images.

## Proof

- Bake and `verify_greyfen_horizon.gd` exit 0, clean: full tree population,
  shared grounding, upward normals, floor joins, textures, no collision and
  no art inside the physical core.
- The first full capture exposed reversed winding under back-face culling.
  Corrected triangle order and added the normal assertion before recapture.
  A subsequent capture exposed the old ridge-to-floor offset gap. The baked
  surface now meets the physical-floor extents, not the legacy ridge offsets.
  Failed/intermediate captures remain diagnostic only.
- All four established cemetery cameras in
  `.release-gate/world001_frontier_cemetery_20260930/` were inspected: wooded
  ground replaces the smooth wall; chapel, graves, bell and glazing remain
  readable. Investigation state is staged for art, not real-input proof.
- Spawn, shrine and forge cameras in
  `.release-gate/world001_frontier_joined_20260930/` were inspected: the floor
  gap is closed and the road continues into its wooded valley, without the
  prior perimeter wall. Buildings, actors and approach lanes remain visible.
- Capture processes exit 0. Only the existing classified OpenGL-to-ANGLE
  selection warning appears. No active renderer error.

Raw logs: `D:/Temp/AshenOath/greyfen_frontier_20260930/`.

## Remaining

Street/frontage/drainage connections and wider supported work composition
remain open, as do the failed full return, final FPS/memory and Web proof.

## Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, run Godot
4.6.3 with `--headless --path . --script tools/build_greyfen_frontier.gd`,
then `tools/verify_greyfen_horizon.gd`. Graphical evidence uses the existing
`capture_world_001.gd -- --candidate-dir=res://.release-gate/<unique>` and
`capture_world_014.gd -- --output-dir=res://.release-gate/<unique>` at 1280x720.
