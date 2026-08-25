# LOADGAME-002 Result - Crow Flight Loading Interaction

## Status

`functional_but_incomplete` pending the Milestone-A browser/export release gate.

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
  1280x720 WebGL2 with no console errors. The wait activity is functional;
  cold startup remains above the roadmap timing target.

## Limitations

Crow Flight is a lightweight browser-side wait activity, not gameplay content
inside the Godot scene. It disappears as soon as the engine reaches readiness.
Measured engine readiness was 42.94 seconds in Chrome and 27.11 seconds in
Edge, so the activity improves perceived waiting but does not yet satisfy the
cold-start budget.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_loadgame_002.py .
```
