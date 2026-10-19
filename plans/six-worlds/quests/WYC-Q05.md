# WYC-Q05 - Where the Water Runs

Parent: [WORLD-SAGA-102](../worlds/WORLD-SAGA-102.md). Runtime ID: `saga_wyc_q05`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional connected aftermath. XP: 500. Existing Bog fight resolved only.

## Hook And People

Iven and Edda can approach the bank after the Bog Wretch falls, but the collection
channel still drains through its fouled hollow. They need useful clean water,
not a claim that defeating a body cleansed every harm.
Edda: "It stopped moving. The water did not change its mind."

## Playable Objectives

1. `survey_watercourse`: inspect an upstream inlet, blocked screen and downstream
   pot stand from authored walkable banks. Do not enter forbidden river space.
2. `choose_flow`: select a contained side channel for workers or restore the
   broader natural run and move their pots to its existing safe collection point.
3. `clear_and_set`: lift debris into the work basket, fit the reused screen and
   open the selected small gate. These are new channel actions, not a boss/core choice.
4. `place_clean_pots`: move two collection pots to the agreed stand and compare
   a visibly clearer sample. State the limit: clear water is not a medical guarantee.

## Branches And Consequences

`side_channel`: maintained modest works, workers keep debris from the screen.
`natural_run`: less infrastructure, slightly farther collection walk and returning
animal signs. Both uncover WYC-S03's inscription and respect all Bog core dispositions.
Iven: "It needs checking tomorrow. That is how we know it is work, not a miracle."

## State, Rewards And Recovery

Save each inspected point, selected flow, screen/gate/pots and
`saga_wyc_q05_outcome` (`side_channel`, `natural_run`). Reward: 500 XP once.
Wayfarer's Bow Grip and boss XP use the separate existing encounter entitlement.
After leaving/returning, inspect the occupied stand for `return:saga_wyc_settled`.
Old defeated-Bog saves start directly at survey, preserving any pending core
decision. Missing workers leave an agreed work plan; no optional prior quest required.
Reload restores a safe gate state and remaining pot work, never a duplicate Bog.

## User Manual Checklist

Finish on fresh and legacy defeats, use both flows and all original core choices,
interrupt each channel step, revisit twice and confirm bridge-only crossing remains.
