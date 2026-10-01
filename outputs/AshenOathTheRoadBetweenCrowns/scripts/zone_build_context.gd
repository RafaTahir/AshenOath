class_name ZoneBuildContext
extends RefCounted

var _host: Node
var zone_id: String
var build_profile := "full"
var ground_count := 0
var bounds_count := 0
var gate_count := 0
var operation_count := 0
var operations: Array[String] = []

var zone_root: Node3D:
	get:
		return _host.zone_root as Node3D
var quests:
	get:
		return _host.quests
var story_state:
	get:
		return _host.story_state
var settings:
	get:
		return _host.settings
var enemy_defs:
	get:
		return _host.enemy_defs

func _init(game_host: Node, id: String, profile: String = "full") -> void:
	_host = game_host
	zone_id = id
	build_profile = profile

func is_opening_fast() -> bool:
	return zone_id == "greyfen" and build_profile == "opening_fast"

func is_opening_boot() -> bool:
	return zone_id == "greyfen" and build_profile == "opening_boot"

func add_node(node: Node, parent: Node = null) -> void:
	var target := parent if parent != null else zone_root
	target.add_child(node)
	record_operation("add_node:%s" % str(node.name))

func record_operation(label: String) -> void:
	operation_count += 1
	if operations.size() < 96:
		operations.append(label)

func configure_zone_controller(controller: Node) -> void:
	controller.configure(_host, quality_preset())

func quality_preset() -> String:
	return str(settings.settings.get("quality_preset", "balanced"))

func is_quest_active(quest_id: String) -> bool:
	return quests.is_active(quest_id)

func is_quest_unlocked(quest_id: String) -> bool:
	return quests.is_unlocked(quest_id)

func is_objective_done(quest_id: String, objective_id: String) -> bool:
	return quests.is_objective_done(quest_id, objective_id)

func set_story_flag(flag_id: String, value: Variant) -> void:
	story_state.set_flag(flag_id, value)

func get_story_flag(flag_id: String, fallback: Variant = null) -> Variant:
	return story_state.get_flag(flag_id, fallback)

func crow_shrine_choice_ready() -> bool:
	return _host._crow_shrine_choice_ready()

func road_ready_to_report() -> bool:
	return _host._road_ready_to_report()

func make_ground(pos: Vector3, size: Vector3, color: Color) -> void:
	_host._make_ground(pos, size, color)
	ground_count += 1

func make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color, bridge_width: float = 0.0, bridge_length: float = 0.0, bridge_approach_length: float = 0.0) -> void:
	_host._make_split_ground(width, depth, river_z, river_span, color, bridge_width, bridge_length, bridge_approach_length)
	ground_count += 1

func make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	_host._make_play_area_bounds(width, depth, color)
	bounds_count += 1

func register_authored_gameplay_core() -> bool:
	var candidates: Array[Node] = [zone_root]
	candidates.append_array(zone_root.find_children("*", "", true, false))
	for candidate in candidates:
		if not bool(candidate.get_meta("authored_gameplay_core", false)):
			continue
		var authored_ground := int(candidate.get_meta("ground_contract_count", 0))
		var authored_bounds := int(candidate.get_meta("bounds_contract_count", 0))
		if authored_ground < 1 or authored_bounds < 1:
			return false
		ground_count += authored_ground
		bounds_count += authored_bounds
		record_operation("authored_gameplay_core:%s" % str(candidate.name))
		return true
	return false

func authored_anchor_position(anchor_name: String, fallback: Vector3) -> Vector3:
	var anchor := zone_root.find_child(anchor_name, true, false) as Node3D
	if anchor == null:
		return fallback
	record_operation("authored_anchor:%s" % anchor_name)
	return zone_root.to_local(anchor.global_position)

func make_road(pos: Vector3, size: Vector3, color: Color) -> void:
	_host._make_road(pos, size, color)

func make_terrain_patch(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_host._make_terrain_patch(id, pos, size, color)

func make_grass_tufts(points: Array, color: Color) -> void:
	_host._make_grass_tufts(points, color)

func make_path_stone(pos: Vector3, scale_value: float) -> void:
	_host._make_path_stone(pos, scale_value)

func make_world_wheel(id: String, pos: Vector3, radius: float, depth: float, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	_host._make_world_wheel(id, pos, radius, depth, color, rotation_degrees)

func make_water_patch(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_host._make_water_patch(id, pos, size, color)

func make_fog_sheet(pos: Vector3, size: Vector3, color: Color) -> void:
	_host._make_fog_sheet(pos, size, color)

func make_light(id: String, pos: Vector3, color: Color, energy: float):
	return _host._make_light(id, pos, color, energy)

func make_torch(pos: Vector3) -> void:
	_host._make_torch(pos)

func make_tree_cluster(points: Array) -> void:
	_host._make_tree_cluster(points)

func make_tree(pos: Vector3) -> void:
	_host._make_tree(pos)

func make_tree_wall(axis_extent: float, fixed_pos: float, count: int, along_x: bool) -> void:
	_host._make_tree_wall(axis_extent, fixed_pos, count, along_x)

func make_pillar(pos: Vector3) -> void:
	_host._make_pillar(pos)

func make_prop_box(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_host._make_prop_box(id, pos, size, color)

func make_reserved_collision_box(id: String, pos: Vector3, size: Vector3) -> void:
	# Replacing a blockout visual must retain its exact reservation/collision policy.
	_host._make_prop_box(id, pos, size, Color.WHITE, false)

func make_collision_box(id: String, pos: Vector3, size: Vector3) -> void:
	_host._make_collision_box(id, pos, size)

func make_visual_box(id: String, pos: Vector3, size: Vector3, color: Color):
	return _host._make_visual_box(id, pos, size, color)

func make_loose_role(role: String, pos: Vector3, scale_value: Vector3, rotation_y: float):
	return _host._make_loose_role(role, pos, scale_value, rotation_y)

func make_visual_role(role: String, category: String, pos: Vector3, scale_value: Vector3, rotation_y: float = 0.0, allow_defer: bool = true):
	# Imported castle dressing is visual enrichment rather than arrival-critical
	# gameplay. If its OBJ mesh is not already cached, leave a transform marker
	# for the host to resolve after the player is live instead of parsing text in
	# the transition's synchronous build.
	if allow_defer and _host.has_method("should_defer_visual_role") and _host.should_defer_visual_role(role, category):
		var marker := Node3D.new()
		marker.name = "DeferredVisualRole_%s" % role
		marker.set_meta("deferred_visual_role", role)
		marker.set_meta("deferred_visual_category", category)
		marker.set_meta("deferred_visual_scale", scale_value)
		marker.position = pos
		marker.rotation_degrees.y = rotation_y
		add_node(marker)
		return marker
	var node = _host._make_role_visual(role, category, scale_value)
	if node == null:
		return null
	node.position = pos
	node.rotation_degrees.y = rotation_y
	add_node(node)
	return node

func make_fitted_environment_role(role: String, pos: Vector3, target_size: Vector3, rotation_y: float = 0.0, allow_defer: bool = true):
	var fitted_scale: Vector3 = _host._environment_role_scale(role, target_size)
	return make_visual_role(role, "environment", pos, fitted_scale, rotation_y, allow_defer)

func make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color):
	return _host._make_clue(id, prompt, pos, quest_id, objective_id, color)

func make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE):
	return _host._make_named_interactable(id, type, prompt, pos, color, scale_override)

func make_village_place(id: String, type: String, prompt: String, pos: Vector3, size: Vector3, color: Color):
	return _host._make_village_place(id, type, prompt, pos, size, color)

func make_zone_gate(prompt: String, pos: Vector3, target: String, spawn_pos: Vector3):
	var gate = _host._make_zone_gate(prompt, pos, target, spawn_pos)
	if gate != null:
		gate_count += 1
	return gate

func spawn_enemy(id: String, pos: Vector3, visual_role: String = ""):
	return _host._spawn_enemy(id, pos, visual_role)

func enemy_exists(id: String) -> bool:
	return enemy_defs.has(id)

func make_material(color: Color) -> StandardMaterial3D:
	return _host._mat(color)

func make_world_material(surface: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	return _host.world_materials.get_material(surface, str(_host.settings.settings.get("quality_preset", "balanced")), tint, 0.0, false)

func forest_tree_mesh(path: String) -> ArrayMesh:
	return _host.asset_helper.get_forest_tree_mesh(path)

func recover_from_river(body: CharacterBody3D, center_z: float, span: float) -> void:
	_host._recover_from_river(body, center_z, span)

func river_recovery_handler() -> Callable:
	# Runtime river volumes must not capture this short-lived build context in a
	# signal closure. Return a host-bound callable so the zone can be retired
	# without retaining a RefCounted builder owner until process shutdown.
	return Callable(_host, "_recover_from_river")

func make_greyfen_terrain_layers() -> void:
	_host._make_greyfen_terrain_layers()

func make_wychwood_terrain_layers() -> void:
	_host._make_wychwood_terrain_layers()

func make_greyfen_path_edges() -> void:
	_host._make_greyfen_path_edges()

func make_wychwood_path_edges() -> void:
	_host._make_wychwood_path_edges()

func make_village_dressing() -> void:
	_host._make_village_dressing()

func make_greyfen_first_impression_dressing(stage: String = "") -> void:
	_host._make_greyfen_first_impression_dressing(stage)

func make_quality_greyfen_overhaul() -> void:
	_host._make_quality_greyfen_overhaul()

func make_spawn_composition() -> void:
	_host._make_spawn_composition()

func make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void:
	_host._make_village_house_dressed(pos, yaw, node_name)

func make_fence(pos: Vector3, vertical: bool) -> void:
	_host._make_fence(pos, vertical)

func make_notice_board(pos: Vector3) -> void:
	_host._make_notice_board(pos)

func make_shrine_scene(pos: Vector3) -> void:
	_host._make_shrine_scene(pos)

func make_blacksmith_scene(pos: Vector3) -> void:
	_host._make_blacksmith_scene(pos)

func make_cart(pos: Vector3, include_visual: bool = true) -> void:
	_host._make_cart(pos, include_visual)

func make_wychwood_gate_scene(pos: Vector3) -> void:
	_host._make_wychwood_gate_scene(pos)

func make_route_markers() -> void:
	_host._make_route_markers()

func make_greyfen_story_beats() -> void:
	_host._make_greyfen_road_of_crows_story_beats()

func make_wychwood_route_dressing() -> void:
	_host._make_wychwood_route_dressing()

func make_wychwood_corridor() -> void:
	_host._make_wychwood_corridor()

func make_wychwood_story_beats() -> void:
	_host._make_wychwood_road_of_crows_story_beats()

func make_narrative_aftermath() -> void:
	_host._make_narrative_aftermath(zone_id)

func make_deadfall(pos: Vector3) -> void:
	_host._make_deadfall(pos)

func make_monster_clearing(pos: Vector3) -> void:
	_host._make_monster_clearing(pos)

func make_ritual_stone(pos: Vector3) -> void:
	_host._make_ritual_stone(pos)

func make_quality_wychwood_overhaul() -> void:
	_host._make_quality_wychwood_overhaul()

func make_gravestone(pos: Vector3) -> void:
	_host._make_gravestone(pos)

func make_rubble(pos: Vector3) -> void:
	_host._make_rubble(pos)

func make_herb(id: String, pos: Vector3, color: Color) -> void:
	_host._make_herb(id, pos, color)

func validate() -> Dictionary:
	var errors: Array[String] = []
	if ground_count < 1:
		errors.append("missing ground")
	if bounds_count < 1:
		errors.append("missing play-area bounds")
	if gate_count < 1:
		errors.append("missing return gate")
	if zone_root == null or zone_root.get_child_count() == 0:
		errors.append("empty zone root")
	elif str(zone_root.name) != zone_id:
		errors.append("zone root identity mismatch")
	var result := {
		"ok": errors.is_empty(),
		"zone": zone_id,
		"errors": errors,
		"ground_count": ground_count,
		"bounds_count": bounds_count,
		"gate_count": gate_count,
		"operation_count": operation_count,
		"operations": operations.duplicate(),
	}
	if zone_root != null:
		zone_root.set_meta("zone_build_contract", result)
	return result
