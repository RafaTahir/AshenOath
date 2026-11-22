# WORLD-001 Grounded Ghoulkin

Decision: retain the authored body; accept the finite occupied-encounter body
and day/night readability cells at native scope. WORLD-001 remains incomplete.
Formal recovery stays 27/37. No Web export or production change occurred.

## Implementation

- Replaced the flying Ghost mapping only for `ghoulkin_creature` with a
  purpose-authored derivative of the retained CC0 Universal full-body mesh.
  Native connected anatomy is sculpted around its skin bones: gaunt limbs,
  forward-curled torso/head and elongated fingers. A sewn, torn burial shroud
  is skinned into the same surface, not attached as proxy anatomy.
- Retained the 65-bone bind contract, non-root-motion UAL2 library, actor ID,
  physics, health, attack timing, quests and five-enemy population. Movement,
  attack, hit and death now use the matching grounded animation clips.
- `tools/build_grounded_ghoulkin.py` produces one 14,570-triangle surface and
  one 1024x1024 atlas. GLTF/bin/PNG total 870,890 source bytes; Web size is not
  yet measured. `GROUNDED_GHOULKIN_MANIFEST.json` records source/license/hashes.
- Updated affected role, runtime and family mappings. Other monster bodies,
  humans, equipment and story content are unchanged.

## Evidence

- Godot 4.6.3 import: exit 0, no parser/resource errors.
- `tools/verify_mon_002.gd -- --ghoulkin-only`: exit 0; complete rig, required
  clips, skinned surface and active material pass. This is structural proof.
- Existing day/night camera batch: exit 0, two fresh 1280x720 frames inspected
  under `.release-gate/world001_grounded_ghoulkin_floor_20260930/`.
  Connected lower body, shroud silhouette and grounded feet are visible; night
  actor silhouette remains readable. No ordinary-villager shirt/body mapping.
- Corrected the staged art fixture's erroneous fixed 0.8m actor elevation with
  its actual physical floor hit. Camera and environment remain unchanged.
  Earlier elevated captures are diagnostic only, not grounding approval.
- Actual graphical New Game, bridge, Anwen dialogue, Wychwood arrival, three
  clues and five-enemy fight pass. Combat finished with all five kills and
  Kael at 120/125 health. The captured live Ghoulkin hit frame reports
  `grounded=true` and was inspected. No forced combat state or story mutation.

## Remaining Failure

The complete route command exited 1: return movement timed out while Greyfen
was active but transition-pending/input-locked. Recorded playable handoff was
733.2ms. No material, renderer, resource or collision error occurred; ANGLE's
known driver-selection warning remains classified. This is not a successful
full return/report run or FPS acceptance. No timeout/threshold was relaxed.

Raw logs and actual hit frame: `D:/Temp/AshenOath/ghoulkin_authored_20260930/`.

## Running Steps

Use the canonical Godot project on D:. Build with the bundled Python:
`tools/build_grounded_ghoulkin.py`, then import with Godot `--editor --import`.
Run `--script tools/verify_mon_002.gd -- --ghoulkin-only` for the affected
structural contract. Graphical capture uses `tools/capture_world_013.gd --
--arena-review`; actual route uses `tools/verify_opening_real_input_native.gd
-- --wychwood-only --ghoulkin-motion-proof`. Set process-local APPDATA,
LOCALAPPDATA, TEMP and TMP under `D:/Temp/AshenOath`; do not change global values.

Freeze this accepted body cell. Next WORLD-001 work is the existing coherent
Greyfen boundary/street and shared cemetery horizon contract, not further
Ghoulkin auditions or one-prop polishing.
