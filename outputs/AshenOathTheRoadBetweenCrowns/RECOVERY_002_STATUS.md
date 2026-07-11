# RECOVERY-002 Status

## Release State

RECOVERY-002 implementation, local acceptance, Web export, and packed startup are complete. Production remains on the previous verified commit until the deployment steps finish.

## Completed Foundations

- Wychwood and Greyfen transition corridors are reserved before scenery placement.
- Trees are rejected from route, gate, river, and combat-clearing reservations.
- Tree collision now follows the trunk instead of the full crown.
- Character interaction sizing no longer multiplies rendered human scale.
- Character bounds are measured from skinned anatomy rather than equipment.
- Imported mesh surfaces receive explicit fallback materials when their source material is null.
- NPC and routine animation can suspend beyond the active presentation range.
- Detached-zone interactions are cleared before quest tracking and compass refresh.
- Batched visual and terrain marker nodes are released after their transforms are copied.
- Greyfen and Wychwood procedural placement uses stable seeds.

## Passing

- `tools/verify_recovery_002_foundation.gd`
- `tools/verify_runtime.gd`
- `tools/verify_zone_budgets.gd`
- Runtime, story, character, motion, river, Greyfen, Castle, audio, visible-quality, VISUAL-003, Visual100, Master-002, and Master-003 gates.
- Fresh native 1280x720 gameplay captures and a native 1920x1080 menu capture.
- Intel HD 620/ANGLE performance: 37.2 FPS average, 35.6 FPS minimum, 294 ms warm transition.

Current structural measurements:

- Greyfen: 1,095 nodes, 363 meshes, 10 skeletons, 6 lights.
- Wychwood: 339 nodes, 103 meshes, 5 skeletons, 6 lights.
- Castle sections and Hart Glade remain below the initial structural budgets.

## Known Limitations

- The environment and character assets remain visibly low-poly and below the Witcher-inspired art benchmark.
- Godot emits dummy/GLES resource teardown diagnostics after verifier scenes quit; active surfaces pass explicit material validation.
- Cold first construction is slower than the warm transition budget and still needs a presented loading state.

## Deployment

Git push, Vercel propagation, PCK identity, and live-browser verification are the remaining release steps.
