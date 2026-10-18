# Faster Startup and Smoother Play - 2026-10-13

Implementation is local on D:, branch codex/masterpiece-rebuild, based on
10371b936bb4f93a7887772129bb9e7a3e60a04f. No commit, push or deployment.
User acceptance remains pending. Existing unrelated untracked work is intact.

## Implementation

- Menu services initialize before the first menu frame. Opening services initialize
  afterward; minigame UI initializes when needed. The shared campaign dialogue file
  also owns opening report/shrine nodes, so it loads with opening services after the
  menu frame, preserving its original override order and all conversations.
- Unstarted journeys cannot Pause/Resume or dismiss the menu. Deferred menu actions
  check their originating screen; input queues reset across the handoff.
- Browser back/forward-cache restoration resets input and pauses a running journey.
- Greyfen remains cached after its complete camera render; idle menu preparation
  stops 3D rendering. New Game reuses that tree instead of rebuilding it.
- All existing opening stages finish before control, including crowd and dressing.
  Three retained villager assemblies move from Characters to Opening, retaining
  content and reducing the late character-pack dependency. No bodies are replaced.
- Camera follow samples the interpolated player transform, while physics remains
  unchanged. Spawn, zone and recovery paths reset interpolation. Orbit changes
  refresh obstruction checks; the camera has an independent world transform.
- The 16-metre tree-group experiment was removed. The partial desktop increase was
  too small against the later measurement variation to justify retaining it. Final
  tree batching, meshes, colours, materials, transforms and collisions match HEAD.
- Existing browser tooling now uses current readiness state, the rendered mouse
  target, Quick Save and direct-menu reload. It supports an explicit viewport size.

## Package

Candidate: startup-smooth-20261013-final-10371b9

Directory: D:\Projects\AshenOath\.release-gate\startup-smooth-20261013\export

15 artifacts: 94,219,834 bytes. Directory including the release manifest:
94,226,680 bytes (89.9 MiB), strictly below 104,857,600. Root PCK SHA-256:
237f4465b37ea1398e585397d451599cb8301cf8a5b96f0bdeca566f2daf6177

Godot script compilation and package size/hash checks passed. Only changed packs
were rebuilt; unchanged content packs were retained. web/ and production are intact.
V1 is preserved at .release-gate/startup-smooth-20261013/rejected-v1: its Continue
path left 3D disabled when cancelling menu preparation. V2 enables rendering only
after that cancellation and the accepted journey handoff. The checked V2 is retained
at .release-gate/startup-smooth-20261013/checked-v2. The final build keeps that fix.

## Focused Evidence

Local headed Chrome, hardware Intel HD Graphics 620 / ANGLE, Balanced, fresh
isolated D: profiles. These are limited samples, not performance certification.

| Observation | Previous package | Experimental V1 first journey |
|---|---:|---:|
| Navigation to menu | 13.49 s | 14.64 s |
| Navigation to control | 45.30 s | 45.99 s |
| Complete opening detail | 56.71 s | 45.92 s |
| Last observed average FPS | 17.54 | 18.73 |
| Last observed 1% low FPS | 10.58 | 11.95 |

The experimental scene was complete at handoff. Initial control was not faster in
this sample; the late assembly interval was eliminated. The small FPS increase did
not establish a reliable gain. The experiment is removed from the final build; these
figures are not final-build performance claims. Numerical limitations remain.

Earlier baseline attempts hit obsolete harness readiness/button assumptions and a
preview favicon response. Corrected baseline reached New Game, movement and durable
Quick Save, then its CDP reload timed out. The desktop after-run reached complete
Greyfen and movement with no console errors, but Runtime.evaluate timed out before
camera, pause/focus and persistence coverage completed. Neither run is a full PASS.

V1 960x540 touch emulation passed the driver's seven startup/movement/save/Continue
assertions, but screenshot review rejected its black Continue scene. This PASS is
not accepted visual evidence. The V2 affected check passed New Game, movement, durable
Quick Save, reload/Continue and restored control, with no console errors. Its final
screenshot visibly contains Greyfen, the bridge, buildings, river and Kael.

V2 960x540 touch-emulated timings: menu 21.57 s; New Game control 64.07 s;
returning Continue control 70.67 s. Its movement sample was 15.01 FPS average /
10.37 FPS 1% low. These results remain poor and vary substantially from the earlier
touch run (41.62 s New Game, 17.39 s Continue, 21.28 / 12.27 movement sample).
No reliable loading or sustained-FPS improvement is claimed. Final changes after
V2 remove the unproven tree experiment and preserve mixed dialogue ownership;
no additional runtime comparison is authorized or performed.

Raw reports and screenshots: D:\Temp\AshenOath\startup-smooth-*.json/png.
Build logs: .release-gate/startup-smooth-20261013/logs/.
Local laptop preview: http://127.0.0.1:8766/ (owned hidden preview process 7876).
Automatic approval review blocked cleanup of the successful-run temporary profile
D:\Temp\AshenOath\ashen-oath-qa002-chrome-1791882771380, with reason "blocked by
policy" and no further detail. It remains QA scratch; no user profile was touched.

## User Checks

1. Leave the fresh menu idle, then click New Game immediately while preparation runs.
2. Confirm complete Greyfen, normal movement and visible actors at first control.
3. Rotate through 360 degrees, zoom into first person, walk and reverse, then zoom out.
4. Quick Save, reload, Continue and confirm scenery, location, supplies and settings.
5. Switch away/back, Pause/Resume, and try portrait/landscape on the actual phone.

Actual phone/WebKit, camera motion approval, focus/back-forward-cache recovery,
full routes/campaign, exact worst-frame timing and target FPS compliance remain
unverified. This task does not approve those through compilation or partial samples.
