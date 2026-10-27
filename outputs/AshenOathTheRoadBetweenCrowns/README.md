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

Production contains a root Web artifact, engine files and eight external packs.
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

The reproducible source-only profile is `tools/run_headless_release.ps1`.
It uses the existing release verifier inventory and owned-process runner, writes
unique isolated D: profiles/logs, and rejects engine errors and shutdown leaks.
`-Only` selects diagnostic rechecks; it cannot establish a complete source run.
Reports explicitly identify `headless_release_with_disclosures`: numerical scene
budget overruns remain visible limitations, while the default strict verifier
behavior and original targets are retained. This profile does not certify
rendering, browser/phone behavior, listening quality or reference-PC performance.

Current repair progress is in
[Release repair status](release_reports/release_repair_20261027.json).

[Historical cleanup results](release_reports/release_cleanup_20261027.json)
retain the original failures, source removals and reversible D: archive. Current
repair coverage uses the consolidated run and two targeted fixture rechecks,
with original failing logs preserved. The combined candidate is
`release-repair-20261027`: 17 files, 107,936,848 deployed bytes. Compilation,
pack ownership, transport/decoded integrity and isolated packed startup pass.
Git-triggered publication has a separate receipt under
`.release-gate/living-road/FINISH-016-*/publication.json` at the repository root.
Pending user acceptance is not converted to approval. Bracken is authorized for
release inclusion, not visually approved. Numerical scene-budget overruns and
historical strict-performance failures remain disclosed; no rendered, browser,
phone or listening certification is claimed.
