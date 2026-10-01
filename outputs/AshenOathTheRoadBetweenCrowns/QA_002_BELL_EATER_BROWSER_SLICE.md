# QA-002 Bell-Eater Browser Slice

## Status

Implemented, not browser-accepted. Formal Recovery-004 status remains 27/37 accepted, 9 pending, 1 visually rejected.

## Change

- Added an isolated `--through-bell-eater` route after the existing real-input opening and cemetery route.
- The driver walks from the shrine to the encounter, acquires target lock with T, casts Oathfire with C, attacks and guards using normal inputs, and uses carried potions when needed.
- The route checks Bell-Eater death, all four reward/aftermath flags, and clears a surviving summoned Ghoulkin through real combat input.
- Named-enemy selection prevents the boss driver from steering toward a different active enemy. The production artifact is no longer rejected just because an unrelated QA export has a newer timestamp.
- Added a separate `--through-teeth` scope with real dialogue selection at Mira, chapel-name and ritual-stone investigation, Deep Wood travel, Bog Wretch combat, and a named memory-core decision. Each progression beat asserts the resulting quest or story state.

## Direct Verification

- `node --check tools/verify_qa_002_browser.mjs`: pass.
- `node --test tools/verify_qa_002_production_mode.test.mjs`: 5/5 pass.
- No Web export or browser run was performed because native PERF-001 is still red. These slices have not demonstrated gameplay success or browser timing.

## Next Action

Port Names They Burned and subsequent native-proven chapter interactions through ordinary browser input, then run the production-byte browser route only after native performance and visual acceptance are green. Keep the legacy mutation-based full route blocked from certification.
