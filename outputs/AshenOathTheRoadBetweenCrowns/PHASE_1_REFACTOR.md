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
godot --headless --path . --script tools/verify_greyfen_routine_ownership.gd
godot --headless --path . --script tools/verify_save_001.gd
godot --headless --path . --script tools/verify_input_004.gd
python -m unittest discover -s tools -p test_content_integrity.py -v
python tools/verify_content_integrity.py
```

The full boundary verifier runs on Linux and launches a worker with a fresh
temporary user-data directory. It checks injected references, signal routing,
the real Greyfen -> Wychwood -> Greyfen route, five live Wychwood enemies,
player control, shutdown, current and version-12 save restoration, required
version-13 keys and rejection of future save versions. It keeps every captured
engine/script error as a failure, and retains temporary saves on failure.
`--structure-only` does not require the Linux worker.

SAVE-001 also creates an isolated child-process profile. Run INPUT-004 with a
temporary user-data profile because it exercises persisted input bindings; in
Linux, set `XDG_DATA_HOME` to a newly created temporary directory before launching
Godot.

Results for this change:

| Check | Result |
| --- | --- |
| Editor import and script parsing | Pass; no script errors |
| Structural boundaries and no ancestor lookups | Pass |
| Game extraction audit | Pass: 455 methods, 188 fields, 46 constants |
| HUD comparison against original implementation | Pass: menu, settings, combat/quest, dialogue, text history, dialogue-close signal count and inventory |
| Quest snapshot isolation | Pass |
| Full route, live references, player control, current/version-12 save restoration and shutdown | Pass: 15,492 checks, zero failures, engine errors or warnings |
| Greyfen routine ownership regression | Pass: 137 checks; original code fails eight ownership assertions |
| Content integrity and companion contract regression | Pass: 21 quests, 84 objectives, 117 dialogue actions, 54 runtime references; five regression tests |
| INPUT-004 | Pass, including physical Enter press/repeat/release, held-input rejection, settled focus and pending-reflow teardown |
| SAVE-001 | Pass: 120 checks, zero engine/script errors; backup generation, corrupt-primary recovery, ordered fallback and future-version preservation |
| Fresh runtime packs and production Web export | Pass; all 29 extracted GDScript modules present in root PCK |
| Export/package integrity and native packed startup without source fallback | Pass |
| Complete Web output size, including manifest and external packs | 106,025,344 bytes (101.1136 MiB), strictly below 268,435,456 bytes |

The initial Web build was staged outside the checkout with all eight pack presets
freshly exported. The follow-up root export reused those packs only after checking
their hashes, sizes and that no changed source/dependency path belongs to them.
All five changed compiled application scripts are present in the refreshed root
PCK. Lossless packaging used zopfli 0.4.0. Tracked runtime manifests and
`web/` were not replaced. The packed startup result is a headless native check of
the exported packs; browser performance and hardware visual acceptance are not
established by it.

## Follow-up fixes for the four failing categories

- **Greyfen NPC runtime defect:** regional enrollment replaced an actor's profile
  but left its queued village routine and temporary-activity restoration data
  pointing to the old profile, which has no regional `activities` field. The
  promotion boundary now invalidates the old queue and updates existing table/
  gathering restoration snapshots to the authored regional routine. No default
  activities were invented. Regression coverage exercises initial enrollment,
  unchanged story signatures, deferred hydration, reconfiguration, phase/story
  changes and both restoration paths; it failed eight assertions before the fix.
- **Companion validator contract defect:** runtime already dispatches all eight
  authored `companion_choice` entries to the seven supported Bracken operations.
  The validator now recognizes that action type and requires a valid
  `companion_action`. Negative tests reject missing, malformed and unknown
  operations, unknown action types and invalid quest references. Authored choices
  and runtime quest behavior are unchanged.
- **INPUT-004 runtime and harness defects:** physical-only Enter/Space events were
  recognized by the HUD but rejected by the router's logical-key action binding.
  A copied event now supplies the matching logical key for the same router
  validation, retaining held-input guards and release activation. Reflow keeps
  its next-frame scheduling through a node-owned one-shot callback that cancels
  on destruction. The verifier checks current controller instructions and waits
  a bounded number of frames for focus on the active surface instead of expecting
  old text and immediate focus. Press/repeat/release, duplicate release, router
  rejection and pending-reflow destruction assertions protect the intended
  behavior. All seven HUD comparisons still pass.
- **SAVE-001 harness defects:** the old stub lacked `zone_root`, used unregistered
  filenames and expected request acceptance to synchronously apply a save. The
  verifier now owns an empty zone, writes registered slots only in an isolated
  profile and exercises prepare/accept/complete semantics. It verifies selected
  slot/source identity, exact backup generation, ordered fallback, all-corrupt
  rejection, unchanged rejected files and future-save preservation. Unwritable
  fixtures and script errors fail the test. SaveManager needed no changes; the
  separate full boundary test verifies real-game restoration.

No requested gate remains failing. HUD/input checks retain the pre-existing
anchor-size warning, also observed in the original HUD comparison. The full
boundary reports no warnings/errors; the Web build has no error diagnostics. Hardware/browser visual
and performance acceptance remains outside these headless checks.
