extends RefCounted
var _life: Node
func _init(life: Node) -> void:
	_life = life
func _update_reaction(entry: Dictionary, delta: float) -> void:
	entry.reaction_time = maxf(float(entry.get("reaction_time", 0.0)) - delta, 0.0)
	entry.sound_attention_cooldown = maxf(float(entry.get("sound_attention_cooldown", 0.0)) - delta, 0.0)
	entry.notice_cooldown = maxf(float(entry.get("notice_cooldown", 0.0)) - delta, 0.0)
	entry.sense_clock = float(entry.get("sense_clock", 0.0)) - delta
	if bool(entry.get("distance_suspended", false)) or _life.Presence.protected(entry.node) or str(_life.read_tag(entry.node, "locomotion_owner", "")) not in ["", "greyfen_life"]:
		return
	if float(entry.reaction_time) <= 0.0 and bool(entry.get("reaction_active", false)):
		_life._finish_reaction(entry)
	if float(entry.sense_clock) > 0.0:
		return
	entry.sense_clock = 0.35
	var face: Node = entry.get("face")
	var threat: Variant = ""
	var threat_position: Vector3 = _life.player.global_position
	var threat_actor: Node3D = _life.player
	if _life.Presence.can_see(entry.node, _life.player, 5.0):
		threat = _life.Presence.player_threat(_life.player)
	for enemy: Node3D in _life.host.encounter_spatial_index.nearby(entry.node.global_position, 7.0):
		if is_instance_valid(enemy) and not bool(enemy.get("dead")) and bool(enemy.get("encounter_active")) and _life.Presence.can_see(entry.node, enemy, 7.0):
			threat = "danger"
			threat_position = enemy.global_position
			threat_actor = enemy
			break
	if threat != "":
		if threat == "armed": entry.minor_friction_until = _life.model.milliseconds() + 45000
		var response: Variant = str(_life.CastProfile.presence_profile(str(entry.id)).get("danger_response", "shelter"))
		var accepted: Variant = _life._start_reaction(entry, ("anger" if response == "guard" else "fear") if threat == "danger" else "suspicion", threat_position, 2.5, threat_actor)
		if accepted and float(entry.notice_cooldown) <= 0.0 and _life.line_cooldown <= 0.0:
			entry.notice_cooldown = 24.0
			_life.line_cooldown = 8.0
			var warning: Variant = "Give us room. People are still working here." if threat == "armed" else "Behind the wall. Leave the road clear!"
			_life.host.hud.toast("%s: %s" % [str(entry.profile.occupation).capitalize(), warning], 3.5)
	elif float(entry.reaction_time) <= 0.0:
		if entry.node.global_position.distance_squared_to(_life.player.global_position) < 0.64:
			entry.minor_friction_until = _life.model.milliseconds() + 30000
		if float(entry.get("social_time", 0.0)) > 0.0:
			return
		if is_instance_valid(face):
			var cast: Variant = _life.CastProfile.presence_profile(str(entry.id))
			face.set_expression(_life.CastProfile.expression_for(cast, _life.host.story_state))
			face.set_focus_target(_life.player if entry.node.global_position.distance_squared_to(_life.player.global_position) < 16.0 else null)
	_life._try_social_exchange(entry)

func _reaction_priority(kind: String) -> int:
	return _life.model.reaction_priority(kind)

func _start_reaction(entry: Dictionary, kind: String, position: Vector3, duration: float, focus: Node3D = null) -> bool:
	var active: Variant = float(entry.get("reaction_time", 0.0)) > 0.0
	if active and _life._reaction_priority(kind) < _life._reaction_priority(str(entry.get("reaction", ""))):
		return false
	var changed: Variant = not active or str(entry.get("reaction", "")) != kind
	if changed:
		entry.route = []
		entry.safety_route = []
	elif (entry.get("safety_threat_position", entry.get("threat_position", position)) as Vector3).distance_squared_to(position) > 1.0:
		entry.safety_route = []
	entry.reaction = kind
	entry.reaction_active = true
	entry.reaction_time = maxf(float(entry.get("reaction_time", 0.0)), duration)
	entry.threat_position = position
	if is_instance_valid(entry.get("face")):
		entry.face.set_focus_target(focus)
		entry.face.set_expression("concern" if kind == "attention" else kind)
	if changed:
		_life.model.record_awareness(str(entry.id), kind, duration)
	return true

func _finish_reaction(entry: Dictionary) -> void:
	entry.reaction_active = false
	entry.reaction = ""
	entry.route = []
	entry.safety_route = []
	if not bool(entry.get("activity_active", false)):
		_life._set_activity_pose(entry, false)
	_life.awareness_changed.emit(str(entry.id), "")

func _seek_safety(entry: Dictionary, threat: Vector3, delta: float) -> bool:
	if (bool(entry.named) and not bool(entry.get("regional", false))) or str(entry.get("reaction", "")) != "fear" or _life.spatial_service == null:
		return false
	var route: Array = entry.get("safety_route", [])
	if route.is_empty():
		var candidate: Vector3 = entry.node.global_position
		var best: Variant = candidate.distance_squared_to(threat)
		for point: Vector3 in entry.path:
			if point.distance_squared_to(threat) > best + 1.0:
				candidate = point
				best = point.distance_squared_to(threat)
		if candidate == entry.node.global_position:
			return false
		route.assign(_life.spatial_service.build_route(entry.node.global_position, candidate, 0.72))
		entry.safety_route = route
		entry.safety_threat_position = threat
		entry.safety_index = 1 if route.size() > 1 else 0
	if route.is_empty():
		return false
	var index: Variant = int(entry.get("safety_index", 0))
	var offset: Vector3 = route[index] - entry.node.global_position
	offset.y = 0.0
	var final_point: Variant = index + 1 >= route.size()
	if final_point and offset.length() <= 0.12 + 0.005 and float(entry.motion_speed) < 0.12:
		entry.motion_speed = 0.0
		_life._set_motion(entry, 0.0)
		return false
	if not final_point and offset.length() < 0.12:
		entry.safety_index = index + 1
		return true
	_life._walk_scripted_step(entry, route[index], minf(float(entry.speed) * 1.15, 1.25), 0.70, 0.12 if final_point else 0.0, delta)
	return true

func _on_perception_cue(position: Vector3, radius: float, danger: bool) -> void:
	if not is_instance_valid(_life.host) or not bool(_life.host.game_started) or _life.get_tree().paused:
		return
	for entry: Dictionary in _life._crowd_index.nearby(position, radius):
		if not is_instance_valid(entry.node) or _life.Presence.protected(entry.node) or not entry.node.is_visible_in_tree():
			continue
		if str(_life.read_tag(entry.node, "locomotion_owner", "")) not in ["", "greyfen_life"]:
			continue
		if not danger and float(entry.get("sound_attention_cooldown", 0.0)) > 0.0:
			continue
		var guard: Variant = str(_life.CastProfile.presence_profile(str(entry.id)).get("danger_response", "")) == "guard"
		if _life._start_reaction(entry, ("anger" if guard else "fear") if danger else "attention", position, 2.5):
			if not danger:
				entry.sound_attention_cooldown = 6.0
