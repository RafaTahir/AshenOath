# OPT Milestone 8 - OPT-052 through OPT-054

## Implementation

- The existing geometry compiler prepares transform/color buffers and bounds
  for 38 literal immutable detail/prop recipes. Batched details no longer need
  transient scene markers for these recipes. Ordered material/alpha/night
  grouping stays unchanged; props retain the exact existing collision and
  route-clearance path. Relocated or parameterized pieces retain runtime data.
- Existing authored house meshes are already compiled assets, and module
  material groups stay with their existing owner. No broad PackedScene bake,
  tree regrouping, staged-prewarm mechanism or content reduction was introduced.
- Objective and navigation models cache by their actual quest, beat, story and
  zone signals. Callers receive copies; load/setup invalidate old snapshots.
- The navigation dial retains separate background/terrain, moving marker and
  frame drawings. Position, spatial revision, radius, layout and contrast
  invalidate only the drawings they affect; heading-only changes do not repeat
  polygon clipping or frame drawing. Spatial edits invalidate by revision, not
  just by the number of registered obstacles.
- Nearby interactions reuse the existing ordered XZ spatial index. Movement,
  visibility, availability, removal and cached-root reentry update registrations.
  Focus scoring/dwell/visibility and fresh Use validation remain authoritative.
- The optional monitor measures positive gameplay frame intervals with a wall
  clock so engine-delta clamping does not conceal long stalls. Paused/menu time
  remains excluded and monitoring is disabled normally.

## Compilation / Publication / Acceptance

The first build reported an existing river-bank compiler type mismatch
(`RefCounted` assigned to `Node3D`). Its export process was stopped; that partial
candidate is not publishable. The compiler now uses the correct ownership and
the packaging command rejects all asset-script errors, not just parser errors.
Corrected production build `opt-m8-20261019-r2-dcdd024` compiled and packaged.
Manifest artifacts: 104345777 bytes. Complete Web directory: 104353612 bytes,
strictly below 104857600. Root PCK: 6313381 bytes; SHA-256
`51fc3d6a3dca2903779f79c487c40db534b8c5a7363f791d2a18b56264501166`.
OPT-054's existing publication receipt records commit/push/Vercel outcome.
No runtime tests,
browser runs, gameplay, benchmarks or screenshots have been performed.
Implementation, compilation, deployment and user acceptance are separate.

## User Checks

Inspect scenery and conditional aftermath, then check objective/compass changes,
dial movement and high contrast/resize. Approach moving speakers and props;
Use must activate the displayed target with keyboard, mouse and touch. Check
returns, Save/Continue and optional `?perf=1` on desktop and an actual phone.
