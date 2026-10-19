# ROA-Q04 - Lights Across the Marsh

Parent: [WORLD-SAGA-104](../worlds/WORLD-SAGA-104.md). Runtime ID: `saga_roa_q04`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional exploration/safety story. XP: 300. Fallen post visible from the route.

## Hook And People

A fallen signal makes a safe bend look like deep water and points travelers
toward an abandoned shoulder. Nera wants ordinary people to read the crossing
without knowing a secret password or relying on a keeper being awake.
Nera: "A light can be seen a long way off. So can a mistake."

## Playable Objectives

1. `read_post`: inspect the fallen post's shape code and maintenance inscription.
2. `survey_line`: inspect three marker bases from the existing walkable route;
   use triangular cuts/height alignment in daylight and reflected lanterns at night.
3. `set_markers`: upright the bases and fit supplied hoods so their faces point
   toward safe boards, not toward the forbidden water. No color-only puzzle.
4. `walk_check`: traverse the short marked corridor in either direction and
   inspect the end board. This is real walkable travel, not a teleport completion.

## Branches And Consequences

Choose `fixed_posts` for unattended passive markers or `hooded_lamps` for a
keeper-maintained light line; both retain carved daytime direction and use
existing lighting budgets. The alternative affects routine/dressing, not safe access.
The line can hint at ROA-S01 without automatically awarding the causeway secret.
Kael: "If we can follow it without you, you can have a night off."

## State, Rewards And Recovery

Save surveyed/set marker IDs, chosen mode and `saga_roa_q04_outcome`
(`fixed_posts`, `hooded_lamps`). Reward: 300 XP and six Standard arrows once.
Supplied fittings are quest work, not consumable player oil. Interrupted route
checks resume from unvisited end inspection; reload cannot claim walking not done.
Keep the current marsh join, collision and bridge-only river crossing unchanged.

## User Manual Checklist

Complete by day and night, choose both modes, walk both directions, interrupt
one marker placement and confirm no sound/color-only clue or new unsafe water route.
