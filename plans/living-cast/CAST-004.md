# CAST-004 - Purposeful Daily Life

Parent: [CAST-000](CAST-000.md).
Dependencies: CAST-001, CAST-003.
Implementation: Six-world clock/outcome routines, local reservations and hand-bound props implemented; runtime/user acceptance pending.
Compilation: see [STATUS](STATUS.md).
User acceptance: Pending.
Publication: see STATUS; independent of acceptance.

2026-10-24 Greyfen work/contact, supported sitting and walking-to-table extension:
[implementation and pending user checks](../living-road/GREYFEN_VILLAGE_IMPLEMENTATION.md).
No broader facial-rig rollout or new population is claimed.

## Implementation And Ownership

The existing life controller enrolls retained people in each region using
data/cast_life.json. Work/errand/rest/social assignments follow the existing
clock and completed quests; changes wait for planted feet rather than teleport.
Work stations retain reservation/interruption cleanup. Hammer, book, rope,
supplies and care/growing props attach to actual hands; carrying is additive to
normal locomotion. Mill workers transfer from the escort owner only after the
recorded rescue and Ashwing defeat, with no duplicate population.

## User Acceptance

1. Watch an entire work/travel/interruption/resumption cycle at the forge and another station.
2. Confirm two workers do not use the same work point simultaneously.
3. Check regional work/travel/rest/social changes using the existing clock, including the rescued mill workers' return.

## Boundaries

Use the master ownership, compatibility and build-only contract. Keep existing
actor/quest/save IDs and contents. No agent runtime tests, browser QA, benchmarks
or automatic acceptance. Wider implementation is now authorized; visual and
behavioral acceptance remains the user's separate review.

