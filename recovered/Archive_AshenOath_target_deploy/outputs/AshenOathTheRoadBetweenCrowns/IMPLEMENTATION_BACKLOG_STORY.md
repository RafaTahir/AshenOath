# Story Implementation Backlog

Planning tickets do not deploy. Implementation tickets follow the repository production workflow unless explicitly marked `DO NOT DEPLOY`.

## NARR-003 — First-Hour Narrative Rewrite

- **Objective:** Replace current first-route text with the approved spoken script and named victims.
- **Files likely touched:** Dialogue/quest data and first-route orchestration.
- **Data:** Bram, Sella, Oren clue copy; report variants.
- **Assets:** Token and wire can begin as authored procedural props.
- **Systems:** Existing dialogue, objectives, HUD, audio.
- **Success:** First hour's core dialogue reads naturally and progression remains intact.
- **Proof:** Dialogue capture, route verifier, table-read checklist.
- **Deploy:** Yes. **Complexity:** Medium.

## QUEST-001 — Road Of Crows Evidence Threshold

- **Objective:** Make five clues order-independent with three-clue progression and optional completion.
- **Data:** Clue IDs, victim evidence, fallback tracks.
- **Systems:** Quest objectives and world flags.
- **Success:** Every clue permutation reaches combat and report.
- **Proof:** Automated permutation verifier.
- **Deploy:** Yes. **Complexity:** Medium.

## DIALOGUE-001 — Conditional Dialogue Contract

- **Objective:** Add ordered variants, simple conditions, and one-shot flag actions.
- **Data:** Conditions, variants, fallback text, performance notes.
- **Systems:** Dialogue manager, story state.
- **Success:** Correct line resolves for private/public/retained reports; base dialogue remains compatible.
- **Proof:** Condition matrix verifier.
- **Deploy:** Yes. **Complexity:** Medium.

## CHOICE-001 — Story State V1

- **Objective:** Add explicit flags and three bounded values.
- **Data:** Neutral defaults and accepted enum values.
- **Systems:** Save/load and dialogue actions.
- **Success:** Choices persist, apply once, and old saves load neutrally.
- **Proof:** Save round-trip and migration verifier.
- **Deploy:** Yes. **Complexity:** Medium.

## WORLD-001 — Cemetery And Chapel Shell

- **Objective:** Author bounded cemetery route, ruined chapel landmark, and staging points.
- **Assets:** Existing graves/stone plus small door/bell props.
- **Systems:** Current cemetery zone helper and collision.
- **Success:** Readable route, no void, no progression content yet.
- **Proof:** Screenshots and collision verifier.
- **Deploy:** Yes. **Complexity:** Medium.

## NPC-001 — Anwen Relocation And Reactions

- **Objective:** Move Anwen from shrine to cemetery after report and update nearby NPC states.
- **Systems:** Fixed staging points selected from flags.
- **Success:** One Anwen instance, correct interaction, safe save/load.
- **Proof:** Runtime checks for both stages.
- **Deploy:** Yes. **Complexity:** Low-medium.

## ENEMY-002 — Evidence-Modified Clearing

- **Objective:** Make clues delay Brute and trap preparation alter Stalker entry.
- **Systems:** Existing spawn positions, sensing, trap, five-kill progression.
- **Success:** Changes are visible but global balance remains unchanged.
- **Proof:** Encounter-state verifier and screenshots.
- **Deploy:** Yes. **Complexity:** Medium.

## WORLD-002 — Bell And Grave Investigation

- **Objective:** Add bell states, three order-independent graves, chapel threshold, and cemetery ambush.
- **Systems:** Interactables, audio, world flags, existing enemies.
- **Success:** Any two graves reveal the threshold; no deadlock.
- **Proof:** Permutation tests and before/after screenshots.
- **Deploy:** Yes. **Complexity:** Medium.

## AUDIO-003 — First-Hour Voice Pilot

- **Objective:** Add approved voice for Anwen's opening/report and Kael's key observations.
- **Assets:** Short reviewed mono clips only.
- **Systems:** Audio manager, subtitle fallback, browser gesture gate.
- **Success:** Missing/disabled audio never blocks dialogue; payload increase within approved budget.
- **Proof:** Audio verifier, browser smoke test, human performance review.
- **Deploy:** Yes. **Complexity:** Medium.

## CINEMATIC-001 — Narrative Staging Without Cutscenes

- **Objective:** Improve facing, pauses, bell response, and landmark framing while retaining control.
- **Systems:** Existing camera, NPC ambient, audio cues.
- **Success:** Key moments read without locking movement or camera.
- **Proof:** Captures for Anwen, victory token, bell, chapel ending.
- **Deploy:** Yes. **Complexity:** Low-medium.

## SAVE-002 — Story Compatibility

- **Objective:** Version story state and migrate completed first-route saves.
- **Systems:** Save manager, quest state, neutral report prompt.
- **Success:** New, old, autosave, and checkpoint files load without invented choices.
- **Proof:** Fixture-based save tests.
- **Deploy:** Yes. **Complexity:** Medium.

## QA-001 — First-Hour Progression Matrix

- **Objective:** Verify clue permutations, three reports, death/reload, Potato/Balanced, and browser input.
- **Systems:** Existing verifiers plus story-state checks.
- **Success:** No deadlock, duplicate NPC, lost evidence, or mismatched report state.
- **Proof:** Automated matrix and selected screenshots.
- **Deploy:** Yes, after all blockers pass. **Complexity:** Medium.

## Later Ticket Order

1. `QUEST-002` Teeth in the Rain.
2. `QUEST-003` Names They Burned.
3. `WORLD-003` Old Mill.
4. `ENEMY-003` Soldier Without Banner.
5. `WORLD-004` Castle Record Hall.
6. `ENEMY-004` Last Witness.
7. `NARR-006` Greyfen Assembly.
8. `FINALE-001` Hart Glade and endings.

Only one implementation ticket should be active at a time. Future prompts read the context brief, the relevant design document, and the active ticket only.
