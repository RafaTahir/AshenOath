extends RefCounted
var _life: Node
func _init(life: Node) -> void:
	_life = life
func enroll_region() -> void:
	preload("res://scripts/living_cast_stations.gd").ensure_region(_life.host)
	var zone_id: Variant = str(_life.host.current_zone_id)
	var definitions: Dictionary = _life.CastProfile.life_data().get("zones", {}).get(zone_id, {}).duplicate()
	if str(preload("res://scripts/saga_catalog.gd").person_location("saga_maren", _life.host.quests).zone) == zone_id:
		definitions["saga_maren"] = {"profile":"maren"}
	for id: String in definitions:
		var definition: Dictionary = definitions[id]
		var node: Variant = _life.CastProfile.registered_actor(_life.host.zone_root, id)
		if node == null:
			node = _life.host.zone_root.find_child(str(definition.get("actor", id)), true, false) as Node3D
		if not is_instance_valid(node) or not node.visible:
			continue
		var existing: Dictionary = {}
		for candidate: Dictionary in _life.actors:
			if candidate.node == node:
				existing = candidate
				break
		if bool(existing.get("regional", false)):
			continue
		var owned: Variant = str(_life.read_tag(node, "locomotion_owner", ""))
		if owned != "" and owned != "greyfen_life":
			continue
		var body: Variant = node.get_node_or_null("Person") as Node3D
		if body != null and not body.visible:
			continue
		var driver: Variant = node.find_child("CharacterAnimationDriver", true, false)
		if driver == null:
			continue
		var routine: Variant = _life.CastProfile.routine(id, zone_id, _life.host.story_state, _life.host.quests, _life.routine_phase, _life._routine_minutes())
		var path: Array = []
		for point: Vector3 in routine.path:
			path.append(_life.host.validate_walkable_position(point))
		_life._bind_workstation(routine, path)
		var entry: Variant = _life._make_entry(id, node, path, 0.62, driver, true) if existing.is_empty() else existing
		entry["regional"] = true
		entry["routine_zone"] = zone_id
		entry["profile"] = routine
		entry["path"] = path
		entry["pending_routine"] = {}
		for restore_key: String in ["table_restore", "gathering_restore"]:
			if entry.has(restore_key):
				var restoration: Dictionary = entry[restore_key]
				restoration["profile"] = routine.duplicate(true)
				restoration["path"] = path.duplicate()
				restoration["line"] = str(routine.line)
		entry["consequence_line"] = str(routine.line)
		entry["target"] = 0
		var alias: Variant = _life.host.zone_root.find_child(id, true, false) as Node3D
		entry["alias_anchor"] = alias if alias != node and definition.has("actor") else null
		var ambient: Variant = node.find_child("NpcAmbient", true, false)
		if ambient != null:
			ambient.process_mode = Node.PROCESS_MODE_DISABLED
		if existing.is_empty():
			_life.actors.append(entry)
		_life._configure_agent(entry)
		driver.set_distance_suspended(false)
		_life._connect_activity_contact(entry)
	_life.story_dirty = true

func _build_population(first: Variant = 0, count: Variant = -1) -> void:
	var population: Variant = 4
	var definitions: Variant = [
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
	var end: Variant = population if count < 0 else mini(population, first + count)
	for i in range(first, end):
		var definition: Dictionary = definitions[i]
		var actor: Variant = _life.CastProfile.registered_actor(_life.host.zone_root, str(definition.id))
		if actor == null or _life.actors.any(func(entry: Variant) -> Variant: return entry.node == actor):
			continue
		definition.path = _life.host.river_safe_path(definition.path,0.9)
		var driver = actor.find_child("CharacterAnimationDriver", true, false)
		if not is_instance_valid(driver) or not driver.is_valid():
			continue
		var ambient: Variant = actor.find_child("NpcAmbient", true, false)
		if ambient != null:
			ambient.process_mode = Node.PROCESS_MODE_DISABLED
		var entry: Variant = _life._make_entry(str(actor.name), actor, definition.path, definition.speed, driver, true)
		_life.actors.append(entry)
		_life._configure_agent(entry)

func _enroll_named_npcs() -> void:
	var named: Variant = {
		"blacksmith_tor":{"path":[Vector3(9.5,0,3),Vector3(10.4,0,4.7),Vector3(8.7,0,4.4)],"speed":0.55},
		"mira":{"path":[Vector3(-6.8,0,-2.3),Vector3(-8.5,0,-1.2),Vector3(-7.7,0,-4.1)],"speed":0.52},
		"rook":{"path":[Vector3(-7.8,0,8.5),Vector3(-6.2,0,6.8),Vector3(-3.8,0,8.6)],"speed":0.62}
	}
	for id in named:
		var node = _life.host.zone_root.find_child(id,true,false)
		if node == null or _life.actors.any(func(entry: Variant) -> Variant: return str(entry.id) == str(id) or entry.node == node):
			continue
		named[id].path = _life.host.river_safe_path(named[id].path,0.9)
		var ambient = node.find_child("NpcAmbient",true,false)
		if ambient != null: ambient.process_mode = Node.PROCESS_MODE_DISABLED
		var entry: Variant = _life._make_entry(id, node, named[id].path, named[id].speed, node.find_child("CharacterAnimationDriver",true,false), true)
		_life.actors.append(entry)
		_life._configure_agent(entry)
		if entry.driver != null and _life.supports(entry.driver, "set_update_rate_hz"):
			entry.driver.set_update_rate_hz(30.0)

func _make_entry(id: String, node: Node3D, path: Array, speed: float, driver: Node, named: bool) -> Dictionary:
	var profile: Dictionary = _life.ROUTINE_PROFILES.get(id, {"occupation": "villager", "activity": "idle", "activity_seconds": 2.0, "line": "greyfen_keep_working"})
	_life.model.register_actor(id, profile, node.global_position)
	var entry: Variant = {
		"id": id, "node": node, "path": path, "target": 1, "speed": speed,
		"base_path": path.duplicate(), "pending_routine": {},
		"pause": _life.rng.range_float(0.0, 0.25), "driver": driver, "named": named,
		"phase": _life.rng.next_float() * TAU, "base_y": node.position.y, "route": [],
		"route_index": 0, "profile": profile.duplicate(true), "activity_active": false,
		"activity_elapsed": 0.0, "activity_cycles": 0, "life_state": "walking",
		"story_reaction": "baseline", "motion_speed": 0.0, "travel_direction": Vector3.ZERO
	}
	var period: Variant = maxi(1, ceili(1000.0 / _life._simulation_hz()))
	entry["decision_due_msec"] = _life.model.milliseconds() + absi(id.hash()) % period
	_life.write_tag(node, "locomotion_owner", "greyfen_life")
	_life.write_tag(node, "life_ticket", "LIFE-001")
	_life.write_tag(node, "life_routine", id)
	_life.write_tag(node, "life_occupation", str(profile.get("occupation", "villager")))
	_life.write_tag(node, "life_state", "walking")
	_life.write_tag(node, "life_story_reaction", "baseline")
	_life.write_tag(node, "cast_presence_profile", _life.CastProfile.presence_profile(id))
	_life.write_tag(node, "cast_eye_height", _life.Presence.eye_height(node))
	if is_instance_valid(driver):
		var visible: Vector3 = driver.get_visible_forward()
		var local: Variant = node.global_basis.inverse()*visible
		_life.write_tag(node, "cast_forward_axis", local.normalized())
		_life.write_tag(node, "cast_forward_offset", atan2(-local.x,-local.z))
	return entry

func _make_skeletal_villager(parent: Node3D, role_id: String, index: int, scale_value: float) -> Variant:
	var role: Variant = str(_life.CROWD_VISUAL_ROLES[index % _life.CROWD_VISUAL_ROLES.size()])
	var target_scale: Variant = clampf(scale_value, 0.96, 1.04) * (0.99 + 0.01 * float(index % 2))
	if _life.host != null and _life.supports(_life.host, "should_defer_character_role") \
			and bool(_life.host.should_defer_character_role(role, role_id)):
		var marker: Variant = Node3D.new()
		marker.name = "DeferredCharacterVisual_%s" % role_id
		_life.write_tag(marker, "deferred_visual_role", role)
		_life.write_tag(marker, "deferred_visual_category", "characters")
		_life.write_tag(marker, "deferred_visual_actor_id", _life.CROWD_IDENTITIES[index % _life.CROWD_IDENTITIES.size()])
		_life.write_tag(marker, "deferred_visual_scale", Vector3.ONE * target_scale)
		_life.write_tag(parent, "character_variant_seed", "%s:%d" % [role_id, index])
		_life.write_tag(parent, "greyfen_routine_id", role_id)
		parent.add_child(marker)
		return null
	var mapped = _life.asset_helper.spawn_visual_role(role, "characters", "%s:%d" % [role_id, index])
	if mapped == null or mapped.name.ends_with("_placeholder"):
		push_error("Rigged villager asset unavailable for %s" % role_id)
		_life.CharacterAnimationDriver.record_configuration(_life.host.zone_root, role_id, null)
		return null
	mapped.name = "%s_rigged_human" % role_id
	_life.asset_helper.apply_normalized_scale(mapped, target_scale)
	_life.write_tag(mapped, "char_002_body_role", role)
	_life.write_tag(mapped, "char_002_identity", role_id)
	_life.write_tag(mapped, "char_009_identity", role_id)
	_life.write_tag(mapped, "char_009_variant_index", index)
	_life.write_tag(mapped, "character_variant_seed", "%s:%d" % [role_id, index])
	parent.add_child(mapped)
	_life.CharacterPresentation.apply_npc(mapped, role_id, false)
	var driver = _life.CharacterAnimationDriver.new()
	driver.name = "CharacterAnimationDriver"
	mapped.add_child(driver)
	var family: Variant = str(_life.read_tag(mapped, "character_animation_family", "")).to_lower()
	var clips: Variant = {"idle":"Idle", "walk":"Walk", "run":"Run", "hit":"RecieveHit", "death":"Death"}
	if family.contains("cleric"):
		clips["work"] = "Idle_Weapon"
	elif family.contains("rogue"):
		clips["work"] = "Idle"
	elif family.contains("monk"):
		clips["work"] = "Idle"
	if not driver.configure(mapped, clips):
		_life.CharacterAnimationDriver.record_configuration(_life.host.zone_root, role_id, driver)
		return null
	_life.CharacterAnimationDriver.record_configuration(_life.host.zone_root, role_id, driver)
	load("res://scripts/grounded_feet_modifier.gd").install_npc(mapped, driver)
	driver.set_update_rate_hz(30.0)
	return driver
