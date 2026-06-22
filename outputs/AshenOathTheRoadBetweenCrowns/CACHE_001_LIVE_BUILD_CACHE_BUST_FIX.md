# CACHE-001 Live Build Cache Bust Fix

## Files Changed

- `vercel.json`
- `DEPLOYMENT_WORKFLOW.md`
- `DEPLOYMENT_POLICY.md`

## Fix

- Changed Godot Web runtime files to `Cache-Control: no-cache, must-revalidate`.
- Runtime files covered: `index.html`, `index.pck`, `index.js`, `index.wasm`, `index.audio.worklet.js`, and `index.audio.position.worklet.js`.
- Kept `index.png` on short static cache.

## Reason

Godot Web exports use stable filenames, so browser/CDN caching can keep serving old `index.pck`, `index.js`, or `index.wasm` after a successful Vercel deploy.

## Verification

- `verify_runtime.gd`: passed.
- `verify_audio_runtime.gd`: passed.
- `verify_visible_quality.gd`: passed.
- `Export_Web_Build.bat`: completed.
- `verify_web_export.py`: passed, 7 files, 43.3 MB.
- Production push: succeeded.

## Live Header Check

- `index.html`: `public, must-revalidate, max-age=0`
- `index.pck`: `must-revalidate, no-cache`
- `index.js`: `must-revalidate, no-cache`
- `index.wasm`: `must-revalidate, no-cache`
- `index.audio.worklet.js`: `must-revalidate, no-cache`
- `index.audio.position.worklet.js`: `must-revalidate, no-cache`

`https://ashenoath.vercel.app/index.pck` now reports revalidation headers instead of `max-age=3600`.
