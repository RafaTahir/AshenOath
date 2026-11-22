# Ashen Oath Asset Pipeline

This pipeline lets you paste direct download URLs or supported asset page URLs into `asset_sources.json`, then run local scripts to download, extract, organize, scan, and suggest asset-role mappings for Godot.

## Recommended Sources

Use assets you own or assets with clear permissive licenses.

- Quaternius free asset packs
- Kenney free assets
- OpenGameArt CC0 assets
- ambientCG CC0 textures
- Poly Haven CC0 textures and HDRIs
- Freesound CC0 audio only

Avoid unclear, noncommercial-only, editorial-only, ripped, or AI-uncertain assets unless you have explicit rights to use them.

## Folder Layout

Downloaded and organized assets live in:

`assets_external/`

Important subfolders:

- `downloads/`: original downloaded archives or files
- `raw/`: extracted source pack contents
- `characters/`: playable and NPC models
- `enemies/`: monster and enemy models
- `environment/`: village, forest, ruins, cemetery, props
- `animations/`: animation libraries
- `textures/`: terrain, wood, stone, metal, cloth, foliage, UI
- `audio/`: combat, footsteps, monsters, ambience, UI, music
- `licenses/`: license/readme/attribution files

## Paste URLs

Open:

`asset_sources.json`

For each pack, replace:

`PASTE_DIRECT_DOWNLOAD_URL_HERE`

with a supported URL. Keep the `category`, `license`, and `source` fields accurate. If a URL still contains the placeholder text, the downloader skips it safely.

Supported URL types:

- Direct archive links such as `.zip`, `.7z`, and `.rar`
- Direct model, texture, or audio file links supported by the pipeline
- Direct links that redirect to a file, including GitHub archive links that redirect to `codeload.github.com`
- GitHub release pages: `/releases/latest` and `/releases/tag/<tag>`
- HTML asset pages that expose normal `<a href>` or `<link href>` download links, including OpenGameArt-style `/sites/default/files/` links

The downloader follows HTTP redirects, keeps a session cookie jar for sites that set simple cookies, honors `Content-Disposition` filenames, and tries `HEAD` before falling back to a one-byte ranged `GET` for servers that do not support `HEAD`.

Unsupported or limited cases:

- Login-only, paywalled, captcha-protected, or JavaScript-only download buttons
- Dead file URLs that return 404
- Pages with multiple valid downloads where the best file cannot be inferred from the link names
- Non-zip archives download successfully, but only `.zip` files are automatically extracted by this script

## Run The Pipeline

From the Godot project root:

```powershell
python tools/download_assets.py
python tools/scan_assets.py
python tools/suggest_asset_mapping.py
python tools/create_placeholders_if_missing.py
```

To test every URL without downloading anything:

```powershell
python tools/download_assets.py --dry-run --verbose
```

If `python` is not on PATH in this Codex workspace, use the bundled runtime:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/download_assets.py
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/download_assets.py --dry-run --verbose
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/scan_assets.py
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/suggest_asset_mapping.py
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/create_placeholders_if_missing.py
```

What each script does:

- `download_assets.py`: resolves page/release/direct URLs, downloads assets, extracts `.zip` files, organizes useful assets, preserves licenses
- `scan_assets.py`: creates `asset_manifest.json`
- `suggest_asset_mapping.py`: creates `asset_role_mapping_suggested.json`
- `create_placeholders_if_missing.py`: marks missing roles with placeholder requirements

## Import Into Godot

After running the scripts:

1. Reopen the Godot project, or use **Project > Reload Current Project**.
2. Let Godot import new `.glb`, `.gltf`, textures, and audio.
3. Inspect `asset_manifest.json` and `asset_role_mapping_suggested.json`.
4. Adjust role mappings manually if the suggestions are not ideal.

## Prefer Real Assets Over Placeholders

Godot integration scripts:

- `scripts/asset_database.gd`
- `scripts/asset_spawn_helper.gd`

`AssetDatabase` loads `asset_manifest.json` and `asset_role_mapping_suggested.json`.

`AssetSpawnHelper` asks the database for role paths and spawns the mapped model when present. If an asset is missing, it creates a simple primitive placeholder and prints a warning.

Use role names like:

- `player_kael`
- `mira_herbalist`
- `ghoulkin`
- `greyfen_house`
- `forest_tree`
- `sword_swing`

## Licensing Safety

- Keep all downloaded license/readme files.
- Prefer CC0 or permissive assets.
- Do not mix unknown-license assets into the project.
- Check whether attribution is required before publishing.
- Keep `asset_sources.json`, `asset_manifest.json`, and `assets_external/licenses/` with the project.

## Low-End Optimization Notes

- Prefer `.glb` and `.gltf`.
- Use low-poly assets.
- Prefer 512 or 1024 textures.
- Avoid huge animation libraries if only a few clips are needed.
- Keep enemy counts low.
- Test with Potato Mode on the Dell Latitude 7280.
