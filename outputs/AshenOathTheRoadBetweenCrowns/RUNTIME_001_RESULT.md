# RUNTIME-001 Result

## Scope

Made required runtime visual-role policy explicit. Approved roles must resolve
to their approved runtime assets without fallback. Unapproved required roles
remain playable only through an explicitly tagged diagnostic fallback so QA and
release tooling cannot mistake the current prototype visual for approval.

## Changes

- `scripts/asset_database.gd`
  - Preserves the curated role category during lookup so character/enemy
    requiredness is evaluated correctly.
  - Exposes `fallback_mode` through the runtime policy contract.
- `scripts/asset_spawn_helper.gd`
  - Records runtime role diagnostics and selected source metadata on each
    spawned visual.
  - Emits one warning per blocked role, keeps missing required assets fatal,
    and avoids silent primitive fallback for characters and enemies.
- `runtime_asset_manifest.json`
  - Declares `fallback_mode: none` for six approved runtime roles and
    `diagnostic_only` for the five blocked monster roles.
  - Declares fatal missing/unregistered policy rules.
- `tools/verify_runtime_required_components.py`
  - Validates the fallback-mode and fatal-policy rules.
- `tools/verify_runtime_asset_policy.gd`
  - Proves an approved Kael role and a diagnostic Ghoulkin fallback through
    the actual runtime spawner and node metadata.
- `tools/run_ticket_gate.ps1` and `tools/gate_profiles.json`
  - Register the native runtime asset-policy proof in the targeted `engine`
    profile so the fallback contract cannot be omitted from future ticket runs.
- `PROJECT_STATE.md`, `RECOVERY_004_IMPLEMENTATION_STATUS.md`, and the
  recovery registry record the checkpoint and its open visual limitations.

## Verification

- Editor/parser scan: PASS, exit code 0.
- `RUNTIME-001` component policy: PASS (23 components, 11 roles, 5 explicit
  visual fallbacks).
- `ASSET-005`: PASS (6 approved runtime roles, 5 explicit fallbacks).
- Native runtime asset policy: PASS.
- Targeted runner/profile registration: PASS (the new gate is selected by the
  `engine` profile and receives the runtime manifest/verifier inputs).
- Render-resource scan: PASS; no active renderer, null-material, RID, ObjectDB,
  or shutdown error matched in the check output.

The native policy verifier intentionally prints one warning for the blocked
Ghoulkin fallback. That warning is evidence of a release-blocking visual
fallback, not approval of the monster asset.

## Screenshots

None. This slice changes runtime policy metadata and diagnostics, not rendered
presentation. Existing visual evidence remains valid only for its recorded
scope and does not close the blocked monster visual gate.

## Limitations and remaining blockers

- Ghoulkin, Bog Wretch, Gravebound Knight, Ashwing, and White Hart remain
  explicitly diagnostic-only fallbacks pending their visual acceptance work.
- The broader visual, campaign, browser, performance, and production release
  gates remain open.
- No Web export, browser acceptance run, tracked `web/` update, push, or
  deployment was performed for this checkpoint.

## Running steps

```powershell
Set-Location D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $godot --headless --path . --editor --quit --audio-driver Dummy
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_runtime_asset_policy.gd
& $python tools/verify_runtime_required_components.py .
& $python tools/verify_asset_005.py .
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_render_resources.gd
```

The detailed logs are retained under `D:\Temp\AshenOath\`.

## Checkpoint

This result document is included in the local checkpoint commit. The
checkpoint is intentionally local-only; the development branch is not pushed
until the accumulated recovery work is ready for its next grouped acceptance
run.
