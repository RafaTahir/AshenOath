# ENGINE-004 — Resource Lifecycle Cleanup

## Status

Targeted lifecycle cleanup is complete on `codex/soul-rebuild`. Production
`main`, tracked `web/`, and Vercel were intentionally left unchanged.

## Changes

- Build-only terrain and authored-detail marker nodes are disposed immediately
  after their transforms are copied into `MultiMesh` batches.
- Final shutdown releases explicitly anchored skinned branches and the hidden
  retired-actor pool before clearing runtime caches.
- Final shutdown clears build-time batch arrays, shared procedural materials,
  and retired material anchors after staged zone retirement.
- Added `verify_engine_004.gd`, which exercises Greyfen, Wychwood, Castle
  Approach, Record Hall, and return through real zone lifecycle calls.
- The gate checks active effective materials, invalid geometry reports, cache
  ownership, retirement completion, stable fallback material identity, and
  final anchor cleanup.
- Added ENGINE-004 to the `engine` ticket profile.

## Verification

- `run_ticket_gate.ps1 -Profiles engine -NoCache`: PASS.
- `content_integrity`: PASS.
- `runtime_smoke`: PASS.
- `verify_engine_002`: PASS.
- `verify_engine_003`: PASS.
- `verify_engine_004`: PASS.
- `verify_qa_005.py --log .release-gate/ticket/verify_engine_004.log`: PASS.
- Fresh lifecycle logs contain no active `Parameter "material" is null`
  messages.

## Known limitation

Godot's isolated Compatibility/headless process still reports renderer
allocator/RID/ObjectDB diagnostics while the verifier process exits. QA-005
classifies these five messages as shutdown-only warnings after the pass marker;
they are not suppressed during active rendering. The remaining teardown
diagnostic is still a release-level cleanup item and is not claimed as solved
by this ticket.

## Running steps

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
$env:GODOT_BIN = 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& .\tools\run_ticket_gate.ps1 -Profiles engine -NoCache
```

## Evidence

- `.release-gate/ticket/verify_engine_004.log`
- `.release-gate/ticket/verify_engine_004.log.godot.log`
- `.release-gate/ticket/engine004_qa005.json`
