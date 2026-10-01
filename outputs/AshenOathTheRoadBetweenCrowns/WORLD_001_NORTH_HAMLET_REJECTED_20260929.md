# WORLD-001 North Hamlet Trial (2026-09-29)

Decision: rejected visual candidate. Formal recovery acceptance remains 27/37.

One Greyfen scene pass placed two existing authored house meshes beyond the
north gate, tapered the visible main road toward the exit, and blended worn
footpaths into the existing ground surface. It added no collision, interaction,
quest state, pack, or new asset. The affected `verify_world_012.gd` native
contract passed with 859 nodes, 185 meshes and two active lights.

The established 1280x720 spawn and bridge captures are retained under
`.release-gate/world001_north_hamlet_candidate_20260929/`. The matching-camera
review shows the houses hidden by the existing ridge. The central road still
terminates in the visible backdrop gap, and the broad street/work area remains
unconvincing. The pass therefore fails the exact WORLD-001 punch list even
though its structural check passes. Only this trial's runtime edits in
`greyfen_section.gd` and `game.gd` were removed; the cumulative worktree and
diagnostic images remain.

Next: do not repeat a small ridge, ring, road-depth, tree-reallocation or
house-behind-ridge variation. A coherent authored boundary scene, integrated
with the playable exit and camera composition, is still required. Continue
independent closure work while that asset/scene method is prepared. No Web
export, commit, push or deployment occurred.
