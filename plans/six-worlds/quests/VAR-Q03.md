# VAR-Q03 - The Prisoner's Garden

Parent: [WORLD-SAGA-105](../worlds/WORLD-SAGA-105.md). Runtime ID: `saga_var_q03`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional independent personal story. XP: 250. Odran's courtyard petition available.

## Hook And People

Odran grew useful herbs in a service alcove while detained. His release order
leaves his tools impounded; accepting a new labor pledge would recover them.
He wants to decide whether gardening here is work he freely chooses.
Odran: "I like the plants. That is not the same as choosing the walls."

## Playable Objectives

1. `read_release`: compare his existing release petition and impounded-tool tag.
2. `recover_tools`: claim the marked tools from the service locker through the
   dated order, not theft combat or the secret seed collection.
3. `choose_garden`: help Odran move his supplied working tray to a traveling box,
   or record an explicitly voluntary, paid return to the courtyard garden.
4. `settle_bed`: carry tray/tools, set a water pot and leave the alcove clear for
   its chosen use. No plant-growth timer or garden-management system.
5. `acknowledge_choice`: read/receive Odran's departure or paid-work acknowledgement.

## Branches And Consequences

`departed`: packed traveling plants and an empty released work position.
`voluntary_work`: Odran retains the right to leave; a work sheet records actual pay.
Neither hides medical access behind agreement or changes his story to a dead echo.
If the campaign already removed Edric's authority, this resolves remaining
property/work arrangements, not an invented re-arrest.

## State, Rewards And Recovery

Save order checked, tools released, moved tray and `saga_var_q03_outcome`
(`departed`, `voluntary_work`). Reward: 250 XP and two redroot ingredients once.
Signature belongs to Odran only after his chosen answer; a neutral drop-off handles
returned tools if he is absent, and the journal waits rather than inventing his decision.
No entry to another prison map required. VAR-S03 remains separately discoverable
under his standing inspection invitation in every outcome.

## User Manual Checklist

Choose departure/work, interrupt tray carrying, finish after Edric's removal,
revisit the separate seed secret and confirm no forced pledge or duplicate actor.
