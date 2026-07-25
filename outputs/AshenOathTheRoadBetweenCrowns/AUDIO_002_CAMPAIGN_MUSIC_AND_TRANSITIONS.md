# AUDIO-002 - Campaign Music and Transitions

## Files Changed

- `scripts/audio_manager.gd`
- `scripts/game.gd`
- `tools/verify_audio_002.gd`
- `tools/gate_profiles.json`
- `PROD_002_ISSUE_REGISTRY.json`

## Implementation

- Added smooth two-player music crossfades instead of abrupt stop/restart changes.
- Added procedural identities for Deep Wood, ash locations, marsh, bandit road, Record Hall, undercroft, assembly, and Hart Glade.
- Added matching low-cost ambience families for wilderness, Castle, interiors, and the finale.
- Centralized zone-to-music selection in `AudioManager.music_state_for_zone()`.
- Preserved master-volume control and the zero-asset payload approach.

## Verification

- `verify_audio_002.gd` validates every campaign state, zone mapping, crossfade lifetime, and ambience stream.
- WORKFLOW-002 audio gate run at ticket completion.

## Running

Open the local Web build through the repository's static server, start New Game, and travel between Greyfen, Wychwood, Castle, and Hart Glade. Music now blends between each authored state.
