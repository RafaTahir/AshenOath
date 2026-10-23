# Living Cast - Interaction and Resource Efficiency

Date: 2026-10-23. Source baseline: 64ad7fd60d0d99a10d2878aa023df84d2f3c47d6.
Existing CAST/OPT owners; no replacement ticket program. Build-only delivery.

## Implemented

1. Work-pose IK propagates upper/lower arm rotations analytically rather than
   forcing four complete skeleton refreshes for two arms. The forge wrist uses
   the retained hammer-head position to orient its contact with the anvil.
2. Facial attention uses camera-frustum/distance budgets, with full conversation
   updates, and avoids unchanged face-bone writes. Bodies and locomotion remain.
3. NPC movement uses initial-overlap validation plus a continuous capsule sweep.
   Authored river, bridge and exclusion validation still applies. Civilian threat
   perception queries the existing enemy spatial index instead of every enemy.
4. Regional work binds standing, facing and hand goals to retained forge/work
   geometry when that geometry exists and a safe approach is available. Optional
   quest stations are not manufactured before the quest makes them available.
5. Forge/page cues follow actual work cycles. The ambient soundscape no longer
   plays unrelated random forge blows. Interrupted work stops producing cues.
6. Eight authored regional exchanges and the existing forge exchange use timed
   individual turns, speaker/listener gestures and approved-audio-only playback.
   Proximity, danger, dialogue and zone retirement interrupt an exchange and
   release its ownership, voices and poses without changing quest progress.
7. Existing CharacterPresence owns claim/release and interruption callbacks for
   social, work and dialogue. Higher-priority actions clean up the lower owner
   before acquiring the body; a former owner cannot release another owner's pose.
8. Latest relationship acknowledgements are greeted once per earned event.
   Existing StoryState flags preserve that greeting history in normal saves;
   explicit relationship dialogue/history remains available and no reward changes.
9. Monsters use nearby retained deadfalls, trees, supplies, clues and watch points
   rather than invented circular patrol destinations. Existing leashes, attack
   authority, population and damage remain. No suitable point means watch/rest.
10. Prepared geometry cache references follow the existing active/cached-zone
    ownership policy. Live scene resources are never detached by cache eviction.

## Delivery State

Implementation: complete, static diff reviewed.
Compilation/package: complete. Godot asset/core/production compilation and static
package identity checks completed without ERROR/parser diagnostics.
Complete deployment: **104841634 bytes**, 17 files including the manifest;
**15966 bytes below** 104857600. Root PCK SHA-256:
`b32c4fa85caa90c734733e67243d845bffbc6d05c27289312b870fc40bc1ed90`.
The final core was recompiled after static review guarded missing ownership
metadata; asset packs from this same build were retained. No runtime retry occurred.
Publication: authorized through existing CAST-010; its publication receipt records
the resulting commit/push/deployment independently of user acceptance.
User/runtime acceptance: pending. No game, browser, screenshot, test, benchmark or
profiling run was performed. No measured loading, FPS or memory gain is claimed.
CAST acceptance remains 0/10; strict reference-PC performance is unverified.

Build directory: .release-gate/cast-efficiency-20261023/.
Candidate: cast-efficiency-20261023.
The build manifest and CAST-010 publication receipt own exact bytes and hashes.

## User Checklist

1. Cold/warm New Game and selected Continue: complete world, bodies, textures,
   working menu, camera, movement and bridges at first control.
2. Watch Tor's hammer/anvil and a regional work station. Compare hand/tool contact
   and sound timing; interrupt with conversation or danger and allow work to resume.
3. Overhear a nearby exchange, approach/Use either person, then leave. Check one
   subtitle speaker at a time, natural turn taking, released props and quest access.
4. Earn a relationship acknowledgement, hear it, save/reload and approach again.
   Check later work greetings and deliberate relationship topics remain available.
5. Observe monsters before detection and after losing sight: nearby destinations,
   obstacle safety, unchanged combat/peaceful outcomes and no repeated rewards.
6. Return across several zones and compare responsiveness/memory using the existing
   controls. Check actual-phone play separately. Gains require your measurements.
