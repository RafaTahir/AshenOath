extends RefCounted

## Opt-in rendered QA module for capture_monster_vitality.gd.
## Controlled scene setup is explicit; combat inputs use the normal event path.
## No injected damage, health refills, quest completion or earned-item grants.
var _game: Variant
var _tree: SceneTree
var _output := ""
var _viewport := Vector2i.ZERO
var _touch := false
var _watched: Variant
var _held: Dictionary = {}
var _snapshots: Array[Dictionary] = []
var _original_pool: Array = []
var _samples: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _cases: Array[Dictionary] = []
var _failures: Array[String] = []
var _contacts: Array[Dictionary] = []
var _damage_contacts: Array[Dictionary] = []
var _blade_samples: Array[Dictionary] = []
var _waits: Array[Dictionary] = []
var _setup_probes: Array[Dictionary] = []
var _coordinates: Script
var _observed_viewport: Dictionary = {}
var _inputs: Array[Dictionary] = []
var _event_count := 0
var _phase := "setup"
var _player_home := Vector3.ZERO
var _player_yaw := 0.0
var _touch_forced_before := false
var _safety_stopped := false
const CENTRE := Vector3(-1.0, 0.0, -6.5)
const ACTIONS := ["light_attack", "heavy_attack", "block", "dodge"]
const HARD_WALL_SECONDS := 120.0

func run(game: Node, output_dir: String, viewport: Vector2i) -> Dictionary:
	_game = game
	_tree = game.get_tree()
	_output = ProjectSettings.globalize_path(output_dir)
	_viewport = viewport
	_touch = viewport.x <= 960
	_coordinates = load(get_script().resource_path.get_base_dir().path_join("qa_viewport_coordinates.gd"))
	DirAccess.make_dir_recursive_absolute(_output)
	if DisplayServer.get_name().to_lower() == "headless":
		return {"passed": false, "failures": ["Actual-world capture requires a graphical renderer"]}
	_tree.paused = false
	Engine.time_scale = 1.0
	_game.process_mode = Node.PROCESS_MODE_INHERIT
	if str(_game.current_zone_id) != "wychwood":
		await _game._load_zone("wychwood", Vector3(0, 1, 11))
	if not await _wait(func() -> bool: return str(_game.current_zone_id) == "wychwood" and not _game.zone_transition_pending and _game.player != null, 20.0,false):
		return {"passed": false, "failures": ["Wychwood did not become playable for the diagnostic"]}
	await _steps(8)
	_observed_viewport = _viewport_contract()
	if not bool(_observed_viewport.valid):
		return {"passed":false,"failures":["Native window/internal canvas contract mismatch"],"viewport_contract":_observed_viewport}
	_player_home = _game.player.global_position
	_player_yaw = _game.player.rotation.y
	var kills_before := int(_game.wychwood_pack_kills)
	var health_before := float(_game.player.health_component.health)
	_original_pool = _game.active_enemies.duplicate()
	for actor: Node3D in _game.active_enemies:
		if not is_instance_valid(actor) or bool(actor.dead): continue
		_snapshots.append({"actor": actor, "position": actor.global_position, "yaw": actor.rotation.y,
			"home": actor.home_position, "active": actor.encounter_active})
		actor.set_encounter_active(false)
	_game.active_enemies.clear()
	_game._sync_camera_enemy_cache()
	if _game.mobile_touch != null:
		_touch_forced_before = bool(_game.mobile_touch.force_touch_for_test)
		_game.mobile_touch.set_force_touch_for_test(_touch)
	await _steps(5)
	if not _game.input_router.is_gameplay_context():
		_failures.append("InputRouter was not in gameplay context")
	if _touch and (_game.mobile_touch == null or not _game.mobile_touch.is_gameplay_visible()):
		_failures.append("The 960 viewport did not expose usable touch controls")
	var observer := func(actor: Node, parried: bool, point: Vector3) -> void:
		_contacts.append({"actor": actor.get_instance_id(), "parried": parried, "point": _v(point), "ms": Time.get_ticks_msec()})
	# EnemyAI emits damaged synchronously inside Health.damage, before its
	# accepted HitReact clears the old strike. Capture that actual boundary.
	var damage_observer := func(actor: Node, health: float, _maximum: float) -> void:
		_damage_contacts.append({"actor":actor.get_instance_id(), "identity":str(actor.enemy_id), "health":health, "phase":_phase,
			"pending":actor.pending_attack_time, "windup":actor.windup_time, "token":actor.owns_attack_token,
			"cooldown":actor.attack_cooldown,"visible":actor.can_see_player,"animation_before_reaction":str(actor.animation_driver.current_state),
			"contact_events":_contacts.size(), "ms":Time.get_ticks_msec()})
	for snapshot: Dictionary in _snapshots:
		snapshot.actor.attack_resolved.connect(observer)
		snapshot.actor.damaged.connect(damage_observer)
	var blade_observer := func(contact: Dictionary) -> void:
		_blade_samples.append({"phase":_phase,"ms":Time.get_ticks_msec(),"attack_id":contact.get("attack_id"),
			"base":_v(contact.base),"tip":_v(contact.tip),"previous_base":_v(contact.previous_base),
			"previous_tip":_v(contact.previous_tip),"contact_phase":contact.contact_phase,"reach":contact.reach,
			"heavy":contact.heavy,"ready":_game.player.is_blade_ready(),"facing":_v(-_game.player.global_basis.z),
			"watched_actor":str(_watched.enemy_id) if is_instance_valid(_watched) else "",
			"measured_existing_sweep_distance":_measured_blade_distance(contact),"existing_melee_width":0.78 if bool(contact.heavy) else 0.66})
	_game.player.blade_contact_requested.connect(blade_observer)
	# The first ordinary Strike input draws the real weapon. No target is active.
	if _failures.is_empty():
		await _tap("light_attack")
		var weapon_ready := await _wait(func() -> bool: return not _game.player.sword_sheathed and not _game.player.equipment_loadout.is_transitioning(), 3.0)
		await _steps(30)
		if not weapon_ready:
			_failures.append("The ordinary Strike input did not finish drawing the real weapon")
		else:
			for identity in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
				if float(_game.player.health_component.health) < 35.0:
					_failures.append("Health safety floor reached; remaining combat observations were stopped")
					break
				await _approach_case(str(identity))
			await _miss_case()
			await _parry_case()
			await _interrupt_case(false)
			await _interrupt_case(true)
			await _wall_case()
	await _release_inputs()
	_watched = null
	_game.active_enemies.clear()
	_game.active_enemies.append_array(_original_pool)
	if _game.player.blade_contact_requested.is_connected(blade_observer): _game.player.blade_contact_requested.disconnect(blade_observer)
	for snapshot: Dictionary in _snapshots:
		var actor: Node3D = snapshot.actor
		if not is_instance_valid(actor): continue
		if actor.attack_resolved.is_connected(observer): actor.attack_resolved.disconnect(observer)
		if actor.damaged.is_connected(damage_observer): actor.damaged.disconnect(damage_observer)
		actor.set_encounter_active(false)
		actor.global_position = snapshot.position
		actor.home_position = snapshot.home
		actor.rotation.y = float(snapshot.yaw)
		actor.velocity = Vector3.ZERO
		actor.set_encounter_active(bool(snapshot.active) and not actor.dead)
	_game._sync_camera_enemy_cache()
	_game.player.global_position = _player_home
	_game.player.rotation.y = _player_yaw
	_game.player.velocity = Vector3.ZERO
	if _game.mobile_touch != null: _game.mobile_touch.set_force_touch_for_test(_touch_forced_before)
	_tree.paused = false
	Engine.time_scale = 1.0
	_game.process_mode = Node.PROCESS_MODE_INHERIT
	if int(_game.wychwood_pack_kills) != kills_before:
		_failures.append("A diagnostic unexpectedly changed the campaign kill count")
	if _game.active_enemies != _original_pool: _failures.append("Original runtime enemy pool/order was not restored")
	var report := {"kind": "monster_mechanics_actual_world", "passed": _failures.is_empty(), "failures": _failures,
		"viewport": [viewport.x, viewport.y], "zone": "wychwood", "cases": _cases, "captures": _captures,
		"viewport_contract":_observed_viewport,"viewport_label":"requested native window client size; raw render retains production 1280x720 canvas",
		"input_method": "synthetic InputEventScreenTouch/ScreenDrag through live MobileTouchControls" if _touch else "synthetic InputEventKey/MouseButton through normal InputRouter",
		"input_actions": _inputs, "input_event_objects_sent": _event_count, "samples": _samples, "damage_contacts":_damage_contacts,
		"blade_samples":_blade_samples,"player_health_before": health_before,
		"wait_budgets":_waits,"setup_probes":_setup_probes,"hard_wall_cap_seconds":HARD_WALL_SECONDS,
		"player_health_after": float(_game.player.health_component.health), "health_refills": 0,
		"quest_preawards": 0, "injected_damage_calls": 0, "campaign_kills_before": kills_before,
		"campaign_kills_after": int(_game.wychwood_pack_kills), "physical_device_coverage": false,
		"fixture_pool_scope":{"original_count":_original_pool.size(),"restored_count":_game.active_enemies.size(),
			"policy":"Same runtime active_enemies Array is narrowed to the watched existing actor per case; other retained actors stay deactivated; the complete original pool and activation states are restored. Prevents the normal wave director reactivating prior fixture opponents; no quest/kill progress writes."},
		"setup": "Diagnostic runtime zone entry, controlled positions/cooldown/perception, and isolated one-actor runtime pool. Not a campaign progression or traversal acceptance run.",
		"performance_note": "PNG readback and diagnostic sampling invalidate frame-time benchmarking."}
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t") + "\n")
	return report

func _actor(identity: String) -> Variant:
	for snapshot: Dictionary in _snapshots:
		if is_instance_valid(snapshot.actor) and str(snapshot.actor.enemy_id) == identity and not snapshot.actor.dead:
			return snapshot.actor
	return null

func _viewport_contract() -> Dictionary:
	var logical: Vector2 = _game.get_viewport().get_visible_rect().size
	var physical := Vector2(DisplayServer.window_get_size())
	var render_size := Vector2i(_game.get_viewport().get_texture().get_size())
	var result: Dictionary = _coordinates.contract(logical,physical)
	result["requested_window_client_size"] = [_viewport.x,_viewport.y]
	result["raw_render_size"] = [render_size.x,render_size.y]
	result["valid"] = bool(result.valid) and Vector2i(physical)==_viewport and Vector2i(logical)==Vector2i(1280,720) and render_size==Vector2i(1280,720)
	return result

func _measured_blade_distance(contact: Dictionary) -> float:
	if not is_instance_valid(_watched): return -1.0
	var best := INF
	for height: float in [0.35,0.72,1.08,1.42]:
		var point: Vector3 = _watched.global_position+Vector3.UP*height
		var closest: Vector3 = _game.combat._closest_sweep_point(point,contact.previous_base,contact.previous_tip,contact.base,contact.tip)
		best = minf(best,point.distance_to(closest))
	return best

func _fixture_exclusions() -> Array[RID]:
	var result: Array[RID] = [_game.player.get_rid()]
	for actor: Node3D in _original_pool:
		if is_instance_valid(actor): result.append(actor.get_rid())
	return result

func _fixture_collision(body: Node3D) -> CollisionShape3D:
	for child: Node in body.get_children():
		if child is CollisionShape3D and child.shape!=null: return child
	return null

func _fixture_floor(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*3.0,point-Vector3.UP*3.0,1)
	query.exclude = _fixture_exclusions()
	query.collide_with_areas = false
	return _game.zone_root.get_world_3d().direct_space_state.intersect_ray(query)

func _fixture_sweep(collision: CollisionShape3D, start: Vector3, finish: Vector3) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = Transform3D(Basis.IDENTITY,start+collision.position)
	query.collision_mask = 1
	query.exclude = _fixture_exclusions()
	query.collide_with_areas = false
	query.margin = 0.0
	var space: PhysicsDirectSpaceState3D = _game.zone_root.get_world_3d().direct_space_state
	var overlaps := space.intersect_shape(query,8)
	var names: Array[String] = []
	for overlap: Dictionary in overlaps:
		var collider: Node = overlap.collider
		names.append(str(collider.get_path()))
	query.motion = finish-start
	var fractions := space.cast_motion(query)
	return {"clear":overlaps.is_empty() and fractions.size()==2 and fractions[0]>=0.99999,
		"initial_overlaps":names,"motion_fraction":float(fractions[0]) if fractions.size()==2 else -1.0}

func _select_corridor(actor: Node3D, distance: float) -> Dictionary:
	var body := _fixture_collision(actor)
	var player_body := _fixture_collision(_game.player)
	if body==null or player_body==null: return {}
	var body_height := float(body.shape.height)
	var player_height := float(player_body.shape.height)
	var candidates := [Vector3(0.2,0,-5.5),Vector3(-0.2,0,-5.5),CENTRE+Vector3(0,0,1),Vector3(0.2,0,-6),Vector3(-0.2,0,-6)]
	for candidate: Vector3 in candidates:
		var player_floor := _fixture_floor(candidate)
		var start_floor := _fixture_floor(candidate+Vector3.FORWARD*distance)
		var record := {"phase":_phase,"actor":str(actor.enemy_id),"candidate":_v(candidate),"accepted":false,
			"collision_height":body_height,"collision_radius":body.shape.radius,"collision_layer":actor.collision_layer}
		if player_floor.is_empty() or start_floor.is_empty():
			record.reason = "missing actual floor"
			_setup_probes.append(record)
			continue
		var player_root: Vector3 = player_floor.position+Vector3.UP*(player_height*0.5-player_body.position.y+0.015)
		var actor_root: Vector3 = start_floor.position+Vector3.UP*(body_height*0.5-body.position.y+0.015)
		var side: float = float(actor.flank_sign)
		if actor.encounter_slot>0: side = -1.0 if actor.encounter_slot%2==0 else 1.0
		var radius: float = actor.tactics.engagement_radius(actor.preferred_distance,actor.attack_range,true,0.0,0.0,actor.enemy_navigation_view.READY_APPROACH_MARGIN)
		var goal: Vector3 = player_root+Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(float(actor.approach_angle_degrees)*side))*radius
		var goal_floor := _fixture_floor(goal)
		var floor_safe := not goal_floor.is_empty()
		var samples := maxi(2,ceili(actor_root.distance_to(goal)/0.30))
		for index in range(samples+1):
			var floor_hit := _fixture_floor(actor_root.lerp(goal,float(index)/samples))
			floor_safe = floor_safe and not floor_hit.is_empty()
			if not floor_hit.is_empty(): floor_safe = floor_safe and floor_hit.normal.y>=0.95 and absf(float(floor_hit.position.y)-float(player_floor.position.y))<=0.08
		if not floor_safe:
			record.reason = "floor discontinuity, slope or raised prop"
			_setup_probes.append(record)
			continue
		var body_goal: Vector3 = goal_floor.position+Vector3.UP*(body_height*0.5-body.position.y+0.015)
		var sweep := _fixture_sweep(body,actor_root,body_goal)
		var player_clear := _fixture_sweep(player_body,player_root,player_root)
		var authored_clear: bool = _game.spatial_service.validate_segment(actor_root,goal,0.62)
		var validated: Vector3 = _game.spatial_service.validate_position(goal,0.62,_game.spatial_service.bank_for(goal),actor)
		var route: Array = _game.spatial_service.build_route(actor_root,goal,0.62,actor)
		record.merge({"actor_root":_v(actor_root),"player_root":_v(player_root),"raw_goal":_v(goal),"validated_goal":_v(validated),
			"actor_sweep":sweep,"player_occupancy":player_clear,"authored_segment_clear":authored_clear,"route_points":route.size()})
		var projected := Vector2(validated.x-goal.x,validated.z-goal.z).length()>0.01
		var endpoint_ok := not route.is_empty() and Vector2(route.back().x-goal.x,route.back().z-goal.z).length()<=0.01
		record.accepted = bool(sweep.clear) and bool(player_clear.clear) and authored_clear and not projected and endpoint_ok
		_setup_probes.append(record)
		if record.accepted: return {"player_root":player_root,"actor_root":actor_root}
	return {}

func _place(actor: Variant, distance: float, perception_delay: float = 0.0) -> bool:
	_game.active_enemies.clear()
	for snapshot: Dictionary in _snapshots:
		if is_instance_valid(snapshot.actor): snapshot.actor.set_encounter_active(false)
	_game._sync_camera_enemy_cache()
	_watched = null
	await _release_inputs()
	var placement := _select_corridor(actor,distance)
	if placement.is_empty():
		_failures.append("No verified floor/capsule/navigation fixture corridor for " + _phase)
		return false
	_game.player.global_position = placement.player_root
	_game.player.rotation.y = 0.0
	_game.player.velocity = Vector3.ZERO
	actor.global_position = placement.actor_root
	actor.home_position = actor.global_position
	actor.velocity = Vector3.ZERO
	actor.attack_cooldown = 0.0
	actor.attack_recovery_time = 0.0
	actor.stagger_time = 0.0
	actor.can_see_player = false
	actor.perception_refresh_time = perception_delay
	actor.perception_memory_time = 0.0
	actor.last_known_player_position = Vector3.INF
	# An existing watching/rest owner holds the idle fixture until real awareness
	# resumes; no patrol target or sound cue may turn it away during preparation.
	actor.ambient_state = "watching"
	actor.ambient_target = Vector3.INF
	actor.ambient_remaining = 1.0
	actor.had_player_contact = false
	actor.heard_cue_deadline = 60 if perception_delay>0.0 else 0
	actor.navigation_target = Vector3.INF
	actor.navigation_refresh_time = 0.0
	actor.navigation_route.clear()
	actor.look_at(Vector3(_game.player.global_position.x,actor.global_position.y,_game.player.global_position.z),Vector3.UP)
	_watched = actor
	_game.active_enemies.append(actor)
	actor.set_encounter_active(true)
	_game._sync_camera_enemy_cache()
	await _steps(2)
	_assert_fixture_pool()
	var actual_goal: Vector3 = actor._engagement_target()
	var unignored: Vector3 = _game.spatial_service.validate_position(actual_goal,0.62,_game.spatial_service.bank_for(actual_goal))
	var ignored: Vector3 = _game.spatial_service.validate_position(actual_goal,0.62,_game.spatial_service.bank_for(actual_goal),actor)
	_setup_probes.append({"phase":_phase,"kind":"actual_live_route","raw_goal":_v(actual_goal),
		"normal_validated_goal":_v(unignored),"caller_excluded_goal":_v(ignored),"route":actor.navigation_route.map(_v)})
	return true

func _finish_actor_case(actor: Variant, settle_steps: int) -> void:
	_game.active_enemies.clear()
	actor.set_encounter_active(false)
	_watched = null
	_game._sync_camera_enemy_cache()
	await _steps(settle_steps)

func _assert_fixture_pool() -> void:
	if not is_instance_valid(_watched): return
	if _game.active_enemies.size()!=1 or _game.active_enemies[0]!=_watched or not _watched.encounter_active:
		_failures.append("Diagnostic runtime pool lost exclusive watched actor ownership")
	for snapshot: Dictionary in _snapshots:
		if is_instance_valid(snapshot.actor) and snapshot.actor!=_watched and snapshot.actor.encounter_active:
			_failures.append("A nonselected fixture actor became active: " + str(snapshot.actor.enemy_id))

func _approach_case(identity: String) -> void:
	var actor: Variant = _actor(identity)
	if actor == null:
		_failures.append("Missing actual runtime actor: " + identity)
		return
	_phase = identity + "_stationary_approach"
	var contact_start := _contacts.size()
	if not await _place(actor,maxf(float(actor.preferred_distance)+2.0,4.5)):
		_finish_case({"case":_phase,"passed":false,"setup_failed":true})
		return
	var health_before: float = _game.player.health_component.health
	var initial: float = actor.global_position.distance_to(_game.player.global_position)
	var player_start: Vector3 = _game.player.global_position
	var began := await _wait(func() -> bool: return actor.pending_attack_time > 0.0, 12.0)
	if began: await _capture(_phase + "_windup")
	var ended := false
	if began: ended = await _wait(func() -> bool: return actor.pending_attack_time <= 0.0 and actor.attack_recovery_time > 0.0, 2.0)
	if ended: await _capture(_phase + "_resolved")
	var displacement := player_start.distance_to(_game.player.global_position)
	var trace: Dictionary = actor.get_attack_trace()
	var body_contact := false
	for index in range(contact_start, _contacts.size()):
		body_contact = body_contact or (_contacts[index].actor == actor.get_instance_id() and not bool(_contacts[index].parried))
	var health_lost: float = health_before - float(_game.player.health_component.health)
	var result := {"case": _phase, "passed": began and ended and body_contact and health_lost > 0.0 and initial > float(actor.preferred_distance) and displacement < 0.35,
		"initial_distance": initial, "preferred_distance": actor.preferred_distance, "attack_range": actor.attack_range,
		"reached_windup": began, "completed_strike": ended, "stationary_player_displacement": displacement,
		"contact_events": _contacts.size() - contact_start, "resolution": "body_contact" if _contacts.size() > contact_start else "geometric_miss",
		"unguarded_body_contact":body_contact, "health_lost":health_lost,
		"skeleton_trace": trace.uses_skeleton, "trace_start": _v(trace.start), "trace_end": _v(trace.end), "closest_contact": _v(trace.contact),
		"contact_probe_distance": (_game.player.global_position + Vector3.UP).distance_to(trace.contact)}
	_finish_case(result)
	await _finish_actor_case(actor,20)

func _miss_case() -> void:
	if _safety_stopped: return
	var actor: Variant = _actor("wychwood_brute")
	if actor == null: return
	_phase = "brute_late_dodge_geometric_miss"
	if not await _place(actor,1.6):
		_finish_case({"case":_phase,"passed":false,"setup_failed":true})
		return
	var health: float = _game.player.health_component.health
	var contact_start := _contacts.size()
	var began := await _wait(func() -> bool: return actor.pending_attack_time > 0.0, 3.0)
	var late_input := false
	var resolved := false
	if began:
		late_input = await _wait(func() -> bool: return actor.pending_attack_time <= actor.attack_windup_total * 0.42, 1.0)
		late_input = late_input and actor.pending_attack_time > 0.0
		_press("move_left", true)
		await _tap("dodge")
		resolved = await _wait(func() -> bool: return actor.pending_attack_time <= 0.0 and actor.attack_recovery_time > 0.0, 1.0)
		_press("move_left", false)
		await _capture(_phase)
	_finish_case({"case": _phase, "passed": began and late_input and resolved and _contacts.size() == contact_start and is_equal_approx(health, _game.player.health_component.health),
		"late_input_before_contact":late_input, "completed_strike_with_recovery":resolved,
		"contact_events": _contacts.size() - contact_start, "health_lost": health - float(_game.player.health_component.health),
		"player_distance_after": actor.global_position.distance_to(_game.player.global_position), "recovery": actor.attack_recovery_time})
	await _finish_actor_case(actor,35)

func _parry_case() -> void:
	if _safety_stopped: return
	var actor: Variant = _actor("wychwood_stalker")
	if actor == null: return
	_phase = "stalker_normal_guard_parry"
	if not await _place(actor,1.15):
		_finish_case({"case":_phase,"passed":false,"setup_failed":true})
		return
	var health: float = _game.player.health_component.health
	var contact_start := _contacts.size()
	var began := await _wait(func() -> bool: return actor.pending_attack_time > 0.0, 3.0)
	if began:
		await _wait(func() -> bool: return actor.pending_attack_time <= 0.17, 1.0)
		_press("block", true)
		await _wait(func() -> bool: return actor.pending_attack_time <= 0.0, 1.0)
		_press("block", false)
		await _capture(_phase)
	var parried := false
	for index in range(contact_start, _contacts.size()):
		parried = parried or bool(_contacts[index].parried)
	_finish_case({"case": _phase, "passed": began and parried and is_equal_approx(health, _game.player.health_component.health),
		"parried_contact": parried, "health_lost": health - float(_game.player.health_component.health), "enemy_stagger": actor.stagger_time})
	await _finish_actor_case(actor,40)

func _interrupt_case(idle_hit: bool) -> void:
	if _safety_stopped: return
	var actor: Variant = _actor("wychwood_brute")
	if actor == null: return
	_phase = "idle_hit_protects_reaction_priority" if idle_hit else "blade_hit_cancels_pending_strike"
	var heavy := idle_hit
	var estimated: float = _game.player.get_blade_attack_damage(heavy) * 1.15
	if float(actor.health_component.health) <= estimated + 12.0:
		_failures.append(_phase + ": nonlethal health margin unavailable; no refill or lethal attack attempted")
		return
	# Start within demonstrated real blade reach. Cold awareness preserves a
	# genuine idle at contact, then only its ordinary refresh timer is released.
	var controlled_distance := 1.05 if idle_hit else 0.90
	if not await _place(actor,controlled_distance,1.0 if idle_hit else 0.0):
		_finish_case({"case":_phase,"passed":false,"setup_failed":true})
		return
	var began := true
	if not idle_hit: began = await _wait(func() -> bool: return actor.pending_attack_time > 0.0, 3.0)
	var before: float = actor.health_component.health
	var contacts_before := _contacts.size()
	var damage_contacts_before := _damage_contacts.size()
	var samples_before := _samples.size()
	if began: await _tap("heavy_attack" if heavy else "light_attack")
	var hit := await _wait(func() -> bool: return float(actor.health_component.health) < before, 1.2)
	var blade_contact: Dictionary = {}
	for index in range(damage_contacts_before, _damage_contacts.size()):
		var sample: Dictionary = _damage_contacts[index]
		if sample.actor == actor.get_instance_id() and float(sample.health) < before:
			blade_contact = sample
			break
	var cooldown_at_hit := float(blade_contact.get("cooldown", -1.0))
	var pending_at_hit := float(blade_contact.get("pending", 0.0))
	var token_at_hit := bool(blade_contact.get("token", false))
	var windup_before_hit := false
	for index in range(samples_before, _samples.size()):
		windup_before_hit = windup_before_hit or (float(_samples[index].windup) > 0.0 and float(_samples[index].actor_health) >= before)
	var cancelled: bool = hit and actor.pending_attack_time == 0.0 and actor.windup_time == 0.0 and not actor.owns_attack_token
	var reaction: bool = hit and str(actor.animation_driver.current_state) == "hit"
	if idle_hit and hit: actor.perception_refresh_time = 0.0
	var protected_samples := 0
	var invisible_restart := false
	if hit:
		if not idle_hit: await _capture(_phase)
		var first_tick := Engine.get_physics_frames()
		var wall_deadline := Time.get_ticks_msec()+int(HARD_WALL_SECONDS*1000.0)
		while str(actor.animation_driver.current_state)=="hit" and Engine.get_physics_frames()-first_tick<ceili(1.2*Engine.physics_ticks_per_second) and Time.get_ticks_msec()<wall_deadline:
			var ready_distance: float = actor.tactics.engagement_radius(float(actor.attack_range),float(actor.attack_range),actor.can_see_player,actor.attack_cooldown,actor.attack_recovery_time)
			if actor.can_see_player and actor.global_position.distance_to(_game.player.global_position) <= ready_distance and float(actor.stagger_time) <= 0.0 and float(actor.attack_cooldown) <= 0.0:
				protected_samples += 1
				invisible_restart = invisible_restart or actor.pending_attack_time > 0.0 or actor.owns_attack_token
				if idle_hit and protected_samples == 1: await _capture(_phase)
			await _steps(1)
	var no_contact: bool = _contacts.size() == contacts_before
	var passed: bool = began and hit and not blade_contact.is_empty() and cancelled and reaction and not invisible_restart and no_contact
	if idle_hit: passed = passed and protected_samples>0 and not windup_before_hit and cooldown_at_hit==0.0 and pending_at_hit==0.0 and not token_at_hit and not bool(blade_contact.get("visible",true))
	else: passed = passed and pending_at_hit > 0.0 and token_at_hit and int(blade_contact.get("contact_events", -1)) == contacts_before
	_finish_case({"case": _phase, "passed": passed, "actual_blade_damage": before - float(actor.health_component.health),
		"controlled_distance":controlled_distance,
		"pending_strike_cancelled": cancelled, "accepted_hit_reaction": reaction, "post_stagger_reaction_samples": protected_samples,
		"cooldown_at_hit": cooldown_at_hit, "windup_observed_before_hit": windup_before_hit,
		"pending_at_blade_contact":pending_at_hit, "token_at_blade_contact":token_at_hit, "no_enemy_contact":no_contact,
		"damage_observation":"actual synchronous EnemyAI.damaged signal before reaction cancellation",
		"controlled_perception_delay":1.0 if idle_hit else 0.0,"perception_refresh_released_after_actual_hit":idle_hit and hit,
		"perception_at_blade_contact":blade_contact.get("visible"),"animation_before_hit_reaction":blade_contact.get("animation_before_reaction"),
		"invisible_restart": invisible_restart, "enemy_contact_events_during_observation": _contacts.size() - contacts_before})
	await _finish_actor_case(actor,40)

func _wall_case() -> void:
	if _safety_stopped: return
	var actor: Variant = _actor("wychwood_brute")
	if actor == null: return
	_phase = "physical_wall_blocks_committed_strike"
	if not await _place(actor,1.6):
		_finish_case({"case":_phase,"passed":false,"setup_failed":true})
		return
	var health: float = _game.player.health_component.health
	var contacts_before := _contacts.size()
	var began := await _wait(func() -> bool: return actor.pending_attack_time > 0.0, 3.0)
	var wall := StaticBody3D.new()
	wall.name = "QAOnlyMonsterLineOfSightWall"
	wall.collision_layer = 1
	wall.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.5, 0.16)
	collision.shape = shape
	wall.add_child(collision)
	_game.zone_root.add_child(wall)
	wall.global_position = (actor.global_position + _game.player.global_position) * 0.5 + Vector3(0, 1.1, 0)
	await _steps(3)
	var blocked: bool = not actor._has_attack_line() and not actor._has_perception_line()
	var resolved := false
	if began: resolved = await _wait(func() -> bool: return actor.pending_attack_time <= 0.0 and actor.attack_recovery_time > 0.0, 1.0)
	await _capture(_phase)
	_finish_case({"case": _phase, "passed": began and blocked and resolved and _contacts.size() == contacts_before and is_equal_approx(health, _game.player.health_component.health),
		"completed_strike_with_recovery":resolved,
		"actual_physics_los_blocked": blocked, "contact_events": _contacts.size() - contacts_before,
		"health_lost": health - float(_game.player.health_component.health)})
	wall.queue_free()
	await _finish_actor_case(actor,3)

func _finish_case(result: Dictionary) -> void:
	_cases.append(result)
	if not bool(result.passed): _failures.append(str(result.case) + " did not satisfy its actual-world assertions")

func _wait(predicate: Callable, seconds: float, simulation_budget: bool = true) -> bool:
	var first_tick := Engine.get_physics_frames()
	var first_ms := Time.get_ticks_msec()
	var ready := false
	while true:
		ready = bool(predicate.call())
		var wall_seconds := (Time.get_ticks_msec()-first_ms)/1000.0
		var simulation_seconds := float(Engine.get_physics_frames()-first_tick)/Engine.physics_ticks_per_second
		if ready or wall_seconds>=HARD_WALL_SECONDS or (simulation_seconds>=seconds if simulation_budget else wall_seconds>=seconds): break
		await _steps(1)
	_waits.append({"phase":_phase,"budget_seconds":seconds,"budget_clock":"physics_steps" if simulation_budget else "monotonic_wall",
		"elapsed_simulation_seconds":float(Engine.get_physics_frames()-first_tick)/Engine.physics_ticks_per_second,
		"elapsed_wall_seconds":(Time.get_ticks_msec()-first_ms)/1000.0,"ready":ready})
	return ready

func _steps(count: int) -> void:
	for index in count:
		await _tree.physics_frame
		if not _safety_stopped and _game.player != null and float(_game.player.health_component.health) <= 25.0:
			_safety_stopped = true
			_failures.append("Health safety floor stopped all diagnostic opponents")
			for snapshot: Dictionary in _snapshots:
				if is_instance_valid(snapshot.actor): snapshot.actor.set_encounter_active(false)
		if is_instance_valid(_watched):
			if not _safety_stopped: _assert_fixture_pool()
			_samples.append({"phase": _phase, "ms": Time.get_ticks_msec(), "tick": Engine.get_physics_frames(),
				"actor": str(_watched.enemy_id), "position": _v(_watched.global_position), "player": _v(_game.player.global_position),
				"windup": _watched.pending_attack_time, "cooldown": _watched.attack_cooldown, "stagger": _watched.stagger_time,
				"can_see_player": _watched.can_see_player, "distance_to_player": _watched.global_position.distance_to(_game.player.global_position),
				"token": _watched.owns_attack_token, "animation": str(_watched.animation_driver.current_state),
				"marker_visible": _watched.windup_marker != null and _watched.windup_marker.visible,
				"actor_health": _watched.health_component.health, "player_health": _game.player.health_component.health,
				"player_blade_ready":_game.player.is_blade_ready(),"player_attack_time":_game.player.attack_anim_time,
				"player_forward":_v(-_game.player.global_basis.z),"input_context":str(_game.input_router.input_context)})
		await _tree.process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _game.get_viewport().get_texture().get_image()
	var path := _output.path_join(label + ".png")
	var error := image.save_png(path)
	_captures.append({"case": label, "path": path, "width": image.get_width(), "height": image.get_height(), "error": error})
	var contract := _viewport_contract()
	if error!=OK or not bool(contract.valid) or image.get_size()!=Vector2i(1280,720): _failures.append("Capture native window/internal-render contract or write failed: " + label)

func _tap(action: String) -> void:
	_press(action, true)
	await _steps(2)
	_press(action, false)
	await _steps(2)

func _release_inputs() -> void:
	for action: String in _held.keys(): _press(action, false)
	await _steps(3)

func _press(action: String, pressed: bool) -> void:
	if not pressed and not _held.has(action): return
	var coordinate_record: Dictionary = {}
	if _touch:
		var control: Variant = _game.mobile_touch
		if pressed and (control == null or not control.is_gameplay_visible()):
			_failures.append("Touch control is unavailable for " + action)
			return
		var logical_point: Vector2
		var index: int = 1 if action == "move_left" else 3 + ACTIONS.find(action)
		if pressed:
			if action == "move_left": logical_point = control._layout.move_center
			elif control.action_centers.has(action) and control._action_enabled(action): logical_point = control.action_centers[action]
			else:
				_failures.append("No enabled touch target for " + action)
				return
			_held[action] = logical_point
		else: logical_point = _held[action]
		var logical_size: Vector2 = _game.get_viewport().get_visible_rect().size
		var physical_size := Vector2(DisplayServer.window_get_size())
		var point: Vector2 = _coordinates.logical_to_window(logical_point,logical_size,physical_size)
		if not point.is_finite() or not bool(_viewport_contract().valid):
			_failures.append("Touch coordinate/native window contract failed: " + action)
			return
		coordinate_record = {"logical_position":[logical_point.x,logical_point.y],"window_client_position":[point.x,point.y],
			"logical_size":[logical_size.x,logical_size.y],"window_client_size":[physical_size.x,physical_size.y]}
		var contact := InputEventScreenTouch.new()
		contact.index = index
		contact.position = point
		contact.pressed = pressed
		Input.parse_input_event(contact)
		_event_count += 1
		if pressed and action == "move_left":
			var drag := InputEventScreenDrag.new()
			drag.index = index
			var logical_delta := Vector2(-float(control._layout.move_travel),0)
			drag.relative = _coordinates.logical_delta_to_window(logical_delta,logical_size,physical_size)
			drag.screen_relative = drag.relative
			drag.position = point + drag.relative
			Input.parse_input_event(drag)
			_event_count += 1
			coordinate_record["logical_drag_delta"] = [logical_delta.x,logical_delta.y]
			coordinate_record["window_client_drag_delta"] = [drag.relative.x,drag.relative.y]
	elif action in ["light_attack", "heavy_attack"]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT if action == "light_attack" else MOUSE_BUTTON_RIGHT
		button.button_mask = (MOUSE_BUTTON_MASK_LEFT if action == "light_attack" else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
		button.position = Vector2(_viewport) * 0.5
		button.pressed = pressed
		Input.parse_input_event(button)
		_event_count += 1
		if pressed: _held[action] = true
	else:
		var key := InputEventKey.new()
		key.keycode = KEY_A if action == "move_left" else (KEY_Q if action == "block" else KEY_SPACE)
		key.physical_keycode = key.keycode
		key.pressed = pressed
		Input.parse_input_event(key)
		_event_count += 1
		if pressed: _held[action] = true
	var input_record := {"ms": Time.get_ticks_msec(), "phase": _phase, "action": action, "pressed": pressed, "touch": _touch}
	input_record.merge(coordinate_record)
	_inputs.append(input_record)
	if not pressed: _held.erase(action)

func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
