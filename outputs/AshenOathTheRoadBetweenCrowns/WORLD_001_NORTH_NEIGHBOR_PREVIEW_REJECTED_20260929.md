# WORLD-001 north-route preview rejected (2026-09-29)

The trial removed only Greyfen's north synthetic ridge and placed a non-colliding forest-floor, tapering track and tree batches beyond the Wychwood gate. It was an attempt to show the adjacent route as physical depth rather than another backdrop. Gameplay collision, gate, quests and actors were unchanged.

`verify_world_012.gd` exited 0 and reported 859 nodes, 184 meshes and 2 lights. The graphical `capture_world_012.gd --landscape-only` process also exited 0 and wrote 1280x720 images under `.release-gate/world001_north_route_preview_20260929/`. Both full logs reported an unapproved `CommonTree_3.obj` lookup. The verifier's PASS marker and exit code therefore do not establish a clean candidate; the error was outside its explicit assertions.

The same-camera spawn image exposes a blue horizontal void after the ridge is removed. The route looks like a pale flat plane, while the trees neither establish a grounded destination nor improve the street composition. This candidate fails the visual and resource gates. Only its source edits were removed; the images and logs remain as diagnostic evidence:

- `D:/Temp/AshenOath/world001_north_preview_verify_20260929.log`
- `D:/Temp/AshenOath/world001_north_route_capture_20260929.stdout.log`
- `D:/Temp/AshenOath/world001_north_route_capture_20260929.stderr.log`

No further generated ridge, track, tree-band or backdrop variant should be attempted under the same mechanism. WORLD-001 remains pending, formal acceptance is **27/37**, and no Web export, commit, push or deployment occurred.
