class_name ProductionObservationBridge
extends Node

## Query-gated, read-only browser observation. It exposes no command channel
## and cannot mutate gameplay, story, saves, actors, or transitions.
const WINDOW_STATE := "window.__ashenOathReadOnlyObservation"
const WINDOW_ROUTE_QUERY := "window.__ashenOathReadOnlyRouteQuery"
const WINDOW_ROUTE_RESULT := "window.__ashenOathReadOnlyRouteResult"
const WINDOW_OBSERVATION_BINDING := "__ASHEN_OATH_READ_ONLY_OBSERVATION__"
const PUBLISH_INTERVAL := 0.20
const SectorManifest = preload("res://scripts/world_sector_manifest.gd")
const CATALOG_MIN_REFRESH_MS := 1000

var _host: Node
var _enabled := false
var _elapsed := 0.0
var _catalog_root: Node3D
var _catalog_child_count := -1
var _catalog_cache_count := -1
var _catalog_refreshed_ms := 0
var _catalog_gates: Array[Node3D] = []
var _catalog_interactions: Array[Node3D] = []
var _frame_times: Array[float] = []
var _performance_zone := ""
var _performance_elapsed := 0.0
var _performance_cache := {"zone": "", "average_fps": 0.0, "one_percent_low_fps": 0.0, "samples": 0}
var _last_route_query_id := 0

func setup(host: Node) -> void:
	_host = host
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		set_process(false)
		return
	_enabled = bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('observe') === '1'", true
	))
	set_process(_enabled)
	if _enabled:
		_publish()

func _process(delta: float) -> void:
	if not _enabled or _host == null or not is_instance_valid(_host):
		return
	_record_frame(delta, str(_host.get("current_zone_id")), bool(_host.get("game_started")) and _host.get("player") != null and not get_tree().paused)
	_elapsed += delta
	if _elapsed < PUBLISH_INTERVAL:
		return
	_elapsed = 0.0
	_publish()

func _publish() -> void:
	var state := snapshot_for_game(_host)
	var json := JSON.stringify(state)
	var payload := json.replace(String.chr(0x2028), "\\u2028").replace(String.chr(0x2029), "\\u2029")
	JavaScriptBridge.eval(
		"if (typeof %s === 'function') %s(%s); %s = %s;" % [
			WINDOW_OBSERVATION_BINDING,
			WINDOW_OBSERVATION_BINDING,
			JSON.stringify(json),
			WINDOW_STATE,
			payload,
		],
		false
	)
	_answer_route_query(_host)

func _answer_route_query(game: Node) -> void:
	var raw: Variant = JavaScriptBridge.eval("JSON.stringify(%s || null)" % WINDOW_ROUTE_QUERY, true)
	var query: Variant = JSON.parse_string(str(raw))
	if not (query is Dictionary):
		return
	var request_id := int(query.get("request_id", 0))
	if request_id <= _last_route_query_id:
		return
	_last_route_query_id = request_id
	var result := route_for_id(game, str(query.get("target_id", "")))
	result["request_id"] = request_id
	var payload := JSON.stringify(result).replace(String.chr(0x2028), "\\u2028").replace(String.chr(0x2029), "\\u2029")
	JavaScriptBridge.eval("%s = %s;" % [WINDOW_ROUTE_RESULT, payload], false)

func route_for_id(game: Node, target_id: String) -> Dictionary:
	_host = game
	var result := {"read_only": true, "ok": false, "target_id": target_id, "zone": str(game.get("current_zone_id")), "points": []}
	if target_id.is_empty() or target_id.length() > 80 or not bool(game.get("game_started")):
		return result
	var player := game.get("player") as CharacterBody3D
	var zone_root := game.get("zone_root") as Node3D
	var spatial := game.get("spatial_service") as Node
	if player == null or zone_root == null or spatial == null:
		return result
	_refresh_catalog(game, zone_root)
	var target: Node3D
	for node in _catalog_gates:
		if is_instance_valid(node) and str(node.get("interaction_id")) == target_id:
			target = node
			break
	if target == null:
		for node in _catalog_interactions:
			if is_instance_valid(node) and str(node.get("interaction_id")) == target_id:
				target = node
				break
	if target == null:
		return result
	if str(target.get("interaction_type")) == "zone":
		var connection := SectorManifest.connection_between(str(game.current_zone_id), str(target.get("zone_target")))
		if not connection.is_empty():
			if not SectorManifest.edge_available(connection, game.quests, game.story_state): return result
			var corridor := SectorManifest.connector_points(connection)
			var normal := SectorManifest.direction(str(connection.id))
			var raw_route: Array[Vector3] = []
			var next_segment := 0
			if SectorManifest.connector_contains(str(game.current_zone_id), player.global_position):
				raw_route.append(player.global_position)
				var nearest := INF
				for index in range(corridor.size() - 1):
					var closest := Geometry3D.get_closest_point_to_segment(player.global_position, corridor[index], corridor[index + 1])
					var distance := player.global_position.distance_squared_to(closest)
					if distance < nearest: nearest = distance; next_segment = index
			else:
				raw_route = _route_from_player(game, player, spatial, corridor[0])
				if raw_route.is_empty(): return result
			for index in range(next_segment + 1, corridor.size()):
				# Stop before the readiness leaf. The driver's final ordinary forward
				# input reaches the existing warm/cold handoff, never a mutation API.
				raw_route.append(corridor[index] - normal * 1.9 if index == corridor.size() - 1 else corridor[index])
			var approach := physical_route_for_points(player, spatial, raw_route)
			for point: Vector3 in approach: result.points.append(_vector(point))
			result["physical_connection"] = true
			result["crossing_point"] = _vector(corridor[-1])
			result["crossing_direction"] = _vector(normal)
			result["waypoint_tolerance"] = 0.25
			result.ok = not approach.is_empty()
			return result
	var points: Array[Vector3] = _route_from_player(game, player, spatial, target.global_position)
	if str(target.get("interaction_type")) != "zone":
		var conversation := str(target.get("interaction_type")) == "dialogue"
		var reach := 3.6 if conversation else 2.8
		# A solid prop centre can be replaced by a remote recovery anchor. That
		# is safe recovery, but not an interaction approach. Query clear nearby
		# standing points without moving actors or relaxing ordinary focus rules.
		if conversation or points.is_empty() or points.back().distance_to(target.global_position) > reach:
			points.clear()
			var toward_player := player.global_position - target.global_position
			toward_player.y = 0.0
			if toward_player.length_squared() < 0.01:
				toward_player = Vector3.FORWARD
			toward_player = toward_player.normalized()
			# Keep a shoulder-camera standing gap instead of walking into the
			# speaker/prop origin, where the camera can lose its eye line.
			var radii := [2.2] if conversation else [1.25, 2.2]
			for radius in radii:
				for degrees in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
					var candidate: Vector3 = target.global_position + toward_player.rotated(Vector3.UP, deg_to_rad(degrees)) * radius
					if not spatial.is_walkable_position(candidate, 0.55, spatial.bank_for(target.global_position)):
						continue
					var approach: Array[Vector3] = _route_from_player(game, player, spatial, candidate)
					var endpoint_distance: float = approach.back().distance_to(target.global_position) if not approach.is_empty() else INF
					if endpoint_distance <= reach and (not conversation or endpoint_distance >= 1.8):
						points = approach
						break
				if not points.is_empty():
					break
	for point in points:
		result.points.append(_vector(point))
	result["waypoint_tolerance"] = 0.25
	result.ok = not result.points.is_empty()
	return result

func _route_from_player(game: Node, player: CharacterBody3D, spatial: Node, destination: Vector3) -> Array[Vector3]:
	var source := player.global_position
	var prefix: Array[Vector3] = []
	var bounds: Vector2 = spatial.half_extents
	if absf(source.x) > bounds.x - 0.55 or absf(source.z) > bounds.y - 0.55:
		var nearest := INF
		var inbound := PackedVector3Array()
		var segment := -1
		for connection: Dictionary in SectorManifest.connections(str(game.current_zone_id)):
			var corridor := SectorManifest.connector_points(connection)
			for index in range(corridor.size() - 1):
				var closest := Geometry3D.get_closest_point_to_segment(source, corridor[index], corridor[index + 1])
				var distance := source.distance_squared_to(closest)
				if distance < nearest: nearest = distance; inbound = corridor; segment = index
		if segment < 0: return []
		prefix.append(source)
		for index in range(segment, -1, -1): prefix.append(inbound[index])
		source = prefix.back()
	var core: Array[Vector3] = spatial.build_route(source, destination, 0.55)
	if core.is_empty(): return []
	if prefix.is_empty(): return physical_route_for_points(player, spatial, core)
	for index in range(1, core.size()): prefix.append(core[index])
	return physical_route_for_points(player, spatial, prefix)

func physical_route_for_points(player: CharacterBody3D, spatial: Node, points: Array[Vector3]) -> Array[Vector3]:
	if points.size() < 2 or player == null or spatial == null:
		return []
	var capsule_node: CollisionShape3D
	for child: Node in player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D and not child.disabled:
			capsule_node = child
			break
	if capsule_node == null:
		return []
	var capsule := capsule_node.shape as CapsuleShape3D
	var padded := capsule.duplicate() as CapsuleShape3D
	padded.radius += 0.30
	padded.height = maxf(padded.height, padded.radius * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]
	query.margin = 0.01
	var context := {"space": player.get_world_3d().direct_space_state, "spatial": spatial,
		"query": query, "actual": capsule, "padded": padded,
		"seamless": _host.get("seamless_world") if is_instance_valid(_host) else null,
		"offset": capsule_node.global_position - player.global_position + Vector3.UP * 0.06}
	var grounded: Array[Vector3] = points.duplicate()
	for index in grounded.size():
		var point: Vector3 = grounded[index]
		if spatial.is_on_bridge(point):
			point.y = maxf(point.y, preload("res://scripts/bridge_surface_contract.gd").DECK_COLLISION_TOP)
			grounded[index] = point
	var result: Array[Vector3] = [grounded[0]]
	for index in range(1, grounded.size()):
		var a: Vector3 = result.back()
		var b: Vector3 = grounded[index]
		if _physical_segment_clear(context, a, b):
			result.append(b)
			continue
		var detour := _physical_detour(context, a, b)
		if detour.is_empty():
			return []
		for step in range(1, detour.size()):
			result.append(detour[step])
	return result

func _physical_point_clear(context: Dictionary, point: Vector3, padded: bool = false) -> bool:
	var bounds: Vector2 = context.spatial.half_extents
	var inside := absf(point.x) <= bounds.x - 0.55 and absf(point.z) <= bounds.y - 0.55
	var resident: bool = is_instance_valid(context.seamless) and context.seamless.contains_resident_passage(point)
	if (not inside and not resident and not SectorManifest.connector_contains(str(context.spatial.zone_id), point, -0.55)) \
		or not context.spatial.validate_segment(point, point, 0.55):
		return false
	var query: PhysicsShapeQueryParameters3D = context.query
	query.shape = context.padded if padded else context.actual
	query.motion = Vector3.ZERO
	query.transform = Transform3D(Basis.IDENTITY, point + context.offset)
	return context.space.intersect_shape(query, 1).is_empty()

func _physical_segment_clear(context: Dictionary, a: Vector3, b: Vector3) -> bool:
	if not context.spatial.validate_segment(a, b, 0.55) \
		or not _physical_point_clear(context, a) or not _physical_point_clear(context, b):
		return false
	var query: PhysicsShapeQueryParameters3D = context.query
	query.transform = Transform3D(Basis.IDENTITY, a + context.offset)
	query.motion = b - a
	var fractions: PackedFloat32Array = context.space.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 0.9999

func _physical_detour(context: Dictionary, a: Vector3, b: Vector3) -> Array[Vector3]:
	var direction := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := direction.length()
	if length < 0.01 or not _physical_point_clear(context, a) or not _physical_point_clear(context, b):
		return []
	direction /= length
	var sideways := Vector3(-direction.z, 0, direction.x)
	const CELL := 0.4
	const HALF_WIDTH := 10
	var columns := ceili(length / CELL) + HALF_WIDTH * 2 + 1
	if columns * (HALF_WIDTH * 2 + 1) > 4096:
		return []
	var graph := AStar3D.new()
	graph.add_point(0, a)
	graph.add_point(1, b)
	var ids: Dictionary = {}
	for column in range(-HALF_WIDTH, columns - HALF_WIDTH):
		for row in range(-HALF_WIDTH, HALF_WIDTH + 1):
			var along := float(column) * CELL
			var point := a + direction * along + sideways * float(row) * CELL
			point.y = lerpf(a.y, b.y, clampf(along / length, 0.0, 1.0))
			if not _physical_point_clear(context, point, true):
				continue
			var id := graph.get_available_point_id()
			var key := Vector2i(column, row)
			ids[key] = id
			graph.add_point(id, point)
			for neighbour in [key + Vector2i.LEFT, key + Vector2i.UP]:
				if ids.has(neighbour):
					graph.connect_points(id, int(ids[neighbour]))
			for endpoint in [0, 1]:
				var endpoint_position := a if endpoint == 0 else b
				if point.distance_to(endpoint_position) <= 1.6 and _physical_segment_clear(context, endpoint_position, point):
					graph.connect_points(endpoint, id)
	var path := graph.get_point_path(0, 1)
	if path.is_empty():
		return []
	var result: Array[Vector3] = [path[0]]
	for index in range(1, path.size() - 1):
		if (path[index] - result.back()).cross(path[index + 1] - path[index]).length_squared() > 0.000001:
			result.append(path[index])
	result.append(path[path.size() - 1])
	for index in range(1, result.size()):
		if not _physical_segment_clear(context, result[index - 1], result[index]):
			return []
	return result

func _character_visual_state(player: Node3D, camera_rig: Node) -> Dictionary:
	var model := player.get("_mapped_body") as Node3D
	var camera := camera_rig.get("camera") as Camera3D if camera_rig != null else null
	var result := {"ready": player.has_required_body(), "visible": player.is_visible_in_tree(), "meshes": []}
	if model == null:
		return result
	result["source"] = str(model.get_meta("prepared_actor_source", model.get_meta("character_base_path", "")))
	result["bindings_valid"] = bool(model.get_meta("character_material_bindings_valid", false))
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null:
			continue
		var surfaces: Array = []
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			surfaces.append({
				"material": material.resource_name if material != null else "",
				"texture": material.albedo_texture.resource_path if material != null and material.albedo_texture != null else "",
				"albedo": str(material.albedo_color) if material != null else "",
			})
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		result.meshes.append({
			"path": str(model.get_path_to(mesh)), "visible": mesh.is_visible_in_tree(),
			"shadow_mode": mesh.cast_shadow, "transparency": mesh.transparency,
			"layers": mesh.layers, "surfaces": surfaces,
			"bounds_position": _vector(bounds.position), "bounds_size": _vector(bounds.size),
			"in_view": camera.is_position_in_frustum(bounds.get_center()) if camera != null else false,
		})
	return result

func snapshot_for_game(game: Node) -> Dictionary:
	if game == null or not is_instance_valid(game):
		return {"schema_version": 2, "read_only": true, "ready": false}
	var player := game.get("player") as CharacterBody3D
	var camera_rig := game.get("camera_rig") as Node
	var focus := game.get("active_interactable") as Node3D
	var hud := game.get("hud") as Node
	var zone_root := game.get("zone_root") as Node3D
	var player_state := {}
	if player != null and is_instance_valid(player):
		var health := player.get("health_component") as Node
		var stamina := player.get("stamina_component") as Node
		player_state = {
			"position": _vector(player.global_position),
			"velocity": _vector(player.velocity),
			"can_control": bool(player.get("can_control")),
			"on_floor": player.is_on_floor(),
			"on_wall": player.is_on_wall(),
			"facing_yaw": player.rotation.y,
			"health": float(health.get("health")) if health != null else 0.0,
			"dead": bool(health.get("dead")) if health != null else false,
			"stamina": float(stamina.get("stamina")) if stamina != null else 0.0,
			"attack_cooldown": float(player.get("attack_cooldown")),
			"weapon_mode": str(player.get("weapon_mode")),
			"bow_aiming": bool(player.get("bow_aiming")),
			"selected_arrow": str(player.get("selected_arrow_id")),
			"visual": _character_visual_state(player, camera_rig),
		}
	var camera_state := {}
	if camera_rig != null and is_instance_valid(camera_rig):
		var target := camera_rig.get_locked_combat_target() as Node3D
		camera_state = {
			"yaw": float(camera_rig.get("yaw")),
			"pitch": float(camera_rig.get("pitch")),
			"distance": float(camera_rig.get("distance")),
			"first_person": camera_rig.is_first_person(),
			"locked_target_id": str(target.get("enemy_id")) if target != null else "",
			"locked_target_position": _vector(target.global_position) if target != null else {},
		}
	var state := {
		"schema_version": 2,
		"read_only": true,
		"timestamp_ms": Time.get_ticks_msec(),
		"ready": bool(game.get("game_started")) and player != null,
		"new_game_ready": bool(hud.get("new_game_ready")) if hud != null else false,
		"zone": str(game.get("current_zone_id")),
		"transition_pending": bool(game.get("zone_transition_pending")),
		"zone_load_request_pending": bool(game.get("zone_load_request_pending")),
		"paused": get_tree().paused,
		"player": player_state,
		"camera": camera_state,
		"focus": _interaction_state(focus, player),
		"gates": [],
		"interactions": [],
		"enemies": [],
		"quests": {},
		"bosses": [],
		"dialogue": {"visible": false, "page": -1, "pages": 0, "actions": [], "focused_action": -1},
		"inventory": {},
		"saves": {},
		"audio": {},
		"input": {},
		"settings": {},
		"ui": {},
		"performance": _performance_state(),
		"save_exists": FileAccess.file_exists("user://ashen_oath_save.json"),
		"mouse_mode": Input.mouse_mode,
	}
	if hud != null:
		var dialogue_layer := hud.get("dialogue_layer") as Control
		var dialogue_pages: Array = hud.get("dialogue_pages")
		var dialogue_title := hud.get("dialogue_title") as Label
		var dialogue_text := hud.get("dialogue_text") as RichTextLabel
		var dialogue_actions := hud.get("dialogue_actions") as VBoxContainer
		var actions: Array[String] = []
		var focused_action := -1
		if dialogue_actions != null:
			for child in dialogue_actions.get_children():
				if child is Button and not child.is_queued_for_deletion() and not child.disabled:
					if child.has_focus():
						focused_action = actions.size()
					actions.append(child.text)
		state.dialogue = {
			"visible": dialogue_layer != null and dialogue_layer.visible,
			"page": int(hud.get("dialogue_page_index")),
			"pages": dialogue_pages.size(),
			"speaker": dialogue_title.text if dialogue_title != null else "",
			"text": dialogue_text.text if dialogue_text != null else "",
			"actions": actions,
			"focused_action": focused_action,
		}
		state.ui = {
			"active_menu": str(hud.get("active_menu")),
			"loading_visible": bool((hud.get("loading_layer") as Control).visible) if hud.get("loading_layer") != null else false,
			"viewport": _vector2(get_viewport().get_visible_rect().size),
			"focused_control": str(get_viewport().gui_get_focus_owner().name) if get_viewport().gui_get_focus_owner() != null else "",
			"inventory_visible": bool((hud.get("inventory_layer") as Control).visible) if hud.get("inventory_layer") != null else false,
			"buttons": _visible_menu_buttons(hud),
		}
	var packs := game.get("runtime_packs") as Node
	if packs != null:
		var pack_state := {}
		for pack_id in ["opening", "quality_materials", "campaign", "characters", "monsters", "audio"]:
			pack_state[pack_id] = {
				"state": str(packs.get_state(pack_id)),
				"progress": float(packs.get_progress(pack_id)),
				"error": str(packs.get_last_error(pack_id)),
			}
		state["runtime_packs"] = pack_state
	if not state.ready:
		return state
	if not get_tree().paused and zone_root != null:
		_refresh_catalog(game, zone_root)
		for node in _catalog_gates:
			var entry := _interaction_state(node, player)
			if not entry.is_empty():
				state.gates.append(entry)
		for node in _catalog_interactions:
			var entry := _interaction_state(node, player)
			if not entry.is_empty():
				state.interactions.append(entry)
	var enemies: Variant = game.get("active_enemies")
	if enemies is Array:
		for enemy in enemies:
			if not (enemy is Node3D) or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			var health := enemy.get("health_component") as Node
			state.enemies.append({
				"id": str(enemy.get("enemy_id")),
				"position": _vector(enemy.global_position),
				"active": bool(enemy.get("encounter_active")),
				"health": float(health.get("health")) if health != null else 0.0,
				"dead": bool(enemy.get("dead")),
				"pending_attack_time": float(enemy.get("pending_attack_time")),
				"boss_phase": int(enemy.get("boss_phase")),
			})
			var controller := enemy.get_node_or_null("BossEncounterController") as Node
			if controller != null:
				state.bosses.append(controller.get_encounter_state())
	var quests := game.get("quests") as Node
	if quests != null:
		var active_quests: Dictionary = quests.get("active")
		var objectives := {}
		var objectives_done := {}
		for quest_id in active_quests:
			objectives[str(quest_id)] = str(quests.get_active_objective_id(str(quest_id)))
			var done: Array[String] = []
			for objective in active_quests[quest_id].get("objectives", []):
				if bool(objective.get("done", false)):
					done.append(str(objective.get("id", "")))
			objectives_done[str(quest_id)] = done
		state.quests = {
			"tracked": str(quests.get_tracked_quest()),
			"active": active_quests.keys(),
			"completed": (quests.get("completed") as Dictionary).keys(),
			"objectives": objectives,
			"objectives_done": objectives_done,
			"world_flags": (quests.get("world_flags") as Dictionary).duplicate(true),
			"tracker_text": str(quests.get_tracker_text()),
			"road_complete": bool(quests.is_completed("main_road_of_crows")),
			"bell_active": bool(quests.is_active("main_bell_beneath_greyfen")),
			"evidence_ready": bool(quests.is_objective_done("main_road_of_crows", "evidence_ready")),
			"fight_complete": bool(quests.is_objective_done("main_road_of_crows", "fight_ghoulkin")),
		}
	var story := game.get("story_state") as Node
	if story != null:
		state["story"] = {"flags": (story.get("flags") as Dictionary).duplicate(true), "values": (story.get("values") as Dictionary).duplicate(true)}
	var inventory := game.get("inventory") as Node
	if inventory != null:
		state.inventory = {
			"coin": int(inventory.get("coin")),
			"items": (inventory.get("items") as Dictionary).duplicate(true),
			"ingredients": (inventory.get("ingredients") as Dictionary).duplicate(true),
			"active_oil": str(inventory.get("active_oil")),
			"oil_remaining_seconds": float(inventory.get("oil_remaining_seconds")),
			"oil_version": 1,
		}
	state.saves = {
		"manual": FileAccess.file_exists("user://ashen_oath_save.json"),
		"autosave": FileAccess.file_exists("user://ashen_oath_autosave.json"),
		"checkpoint": FileAccess.file_exists("user://ashen_oath_checkpoint.json"),
	}
	var master := AudioServer.get_bus_index("Master")
	var audio := game.get("audio") as Node
	state.audio = {
		"master_db": AudioServer.get_bus_volume_db(master) if master >= 0 else -80.0,
		"muted": AudioServer.is_bus_mute(master) if master >= 0 else true,
		"music_state": str(audio.get("music_state")) if audio != null else "",
		"music_playing": bool((audio.get("music_player") as AudioStreamPlayer).playing) if audio != null and audio.get("music_player") != null else false,
	}
	var input_router := game.get("input_router") as Node
	if input_router != null:
		state.input = {
			"device": str(input_router.get("active_device")),
			"context": str(input_router.get("input_context")),
			"gamepad_id": int(input_router.get("active_gamepad_id")),
			"connected_joypads": Input.get_connected_joypads(),
		}
	var settings := game.get("settings") as Node
	if settings != null:
		var values: Dictionary = settings.get("settings")
		for key in ["quality_preset", "fullscreen", "master_volume", "subtitle_scale", "camera_shake", "reduced_motion", "high_contrast", "gamepad_deadzone", "gamepad_invert_x", "gamepad_invert_y", "custom_bindings"]:
			state.settings[key] = values.get(key)
	return state

func _refresh_catalog(game: Node, zone_root: Node3D) -> void:
	var cache: Variant = game.get("interaction_area_cache")
	var cache_count: int = cache.size() if cache is Array else -1
	var child_count := zone_root.get_child_count()
	var now := Time.get_ticks_msec()
	if zone_root == _catalog_root and child_count == _catalog_child_count and cache_count == _catalog_cache_count and now - _catalog_refreshed_ms < CATALOG_MIN_REFRESH_MS:
		return
	_catalog_root = zone_root
	_catalog_child_count = child_count
	_catalog_cache_count = cache_count
	_catalog_refreshed_ms = now
	_catalog_gates.clear()
	_catalog_interactions.clear()
	for node in zone_root.find_children("*", "Area3D", true, false):
		if node.is_queued_for_deletion() or not _has_property(node, "interaction_id"):
			continue
		if str(node.get("interaction_type")) == "zone":
			_catalog_gates.append(node)
		else:
			_catalog_interactions.append(node)

func _interaction_state(node: Node3D, player: CharacterBody3D) -> Dictionary:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():
		return {}
	var position := node.global_position
	return {
		"id": str(node.get("interaction_id")),
		"type": str(node.get("interaction_type")),
		"target": str(node.get("zone_target")),
		"prompt": str(node.get("prompt")),
		"position": _vector(position),
		"distance": player.global_position.distance_to(position) if player != null else -1.0,
	}

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _vector(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}

func _visible_menu_buttons(hud: Node) -> Array[Dictionary]:
	var buttons: Array[Dictionary] = []
	var menu_layer := hud.get("menu_layer") as Control
	var inventory_layer := hud.get("inventory_layer") as Control
	var dialogue_layer := hud.get("dialogue_layer") as Control
	if not ((menu_layer != null and menu_layer.visible) or (inventory_layer != null and inventory_layer.visible) or (dialogue_layer != null and dialogue_layer.visible)):
		return buttons
	for node in hud.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button.is_queued_for_deletion() or not button.is_visible_in_tree():
			continue
		var rect := button.get_global_rect()
		buttons.append({
			"text": button.text,
			"name": button.name,
			"enabled": not button.disabled,
			"focused": button.has_focus(),
			"position": _vector2(rect.position),
			"size": _vector2(rect.size),
		})
		if buttons.size() >= 48:
			break
	return buttons

func _vector2(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _performance_state() -> Dictionary:
	if _frame_times.is_empty():
		return _performance_cache.duplicate(true)
	if int(_performance_cache.samples) > 0 and _performance_elapsed < 1.0:
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
		"zone": _performance_zone,
		"average_fps": float(_frame_times.size()) / maxf(total, 0.001),
		"one_percent_low_fps": 1.0 / maxf(slow_total / float(slow_count), 0.001),
		"samples": _frame_times.size(),
	}
	return _performance_cache.duplicate(true)

func _record_frame(delta: float, zone_id: String, ready: bool) -> void:
	if not ready or zone_id.is_empty() or zone_id != _performance_zone:
		_performance_zone = zone_id if ready else ""
		_frame_times.clear()
		_performance_elapsed = 0.0
		_performance_cache = {"zone": _performance_zone, "average_fps": 0.0, "one_percent_low_fps": 0.0, "samples": 0}
	if not ready or zone_id.is_empty():
		return
	_frame_times.append(delta)
	if _frame_times.size() > 600:
		_frame_times.pop_front()
	_performance_elapsed += delta
