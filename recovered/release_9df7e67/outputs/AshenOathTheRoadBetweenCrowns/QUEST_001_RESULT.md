# QUEST-001 Result

## Scope

Consolidated objective presentation around the selected quest and objective.
Quest progression remains owned by `QuestManager`; `ObjectiveViewModel` is now
the single source for tracker, compass, interaction priority, quest-direction
guidance, and save-slot summary presentation.

## Changes

- `scripts/quest_presentation_state.gd`
  - Replaced the borrowed all-active-quest tracker string with an authoritative
    formatter built from the selected view model.
  - Preserved group progress such as `0/3` and beat-directed next actions.
  - Kept the existing manual tracking, zone fallback, and completed-finale
    return-route behavior.
- `scripts/objective_view_model.gd`
  - Added authoritative compass text and a derived, non-mutating save summary.
- `scripts/interaction_focus_service.gd` and `scripts/runtime_service_registry.gd`
  - Focus resolution now consumes the selected quest/objective from the same
    presentation view instead of independently walking quest state.
- `scripts/game.gd`
  - Compass target distance retains the authored next-action wording.
  - Quest-direction hints now use the current objective view. Immediate combat,
    control, blocked-action, and stamina feedback remain transient by design.
- `tools/verify_objective_view_model.gd`
  - Added a regression with Road of Crows and a concurrent side quest.
  - Verifies that the selected main route remains active and that the evidence
    transition retains its grouped progress without leaking the side-quest
    title.
  - Verifies focus priority and save-summary identity against the selected view.
- `tools/verify_quest_001_runtime.gd`
  - Boots the actual Greyfen runtime and verifies rendered tracker, compass,
    Anwen prompt/focus, and save payload agreement.

## Verification

- Editor/parser scan: PASS, zero parse/load errors.
- Objective view model verifier: PASS.
- QUEST-001 live Greyfen runtime verifier: PASS.
- Engine coordination verifier: PASS.
- Quest tracker 720p/1080p layout verifier: PASS.

The engine route emits the existing explicit diagnostic warnings for
unapproved monster fallback roles. Those warnings are retained as release
evidence and are not treated as approval.

## Screenshots

None. This slice changes the objective presentation contract and its native
regression proof; it does not change world geometry or a camera composition.
The existing visual gallery remains subject to the broader visual gate.

## Limitations and remaining blockers

- Full real-input campaign progression and production-browser certification
  remain owned by `STORY-001`, `CERT-001`, and `RELEASE-001`.
- The broader `verify_save_003.gd` fixture still reports its existing invalid-
  position grounding failure. The QUEST-001 save-summary assertion passes;
  spatial save recovery remains owned by `SAVE-001`.
- Transient combat/control hints remain separate from quest direction by design.
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
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_quest_001_runtime.gd
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_engine_005.gd
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_quest_tracker_layout.gd
```

## Checkpoint

This result document is intended for the local development checkpoint only.
Production remains frozen until the full source-aligned export and player
acceptance sequence passes.
