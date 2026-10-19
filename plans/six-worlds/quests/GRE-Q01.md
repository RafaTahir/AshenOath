# GRE-Q01 - The Baker's Last Sack

Parent: [WORLD-SAGA-101](../worlds/WORLD-SAGA-101.md). Runtime ID: `saga_gre_q01`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional, connected. XP: 300. Prerequisite: ordinary Greyfen access only.

## Hook And People

Nessa cuts a loaf into smaller portions beside the kitchen. She needs to learn
whether a sack was lost or a delivery measure changed; she does not want hungry
neighbors accused without evidence. Tor can identify a replaced scale pin.
Nessa: "I can bake less. I cannot tell a child a smaller loaf is the same size."

## Playable Objectives

1. `hear_shortfall`: ask Nessa about the mismatched delivery. Accept or leave it open.
2. `compare_measures`: compare her marked sack seam with the delivery scale beside
   the existing cart layby. Either order; rotating/reading both shows a changed pin.
3. `trace_diversion`: follow spilled grain to a dry household store. Read a current
   ration slip: an intermediary took a fee, then a household kept an extra share.
4. `settle_supply`: choose Nessa's public correction with addresses removed, or a
   private witnessed repayment and protected copy. No violent interrogation.
5. `weigh_next_batch`: physically set the corrected weight and mark a new receipt
   at the bakery table. This new weighing action, not the old flour delivery, ends it.

## Branches And Consequences

`public`: a corrected scale notice appears; neighbors debate the levy, no family named.
`private`: the household returns the surplus and Nessa keeps two witnessed receipts.
Both record a delivery abuse, not proof Edric ordered the travelers' deaths.
Anwen can acknowledge the account later; neither choice forces testimony or romance.
Nessa: "You left us enough truth to change the measure. That will do for today."

## State, Rewards And Recovery

Save the five objective IDs, `saga_gre_q01_outcome` (`public`, `private`), and
`saga_gre_q01_weight_set`. Held weight/receipts are quest records, not sellable loot.
Reward: 300 XP through `quest:saga_gre_q01` and two travel bread once; no money cost.
If Nessa is unavailable, her signed correction/drop-off tray supports the same final action.
Reload restores an inspected scale or held weight; no repeated receipt/XP grant.
Late-game ration liberation changes dialogue tense, not the availability of this
specific past delivery dispute. No new prerequisite for the existing Assembly.

## User Manual Checklist

Compare clues in both orders; take both resolutions; reload while holding the
weight; finish after the main ending; confirm one reward and preserved kitchen-cart progress.
