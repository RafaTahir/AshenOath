# WORLD-REPAIR-001 — Greyfen and Wychwood Route Repair

## Status

Implemented on the development branch `codex/repair-milestone-1`. This ticket is a focused route-presentation and traversal-safety pass; it does not add quests, zones, enemies, or new external assets.

## Files Changed

- `scripts/game.gd`
- `scripts/zones/river_section.gd`
- `WORLD_REPAIR_001_GREYFEN_WYCHWOOD.md`

## What Changed

- Replaced the solid player-facing gate marker with an open two-pillar arch and readable lintel.
- Reduced zone and building world-label size so prompts do not dominate the camera.
- Increased paved-road coverage and tightened stagger spacing to reduce visible gaps.
- Replaced cone-like tree crowns with low-cost rounded sphere crowns and narrowed tree collision width.
- Added restrained shoreline foam strips to separate the water surface from the banks.
- Flattened and lengthened bridge approaches so the player reaches the deck without a jump or collision step.
- Kept the existing river exclusion, bank barriers, bridge-only crossings, recovery anchors, navigation, and interaction ownership unchanged.

## Verification

Passed:

- `verify_world_001.gd` — Greyfen composition, route clearance, node/mesh/light budgets.
- `verify_world_002.gd` — Wychwood gate, clues, bridge, combat route, and budgets.
- `verify_river_swimming.gd` — river exclusion and recovery safety.
- `verify_navigation_001.gd` — bridge routing and actor recovery.
- `verify_visible_quality.gd`
- `verify_visual_003.gd`
- Graphical captures `capture_world_001.gd` and `capture_world_002.gd` at 1280x720.

Fresh proof is in `Development_Gallery/screenshots/` with the `20260810_215929` and `20260810_215955` timestamps.

## Known Issues

- The visual language remains stylized and below the Witcher 3 benchmark; this pass improves composition and route readability rather than replacing the asset library.
- The Compatibility renderer still reports imported null-material and teardown/RID warnings during test shutdown. They are not hidden and remain assigned to `ENGINE-REPAIR-001`.

## Running Steps

1. Open PowerShell in the project folder.
2. Run the local Web build server if using the exported build:
   `& "$env:USERPROFILE\\.cache\\codex-runtime\\dependencies\\python\\python.exe" -m http.server 8787 --bind 127.0.0.1`
3. Open `http://127.0.0.1:8787/` from `outputs/AshenOath_Web` or the synchronized `web` folder.
4. Start a new game, cross Greyfen’s bridge, use the Wychwood gate, and return through the open `Back to Greyfen` arch.

## Next Ticket

`WORLD-REPAIR-002` — Castle, finale, and river presentation, followed by `SKY-REPAIR-001` acceptance and the Milestone 2 combat/character/world verification bundle.
