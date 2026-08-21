# QUEST-009 Result

## Changes
- Bell Beneath Greyfen keeps order-independent grave evidence, chapel gating, Crow Shrine choices, and Bell-Eater aftermath state.
- Shrine state now changes Greyfen/cemetery lighting on rebuild.
- The three shrine outcomes are now a checked contract: `cleansed`,
  `disturbed`, and `bound`, each with one-shot persistence and a distinct
  cemetery presentation branch.

## Verification
- `verify_campaign_quests_008_012.gd`: PASS.
- `verify_quest_009.gd`: PASS - unique three-way shrine state contract,
  runtime objective completion, consequence persistence, and one-shot guard.
- Boss and cemetery source contracts: PASS.

## Remaining
Graphical cemetery before/after captures and full real-input boss validation remain pending.
