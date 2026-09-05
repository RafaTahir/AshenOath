# RECOVERY-003 Result

## Status

Release continuation in progress. The complete release tail has now passed
locally on `codex/masterpiece-rebuild`, including fresh screenshots, packed
startup, desktop Chrome/Edge, mobile emulation, and the full consolidated
browser route. Production remains unchanged until the source checkpoint,
strict report identity, Web synchronization, and live hash check complete.

The release runner bookkeeping was corrected so PowerShell and Python compute
the same source fingerprint and expected fresh screenshot/report writes do not
masquerade as uncommitted runtime source. The current worktree still contains
the cumulative Recovery-003 changes and has not yet been checkpointed.

## Current Atomic Checkpoint

- Current atomic work: reduce the Greyfen first-render cost introduced by
  immediate cemetery landmarks in the `opening_fast` profile while preserving
  the complete full-detail cemetery build. The broader recovery remains
  paused; no next recovery ticket has been started.
- Completed fix: `CemeterySection.build()` now accepts a compact opening mode.
  Fast Greyfen keeps its cemetery staging markers, route geometry, collision,
  bell, shrine, chapel, and interactions, while deferring loose edge trees,
  fog, and decorative authored presentation meshes. The normal full build
  still emits the complete cemetery presentation.
- Latest atomic result: the focused cemetery route gate passed, and the
  graphical Compatibility performance gate passed all sampled zones. Greyfen
  measured `51.6 FPS` average and `31.1 FPS` 1% low; Wychwood `60.0/51.0`,
  Wychwood combat `60.0/40.4`, Castle courtyard `60.0/52.3`, Record Hall
  `44.1/38.4`, and Hart Glade `60.0/55.6`. The direct graphical run exited
  with code 0 and printed `PERF-001 VERIFIER: PASS`.
- Evidence: `.release-gate/perf_001_report.json`, the waited graphical-run
  result in the task log, and the targeted cemetery gate log.
- Completed fix: the browser route harness now uses camera-relative movement,
  request-scoped QA command results, progress-based key rearming, and the
  normal rendered dialogue action path. It records route checkpoints without
  mutating the player transform or story state.
- Latest atomic result: the focused Chrome probe passed with 9 checkpoints in
  `313951 ms`; it reached Greyfen, focused Anwen at `3.214 m`, completed her
  dialogue, and reported zero console, network, JavaScript, WebAssembly, or
  Godot runtime errors. The exact evidence is
  `.release-gate/qa_002/anwen-probe.json`.
- Browser isolation result: the profile was created under
  `D:\Temp\AshenOath` and removed after the pass. No browser profile was left
  outside the project QA temp root.
- Completed fix: the player route driver now advances on physics frames, stops at an
  inset sector boundary before outward travel, and stops steering when the
  authoritative sector changes. `QUEST-012` now finalizes each ending fixture and
  emits the shutdown phase before exit.
- Latest result: direct graphical `QA-012` passed the opening route, five-enemy
  Wychwood encounter, Greyfen return/report, every released exterior boundary,
  Castle approach/courtyard/Record Hall round trip, and the final return to Greyfen.
  The clean `story` ticket profile also passed, including `verify_quest_012`, with
  no active renderer/resource failure.
- Completed fix: `verify_world_002.gd` now prepares and finalizes the game root,
  emits `VERIFIER_PHASE: SHUTDOWN`, retires the root, synchronizes rendering,
  and only then prints its final result and exits. This keeps active-render
  failures fatal while classifying orderly teardown correctly.
- Latest atomic result: the authoritative single-gate run passed
  `verify_world_002` in `7.76 s` with `nodes=420`, `meshes=73`, `lights=2`, and
  `enemies=5`; the log ends with the shutdown phase followed by `WORLD-002
  VERIFIER: PASS`. Evidence: `.release-gate/verify_world_002.log`.
- Latest focused result after the initial checkpoint: normal full-detail
  `WORLD-014` now passes at `1,075` nodes and `338` meshes after the retained
  grave-row and crow-roost decoration was moved onto the existing static visual
  batching path. The compact opening profile remains unchanged.
- Latest graphical Compatibility result: `verify_perf_001` passes on a clean
  run. Greyfen measured `52.85 FPS` average and `32.87 FPS` 1% low; Wychwood
  `59.99/49.96`; Wychwood combat `60.02/45.01`; Castle courtyard
  `60.00/53.18`; Record Hall `45.93/38.61`; and Hart Glade `60.00/56.43`.
  The run exited with code 0 and printed `PERF-001 VERIFIER: PASS`.
- Remaining blocker: the authoritative recovery/release suite has not yet been
  rerun against this current source. Fresh screenshots, Web packaging, packed
  startup, browser proof, push, and deployment remain open.
- Exact next action on resume: run the authoritative suite from the next
  unfinished gate, preserving already-passed results where the runner can
  safely do so; stop on the first genuine failure and record it.

## Completed In This Checkpoint

- Added `ObjectiveViewModel` as the single shaped presentation result for
  tracked quest, objective, next action, tracker text, and contextual text.
- Added explicit manual tracked-quest persistence and zone-aware fallback in
  `QuestManager`.
- Routed HUD and zone refresh through the objective view model while keeping
  QuestManager as the progression authority.
- Fixed the procedural property helper so decorative batched props do not
  create unowned collision shapes or mesh instances.
- Added explicit owned game timers and cancellation during resource shutdown.
- Added staged renderer-resource release before retired zone disposal.
- Made lifecycle and save verifiers exercise finalization instead of leaving
  test-only owners behind.
- Added a bounded watchdog and deterministic teardown to the legacy quest
  harness. It remains diagnostic because it uses direct interaction calls.
- Removed temporary API and lifecycle probe scripts.
- Preserved imported head and hair transforms when composing the Universal
  humanoid layers, so native face geometry stays fitted to the body skeleton.
- Removed primitive player and enemy anatomy fallbacks. A missing required
  character or enemy visual now fails explicitly instead of shipping a capsule,
  sphere, or procedural Hart substitute.
- Refined the Oathblade mesh while keeping its real hand socket and existing
  combat animation contract.
- Corrected the retained monster mapping expectations for Skeleton, Bat, and
  Dragon source families.
- Disabled Anwen's duplicate imported staff and kept one compact hand-socket
  staff. The portrait capture now selects exact standing `Idle` clips instead
  of accidentally selecting `Crouch_Idle`.
- Replaced the remaining anonymous audio timers with owned timers that are
  cancelled during audio shutdown, and corrected `AUDIO-001` to assert the
  RiverSection contract of two bank approach ramps.

## Verification

| Gate | Result | Evidence |
|---|---|---|
| `verify_engine_003.gd` | PASS | `.release-gate/engine003_current.log` |
| `verify_engine_004.gd` | PASS | `.release-gate/engine004_current.log` |
| `verify_save_003.gd` | PASS | `.release-gate/save_003_final.log` |
| `verify_narr_005.gd` | PASS | `.release-gate/narr_005_current.log` |
| `verify_objective_view_model.gd` | PASS | `.release-gate/objective_view_model_current.log` |
| `verify_quest_001.gd` | PASS, diagnostic only | `.release-gate/quest_001_clean.log` |
| `verify_visible_quality.gd` | PASS, clean active-render stream | `D:\Temp\AshenOath\verify_visible_quality_after_cleanup.log` |
| `combat + assets + engine` ticket gate | PASS | `D:\Temp\AshenOath\recovery003_targeted_gate.log` |
| `audio` ticket gate | PASS | `D:\Temp\AshenOath\recovery003_audio_gate_fixed.log` |
| Character portrait capture | PASS, 12 fresh 1280x720 frames | `D:\Temp\AshenOath\character_portraits_standing.log` |
| `QA-012` graphical real-input route | PASS | `.release-gate/ticket/verify_qa_012.log` |
| `story` ticket profile | PASS | `.release-gate/ticket/verify_quest_012.log` and ticket-gate output |
| `performance` ticket profile after cache fix | FAIL | `.release-gate/ticket/verify_perf_001.log` |
| `verify_world_003.gd` after compact cemetery change | PASS | `.release-gate/verify_world_003.log` |
| Graphical `verify_perf_001.gd` after compact cemetery change | PASS | `.release-gate/perf_001_report.json` and waited graphical-run result |
| Normal full-detail `verify_world_014.gd` | PASS, 338 meshes <= 340 budget | direct graphical-independent run |

The clean lifecycle run contains no leaked renderer resources, leaked ObjectDB
nodes, or leaked SceneTree timers. The visible-quality and audio runs now complete without
the previous `Parameter "material" is null` diagnostic. Godot may still print
one shutdown-only unclaimed `timeout` StringName in the legacy fixture runs;
that notice is documented rather than suppressed.

## Remaining Blockers

- Visual acceptance is improved for the Universal human composition, but the
  captured monster families remain stylized/provisional and the world remains
  largely procedural. This is not a final visual approval.
- The portrait gate proves the selected standing clips and body resources; it
  does not replace gameplay-distance review of sword draw, attacks, dialogue,
  or every crowd recipe.
- The legacy quest harness remains diagnostic because it uses direct interaction
  calls; the real-input `QA-012` campaign route now passes and remains the required
  player-route evidence.
- Fresh source-aligned Web export, packed startup, and production browser
  verification were not run after this source change.
- Native target-hardware performance and cold startup targets remain open beyond
  this focused sample; the current graphical Compatibility sample itself now
  passes its configured thresholds.
- The normal full-detail cemetery presentation still exceeds the independent
  `WORLD-014` mesh budget by 13 meshes.
- The local checkpoint commit is not pushed; no `main` promotion or Vercel
  deployment occurred.

## Exact Local Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
$env:GODOT_BIN = "C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe"
& $env:GODOT_BIN --headless --path . --script res://tools/verify_engine_003.gd
& $env:GODOT_BIN --headless --path . --script res://tools/verify_engine_004.gd
& $env:GODOT_BIN --headless --path . --script res://tools/verify_save_003.gd
& $env:GODOT_BIN --headless --path . --script res://tools/verify_objective_view_model.gd
$env:GODOT_GRAPHICAL_BIN = "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64.exe"
Start-Process -FilePath $env:GODOT_GRAPHICAL_BIN -ArgumentList @('--path',(Get-Location).Path,'--rendering-method','gl_compatibility','--script','res://tools/capture_character_real_portraits.gd') -WorkingDirectory (Get-Location).Path -Wait
pwsh.exe -NoProfile -Command "& '.\tools\run_ticket_gate.ps1' -Profiles @('combat','assets','engine') -TimeoutSeconds 240"
```
```
