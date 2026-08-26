# PACK-003 Result - Real Versioned Runtime Pack Candidates

## Status

`verified`

Six real Godot PCK candidates now export deterministically from named runtime
pack presets. They are verified outside the repository and remain external
artifacts for the source tree. The current Web candidate includes the five
non-base packs beside the root runtime; the base pack remains embedded as the
startup fallback.

## Changes

- Replaced recursive environment filters in the Opening and Campaign pack
  presets with the curated runtime environment list and runtime material maps.
- Added `tools/build_runtime_packs.ps1`, which exports one pack at a time,
  waits for the Windows Godot GUI process, checks `GDPC` magic, records bytes
  and SHA-256 values, and writes an artifact manifest.
- Added `tools/verify_pack_candidates.py` for manifest-only and external-file
  hash verification.
- Added `runtime_pack_candidates.json` with the verified external candidate
  contract and updated `runtime_pack_manifest.json` with schema 2 candidate
  metadata while preserving embedded/manifest-only runtime behavior.
- Registered the candidate gate in the existing `packs` ticket profile.
- Fixed four Godot 4.6 typed-inference errors in the bow/shop integration that
  blocked runtime startup, and made the ticket runner wait for GUI Godot
  processes instead of accepting an early process return.
- Added non-empty options sections for every runtime-pack export preset; clean
  exports now produce no preset-configuration stderr diagnostics.

## Candidate Artifacts

The verified files are in the external cache directory
`C:\Users\User\.cache\codex-runtimes\ashenoath-packs-v4` and are intentionally
not in tracked `web/` or the production PCK:

| Pack | Size | SHA-256 |
|---|---:|---|
| base | 1.19 MB | `e2698fe7618fd6963b5a58803add0804c82c8ad4ca33acc11ff572fae15ca3cf` |
| opening | 29.75 MB | `0c1aa12dde7c570d34add2ecbca91cdbd9e65f444077e69703c0fe22ce32f7b4` |
| campaign | 25.81 MB | `f52090e6880b9ad277b5c8be92f21c78349acb40e68389f9f4f299037c829d9d` |
| characters | 19.84 MB | `854079584e3f35e152b96622d68ffc71f1fa8c3070fe98ce13b9f585b37baf1e` |
| monsters | 1.48 MB | `e5cd7162e3f347bb8e36584d50805ead4844bcbf2f379e188a7bce7e398aa158` |
| audio | 2.46 MB | `ca06c482c7c5620fbdd19fcdfa5439e0eeb3f23b26277bf068393bb587274bf5` |

Total candidate bytes: `55,217,080` (`52.66 MB`) for the external candidate
set used by this checkpoint.

## Verification

- `verify_pack_candidates.py runtime_pack_candidates.json`: PASS.
- External artifact verification with `--require-artifacts`: PASS for all six
  PCKs, including magic, size, and SHA-256.
- `verify_runtime_packs.py`: PASS, six packs within the 100 MB deployment
  budget.
- JSON parsing: PASS for the pack manifest, candidate manifest, and gate
  profile configuration.
- Godot 4.6.3 headless export: PASS for all six named presets.

## Limitations

- `RuntimePackManager` still treats empty URLs as embedded and rejects external
  downloads. `STREAM-003` must add mounting, retry, cache, and rollback before
  these candidates are a live runtime dependency.
- No production export, tracked `web/` synchronization, commit to `main`, or
  Vercel deployment was performed for this ordinary ticket.
- This ticket does not claim visual acceptance for the provisional character,
  monster, or environment mappings.

## Running Steps

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
powershell -ExecutionPolicy Bypass -File .\tools\build_runtime_packs.ps1 `
  -OutputDirectory C:\Users\User\.cache\codex-runtimes\ashenoath-packs-v4
& C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe `
  .\tools\verify_pack_candidates.py .\runtime_pack_candidates.json
```

To verify the external files themselves, add
`--artifact-dir C:\Users\User\.cache\codex-runtimes\ashenoath-packs-v4
--require-artifacts`.
