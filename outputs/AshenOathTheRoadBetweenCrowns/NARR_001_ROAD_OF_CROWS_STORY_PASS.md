# NARR-001 Road Of Crows Story Pass

## Files Changed
- `data/quests.json`
- `data/dialogue.json`
- `scripts/game.gd`
- `tools/verify_runtime.gd`
- `NARR_001_ROAD_OF_CROWS_STORY_PASS.md`

## First Route Story Question
What killed the men on the old road, and why does Sister Anwen already know more than she admits?

## Sister Anwen Dialogue Changes
- Rewrote her first conversation to be solemn, guarded, and spiritually burdened.
- She now gives the contract through specific signs: cart, clawed mud, black feathers.
- She explicitly withholds why she knows those signs, creating the first route mystery.

## Greyfen Micro-Story Changes
- Updated notice board copy to mention missing men, an empty cart, black feathers, and Anwen holding the names.
- Added small fear-lines to existing NPCs only: Mira, Rook, Blacksmith Tor, and Farmer Toma.
- Greyfen now suggests recent deaths, sleepless Anwen, bells at night, and villagers afraid to speak near the shrine.

## Clue / Aftermath Changes
- Road of Crows objective text now uses clearer dark-fantasy wording.
- Existing Wychwood clue prompts were renamed for stronger tone.
- Corpse, claw marks, feathers, and tracks now produce short mystery beats through existing HUD/toast logic.
- Ghoulkin victory now says the creature died too far from its den, implying it was drawn to the road.

## Return / Report Hook
- Reporting to Sister Anwen now lands with a stronger emotional beat: she recognizes the feathers and says the creature was called there.
- This resolves the immediate monster question while opening the next question about human involvement.

## Quest Robustness Notes
- Existing clue-order safety remains intact.
- Tracks still complete skipped corpse/claw/feather objectives without completing report early.
- Ghoulkin victory still completes `fight_ghoulkin`.
- Sister Anwen report still completes `return_village` and the quest.

## Verification Result
- `tools/verify_runtime.gd`: passed.
- Added small verifier checks for narrative objective text, Anwen withholding-truth line, Greyfen rumor text, and clue prompts.
- Godot emitted the existing ObjectDB cleanup warning after verifier exit.

## Export Result
- `Export_Web_Build.bat`: passed.
- `verify_web_export.py`: passed as part of export.
- Web output remained `7 files / 43.2 MB`.
- Export cleanup noted the output folder was in use, but the build still exported and verified.

## Remaining Narrative Weaknesses
- Dialogue remains static; Sister Anwen does not yet switch to a full bespoke post-report dialogue tree.
- Clue story is still delivered through HUD/toast beats, not inspected object panels or voiced scenes.
- Greyfen ambient story is improved but still shallow compared with a full RPG village.

## Run Steps
1. Open PowerShell.
2. Run: `cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web_Slim"`
3. Run: `& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1`
4. Open Chrome or Edge to: `http://127.0.0.1:8787/index.html?v=narr001`
5. Click inside the game window to start/capture input.
6. Use `WASD` to move, mouse to look, `Left Click` light attack, `Shift + Left Click` heavy attack, `Q` block/parry, `Space` dodge, `Esc` pause/release mouse.
