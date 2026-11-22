# Phase 1K Audio Encounter Presentation

## Files Changed

| File | Change |
| --- | --- |
| `scripts/audio_manager.gd` | Expanded lightweight procedural audio library, richer ambience generation, contextual footstep events, and occasional restrained ambient accents. |
| `scripts/game.gd` | Routed footsteps by zone/surface and added shrine, Wychwood tension, Ghoulkin, victory, tracks, and report cue hooks. |

## Audio Cues Added Or Changed

- Added contextual footsteps:
  - `step_road`
  - `step_forest`
  - `step_mud`
- Improved combat cues:
  - `enemy_windup`
  - `ghoulkin_lunge`
  - `hit`
  - `block`
  - `parry`
  - `stagger`
  - `death`
- Added encounter/quest presentation cues:
  - `wychwood_tension`
  - `tracks_found`
  - `victory`
  - `return_report`
  - `shrine_hum`

## Ambience Changes

- Greyfen ambience is now a restrained layered drone/noise bed with occasional crow or cloth/wind accents.
- Shrine entry now gets a short low sacred/haunted hum.
- Wychwood ambience is colder and darker, with a low tension cue on entering the road and again near the clearing.
- Ambient accents are timer-based and sparse so the soundscape does not become noisy.

## Combat Timing Changes

- Ghoulkin windup uses the existing windup signal and now has a clearer low warning cue.
- Ghoulkin resolved attacks play a short lunge/impact cue.
- Player hits, blocks, parries, staggers, and deaths now have more distinct procedural timbres.
- Ghoulkin victory plays the restrained victory cue; inspecting post-fight tracks plays a darker clue cue; reporting to Sister Anwen plays a return/report cue.

## Payload Impact

- No audio files were downloaded or imported.
- No long tracks were added.
- All new sounds are generated procedurally at runtime from script.
- Slim export include/exclude rules were not changed.
- Expected Web payload impact: negligible script-byte increase only.

## Verification

Command run:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_runtime.gd
```

Result: passed.

Output:

```text
runtime vertical slice verification complete
```

Known existing note: Godot still reports `ObjectDB instances leaked at exit` after verifier success.

## Known Issues

- This remains procedural placeholder audio, not a professional authored sound library.
- Spatial audio is still limited; most cues are non-positional `AudioStreamPlayer` playback.
- Full browser audio smoke testing was not run in this phase because no export/config/media files changed.

## Recommended Phase 1L

Run a browser smoke and feel pass on `AshenOath_Web_Slim`: export once, play the route in Chrome/Edge, confirm audio unlocks after the first click, verify ambience does not stack too loudly, and tune cue volumes/pitch if anything feels harsh in browser playback.
