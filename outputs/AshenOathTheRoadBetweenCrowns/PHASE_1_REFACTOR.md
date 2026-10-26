# Phase 1: game and HUD service extraction

`scripts/game.gd` is the 91-line composition root. Its subsystem map and the
ownership of all 455 original methods are documented in
[`scripts/systems/README.md`](scripts/systems/README.md) and
[`method_ownership.json`](scripts/systems/method_ownership.json).

`scripts/hud.gd` retains the original resource path and extends the 278-line
[`scripts/hud/hud_root.gd`](scripts/hud/hud_root.gd). The root constructs panels,
injects their shared presentation state, routes request signals, and forwards
the existing public API. Panel ownership is:

| Module | Responsibility |
| --- | --- |
| `quest_panel` | Tracker, compass, navigation and interaction prompt |
| `dialogue_panel` | Dialogue, topics, history, ambient subtitles and introduction skip |
| `inventory_panel` | Inventory, crafting, preparation, vendors and upgrades |
| `settings_panel` | Settings, accessibility, controls and input remapping |
| `combat_feedback` | Resources, enemy status, equipment, notices and attention cues |
| `menu_panel` | Main/pause menus, journey selection, loading and touch menus |
| `save_panel` | Save service access and slot presentation |
| `hud_layout` | Control construction, responsive layout and reflow |
| `hud_input` | Input routing, focus and touch controls |
| `hud_style` | Existing colors, typography, theme and button styling |
| `hud_lifecycle` | Initialization, per-frame presentation and process policy |

`HudState` holds the original presentation fields. `hud_api.gd` and
`hud_component.gd` provide typed compatibility bindings; presentation behavior
belongs to the modules above. Settings, game ownership and save services are
injected explicitly. Services and panels never locate dependencies by walking
up the scene tree.

Save format version 13, world-state keys, authored data, timing constants and
visual values are preserved. The extraction audit compared all 455 game method
bodies, 188 state declarations and 46 constants against base commit
`96e9137c8eb382ea61e8427424c8aa36efcf838d`. Allowed differences are injected node
ownership/callback bindings, observational signals, downward marker lookup and
relocation of two unchanged material helpers. Public compatibility functions
retain coroutine behavior.

## Validation

Run from this project directory with Godot 4.6.3:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tools/verify_boundaries.gd -- --structure-only
godot --headless --path . --script tools/verify_boundaries.gd
python tools/verify_content_integrity.py
```

The full boundary verifier runs on Linux and launches a worker with a fresh
temporary user-data directory. It checks injected references, signal routing,
the real Greyfen -> Wychwood -> Greyfen route, five live Wychwood enemies,
player control, shutdown, current and version-12 save restoration, required
version-13 keys and rejection of future save versions. It keeps every captured
engine/script error as a failure, and retains temporary saves on failure.
`--structure-only` does not require the Linux worker.

Results for this change:

| Check | Result |
| --- | --- |
| Editor import and script parsing | Pass; no script errors |
| Structural boundaries and no ancestor lookups | Pass |
| Game extraction audit | Pass: 455 methods, 188 fields, 46 constants |
| HUD comparison against original implementation | Pass: menu, settings, combat/quest, dialogue, text history, dialogue-close signal count and inventory |
| Quest snapshot isolation | Pass |
| Route, live references, player control and save assertions | Pass; full boundary gate still fails for the NPC error below |
| Fresh runtime packs and production Web export | Pass; all 29 extracted GDScript modules present in root PCK |
| Export/package integrity and native packed startup without source fallback | Pass |
| Complete Web output size, including manifest and external packs | 106,025,335 bytes (101.1136 MiB), strictly below 268,435,456 bytes |

The Web build was staged outside the checkout with all eight pack presets freshly
exported. Lossless packaging used zopfli 0.4.0. Tracked runtime manifests and
`web/` were not replaced. The packed startup result is a headless native check of
the exported packs; browser performance and hardware visual acceptance are not
established by it.

## Existing failures retained

These failures remain visible; no acceptance assertions were removed to make the
refactor pass:

- **Boundary runtime:** `greyfen_life_controller.gd:679` accesses an absent
  `activities` key on a legacy NPC routine. The same error was observed before
  extraction. The final run reports one engine error type and two failed
  assertions, with route/save assertions completing and shutdown succeeding.
- **Content integrity:** eight `bracken_rescue` dialogue actions use
  `companion_choice`, which the existing verifier does not recognize. The
  verifier now scans the extracted systems and still checks all 54 runtime quest
  references.
- **INPUT-004:** three assertions fail both before and after extraction:
  controller guidance text, remap focus and physical Enter dialogue advance.
  Both runs also report the existing deferred reflow-after-free error.
- **SAVE-001:** two assertions fail: corrupt-primary backup recovery and fallback
  slot loading. Its unchanged `GameStub` lacks `zone_root`, and the verifier uses
  old load assumptions. The real-game current/legacy save tests above pass.

The NPC routine, input verifier and legacy save verifier need separate follow-up;
their gameplay behavior and assertions were not rewritten in this extraction.
