# Ashen Oath Milestone Deployment Policy

This repository protects the public build behind milestone acceptance. Development tasks verify and export locally by default. Production deployment requires explicit milestone approval.

## Required End-Of-Task Flow

After every successful implementation task:

1. Run all project verifiers.
2. Export the latest Godot Web build.
3. Synchronize the latest export into `web/`.
4. Verify the web build.
5. Write an authoritative machine-readable release report.
6. Keep the work on a development branch until its milestone is approved.

If any step fails, stop immediately and report the failing step. A failed gate may not be bypassed by relabeling the build.

## Standard Command

Use this command at the end of every task:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "short task summary"
```

This command verifies, exports, and syncs `web/` locally. It does not push production.

## Production Command

Use only after milestone review approval:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "MILESTONE-ID" -Summary "release summary" -Production -ApprovedMilestone
```

The script refuses production unless both production switches are present. It verifies the live PCK hash after Vercel publishes.

## Vercel Requirement

Vercel must be connected once through the Vercel dashboard:

- Git repository: `RafaTahir/AshenOath`
- Production branch: `main`
- Output directory: `web`
- Build command: empty/static
- Production URL: `https://ashenoath.vercel.app/`

After that, every successful push to `origin/main` should trigger a Vercel production deployment automatically.

## Cache Policy

Godot Web runtime filenames are stable. Vercel must serve `index.html`, `index.pck`, `index.js`, `index.wasm`, and audio worklet files with `Cache-Control: no-cache, must-revalidate` so the live game reflects new pushes quickly.
