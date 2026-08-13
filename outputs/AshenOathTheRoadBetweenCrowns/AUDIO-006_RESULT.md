# AUDIO-006 — Opening Soundscape

## Changes

- Added `OpeningSoundscape`, a single low-frequency coordinator for region-aware accents.
- Added lightweight procedural cues for river current, forge hammer, forest breath, stone interiors, and Oath Gate states.
- Added distance attenuation and shared cooldown handling so nearby accents do not stack into noise.
- Connected Greyfen, Wychwood, cemetery, Castle, Record Hall, Undercroft, Assembly, and Hart Glade profiles to the existing `AudioManager` master-volume path.
- Added shrine, forge, village, forest, river, and landmark anchor discovery without per-prop audio scripts.
- Bound Oath Gate awakening, preload, ready, travel, and error states to restrained audio feedback.
- Kept existing recorded footstep variants and surface selection for road, forest, mud, stone, and wood.

## Verification

Targeted gate command:

```powershell
$files=@(
  'outputs/AshenOathTheRoadBetweenCrowns/scripts/audio_manager.gd',
  'outputs/AshenOathTheRoadBetweenCrowns/scripts/opening_soundscape.gd',
  'outputs/AshenOathTheRoadBetweenCrowns/scripts/oath_gate_portal.gd',
  'outputs/AshenOathTheRoadBetweenCrowns/scripts/game.gd',
  'outputs/AshenOathTheRoadBetweenCrowns/tools/verify_audio_006.gd',
  'outputs/AshenOathTheRoadBetweenCrowns/tools/capture_audio_006.gd',
  'outputs/AshenOathTheRoadBetweenCrowns/tools/gate_profiles.json'
)
.\tools\run_ticket_gate.ps1 -Profiles audio_006 -ChangedViews opening_soundscape -ChangedFiles $files -NoCache
```

Result: **PASS**.

Passed gates: content integrity, runtime smoke, `verify_audio_006`, existing audio runtime, campaign audio, runtime regressions, functional props, zone budgets, visible quality, and graphical capture.

Fresh 1280x720 captures:

- `Development_Gallery/screenshots/AUDIO-006_01_Greyfen_Shrine_20260813_112612.png`
- `Development_Gallery/screenshots/AUDIO-006_02_Greyfen_Forge_20260813_112612.png`
- `Development_Gallery/screenshots/AUDIO-006_03_Greyfen_River_20260813_112612.png`
- `Development_Gallery/screenshots/AUDIO-006_04_Wychwood_Gate_20260813_112612.png`

## Running Steps

From the project directory:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe' --path .
```

Then choose **New Game**, approach Sister Anwen, walk toward the forge, cross the Greyfen bridge, and enter Wychwood. Keep the master volume above zero to hear the layered accents. Use `Esc` to pause and confirm ambience/music pause and resume normally.

For the lightweight direct runtime check:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script tools/verify_audio_006.gd --quit-after 90
```

## Known Limitations

- The sound library remains intentionally procedural and compact; it is not final recorded voice or orchestral production.
- Existing Godot Compatibility teardown output still reports null-material/RID/ObjectDB cleanup diagnostics after test shutdown. The active ticket gates pass, but this remains tracked for the engine/resource-lifecycle work.
- Fresh capture output demonstrates the changed route and framing, not the audible result; audio acceptance is covered by the runtime contract and existing audio tests.

## Next Ticket

`OPENING-QA-001 — First 90-Minute Gate`.
