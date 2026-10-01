# PERF-001 Material vs Mesh First-Reveal Discriminant

Date: 2026-09-29. Diagnostic only. No production source, quality setting, or
acceptance threshold changed. PERF-001 remains pending.

The same fully hydrated Greyfen scene was built with 3D viewport drawing
disabled, then exposed for 90 graphical native Compatibility frames. One run
kept authored materials; a second overrode the same MeshInstance3D nodes with
one neutral StandardMaterial3D only after all source-dependent role/material
selection was complete. The temporary verifier was removed after the runs.

| Case | Meshes | Surfaces | Draws | Primitives | First/worst reveal frame |
| --- | ---: | ---: | ---: | ---: | ---: |
| Authored | 211 | 265 | 255 | 131,864 | 322.495 ms |
| One diagnostic material | 211 | 265 | 255 | 131,864 | 203.991 ms |

Both owned processes exited 0 and had no active renderer or resource errors.
The neutral case was not a candidate visual setting: it loses authored colors,
textures, cutouts and material response. Runs were sequential and used warm
driver caches, so their 118.5 ms difference is not a controlled cold-start
speedup. They show that removing material diversity alone does **not** remove
the large first-visible frame with unchanged mesh submission.

The earlier rendered/no-3D comparison and WebGL program-link probe remain
valid at their original scopes. Together they implicate 3D first-use work, but
do not establish one exclusive shader, mesh upload, GL wait or driver owner.
The next intervention must address the shared complete-scene render ownership
and survive menu-to-control, hydration and settled graphical gates, not merely
move the stall or discard authored material quality.

Evidence: `D:/Temp/AshenOath/perf_material_owner_20260929/original.log`,
`original.json`, `neutral.log`, and `neutral.json`. No Web export, commit,
push or deployment occurred.
