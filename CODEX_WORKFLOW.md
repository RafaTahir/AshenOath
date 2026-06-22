# Codex Production Workflow

For future Ashen Oath production tickets, the work is not complete until the playable web path is updated, committed, pushed, and handed to Vercel for production deployment.

Permanent rule: deploy after every successful task unless the user explicitly writes `DO NOT DEPLOY`.

See `DEPLOYMENT_POLICY.md`.

Required ending steps for every successful task:

1. Run all project verifiers.
2. Run `tools/verify_visible_quality.gd` when visual/gameplay presentation is relevant.
3. Export the slim Godot Web build.
4. Sync `outputs/AshenOath_Web_Slim` into root-level `web/`.
5. Run `tools/verify_web_export.py`.
6. Commit all relevant changes with the ticket ID and summary.
7. Push to `origin/main`.
8. Wait for push completion.
9. Confirm the commit hash and push success.
10. Confirm Vercel will auto-deploy from `origin/main`.
11. Report the production URL: `https://ashenoath.vercel.app/`.

Use:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "short task summary"
```

Only when the user explicitly writes `DO NOT DEPLOY`, use:

```powershell
.\scripts\deploy_web_update.ps1 -NoDeploy
```

Do not commit secrets, raw downloads, screenshot galleries, old non-slim exports, or Godot import caches.
