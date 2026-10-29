# FINISH-003 - Movement, Camera And Character Integrity

## Face Artifact Rear-View Correction - 2026-10-29

Rafa's new screenshot rejects the retained rear hood shell and added mantle.
The prior front-opening repair was insufficient; its historical evidence below
is not current appearance approval. Clerics now use their native clothing and
existing staff without either added shape. Anwen's original A-set head/hair,
body, colours, proportions and animation remain; the pilgrim retains its native
body. Other roles' cloak/mantle recipes are unchanged.

Silhouette reconfiguration removes only obsolete silhouette-owned attachments,
preventing retained assemblies from keeping these retired shapes. The existing
capture checks initial absence and removal of stale hood/mantle nodes, then
captures front, side, back and rear-quarter views in neutral, blink, speech,
gaze and walking states. The isolated native run passes; inspected rear views
show native hair/clothing without the reported shell/cape. No new browser or
campaign run is needed for this bounded layer-removal check.

Candidate `cleric-rear-cleanup-20261029` compiled through the existing base/root
export path; seven unchanged packs reused. Package hash/size checks pass at
162,882,438 bytes including the manifest, below 256 MiB. Publication and final
package identity belong to its FINISH-003 receipt and linked evidence. User acceptance remains pending;
this correction does not begin SOLID-FURNITURE or establish phone/performance
acceptance.

[Rear-view correction evidence](../../outputs/AshenOathTheRoadBetweenCrowns/release_reports/cleric_rear_cleanup_20261029.json).

## Director Child: Face Artifact - 2026-10-29

The confirmed GAME defect is the added cleric hood, not missing native anatomy.
Anwen and the care-route `shrine_pilgrim` recipe reproduce a closed cloth shell
over intact faces. Hiding only `SilhouetteEquipment_hood` reveals those faces;
rotating it does not fix the closed mesh. The originally unnamed second actor
remains inferred, not independently matched to an unavailable user image.

The retained Monk-derived hood now has an open face/hairline and fitted crown.
Original faces, hair, skins, rigs, clips, colours, mantle and staff are unchanged.
The compiler and provenance retain that repair. Paired front/side native captures
cover neutral, blink, speech, gaze and walking on both affected role recipes.
Final-package normal-input browser New Game, care-area movement and Anwen
dialogue show her face, with no console warnings/errors. Controller/viewport
interruptions recovered on the same tab; no campaign restart or extra candidate.

Candidate `face-artifact-20261029`: compilation and package integrity pass.
Complete directory including manifest: 162,882,017 bytes / 155.34 MiB. Opening
was rebuilt, seven unchanged content packs reused. Publication is owned by the
FINISH-003 Git receipt; no Vercel waiting. Status: implementation/targeted checks
complete for the confirmed hood defect; user acceptance pending. Furniture,
targeting and approach-dependent camera crowding remain separate obligations.
This is not all-cast, all-lighting, phone, performance or whole-ticket acceptance.

[Bounded evidence](../../outputs/AshenOathTheRoadBetweenCrowns/release_reports/face_artifact_20261029.json).

## Director Child: Animation Lifecycle - 2026-10-29

Bounded source repair: complete; compilation: passed; targeted developer checks:
passed at the scope below; user acceptance: pending. Candidate
`animation-lifecycle-20261029`, 162,882,616 bytes / 155.34 MiB. The FINISH-003 Git
receipt owns push status; no Vercel waiting/manual deployment is authorized.

Required idle/walk/run clips now bind real actor bones before a driver is valid.
Configuration failure retires its graph and timer; duplicate skeleton owners are
rejected. Named/routine factories propagate failure, and player/enemy/Hart witness
owners register weak, destination-bound references. Existing readiness, Retry and
rollback paths reject failed actors instead of allowing moving bind poses.
Cached activation reconciles clocks without resetting valid playback or death
state. No AnimationTree replacement, raw asset/skin edits or new clips.

Clock/ownership fixtures pass. Native graphical readback on Intel HD 620/ANGLE
confirms changing bones and skinned vertices for 15 opening actors plus seven
encounter-rig representatives. Dialogue clock restoration and cache resume pass;
eleven campaign destinations pass actor-aware preparation/cancellation. A known
construction-fixture ObjectDB shutdown warning remains, not memory acceptance.
Final-package browser New Game, ordinary movement, displayed Anwen Use and
dialogue/input recovery pass without console warnings/errors. However, the care
area has obstructed dialogue framing and malformed head/hood presentation. Those
GAME defects remain open for the separate face/framing owner. This child is not
a visual, all-animation, all-region, phone, performance or whole-ticket acceptance.

[Bounded evidence](../../outputs/AshenOathTheRoadBetweenCrowns/release_reports/animation_lifecycle_20261029.json).

## Blank World View Hotfix - 2026-10-27

User report: the HUD is visible after loading, but the 3D world is blank.
Read-only HTTP inspection returned the expected production manifest for
`grounded-camera-20261027`, with its expected root identity. This is not proof of
runtime rendering or of every delivered asset. No accessible existing game tab
was available for error-log inspection; no game/browser run was started.

The source repair removes the recent incremental orbit-history transformation,
retaining the single 14/s position and 8/s look filters, trauma shake and the
physics/cadence/foot changes. Camera preparation explicitly selects the real
camera; arrival restores the published active world's visibility and 3D viewport
before releasing the handoff. Invalid/degenerate camera transforms and stale
follow history are reseeded without moving the player or changing a journey.
Dialogue publication synchronizes the stored camera position. Covered prewarm
may disable 3D only while it still owns the menu, not after its active-world
ownership check. A disabled gameplay viewport can recover through the same
existing session owner, without spawning another world or clearing saves.

Candidate: `world-view-hotfix-20261027`. All eight runtime packs and the production
Web export compiled successfully. Static packaging/manifest generation passed:
17 deployed files, 108,010,642 bytes total; largest file 32,705,550 bytes. The exact
candidate was synchronized to `web/` for the Git automatic-publication workflow.
Publication commit/status is recorded separately in the existing release receipt.
The exact trigger and the player's visible result remain unverified under the
current build-only instruction. These source corrections are not represented as
an observed runtime pass. User checks: New Game reaches visible complete Greyfen,
Continue shows its recorded world, opening/dialogue/Resume retain the view, and
third-/first-person camera transitions preserve scenery and character visibility.

## Camera, Cadence And Grounding Repair - 2026-10-27

Candidate: `grounded-camera-20261027`, preserving the published living-motion
implementation and the existing animation/action owners.

- Camera follow has one shake-free exponential position filter (14/s) and one
  look filter (8/s), instead of chained anchor/output filtering. Deliberate orbit
  input rotates the stored follow frame immediately. First-person eye anchoring,
  collision safety, rebasing and dialogue-return composition remain retained.
- Camera impacts use bounded, squared trauma and continuous FastNoiseLite motion
  after the follow filter. Shaken output never feeds back into follow history.
  Saved shake intensity, zero-shake, reduced-motion and flash-reduction settings
  suppress the appropriate effects; idle camera breathing respects reduced motion.
- Locomotion rates are recomputed from achieved horizontal speed and authored
  reference cadence, clamped to 0.6-1.6, with no state-switch multiplication or
  phase seeks. Timed combat actions retain their controller-owned durations.
- Player, companion, routine and ambient root movement use physics callbacks.
  Enemy perception/decisions retain their throttled rates, but physical motion
  now advances each physics tick at its configured speed rather than skipping
  capsule movement with the AI tick. Achieved displacement drives enemy cadence.
- Web simulation steps above 1/30 second are bounded. A shared movement helper
  also accounts for move_and_slide's internal engine delta; collision-adjusted
  velocity is restored afterward. This deliberately drops excess stalled Web
  simulation time instead of applying an unbounded catch-up displacement.
- Existing floor snap remains active; enemies explicitly receive equivalent
  snap/stop-on-slope settings. Foot rays distinguish animated lift from terrain
  clearance, permit bounded downward reach, smooth offsets/normals, and align
  ankles to supported slopes. Airborne, dead, action-owned and seated poses opt
  out. Analytic leg solving removes repeated whole-rig forced refreshes.

Implementation: present; static call-site/diff review complete.
Compilation: all eight content packs and production Web export completed without
errors. Static packaging passed for 17 files, 108,009,852 bytes (103.0 MiB),
below the shared 256 MiB policy. Root transport SHA-256:
`a1f9ceff8b7eb01edaab05d67fe4f01537a2d572be982df99066b2ba56c6f1e9`.
Balanced opening transport is 48,360,514 bytes, not a measured startup time.
Publication: the FINISH-003 Git publication receipt owns the actual commit/push
result. Vercel builds and publishes automatically after the main push; no manual
deployment, provider polling or live/gameplay verification is claimed.
Agent runtime tests, browser QA, captures and benchmarks: NOT RUN.
User acceptance and measured smoothness/performance: PENDING, not a passing claim.
No meshes, textures, population, saves, input bindings or damage values removed.

User checks: walk/run/reverse/stop on flat ground, bridge joins and slopes; jump
and dodge without planted airborne feet; idle NPC feet and seated traveler poses;
ordinary enemy pursuit and combat timing; orbit, first person and bow aiming;
dialogue/Continue/zone returns without stale follow history; impacts and every
shake/reduced-motion setting; repeat on actual phones, including a tab return.

## Current Implementation Delivery - 2026-10-26

Candidate: `finish-implementation-20261026`, continued from published r14
(`4b28d2d`) on the canonical D: development branch.

Retained eight-direction locomotion, first person, bow alignment, stable dialogue framing, materials and all existing weighted facial assemblies. Centralized playback clocks and full dialogue-policy restoration; corrected abandoned boss-strike clock ownership.

Source implementation/reconciliation: complete for this build-only delivery.
Compilation/package/publication: recorded centrally in
[FINISH-000](FINISH-000.md) and the current FINISH-016 publication receipt.
Agent runtime verification: NOT RUN; user acceptance: PENDING.
No historical failure or unplayed case is promoted to passed. The approved
build-and-publish boundary supersedes old intermediate approval/publication holds
below; original runtime/performance contracts remain for the user's acceptance.

## Preserved Contract And Historical Evidence


Parent: [FINISH-000](FINISH-000.md). Dependencies: FINISH-001, FINISH-002.
Implementation: retained movement/material/camera repairs present.
Compilation: baseline recorded; not rerun. User acceptance: Pending.
Publication: baseline only.

## Player Outcome

Kael moves naturally toward travel, the camera follows without fighting input,
and required characters remain complete, textured and recognizable.

## Existing Owners And Evidence

Use player/camera controllers, locomotion/pose drivers, prepared actor/material
records and existing camera placement. Relevant records:
[movement/colour](../../outputs/AshenOathTheRoadBetweenCrowns/CHARACTER_MOTION_COLOUR_RESULT.md),
[atlas delivery](../../outputs/AshenOathTheRoadBetweenCrowns/BOOT_009_RESULT.md),
[camera smoothing](../../outputs/AshenOathTheRoadBetweenCrowns/STARTUP_SMOOTH_001_RESULT.md).
The atlas startup observation did not establish final visible-character approval.

## Remaining Conditions And Bounded Repair

- Keyboard arrows/WASD, touch and available gamepad turn normal locomotion toward
  all travel directions using forward strides; sharp reversal brakes without
  persistent backward sliding, awkward reverse clips or stuck arm overrides.
- Achieved movement drives footsteps; idle/pause do not produce walking sounds.
- Unrestricted yaw, shortest-arc turning, immediate manual look, collision-safe
  follow and zoom-to-first-person survive aim, relocation and zone transitions.
- First-person/bow movement turns body/view as designed without self-fed spinning;
  committed attack/cast direction remains locked through its legitimate phase.
- Zooming out restores Kael. New Game, Continue, quality changes, day/night and
  region returns retain A-set bodies/atlases, Ranger Senn and approved NPC recipes.
- Gameplay and dialogue cameras avoid roofs, walls and the Hart's body, frame
  actual speakers and restore the previous player view afterward.
- Fix bindings/ownership or placement at its source. No generic recolour,
  substitute capsule, forced lighting change or replacement character family.

## User Manual Checklist

1. Walk/run eight directions, reverse repeatedly, stop, then draw/sheath and guard;
   check facing, feet, arm release and footstep timing.
2. Rotate fully, zoom in/out, repeat movement and bow aiming in first person;
   confirm stable heading and arrows follow displayed aim.
3. Continue, change quality and revisit day/night areas; inspect Kael, Anwen,
   nearby villagers, Senn and later Halvern for complete consistent bodies/colours.
4. Enter an interior and talk to a human and the Hart; check framing and camera
   restoration. Gather these checks during the regional route, not a separate tour.

## Delivery Record

Targeted a54 Chrome observation - 2026-10-20, ruins-road candidate, hardware
960x540: real keyboard orbit accumulated 11.37312 radians, zoom input reached
the observed first-person state, and zoom-out restored Kael's ready, visible,
texture-bound A-set body. No captured console errors/warnings. Existing observer
fields supplied these assertions; no new runtime telemetry/candidate was added.
Report/image: D:/Temp/AshenOath/finish-targeted-20261020-a54-chrome-controls/browser.json
and browser_first_person.png. Overall strict browser-memory FAIL 606 MiB.
This observes orbit/first-person/body restoration, not every locomotion/combat/
equipment/actual-phone condition or user acceptance.

2026-10-20 graphical verification 1/1: current native source, 1280x720
Compatibility/ANGLE Intel HD 620. Eight real-key travel directions, forward
locomotion selection, idle settling, retained Kael atlas, unrestricted orbit,
first-person zoom/body visibility and zoom-out restoration had no assertion
failures. One assertion failed after the fixture directly teleported Kael without
resetting physics interpolation. HARNESS correction adds the same reset required
for relocations; the owned watchdog is now stopped/freed at teardown to avoid
its callback retaining the test tree. No gameplay camera code was changed.
Log: D:/Temp/AshenOath/finish-003-20261020/stdout.log. Correction is not rerun.
Full-world NPC/quality/day-night/interior/Hart observations remain Pending;
this graphical component session alone does not accept the whole card.
User verdict/date: Pending. Unavailable physical gamepads remain untested.

