# Natural movement release

Date: 4 October 2026. Requested outcome: more natural NPC and Kael body movement, particularly awkward backward and sideways walking. Push and deploy when finished. The user authorizes exactly one test/verification pass for this request.

## Source findings

- Camera-relative backward input previously froze Kael's old body yaw, so moving the camera or retreating after a sideways approach could send the body sideways relative to its gait.
- Animation received the requested direction with the actual speed. During acceleration, collision, reversals, dodge and coasting, those described different movements.
- Driver direction used the scaled and tilted imported model basis, making directional thresholds depend on asset normalization and presentation pose.
- The active shared library contains forward Walk and Sprint. Forward Walk also supplied strafing and backward fallbacks; frequent state changes restarted its phase. Explicitly mapping a reverse state to Walk could also be mistaken for a genuinely authored backward clip.
- Greyfen villagers moved at sparse simulation ticks, snapped to route yaw and supplied commanded rather than achieved speed to animation. Stationary ambient motion translated the whole root vertically and allowed broad body turns toward Kael.
- Mill workers moved diagonally while retaining a fixed visual rotation and receiving a constant forward animation direction. Their imported grounding and facing correction were overwritten at placement.

## Changes

- Separate desired facing from achieved motion: intentional backpedaling faces opposite the requested travel direction; actual displacement drives gait, movement state and lean. Reversals do not use old forward inertia as a new facing instruction.
- Backpedal pace is capped at 1.45 metres/second. Free third-person backward sprint turns into a forward run toward that input direction. Aiming/first-person keeps its facing and controlled backward pace.
- Sharp free turns brake the old stride and ramp acceleration as the body turns. Moving rigged bodies receive less additional whole-root bob and lean over their authored animation.
- Shared animation normalizes horizontal direction independently of source scale/tilt, accepts physical velocity, calibrates cadence from travel speed and retains gait phase through transitions. Existing ratio callers remain supported.
- Visible Greyfen villagers move continuously, accelerate and brake, slow at arrivals and use bounded turns/planted pivots. Sparse story, distance and hydration decisions remain separate from visible motion; nearby animation updates receive a higher cadence.
- Stationary ambient behavior keeps feet planted, bounds attention and yields to the movement or dialogue owner. Direct imported +Z bodies and ordinary -Z actor wrappers retain their respective facing contracts.
- Mill escorts preserve imported grounding/orientation beneath an actor wrapper, face their route, move each physics tick with acceleration/braking and feed achieved velocity to animation. A small follow-distance hysteresis avoids repeated starts and stops at the threshold.

## Animation scope

The active in-place clips do not contain source ground-travel measurements. Physical stride/cadence values are explicit calibration assumptions, not motion-capture measurements or a foot-lock guarantee. Older local character GLBs contain directional run clips, but their rest axes, hierarchy and limb bases differ from the current universal rig. The existing fusion helper only renames tracks; those clips are not transplanted without a full retargeting pipeline. This release corrects the current locomotion system and bounds backward pace rather than presenting a reversed forward clip as newly authored backward motion.

## Single verification pass

Reserved, not yet run. Root will execute one graphical Godot fixture session after source integration and production compilation. It will exercise real controllers and imported rigs across forward travel, camera-relative backward/diagonal movement, sharp turns, backward sprint turnaround, stopping and NPC waypoint/attention movement. The same session will emit metrics and time-separated rendered frames. Reading its report and viewing those frames constitutes the one verification pass; there will be no baseline execution or second run.

Production import/export and responding to compiler diagnostics produce the release artifacts. They are not additional gameplay test passes. No general regression suite, browser playthrough or post-deployment verification is planned.

## Publication

Implementation and the single verification are in progress. Final source, package, report outcome and Vercel response will be recorded here.
