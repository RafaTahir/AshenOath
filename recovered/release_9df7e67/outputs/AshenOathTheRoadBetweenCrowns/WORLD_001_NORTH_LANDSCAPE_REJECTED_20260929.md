# WORLD-001 North landscape trial (2026-09-29)

Status: rejected visual candidate. Formal acceptance remains **27/37**.

The candidate replaced only Greyfen's north perimeter strip with a deeper,
non-colliding forest-ground landscape and placed the existing distant tree
batch on its contour. Its focused geometry check passed: 2,080 upward-facing
triangles, textured material, finite positions outside the playable zone and
substantial elevation variation. The fixed 1280x720 spawn camera nevertheless
showed a large sky gap and dark road-end band behind the village. It was less
coherent than the retained scene. Geometry validity did not establish visual
quality.

The candidate builder, tree repositioning and candidate-specific verifier
changes were removed with scoped edits. The original horizon verifier passes
again: `D:/Temp/AshenOath/world001_north_landscape_reject_verify_20260929.log`.
Diagnostic capture remains at
`.release-gate/world001_north_landscape_candidate_20260929/`; it is not
approved evidence. The previously retained Greyfen social square and
Wychwood integrated-ground changes remain intact.

No further generated ridge, terrain ring or valley variant should be tried
without a materially new authored environmental asset or scene composition
method. The north/cemetery horizon cells stay red. Do not use this failed
candidate to approve WORLD-001, PRES-001, PERF-001, or a Web export. No commit,
push, merge or deployment occurred.
