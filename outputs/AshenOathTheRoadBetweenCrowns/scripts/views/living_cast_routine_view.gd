extends RefCounted
var _life: Node
func _init(life: Node) -> void:
	_life = life
func _apply_pending_routine(entry: Dictionary) -> void:
	var pending: Dictionary = entry.get("pending_routine", {})
	if pending.is_empty(): return
	if entry.has("table_restore") and not bool(pending.get("table_visit",false)):
		entry.table_restore = pending.duplicate(true)
		entry.table_restore["spatial_override"] = true
		entry.pending_routine = {}
		return
	if _life.gathering_staged and entry.has("gathering_restore") and not bool(pending.get("gathering", false)):
		entry.gathering_restore = pending.duplicate(true)
		entry.pending_routine = {}
		return
	entry.pending_routine = {}
	if not bool(pending.get("table_visit", false)):
		entry.erase("table_approach")
	entry.profile = pending.profile
	entry.consequence_line = str(pending.get("line", ""))
	_life.write_tag(entry.node, "life_occupation", str(entry.profile.get("occupation", "villager")))
	if bool(entry.named) and not bool(entry.get("regional", false)) and not bool(pending.get("spatial_override",false)) and not bool(pending.get("gathering",false)): return
	var next_path: Array = pending.path
	if next_path == entry.path: return
	entry.path = next_path.duplicate() if bool(entry.get("regional", false)) else _life.host.river_safe_path(next_path, 0.9)
	entry.target = 0
	if not bool(entry.get("regional", false)):
		_life._precompute_routes(entry)
	var destination: Vector3 = _life.host.validate_walkable_position(entry.path[0])
	entry.route = _life._routine_route(entry, destination)
	entry.route_index = 1 if entry.route.size() > 1 else 0

func _routine_route(entry: Dictionary, destination: Vector3) -> Array[Vector3]:
	var start: Vector3 = entry.node.global_position
	if _life.spatial_service == null:
		return [destination]
	if not entry.has("table_approach"):
		return _life.spatial_service.build_route(start, destination, 0.72)
	var corner: Vector3 = entry.table_approach
	var first: Array[Vector3] = _life.spatial_service.build_route(start, corner, 0.72)
	var last: Array[Vector3] = _life.spatial_service.build_route(corner, destination, 0.72)
	if first.is_empty() or last.is_empty():
		return []
	first.append_array(last.slice(1))
	return _fit_table_route(first)

func _fit_table_route(route: Array[Vector3]) -> Array[Vector3]:
	var spatial: Node = _life.spatial_service
	var fitted: Array[Vector3] = [route[0]]
	const CLEARANCE := 0.58
	for point: Vector3 in route.slice(1):
		var start := fitted.back() as Vector3
		if not spatial.validate_runtime_segment(start, point, CLEARANCE):
			var bank: int = spatial.bank_for(start)
			if spatial.bank_for(point) != bank:
				return []
			var midpoint := (start + point) * 0.5
			var side := (point - start).cross(Vector3.UP).normalized()
			var bend := Vector3.INF
			for offset: float in [-1.4, 1.4, -2.4, 2.4]:
				var candidate := midpoint + side * offset
				if spatial.bank_for(candidate) == bank and spatial.is_walkable_position(candidate, CLEARANCE, bank) \
						and spatial.validate_runtime_segment(start, candidate, CLEARANCE) \
						and spatial.validate_runtime_segment(candidate, point, CLEARANCE):
					bend = candidate
					break
			if bend == Vector3.INF:
				return []
			fitted.append(bend)
		fitted.append(point)
	return fitted

func _sync_story_state(force: bool) -> void:
	if _life.host == null:
		return
	_life.story_dirty = false
	var state = _life.host.get("story_state")
	var report: Variant = str(state.get_flag("evidence_report", "")) if state != null and _life.supports(state, "get_flag") else ""
	_life.model.set_chapter(report, _life.routine_phase)
	var bell: Variant = bool(state.get_flag("cemetery_bell_rung", false)) if state != null and _life.supports(state, "get_flag") else false
	var weather: Variant = str(_life.host.day_night.current_weather) if is_instance_valid(_life.host.day_night) else "clear"
	var signature: Variant = str([report, bell, _life.ConsequenceRoutines.signature(state), _life.routine_phase, weather, _life.cast_revision, floori(_life._routine_minutes())])
	if not force and signature == _life.story_signature:
		return
	_life.story_signature = signature
	var reaction: Variant = "baseline"
	if report != "":
		reaction = "reported_%s" % report
	if bell:
		reaction += "_bell_rung"
	for entry in _life.actors:
		if bool(entry.get("regional", false)):
			var routine: Variant = _life.CastProfile.routine(str(entry.id), str(entry.routine_zone), state, _life.host.quests, _life.routine_phase, _life._routine_minutes())
			if routine.is_empty():
				continue
			routine = _life.RoutineDirector.weather_routine(routine,entry,_life.host,weather)
			var previous: Dictionary = entry.pending_routine.get("profile", entry.profile)
			if str(routine.revision) == str(previous.get("revision", "")):
				continue
			var path: Array = []
			for point: Vector3 in routine.path:
				path.append(_life.host.validate_walkable_position(point))
			_life._bind_workstation(routine, path)
			entry.pending_routine = {"profile":routine, "path":path, "line":routine.line}
			continue
		entry.story_reaction = reaction
		entry.quiet_after_report = (report == "public" and str(entry.id) in ["forge_helper", "blacksmith_tor"]) \
			or (report == "private" and str(entry.id) == "shrine_pilgrim")
		var base_profile: Dictionary = _life.ROUTINE_PROFILES.get(str(entry.id), entry.profile)
		var next_profile: Variant = base_profile.duplicate(true)
		if report != "":
			next_profile.activity_seconds = float(base_profile.get("activity_seconds", 2.0)) * 1.8
		var outcome: Variant = _life.ConsequenceRoutines.for_actor(str(entry.id), state)
		for key in ["activity", "occupation", "activity_seconds"]:
			if outcome.has(key): next_profile[key] = outcome[key]
		next_profile["revision"] = str([reaction, _life.cast_revision])
		var schedule: Variant = _life.model.existing_route(_life.CastProfile.life_data(), str(entry.id), next_profile, outcome.get("path", entry.base_path), _life._routine_minutes())
		schedule = _life.RoutineDirector.weather_routine(schedule,entry,_life.host,weather)
		var previous: Dictionary = entry.pending_routine.get("profile", entry.profile)
		if str(schedule.get("revision", "")) != str(previous.get("revision", "")):
			entry.pending_routine = {"profile":schedule, "path":schedule.get("path", entry.base_path).duplicate(), "line":outcome.get("line", ""), "spatial_override":true}
		var node: Node3D = entry.node
		if is_instance_valid(node):
			_life.write_tag(node, "life_story_reaction", reaction)
			if bool(entry.get("activity_active", false)):
				_life._set_activity_pose(entry, true)

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
	agent.process_mode = Node.PROCESS_MODE_DISABLED
	var map_rid: RID = _life.spatial_service.get_navigation_map() if _life.spatial_service != null else RID()
	if map_rid.is_valid():
		agent.set_navigation_map(map_rid)
	entry.route = []
	entry.route_index = 0

func _precompute_routes(entry: Dictionary) -> void:
	if _life.spatial_service == null or entry.path.is_empty():
		return
	var routes: Dictionary = {}
	for destination_index in range(entry.path.size()):
		var source_index: Variant = wrapi(destination_index - 1, 0, entry.path.size())
		var source: Vector3 = _life.host.validate_walkable_position(entry.path[source_index])
		var destination: Vector3 = _life.host.validate_walkable_position(entry.path[destination_index])
		routes[destination_index] = _life.spatial_service.build_route(source, destination, 0.72)
	entry.routes = routes

func _set_agent_target(entry: Dictionary) -> void:
	pass

func _c11_carry_scope_live(entry: Dictionary) -> bool:
	return entry.route.size() == 2 and int(entry.route_index) == 1 and int(entry.target) == 1 \
		and entry.pending_routine.is_empty() and not entry.has("table_restore") and not entry.has("gathering_restore") \
		and float(entry.get("pause", 0.0)) <= 0.0 and float(entry.get("greeting_remaining", 0.0)) <= 0.0 \
		and float(entry.get("reaction_time", 0.0)) <= 0.0

func _reviewed_c11_carry_leg(entry: Dictionary) -> String:
	if str(entry.id) != "saga_nessa" or not bool(entry.get("regional", false)) or str(entry.get("routine_zone", "")) != "greyfen" \
			or int(entry.get("arrived_target", -1)) != 0 or not is_equal_approx(float(entry.speed), 0.62) or not _life._c11_carry_scope_live(entry):
		return ""
	var profile: Dictionary = entry.profile
	if not bool(profile.get("scheduled", false)) or not bool(profile.get("carry_in_transit", false)) \
			or str(profile.get("intent_key", "")) != "baker_day:4" or str(profile.get("intent", "")) != "carry" \
			or str(profile.get("activity", "")) != "carry" or str(profile.get("prop", "")) != "supply" \
			or profile.get("activities", []) != ["carry", "carry"] or entry.path.size() != 2 or profile.get("path", []).size() != 2:
		return ""
	var authored: Dictionary = _life.CastProfile.life_data().get("zones", {}).get("greyfen", {}).get("saga_nessa", {})
	var labels: Variant = ["work", "errand"]
	var tolerance: Variant = _life.ARRIVAL_DISTANCE + 0.015
	for index: int in 2:
		var raw: Array = authored.get(labels[index], [])
		if raw.size() != 3: return ""
		var original: Variant = Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
		var resolved: Vector3 = profile.path[index]
		var validated: Vector3 = entry.path[index]
		var routed: Vector3 = entry.route[index]
		if resolved != original or routed.distance_squared_to(validated) > tolerance * tolerance: return ""
	return "greyfen:saga_nessa:baker_day:4:work_to_errand"

func _set_motion(entry: Dictionary, speed: float, direction: Vector3 = Vector3.ZERO) -> void:
	var driver = entry.driver
	if driver != null and _life.supports(driver, "set_locomotion"):
		if _life.supports(driver, "set_working"):
			driver.set_working(false)
		if _life.supports(driver, "set_dialogue_pose"):
			driver.set_dialogue_pose(false)
		var player_nearby: bool = is_instance_valid(_life.player) and entry.node.global_position.distance_to(_life.player.global_position) < 2.1
		if speed <= 0.01 and str(entry.id) == "forge_helper" and not bool(entry.get("quiet_after_report", false)) and not player_nearby and _life.supports(driver, "set_working"):
			driver.set_working(true)
		else:
			if _life.supports(driver, "set_working"):
				driver.set_working(false)
			if _life.supports(driver, "set_locomotion_motion"):
				driver.set_locomotion_motion(direction * speed, true)
			else:
				driver.set_locomotion(clampf(speed / 2.0,0.0,0.70),direction,true)
		if bool(entry.profile.get("scheduled", false)):
			var carrying: Variant = speed > 0.05 and bool(entry.profile.get("carry_in_transit", false))
			driver.set_carried_activity("carry" if carrying else "")
			if carrying and entry.has("carry_route_scope") and _life.supports(driver, "set_carried_activity_scope"):
				if _life._c11_carry_scope_live(entry):
					driver.set_carried_activity_scope(str(entry.carry_route_scope))
				else:
					entry.erase("carry_route_scope")
			driver.set_activity_prop(str(entry.profile.get("prop", "")) if carrying else "")
		elif bool(entry.get("regional", false)):
			driver.set_carried_activity("carry" if speed > 0.05 and int(entry.target) == 1 and _life.routine_phase != "night" else "")
	entry.phase = float(entry.phase) + _life.MotionStep.simulation_delta(_life.get_physics_process_delta_time()) * (0.8 + speed * 1.7)

func _bind_rest_anchor(profile: Dictionary, path: Array) -> void:
	profile["rest_anchor"] = {}
	var sleeping: Variant = bool(profile.get("sleeping", false))
	var activities: Array = profile.get("activities", [str(profile.get("activity", ""))])
	var rest_index: Variant = 0 if sleeping else activities.find("rest")
	if rest_index < 0 or rest_index >= path.size():
		return
	var identity: Variant = str(profile.get("identity", ""))
	for anchor: Marker3D in _life.host.zone_root.find_children("LifeRest_*", "Marker3D", true, false):
		var owner_identity: Variant = str(_life.read_tag(anchor, "rest_identity", ""))
		if owner_identity.is_empty() and not sleeping or not owner_identity.is_empty() and owner_identity != identity:
			continue
		if not bool(_life.read_tag(anchor, "rest_supported", false)) or str(_life.read_tag(anchor, "rest_kind", "")) != "seated":
			continue
		var stand: Vector3 = anchor.to_global(_life.read_tag(anchor, "stand_offset", Vector3.ZERO))
		var seat: Vector3 = anchor.global_position
		var seat_height: Variant = seat.y - stand.y
		if seat_height < 0.35 or seat_height > 0.65 or stand.distance_squared_to(path[rest_index]) > 1.0:
			continue
		if _life.host.validate_walkable_position(stand).distance_squared_to(stand) > 0.04:
			continue
		profile.rest_anchor = {"node":weakref(anchor), "stand":stand, "seat":seat, "kind":"seated", "look":stand + anchor.global_basis.z}
		path[rest_index] = stand
		return

func _supported_rest(entry: Dictionary) -> bool:
	var rest: Dictionary = entry.profile.get("rest_anchor", {})
	var reference: WeakRef = rest.get("node")
	if _life._player_near_rest_seat(rest):
		return false
	return reference != null and is_instance_valid(reference.get_ref()) and str(rest.get("kind", "")) == "seated" \
		and entry.node.global_position.distance_squared_to(rest.get("stand", Vector3.INF)) <= 0.16

func _player_near_rest_seat(rest: Dictionary) -> bool:
	return is_instance_valid(_life.player) and not rest.is_empty() and _life.player.global_position.distance_squared_to(rest.get("seat", Vector3.INF)) < 1.96

func _awake_rest_support(entry: Dictionary) -> Dictionary:
	var node: Node3D = entry.node
	var profile: Dictionary = entry.profile
	if str(profile.get("activity", "")) != "rest" or bool(profile.get("sleeping", false)) \
			or not bool(entry.get("activity_active", false)) or _life.station_actor(str(entry.get("station", ""))) != node:
		return {}
	var rest: Dictionary = profile.get("rest_anchor", {})
	var reference: WeakRef = rest.get("node")
	var marker: Variant = reference.get_ref() as Marker3D if reference != null else null
	if not is_instance_valid(marker) or marker.is_queued_for_deletion() or not marker.is_visible_in_tree() \
			or not bool(_life.read_tag(marker, "rest_supported", false)) or str(rest.get("kind", "")) != "seated" \
			or str(_life.read_tag(marker, "rest_identity", "")) != str(profile.get("identity", "")) \
			or node.global_position.distance_squared_to(rest.get("stand", Vector3.INF)) > 0.16:
		return {}
	return rest

func _release_awake_seat(entry: Dictionary) -> void:
	var driver: Node = entry.get("driver")
	if not is_instance_valid(driver) or not _life.supports(driver, "set_life_rest_anchor"):
		return
	var modifier: Node = driver.get("life_modifier")
	if is_instance_valid(modifier) and int(modifier.rest_anchor.get("awake_rest_owner", 0)) == _life.get_instance_id():
		driver.set_life_rest_anchor({})
