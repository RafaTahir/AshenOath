# Studio Recovery Tranche 001

## Scope

This tranche implements the first four actions from `ASHEN_OATH_MASTER_STUDIO_REVIEW.md` without claiming that the full roadmap is complete.

## Implemented

- Locked the Web-first 90-minute Act One and 4-6 hour campaign scope.
- Changed production deployment from every edit to explicit approved milestones.
- Added an authoritative release runner with JSON results, per-gate duration, logs, warnings, failure reason, commit identity, and targeted/full mode.
- Added content-integrity verification for quest definitions, unlocks, dialogue actions, and literal runtime objective references.
- Corrected stale dialogue and world objective IDs across Road of Crows, Bitter Roots, Widow's Bell, Black Dog, Teeth in the Rain, Blood Under Stone, and Hart content.
- Added persistent story flags to the Bitter Roots, Widow's Bell, and Black Dog dialogue choices.
- Consolidated the two Web export presets into one `Web Browser` production preset.
- Added `RuntimeServiceRegistry` as the first composition boundary outside `game.gd`.
- Updated project truth: current status is pre-alpha prototype and performance evidence remains provisional until a full gate passes.

## Verification

- `tools/verify_content_integrity.py`: pass.
- `tools/verify_runtime.gd`: pass.
- Headless dummy-renderer material diagnostics and post-pass teardown leaks are recorded as warnings in `release_reports/latest.json`; the graphical Compatibility gate still treats the same material error as fatal.
- Single-preset Web export: pass, 7 files / 69.5 MB.
- Packed startup: pass after five-second smoke launch; no parser, script-load, or missing-resource error.

## Not Yet Implemented

The art audition, asset curation, character replacement, navigation rewrite, combat reconstruction, and Greyfen rebuild are the next sequential tickets. They are not represented as completed work in this tranche.
