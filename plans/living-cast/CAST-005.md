# CAST-005 - Awareness and Reactions

Parent: [CAST-000](CAST-000.md).
Dependencies: CAST-001, CAST-004.
Implementation: Greyfen reactive sample implemented; regional rollout pending sample review.
Compilation: see [STATUS](STATUS.md).
User acceptance: Pending.
Publication: see STATUS; independent of acceptance.

## Implementation And Ownership

Use bounded local sight queries and the game's registered active-enemy list. React to nearby drawn weapons, attacks and casting; nearby moving villagers can seek a farther clear point on their existing safe route. Essential named speakers remain reachable and can warn/brace. Cooldowns prevent repeated notices. No crime system or changes to civilian death rules.

## User Acceptance

1. Approach armed/unarmed, walk behind a worker, and start/finish representative danger.
2. Confirm cover movement stays on legal surfaces and required speakers remain usable.
3. Confirm people settle and resume their route after danger without a visible teleport.

## Boundaries

Use the master ownership, compatibility and build-only contract. Keep existing
actor/quest/save IDs and contents. No agent runtime tests, browser QA, benchmarks
or automatic acceptance. The user reviews the Greyfen reference standard before
wider character/boss/regional authoring.

