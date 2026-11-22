# WORLD-001 Landscape Ring Trial, 2026-09-29

Status: **rejected visual candidate**, not WORLD-001 acceptance. Formal recovery
status remains 27/37 accepted, 9 pending, 1 visually rejected. No Web export,
commit, push, or deployment followed.

The scene-level trial replaced Greyfen's four distant ridge strips with one
collision-free, 480-triangle textured terrain ring. It kept the playable
boundary, actors, buildings and route geometry intact. The first capture
exposed downward face winding and a culled top; a focused geometry assertion
found 0/320 upward normals. Reversing winding made the ring structurally valid.
The corrected ring, however, rendered as a broad flat tan band behind the
cemetery rather than a convincing landscape. Both gameplay-camera candidates
are retained only in ignored `.release-gate/world001_landscape_candidate/` and
`.release-gate/world001_landscape_candidate_v2/`.

Focused evidence: `verify_greyfen_horizon.gd`, `verify_world_001.gd`, and
`verify_boundary_stages.gd` passed for the candidate; `capture_world_014.gd`
produced four nonblank 1280x720 views with a clean graphical exit. Image
inspection rejected the result. The ring builder and candidate-specific
horizon test were removed using scoped edits, preserving the earlier authored
cemetery changes. The retained original horizon passes
`D:/Temp/AshenOath/world001_horizon_retain_20260929.log`; boundary parity passes
`D:/Temp/AshenOath/world001_boundary_retain_20260929.log`. The boundary
fixture now includes the already-shipping distant forest on both comparison
paths, correcting a pre-existing false mismatch.

Remaining blocker: Greyfen/cemetery still need a scene-level authored
landscape/background, plus the documented street and Wychwood composition
cells. Do not retry a smooth ridge, flat textured ring, or tree-mask treatment
as visual acceptance. Reuse the existing same-camera views when an actual
authored terrain/forest composition is ready.
