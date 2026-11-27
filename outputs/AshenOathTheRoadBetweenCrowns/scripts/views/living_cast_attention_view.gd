extends RefCounted
var _life: Node
func _init(life: Node) -> void:
	_life = life
func _begin_scene_attention(entry: Dictionary, raw: Variant) -> void:
	entry.erase("scene_attention")
	if not raw is Dictionary: return
	var mode: Variant = str(raw.get("mode", "actor"))
	var seconds: Variant = clampf(float(raw.get("seconds", 1.0)),0.0,2.0)
	if not is_finite(seconds) or seconds <= 0.0: return
	if mode == "neutral":
		entry.scene_attention = {"mode":"neutral","remaining":seconds}
		return
	if mode != "point": return
	var target: Variant = Vector3.INF
	var offset: Variant = raw.get("offset")
	if offset is Array and offset.size() == 3:
		var point: Variant = Vector3(float(offset[0]),float(offset[1]),float(offset[2]))
		if point.is_finite() and point.length() <= 6.0:
			target = entry.node.to_global(point)
	elif str(raw.get("anchor", "")) != "":
		var nearest: Variant = 36.0
		for anchor: Node3D in _life.host.zone_root.find_children("LifeAttention_*", "Marker3D", true, false):
			if str(_life.read_tag(anchor, "attention_anchor", "")) != str(raw.anchor) or not bool(_life.read_tag(anchor, "geometry_verified", false)): continue
			var distance: float = entry.node.global_position.distance_squared_to(anchor.global_position)
			if distance < nearest:
				nearest = distance
				target = anchor.global_position
	if target.is_finite(): entry.scene_attention = {"mode":"point","point":target,"remaining":seconds}

func _apply_scene_attention(entry: Dictionary, focus: Node3D, delta: float) -> void:
	if not is_instance_valid(entry.get("face")): return
	var intent: Dictionary = entry.get("scene_attention", {})
	if intent.is_empty() or float(intent.get("remaining",0.0)) <= 0.0:
		entry.face.set_focus_target(focus)
		entry.erase("scene_attention")
		return
	intent.remaining = maxf(0.0,float(intent.remaining)-delta)
	entry.face.set_attention(str(intent.mode), null, intent.get("point",Vector3.ZERO))

func _story_workstation_valid(record: Dictionary) -> bool:
	var station: Dictionary = record.get("workstation", {})
	if station.is_empty(): return true
	var node: Node3D = station.node_ref.get_ref()
	var prop: Node3D = station.prop_ref.get_ref()
	if not is_instance_valid(node) or not is_instance_valid(prop) or not prop.is_visible_in_tree() or not _life.host.zone_root.is_ancestor_of(node): return false
	if str(_life.read_tag(node, "work_identity", "")) != str(station.identity) or not bool(_life.read_tag(prop, "grip_geometry_verified", false)): return false
	var bound: WeakRef = _life.read_tag(node, "task_prop") if node.has_meta("task_prop") else null
	if bound == null or bound.get_ref() != prop or _life.station_actor(str(station.reservation)) != record.entry.node: return false
	var stand: Variant = node.get_node_or_null("WorkStand") as Marker3D
	var contact: Variant = node.get_node_or_null("WorkContact") as Marker3D
	return stand != null and contact != null and stand.global_position.is_equal_approx(station.stand) and contact.global_position.is_equal_approx(station.point)

func _release_story_workstation(record: Dictionary) -> void:
	var station: Dictionary = record.get("workstation", {})
	if not station.is_empty() and _life.station_actor(str(station.reservation)) == record.entry.node:
		_life.release_station(str(station.reservation))

func _story_workstation_aligned(record: Dictionary) -> bool:
	var station: Dictionary = record.get("workstation", {})
	if station.is_empty(): return false
	var actor: Node3D = record.entry.node
	if actor.global_position.distance_to(station.stand) > 0.035: return false
	var facing: Vector3 = station.point - actor.global_position
	facing.y = 0.0
	return facing.length_squared() > 0.0001 and absf(wrapf(_life._wanted_yaw(actor,facing) - actor.rotation.y, -PI, PI)) <= 0.01

func _story_workstation_action(record: Dictionary) -> bool:
	var driver: Node = record.entry.driver
	return not record.get("workstation", {}).is_empty() and is_instance_valid(driver) and bool(driver.action_active) and str(driver.current_state) == "story_settle_ledger"

func _world_walk_to(entry: Dictionary, target: Vector3, delta: float, arrival_radius: float = 0.2) -> bool:
	var offset: Vector3 = target - entry.node.global_position
	offset.y = 0
	if offset.length() <= arrival_radius + 0.005 and float(entry.motion_speed) < 0.12:
		entry.route = []
		entry.motion_speed = 0.0
		_life._set_motion(entry, 0.0)
		return true
	if entry.route.is_empty():
		if _life.model.milliseconds() < int(entry.get("world_route_due", 0)): return false
		entry.world_route_due = _life.model.milliseconds() + 750
		entry.route = _life.spatial_service.build_route(entry.node.global_position, target, 0.72) if _life.spatial_service != null else []
		entry.route_index = 1 if entry.route.size() > 1 else 0
	if entry.route.is_empty(): return false
	var point: Vector3 = entry.route[int(entry.route_index)]
	offset = point - entry.node.global_position
	offset.y = 0
	var final_point: bool = int(entry.route_index) + 1 >= entry.route.size()
	if not final_point and offset.length() < 0.2:
		entry.route_index = int(entry.route_index) + 1
		return false
	_life._walk_scripted_step(entry, point, 0.7, 0.5, arrival_radius if final_point else 0.0, delta)
	return false

func begin_opening_scene() -> bool:
	if not _life.opening_scene.is_empty() or str(_life.host.current_zone_id) != "greyfen" or _life.get_tree().paused: return false
	_life._end_social_exchange()
	_life.opening_scene = {"index":0,"remaining":0.0,"actor":null,"entry":{},"activity":"","station":{},"watching":false}
	_life.host.hud.show_opening_scene_action("Watch village arrival", _watch_arrival, false)
	_life.host.audio.set_ambient_conversation(true)
	return true

func _watch_arrival() -> void:
	if _life.opening_scene.is_empty() or not _life.host.input_router.is_gameplay_context() or not _life.player.can_control:
		return
	_life.opening_scene.watching = true
	_life.write_tag(_life.host.zone_root, "opening_scene_active", true)
	_life.host.input_router.begin_context("dialogue")
	_life.player.can_control = false
	_life.host.hud.show_opening_scene_action("Skip introduction", _life.finish_opening_scene.bind("skipped"), true)
	if is_instance_valid(_life.opening_scene.actor):
		_life.host.camera_rig.frame_story_action(_life.opening_scene.actor)

func _tick_opening_scene(delta: float) -> void:
	if _life.host.resource_shutdown_prepared or _life.host.zone_transition_pending or _life.host._journey_load_pending() or (not _life.opening_scene.watching and not _life.host.input_router.is_gameplay_context()):
		_life.finish_opening_scene("interrupted")
		return
	if float(_life.opening_scene.remaining) > 0.0:
		_life.opening_scene.remaining = maxf(0.0, float(_life.opening_scene.remaining) - delta)
		return
	_life._release_opening_performer()
	var beats: Array[Dictionary] = preload("res://scripts/story_scene_direction.gd").opening_arrival()
	if int(_life.opening_scene.index) >= beats.size():
		_life.finish_opening_scene("completed")
		return
	var beat: Dictionary = beats[int(_life.opening_scene.index)]
	_life.opening_scene.index = int(_life.opening_scene.index) + 1
	var entry: Variant = _life._world_actor(str(beat.actor))
	if entry.is_empty() or not is_instance_valid(entry.node) or not entry.node.is_visible_in_tree():
		return
	if not _life.Presence.claim(entry.node, "work", _life.get_instance_id()): return
	_life.opening_scene.actor = entry.node
	_life.opening_scene.entry = entry
	var modifier: Node = entry.driver.life_modifier if is_instance_valid(entry.driver) else null
	_life.opening_scene.activity = str(modifier.activity) if is_instance_valid(modifier) else ""
	_life.opening_scene.station = modifier.station.duplicate(true) if is_instance_valid(modifier) else {}
	_life.write_tag(entry.node, "cast_work_cancel", _life.finish_opening_scene.bind("interrupted"))
	_life._release_activity(entry)
	if is_instance_valid(entry.driver):
		entry.driver.set_distance_suspended(false)
		entry.driver.set_life_activity(str(beat.activity))
		var station: Dictionary = entry.profile.get("workstation", {})
		if not station.is_empty() and entry.node.global_position.distance_to(station.get("stand", entry.node.global_position)) < 1.3:
			entry.driver.set_life_workstation(station)
	if _life.opening_scene.watching and _life.host.camera_rig != null: _life.host.camera_rig.frame_story_action(entry.node)
	_life.opening_scene.remaining = float(beat.seconds)
	_life.host.hud.show_ambient_subtitle(_life.get_instance_id(), str(beat.speaker), str(beat.text), float(beat.seconds))
	_life.host.audio.play_nearby_speech(str(beat.actor), str(beat.text), entry.node)

func _release_opening_performer() -> void:
	if _life.opening_scene.is_empty(): return
	var candidate = _life.opening_scene.get("actor")
	if not is_instance_valid(candidate): return
	var actor: Node3D = candidate
	var entry: Dictionary = _life.opening_scene.entry
	if not entry.is_empty() and is_instance_valid(entry.driver):
		entry.driver.set_life_activity(str(_life.opening_scene.activity))
		entry.driver.set_life_workstation(_life.opening_scene.station)
	_life.Presence.release(actor, "work", _life.get_instance_id())
	_life.opening_scene.actor = null

func finish_opening_scene(reason: String = "skipped") -> void:
	if _life.opening_scene.is_empty(): return
	_life._release_opening_performer()
	var watching := bool(_life.opening_scene.watching)
	_life.opening_scene.clear()
	if not is_instance_valid(_life.host): return
	if is_instance_valid(_life.get_parent()): _life.write_tag(_life.get_parent(), "opening_scene_active", false)
	var coordinator: Node = _life.host.coordinator if _life.supports(_life.host, "retire_construction_host") else _life.host
	if not is_instance_valid(coordinator) or coordinator.is_queued_for_deletion(): return
	if bool(coordinator.resource_shutdown_prepared) or coordinator.zone_root != _life.get_parent(): return
	if is_instance_valid(_life.host.hud):
		_life.host.hud.clear_ambient_subtitle(_life.get_instance_id())
		_life.host.hud.hide_opening_scene_skip()
	if watching and is_instance_valid(_life.host.camera_rig): _life.host.camera_rig.release_dialogue_frame()
	if is_instance_valid(_life.host.audio): _life.host.audio.set_ambient_conversation(false)
	if watching and is_instance_valid(_life.player) and not _life.player.transition_locked:
		_life.player.can_control = _life.player.health_component.health > 0.0
	if _life.host.resource_shutdown_prepared or not _life.host.is_inside_tree(): return
	_life.host.story_state.set_flag("opening_arrival_presentation", reason)
	if (watching or _life.host.input_router.is_gameplay_context()) and not _life.get_tree().paused and not _life.host._journey_load_pending() and not _life.host.zone_transition_pending and not _life.host.zone_load_request_pending and _life.get_parent() == _life.host.zone_root:
		if watching: _life.host.input_router.begin_context("gameplay")
		_life.host._show_current_objective_guidance(7.0)
		_life.host.hud.toast("Anwen needs the northern road investigated. Nera's relief work can wait until you choose to help.", 7.0)
	_life.host.story_save_pending = true
	_life.host.call_deferred("_persist_story_action")
