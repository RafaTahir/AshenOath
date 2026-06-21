# Production Pass

## Completed In This Pass

- Added timed enemy attack windups, parry timing, stagger response, target-facing player attacks, and stronger boss-branch combat.
- Added autosave, checkpoint save, checkpoint death recovery, versioned save payloads, and persistent removed interactables for clues and herbs.
- Added all requested side quests from the original brief: A Widow's Bell, The Black Dog Contract, and Bitter Roots.
- Added quest reward payout so completed quests grant JSON-defined coin and items.
- Added a compass-style zone/nearest-marker readout.
- Added generated item icons and JSON icon metadata for inventory/crafting art replacement.
- Preserved the low-spec runtime budget: small hubs, low-poly meshes, generated lightweight audio, limited enemies, no heavy simulation.

## Best Current Play Path

1. Start Road of Crows at the Greyfen notice board.
2. Speak to Sister Anwen.
3. Visit Wychwood, inspect clues, kill Ghoulkin.
4. Return through Mira, craft and use oils/items, then continue the main chain.
5. Try the three side quests before resolving the White Hart.
6. Choose kill or bind for the boss-fight ending path, or free/expose for the moral-resolution path.

## Remaining External Work

- Install Godot 4.6.3 export templates.
- Run `Export_Web_Build.bat`.
- Playtest the exported web build on the Dell Latitude 7280 in Chrome or Edge at 720p and Potato Mode.
- Optional future asset replacement: swap temporary stylized human bases for higher-fidelity licensed GLB characters with real faces, hair, clothing, and animation sets.
