# UI-002 - Menus, Journal, Settings, and Loading

## Improvements

- Added explicit save-source messaging beneath Continue.
- Added direct `Journal & Preparation` access to the pause menu.
- Preserved functional Save, Load, Controls, Settings, and Main Menu routes.
- Updated the visible build identity to `UI-002 MILESTONE D`.
- Kept the prestige menu at a 1920x1080 internal canvas while gameplay remains native 1280x720.
- Confirmed ordinary zone travel never displays or captures input through a blocking loading overlay.

## Verification

`verify_ui_002.gd` checks the full main/pause action sets, 1080p menu canvas, save feedback, key settings, journal access, and nonblocking loading behavior.

## Running

Serve `outputs/AshenOath_Web`, open `http://127.0.0.1:8787`, press Enter, and use the main menu. In game, press `Esc` for pause and select `Journal & Preparation`.
