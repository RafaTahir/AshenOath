# Living Cast - Remaining Pipeline Implementation

Date: 2026-10-22. Source baseline: e8d92627bec50fa7bd8121f892ce4af212fcca2c.
Request: implement remaining pipeline work. Build-only; user owns runtime review.

## Scope And Status

WORLD-SAGA/Living Road quest, relationship, preparation and aftermath source work
was retained. This delivery fills the outstanding Living Cast implementation
instead of reopening those features. All 51 quests, rewards, earned choices,
four endings and homecoming remain under their existing authorities.

The earlier Greyfen sample review has not been fabricated or silently accepted.
The latest request authorizes wider implementation; all visual/behavioral
acceptance remains pending. CAST user acceptance remains **0/10**.

| Owner | Added implementation |
|---|---|
| CAST-001/002 | Eleven actual weighted face controls in eight retained human assemblies and the composed Ranger head; compile-time required-control and texture checks |
| CAST-003 | Shared head attention, inherited expression controls, additive work/carry performance, retained approved-audio-only speech |
| CAST-004 | Authored work, errand, dusk social and night rest assignments using the existing clock, spatial contract and life controller |
| CAST-005 | Registered local audible-cue reactions; civilian safe-route shelter and guard-role watch responses; protected dialogue remains higher priority |
| CAST-006 | Eight co-present regional exchanges, public-outcome variants and existing witnessed-memory acknowledgements; no new affection authority |
| CAST-007 | Bounded sound investigation through existing navigation/leashes; sound alone does not create attack knowledge |
| CAST-008 | Retained-body head/spine/wing idle and recovery characterization for the six bosses, subordinate to attacks |
| CAST-009 | Six-world cast integration, outcome-sensitive work and transfer of the existing rescued mill workers to routine ownership |
| CAST-010 | Necessary asset compilation and one combined production package; publication and user acceptance recorded separately |

## Ownership And Compatibility

- No new quest, actor, encounter or save IDs replace existing ones. Routine
  position, temporary mood and blink state are derived rather than serialized.
- Hidden/departed people are not recreated for a social scene. Mill workers are
  the two existing bodies, not a new Dain plus duplicate workers. Their escort
  owner retains control until the actual rescue and Ashwing outcome permit work.
- Motion uses the retained skeleton's visible forward axis, including imported
  half-turns. A carried prop does not switch walking back to an idle animation.
- Work points use existing reservations and navigation. Interruptions release
  props/stations; quest interactions move with their actual actor through the
  existing interaction-position notifications.
- Native Ranger facial compilation preserves body geometry, original materials,
  skin topology and locomotion bones; only head-layer skin influences gain
  facial bindings. All other human assemblies are rebuilt from retained source
  layers and unchanged atlas pixels. No replacement heads or detached eyes.
- Detailed poses/attention use existing close-actor budgets. No population,
  scenery, quality preset, attack damage, phase timing or peaceful outcome is
  removed or reduced to obtain a performance claim.
- Audio perception reuses actual spatial cue positions. No fabricated speech,
  remote private-event knowledge, autonomous civilian deaths or new crime system.

## Build And Delivery

Candidate: `cast-complete-20261022`.
Asset/prepared-scene/production compilation: completed without ERROR/parser
diagnostics after the recorded build corrections.
Aggregate package: **104832999 bytes**, including the manifest; 17 files;
**24601 bytes below** the strict 104857600-byte limit.
Root PCK SHA-256: `07b7f2f6e4d5fc51ce1cd25a7f30ffdba69910af5843d629d40664dfb3bb3ffe`.
Publication: authorized through the existing CAST-010 workflow. Its publication
receipt under `.release-gate/living-road/CAST-010-*/publication.json` owns the
resulting commit and deployment status; no user acceptance is implied.
Build logs: `.release-gate/cast-complete-20261022/logs/`.

Build corrections: Ranger head layers are identified by their actual composition
owner, not guessed mesh names. Reconstructed surfaces preserve the imported
custom-channel format and surface names; a missing surface fails compilation.
The production wrapper rejects Godot's native `ERROR:` diagnostics even when the
tool process returns zero. The superseded partial export was not published.
This follows the [ArrayMesh format contract](https://docs.godotengine.org/en/4.6/classes/class_arraymesh.html#class-arraymesh-method-add-surface-from-arrays),
not a change to authored textures or facial geometry.
The corrected Ranger material descriptors match the retained catalogue: no eye,
brow or body texture binding was removed. The prepared-actor tool emits an
ObjectDB shutdown warning; this is recorded as a build-tool warning, not evidence
of a clean runtime lifecycle. Runtime resource behavior remains user-unverified.

No game, browser, gameplay automation, screenshots, benchmark or profiling is
authorized or performed for this delivery. Compilation is not runtime proof.
Historical strict reference-PC performance failures remain unresolved; this work
does not establish numerical performance compliance or a finished-game claim.

## User Checks

1. New Game and selected Continue: complete Kael/NPC bodies, expected colours,
   connected eyes/lids/neck and retained wardrobe/equipment in light and shadow.
2. Eight-direction movement, aim, draw/sheath and conversation: facial/work
   modifiers must release without changing established action poses or controls.
3. Watch a full work/errand/rest cycle; interrupt it with Use and danger, then
   leave. Check held props, station exclusivity, safe routes and reachable people.
4. Compare each world's legitimate before/after work and social exchange. Include
   rescued mill workers, Senn testimony, Odran departure and late Hartlands access.
5. Observe monster investigation/search/return and each boss's anticipation and
   recovery. Check current telegraphs, phases, checkpoints and peaceful outcomes.
6. Save/Continue a genuine consequence, compare private/public acknowledgements,
   and check desktop/actual-phone startup, input, audio and responsiveness.
