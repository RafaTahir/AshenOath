# FINISH-003 - Movement, Camera And Character Integrity

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

