class_name ZoneBuildContext
extends RefCounted

var _host: Node
var zone_id: String
var ground_count := 0
var bounds_count := 0
var gate_count := 0

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

func _init(game_host: Node, id: String) -> void:
	_host = game_host
	zone_id = id

func add_node(node: Node, parent: Node = null) -> void:
	var target := parent if parent != null else zone_root
	target.add_child(node)

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

func make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color) -> void:
	_host._make_split_ground(width, depth, river_z, river_span, color)
	ground_count += 1

func make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	_host._make_play_area_bounds(width, depth, color)
	bounds_count += 1

func make_road(pos: Vector3, size: Vector3, color: Color) -> void:
	_host._make_road(pos, size, color)

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

func make_visual_box(id: String, pos: Vector3, size: Vector3, color: Color):
	return _host._make_visual_box(id, pos, size, color)

func make_loose_role(role: String, pos: Vector3, scale_value: Vector3, rotation_y: float):
	return _host._make_loose_role(role, pos, scale_value, rotation_y)

func make_visual_role(role: String, category: String, pos: Vector3, scale_value: Vector3, rotation_y: float = 0.0):
	var node = _host._make_role_visual(role, category, scale_value)
	if node == null:
		return null
	node.position = pos
	node.rotation_degrees.y = rotation_y
	add_node(node)
	return node

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

func spawn_enemy(id: String, pos: Vector3):
	return _host._spawn_enemy(id, pos)

func enemy_exists(id: String) -> bool:
	return enemy_defs.has(id)

func make_material(color: Color) -> StandardMaterial3D:
	return _host._mat(color)

func recover_from_river(body: CharacterBody3D, center_z: float, span: float) -> void:
	_host._recover_from_river(body, center_z, span)

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

func make_greyfen_first_impression_dressing() -> void:
	_host._make_greyfen_first_impression_dressing()

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

func make_cart(pos: Vector3) -> void:
	_host._make_cart(pos)

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
	}
	if zone_root != null:
		zone_root.set_meta("zone_build_contract", result)
	return result
