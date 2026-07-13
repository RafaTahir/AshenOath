# Codex Production Workflow

Ashen Oath uses milestone-gated production releases. Ordinary implementation tickets verify locally and may create preview builds; they do not replace the public game automatically.

Production deploys happen only for an explicitly approved release milestone after the authoritative gate passes.

See `DEPLOYMENT_POLICY.md`.

Required ending steps for every implementation task:

1. Run all project verifiers.
2. Run `tools/verify_visible_quality.gd` when visual/gameplay presentation is relevant.
3. Export the single Godot Web build.
4. Sync `outputs/AshenOath_Web` into root-level `web/` for local or preview review.
5. Run `tools/verify_web_export.py`.
6. Record the result in `.release-gate/release_report.json`.
7. Commit to the active development branch when requested.
8. Push a preview branch when a browser review is required.

For an approved production milestone, also push `main`, wait for Vercel, and verify the live `index.pck` hash.

Use:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "short task summary"
```

For an approved production milestone only:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "MILESTONE-ID" -Summary "release summary" -Production -ApprovedMilestone
```

Do not describe the current public build as Alpha or production-ready. It remains a prototype until the Web Act One milestone passes.
