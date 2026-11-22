extends Node3D

const Routes = preload("res://scripts/story_route_catalog.gd")
const Sectors = preload("res://scripts/world_sector_manifest.gd")
var host: Node
var zone_id := ""
var tick := 0.0
var settled := 0.0
var gate_cache: Array[Dictionary] = []
var destinations_requested: Dictionary = {}
var geometry_dirty := true
var route_dirty := true
var route_key := ""
var route: Dictionary = {}
var chosen_gate: Node3D
var best_distance := INF
var wandering := 0.0
var hint_cooldown := 35.0

static func install(game: Node, root: Node3D, zone: String) -> void:
	var director := root.get_node_or_null("JourneyFlowDirector")
	if director == null:
		director = load("res://scripts/journey_flow_director.gd").new()
		director.name = "JourneyFlowDirector"
		root.add_child(director)
		director.configure(game, zone)
	director.route_dirty = true

func configure(game: Node, zone: String) -> void:
	host = game
	zone_id = zone
	get_parent().child_entered_tree.connect(_child_added)
	host.story_state.changed.connect(_story_changed)

func _child_added(_node: Node) -> void:
	geometry_dirty = true

func _story_changed() -> void:
	route_dirty = true
	geometry_dirty = true

func _process(delta: float) -> void:
	if not is_instance_valid(host) or host.zone_root != get_parent() or not host.game_started: return
	if get_tree().paused or host.zone_transition_pending or host.zone_load_request_pending: return
	if not is_instance_valid(host.player) or not host.player.can_control or host.player.transition_locked: return
	tick += delta
	if tick < 0.5: return
	var elapsed := tick
	tick = 0.0
	settled += elapsed
	hint_cooldown = maxf(hint_cooldown - elapsed, 0.0)
	if geometry_dirty:
		_collect_gates()
	_refresh_route()
	var danger := false
	for enemy in host.active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(host.player.global_position) < 14.0:
			danger = true
			break
	if danger:
		wandering = 0.0
		return
	for entry: Dictionary in gate_cache:
		var gate: Node3D = entry.gate
		var available := _available(gate)
		entry.sign.visible = available
		if not available: continue
		var distance: float = gate.global_position.distance_to(host.player.global_position)
		var destination := str(gate.get("zone_target"))
		var toward: Vector3 = gate.global_position - host.player.global_position
		toward.y = 0.0
		var movement: Vector3 = host.player.velocity
		movement.y = 0.0
		if settled >= 8.0 and distance < 9.0 and movement.length() > 0.35 and movement.dot(toward.normalized()) > 0.2:
			if host.runtime_packs != null and not destinations_requested.has(destination):
				# Only queue network work. Existing streaming owns scene residency.
				if host.runtime_packs.request_zone_packs(destination):
					destinations_requested[destination] = true
	if not is_instance_valid(chosen_gate) or not _available(chosen_gate): return
	var remaining: float = chosen_gate.global_position.distance_to(host.player.global_position)
	if remaining < best_distance - 0.8:
		best_distance = remaining
		wandering = 0.0
	elif host.player.velocity.length() > 0.4 and remaining > 5.0:
		wandering += elapsed
	if wandering >= 30.0 and hint_cooldown <= 0.0:
		host.hud.toast("Toward %s: follow the %s sign." % [str(route.get("destination_name", "your destination")), Routes.zone_name(str(chosen_gate.get("zone_target")))])
		hint_cooldown = 120.0
		wandering = 0.0

func _available(gate: Node3D) -> bool:
	return is_instance_valid(gate) and not gate.is_queued_for_deletion() and str(gate.get("interaction_type")) == "zone" and gate.is_interaction_enabled()

func _collect_gates() -> void:
	geometry_dirty = false
	for entry: Dictionary in gate_cache:
		if is_instance_valid(entry.sign): entry.sign.queue_free()
	gate_cache.clear()
	for candidate: Node in get_parent().find_children("*", "Area3D", true, false):
		if not candidate.has_method("get_context_prompt") or str(candidate.get("interaction_type")) != "zone": continue
		if str(candidate.get("zone_target")) == "": continue
		var sign := _make_sign(candidate)
		gate_cache.append({"gate":candidate, "sign":sign})
	route_dirty = true

func _refresh_route() -> void:
	var quest: String = host.quests.get_tracked_quest()
	var objective: String = host.quests.get_active_objective_id(quest)
	var key := quest + ":" + objective
	if key == route_key and not route_dirty: return
	route_key = key
	route_dirty = false
	route = Routes.for_objective(quest, objective, host.story_state, host.quests, zone_id)
	chosen_gate = null
	best_distance = INF
	wandering = 0.0
	var destination := str(route.get("destination_zone", ""))
	var best_steps := 999
	if destination != "" and destination != zone_id:
		for entry: Dictionary in gate_cache:
			if not _available(entry.gate): continue
			var steps := _steps_to(str(entry.gate.get("zone_target")), destination)
			if steps >= 0 and steps < best_steps:
				best_steps = steps
				chosen_gate = entry.gate
	for entry: Dictionary in gate_cache:
		var label := entry.sign.get_node("Destination") as Label3D
		var chosen: bool = entry.gate == chosen_gate
		label.modulate = Color(0.94, 0.77, 0.43) if chosen else Color(0.77, 0.72, 0.60)
		label.text = Routes.zone_name(str(entry.gate.get("zone_target"))).to_upper() + ("\nON YOUR ROAD" if chosen else "")

func _steps_to(source: String, destination: String) -> int:
	if source == destination: return 0
	var visited: Dictionary = {zone_id:true, source:true}
	var queue: Array = [[source, 0]]
	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		for next_zone: String in Sectors.neighbors(str(entry[0])):
			if visited.has(next_zone): continue
			var steps := int(entry[1]) + 1
			if next_zone == destination: return steps
			visited[next_zone] = true
			queue.append([next_zone, steps])
	return -1

func _make_sign(gate: Node3D) -> Node3D:
	var sign := Node3D.new()
	sign.name = "Waymark_" + str(gate.get("zone_target"))
	add_child(sign)
	var door := bool(gate.get_meta("interior_door", false))
	var offset := Vector3(1.55, 0, 0) if not door else Vector3(1.15, 0, 0)
	sign.global_position = host.validate_walkable_position(gate.global_position + offset)
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.22, 0.15, 0.09)
	timber.roughness = 1.0
	for shape: Array in [[Vector3(0.10,1.65,0.10), Vector3(0,0.825,0)], [Vector3(1.25,0.36,0.10), Vector3(0,1.52,0)]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = shape[0]
		mesh.mesh = box
		mesh.position = shape[1]
		mesh.material_override = timber
		mesh.visibility_range_end = 24.0
		sign.add_child(mesh)
	var label := Label3D.new()
	label.name = "Destination"
	label.position = Vector3(0,1.88,0)
	label.font_size = 36
	label.pixel_size = 0.006
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.visibility_range_end = 13.0
	sign.add_child(label)
	return sign
