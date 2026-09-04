# RECOVERY-003 Result

## Status

Partial recovery checkpoint. The atomic route/lifecycle fix below is committed
locally on `codex/masterpiece-rebuild`; the broader recovery changes remain in
the working tree and are not pushed or deployed. Production remains unchanged.
The current performance continuation is intentionally uncommitted because its
direct acceptance gate still fails.

## Current Atomic Checkpoint

- Current atomic work: `QA-002` browser-route stabilization for the Anwen
  approach and dialogue interaction. The broader recovery remains paused with
  `PERF-001` as the next documented blocker.
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
- Current continuation: `game.gd` now invalidates interaction focus on movement,
  camera turns, zone changes, quest changes, and trigger entry/exit, and caches
  compass scans while the player and objective are unchanged. This reduces
  repeated idle raycasts and marker scans without changing interaction rules.
- Latest continuation result: the targeted graphical `performance` profile
  completed and parsed the updated runtime, but failed its real threshold in
  Greyfen: `43.17 FPS` average and `28.06 FPS` 1% low from five `34-37 ms`
  frames. Wychwood measured `56.23 FPS` average / `31.67 FPS` 1% low and
  Wychwood combat measured `55.98 / 40.80`; the remaining zones passed.
- Remaining blocker: the broader recovery is still incomplete; the current
  Greyfen 1% low failure remains unresolved, in addition to visual acceptance,
  source-aligned Web export, target-hardware performance, and production browser
  evidence remaining open.
- Exact next action on resume: continue this same `PERF-001` frame-pacing fix by
  isolating the recurring Greyfen update burst, make the smallest gameplay-safe
  optimization, and rerun only the graphical performance profile. Do not create
  a checkpoint commit, export, push, deploy, or start another recovery ticket
  until that gate passes.

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
- Native target-hardware performance and cold startup targets remain open.
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
