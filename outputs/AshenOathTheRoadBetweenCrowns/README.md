# Ashen Oath: The Road Between Crowns

A Godot 4.6 dark-fantasy action RPG, authored here and published as a static Web
game. The current implementation contains six regions, 57 quests, four covenant
resolutions and a playable homecoming. This remains a pre-alpha: implementation,
compilation, automated checks, visual approval and user acceptance are separate.
A successful export does not prove game feel, phone compatibility or performance.

## Open and Play

Import `project.godot` with Godot 4.6 (the retained build tool is 4.6.3).
`scenes/main.tscn` is the entry point. Fresh launches show the main menu; only an
explicit New Game or selected Continue starts a journey. Menu readiness and world
readiness are separate: complete destination scenery, collision, actors and the
gameplay camera must be ready before control is released.

Use the in-game Controls and Settings screens for current keyboard, mouse,
controller and touch bindings. Remapping and saved preferences are authoritative.
Browser audio unlock needs a genuine user gesture. Actual phone and audible
acceptance remain user-owned.

## Current Documentation

- [Campaign throughline and consequences](docs/THROUGHLINE.md)
- [Retained art direction and identities](docs/ART_BIBLE.md)
- [Runtime ownership boundaries](scripts/README_BOUNDARIES.md)
- [Packaging and Git-based publication](WEB_DEPLOY.md)

Obsolete root milestone Markdown and stale root process logs are removed during
release housekeeping. Their committed versions remain available in Git history.
Repository-level plans and machine-readable registries are not erased or promoted
to acceptance. Asset licenses and provenance stay with retained assets.

## Assets and Builds

Runtime catalogs and export presets own inclusion. A raw inventory entry is not
runtime ownership; conversely, a model without literal `.gd` references may still
be required by a catalog, resource, import, fallback or preparation tool.

Production contains a root Web artifact, engine files and seven external packs.
The shared policy is `data/deployment_policy.json`: total deployed files strictly
below 256 MiB, warning at 200 MiB; individual tracked files below 100 MiB. Download
bytes, decoded resources and process memory are different measurements. Removing
excluded source models does not automatically improve Web payload or FPS.

## Checks and Limitations

Existing integration checks live under `tools/`. Headless Godot checks resource
loading, scripted integration and lifecycle errors, not visible rendering, sound
balance, real browser input or phone behavior. Preserve complete scenes, intended
population, saves and quality presets when interpreting results.

Reference-PC targets remain native 1280x720 Balanced on the Intel HD 620 laptop:
32 FPS average, 30 FPS 1% low, peak private memory below 450 MiB, warm transitions
at most 350 ms and cold transitions at most 900 ms. Startup goals remain first
paint 0.75 s; cold/warm menu 12/6 s; navigation-to-control 15/7 s; prepared New Game
handoff 750 ms. These are requirements, not claims that current builds pass them.

## Cleanup Evidence - 2026-10-27

[Cleanup and headless/export results](release_reports/release_cleanup_20261027.json)
record source removals, the reversible D: archive, refreshed technical identities
and exact candidate bytes. Boot and packed startup passed; the full integration
suite is not green. Pending asset review is not silently converted to approval.
Production remains held while the recorded integration/strict-asset gates are red.
