# MOBILE-001 Mobile Feasibility Gate

## Result

The browser build now has a functional landscape touch-control layer backed by
INPUT-001's semantic input router. Mobile browser emulation reaches Greyfen,
shows the touch HUD, preserves gameplay actions, avoids pointer lock, and keeps
the existing desktop controls unchanged.

This proves **mobile Web feasibility**. It does not prove an Android/iOS store
release: no signed native package, physical-device thermal run, battery test,
Safari/iOS test, or store compliance work was available in this workspace.

## Implemented

- Left-thumb analog movement with full-stick automatic running.
- Right-side drag camera control with adjustable sensitivity.
- Multi-touch buttons for light/heavy attack, dodge, jump, block/parry,
  Oathfire, interaction, potion, bomb, journal, and pause.
- Hold and release semantics for block and Oathfire.
- Touch-specific prompts, controls text, and equipment labels.
- Automatic touch detection with `Auto`, `On`, and `Off` settings.
- Landscape gameplay layout with a portrait rotation message.
- Touch controls hide during menus, dialogue, inventory, and paused states.
- Mobile input avoids desktop pointer-lock requests.
- OS-assigned DevTools ports make browser verification resilient to Windows
  dynamic port exclusions.

## Verification

- Runtime, INPUT-001, UI-001, and MOBILE-001 functional gates: pass.
- Chrome mobile landscape emulation: 960x540 WebGL2, engine ready in 22.3
  seconds, Greyfen ready 21.2 seconds after New Game, 10.9 MB JavaScript heap,
  no console errors.
- Edge mobile landscape emulation: 960x540 WebGL2, engine ready in 21.9
  seconds, Greyfen ready 18.6 seconds after New Game, 10.7 MB JavaScript heap,
  no console errors.
- Web candidate: seven files, 64.0 MB total, 27.7 MB PCK.
- Candidate PCK SHA-256:
  `9f0fcaec8892d4e069766fbc156e813759eaf1d2735e14e2ed5b49dc05ca44e9`.

Screenshots:

- `Development_Gallery/screenshots/25_mobile_001_touch_layout_chrome_2026-07-25.png`
- `Development_Gallery/screenshots/25_mobile_001_touch_layout_edge_2026-07-25.png`

## Remaining Mobile Risk

- Real phone GPU, thermal, battery, memory, browser-toolbar, notch/safe-area,
  and multi-touch ergonomics require physical-device testing.
- Portrait gameplay is intentionally blocked with rotate guidance.
- iOS Safari remains unsupported until tested on Apple hardware.
- Native Android/iOS packages, signing, stores, privacy declarations, ratings,
  and platform compliance belong to later MOBILE-002/MOBILE-003 tickets.

## Run Locally

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Desktop:

`http://127.0.0.1:8787/index.html?v=mobile001`

Force the touch layout for desktop inspection:

`http://127.0.0.1:8787/index.html?v=mobile001&touch=1`

## Roadmap

MOBILE-001 completes the original 25-ticket roadmap. The cumulative milestone
now proceeds through the authoritative full verifier, screenshot, export,
packed-startup, desktop/mobile browser, `web/` synchronization, `main` push,
Vercel PCK identity, and live smoke-test workflow.
