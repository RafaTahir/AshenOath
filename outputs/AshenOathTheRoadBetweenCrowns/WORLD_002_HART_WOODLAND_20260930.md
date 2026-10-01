# WORLD-002 Hart Woodland Frame And Depth

## Decision

Retain the finite native woodland-frame, horizon and clearing-depth correction.
This does not accept the whole Hart encounter, assembly, WORLD-002, performance
or browser candidate. Formal recovery remains 27/37. Existing earned covenant,
aftermath meshes, actor population, floor/collision, routes and choices remain.

## Implementation

- `scripts/hart_woodland.gd` owns authored adjoining terrain and grounded tree
  positions together. It joins the actual moss-floor edge at +/-22.5 x and
  +/-19.5 z, leaving the physical arena and central return aisle untouched.
- Thirty-two staggered retained CC0 tree instances (twenty in Potato) replace
  the smooth generic far-terrain presentation. Existing near trees are not
  removed. No collision, local light, processing loop or additional texture.
- Six fitted source-native CC0 Fern_1 assemblies replace the rejected generated
  leaf shapes. They remain beyond x +/-10, away from the battle/return sightline.
- `tools/build_hart_woodland.gd` produces a 55,293-byte, two-surface, 2,432-triangle
  mesh. SHA-256:
  `26cb52dc8248328a0bead4fb0629ee0638eb964b71ba79570ccdb12717a8525f`.
  Actual fern source checksum is embedded. Campaign export ownership is explicit;
  no Web export was run. Existing focal stones and all four aftermath hashes
  remain unchanged.

## Evidence And Limits

- `D:/Temp/AshenOath/hart_woodland_20260930/contract_native_fern_stdout.log`:
  graphical native exit 0. Materials, correct front-face normals, complete
  instance population, ground joins, grounded roots, geometry/byte budgets,
  central clearance and resource retirement pass. Only Intel ANGLE advisory.
- Headless instance readback returned identity transforms and is invalid for
  that question. The scoped verifier now requires the graphical renderer;
  no fabricated headless tree-placement proof is accepted.
- The initial bake correction referenced a leaf-loop variable in the terrain
  loop and failed parsing. It was corrected before any accepted run. Initial
  generated leaves passed geometry but failed gameplay-camera review as
  provisional triangular shapes; those frames are diagnostic only.
- The first capture placed the earned save in an incorrect APPDATA subdirectory.
  It failed missing-save JSON parsing and was safely stopped (only owned PIDs).
  The fixture now fails explicitly on missing/invalid saves; no game behavior
  changed. Corrected invocation copies the unchanged earned Mercy save into
  the actual isolated `APPDATA/Godot/app_userdata` slot. SHA remains
  `5ce845b0398dc8b8e60c54b5a2916894e55aca7d92f64efb033fe1579d12957c`.
- `.release-gate/world002_hart_woodland_native_fern_20260930/`: both established
  1280x720 day/night frames inspected, same reference camera. Native plants,
  woodland layers, supported roots, memorial and unobstructed central approach
  remain readable; no smooth wall or exposed world edge dominates the frame.
  Capture exits 0 without resource/renderer errors. Report records actual inputs.
- Staged time/camera art review is not real-input travel or earned-ending proof.
  Those unaffected earlier cells remain valid at their scope. Readiness 1342.2 ms
  still exceeds transition acceptance; this is not a controlled FPS/memory run.

## Exact Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, use stock
Godot 4.6.3 at `D:/Temp/AshenOath/godot-4.6.3/`:

1. Bake: `--headless --path . --script tools/build_hart_woodland.gd`.
2. Actual instance check: `--path . --script tools/verify_finale_composition.gd -- --hart-woodland-only`.
3. Copy the original earned Mercy checkpoint into a D: profile's actual
   `APPDATA/Godot/app_userdata/Ashen Oath- The Road Between Crowns/` manual slot;
   APPDATA is `<profile>/AppData/Roaming`, not the profile root.
4. `--path . --script tools/capture_pres_001.gd -- --continue-fixture --views=Hart_Day,Hart_Night --output-dir=res://.release-gate/<unique> --reference-report=res://.release-gate/pres001_missing_interior_finale_20260930/capture_report.json`.

No commit, push, merge, deployment or production change. Freeze this cell;
continue the existing Bandit Road broad clearing/horizon cell, not Hart polish.
