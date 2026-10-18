# OPT-001 through OPT-008: Startup Packaging and Transport

## Outcome

Implementation and compilation complete for the first eight optimization tickets.
Performance, rendered behavior and user acceptance are unverified. The other forty
tickets remain open; OPT-009 received partial shared-transport implementation.

## Retained Changes

- Root selects menu/core resources rather than later-world geometry and actors.
- Lightweight cemetery coordinates remain available for restoration without
  parsing scenery. Zone/social/evidence helper assets load only after pack entry.
- Opening retains complete Greyfen, its cemetery scenery and approved humans.
  Wychwood evidence/ruins/non-Greyfen scene layers move to the adjacent pack.
- Export selections transfer existing assets instead of deleting or re-authoring
  them. Core code/manifests are not deliberately exported in asset-family packs.
- Download dependencies no longer require waiting for dependency mounts. Verified
  files wait for dependency-ordered mounting; errors remain visible and terminal.
- Current journeys take priority over speculative downloads, with at most three
  desktop or two coarse-pointer browser downloads active through the manager.
- Browser pack fetching, hashing, caching and filesystem handoff share one owner;
  obsolete operations cannot publish a new attempt's state. Retry can reload a
  failed manifest or corrupt download without resetting saves or preferences.
- Content-addressed pack caches reuse unchanged bytes across game releases.
- Engine/WASM/worklet files live under an immutable content-derived directory;
  main PCK and release identity remain independent and strictly declared.
- Completed pack operations retain metadata, not a payload-returning promise.
  Native downloads write to their temporary file instead of buffering the body.

## Package

- Build: `opt-m1-20261018-cc97239`.
- Directory: `.release-gate/opt-m1-20261018/final-export` under the D: repository.
- Aggregate deployment: **90390840 bytes**, strictly below **104857600**.
- Manifested artifacts: 16, including seven external packs and the engine family.
- Root PCK: **8994476 bytes**, previously **18915122** (about 52% smaller).
- Root SHA-256:
  `4fece9375d7e60e6f6438e2c29ffc59e7bf140d239fbb840328001a2b33a4346`.
- Engine stem: `engine/ab2c53ed650ba2680cdff4a1/index`.

This does not establish a faster page-to-control time or a higher FPS figure.
The root reduction must not be confused with removing all bytes needed by Greyfen;
those content bytes now have explicit pack ownership and download concurrently.

## Build and Review

Used the existing production packaging command. Corrected the lazy river builder's
explicit float types and new preset options after compiler diagnostics. Static
review also corrected asset-preload dependencies and a ready-pack priority guard.
Only the root export was refreshed for the final root-script corrections; unchanged
asset packs from this build were reused. Package byte/hash consistency and the size
cap are enforced by the existing builder. No QA harness was added or modified.

The existing builder regenerated Bracken's serialized artifact; its recorded input
hash and target dimensions are unchanged. Unrelated untracked diagnostic/export
directories were not staged, removed or modified.

## User Checklist

1. Open the published URL in desktop and phone browsers: menu first, then explicit
   New Game; complete Greyfen and retained Kael/Anwen bodies at first control.
2. Walk the bridge, interact with Anwen and enter/return from Wychwood; check the
   cemetery, equipment, required actors, scenery and normal combat presentation.
3. Save, reload and Continue; confirm exact journey, XP, settings and visual preset.
4. Retry after an interrupted download, then reload normally; no stuck state or
   duplicate journey. Compare cold and repeat total loading time and smoothness.

Agent game launches, browser QA, gameplay tests, benchmarks and screenshots: none.
