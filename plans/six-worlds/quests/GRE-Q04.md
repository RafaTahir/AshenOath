# GRE-Q04 - A Small Dishonesty

Parent: [WORLD-SAGA-101](../worlds/WORLD-SAGA-101.md). Runtime ID: `saga_gre_q04`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional, independent social story. XP: 300. Common-table access required only.

## Hook And People

Nessa says Rook changed a wager after a game; Rook says she remembered the joke
but not the terms. Neither is secretly a criminal mastermind. The cost is a
borrowed kettle and a friendship, not access to food or main-story evidence.
Rook: "I said a round. Apparently she heard a lifetime of washing up."

## Playable Objectives

1. `hear_accounts`: hear both versions at the common table, in either order.
2. `inspect_tally`: compare the scratched score slip and the chalked wager terms;
   a reused mark explains the dispute without requiring a hidden random roll.
3. `offer_settlement`: propose replaying one ordinary Three Marks round with written
   terms, or cancel the disputed wager and return the kettle together.
4. `return_kettle`: carry it from the table to Nessa's kitchen shelf and confirm
   their agreement. A game victory alone cannot complete this action.

## Branches And Consequences

`replayed`: either game's outcome is honored, including Kael/Rook losing; quest
success depends on an agreed settlement, not on the player winning.
`voided`: neither keeps the disputed advantage; both retain their embarrassment.
The table remains playable and gathering dialogue recalls the incident once.
Nessa: "There. One kettle. No treaty required."

## State, Rewards And Recovery

Save both accounts, tally inspection, agreed route, any earned game result and
`saga_gre_q04_outcome` (`replayed`, `voided`). Never manufacture a win on reload.
Reward: 300 XP and one travel bread once; ordinary game wagers/rewards retain
their existing owner and are not multiplied by this quest.
If Rook is unavailable, a signed settlement invitation permits the no-game route
at the kitchen. Interrupted games follow their existing cancel/restart behavior;
the undisputed kettle return can still finish the quest.

## User Manual Checklist

Win, lose, decline a replay, reload during the round and choose the no-game route;
confirm no lost main dialogue, duplicate payment or blocked future minigame.
