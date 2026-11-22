# WEB-002 Full Campaign Candidate

## Result

The complete released campaign is present in one single-threaded Godot Web candidate. The same exported PCK was exercised from Greyfen through Deep Wood, mill, farmstead, marsh, Long Road, Castle Vargan, Record Hall, undercroft, assembly, and Hart Glade.

## Artifact

- Shape: seven runtime files
- Total payload: 65.6 MB
- PCK: 29.3 MB
- PCK SHA-256: `9d52093d4f8bc7bdb3ebc8a6f2cff5f5b2594af6e29949c8d3b4c22d02ef84be`
- Renderer: Compatibility, WebGL 2, single-threaded

## Browser Acceptance

| Browser | Route | Settled Hart FPS | 1% low | JS heap | Console/network |
|---|---:|---:|---:|---:|---|
| Chrome desktop | 36 checkpoints | 58.29 | 41.84 | 11.7 MB | Clean |
| Edge desktop | 36 checkpoints | 45.01 | 30.30 | 11.4 MB | Clean |
| Chrome mobile emulation | 36 checkpoints | Diagnostic only | Diagnostic only | 11.0 MB | Clean |
| Edge mobile emulation | 36 checkpoints | Diagnostic only | Diagnostic only | 11.3 MB | Clean |

Mobile results are feasibility diagnostics, not native-mobile certification. Desktop native-720p acceptance retains the PERF-003 32 FPS average and 30 FPS 1% low floor.

## Fixes Made

- Added complete-campaign static export validation.
- Added Web-only route, save, input, audio, mouse-mode, and frame telemetry.
- Isolated navigation maps per zone to remove browser navigation-edge errors.
- Preserved bridge-safe route authority while removing overlapping map raster edges.
- Corrected post-Ghoulkin music-state priority.
- Reduced Hart Glade transparent overdraw and distant tree cost.

## Local Running

1. Open PowerShell in `outputs/AshenOath_Web`.
2. Run:
   `& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1`
3. Open `http://127.0.0.1:8787/`.
4. Click the game, press Enter, then choose New Game.

Production is not changed by WEB-002. RELEASE-001 owns the final sync and deployment.
