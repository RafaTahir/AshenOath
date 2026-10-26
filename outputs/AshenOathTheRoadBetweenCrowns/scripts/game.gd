extends "res://scripts/systems/game_bindings.gd"
## Composition root. The inherited bindings preserve the existing public API;
## system nodes own behavior and the shared state owns save-facing data.
signal system_configured(service_name: String)
signal session_started()
signal opening_phase_changed(phase: String)
signal zone_changed(zone_id: String)
signal combat_impact(position: Vector3, heavy: bool)
signal dialogue_action_completed(action: Dictionary)
signal quest_completed(quest_id: String)
signal inventory_operation_completed(result: Dictionary)
signal world_state_loaded()
signal tracker_refreshed()
signal render_resources_validated(report: Dictionary)
signal interaction_focus_updated(target: Node)

const SESSION = preload("res://scripts/systems/session_service.gd")
const STARTUP = preload("res://scripts/systems/opening_startup_service.gd")
const ZONE_LIFECYCLE = preload("res://scripts/systems/zone_lifecycle_service.gd")
const COMBAT = preload("res://scripts/systems/combat_coordinator.gd")
const DIALOGUE = preload("res://scripts/systems/dialogue_service.gd")
const QUEST = preload("res://scripts/systems/quest_service.gd")
const INVENTORY = preload("res://scripts/systems/inventory_service.gd")
const SAVE = preload("res://scripts/systems/save_service.gd")
const HUD = preload("res://scripts/systems/hud_coordinator.gd")
const WORLD = preload("res://scripts/systems/world_presentation_service.gd")
const INTERACTION = preload("res://scripts/systems/interaction_service.gd")

func _init() -> void:
	_host = self
	_state = State.new(self)
	_systems["session"] = SESSION.new()
	_systems["startup"] = STARTUP.new()
	_systems["zone_lifecycle"] = ZONE_LIFECYCLE.new()
	_systems["combat"] = COMBAT.new()
	_systems["dialogue"] = DIALOGUE.new()
	_systems["quest"] = QUEST.new()
	_systems["inventory"] = INVENTORY.new()
	_systems["save"] = SAVE.new()
	_systems["hud"] = HUD.new()
	_systems["world"] = WORLD.new()
	_systems["interaction"] = INTERACTION.new()
	for id in _systems:
		var system: Node = _systems[id]
		system.name = str(id).to_pascal_case() + "System"
		system.configured.connect(system_configured.emit)
		system.configure(self, _state, _systems)
		add_child(system)
	_systems["session"].session_started.connect(session_started.emit)
	_systems["startup"].opening_phase_changed.connect(opening_phase_changed.emit)
	_systems["zone_lifecycle"].zone_changed.connect(zone_changed.emit)
	_systems["combat"].combat_impact.connect(combat_impact.emit)
	_systems["dialogue"].dialogue_action_completed.connect(dialogue_action_completed.emit)
	_systems["quest"].quest_completed.connect(quest_completed.emit)
	_systems["inventory"].inventory_operation_completed.connect(inventory_operation_completed.emit)
	_systems["save"].world_state_loaded.connect(world_state_loaded.emit)
	_systems["hud"].tracker_refreshed.connect(tracker_refreshed.emit)
	_systems["world"].render_resources_validated.connect(render_resources_validated.emit)
	_systems["interaction"].interaction_focus_updated.connect(interaction_focus_updated.emit)

func get_system(id: String) -> Node:
	return _systems.get(id)

func _ready() -> void:
	if _systems.has("session"):
		_systems["session"].start_session()

func _process(delta: float) -> void:
	if _systems.has("session"):
		_systems["session"].tick_session(delta)

func _input(event: InputEvent) -> void:
	if _systems.has("session"):
		_systems["session"].route_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if _systems.has("session"):
		_systems["session"].route_unhandled_input(event)

func _exit_tree() -> void:
	if _systems.has("zone_lifecycle"):
		_systems["zone_lifecycle"].release_session()

func _notification(what: int) -> void:
	# Only the focus notification was handled before extraction. Destruction
	# notifications can arrive after child services have already been freed.
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	var coordinator = _systems.get("hud")
	if is_instance_valid(coordinator):
		coordinator.route_notification(what)
