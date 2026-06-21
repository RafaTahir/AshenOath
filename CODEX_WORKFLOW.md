# Codex Production Workflow

For future Ashen Oath production tickets, the work is not complete until the playable web path is updated or the reason is documented.

Required ending steps:

1. Run `tools/verify_runtime.gd`.
2. Run `tools/verify_visible_quality.gd` when visual/gameplay presentation is relevant.
3. Export the slim Godot Web build.
4. Sync `outputs/AshenOath_Web_Slim` into root-level `web/`.
5. Run `tools/verify_web_export.py`.
6. Check `git status`.
7. Commit with the ticket ID when the user wants deployment.
8. Push to GitHub when deployment is intended.
9. Confirm Vercel deployment URL/status when available.

Use:

```powershell
.\scripts\deploy_web_update.ps1
```

To commit and push after verification:

```powershell
.\scripts\deploy_web_update.ps1 -Commit -Message "TICKET-ID: update Ashen Oath web build"
```

Do not commit secrets, raw downloads, screenshot galleries, old non-slim exports, or Godot import caches.
