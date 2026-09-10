# REL-TRUTH-001 Result

## Status

Verified as a tooling checkpoint. This ticket does not approve production.

## Changes

- Added report schema 3 identity fields and verification revision metadata.
- Included the recovery issue registry in the source fingerprint.
- Recorded the registry hash, identity, schema, and category statuses in every
  report.
- Made a missing or unreadable registry a release blocker.
- Made reported blockers compare against the current registry categories.
- Fixed the release-resume repository-path typo.
- Required named log entries for recorded passing gates.

## Verification

- PowerShell AST parse of `tools/run_release_gate.ps1`: pass.
- Python compile of `tools/verify_release_report.py`: pass.
- `git diff --check`: pass.
- Existing stale `release_reports/latest.json`: correctly rejected.

## Limitations

The current source still has unresolved visual, campaign, performance, and
release blockers. No export, push, merge, or deployment was performed for this
tooling-only checkpoint.

## Running steps

```powershell
cd D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
powershell -ExecutionPolicy Bypass -File .\tools\run_release_gate.ps1 -Only <gate>
```
