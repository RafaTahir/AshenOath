# Character, consequence, combat and journey refinement

The user requests all four remaining priorities implemented autonomously, with no tests or verification, followed by push and deployment. The playable opening is already published. This document records implementation decisions before the next edits.

## 2. Character performances

- Bake the local CC0 directional run clips onto the current Universal humanoid rig using global rest-pose rotation differences, fixed target limb lengths and in-place root motion. Add backward/left/right clips to the existing shared library, preserve attribution, and retain current gait fallbacks for other rigs. This is production asset generation, not a playback review.
- Add restrained, ground-aware two-bone foot adjustment for Kael, with bounded vertical reach and no body/hitbox translation; keep authored airborne motion.
- Direct conversations by actual speaker and authored emotional beats. Give Kael listening reactions, replace repeating generic hand gestures with bounded page-specific gestures, and frame speaker/listener pairs with collision-aware camera transitions. Preserve text, choices, pause ownership and accessibility settings.

## 3. Everyday consequences

- Expand Greyfen's routine response beyond the evidence report to flour deliveries, repaired roads, household relief, the mill decision and the final covenant.
- Reassign existing ambient villagers to kitchen, repair, supply and memorial activity anchors through the existing navigation service. Apply route changes at activity boundaries without teleportation; keep named quest actors on their existing authored routines.
- Add concise contextual ambient observations and visible supply/work changes driven by existing flags. These read committed outcomes and never invent promises, consent or new rewards.

## 4. Combat feel

- Give every attempted melee strike a readable recovery, including misses. Use distinct recovery by enemy behavior and maintain evidence-earned windup advantages.
- Bound facing adjustment early in a windup and commit before contact. Preserve boss special geometry and the real blade/contact system.
- Add bounded, contact-only hit emphasis and repair overlapping hitstop ownership so pause/transition cannot leave time slowed. Respect reduced motion and flash settings; avoid routine miss-message spam.

## 5. Journey flow

- Add in-world directional waymarks for public route gates and quiet, throttled help toward the current tracked objective. Respect manual tracking and unknown evidence.
- Request upcoming route asset packs near a gate while the player is approaching and safe, using the existing asynchronous pack manager. Do not instantiate hidden zones or interrupt first control.
- Cache destination lookups; suspend work during menus, combat and transitions. Retain existing loading recovery and save continuity. No measured performance gain will be claimed without measurements.

## Production and limits

Use the existing Godot 4.6.3 pipeline, regenerate affected animation/audio/source catalog assets and all runtime packs, push `main` and `codex/story-centered-overhaul`, and deploy the existing Vercel project. No tests, QA tools, gameplay launches, previews, performance measurements, verification or post-deployment requests. Compiler/import diagnostics are handled only to produce the requested artifacts. Report implemented scope, publication receipts and the absence of testing honestly.

## Implemented scope

- Directional animation production now bakes backward and left/right clips from the retained Quaternius CC0 Adventurer into the Universal humanoid rest pose. Per-clip stride metadata drives cadence. The existing movement controller remains authoritative.
- Kael receives bounded, ground-aware leg reach with lifted-foot weighting, no root movement, and immediate release during airborne/action poses. Conversations animate both participants with page-specific gestures and speaker/listener expression; camera reverse angles stay on one side of the conversation and interpolate with collision bounds. Reduced Motion retains the established two-person shot.
- Greyfen's existing workers take on kitchen, drainage, mill reserve/repair and household relief routines as committed outcomes change. New assignments start from each actor's real stopped position. Ending observations follow the selected covenant. Supply stacks, mill accounts, returned bowls and a final notice make those consequences visible.
- Enemies follow the player only during the early part of a bounded windup, then commit. Misses now incur recovery too, with slower heavy creatures and quicker duelists. Story preparation bonuses apply consistently. Confirmed blade hits receive short unscaled-time hit emphasis, overlapping timers cannot end a newer hit pause, and Reduced Motion disables it. Routine missed swings no longer spam text.
- Public exits receive close-range destination signs, with the next available road toward the manually tracked objective highlighted. A brief route reminder appears only after sustained wandering without progress and is throttled for two minutes. Nearby approaches queue destination packs asynchronously after the first eight seconds of control; menus, danger and transitions suspend this work. No hidden clue positions are revealed and no hidden scenes are instantiated.

These changes have not been tested or visually reviewed, as requested; no claim of measured performance or verified animation quality is made.

## Publication receipt — 4 October 2026

- Source revision: `b03fe2da5f95feac8f6c757af37dbe1d6f8fd7b3`.
- Build identity: `story-20261004T074623Z-b03fe2da5f95`.
- Generated release commit: `4cbfbc6`, pushed to `main` and `codex/story-centered-overhaul`.
- Production import, directional animation baking, all seven runtime packs, and Web export completed through `build_story_release.ps1 -BuildVoices -Publish`.
- Vercel deployment: `dpl_EdkCCDBxYHM15uLRWKdxooTtfQeD`. Deployment command returned `READY` and aliased `https://ashenoath.vercel.app`.
- Deployment URL: `https://ashenoath-8zwhyxv3p-rafaeitahir-5792s-projects.vercel.app`.
- Local publication receipt: `.release-gate/remaining-four-01/publication.json`.
- No tests, verification, gameplay launches, visual review, performance measurements or post-deployment probes were run.
