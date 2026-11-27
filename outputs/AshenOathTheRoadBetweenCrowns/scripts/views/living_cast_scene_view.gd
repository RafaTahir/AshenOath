extends RefCounted
const RookPerformance = preload("res://scripts/views/novel_rook_performance.gd")
var _life: Node
func _init(life: Node) -> void:
	_life = life
func _try_world_scene() -> void:
	if not bool(_life.player.can_control): return
	if not _life.social_scene.is_empty() or _life.social_cooldown > 0.0 or not _life.host.hud.ambient_subtitle_available(_life.get_instance_id()) or _life.host._story_has_active_combat() or _life.host.zone_transition_pending or _life.Presence.player_threat(_life.player) != "": return
	var heard: Dictionary = _life.host.story_state.get_flag("world_scenes_heard", {})
	for scene: Dictionary in _life.WorldScenes.data().get("scenes", []):
		if bool(scene.get("requested", false)): continue
		if _life.model.milliseconds() < int(_life.world_retry_after.get(str(scene.id), 0)): continue
		if bool(heard.get(str(scene.id), false)) or not _life.WorldScenes.eligible(scene, _life.host): continue
		var selected: Array[Dictionary] = []
		var near: Variant = false
		var ready: Variant = true
		for id: String in scene.actors:
			if id == "player": continue
			var entry: Variant = _life._world_actor(id)
			if entry.is_empty() or _life.Presence.protected(entry.node) or not entry.node.is_visible_in_tree() or str(_life.read_tag(entry.node, "locomotion_owner", "")) not in ["", "greyfen_life"] or float(entry.get("reaction_time", 0.0)) > 0.0:
				ready = false
				break
			var distance: float = entry.node.global_position.distance_to(_life.player.global_position)
			near = near or (distance < 5.5 and _life.Presence.can_see(entry.node, _life.player, 6.0))
			if distance > 24.0: ready = false
			if not selected.any(func(item: Variant) -> Variant: return item.node == entry.node):
				selected.append(entry)
		if scene.has("near"):
			var point: Array = scene.near
			near = _life.player.global_position.distance_to(Vector3(point[0],point[1],point[2])) < 4.0
		if not ready or not near: continue
		_life._start_world_scene(scene, selected)
		return

func _start_world_scene(scene: Dictionary, selected: Array[Dictionary]) -> void:
	for entry: Dictionary in selected:
		if not is_instance_valid(entry.node) or str(_life.read_tag(entry.node, "locomotion_owner", "")) not in ["", "greyfen_life"]:
			return
	var required_station: Variant = str(scene.get("requires_workstation", ""))
	var stations: Dictionary = {}
	if required_station != "":
		for entry: Dictionary in selected:
			if not is_instance_valid(entry.driver) or not entry.driver.supports_story_workstation(required_station): continue
			var station: Variant = _life.story_workstation_for(entry.driver, required_station)
			if not station.is_empty(): stations[str(entry.id)] = station
		if stations.is_empty(): return
	var saved: Array[Dictionary] = []
	for entry: Dictionary in selected:
		if not _life.Presence.claim(entry.node, "social", _life.get_instance_id()):
			for claimed: Dictionary in saved: _life.Presence.release(claimed.entry.node, "social", _life.get_instance_id())
			return
		var face: Node = entry.get("face")
		saved.append({"entry":entry, "attention":face.capture_attention() if is_instance_valid(face) else {}, "workstation":stations.get(str(entry.id), {})})
	for record: Dictionary in saved:
		var entry: Dictionary = record.entry
		_life.write_tag(entry.node, "cast_social_cancel", _life._end_social_exchange)
		_life._release_activity(entry)
		var station: Dictionary = record.workstation
		if not station.is_empty(): _life.reserve_station(str(station.reservation), entry.node)
		entry.social_time = 2.0
		entry.motion_speed = 0.0
		entry.route = []
	var progress: Dictionary = _life.host.story_state.get_flag("world_scene_progress", {})
	var turns: Array = _life.WorldScenes.turns(scene, _life.host)
	var signature: Variant = JSON.stringify(turns).sha256_text()
	var checkpoint: Variant = progress.get(str(scene.id), {})
	var matching: Variant = checkpoint is Dictionary and str(checkpoint.get("signature", "")) == signature
	var index: Variant = clampi(int(checkpoint.get("index", 0)), 0, turns.size()) if matching else 0
	var walk_index: Variant = clampi(int(checkpoint.get("walk_index", 0)), 0, scene.get("walk", []).size()) if matching else 0
	_life.social_scene = {"world":scene, "actors":saved, "turns":turns, "signature":signature, "index":index, "remaining":0.0, "speaking":false, "walk_index":walk_index, "staged":false, "waiting":0.0}
	var required_prop: Variant = str(scene.get("requires_bound_prop", ""))
	if required_prop != "":
		var bound: Variant = false
		for record: Dictionary in saved:
			var driver: Node = record.entry.driver
			if not is_instance_valid(driver) or not driver.supports_story_prop(required_prop): continue
			driver.set_dialogue_pose(true)
			bound = driver.set_story_prop(required_prop,_life.get_instance_id())
			if bound: break
		if not bound:
			_life._end_social_exchange()
			return
	_life.social_cooldown = 8.0

func _tick_world_scene(delta: float) -> void:
	var scene: Dictionary = _life.social_scene.world
	if not bool(_life.player.can_control):
		_life._end_social_exchange()
		return
	if float(_life.social_scene.waiting) > 20.0:
		_life.world_retry_after[str(scene.id)] = _life.model.milliseconds() + 30000
		_life._end_social_exchange()
		return
	if not _life.WorldScenes.eligible(scene, _life.host) or _life.host._story_has_active_combat() or _life.host.zone_transition_pending or not _life.host.hud.ambient_subtitle_available(_life.get_instance_id()) or _life.Presence.player_threat(_life.player) != "":
		_life._end_social_exchange()
		return
	for record: Dictionary in _life.social_scene.actors:
		var entry: Dictionary = record.entry
		if not is_instance_valid(entry.node) or not entry.node.is_visible_in_tree() or _life.Presence.protected(entry.node) or str(_life.read_tag(entry.node, "locomotion_owner", "")) not in ["", "greyfen_life"] or float(entry.get("reaction_time", 0.0)) > 0:
			_life._end_social_exchange()
			return
		if not _life._story_workstation_valid(record):
			_life._end_social_exchange()
			return
		entry.social_time = 2.0
		if entry.node.global_position.distance_to(_life.player.global_position) > (26.0 if not bool(_life.social_scene.staged) else 9.0):
			_life._end_social_exchange()
			return
	if not bool(_life.social_scene.staged):
		_life.social_scene.waiting = float(_life.social_scene.waiting) + delta
		var arrived: Variant = true
		for record: Dictionary in _life.social_scene.actors:
			var entry: Dictionary = record.entry
			var workstation: Dictionary = record.get("workstation", {})
			if not workstation.is_empty():
				var at_station: Variant = _life._world_walk_to(entry, workstation.stand, minf(delta,0.05), 0.025)
				if at_station:
					_life._face(entry.node, workstation.point, delta)
					at_station = _life._story_workstation_aligned(record)
				arrived = at_station and arrived
				continue
			var raw: Array = scene.get("stage", {}).get(str(entry.id), [])
			if raw.is_empty():
				for staged_id: String in scene.get("stage", {}):
					if _life.CastProfile.same_person(staged_id, str(entry.id)):
						raw = scene.stage[staged_id]
						break
			if raw.size() == 3:
				arrived = _life._world_walk_to(entry, Vector3(raw[0],raw[1],raw[2]), minf(delta,0.05)) and arrived
		if not arrived: return
		_life.social_scene.staged = true
		_life.social_scene.waiting = 0.0
		if scene.has("music") and not _life.social_scene.actors.is_empty():_life.host.audio.play_table_performance(_life.get_instance_id(),_life.social_scene.actors[0].entry.node)
	if scene.has("walk") and int(_life.social_scene.index) == 1 and not bool(_life.social_scene.speaking):
		var route: Array = scene.walk
		var step: Variant = int(_life.social_scene.walk_index)
		if step < route.size() and not _life.social_scene.actors.is_empty():
			_life.social_scene.waiting = float(_life.social_scene.waiting) + delta
			var entry: Dictionary = _life.social_scene.actors[0].entry
			if entry.node.global_position.distance_to(_life.player.global_position) > 5.5:
				_life._set_motion(entry, 0.0)
				return
			var raw: Array = route[step]
			if _life._world_walk_to(entry, Vector3(raw[0],raw[1],raw[2]), minf(delta,0.05)):
				_life.social_scene.walk_index = step + 1
				_life.social_scene.waiting = 0.0
				_life._remember_world_scene_progress()
			return
	if float(_life.social_scene.remaining) > 0.0:
		var current: Array = _life.social_scene.turns[int(_life.social_scene.index)]
		var speaker: Node3D = _life.player
		for record: Dictionary in _life.social_scene.actors:
			if _life.CastProfile.same_person(str(record.entry.id), str(current[0])): speaker = record.entry.node
		for record: Dictionary in _life.social_scene.actors:
			var actor: Node3D = record.entry.node
			var focus: Node3D = speaker if actor != speaker else _life.player
			if actor == speaker and str(scene.kind) == "exchange":
				for listener: Dictionary in _life.social_scene.actors:
					if listener.entry.node != actor:
						focus = listener.entry.node
						break
			if _life._story_workstation_action(record):
				if not _life._story_workstation_aligned(record):
					_life._end_social_exchange()
					return
				_life._face(actor, record.workstation.point, delta)
			else:
				_life._face(actor, focus.global_position, delta)
			if _life._story_workstation_action(record) and is_instance_valid(record.entry.get("face")):
				record.entry.face.set_attention("point", null, record.workstation.point)
			else:
				_life._apply_scene_attention(record.entry, focus, delta)
		_life.social_scene.remaining = maxf(0.0, float(_life.social_scene.remaining) - delta)
		return
	if bool(_life.social_scene.speaking):
		_life.social_scene.index = int(_life.social_scene.index) + 1
		_life.social_scene.speaking = false
		_life._remember_world_scene_progress()
		if scene.has("walk") and int(_life.social_scene.index) == 1:
			return
	if scene.has("activity_point") and int(_life.social_scene.index) == 2 and not bool(_life.host.story_state.get_flag("everyday_work:" + str(scene.id), false)):
		return
	if int(_life.social_scene.index) >= _life.social_scene.turns.size():
		if not bool(scene.get("ephemeral", false)):
			var heard: Dictionary = _life.host.story_state.get_flag("world_scenes_heard", {}).duplicate()
			heard[str(scene.id)] = true
			if scene.has("completes_scene"): heard[str(scene.completes_scene)] = true
			_life.host.story_state.set_flag("world_scenes_heard", heard)
			_life.host.story_save_pending = true
			_life.host.call_deferred("_persist_story_action")
		_life._end_social_exchange()
		_life.social_cooldown = 12.0
		return
	var turn: Array = _life.social_scene.turns[int(_life.social_scene.index)]
	var direction: Variant = preload("res://scripts/story_scene_direction.gd").for_world(str(scene.id), int(_life.social_scene.index), turn)
	var duration: Variant = clampf(str(turn[2]).split(" ", false).size() * 0.32 + 1.5, 3.0, 11.0)
	if scene.has("music") and int(_life.social_scene.index)==1:duration=14.0
	for record: Dictionary in _life.social_scene.actors:
		var entry: Dictionary = record.entry
		_life._set_motion(entry, 0.0)
		var speaking: Variant = _life.CastProfile.same_person(str(entry.id), str(turn[0]))
		var gesture: Variant = str(direction.get("gesture" if speaking else "listener_gesture", ""))
		var body_gesture: Variant = str(direction.get("body_gesture" if speaking else "body_listener_gesture", gesture))
		if body_gesture == "settle_ledger":
			if not _life._story_workstation_valid(record) or not _life._story_workstation_aligned(record):
				_life._end_social_exchange()
				return
			_life._face(entry.node, record.workstation.point, delta)
		else:
			_life._face(entry.node, _life.player.global_position, delta)
		if is_instance_valid(entry.driver):
			if str(scene.get("requires_bound_prop", "")) == "": entry.driver.clear_story_prop(_life.get_instance_id())
			entry.driver.set_dialogue_pose(true)
			entry.driver.set_story_listening(not speaking)
			if body_gesture == "drink":
				if not entry.driver.set_story_prop("cup", _life.get_instance_id()):
					_life._end_social_exchange()
					return
			if not RookPerformance.try_laugh(entry.driver, str(scene.id), speaking) and body_gesture != "":
				entry.driver.play_story_gesture(body_gesture)
			if body_gesture in ["drink", "settle_ledger"] and bool(entry.driver.action_active):
				duration = maxf(duration,float(entry.driver.action_duration)+0.15)
		if is_instance_valid(entry.get("face")):
			entry.face.set_conversation_active(true)
			entry.face.set_focus_target(_life.player)
			entry.face.set_expression(str(direction.get("emotion" if speaking else "listener_emotion", _life.CastProfile.expression_for(_life.CastProfile.presence_profile(str(entry.id)), _life.host.story_state))))
			entry.face.set_speech_amount(0.0)
			if gesture != "": entry.face.play_story_gesture(gesture)
		_life._begin_scene_attention(entry, direction.get("attention" if speaking else "listener_attention", {}))
		if body_gesture == "settle_ledger" and is_instance_valid(entry.get("face")):
			entry.face.set_attention("point", null, record.workstation.point)
		if speaking:
			duration = maxf(duration, float(_life.host.audio.play_nearby_speech(str(entry.id), str(turn[2]), entry.node)) + 0.3)
	_life.host.audio.set_ambient_conversation(true)
	_life.host.hud.show_ambient_subtitle(_life.get_instance_id(), str(turn[1]), str(turn[2]), duration)
	_life.social_scene.remaining = duration
	_life.social_scene.speaking = true

func _remember_world_scene_progress() -> void:
	if bool(_life.social_scene.world.get("ephemeral", false)): return
	var progress: Dictionary = _life.host.story_state.get_flag("world_scene_progress", {}).duplicate()
	progress[str(_life.social_scene.world.id)] = {"index":int(_life.social_scene.index), "walk_index":int(_life.social_scene.walk_index), "signature":str(_life.social_scene.signature)}
	_life.host.story_state.set_flag("world_scene_progress", progress)
	_life.host.story_save_pending = true
	_life.host.call_deferred("_persist_story_action")

func _update_gathering_routines() -> void:
	if _life.host.current_zone_id != "greyfen": return
	var active: Variant = preload("res://scripts/greyfen_gathering.gd").active(_life.host)
	if not _life.model.stage_gathering(active): return
	var positions: Variant = _life.model.gathering_positions()
	for id: String in positions:
		var entry: Variant = _life._world_actor(id)
		if entry.is_empty(): continue
		if active:
			entry["gathering_restore"] = {"profile":entry.profile.duplicate(true), "path":entry.path.duplicate(), "spatial_override":true}
			var profile: Dictionary = entry.profile.duplicate(true)
			profile["activity"] = "rest"
			profile["activities"] = ["rest"]
			profile["workstation"] = {}
			entry.pending_routine = {"profile":profile, "path":[positions[id]], "line":"There is room here. Nothing requires you to stay.", "gathering":true}
		elif entry.has("gathering_restore"):
			entry.pending_routine = entry.gathering_restore
			entry.erase("gathering_restore")
		_life._release_activity(entry)
		entry.route = []
		_life._apply_pending_routine(entry)

func request_table_visit(id: String, point: Vector3, approach: Vector3 = Vector3.INF) -> bool:
	var entry: Variant = _life._world_actor(id)
	if entry.is_empty() or _life.Presence.protected(entry.node) or not entry.node.is_visible_in_tree() or _life.host._story_has_active_combat(): return false
	if entry.node.global_position.distance_to(point) <= 0.35:
		entry.pause = maxf(float(entry.pause),2.0)
		return true
	if not entry.has("table_restore"):
		entry.table_restore = {"profile":entry.profile.duplicate(true),"path":entry.path.duplicate(),"spatial_override":true}
		entry.table_point = point
		if approach != Vector3.INF:
			entry.table_approach = approach
		entry.table_seconds = 120.0
		var profile: Dictionary = entry.profile.duplicate(true)
		profile["activity"] = "rest"
		profile["activities"] = ["rest"]
		profile["workstation"] = {}
		entry.pending_routine = {"profile":profile,"path":[point],"table_visit":true,"spatial_override":true}
		_life._release_activity(entry)
		_life._apply_pending_routine(entry)
	return false
