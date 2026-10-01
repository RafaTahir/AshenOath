# WORLD-002 Old Mill Composition

Status: retained native visual improvement; not full WORLD-002 acceptance.

## Composition

- A deterministic 59,294-byte, two-surface mesh uses retained CC0 Quaternius
  stone, wood-grid, gable and tile sources. The eastern roof is burned away to
  keep Ashwing and clue sightlines open. Its original wheel assembly has actual
  rims, spokes, paddles and an axle perpendicular to the west wall.
- An irregular metre-UV cart track replaces the dashed slab-like wear. A low
  distant bank beyond the unchanged zone bounds closes the exposed horizon.
- Original wall, doorway and reservation collision, arena, clue positions,
  actors, route gates, boss and consequence state remain unchanged. No new
  collision belongs to the purely visual wheel, track or distant terrain.

Files: `build_ash_mill.gd`, `verify_ash_mill.gd`,
`campaign_wilderness_section.gd`, `AshMill_Authored.res`, runtime manifest,
campaign export filter, narrow gate profile and mandatory release-runner entry.

SHA256: `9fecc6ce7ab506676d87e4278f24f02bde81d2817c5866bc56e61893ecae2e69`.
4,271 triangles. Source hashes/license are embedded; rebake is byte-identical.

## Evidence

- `D:/Temp/AshenOath/world002_ash_mill_contract_v3.log`: PASS with clean exit.
  Required resource/material/hash/license/filter checks and real CharacterBody
  open-front sweeps at five offsets in both directions pass; the rear wall
  continues to block. Distant terrain is outside the playable boundary.
- `world002_ash_mill_determinism_v1.log`: clean byte-identical rebake.
- Grounded identical-camera baseline: `.release-gate/world002_campaign_grounded_baseline/32_ash_mill.png`.
  Current: `.release-gate/world002_mill_final_current/32_ash_mill.png`.
  Capture v3 passes at 1280x720 with feet on support and clean shutdown. Codex
  inspected the scene and retained architecture, wheel fit, route and horizon
  changes. This staged image is not player-route or story evidence.
- `world002_mill_route_v1.log` plus stderr: PASS, genuine Continue from the
  preserved arrival save, physical millstones approach, focused E, two sword
  kills, exactly one Ashwing and pause-menu save, with clean shutdown. This is
  a resumed native leg, not uninterrupted or browser campaign acceptance.
  Activation was 1,111.8 ms and fails the cold 900 ms target.

## Rejected Or Superseded Evidence

- Bake v1 had an unindexed-array script error despite a printed PASS and is
  rejected. Indexed geometry fixes it. Earlier clean shell-only bakes are
  superseded by the complete current composition.
- Capture v2 showed the wheel intersecting a wall because it inherited the old
  decorative disc orientation. Its retained wheel geometry is not accepted;
  the final wheel has a perpendicular axle and rim outside the masonry.
- Record Hall and Castle partial passes remain valid at their own dependency
  scope. No full campaign visual, night, browser, FPS or payload acceptance is
  inferred from this mill pass. PERF-001 remains red; no Web export was run.

## Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, use Godot
4.6.3 with child-only APPDATA/LOCALAPPDATA under `D:/Temp/AshenOath`:

```powershell
& 'C:/Temp/AshenOathGodot4.6.3/Godot_v4.6.3-stable_win64_console.exe' `
  --headless --path . --script res://tools/verify_ash_mill.gd
```

The actual input leg uses an isolated copy of the genuine `ash_mill_v1_fixture`
and `verify_opening_real_input_native.gd -- --continue-ash-mill-clue`.
No commit, push, merge, export or deployment.
