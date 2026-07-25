# Codex Production Workflow

Ashen Oath uses the credit-efficient WORKFLOW-002 pipeline. Read only the
roadmap context brief, the active ticket, and files directly implicated by that
ticket. Do not reread phase history or scan the full asset library.

## Tier 1: Development Loop

- Run parser/static checks first.
- Run only the active ticket's verifier after meaningful edits.
- Do not export, capture screenshots, synchronize `web/`, or deploy.
- Do not rerun a passing gate unless one of its inputs changed.
- Keep full output in `.release-gate/`; report concise pass/fail summaries.

## Tier 2: Ticket Completion

Ordinary tickets run on a `codex/roadmap-*` branch:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "short summary"
```

The script automatically selects gates from changed files, always includes
content integrity and a runtime smoke check, commits the checkpoint, and pushes
the development branch. It does not modify `web/` or production.

Use `-Profiles combat,ui` only to add explicit profiles. Use
`-ChangedViews greyfen,animation` for changed visual areas. Use `-ForceWeb`
only for browser/export-specific risk.

## Tier 3: Roadmap Milestone

After the complete roadmap tranche is merged to `main`:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "MILESTONE-ID" -Summary "release summary" -Production -RoadmapMilestone
```

This is the only mode that runs every verifier, full performance and screenshot
acceptance, Web export, packed startup, `web/` synchronization, `main` push,
Vercel polling, and live PCK comparison.

Do not describe the public build as Alpha or production-ready. It remains a
prototype until the Web Act One milestone passes.
