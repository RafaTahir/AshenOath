# STORY-FULL-001 - Complete Campaign Implementation

## Implemented
- Versioned `StoryState` with persistent flags and bounded trust, fear, and debt values.
- Ten main quests, ten side quests, order-independent evidence groups, and legacy-save migration.
- Conditional dialogue/action resolution and compact human-voiced dialogue for major confrontations.
- Bounded campaign route: deeper Wychwood, ash mill, burned farmstead, marsh, bandit road, three Vargan sections, undercroft, Greyfen assembly, and White Hart glade.
- Persistent report, shrine, names, Senn, Edric, Halvern, confession, side-story, and final-covenant outcomes.
- Witness, Mercy, Duty, and Ash endings with state-sensitive epilogue text.
- Lightweight scratch-voice library with subtitle fallback; no external payload added.

## Verification
- `tools/verify_runtime.gd`
- `tools/verify_story_campaign.gd`
- Existing audio, motion, visible-quality, Visual100, Web export, and packed-start checks.
- Campaign screenshots are included in the shared capture workflow as frames 31-41.

## Performance
All new locations reuse current assets and procedural materials. They are bounded, use shared systems, add no decorative per-frame scripts, and preserve Potato/Balanced behavior.

## Honest Limitations
The campaign is a complete stylized implementation, not an AAA-scale authored production. Scratch voices use the existing browser/procedural fallback and should eventually be replaced by actors. New locations intentionally reuse modular scenery and require later art-direction passes for greater visual uniqueness.
