# VISUAL-003 Native 720p Realism Overhaul

## Implemented

- Balanced and Quality render at native 1280x720; Potato remains the explicit 0.65 fallback.
- Added seven documented ambientCG CC0 surface sets for forest soil, wet mud, paving, plaster, timber, roof tile, and masonry.
- Added cached PBR material lookup, crossed-card grass MultiMesh, textured roads/terrain, and materially differentiated buildings.
- Expanded Greyfen houses with foundations, eaves, chimneys, shutters, timber braces, steps, windows, and varied frontage dressing.
- Added a persistent 36-minute day/night cycle starting at 16:30, with saved time/day, phase lighting, night windows/lanterns, and menu/dialogue pause behavior.
- Removed synthetic Visual100 markers, skeletal-character proxy anatomy, detached face/clothing overlays, and permanently visible world labels.
- Oathfire now captures Kael's facing direction when C is first pressed and uses that direction through sheathing, charge, release, collision, and cancellation.
- Wychwood uses both animated CC0 skeleton and cursed-orc rigs with variant scale, material, behavior, and animation maps.

## VISUAL-003B Performance Recovery

- Batches trees, crowns, and deadfalls through MultiMesh while preserving route collision.
- Limits Balanced to six short-range shadowless local lights; Quality retains richer lighting, normal maps, AO, triplanar surfaces, MSAA, and directional shadow.
- Removes transparent fog-sheet overdraw from Balanced while retaining environment fog and day/night atmosphere.
- Caches Greyfen and Wychwood roots, disables parked-zone collision/processing, and defers transition autosaves.
- Throttles distant ambient NPC and inactive enemy updates without changing nearby combat or dialogue behavior.

## Measured Result

- Native 720p Balanced: 30.0 FPS average, 30.0 FPS sampled minimum on Intel HD 620 through ANGLE.
- Wychwood rendering: 178 draw calls and approximately 77,104 primitives.
- Warm Greyfen/Wychwood transition: 229 ms.
- Cold first Wychwood construction: approximately 1.1 seconds and treated as initial loading work.

## Verification

- Runtime, story, Greyfen, Castle, audio, visible-quality, motion, Visual100-replacement, and VISUAL-003 checks pass.
- Ten VISUAL-003 screenshots were captured at exactly 1280x720 in `verification_screenshots/visual_003/` and mirrored to `Development_Gallery/screenshots/`.
- Web export and packed-startup verification pass: 7 runtime files, 66.9 MB total, including a 30.7 MB PCK and 36.0 MB WASM. Commit, push, and live-hash results are recorded during production finalization.

## Remaining Limits

- Humans are cleaned, textured, animated licensed skeletal characters, but remain stylized rather than MakeHuman-grade realistic assets.
- Buildings remain runtime-authored modular shells rather than bespoke high-poly architectural GLBs.
- Cold first entry still requires a short load; subsequent route travel is cached.
- Quality mode is intentionally more expensive and is not the Dell 7280 default.

## Running

1. Open `https://ashenoath.vercel.app/?v=visual003b` in Chrome or Edge.
2. Press Enter or click the launch screen.
3. Choose New Game.
4. Use WASD to move, mouse to look, E to interact, left/right mouse for attacks, Space to dodge, Q to parry/block, and hold C then release for Oathfire.
