# LR-008 - Bracken's Rescue

Status: implemented; production package/publication pending. User acceptance pending.

## Implemented

- Bracken is a living, dark-coated hound on the western verge of Greyfen's north
  road. Ordinary interaction lets Kael calm him, release a caught travelling strap,
  and offer a home or leave him safe. Refusal retains a later adoption opportunity.
- The independent `side_bracken_rescue` event has three objectives and no payment,
  main-quest prerequisite or consumable requirement. The existing Black Dog
  Contract, memory-fragment identity and every outcome remain unchanged.
- The retained Quaternius Animated Animals Vol.2 Dog source is packaged into a
  compressed runtime scene with its complete skeleton, native idle/walk clips,
  charcoal coat and normalized 0.78 m bounds. Root horizontal animation movement
  is removed so future controller physics owns movement. Raw FBX is not a new
  production dependency; the bundled scene carries the derived body/animations.
- Source license/provenance and the build ledger identify the derivative. The
  retained flat Dog FBX and licensed archive's Dog FBX have identical SHA-256:
  `a7250b3c68857120e6da0fd9ea2cdb4a4493823b6afed371b7aa9208407af039`.
- Stable identity, calm/release and home/refusal state use existing saved story
  flags and quest serialization. No save reset or replacement schema. World
  decoration refreshes the actor after choices and cached-zone reuse; inherited
  process modes stop the actor with its zone and during pause.
- Bracken has no enemy health, hostile group or damage receiver. Ordinary combat
  cannot permanently kill him. The loose strap disappears after release; the
  discarded harness remains a ground prop, not fake skeletal anatomy.
- Animal dialogue uses authoritative text with no generated speech. Camera framing
  reads the short actor's focus height without changing human/default camera behavior.

## Files And Static Review

`scripts/companion_controller.gd`, `story_world_director.gd`, `game.gd`,
`camera_controller.gd`, `quest_manager.gd`, `story_route_catalog.gd`;
`data/dialogue.json`, `data/quests.json`; `assets/companions/`;
`tools/build_bracken_asset.gd`, `tools/build_story_release.ps1`;
export/asset/acceptance/license manifests; project/ticket records and generated Web.

SaveManager and dialogue resolution were inspected; their existing additive state
and variant/action paths cover this event. No new save migration was necessary.
Static review includes choice availability, distance/combat guards, source license,
old-save quest unlocks, repeat adoption, rendering ownership and pack dependency.

No game, tests, browser QA, visual review or screenshots were run. Static review
caught the dialogue-close lifecycle clearing proximity/facing before action
dispatch. Choice payloads now bind the actual staged actor and revalidate zone,
identity and distance instead of relying on the cleared pointer. The first
packaging operation was cancelled before publication to include that correction.
Minimum production asset generation and packaging succeeded. Build:
`lr-008-20261008-bracken-rescue`, source `3228754` plus the dirty implementation.
Full Web directory: **92,010,896 bytes**, below 104,857,600.
Stored root PCK: `b877ccb25b814a956a9b8a28c9e93b1f71fb12fcb94c653b2d05fc0ec4c25ecf`.
Decoded root PCK: `5044c362ab510371e5740a5247329138c9ad99bd927b670832cd4eda0f5fbaed`.
Bracken runtime scene: `c5314c83bcc1b7152e50f6d918acb1a31dc8c0f3b4a975d4cfc9942c7c039689`.
Output: `.release-gate/LR-008-20261008-build-final`. Publication receipt pending.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: visible anatomy/materials, grounding, animation,
approach/dialogue focus, rescue choices and Save/Continue. Bracken remains in
Greyfen in this ticket; following, travel and commands are LR-009, not claimed here.
The source provides Idle and Walking, not authored sit, death or jumping clips.

## Manual Test Checklist

1. Find the black hound beside Greyfen's north road. Calm him and release the strap.
2. Leave him safe, return and adopt him. Inspect body, grounding and idle animation.
3. Save/Continue before and after adoption; confirm the rescue state persists and
   the existing Black Dog Contract remains independent.
