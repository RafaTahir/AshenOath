# Browser Audio Routing Repair

## Incident And Cause

The user reported complete silence in the deployed game. This was reproduced
on `greyfen-village-20261024`, commit `9285373`.

- GitHub `main`, `codex/masterpiece-rebuild` and the D: checkout matched.
- All 16 Vercel artifacts, including both worklets and every PCK, matched the
  local release manifest exactly; HTTP status, gzip headers and MIME types were
  correct. The release manifest itself also matched.
- Existing native actual-PCM mix verification passed: resumed-world peak
  0.0136677; combined combat/music peak 0.709257; native pause output zero.
- In the Web build, the real AudioContext was running, Master was unmuted,
  music reported playing, and no audio-resource failure was reported.
- A temporary local page using those same game/engine/pack bytes measured
  nonzero source samples (menu music peak 0.0448322) and a nonzero sample-bus
  output (peak 0.00798187), but exactly zero destination-bound output.
- Connection tracing found a cycle between the nominal Master/Cues/Music
  buses, with Master no longer connected to AudioDestinationNode.

Godot 4.6.3 `AudioServer.add_bus(count)` normalizes append to `-1`. Its Web
sample-driver `Bus.addAt(-1)` passes that sentinel through `Bus.move`, which
uses `splice(toIndex - 1, ...)`. Native and browser bus indices then disagree.
Subsequent sends/volumes target different browser buses, producing the cycle.

Engine references: [AudioServer](https://github.com/godotengine/godot/blob/4.6.3-stable/servers/audio/audio_server.cpp),
[Web sample buses](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/web/js/libs/library_godot_audio.js).

## Repair

`audio_manager.gd` grows the bus count before naming/routing each owned bus,
instead of calling `add_bus` at the append position. `set_bus_count` preserves
the order in both the engine and browser sample driver. No engine patch,
streaming-mode change, audio re-encoding or volume increase is required.

Candidate: `audio-routing-20261025`. Only the affected code/base package is
rebuilt. External packs are reused after decoded-byte/hash checks and checking
that none contains an overriding AudioManager compiled script/remap.

## Delivery Evidence

Implementation, AudioManager parser check and production compilation: passed.
The fixed browser graph sends Cues/Music/Voice to the same Master, and Master
to AudioDestinationNode, with no routing cycle. Menu destination-bound peak:
0.005423 (previously exactly zero). Windows' actual browser-session output
peak: 0.005226 after New Game, zero while paused, 0.005751 after Resume.
Normal keyboard movement and pause/resume were exercised. No unexpected
audio-resource or JavaScript error was reported during this focused check.

Complete package: **104,672,481 bytes**, **185,119 bytes** below the strict cap.
All seven external content packs and the complete engine match their prior
bytes. Production publication is owned by the CAST-010 receipt under
`.release-gate/living-road/`; this record is not a full-campaign acceptance.

The temporary analyser is not part of the shipped page. Actual phone/WebKit
playback and subjective mix balance still require the user's review.
