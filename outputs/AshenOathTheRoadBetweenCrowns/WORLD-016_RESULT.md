# WORLD-016 Result

## Scope

This development slice applies the authored presentation pass to Castle Vargan,
the Record Hall, the undercroft, the Greyfen assembly, and Hart Glade. Route
ownership, quest state, gate destinations, collision, and save contracts remain
unchanged.

## Changes

- Castle approach now has military-road shoulder variation, path stones, a
  gatehouse keystone/threshold, and a framed keep entry.
- Castle courtyard now has edge paving, stable framing, a cistern rim, a crest,
  and a restrained training-yard marker.
- Record Hall prop batches preserve authored material tints instead of reusing a
  single pale surface material. The archive now has floor insets, pilasters,
  door arches, lantern accents, a ledger runner, and a warmer ceiling treatment.
- The undercroft reserves its two Balanced light slots for the witness route,
  adds a readable unshaded route inlay, ceiling inlays, wall bands, arch bands,
  and a witness threshold.
- Greyfen assembly now has road wear, witness banners, a dais edge, and a small
  ceremonial fire-bowl marker.
- Hart Glade now has deliberate moss framing, approach stones, a witness
  threshold, and a visible spectral Hart at gameplay distance.
- Enemy visual-role construction now prefers visual-upgrade mappings before
  legacy combat fallbacks for focal creatures.
- White Hart normalization uses its intended focal height and 48 m visibility
  range. Its imported body receives a restrained spectral material while the
  antler crown remains bone-attached.
- The generated Ghoul family keeps readable eyes, jaw, mouth, and teeth while
  consolidating monster materials to six surfaces for the Compatibility budget.

## Verification

- `verify_world_016.gd`: PASS.
- `verify_castle_vargan.gd`: PASS.
- `verify_perf_003.gd`: PASS after Godot reimported the regenerated GLBs.
- `verify_mon_002.gd`: PASS.
- `verify_char_001.gd`: PASS.
- `verify_engine_003.gd`: PASS for active runtime lifecycle/material checks.
- `verify_content_integrity.py`: PASS.
- `capture_world_005.gd`: PASS, fresh 1280x720 Compatibility captures.
- `capture_world_006.gd`: PASS, fresh 1280x720 Compatibility captures.
- `git diff --check`: PASS.

The isolated Godot processes still print shutdown-only renderer allocator,
RID, shader, and ObjectDB diagnostics after capture/verification exit. These
remain release blockers for the complete production gate and are recorded
rather than suppressed.

## Screenshots

Fresh graphical Compatibility captures:

- `Development_Gallery/screenshots/WORLD_005_01_BanditRoad_20260821_091422.png`
- `Development_Gallery/screenshots/WORLD_005_02_CastleApproach_20260821_091422.png`
- `Development_Gallery/screenshots/WORLD_005_03_CastleCourtyard_20260821_091422.png`
- `Development_Gallery/screenshots/WORLD_005_04_RecordHall_20260821_091422.png`
- `Development_Gallery/screenshots/WORLD_006_01_Undercroft_20260821_090821.png`
- `Development_Gallery/screenshots/WORLD_006_02_Assembly_20260821_090821.png`
- `Development_Gallery/screenshots/WORLD_006_03_HartGlade_20260821_090821.png`

The captures are current, nonblank, and route-readable. They remain stylized
development evidence; final approval still requires a complete campaign pass,
stronger bespoke boss/character assets, full export verification, and browser
testing.

## Running

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tools\verify_world_016.gd
& C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1280x720 --rendering-method gl_compatibility --rendering-driver opengl3 --script tools\capture_world_005.gd
& C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1280x720 --rendering-method gl_compatibility --rendering-driver opengl3 --script tools\capture_world_006.gd
```

## Checkpoint

This result is intended for the pushed `codex/soul-rebuild` development branch.
It does not export, modify tracked `web/`, push `main`, or deploy Vercel.
