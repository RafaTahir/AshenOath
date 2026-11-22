# LOADGAME-002 Result - Crow Flight Loading Interaction

## Status

`verified` for the Milestone-A loader contract.

## Changes

- Formalized Crow Flight as a non-blocking canvas activity during engine startup.
- Preserved keyboard, pointer, touch, and gamepad-A flap input.
- Added rising-edge gamepad handling so a held button does not spam input every
  animation frame.
- Preserved branch obstacles, ember collection, score feedback, reset behavior,
  accessible status text, and reduced-motion fallback.

## Verification

- `verify_loadgame_002.py`: input and reduced-motion contract gate.
- Browser input and actual Web startup: PASS in Chrome and Edge at native
  1280x720 WebGL2 with no console errors. The wait activity is functional and
  the current candidate is below the hard cold-start ceiling; the typical
  startup optimization remains documented follow-up.

## Limitations

Crow Flight is a lightweight browser-side wait activity, not gameplay content
inside the Godot scene. It disappears as soon as the engine reaches readiness.
Measured engine readiness was 8.30 seconds in Chrome and 9.07 seconds in Edge.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_loadgame_002.py .
```
