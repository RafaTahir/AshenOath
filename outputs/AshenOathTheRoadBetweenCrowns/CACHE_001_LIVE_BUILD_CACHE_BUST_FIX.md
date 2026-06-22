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

- Pending production deploy script.

## Live Header Check

After Vercel deploys, `https://ashenoath.vercel.app/index.pck` must report `no-cache` or `must-revalidate`, not `max-age=3600`.
