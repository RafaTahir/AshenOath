# QUEST-009 Result

## Changes
- Bell Beneath Greyfen keeps order-independent grave evidence, chapel gating, Crow Shrine choices, and Bell-Eater aftermath state.
- Shrine state now changes Greyfen/cemetery lighting on rebuild.
- The three shrine outcomes are now a checked contract: `cleansed`,
  `disturbed`, and `bound`, each with one-shot persistence and a distinct
  cemetery presentation branch.
- Dialogue choice buttons now restore gameplay focus, unpause the world, and
  hide the dialogue layer before applying the shrine consequence. This keeps
  the three shrine outcomes usable through the real player-facing button path.

## Verification
- Story ticket gate: PASS, including runtime, all campaign quest gates, save,
  narrative, side-quest, and cinematic checks.
- `verify_quest_009.gd`: PASS - unique three-way shrine state contract,
  runtime objective completion, consequence persistence, one-shot guard, and
  dialogue-action unpause/hide behavior.
- Boss and cemetery source contracts: PASS.
- Graphical `capture_world_014.gd`: PASS at 1280x720 Compatibility rendering
  with fresh nonblank cemetery/chapel frames.

## Remaining
Full real-input Bell-Eater validation and final visual acceptance remain part
of Milestone E/F. The current cemetery capture still exposes stylized
blockout-quality dressing and one tree-heavy framing; that remains visual
reconstruction work rather than being hidden by the functional pass.

## Screenshots
- `Development_Gallery/screenshots/WORLD-014_01_Cemetery_Approach_20260821_145648.png`
- `Development_Gallery/screenshots/WORLD-014_02_Grave_Court_Crows_20260821_145648.png`
- `Development_Gallery/screenshots/WORLD-014_03_Ruined_Crow_Chapel_20260821_145648.png`
- `Development_Gallery/screenshots/WORLD-014_04_Bell_and_Shrine_20260821_145648.png`
