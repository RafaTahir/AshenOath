# DEPLOY-001 GitHub + Vercel Workflow

## Repo Status

- Workspace root: `C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video`
- Godot source project: `outputs/AshenOathTheRoadBetweenCrowns`
- Slim export source: `outputs/AshenOath_Web_Slim`
- Deployable static folder: `web`
- Git status before ticket: not a Git repository.
- Git status after ticket: initialized local Git repo on `main`.
- Local baseline commit created: `DEPLOY-001: add web deployment workflow` (run `git log --oneline -1` for the current hash).
- Remote: none configured.

## Files Created Or Changed

- `.gitignore`
- `vercel.json`
- `web/`
- `scripts/deploy_web_update.ps1`
- `Deploy_Web_Update.bat`
- `DEPLOYMENT_WORKFLOW.md`
- `CODEX_WORKFLOW.md`
- `DEPLOY_001_GITHUB_VERCEL_WORKFLOW.md`

## Web Folder Size

- `web/` contains the current slim Godot Web build.
- Size: `45,348,220` bytes, about `43.2 MB`.
- Files:
  - `index.html`
  - `index.js`
  - `index.wasm`
  - `index.pck`
  - `index.png`
  - `index.audio.worklet.js`
  - `index.audio.position.worklet.js`

## GitHub Status

- GitHub CLI is not installed or unavailable in this environment.
- No GitHub remote was created.
- Manual GitHub setup is documented in `DEPLOYMENT_WORKFLOW.md`.

## Vercel Status

- Vercel CLI is not installed or unavailable in this environment.
- No Vercel project was linked or deployed.
- Manual Vercel dashboard setup is documented in `DEPLOYMENT_WORKFLOW.md`.

## Deployment URL

- None created in this environment.

## Commands Run

```powershell
git status --short
git rev-parse --show-toplevel
git branch --show-current
git remote -v
gh auth status
vercel whoami
```

Result:

- Initial Git commands confirmed this workspace was not a repo.
- `gh` was not installed.
- `vercel` was not installed.

```powershell
git init -b main
```

Result: local Git repo initialized.

```powershell
.\scripts\deploy_web_update.ps1
```

Result:

- `tools/verify_runtime.gd` passed.
- `tools/verify_visible_quality.gd` passed.
- `Export_Web_Build.bat` completed.
- `tools/verify_web_export.py` passed.
- `outputs/AshenOath_Web_Slim` synced into `web/`.

Note: `Export_Web_Build.bat` still prints a warning when an existing slim export folder is in use:

```text
The process cannot access the file because it is being used by another process.
```

The export and verifier still completed successfully.

## What Succeeded

- Created root-level `web/` deploy folder.
- Synced current slim Web export into `web/`.
- Created minimal `vercel.json` for serving the static build from `web`.
- Created `.gitignore` to avoid secrets, raw downloads, screenshots, Godot caches, and old non-slim export folders.
- Created repeatable deployment script.
- Created Windows batch wrapper.
- Created deployment workflow documentation.
- Created future Codex workflow documentation.
- Initialized local Git repo.

## Manual Setup Still Needed

GitHub:

1. Install GitHub CLI or create a repo from the GitHub website.
2. Create a private repo named `ashen-oath`.
3. Run:

```powershell
git remote add origin https://github.com/YOUR_ACCOUNT/ashen-oath.git
git branch -M main
git push -u origin main
```

Vercel:

1. Go to Vercel.
2. Add New Project.
3. Import the GitHub repo.
4. Use static/other framework settings.
5. Set output directory to `web` if prompted.
6. Deploy.
7. Future pushes to `main` should auto-deploy.

## Future Update Command

Dry run update without commit:

```powershell
.\scripts\deploy_web_update.ps1
```

Verify, export, sync, commit, and push:

```powershell
.\scripts\deploy_web_update.ps1 -Commit -Message "TICKET-ID: update Ashen Oath web build"
```

## Risks

- GitHub/Vercel deployment could not be completed because their CLIs are missing.
- A full source commit includes a large local asset library. Individual files are below GitHub's 100 MB hard limit, but the repository is still large enough that Git LFS may be worth adding later.
- Vercel should serve only `web/`, not the raw Godot project or asset library.
- The export batch warning about deleting an in-use slim folder should be cleaned up later by stopping any local server before export or making the batch more defensive.
