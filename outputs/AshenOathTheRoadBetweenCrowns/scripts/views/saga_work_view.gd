extends RefCounted
var _activities: Node3D
func _init(activities: Node3D) -> void:
	_activities = activities
func _begin_work(id: String, step: Array, area: Node3D) -> void:
	if not _activities._within_reach(area) or not _activities.host.player.can_control or _activities.host.player.transition_locked:
		return
	_activities._cancel_work()
	_activities._work = {"id":id, "step":step, "area":weakref(area), "start":_activities.host.player.global_position, "part":_activities._part(id, str(step[0]))}
	_activities._work.performance = _activities.Catalog.work_performance(id, step, int(_activities._work.part))
	match id + ":" + str(step[0]):
		"side_escort_01:steady_arrival":
			if int(_activities._work.part) > 0:
				_activities._work.surface_prop = "relief_cart"
		"side_escort_04:coil_return_rope":
			if int(_activities._work.part) == 0:
				_activities._work.surface_prop = "rope_drying_post"
		"saga_roa_q02:set_rescue_terms":
			if int(_activities._work.part) == 0:
				_activities._work.surface_prop = "mooring_warning_board"
	_activities._elapsed = 0.0
	_activities.host.player.face_target(area.global_position)
	_activities.host.player._request_equipment(_activities.host.player.weapon_mode, _activities.host.player.get_selected_blade_id(), false)
	_activities.host.hud.toast(str(area.prompt))

func _cancel_work() -> void:
	if not _activities._work.is_empty() and not bool(_activities._work.get("escort", false)):
		_activities.WorkPresentation.sync_progress(_activities._assemblies.get(str(_activities._work.id)), _activities.host, str(_activities._work.id))
	if not _activities._work.is_empty() and not bool(_activities._work.get("escort", false)) and _activities.host != null and is_instance_valid(_activities.host.player):
		_activities.Presence.release(_activities.host.player, "work", _activities.get_instance_id())
		if _activities.host.player.animation_driver != null:
			_activities.host.player.animation_driver.clear_life_activity()
	if bool(_activities._work.get("escort", false)):
		for driver: Node in _activities._escort_drivers:
			if is_instance_valid(driver):
				driver.set_locomotion_motion(Vector3.ZERO, true)
	_activities._work.clear()
	_activities._elapsed = 0.0

func _sync_carried_work() -> void:
	var key: Variant = ""
	var label: Variant = ""
	for id: String in _activities.Catalog.QUESTS:
		if _activities._quest_zone(id) != _activities.zone or not _activities.host.quests.is_active(id):
			continue
		var step: Variant = _activities._step(id)
		if step.is_empty() or str(step[3]) != "carry":
			continue
		var part: Variant = _activities._part(id, str(step[0]))
		if part % 2 == 1 and part < step[4].size():
			key = id + ":" + str(step[0]) + ":" + str(part)
			label = str(step[4][part - 1])
			if int(_activities.host.story_state.get_flag(id + ":" + str(step[0]) + ":bundle_pickup", -1)) == part:
				label = str(_activities.Catalog.BUNDLED_CARRIES.get(id + ":" + str(step[0]), label))
			break
	if key == _activities._carried_key:
		return
	if is_instance_valid(_activities._carried):
		_activities._carried.queue_free()
	_activities._carried = null
	_activities._carried_key = key
	if key != "":
		_activities._carried = _activities.WorkPresentation.carried_item(_activities.host, label)

func _restore_escort(id: String, step: Array, area: Node3D) -> void:
	if _activities._escort != null:
		return
	if id == "side_escort_04":
		_activities._escort = _activities.CastProfile.registered_actor(_activities.host.zone_root, "saga_maren")
		if _activities._escort == null:
			_activities._escort = _activities.points.get("saga_maren")
		if not is_instance_valid(_activities._escort):
			return
		_activities.write_tag(_activities._escort, "locomotion_owner", "relief_escort")
		var leader: Variant = _activities._escort.find_child("CharacterAnimationDriver", true, false)
		if leader != null:
			_activities._escort_drivers.append(leader)
		var position: Variant = _activities.host.story_state.get_flag(id + ":escort_position", null)
		if position is Array and position.size() == 3:
			var restored: Variant = Vector3(float(position[0]), float(position[1]), float(position[2]))
			_activities._escort.position = _activities.host.spatial_service.validate_position(restored, 0.65) if _activities.host.spatial_service != null else restored
		for index in range(2):
			var actor_id: Variant = "farmer_toma" if index == 0 else "widow_elna"
			var body: Variant = _activities._escort_person(actor_id, _activities._escort.position + Vector3(0, 0, 0.85 + float(index) * 0.85))
			if body == null:
				continue
			var saved_travelers: Variant = _activities.host.story_state.get_flag(id + ":travelers", [])
			if saved_travelers is Array and index < saved_travelers.size() and saved_travelers[index] is Array and saved_travelers[index].size() == 3:
				var row: Array = saved_travelers[index]
				body.global_position = Vector3(float(row[0]), float(row[1]), float(row[2]))
				if _activities.host.spatial_service != null:
					body.position = _activities.host.zone_root.to_global(_activities.host.spatial_service.validate_position(_activities.host.zone_root.to_local(body.global_position), 0.5))
			_activities._relief_travelers.append(body)
			var driver: Variant = body.find_child("CharacterAnimationDriver", true, false)
			if driver != null:
				_activities._escort_drivers.append(driver)
		var saved_trail: Variant = _activities.host.story_state.get_flag(id + ":trail", [])
		if saved_trail is Array:
			for row: Variant in saved_trail:
				if row is Array and row.size() == 3:
					_activities._escort_trail.append(Vector3(float(row[0]), float(row[1]), float(row[2])))
		if _activities._escort_trail.is_empty():
			for index in range(_activities._relief_travelers.size() - 1, -1, -1):
				_activities._escort_trail.append(_activities._relief_travelers[index].global_position)
			_activities._escort_trail.append(_activities._escort.global_position)
		return
	_activities._escort = _activities._escort_person("farmer_toma", area.position + Vector3(0.5, 0, 0))
	if _activities._escort == null:
		return
	var saved: Variant = _activities.host.story_state.get_flag(id + ":escort_position", null)
	if saved is Array and saved.size() == 3:
		_activities._escort.position = _activities.host.spatial_service.validate_position(Vector3(float(saved[0]), float(saved[1]), float(saved[2])), 0.65)
	var leader: Variant = _activities._escort.find_child("CharacterAnimationDriver", true, false)
	if leader != null: _activities._escort_drivers.append(leader)
	if id == "saga_gre_q05":
		var follower: Variant = _activities._escort_person("rook", _activities._escort.position + Vector3(0.6, 0, 0.9))
		if follower != null:
			_activities._relief_travelers.append(follower)
			var driver: Variant = follower.find_child("CharacterAnimationDriver", true, false)
			if driver != null: _activities._escort_drivers.append(driver)
	for index in range(_activities._relief_travelers.size() - 1, -1, -1):
		_activities._escort_trail.append(_activities._relief_travelers[index].global_position)
	_activities._escort_trail.append(_activities._escort.global_position)

func _escort_person(actor_id: String, position: Vector3) -> Node3D:
	var actor: Variant = _activities.CastProfile.registered_actor(_activities.host.zone_root, actor_id)
	if actor == null:
		actor = _activities.host._make_named_interactable(actor_id, "dialogue", "Speak with " + _activities.CastProfile.display_name(actor_id), position, Color.WHITE)
	if actor != null:
		_activities.write_tag(actor, "locomotion_owner", "relief_escort")
	return actor

func _release_escort_ownership() -> void:
	var members: Array[Node3D] = _activities._relief_travelers.duplicate()
	if is_instance_valid(_activities._escort): members.append(_activities._escort)
	for member: Node3D in members:
		if is_instance_valid(member) and str(_activities.read_tag(member, "locomotion_owner", "")) == "relief_escort":
			member.remove_meta("locomotion_owner")

func _start_escort(id: String, step: Array, area: Node3D) -> void:
	_activities._restore_escort(id, step, area)
	if not is_instance_valid(_activities._escort):
		return
	if id == "side_escort_04" and _activities._relief_travelers.size() != 2:
		_activities.host.hud.toast("The crossing cannot start until the complete relief group is available.")
		return
	var site: Variant = str(step[4][1])
	if id == "side_escort_04":
		site = str(step[4].back())
	if id == "saga_gre_q05":
		site = "kitchen" if str(_activities.host.story_state.get_flag(id + "_outcome", "")) == "store" else "courtyard"
	var destination: Variant = _activities._site_position(site, id + "_escort_destination")
	if id == "side_escort_04":
		_activities._escort_path.clear()
		_activities._escort_legs.clear()
		var start: Variant = _activities._escort.position
		var completed_leg: Variant = mini(int(_activities.host.story_state.get_flag(id + ":escort_leg", 1)), step[4].size() - 1)
		for index in range(completed_leg, step[4].size()):
			var end: Variant = _activities._site_position(str(step[4][index]), id + "_escort_leg_" + str(index))
			var leg: Array[Vector3] = _activities.host.spatial_service.build_route(start, end, 0.65) if _activities.host.spatial_service != null else []
			if leg.is_empty():
				_activities._escort_path.clear()
				break
			_activities._escort_path.append_array(leg)
			_activities._escort_legs[_activities._escort_path.size() - 1] = index + 1
			start = end
		if _activities._escort_path.is_empty() and int(_activities.host.story_state.get_flag(id + ":escort_leg", 0)) >= step[4].size() and _activities._escort.position.distance_to(destination) < 3.0:
			_activities._complete_step(id, step)
			return
	else:
		_activities._escort_path = _activities.host.spatial_service.build_route(_activities._escort.position, destination, 0.65) if _activities.host.spatial_service != null else []
	if _activities._escort_path.is_empty():
		_activities.host.hud.toast("The travelers wait safely. Clear the short path before asking them to follow.")
		return
	_activities._escort_index = 0
	_activities._work = {"id":id, "step":step, "escort":true}
	_activities._escort_hint = ""
	_activities.host.story_state.set_flag(id + ":escort_started", true)
	_activities.host.hud.toast("Stay nearby. The travelers walk and wait if you leave them behind.")

func _tick_walk_steps() -> void:
	if not _activities.host.player.can_control or _activities.host.player.transition_locked or _activities.host._story_has_active_combat():
		return
	var id: Variant = "side_escort_02"
	if _activities.zone != "wychwood" or not _activities.host.quests.is_active(id):
		return
	var step: Variant = _activities._step(id)
	if step.is_empty() or str(step[3]) != "walk":
		return
	var sites: Variant = _activities._walk_sites(id, step)
	var part: Variant = _activities._part(id, str(step[0]))
	var target: Node3D = _activities.points.get(id + ":" + str(step[0]) + ":walk")
	if part < sites.size() and is_instance_valid(target) and target.is_visible_in_tree() and _activities.host.player.global_position.distance_to(target.global_position) <= 2.0:
		_activities._advance_part(id, step)

func _tick_return_steps() -> void:
	for id: String in ["saga_har_q03", "saga_roa_q04"]:
		if not _activities.host.quests.is_active(id) or str(_activities.Catalog.QUESTS[id].zone) != _activities.zone:
			continue
		var step: Variant = _activities._step(id)
		if step.is_empty() or str(step[3]) not in ["return", "signal"]:
			continue
		var key: Variant = id + ":left_work_area"
		var anchor: Vector3 = _activities.Catalog.SITES[_activities.zone][step[2]]
		var far_enough: bool = _activities.host.player.global_position.distance_to(anchor) >= 7.0
		if str(step[3]) == "signal":
			far_enough = _activities._flag(id + ":signal_mode_set") and _activities.host.player.global_position.distance_to(_activities.Catalog.SITES[_activities.zone].line) < 2.0
		if far_enough:
			if not _activities._flag(key):
				_activities.host.story_state.set_flag(key, true)
				_activities._commit()
		elif _activities._flag(key) and _activities.host.player.global_position.distance_to(anchor) < 2.8 and str(step[3]) == "signal":
			_activities._complete_step(id, step)

func _tick_escort(delta: float) -> void:
	if not is_instance_valid(_activities._escort) or _activities.host._story_has_active_combat() or not _activities.host.player.can_control or _activities.host.player.transition_locked or _activities.host.zone_transition_pending or _activities._escort.global_position.distance_to(_activities.host.player.global_position) > 6.0:
		for driver: Node in _activities._escort_drivers:
			if is_instance_valid(driver):
				driver.set_locomotion_motion(Vector3.ZERO, true)
		return
	if _activities._escort_index >= _activities._escort_path.size():
		var id: Variant = str(_activities._work.id)
		var step: Array = _activities._work.step
		_activities._work.clear()
		_activities._complete_step(id, step)
		for driver: Node in _activities._escort_drivers:
			if is_instance_valid(driver):
				driver.set_locomotion_motion(Vector3.ZERO, true)
		_activities._release_escort_ownership()
		return
	var target: Variant = _activities._escort_path[_activities._escort_index]
	var offset: Variant = target - _activities._escort.position
	offset.y = 0
	if offset.length() < 0.15:
		if str(_activities._work.id) == "side_escort_04" and _activities._escort_legs.has(_activities._escort_index):
			_activities.host.story_state.flags["side_escort_04:escort_leg"] = _activities._escort_legs[_activities._escort_index]
			_activities._persist()
		_activities._escort_index += 1
		return
	if str(_activities._work.id) == "side_escort_04":
		var rear: Variant = str(_activities.host.story_state.get_flag("side_escort_04_outcome", "")) == "rear"
		var reference: Vector3 = _activities._relief_travelers.back().global_position if rear and not _activities._relief_travelers.is_empty() else _activities._escort.global_position
		var relative: Vector3 = _activities.host.player.global_position - reference
		var heading: float = relative.dot(offset.normalized())
		if (rear and heading > -0.65) or (not rear and heading < 0.65):
			for driver: Node in _activities._escort_drivers:
				if is_instance_valid(driver): driver.set_locomotion_motion(Vector3.ZERO, true)
			var hint: Variant = "Take your place behind the last traveler." if rear else "Check the approach ahead of Nera."
			if _activities._escort_hint != hint:
				_activities._escort_hint = hint
				_activities.host.hud.toast(hint)
			return
		_activities._escort_hint = ""
	var destination: Variant = _activities._escort.position + offset.normalized() * minf(delta * 1.35, offset.length())
	if _activities.host.spatial_service != null and not _activities.host.spatial_service.validate_runtime_segment(_activities._escort.position, destination, 0.5, _activities.host.player):
		return
	_activities._escort.position = destination
	_activities._escort.rotation.y = atan2(-offset.x, -offset.z)
	if not _activities._relief_travelers.is_empty():
		_activities._follow_relief_trail()
	for driver: Node in _activities._escort_drivers:
		if is_instance_valid(driver):
			driver.set_locomotion_motion(offset.normalized() * 1.35, true)
	var id: Variant = str(_activities._work.id)
	_activities.host.story_state.flags[id + ":escort_position"] = [_activities._escort.position.x, _activities._escort.position.y, _activities._escort.position.z]

func _follow_relief_trail() -> void:
	var trail_changed: bool = _activities._escort_trail.is_empty() or _activities._escort_trail.back().distance_to(_activities._escort.global_position) >= 0.10
	if trail_changed:
		_activities._escort_trail.append(_activities._escort.global_position)
		if _activities._escort_trail.size() > 64: _activities._escort_trail.pop_front()
	var stored: Array = []
	for index in range(_activities._relief_travelers.size()):
		var traveler: Node3D = _activities._relief_travelers[index]
		var remaining: Variant = 0.85 * float(index + 1)
		var ahead: Variant = _activities._escort.global_position
		var target: Variant = _activities._escort_trail[0]
		for point_index in range(_activities._escort_trail.size() - 1, -1, -1):
			var point: Variant = _activities._escort_trail[point_index]
			var length: Variant = ahead.distance_to(point)
			if length >= remaining and length > 0.001:
				target = ahead.lerp(point, remaining / length)
				break
			remaining -= length
			ahead = point
		var motion: Variant = target - traveler.global_position
		if motion.length_squared() > 0.00001:
			traveler.global_rotation.y = atan2(-motion.x, -motion.z)
		traveler.global_position = target
		stored.append([target.x, target.y, target.z])
	var quest_id: Variant = str(_activities._work.get("id", "side_escort_04"))
	_activities.host.story_state.flags[quest_id + ":travelers"] = stored
	if trail_changed:
		var trail: Array = []
		for point: Vector3 in _activities._escort_trail:
			trail.append([point.x, point.y, point.z])
		_activities.host.story_state.flags[quest_id + ":trail"] = trail
