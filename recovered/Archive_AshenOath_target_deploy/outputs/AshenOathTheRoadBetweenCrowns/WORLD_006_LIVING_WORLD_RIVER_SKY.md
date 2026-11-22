# WORLD-006 - Living World, River, and Sky

## Implemented
- Added a continuous authored river crossing in Greyfen and Wychwood with animated water, banks, reeds, stones, collision-safe plank bridges, currents, and water interaction.
- Added full player swimming states with camera-relative movement, surface/submerged movement, breath, sprint stamina, current drift, splash feedback, drowning recovery, and combat suppression in water.
- Repositioned route clues and Greyfen forge content onto dry reachable ground.
- Strengthened the living sky with a modeled warm sun, radial sun forms, clustered volumetric-style clouds, visible moon, and procedural stars across the persistent day/night cycle.
- Preserved Balanced, Potato, and Quality behavior without adding external payload.

## Verification
- `tools/verify_runtime.gd`
- `tools/verify_river_swimming.gd`
- Existing campaign, visual, motion, audio, and Web verifiers remain release gates.

## Performance
All new world art is procedural and low-poly. River water uses one lightweight shader per zone. Cloud and star counts remain quality-tier controlled.

## Running
Open the production URL, click **Enter**, choose **New Game**, then follow the road through Greyfen. The river crossing and bridge are directly on the village route and continue through Wychwood.
