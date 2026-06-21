# Ashen Oath Permanent Deployment Policy

This repository is production-first.

Every future Codex task must end with a full deployment to production unless the user explicitly writes:

```text
DO NOT DEPLOY
```

## Required End-Of-Task Flow

After every successful task:

1. Run all project verifiers.
2. Export the latest Godot Web build.
3. Synchronize the latest export into `web/`.
4. Verify the web build.
5. Commit all relevant changes with the current ticket ID and summary.
6. Push to `origin/main`.
7. Wait for the push to complete.
8. Confirm the commit hash.
9. Confirm the push succeeded.
10. Confirm Vercel will auto-deploy from `origin/main`.
11. Report the production URL when configured.

If any step fails, stop immediately and report the failing step. Never claim deployment succeeded unless the push completed.

## Standard Command

Use this command at the end of every task:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "short task summary"
```

This command verifies, exports, syncs `web/`, commits, and pushes by default.

## Explicit No-Deploy Command

Only use this when the user explicitly writes `DO NOT DEPLOY`:

```powershell
.\scripts\deploy_web_update.ps1 -NoDeploy
```

This still runs verification, export, sync, and web verification, but it does not commit or push.

## Vercel Requirement

Vercel must be connected once through the Vercel dashboard:

- Git repository: `RafaTahir/AshenOath`
- Production branch: `main`
- Output directory: `web`
- Build command: empty/static

After that, every successful push to `origin/main` should trigger a Vercel production deployment automatically.
