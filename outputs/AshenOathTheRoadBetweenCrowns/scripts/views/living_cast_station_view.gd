extends RefCounted
var _life: Node
func _init(life: Node) -> void:
	_life = life
func _begin_activity(entry: Dictionary) -> void:
	var node: Node3D = entry.node
	var profile: Dictionary = entry.profile
	if bool(entry.get("regional", false)) or bool(profile.get("scheduled", false)):
		var index: Variant = int(entry.get("arrived_target", 0))
		entry.profile.activity = str(entry.profile.activities[mini(index, entry.profile.activities.size()-1)])
	var anchor: Variant = _life._activity_anchor(entry)
	if anchor != Vector3.ZERO and node.global_position.distance_squared_to(anchor) > 1.44:
		entry.pause = 0.6
		return
	var station: Variant = str(Vector3(snappedf(anchor.x, 0.5), 0, snappedf(anchor.z, 0.5)))
	var occupant: Node3D = _life.station_actor(station)
	if is_instance_valid(occupant) and occupant != node:
		entry.pause = 1.2
		return
	_life.reserve_station(station, node)
	entry.station = station
	entry.activity_active = true
	entry.motion_speed = 0.0
	entry.travel_direction = Vector3.ZERO
	entry.activity_elapsed = 0.0
	entry.activity_cycles = int(entry.activity_cycles) + 1
	entry.life_state = "working:%s" % str(profile.get("activity", "idle"))
	_life.write_tag(node, "life_state", entry.life_state)
	_life._set_activity_pose(entry, true)
	if is_instance_valid(entry.driver):
		entry.driver.set_life_workstation(entry.profile.get("workstation", {}))

func _update_activity(entry: Dictionary, delta: float) -> void:
	var node: Node3D = entry.node
	var profile: Dictionary = entry.profile
	entry.activity_elapsed = float(entry.activity_elapsed) + delta
	var anchor: Variant = _life._activity_anchor(entry)
	var station: Dictionary = entry.profile.get("workstation", {})
	if str(profile.get("activity", "")) == "sleep" and _life._supported_rest(entry):
		anchor = entry.profile.rest_anchor.look
	elif str(profile.get("activity", "")) == "rest":
		var seat: Variant = _life._awake_rest_support(entry)
		if not seat.is_empty() and not _life._player_near_rest_seat(seat):
			anchor = node.global_position + (seat.look - seat.stand)
	if str(profile.get("activity", "")) == str(station.get("activity", "")):
		anchor = station.get("look", station.get("point", anchor))
	if anchor != Vector3.ZERO:
		_life._face(node, anchor, delta)
	_life._set_activity_pose(entry, true)
	if bool(profile.get("hold_activity", false)):
		return
	if float(entry.activity_elapsed) >= float(profile.get("activity_seconds", 2.0)):
		_life._end_activity(entry)
		entry.pause = _life.rng.range_float(0.65, 1.55)

func _end_activity(entry: Dictionary) -> void:
	_life._release_activity(entry)
	entry.activity_active = false
	entry.life_state = "walking"
	entry.route = []
	entry.route_index = 0
	_life.write_tag(entry.node, "life_state", "walking")
	_life._set_activity_pose(entry, false)
	_life._apply_pending_routine(entry)

func _release_activity(entry: Dictionary, release_pose: bool = true) -> void:
	entry.erase("carry_route_scope")
	_life._clear_work_contact_effects(entry.node)
	var was_active: Variant = bool(entry.get("activity_active", false))
	var station: Variant = str(entry.get("station", ""))
	if station != "" and _life.station_actor(station) == entry.node:
		_life.release_station(station)
	entry.station = ""
	entry.activity_active = false
	if not release_pose:
		_life._release_awake_seat(entry)
		return
	if was_active:
		_life._set_activity_pose(entry, false)
	if was_active and entry.driver != null and _life.supports(entry.driver, "clear_life_activity"):
		entry.driver.clear_life_activity()
	if is_instance_valid(entry.driver) and _life.supports(entry.driver, "set_carried_activity"):
		entry.driver.set_carried_activity("")
	if is_instance_valid(entry.driver):
		entry.driver.set_life_workstation({})

func _bind_workstation(profile: Dictionary, path: Array) -> void:
	_life._bind_rest_anchor(profile, path)
	profile["workstation"] = {}
	var definition: Dictionary = profile.get("station", {})
	if definition.is_empty():
		return
	var station: Node3D
	if definition.has("node"):
		station = _life.host.zone_root.find_child(str(definition.node), true, false) as Node3D
		var nearest: Variant = INF
		var names: Array = [str(definition.node)]
		names.append_array(definition.get("alternates", []))
		for name: String in names:
			var candidate: Variant = _life.host.zone_root.find_child(name, true, false) as Node3D
			var stand_marker: Variant = candidate.get_node_or_null("WorkStand") as Node3D if candidate != null else null
			if stand_marker == null: continue
			for point: Vector3 in path:
				var distance: Variant = point.distance_squared_to(stand_marker.global_position)
				if distance < nearest:
					nearest = distance
					station = candidate
	else:
		for candidate in _life.host.zone_root.find_children("RegionalWork", "Node3D", true, false):
			if str(_life.read_tag(candidate, "quest", "")) == str(definition.get("quest", "")):
				station = candidate as Node3D
				break
	if not is_instance_valid(station):
		return
	var standing: Vector3 = station.to_global(definition.get("stand", Vector3.ZERO))
	if bool(definition.get("markers", false)):
		var stand_marker: Variant = station.get_node_or_null("WorkStand") as Marker3D
		if stand_marker == null:
			return
		standing = stand_marker.global_position
	var safe: Vector3 = _life.host.validate_walkable_position(standing)
	if safe.distance_squared_to(standing) > 0.04:
		return
	for index in path.size():
		var activity: Variant = str(profile.activities[index])
		var supported: Array = definition.get("activities", [str(definition.activity)])
		if activity not in supported or path[index].distance_squared_to(standing) > 9.0:
			continue
		var resolved: Variant = definition.duplicate()
		resolved.activity = activity
		resolved.stand = standing
		resolved.node_ref = weakref(station)
		for key: String in ["point", "left", "right"]:
			if bool(definition.get("markers", false)):
				var marker: Variant = station.get_node_or_null({"point":"WorkContact", "left":"WorkLeft", "right":"WorkRight"}[key]) as Marker3D
				if marker == null:
					return
				resolved[key] = marker.global_position
			else:
				resolved[key] = station.to_global(definition[key])
		if definition.has("look"):
			resolved["look"] = station.to_global(definition.look)
		elif station.has_meta("work_identity"):
			var toward: Vector3 = resolved.point - standing
			toward.y = 0.0
			if toward.length_squared() > 0.001:
				resolved["look"] = standing + toward.normalized()
		profile.workstation = resolved
		path[index] = safe

func _set_activity_attention(entry: Dictionary, active: bool) -> void:
	var face = entry.get("face")
	if not is_instance_valid(face):
		return
	var activity: Variant = str(entry.profile.get("activity", "idle"))
	if not active:
		face.set_attention("neutral")
	elif activity == "sleep":
		face.set_attention("sleep" if _life._supported_rest(entry) else "neutral")
	elif activity in ["rest", "idle", "remember", "sit"]:
		face.set_attention("neutral")
	elif activity in ["watch", "lookout"] and entry.profile.get("workstation", {}).is_empty():
		face.set_attention("neutral")
	else:
		var station: Dictionary = entry.profile.get("workstation", {})
		var target: Vector3 = station.get("point", entry.node.global_position + entry.driver.get_visible_forward() * 0.5 + Vector3.UP * 1.0)
		if is_instance_valid(entry.driver.life_modifier) and is_instance_valid(entry.driver.life_modifier.tool) and station.is_empty():
			target = entry.driver.life_modifier.tool.global_position
		face.set_attention("point", null, target)

func _connect_activity_contact(entry: Dictionary) -> void:
	if not is_instance_valid(entry.driver) or not is_instance_valid(entry.node):
		return
	if _life.supports(entry.driver, "set_story_workstation_owner"): entry.driver.set_story_workstation_owner(_life)
	var callback: Callable = entry.get("contact_callback", Callable())
	var previous_driver: WeakRef = entry.get("contact_driver")
	var previous_actor: WeakRef = entry.get("contact_actor")
	var old_driver: Node = previous_driver.get_ref() if previous_driver != null else null
	if not callback.is_valid() or old_driver != entry.driver or previous_actor == null or previous_actor.get_ref() != entry.node:
		if is_instance_valid(old_driver) and callback.is_valid() and old_driver.activity_contact.is_connected(callback):
			old_driver.activity_contact.disconnect(callback)
		var actor_ref: WeakRef = weakref(entry.node)
		callback = _life._on_activity_contact.bind(actor_ref)
		entry.contact_callback = callback
		entry.contact_driver = weakref(entry.driver)
		entry.contact_actor = actor_ref
	if not entry.driver.activity_contact.is_connected(callback):
		entry.driver.activity_contact.connect(callback)

func story_workstation_for(driver: Node, identity: String) -> Dictionary:
	if identity != "vale" or not is_instance_valid(_life.host) or _life.get_parent() != _life.host.zone_root: return {}
	var actor: Node3D
	for entry: Dictionary in _life.actors:
		if entry.driver == driver and _life.CastProfile.same_person(str(entry.id), identity):
			actor = entry.node
			break
	if not is_instance_valid(actor) or not _life.host.zone_root.is_ancestor_of(actor): return {}
	var result: Dictionary = {}
	var nearest: Variant = INF
	for station: Node3D in _life.host.zone_root.find_children("LifeWork_*", "Node3D", true, false):
		if str(_life.read_tag(station, "work_identity", "")) != identity: continue
		var prop_ref: WeakRef = _life.read_tag(station, "task_prop") if station.has_meta("task_prop") else null
		var prop: Variant = prop_ref.get_ref() as Node3D if prop_ref != null else null
		if prop == null or not prop.is_visible_in_tree() or str(_life.read_tag(prop, "actor_identity", "")) != identity \
				or not bool(_life.read_tag(prop, "stationary_supported_prop", false)) or not bool(_life.read_tag(prop, "grip_geometry_verified", false)): continue
		var stand: Variant = station.get_node_or_null("WorkStand") as Marker3D
		var contact: Variant = station.get_node_or_null("WorkContact") as Marker3D
		if stand == null or contact == null or not stand.global_position.is_finite() or not contact.global_position.is_finite(): continue
		var station_key: Variant = str(Vector3(snappedf(stand.global_position.x,0.5),0,snappedf(stand.global_position.z,0.5)))
		var occupant: Node3D = _life.station_actor(station_key)
		if is_instance_valid(occupant) and occupant != actor: continue
		if _life.host.validate_walkable_position(stand.global_position).distance_squared_to(stand.global_position) > 0.04: continue
		var distance: Variant = actor.global_position.distance_squared_to(stand.global_position)
		if distance >= nearest: continue
		nearest = distance
		result = {"node_ref":weakref(station), "prop_ref":weakref(prop), "stand":stand.global_position, "point":contact.global_position, "reservation":station_key, "identity":identity}
	return result

func _set_activity_pose(entry: Dictionary, active: bool) -> void:
	var driver = entry.driver
	if driver == null:
		return
	var activity: Variant = str(entry.profile.get("activity", "idle"))
	if activity == "sleep" and not _life._supported_rest(entry):
		activity = "rest"
	if _life.supports(driver, "set_life_activity"):
		if active: driver.set_life_workstation(entry.profile.get("workstation", {}))
		driver.set_life_activity(activity if active else "")
		if _life.supports(driver, "set_life_rest_anchor"):
			var rest: Dictionary = entry.profile.get("rest_anchor", {}) if active and activity == "sleep" else {}
			if active and activity == "rest" and not bool(driver.dead) and not bool(driver.distance_suspended) \
					and not driver.has_active_action() and not bool(driver.story_dialogue_active):
				rest = _life._awake_rest_support(entry).duplicate()
				if not rest.is_empty():
					var outward: Vector3 = rest.look - rest.stand
					var forward: Vector3 = driver.get_visible_forward()
					rest["awake_rest_owner"] = _life.get_instance_id()
					rest["seat_requested"] = not _life._player_near_rest_seat(rest) and float(entry.get("greeting_remaining", 0.0)) <= 0.0 \
						and forward.dot(outward.normalized()) >= 0.98
			driver.set_life_rest_anchor(rest)
		driver.set_activity_prop(str(entry.profile.get("prop", "")) if active else "")
		if active:
			driver.set_life_workstation(entry.profile.get("workstation", {}))
		_life._set_activity_attention(entry, active)
		return
	if active:
		if activity == "notice_board" or activity == "lookout" or bool(entry.get("quiet_after_report", false)):
			if _life.supports(driver, "set_working"):
				driver.set_working(false)
			if _life.supports(driver, "set_dialogue_pose"):
				driver.set_dialogue_pose(true)
		else:
			if _life.supports(driver, "set_dialogue_pose"):
				driver.set_dialogue_pose(false)
			if _life.supports(driver, "set_working"):
				driver.set_working(true)
	else:
		if _life.supports(driver, "set_working"):
			driver.set_working(false)
		if _life.supports(driver, "set_dialogue_pose"):
			driver.set_dialogue_pose(false)

func _activity_anchor(entry: Dictionary) -> Vector3:
	if (bool(entry.get("regional", false)) or bool(entry.profile.get("scheduled", false))) and not entry.path.is_empty():
		return entry.path[clampi(int(entry.get("arrived_target", 0)), 0, entry.path.size()-1)]
	if bool(entry.named) and not entry.path.is_empty():
		return entry.path.back()
	var activity: Variant = str(entry.profile.get("activity", ""))
	if activity == "notice_board" and _life.host != null and is_instance_valid(_life.host.zone_root):
		var board: Variant = _life.host.zone_root.find_child("notice_board", true, false) as Node3D
		if board != null:
			return board.global_position + Vector3(0, 0, -1.2)
	var anchors: Variant = {
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
