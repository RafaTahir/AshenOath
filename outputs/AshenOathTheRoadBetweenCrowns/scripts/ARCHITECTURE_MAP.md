# Live Architecture Map

Current source: Phase 5 on `refactor/phase-5-replay-benchmarks-and-repo-cleanup`,
based on Phase 4 `6aab02c`. Metrics below describe the final runtime sources;
Phase 5 changes test/CI/status/archive ownership, not gameplay implementation.
Historical comparison: Phase 0 `130ab3e`, scanned from production `3707be3`.
Counts use the existing token-aware architecture checker and physical splitlines.

## Measured Structure

| Runtime source metric | Phase 0 | Phase 5 |
| --- | ---: | ---: |
| GDScript files under scripts/ | 242 | 319 |
| Total physical lines | 82388 | 83304 |
| Incompletely typed functions/lambdas | 687 | 603 |
| Reflection/metadata calls | 1728 | 1357 |
| Global RNG calls | 40 | 36 |
| Dynamic _get/_set definitions | 2 | 0 |
| All Time.get_ticks_* calls | 178 | 159 |

Extraction reduces owner size, not necessarily total source size. No claim of a
zero-debt codebase or measured gameplay performance gain follows from these counts.
All new core/models/builders/views modules remain within their 400-line law.

## Original Top Ten: Before And After

The same ten largest Phase-0 owners are compared, rather than changing the sample.
Untyped counts include lambdas; proxy counts are definitions, not string matches.
Wall-clock counts are raw executable calls, not an inferred gameplay classification.

| Owner | Lines | Untyped | _get/_set | Time.get_ticks_* |
| --- | ---: | ---: | ---: | ---: |
| `zone_construction_host.gd` | 4283 -> 339 | 26 -> 0 | 2 -> 0 | 0 -> 0 |
| `player_controller.gd` | 2760 -> 588 | 2 -> 0 | 0 -> 0 | 1 -> 0 |
| `greyfen_life_controller.gd` | 2430 -> 378 | 9 -> 2 | 0 -> 0 | 20 -> 0 |
| `enemy_ai.gd` | 2216 -> 580 | 3 -> 0 | 0 -> 0 | 2 -> 0 |
| `audio_manager.gd` | 1907 -> 1907 | 7 -> 7 | 0 -> 0 | 2 -> 2 |
| `asset_spawn_helper.gd` | 1548 -> 1548 | 5 -> 5 | 0 -> 0 | 7 -> 7 |
| `input_router.gd` | 1526 -> 415 | 1 -> 0 | 0 -> 0 | 12 -> 3 |
| `character_animation_driver.gd` | 1504 -> 1504 | 1 -> 1 | 0 -> 0 | 0 -> 0 |
| `save_manager.gd` | 1395 -> 945 | 21 -> 20 | 0 -> 0 | 3 -> 3 |
| `saga_activities.gd` | 1287 -> 373 | 1 -> 1 | 0 -> 0 | 0 -> 0 |

## Largest Current Owners

| Owner | Lines | Untyped | Time.get_ticks_* |
| --- | ---: | ---: | ---: |
| `audio_manager.gd` | 1907 | 7 | 2 |
| `asset_spawn_helper.gd` | 1548 | 5 | 7 |
| `character_animation_driver.gd` | 1504 | 1 | 0 |
| `camera_controller.gd` | 1168 | 1 | 2 |
| `story_activity_director.gd` | 1044 | 16 | 0 |
| `systems/zone_lifecycle_service.gd` | 1028 | 4 | 13 |
| `seamless_world_service.gd` | 1022 | 0 | 23 |
| `runtime_pack_manager.gd` | 978 | 2 | 5 |
| `systems/world_presentation_service.gd` | 956 | 7 | 3 |
| `systems/opening_startup_service.gd` | 949 | 1 | 30 |

The remaining large audio, asset, animation, camera and lifecycle owners are not
silently declared decomposed by Phase 5.

## Determinism Boundary

All 14 model files contain **zero** executable Time.get_ticks_* calls and zero
global random calls. Player/enemy/Greyfen-life controllers and saga activities
also contain zero wall-clock calls. SimClock and SeededRng own extracted simulation.
ReplayRunner retains three wall-clock calls solely to measure replay elapsed time.

The complete runtime still has **159** raw wall-clock calls. This includes resource
scheduling, input handoff and presentation. It also includes two everyday-life
social cooldown calls outside the extracted LivingCastModel. Those are not a claim
of fully deterministic live-world simulation. Browser/GPU/phone acceptance and
reference-PC FPS, startup, transition and memory requirements remain separate.

## Actual Module Tree

Paths below are relative to scripts/. Numbers are current physical line counts.

```text
core/
  canonical_state.gd (46)
  deterministic_model.gd (12)
  game_session_bindings.gd (394)
  input_defaults.gd (178)
  input_frame.gd (39)
  replay_runner.gd (31)
  seeded_rng.gd (42)
  sim_clock.gd (17)
  sim_event_bus.gd (30)
  zone_construction_api.gd (35)
  zone_instance_scope.gd (111)
models/
  ammo_loadout_model.gd (104)
  bow_aim_release_model.gd (104)
  combat_hit_model.gd (9)
  enemy_tactics_model.gd (140)
  input_binding_model.gd (117)
  living_cast_model.gd (150)
  player_combat_locomotion_model.gd (257)
  save_payload_codec.gd (250)
  save_payload_fields.gd (192)
  save_selection_model.gd (70)
  vendor_economy_model.gd (263)
  vendor_pricing.gd (42)
  world_transition_model.gd (124)
  zone_construction_rules.gd (130)
builders/
  architecture_batch_builder.gd (400)
  foliage_and_prop_builder.gd (398)
  interaction_station_builder.gd (398)
  settlement_detail_builder.gd (400)
  terrain_and_water_builder.gd (400)
  zone_actor_spawner.gd (400)
views/
  combat_boss_view.gd (314)
  combat_capsule_view.gd (35)
  combat_encounter_view.gd (250)
  combat_impact_view.gd (209)
  enemy_body_view.gd (363)
  enemy_equipment_view.gd (263)
  enemy_identity_view.gd (272)
  enemy_navigation_view.gd (208)
  enemy_presence_view.gd (155)
  enemy_scene_state.gd (144)
  enemy_strike_view.gd (248)
  enemy_visual_view.gd (293)
  input_binding_adapter_view.gd (302)
  input_gamepad_view.gd (219)
  input_hardware_view.gd (277)
  input_touch_view.gd (120)
  journal_evidence_view.gd (240)
  journal_reader_view.gd (185)
  journey_load_view.gd (194)
  living_cast_attention_view.gd (180)
  living_cast_awareness_view.gd (128)
  living_cast_dialogue_barks_view.gd (284)
  living_cast_locomotion_view.gd (289)
  living_cast_population_view.gd (190)
  living_cast_routine_view.gd (255)
  living_cast_scene_view.gd (286)
  living_cast_station_view.gd (285)
  living_cast_work_contact_view.gd (143)
  menu_layout_view.gd (302)
  player_action_view.gd (321)
  player_animation_view.gd (245)
  player_blade_contact_view.gd (85)
  player_blade_geometry_view.gd (319)
  player_bow_view.gd (213)
  player_camera_occlusion_view.gd (37)
  player_character_view.gd (284)
  player_equipment_pose_view.gd (274)
  player_equipment_view.gd (290)
  player_locomotion_view.gd (249)
  player_oathfire_view.gd (220)
  player_scene_state.gd (234)
  saga_dialogue_view.gd (301)
  saga_site_view.gd (351)
  saga_work_view.gd (297)
  vendor_shop_view.gd (51)
  web_pointer_bridge.gd (97)
```

## Runtime Ownership

- `game.gd` and the service registry coordinate; GameState owns shared state.
  `game_bindings.gd` is 683 lines; explicit session aliases live in
  `core/game_session_bindings.gd` (394), not another dynamic proxy.
- Construction uses typed builders, ZoneBuildContext and ZoneInstanceScope.
  WorldTransitionModel owns generation/publication decisions; existing lifecycle
  services retain complete readiness, safe arrivals, gates and resource retirement.
- Player/enemy controllers retain physics and engine callbacks. Pure models decide
  actions; views own bodies, equipment, contact, navigation and animation projection.
- LivingCastModel owns deterministic time, reservations and awareness data. Views
  retain station props, work contact, conversation and routine projection. The
  existing npc_routine_director remains the intent resolver.
- InputBindingModel owns binding/context rules. InputRouter emits InputFrame;
  browser/touch/gamepad adapters retain hardware and handoff behavior.
- HUD components share one HudState. VendorShopView and JourneyLoadView emit
  existing intents; inventory/vendor/save owners remain authoritative.
- QuestManager retains objective truth and once-only completion. SavePayloadCodec
  normalizes payloads; existing save adapters retain I/O and browser durability.

## One Check Entry Point

```text
python3 outputs/AshenOathTheRoadBetweenCrowns/tools/run_checks.py --require-godot
```

Use Godot 4.6.x from PATH or GODOT_BIN. CI pins official 4.6.3 with a verified
archive checksum and cached installation. The runner performs architecture rule
self-tests/ratchet, strict JSON parsing and item/quest schemas/references, static
script-resource closure, archive hash/reference integrity, required UI resource
imports, generated class-name indexing and all five headless suites. The index
comes from actual declarations, without importing the world or replacing engine
type checking. It rejects engine warnings/errors, missing
success markers, nonzero exit codes and timeouts; missing Godot fails in CI.

The Phase-5 vertical slice uses real cast, vendor, ammunition, transition, combat,
quest and save-codec owners. Each 600-tick combat/cast run must be <250 ms; duplicate
replay plus fresh-session checkpoint and input-sensitivity check must be <1000 ms.
RunSnapshot here means the canonical **durable checkpoint**, not restored transient
attack/blink timers. The replay is a scripted slice, not all 57 quests or a rendered
playthrough. Headless timing cannot establish the Intel HD 620 gameplay FPS gates.

CI runs this command on every push/PR with read-only permissions. No export, Web
bundle synchronization, push or deployment job is added. Repository branch
protection settings are not changed by this workflow; require this status check
in protection rules to make merge enforcement mandatory on GitHub.

## Archive And Status

222 unreferenced historical verifier files retain exact bytes in docs/archive/.
183 referenced candidates remain at their original paths. The archive is excluded
from Godot scanning; phase5-index.json provides original/new paths and SHA-256.
No loose project-root REPORT/MATRIX/CHECKLIST artifacts exist at this baseline.
Current plans, linked historical results and all runtime assets remain intact.

BOW-001, AMMO-001 and SHOP-001 now record separate verified simulation/headless
integration evidence. Their overall status remains functional_but_incomplete and
graphical acceptance remains unverified. Local passing suites do not imply a
remote CI run, browser acceptance, publication or whole-game completion.

An initial clean-cache Phase-5 run exposed missing generated global-class
metadata in the runner, blocking the zone and HUD suites. The source-derived
index preflight repairs that setup dependency; no model assertion was removed.
