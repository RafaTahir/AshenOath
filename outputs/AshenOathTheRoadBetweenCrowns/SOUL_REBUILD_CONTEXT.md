# Ashen Oath Soul-Rebuild Context

This is the compact handoff document for the 62-ticket soul-rebuild program. It is intentionally shorter than the historical phase archive.

## Product Truth

Ashen Oath is an original browser-first dark-fantasy RPG. The current source is a functional pre-alpha with a playable Greyfen/Wychwood route and broader campaign sections. It is not yet a finished AAA game. The soul-rebuild target is a coherent 90-minute opening followed by a compact 4-6 hour campaign.

## Creative Pillars

1. Buried testimony: every investigation reveals a person, not just a collectible.
2. Dangerous vows: Kael's choices change trust, access, encounters, and the shape of the ending.
3. Landscapes altered by memory: rivers, roads, shrines, graves, portals, and weather react to what Greyfen remembers.

The visual language is grounded stylized dark fantasy: wet stone, ash, timber, muted cloth, warm fire, cold moonlight, and restrained supernatural cyan. No protected characters, names, scenes, or copied designs are used.

## Non-Negotiable Runtime Rules

- Imported character bodies are authoritative. Runtime must not add root-mounted faces, hair, shoulders, cloaks, eye boxes, fake necks, or proxy limbs.
- All route-visible humans use one shared humanoid ecosystem. All released monsters use complete bodies and readable silhouettes.
- Bridges are the only river crossings. NPCs and enemies use the same river-aware spatial service as the player.
- Oath Gates are animated arches with preloading, destination silhouettes, ash/crow motion, audio, and safe rollback. Plain colored transition slabs are prohibited.
- Loading must never become a black screen. The Web shell shows Ashen Oath content immediately; long travel uses an interactive Crow Path vignette.
- Objectives, dialogue, compass, portals, world state, and save state use one authoritative quest presentation state.

## Performance Contract

- Balanced is native 1280x720 and must average at least 32 FPS with a 30 FPS 1% low on the Dell 7280.
- Potato reduces visual density but never removes gameplay-critical routes, actors, clues, or prompts.
- Web deployment stays below 100 MB. Raw downloads, Blender files, screenshots, and development tools are excluded.
- Cold engine startup target is 12 seconds or less, with a hard 15-second ceiling. New Game after engine readiness is 750 ms or less.

## Content Spine

The campaign is presented through six main chapters: Road of Crows; Bell Beneath Greyfen; Teeth, Names, and Ash; Blood Under Stone; The Last Witness; and The Hart Remembers. Legacy quest IDs remain loadable through aliases. The five large encounters are Bell-Eater, Rootbound Colossus, Ashwing Carrion Drake, Halvern Gravebound Knight, and the White Hart.

## Workflow

Read this file, `PROJECT_STATE.md`, and the active ticket only. Ordinary tickets use `tools/run_ticket_gate.ps1`, changed-view screenshots, a result document, and the cumulative `codex/soul-rebuild` checkpoint. Full Web export, `web/` synchronization, `main`, Vercel, and live smoke testing happen only at milestone boundaries.

## Current Foundation Checkpoint

The first soul-rebuild implementation slice removes generated anatomy overlays, adds the custom Web boot shell and Crow's Crossing loading activity, identifies gamepad families/hotplug state, replaces plain route markers with animated Oath Gate visuals, and registers a threaded zone-resource request service. The remaining character, world, combat, boss, story, and performance tickets must build on this contract rather than reintroducing procedural overlays.

This checkpoint is local/development state only. It has not been synchronized into `web/`, pushed to `main`, or deployed to Vercel.
