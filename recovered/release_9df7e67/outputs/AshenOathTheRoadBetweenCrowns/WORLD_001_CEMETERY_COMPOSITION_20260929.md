# WORLD-001 Cemetery Composition Review (2026-09-29)

Status: retained partial improvement; **cemetery visual cell remains pending**. Formal recovery acceptance remains 27/37. No production export or deployment occurred.

The bounded edit varied the 216-triangle grave-row mesh, replaced boxy gate-pier visuals while keeping their collision envelopes, moved the chapel memory window onto the visible side wall, and added a noncolliding distant tree line. Only `Cemetery_grave_rows_Authored.res` was rebuilt. Its SHA-256 is `2906609dfdae7132ea4ad5aa1940dfbc53618f36ae80e59fc7b9046d4385b3eb`; `runtime_asset_manifest.json` was updated to match.

Direct checks passed: `verify_cemetery_architecture.gd`, `verify_cemetery_stages.gd`, `verify_world_014.gd`, and a clean native Intel HD620 Compatibility capture. Final 1280x720 evidence in `Development_Gallery/screenshots/`:

| View | SHA-256 |
| --- | --- |
| `WORLD-014_01_Cemetery_Approach_20260929_003954.png` | `21beac35faec0251962e177fa256f74975e93b93f077df94efbbc9c174955ecf` |
| `WORLD-014_02_Grave_Court_Crows_20260929_003954.png` | `cbbaed73470a6d683254c0c3e73a13a51a07e3224010a887678ead452f957079` |
| `WORLD-014_03_Ruined_Crow_Chapel_20260929_003954.png` | `e8fe95d6fd17b4f265203e87f4eac5faccfcbd28ef15ae4653f28f62cd475a4d` |
| `WORLD-014_04_Bell_and_Shrine_20260929_003954.png` | `c3653481c2ce94b0bf372f490a0204c3275fe5c535a02074c40733dfe919ee1b` |

Visual review: the treeline, grave profiles and pier silhouettes improve the original repeated blockout rhythm. The smooth pale perimeter remains visible behind the trees, however, and the relocated chapel window reads chiefly as a dark outlined opening rather than legible glazing. The four captures are staged visual evidence, not a fresh uninterrupted player route, graphical performance acceptance, or actor-grounding proof. Retain the verified changes but do not approve the cemetery cell yet.

Next: one source-backed cemetery correction for the exposed backdrop and window material/readability, then affected native proof and one matching-camera capture batch. After that, continue the finite Greyfen and Wychwood cells. No Web export while `PERF-001` is native-red.

## Shared-ridge and glass correction, same day

The shared Greyfen horizon ridge now varies its height and vertex tone instead of presenting a nearly level pale band. The memory-window glass was recolored and moved slightly ahead of the masonry. A first brighter-emission candidate failed the existing `verify_cemetery_architecture.gd` slab guard and was not retained. The corrected mesh keeps the required 0.15 emission multiplier and passes that contract (137,312 total cemetery resource bytes); `verify_world_001.gd` also passes. The regenerated window resource is 3,948 bytes, SHA-256 `a166114e611c871ffbf0b1a2fc112d0b3c6d5d54402bf064ad3ceb7252c9745c`.

The native Intel HD620 Compatibility capture in `.release-gate/world001_cemetery_horizon_v2/` produced four same-camera 1280x720 frames with suffix `20260929_005017` and exited cleanly. Codex inspected the approach and bell/shrine views. The ridge is less uniform and the small window reads as muted green glass, but the scene still has a visibly smooth synthetic perimeter and sparse built context. **The cemetery cell remains pending.** This is the second distinct bounded attempt (tree masking, then shared-ridge geometry); more prop-level additions are not justified by these results. Next visual intervention must change the landscape/scene-authorship level and be judged with the same cameras. No performance or player-route acceptance is inferred.
