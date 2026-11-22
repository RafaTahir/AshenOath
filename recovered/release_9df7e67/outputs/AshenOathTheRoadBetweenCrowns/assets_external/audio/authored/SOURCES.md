# Authored runtime audio sources

Only the compressed OGG clips in this directory are runtime assets. Raw archives
and source recordings are not included in the Web export.

| Runtime clip | Original | Source and license |
| --- | --- | --- |
| `greyfen_air.ogg` | `amb_mountains.flac` | Yo Frankie! ambience, Blender Foundation, CC-BY 3.0 |
| `wychwood_air.ogg` | `amb_forest.flac` | Yo Frankie! ambience, Blender Foundation, CC-BY 3.0 |
| `marsh_water.ogg` | `amb_river.flac` | Yo Frankie! ambience, Blender Foundation, CC-BY 3.0 |
| `castle_wind.ogg` | `amb_wind_1.flac` | Yo Frankie! ambience, Blender Foundation, CC-BY 3.0 |
| `river_current.ogg` | `amb_stream.flac` | Yo Frankie! ambience, Blender Foundation, CC-BY 3.0 |
| `forge_hammer.ogg` | `metal-hammer-hit-02.wav` | Tinysized SFX, Vehicle, CC0 |
| `record_page.ogg` | `book-page-02.wav` | Tinysized SFX, Vehicle, CC0 |
| `sword_clash_light.ogg` | `sword-clash-03.wav` | Tinysized SFX, Vehicle, CC0 |
| `sword_clash_heavy.ogg` | `sword-clash-05.wav` | Tinysized SFX, Vehicle, CC0 |
| `sword_sheathe.ogg` | `seax-sheathe-01.wav` | Tinysized SFX, Vehicle, CC0 |
| `record_hall_air.ogg` | `Iwan Gabovitch - Dark Ambience Loop.ogg` | Iwan Gabovitch, CC-BY 3.0 |
| `village_crow.ogg` | `Crows.ogg` | IgnasD, CC0 |
| `wood_step.ogg` | `boots-leather-step-01.wav` | Tinysized SFX, Vehicle, CC0 |

Yo Frankie! source: https://opengameart.org/content/ambient-mountain-river-wind-and-forest-and-waterfall
Archive SHA-256: `4C5D5B57EEB14A8E053F18E17B3392F2C53C226ACBF2A79CCE6D843B3EBED401`.
Credit: "Ambient sounds from Yo Frankie!" by Blender Foundation, licensed under
Creative Commons Attribution 3.0 (https://creativecommons.org/licenses/by/3.0/).
Changes: converted selected FLACs to 48 kHz stereo, 64 kb/s OGG Vorbis.
The quiet forest recording was raised 18 dB before encoding to remain audible
at the Wychwood ambience bus level.
The Wychwood and Castle loops use 0.5-second end-to-start crossfades; Castle
is attenuated 1.9 dB to preserve headroom after its wind gust. The Record Hall
loop uses a 1-second end-to-start crossfade and 5.2 dB attenuation so its
decoded peak stays below full scale. Greyfen and marsh loops were retained.

Additional short event recordings are reproducible with
`tools/build_authored_event_audio.ps1`; `event_manifest.json` records exact source
and runtime checksums, events, trims, gains, authors and pack ownership. These
are candidates, not a claimed listening-quality pass.

Monster vocal source: "Monster Sound Effects Pack" by Ogrebane, CC0-1.0:
https://opengameart.org/content/monster-sound-effects-pack . Archive SHA-256:
`F39C5AE356B1FC01284057EE48E35EC1A52FCC84BFA959B77D0A696ADC8459E4`.
Selected monster-1/2/3/6 supply breath, attack, stagger and death. They are
creature effects, not cloned human dialogue or approved character performances.
Tinysized compressed air/discharge, match, bottle and twig recordings supply
Oathfire, candle, potion and forest events. All use mono 48 kHz Vorbis, short
faded boundaries and conservative source gain. Existing ambience loops and
combat event timing are unchanged; no raw archives enter the runtime.

Tinysized SFX source: https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx
Archive SHA-256: `7F00E2B1DAE15E68DB0E1D6096767F03755E9E7C247128AFC3E935E63774D7DB`.
Original archive readme explicitly states CC0. Selected WAVs were converted to
48 kHz OGG Vorbis. The mono wood step was attenuated 6 dB before encoding for
transient headroom. No voice cloning or speech assets are included.

Dark Ambience Loop source: https://opengameart.org/content/dark-ambience-loop
Source SHA-256: `5CEAFDD6001660EC7DEADFEBF9F03A4E450423889A101B99DF695DFEE07B9972`.
The in-game Credits screen names Iwan Gabovitch as required by the source.
Change: recompressed the 38-second loop to 48 kHz stereo, 48 kb/s OGG Vorbis.

Crows singing source: https://opengameart.org/content/crows-singing
Source SHA-256: `C2AC86EDFE858402A5440488AD8BFA17921E2F4831B58FACB544A928F20C3CAD`.
Author: IgnasD, CC0. Change: converted to 48 kHz stereo, 64 kb/s OGG Vorbis.
