extends Node

const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")

const AMBIENT_LINES := {
	"greyfen_road_quiet":"Road's quiet today. That's worse.",
	"greyfen_bell_dawn":"Bell rang before dawn. Nobody touched it.",
	"greyfen_shrine_voice":"Keep your voice low near the shrine.",
	"greyfen_anwen_sleep":"Anwen has not slept.",
	"greyfen_crows_fat":"Crows came back fat.",
	"greyfen_woods_stare":"Don't stare at the woods. It stares back.",
	"greyfen_forge_night":"Tor worked the forge through the night.",
	"greyfen_well_iron":"Water tastes of iron again.",
	"greyfen_cart_light":"Cart came back lighter than it left.",
	"greyfen_roots_bitter":"Mira says the roots are bitter this year.",
	"greyfen_north_smoke":"No smoke from the north road.",
	"greyfen_keep_working":"We keep working. What else is there?"
}

var host: Node
var player: Node3D
var actors: Array = []
var line_cooldown := 5.0
var quality := "balanced"
var rng := RandomNumberGenerator.new()
var asset_helper
var far_tick_accumulator := 0.0
var simulation_tick_accumulator := 0.0
var spatial_service

const CROWD_IDENTITIES := [
	"generic_villager_01", "generic_villager_02", "farmer_toma", "widow_elna",
	"mira_herbalist", "rook_smuggler", "blacksmith_tor", "generic_villager_03"
]

func _simulation_hz() -> float:
	return 15.0 if quality == "quality" else 10.0

func configure(game: Node, quality_preset: String) -> void:
	host = game
	player = game.player
	quality = quality_preset
	rng.seed = 44017
	asset_helper = AssetSpawnHelper.new()
	add_child(asset_helper)
	set_spatial_service(game.spatial_service)
	_build_population()
	_enroll_named_npcs()

func set_spatial_service(service) -> void:
	spatial_service = service
	for entry in actors:
		_configure_agent(entry)
		_precompute_routes(entry)

func actor_count() -> int:
	return actors.size()

func routine_ids() -> Array:
	return actors.map(func(entry): return str(entry.id))

func _process(delta: float) -> void:
	if host == null or player == null or get_tree().paused: return
	simulation_tick_accumulator += delta
	if simulation_tick_accumulator < 1.0 / _simulation_hz():
		return
	delta = simulation_tick_accumulator
	simulation_tick_accumulator = 0.0
	line_cooldown = max(line_cooldown - delta, 0.0)
	var visible_ambient := _visible_ambient_ids()
	for entry in actors:
		var actor_node: Node3D = entry.node
		var render_distance := 6.0 if quality == "potato" else (16.0 if quality == "quality" else 6.5)
		var over_budget := not bool(entry.named) and not visible_ambient.has(str(entry.id))
		var was_distant := bool(entry.get("distance_suspended", false))
		var distance_limit := render_distance - 0.8 if was_distant else render_distance + 0.8
		var distant := is_instance_valid(actor_node) and (actor_node.global_position.distance_to(player.global_position) > distance_limit or over_budget)
		if is_instance_valid(actor_node) and distant != was_distant:
			actor_node.visible = not distant
			var driver = entry.driver
			if driver != null and driver.has_method("set_distance_suspended"):
				driver.set_distance_suspended(distant)
			entry.distance_suspended = distant
		if not distant:
			_update_actor(entry, delta)

func _build_population() -> void:
	var population := 4 if quality == "potato" else (10 if quality == "quality" else 4)
	var definitions := [
		{"id":"walker_well","path":[Vector3(-12,0,8),Vector3(-5,0,5),Vector3(-8,0,-1)],"speed":1.05},
		{"id":"walker_board","path":[Vector3(-11,0,-4),Vector3(-4,0,7),Vector3(1,0,8)],"speed":0.92},
		{"id":"shrine_pilgrim","path":[Vector3(-4,0,-9),Vector3(2,0,-8),Vector3(4.6,0,-6.6)],"speed":0.72},
		{"id":"forge_helper","path":[Vector3(7,0,7),Vector3(10,0,5),Vector3(8,0,2)],"speed":0.82},
		{"id":"herb_helper","path":[Vector3(-9,0,-4),Vector3(-7,0,-2),Vector3(-10,0,1)],"speed":0.78},
		{"id":"worried_villager","path":[Vector3(4,0,10),Vector3(1,0,5),Vector3(3,0,1)],"speed":0.68},
		{"id":"young_villager","path":[Vector3(-12,0,5),Vector3(-8,0,3),Vector3(-10,0,0)],"speed":1.32,"scale":0.82},
		{"id":"water_carrier","path":[Vector3(-14,0,-2),Vector3(-9,0,-1),Vector3(-6,0,3)],"speed":0.86},
		{"id":"quality_sweeper","path":[Vector3(6,0,8),Vector3(4,0,5),Vector3(7,0,2)],"speed":0.62},
		{"id":"quality_mourner","path":[Vector3(10,0,11),Vector3(12,0,9),Vector3(10,0,7)],"speed":0.58}
	]
	for i in range(population):
		var definition: Dictionary = definitions[i]
		definition.path = host.river_safe_path(definition.path,0.9)
		var actor := Node3D.new()
		actor.name = "Routine_%s" % definition.id
		actor.position = host.validate_walkable_position(definition.path[0])
		host.zone_root.add_child(actor)
		var driver = _make_skeletal_villager(actor, str(definition.id), i, float(definition.get("scale",1.0)))
		var entry := {"id":definition.id,"node":actor,"path":definition.path,"target":1,"speed":definition.speed,"pause":rng.randf_range(0.0,0.25),"driver":driver,"named":false,"phase":rng.randf()*TAU,"base_y":actor.position.y,"route":[],"route_index":0}
		actors.append(entry)
		_configure_agent(entry)

func _enroll_named_npcs() -> void:
	var named := {
		"blacksmith_tor":{"path":[Vector3(9.5,0,3),Vector3(10.4,0,4.7),Vector3(8.7,0,4.4)],"speed":0.55},
		"mira":{"path":[Vector3(-6.8,0,-2.3),Vector3(-8.5,0,-1.2),Vector3(-7.7,0,-4.1)],"speed":0.52},
		"rook":{"path":[Vector3(-7.8,0,8.5),Vector3(-6.2,0,6.8),Vector3(-3.8,0,8.6)],"speed":0.62}
	}
	for id in named:
		named[id].path = host.river_safe_path(named[id].path,0.9)
		var node = host.zone_root.find_child(id,true,false)
		if node == null: continue
		var ambient = node.find_child("NpcAmbient",true,false)
		if ambient != null: ambient.process_mode = Node.PROCESS_MODE_DISABLED
		var entry := {"id":id,"node":node,"path":named[id].path,"target":1,"speed":named[id].speed,"pause":rng.randf_range(0.0,0.25),"driver":node.find_child("CharacterAnimationDriver",true,false),"named":true,"phase":rng.randf()*TAU,"base_y":node.position.y,"route":[],"route_index":0}
		actors.append(entry)
		_configure_agent(entry)
		if entry.driver != null and entry.driver.has_method("set_update_rate_hz"):
			entry.driver.set_update_rate_hz(20.0 if quality == "quality" else 12.0)

func _update_actor(entry: Dictionary, delta: float) -> void:
	var node: Node3D = entry.node
	if not is_instance_valid(node): return
	var distance_to_player := node.global_position.distance_to(player.global_position)
	if distance_to_player < 2.1:
		entry.pause = max(float(entry.pause), 1.2)
		_face(node, player.global_position, delta)
		_set_motion(entry,0.0)
		if line_cooldown <= 0.0 and not bool(entry.named):
			line_cooldown = 8.0
			var lines: Array = AMBIENT_LINES.values()
			host.hud.toast(str(lines[rng.randi_range(0,lines.size()-1)]))
		return
	if float(entry.pause) > 0.0:
		entry.pause = float(entry.pause) - delta
		_set_motion(entry,0.0)
		return
	if entry.path.is_empty():
		_set_motion(entry, 0.0)
		return
	entry.target = int(entry.target) % entry.path.size()
	var final_target: Vector3 = host.validate_walkable_position(entry.path[int(entry.target)])
	if entry.route.is_empty():
		var route_key := int(entry.target)
		var cached_routes: Dictionary = entry.get("routes", {})
		entry.route = cached_routes.get(route_key, [final_target]).duplicate()
		entry.route_index = 1 if entry.route.size() > 1 else 0
		_set_agent_target(entry)
	if entry.route.is_empty():
		_set_motion(entry, 0.0)
		return
	var target: Vector3 = entry.route[int(entry.route_index)]
	var offset := target - node.global_position
	offset.y = 0.0
	if node.global_position.distance_to(target) < 0.28:
		entry.route_index = int(entry.route_index) + 1
		if int(entry.route_index) < entry.route.size():
			_set_agent_target(entry)
			return
		entry.route = []
		entry.target = (int(entry.target) + 1) % entry.path.size()
		entry.pause = rng.randf_range(1.4,3.8) * (1.4 if str(entry.id) == "shrine_pilgrim" else 1.0)
		_set_motion(entry,0.0)
		return
	var direction := offset.normalized()
	var next_position := node.global_position + direction * minf(float(entry.speed) * delta, offset.length())
	if spatial_service != null and not spatial_service.validate_segment(node.global_position, next_position, 0.58):
		entry.route = []
		entry.pause = 0.5
		_set_motion(entry, 0.0)
		return
	node.global_position = next_position
	_face(node,node.global_position + direction,delta)
	_set_motion(entry,float(entry.speed))

func _configure_agent(entry: Dictionary) -> void:
	var actor: Node3D = entry.node
	if not is_instance_valid(actor):
		return
	var agent: NavigationAgent3D = entry.get("agent")
	if agent == null:
		agent = NavigationAgent3D.new()
		agent.name = "NavigationAgent3D"
		agent.path_desired_distance = 0.25
		agent.target_desired_distance = 0.22
		agent.radius = 0.38
		agent.height = 1.72
		actor.add_child(agent)
		entry.agent = agent
	# ZoneSpatialService has already produced a deterministic, bridge-safe route.
	# Retain the agent contract for inspection without running a second solver.
	agent.process_mode = Node.PROCESS_MODE_DISABLED
	var map_rid: RID = spatial_service.get_navigation_map() if spatial_service != null else RID()
	if map_rid.is_valid():
		agent.set_navigation_map(map_rid)
	entry.route = []
	entry.route_index = 0

func _precompute_routes(entry: Dictionary) -> void:
	if spatial_service == null or entry.path.is_empty():
		return
	var routes: Dictionary = {}
	for destination_index in range(entry.path.size()):
		var source_index := wrapi(destination_index - 1, 0, entry.path.size())
		var source: Vector3 = host.validate_walkable_position(entry.path[source_index])
		var destination: Vector3 = host.validate_walkable_position(entry.path[destination_index])
		routes[destination_index] = spatial_service.build_route(source, destination, 0.72)
	entry.routes = routes

func _visible_ambient_ids() -> Dictionary:
	var visible := {}
	var retained := [] if quality == "potato" else (
		["walker_well", "walker_board", "shrine_pilgrim", "forge_helper"] if quality == "quality"
		else []
	)
	for id in retained:
		visible[id] = true
	return visible

func _set_agent_target(entry: Dictionary) -> void:
	pass

func _set_motion(entry: Dictionary, speed: float) -> void:
	var driver = entry.driver
	if driver != null and driver.has_method("set_locomotion"):
		# Routine speeds are walking pace; this ratio also controls clip cadence.
		driver.set_locomotion(clampf(speed / 2.0,0.0,0.70),Vector3.ZERO,true)
	entry.phase = float(entry.phase) + get_process_delta_time() * (0.8 + speed * 1.7)

func _face(node: Node3D, target: Vector3, delta: float) -> void:
	var offset := target - node.global_position
	offset.y = 0.0
	if offset.length() < 0.05: return
	var wanted := atan2(-offset.x,-offset.z)
	node.rotation.y = lerp_angle(node.rotation.y,wanted,min(delta*3.0,1.0))

func _make_skeletal_villager(parent: Node3D, role_id: String, index: int, scale_value: float):
	var role_cycle := [
		"villager_human",
		"villager_female_human",
		"villager_worker_human",
		"villager_hooded_human",
	]
	var role := str(role_cycle[index % role_cycle.size()])
	var mapped = asset_helper.spawn_visual_role(role, "characters")
	if mapped == null or mapped.name.ends_with("_placeholder"):
		push_error("Rigged villager asset unavailable for %s" % role_id)
		return null
	mapped.name = "%s_rigged_human" % role_id
	# The imported role is already normalized to its CharacterRoleSpec height.
	# Apply only a bounded adult variation; the old 0.82 young scale produced
	# visibly tiny actors and multiplied normalization a second time.
	var target_scale := clampf(scale_value, 0.96, 1.04) * (0.99 + 0.01 * float(index % 2))
	asset_helper.apply_normalized_scale(mapped, target_scale)
	mapped.set_meta("char_002_body_role", role)
	mapped.set_meta("char_002_identity", role_id)
	mapped.set_meta("char_009_identity", CROWD_IDENTITIES[index % CROWD_IDENTITIES.size()])
	mapped.set_meta("char_009_variant_index", index)
	parent.add_child(mapped)
	CharacterPresentation.apply_npc(parent, str(mapped.get_meta("char_009_identity", role_id)))
	var driver = CharacterAnimationDriver.new()
	driver.name = "CharacterAnimationDriver"
	mapped.add_child(driver)
	driver.configure(mapped, {"idle":"Idle", "walk":"Walk", "run":"Run", "hit":"RecieveHit", "death":"Death"})
	driver.set_update_rate_hz(20.0 if quality == "quality" else 12.0)
	return driver
