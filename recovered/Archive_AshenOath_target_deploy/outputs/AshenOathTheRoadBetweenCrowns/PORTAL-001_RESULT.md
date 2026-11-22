# PORTAL-001 Result

## Changes

- Oath Gates now bind to `ZoneStreamingService` and expose `LOCKED`, `DORMANT`, `AWAKENING`, `PRELOADING`, `READY`, `TRAVELING`, and `ERROR` states.
- Procedural destinations remain immediately ready through the embedded runtime path.
- Authored opening layers preload when adjacent or when Kael approaches a gate, rather than blocking zone construction.
- Gate activation is refused with a compact in-world toast while the destination is still preloading; successful activation marks the portal as traveling before the existing transition owner runs.
- Portal visuals retain the stone arch, black-glass interior, runic edge, ash motes, state colors, and low-cost animation.

## Verification

- `tools/verify_portal_001.gd`: PASS.
- `tools/verify_stream_001.gd`: PASS.
- `tools/verify_runtime.gd`: PASS.
- The runtime route remains compatible with the current embedded PCK and procedural campaign zones.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_portal_001.gd
& .\tools\run_ticket_gate.ps1 -Profiles portal -NoCache
```

## Limitations

The current portal is an authored procedural presentation, not a copied design from another game. Destination scenes remain bounded and the portal does not yet stream external downloadable packs; that work remains gated behind verified artifacts.
