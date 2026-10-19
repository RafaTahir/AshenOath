# GRE-Q03 - A Door Before Winter

Parent: [WORLD-SAGA-101](../worlds/WORLD-SAGA-101.md). Runtime ID: `saga_gre_q03`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional, independent household story. XP: 250. No other new quest required.

## Hook And People

Elna's door closes but the frame has settled; rain reaches her bedding. She wants
to decide what changes in her home. Nessa offers a spare beam; Tor offers advice.
This is not Tor's retained hinge-holding friendship activity or Harl's grave quest.
Elna: "Ask me where I want the new latch. Everyone has an opinion about my door."

## Playable Objectives

1. `survey_frame`: inspect the wet sill and misaligned frame with Elna's permission.
2. `choose_repair`: choose a salvaged sound beam from the public storm pile, or
   a reversible brace that preserves the marked old frame. Both are free materials.
3. `fit_support`: carry the chosen quest-work piece, seat it at the cleared entrance
   and peg it using Tor's loaned tool. No precision crafting minigame or timer.
4. `check_clearance`: open and close the actual door, then ask Elna to approve the latch.

## Branches And Consequences

`renewed`: a replaced sill and old carved strip saved inside. `braced`: the intact
frame gains a neat removable support. Both keep the door/collision usable.
Elna may invite Kael to read an unfinished letter (GRE-S03); refusing is respected.
Her later line concerns a dry house and her plans, not another forced Harl confession.
Elna: "Tonight I can put the basin back in the kitchen. That is quite a gift."

## State, Rewards And Recovery

Save survey, held-part ID, fitted state and `saga_gre_q03_outcome` (`renewed`, `braced`).
Reward: 250 XP and one bitterleaf tonic; no prerequisite on Elna's testimony choice.
Never consume ordinary timber or require Tor's marked iron. If Elna is unavailable,
her explicit repair plan remains at the door; completion records delivered work,
and personal conversation/letter waits for consent on a later visit.
Death/reload restores held/fitted work once and does not trap actors in a closed door.

## User Manual Checklist

Choose both repairs, interrupt carrying/fitting, operate the door from both sides,
decline the letter and finish after Elna's existing quest without altering its result.
