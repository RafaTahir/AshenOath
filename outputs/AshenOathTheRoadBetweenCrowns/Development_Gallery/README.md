# Ashen Oath Development Gallery

This folder collects development screenshots for Ashen Oath without deleting or moving the originals.

## Folder Layout

- `screenshots/` contains copied gallery images with clearer ordered filenames.
- `index.html` is a local static thumbnail gallery.
- `SCREENSHOT_TIMELINE.md` lists every collected screenshot, original path, copied path, timestamp, likely phase/source, and note.
- `screenshot_manifest.json` is a small machine-readable manifest for future tooling.

## Opening The Gallery

Open this file in a browser:

`Development_Gallery/index.html`

No server, build step, or external JavaScript framework is required.

## Future Screenshot Workflow

Use the existing screenshot capture tool:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://tools/capture_slice_screenshots.gd
```

The tool still writes originals to:

`verification_screenshots/`

It now also mirrors each new capture to:

`Development_Gallery/screenshots/`

## QA-003 Visual Approval

`qa_003_approval_manifest.json` defines the current required release views. It stores the
matching screenshot pattern, expected size, human-approval status, reviewer, note, and an
optional approved baseline comparison. It deliberately starts with `pending` review states;
this is evidence awaiting a human decision, not an automatic art-quality claim.

Run the ordinary changed-view check after a visual ticket:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_screenshot_qa_003.py . --mode ticket --views greyfen_spawn,wychwood_combat
```

Use `--dry-run` to resolve image patterns and source freshness inputs without reading pixels.
At a milestone, run `--mode milestone`; every required view must be marked `approved` with a
non-empty reviewer and note before that invocation can pass. To compare a new capture to a
baseline, set an approved `baseline.path`, reviewer, note, and numeric
`max_mean_absolute_difference` in the manifest.

## Rules

- Do not delete original screenshots.
- Do not move original screenshots.
- New phase reports should reference both the normal verification screenshot folder and this gallery.
- Regenerate screenshots only when a phase actually needs visual verification.
- Do not overwrite or move existing captures when approving a view. Approval metadata belongs in
  `qa_003_approval_manifest.json`; originals remain in their existing folders.
