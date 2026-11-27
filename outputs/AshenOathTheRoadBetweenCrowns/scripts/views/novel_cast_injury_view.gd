extends Node
## Projects the owning named interaction's saved injury onto its current visual.
## Signals keep cached and rebuilt actors correct without polling the story state.

const Interactable = preload("res://scripts/interactable.gd")
const TorPerformance = preload("res://scripts/views/novel_tor_performance.gd")
const RookPerformance = preload("res://scripts/views/novel_rook_performance.gd")
const Endings = preload("res://scripts/ending_catalog.gd")
const SPRING_ROUTE := &"novel_spring_route"
const FLAGS := {
	"blacksmith_tor": &"novel_tor_braced",
	"tor": &"novel_tor_braced",
	"board_tor": &"novel_tor_braced",
	"rook": &"novel_rook_ribs",
	"board_rook": &"novel_rook_ribs",
	"witness_-3": &"novel_rook_ribs",
}

var _state: Node
var _driver: Node
var _flag: StringName


static func bind_named_actor(driver: Node, presentation_id: String, state: Node) -> void:
	if not FLAGS.has(presentation_id) or not is_instance_valid(state):
		return
	var owner_node := driver.get_parent()
	while owner_node != null and not owner_node is Interactable:
		owner_node = owner_node.get_parent()
	# Some unnamed workers deliberately borrow a named character's animation setup.
	if owner_node == null or FLAGS.get(owner_node.interaction_id, &"") != FLAGS[presentation_id]:
		return
	var binding = driver.get_node_or_null("NovelCastInjury")
	if binding == null:
		binding = new()
		binding.name = "NovelCastInjury"
		driver.add_child(binding)
	binding.setup(driver, state, FLAGS[presentation_id])


func setup(driver: Node, state: Node, flag: StringName) -> void:
	if is_instance_valid(_state) and _state != state and _state.state_changed.is_connected(_story_changed):
		_state.state_changed.disconnect(_story_changed)
	_driver = driver
	_state = state
	_flag = flag
	if not _state.state_changed.is_connected(_story_changed):
		_state.state_changed.connect(_story_changed)
	_sync()


func _story_changed(changes: Dictionary) -> void:
	var flags: Dictionary = changes.get("flags", {})
	if changes.has("*") or flags.has(_flag) or flags.has(SPRING_ROUTE):
		_sync()


func _sync() -> void:
	var active: bool = _state.get_flag(_flag, false) == true
	var route: String = str(_state.get_flag(SPRING_ROUTE, ""))
	var spring := active and route in Endings.COVENANTS.values()
	var old_phase: StringName = _driver.novel_injury
	_driver.novel_injury = _flag if active else &""
	if spring:
		_driver.novel_injury = TorPerformance.STIFF if _flag == &"novel_tor_braced" else RookPerformance.HEALED
	if _flag == &"novel_tor_braced":
		TorPerformance.sync(_driver, active and not spring, spring)
	elif old_phase != _driver.novel_injury:
		RookPerformance.release_obsolete_pose(_driver)
