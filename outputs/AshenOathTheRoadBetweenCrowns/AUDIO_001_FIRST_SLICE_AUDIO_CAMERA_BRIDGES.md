# AUDIO-001 First-Slice Audio, Camera, and Bridges

## Scope

- Replaced first-slice footsteps, weapon movement, metal contact, block, parry, cloth, and village foley with selected CC0 Kenney recordings.
- Added smooth camera zoom using the mouse wheel and Page Up/Page Down.
- Added collision-backed ramps to both ends of every Greyfen and Wychwood bridge so normal walking can mount the deck.

## Assets

- Source: `https://kenney.nl/assets/rpg-audio`
- License: Creative Commons CC0 1.0.
- Selected runtime payload: approximately 344 KB.
- The source pack license is retained at `assets_external/audio/rpg/KENNEY_RPG_AUDIO_LICENSE.txt`.

## Acceptance

- Recorded event variants resolve for first-slice movement, combat, ambience accents, and menu feedback.
- Wheel and keyboard zoom remain within the authored camera range.
- Bridge floor samples remain continuous enough for walking without jumping.
- Runtime, river, audio, performance, Web export, packed startup, and live-browser gates pass before release.

## Release Results

- Authoritative release gate: PASS.
- Native 720p performance: 43.1 FPS average, 43 FPS minimum, 105 ms warm transition.
- Web payload: 63.9 MB total; `index.pck` is 27.6 MB.
- Local PCK SHA-256: `4CF48959A5E771FE2248418CB24423C87FB2738D727E9974D9E70AD01B38DD27`.
- The packed-startup gate verifies that all selected recorded audio is present in the Web build.
