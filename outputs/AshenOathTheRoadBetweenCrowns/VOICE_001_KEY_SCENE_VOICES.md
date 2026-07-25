# VOICE-001 - Key-Scene Voices and Combat Barks

## Delivery

- Added 14 compact, locally generated scratch performances for Anwen, Kael, Senn, Halvern, Edric, and the White Hart.
- Runtime prefers recorded WAV files and retains procedural/browser fallback when a clip is unavailable.
- Subtitles remain authoritative. These clips are production placeholders, not final actor performances.
- Existing player effort, hit, parry, enemy windup, Ghoulkin, and death barks remain synchronized through the audio event system.

## Payload

The voice verifier enforces a combined 15 MB maximum. Raw generation is reproducible with `tools/generate_scratch_voices.ps1`.

## Verification

`verify_voice_001.gd` checks the manifest, required clips, runtime preference, subtitle policy, and payload ceiling.

## Running

Serve `outputs/AshenOath_Web`, open `http://127.0.0.1:8787`, start New Game, and speak with Anwen. Key dialogue plays after browser audio unlock; subtitles always remain available.
