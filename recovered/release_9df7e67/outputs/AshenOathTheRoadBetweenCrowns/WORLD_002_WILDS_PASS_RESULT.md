# WORLD-002 - Campaign Wilds Composition, 2026-09-27

## Outcome

Retained implementation and partial native/camera evidence, **not WORLD-002
acceptance**. Formal progress remains 26/37. Production is unchanged.

One four-area pass replaces slab roads, exposed northern horizons, farm box
shells, checkpoint boxes, square pools and cube reeds. Existing trees, actors,
quest IDs, clue positions, encounters, gates and save progression remain.
Seven deterministic resources total 139,643 bytes and 9,216 triangles. Source
hashes, license evidence and campaign export ownership are registered in
`runtime_asset_manifest.json`; no raw asset or new external dependency ships.

Farm ruins use retained native brick, timber grid, door and broken roof meshes.
Inner walls and the eastern raised foundation remain absent for route clearance.
Visible rear/outer walls and doors now have exact-position collision, rather
than passing masonry through actor recovery/reservation and silently losing it.
The checkpoint's two towers and overhead beam retain the central passage. Its
closed camp shelter and table are placed clear of gates and the diagonal sector
lane, with matching collision. Marsh boards are flush visual dressing over the
original supported floor; they do not invent a raised threshold or change river
crossing/recovery rules. Organic pools/reeds are visual only.

## Evidence

- `world002_wilds_bake_v5.log`: clean seven-resource bake.
- `world002_wilds_determinism_v1.log`: all seven resources byte-identical on
  rebake. Total bytes are raw resources, not a claimed exported payload.
- `world002_wilds_contract_v3.log`: clean native PASS. Indexed finite geometry,
  materials, source/current manifest hashes, byte budgets, export membership,
  noncollapsed board-top UVs, exact published structure collision, central lanes
  at three offsets, both approach directions and Bandit's diagonal/north/south
  routes pass. This is a static CharacterBody sweep, not real-input acceptance.
- Fresh grounded 1280x720 before/current views:
  `.release-gate/world002_wilds_before` and `world002_wilds_final`.
  Codex inspected all four comparisons. Farm/checkpoint structure, terrain
  boundaries, organic marsh pools and usable boardwalk are visibly improved.
  Broad flat terrain, stylized staging and lighting/water debt remain; this is
  not final semantic gallery or night acceptance.
- Gallery: `WORLD-002_Wilds_{DeepWood,Farmstead,Marsh,BanditRoad}_20260927.png`.
- `world002_wilds_route_v1.log`/stderr: **overall FAIL**. Genuine Continue from an
  untouched copy of the prior Soldier handoff save physically crossed Farmstead,
  walked Marsh without jumping, reached Bandit, advanced the road objective and
  saved through the pause menu. The extra Senn continuation missed its bounded
  movement deadline at z=5.08 despite northward velocity and no forward obstacle.
  Do not relabel this run as a route pass. Two explicit diagnostic-fallback
  warnings show the `bandit` role lacks an acceptance record; this is also a
  release blocker, not an allowlisted engine diagnostic.
- Real-input activations: Farmstead 95.3 ms, Marsh 2623.0 ms and Bandit
  2035.5 ms. The latter two fail the cold budget. Faster staged captures do not
  erase them.
- JSON and release PowerShell syntax pass. Narrow `campaign_wilds` gate and the
  mandatory native verifier are registered; no complete suite or Web export run.

## Rejected / Limited Evidence

The first candidate drew an eastern rear wall and camp furnishings where the
old placement helper discarded collision. Native shape inspection caught this;
that geometry/collision mismatch is rejected. Exact authored collision and
route-safe camp placement supersede it. First board UVs collapsed the top-face
mapping; final local mesh UVs and regression assertions supersede those bytes.
The original four-view baseline is preserved, not regenerated as a before-state.

## Next Dependency

WORLD-002 cannot close with rejected performance and an unapproved Bandit combat
role. Preserve its retained composition; do not polish props or repeat green
contracts. PERF-001's next discriminant is a controlled explicit desktop OpenGL
versus ANGLE run of the existing native first-visible/settled sample on identical
source and shader-cache fixtures. This distinguishes renderer/cache ownership
from the leading distributed-publication hypothesis before another redesign.
The Bandit policy omission also requires a validated same-body/animation role
record, not a warning suppression or fabricated approval.

## Running

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, with child-only
APPDATA/LOCALAPPDATA under `D:/Temp/AshenOath`:

```powershell
& 'C:/Temp/AshenOathGodot4.6.3/Godot_v4.6.3-stable_win64_console.exe' `
  --headless --path . --script res://tools/verify_campaign_wilds_composition.gd
```

The affected graphical route uses a new isolated copy of
`soldier_road_v2_fixture/AppData/Roaming` and
`verify_opening_real_input_native.gd -- --continue-soldier-road --wilds-composition-proof`.
Do not reuse the now-advanced `world002_wilds_route` save as an original fixture.
No commit, push, merge, Web export or deployment.
