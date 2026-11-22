# Phase 1D: UI Guidance Polish

## Summary

Phase 1D improves HUD readability, first-route guidance, and first-combat UI feedback from New Game through the first Ghoulkin victory. This pass keeps the existing code-generated HUD and avoids a full UI rewrite.

The goal was practical readability: the player should know the current objective, what resource changed, which enemy is engaged, when block/parry matters, what happened after taking or dealing damage, and how checkpoint recovery works.

This is still a browser-first low-spec vertical slice. The UI is more useful and cleaner, but it is not a final AAA interface pass.

## Files Modified

| File | Change |
| --- | --- |
| `scripts/hud.gd` | Added compact value labels, equipment quick-read, enemy focus health, contextual guidance hint, combat status cue, low-health pulse, stamina exhaustion flash, and cleaner tracker formatting. |
| `scripts/game.gd` | Routed quest, combat, item, stamina, enemy, victory, and death events into the improved HUD. Added first-route and first-fight guidance. |
| `scripts/player_controller.gd` | Added `stamina_exhausted(action)` signal for failed dodge/heavy-attack attempts. |
| `data/quests.json` | Tightened Road of Crows objective copy with stronger verbs and shorter tracker text. |
| `tools/verify_runtime.gd` | Added assertions for Phase 1D HUD elements and first-combat enemy/hint display. |
| `tools/capture_slice_screenshots.gd` | Added UI review screenshots for post-Anwen objective, Wychwood guidance, combat HUD, block cue, death read, and victory objective. |
| `PHASE_1D_UI_GUIDANCE_POLISH.md` | New handoff file for this pass. |

## HUD Improvements

- Health and stamina bars now show numeric values.
- Health is labeled as `Blood`; stamina is labeled as `Breath` for a restrained dark-fantasy tone.
- Low health applies a subtle pulse to the health bar.
- Health loss flashes the bar and shows a short `Blood lost` / hit cue.
- Stamina spending flashes the stamina bar.
- Failed dodge/heavy attack attempts show `Stamina spent` and a short recovery hint.
- A compact equipment line shows Redroot, Ash Bomb, and active oil status.
- Top-left and quest-tracker areas now have light dark backplates for readability over fog and bright lanterns.

## Quest Guidance Improvements

- New Game now starts with a direct `Speak to Sister Anwen` objective and contextual hint.
- After Sister Anwen, a short hint tells the player to follow the road north and inspect the route clues.
- Wychwood gate guidance points the player along the lit road without adding a minimap.
- Road of Crows objective text is shorter and more verb-led:
  - Speak to Sister Anwen.
  - Inspect the corpse.
  - Inspect claw marks.
  - Inspect black feathers.
  - Survive the Ghoulkin clearing.
  - Return to Greyfen with proof.

## Combat Readability Improvements

- Enemy health appears when the player targets, hits, or is threatened by an enemy.
- Enemy focus now shows a concise `Target: Ghoulkin` label and numeric health.
- Enemy focus hides after a short delay or when the enemy dies.
- Combat hit events now use short status cues instead of repeated long toast spam.
- First Wychwood combat gives a compact survival hint instead of a long tutorial message.
- Victory after the first Ghoulkin encounter shows `Ghoulkin slain` and a return/inspect hint.

## Block / Parry Hint Behavior

- On the first Ghoulkin windup, the HUD shows:

```text
Q at the lunge to parry. Hold Q to block.
```

- The hint is temporary and fades.
- The hint stops after the player successfully blocks or parries.
- Parry shows a distinct `Parry` status cue.
- Block shows a distinct `Blocked` status cue.
- The system does not add a tutorial wall or persistent overlay.

## Damage And Status Cue Behavior

Short status cues now cover:

- Player damage: `Hit: -N`
- Enemy damage: `Enemy hit`
- Block: `Blocked`
- Parry: `Parry`
- Stamina exhausted: `Stamina spent`
- Redroot potion: `Redroot used`
- Ash Bomb: `Ash Bomb thrown`
- Oil application: `Oil applied`
- Iron Trap: `Iron Trap set`
- Victory: `Ghoulkin slain`

The cue sits low-center and fades quickly to avoid covering the fight.

## Death / Checkpoint Messaging

- Death screen copy now explains checkpoint recovery directly.
- The player is told that `Load Last Checkpoint` returns Kael to the last safe contract marker with quest progress preserved.
- This avoids making checkpoint recovery feel like a broken state or unexplained reload.

## Web / Potato Mode Performance Precautions

- No new textures, fonts, imported UI assets, audio files, or external dependencies were added.
- New UI nodes are basic Godot `Label`, `ColorRect`, and `ProgressBar` controls.
- Animated UI is limited to short tweens for toast/hint/status fades and bar flashes.
- The only continuous HUD work is a tiny low-health pulse calculation in `hud.gd`.
- No minimap, journal redesign, complex UI effects, or expensive per-frame layout logic was added.
- Runtime 3D scene cost is unchanged by this UI pass.

## Verification Commands Run

Runtime verifier:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_runtime.gd
```

Screenshot capture:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --path . --script res://tools/capture_slice_screenshots.gd
```

Web export:

```bat
Export_Web_Build.bat
```

Direct web export verification:

```powershell
& 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools\verify_web_export.py '..\AshenOath_Web'
```

## Test Results

| Check | Result | Notes |
| --- | --- | --- |
| Runtime verifier | Passed | Output: `runtime vertical slice verification complete`. |
| Screenshot capture | Passed | Saved updated review screenshots to `verification_screenshots`. |
| Web export | Passed | Export completed through `Export_Web_Build.bat`. |
| Web export verifier | Passed | `web export verified: 7 files, 261.0 MB`. |
| Manual screenshot spot-check | Passed with caveats | HUD is readable; enemy focus was moved down after an overlap was found. |

Known local graphics note: screenshot capture still reports the expected Intel HD Graphics 620 ANGLE fallback warning.

## Screenshot Outputs

Current Phase 1D review screenshots:

- `verification_screenshots/01_greyfen_spawn.png`
- `verification_screenshots/04_sister_anwen_dialogue.png`
- `verification_screenshots/05_post_anwen_objective.png`
- `verification_screenshots/06_wychwood_gate_guidance.png`
- `verification_screenshots/10_ghoulkin_windup_hud.png`
- `verification_screenshots/11_player_block_cue.png`
- `verification_screenshots/12_ghoulkin_death_read.png`
- `verification_screenshots/13_ghoulkin_victory_objective.png`

Older screenshot names from prior phases may still remain in the folder.

## Known Issues

- The HUD is clearer, but it is still a code-generated vertical-slice HUD, not a final AAA UI skin.
- Enemy focus handles the first fight well, but multi-enemy targeting is still simple and nearest/last-engaged rather than a full target-lock system.
- The first-fight hints are intentionally lightweight; they do not teach every timing nuance.
- Some quest flow oddities from the older route logic remain, especially around clue order if the player skips intended steps.
- The web export is still large at about 261 MB.
- Human and monster visuals remain the larger quality gap; this pass only improves UI/readability.

## Recommended Phase 1E

Implement Phase 1E: first-route quest and encounter flow cleanup. Keep the same Greyfen to Wychwood slice, but make the Road of Crows progression more robust: prevent clue-order confusion, make the tracks clue appear/update after the Ghoulkin victory, improve return-to-Greyfen reporting, add verifier checks for objective order, and keep all changes Web/Potato Mode safe. Do not add new zones or broaden the story.
