# Ashen Oath Deployment Workflow

## Pipeline

Ashen Oath uses this production path:

`Godot source project -> slim Godot Web export -> web/ -> GitHub -> Vercel`

This pipeline is mandatory after every successful Codex task unless the user explicitly writes `DO NOT DEPLOY`.

- Editable Godot project: `outputs/AshenOathTheRoadBetweenCrowns`
- Generated slim export: `outputs/AshenOath_Web_Slim`
- Deployable static folder: `web`
- Vercel config: `vercel.json`
- Production URL: `https://ashenoath.vercel.app/`

## One-Time GitHub Setup

If GitHub CLI is installed and authenticated later:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video"
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

The project includes `vercel.json`, which declares `web` as the output directory and keeps `index.html` from being aggressively cached.

## Daily Codex Workflow

After implementing a production ticket:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video"
.\scripts\deploy_web_update.ps1 -TicketId "TICKET-ID" -Summary "short task summary"
```

The script verifies, exports, syncs `web/`, commits, and pushes to `origin/main` by default. Vercel should deploy automatically after the repository has been connected once in the Vercel dashboard.

Only when the user explicitly writes `DO NOT DEPLOY`:

```powershell
.\scripts\deploy_web_update.ps1 -NoDeploy
```

The no-deploy path still verifies, exports, syncs, and verifies the web build, but skips commit and push.

## Manual Deploy

1. Run the deploy script with the ticket ID and summary.
2. Confirm `web/` contains `index.html`, `index.js`, `index.wasm`, `index.pck`, `index.png`, and worklet files.
3. Confirm the script committed and pushed to GitHub.
4. Check the Vercel dashboard for the production deployment if a deployment URL is not already configured locally.

## Avoiding Stale Browser Cache

- Hard refresh the browser after deployment.
- Use a cache-busting query string, for example:

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
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\web"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8787/index.html
```
