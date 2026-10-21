# CAST-010 - Packaging and Delivery

Parent: [CAST-000](CAST-000.md).
Dependencies: Applicable sample or final implementation and explicit sample review boundary.
Implementation: Reference package complete; compilation/publication/user acceptance recorded separately.
Compilation: see [STATUS](STATUS.md).
User acceptance: Pending.
Publication: see STATUS; independent of acceptance.

## Implementation And Ownership

Compile prepared actors and shared animation/material bindings, preserving required fallback resources. Keep all project/output on D:. Aggregate deployment, including release_manifest.json, must be strictly below 104857600 bytes. Use only lossless deduplication/packaging. Publish using the existing workflow at the applicable review boundary; never claim implementation or compilation is user acceptance.

## User Acceptance

1. Use the consolidated reference checklist in STATUS.md.
2. At final rollout compare all six worlds, startup/Continue, controls and actual phone responsiveness.
3. Report exact package bytes, commit/deployment, unverified coverage and any blocked next action.

## Boundaries

Use the master ownership, compatibility and build-only contract. Keep existing
actor/quest/save IDs and contents. No agent runtime tests, browser QA, benchmarks
or automatic acceptance. The user reviews the Greyfen reference standard before
wider character/boss/regional authoring.

