# AUD-002-LOCKDOWN Voice And Music Results

## Files Changed

- `scripts/audio_manager.gd`
- `scripts/game.gd`
- `scripts/hud.gd`
- `data/dialogue.json`
- `tools/verify_runtime.gd`
- `tools/verify_audio_runtime.gd`
- `AUD_002_LOCKDOWN_VOICE_MUSIC_RESULTS.md`

## Why The Previous Attempt Was Inaudible

- Voice was only a generated tonal placeholder, not spoken words.
- There was no direct V/B smoke test to prove voice in the playable Web path.
- Music was procedural but mixed too low and too subtle to be obvious during play.
- Debug logging existed for some events but did not clearly prove browser speech or state changes.

## Voice Smoke Test

- Press `V`: speaks `Sister Anwen: The road remembers every oath broken upon it.`
- Press `B`: speaks `Player: Then I will hear what the dead have to say.`
- In Web builds, this uses browser `speechSynthesis` through `JavaScriptBridge`.
- In non-Web/headless runs, it logs `browser_speech_unavailable_*` and falls back to generated voice tones when possible.
- Browser speech is cancelled cleanly when a new voice starts or dialogue closes.

## Sister Anwen Voice Hooks

- Sister Anwen first dialogue now sends actual spoken text to browser speech synthesis.
- Covered moments:
  - first greeting
  - Road of Crows warning
  - Wychwood warning
  - return/report reaction
- Subtitles remain unchanged.
- Missing voice IDs do not crash.

## Player Voice Hooks

- Player voice lines now trigger for:
  - accepting Road of Crows
  - inspecting Wychwood tracks/clues
  - post-Ghoulkin victory
  - return/report cue

## Music States

- `greyfen_explore`: audible dark-fantasy exploration loop.
- `shrine_anwen`: quieter solemn shrine layer.
- `wychwood_tension`: colder Wychwood loop.
- `ghoulkin_combat`: louder combat pulse.
- `return_report`: post-victory/report music state.
- `victory_return_cue`: short post-Ghoulkin cue.

Music volumes were raised substantially from the previous pass.

## Debug Logs

Runtime now prints obvious audio logs, including:

- `AUDIO: voice_sister_anwen_test`
- `AUDIO: voice_player_test`
- `AUDIO: music_state_greyfen_explore`
- `AUDIO: music_state_wychwood_tension`
- `AUDIO: music_state_ghoulkin_combat`
- `AUDIO: music_cue_victory_return_cue`

## Verification

Runtime verifier:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script "res://tools/verify_runtime.gd"
```

Result: passed.

Audio verifier:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script "res://tools/verify_audio_runtime.gd"
```

Result: passed.

Web export:

```powershell
& "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns\Export_Web_Build.bat"
```

Result: passed.

Browser smoke test:

- Local Chrome loaded `http://127.0.0.1:8787/index.html?v=aud002lockdown`.
- Pressed `V` and `B`.
- Browser console confirmed:
  - `AUDIO: voice_sister_anwen_test`
  - `AUDIO: voice_player_test`

Headless browser automation cannot confirm what a human hears through speakers, so final audible confirmation still needs an interactive browser check.

## Export Size Impact

- Before: `45,345,212` bytes, about `43.2 MB`.
- After: `45,348,220` bytes, about `43.2 MB`.
- Increase: about `3 KB`.
- No external audio files were added.

## Exact Browser Test Instructions

1. Open PowerShell.
2. Run:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web_Slim"
```

3. Run:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

4. Open:

```text
http://127.0.0.1:8787/index.html?v=aud002lockdown
```

5. Click the game/launch screen once so browser audio is unlocked.
6. Press `V`; Sister Anwen should speak.
7. Press `B`; the player should speak.
8. Start a new game.
9. Talk to Sister Anwen; she should speak her first-route dialogue.
10. Accept/acknowledge the contract; the player should speak.
11. Walk to Wychwood; the music should become colder/darker.
12. Fight the Ghoulkin; combat music should clearly start.
13. Kill the Ghoulkin; the victory/return cue should play and combat music should stop.

## Remaining Limitations

- Web voice depends on the browser's built-in `speechSynthesis` voices.
- Voice quality will vary by browser/OS.
- Headless tests can prove hooks and logs, but not actual speaker output.
- Procedural music is still lightweight and simple, not a composed score.
