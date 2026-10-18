# Performance Optimization Tickets

Approved basis: 48-ticket performance plan, 2026-10-18. Canonical checkout:
`D:\Projects\AshenOath`, branch `codex/masterpiece-rebuild`.

## Execution and Acceptance

- Preserve content, population, quests, preferred character identities, equipment,
  saves, visual presets and complete Greyfen before control.
- Build-only implementation: static review and necessary artifact compilation/
  packaging only. No agent tests, game launches, browser runs or benchmarks.
- `implemented` means source is present, not that performance or gameplay passed.
  User acceptance remains separate and pending until supplied by the user.
- Compare cold/warm page-to-menu and page-to-control, first playable frames,
  sustained FPS, slow frames and memory. Do not move costs beyond the timer.
- Full Web directory must remain strictly below 104857600 bytes. Publish at the
  six milestone boundaries through the existing explicit-path release command.
- Conditional visual changes require the user's before/after comparison. Do not
  revive rejected tree grouping, shader or one-object prewarm mechanisms.
- No engine fork, renderer change, silent quality reduction or new QA framework.

## Milestone 1: Downloads, Startup and Caching

### OPT-001 - Smaller bootstrap package
Owner: `game.gd`, export selections, pack-layout compiler. Depends: OPT-003.
Change: keep coordinate-only restoration data in base; defer zone scripts and
their scenery, human assemblies and equipment until the opening pack is mounted.
User check: fresh menu still works; first Greyfen is complete; campaign loads.

### OPT-002 - Greyfen-only opening dependency
Owner: export selections, runtime-pack manifest/manager. Depends: OPT-001/003.
Change: separate Wychwood/ruins scripts, evidence and non-Greyfen authored layers
into `adjacent`; keep cemetery scenery shared with Greyfen in opening.
User check: opening works without adjacent; earned crossings and returns work.

### OPT-003 - Single-owner pack resources
Owner: `tools/prepare_runtime_pack_layout.py`, existing package builder.
Change: transfer explicit selections to base/opening/adjacent/campaign owners;
do not export replacement core scripts/manifests in character/monster/audio packs.
User check: characters, scenery and materials remain correct after every mount.

### OPT-004 - Reusable engine downloads
Owner: Web manifest builder, shell engine configuration, hosting headers.
Change: move the unchanged engine family under a content-derived immutable path;
keep main PCK identity independent and retain gzip/MIME/AudioWorklet configuration.
User check: fresh load and normal reload work across two game releases.

### OPT-005 - Cross-release pack caching
Owner: browser pack cache and RuntimePackManager cache paths.
Change: key cached bytes by content identity rather than release name; validate
every consumed browser artifact and bound eviction to non-current cache entries.
User check: unchanged packs are reused; corrupt bytes cannot mount; Retry works.

### OPT-006 - Separate download and mount dependencies
Owner: RuntimePackManager. Depends: OPT-003.
Change: fetch independent queued packs concurrently; retain verified files until
dependencies are mounted; propagate dependency errors instead of hanging.
User check: cold/cached destinations load without missing-resource errors.

### OPT-007 - Critical-download priority
Owner: RuntimePackManager. Depends: OPT-006.
Change: startup/foreground/background priorities, bounded desktop/touch download
slots and preemption of speculative work when a journey requires a slot.
User check: Continue to another zone and Retry never wait behind obsolete work.

### OPT-008 - Shared browser download handoff
Owner: Web shell and RuntimePackManager. Depends: OPT-005/006/007.
Change: use the same validated browser download for all packs; publish metadata
only after filesystem handoff; cancel obsolete attempts; retain HTTP fallback.
User check: no duplicate fetches, stale attempt activation or stuck Retry states.

## Milestone 2: Preparation, Worlds and Transitions

### OPT-009 - Lower pack-memory peaks
Owner: shell buffer lifetime and RuntimePackManager download completion.
Change: avoid persistent payload-bearing promises and unnecessary buffer/file
copies; native downloads use file sinks; preserve validation and bounded fallback.
Depends: OPT-008. User check: compare startup and transition peak process memory.

### OPT-010 - Coalesced resource requests
Owner: AssetSpawnHelper, WorldMaterialLibrary, ZoneStreamingService.
Change: share pending loads and successful immutable results for identical paths;
attempt cancellation must not discard another owner's valid request.
Depends: OPT-009. User check: Retry and preparation-time quality changes work.

### OPT-011 - Demand-driven campaign initialization
Owner: RuntimeServiceRegistry and campaign data indexes.
Change: defer only services/data demonstrably unused by opening, retaining shared
opening dialogue, quests, saves and required service injection.
User check: menu-to-opening and first campaign entry both preserve all features.

### OPT-012 - Settings-specific updates
Owner: game settings application, HUD and VisualDirector.
Change: propagate changed fields only; use supported local presentation changes
instead of zone reloads; rebuild only components whose preset geometry differs.
User check: volume, subtitles and visual preset changes preserve encounter/save.

### OPT-013 - Prepared Greyfen geometry
Owner: existing geometry builder and runtime packed-scene preparation.
Change: compile immutable meshes/batches before packaging; preserve authored
transforms, collision, routes and dynamic story layers. Depends: OPT-003.
User check: identical opening composition, population and interaction access.

### OPT-014 - Prepared campaign geometry
Owner: campaign zone builders. Depends: OPT-013.
Change: apply the prepared geometry contract to remaining static construction;
retain return, combat, lighting and aftermath overlays without duplicate builds.
User check: arrival/return and changed-story states retain complete scenery.

### OPT-015 - Zone-local cache invalidation
Owner: zone signatures and residency service.
Change: use declared zone-relevant state revisions rather than whole-story save
hashes; preserve invalidation for every actual scene/encounter consequence.
User check: unrelated progress preserves cache; relevant consequences still apply.

### OPT-016 - Real destination prefetch
Owner: ZoneStreamingService and ZoneSceneCatalog. Depends: OPT-014/015.
Change: prefetch actual likely destination resources through one scene owner;
do not label empty-path requests as prepared authored content.
User check: boundary crossings, cancellation and returns remain complete/safe.

## Milestone 3: Characters and NPC Loading

### OPT-017 - Prepared human assemblies
Owner: character build pipeline and AssetSpawnHelper.
Change: serialize immutable fitted assemblies, retaining per-actor recipe state,
native animation, anatomy, sockets and role IDs. Depends: OPT-003.
User check: A-set Kael/Anwen, Ranger Senn and crowd variations are unchanged.

### OPT-018 - Prepared animation bindings
Owner: CharacterAnimationFusion. Depends: OPT-017.
Change: prepare immutable libraries once per source/rig/binding signature instead
of repeatedly cloning and retargeting tracks at actor creation.
User check: backward/forward gait, footsteps, combat and dialogue gestures agree.

### OPT-019 - Prepared character metadata
Owner: AssetSpawnHelper and character drivers. Depends: OPT-017/018.
Change: reuse immutable hierarchy/bounds/normalization/clip/socket metadata; never
share live node references between instances or skip instance-specific checks.
User check: grounding, height, animation and equipment attachment remain correct.

### OPT-020 - Shared appearance materials
Owner: humanoid and monster appearance recipes. Depends: OPT-019.
Change: cache immutable palette variants; keep damage/flash/expression material
state instance-local and invalidate on actual source or recipe changes.
User check: adjacent identities stay distinct; one actor's hit cannot tint others.

### OPT-021 - Prepared monster assemblies
Owner: enemy presentation and existing asset pipeline. Depends: OPT-018/019.
Change: prepare retained bodies, attachments and bindings with existing bounds;
preserve boss IDs, animation contracts, phases and saved encounter restoration.
User check: every retained monster/boss looks and behaves as before.

### OPT-022 - Equipment-state reuse
Owner: EquipmentLoadout, player/enemy equipment presentation.
Change: retain fitted equipment resources; update actual draw/sheath/weapon state
only, without rebuilding geometry or applying redundant visibility writes.
User check: sword, bow, quiver, first person and Oathfire restore correctly.

### OPT-023 - NPC neighbour indexing
Owner: GreyfenLifeController and existing actor registration.
Change: local spatial neighbour queries replace whole-crowd spacing scans; keep
registration/removal/relocation updates and exact route/collision authority.
User check: population count, routines, crowd spacing and approaches are retained.

### OPT-024 - Change-driven facial writes
Owner: CharacterFaceDriver and StoryHeadModifier.
Change: skip identical presentation property writes, not required animation
evaluation or active gestures; retain blink/speech cadence and listening reactions.
User check: close conversations and idle attention remain natural and animated.

## Milestone 4: AI, Navigation, Physics and Camera

### OPT-025 - Enemy neighbour indexing
Owner: enemy spacing/reservations. Depends: OPT-023.
Change: reuse registered local queries for peers instead of full encounter scans;
keep authoritative body movement, hitboxes and attack reservation ownership.
User check: five-enemy fights remain populated, separated and collision-safe.

### OPT-026 - Reusable route calculations
Owner: ZoneSpatialService and actor route requests.
Change: cache deterministic route portions by zone revision/clearance/endpoints;
keep final live collision checks and moving-obstacle invalidation.
User check: bridges, gates, pursuits, escorts and return routes remain valid.

### OPT-027 - Shared perception queries
Owner: enemy perception. Depends: OPT-025.
Change: reuse equivalent same-step visibility queries only until relevant motion;
actual damage/contact and attack-lane decisions retain fresh authority.
User check: concealment, sight acquisition and attacks through obstacles agree.

### OPT-028 - Indexed spatial exclusions
Owner: SpatialSurfaceContract/ZoneSpatialService.
Change: index immutable exclusions, corridors and bridges while preserving exact
queries and version invalidation; do not introduce parallel spatial rules.
User check: bridge-only river crossing, recovery and invalid saves remain safe.

### OPT-029 - Reusable physics-query objects
Owner: occupancy, perception and camera query construction.
Change: reuse owner-local parameters and buffers; fully reset masks, transforms
and exclusions; do not share mutable query instances across concurrent owners.
User check: no new movement/camera obstruction or ignored-actor regression.

### OPT-030 - Deduplicated movement validation
Owner: spatial/actor step validation. Depends: OPT-026/028/029.
Change: combine equivalent checks within the same physics state; invalidate on
relevant movement; never omit authoritative live checks based on stale results.
User check: off-centre crossings and movement near props/NPCs remain clear.

### OPT-031 - Shared camera target evaluation
Owner: CameraController. Depends: OPT-027.
Change: reuse same-frame candidate filtering/visibility across lock and framing;
immediate orbit/zoom changes still refresh obstruction and first-person state.
User check: 360 yaw, first person, target switching and dialogue exit work.

### OPT-032 - Staggered planning work
Owner: AI/routine scheduling. Depends: OPT-025/026.
Change: phase perception/repath/routine deadlines without lowering their intended
cadence or delaying physics, attack timing, telegraphs or player response.
User check: movement/combat stays responsive while recurring frame spikes fall.

## Milestone 5: Rendering and Resource Memory

### OPT-033 - Prepared tree-source metadata
Owner: tree batch creation and asset preparation. Depends: OPT-019.
Change: prepare tree mesh/material/normalization metadata instead of creating
preview actors to rediscover it; keep every instance and camera collider.
User check: tree identity, location, scale and camera clearance are unchanged.

### OPT-034 - Bulk MultiMesh uploads
Owner: static environment batch publication. Depends: OPT-013/014.
Change: build one complete transform/color buffer per unchanged batch rather than
repeated server writes; retain bounds, material groups and exact transforms.
User check: identical geometry and fewer construction stalls, without pop-in.

### OPT-035 - Transparent-surface efficiency
Owner: authored/effect surface classification. Conditional user comparison.
Change: avoid blending only where the actual surface is opaque; do not flatten
materials, change silhouettes or remove fog/water/impact contributions.
User check: same-camera appearance plus frame-time comparison; retain on approval.

### OPT-036 - Inactive presentation allocation
Owner: VisualDirector/SkyBackdrop.
Change: instantiate only active supported presentation paths; preserve alternate
source assets and necessary diagnostic data without hidden duplicate geometry.
User check: outdoor/interior/day/night/menu and accessibility states still match.

### OPT-037 - Accurate culling bounds
Owner: oversized imported/batched mesh bounds. Conditional user comparison.
Change: fix only demonstrably inaccurate bounds with full animation/camera
coverage; do not shorten visibility distances or clip moving characters.
User check: orbit and movement show no missing geometry or animation clipping.

### OPT-038 - Interior occlusion
Owner: existing solid interior architecture. Conditional user comparison.
Change: conservative occluders only after unsupported cases are excluded; retain
layout, doors, actors and dynamic visibility. Depends: OPT-014.
User check: no disappearing content and an actual performance benefit.

### OPT-039 - Reusable combat effects
Owner: CombatVfxCoordinator and contact effects.
Change: pool immutable meshes and safely reset instance-owned materials/tweens;
zone retirement cancels/reclaims all effects; preserve every impact/timing cue.
User check: repeated arrows/Oathfire/melee retain appearance with no stale effects.

### OPT-040 - Resource-cache retirement
Owner: AssetSpawnHelper and ZoneResidencyService.
Change: release unused cache references with explicit active/shared ownership;
retain proven renderer safeguards; do not claim mounted packs can be unmounted.
User check: repeated zone returns do not grow memory or lose resources.

## Milestone 6: HUD, Audio, Saves and Progression

### OPT-041 - Changed-value HUD updates
Owner: HUD and progression/player signal wiring.
Change: avoid identical text/bar updates; XP-only changes must not reapply health
or unrelated stats; preserve genuine notifications and derived stat changes.
User check: damage, stamina, XP, level-up, skill purchase and quick counts update.

### OPT-042 - Cached journal models
Owner: journal/inventory/evidence/progression presentation.
Change: retain unchanged data models and update affected entries rather than
rebuild all controls; invalidate on real state changes and preserve reading/focus.
User check: journal/shop/growth screens remain current and navigable.

### OPT-043 - Lean responsive reflow
Owner: existing HUD reflow and typography application.
Change: cache unchanged style/typography results while retaining viewport,
safe-area, subtitle and focus invalidation; do not replace the responsive system.
User check: portrait/landscape/short screens remain usable with working Use.

### OPT-044 - Demand-loaded recorded cues
Owner: AudioManager recorded library.
Change: prepare relevant sound groups rather than eager full-library loading;
prime required cues before use and retain authored/approved fallback policy.
User check: footsteps, combat, shops and regional ambience have no missing onset.

### OPT-045 - Reusable dialogue playback
Owner: AudioManager voice players.
Change: reuse playback nodes between approved lines with complete reset; retain
queue, cancellation, ducking, pause, subtitle and browser audio-unlock behavior.
User check: conversations, interruption and replay have no overlap or missing line.

### OPT-046 - Split prepared audio banks
Owner: PreparedAudioBank and its existing build pipeline. Depends: OPT-003.
Change: separate menu/opening references from campaign music/ambience without
re-encoding, deleting audio or introducing unapproved synthetic speech.
User check: sound/music transitions and saved mix remain unchanged.

### OPT-047 - Efficient durable saves
Owner: SaveManager and saved journey summaries.
Change: build/serialize each snapshot once and cache unchanged summaries; keep
atomic writes, exact journey tokens, recovery copies and durable browser sync.
User check: normal Save/reload/Continue restores the exact journey/settings/XP.

### OPT-048 - Incremental XP reward processing
Owner: progression reward collection. Depends: OPT-041.
Change: process affected reward categories and coalesce notifications without
inventing/removing XP, replaying claims or losing region/return/skill progression.
User check: discovery, quests, kills, meaningful returns and reload remain correct.

## Milestone 7 - Enablement and Startup

### OPT-049 - Honest comparison controls
Enable alpha splitting and static bounds by default; request native interior
occlusion while reporting stock Web occlusion unsupported. Explicit 0/1 query
and native arguments override defaults. Optional perf display includes slow
gameplay frames, worst frame, >50ms hitches, effective options and known timings.
User check: compare defaults and individual overrides without changing saves.

### OPT-050 - Lazy script dependencies
Demand-load gameplay service scripts and campaign-only coordinators before use;
retain service IDs, order, required-component errors and menu readiness.
User check: New Game, Continue, encounters and campaign interactions remain intact.

### OPT-051 - Offline terrain construction
Move fixed authored Wychwood ground, path, clearing, layby and berm mesh building
to the existing asset compiler. Preserve vertices, UVs, normals, transforms and
runtime material ownership. Random/state-dependent overlays keep their owner.
User check: identical terrain, bridge joins, collision and quality presets.

## Milestone 8 - Construction and Gameplay CPU Work

### OPT-052 - Prepared static batch data
Compile immutable house/module/prop/detail buffers, preserving material grouping,
night states, transforms and dynamic consequences. No broad scene/prewarm rewrite.
User check: every building, prop and consequence remains visible and functional.

### OPT-053 - Cached objective/navigation presentation
Invalidate objective models only on actual inputs; reuse navigation terrain/frame
work independently from moving markers, including spatial revision and layout.
User check: objectives, dial, accessibility, movement and saves remain current.

### OPT-054 - Nearby interaction indexing
Use registered local candidates; preserve scoring, dwell, visibility and relevant
looked-at priority. Revalidate the displayed target on Use.
User check: keyboard, mouse and touch interact with the displayed object.

## Milestone 9 - Resource Efficiency

### OPT-055 - Shared immutable collision shapes
Share exact-property primitive resources, never mutable shapes. Retain every
body, transform, collision layer/mask and interaction identity.
User check: routes, bridge, actors, projectiles and collisions remain unchanged.

### OPT-056 - Bounded decoded-audio ownership
Retire inactive campaign music/ambience cache references after crossfades;
preserve active/transition streams, voices, shared cues and destination readiness.
User check: transitions, dialogue, pause and audio preferences persist correctly.
