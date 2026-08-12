# INPUT-003 / INPUT-004 Result

## Scope

This checkpoint extends the existing action-based input router with gamepad-family detection and controller-aware prompt labels. It preserves keyboard, mouse, and touch actions.

## Changes

- Detects connected controllers and hotplug/reconnect events through Godot's joypad signals.
- Classifies PlayStation, Nintendo, Xbox/XInput, and generic recognized devices for prompt labels.
- Keeps semantic actions independent of physical glyphs, so gameplay bindings do not change when a device changes.
- Refreshes HUD prompts and equipment guidance when the active controller family changes.
- Preserves the existing default action layout and keyboard fallback.

## Verification

- `verify_input_001.gd`: PASS for keyboard, gamepad action map, menu focus, settings, prompts, and virtual input.
- Runtime startup: PASS.
- Physical DualShock, DualSense, Switch Pro, and Xbox hardware: not available in this environment; browser/Godot mapping remains the next hardware acceptance gate.

## Known limitations

- Full remapping UI, glyph image families, calibration screens, and guarded vibration settings remain `INPUT-004` follow-up work.
- The current Godot shutdown path reports renderer cleanup warnings unrelated to input behavior.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://tools/verify_input_001.gd
```

For a browser build, export with `Export_Web_Build.bat`, serve `..\AshenOath_Web` on port 8787, and use a connected controller recognized by the browser.
