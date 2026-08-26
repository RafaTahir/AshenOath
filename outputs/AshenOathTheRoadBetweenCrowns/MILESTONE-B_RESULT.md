# Milestone B Result

## Scope

Milestone B implements the coordinate atlas, exterior seam lifecycle,
portal-free outdoor traversal, navigation-safe boundary transitions, world
coordinate save migration, and physical interior-door semantics.

## Gates

The structural `milestone_b` profile passed:

- content integrity and runtime smoke
- WORLDGRID-001, SEAM-001, SEAM-002, NAV-002
- SAVE-004 and INTERIOR-001
- player-driven SEAM-QA-001 circuit
- STREAM-003, navigation, save, scene, and zone-builder regressions
- focused audio and character regression profiles after the boot optimization
- Web export, seven-file artifact validation, and packed startup
- Chrome and Edge WebGL2 startup/New Game smoke with no console errors. The
  first two-browser invocation hit a CDP screenshot timeout after Chrome had
  passed; independent final Chrome and Edge probes passed against the
  committed-tree export.
- current seamless changed-view capture

SEAM-QA-001 traversed both directions through:

`Greyfen -> Wychwood -> Deep Woods -> Old Mill -> Burned Farmstead -> Marsh Crossing -> Bandit Road -> Vargan Approach`

The final export contains seven files, totals `87.30 MB`, and has PCK SHA-256:

`27994E556ADE09F69EE2D1CE7FE2DBD34D15EF5A89D39435E126AC64C54F9903`

Browser evidence:

- Chrome: 1280x720 WebGL2, no console errors, engine ready `33.40 s`, New
  Game ready `5.66 s`.
- Edge: 1280x720 WebGL2, no console errors, engine ready `19.60 s`, New Game
  ready `4.99 s`.

The clean-source pass also defers noncritical generated, recorded, and voice
audio libraries until after the menu path and moves the shared humanoid clip
library and unused Dragon FBX out of script-level boot preloads. A warmed
headless boot remains approximately `0.53 s`; the fresh-profile graphical
harness remains variable because it uses a software ANGLE path.

## Evidence

- `Development_Gallery/screenshots/SEAM_001_01_GreyfenBoundary_20260826_150551.png`
- `Development_Gallery/screenshots/SEAM_001_02_WychwoodArrival_20260826_150551.png`
- `.release-gate/ticket/web_browser_chrome_final_chrome.png`
- `.release-gate/ticket/web_browser_edge_final_edge.png`

## Known blockers and honest status

The route/lifecycle work passes, but the broader release contract still has
open items: cold browser startup remains above the 12-second target, the
later-zone art is still procedural/blockout-grade, and graphical verifier
teardown prints shutdown-only allocator/ObjectDB diagnostics. The startup
target is not waived by the optimization; the browser measurements above are
the current truth. These issues keep the production release classified as
functional-but-incomplete rather than visually final. One earlier Edge
screenshot timeout was isolated to the first browser invocation; independent
final Chrome and Edge probes passed against the committed-tree export.

The verified Web candidate is ready for a development checkpoint. Production
`main`, tracked `web/`, and Vercel remain unchanged until the startup/lifecycle
release blockers are explicitly cleared.

## Running

From the project directory:

```powershell
$env:GODOT_BIN='C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles milestone_b -ChangedViews seamless
```
