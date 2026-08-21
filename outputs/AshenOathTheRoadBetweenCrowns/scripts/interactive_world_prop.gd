extends Node3D
class_name InteractiveWorldProp

## Small state contract for world objects that already own an interaction area.
## Gameplay remains authoritative in game.gd; this component only persists and
## presents the object's local state.

signal state_changed(prop_id: String, state: String)

var prop_id := ""
var kind := "generic"
var state_key := ""
var current_state := "idle"
var story_state: Node
var _visual_nodes: Array[Node3D] = []
var _elapsed := 0.0

func _ready() -> void:
	add_to_group("interactive_world_prop")
	# WorldPropController owns ambient motion centrally. Keeping one process loop
	# on every interactive component created a redundant per-prop scene scan.
	set_process(false)
	_cache_visual_nodes.call_deferred()

func configure(id: String, prop_kind: String, persistent_key: String = "", initial_state: String = "idle", state_owner: Node = null) -> void:
	prop_id = id
	kind = prop_kind
	state_key = persistent_key
	story_state = state_owner
	current_state = initial_state
	set_meta("world_prop_id", prop_id)
	set_meta("world_prop_kind", kind)
	set_meta("world_prop_state_key", state_key)
	set_meta("world_prop_state", current_state)
	if story_state != null and state_key != "" and story_state.has_method("get_flag"):
		var saved: Variant = story_state.get_flag(state_key, null)
		if saved != null and str(saved) != "":
			current_state = str(saved)
	_apply_state()

func bind_story_state(state_owner: Node) -> void:
	story_state = state_owner
	if state_key != "" and story_state != null and story_state.has_method("get_flag"):
		var saved: Variant = story_state.get_flag(state_key, null)
		if saved != null and str(saved) != "":
			current_state = str(saved)
	_apply_state()

func activate() -> void:
	var next := "used"
	if kind in ["lantern", "candle", "shrine"]:
		next = "extinguished" if current_state == "lit" else "lit"
	elif kind == "forge":
		next = "working" if current_state != "working" else "cooling"
	elif kind == "door" or kind == "gate":
		next = "closed" if current_state == "open" else "open"
	set_state(next)

func set_state(next_state: String, persist := true) -> void:
	current_state = next_state
	set_meta("world_prop_state", current_state)
	if persist and story_state != null and state_key != "" and story_state.has_method("set_flag"):
		story_state.set_flag(state_key, current_state)
	_apply_state()
	state_changed.emit(prop_id, current_state)

func get_state() -> String:
	return current_state

func get_prop_id() -> String:
	return prop_id

func get_kind() -> String:
	return kind

func _cache_visual_nodes() -> void:
	_visual_nodes.clear()
	var owner := get_parent()
	if owner == null:
		return
	for child in owner.get_children():
		if child == self or not (child is Node3D):
			continue
		_visual_nodes.append(child as Node3D)
	_apply_state()

func _apply_state() -> void:
	var inactive := current_state == "extinguished" or current_state == "closed"
	for node in _visual_nodes:
		if not is_instance_valid(node):
			continue
		var lower := str(node.name).to_lower()
		if lower.contains("flame") or lower.contains("glow") or lower.contains("coal"):
			node.visible = not inactive
		if (kind == "door" or kind == "gate") and lower.contains("door"):
			node.rotation.y = deg_to_rad(88.0 if current_state == "open" else 0.0)
