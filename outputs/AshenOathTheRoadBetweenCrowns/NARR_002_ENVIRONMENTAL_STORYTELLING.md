# NARR-002 Environmental Storytelling

## Files Changed
- `scripts/game.gd`
- `tools/verify_runtime.gd`
- `tools/verify_visible_quality.gd`
- `tools/capture_slice_screenshots.gd`
- `NARR_002_ENVIRONMENTAL_STORYTELLING.md`

## Environmental Story Beats Added
- Black feathers and a snapped prayer charm near the notice board.
- Black feathers, extinguished candle, and broken token at the shrine.
- Disturbed grave soil and half-buried charm in the visible graveyard area.
- Wychwood gate threshold: broken sign, dark mud trail, feathers, and claw-marked post.
- Old road clue route: broken cart supplies, dragged tracks, claw marks, torn red cloth, and broken prayer token.
- Ghoulkin clearing: dragged marks, old blood-mud, snapped charm, and feathers.
- Post-victory clue: human boot tracks beside claw tracks, cut red thread, and feathers.

## Clue Objects / Text
- Existing clue prompts remain short and sharp from NARR-001.
- Clue locations now have visible supporting objects instead of relying only on HUD text.
- New visuals use black/dark grey feathers, red-brown mud/blood, old wood, muted cloth, bone/stone charms, and cold grave/shrine colors.

## Shrine / Graveyard Omen
- Added shrine feathers, extinguished candle, snapped token, disturbed grave soil, and half-buried charm.
- The area now visually supports Anwen's unease without supernatural effects.

## Wychwood Threshold
- Added threshold feathers, a dark mud trail, broken sign, and claw-marked post around the Wychwood gate.
- These are nonblocking visual props and keep the route open.

## Ghoulkin Clearing Payoff
- Added drag marks and blood-mud leading into the clearing, plus feathers/charm pieces near the fight.
- After Ghoulkin victory, a new visual clue appears: boot tracks beside claw tracks and cut red thread, implying the monster was led or called.

## Quest Flow Safety
- Existing Road of Crows clue-order safety remains unchanged.
- Ghoulkin victory still completes `fight_ghoulkin`.
- Return/report still completes through Sister Anwen.
- Post-victory clue is visual only and does not block completion.

## Screenshot Paths
- `Development_Gallery/screenshots/Capture_19_shrine_graveyard_omen_2026-06-22_032515.png`
- `Development_Gallery/screenshots/Capture_20_wychwood_gate_threshold_2026-06-22_032515.png`
- `Development_Gallery/screenshots/Capture_21_old_road_clue_story_2026-06-22_032515.png`
- `Development_Gallery/screenshots/Capture_22_ghoulkin_clearing_story_2026-06-22_032515.png`
- `Development_Gallery/screenshots/Capture_23_ghoulkin_aftermath_clue_2026-06-22_032515.png`

## Verifier Results
- `tools/verify_runtime.gd`: passed.
- `tools/verify_visible_quality.gd`: passed.
- `tools/capture_slice_screenshots.gd`: passed.
- Godot emitted the expected ANGLE fallback during visible screenshot capture on the Dell GPU path.

## Export Result
- `Export_Web_Build.bat`: passed.
- `verify_web_export.py`: passed as part of export.
- Web output remained `7 files / 43.2 MB`.

## Remaining Narrative Weaknesses
- The environmental objects are still stylized primitive compositions, not bespoke high-detail props.
- Post-victory clue is visual/HUD-driven rather than a dedicated inspectable aftermath interaction.
- More authored camera framing would help players notice the smallest clue objects during normal play.

## Run Steps
1. Open PowerShell.
2. Run: `cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web_Slim"`
3. Run: `& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1`
4. Open Chrome or Edge to: `http://127.0.0.1:8787/index.html?v=narr002`
5. Click inside the game window to start/capture input.
6. Use `WASD` to move, mouse to look, `Left Click` light attack, `Shift + Left Click` heavy attack, `Q` block/parry, `Space` dodge, `Esc` pause/release mouse.
