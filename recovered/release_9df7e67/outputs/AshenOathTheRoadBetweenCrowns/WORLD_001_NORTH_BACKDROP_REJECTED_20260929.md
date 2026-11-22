# WORLD-001 North backdrop trial rejected (2026-09-29)

An original transparent tree-and-hillside cutout was generated as a materially different alternative to the rejected procedural skyline meshes. It was tested as one non-colliding, alpha-lit distant layer without altering road, gate, collision, actors or the existing ridge/forest.

Godot imported it cleanly and `capture_world_012.gd --landscape-only` passed in a graphical 1280x720 Compatibility viewport. Fixed spawn and bridge frames at `res://.release-gate/world001_backdrop_candidate_20260929/` were inspected. The layer produced only a faint secondary tree line; the smooth hill and north road-end composition remained. Its visual gain did not justify another alpha surface or 0.8 MB texture. The runtime code and asset were removed from the project; the candidate, capture and log remain in `D:\Temp\AshenOath\world001_backdrop_candidate_20260929` for diagnosis. The original generated file remains in Codex's generated-images directory.

WORLD-001 remains open. The next credible horizon change must be an integrated authored 3D landscape/road composition, not another mesh ring or a distant flat cutout. No Web export, commit, push or deployment was performed.
