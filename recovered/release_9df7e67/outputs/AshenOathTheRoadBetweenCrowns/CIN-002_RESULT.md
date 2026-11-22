# CIN-002 Result

## Changes
- Campaign dialogue entries now include explicit presentation contracts for
  Captain Senn, Halvern, Edric, the White Hart, and the Crow Shrine.
- Dialogue pages now carry stable `speaker_id`, beat, optional direction, and
  pause metadata. Existing `Speaker: line` text remains backward compatible.
- `DialogueManager` normalizes framing, speaker focus, subtitle rate, reaction
  pause, and subtitle fallback metadata on every resolved entry.
- HUD emits `dialogue_page_changed` for every rendered turn.
- The game refreshes the face-to-face camera framing and actor orientation on
  each page while dialogue is paused, preventing multi-speaker turns from
  drifting or losing the intended focus.
- Resolved dialogue entries always expose `fallback_text` and
  `subtitle_fallback` so missing audio cannot block interaction.
- Quest beat text replaces stale contextual tracker wording.

## Verification
- `verify_cin_002.gd`: PASS.
- Campaign quest contract: PASS.
- Targeted story profile: PASS, including content, runtime, quest, save,
  side-quest, and cinematic gates.
- Targeted UI profile: PASS, including runtime-regression, UI, and HUD gates.
- Fresh graphical 1280x720 dialogue captures, visually inspected:
  `CIN_002_01_AnwenGreeting_20260821_152545.png`,
  `CIN_002_02_DialogueTurn_20260821_152546.png`,
  `CIN_002_03_DialogueTurn_20260821_152546.png`, and
  `CIN_002_04_DialogueTurn_20260821_152547.png`.

## Known Limits
- Human-recorded performance audio remains deferred to the audio release gate;
  subtitles remain authoritative when browser audio is unavailable.
- The surrounding character and environment art remains the documented
  stylized development fallback and is not final visual approval.

## Running Steps
1. Start New Game and approach Sister Anwen in Greyfen.
2. Press `E` to open the conversation.
3. Advance through the pages and confirm the speaker label and framing remain
   stable across the Anwen and Kael turns.
4. Close the dialogue with the mouse, keyboard, or controller and confirm the
   gameplay pointer and movement return.
