# Witcher-inspired HUD release

Date: 4 October 2026. This is a new, bounded request after the preceding story-overhaul delivery: study The Witcher 3 HUD, adapt its appearance to Ashen Oath, then push and deploy.

## Reference and design

Primary reference: [CD Projekt Red's official PC manual, interface illustration and legend](https://cdn-l-thewitcher.cdprojektred.com/media/TW3/Pdf/Manuals/PC/The_Witcher_3_Wild_Hunt_Game_Manual_PC_GB.pdf), PDF pages 5–7. The reference places the medallion and vitality/stamina in the upper left, circular minimap in the upper right, tracked quest beneath it, consumables in the lower left and contextual control hints in the lower right. Narrow translucent strips, angular resource bars and uppercase headings leave the world visible. The illustrated page was downloaded, rendered and visually examined; it is a grayscale composite of different HUD states, not a color sample or a requirement to show every depicted element simultaneously.

Ashen Oath adopts that composition with an original Hart emblem, slimmer shaped resource bars, a circular local navigation display, a gold quest heading and ivory objective, compact quick-item slots, lower-right input hints and a centered interaction prompt. Dialogue receives a matching restrained charcoal/ivory/gold treatment while retaining its existing reading and choice controls.

The navigation cluster also displays the existing in-game clock and dawn/day/dusk/night phase. It listens to the day/night service's current values rather than introducing a separate time or weather model.

The new navigation display uses actual active-zone spatial records, player position/facing and currently eligible objective or passage positions. It is a schematic local map, not a fabricated terrain texture or an invented pathfinding route. It does not add hidden enemies, clues or unrevealed character markers. Existing quest tracking remains authoritative.

The preceding display-aware layout, safe-area handling, compact reading surfaces, touch-control reservations, high contrast, reduced motion, current bindings, resource values and story-state behavior remain integration constraints. No additional dialogue, balance, ending or save-schema changes are part of this task.

## Implementation split

- HUD presentation: `scripts/hud.gd`, shared visual styling and original vector emblem helpers.
- Local navigation: `scripts/hud_navigation_dial.gd` and `scripts/quest_hud_coordinator.gd`, with any small dedicated data helper needed for the live schematic.
- Runtime integration: a separate 0.10-second navigation display update during live gameplay and a clear/reset at gameplay handoff. Existing story-text guidance retains its 0.50-second cadence. The existing time-change signal updates the clock, with an initial value at service setup.
- Release: commit source, generate a fresh production candidate, push the existing authorized branches and deploy to the existing Vercel production project. Resolve actual compiler or publication diagnostics as needed.

## Release status

Complete, pushed and deployed. Source `01de770d60655cf5aec1f6c89a082c418c8a6a1f` produced build `story-20261004T024339Z-01de770d6065`, candidate `.release-gate/witcher-hud-01`. Godot import, all seven runtime packs and Web export completed. Package `051c5f9` was pushed to both `main` and `codex/story-centered-overhaul`. The same production command deployed 87.9 MB to Vercel: deployment `dpl_4EJEgBLKwAnWspq2oBVMBA6Xv7Tt` returned `status: ok`, `readyState: READY` and alias [ashenoath.vercel.app](https://ashenoath.vercel.app). Its unique address is [the HUD production release](https://ashenoath-gpfhjcawf-rafaeitahir-5792s-projects.vercel.app).

Final release documentation is pushed after the game package. The user's standing instruction excluded tests, previews, screenshots of the game, QA, listening or post-deployment verification. Viewing the external reference was research for the requested redesign. No gameplay, visual-quality or device-compatibility verification is claimed. This bounded request is complete; no further changes are scheduled.

## Implemented changes

- Upper-left original silver Hart medallion with tapered crimson vitality and gold stamina ribbons; live resource numbers and critical-state cues remain connected.
- Upper-right circular silver/brass navigator, north-up local spatial geometry, real player-facing arrow and one eligible current objective or next passage bearing. The snapshot contains no retained scene-node pointers; static geometry is cached separately from live movement and heading.
- Existing world clock and phase beside the navigator; gold story heading, ivory next action and current route information below it.
- Lower-left original potion, bomb and arrow symbols with actual inventory counts and current input bindings; existing oil information remains available.
- Lower-right binding hints, a smaller central interaction prompt and a restrained enemy vitality ribbon.
- Removed the gameplay-wide shade and normal opaque information cards. Text uses local shading and outlines; high contrast restores stronger local backdrops.
- Harmonized conversation panels with charcoal, ivory and metallic gold/silver details without changing choice or reading navigation.
- Retained responsive sizing, compact layouts, touch-control space, focus/scroll restoration, reduced-motion behavior and current input handoffs. Secondary ornament yields space to reading and controls in compact layouts.

New helpers are `hud_visual_style.gd`, `hud_emblem.gd` and `hud_navigation_dial.gd`. The existing HUD, quest HUD coordinator, game runtime and service registry provide their live data and lifecycle integration.
