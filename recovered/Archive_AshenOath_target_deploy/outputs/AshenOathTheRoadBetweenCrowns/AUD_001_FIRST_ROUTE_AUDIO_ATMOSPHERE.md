# AUD-001 First Route Audio Atmosphere

## Files Changed
- `scripts/audio_manager.gd`
- `scripts/game.gd`
- `AUD_001_FIRST_ROUTE_AUDIO_ATMOSPHERE.md`

## Greyfen Ambience Changes
- Kept Greyfen restrained but less silent with a warmer low ambient loop.
- Added lightweight generated accents for distant village life, cloth/wind movement, and softer crow calls.
- Added slight volume variation to one-shot events so repeated cues feel less identical.

## Shrine Ambience Changes
- Added shrine proximity cue near Sister Anwen: low shrine hum, candle/ritual texture, and a quiet bell tone.
- The shrine now has a distinct one-shot atmosphere without adding music or imported audio files.

## Wychwood Tension Changes
- Darkened Wychwood ambient bed with lower tones and more wind/noise.
- Added a short silence/drop cue and tension layer as the player approaches the Ghoulkin clearing.
- Added a low Ghoulkin idle threat cue on first Ghoulkin spawn and near-clearing approach.

## Footstep Changes
- Existing road/forest/mud footsteps remain.
- Added global pitch and volume jitter to procedural one-shots, making footsteps less robotic without new files.

## Combat Audio Changes
- Light and heavy hits now use distinct impact cues through the combat impact callback.
- Heavy hit cue is lower and weightier; light hit cue is shorter and sharper.
- Block, parry, hurt, swing, and heavy swing hooks remain intact.

## Ghoulkin Audio Changes
- Ghoulkin windup is lower and more threatening.
- Ghoulkin idle, lunge, stagger, and death cues are clearer and still short/procedural.

## Victory / Return Cue
- Ghoulkin victory cue remains tied to completing `fight_ghoulkin`.
- Return/report cue remains tied to reporting back to Sister Anwen.
- Victory tone was adjusted to feel restrained and contract-like rather than arcade-bright.

## Payload Impact
- No external audio assets were added.
- Audio remains generated at runtime in `audio_manager.gd`.
- Slim Web export remained `7 files / 43.2 MB`.

## Verification Result
- `tools/verify_runtime.gd`: passed.
- Note: Godot emitted the existing ObjectDB cleanup warning on verifier exit.

## Export Result
- `Export_Web_Build.bat`: passed.
- Output folder: `outputs/AshenOath_Web_Slim`.
- `verify_web_export.py`: passed as part of export script.

## Remaining Audio Weaknesses
- Audio is still procedural and simple, not professionally authored Foley/ambience.
- No positional 3D audio mix yet; most cues are global one-shots.
- No true adaptive music system, only restrained ambience and stingers.

## Run Steps
1. Open PowerShell.
2. Run: `cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web_Slim"`
3. Run: `& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1`
4. Open Chrome or Edge to: `http://127.0.0.1:8787/index.html?v=aud001`
5. Click inside the game window to start/capture input.
6. Use `WASD` to move, mouse to look, `Left Click` light attack, `Shift + Left Click` heavy attack, `Q` block/parry, `Space` dodge, `Esc` pause/release mouse.
