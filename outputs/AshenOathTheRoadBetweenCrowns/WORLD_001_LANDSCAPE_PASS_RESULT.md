# WORLD-001 Ground, Bank, Horizon and Dialogue Fit

2026-09-27: retained partial work. WORLD-001/PRES-001 remain pending; recovery
count stays 27/37. No browser, performance, full-world or release acceptance.

## Retained Fixes

- Source and native geometry prove both RiverSection bank slopes faced below
  the water: 96 wrong triangles/288 wrong normals per side. Corrected winding
  restores upward visible faces and lighting; physics/recovery are unchanged.
- Rebalanced existing ground vertex colors toward damp vegetation and worn
  work areas; retained the source texture, geometry, roads and actor population.
- Replaced four flat horizon cards with a joined three-band perimeter. Geometry
  is 288 triangles total, outside existing playable bounds, with no collision.
  The first independent-ridge trial left a notch and is explicitly rejected.
  Shared world-space coordinates/height now join all twelve corner-band points.
- The actual physical-input run exposed Kael at Y=1.002 during paused Anwen
  dialogue. The coordinator was adding Vector3.UP after spatial validation.
  Replaced that with the shared floor-support query, a 2 mm floor clearance,
  player-RID exclusion, and refusal of unsupported/greater-than-0.35 m steps.
  Staging, facing, camera, dialogue actions and mouse ownership stay intact.

## Evidence

Logs under `D:/Temp/AshenOath/`:

- `pres001_bank_winding_before_20260927`: FAIL proving both inverted banks.
- `world001_landscape_contract_20260927`: bank geometry and WORLD-012 PASS.
- `world001_landscape_candidate_20260927`: capture succeeds but separated-ridge
  composition is REJECTED. This is not accepted art evidence.
- `world001_horizon_join_20260927`: FAIL due unit setup querying global transforms
  before tree entry and assuming vertex-array ordering after SurfaceTool commit.
  Corrected fixture checks actual local geometry/corner positions independently.
- `world001_horizon_join_v2_20260927` and
  `world001_horizon_actual_builder_20260927`: PASS; latter executes the production
  builder rather than a duplicate of its layout specifications.
- `world001_landscape_joined_20260927`: four fresh 1280x720 frames inspected
  against `world001_social_final`. Keeps terrain/road contrast, closes the notch,
  and preserves actors, furniture, water and crossings. Background remains
  sparse and visually incomplete, not approved at full opening scope.
- `world001_landscape_input_20260927`: PASS actual keyboard New Game, physical
  south-to-north bridge, Anwen focus/E, conversation and quest advance/close.
  Its logged airborne staging is a demonstrated bug, not accepted grounding.
- First grounding unit fails compilation; bounded owned process terminates.
  Explicit Variant typing fixes the error; failure is retained, not suppressed.
- `world001_dialogue_grounding_unit_v2_20260927`: PASS supported/blocked step,
  facing/page/close/retirement/idempotent ownership.
- `world001_dialogue_grounding_matrix_20260927`: PASS additional raised-floor,
  high-platform and missing-floor checks protecting the new support policy.
- `world001_dialogue_grounding_input_20260927`: PASS actual menu/movement/E,
  paused grounded dialogue Y=0.002 and normal close; ANGLE driver advisory only.
  Actual inspected image: `D:/Temp/AshenOath/world001_anwen_grounded_dialogue.png`.
  The dialogue panel obscures feet, so this image is not full-body art approval.

Final camera images: `.release-gate/world001_landscape_joined/`:

| Image | SHA-256 |
|---|---|
| WORLD_001_Social_Spawn.png | 4aba273c32246119da9e1a8d8ba4817526b3ba30511adb7c9c66faf1d1a69801 |
| WORLD_001_Social_Table.png | c238c603578445c50175343324cd8f4dbf830334c9dda222179ab6000640ba57 |
| WORLD_001_Social_Apothecary.png | d247b08cb9bfaaaa11c89cad9928c5bdb2937f96b1cd9e4c2be5aa14ea048584 |
| WORLD_012_04_Greyfen_River_Bridge.png | 3517121dc9a86d3df12b15989a8ed88290c2dc52a0fc4dc81521fd83e00c5758 |

These staged stills predate the later dialogue-grounding fix; their unchanged
static landscape dependencies remain valid. They are not whole-source gallery
approvals, continuous campaign proof or browser screenshots.

## Running Steps / Next Action

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`:

```powershell
$godot = 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/verify_river_bank_faces.gd
& $godot --headless --path . --script res://tools/verify_greyfen_horizon.gd
& $godot --headless --path . --script res://tools/verify_dialogue_runtime_coordinator.gd
& $godot --path . --script res://tools/capture_world_012.gd -- --landscape-only --output-dir=res://.release-gate/world001_landscape_joined
& $godot --path . --script res://tools/verify_opening_real_input_native.gd -- --anwen-only
```

Use isolated test user data under D:/Temp/AshenOath. No commit, export, push,
merge or deployment. PERF-001 first-control publication/construction remains red;
the earlier settled sample cannot certify these later changes. Next: a distinct,
source-backed performance discriminant, remaining opening composition, and then
source-aligned browser/full-route evidence. Do not repeat rejected per-prop
prewarm or identical batching experiments.
