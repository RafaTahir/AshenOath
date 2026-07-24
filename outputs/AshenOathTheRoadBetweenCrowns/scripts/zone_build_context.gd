extends RefCounted

var host: Node
var zone_id: String
var ground_count := 0
var bounds_count := 0
var gate_count := 0

var zone_root:
	get:
		return host.zone_root
var quests:
	get:
		return host.quests
var story_state:
	get:
		return host.story_state
var settings:
	get:
		return host.settings
var enemy_defs:
	get:
		return host.enemy_defs

func _init(game_host: Node, id: String) -> void:
	host = game_host
	zone_id = id

func make_ground(pos: Vector3, size: Vector3, color: Color) -> void:
	host._make_ground(pos, size, color)
	ground_count += 1

func make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	host._make_play_area_bounds(width, depth, color)
	bounds_count += 1

func make_road(pos: Vector3, size: Vector3, color: Color) -> void:
	host._make_road(pos, size, color)

func make_fog_sheet(pos: Vector3, size: Vector3, color: Color) -> void:
	host._make_fog_sheet(pos, size, color)

func make_torch(pos: Vector3) -> void:
	host._make_torch(pos)

func make_tree_cluster(points: Array) -> void:
	host._make_tree_cluster(points)

func make_tree(pos: Vector3) -> void:
	host._make_tree(pos)

func make_pillar(pos: Vector3) -> void:
	host._make_pillar(pos)

func make_prop_box(id: String, pos: Vector3, size: Vector3, color: Color):
	return host._make_prop_box(id, pos, size, color)

func make_loose_role(role: String, pos: Vector3, scale: Vector3, rotation_y: float):
	return host._make_loose_role(role, pos, scale, rotation_y)

func make_light(id: String, pos: Vector3, color: Color, energy: float):
	return host._make_light(id, pos, color, energy)

func make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color):
	return host._make_clue(id, prompt, pos, quest_id, objective_id, color)

func make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE):
	return host._make_named_interactable(id, type, prompt, pos, color, scale_override)

func make_zone_gate(prompt: String, pos: Vector3, target: String, spawn_pos: Vector3):
	var gate = host._make_zone_gate(prompt, pos, target, spawn_pos)
	if gate != null:
		gate_count += 1
	return gate

func spawn_enemy(id: String, pos: Vector3):
	return host._spawn_enemy(id, pos)

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
	return {
		"ok": errors.is_empty(),
		"zone": zone_id,
		"errors": errors,
		"ground_count": ground_count,
		"bounds_count": bounds_count,
		"gate_count": gate_count,
	}
