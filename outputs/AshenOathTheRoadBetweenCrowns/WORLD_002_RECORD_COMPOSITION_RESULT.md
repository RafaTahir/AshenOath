# WORLD-002 Record Hall Composition

2026-09-28. Retained scoped improvement; WORLD-002 remains visually rejected
at complete campaign scope. No export, commit, push or deployment.

## Changes

Record Hall's wall/ceiling/floor vertices now carry metre UVs; the material
library alone applies its authored texture scale. The former extra 0.22 factor
made masonry oversized. The aisle and room floor share restrained stone rather
than a bright cobblestone road. The same twenty cabinets now use wider,
inward-facing native furniture with all 120 book groups. Skeletons, actors,
lights, collisions, interaction IDs, door arrivals and quest conditions remain.
The archive still has two surfaces and 65170 triangles. Its compressed asset
is 1251143 bytes, SHA256
a46e34a572782c122aef8547caf1fd3e714d128ca35927399d06fa0f88aa39d4.

## Evidence

D:/Temp/AshenOath/world002_record_composition_20260928 contains the bake,
resource contract, capture, physical route and source identities.

- contract_v2.log exits 0 cleanly: native sources/license/manifest/export,
  twenty cabinet bounds, central aisle and both arrival corridors, indexed
  nonnull surfaces and metre UVs pass. Initial contract.log correctly fails
  the old verifier's assumption that archive is the first manifest entry;
  lookup now uses its exact ID, without weakening any assertion.
- capture.log/capture.err exits 0 cleanly. Both source-frozen 1280x720 frames
  were inspected, not merely checked for exposure. Camera transforms exactly
  match the earlier PRES reference. Current frames are under
  .release-gate/world002_record_scale_20260928/.
- Day: mean luminance0.207429, 51 draws/72239 primitives, PNG SHA256
  b0b2d8870b90342ba1a1951ccb20e3d660adf7bfe5d4bae3eea59bde8b1bf08c.
  Night: mean0.179669, 57 draws/77167 primitives, PNG SHA256
  7cf811385b6c94d2f5305d8cacb055e8c4f36681ae58bc05cad689eb3de12a85.
  Variable actor poses/draw counts are not controlled performance comparisons.
- route.log/route.err exits 0 cleanly: genuine courtyard Continue, physical
  Record Hall door focus/E, arrival/manual save/Escape, return to courtyard,
  central arch crossing, west Approach return and manual save. Original save
  remains byte-identical. No teleport, flags or interaction handler shortcut.

## Limits And Next Action

This approves the scoped masonry/floor/archive change, not final room or
campaign art. Doorway presentation, sparse furnishing/atmosphere and broader
campaign composition remain incomplete. Staged capture has contextual objective
text from its prepared art state; it is not story progression evidence.
Transitions remain red: courtyard2187.5ms, Record Hall2947.5ms, courtyard
return1227.3ms; Approach81.9ms alone does not establish a whole timing pass.
No FPS, packed/browser or whole WORLD acceptance is implied.

Next independent STORY dependency: one uninterrupted New Game-to-ending native
route using the established physical input legs and actual carried inventory.
Keep the shared native PERF blocker explicit; no Web export while red.

## Running

Use Godot4.6.3 in this project, with child-only APPDATA/LOCALAPPDATA/TEMP/TMP
under D:/Temp/AshenOath. Run res://tools/verify_record_archive.gd headlessly.
For staged captures, run res://tools/capture_pres_001.gd with
--views=RecordHall_Day,RecordHall_Night, a unique res://.release-gate output,
and the preserved PRES reference report. For real routes, byte-copy the genuine
castle_evidence_v2_fixture save and use verify_opening_real_input_native.gd
--continue-record-hall --castle-return-proof. Never overwrite original evidence.
