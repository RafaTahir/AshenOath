# WORLD-001 Authored Greyfen

## Result

Greyfen's environment now belongs to a dedicated zone builder. The opening route keeps its established interactions and navigation while gaining a clearer village silhouette, grounded modular roofs and gables, visible rear facades, textured staggered paving, role-specific plaster/timber variation, and selected full-tree perimeter landmarks.

## Files Changed

- `scripts/zones/greyfen_section.gd`: authored environment composition and landmark ownership.
- `scripts/game.gd`: modular house shells, closed gables, facade variation, and dense paving.
- `curated_runtime_assets.json` and `export_presets.cfg`: four licensed village modules included in the runtime contract and Web package.
- `tools/verify_world_001.gd`, `tools/capture_world_001.gd`, and `tools/run_release_gate.ps1`: mandatory structural, route, budget, and graphical acceptance.

## Acceptance

- Four distinct route houses retain collision and use modular roofs, door/window facades, and chimneys.
- Spawn-to-Wychwood, shrine, bridge, cemetery, and NPC routes remain unchanged and traversable.
- Balanced Greyfen remains inside its 1,350-node, 420-mesh, ten-skeleton, and eight-light budgets.
- Graphical captures are stored as `Development_Gallery/screenshots/WORLD_001_*.png` at native 1280x720.
- The authoritative release gate passed at 37.0 FPS average and 34.9 FPS minimum, with a 137 ms warm transition.
- The verified Web package is 63.39 MB and passed packed-startup validation.

## Known Limits

The retained modular assets are deliberately low-poly. WORLD-001 improves composition, structure, materials, and route presentation; it does not claim photoreal buildings or replace the character art.

## Next Ticket

`WORLD-002` should apply the same authored-zone contract to Wychwood's investigation route and combat clearing.
