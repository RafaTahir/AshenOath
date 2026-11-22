# Ashen Oath Deployment Workflow

## Pipeline

Ashen Oath uses this production path:

`Godot source project -> slim Godot Web export -> web/ -> GitHub -> Vercel`

This pipeline runs only for approved roadmap milestones. Ordinary tickets use
targeted verification and a development-branch checkpoint; they do not export
unless Web-specific risk requires it.

- Editable Godot project: `outputs/AshenOathTheRoadBetweenCrowns`
- Generated export: `outputs/AshenOath_Web`
- Deployable static folder: `web`
- Vercel config: `vercel.json`
- Production URL: `https://ashenoath.vercel.app/`

## QA Build Boundary

The repository contains two Web presets by design: `Web Browser` is the
production candidate and `Web QA Browser` is a disposable local test build.
Only the QA preset carries the `ashenoath_qa` feature flag and browser telemetry
commands. Never upload `.release-gate/AshenOath_QA` or expose `?qa=1` on the
production candidate. `tools/verify_security_001.py` is the static boundary
check used before a milestone release.

## One-Time GitHub Setup

If GitHub CLI is installed and authenticated later:

```powershell
cd "D:\Projects\AshenOath"
gh repo create ashen-oath --private --source . --remote origin --push
```

Manual setup without GitHub CLI:

1. Create a private GitHub repository named `ashen-oath`.
2. From this workspace, run:

```powershell
git remote add origin https://github.com/YOUR_ACCOUNT/ashen-oath.git
git branch -M main
git push -u origin main
```

Do not paste tokens into files. Use normal GitHub browser login, Git Credential Manager, or GitHub CLI auth.

## One-Time Vercel Setup

Because Vercel CLI is not currently installed/authenticated in this workspace, use the dashboard:

1. Go to Vercel.
2. Add New Project.
3. Import the GitHub repo.
4. Framework preset: Other or static.
5. Build command: leave empty unless Vercel requires one.
6. Output directory: `web`.
7. Deploy.
8. Production URL: `https://ashenoath.vercel.app/`.
9. Future pushes to `main` update production automatically.

The project includes `vercel.json`, which declares `web` as the output directory. Godot Web runtime files use stable names, so `index.html`, `index.pck`, `index.js`, `index.wasm`, and worklet files must always revalidate instead of using long-lived browser cache.

## Daily Codex Workflow

After implementing an ordinary ticket on `codex/roadmap-*`:

```powershell
cd "D:\Projects\AshenOath"
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "short task summary"
```

The script selects affected gates, uses cached passes when inputs are unchanged,
and commits/pushes the development branch. It does not modify `web/`.

For an approved production milestone:

```powershell
.\scripts\deploy_web_update.ps1 -TicketId "MILESTONE-ID" -Summary "release summary" -Production -RoadmapMilestone
```

Only milestone mode runs the full suite, complete gallery, export, packed
startup, `web/` synchronization, `main` push, and Vercel verification.

## Manual Deploy

1. Run the deploy script with the ticket ID and summary.
2. The script launches the exported `index.pck` through Godot to catch omitted scripts and preload failures before deployment.
3. Confirm `web/` contains `index.html`, `index.js`, `index.wasm`, `index.pck`, `index.png`, and worklet files.
4. Confirm the script committed and pushed to GitHub.
5. Check the Vercel dashboard for the production deployment if a deployment URL is not already configured locally.

## Avoiding Stale Browser Cache

- Runtime files are configured with `Cache-Control: no-cache, must-revalidate`.
- After deployment, verify the live headers:

```powershell
Invoke-WebRequest -Uri "https://ashenoath.vercel.app/index.pck?v=cache-check" -Method Head -UseBasicParsing
```

The `Cache-Control` header must include `no-cache` or `must-revalidate`, not `max-age=3600`.

- A cache-busting query string can still be used while testing:

```text
https://ashenoath.vercel.app/?v=ticket-id
```

- For public release notes, include a visible version tag or ticket ID.

## Do Not Commit

- Secrets or `.env` files.
- Raw downloads and archives.
- Screenshots or `Development_Gallery`.
- Old non-slim exports under `outputs/AshenOath_Web` or `outputs/AshenOath_Web_Slim`.
- Godot `.godot` import cache.

## Local Web Test

```powershell
cd "D:\Projects\AshenOath\web"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8787/index.html
```
