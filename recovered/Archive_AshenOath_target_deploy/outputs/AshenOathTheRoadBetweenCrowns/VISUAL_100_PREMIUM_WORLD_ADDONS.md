# VISUAL-100 Premium World Add-Ons

## Result
Implemented the complete 100-item visible-upgrade contract across Greyfen and Wychwood. Every item has a numbered runtime feature node, visible geometry/effect in Balanced and Quality modes, and a lightweight Potato fallback.

## Systems Added
- `WorldVisualUpgrade`: data-driven placement and presentation of all 100 additions.
- `WorldMotionController`: shared wind, flame, sign, wheel, crow, and ambient motion.
- `SurfaceFeedbackManager`: bounded player footprints without permanent node growth.
- `verify_visual_100.gd`: fails unless all numbered features exist across the playable slice.

## Visual Groups
1. Terrain and roads: 10 improvements.
2. Vegetation and forest: 10 improvements.
3. Sky, weather, and atmosphere: 10 improvements.
4. Greyfen architecture: 10 improvements.
5. Living village props: 10 improvements.
6. Shrine and cemetery: 10 improvements.
7. Character staging: 10 improvements.
8. Enemy and combat staging: 10 improvements.
9. Camera landmarks and framing cues: 10 improvements.
10. Lighting, feedback, and opening composition: 10 improvements.

The exact ordered feature names are the `FEATURE_NAMES` contract in `scripts/world_visual_upgrade.gd`.

## Performance Rules
- Balanced is the default.
- Potato omits secondary geometry but retains a feature marker and all gameplay-relevant objects.
- Motion is controlled centrally rather than by one script per prop.
- Footprints are capped at 20 instances.
- No new texture or model payload was required.

## Running Steps
1. Open `https://ashenoath.vercel.app/?v=visual100` in Chrome or Edge.
2. Click the game and press Enter.
3. Choose **New Game**.
4. Walk through Greyfen, visit the shrine, enter Wychwood, and reach the Ghoulkin clearing.
5. Use Settings to compare Potato, Balanced, and Quality presets.
