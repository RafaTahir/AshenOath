# WORLD-002 Undercroft Composition

Status: retained native camera and real-input improvement.
This is not full WORLD-002, browser, performance or release acceptance.

## Changes

- Original authored elliptical intrados and five masonry ribs replace the flat
  ceiling silhouette. Four bevelled sarcophagi fit the unchanged 4.2x1.6x2.1 m
  tomb collision footprints. A stone processional aisle replaces the mud strip.
- The existing arch decoration is aligned with the actual eastern doorway,
  rather than suggesting an unavailable central exit. Existing doorway wall
  holes, route gates, Halvern, quest state and local-light budgets are preserved.
- The roof has matching overhead collision. That collision declares
  `walkable_support=false`; `SpatialSurfaceContract.support_hit` excludes such
  bodies during grounding without removing physical actor/camera collision.
  Game arrival grounding uses this shared support query.

Mesh: `assets_external/environment/village/UndercroftVault_Authored.res`.
27,872 bytes, 1,960 triangles, two surfaces. SHA256:
`340cd1e065a9edb827a809f783318bcc9c0a674ff7ca58e4257f99804243036e`.
Byte-identical rebake passes. Original project geometry uses existing CC0
runtime surface materials; no external model or placeholder actor is introduced.

## Evidence

- `D:/Temp/AshenOath/world002_undercroft_contract_v2.log`: clean PASS for
  resource bounds, four tombs, overhead collision, actual floor support below
  the roof, and physical capsule crossing both doors in both directions at
  three offsets. Manifest/export ownership is checked, not merely recorded.
- `world002_undercroft_determinism_v1.log`: clean deterministic bake.
- Grounded baseline: `.release-gate/world002_campaign_grounded_baseline/39_undercroft.png`.
  Current visual: `.release-gate/world002_vault_candidate/39_undercroft.png`.
  1280x720, grounded player, inspected by Codex. Vault, tombs and stone aisle are
  retained visual improvements; the unchanged room view does not prove routes.
  Gallery: `WORLD-002_Undercroft_Vault_Authored.png`.
- `world002_undercroft_route_v2.log` plus stderr: clean PASS from genuine
  Continue through Q parry, peaceful witness dialogue and save, both doorways
  physically crossed both ways without jumping, focused assembly travel and
  save. No telemetry mutation or direct interaction shortcuts. Assembly
  activation was 197.7 ms; this does not erase prior cold or first-visible
  failures. It is a resumed native leg, not full browser/campaign acceptance.

## Rejected Evidence

- Bake v1 fails parsing. Bake v2 emits SurfaceTool normal-format errors despite
  printing PASS and is rejected. Initializing the normal format before the
  first vertex resolves the errors in clean v3 output.
- Real-input v1 places the saved actor on top of the roof, then fails movement.
  The arrival ray picked the highest collider as support. This is a real
  regression, not a driver excuse. Current native support regression explicitly
  rays from above the roof and requires the physical floor below it.
- Capture timing 3,437.0 ms and first route activation 1,774.8 ms fail the cold
  target. No new performance claim is made. PERF-001 remains red.

## Running Steps

Use Godot 4.6.3 from
`D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, with child-only
APPDATA/LOCALAPPDATA under `D:/Temp/AshenOath`:

```powershell
& 'C:/Temp/AshenOathGodot4.6.3/Godot_v4.6.3-stable_win64_console.exe' `
  --headless --path . --script res://tools/verify_undercroft_vault.gd
```

Real input uses an isolated copy of the genuine `undercroft_v1_fixture`:
`verify_opening_real_input_native.gd -- --continue-halvern --undercroft-composition-proof`.
The leg resumes saved menus through Escape and uses movement, Q/E and visible
dialogue/save controls only. No flag mutation, teleport or direct interaction.

No commit, push, merge, export or deployment.
