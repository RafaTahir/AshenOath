extends Node

const WINDOW_STATE := "window.__ASHEN_OATH_QA__"
const WINDOW_COMMAND := "window.__ASHEN_OATH_QA_COMMAND__"
const UPDATE_INTERVAL := 0.20

var enabled := false
var _elapsed := 0.0
var _game: Node
var _frame_times: Array[float] = []
var _command_result: Dictionary = {}
var _last_prewarm_ready := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# QA telemetry is intentionally available only in the disposable QA Web
	# preset. Production builds must not expose state mutation or teleport hooks.
	if not OS.has_feature("web") or not OS.has_feature("ashenoath_qa"):
		set_process(false)
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
	if _game != null and not bool(_game.get("game_started")):
		var hud: Node = _game.get("hud") as Node
		var prewarm_ready := bool(hud.get("new_game_ready")) if hud != null else false
		if prewarm_ready == _last_prewarm_ready:
			return
		_last_prewarm_ready = prewarm_ready
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
	var hud: Node = game.get("hud") as Node
	var state := {
		"enabled": true,
		"ready": bool(game.get("game_started")) and player != null,
		"new_game_ready": bool(hud.get("new_game_ready")) if hud != null else false,
		"zone": str(game.get("current_zone_id")),
		"transition_pending": bool(game.get("zone_transition_pending")),
		"zone_load_request_pending": bool(game.get("zone_load_request_pending")),
		"opening_pack_waiting": bool(game.get("opening_pack_waiting")),
		"campaign_pack_waiting": bool(game.get("campaign_pack_waiting")),
		"paused": get_tree().paused,
		"player": {},
		"camera": {},
		"focus": {},
		"focus_candidates": [],
		"gates": [],
		"interactions": [],
		"dialogue": {"visible": false, "page": -1, "pages": 0},
		"enemies": [],
		"quests": {},
		"performance": _performance_state(),
		"mouse_mode": Input.mouse_mode,
		"audio": _audio_state(),
		"save_exists": FileAccess.file_exists("user://ashen_oath_save.json"),
		"command_result": _command_result,
	}
	var runtime_packs = game.get("runtime_packs")
	if runtime_packs != null:
		state["runtime_packs"] = {}
		for pack_id in ["opening", "campaign", "characters", "monsters", "audio"]:
			state.runtime_packs[pack_id] = {
				"state": str(runtime_packs.get_state(pack_id)) if runtime_packs.has_method("get_state") else "",
				"progress": float(runtime_packs.get_progress(pack_id)) if runtime_packs.has_method("get_progress") else 0.0,
				"error": str(runtime_packs.get_last_error(pack_id)) if runtime_packs.has_method("get_last_error") else "",
			}
	if player != null:
		var player_health = player.get("health_component")
		var player_body := player as CharacterBody3D
		state.player = {
			"position": _vector(player.global_position),
			"velocity": _vector(player_body.velocity) if player_body != null else _vector(Vector3.ZERO),
			"facing_yaw": player.global_rotation.y,
			"can_control": bool(player.get("can_control")),
			"health": float(player_health.get("health")) if player_health != null else 0.0,
			"dead": player_health != null and float(player_health.get("health")) <= 0.0,
			"on_floor": player.is_on_floor() if player is CharacterBody3D else true,
			"slide_collisions": _slide_collisions(player_body),
		}
	# Greyfen is prewarmed behind the menu. Do not walk the full zone tree while
	# the browser is waiting for the real New Game input.
	if not bool(game.get("game_started")):
		return state
	if camera_rig != null:
		state.camera = {
			"yaw": float(camera_rig.get("yaw")),
			"pitch": float(camera_rig.get("pitch")),
		}
	var focus_candidates: Array = []
	var candidates_variant = game.get("interaction_candidates")
	if candidates_variant is Array:
		for candidate in candidates_variant:
			if candidate == null or not is_instance_valid(candidate) or not candidate.is_inside_tree():
				continue
			var distance := player.global_position.distance_to(candidate.global_position) if player != null else -1.0
			focus_candidates.append({
				"id": str(candidate.get("interaction_id")),
				"type": str(candidate.get("interaction_type")),
				"distance": distance,
				"valid": bool(game.call("_interaction_target_valid", candidate)),
			})
	state.focus_candidates = focus_candidates
	if hud != null:
		var dialogue_layer: Control = hud.get("dialogue_layer") as Control
		var dialogue_pages: Array = hud.get("dialogue_pages") as Array
		state.dialogue = {
			"visible": dialogue_layer != null and dialogue_layer.visible,
			"page": int(hud.get("dialogue_page_index")),
			"pages": dialogue_pages.size() if dialogue_pages != null else 0,
		}
	if focus != null and is_instance_valid(focus):
		state.focus = _interaction_state(focus, player)
	if zone_root != null and is_instance_valid(zone_root):
		var gates: Array = []
		var interactions: Array = []
		for node in zone_root.find_children("*", "Area3D", true, false):
			var interaction := _interaction_state(node, player)
			if str(node.get("interaction_type")) == "zone":
				gates.append(interaction)
			else:
				interactions.append(interaction)
		gates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("target", "")) < str(b.get("target", ""))
		)
		interactions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("id", "")) < str(b.get("id", ""))
		)
		state.gates = gates
		state.interactions = interactions
	var enemies: Array = []
	for enemy in game.get("active_enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var health = enemy.get("health_component")
		enemies.append({
			"id": str(enemy.get("enemy_id")),
			"position": _vector(enemy.global_position),
			"active": bool(enemy.get("encounter_active")),
			"health": float(health.get("health")) if health != null else 0.0,
		})
	state.enemies = enemies
	var quests = game.get("quests")
	if quests != null:
		state.quests = {
			"tracked": str(quests.get_tracked_quest()),
			"road_active": bool(quests.is_active("main_road_of_crows")),
			"road_complete": bool(quests.is_completed("main_road_of_crows")),
			"evidence_ready": bool(quests.is_objective_done("main_road_of_crows", "evidence_ready")),
			"fight_complete": bool(quests.is_objective_done("main_road_of_crows", "fight_ghoulkin")),
			"bell_active": bool(quests.is_active("main_bell_beneath_greyfen")),
			"grave_truth": bool(quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth")),
		}
	return state

func _poll_command() -> void:
	var command_json = JavaScriptBridge.eval("JSON.stringify(%s || null)" % WINDOW_COMMAND, true)
	var command = JSON.parse_string(str(command_json))
	if command == null or not (command is Dictionary):
		return
	JavaScriptBridge.eval("%s = null;" % WINDOW_COMMAND, false)
	var action := str(command.get("action", ""))
	var request_id := int(command.get("request_id", 0))
	_command_result = {"action": action, "request_id": request_id, "ok": false}
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
			_command_result = {"action": action, "request_id": request_id, "target": target, "ok": true}
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
			_command_result = {"action": action, "request_id": request_id, "ok": not encoded.is_empty(), "points": encoded}
		"orient_camera":
			var camera_controller = _game.get("camera_rig")
			if camera_controller == null:
				_command_result.error = "camera controller unavailable"
				return
			camera_controller.set("yaw", float(command.get("yaw", 0.0)))
			_command_result = {"action": action, "request_id": request_id, "ok": true, "yaw": float(camera_controller.get("yaw"))}
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
			# Stage on the playable side of the visible gate. The spatial service's
			# registered arrival is the destination spawn for the next zone, not an
			# approach point for the current gate; using it here put QA several
			# metres away from the interaction focus and made a valid gate look
			# unreachable in the browser route.
			var gate_position := gate.global_position
			var inward := Vector3.ZERO
			if absf(gate_position.x) > absf(gate_position.z):
				inward.x = -1.0 if gate_position.x > 0.0 else 1.0
			else:
				inward.z = -1.0 if gate_position.z > 0.0 else 1.0
			var candidate := gate_position + inward * 1.45 + Vector3.UP
			candidate.y = maxf(candidate.y, 0.95)
			var validated: Vector3 = spatial.validate_position(candidate, 0.55, spatial.bank_for(candidate))
			player.global_position = candidate if validated.distance_to(candidate) > 2.5 else validated
			player.velocity = Vector3.ZERO
			_command_result = {"action": action, "request_id": request_id, "target": target_id, "ok": true, "position": _vector(player.global_position)}
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

func _slide_collisions(body: CharacterBody3D) -> Array:
	var result: Array = []
	if body == null:
		return result
	for index in range(body.get_slide_collision_count()):
		var collision := body.get_slide_collision(index)
		var collider := collision.get_collider()
		result.append({
			"normal": _vector(collision.get_normal()),
			"collider": collider.name if collider is Node else str(collider),
		})
	return result

func _has_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
