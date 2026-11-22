# Ashen Oath Milestone Deployment Policy

The public build changes only at an explicitly approved roadmap milestone.

## Ordinary Tickets

- Work on `codex/roadmap-*`.
- Run the targeted ticket gate selected from changed files.
- Capture only changed views.
- Export locally only for browser, export-filter, runtime-resource, input, or
  audio-unlock risk.
- Commit and push the development branch.
- Never synchronize tracked `web/`, push `main`, or poll Vercel.

Command:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "short summary"
```

## Production Milestones

Milestone release must run from `main` after the approved roadmap branch is
merged:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "MILESTONE-ID" -Summary "release summary" -Production -RoadmapMilestone
```

The command runs the complete authoritative release suite, regenerates full
visual evidence, exports and verifies the Web package, synchronizes `web/`,
pushes `main`, waits for Vercel, and compares the live PCK hash.

Any failing gate stops the workflow. Production mode is rejected without
`-RoadmapMilestone`.

## Vercel

- Repository: `RafaTahir/AshenOath`
- Production branch: `main`
- Output: `web`
- URL: `https://ashenoath.vercel.app/`
- Runtime files must use `Cache-Control: no-cache, must-revalidate`.
