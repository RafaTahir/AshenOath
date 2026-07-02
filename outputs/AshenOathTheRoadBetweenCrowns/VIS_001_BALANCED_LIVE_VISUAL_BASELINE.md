# VIS-001 Balanced Live Visual Baseline

## Implemented

- Balanced is now the live default at 0.65 render scale and a 30 FPS target.
- Potato, Balanced, and Quality presets have explicit foliage, shadow, density, and resolution settings.
- The settings menu cycles named visual presets and rebuilds the active zone immediately.
- Greyfen gains a batched paved-road stone surface; Wychwood gains a batched wet-mud detail pass.
- Existing quality dressing, grass, fog, imported scenery, and light pools now appear in the Balanced default.
- A lightweight rolling FPS sampler reports average/minimum FPS every ten seconds.
- Runtime verification requires the Balanced defaults, performance sampler, and both road-detail batches.

## Performance Contract

- Potato: 0.55 scale, no foliage or shadows, 30 FPS target.
- Balanced: 0.65 scale, moderate foliage and visual density, no dynamic shadows, 30 FPS target.
- Quality: 0.85 scale, richer density and shadows, 30 FPS target.

## Deferred

Interactive props, moving village objects, cemetery bell behavior, character schedules, and new gameplay remain in later roadmap tickets.
