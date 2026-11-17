extends RefCounted
var _life: Node
func _init(life: Node) -> void:
	_life = life
func _line_for_actor(entry: Dictionary) -> String:
	var standing: Dictionary = _life.host.story_state.honor_view(str(entry.id))
	if bool(standing.grievance) or str(standing.band) in ["Distrusted", "Respected"]:
		return str(standing.reaction)
	if bool(entry.get("regional", false)):
		var identity: Variant = str(entry.profile.get("identity", ""))
		var acknowledgement: Variant = str(_life.host.story_state.consume_relationship_greeting(identity))
		if acknowledgement != "":
			return acknowledgement
	var consequence_line: Variant = str(entry.get("consequence_line", ""))
	if consequence_line != "": return consequence_line
	var reaction: Variant = str(entry.get("story_reaction", "baseline"))
	for report in ["public"]:
		if reaction.begins_with("reported_" + report):
			return _life.model.post_report_line(report, int(entry.get("activity_cycles", 0)), true)
	return str(_life.OCCUPATION_LINES.get(str(entry.id), _life.AMBIENT_LINES.get(str(entry.profile.get("line", "")), _life.AMBIENT_LINES.greyfen_keep_working)))

func _tick_greeting(entry: Dictionary, delta: float) -> bool:
	var node: Node3D = entry.node
	var distance: Variant = node.global_position.distance_to(_life.player.global_position)
	if distance > 4.6:
		_life.model.proximity(str(entry.id), distance, false, false, false)
	var remaining: Variant = float(entry.get("greeting_remaining", 0.0))
	if remaining <= 0.0:
		if distance > 4.0 or bool(entry.profile.get("sleeping", false)) and _life._supported_rest(entry) or float(entry.bark_cooldown) > 0.0 or not _life.social_scene.is_empty():
			return false
		if not is_instance_valid(entry.driver) or entry.driver.has_active_action() or not _life.Presence.can_see(node, _life.player, 4.0, true):
			return false
		if not _life.model.proximity(str(entry.id), distance, false, true, true): return false
		entry.bark_cooldown = 60.0
		remaining = 3.2
		entry.greeting_started = false
	entry.greeting_remaining = maxf(remaining - delta, 0.0)
	if not bool(entry.get("greeting_started", false)) and not _life._awake_rest_support(entry).is_empty():
		_life._set_activity_pose(entry, true)
		var modifier: Node = entry.driver.life_modifier
		if is_instance_valid(modifier) and float(modifier.awake_seat_weight) > 0.001 and float(entry.greeting_remaining) > 0.0:
			return true
	_life._brake_actor(entry, delta)
	if float(entry.motion_speed) <= 0.05:
		_life._face(node, _life.player.global_position, delta)
		var heading: Vector3 = entry.driver.get_visible_forward()
		var to_player: Variant = _life.player.global_position - node.global_position
		to_player.y = 0.0
		if not bool(entry.get("greeting_started", false)) and (to_player.length_squared() < 0.01 or heading.dot(to_player.normalized()) > 0.85):
			entry.greeting_started = true
			entry.greeting_remaining = 1.2
			entry.driver.clear_life_activity()
			entry.driver.trigger_action("greet", 1.0, 0.10, false, 1.1)
			if is_instance_valid(entry.get("face")):
				entry.face.set_focus_target(_life.player)
				entry.face.play_story_gesture("acknowledge")
			if _life.line_cooldown <= 0.0 and _life.host.hud.ambient_subtitle_available(_life.get_instance_id()):
				var remark: Variant = _life._line_for_actor(entry)
				var duration: Variant = float(_life.host.audio.play_nearby_speech(str(entry.id), remark, node)) if _life.host.audio != null else 0.0
				_life.line_cooldown = maxf(15.0, duration + 4.0)
				_life.host.hud.show_ambient_subtitle(_life.get_instance_id(), str(entry.profile.get("occupation", "Villager")).capitalize(), remark, maxf(5.5, duration + 0.3))
	if float(entry.greeting_remaining) <= 0.0:
		_life._cancel_greeting(entry)
	return true

func _cancel_greeting(entry: Dictionary, release_pose: bool = true) -> void:
	if float(entry.get("greeting_remaining", 0.0)) <= 0.0 and not bool(entry.get("greeting_started", false)):
		return
	entry.greeting_remaining = 0.0
	entry.greeting_started = false
	if not release_pose:
		return
	if is_instance_valid(entry.driver) and str(entry.driver.current_state) == "greet":
		entry.driver.stop_action()
	if is_instance_valid(entry.get("face")):
		_life._set_activity_attention(entry, bool(entry.get("activity_active", false)))

func _try_social_exchange(entry: Dictionary) -> void:
	pass

func _social_actor_available(entry: Dictionary) -> bool:
	if not is_instance_valid(entry.node) or not entry.node.is_visible_in_tree() or _life.Presence.protected(entry.node):
		return false
	if bool(entry.profile.get("sleeping", false)) or float(entry.get("greeting_remaining", 0.0)) > 0.0:
		return false
	if str(_life.read_tag(entry.node, "locomotion_owner", "")) not in ["", "greyfen_life"]:
		return false
	if float(entry.get("reaction_time", 0.0)) > 0.0 or float(entry.get("motion_speed", 0.0)) > 0.05:
		return false
	var body: Variant = entry.node.get_node_or_null("Person") as Node3D
	return body == null or body.visible

func _social_pair(first: Dictionary, second: Dictionary, turns: Array) -> void:
	if turns.is_empty() or not _life.Presence.claim(first.node, "social", _life.get_instance_id()):
		return
	if not _life.Presence.claim(second.node, "social", _life.get_instance_id()):
		_life.Presence.release(first.node, "social", _life.get_instance_id())
		return
	_life.social_cooldown = 65.0
	_life.line_cooldown = 12.0
	var saved: Array[Dictionary] = []
	for entry: Dictionary in [first, second]:
		var face: Node = entry.get("face")
		saved.append({"entry":entry, "attention":face.capture_attention() if is_instance_valid(face) else {}})
		_life.write_tag(entry.node, "cast_social_cancel", _life._end_social_exchange)
		_life._release_activity(entry)
		entry.social_time = 30.0
		entry.motion_speed = 0.0
		if is_instance_valid(entry.driver):
			entry.driver.set_dialogue_pose(true)
		if is_instance_valid(face):
			face.set_conversation_active(true)
	_life.social_scene = {"actors":saved, "turns":turns, "index":0, "remaining":0.0, "elapsed":0.0}

func _tick_social_exchange(delta: float) -> void:
	if _life.social_scene.is_empty():
		return
	if _life.social_scene.has("world"):
		_life._tick_world_scene(delta)
		return
	_life.social_scene.elapsed = float(_life.social_scene.elapsed) + delta
	var saved: Array = _life.social_scene.actors
	for record: Dictionary in saved:
		var entry: Dictionary = record.entry
		if not _life._social_actor_available(entry) or entry.node.global_position.distance_squared_to(_life.player.global_position) > 81.0 or entry.node.global_position.distance_squared_to(_life.player.global_position) < 4.41 or float(_life.social_scene.elapsed) > 29.0:
			_life._end_social_exchange()
			return
	if saved[0].entry.node.global_position.distance_squared_to(saved[1].entry.node.global_position) > 16.0:
		_life._end_social_exchange()
		return
	for index in saved.size():
		_life._face(saved[index].entry.node, saved[1-index].entry.node.global_position, delta)
	_life.social_scene.remaining = float(_life.social_scene.remaining) - delta
	if float(_life.social_scene.remaining) > 0.0:
		return
	var index: Variant = int(_life.social_scene.index)
	var turns: Array = _life.social_scene.turns
	if index >= turns.size():
		_life._end_social_exchange()
		return
	var turn: Dictionary = turns[index]
	var words: Variant = str(turn.get("text", ""))
	var speaker: Variant = str(turn.get("speaker", ""))
	var duration: Variant = clampf(float(words.split(" ", false).size()) * 0.28 + 1.0, 2.5, 7.0)
	for record: Dictionary in saved:
		var entry: Dictionary = record.entry
		var speaking: Variant = str(entry.id) == speaker
		var other: Dictionary = saved[1].entry if str(saved[0].entry.id) == str(entry.id) else saved[0].entry
		if is_instance_valid(entry.get("face")):
			entry.face.set_focus_target(other.node)
			entry.face.set_expression("wry" if str(entry.id) == "rook" else "warmth")
			entry.face.set_speech_amount(0.0)
			entry.face.play_story_gesture("explain" if speaking else "acknowledge")
		if is_instance_valid(entry.driver):
			entry.driver.set_story_listening(not speaking)
			if speaking:
				entry.driver.play_story_gesture("explain")
		if speaking and is_instance_valid(_life.host.audio):
			duration = maxf(duration, float(_life.host.audio.play_nearby_speech(str(entry.id), words, entry.node)) + 0.25)
	_life.host.hud.toast("%s: %s" % [str(turn.get("name", speaker)), words], duration)
	_life.social_scene.index = index + 1
	_life.social_scene.remaining = minf(duration + 0.25, 12.0)

func _end_social_exchange() -> void:
	if _life.social_scene.is_empty():
		return
	if is_instance_valid(_life.host.hud):
		_life.host.hud.clear_ambient_subtitle(_life.get_instance_id())
	if is_instance_valid(_life.host.audio):
		_life.host.audio.set_ambient_conversation(false)
		_life.host.audio.stop_table_performance(_life.get_instance_id())
	for record: Dictionary in _life.social_scene.actors:
		var entry: Dictionary = record.entry
		_life._release_story_workstation(record)
		if not is_instance_valid(entry.node):
			continue
		entry.erase("scene_attention")
		if is_instance_valid(entry.driver) and _life.supports(entry.driver, "clear_story_prop"):
			entry.driver.clear_story_prop(_life.get_instance_id())
		_life.Presence.release(entry.node, "social", _life.get_instance_id())
		var release_pose: Variant = not _life.Presence.has_protected_owner(entry.node) and str(_life.read_tag(entry.node, "locomotion_owner", "")) in ["", "greyfen_life"]
		if is_instance_valid(_life.host) and is_instance_valid(_life.host.audio):
			_life.host.audio.stop_nearby_speech(entry.node, release_pose)
		entry.social_time = 0.0
		entry.route = []
		entry.motion_speed = 0.0
		entry.pause = 0.8
		if not release_pose:
			continue
		if is_instance_valid(entry.driver):
			entry.driver.stop_story_gesture()
			entry.driver.set_dialogue_pose(false)
			entry.driver.clear_life_activity()
		if is_instance_valid(entry.get("face")):
			entry.face.restore_attention(record.get("attention", {}))
	_life.social_scene = {}

func _world_actor(id: String) -> Dictionary:
	for entry: Dictionary in _life.actors:
		if _life.CastProfile.same_person(str(entry.id), id) and is_instance_valid(entry.node):
			return entry
	if id == "player": return {}
	var names: Array = ["edric_campaign", "edric_castle"] if id == "edric" else [id]
	for actor_name: String in names:
		var node: Variant = _life.CastProfile.registered_actor(_life.host.zone_root, actor_name)
		if node == null:
			node = _life.host.zone_root.find_child(actor_name, true, false) as Node3D
		if not is_instance_valid(node) or not node.is_visible_in_tree() or str(_life.read_tag(node, "locomotion_owner", "")) not in ["", "greyfen_life"]: continue
		var driver: Variant = node.find_child("CharacterAnimationDriver", true, false)
		if driver == null: continue
		var entry: Variant = _life._make_entry(id, node, [node.global_position], 0.62, driver, true)
		var ambient: Variant = node.find_child("NpcAmbient", true, false)
		if ambient != null: ambient.process_mode = Node.PROCESS_MODE_DISABLED
		entry.profile = {"occupation":id.capitalize(), "activity":"idle", "activity_seconds":8.0, "line":""}
		_life.actors.append(entry)
		_life._configure_agent(entry)
		return entry
	return {}

func has_minor_friction(actor: Node3D) -> bool:
	for entry: Dictionary in _life.actors:
		if entry.node == actor:
			return float(entry.get("minor_friction_until", 0.0)) > _life.model.milliseconds()
	return false

func repair_minor_friction(actor: Node3D) -> bool:
	if _life.Presence.player_threat(_life.player) != "" or actor.global_position.distance_to(_life.player.global_position) < 1.1: return false
	for entry: Dictionary in _life.actors:
		if entry.node != actor or not _life.has_minor_friction(actor): continue
		entry.minor_friction_until = 0
		if str(entry.get("reaction", "")) == "suspicion": _life._finish_reaction(entry)
		return true
	return false

func joinable_world_conversation(actor: Node3D) -> Dictionary:
	if _life.social_scene.is_empty() or not _life.social_scene.has("world"): return {}
	var scene: Dictionary = _life.social_scene.world
	if str(scene.get("kind", "")) != "exchange": return {}
	for record: Dictionary in _life.social_scene.actors:
		if record.entry.node == actor:
			var copy: Variant = scene.duplicate(true)
			copy["join_from"] = int(_life.social_scene.index)
			return copy
	return {}

func join_world_conversation(actor: Node3D, scene: Dictionary) -> void:
	if scene.is_empty() or not _life.WorldScenes.eligible(scene, _life.host): return
	var selected: Array[Dictionary] = []
	for id: String in scene.get("actors", []):
		var entry: Variant = _life._world_actor(id)
		if entry.is_empty() or not _life._social_actor_available(entry) or entry.node.global_position.distance_to(_life.player.global_position) > 6.0: return
		if not selected.any(func(other: Variant) -> Variant: return other.node == entry.node): selected.append(entry)
	if selected.is_empty(): return
	_life._end_social_exchange()
	var joined: Variant = scene.duplicate(true)
	joined.id = str(scene.id) + ":joined"
	if bool(_life.host.story_state.get_flag("world_scenes_heard", {}).get(str(joined.id), false)): return
	joined["completes_scene"] = str(scene.id)
	joined.turns = [["player", "Kael", "May I join you?"], [str(actor.get("interaction_id")), _life.CastProfile.display_name(str(actor.get("interaction_id"))), "Of course. We were just talking about the work here."]] + _life.WorldScenes.turns(scene, _life.host).slice(int(scene.get("join_from",0)))
	joined.erase("variants")
	_life._start_world_scene(joined, selected)

func play_optional_exchange(actor: Node3D, turns: Array, id: String) -> bool:
	if _life.host._story_has_active_combat() or _life.host.zone_transition_pending or _life.Presence.player_threat(_life.player) != "": return false
	var entry: Variant = _life._world_actor(str(actor.get("interaction_id")))
	if entry.is_empty() or not _life._social_actor_available(entry): return false
	_life._end_social_exchange()
	var scene: Variant = {"id":id + ":" + str(_life.model.milliseconds()), "ephemeral":true, "zone":_life.host.current_zone_id, "kind":"conversation", "actors":[str(entry.id)], "turns":turns, "action":"idle"}
	_life._start_world_scene(scene, [entry])
	return not _life.social_scene.is_empty()

func request_world_scene(id: String) -> bool:
	if _life.host._story_has_active_combat() or _life.host.zone_transition_pending or _life.Presence.player_threat(_life.player) != "": return false
	for scene: Dictionary in _life.WorldScenes.data().get("scenes", []):
		if str(scene.id) != id or not bool(scene.get("requested", false)) or not _life.WorldScenes.eligible(scene, _life.host): continue
		var selected: Array[Dictionary] = []
		for actor_id: String in scene.get("actors", []):
			var entry: Variant = _life._world_actor(actor_id)
			if entry.is_empty() or not _life._social_actor_available(entry) or entry.node.global_position.distance_to(_life.player.global_position) > 12.0: return false
			if not selected.any(func(other: Variant) -> Variant: return other.node == entry.node): selected.append(entry)
		_life._end_social_exchange()
		_life._start_world_scene(scene, selected)
		return not _life.social_scene.is_empty()
	return false
