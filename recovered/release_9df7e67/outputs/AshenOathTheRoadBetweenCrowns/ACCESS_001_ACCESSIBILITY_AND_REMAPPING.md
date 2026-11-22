# ACCESS-001 - Accessibility and Remapping

## Improvements

- Added persistent Standard and Left-Handed keyboard/mouse layouts.
- Left-Handed uses `IJKL`, `O` interact, `U` guard, `N` dodge, `M` jump, and swapped mouse attacks.
- Added High Contrast HUD text outlines.
- Applied subtitle scaling directly to dialogue text.
- Reduced Motion now suppresses the low-health pulse in addition to camera and world motion reductions.
- Preserved keyboard/gamepad focus on every menu button.

## Verification

`verify_access_001.gd` validates both control layouts, action labels, subtitle scale, high contrast, reduced motion, and focusability.

## Running

Serve `outputs/AshenOath_Web`, open `http://127.0.0.1:8787`, choose `Settings`, then adjust `Control Layout`, `High Contrast`, `Subtitle Size`, and `Reduced Motion`.
