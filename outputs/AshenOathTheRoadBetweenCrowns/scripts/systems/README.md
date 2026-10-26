# Game subsystem ownership

`../game.gd` constructs and injects the systems, forwards engine lifecycle/input
callbacks, and connects their notifications. It contains no quest, combat,
inventory, save, or presentation rules.

| System ID | Implementation | Responsibility | Representative incoming function | Outgoing notification |
| --- | --- | --- | --- | --- |
| `zone_lifecycle` | `zone_lifecycle_service.gd` | Travel requests, pack waits, activation, residency, retirement and shutdown | `_load_zone`, `prepare_resource_shutdown` | `zone_changed` |
| `combat` | `combat_coordinator.gd` | Player attacks, enemy events, encounter/boss orchestration and combat feedback | `_on_player_blade_contact`, `_on_enemy_died` | `combat_impact` |
| `dialogue` | `dialogue_service.gd` | Dialogue action dispatch, story-action completion, speaker staging and topics | `_handle_dialogue_action` | `dialogue_action_completed` |
| `quest` | `quest_service.gd` | Evidence, campaign arrival, quest rewards, progression and endings | `_on_quest_completed` | `quest_completed` |
| `inventory` | `inventory_service.gd` | Quick items, preparation, crafting, practices and vendor operations | `_use_inventory_item` | `inventory_operation_completed` |
| `save` | `save_service.gd` | Journey restoration, player restoration and world-state serialization | `save_world_state`, `load_world_state` | `world_state_loaded` |
| `hud` | `hud_coordinator.gd` | Pause/settings requests, tracker, compass, guidance and equipment readout | `_refresh_tracker` | `tracker_refreshed` |
| `session` | `session_service.gd` | Runtime dependency initialization, input and frame orchestration | `start_session`, `tick_session` | `session_started` |
| `startup` | `opening_startup_service.gd` | Opening resource preparation, staged hydration and deferred presentation | `_prepare_opening_services` | `opening_phase_changed` |
| `world` | `world_presentation_service.gd` | Authored scene-construction adapters, materials and render-resource validation | `_validate_zone_render_resources` | `render_resources_validated` |
| `interaction` | `interaction_service.gd` | Interaction selection, prompts, action routing and minigame callbacks | `_handle_interaction` | `interaction_focus_updated` |

Every system receives `configure(host, shared_state, services)` explicitly. Its
`configured` signal reports dependency injection; the table lists its separate
domain notification. The composition root forwards those domain notifications
without adding gameplay actions or waits. Existing operations retain their
original order and coroutine behavior.

`method_ownership.json` maps all 455 original methods to their physical owner and
records the original source line for review. Original engine callbacks were
renamed inside their owning service so adding a service node does not execute a
second `_ready`, `_process`, input, notification or exit callback.

## Compatibility and data ownership

`game_bindings.gd` contains only explicit typed property aliases and one-line
function forwards. It preserves the API used by authored zone builders,
existing runtime services and verifiers. It does not contain relocated gameplay
logic or generic method-name dispatch. Calls to asynchronous operations still
await the owning service; callback identities still point to the original game
facade, including signal connections and deferred calls.

`game_state.gd` owns the 188 pre-existing session fields, with their original
initial values and zone-owned property accessors. `game_definitions.gd` owns the
46 immutable declarations. Existing lower-level services remain the authorities
for their own data: quests, inventory, save files, health, stamina and zone
residency are not duplicated. In particular, world-state keys, save version,
timers, coordinates, damage values, resource paths and authored dialogue remain
unchanged.

Scene ownership is explicit. Services use the injected host for tree operations,
node insertion, viewport/world access and tween ownership. Deferred visual
markers resolve their host from the supplied zone subtree by downward traversal;
systems do not climb parent chains. Render-resource validation owns its two pure
material helpers so retirement can validate a cached subtree after the active
zone has been cleared.

An indentation-sensitive extraction audit compared all moved method bodies,
state declarations and constants against the source version. The permitted
differences are host/Callable bindings, observable completion signals, explicit
marker ownership, and moving the two unchanged material helper implementations
from the construction host. `tools/verify_boundaries.gd` provides structural and
actual route/save validation; it must pass independently of the extraction audit.
