# WORLD-001 North Road Depth Trial (2026-09-29)

Decision: rejected. Recovery acceptance remains 27/37.

The Greyfen horizon stage temporarily replaced the north perimeter ridge with
a non-colliding textured road continuation and reallocated the existing distant
tree instances around that route. No playable surface, gate, bridge, spawn,
river rule or collision changed. `verify_world_012.gd` passed. The graphical
`capture_world_012.gd --landscape-only` pass produced current 1280x720 spawn
and bridge frames in `.release-gate/world001_north_road_candidate_20260929/`;
its full console output is in
`D:/Temp/AshenOath/world001_north_road_capture_20260929.log`.

The fixed spawn view exposes a blue void behind the village where the old
ridge met the sky. It makes the settlement look less bounded and does not
resolve the road/work-area composition. This is a visual failure even though
the structural check and image capture completed. Only the trial edits in
`scripts/zones/greyfen_section.gd` were removed. The captured images remain
diagnostic evidence, not approved screenshots.

The next Greyfen horizon attempt must use a materially different, scene-level
method with a continuous authored background; do not repeat a perimeter ridge,
terrain strip, alpha card or road-extension tweak. PERF-001 remains separately
red on cold first-visible rendering. No Web export, commit, push or deployment
occurred.
