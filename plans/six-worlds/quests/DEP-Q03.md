# DEP-Q03 - The House That Kept Its Heat

Parent: [WORLD-SAGA-103](../worlds/WORLD-SAGA-103.md). Runtime ID: `saga_dep_q03`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional independent exploration. XP: 250. Burned Farmstead accessible.

## Hook And People

Warm dry air escapes a cellar grate beneath a burned home. Ressa fears somebody
is using the ruin, then recognizes a sun-warmed brick flue and a protected store.
The surprise is useful survival of a place, not another resurrected household.
Ressa: "That crock has outlasted three roofs. I would like it to see a fourth."

## Playable Objectives

1. `inspect_air`: compare the sun-facing flue, clean animal tracks and cellar grate.
2. `clear_entry`: lift two loose boards from an authored low cellar entry;
   reuse interior/camera rules, no crouch/climbing feature or blocked diagonal road.
3. `identify_store`: inspect dry shelving and Ressa's marked bread crock. Explain
   retained warmth as ordinary brick/daylight; do not claim a six-year fire still burns.
4. `choose_crock`: take the crock to Ressa's new work table or preserve it in the
   dry cellar with a labeled access record for her household.
5. `secure_air`: open the safe vent and fasten the loose grate so the store remains usable.

## Branches And Consequences

`returned`: the crock becomes a modest visible possession at Ressa's work area.
`stored`: it remains on the accessible dry shelf with her permission recorded.
Both restore useful space. The optional false-backed cupboard DEP-S01 remains
a separate discovery; merely entering the cellar does not grant its loot/XP.

## State, Rewards And Recovery

Save cleared boards, crock custody, vent/grate and `saga_dep_q03_outcome`
(`returned`, `stored`). Reward: 250 XP and a household-history lore entry.
No edible centuries-old stock, forced theft or inventory weight. The written
household marking provides provenance if Ressa is absent; do not invent consent
to publish private letters. Return/drop-off is reversible until final placement.
Reload never recreates boards across the exit or puts Kael under the closed grate.

## User Manual Checklist

Enter/exit with the gameplay camera, interrupt carrying the crock, take both
placements, find DEP-S01 separately and return with old farmstead clues retained.
