# AUD-002 Voice And Dynamic Music

## Files Changed

- `scripts/audio_manager.gd`
- `scripts/game.gd`
- `scripts/hud.gd`
- `data/dialogue.json`
- `tools/verify_runtime.gd`

## Implementation Summary

- Added lightweight generated voice playback hooks in `AudioManager`.
- Added safe missing-voice behavior: unknown voice IDs return without crashing.
- Added queued voice playback for dialogue sequences.
- Added voice stop behavior when dialogue advances or closes.
- Added generated placeholder voice beds for Sister Anwen and Kael/player route beats.
- Added dynamic procedural music states:
  - `greyfen_explore`
  - `shrine_anwen`
  - `wychwood_tension`
  - `ghoulkin_combat`
  - `return_report`
- Added a short procedural `victory_return_cue` for post-Ghoulkin victory.
- Wired first-route music state changes through Greyfen, shrine, Wychwood, combat, victory, and return/report moments.
- Tagged Sister Anwen dialogue with voice metadata while keeping subtitles unchanged.

## Audio Notes

- This pass does not add real spoken dialogue files.
- Current voices are tiny original procedural placeholders, not AI/TTS speech.
- The system is ready for real licensed `.ogg`/`.wav` voice clips later if added to the voice registry.
- All generated audio is runtime-created and avoids external paid APIs, copyrighted audio, and large asset imports.

## Payload Impact

- No external audio files were added.
- Web export verified at about 43.2 MB:
  - `index.wasm`: 36.0 MB
  - `index.pck`: 7.0 MB
  - `index.js`: 0.3 MB

## Verification

Commands run:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script "res://tools/verify_runtime.gd"
```

Result: passed.

```powershell
& "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns\Export_Web_Build.bat"
```

Result: passed. Web verifier confirmed 7 files in `AshenOath_Web_Slim`.

Note: the export batch reported that the existing output folder could not be deleted because a file was in use, but the export still completed and verified successfully.

## Known Issues

- Voice clips are expressive placeholder tones, not real human speech.
- Music is procedural and lightweight, so it gives identity and state changes but not full composed score quality.
- Dynamic music is state-based, not beat-synced.

## Recommended Next Phase

AUD-003 should replace the procedural voice placeholders with a tiny licensed voice pack or locally generated original voice clips, then add a simple voice registry that loads external `.ogg` clips when present and falls back to procedural placeholders when absent.
