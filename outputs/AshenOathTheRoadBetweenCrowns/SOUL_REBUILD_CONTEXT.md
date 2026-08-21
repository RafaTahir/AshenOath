# Ashen Oath Soul-Rebuild Context

## Current Working Checkpoint - 2026-08-21

### ACCESS-003 controller recovery checkpoint

Gamepad profile updates now reach the HUD, and an active-controller loss
clears stale virtual input/focus before returning to keyboard/mouse input.
The targeted access/product gates pass with fresh menu, Greyfen, and Hart
captures. Physical DualShock, DualSense, Xbox, and Switch hardware remains
explicitly untested in this environment; generic SDL/browser mappings remain
the fallback. Production is unchanged.

### AUDIO-007 campaign mix lifecycle checkpoint

Transient world cues now stop at the pause edge, and rapid music-state changes
cancel stale crossfades so the active player set remains bounded. The targeted
audio profile passes with fresh opening soundscape captures. The current sound
library remains procedural/scratch development audio; final recorded/mastered
mix work is still open and production is unchanged.

### HUD-005 product interface checkpoint

The menu and gameplay HUD remain responsive at 1080p menu scale and native
720p gameplay scale. The main menu now has a real Quit action with a desktop
exit path and a browser-safe departure notice, and its build identity clearly
states `DEVELOPMENT CANDIDATE`. The product profile passes with fresh menu,
Greyfen, and Hart captures. Full-route UI review remains part of QA-012 and
RELEASE-003; production is unchanged.

### CIN-002 human dialogue presentation checkpoint

Resolved dialogue pages now carry stable speaker IDs and a normalized
presentation contract. The HUD emits turn changes, and the paused game refreshes
actor facing and the camera's two-shot framing for every page. The CIN-002
verifier, story profile, and UI profile pass. Fresh 1280x720 Anwen/Kael dialogue
captures are current and visually inspected. Acting-quality voice production
and final character visual replacement remain separate release gates; this
checkpoint does not modify production `main`, tracked `web`, or Vercel.

### SIDE-003 consequential side-quest flow checkpoint

The five selected side quests now expose contact handoffs and consequential
choices only when the matching quest state is valid. `DialogueManager` resolves
quest/objective conditions, while `game.gd` rejects stale or out-of-order
actions after reload or duplicate activation. `verify_side_003.gd` and the
targeted story profile pass. Fresh changed-view evidence is in
`Development_Gallery/screenshots/WORLD_001_*_20260821_151120.png` and
`WORLD_002_*_20260821_151155.png`. Full side-quest aftermath and save/reload
permutations remain a `QA-012` responsibility; this development checkpoint
does not change production `main`, tracked `web/`, or Vercel.

### WORLD-012 Greyfen visual recovery update

The latest Greyfen slice fixes an actual screenshot failure: the authored sky
is now a transparent celestial overlay, leaving the 3D world visible under the
WorldEnvironment gradient. Balanced houses use connected gabled roof meshes,
the river material/current is toned into a darker flowing channel, and a
continuous non-colliding ridge closes the empty village horizon. Fresh
1280x720 Greyfen spawn, shrine, forge, and south-approach bridge captures are
current and inspected. This is a bounded presentation improvement, not final
visual approval; the opening still needs the cohesive character/monster and
full authored environment gates before production release.

### OATH-002 combat-state checkpoint

The Oathfire path now uses one state machine for sheathing, hand-based charge,
release, redraw, and cancellation. Its initial facing is immutable through
camera movement and is shared by player orientation, hand-origin effects,
damage, beam endpoint, and impact feedback. Transition locks cancel it
authoritatively and restore the sword. `verify_oath_002` and the targeted combat
profile pass with current native-720p charge/release/wall-impact evidence.
This improves the runtime contract but does not waive the larger visual gate:
the surrounding world and monster family still require final visual review.

### AI-003 tactical behavior checkpoint

The Wychwood pack now treats navigation, crowd separation, attack reservations,
attack-lane clearance, leash recovery, and perception as one movement contract.
Unsafe direct steps stop or reroute through the spatial service, and moving
enemies face their chosen route. The runtime AI gate passes the five-enemy
staged reveal and live spacing/reservation checks. Later browser performance and
final monster-family visual acceptance remain required.

### BOSS-002 lifecycle checkpoint

Boss phases, checkpoints, telegraphs, peaceful outcomes, and defeat are now
idempotent and save-aware. A restored resolved encounter is inactive, while
phase checkpoint health remains authoritative. Framework and five encounter
gates pass; final boss meshes, spectacle, and browser performance remain part
of the full visual/release gate.

### MON-002 monster-family checkpoint

Wychwood's four enemy roles now use one connected Ghoul family: gaunt for
Ghoulkin/Raider, hooded lean for Stalker, and broad for Brute. Each role loads a
skinned body with modeled skull/face, hands, feet, six material surfaces, and
the shared Idle/Walk/Run/Attack/HeavyAttack/RecieveHit/Dodge/Death clips. The
legacy Skeleton.fbx source is quarantined and no longer mapped to route-visible
Wychwood actors. Runtime family instantiation, animation-driver validity, and
fresh 1280x720 formation/contact captures pass. The matching Ultimate Monsters
source and final boss-family visual approval remain open; production remains
unchanged.

### WORLD-015 later-wild presentation checkpoint

Deep Woods, Old Mill, Burned Farmstead, and Marsh Crossing now have a second
route-safe dressing pass: paired road ruts and damp edges, nearer forest
silhouettes, mill braces and warm window light, farmstead charred posts/ash and
ember cues, and marsh water streaks/reflection light. Fresh 1280x720 captures
pass the nonblank gate. The later zones remain deliberately stylized and their
final architecture/material/sky acceptance is still open; production remains
unchanged.

### WORLD-016 castle/finale presentation checkpoint

Castle Approach, Courtyard, Record Hall, Undercroft, Assembly, and Hart Glade
now have a second authored dressing pass: castle route seams and edge insets,
cistern water, visible ledger pages, assembly fire light, Hart Glade edge
silhouettes, and unshaded undercroft ceiling/wall fill. Fresh 1280x720 Castle
and finale captures pass the route/nonblank checks, and the Undercroft arrival
is readable rather than black. These areas remain stylized development visuals;
final architecture, bespoke creature assets, and full browser acceptance remain
open. Production remains unchanged.

### Character contract checkpoint - current continuation

The character foundation contract is enforced at runtime. An inspected role
must have one skeleton, skinned meshes, material surfaces, grounded rendered
bounds within its target height, required sockets, and exactly one
normalization pass. The native face driver recognizes imported eye, brow, skin,
head, hair, jaw, mouth, and teeth surfaces. The released identity profile no
longer adds synthetic face cards, eye boxes, fake necks, or proxy limbs.

The connected Universal full-body candidate was captured and rejected because
its current wardrobe import is underwear-only for the male and bald/underwear-
only for the female. Runtime therefore remains on the complete clothed male
and female peasant composites while the proper hunter, cleric, crowd, and guard
outfit pass remains open. These fallback composites are grounded and have
native face/hair surfaces, but they are not final visual approval.

The current targeted character gates pass: CHAR-005 through CHAR-009,
FACE-003, CHARACTER-REAL-001, and the new role-contract verifier. Asset
acceptance passes with one approved Ranger role and eight pending roles. Fresh
character evidence is in `Development_Gallery/screenshots/CHAR_006_*` through
`CHAR_009_*`. No production export or deployment has been performed for this
continuation.

### ENGINE-004 lifecycle checkpoint

ENGINE-004 now owns the latest development checkpoint. Build-only terrain and
detail marker nodes are freed after MultiMesh transforms are copied, final
shutdown releases explicit skinned/material anchors and build-time arrays, and
`verify_engine_004.gd` passes active material, invalid-geometry, cache, staged
retirement, and final-anchor checks across Greyfen, Wychwood, Castle Approach,
Record Hall, and return. QA-005 classifies five remaining renderer messages as
shutdown-only warnings after the verifier pass marker; active null-material
errors are absent. Production `main`, tracked `web/`, and Vercel remain
unchanged until the complete visual and release gates pass.

### SAVE-003 migration checkpoint

SAVE-003 advances the save schema to version 7. Direct and file-backed loads
share migration, malformed quest/story/settings/world containers are sanitized,
unknown tracked quests are discarded without inventing progress, all released
zones have explicit safe defaults, and invalid river/campaign positions are
validated through the zone spatial service. `verify_save_003.gd` passes the
malformed-data and real Wychwood recovery route. Production remains unchanged.

### INPUT-002 continuation checkpoint

`InputRouter` now owns the input-context contract for menu, gameplay, pause,
dialogue, journal, settings, controls, remapping, minigame, death, and
transition states. HUD panels, minigames, pause/resume, and camera pointer
handling delegate to the same service. Focus helpers prevent stale menu focus
and remap navigation remains keyboard/gamepad safe. `verify_input_002`, the
existing INPUT-001/003/004 gates, runtime regressions, UI-001, and the full
input ticket profile pass. Headless Godot cannot prove an OS pointer lock, so
that exact assertion remains reserved for graphical/browser testing. This is a
development checkpoint; production remains unchanged.

### QUEST-012 continuation checkpoint

The Hart Remembers arc now has four immutable covenant outcomes: Witness,
Mercy, Duty, and Ash. The runtime verifier exercises all four, including the
two boss-backed resolutions, White Hart defeat handoff, epilogue card creation,
save round trip, stale-dialogue replay protection, and state-specific Hart
Glade aftermath dressing. Story and World-006 targeted profiles pass and fresh
Hart route captures exist. This remains a development checkpoint: later-zone
visual quality is still below the locked bar, shutdown diagnostics remain
open, and no production export, `main` push, or Vercel deployment has occurred.

### BOSS-007 continuation checkpoint

The White Hart now has a data-driven three-phase encounter slice in the
reopened Hart Glade. Duty/Ash combat endings spawn the boss with a ten-metre
leash, Mercy/Witness resolutions normalize to the final covenant, and the
existing save/checkpoint path preserves phase health and no-respawn aftermath.
The mapped animated Wolf body receives a restrained memory halo, oath mark,
phase-reactive rings, and the existing bone-attached antler crown. The targeted
verifier passes identity, animation, phases, checkpoint restore, Mercy
resolution, objective completion, and reload safety. Fresh native-720p frames
exist for Witness, Mercy, and Debt. The encounter and witness display now use
the dedicated `white_hart_boss` role at 3.60 m with a measured imported ground
offset, so the Hart is grounded and readable at the gameplay camera distance.
The body and Hart Glade remain interim visuals; MON-002 and the later visual
gate still require a final supernatural stag treatment. No production export
or deployment has occurred for this checkpoint.

### BOSS-005 continuation checkpoint

Ashwing now has a reload-safe Old Mill encounter slice. Its authored phases,
checkpoint objective, charred harness, ash core, and scorched wing roots are
active. The actual Oathfire cast resolver interrupts Ashwing's windup and
stagger-locks the encounter when the beam hits during `ash_breath`. Runtime
verification and fresh Compatibility captures pass. The dedicated
`ashwing_boss` role normalizes the animated Dragon source to 4.80 m. The body
is still an interim low-poly mapping; MON-002 remains responsible for the final
cohesive monster-family replacement. No production export or deployment has
occurred for this checkpoint.

### BOSS-006 continuation checkpoint

Halvern now uses the connected Gravebound runtime source rather than the
missing legacy alias. His Vargan cuirass, grave seal, asymmetric shoulders,
and broken banner sit under the boss identity layer. A genuine player parry
opens a testimony window, sets `halvern_guard_broken`, completes the guard
break objective, and preserves the existing parry feedback. Phase checkpoint,
health restore, testimony resolution, and reload safety pass. The undercroft
now uses two named Balanced light pools and a brighter authored interior
profile, so the duel remains readable. The armor source remains interim
low-poly. No production export or deployment has occurred for this checkpoint.

The deployed production baseline is the earlier `bd24495` release. The current
Soul Rebuild continuation is uncommitted on `codex/soul-rebuild`, and its Web
artifact has not been rebuilt or deployed. Historical hashes and browser runs
in this file are evidence for the prior checkpoint only.

The current source has targeted passes for lifecycle cleanup, save/input
foundations, characters, combat, Oathfire, AI, authored world/lighting
contracts, and fresh graphical sky captures. The active capture frames are
1280x720 and nonblank. Godot still emits shutdown-only allocator diagnostics
after isolated graphical processes exit; no active-frame material error was
seen in the targeted gates.

The NARR-005 continuation closes the remaining authored-beat gaps in the
campaign presentation layer. `QuestBeatDirector` now covers every non-optional
objective in all ten main quests, including chapel opening, erased-name
reading, Castle entry/evidence/haunting, the undercroft hook, and Hart arrival.
QuestManager remains the only progression authority; beat state is still
zone-aware and saveable. The strengthened verifier passes source coverage and
beat-zone save/load round-trip. This improves guidance only and does not claim
that the full campaign has passed real-input or final visual acceptance.

The QUEST-008 continuation adds an explicit Road-of-Crows report contract for
private Anwen, public notice-board, and retained-evidence outcomes. Its new
permutation gate exercises all 120 clue orders and proves the three-clue
threshold remains order-independent without losing the report targets. The
route is functionally covered; final browser pacing and visual evidence remain
Milestone F work. Report-ready prompts now name the actual private/public
choice, post-report notice-board dialogue no longer exposes the old contract
action, and legacy completed saves receive a neutral report-choice handoff.
The inserted chapel-name objective also migrates from later Teeth in the Rain
progress, with the full story profile passing after the repair.

The QUEST-009 continuation closes a player-facing choice bug shared by the
shrine and later campaign decisions: selecting a dialogue action now restores
the gameplay pointer, unpauses the world, and hides the dialogue layer before
the consequence is applied. The full story profile and fresh WORLD-014
cemetery captures pass. The cemetery remains stylized development art, with a
tree-heavy framing called out for later world reconstruction.

The latest continuation slice adds Anwen's bone-attached upright staff, shared
Balanced roof treatment, visible animated river-current ribbons, stronger
Oathblade presentation, capsule/cylinder boss silhouette dressing, and
shutdown-safe capture/verifier cleanup. The deferred autosave race that could
read a released player during Oathfire teardown is fixed. Character, combat,
world, Oathfire, and lifecycle targeted gates pass on this source state.

The released Bog Wretch and Gravebound Knight mappings no longer fall through
to primitive Slime/Skeleton bodies. Both now use connected skinned Ghoul-family
runtime bodies with role-specific swamp or iron material profiles and explicit
pending fallbacks in the asset manifest. This improves runtime coherence while
leaving final bespoke creature and armor approval open.

`WORLD-016` is the next completed development slice. Castle approach,
courtyard, Record Hall, undercroft, assembly, and Hart Glade now have bounded
structural dressing, authored material tint variants, route-safe staging, and
fresh 1280x720 captures. The White Hart is visible at the gameplay camera
distance and the generated Ghoul family is re-exported within the six-surface
Compatibility budget. This remains development evidence, not final visual
approval.

The active BOSS-002/BOSS-003 slice makes Bell-Eater phase and checkpoint state
durable: phase health is saved/restored, resolved encounters do not respawn
after zone rebuild, and the harness, bell, chains, eyes, and phase sigil
animate from one identity layer. Bell-Eater now uses a dedicated 3.80 m
focal-creature role with a matching collision capsule, corrected derived-body
facing, and no floating proxy torso/arm rods. Cemetery NPCs evacuate during
the fight and return after victory. Fresh Bell-Eater frames are in
`Development_Gallery/screenshots/`. The encounter is readable but still uses
an interim low-poly monster mapping and a blockout cemetery; this is a
development checkpoint, not final visual approval or production release.

The BOSS-004 slice adds the same durable encounter contract to Rootbound
Colossus in Deep Wood. Register reconstruction spawns the boss, the phase
checkpoint restores health, and the dedicated 4.40 m `rootbound_colossus_boss`
role gives it a bark mantle, root feet/crown, and exposed-heart silhouette. A
defeated encounter does not respawn after zone rebuild. Fresh phase frames and
a runtime gate pass; the source body is still an interim low-poly mapping.

The full 62-ticket Soul Rebuild acceptance is still open: interim monster and
boss assets, later-zone visual reconstruction, full real-input campaign proof,
fresh export/packed startup, and post-edit live PCK comparison remain. Do not
describe this checkpoint as a production release.

This is the compact handoff document for the 62-ticket soul-rebuild program. It is intentionally shorter than the historical phase archive.

## Product Truth

Ashen Oath is an original browser-first dark-fantasy RPG. The current source is a functional pre-alpha with a playable Greyfen/Wychwood route and broader campaign sections. It is not yet a finished AAA game. The soul-rebuild target is a coherent 90-minute opening followed by a compact 4-6 hour campaign.

## Creative Pillars

1. Buried testimony: every investigation reveals a person, not just a collectible.
2. Dangerous vows: Kael's choices change trust, access, encounters, and the shape of the ending.
3. Landscapes altered by memory: rivers, roads, shrines, graves, portals, and weather react to what Greyfen remembers.

The visual language is grounded stylized dark fantasy: wet stone, ash, timber, muted cloth, warm fire, cold moonlight, and restrained supernatural cyan. No protected characters, names, scenes, or copied designs are used.

## Non-Negotiable Runtime Rules

- Imported character bodies are authoritative. Runtime must not add root-mounted faces, hair, shoulders, cloaks, eye boxes, fake necks, or proxy limbs.
- All route-visible humans use one shared humanoid ecosystem. All released monsters use complete bodies and readable silhouettes.
- Bridges are the only river crossings. NPCs and enemies use the same river-aware spatial service as the player.
- Oath Gates are animated arches with preloading, destination silhouettes, ash/crow motion, audio, and safe rollback. Plain colored transition slabs are prohibited.
- Loading must never become a black screen. The Web shell shows Ashen Oath content immediately; long travel uses an interactive Crow Path vignette.
- Objectives, dialogue, compass, portals, world state, and save state use one authoritative quest presentation state.

## Performance Contract

- Balanced is native 1280x720 and must average at least 32 FPS with a 30 FPS 1% low on the Dell 7280.
- Potato reduces visual density but never removes gameplay-critical routes, actors, clues, or prompts.
- Web deployment stays below 100 MB. Raw downloads, Blender files, screenshots, and development tools are excluded.
- Cold engine startup target is 12 seconds or less, with a hard 15-second ceiling. New Game after engine readiness is 750 ms or less.

## Content Spine

The campaign is presented through six main chapters: Road of Crows; Bell Beneath Greyfen; Teeth, Names, and Ash; Blood Under Stone; The Last Witness; and The Hart Remembers. Legacy quest IDs remain loadable through aliases. The five large encounters are Bell-Eater, Rootbound Colossus, Ashwing Carrion Drake, Halvern Gravebound Knight, and the White Hart.

## Workflow

Read this file, `PROJECT_STATE.md`, and the active ticket only. Ordinary tickets use `tools/run_ticket_gate.ps1`, changed-view screenshots, a result document, and the cumulative `codex/soul-rebuild` checkpoint. Full Web export, `web/` synchronization, `main`, Vercel, and live smoke testing happen only at milestone boundaries.

## Current Foundation Checkpoint

The first soul-rebuild implementation slice removes generated anatomy overlays, adds the custom Web boot shell and Crow's Crossing loading activity, identifies gamepad families/hotplug state, replaces plain route markers with animated Oath Gate visuals, and registers a threaded zone-resource request service. The loading checkpoints add a validated runtime-pack manifest, embedded-PCK fallback manager, Web artifact hash generator, opening PackedScene layer catalog, adjacent-zone prewarming, gate-owned preload/travel/error states, and a delayed nonblocking in-game transition vignette with safe procedural fallback. The remaining character, world, combat, boss, story, and performance tickets must build on this contract rather than reintroducing procedural overlays.

## Milestone D Acceptance

`OPENING-QA-001` accepts the cumulative opening rebuild under an abbreviated, user-selected browser gate: Chrome must complete the real-input opening route without console errors and average at least 30 FPS at native 1280x720 Balanced. The accepted run completed 17 checkpoints at 33.0 FPS average and returned to Greyfen after reporting to Anwen.

The 30 FPS 1% low, transition-time targets, Edge/Firefox coverage, full verifier suite, and complete screenshot refresh remain deferred. Future tickets must not interpret this milestone deployment as evidence that those stricter contracts passed.

## Current continuation checkpoint

The current Milestone E/F product slice is present in the working tree: contact-driven sword evidence, optional target lock-on, Oathfire endpoint feedback, data-driven boss definitions/checkpoints/save restoration, role-specific boss telegraphs, encounter-specific procedural music, QuestBeatDirector tracker decoration, campaign consequence dressing, responsive HUD anchoring, accessibility/gamepad acceptance, deterministic performance contracts, and released-zone lifecycle coverage.

Godot gates run with an explicit log-file because the sandbox cannot create the default user logs path. The targeted accumulated gates pass with that isolated logging path. The sandbox can read but not write its Godot user profile, so settings and atomic-save checks report a bounded environment warning; those disk assertions remain active in a normal writable browser profile.

The current continuation is an uncommitted recovery checkpoint. Fresh graphical character evidence, a native Compatibility visible-quality run, runtime contracts, asset checks, product captures, and opening timing have been rerun. The older Web artifact and browser results in `RELEASE-003_RESULT.md` are historical evidence only; a new export, packed startup, live hash comparison, and deployment are still required after the current source changes. Web Greyfen prewarm is now enabled behind the visible launch/menu state with a bounded 30-frame warmup; the opening gate records 10.982 seconds engine-ready and 51 ms New Game activation.

The current visual gate is intentionally honest: Kael and Anwen pass the native-face/connected-body portrait check, while Ghoulkin remains a grounded low-poly interim family and Ashwing remains an interim animated Dragon mapping. The latest Greyfen and Hart captures are fresh, but still show stylized/procedural architecture and finale dressing below the locked visual bar. Later campaign architecture, river/bridge composition, and complete route evidence still require the visual acceptance pass before production deployment.

## ENGINE-005 Development Checkpoint

The typed coordination boundary is now implemented and verified on
`codex/soul-rebuild`. `ZoneRuntimeCoordinator` receives the quest presentation,
quest-beat, interaction-focus, and quest-manager services; validates registered
zone requests; synchronizes zone context; refreshes the tracked objective;
selects focused interactions; and records playable transition timing. The
runtime host delegates those operations instead of duplicating direct service
calls.

`verify_engine_005.gd` and the targeted engine profile pass. QA-005 reports no
active renderer/material errors before the verifier pass marker. Godot's known
Compatibility shutdown diagnostics remain after isolated test teardown and are
classified as warnings, not hidden. The result is recorded in
`ENGINE-005_RESULT.md`; no Web export or production deployment was performed.

## ASSET-004 Current Contract Checkpoint

The asset contract has been corrected to match the actual local library. The
source manifest records five CC0 pack families, dependencies, acquisition
status, selected runtime artifacts, byte/hash evidence, and export policy. The
role manifest contains nine route-visible role entries: only the optimized
Ranger runtime is approved and export-eligible; the other eight roles are
blocked with explicit reasons and playable fallbacks until their selected
sources pass import, skeleton, clip, budget, license, and Codex visual review.
The optimized UAL2 animation file is recorded as a selected runtime dependency;
root-motion, FBX, setup, mannequin, raw, and download sources remain excluded.

`verify_asset_acceptance.py` and the `assets` ticket profile pass. This is an
honest asset-library checkpoint, not a claim that the final character or
monster replacement has shipped. `ASSET-004_RESULT.md` records the exact
artifact counts and next registration requirements. Production `web/`, `main`,
and Vercel remain unchanged.

`PIPE-003` adds `tools/character_asset_pipeline.py`, a deterministic plan/execute
boundary for selected GLB/GLTF sources. It rejects raw/download/source-animation
inputs and unsafe runtime outputs, preserves root-motion-off policy, records
artifact hashes, and registers converted outputs as pending visual review.
`verify_pipe_003.py` is wired into the assets profile and passes. Blender and
gltfpack are intentionally external prerequisites; the current generated Ghoul
files remain fallbacks, not approved final monsters.

### PERF-008 runtime performance checkpoint

PerformanceBudgetMonitor is now a concrete runtime contract bound to zone
activation, transition timing, lifecycle snapshots, quality presets, and
explicit budget refreshes. Compass interaction summaries reuse the indexed
area cache; ambient prop animation is centralized and distance-bounded;
interactive state components no longer run duplicate per-prop process loops;
enemy encounter peers and camera enemy candidates are cached; stale freed
actors are ignored; and player foot-height probes are limited to 30 Hz while
movement and combat remain full-rate. The graphical verifier no longer
contains temporary process-disabling or timing probes.

The final clean native-720p Compatibility run passed every sampled zone and
combat profile: Greyfen 59.9 / 34.0, Wychwood 59.9 / 33.5, Wychwood combat
55.3 / 30.1, Vargan courtyard 60.0 / 40.5, Record Hall 60.0 / 52.1, and
Hart Glade 60.0 / 46.7 FPS average/1% low. Static memory stayed below
106 MB, cold transitions below 264 ms, and warm return was 60 ms. The
performance-contract and zone-budget gates pass.

Known Compatibility renderer/RID/ObjectDB messages occur only during isolated
verifier teardown and remain ENGINE-004 lifecycle debt. They are reported
explicitly, not suppressed. This checkpoint remains development-only: final
visual asset approval, full real-input campaign coverage, Web export, and
production deployment remain open.

### QA-012 real-input route checkpoint

QA-012 is now a truthful graphical candidate gate rather than a direct state
or zone-loader smoke test. On a fresh isolated profile it moved through the
opening, interacted with Anwen and three Wychwood clues, defeated the staged
five-enemy pack through mapped attack input, reported to Anwen, and traversed
all released wilderness and Castle gates in both directions before returning
to Greyfen. Story-gated Undercroft, Assembly, and Hart Glade thresholds were
observed locked without mutating story state.

The route found and fixed a Greyfen `LowBerm` collider in the west long-road
approach and a Castle Courtyard outer gate positioned inside the gatehouse
left-wing collision. The targeted `qa012` profile passes content integrity,
runtime smoke, QA-012, runtime regressions, save migration, gate transitions,
navigation, and river safety. `QA-012_RESULT.md` contains the exact route and
running command.

Compatibility renderer/RID/ObjectDB shutdown messages remain classified
ENGINE-004 debt after the verifier pass. QA-012 is a development checkpoint;
the final visual gallery, full release runner, Web export, `main` push, and
Vercel deployment remain RELEASE-003 work.

### ENGINE-004 anchor retention correction

The deferred zone retirement path now drops retained material anchors only
after the final staged root has completed its queued free. This preserves the
renderer-safe retirement window and fixes the pre-finalization anchor failure.
The fresh graphical ENGINE-004 run and full `engine` ticket profile pass with
no active null-material errors. Compatibility RID/ObjectDB diagnostics still
appear after the verifier pass during isolated process teardown and remain
explicit shutdown debt rather than an active gameplay failure.
