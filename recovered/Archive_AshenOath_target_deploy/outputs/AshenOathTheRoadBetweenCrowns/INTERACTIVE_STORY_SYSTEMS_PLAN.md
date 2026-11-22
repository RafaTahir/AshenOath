# Interactive Story Systems Plan

## 1. Conditional Dialogue Variants

- **Purpose:** Let characters remember evidence, choices, and omissions.
- **Approach:** Extend dialogue entries with ordered variants and simple predicates; retain base greeting/lines fallback.
- **Likely files:** `dialogue_manager.gd`, `game.gd`, dialogue data.
- **Save:** Reads existing quest state plus `story_state`.
- **Risk:** Variant ambiguity. Resolve by priority and verifier coverage.
- **Timing:** Required for Act I.

## 2. Story State Component

- **Purpose:** Track explicit choices and three bounded values.
- **Approach:** Small manager with `set_flag`, `get_flag`, `adjust_value`, `matches`, `save_state`, `load_state`.
- **Likely files:** New `story_state.gd`, save/game integration.
- **Save:** Versioned block with defaults.
- **Risk:** Old-save assumptions. Never infer ambiguous choices.
- **Timing:** Required for Act I.

## 3. Evidence Threshold Objectives

- **Purpose:** Prevent clue-order deadlocks while rewarding thorough investigation.
- **Approach:** Each clue sets an objective/flag; quest checks `found >= required`. Optional clues remain journal entries.
- **Likely files:** Quest manager and first-route hooks.
- **Save:** Existing objective state.
- **Risk:** Duplicate triggers. Make clue completion idempotent.
- **Timing:** Required immediately.

## 4. NPC Relocation

- **Purpose:** Make story progression visible and support report scenes.
- **Approach:** Fixed staging points selected at zone build from quest/choice state. Never duplicate one NPC in two locations.
- **Likely files:** Zone builder/game NPC creation.
- **Save:** Derived from flags/objectives.
- **Risk:** Old saves loading inside an occupied staging point.
- **Timing:** Required for cemetery expansion.

## 5. Consequence Dressing

- **Purpose:** Show outcomes without cutscenes.
- **Approach:** Named prop groups with mutually exclusive states: shrine, board, graves, forge, mill, road residue.
- **Likely files:** Zone helpers and world-state loading.
- **Save:** Consequential state flags only.
- **Risk:** Missing state after zone rebuild. Add verifier per state.
- **Timing:** Required for Act I.

## 6. Clue-Modified Encounters

- **Purpose:** Make investigation affect play.
- **Approach:** Pre-encounter flags adjust wave delay, sense range, spawn side, or one existing weakness. No global combat rebalance.
- **Likely files:** Encounter spawn logic and enemy metadata.
- **Save:** Clue/objective state.
- **Risk:** Encounter bypass or unfair spawn. Preserve five-kill completion and safe positions.
- **Timing:** Required for revised Road of Crows.

## 7. Return/Report Conversations

- **Purpose:** Deliver emotional payoff and explicit consequence selection.
- **Approach:** Aftermath objective names a report target; dialogue offers evidence-backed choices and applies state once.
- **Likely files:** Dialogue actions, HUD objective text, game interaction routing.
- **Save:** Report flag plus quest objective.
- **Risk:** Reporting twice. Choice actions become unavailable after state set.
- **Timing:** Required immediately.

## 8. Oath Mark Presentation

- **Purpose:** Make Kael's internal arc visible without a morality bar.
- **Approach:** Subtle hand/weapon emissive state during major oath choices; color/shape follows final orientation only at authored moments.
- **Likely files:** Player presentation and story hooks.
- **Save:** Final or major oath flags.
- **Risk:** Reading as a power meter. Keep absent from HUD.
- **Timing:** Act II onward.

## 9. Bell Omen Controller

- **Purpose:** Signal cemetery state and broken promises.
- **Approach:** Timed audio plus bell animation keyed to proximity and quest state; post-combat rhythm changes.
- **Likely files:** Cemetery section and audio manager.
- **Save:** Derived from quest phase.
- **Risk:** Repetitive audio. Cooldown and one-shot states.
- **Timing:** Required for Act I.

## 10. Voice Playback Contract

- **Purpose:** Deliver important dialogue with human-reviewed cadence while retaining Web fallback.
- **Approach:** Dialogue line optionally references a compressed clip and performance metadata. Missing clip immediately uses subtitle timing; never blocks input.
- **Likely files:** Dialogue/HUD/audio integration.
- **Save:** None.
- **Risk:** Payload and autoplay. Main-path lines only; begin after user gesture.
- **Timing:** First-hour polish after writing lock.

## Voice Production Workflow

1. Table read the first-hour script.
2. Remove lines that sound written rather than spoken.
3. Record or generate scratch takes with direction.
4. Human-review emphasis, breath, names, and emotional continuity.
5. Replace approved scratch takes with final performance where available.
6. Compress mono speech and test Web payload.
7. Keep subtitles authoritative and all choices usable without audio.
