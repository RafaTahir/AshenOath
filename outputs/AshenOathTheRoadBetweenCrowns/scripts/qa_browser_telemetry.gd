extends Node

const WINDOW_STATE := "window.__ASHEN_OATH_QA__"
const UPDATE_INTERVAL := 0.10

var enabled := false
var _elapsed := 0.0
var _game: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	enabled = bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('qa') === '1'",
		true
	))
	if enabled:
		JavaScriptBridge.eval("%s = {enabled:true, ready:false};" % WINDOW_STATE, false)

func _process(delta: float) -> void:
	if not enabled:
		return
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = 0.0
	if not is_instance_valid(_game):
		_game = _find_game()
	var state := snapshot_for_game(_game)
	var payload := JSON.stringify(state)
	JavaScriptBridge.eval("%s = JSON.parse(%s);" % [WINDOW_STATE, JSON.stringify(payload)], false)

func snapshot_for_game(game: Node) -> Dictionary:
	if game == null or not is_instance_valid(game):
		return {"enabled": true, "ready": false}
	var player: Node3D = game.get("player") as Node3D
	var camera_rig: Node = game.get("camera_rig") as Node
	var focus: Node = game.get("active_interactable") as Node
	var zone_root: Node = game.get("zone_root") as Node
	var state := {
		"enabled": true,
		"ready": bool(game.get("game_started")) and player != null,
		"zone": str(game.get("current_zone_id")),
		"transition_pending": bool(game.get("zone_transition_pending")),
		"paused": get_tree().paused,
		"player": {},
		"camera": {},
		"focus": {},
		"gates": [],
	}
	if player != null:
		state.player = {
			"position": _vector(player.global_position),
			"facing_yaw": player.global_rotation.y,
			"can_control": bool(player.get("can_control")),
			"on_floor": player.is_on_floor() if player is CharacterBody3D else true,
		}
	if camera_rig != null:
		state.camera = {
			"yaw": float(camera_rig.get("yaw")),
			"pitch": float(camera_rig.get("pitch")),
		}
	if focus != null and is_instance_valid(focus):
		state.focus = _interaction_state(focus, player)
	if zone_root != null and is_instance_valid(zone_root):
		var gates: Array = []
		for node in zone_root.find_children("*", "Area3D", true, false):
			if str(node.get("interaction_type")) != "zone":
				continue
			gates.append(_interaction_state(node, player))
		gates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("target", "")) < str(b.get("target", ""))
		)
		state.gates = gates
	return state

func _find_game() -> Node:
	var scene := get_tree().current_scene
	if scene != null and _has_property(scene, "current_zone_id"):
		return scene
	for child in get_tree().root.get_children():
		if _has_property(child, "current_zone_id"):
			return child
	return null

func _interaction_state(node: Node, player: Node3D) -> Dictionary:
	var position := Vector3.ZERO
	if node is Node3D:
		position = (node as Node3D).global_position
	return {
		"id": str(node.get("interaction_id")),
		"type": str(node.get("interaction_type")),
		"target": str(node.get("zone_target")),
		"prompt": str(node.get("prompt")),
		"position": _vector(position),
		"distance": player.global_position.distance_to(position) if player != null else -1.0,
	}

func _vector(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}

func _has_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
