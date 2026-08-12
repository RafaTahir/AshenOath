# STREAM-001 / STREAM-002 Result

## Changes

- Retained the existing threaded `ZoneStreamingService` as the request, progress, cancellation, activation, and retirement API.
- Added a checked-in zone topology so only adjacent areas are prewarmed and unrelated requests are retired.
- Added authored-layer prewarming for Greyfen, Wychwood, and the cemetery. Campaign areas without approved PackedScenes remain on the embedded/procedural fallback path.
- Wired prewarming to menu acceptance and completed zone activation without changing route or save ownership.

## Verification

- Runtime smoke: PASS.
- Input/runtime regression gate: PASS.
- Pack validation, Web export, and packed startup: PASS.
- `tools/verify_stream_001.gd`: PASS for topology, embedded request readiness, and retirement.
- Existing route remains playable through the embedded PCK fallback.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles packs -NoCache
```

## Limitations

True mesh-rich PackedScene conversion remains separate. This checkpoint deliberately avoids replacing live procedural geometry before equivalent collision, save, and visual tests exist; prewarming currently compiles only the safe authored layer scenes and keeps the current fallback active.
