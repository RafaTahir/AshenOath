# PRES-001 - Sky, Interior Lighting and Shore Ownership

2026-09-27. **Partial evidence, not formal ticket acceptance.** Formal Recovery-004
count remains 27/37. No export, commit, push, merge or deployment in this pass.

## Retained source changes

- Three original, deterministically baked continuous-density cloud volumes replace
  transparent cards. Seven resident formations retain 2/4/7 quality-tier density,
  three shared meshes and one opaque, painted material. Total mesh bytes: 156,463.
- Clouds sit at atmospheric rather than foreground angular sizes. Depth-tested
  sun, moon and stars lie beyond them; billboard scale preservation maintains
  visible disc sizes. No no-depth-test shortcut or oversized sun sphere.
- Outdoor fog no longer washes away the authored sky. Night retains a dark
  horizon with readable actors and paths; daylight and moon/stars are exclusive.
- Record Hall and undercroft inherit neither exterior sun direction nor colour.
  Their fixed interior light retains authored brightness and suppresses sky.
- Animated water now uses a generated tangent basis and tangent-space normal
  map, instead of writing a world-up vector into the view-space fragment normal.
- Greyfen's visual soil is cropped at the bank join. The merged terrain alone
  owns the sloping bank, terminating below the lowest wave along the water's
  actual contour. Former overlapping river slopes are not created for Greyfen.
- Wetness accents follow the contour and stop outside the bridge route; the
  former floating rectangular wetness boxes are gone. Collision is unchanged.
- One shared 512-triangle far-terrain mesh joins the Wychwood support apron and
  Hart perimeter. Fitted rolling ridges replace the exposed lower-sky boundary;
  all terrain vertices remain outside playable/support interiors.
- Four shared, sourced masonry piers support each river span from the bed at
  -1.62 m to the deck underside. The eight-rock, four-course derivative is
  61,348 bytes / 2,736 triangles; the initial heavier bake was not integrated.

## Proof and limitations

- `tools/verify_pres_001.gd`: phase/material/mesh/tangent/interior-history contract
  passes cleanly. This does not claim rendered art or hardware FPS acceptance.
- `tools/verify_greyfen_shore_ownership.gd`: actual production ground routine and
  packed gameplay core pass. Every collision shape ID and world transform is
  unchanged; zero flat soil triangles cover the bank and no duplicate bank owner
  remains. Both supported wetness contours clear the bridge width.
- `tools/verify_celestial_rendered_size.gd`: actual Intel HD 620 ANGLE pixels pass.
  Sun expected 28.15 / bright 25 px; moon expected 27.02 / bright 22 px. The size
  defect caught during review was fixed, not retrospectively approved.
- Final evidence: `.release-gate/pres001_review_final_20260927/capture_report.json`.
  All 13 current 1280x720 images were inspected by Codex. PNG and seven affected
  input hashes match. Baseline camera transforms match within 2e-8 numeric
  serialization error (1e-6 tolerance); not all serialized strings are identical.
- These are **staged art fixtures**, not player-input progression. NPC schedule
  time changes between captures; camera equality does not imply actor equality.
- Reviewed improvements: smaller billowed clouds; day sun/night moon and stars;
  readable nocturnal paths; neutral Record Hall ceiling; removal of Greyfen's
  pale straight bank strip. Full scene approval is still withheld: Wychwood/Hart
  expose lower-sky gaps, bridge foundations remain weak, Castle and several
  foreground compositions still require WORLD-001/002. Trees can obscure the
  Wychwood daytime sun; a visible node is not universal rendered-body proof.

## Rejected and red evidence

- Final foundation/terrain views are in
  `.release-gate/pres001_foundations_v2_20260927/capture_report.json`: six actual
  1280x720 images inspected, all twelve source hashes and six PNG hashes match.
  Five preserve the recorded gameplay-camera compositions; the bridge side
  view is additional foundation evidence, not an identical-camera baseline.
  Hart now has a continuous rolling horizon; Wychwood's distant ground covers
  the support edge; the side view shows supports beneath the span. These are
  retained bounded presentation improvements, not whole-world art approval.
- `verify_landscape_foundations.gd` passes shared mesh/material, metre-scale UV,
  winding, bounds, idempotence and exact unchanged-collider contracts. Updated
  shore proof passes the actual production builder. Its first immediate exit
  leaked an active WAV playback; explicit stop/detachment and audio drain fix
  the fixture. The initial exact float equality for -1.62 failed; the corrected
  approximate numeric comparison passes. Failed records are preserved.
- The first terrain fitting was too low to resolve Hart's visible edge; supports
  inherited bank-side positions and could not be approved from the front view.
  One coherent fitting correction raised exterior ridges and placed supports
  within the river span, without any collision or route change.
- Current affected native Greyfen performance remains **FAIL**:
  45.730 avg / 29.147 FPS 1% low settled; hydration 37.816 / 2.958,
  worst 895.447 ms; 83,491,711 bytes, 253 draws, 127,334 primitives.
  Report: `D:/Temp/AshenOath/pres001_foundations_perf_20260927.report.json`.
  This warm-profile diagnostic is not an interleaved A/B performance attribution.
  No startup, FPS, browser or full ticket acceptance follows.

- Initial wedge cloud mesh: visually rejected despite geometry checks passing.
- Early volume bounds: failed unchanged minimum depth; corrected offline before
  retention. Final repeated build produces the same three SHA-256 values.
- First shore fixture printed PASS before scene-tree entry and leaked its unused
  residency service. That run is **failed**. The corrected fixture awaits entry,
  frees the standalone service and passes with no runtime/shutdown errors.
- `pres001_shore_final_20260927`: fresh native profile fails complete Greyfen
  readiness at the unchanged 45-second limit; initial prewarm 33,814 ms. No visual
  or loading acceptance follows. Its log remains under D:/Temp/AshenOath.
- Explicit warm-profile captures succeed: first 1,713 ms, final 1,639 ms prewarm.
  This cache-sensitive difference is diagnostic, not a controlled causal study
  or a cold-start pass. Do not discard the failed cold result.
- Intermediate warm frames had undersized celestial discs because billboard
  scale was ignored. Those sky frames are rejected; the final batch supersedes
  them. Interior and unchanged shoreline observations retain bounded scope.
- Earlier exact capture's Hart cold activation was 37,022.8 ms. Final warm
  activations still include Greyfen 972.5 / Wychwood 847.3 / Castle 677.8 /
  Record Hall 520.6 / Hart 480.4 ms. Capture PASS does not pass transition budgets.
- Directly affected native PERF sample before the final shore/scale correction:
  settled Greyfen **39.010 avg / 22.852 FPS 1% low**, hydration **30.558 / 1.509**,
  worst frame **1,408.025 ms**, memory 83,485,413 bytes. Thresholds remain red.
  Report: `D:/Temp/AshenOath/pres001_affected_perf_20260927.report.json`.
  No current-source full FPS claim or performance attribution is made.

## Running steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, use
`C:/Temp/AshenOathGodot4.6.3/Godot_v4.6.3-stable_win64_console.exe`:

```powershell
$godot = 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/verify_pres_001.gd
& $godot --headless --path . --script res://tools/verify_greyfen_shore_ownership.gd
& $godot --headless --path . --script res://tools/verify_landscape_foundations.gd
& $godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/verify_celestial_rendered_size.gd
```

For art only, use `capture_pres_001.gd` with a new `.release-gate/` output directory
and `--reference-report=res://.release-gate/pres001_baseline_20260927/capture_report.json`.
The 45-second readiness and 180-second owned-process bounds are not relaxed.
Owned profiles/logs remain under D:/Temp/AshenOath; no global environment change.

The coherent far-terrain/foundation pass is retained at its proven scope.
PRES-001 awaits the shared native performance/certification blocker; the
complete-residency/publication and renderer-family hypotheses already failed
the combined PERF contract. No further per-prop or warm-stage edits are justified.
Proceed with independent release-critical work, retaining these current inputs
and reviews. PRES-001, WORLD-001/002 and PERF-001 remain unaccepted; no Web while
native-red.
