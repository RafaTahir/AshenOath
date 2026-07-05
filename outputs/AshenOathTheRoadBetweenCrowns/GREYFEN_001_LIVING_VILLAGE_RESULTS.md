# GREYFEN-001 - Living Greyfen Village and Playable Minigames

## Implementation
- Added one shared Greyfen life controller with fixed, collision-safe waypoint routines.
- Balanced has eight ambient villagers plus Tor, Mira, and Rook; Potato has six plus named NPCs; Quality has ten plus named NPCs.
- Added walking, shrine pilgrim, forge helper, herbalist helper, worried villager, young-villager substitute, water carrier, and quality-only routines.
- Added twelve rate-limited ambient lines. Nearby villagers pause, face Kael, speak, and resume.
- Added functional village well, notice board, forge corner, shrine bench, common game table, and barrel draughts board.

## Minigames
- Three Marks is complete tic-tac-toe with win/block/center/corner NPC logic, win/loss/draw states, restart, exit, mouse, and keyboard focus.
- Greyfen Draughts is a complete 6x6 variant with mandatory diagonal captures, crowning, win/loss states, restart, exit, and capture-first NPC logic.
- World simulation pauses while playing and controls restore on exit.
- One-time wins grant Rook's road hint or Tor's Vargan-iron hint plus one scrap iron.

## Save and Performance
- StoryState stores games played, wins, reward claims, and social hints. Cosmetic routine positions reset on load.
- No pathfinding or per-villager process scripts are used. Ambient villagers share lightweight geometry and centralized procedural locomotion.
- Both games and all consequential NPCs remain present in Potato Mode.

## Verification
- `tools/verify_greyfen_life.gd`
- `tools/verify_runtime.gd`
- `tools/verify_visible_quality.gd`
- Full repository verifier suite, Web export verifier, and packed-build startup run during deployment.

## Screenshots
- `Development_Gallery/screenshots/Capture_42_greyfen_living_street_2026-07-05_191711.png`
- `Development_Gallery/screenshots/Capture_43_blacksmith_routine_2026-07-05_191711.png`
- `Development_Gallery/screenshots/Capture_44_shrine_pilgrim_2026-07-05_191711.png`
- `Development_Gallery/screenshots/Capture_45_notice_board_interaction_2026-07-05_191711.png`
- `Development_Gallery/screenshots/Capture_46_tic_tac_toe_ui_2026-07-05_191711.png`
- `Development_Gallery/screenshots/Capture_47_greyfen_draughts_ui_2026-07-05_191711.png`
- `Development_Gallery/screenshots/Capture_48_minigame_tables_world_2026-07-05_191711.png`
- `Development_Gallery/screenshots/Capture_49_greyfen_life_wide_2026-07-05_191711.png`

## Release
- Commit: the `GREYFEN-001` commit containing this report; exact hash is reported after push.
- Deployment: slim Web build to `https://ashenoath.vercel.app/` after all gates pass.

## Remaining Weaknesses
- Ambient villagers intentionally use inexpensive stylized bodies rather than additional full skeletal rigs.
- Draughts uses single captures rather than chained multi-jumps.
- The village remains visually stylized and browser-budgeted rather than photoreal.
