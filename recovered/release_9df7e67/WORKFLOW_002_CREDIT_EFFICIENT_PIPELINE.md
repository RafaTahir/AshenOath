# WORKFLOW-002 Credit-Efficient Pipeline

## Purpose

Ordinary tickets no longer pay the complete production-release cost. Changed
files select a small verifier profile, results are cached locally, and detailed
logs stay on disk.

## Commands

Preview automatic selection without running tests:

```powershell
powershell -ExecutionPolicy Bypass -File outputs\AshenOathTheRoadBetweenCrowns\tools\run_ticket_gate.ps1 -DryRun
```

Run an ordinary ticket gate:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "summary"
```

Add changed visual areas:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "summary" -ChangedViews greyfen,animation
```

Force local Web proof only when necessary:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "summary" -ForceWeb
```

Release the completed roadmap milestone from `main`:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "MILESTONE-ID" -Summary "summary" -Production -RoadmapMilestone
```

## Profiles

- `combat`: motion, combat, AI, and Oathfire.
- `world`: visible quality and zone budgets.
- `navigation`: builders, gates, navigation, and river safety.
- `story`: campaign and quest progression.
- `ui`: runtime regressions and UI.
- `audio`: audio runtime and presentation.
- `assets`: asset instantiation, characters, and visible quality.
- `web`: export, Web package, and packed startup.

All profiles include content integrity and a lightweight runtime startup check.
Cached passes invalidate when the active commit, changed file contents, or gate
script changes.

Full logs: `outputs/AshenOathTheRoadBetweenCrowns/.release-gate/`

Local cache: `outputs/AshenOathTheRoadBetweenCrowns/.verification-cache/`
