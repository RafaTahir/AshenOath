# BOOT-004 - Direct Main Menu Startup

Implementation and production packaging complete; publication pending.
UNVERIFIED - REQUIRES USER TESTING. No game/browser launch, runtime tests,
automated gameplay, screenshots or startup benchmarks were performed.

## Changes

- Removed Crow Flight, its canvas, score, controls, animation/input loops, loading
  page, progress widgets, Enter button and opening-readiness handoff polling.
- The page automatically starts Godot. Its existing startGame implementation
  initializes/downloads WASM and the root PCK together; the old explicit sequential
  Engine.load wait is removed. The game canvas has no HTML cover or reveal gate.
- The existing Greyfen menu image is the browser background during initialization.
  The build copies those original image bytes as `web/menu-background.jpg` and
  includes them in the ordinary artifact manifest/budget.
- Godot shows the real main menu immediately and labels its start action New Game.
  Opening preparation begins after the first menu draw. The old cover helper is
  an inert compatibility method; no runtime caller can hide the menu through it.
- New Game remains actionable while preparation is queued. Complete scenery,
  collision and actual-camera readiness, retry generations, saved journeys, quality
  requirements and all in-game transitions retain their existing owners.
- Preserved the opening-pack early prefetch, verified cache/hash/size/version
  handoff, release identity constants, display metrics and mobile safe areas.
  Pack failure remains owned by the native menu's New Game/retry feedback.
- Browser engine failures show an accessible error panel and Reload. A finite
  startup watchdog postpones its decision while the tab is hidden. Reload never
  clears saves, settings or cached packs. No duplicate engine retry loop exists.

## Files

`web_boot_shell.html`, `scripts/game.gd`, `scripts/hud.gd`,
`tools/build_story_release.ps1`, `tools/publish_living_road.ps1`, current project
state and this record. Generated Web/pack files will be included at publication.
The retained menu artwork, characters, worlds and mobile repair are unchanged.

## Delivery

One minimum production build followed by one combined push/deployment. Static
diff, artifact hash/size and provider-receipt checks only. The complete Web package
must stay below 104,857,600 bytes. Project, output and deployment scratch stay on D:.
Build `boot-004-20261008-direct-menu` completed without compiler errors. The
complete Web directory contains 16 files and 92,408,136 bytes, leaving 12,449,464
bytes below the cap. Build directory: `.release-gate/BOOT-004-20261008-direct-menu-build`.

Stored root PCK: 16,364,412 bytes, SHA-256
`520251062716abf3c42fbb6de9ccf98953ed626731e538664c62adc450c769ba`.
Decoded root: 19,568,400 bytes, SHA-256
`2aed15db56b718f9ce43e1d44ba843efbf31214c780d5d9a03e7f4ca37d735be`.
The menu background is 302,702 bytes, copied from the retained source image.
Build provenance remains `4bc27e14b6729d9d71b64624a0f44ce646eb8bc1` plus the working
changes packaged here. Generated pack ledgers, retained Bracken serialization and
Web output are included with the authored source. Publication receipt is pending.

## Manual Test Checklist

1. Open fresh and cached sessions on desktop/mobile. The native main menu appears
   automatically; there is no crow game, loading page or Enter gate.
2. Click New Game during preparation. Confirm it queues once and opens complete
   Greyfen, with scenery, collision, camera and ordinary movement available.
3. Continue a real save and check choices, inventory, remaps and Touch Aim survive.
4. Check New Game retry after a content failure and Reload after engine failure;
   neither should erase saved data. Check returning from a background tab.

Browser download, preparation time, actual startup behavior and user acceptance
remain unverified. No instant-loading or former performance-target claim is made.
