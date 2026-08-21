# SIDE-003 Result

## Changes
- Kept the five selected consequential side quests startable from the authored Greyfen board dialogue.
- Added quest-aware dialogue action conditions for the Widow's Bell, Iron Remembers,
  Bitter Roots, Black Dog Contract, and Man Who Walked Home contacts.
- Progress handoffs are visible only while the matching quest is active and its
  required objective is still open.
- Consequential choices are hidden until their prerequisite clue/objective is
  complete and disappear after the choice is resolved.
- Added a runtime guard in `game.gd` so stale dialogue nodes cannot mutate quest
  or story state after a save reload, duplicate activation, or out-of-order visit.
- Extended `DialogueManager` with `quest_active`, `quest_available`,
  `quest_completed`, `objectives_done`, and `objectives_not_done` conditions.
- Preserved the returned-soldier flow, where the grave clue completes the
  investigation handoff before the witness choice becomes available.

## Verification
- `verify_side_003.gd`: PASS.
- Targeted `story` ticket gate: PASS.
- Covered content integrity, runtime smoke, campaign quest gates, save
  migration, narrative, side-quest, and cinematic checks: PASS.
- Fresh changed-view captures: `WORLD_001_*_20260821_151120.png` and
  `WORLD_002_*_20260821_151155.png`.

## Known Limits
- Full end-to-end side-quest aftermath and save/reload permutation coverage
  remains part of `QA-012`.
- The opening and later-world captures remain stylized development evidence;
  this ticket does not claim final character or environment visual approval.

## Running Steps
1. Start New Game and reach the Greyfen notice board.
2. Accept one side contract and visit its named contact.
3. Confirm the contact exposes only the active investigation handoff.
4. Complete the required clue/objective, return to the contact, and choose the
   consequential resolution.
5. Reload before and after the choice to verify the stale-action guard and the
   saved quest state.
