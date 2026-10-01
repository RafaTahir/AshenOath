# WORLD-002 Undercroft Aftermath

Verdict: accepted scoped native story focal point, peaceful/destructive aftermath,
and real-input duel/choice/Save/Continue/door-return cells. **Not WORLD-002 ticket
acceptance.** Formal recovery remains 27/37; production is unchanged.

## Retained Changes

- `tools/build_undercroft_vault.gd` and its authored resource add a supported rear
  memorial niche to the existing second surface. Four tombs, ten rib piers, both
  door openings, roof collision and the physical combat lane remain unchanged.
- `scripts/undercroft_memorial.gd` owns the existing carved witness relief,
  three actual MultiMesh oath inlays and six votives. One story-state connection
  updates witness/release/destruction presentation; retirement disconnects it.
  No per-frame polling or extra local lights were added.
- `scripts/zones/campaign_finale_section.gd` attaches this stateful presentation.
  Existing Vargan door meshes replace the plain interior panels while preserving
  triggers, wall openings, arrivals and collision. Dynamic door publication is
  handled by the memorial's owned child-entered connection.
- The runtime manifest and scoped vault verifier track the changed resource.
  The capture fixture fingerprints the actual relief, door and memorial inputs.

Vault: 45,145 bytes, two surfaces, 3,172 triangles; SHA-256
`30d390d85e1cda811e8a59feabedf29205c0c9f6c3ea792ca1aae6505c0086b4`.
Growth is 4,753 bytes / 276 triangles, below the existing 100 KB cap.

## Accepted Evidence

Logs: `D:/Temp/AshenOath/undercroft_aftermath_20260930/`.

- `contract_state_owned_stdout.log`: clean exit 0; resource/hash/material checks,
  original floor/roof and 12 bidirectional capsule door sweeps, state-owned inlay
  colors, candle policy, dynamic authored door and signal retirement. Its direct
  isolated story fixture is unit evidence, not an earned-player route.
- `duel_choice_return_stdout.log`: clean graphical exit 0. A genuine pre-duel
  Continue physically approaches Halvern, parries, saves, continues, approaches
  and interacts, chooses testimony, saves/continues, crosses both door passages
  in both directions without jumping, travels to assembly and saves.
- `memorial_{preduel,witness,released,destroyed}_stdout.log`: clean graphical exits
  0. Copied genuine saved states provide eight current 1280x720 day/night frames.
  Original saved files were not altered. Cameras match the established room
  references. Codex inspected connected/supporting niche, aisle, speaker, mural,
  inscription, authored door, state-colored inlays and votive presence.

Frames and capture reports:
`.release-gate/world002_undercroft_memorial_{preduel,witness,released,destroyed}_20260930/`.

The pre-duel wall names the bound oath, without a vigil. Witness/release warm the
memorial, change its inscription and light the votives. Destruction leaves the
dark, unlit memorial. The empty aftermath dais/plain exit-panel defect is closed.

## Rejected Attempts And Limits

First material duplication failed because the decoration helper returns an
unpublished batch marker with a null material. A subsequent immutable batch
ignored state colors when published. Those logs/frames remain failed evidence;
the state-owner MultiMesh correction, not either earlier result, is retained.

No detailed moving windup/contact frame sequence, full scene/campaign, browser,
payload, FPS or total-memory approval is inferred. Native readiness observations
remain red: pre-duel 14,731.7 ms, real-route Undercroft 10,468.4 ms and assembly
1,497.7 ms. Cached observations are not controlled performance improvements.
PERF-001 remains parked; no performance investigation or export occurred.

## Exact Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, use stock Godot
4.6.3 at `D:/Temp/AshenOath/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe`.

1. Scoped contract: `--headless --path . --script res://tools/verify_undercroft_vault.gd`.
2. Real route: copy the unchanged earned pre-duel save into an isolated D: QA
   profile; set APPDATA/LOCALAPPDATA/TEMP/TMP only for that command. Run
   `--path . --script res://tools/verify_opening_real_input_native.gd -- --continue-halvern --undercroft-composition-proof`.
3. Changed views: use the corresponding copied earned save with
   `--path . --script res://tools/capture_pres_001.gd -- --continue-fixture --views=Undercroft_Day,Undercroft_Night --output-dir=res://.release-gate/<unique-folder> --reference-report=res://.release-gate/pres001_missing_interior_finale_20260930/capture_report.json`.

Source remains cumulative and uncommitted on `codex/masterpiece-rebuild`, HEAD
`5b530361a5aae8612626532287b5bd27d7b244b8`. No push, merge or deployment.
