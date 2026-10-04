extends Node

const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")
const ConsequenceRoutines = preload("res://scripts/village_consequence_routines.gd")

const WALK_ACCELERATION := 1.65
const WALK_BRAKING := 2.8
const ARRIVAL_DISTANCE := 0.065
const ROUTE_TURN_RATE := 2.65
const ATTENTION_TURN_RATE := 1.65

const AMBIENT_LINES := {
	"greyfen_road_quiet":"Road's quiet today. That's worse.",
	"greyfen_bell_dawn":"Bell rang before dawn. Nobody touched it.",
	"greyfen_shrine_voice":"Keep your voice low near the shrine.",
	"greyfen_anwen_sleep":"Anwen has not slept.",
	"greyfen_crows_fat":"Crows came back fat.",
	"greyfen_woods_stare":"Don't stare at the woods. It stares back.",
	"greyfen_forge_night":"Tor worked the forge through the night.",
	"greyfen_well_iron":"Water tastes of iron again.",
	"greyfen_cart_light":"Bram always brought the empty baskets back. Not this time.",
	"greyfen_roots_bitter":"Mira says the roots are bitter this year.",
	"greyfen_north_smoke":"No smoke from the north road.",
	"greyfen_keep_working":"We keep working. What else is there?"
}

const POST_REPORT_LINES := {
	"private": ["Anwen took the evidence inside. The village is pretending not to listen.", "Nobody asks what Kael told her. They watch the cemetery road instead."],
	"public": ["The notice board has new names on it. People read them and keep their hands busy.", "The bell changed the way Greyfen walks. No one crosses the square alone."],
	"retained": ["Someone kept a piece of the road's story. The crows know which piece.", "The evidence is not all in Anwen's hands. That makes every quiet conversation sharper."]
}

const ROUTINE_PROFILES := {
	"walker_well": {"occupation": "well keeper", "activity": "well", "activity_seconds": 2.8, "line": "greyfen_well_iron"},
	"walker_board": {"occupation": "notice reader", "activity": "notice_board", "activity_seconds": 2.4, "line": "greyfen_road_quiet"},
	"shrine_pilgrim": {"occupation": "shrine pilgrim", "activity": "shrine", "activity_seconds": 3.4, "line": "greyfen_shrine_voice"},
	"forge_helper": {"occupation": "forge helper", "activity": "forge", "activity_seconds": 3.1, "line": "greyfen_forge_night"},
	"herb_helper": {"occupation": "herb gatherer", "activity": "herb_stall", "activity_seconds": 2.6, "line": "greyfen_roots_bitter"},
	"worried_villager": {"occupation": "road lookout", "activity": "lookout", "activity_seconds": 2.0, "line": "greyfen_north_smoke"},
	"young_villager": {"occupation": "market runner", "activity": "market", "activity_seconds": 1.8, "line": "greyfen_cart_light"},
	"water_carrier": {"occupation": "water carrier", "activity": "well", "activity_seconds": 2.4, "line": "greyfen_well_iron"},
	"quality_sweeper": {"occupation": "street sweeper", "activity": "market", "activity_seconds": 2.2, "line": "greyfen_keep_working"},
	"quality_mourner": {"occupation": "mourner", "activity": "shrine", "activity_seconds": 3.0, "line": "greyfen_anwen_sleep"},
	"blacksmith_tor": {"occupation": "blacksmith", "activity": "forge", "activity_seconds": 3.6, "line": "greyfen_forge_night"},
	"mira": {"occupation": "herbalist", "activity": "herb_stall", "activity_seconds": 3.0, "line": "greyfen_roots_bitter"},
	"rook": {"occupation": "road watcher", "activity": "notice_board", "activity_seconds": 2.2, "line": "greyfen_crows_fat"}
}

const OCCUPATION_LINES := {
	"walker_well": "Sella left her washing on the line. I brought it in before the rain.",
	"walker_board": "Bram lent me his cart every harvest. Never asked for a coin.",
	"shrine_pilgrim": "Oren carved that wooden crow himself. Anwen kept telling him to mind his fingers.",
	"forge_helper": "Tor repaired Bram's axle yesterday. He still has the payment laid aside."
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
var story_signature := ""
var last_story_line := ""
var story_dirty := true
var story_source: Node

const CROWD_IDENTITIES := [
	"generic_villager_01", "generic_villager_02", "farmer_toma", "widow_elna",
	"mira_herbalist", "rook_smuggler", "blacksmith_tor", "generic_villager_03"
]

func _simulation_hz() -> float:
	# Story, distance and hydration decisions are cheap background ticks. Visible
	# bodies move each frame independently of this decision frequency.
	return 15.0 if quality == "quality" else 8.0

func configure(game: Node, quality_preset: String) -> void:
	if story_source != null and is_instance_valid(story_source) and story_source.changed.is_connected(_on_story_changed):
		story_source.changed.disconnect(_on_story_changed)
	host = game
	story_source = game.story_state
	if story_source != null:
		story_source.changed.connect(_on_story_changed)
	story_dirty = true
	player = game.player
	quality = quality_preset
	rng.seed = 44017
	# Share the game's imported-resource and retargeted-animation cache. A
	# controller-local helper repeated that work when the first villager spawned.
	asset_helper = game.asset_helper
	set_spatial_service(game.spatial_service)
	if not bool(get_meta("staged_population", false)):
		_build_population()
	_enroll_named_npcs()
	_sync_story_state(true)

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
	if host == null or player == null or get_tree().paused or not bool(host.get("game_started")): return
	simulation_tick_accumulator += delta
	var decision_tick: bool = simulation_tick_accumulator >= 1.0 / _simulation_hz()
	if decision_tick:
		simulation_tick_accumulator = 0.0
	line_cooldown = max(line_cooldown - delta, 0.0)
	if decision_tick and story_dirty:
		_sync_story_state(false)
	for entry in actors:
		var actor_node: Node3D = entry.node
		if not is_instance_valid(actor_node):
			continue
		if decision_tick:
			if entry.driver == null:
				var hydrated_driver: Node = actor_node.find_child("CharacterAnimationDriver", true, false)
				if hydrated_driver != null:
					entry.driver = hydrated_driver
			var render_distance: float = 8.0 if quality == "potato" else (18.0 if quality == "quality" else 16.0)
			var was_distant: bool = bool(entry.get("distance_suspended", false))
			var distance_limit: float = render_distance - 0.8 if was_distant else render_distance + 0.8
			var distance_to_player: float = actor_node.global_position.distance_to(player.global_position)
			var distant: bool = distance_to_player > distance_limit
			var driver: Node = entry.driver
			if distant != was_distant:
				actor_node.visible = not distant
				if driver != null and driver.has_method("set_distance_suspended"):
					driver.set_distance_suspended(distant)
				entry.distance_suspended = distant
				entry.motion_speed = 0.0
			if not distant and driver != null and driver.has_method("set_update_rate_hz"):
				var animation_hz: float = 30.0 if distance_to_player < 7.0 else (20.0 if quality == "quality" else 15.0)
				if not is_equal_approx(float(entry.get("animation_hz", 0.0)), animation_hz):
					driver.set_update_rate_hz(animation_hz)
					entry.animation_hz = animation_hz
		if not bool(entry.get("distance_suspended", false)):
			# A stalled render frame must not launch a villager across an anchor.
			_update_actor(entry, minf(delta, 0.05))

func build_population_member(index: int) -> void:
	_build_population(index, 1)
	_sync_story_state(true)

func _build_population(first := 0, count := -1) -> void:
	var population := 4 if quality == "potato" else (10 if quality == "quality" else 4)
	var definitions := [
		{"id":"walker_well","path":[Vector3(-12,0,8),Vector3(-5,0,5),Vector3(-8,0,-1)],"speed":1.05},
		{"id":"walker_board","path":[Vector3(-11,0,-4),Vector3(-4,0,7),Vector3(1,0,8)],"speed":0.92},
		{"id":"shrine_pilgrim","path":[Vector3(-4,0,-9),Vector3(2,0,-8),Vector3(4.6,0,-6.6)],"speed":0.72},
		{"id":"forge_helper","path":[Vector3(8,0,1.5),Vector3(10.5,0,1),Vector3(9.5,0,-1)],"speed":0.82},
		{"id":"herb_helper","path":[Vector3(-9,0,-4),Vector3(-7,0,-2),Vector3(-10,0,1)],"speed":0.78},
		{"id":"worried_villager","path":[Vector3(4,0,10),Vector3(1,0,5),Vector3(3,0,1)],"speed":0.68},
		{"id":"young_villager","path":[Vector3(-12,0,5),Vector3(-8,0,3),Vector3(-10,0,0)],"speed":1.32,"scale":0.82},
		{"id":"water_carrier","path":[Vector3(-14,0,-2),Vector3(-9,0,-1),Vector3(-6,0,3)],"speed":0.86},
		{"id":"quality_sweeper","path":[Vector3(6,0,8),Vector3(4,0,5),Vector3(7,0,2)],"speed":0.62},
		{"id":"quality_mourner","path":[Vector3(10,0,11),Vector3(12,0,9),Vector3(10,0,7)],"speed":0.58}
	]
	var end := population if count < 0 else mini(population, first + count)
	for i in range(first, end):
		var actor_started := Time.get_ticks_usec()
		var definition: Dictionary = definitions[i]
		if host.zone_root.find_child("Routine_%s" % definition.id, true, false) != null:
			continue
		definition.path = host.river_safe_path(definition.path,0.9)
		var actor := Node3D.new()
		actor.name = "Routine_%s" % definition.id
		actor.position = host.validate_walkable_position(definition.path[0])
		host.zone_root.add_child(actor)
		var spawn_started := Time.get_ticks_usec()
		var driver = _make_skeletal_villager(actor, str(definition.id), i, float(definition.get("scale",1.0)))
		var spawn_ms := float(Time.get_ticks_usec() - spawn_started) / 1000.0
		var entry := _make_entry(definition.id, actor, definition.path, definition.speed, driver, false)
		actors.append(entry)
		_configure_agent(entry)
		if OS.get_environment("ASHEN_PROFILE_GREYFEN_ACTORS") == "1":
			print("GREYFEN_ACTOR_PROFILE id=%s spawn_ms=%.2f setup_ms=%.2f total_ms=%.2f" % [
				definition.id, spawn_ms,
				float(Time.get_ticks_usec() - spawn_started) / 1000.0 - spawn_ms,
				float(Time.get_ticks_usec() - actor_started) / 1000.0,
			])

func _enroll_named_npcs() -> void:
	var named := {
		"blacksmith_tor":{"path":[Vector3(9.5,0,3),Vector3(10.4,0,4.7),Vector3(8.7,0,4.4)],"speed":0.55},
		"mira":{"path":[Vector3(-6.8,0,-2.3),Vector3(-8.5,0,-1.2),Vector3(-7.7,0,-4.1)],"speed":0.52},
		"rook":{"path":[Vector3(-7.8,0,8.5),Vector3(-6.2,0,6.8),Vector3(-3.8,0,8.6)],"speed":0.62}
	}
	for id in named:
		if actors.any(func(entry): return str(entry.id) == str(id)):
			continue
		named[id].path = host.river_safe_path(named[id].path,0.9)
		var node = host.zone_root.find_child(id,true,false)
		if node == null: continue
		var ambient = node.find_child("NpcAmbient",true,false)
		if ambient != null: ambient.process_mode = Node.PROCESS_MODE_DISABLED
		var entry := _make_entry(id, node, named[id].path, named[id].speed, node.find_child("CharacterAnimationDriver",true,false), true)
		actors.append(entry)
		_configure_agent(entry)
		if entry.driver != null and entry.driver.has_method("set_update_rate_hz"):
			entry.driver.set_update_rate_hz(30.0)

func _update_actor(entry: Dictionary, delta: float) -> void:
	var node: Node3D = entry.node
	if not is_instance_valid(node): return
	if bool(node.get_meta("dialogue_facing_lock", false)):
		entry.motion_speed = 0.0
		entry.travel_direction = Vector3.ZERO
		return
	# Major encounters temporarily own their arena. The game restores this
	# marker after the encounter so named villagers do not walk through a boss
	# fight or re-enter its collision space while the player is engaged.
	if bool(node.get_meta("bell_eater_evacuated", false)):
		entry.motion_speed = 0.0
		_set_motion(entry, 0.0)
		return
	if not bool(entry.get("activity_active", false)) and float(entry.get("motion_speed", 0.0)) < 0.05:
		_apply_pending_routine(entry)
	var distance_to_player := node.global_position.distance_to(player.global_position)
	if distance_to_player < 2.1:
		entry.pause = max(float(entry.pause), 1.2)
		_brake_actor(entry, delta)
		if float(entry.motion_speed) < 0.05:
			_face(node, player.global_position, delta)
		if line_cooldown <= 0.0 and not bool(entry.named):
			line_cooldown = 8.0
			host.hud.toast(_line_for_actor(entry))
		return
	if bool(entry.get("activity_active", false)):
		_update_activity(entry, delta)
		return
	if float(entry.pause) > 0.0:
		entry.pause = float(entry.pause) - delta
		_brake_actor(entry, delta)
		return
	if entry.path.is_empty():
		_brake_actor(entry, delta)
		return
	entry.target = int(entry.target) % entry.path.size()
	if entry.route.is_empty():
		var final_target: Vector3 = host.validate_walkable_position(entry.path[int(entry.target)])
		var route_key := int(entry.target)
		var cached_routes: Dictionary = entry.get("routes", {})
		entry.route = cached_routes.get(route_key, [final_target]).duplicate()
		entry.route_index = 1 if entry.route.size() > 1 else 0
		_set_agent_target(entry)
	if entry.route.is_empty():
		_brake_actor(entry, delta)
		return
	var target: Vector3 = entry.route[int(entry.route_index)]
	var offset := target - node.global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance <= ARRIVAL_DISTANCE + 0.015 and float(entry.motion_speed) < 0.12:
		entry.motion_speed = 0.0
		_set_motion(entry, 0.0)
		entry.route_index = int(entry.route_index) + 1
		if int(entry.route_index) < entry.route.size():
			_set_agent_target(entry)
			return
		entry.route = []
		entry.target = (int(entry.target) + 1) % entry.path.size()
		_begin_activity(entry)
		return
	var direction: Vector3 = offset.normalized()
	var wanted_yaw: float = atan2(-direction.x, -direction.z)
	var turn_error: float = absf(wrapf(wanted_yaw - node.rotation.y, -PI, PI))
	# Arrive and plant the feet before a sharp corner. Translating sideways
	# while spinning through a half-turn would defeat the facing improvement.
	if turn_error > deg_to_rad(65.0) and float(entry.motion_speed) > 0.05:
		_brake_actor(entry, delta)
		return
	_face(node, node.global_position + direction, delta, true)
	turn_error = absf(wrapf(wanted_yaw - node.rotation.y, -PI, PI))
	var turn_pace: float = clampf((deg_to_rad(65.0) - turn_error) / deg_to_rad(48.0), 0.0, 1.0)
	var arrival_pace: float = sqrt(2.0 * WALK_BRAKING * maxf(distance - ARRIVAL_DISTANCE, 0.0))
	var desired_speed: float = minf(float(entry.speed) * turn_pace, arrival_pace)
	var current_speed: float = float(entry.motion_speed)
	var rate: float = WALK_ACCELERATION if desired_speed > current_speed else WALK_BRAKING
	entry.motion_speed = move_toward(current_speed, desired_speed, rate * delta)
	entry.travel_direction = direction
	_move_actor(entry, direction, float(entry.motion_speed), delta, maxf(distance - ARRIVAL_DISTANCE, 0.0))

func _brake_actor(entry: Dictionary, delta: float) -> void:
	entry.motion_speed = move_toward(float(entry.get("motion_speed", 0.0)), 0.0, WALK_BRAKING * delta)
	var direction: Vector3 = entry.get("travel_direction", Vector3.ZERO)
	_move_actor(entry, direction, float(entry.motion_speed), delta)

func _move_actor(entry: Dictionary, direction: Vector3, speed: float, delta: float, remaining_distance: float = INF) -> void:
	var node: Node3D = entry.node
	var start: Vector3 = node.global_position
	var step: float = minf(speed * delta, remaining_distance)
	if direction.length_squared() < 0.001 or step <= 0.00001:
		entry.motion_speed = 0.0
		_set_motion(entry, 0.0)
		return
	var destination: Vector3 = start + direction * step
	if spatial_service != null and not spatial_service.validate_runtime_segment(start, destination, 0.58):
		entry.route = []
		entry.pause = 0.5
		entry.motion_speed = 0.0
		_set_motion(entry, 0.0)
		return
	node.global_position = destination
	var achieved_velocity: Vector3 = (node.global_position - start) / maxf(delta, 0.001)
	achieved_velocity.y = 0.0
	_set_motion(entry, achieved_velocity.length(), achieved_velocity.normalized())

func _make_entry(id: String, node: Node3D, path: Array, speed: float, driver: Node, named: bool) -> Dictionary:
	var profile: Dictionary = ROUTINE_PROFILES.get(id, {"occupation": "villager", "activity": "idle", "activity_seconds": 2.0, "line": "greyfen_keep_working"})
	var entry := {
		"id": id, "node": node, "path": path, "target": 1, "speed": speed,
		"base_path": path.duplicate(), "pending_routine": {},
		"pause": rng.randf_range(0.0, 0.25), "driver": driver, "named": named,
		"phase": rng.randf() * TAU, "base_y": node.position.y, "route": [],
		"route_index": 0, "profile": profile.duplicate(true), "activity_active": false,
		"activity_elapsed": 0.0, "activity_cycles": 0, "life_state": "walking",
		"story_reaction": "baseline", "motion_speed": 0.0, "travel_direction": Vector3.ZERO
	}
	node.set_meta("locomotion_owner", "greyfen_life")
	node.set_meta("life_ticket", "LIFE-001")
	node.set_meta("life_routine", id)
	node.set_meta("life_occupation", str(profile.get("occupation", "villager")))
	node.set_meta("life_state", "walking")
	node.set_meta("life_story_reaction", "baseline")
	return entry

func _begin_activity(entry: Dictionary) -> void:
	var node: Node3D = entry.node
	var profile: Dictionary = entry.profile
	entry.activity_active = true
	entry.motion_speed = 0.0
	entry.travel_direction = Vector3.ZERO
	entry.activity_elapsed = 0.0
	entry.activity_cycles = int(entry.activity_cycles) + 1
	entry.life_state = "working:%s" % str(profile.get("activity", "idle"))
	node.set_meta("life_state", entry.life_state)
	_set_activity_pose(entry, true)

func _update_activity(entry: Dictionary, delta: float) -> void:
	var node: Node3D = entry.node
	var profile: Dictionary = entry.profile
	entry.activity_elapsed = float(entry.activity_elapsed) + delta
	var anchor := _activity_anchor(entry)
	if anchor != Vector3.ZERO:
		_face(node, anchor, delta)
	_set_activity_pose(entry, true)
	if float(entry.activity_elapsed) >= float(profile.get("activity_seconds", 2.0)):
		_end_activity(entry)
		entry.pause = rng.randf_range(0.65, 1.55)

func _end_activity(entry: Dictionary) -> void:
	entry.activity_active = false
	entry.life_state = "walking"
	entry.route = []
	entry.route_index = 0
	entry.node.set_meta("life_state", "walking")
	_set_activity_pose(entry, false)
	_apply_pending_routine(entry)

func _apply_pending_routine(entry: Dictionary) -> void:
	var pending: Dictionary = entry.get("pending_routine", {})
	if pending.is_empty(): return
	entry.pending_routine = {}
	entry.profile = pending.profile
	entry.consequence_line = str(pending.get("line", ""))
	entry.node.set_meta("life_occupation", str(entry.profile.get("occupation", "villager")))
	if bool(entry.named): return
	var next_path: Array = pending.path
	if next_path == entry.path: return
	entry.path = host.river_safe_path(next_path, 0.9)
	entry.target = 0
	_precompute_routes(entry)
	# The first leg begins where the person actually stopped, not where the
	# new loop's last anchor happens to be. No teleport or stale route splice.
	var destination: Vector3 = host.validate_walkable_position(entry.path[0])
	entry.route = spatial_service.build_route(entry.node.global_position, destination, 0.72) if spatial_service != null else [destination]
	entry.route_index = 1 if entry.route.size() > 1 else 0

func _set_activity_pose(entry: Dictionary, active: bool) -> void:
	var driver = entry.driver
	if driver == null:
		return
	var activity := str(entry.profile.get("activity", "idle"))
	if active:
		if activity == "notice_board" or activity == "lookout" or bool(entry.get("quiet_after_report", false)):
			if driver.has_method("set_working"):
				driver.set_working(false)
			if driver.has_method("set_dialogue_pose"):
				driver.set_dialogue_pose(true)
		else:
			if driver.has_method("set_dialogue_pose"):
				driver.set_dialogue_pose(false)
			if driver.has_method("set_working"):
				driver.set_working(true)
	else:
		if driver.has_method("set_working"):
			driver.set_working(false)
		if driver.has_method("set_dialogue_pose"):
			driver.set_dialogue_pose(false)

func _activity_anchor(entry: Dictionary) -> Vector3:
	var activity := str(entry.profile.get("activity", ""))
	if activity == "notice_board" and host != null and is_instance_valid(host.zone_root):
		var board := host.zone_root.find_child("notice_board", true, false) as Node3D
		if board != null:
			return board.global_position + Vector3(0, 0, -1.2)
	var anchors := {
		"well": Vector3(-8.0, 0.0, -1.0),
		"kitchen": Vector3(-4.4, 0.0, 0.9),
		"drain": Vector3(2.8, 0.0, 7.1),
		"relief": Vector3(-9.0, 0.0, 3.5),
		"notice_board": Vector3(4.4, 0.0, 10.9),
		"shrine": Vector3(5.8, 0.0, -7.0),
		"forge": Vector3(9.0, 0.0, -1.0),
		"herb_stall": Vector3(-7.0, 0.0, -2.0),
		"lookout": Vector3(1.5, 0.0, 5.0),
		"market": Vector3(-6.3, 0.0, 8.5)
	}
	return anchors.get(activity, Vector3.ZERO)

func _on_story_changed() -> void:
	story_dirty = true

func _sync_story_state(force: bool) -> void:
	if host == null:
		return
	story_dirty = false
	var state = host.get("story_state")
	var report := str(state.get_flag("evidence_report", "")) if state != null and state.has_method("get_flag") else ""
	var bell := bool(state.get_flag("cemetery_bell_rung", false)) if state != null and state.has_method("get_flag") else false
	var signature := "%s|%s|%s" % [report, str(bell), ConsequenceRoutines.signature(state)]
	if not force and signature == story_signature:
		return
	story_signature = signature
	var reaction := "baseline"
	if report != "":
		reaction = "reported_%s" % report
	if bell:
		reaction += "_bell_rung"
	for entry in actors:
		entry.story_reaction = reaction
		# Named characters retain their reserved routes. Ambient workers change
		# assignments only after planting their feet or finishing an activity.
		entry.quiet_after_report = (report == "public" and str(entry.id) in ["forge_helper", "blacksmith_tor"]) \
			or (report == "private" and str(entry.id) == "shrine_pilgrim")
		var base_profile: Dictionary = ROUTINE_PROFILES.get(str(entry.id), entry.profile)
		var next_profile := base_profile.duplicate(true)
		if report != "":
			next_profile.activity_seconds = float(base_profile.get("activity_seconds", 2.0)) * 1.8
		var outcome := ConsequenceRoutines.for_actor(str(entry.id), state)
		for key in ["activity", "occupation", "activity_seconds"]:
			if outcome.has(key): next_profile[key] = outcome[key]
		entry.pending_routine = {"profile":next_profile, "path":outcome.get("path", entry.base_path).duplicate(), "line":outcome.get("line", "")}
		var node: Node3D = entry.node
		if is_instance_valid(node):
			node.set_meta("life_story_reaction", reaction)
			if bool(entry.get("activity_active", false)):
				_set_activity_pose(entry, true)

func _line_for_actor(entry: Dictionary) -> String:
	var consequence_line := str(entry.get("consequence_line", ""))
	if consequence_line != "": return consequence_line
	var reaction := str(entry.get("story_reaction", "baseline"))
	for report in ["private", "public", "retained"]:
		if reaction.begins_with("reported_" + report):
			var lines: Array = POST_REPORT_LINES[report]
			return str(lines[int(entry.get("activity_cycles", 0)) % lines.size()])
	return str(OCCUPATION_LINES.get(str(entry.id), AMBIENT_LINES.get(str(entry.profile.get("line", "")), AMBIENT_LINES.greyfen_keep_working)))

func get_routine_snapshot() -> Array:
	var snapshot: Array = []
	for entry in actors:
		snapshot.append({
			"id": str(entry.id), "named": bool(entry.named),
			"occupation": str(entry.profile.get("occupation", "")),
			"activity": str(entry.profile.get("activity", "")),
			"state": str(entry.life_state), "story_reaction": str(entry.story_reaction),
			"activity_cycles": int(entry.activity_cycles),
			"position": entry.node.global_position if is_instance_valid(entry.node) else Vector3.ZERO
		})
	return snapshot

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

func _set_agent_target(entry: Dictionary) -> void:
	pass

func _set_motion(entry: Dictionary, speed: float, direction: Vector3 = Vector3.ZERO) -> void:
	var driver = entry.driver
	if driver != null and driver.has_method("set_locomotion"):
		if driver.has_method("set_working"):
			driver.set_working(false)
		if driver.has_method("set_dialogue_pose"):
			driver.set_dialogue_pose(false)
		# Report the distance actually covered. The shared driver owns gait and
		# cadence in metres per second, including the slow named work routines.
		var player_nearby: bool = is_instance_valid(player) and entry.node.global_position.distance_to(player.global_position) < 2.1
		if speed <= 0.01 and str(entry.id) == "forge_helper" and not bool(entry.get("quiet_after_report", false)) and not player_nearby and driver.has_method("set_working"):
			driver.set_working(true)
		else:
			if driver.has_method("set_working"):
				driver.set_working(false)
			if driver.has_method("set_locomotion_motion"):
				driver.set_locomotion_motion(direction * speed, true)
			else:
				driver.set_locomotion(clampf(speed / 2.0,0.0,0.70),direction,true)
	entry.phase = float(entry.phase) + get_process_delta_time() * (0.8 + speed * 1.7)

func _face(node: Node3D, target: Vector3, delta: float, walking: bool = false) -> void:
	var offset := target - node.global_position
	offset.y = 0.0
	if offset.length() < 0.05: return
	var wanted := atan2(-offset.x,-offset.z)
	var turn_error: float = wrapf(wanted - node.rotation.y, -PI, PI)
	var turn_limit: float = (ROUTE_TURN_RATE if walking else ATTENTION_TURN_RATE) * delta
	node.rotation.y += clampf(turn_error, -turn_limit, turn_limit)

func _make_skeletal_villager(parent: Node3D, role_id: String, index: int, scale_value: float):
	var role_cycle := [
		"villager_human",
		"villager_female_human",
		"villager_worker_human",
		"villager_hooded_human",
	]
	var role := str(role_cycle[index % role_cycle.size()])
	# The imported role is already normalized to its CharacterRoleSpec height.
	# Apply only a bounded adult variation; the old 0.82 young scale produced
	# visibly tiny actors and multiplied normalization a second time.
	var target_scale := clampf(scale_value, 0.96, 1.04) * (0.99 + 0.01 * float(index % 2))
	if host != null and host.has_method("should_defer_character_role") \
			and bool(host.should_defer_character_role(role, role_id)):
		var marker := Node3D.new()
		marker.name = "DeferredCharacterVisual_%s" % role_id
		marker.set_meta("deferred_visual_role", role)
		marker.set_meta("deferred_visual_category", "characters")
		marker.set_meta("deferred_visual_actor_id", CROWD_IDENTITIES[index % CROWD_IDENTITIES.size()])
		marker.set_meta("deferred_visual_scale", Vector3.ONE * target_scale)
		parent.set_meta("character_variant_seed", "%s:%d" % [role_id, index])
		parent.set_meta("greyfen_routine_id", role_id)
		parent.add_child(marker)
		return null
	var visual_started := Time.get_ticks_usec()
	var mapped = asset_helper.spawn_visual_role(role, "characters", "%s:%d" % [role_id, index])
	var load_ms := float(Time.get_ticks_usec() - visual_started) / 1000.0
	if mapped == null or mapped.name.ends_with("_placeholder"):
		push_error("Rigged villager asset unavailable for %s" % role_id)
		return null
	mapped.name = "%s_rigged_human" % role_id
	asset_helper.apply_normalized_scale(mapped, target_scale)
	mapped.set_meta("char_002_body_role", role)
	mapped.set_meta("char_002_identity", role_id)
	# Routine identity owns the visible occupation recipe. The old rotating
	# generic aliases made well keepers, pilgrims, and forge workers render as
	# unrelated clone recipes despite having distinct schedules.
	mapped.set_meta("char_009_identity", role_id)
	mapped.set_meta("char_009_variant_index", index)
	mapped.set_meta("character_variant_seed", "%s:%d" % [role_id, index])
	parent.add_child(mapped)
	var presentation_started := Time.get_ticks_usec()
	# Apply presentation to the imported actor itself. Applying it to the zone
	# parent leaves the routine without its native face driver and makes the
	# visual acceptance gate report a false faceless crowd failure.
	CharacterPresentation.apply_npc(mapped, role_id, false)
	var presentation_ms := float(Time.get_ticks_usec() - presentation_started) / 1000.0
	var driver = CharacterAnimationDriver.new()
	driver.name = "CharacterAnimationDriver"
	mapped.add_child(driver)
	var family := str(mapped.get_meta("character_animation_family", "")).to_lower()
	var clips := {"idle":"Idle", "walk":"Walk", "run":"Run", "hit":"RecieveHit", "death":"Death"}
	if family.contains("cleric"):
		clips["work"] = "Idle_Weapon"
	elif family.contains("rogue"):
		clips["work"] = "Idle"
	elif family.contains("monk"):
		clips["work"] = "Idle"
	driver.configure(mapped, clips)
	load("res://scripts/grounded_feet_modifier.gd").install_npc(mapped, driver)
	driver.set_update_rate_hz(30.0)
	if OS.get_environment("ASHEN_PROFILE_GREYFEN_ACTORS") == "1":
		print("GREYFEN_VISUAL_PROFILE id=%s role=%s asset_ms=%.2f presentation_ms=%.2f driver_ms=%.2f" % [
			role_id, role, load_ms, presentation_ms,
			float(Time.get_ticks_usec() - presentation_started) / 1000.0 - presentation_ms,
		])
	return driver
