# Ashen Oath Soul-Rebuild Context

## Current Working Checkpoint - 2026-08-21

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
animate from one identity layer. Fresh Bell-Eater frames are in
`Development_Gallery/screenshots/`. The encounter is readable but still uses
an interim low-poly monster mapping; this is a development checkpoint, not a
final visual approval or production release.

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
