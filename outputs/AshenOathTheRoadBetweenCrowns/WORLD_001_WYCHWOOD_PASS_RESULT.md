# WORLD-001 Wychwood Evidence and Ground Composition

## Status - 2026-09-27

Retained implementation and affected native route evidence, **not formal
WORLD-001 acceptance**. Recovery remains 27/37 accepted. No Web export, Git
checkpoint, push, merge or deployment was performed.

## Changes

- Five static, identity-specific investigation meshes replace generic clue
  capsules. Bram uses the complete preferred CC0 Universal male body in UAL2
  Death01, normalized to 1.72 metres before CPU skin baking. The resulting
  body is grounded, horizontal and has no live skeleton. Ledger pages,
  red-thread feathers, Oren's token, broken wire and mud scuffs distinguish
  the evidence. Original actor anatomy is retained rather than proxy limbs.
- Terrain and drag-mark footprints now have irregular, world-metre UV edges.
  Wychwood's ground tint matches the forest floor. Bank-clipped patches no
  longer receive rotations that could invade water.
- Interaction IDs, collision, routes, quest requirements, actor population,
  five-enemy staging and river rules are unchanged.
- Runtime manifest records opening ownership, source checksums, license,
  resource bytes and hashes. Production/QA/opening filters include the five
  finished resources; base startup does not preload them.
- The graphical route harness can stop after the affected Wychwood report
  using `--wychwood-only`. Default full-route behavior is unchanged.

Files: `scripts/wychwood_evidence_presentation.gd`, `scripts/game.gd`,
`scripts/world_material_library.gd`, `tools/build_wychwood_evidence.gd`,
`tools/verify_wychwood_evidence.gd`, `tools/verify_world_013.gd`,
`tools/capture_world_013.gd`, `tools/verify_opening_real_input_native.gd`,
`tools/gate_profiles.json`, `runtime_asset_manifest.json`, `export_presets.cfg`
and five `assets_external/environment/forest/Wychwood_*_Evidence.res` files.

## Verification

- Deterministic bake: PASS, 400,313 bytes, 12 surfaces, 20,007 triangles.
  The complete body accounts for 18,915 triangles; no performance claim is made.
- `world001_wychwood_contract_v2_20260927.verify_wychwood_evidence`: PASS.
  Checks exact resource/source hashes, ownership, export inclusion, valid
  materials, static skin baking, pose support, ground UVs and upward winding.
- `world001_wychwood_contract_v2_20260927.verify_world_013`: PASS, 481 nodes,
  113 mesh instances, 20 MultiMesh instances. Route and retained canopy/tree
  contracts pass. Isolated scene setup is system evidence, not player traversal.
- First organic-fan winding assertion failed. The winding was corrected,
  rebaked and retested; the failed run is preserved, not suppressed.
- `world001_wychwood_visual_20260927`: PASS clean native capture, 1280x720.
  Its staged art fixture does not prove quest progression or combat population.
- `world001_wychwood_real_input_20260927`: PASS actual keyboard menu startup,
  movement, Anwen focus/dialogue, Bram/Sella/wire evidence, five enemy kills,
  bridge/return crossing and report. Road of Crows completes and Bell starts.
  No teleport, direct interaction call or story mutation prepares this route.
  Owned graphical process exits cleanly; only the existing ANGLE driver
  advisory remains. Genuine isolated saves remain under its D: temp profile.

Logs are under `D:/Temp/AshenOath/` with the names above. Native integration
activation was 2,052.3 ms; real-input Wychwood/Greyfen travel was 4,060.0/806.1
ms. Cold 900 ms and warm 350 ms acceptance remain red. These are not FPS samples.

## Inspected Same-Camera Evidence

Current files are under `.release-gate/world001_wychwood_candidate/`, compared
with preserved `Development_Gallery/screenshots/WORLD-013_*_20260924_150739.png`.
Codex inspected all four current frames; clues and irregular ground are better.
They are retained at bounded improvement scope only:

| View, suffix `20260927_203137.png` | SHA-256 |
|---|---|
| WORLD-013_01_Wychwood_Gate_Arch | 891bf6552309811c4f6d4330c37d890927ba2928dfcc505f20ea883319060187 |
| WORLD-013_02_Wychwood_Clue_Route | 8a1d18f59838adec3666751fd217d37b291e6448a555f09f57978259d475e919 |
| WORLD-013_03_Wychwood_Bridge_Canopy | 4cabb8d1b8024e8934fa4839c806c664e5df4378f09a303f8aa3972de714a456 |
| WORLD-013_04_Wychwood_Combat_Clearing | 79010e19aa079009ab48b6abc1f4f328644b5e6f5161204d8490c4e8e1b8792b |

Full visual review remains REJECTED: sparse forest horizon, plain angular arch,
visible boundary panels and repeated coarse trunks/deadfalls remain. Exposure
is nocturnal but route readable; preferred Kael is grounded; Bram has complete
anatomy and lies on the mud; materials are assigned and clue collision unchanged.
The combat art frame does not visibly prove five enemies; the separate actual
input log proves gameplay only, not final monster appearance. No browser,
full-world, boss, screenshot-gallery or hardware performance approval follows.

## Forest Framing Follow-up

The subsequent coherent framing pass is retained, not whole-world approval.
The two threshold supports use complete sourced twisted trees instead of bare
cylinders; the timber crown stays visible and retains its near-camera clearance.
Distant trees now share the accepted bark/leaf materials in two offset depth
layers. Existing boundary colliders remain unchanged while sloping, irregular
ground-textured berms replace their visual cubes inside the original envelope.
No new collision or hidden gameplay actor is introduced.

`world001_wychwood_frame_contract_20260927` fails all 32 instance-position
queries headlessly. The same source passes actual graphical instance transforms
in `world001_wychwood_frame_graphical_contract_20260927`: 483 nodes, 116 mesh
instances, 19 MultiMesh instances, clean shutdown. Do not promote the failed
headless run. WORLD-013 now explicitly requires graphical execution; both
ticket/release runners select it accordingly. PowerShell parser checks pass.

All four `world001_wychwood_frame_visual_20260927` native images were inspected
against the preceding identical cameras. Threshold, forest depth and ground
edges improve without occluding clues or the bridge. Retain the coherent pass;
full visual approval still fails for sparse/coarse foreground vegetation,
block-like route props, flat lighting and the unrepresented combat population
in this art fixture. Distant trees do not supply continuous horizon depth.
The previously passed actual-input route remains valid for unchanged physics,
interaction IDs and quest logic; it is not fresh graphical performance proof.
Current graphical activation remains red at 2,034.3 ms (capture 1,502.8 ms).

Current frames, `.release-gate/world001_wychwood_frame/`:

| View, suffix `20260927_204842.png` | SHA-256 |
|---|---|
| WORLD-013_01_Wychwood_Gate_Arch | 3bc300b83288db55e37c6861a141990160c654032490ae9180da29cd48ca3689 |
| WORLD-013_02_Wychwood_Clue_Route | e070888623715fa6091cadaffa255990b4eb492b979402706d9cfeb5efeaf640 |
| WORLD-013_03_Wychwood_Bridge_Canopy | 496b59443da479be16376b17f22c80df3602b011034ec6701bfbe1fb714872cd |
| WORLD-013_04_Wychwood_Combat_Clearing | 180ad6a306d32684c44bb7a173139def3a77064cb3e0d4421e31617438c8b074 |

## Running Steps / Next Action

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, launch the
installed Godot 4.6.3 Compatibility executable with `--path . --resolution
1280x720 --script res://tools/verify_opening_real_input_native.gd --
--wychwood-only`. Use a new isolated `APPDATA`/`LOCALAPPDATA` child profile under
`D:/Temp/AshenOath`; never edit the player's real saves or global environment.
For the fixed-camera art fixture use `capture_world_013.gd` with
`--output-dir=res://.release-gate/<new-run>` after `--`.

Next: resolve the shared full-scene construction/publication dependency before
more cosmetic passes or browser certification. Reuse unchanged clue, route,
physics and reviewed-camera evidence. A new structural performance candidate
must discriminate construction/submission work from first-visible driver work,
preserving exact final content; prior covered readiness/static merge/backend
trials remain rejected. No Web export while required native acceptance is red.
