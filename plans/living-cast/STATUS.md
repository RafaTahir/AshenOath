# Living Cast - Current Checkpoint

## Role Silhouette Delivery - 2026-10-27

CAST-001/002/009/010 source extension: anatomical shoulder/head/torso ratios,
six idle postures and fitted retained-library role shapes replace random width
variation. Six regional palettes and 27 unique named accents are data-owned.
Kael/Anwen faces/atlases, Ranger identity, monster bodies, collision and saves
remain retained. The mask verifier is authored for user execution, not run.
Implementation/build/publication status is recorded in the latest CAST-010
publication receipt; no new visual, gameplay or performance acceptance is
claimed. Formal cast acceptance remains 0/10.

Scope and user checks: `outputs/AshenOathTheRoadBetweenCrowns/assets/characters/silhouette/README.md`.

Current delivery candidate: `role-silhouette-20261027-integrated`, built after a
clean fast-forward to GitHub main `40b3215` (normal-texture correction and Phase 1
game/HUD extraction), preserving the silhouette work. All 31 service/HUD/character
modules are present in the root export. Complete package: 107,980,319 bytes (103.0
MiB); root transport SHA-256:
`2dbabb1aabdb0eb3d36e1e0d1e851783186bd300bbeb8c060479335cd4517f03`.
The earlier candidate below was not published because the release guard detected
the newer main commits. The integrated package supersedes it; the CAST-010
receipt records actual push, staged promotion and HTTP file-identity results.

Earlier candidate `role-silhouette-20261027`: required asset import, script compilation,
eight content-pack exports and production Web export completed. Package integrity
checks cover all 17 files: 107,807,868 bytes (102.8 MiB), below the 256 MiB ceiling.
Root transport SHA-256: `443355b034ce4534d2a3c8f81c49ef55858a3d882d0eab69a310ebd9be149b76`.
An initial type-inference compilation error was corrected. The first pack build
was interrupted for a source-confirmed off-tree skeleton setup correction;
the final pack set was then built from the corrected source. No masks,
screenshots, game/browser runs or benchmarks were executed. Publication completion
is owned by the CAST-010 receipt, not by this implementation record.

## Current Combined Delivery - 2026-10-26

The user authorizes the existing facial technique without an intermediate sample
approval and authorizes development/publication of the three original music
sketches. The eight retained human assemblies and Ranger facial bindings already
exist and are preserved, not re-created. The combined FINISH implementation adds
animation-clock reconciliation, full dialogue-policy restoration and cancellation
of abandoned boss-strike clock ownership. The new exploration/tension/combat
arrangements use the existing mixer and streamed Vorbis; original PCM masters
remain in source. No listening, visual, gameplay or performance acceptance is
claimed. Candidate and exact publication: FINISH-000 and the latest FINISH-016
receipt. Formal cast acceptance remains 0/10. Earlier sample holds below are
historical and do not impose another pre-publication approval gate.

2026-10-25 audio-routing repair: the user authorized focused runtime diagnosis.
[Cause, fix and measured output](AUDIO_ROUTING_REPAIR_20261025.md).
Candidate `audio-routing-20261025` is implemented, compiled and packaged.
Godot Web's dynamic bus append path reordered browser buses and disconnected
Master from the output; increasing bus count instead preserves routing.
Actual browser-session Windows peaks: 0.005226 after New Game, 0 while paused,
0.005751 after Resume. These are signal measurements, not subjective listening
approval or a full campaign test. All seven external content packs are unchanged.
Complete package: **104672481 bytes**, **185119 bytes below** the strict cap.
Root PCK: `41b2ead71671f755724901567a60aa9ceb670ab5351a6cffe8a3d90601ad4206`.
Publication completion is owned by the current CAST-010 receipt. Phone/WebKit
and subjective mix balance remain user-owned; formal cast acceptance is unchanged.
The earlier recovery-only diagnosis below is retained as history, not current cause.

## Previous Audio Recovery Attempt

2026-10-24 audio-startup repair: implemented, compiled and packaged as
`audio-recovery-20261024`. No runtime/listening test is authorized or claimed.
The synchronized production package contains 17 files, **104817107 bytes**,
**40493 bytes below** the cap. Root PCK SHA-256:
`aa048d0dff392ccc4008ee024520e691429a4f8a6cd2bbfeee017cf33ac04a10`.
Build logs: `.release-gate/audio-recovery-20261024/logs/`. Actual commit, push and
deployment completion are owned by the current CAST-010 publication receipt
under `.release-gate/living-road/`, not by a runtime acceptance claim.
The user reports all desktop-browser sound absent despite enabled volumes and
an unmuted site. Static inspection confirms the current PCK directories contain
menu music/UI and opening footsteps/combat streams; it does not prove playback.

- Observe the actual Godot WebAudio context during initialization only. Trusted
  game input resumes a suspended context; a conditional Enable sound/Retry sound
  control reports suspension or required resource failures without a launch gate.
- Bind audio pack availability during menu service configuration and reconcile
  already-mounted packs, instead of relying on a later gameplay-only signal.
- Retain failed music requests for recovery; retry null ambience after packs
  arrive. Preserve loaded resources, active voices, pause ownership and saved mix.
- Report the exact missing/unloadable prepared sound once per fault, permit retry,
  and expose current context/error/mute state in the existing browser shell.

The specific cause in the user's session remains unverified. These changes repair
source-level recovery gaps; they are not a claim that audible playback passed.
User checklist: cold launch and a real click/key; hear menu cues/music and gameplay
steps/combat; Enable sound if shown; switch tabs then Resume; mute/unmute saved
volumes; Continue/zone return without missing ambience or interrupted speech.
Formal Living Cast acceptance remains **0/10**.

## Previous Published Candidate

2026-10-24 current work: **People, Place And Honor** implemented and compiled;
the combined production package is synchronized to `web/`. User acceptance is
still **0/10**; no new runtime test is authorized or claimed.
Current scope, scene map, Honor rules and user checklist:
[People, Place And Honor](../living-road/PEOPLE_PLACE_HONOR_IMPLEMENTATION.md).
The bow and actor-presence baseline below is preserved history, not the current
next-action instruction. New candidate: `people-place-honor-20261024`.
Complete package: **104808755 bytes**, 17 files, **48845 bytes below** the cap.
Root PCK: `b1a85adb63345dd5f60d218a246d0a1c6db1a28cee3364b086a83edf0ee1de6e`.
Publication completion/commit/live identity belong to the current CAST-010
receipt under `.release-gate/living-road/`, not to a runtime acceptance claim.

## Previous Published Baseline

Stage: bow experience implemented, compiled and packaged; CAST-010 publication.
Formal user acceptance: **0/10**. Bow runtime appearance/input is unverified;
no gameplay/browser check was run for this change. The prior actor-presence
check identified the shared enemy parser failure, not a post-fix runtime pass.
Current change and manual checks: [bow experience](BOW_EXPERIENCE.md).
Retained repair/evidence: [actor presence](ACTOR_PRESENCE_REPAIR.md).
Current implementation and checklist: [interaction/resource efficiency](INTERACTION_EFFICIENCY_IMPLEMENTATION.md).
Retained six-world rollout: [rollout](ROLLOUT_IMPLEMENTATION.md).
Current candidate: `bow-experience-20261023`; **104855895 bytes**, 17 files,
1705 bytes below the cap. Root PCK SHA-256:
`68afa4234867988914ba0ff3c68077ac42acb806d02eb8c7fad4e51b47503c5f`.
Production packaging and demand-loaded enemy compilation succeeded. Runtime
check: partial/failed on the original parser error, not a post-fix pass.
Publication ownership: current CAST-010 receipt under `.release-gate/living-road/`.
The receipt records actual commit/push/deployment completion, not acceptance.
Strict performance is not established by this work.

2026-10-22: [A World Worth Caring About](../living-road/WORLD_WORTH_CARING_IMPLEMENTATION.md)
extends existing regional occupational/reaction presentation, remembered help,
dialogue ownership and bounded monster/boss habits without changing more rigs.
Those source changes are not user-accepted; their published baseline remains
recorded in that delivery note and receipt. The historical sample below is retained
as history; its old next-action instruction is superseded by the current rollout.

## Implemented Reference

- Named-core/saga intent profiles separate from wardrobe; protected dialogue,
  work and combat presentation priorities.
- Eleven weighted facial controls in Anwen, male villager and worker/Tor
  source assemblies, using retained atlas pixels and mesh topology. Real eyelid,
  eye, brow, mouth and jaw controls; truthful unrigged capability reporting.
- Blended emotional head/face performance and approved-audio speech ownership.
- Distinct close work/care/reading/rope/forge hand goals, a bone-held forge hammer,
  work-point reservations and interruption cleanup in existing Greyfen routines.
- Greyfen approach/threat reactions, shared notice cooldowns, safe-route shelter
  movement for moving civilians, and bounded worker-to-worker attention.
- Relationship-event mood reuse and public-only ambient evidence knowledge.
- Existing Ghoulkin-family patrol, scavenging/watch, search and return behavior
  between combat phases; existing encounter and attack authority preserved.
- Nessa/Jory enrolled in the existing ambient presentation in Greyfen.

## Build And Publication

Asset compilation: eleven weighted controls compiled for each reference assembly.
Godot import, prepared actors and production Web export: Completed without reported
compiler/parser errors. Shared locomotion resources retain their existing binding;
two unused generated library copies were preserved under D:/Temp/AshenOath rather
than shipped. No texture pixels or gameplay population were removed.
Candidate: cast-greyfen-v1-20261021.
Package: 17 files, **104745044 bytes** including release_manifest.json; 112556 bytes
below the strict cap. Artifact payload excluding manifest: 104736997 bytes.
Root PCK SHA-256: 01bddc1392926c858e391b99cbeaee166b01b25a605e2847df867a7deed76a3c.
Source baseline: a69c342 plus the recorded working changes. Publication receipt
binds the resulting source commit and deployed site to this package.
Commit/deployment: owned by the CAST-010 receipt under .release-gate/living-road/.
Runtime/user acceptance, phone behavior and performance: UNVERIFIED.

Build logs: D:/Temp/AshenOath/cast-sample-import-final.log,
cast-prepared-shared-build.log, cast-base-final-build.log and
cast-production-build.log. External pack/candidate manifests and exact Web output
are retained under .release-gate/cast-greyfen-v1-20261021/.

## User Reference Checklist

1. Start normally and Continue an earned journey. Check complete Greyfen, Kael,
   Anwen/Tor/villager body colours, equipment and connected anatomy.
2. Watch Anwen's eyes/eyelids and expression from conversation distance; advance,
   interrupt and return. Check restrained listening and no silent mouth flapping.
3. Watch the forge and another work station. Interrupt/release it, wait for work
   to resume, and check hands/tools remain connected and stations are not shared.
4. Approach armed/unarmed, walk behind someone, and cause/leave danger. Check
   cooldowns, legal shelter movement and reachable quest speakers.
5. Check private evidence remains private; compare a genuinely remembered
   promise/help event through Save/Continue. Listen/read a nearby social exchange.
6. Observe the first Wychwood Ghoulkin family before detection, during combat and
   after breaking sight. Confirm retained counterplay, rewards and persistence.
7. Compare desktop and actual-phone interaction/startup/responsiveness. No agent
   measurement, runtime acceptance or claimed frame-rate improvement is implied.

## Exact Next Action

Complete publication through the existing CAST-010 receipt, then obtain the
user's third-/first-person bow review and retained Wychwood/NPC/Hart review.
No additional agent runtime test is authorized.

