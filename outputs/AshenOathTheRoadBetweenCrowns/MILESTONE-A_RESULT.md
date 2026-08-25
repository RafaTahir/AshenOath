# Milestone A Result - Truth, Architecture, and Fast Boot

## Status

`blocked_by_acceptance_target` on `codex/masterpiece-rebuild`.

The implementation and aggregate verification gates for Milestone A pass. The
milestone is not marked release-ready because its measured cold-start targets
and production pack-hosting conditions are not yet satisfied.

## Completed Tickets

- `PROD-004`: established the current outcome/status boundary and stopped
  historical result documents from being treated as approval.
- `ENGINE-006`: retained typed zone construction and added transactional
  lifecycle validation, timing, rollback, and failure telemetry.
- `QA-013`: created a reproducible historical baseline ledger with explicit
  freshness boundaries.
- `ASSET-005`: created the runtime asset acceptance manifest, license/hash
  records, fallback policy, and export boundary.
- `BOOT-003`: kept one immediate HTML-to-Godot boot path and removed QA
  telemetry from the production Web preset.
- `LOADGAME-002`: formalized the non-blocking Crow Flight wait activity with
  keyboard, pointer, touch, gamepad, and reduced-motion input.
- `PACK-003`: exported six deterministic, hash-verified external PCK
  candidates.
- `STREAM-003`: added verified temporary download, cache, retry, cancel,
  local-mount, and embedded-fallback behavior.
- `LOAD-QA-002`: added the six-pack budget, metadata, boot telemetry, and
  cache lifecycle acceptance contract.

## Verification

The aggregate command below passed the Milestone A loading, streaming, scene,
export, packed-startup, and browser gates. The foundation gates added during
the final acceptance pass were then run through the ticket runner separately:
`engine` PASS, `assets` PASS, and `qa_013` PASS. The `milestone_a` profile now
includes all three foundation gates for future runs.

```powershell
$env:GODOT_BIN="C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64.exe"
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 `
  -Profiles milestone_a -NoCache
```

Passed groups include content integrity, runtime smoke, engine lifecycle,
asset acceptance, current QA evidence, boot shell, Crow
Flight, pack metadata, runtime regressions, streaming, portals, scenes, zone
builders, Web export, packed startup, and browser smoke.

The current seven-file candidate is `87.3 MB` total with a `51.0 MB` PCK.
The current exported PCK SHA-256 is:

`c53644bdd8d84e7661907a1ea46d4e718e42263e1d25affb9a2614717ce32189`

Chrome and Edge both reached a native `1280x720` WebGL2 canvas with no
JavaScript, WebAssembly, resource, or Godot console errors:

| Browser | Canvas | Engine-ready measurement | New Game measurement | JS heap |
|---|---:|---:|---:|---:|
| Chrome | 1280x720 WebGL2 | 42.94 s | 4.79 s | 13.1 MB |
| Edge | 1280x720 WebGL2 | 27.11 s | 6.22 s | 11.7 MB |

The browser process-tree readings were approximately `1.31-1.32 GB` and are
retained as diagnostics; only the JavaScript heap check passed the existing
browser gate. They are not a claim that the full memory target has passed.

## Remaining Blockers

1. Cold engine readiness exceeds the Milestone A target of 8 seconds typical
   and 12 seconds hard maximum.
2. New Game after the measured Greyfen readiness exceeds the 750 ms target.
3. The checked-in runtime pack manifest still has empty production URLs, so
   the shipped candidate uses the embedded PCK fallback. The six external
   candidates total `80.52 MB` and are not a hosted runtime dependency yet.
4. The ASSET-005 visual roles, fresh QA-013 graphical baseline, renderer
   teardown classification, and final visual acceptance remain later release
   work.

## Production and Checkpoint

Production `main`, tracked `web/`, and Vercel were not changed. No deployment
was made because the explicit startup and hosted-pack acceptance conditions
remain open. The development checkpoint is ready to commit on
`codex/masterpiece-rebuild`.

## Running Steps

To verify the static contracts without the long browser run:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_boot_003.py .
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_loadgame_002.py .
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_load_qa_002.py . --candidate-dir "C:\Users\User\.cache\codex-runtimes\ashenoath-packs-v4"
```
