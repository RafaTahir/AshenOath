extends Node

const WINDOW_STATE := "window.__ASHEN_OATH_QA__"
const WINDOW_COMMAND := "window.__ASHEN_OATH_QA_COMMAND__"
const WINDOW_OBSERVATION_BINDING := "__ASHEN_OATH_QA_OBSERVATION__"
const UPDATE_INTERVAL := 0.45
const DIAGNOSTIC_UPDATE_INTERVAL := 0.20
const PERFORMANCE_REFRESH_INTERVAL := 1.0

var enabled := false
var _elapsed := 0.0
var _game: Node
var _frame_times: Array[float] = []
var _command_result: Dictionary = {}
var _last_prewarm_ready := false
var _diagnostics_enabled := false
var _performance_elapsed := 0.0
var _performance_cache: Dictionary = {"average_fps": 0.0, "one_percent_low_fps": 0.0, "samples": 0}
var _catalog_root: Node3D
var _catalog_child_count := -1
var _catalog_interaction_count := -1
var _catalog_gates: Array = []
var _catalog_interactions: Array = []
var _catalog_bridge_surfaces: Array = []

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
	_diagnostics_enabled = bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('diag') === '1'",
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
	_performance_elapsed += delta
	var publish_interval := DIAGNOSTIC_UPDATE_INTERVAL if _diagnostics_enabled else UPDATE_INTERVAL
	if _elapsed < publish_interval:
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
	# Publish through JSON.parse rather than interpolating the object as
	# executable JavaScript. This keeps prompts and future Unicode text data
	# out of the JS parser and avoids a browser-only exception while preserving
	# the same read-only snapshot value.
	var payload := JSON.stringify(state)
	# The payload is already valid JSON/JavaScript. Assign it directly instead of
	# serializing the complete snapshot a second time and asking the browser to
	# parse the resulting string on the same Web main thread as rendering.
	# Escape the two legacy JavaScript line separators so text remains a valid
	# expression even when a future prompt or dialogue line contains them.
	var javascript_payload := payload.replace(String.chr(0x2028), "\\u2028").replace(String.chr(0x2029), "\\u2029")
	var binding_payload := JSON.stringify(payload)
	JavaScriptBridge.eval(
		"if (typeof %s === 'function') %s(%s); %s = %s;" % [
			WINDOW_OBSERVATION_BINDING,
			WINDOW_OBSERVATION_BINDING,
			binding_payload,
			WINDOW_STATE,
			javascript_payload,
		],
		false
	)

func snapshot_for_game(game: Node) -> Dictionary:
	if game == null or not is_instance_valid(game):
		return {"enabled": true, "ready": false}
	var player: Node3D = game.get("player") as Node3D
	var camera_rig: Node = game.get("camera_rig") as Node
	var focus: Node = game.get("active_interactable") as Node
	var zone_root: Node = game.get("zone_root") as Node
	var hud: Node = game.get("hud") as Node
	# Dialogue pauses gameplay while its UI keeps processing. Publish the
	# smallest useful state before touching runtime-pack, camera, enemy, or
	# interaction catalogs; those queries can starve the Web Runtime domain on a
	# Compatibility frame even though the paused dialogue is already visible.
	var paused := get_tree().paused
	if paused:
		var paused_dialogue_layer: Control = hud.get("dialogue_layer") as Control if hud != null else null
		var paused_dialogue_pages: Array = hud.get("dialogue_pages") as Array if hud != null else []
		var paused_position := _vector(player.global_position) if player != null else {}
		return {
			"enabled": true,
			"ready": bool(game.get("game_started")) and player != null,
			"new_game_ready": bool(hud.get("new_game_ready")) if hud != null else false,
			"zone": str(game.get("current_zone_id")),
			"transition_pending": bool(game.get("zone_transition_pending")),
			"zone_load_request_pending": bool(game.get("zone_load_request_pending")),
			"paused": true,
			"player": {"position": paused_position},
			"focus": {},
			"dialogue": {
				"visible": paused_dialogue_layer != null and paused_dialogue_layer.visible,
				"page": int(hud.get("dialogue_page_index")) if hud != null else -1,
				"pages": paused_dialogue_pages.size(),
			},
			"mouse_mode": Input.mouse_mode,
			"command_result": _command_result,
		}
	var state := {
		"enabled": true,
		"ready": bool(game.get("game_started")) and player != null,
		"new_game_ready": bool(hud.get("new_game_ready")) if hud != null else false,
		"zone": str(game.get("current_zone_id")),
		"transition_pending": bool(game.get("zone_transition_pending")),
		"zone_load_request_pending": bool(game.get("zone_load_request_pending")),
		"opening_pack_waiting": bool(game.get("opening_pack_waiting")),
		"campaign_pack_waiting": bool(game.get("campaign_pack_waiting")),
		"paused": paused,
		"player": {},
		"bridge_surfaces": [],
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
		for pack_id in ["opening", "quality_materials", "campaign", "characters", "monsters", "audio"]:
			state.runtime_packs[pack_id] = {
				"state": str(runtime_packs.get_state(pack_id)) if runtime_packs.has_method("get_state") else "",
				"progress": float(runtime_packs.get_progress(pack_id)) if runtime_packs.has_method("get_progress") else 0.0,
				"error": str(runtime_packs.get_last_error(pack_id)) if runtime_packs.has_method("get_last_error") else "",
			}
	if player != null:
		var player_health = player.get("health_component")
		var player_body := player as CharacterBody3D
		var floor_velocity := Vector3.ZERO
		if player_body != null and player_body.is_on_floor() and player_body.has_method("get_platform_velocity"):
			floor_velocity = player_body.get_platform_velocity()
		state.player = {
			"position": _vector(player.global_position),
			"velocity": _vector(player_body.velocity) if player_body != null else _vector(Vector3.ZERO),
			"facing_yaw": player.global_rotation.y,
			"can_control": bool(player.get("can_control")),
			"health": float(player_health.get("health")) if player_health != null else 0.0,
			"dead": player_health != null and float(player_health.get("health")) <= 0.0,
			"on_floor": player.is_on_floor() if player is CharacterBody3D else true,
			"on_wall": player.is_on_wall() if player is CharacterBody3D else false,
			"floor_normal": _vector(player.get_floor_normal()) if player is CharacterBody3D and player.is_on_floor() else _vector(Vector3.ZERO),
			"floor_velocity": _vector(floor_velocity),
			"slide_collisions": _slide_collisions(player_body),
		}
		if player_body != null:
			state.player["motion_mode"] = player_body.motion_mode
			state.player["safe_margin"] = player_body.safe_margin
			state.player["floor_snap_length"] = player_body.floor_snap_length
			if player_body.has_method("get_real_velocity"):
				state.player["real_velocity"] = _vector(player_body.get_real_velocity())
			if player_body.has_method("get_position_delta"):
				state.player["position_delta"] = _vector(player_body.get_position_delta())
			if _diagnostics_enabled:
				var forward_probe := KinematicCollision3D.new()
				var forward_blocked := player_body.test_move(player_body.global_transform, Vector3(0.0, 0.0, -0.5), forward_probe, 0.0, true)
				state.player["forward_probe"] = {
					"blocked": forward_blocked,
					"normal": _vector(forward_probe.get_normal()) if forward_blocked else _vector(Vector3.ZERO),
					"collider": forward_probe.get_collider().name if forward_blocked and forward_probe.get_collider() is Node else "",
				}
				state.player["overlap_colliders"] = _overlap_colliders(player_body)
	# Greyfen is prewarmed behind the menu. Do not walk the full zone tree while
	# the browser is waiting for the real New Game input.
	if not bool(game.get("game_started")):
		return state
	if camera_rig != null:
		state.camera = {
			"yaw": float(camera_rig.get("yaw")),
			"pitch": float(camera_rig.get("pitch")),
		}
	# Candidate validation performs distance and line-of-sight work for every
	# interaction. It is useful for focused native diagnostics, but normal browser
	# routing only needs the already-resolved focus and catalog below. Avoid doing
	# those raycasts on the same Web main thread that renders the world.
	if _diagnostics_enabled:
		var focus_candidates: Array = []
		var candidates_variant = game.get("interaction_candidates")
		if candidates_variant is Array:
			for candidate in candidates_variant:
				if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate.is_inside_tree():
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
		if not focus.is_queued_for_deletion() and focus.is_inside_tree():
			state.focus = _interaction_state(focus, player)
	# Dialogue intentionally pauses the gameplay tree. Keep this observation
	# path small while the UI owns input: rebuilding every gate, interaction, and
	# enemy entry here competes with the paused Web renderer and can make a valid
	# close state appear to the browser as a Runtime timeout. The next unpaused
	# snapshot repopulates the full route state after the handoff.
	if get_tree().paused:
		return state
	if zone_root != null and is_instance_valid(zone_root):
		var interaction_cache: Variant = game.get("interaction_area_cache")
		_refresh_zone_catalog(zone_root, interaction_cache if interaction_cache is Array else [])
		state.bridge_surfaces = _catalog_bridge_surfaces.duplicate(true)
		var gates: Array = []
		var interactions: Array = []
		for node in _catalog_gates:
			if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
				continue
			gates.append(_interaction_state(node, player))
		for node in _catalog_interactions:
			if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
				continue
			var interaction := _interaction_state(node, player)
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
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
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
		return _performance_cache.duplicate(true)
	if _performance_cache.get("samples", 0) > 0 and _performance_elapsed < PERFORMANCE_REFRESH_INTERVAL:
		return _performance_cache.duplicate(true)
	_performance_elapsed = 0.0
	var total := 0.0
	for frame_time in _frame_times:
		total += frame_time
	var ordered := _frame_times.duplicate()
	ordered.sort()
	var slow_count := maxi(1, ceili(float(ordered.size()) * 0.01))
	var slow_total := 0.0
	for index in range(ordered.size() - slow_count, ordered.size()):
		slow_total += ordered[index]
	_performance_cache = {
		"average_fps": float(_frame_times.size()) / maxf(total, 0.001),
		"one_percent_low_fps": 1.0 / maxf(slow_total / float(slow_count), 0.001),
		"samples": _frame_times.size(),
	}
	return _performance_cache.duplicate(true)

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
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():
		return {}
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
		var collider_shape_count := 0
		var collider_first_shape: Dictionary = {}
		if collider is Node:
			var shape_nodes := (collider as Node).find_children("*", "CollisionShape3D", true, false)
			collider_shape_count = shape_nodes.size()
			if not shape_nodes.is_empty():
				var first_shape := shape_nodes[0] as CollisionShape3D
				if first_shape != null and first_shape.shape != null:
					collider_first_shape = {
						"name": first_shape.name,
						"class": first_shape.shape.get_class(),
						"position": _vector(first_shape.global_position),
						"scale": _vector(first_shape.global_transform.basis.get_scale()),
					}
					if first_shape.shape is BoxShape3D:
						collider_first_shape["size"] = _vector((first_shape.shape as BoxShape3D).size)
		result.append({
			"normal": _vector(collision.get_normal()),
			"position": _vector(collision.get_position()),
			"travel": _vector(collision.get_travel()),
			"remainder": _vector(collision.get_remainder()),
			"depth": collision.get_depth(),
			"collider": collider.name if collider is Node else str(collider),
			"collider_path": str(collider.get_path()) if collider is Node else "",
			"collider_class": collider.get_class() if collider is Object else "",
			"collider_parent": str(collider.get_parent().get_path()) if collider is Node and collider.get_parent() != null else "",
			"collider_shape_count": collider_shape_count,
			"collider_first_shape": collider_first_shape,
		})
	return result

func _overlap_colliders(body: CharacterBody3D) -> Array:
	var result: Array = []
	if body == null or body.get_world_3d() == null:
		return result
	var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return result
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = body.global_transform * shape_node.transform
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	for hit in body.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var collider = hit.get("collider")
		if collider is Node:
			result.append(str(collider.name))
	return result

func _bridge_surface_state(root: Node3D) -> Array:
	var result: Array = []
	for node in root.find_children("RiverBridgeContinuousSurface", "StaticBody3D", true, false):
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():
			continue
		for raw_shape in node.find_children("*", "CollisionShape3D", true, false):
			var shape_node := raw_shape as CollisionShape3D
			if shape_node == null or shape_node.shape == null:
				continue
			var shape_size := Vector3.ZERO
			if shape_node.shape is BoxShape3D:
				shape_size = (shape_node.shape as BoxShape3D).size
			result.append({
				"node": node.name,
				"shape": shape_node.shape.get_class(),
				"size": _vector(shape_size),
				"position": _vector(shape_node.global_position),
				"scale": _vector(shape_node.global_transform.basis.get_scale()),
				"aabb": _aabb_state(shape_node.shape.get_debug_mesh() if shape_node.shape.has_method("get_debug_mesh") else null),
			})
	return result

func _aabb_state(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}
	var bounds := mesh.get_aabb()
	return {
		"position": _vector(bounds.position),
		"size": _vector(bounds.size),
	}

func _refresh_zone_catalog(zone_root: Node3D, interaction_cache: Array = []) -> void:
	var child_count := zone_root.get_child_count() if zone_root != null and is_instance_valid(zone_root) else -1
	var interaction_count := interaction_cache.size()
	var same_root := zone_root == _catalog_root and is_instance_valid(_catalog_root)
	if same_root and child_count == _catalog_child_count \
			and interaction_count == _catalog_interaction_count:
		return
	if zone_root == null or not is_instance_valid(zone_root):
		_catalog_root = zone_root
		_catalog_child_count = child_count
		_catalog_interaction_count = interaction_count
		_catalog_gates.clear()
		_catalog_interactions.clear()
		_catalog_bridge_surfaces.clear()
		return
	_catalog_root = zone_root
	_catalog_child_count = child_count
	_catalog_interaction_count = interaction_count
	_catalog_gates.clear()
	_catalog_interactions.clear()
	# Deferred scenery changes the root child count while the player's proximity
	# cache can legitimately be empty. That cache is suitable for focus work, not
	# for the complete read-only QA catalog, so rebuild from the authoritative
	# zone tree whenever either invalidation input changes.
	for node in zone_root.find_children("*", "Area3D", true, false):
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
			continue
		if str(node.get("interaction_type")) == "zone":
			_catalog_gates.append(node)
		else:
			_catalog_interactions.append(node)
	_catalog_bridge_surfaces = _bridge_surface_state(zone_root)

func _has_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
