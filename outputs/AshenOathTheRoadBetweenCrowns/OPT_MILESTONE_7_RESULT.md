# OPT Milestone 7 - OPT-049 through OPT-051

## Implementation

- Alpha batch separation and conservative static bounds default ON. Interior
  occlusion defaults requested ON but is unsupported/effectively OFF on stock
  Web; its early guard skips occluder allocation. Native requests are effective.
- Query/native `opt_alpha`, `opt_bounds`, `opt_occlusion` accept explicit 0/1.
  No saved quality preferences or journey data are modified.
- Optional `?perf=1` / `--perf=1` uses the existing monitor. It includes slow
  positive gameplay frames, per-zone worst frame and >50ms hitch count, rolling
  FPS, option states and available boot/transition timings. Sampling is off
  normally; paused/menu frames are not presented as gameplay measurements.
- Service registry loads only the requested script paths in its existing order.
  Gameplay-only coordinator scripts are cached on first use instead of eager
  menu parsing. Required script errors are explicit, never replaced with stubs.
- Fixed Wychwood integrated ground, winding path, clearing, layby and rounded
  berm geometry compiles offline through the existing asset compiler. Source
  vertex, UV, normal and color generation is retained verbatim. Collision,
  quality-specific materials and random/story overlays retain their owners.
- Wychwood prepared resources belong to the adjacent pack, not the campaign.

## Build / Publication

Production build `opt-m7-20261019-efd9132` compiled and packaged with the existing
`tools/build_story_release.ps1` command. Manifest artifacts: 104329973 bytes;
complete Web directory: 104337805 bytes, strictly below 104857600.
Root PCK SHA-256:
`7238f721bd235f85f4b3231c088ce72ca7fa399dbd852b7276b32b14b1e8d23b`.
OPT-051 publication receipt records its commit, push and Vercel outcome under
the existing `.release-gate/living-road/OPT-051-*/publication.json` path.
No runtime tests,
gameplay, browser QA, screenshots or benchmarks are authorized or performed.
User acceptance: pending. No measured performance gain is claimed.

## User Checks

Compare defaults with each explicit 0/1 override and optional perf display.
Check New Game/Continue, complete Greyfen, Wychwood terrain/river joins and
quality changes. Native occlusion needs a native comparison; Web must report
unsupported even when `opt_occlusion=1` is requested.
