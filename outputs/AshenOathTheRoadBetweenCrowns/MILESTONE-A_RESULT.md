# Milestone A Result - Truth, Architecture, and Fast Boot

## Status

`verified_with_follow_up` on `codex/masterpiece-rebuild`.

Milestone A's implementation, runtime, pack, export, packed-startup, and
Chrome/Edge browser gates pass against the current source. The candidate is
ready for the Milestone A promotion. Browser numbers use the isolated
software-WebGL acceptance runner and are diagnostic rather than Dell hardware
performance proof.

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

The final aggregate run passed `content_integrity`, `runtime_smoke`,
`verify_engine_006`, `verify_qa_013`, `verify_asset_005`, `verify_boot_003`,
`verify_loadgame_002`, `verify_load_qa_002`, `verify_load_qa_001`,
`verify_runtime_regressions`, `verify_stream_001`, `verify_stream_003`,
`verify_runtime_packs`, `verify_pack_candidates`, `verify_portal_001`,
`verify_scene_001`, `verify_zone_builder_integrity`, `web_export`,
`verify_web_export`, `packed_startup`, and `verify_web_browser`.

Packed startup contains no active parser, resource, material, or renderer
errors. Shutdown-only engine diagnostics remain recorded by the runner.

```powershell
$env:GODOT_BIN="C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe"
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 `
  -Profiles milestone_a -NoCache
```

Passed groups include content integrity, runtime smoke, engine lifecycle,
asset acceptance, current QA evidence, boot shell, Crow
Flight, pack metadata, runtime regressions, streaming, portals, scenes, zone
builders, Web export, packed startup, and browser smoke.

The current candidate is `89.43 MB` total across `12` files: the root Web
runtime plus five streamed packs. The root PCK is `1,760,764` bytes.
Its exported PCK SHA-256 is:

`0E819446442435F703C253D6AD0C3AF892C8D5EA9F680BD7A0DA7AAE6101E6DF`

Chrome and Edge both reached a native `1280x720` WebGL2 canvas, accepted the
focused keyboard menu path, entered Greyfen, produced nonblank captures, and
reported no JavaScript, WebAssembly, resource, or Godot console errors:

| Browser | Canvas | Engine ready | Greyfen prewarm | New Game event | JS heap |
|---|---:|---:|---:|---:|---:|
| Chrome | 1280x720 WebGL2 | 8.30 s | 9.36 s | 5.81 s | 11.6 MB |
| Edge | 1280x720 WebGL2 | 9.07 s | 7.06 s | 6.32 s | 11.4 MB |

The browser process-tree readings were approximately `1.36-1.39 GB` and are
diagnostic only; the enforced JavaScript heap remained below `450 MB`.

## Follow-up Boundaries

1. Cold engine readiness is below the 12-second hard ceiling but remains
   slightly above the 8-second typical target in this software-browser run.
2. The browser event-to-frame measurement reports several seconds after the
   runtime's internal prewarmed playable marker; hardware-driver performance
   and remaining loading polish belong to later product tickets.
3. Only Captain Senn's processed Ranger is visually approved by ASSET-005;
   final character, monster, and world presentation remain later milestones.
4. Firefox, physical-controller certification, and Dell hardware GPU
   measurements were not available in this Windows acceptance run.

## Production and Checkpoint

At the time of this result, production `main`, tracked `web/`, and Vercel still
point to the previous Milestone B checkpoint. Promotion now consists of
syncing this verified candidate, committing it on `codex/masterpiece-rebuild`,
pushing the branch and `main`, and comparing the live PCK hash with the value
above.

## Running Steps

To run the complete Milestone A gate:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
$env:GODOT_BIN = "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe"
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles milestone_a -NoCache
```

Detailed logs and fresh browser captures are in `.release-gate\ticket\`.
