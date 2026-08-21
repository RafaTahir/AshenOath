# ACCESS-003 Result

## Changes

- Preserved action-based keyboard, mouse, touch, and gamepad input.
- Verified deadzone, inversion, sensitivity, rumble, remapping, conflict swapping, reset defaults, generic glyph profile, and disconnect cleanup.
- Added the missing HUD gamepad-profile contract so PlayStation, Xbox,
  Nintendo, and generic glyph changes reach the visible controls/remap UI.
- Controller disconnect now clears virtual input, releases stale focus, falls
  back to keyboard/mouse, refreshes the profile, and shows a recovery notice.
- Preserved reduced-motion, high-contrast, and subtitle-size settings.

## Verification

- verify_access_003.gd: PASS
- Product ticket gate: PASS (`verify_hud_005`, `verify_audio_007`,
  `verify_access_003`, `verify_perf_008`, `verify_qa_012`)

## Screenshots

- Fresh product views were regenerated at 1280x720/native gameplay and
  1920x1080/menu scale:
  `HUD_005_MainMenu_1080p_20260821_153537.png`,
  `SOUL_REBUILD_Greyfen_Current_20260821_153543.png`, and
  `SOUL_REBUILD_HartGlade_Current_20260821_153544.png`.

## Known limitation

Physical DualShock, DualSense, Xbox, and Switch Pro hardware certification is not claimed in this environment. Generic SDL/browser mappings remain the runtime fallback.

## Running steps

    .\tools\run_ticket_gate.ps1 -Profiles product -NoCache
