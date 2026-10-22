# CAST-005 - Awareness and Reactions

Parent: [CAST-000](CAST-000.md).
Dependencies: CAST-001, CAST-004.
Implementation: Local sight/sound reactions and regional safe-route responses implemented; runtime/user acceptance pending.
Compilation: see [STATUS](STATUS.md).
User acceptance: Pending.
Publication: see STATUS; independent of acceptance.

## Implementation And Ownership

Use bounded local sight queries and the game's registered active-enemy list.
Spatial audio emits location/radius cues only for selected audible events.
Nearby civilians investigate/brace or seek a clear point on their existing
safe route; guard-role actors watch rather than acquire civilian fear behavior.
Protected interactions take precedence and quest speakers stay usable.
Cooldowns prevent repeated notices. No crime system or civilian death changes.

## User Acceptance

1. Approach armed/unarmed, walk behind a worker, and start/finish representative danger.
2. Confirm cover movement stays on legal surfaces and required speakers remain usable.
3. Confirm people settle and resume their route after danger without a visible teleport.

## Boundaries

Use the master ownership, compatibility and build-only contract. Keep existing
actor/quest/save IDs and contents. No agent runtime tests, browser QA, benchmarks
or automatic acceptance. Wider implementation is now authorized; visual and
behavioral acceptance remains the user's separate review.

