# DEP-Q04 - The Orchard's Debt

Parent: [WORLD-SAGA-103](../worlds/WORLD-SAGA-103.md). Runtime ID: `saga_dep_q04`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional ecological/personal story. XP: 300. Clear orchard shoulder accessible.

## Hook And People

Ressa has one viable graft from an orchard maintained before the burning. Dain
wants the surviving trunk for repair timber; neither has enough material to
pretend the decision costs nothing. Work takes place outside Rootbound's arena.
Dain: "It is sound wood. That is why this is not an easy answer."

## Playable Objectives

1. `inspect_stock`: inspect the healthy graft, hollow trunk and public fallen timber.
2. `hear_uses`: hear Ressa's planting plan and Dain's repair need, or their signed notes.
3. `choose_orchard`: preserve the living trunk and source fallen repair wood, or
   salvage the unsafe hollow section while protecting the graft in a nursery frame.
4. `protect_graft`: carry the supplied frame, set its stakes and wrap the graft
   at the chosen clear plot. No tree damage simulator or timed growth required.
5. `record_material`: label the timber and nursery so future workers know what to keep.

## Branches And Consequences

`standing`: intact living stock, smaller salvage pile. `nursery`: sound salvaged
timber and an explicitly supported graft. A later milestone adds new leaves,
not a fruit reward farm. Neither replaces redirecting Rootbound's marked roots
or lifting the existing name-board. Original guardian aftermath remains legible.
Ressa: "Keep the label. Someone else will be doing this work after us."

## State, Rewards And Recovery

Save inspected facts, agreed plan, frame/stakes and `saga_dep_q04_outcome`
(`standing`, `nursery`). Reward: 300 XP and one iron trap once.
No requirement to defeat or provoke Rootbound; block only active nearby danger,
then resume. Ressa's supplied frame is not consumed by unrelated crafting.
Reload preserves placement and leaves the existing root-channel/board flags unchanged.

## User Manual Checklist

Complete before/after Rootbound, compare both plans, interrupt frame placement
and confirm distinct guardian and orchard consequences survive reload and return.
