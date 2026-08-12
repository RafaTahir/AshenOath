# PACK-001 / PACK-002 Result

## Changes

- Added `RuntimePackManager`, registered through `RuntimeServiceRegistry` and exposed to `game.gd`.
- Added manifest validation for pack dependencies, status, optional checksums, embedded-pack byte claims, and the 100 MB deployment ceiling.
- Embedded packs resolve immediately so the current playable route is unchanged. A non-empty URL is rejected clearly until a verified downloader and same-origin pack endpoint are available.
- Added the manager to both Web and QA export file lists and included the runtime manifest in both presets.
- Added a `packs` ticket-gate profile and included pack validation in the asset and Web profiles.

## Verification

- Runtime pack manifest validation: PASS.
- Runtime smoke: PASS.
- Web export and packed startup: PASS after the export-filter change.
- No production Web folder, `main`, or Vercel deployment was changed.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_runtime_packs.py .
& .\tools\run_ticket_gate.ps1 -Profiles packs -NoCache
```

## Limitations

This ticket establishes the lifecycle contract, not final split downloads. The current runtime still embeds the game in `index.pck`; external pack mounting is available for verified local PCK files but is not silently used by gameplay.
