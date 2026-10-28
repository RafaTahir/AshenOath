# Grounded NPC behavior: cloud integration

The goal is purposeful daily life with readable interruptions and believable
movement. AshenOath already has authored day/night jobs, workstations, finite
social scenes, story-dependent routines, line-of-sight reactions, bounded turning
and walking acceleration. This change improves how those systems cooperate;
it does not add a second scheduler or replace authored behavior. The integration
combines main `31a09063e52a900b0508a0316dfe04a7739c707a` with the NPC branch
`f78744eaa8fdee87a64b80803262847d2d3738e6`.

## Player-facing changes

- **One animated greeting, then back to work.** Main's greeting system remains
  authoritative: the existing four-metre sight check, 4.6-metre rearm distance,
  sixty-second cooldown and bounded turn/greeting action remain unchanged.
  Remaining nearby cannot continually restart the greeting. Workers retain
  activity progress, workstation reservation and route, then resume the
  existing workstation pose. Sleeping actors do not greet. The cloud branch's
  older proximity-pause timer is removed rather than layered onto this system.
- **Attention and personal space are separate.** An off-route player can stand
  near a working or walking NPC. A player in the route receives right of way.
  The existing sidestep planner now considers that obstruction and validates
  all three legs, including its connection back to the route. If there is no
  safe passage, the NPC waits rather than moving through the player or a wall.
  A swept planar clearance check also covers braking and scripted walking,
  including large steps; existing overlaps may separate without teleporting.
- **Fewer false obstructions.** Hidden actors/presentations are ignored by crowd
  pacing. Player clearance ignores clearly separate floors, using body-height
  metadata with tolerance for different actor-root conventions.
- **Danger takes priority.** An ordinary sound cannot replace fear/anger or
  weapon suspicion. Ordinary sound reactions have a per-actor six-second
  cooldown, so repeated cues cannot continually restart the distraction. Real
  danger bypasses that cooldown. Sight reactions focus the observed threat,
  including an enemy, rather than always focusing Kael.
- **Recover and resume.** Expired reactions release their presentation and
  rebuild travel from the actor's actual position, even without a face driver.
  Escape plans are invalidated when the threat moves away from the observation
  used to choose that plan, including cumulative small movements.
- **Respect authored ownership.** Dialogue, work scenes and scripted escorts
  retain control of their poses and movement. Awareness cleanup waits until
  ownership returns. Weapon contact still records its existing grievance,
  warning and save request, without replacing a scripted escort pose.
- **Scripted motion follows the body.** Ambient scene walks and retreats use
  the actor's visible forward direction, as routine walking already does.
  Sharp turns brake along the last achieved movement before rotating. Final
  arrivals decelerate toward the existing arrival radius instead of stopping
  abruptly. Authored destinations, speed caps and intermediate route points
  remain unchanged.
- **Ambient scenes yield to escorts.** A scene cannot claim an actor whose
  movement is already owned elsewhere. If an escort takes over during a scene,
  the ambient scene releases its own state without clearing the new pose or
  advancing the completed-beat checkpoint. It can resume that checkpoint when
  the actor becomes available again. Interrupted ambient audio stops without
  resetting the new owner's mouth animation; ordinary speech stops retain
  their existing face reset.

Main's physics-based update loop, minute-based intent scheduling, animation
graph, props, and workstation restoration remain intact. A later dialogue,
work or escort owner cancels this controller's greeting bookkeeping without
clearing that owner's action or focus. Social eligibility retains both main's
sleep/greeting exclusions and the cloud branch's foreign-movement exclusion.

`GreyfenLifeController.awareness_changed(actor_id, reaction)` reports reaction
transitions; an empty reaction reports completion. No new gameplay listener is
connected. All new attention/cooldown/route bookkeeping is transient. Save
version, quest flags, relationships, authored activity lengths, movement speeds,
combat values, animations and assets remain compatible.

## Design reference and research boundary

RDR2 and The Witcher 3 are the user's requested references for believable people
with jobs, contextual reactions and movement. The coordinating task supplied
these primary references and descriptions on 2026-10-28:

- CD PROJEKT RED, Witcher 3 REDkit documentation, described in the handoff as
  scripted NPC actions and movement:
  https://cdprojektred.atlassian.net/wiki/spaces/W3REDkit/pages/1189085185
- Rockstar developer presentation, *Making the Believable Horses of Red Dead
  Redemption II* (GDC 2021):
  https://media.gdcvault.com/GDC%2B2021/making_horses_gdc2021.pdf

Both direct requests from this cloud environment failed with HTTPS proxy
`Tunnel connection failed: 403 Forbidden`. No document body, PDF pages or
quotable technical excerpts were retrieved here. The source subjects above
come from the handoff; they are not claims of independent document inspection.
The horse presentation is an animation/movement reference, not evidence for
Rockstar's human NPC schedules, perception, navigation or decision architecture.

The practical comparison is therefore with AshenOath's inspected implementation:

| Reference subject / intended player experience | Existing AshenOath support | Concrete gap addressed |
| --- | --- | --- |
| Scripted actions and movement; characters finish purposeful tasks | Authored workstations, daily routines, finite social scenes and persisted completed beats | A nearby player could indefinitely interrupt work; a scene could compete with an escort's later motion claim |
| Believable motion; the body visibly leads a turn and settles at a destination | Bounded yaw, acceleration, braking, achieved-velocity animation input and chest-forward routine walking | Scripted walks/retreats still translated sideways, retained stale braking direction and stopped abruptly at arrival |
| Context-sensitive reactions, requested as a general NPC goal | Existing sight/sound reactions, priorities and authored safe destinations | Ordinary sounds could replace danger; repeated distractions could prevent resumption |

These are original fixes derived from observable code paths and runtime tests,
not reconstructions of either game's implementation. More elaborate activity
chains, authored gait/turn clips, terrain adaptation or motion matching remain
research candidates. They are not implemented or promised by this increment;
they would need verified source details, suitable licensed assets and measured
budget on AshenOath's target hardware.

Earlier general research requests were also proxy-blocked:

- Rockstar RDR2 features: https://www.rockstargames.com/reddeadredemption2/features
- Official Witcher 3 page: https://www.thewitcher.com/us/en/witcher3
- GDC Vault search: https://gdcvault.com/search.php#&keyword=witcher

No proprietary assets, dialogue or code were copied. Detailed source-backed
comparisons still require access to the documents. This increment does not claim
either game's simulation depth, animation quality or production performance.

## Validation and cost

Run from this project directory after activating the cloud toolchain:

```sh
source /workspace/ashen-oath-cloud/activate.sh
godot --headless --path . --script tools/verify_npc_attention_movement.gd
godot --headless --path . --script tools/verify_npc_awareness.gd
godot --headless --path . --script tools/verify_npc_scene_ownership.gd
godot --headless --path . --script tools/verify_greyfen_routine_ownership.gd
godot --headless --path . --script tools/verify_boundaries.gd
python3 tools/verify_content_integrity.py
```

### Integration result, 2026-10-28

The three controller conflicts are resolved on `codex/cloud-npc-integration`.
Main's newer greeting, schedule, physics and animation contracts are retained.
The test fixtures now disable both automatic processing callbacks and implement
the current driver/host interfaces. Assertions cover main's authored greeting
and minute transitions instead of the removed cloud attention timer.

| Combined-source check | Result |
| --- | --- |
| Controller and four focused verifier parsers | Pass |
| Movement, animated greetings, sleep, held work/prop resumption | Pass: 67 checks |
| Awareness and recovery | Pass: 25 checks |
| Scene ownership, protected poses, audio and save checkpoint | Pass: 21 checks |
| Regional ownership and work/meal/sleep minute transitions | Pass: 261 checks |
| Content integrity | Pass: 21 quests, 86 objectives, 117 dialogue actions, 54 runtime references |
| Combined architecture + Greyfen/Wychwood/return + current/version-12 save checks | **Fail: 2 of 16,102 checks**, both existing ancestor-lookups in main's `scripts/systems/character_silhouette.gd:74` and `:247`; zero engine/script error types or warnings |

The silhouette script is byte-for-byte unchanged from main `31a09063`.
Its direct skeleton-parent access and ancestor-transform walk violate the
existing extracted-system boundary rule. Neither the implementation nor the
assertion was altered to make integration appear green. Route and save checks
completed; the aggregate gate remains failed and blocks the main merge.

The first combined run also encountered missing import caches for main's new
silhouette meshes. A normal Godot editor import successfully imported ten
existing OBJ sources. The necessary rerun removed all resource/runtime errors;
only the two source-boundary failures remain. No art source was changed.
Logs are retained under `.release-gate/npc-integration-*.log`; the final combined
run is `npc-integration-boundaries-imported.log`.

The GitHub check-run request for main returned `Forbidden` from this environment.
The coordinating task separately reported successful Vercel statuses on both
input tips; those are deployment statuses, not test results for this integration.
No required-check policy or successful remote integration test run is claimed.
Main remains unmodified pending those checks and resolution of the boundary gate.

Committed `web/` and hosting configuration are unchanged from main. Its Web tree
is `e61bf8348ee8dbe3dc772329638ff74cdf821eaf`; no export or separate production
deployment was performed. The main deployment policy allows Git merges to
trigger Vercel, but its static build does not compile these source changes.

Godot 4.6.3 results on the original NPC tip `f78744ea` (before integration):

| Check | Result |
| --- | --- |
| Attention/movement, including scripted turns, braking and arrival | Pass: 56 checks, zero engine/script errors |
| Awareness priority, cooldown, expiry, ownership, escape planning and threat focus | Pass: 25 checks, zero engine/script errors |
| Scene takeover, real audio cleanup and unchanged/resumable checkpoints | Pass: 18 checks, zero engine/script errors |
| Existing regional routine ownership | Pass: 137 checks |
| Actual Greyfen -> Wychwood -> return, player control, five enemies and current/version-12 saves | Pass: 15,492 checks, zero failures or captured engine errors; shutdown caveat below |
| Content integrity | Pass: 21 quests, 84 objectives, 117 dialogue actions, 54 runtime references |

Movement tests translate real Node3D actors across fixed ticks, including a
successful pass, closed passage, swept collision, repeated hovering, retained
work progress and protected poses. Small fixtures isolate decisions; the full
boundary verifier separately exercises actual scenes and save restoration.
Scripted movement fixtures executed 809 steps with 603 spatial validations,
at most one validation per step. Scene interruption tests use the actual audio
manager and verify that cleanup releases voice resources while leaving the new
owner's face output and saved checkpoint intact.

The first follow-up boundary run emitted `ObjectDB instances leaked at exit`
after its passing summary (the logger had already been removed). One isolated
verbose diagnostic rerun also passed all 15,492 checks and did not reproduce
that warning; verbose shutdown listed orphan skeleton-related StringNames.
The intermittent leak warning has not been attributed or fixed. Do not treat
the captured `warnings=0` summary as proof that shutdown was warning-free.
Evidence is retained in `.release-gate/npc-followup-boundaries.log` and
`.release-gate/npc-followup-boundaries-diagnostic.log` in this workspace.

The existing local crowd index and staggered sensing budget remain in use.
Player clearance is a constant-cost analytic check with no extra physics scan;
sidesteps keep the existing retry delay and now validate their final leg. There
are no new all-actor scans, assets, dependencies or persistent services.

The development workflow forbids routine Web export/screenshots/deployment at
this stage. No new Web artifact was generated or size/performance certification
claimed. Rendered motion, crowded-scene frame rates and browser acceptance still
need their normal review. The source change adds no art/audio payload and keeps
the previously established packaging configuration.
