# AUDIO-001 Recorded Events and Native Mix

2026-09-28. Retained implementation and partial evidence, NOT full acceptance.
Authoritative formal count remains 27/37. Production is unchanged.

## Retained Changes

- Actual AudioStreamPlayer3D landmark and enemy cues, with camera-relative pan
  and the existing Kael-relative range/gain; bounded four-player spatial pool
  shares the original eight-active-cue ceiling with global cues.
- Two-player ambience crossfade, cancellation/retirement, and pause/resume for
  both outgoing and incoming ambience/music. Stopping a zone detaches streams
  rather than allowing the update loop to restart stopped audio.
- One owned cue bus with a native look-ahead limiter at -3 dB. Bus, streams,
  players and crossfade tweens retire cleanly.
- Nine reproducibly converted CC0 mono Vorbis recordings, 72,822 bytes total:
  Ghoulkin breath/attack/hit/death, Oathfire charge/release, candle, potion, twig.
  event_manifest.json binds source/archive/runtime hashes, license, gain,
  duration, events and pack ownership. Two deterministic builds match.
- Enemy signal callers now emit at their world position. Only declared Ghoulkin
  and Bell-Eater roles inherit Ghoulkin vocals. Other opponents use recorded
  cloth/armor/contact rather than fabricated human acting or a Ghoulkin voice.
  This does not claim final distinct vocals for every monster family.

## Current Evidence

All logs below are under D:/Temp/AshenOath. Each current run exits 0 with empty
error output; post-PASS resource/renderer errors are not suppressed.

- audio001_event_import_20260928: clean native resource import.
- audio001_authored_identity_20260928: actual stream registration, nonlooping
  event duration/checksums, surface footsteps, runtime mount replacement,
  actor-family policy, pause, attribution and subtitle-only voice policy PASS.
- audio001_native_identity_20260928: actual stereo PCM on Intel HD 620 ANGLE,
  not headless audio or stream/node presence. Left/right dominant RMS ratio
  approximately 1.69; paused waveform peak exactly 0; resumed audio nonzero.
  Combined combat/landmark/music peak 0.719566, maximum-volume eight impacts
  0.716694, recorded enemy-family mix 0.167351. Crossfade, pool limits and owned
  cue-bus removal PASS. The copied .report.json binds manager/verifier hashes.
- FFmpeg decoded all nine new recordings: highest peak -1.660953 dBFS;
  no decoded file clips. This is technical headroom, not listening approval.

Current manager SHA-256:
`c7eb73c097424b62f22d1843fa40698aa7e2505e93b5e5a1bc687213d1741de4`.
2026-09-28 game caller SHA-256:
`560d4f7966ebc383142e40639948770aafc53cfe59c81281bd2c72f42204f4c5`.

## Rejected / Incomplete Evidence

The earlier unprotected stress mix exceeded full scale (1.022617 combined,
2.035884 at maximum volume); it remains failed history, not a retroactive pass.
The authored fixture's initial unused ZoneResidencyService leak was corrected
by explicit fixture ownership; its original post-PASS failure remains rejected.

This model cannot consume audio input. No line, loop, cue or score is labeled
listening-approved from these measurements. Original prepared music and some
ambient accents remain provisional. Full real-input event synchronization,
listening review, and source-aligned browser unlock/pause/persistence remain
open. Browser acceptance is blocked by the previously documented distinct
PERF-001 failures; no Web export is permitted while native acceptance is red.

## Running Steps / Next Dependency

From D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns:

```powershell
$godot = 'D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/verify_audio_001_authored.gd
& $godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/verify_audio_001_mix.gd
```

Use an isolated AppData directory under D:/Temp/AshenOath and inspect complete
stderr/exit ownership. Do not rerun unchanged native contracts. Exact next
closure dependency is PERF-001: a source-backed mechanism distinct from the
rejected residency/publication/shader-family trials must clear startup and
first-control/settled performance before one combined Web acceptance artifact.
No commit, push, merge, export or deployment occurred.

## 2026-10-01 Real-Input Synchronization

Native synchronization cell closed; whole AUDIO-001 remains unaccepted.
The manager/mix implementation remains unchanged. Removed the extra melee-heavy
cue from `_on_player_beam`: the phase signal already owns Oathfire release.
Actual controls exposed the duplicate before the fix and pass afterward.

- `D:/Temp/AshenOath/audio_sync_before_20261001/`: owned exit 1, exactly the
  unrelated release cue failure. Preserved as rejected history.
- `D:/Temp/AshenOath/audio_sync_after_20261001/`: owned exit 0, physical forward,
  backward and sprint footfalls start recorded cues in the emission frame;
  idle/pause emit none; resume works; one light, one heavy and the three
  sheathe/charge/release phases complete with no replacement cue.
- `D:/Temp/AshenOath/audio_combat_final_input_20261001/`: owned exit 0. Actual
  New Game, Anwen, three clues, five kills, bridges both ways and return report.
  Five-enemy signal-frame audio observes 10 windups, 19 hits, five attacks and
  five deaths. An explicit full-hydration wait isolates cue timing; **this is
  not cold-startup, first-control, FPS or browser acceptance**. Return handoff
  is 725.0 ms; no claim about the complete warm-transition matrix follows.
- `D:/Temp/AshenOath/audio_parry_input_20261001/`: owned exit 0, Continue from
  the original earned Halvern save, physical approach, actual Q parry and
  pause-menu save. Windup and parry cues coincide/coalesce with their signals.
  Original fixture SHA-256 stays
  `98d0376e5c7b5232478b55c53a1206e68bd6b1f85992cccf4711b7a6b7ba8f1c`.

The original cold combat-audio run failed during hydration; the next reached
all five kills but failed a northward camera turn. Neither is retrospectively
passed. The north helper now uses the same per-frame signed-error feedback as
the existing south helper, retaining its 3500-ms deadline and angular limits.
The final clean route supplies affected real-input proof, not a new gameplay
camera change or a waiver of startup failures.

Runtime game SHA-256:
`6c4aa27a09a65dbf9598e8b92d717a6ef35c327b7608eabfe87a5856cdcbd227`.
Final native input-verifier SHA-256:
`7e65ac01aa9601a4c41b12df913bf2d047fc534046d02e60a3885bc86c90642b`.
The earlier manager PCM/headroom proof stays valid at its unchanged scope.
The audio-input tool explicitly reports that this model cannot consume audio;
listening approval remains pending, never inferred from stream/PCM assertions.
Final browser unlock/persistence and PERF-001 remain dependencies. All owned
commands exited; original saves, cumulative work and production are preserved.
