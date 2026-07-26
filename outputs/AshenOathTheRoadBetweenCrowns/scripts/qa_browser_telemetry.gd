extends Node

const WINDOW_STATE := "window.__ASHEN_OATH_QA__"
const WINDOW_COMMAND := "window.__ASHEN_OATH_QA_COMMAND__"
const UPDATE_INTERVAL := 0.10

var enabled := false
var _elapsed := 0.0
var _game: Node
var _frame_times: Array[float] = []
var _command_result: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	enabled = bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('qa') === '1'",
		true
	))
	if enabled:
		JavaScriptBridge.eval("%s = {enabled:true, ready:false}; %s = null;" % [WINDOW_STATE, WINDOW_COMMAND], false)

func _process(delta: float) -> void:
	if not enabled:
		return
	_frame_times.append(delta)
	if _frame_times.size() > 600:
		_frame_times.pop_front()
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = 0.0
	if not is_instance_valid(_game):
		_game = _find_game()
	_poll_command()
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
		"performance": _performance_state(),
		"mouse_mode": Input.mouse_mode,
		"audio": _audio_state(),
		"save_exists": FileAccess.file_exists("user://ashen_oath_save.json"),
		"command_result": _command_result,
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

func _poll_command() -> void:
	var command_json = JavaScriptBridge.eval("JSON.stringify(%s || null)" % WINDOW_COMMAND, true)
	var command = JSON.parse_string(str(command_json))
	if command == null or not (command is Dictionary):
		return
	JavaScriptBridge.eval("%s = null;" % WINDOW_COMMAND, false)
	var action := str(command.get("action", ""))
	_command_result = {"action": action, "ok": false}
	if not is_instance_valid(_game):
		_command_result.error = "game unavailable"
		return
	match action:
		"prepare_route":
			var target := str(command.get("target", ""))
			var story = _game.get("story_state")
			if story == null:
				_command_result.error = "story state unavailable"
				return
			match target:
				"record_hall":
					story.set_flag("vargan_ledger_choice_made", true)
					story.set_flag("castle_haunting_cleared", true)
				"undercroft":
					story.set_flag("halvern_fate", "witness")
				"assembly":
					story.set_flag("confession_method", "witnesses")
				_:
					_command_result.error = "unsupported route target"
					return
			_command_result = {"action": action, "target": target, "ok": true}
		"save":
			var manager = _game.get("save_manager")
			_command_result.ok = manager != null and bool(manager.save_game(_game))
		"load":
			var manager = _game.get("save_manager")
			_command_result.ok = manager != null and bool(manager.load_game(_game))
		"reset_performance":
			_frame_times.clear()
			_command_result.ok = true
		"route_to":
			var target := Vector3(
				float(command.get("x", 0.0)),
				float(command.get("y", 0.0)),
				float(command.get("z", 0.0))
			)
			var player: Node3D = _game.get("player") as Node3D
			var spatial = _game.get("spatial_service")
			if player == null or spatial == null:
				_command_result.error = "route service unavailable"
				return
			var fallback: Array[Vector3] = spatial.build_route(player.global_position, target, 0.55)
			var points := PackedVector3Array(fallback)
			var encoded: Array = []
			for point in points:
				encoded.append(_vector(point))
			_command_result = {"action": action, "ok": not encoded.is_empty(), "points": encoded}
		"stage_gate":
			var target_id := str(command.get("target", ""))
			var player: CharacterBody3D = _game.get("player") as CharacterBody3D
			var zone_root: Node = _game.get("zone_root") as Node
			var spatial = _game.get("spatial_service")
			if player == null or zone_root == null or spatial == null:
				_command_result.error = "gate staging unavailable"
				return
			var gate: Node3D
			for node in zone_root.find_children("*", "Area3D", true, false):
				if str(node.get("interaction_type")) == "zone" and str(node.get("zone_target")) == target_id:
					gate = node as Node3D
					break
			if gate == null:
				_command_result.error = "gate not found"
				return
			var inward := (Vector3.ZERO - gate.global_position)
			inward.y = 0.0
			var candidate := gate.global_position + inward.normalized() * 2.2 + Vector3.UP
			player.global_position = spatial.nearest_safe(candidate, spatial.bank_for(candidate))
			player.velocity = Vector3.ZERO
			_command_result = {"action": action, "target": target_id, "ok": true, "position": _vector(player.global_position)}
		_:
			_command_result.error = "unsupported command"

func _performance_state() -> Dictionary:
	if _frame_times.is_empty():
		return {"average_fps": 0.0, "one_percent_low_fps": 0.0, "samples": 0}
	var total := 0.0
	for frame_time in _frame_times:
		total += frame_time
	var ordered := _frame_times.duplicate()
	ordered.sort()
	var low_index := clampi(int(floor(float(ordered.size() - 1) * 0.99)), 0, ordered.size() - 1)
	return {
		"average_fps": float(_frame_times.size()) / maxf(total, 0.001),
		"one_percent_low_fps": 1.0 / maxf(float(ordered[low_index]), 0.001),
		"samples": _frame_times.size(),
	}

func _audio_state() -> Dictionary:
	var master := AudioServer.get_bus_index("Master")
	return {
		"master_db": AudioServer.get_bus_volume_db(master) if master >= 0 else -80.0,
		"muted": AudioServer.is_bus_mute(master) if master >= 0 else true,
	}

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
