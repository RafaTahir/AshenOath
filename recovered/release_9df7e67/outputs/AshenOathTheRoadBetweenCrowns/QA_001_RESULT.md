# QA-001 - Structured Gate Protocol

## Result

Accepted for the release-runner protocol. This ticket does not approve a
release or convert any failing gameplay, visual, performance, or browser gate
to a pass.

## Changes

- The authoritative runner owns every child process, captures both output
  streams, preserves the real exit code, enforces a timeout, and records a
  failure if a descendant holds an inherited stream open.
- External and Godot-style gates both fail on nonzero exits, timeout, parser
  and resource diagnostics, and material/RID errors even after a PASS marker
  or shutdown phase. Structured reports, when requested, must exist, parse,
  and declare `pass`.
- Each gate result records status, duration, log, warning lines, explicitly
  labeled runner/verifier assertions, phase, failure, and owned-process exit
  metadata. Strict release-report validation rejects missing or unsuccessful
  owned-process evidence. Resumed legacy results retain a `legacy-report`
  owner and cannot masquerade as fresh strict evidence.

## Focused Verification

- `tools/verify_qa_001.py .`: PASS.
- Deliberate child fixtures: PASS for normal success, post-PASS material/RID
  failures, nonzero Python and batch exits, report failure/missing/malformed/
  statusless cases, timeout, and inherited output-stream timeout.
- Godot-style fixtures: PASS for success and rejection of post-PASS errors,
  nonzero exit, missing PASS marker, and timeout.
- PowerShell and Python parser checks and patch whitespace check: PASS.

## Limits And Next Work

Many legacy verifiers emit only a PASS marker. Their explicit assertion list
can be empty; the result labels runner checks separately rather than
pretending the verifier supplied detailed assertions. QA-002 and QA-003 still
own player-driven and visual acceptance. WORLD-001 remains visually rejected,
and PERF-001 last failed at 22.81 FPS average / 13.88 FPS 1% low. No Web
export, browser acceptance, commit, push, or deployment was performed here.

Run locally from the Godot project directory:

```powershell
& 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' .\tools\verify_qa_001.py .
```
