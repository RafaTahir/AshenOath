# CAST-007 - Monsters Beyond Combat

Parent: [CAST-000](CAST-000.md).
Dependencies: CAST-001.
Implementation: Existing family habits extended with bounded audible-cue investigation; runtime/user acceptance pending.
Compilation: see [STATUS](STATUS.md).
User acceptance: Pending.
Publication: see STATUS; independent of acceptance.

## Implementation And Ownership

Use existing enemy perception, navigation, leash, encounter activation and attack
ownership. Ghoulkin variants, gravebound and hostile road humans retain their
existing family habits. A heard local cue can select an investigation point,
but cannot manufacture player knowledge or start an attack without perception.
Patrol sweeps ignore the querying body's own collider. Health, damage, attack
cooldowns, population and encounter gates remain unchanged.

## User Acceptance

1. Observe before detection, break sight, and watch searching/return behavior.
2. Compare stalker pace/positioning with a brute and ordinary Ghoulkin.
3. Confirm attacks, encounter checkpoints, rewards and bridge-only routing retain their existing behavior.

## Boundaries

Use the master ownership, compatibility and build-only contract. Keep existing
actor/quest/save IDs and contents. No agent runtime tests, browser QA, benchmarks
or automatic acceptance. Wider implementation is now authorized; visual and
behavioral acceptance remains the user's separate review.

