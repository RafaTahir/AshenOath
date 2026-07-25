# INPUT-001 Input Abstraction

## Result

INPUT-001 replaces scattered direct input handling with a shared semantic
`InputRouter`. Existing keyboard and mouse controls remain compatible, while
gameplay, menus, prompts, settings, and camera controls now support an
Xbox-style gamepad. Virtual axes and actions provide the foundation required by
MOBILE-001 without adding touch UI in this ticket.

## Changes

- Added semantic movement, look, action, device-detection, label, virtual-input,
  and rumble APIs in `scripts/input_router.gd`.
- Routed player movement, combat, blocking, items, dodge, jump, Oathfire, camera
  look, sprint FOV, and zoom through the shared service.
- Added controller focus and cancel behavior to menus, dialogue, inventory, and
  minigames.
- Added device-aware HUD prompts, guidance, equipment shortcuts, and controls
  text.
- Added controller-look sensitivity and vibration settings with persistence.
- Added `verify_input_001.gd`, the `input` ticket-gate profile, and explicit Web
  export inclusion.

## Default Gamepad Layout

- Left stick: move
- Right stick: camera
- `A`: interact/accept
- `B`: dodge/cancel
- `Y`: jump
- `L3`: run
- `RB`: light attack
- `RT`: heavy attack
- `LB`: block/parry
- `LT`: hold Oathfire
- D-pad left/right: potion/bomb
- D-pad up/down: camera zoom
- View/Menu: inventory/pause

## Verification

- INPUT-001, runtime regression, UI, motion, combat, AI, and Oathfire gates:
  pass.
- Static Web configuration, 64.0 MB export, 27.7 MB PCK, packed startup, and
  seven-file artifact contract: pass.
- PCK SHA-256:
  `3f687630fb17d647ae3387b4ad10bac2c8ff1b8115aa34e4f166814ebd11be76`.
- Chrome: 1280x720 WebGL2, engine ready in 18.9 seconds, Greyfen ready 16.3
  seconds after New Game, 10.4 MB JavaScript heap, no console errors.
- Edge: 1280x720 WebGL2, engine ready in 14.1 seconds, Greyfen ready 14.0
  seconds after New Game, 10.6 MB JavaScript heap, no console errors.

The automated tests validate controller mappings, device switching, semantic
input behavior, virtual touch hooks, focus, prompts, settings, and service
wiring. A physical gamepad was not available for hands-on hardware validation,
so vibration strength, controller-specific browser quirks, and subjective stick
feel remain final milestone QA items.

## Deployment

This is a development-branch checkpoint. It does not synchronize tracked
`web/`, push `main`, or deploy Vercel. `MOBILE-001` is the final roadmap ticket;
the complete milestone release and production deployment follow it.

## Run Locally

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Open `http://127.0.0.1:8787/index.html?v=input001`, click the game, press
`Enter`, then choose `New Game`. A connected gamepad can be used immediately;
pressing any gamepad control switches the on-screen prompts.

## Remaining Roadmap

1. `MOBILE-001`

Production deployment follows successful completion of that final ticket.
