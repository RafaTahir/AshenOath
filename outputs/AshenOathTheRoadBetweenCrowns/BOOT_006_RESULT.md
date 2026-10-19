# BOOT-006 - Ready Menu and Artwork Loading

## Implementation

- Keep the initial HTML artwork and phase progress until Godot's matching loading
  view has drawn. Reveal the main menu only after the current opening attempt has
  prepared resources, complete Greyfen, its real gameplay camera and save summaries.
- Use real engine bytes, runtime-pack progress and completed world stages; unknown
  phases are indeterminate and preparation never reports a premature 100 percent.
- Keep existing generation guards, verified pack sharing, failure diagnostics and
  same-flow Retry. Cancelled opening preparation does not overwrite Continue's UI.
- Quality changes repeat preparation behind the same loading view, not a dead menu.
- Reuse the existing four-panel journal atlas after optional threaded loading;
  eight-second changes and brief fades respect reduced motion. It is not a gate.
- Use bundled Spectral Medium (SIL OFL 1.1, license and credit included), transparent
  menu-action styles, actual wrapped-label hover/focus colors, a fine focus rule
  and existing responsive/safe-area layout with minimum 48-pixel touch targets.
- Remove the main menu's enclosing bordered panel. Settings/save tools keep their
  functional containers. Preserve current content, camera, saves and preferences.

## Build and Publication

Implementation, static diff review and production compilation/package generation
completed. Candidate: `ready-menu-20261019-3472773`.

- Complete Web directory: **104,850,917 bytes**; 6,683 bytes below 100 MiB.
- Manifest artifact aggregate: **104,842,887 bytes**.
- Root PCK SHA-256:
  `922bd75a1d2ee66752b89c702f1767ef289267fc6777e76d28d4cd45b91ddc81`.
- Build output: `D:\Projects\AshenOath\.release-gate\boot-006-20261019\export`.
- The existing BOOT-006 publisher records the commit and Vercel result in its
  local `.release-gate/living-road/BOOT-006-*/publication.json` receipt.

No game launch, browser QA, automated tests, screenshots or benchmarks. Runtime
acceptance and actual speed/appearance remain **UNVERIFIED - REQUIRES USER TESTING**.

## Changed Source

`scripts/game.gd`, `scripts/hud.gd`, `scripts/startup_loading_view.gd`,
`assets/ui/fonts/Spectral-Medium.ttf` (with import metadata and OFL),
`web_boot_shell.html`, `tools/prepare_runtime_pack_layout.py`,
`data/production_credits.json`, the export filters and this project's state record.
Generated prepared resources, runtime manifests/ledger and `web/` are synchronized
from the same build. No unrelated untracked diagnostics are included.

## Manual Test Checklist (Not Run by Agent)

1. Cold and warm launch: artwork/progress, then a working menu without auto-start.
2. New Game, saved Continue and recovery selections; complete Greyfen on entry.
3. All menu actions, touch targets, mouse hover, keyboard/gamepad focus and Back.
4. Short portrait/landscape layouts, safe areas and large-text settings.
5. Quality change, failed download/Retry, reduced motion and focus recovery.
6. Save/settings persistence and retained 360-degree/first-person camera behavior.
