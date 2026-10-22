# CAST-001 - Character Ownership

Parent: [CAST-000](CAST-000.md).
Dependencies: None.
Implementation: Shared profiles and ownership implemented; user acceptance pending.
Compilation: see [STATUS](STATUS.md).
User acceptance: Pending.
Publication: see STATUS; independent of acceptance.

## Implementation And Ownership

Extend story_cast_profile, character_presence, CharacterAnimationDriver and StoryPerformance. Profiles cover the existing core and saga cast without changing their wardrobe recipes. Dialogue/death/combat own presentation before life activities. Facial features are advertised only when their actual controls exist.

## User Acceptance

1. Named people retain distinct occupation, concern, social links and permitted danger response.
2. Starting/ending dialogue, damage and work cannot leave a lower-priority pose in control.
3. An unrigged face reports head attention only, never working eyelids.

## Boundaries

Use the master ownership, compatibility and build-only contract. Keep existing
actor/quest/save IDs and contents. No agent runtime tests, browser QA, benchmarks
or automatic acceptance. Wider implementation is now authorized; visual and
behavioral acceptance remains the user's separate review.

