# AUDIO-REPAIR-001 — Atmosphere and Human Voice

## Scope

Focused audio repair for the existing Greyfen, Wychwood, cemetery, Castle, and finale route. No quests, combat balance, zones, assets, or export output were changed.

## Files Changed

- `scripts/audio_manager.gd`
- `scripts/game.gd`
- `scripts/runtime_service_registry.gd`
- `tools/verify_audio_repair_001.gd`
- `tools/gate_profiles.json`

## Implemented

- Added debounced transient playback so footsteps, enemy windups, stagger cues, and impact feedback do not stack into an abrasive burst.
- Connected the authoritative player blade result to distinct light-hit and heavy-hit cues.
- Kept parry, block, windup, stagger, death, Oathfire, victory, and return-report cues on the existing event path.
- Added surface-aware footsteps for road, forest, mud, stone, and wood-compatible callers; Greyfen/Wychwood retain the existing recorded variations.
- Added restrained local accent coverage for cemetery/chapel, Record Hall/Undercroft, Castle approach/court, assembly, and Hart Glade.
- Paused world ambience, music, and transient cues while dialogue, inventory, pause, or death UI is active; subtitle/voice playback remains available. Closing dialogue or inventory resumes world audio.
- Preserved Master-bus volume handling and the existing recorded sound effects plus scratch voice files.

## Verification

- `verify_audio_repair_001.gd`: PASS
- Existing `verify_audio_runtime.gd`, `verify_audio_001.gd`, `verify_audio_002.gd`, and `verify_voice_001.gd`: run as the remaining targeted gate.
- Known Godot headless shutdown warnings about ObjectDB/RID cleanup remain diagnostic only; no active playback/resource assertion is accepted by this ticket.

## Voice Status

The repository contains locally generated scratch performances under `assets_external/audio/voices/scratch/`. Subtitles remain authoritative and missing voice files never block dialogue. These are not final actor recordings.

## Running Steps

1. Open PowerShell in the repository root.
2. Run `cd outputs/AshenOathTheRoadBetweenCrowns`.
3. Start a local Web server with `& "$env:USERPROFILE\\.cache\\codex\\runtimes\\codex-primary-runtime\\dependencies\\python\\python.exe" -m http.server 8787 --bind 127.0.0.1`.
4. Open `http://127.0.0.1:8787/` from the exported Web folder when a Web build is available. This ticket does not regenerate production `web/` or deploy Vercel.

## Remaining Issues

- Final human voice acting, mastered music, and spatially placed emitters remain production work.
- Godot/ANGLE teardown warnings still need the lifecycle/performance ticket; they are not hidden by this audio pass.

## Next Ticket

`PERF-REPAIR-001` — real browser and Dell performance profiling, followed by the screenshot approval gate and final Web release.
