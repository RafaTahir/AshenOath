# PROD-002 Issue Registry And Milestone Dashboard

## Status

Complete. This ticket changes production/QA documentation and narrowly scoped
workflow tooling only. Gameplay, zones, characters, imported assets, Web
output, Git history, and deployment were not changed by PROD-002.

## Files Added

- `PROD_002_ISSUE_REGISTRY.json` - canonical machine-readable registry.
- `PROD_002_MILESTONE_DASHBOARD.md` - generated readable dashboard.
- `tools/generate_prod_002_dashboard.py` - deterministic dashboard generator.
- `tools/verify_prod_002.py` - schema, status, cross-reference, count, and freshness verifier.

## Files Updated

- `tools/gate_profiles.json` - adds targeted `production` and `qa` profile wiring; existing QA-002 browser gates remain explicit and do not run for registry-only changes.
- `tools/run_ticket_gate.ps1` - invokes the Python PROD-002 verifier.
- `tools/run_release_gate.ps1` - validates the registry before an authoritative milestone release.
- `tools/verify_workflow_002.ps1` - checks PROD-002 profile selection and the current `verify_perf_001` release gate name.
- `RECOVERY_003_ISSUE_REGISTRY.md` - marks the historical report and screenshot gate rows fixed and points to the canonical registry.
- `CODEX_WORKFLOW.md` - documents registry ownership, commands, and profile behavior.

## Registry Snapshot

- 63 roadmap tickets.
- 27 complete.
- 34 planned.
- 2 blocked by external prerequisites.
- 15 tracked issues: 4 open, 2 accepted technical-debt items, and 9 fixed RECOVERY-003 issues.
- Baseline reviewed: `e7e00c1a08747ad390c8cde835247427d6a4bb6f`.

## Tests Run

- `python tools/verify_prod_002.py` - PASS.
- `python tools/generate_prod_002_dashboard.py --check` - PASS.
- `tools/run_ticket_gate.ps1 -DryRun -ChangedFiles outputs/AshenOathTheRoadBetweenCrowns/PROD_002_ISSUE_REGISTRY.json` - PASS; selected `production` only, with `content_integrity`, `runtime_smoke`, and `verify_prod_002`.
- `tools/verify_workflow_002.ps1` - PASS.

Runtime verifiers, screenshots, Web export, Web synchronization, commit,
push, Vercel polling, and live deployment were intentionally not run.
