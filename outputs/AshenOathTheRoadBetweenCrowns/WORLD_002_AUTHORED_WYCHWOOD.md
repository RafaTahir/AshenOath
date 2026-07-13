# WORLD-002 Authored Wychwood

## Result

Wychwood's environment now belongs to a dedicated zone builder. The Greyfen threshold, river crossing, clue road, forest frame, and first combat clearing have distinct authored composition while retaining the established Road of Crows interactions and five-enemy encounter.

## Files Changed

- `scripts/zones/wychwood_section.gd`: authored environment, lighting, route, and clearing ownership.
- `scripts/game.gd`: delegates Wychwood environment construction while retaining gates, clues, quests, herbs, and enemies.
- `tools/verify_world_002.gd`, `tools/capture_world_002.gd`, and `tools/run_release_gate.ps1`: mandatory route, river, encounter, budget, and graphical acceptance.
- `export_presets.cfg`: includes the Wychwood builder in the Web package.

## Acceptance

- The route from Greyfen gate through the bridge and clearing remains traversable in both directions.
- Four Road of Crows clues remain outside the river exclusion zone.
- Five enemies retain staged activation and existing quest progression.
- Balanced Wychwood stays inside the 1,350-node, 420-mesh, ten-skeleton, and eight-light budgets.
- Final measured scene budget: 375 nodes, 105 meshes, five skeletons, and six lights.
- Native 720p graphical verification passed at 39.2 FPS average, 38.3 FPS minimum, and 143 ms warm transition on Intel HD 620/ANGLE.
- The verified Web payload is 63.4 MB.
- Native 1280x720 captures are stored as `Development_Gallery/screenshots/WORLD_002_*.png`.

## Known Limits

The forest remains intentionally stylized and uses the current licensed asset set. WORLD-002 improves composition and route authorship without replacing monster or terrain art.

## Next Ticket

`WORLD-003` should apply the authored-zone standard to the cemetery and ruined Crow Chapel route.
