# Grounded NPC behavior: cloud development increment

The goal is purposeful daily life with readable interruptions and believable
movement. AshenOath already has authored day/night jobs, workstations, finite
social scenes, story-dependent routines, line-of-sight reactions, bounded turning
and walking acceleration. This change improves how those systems cooperate;
it does not add a second scheduler or replace authored behavior.

## Player-facing changes

- **Brief acknowledgement, then back to work.** Approaching someone starts one
  1.2-second acknowledgement. Remaining nearby no longer resets it each frame.
  Workers retain their activity progress, workstation reservation and route;
  workstation animation binding resumes afterward. Leaving beyond the existing
  3.4-metre rearm distance permits another acknowledgement.
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

`GreyfenLifeController.awareness_changed(actor_id, reaction)` reports reaction
transitions; an empty reaction reports completion. No new gameplay listener is
connected. All new attention/cooldown/route bookkeeping is transient. Save
version, quest flags, relationships, authored activity lengths, movement speeds,
combat values, animations and assets remain compatible.

## Design reference and research boundary

RDR2 and The Witcher 3 are the user's requested references for believable people
with jobs, contextual reactions and movement. Their exact internal algorithms
are not asserted here. Fresh authoritative research was attempted, but this
environment's HTTPS proxy denied the requests with a CONNECT-tunnel
`403 Forbidden`. No source text was retrieved from these unverified leads:

- Rockstar RDR2 features: https://www.rockstargames.com/reddeadredemption2/features
- Official Witcher 3 page: https://www.thewitcher.com/us/en/witcher3
- GDC Vault search: https://gdcvault.com/search.php#&keyword=witcher

The implementation is original AshenOath behavior. No proprietary assets,
dialogue or code were copied. Source-backed comparisons still require approved
access to authoritative material. This increment does not claim either game's
simulation depth, animation quality or production performance.

## Validation and cost

Run from this project directory after activating the cloud toolchain:

```sh
source /workspace/ashen-oath-cloud/activate.sh
godot --headless --path . --script tools/verify_npc_attention_movement.gd
godot --headless --path . --script tools/verify_npc_awareness.gd
godot --headless --path . --script tools/verify_greyfen_routine_ownership.gd
godot --headless --path . --script tools/verify_boundaries.gd
python3 tools/verify_content_integrity.py
```

Godot 4.6.3 results:

| Check | Result |
| --- | --- |
| Attention/movement | Pass: 27 checks, zero engine/script errors |
| Awareness priority, cooldown, expiry, ownership, escape planning and threat focus | Pass: 25 checks, zero engine/script errors |
| Existing regional routine ownership | Pass: 137 checks |
| Actual Greyfen -> Wychwood -> return, player control, five enemies, current/version-12 saves and shutdown | Pass: 15,492 checks, zero failures, engine errors or warnings |
| Content integrity | Pass: 21 quests, 84 objectives, 117 dialogue actions, 54 runtime references |

Movement tests translate real Node3D actors across fixed ticks, including a
successful pass, closed passage, swept collision, repeated hovering, retained
work progress and protected poses. Small fixtures isolate decisions; the full
boundary verifier separately exercises actual scenes and save restoration.

The existing local crowd index and staggered sensing budget remain in use.
Player clearance is a constant-cost analytic check with no extra physics scan;
sidesteps keep the existing retry delay and now validate their final leg. There
are no new all-actor scans, assets, dependencies or persistent services.

The development workflow forbids routine Web export/screenshots/deployment at
this stage. No new Web artifact was generated or size/performance certification
claimed. Rendered motion, crowded-scene frame rates and browser acceptance still
need their normal review. The source change adds no art/audio payload and keeps
the previously established packaging configuration.
