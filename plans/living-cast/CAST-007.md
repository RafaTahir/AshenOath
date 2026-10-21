# CAST-007 - Monsters Beyond Combat

Parent: [CAST-000](CAST-000.md).
Dependencies: CAST-001.
Implementation: Ghoulkin-family reference behavior implemented; other families pending review.
Compilation: see [STATUS](STATUS.md).
User acceptance: Pending.
Publication: see STATUS; independent of acceptance.

## Implementation And Ownership

Use existing enemy perception, navigation, leash, encounter activation and attack ownership. Ghoulkin stalkers, raiders and brutes patrol, watch/scavenge, search the last perceived location and return home between fights. Combat starts through the existing perception contract with unchanged health/damage/cooldowns. No duplicate populations or off-camera kills.

## User Acceptance

1. Observe before detection, break sight, and watch searching/return behavior.
2. Compare stalker pace/positioning with a brute and ordinary Ghoulkin.
3. Confirm attacks, encounter checkpoints, rewards and bridge-only routing retain their existing behavior.

## Boundaries

Use the master ownership, compatibility and build-only contract. Keep existing
actor/quest/save IDs and contents. No agent runtime tests, browser QA, benchmarks
or automatic acceptance. The user reviews the Greyfen reference standard before
wider character/boss/regional authoring.

