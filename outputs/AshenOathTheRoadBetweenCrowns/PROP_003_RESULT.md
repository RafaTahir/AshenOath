# PROP-003 Result — Functional World Objects

## Files changed

- `scripts/interactive_world_prop.gd`
- `scripts/world_prop_controller.gd`
- `scripts/game.gd`
- `scripts/zones/cemetery_section.gd`
- `tools/verify_prop_003.gd`
- `tools/capture_prop_003.gd`
- `tools/gate_profiles.json`
- `Development_Gallery/screenshots/PROP-003_*.png`

## Implemented

- Added `InteractiveWorldProp`, a reusable state component for existing interaction areas. It persists consequential object states through `StoryState` without owning quest progression.
- Added one low-cost `WorldPropController` per active zone. It updates registered flames, candles, lanterns, forge sparks, cloth/papers, wheels, shrine embers, and bells at a bounded 24 Hz tick.
- Tagged existing Greyfen and cemetery objects instead of replacing their collision ownership: notice board, shrine, forge, well, minigame tables, lanterns, route candles, torches, cart wheels, and cemetery bell.
- Added lightweight authored object dressing: notice papers, forge sparks, shrine ember, and state-aware object motion.
- Added prop audio hooks using existing procedural cues: village life, shrine candle/bell, and cloth wind. Master-volume routing remains owned by `AudioManager`.
- Reused existing river-safe placement and zone lifecycle. No new zone, quest, enemy, asset pack, or Web export was added.

## Verification and captures

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_prop_003.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --display-driver windows --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --script tools/capture_prop_003.gd
& .\tools\run_ticket_gate.ps1 -Profiles props_003 -ChangedFiles @('outputs/AshenOathTheRoadBetweenCrowns/scripts/game.gd','outputs/AshenOathTheRoadBetweenCrowns/scripts/interactive_world_prop.gd','outputs/AshenOathTheRoadBetweenCrowns/scripts/world_prop_controller.gd','outputs/AshenOathTheRoadBetweenCrowns/scripts/zones/cemetery_section.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/verify_prop_003.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/capture_prop_003.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/gate_profiles.json','outputs/AshenOathTheRoadBetweenCrowns/PROP_003_RESULT.md') -NoCache
```

Fresh visual evidence:

- `Development_Gallery/screenshots/PROP-003_01_Notice_Board_Life_20260813_104900.png`
- `Development_Gallery/screenshots/PROP-003_02_Shrine_Candles_20260813_104900.png`
- `Development_Gallery/screenshots/PROP-003_03_Forge_Working_20260813_104900.png`
- `Development_Gallery/screenshots/PROP-003_04_Cart_and_Market_20260813_104900.png`
- `Development_Gallery/screenshots/PROP-003_05_Cemetery_Bell_20260813_104900.png`

## Running steps

1. Open PowerShell in `outputs/AshenOathTheRoadBetweenCrowns`.
2. Run the Godot project with the Compatibility renderer.
3. Choose **New Game** and enter Greyfen.
4. Walk to the notice board, shrine, forge, cart/market, and cemetery bell. Their papers, embers, flames, wheels, and bell motion should remain lightweight and grounded.
5. Interact with a village place. Its state is stored in the current save/story state; reload preserves state-keyed consequences.

## Known limitations

- The underlying Greyfen architecture and character assets remain the existing low-poly baseline; this ticket adds functional object presentation rather than a full environment art replacement.
- Godot still reports known renderer RID/ObjectDB cleanup diagnostics when the multi-zone test process exits. No active gameplay renderer error occurred in the targeted run.
- The ordinary development workflow does not export or deploy this ticket. The checkpoint is pushed to `codex/soul-rebuild`.

## Next ticket

`AUDIO-006 — Opening Soundscape`.
