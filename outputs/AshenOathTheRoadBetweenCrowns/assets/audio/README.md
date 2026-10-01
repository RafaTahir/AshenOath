# Prepared Compatibility Sound Bank

`prepared_bank.res` is generated from Ashen Oath's existing procedural audio
code, not downloaded audio or cloned voices. It preserves the provisional
sound palette while moving PCM synthesis out of runtime startup.

- 50 cue streams, 20 music states, 12 ambience entries.
- Godot compressed binary resource; 2,857,003 bytes at initial generation.
- Original PCM, sample rates, channel formats and loop boundaries preserved.
- Fixed generator seed: 41021. Random pitch/volume during playback is unchanged.
- Recorded effects and approved voice selection still override/follow the
  existing audio manager policy. This bank adds no spoken voice.
- Runtime preloads this dependency in the base resource graph. Final Web pack
  inclusion, payload and browser timing still require acceptance.

Regenerate from the Godot project directory using Godot 4.6.3:

```powershell
& $Godot --headless --path . --script tools/build_prepared_audio.gd
& $Godot --headless --path . --script tools/verify_prepared_audio.gd
```

The committed bank is the bootstrap dependency of AudioManager, including the
generator. Retain it when rebuilding. The equivalence gate checks decoded audio
data, not incidental serialized resource IDs. Any synthesis change requires a
bank rebuild and this check. Sound design remains provisional until reviewed.
