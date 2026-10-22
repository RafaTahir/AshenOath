# CAST-002 - Human Faces

Parent: [CAST-000](CAST-000.md).
Dependencies: CAST-001.
Implementation: Facial controls extended to all eight retained human assemblies and the composed Ranger; user visual acceptance pending.
Compilation: see [STATUS](STATUS.md).
User acceptance: Pending.
Publication: see STATUS; independent of acceptance.

## Implementation And Ownership

Compile eleven weighted eyelid, eye, brow, mouth and jaw controls into Kael,
Anwen, male/female/worker/hooded villagers and deserter/tracker assemblies.
Compile equivalent controls into the Ranger's existing composed head layers
before prepared-scene serialization. Retain bodies, atlas pixels, skin topology,
hair, neck, clothing and locomotion bones. Missing weighted controls or required
texture bindings stop asset compilation rather than silently substitute a body.

## User Acceptance

1. Inspect Anwen, Tor and an ordinary villager in daylight, shadow and conversation.
2. Confirm eyelids close over eyes, expressions read naturally and the neck remains connected in motion.
3. Compare Kael, female/hooded villagers, hostile humans and Ranger Senn with their retained identities; name any concrete face/anatomy defect.

## Boundaries

Use the master ownership, compatibility and build-only contract. Keep existing
actor/quest/save IDs and contents. No agent runtime tests, browser QA, benchmarks
or automatic acceptance. Wider implementation is now authorized; visual and
behavioral acceptance remains the user's separate review.

