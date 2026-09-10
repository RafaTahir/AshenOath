# QUEST-001 Result

## Scope

Consolidated objective presentation around the selected quest and objective.
Quest progression remains owned by `QuestManager`; the presentation service is
now the single source for the displayed tracker title, action, grouped progress,
contextual text, and zone-aware fallback.

## Changes

- `scripts/quest_presentation_state.gd`
  - Replaced the borrowed all-active-quest tracker string with an authoritative
    formatter built from the selected view model.
  - Preserved group progress such as `0/3` and beat-directed next actions.
  - Kept the existing manual tracking, zone fallback, and completed-finale
    return-route behavior.
- `tools/verify_objective_view_model.gd`
  - Added a regression with Road of Crows and a concurrent side quest.
  - Verifies that the selected main route remains active and that the evidence
    transition retains its grouped progress without leaking the side-quest
    title.
- `PROJECT_STATE.md` and `RECOVERY_004_IMPLEMENTATION_STATUS.md`
  - Record the current native checkpoint and remaining release blockers.

## Verification

- Editor/parser scan: PASS, exit code 0.
- Objective view model verifier: PASS.
- Engine coordination verifier: PASS.

The engine route emits the existing explicit diagnostic warnings for
unapproved monster fallback roles. Those warnings are retained as release
evidence and are not treated as approval.

## Screenshots

None. This slice changes the objective presentation contract and its native
regression proof; it does not change world geometry or a camera composition.
The existing visual gallery remains subject to the broader visual gate.

## Limitations and remaining blockers

- Full real-input story progression and browser campaign acceptance remain
  open.
- Transient tutorial and combat hints are still separate by design and need a
  later UX pass to distinguish them from the tracked objective without visual
  conflict.
- Visual role approvals, world presentation, performance, and production
  release remain open.
- No Web export, browser acceptance run, tracked `web/` update, push, or
  deployment was performed.

## Running steps

```powershell
Set-Location D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --editor --quit --audio-driver Dummy
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_objective_view_model.gd
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_engine_005.gd
```

## Checkpoint

This result document is intended for the local development checkpoint only.
Production remains frozen until the full source-aligned export and player
acceptance sequence passes.
