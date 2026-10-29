# Anwen reconstruction: REWORK, not a completed vertical slice

## Honest result

The audit rejects the prior 32 replacements plus Kael as production art. This pass makes real changes to Anwen's anatomy, UV/material source and editable garments, but **does not achieve the requested 4/5 gate**. It is not a finished likeness, a user-accepted asset, or an approved runtime replacement. No production push/deployment occurred. Ghoulkin and Bell-Eater remain locked.

## Actual changes

- Replaced the generic low-detail facial foundation with a CC0 MakeHuman anatomical head, derived from female young/old morph data and further shaped at the jaw, cheeks, nasal bridge, brow and nasolabial region. The exact upstream version, source data and licenses are retained; this is not claimed as a from-scratch scanned/specialist portrait sculpt.
- Kept the 76-joint body contract. Repositioned the eleven existing facial controls to the new landmarks and weighted the new eyelid, mouth and jaw regions. Eye geometry is separately bound to the eye controls. Full blink/lip performance has NOT been established.
- Rebuilt the gown as six-gore layers with an open front, seams, visible linen, a continuous belt, revised buckle and separate shawl. Seams use the garment's weight policy, not a rigid pelvis-only attachment.
- Tried fitted hair geometry, rejected face-covering output, and preserved a review-only fitted card/braid derivative. Its current dark, blunt profile is still wrong for Anwen's pale, pinned reference. It needs substantial restyling, not an approval label.
- Created baked base-color, tangent normal and packed ORM review textures. Three exported mesh/material groups separate face, body and hair. This is a review derivative, NOT an optimized game-ready asset.

## Visual scores and named remaining failures

| Required category | Score | Evidence / remaining failure |
| --- | ---: | --- |
| Reference fidelity | 2/5 | Recognizably human but not the reference individual. Hair, facial age/character and shawl silhouette are not faithful enough. |
| Anatomy / structure | 3/5 | Better ear/nose/jaw/lid topology. Neck/collar transition, retained hands/boots and garment joins still need refinement. |
| Materials / craftsmanship | 2/5 | Textured skin and baked PBR exist, but clothing remains too regular and hair reads as dark broad cards. Material presence is not realism. |
| Distinctive identity | 2/5 | Bell and slate/linen layering help; the intended mature, attentive individual has not been convincingly captured. |
| In-engine presentation | 2/5 | Neutral and genuine prepared-Greyfen captures expose harsh cloth shading, hair silhouette and collar defects. No lighting change was used to hide them. |
| Deformation / motion | 2/5 | The existing AnimationTree owner advances the body. The skirt distorts, staff contact/grip are not grounded, and convincing Anwen-specific motion remains unproven. |

These are critical subjective reviews, not scientific measurements. All scores fail the >=4 requirement. The next substantive art work is likeness and age sculpting, pinned hair reconstruction, garment drape/edge/contact refinement and staff-specific performance. More repeated procedural volume tweaks are not a defensible substitute. The useful foundation is retained, but the professional craftsmanship requested is still unfinished.

## Inspectable files

- Editable layered source: `models/C01_anwen_reconstruction_v002.blend`.
- Original: `../design_pack_v1/models/C01_anwen_v001.blend` (unchanged).
- Blender views: `exports/front.png`, `side.png`, `rear.png`, `quarter.png`, `face.png`.
- Full 36-view orbit: `evidence/blender_turntable.gif` and its original `exports/turntable/*.png` frames.
- Before/reference/current comparison: `evidence/anwen_comparison.jpg`.
- Godot neutral views, actual AnimationTree walking frames, actual prepared Greyfen and camera views: `evidence/godot/`.
- Motion preview: `evidence/godot_walk.gif`. This is in-place review playback, not movement/footstep gameplay acceptance.
- Runtime review GLB: `outputs/AshenOathTheRoadBetweenCrowns/art_review/anwen/anwen_review.glb` relative to the repository.
- Exact source/export/capture sizes and SHA-256 identities: `evidence/identities.json`.
- All-asset criticism and three largest discrepancies per asset: `AUDIT.md`, with nine baseline comparison sheets and source inventory under `evidence/baseline/`.

Godot review viewer (no journey/save service): run the pinned Godot executable with `--path outputs/AshenOathTheRoadBetweenCrowns --script D:/Projects/AshenOath/art_source/art_recovery_v2/tools/review_scene.gd -- --interactive`. It captures the review first, then provides orbit/zoom and idle/walk inspection. Drag left mouse to orbit, wheel to zoom, Space to toggle walking. This is not the campaign and is not represented as a playable accepted slice.

## Checks actually performed

- Opened all 33 Blender source files read-only for geometry/material/rig/action inventory; rendered all 33 exported GLBs in Godot Compatibility from four directions against all 32 reference sheets. Kael has no individual supplied sheet: reference-fidelity score remains NR.
- Blender rendered Anwen's neutral front/side/rear/three-quarter/detail and full orbit. Several intermediate attempts were visibly rejected; rendering alone did not establish success.
- Baked/imported the review GLB. First bake failed because removing old UV layers invalidated the retained layer reference; the bake script was corrected to remove layers by name, then completed.
- Export structural inspection: **22,668,420 bytes, 109,892 triangles, 3 meshes, 3 materials, 76 joints**. This is too heavy to treat as an approved runtime NPC. No LOD, memory or performance compliance is claimed.
- Exporter warned about multiple image-node samplers, unused vertex color and more than four source influences after subdivision. The exporter limits/normalizes exported influences; deformation still needs art/technical work. These warnings are not hidden or counted as visual passes.
- Godot imported textures and the body. Neutral captures use the project's existing shared library and AnimationTree driver. An initial review script mistakenly selected a backward clip by substring; it was corrected to the exact forward `Walk` and then to the actual driver-owned path. Discard the earlier raw backward-clip captures as locomotion evidence.
- Launched the actual main scene only through its menu-covered Greyfen preparation, with input isolated in a SubViewport. The journey was never started and no New Game/Continue/choice/save action was invoked. Captures use the real prepared level lighting and game Camera3D, repositioned for art inspection; they are NOT a player playthrough.
- That level inspection exposed a baseline ecology publication bug: IDs containing `:` were invalid metadata keys, breaking the duplicate-publication guard. Only the transient metadata key was sanitized; interaction/evidence/save IDs remain unchanged. The affected prepared-Greyfen capture was rerun; the corrected log has no corresponding metadata errors.
- PowerShell guard syntax was parsed; no production packaging/push was invoked. The release tool now refuses the rejected-art hold and checks the brief's stricter 100-MiB recovery ceiling before a future Web copy.

## Budget / publication

The existing published package is **242,429,964 bytes**, exceeding this brief's 104,857,600-byte boundary by **137,572,364 bytes**. The earlier repository policy is 256 MiB; this recovery explicitly retains the stricter brief as an additional hold. No claim is made that the new, unoptimized review GLB solves the full-game budget. Do not discard content, anatomy or quality to make that claim.

Current branch: `codex/art-recovery-anwen`. Production, `web/`, runtime role registries and earned saves are unchanged by the review asset. The only gameplay-source correction is the identified ecology metadata key. All unaccepted art stays isolated. **This recovery remains unfinished.**
