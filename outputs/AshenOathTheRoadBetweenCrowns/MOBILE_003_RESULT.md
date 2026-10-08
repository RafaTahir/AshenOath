# MOBILE-003 - Landscape Startup and Menu Repair

Implemented, packaged and published. Runtime acceptance belongs
to the user. No game, browser, automated gameplay, screenshots or benchmarks were
run for this change. The single BOOT-005 browser session remains historical evidence,
not acceptance of MOBILE-003 or of iPhone/WebKit.

## Source Causes and Changes

- The old touch layout required a fitted, safe 560x300 CSS-pixel region. Landscape
  phones with browser chrome can fail that condition despite their screen orientation.
  The existing safety callback then pauses a newly started game and disables Resume.
  A compact layout now fits a 360px-wide safe region with at least 200px height;
  actual fitted dimensions must still accommodate the controls. Combat/navigation/Use
  targets retain at least 48px diameter, with independent movement and look regions.
  Portrait and genuinely insufficient regions still expose a visible pause reason.
- Short displays use smaller fixed menu typography, spacing and padding, bounded
  scrolling, and a clipped frame. Main/pause summaries and decorative subtitles are
  omitted from the compact header; their content remains in Saved Journeys/Journal.
  Resume stays in the existing footer as well as the scrollable action list.
- Compact gameplay notices and interaction text share the center region when there
  is insufficient height for both. Notice/hint/status priority prevents overlap;
  the Use target remains separate and retains the current interaction model.
- New Game preparation no longer waits for a click merely because a Continue save
  exists. Normal Continue cancels preparation through the existing attempt generation
  and load flow. No save contents or settings are cleared or rewritten by this change.
- Greyfen and Kael remain hidden while required stages are assembled. The complete
  gameplay view is published/rendered before readiness, avoiding the earlier partial
  world render and intermediate GPU submissions during construction. Buildings,
  scenery, population, collision, materials, camera and readiness checks are retained.
- Escape the three literal percentage signs in the dialogue SVG format string.
  This removes the source error behind the previously recorded unsupported-format
  diagnostic; it is not claimed as a fresh zero-console-error result.

## Files

`scripts/mobile_touch_layout.gd`, `scripts/hud_layout_policy.gd`, `scripts/hud.gd`,
`scripts/game.gd`, `scripts/hud_visual_style.gd`, current project state, this record,
and the aligned generated Web/pack manifests and transport files.

## Unverified

Actual iPhone/WebKit clicks, orientation/chrome changes, New Game/Continue handoff,
short-screen rendering, and cold/warm loading times require user testing. The
previous measured 25.3-second click-to-ready remains historical; no new speed or
performance target compliance is claimed. This is not instant loading: engine and
opening content still need to download and first-use rendering still occurs.

## Manual Test Checklist

1. Open the updated production URL in iPhone landscape with browser controls visible.
   Confirm New Game/Continue are readable, scrollable, and activate on a normal tap.
2. Select New Game once. Confirm complete Greyfen and touch controls appear without
   an unexpected Paused screen; move, turn, cross the bridge, and use Anwen.
3. Pause and Resume. Rotate portrait/landscape and hide/show browser controls;
   confirm the landscape layout permits Resume and controls recover.
4. Save, reload, and Continue; confirm the saved location/preferences remain. Compare
   fresh and repeat page-to-control waits and report any remaining stall.

## Packaging and Publication

The single `mobile-003-20261008-landscape` production build succeeded, including
script compilation, resource import, all runtime pack exports and the Web export.
The aligned files are synchronized to tracked `web/` on D:. Whole package:
92,419,781 bytes (88.14 MiB; 16 files including the release manifest), below
the 104,857,600-byte cap. The manifest's hashed artifact subtotal is 92,412,944
bytes; the standalone release manifest accounts for the difference.

Stored root PCK: 16,375,512 bytes, SHA-256
`6a4058e4373464075c31fc07d0016474889ee8f1e97d4cb2a5fca8937f14a488`.
Decoded root: 19,583,448 bytes, SHA-256
`24badee554aa5dcdc9462363a962afb58f232940d29b67c25ecc165ebfeeb7a6`.
Provenance: `967079b73cf79373c18c881ffeda21d2b9043bf3` plus the packaged
working changes. The standard build regenerated Bracken's scene/byte ledger;
its source, dimensions and animation definitions are unchanged.

Build output/logs: `.release-gate/MOBILE-003-20261008-landscape-build/`.
Prior Web files are preserved in its `previous-web/` directory.

Package commit `9ac593a7dd194c3eb1fb01d68832bfe306257a52` is pushed to
`codex/masterpiece-rebuild` and `main`; the existing D: main worktree was
fast-forwarded without changing unrelated work. GitHub's existing Vercel integration
reports deployment complete. No separate CLI authorization retry was attempted.
The live release manifest matches all 15 hashed artifact records; the directly
downloaded live root PCK matches the local stored hash and size above.

Live: https://ashenoath.vercel.app/?v=mobile-003-9ac593a
Receipt: `.release-gate/living-road/MOBILE-003-20261008T090213Z/publication.json`.
These are static publication identity checks, not game/browser acceptance.
No runtime test was performed or is scheduled. Next action: user manual testing.
