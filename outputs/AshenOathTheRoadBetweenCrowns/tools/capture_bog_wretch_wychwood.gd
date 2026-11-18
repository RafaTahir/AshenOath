extends "res://tools/capture_monster_mechanics.gd"

## Separate optional actual-world observation; the passing nine-case module is
## inherited unchanged. A missing conditional boss is explicitly fixture-spawned
## through its real owner, without invoking the quest-awarding Saga interaction.
const Saga = preload("res://scripts/saga_encounters.gd")
const SupportGeometry = preload("res://tools/living_cast_capture_geometry.gd")
const RuntimePacks = preload("res://scripts/runtime_pack_manager.gd")
var _owned_bog: Node3D
var _spawn_receipt: Dictionary = {}
var _generic_probes: Array[Dictionary] = []
var _native_contacts: Array[Dictionary] = []
var _preparation_receipt: Dictionary = {}
var _camera_view_before: Dictionary = {}
var _view_receipts: Array[Dictionary] = []

func run(game: Node, output_dir: String, viewport: Vector2i) -> Dictionary:
	_game = game
	_tree = game.get_tree()
	_output = ProjectSettings.globalize_path(output_dir)
	_viewport = viewport
	_touch = viewport.x <= 960
	_coordinates = load(get_script().resource_path.get_base_dir().path_join("qa_viewport_coordinates.gd"))
	DirAccess.make_dir_recursive_absolute(_output)
	if DisplayServer.get_name().to_lower() == "headless":
		return _early_failure("Actual-world Bog observation requires a graphical renderer")
	_tree.paused = false
	Engine.time_scale = 1.0
	_game.process_mode = Node.PROCESS_MODE_INHERIT
	var coordinator: Variant = _game.zone_runtime_coordinator
	if coordinator==null: return _early_failure("Actual zone runtime coordinator was unavailable")
	var preparation_started := Time.get_ticks_msec()
	var failure_count_before := int(coordinator.failure_count)
	if str(_game.current_zone_id) != "wychwood":
		await _game._load_zone("wychwood",Vector3(0,1,11))
	# The public forwarding call initiates frame-driven composition/arrival; its
	# return does not mean native warmup or supported publication has completed.
	if not await _wait_for_arena_ready(coordinator,int(coordinator.transition_count),failure_count_before,int(_game.world_transition.transition_epoch),preparation_started):
		return _early_failure("Wychwood preparation did not become playable: "+str(_preparation_receipt.get("resolution","unknown")))
	await _steps(8)
	_observed_viewport = _viewport_contract()
	if not bool(_observed_viewport.valid):
		return _early_failure("Native window/internal canvas contract mismatch")
	if not is_instance_valid(_game.camera_rig): return _early_failure("Existing gameplay camera owner was unavailable")
	if _game.camera_rig.get_locked_combat_target()!=null: return _early_failure("Fresh fixture unexpectedly had a locked target; camera setup stopped before changing it")
	_camera_view_before = _game.camera_rig.save_activity_view().duplicate(true)
	_player_home = _game.player.global_position
	_player_yaw = _game.player.rotation.y
	var health_before := float(_game.player.health_component.health)
	var kills_before := int(_game.wychwood_pack_kills)
	var progression_before := _progression_snapshot()
	_original_pool = _game.active_enemies.duplicate()
	for actor: Node3D in _original_pool:
		if not is_instance_valid(actor) or bool(actor.dead): continue
		_snapshots.append(_snapshot(actor))
	_generic_anchor_preflight("original_runtime_pool")
	for snapshot: Dictionary in _snapshots: snapshot.actor.set_encounter_active(false)
	_game.active_enemies.clear()
	_game._sync_camera_enemy_cache()
	if _game.mobile_touch!=null:
		_touch_forced_before = bool(_game.mobile_touch.force_touch_for_test)
		_game.mobile_touch.set_force_touch_for_test(_touch)
	await _steps(5)
	_generic_anchor_preflight("isolated_pool_after_deactivation")
	var bog: Variant = _actor("bog_wretch")
	if bog==null:
		bog = _game._spawn_enemy("bog_wretch",Saga.BOG_CENTER)
		if is_instance_valid(bog):
			_owned_bog = bog
			bog.leash_radius = 5.5
			bog.set_encounter_active(false)
			_snapshots.append(_snapshot(bog))
		_spawn_receipt = {"conditional_fixture":true,"owner":"game._spawn_enemy -> ZoneActorSpawner; SagaEncounters.activate uses the same call",
			"requested_anchor":_v(Saga.BOG_CENTER),"actual_owner_position":_v(bog.global_position) if is_instance_valid(bog) else [],
			"leash_radius":5.5,"original_pool_living_count":_snapshots.size()-(1 if is_instance_valid(bog) else 0),
			"factory_pool_count_before_spawn":0,"quest_gate_earned":false,"saga_activate_called":false}
	else:
		_spawn_receipt = {"conditional_fixture":false,"owner":"existing actual Wychwood enemy","requested_anchor":_v(Saga.BOG_CENTER),
			"actual_owner_position":_v(bog.global_position),"leash_radius":bog.leash_radius,"saga_activate_called":false}
	_game.active_enemies.clear()
	_game._sync_camera_enemy_cache()
	await _steps(3)
	var native_profile: Dictionary = bog.native_attack_profile.duplicate(true) if is_instance_valid(bog) else {}
	var observer := func(actor: Node,parried: bool,point: Vector3) -> void:
		_contacts.append({"actor":actor.get_instance_id(),"parried":parried,"point":_v(point),"ms":Time.get_ticks_msec()})
		var trace: Dictionary = actor.get_attack_trace()
		var chest: Vector3 = _game.player.global_position+Vector3.UP
		var probe_distance := chest.distance_to(trace.contact)
		var attack_line: bool = actor._has_attack_line()
		var special_id: String = actor._boss_attack_id()
		var special_radius: float = actor._boss_attack_radius(special_id)
		_native_contacts.append({"actor":actor.get_instance_id(),"physics_frame":Engine.get_physics_frames(),"ms":Time.get_ticks_msec(),
			"native_skeleton_trace":bool(trace.uses_skeleton),"contact_probe_distance":probe_distance,"existing_contact_radius":actor.contact_radius,
			"native_melee_contact":probe_distance<=float(actor.contact_radius) and attack_line,"attack_line":attack_line,"parried":parried,
			"player_chest":_v(chest),"trace_start":_v(trace.start),"trace_end":_v(trace.end),"closest_contact":_v(trace.contact),
			"special_id":special_id,"special_radius":special_radius,"special_contact":actor._special_attack_hits_player(special_id,special_radius),
			"actor_position":_v(actor.global_position),"player_position":_v(_game.player.global_position),"view_at_native_contact":_view_receipt("native_contact",actor)})
	if not _game.input_router.is_gameplay_context(): _failures.append("InputRouter was not in gameplay context")
	if _touch and (_game.mobile_touch==null or not _game.mobile_touch.is_gameplay_visible()):
		_failures.append("The physical touch viewport did not expose usable controls")
	if not is_instance_valid(bog):
		_failures.append("Real construction owner did not create conditional Bog Wretch")
	elif _failures.is_empty():
		bog.attack_resolved.connect(observer)
		await _approach_case("bog_wretch")
		if bog.attack_resolved.is_connected(observer): bog.attack_resolved.disconnect(observer)
		var native_hit := false
		for contact: Dictionary in _native_contacts:
			native_hit = native_hit or (bool(contact.native_melee_contact) and bool(contact.native_skeleton_trace) and not bool(contact.parried))
		if not _cases.is_empty():
			_cases.back()["native_body_contact_required"] = true
			_cases.back()["native_body_contact_observed"] = native_hit
			_cases.back()["passed"] = bool(_cases.back().passed) and native_hit
		if not native_hit: _failures.append("Bog strike did not establish actual native/body contact; radial-only hits do not satisfy this assertion")
	await _release_inputs()
	_watched = null
	if is_instance_valid(bog): bog.set_encounter_active(false)
	_game.active_enemies.clear()
	_game.active_enemies.append_array(_original_pool)
	for snapshot: Dictionary in _snapshots:
		var actor: Node3D = snapshot.actor
		if not is_instance_valid(actor) or actor==_owned_bog: continue
		actor.set_encounter_active(false)
		actor.global_position = snapshot.position
		actor.home_position = snapshot.home
		actor.rotation.y = float(snapshot.yaw)
		actor.velocity = Vector3.ZERO
		actor.set_encounter_active(bool(snapshot.active) and not actor.dead)
	var freed_owned_actor := false
	if is_instance_valid(_owned_bog):
		_owned_bog.queue_free()
		await _tree.process_frame
		freed_owned_actor = not is_instance_valid(_owned_bog)
	_game._sync_camera_enemy_cache()
	_game.player.global_position = _player_home
	_game.player.rotation.y = _player_yaw
	_game.player.velocity = Vector3.ZERO
	_game.camera_rig.restore_activity_view(_camera_view_before)
	_game.camera_rig.reset_follow()
	_game.camera_rig.prepare_view()
	if _game.mobile_touch!=null: _game.mobile_touch.set_force_touch_for_test(_touch_forced_before)
	_tree.paused = false
	Engine.time_scale = 1.0
	_game.process_mode = Node.PROCESS_MODE_INHERIT
	var progression_after := _progression_snapshot()
	if progression_before!=progression_after: _failures.append("Bog observation changed campaign objective progression")
	if int(_game.wychwood_pack_kills)!=kills_before: _failures.append("Bog observation changed campaign kill count")
	if _game.active_enemies!=_original_pool: _failures.append("Original runtime enemy pool/order was not restored")
	if bool(_spawn_receipt.get("conditional_fixture",false)) and not freed_owned_actor: _failures.append("Owned conditional fixture actor was not freed")
	var report := {"kind":"bog_wretch_wychwood_actual_world","passed":_failures.is_empty() and _cases.size()==1,"failures":_failures,
		"zone":"wychwood","authored_arena_anchor":_v(Saga.BOG_CENTER),"spawn":_spawn_receipt,"cases":_cases,"captures":_captures,
		"viewport":[viewport.x,viewport.y],"viewport_contract":_observed_viewport,"native_attack_profile":native_profile,"native_contact_observations":_native_contacts,
		"preparation":_preparation_receipt,
		"live_view_receipts":_view_receipts,"camera_activity_before":_camera_view_before,"camera_activity_restored":_game.camera_rig.save_activity_view(),
		"camera_fixture":"Existing CameraController follows a disclosed +35 degree three-quarter heading; normal camera collision, live actors and native animation remain active. Original activity view is restored. Frustum/visibility diagnostics require image review for visual acceptance.",
		"generic_npc_placement_preflight":_generic_probes,"setup_probes":_setup_probes,"samples":_samples,"wait_budgets":_waits,
		"hard_wall_cap_seconds":HARD_WALL_SECONDS,"player_health_before":health_before,"player_health_after":float(_game.player.health_component.health),
		"quest_preawards":0,"injected_damage_calls":0,"health_refills":0,"input_actions":_inputs,"input_event_objects_sent":_event_count,
		"input_method":"Stationary player observes ordinary incoming AI strike; no player action events are sent",
		"campaign_kills_before":kills_before,"campaign_kills_after":int(_game.wychwood_pack_kills),
		"objective_state_before":progression_before,"objective_state_after":progression_after,"original_pool_restored":_game.active_enemies==_original_pool,
		"original_pool_count":_original_pool.size(),"owned_fixture_freed":freed_owned_actor,"physical_device_coverage":false,
		"setup":"Diagnostic Wychwood entry; actual conditional EnemyAI via existing construction owner at Saga anchor, isolated original runtime pool, verified capsule/floor/nav corridor. Not quest-gate or campaign traversal acceptance.",
		"performance_note":"Diagnostic sampling and PNG readback invalidate performance benchmarking."}
	_write_bog_report(report)
	return report

func _early_failure(reason: String) -> Dictionary:
	_failures.append(reason)
	var report := {"kind":"bog_wretch_wychwood_actual_world","passed":false,"failures":_failures,
		"zone":"wychwood","cases":_cases,"captures":_captures,"preparation":_preparation_receipt,
		"viewport":[_viewport.x,_viewport.y],"viewport_contract":_observed_viewport,
		"quest_preawards":0,"injected_damage_calls":0,"health_refills":0,"physical_device_coverage":false}
	_write_bog_report(report)
	return report

func _write_bog_report(report: Dictionary) -> void:
	var file := FileAccess.open(_output.path_join("report.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"\t")+"\n")

func _place(actor: Variant, distance: float, perception_delay: float = 0.0) -> bool:
	if not await super._place(actor,distance,perception_delay): return false
	actor.reset_physics_interpolation()
	_game.camera_rig.follow_movement_heading(float(_game.player.rotation.y)+deg_to_rad(35.0))
	_game.camera_rig.reset_follow()
	_game.camera_rig.prepare_view()
	await _steps(2)
	_view_receipts.append(_view_receipt("fixture_camera_setup",actor))
	return true

func _capture(label: String) -> void:
	await super._capture(label)
	if not is_instance_valid(_watched): return
	var receipt := _view_receipt(label,_watched)
	_view_receipts.append(receipt)
	if not bool(receipt.actor_visible_in_tree) or int(receipt.color_mesh_candidates)==0 or bool(receipt.driver.distance_suspended):
		_failures.append("Bog capture had no eligible visible live body: "+label)

func _finish_actor_case(actor: Variant, settle_steps: int) -> void:
	if is_instance_valid(actor) and float(actor.attack_recovery_time)>0.0:
		await _steps(3)
		await _capture(_phase+"_recovery")
	await super._finish_actor_case(actor,settle_steps)

func _view_receipt(label: String, actor: Node3D) -> Dictionary:
	var camera: Camera3D = _game.get_viewport().get_camera_3d()
	var driver: Variant = actor.animation_driver
	var source_player: AnimationPlayer = driver.animation_player
	# AnimationTree owns the live pose; its AnimationPlayer may only supply
	# libraries. Stopped library players have no valid current-position getter.
	var library_clock := {"available":false,"reason":"missing_library_player","clip":"","position":null,"length":null}
	if is_instance_valid(source_player):
		library_clock.clip = str(source_player.current_animation)
		library_clock["player_active"] = source_player.active
		library_clock.reason = "inactive_or_no_current_animation"
		if source_player.active and not str(library_clock.clip).is_empty() and source_player.is_playing():
			library_clock.merge({"available":true,"reason":"playing_library_clock_is_not_runtime_graph_clock",
				"position":source_player.current_animation_position,"length":source_player.current_animation_length},true)
	var graph_clock := {"available":false}
	var graph: Variant = driver.animation_graph
	if graph!=null:
		graph_clock = {"available":true,"active_state":graph.active_state,"requested_state":graph.requested,
			"evaluation_suspended":graph.evaluation_suspended,"scheduled":graph.scheduled(),
			"tree_active":is_instance_valid(graph.tree) and graph.tree.active,
			"playback_playing":graph.playback!=null and graph.playback.is_playing(),
			"current_node":str(graph.playback.get_current_node()) if graph.playback!=null and graph.playback.is_playing() else ""}
	var meshes: Array[Dictionary] = []
	var color_candidates := 0
	for mesh: MeshInstance3D in actor.visual_root.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null: continue
		var candidate: bool = mesh.is_visible_in_tree() and (mesh.layers&camera.cull_mask)!=0 and mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if candidate: color_candidates += 1
		meshes.append({"path":str(mesh.get_path()),"visible":mesh.visible,"visible_in_tree":mesh.is_visible_in_tree(),
			"render_layers_match":(mesh.layers&camera.cull_mask)!=0,"shadows_only":mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
			"authored_mesh_bounds_center_in_frustum":camera.is_position_in_frustum(mesh.global_transform*mesh.get_aabb().get_center())})
	var projected: Dictionary = {}
	var trace: Dictionary = actor.get_attack_trace()
	var points := {"root":actor.global_position,"body_proxy":actor.global_position+Vector3.UP*0.8,
		"head_proxy":actor.global_position+Vector3.UP*1.5,"latest_native_contact":trace.contact}
	for key: String in points:
		var point: Vector3 = points[key]
		var behind := camera.is_position_behind(point)
		var screen := camera.unproject_position(point) if not behind else Vector2.ZERO
		projected[key] = {"world":_v(point),"behind_camera":behind,"in_frustum":camera.is_position_in_frustum(point),
			"logical_screen_point":[screen.x,screen.y] if not behind else []}
	return {"label":label,"ms":Time.get_ticks_msec(),"physics_frame":Engine.get_physics_frames(),
		"actor_visible":actor.visible,"actor_visible_in_tree":actor.is_visible_in_tree(),"visual_root_visible":actor.visual_root.is_visible_in_tree(),
		"color_mesh_candidates":color_candidates,"meshes":meshes,"points":projected,
		"camera":{"same_existing_owner":camera==_game.camera_rig.camera,"position":_v(camera.global_position),
			"basis_x":_v(camera.global_basis.x),"basis_y":_v(camera.global_basis.y),"basis_z":_v(camera.global_basis.z),
			"activity_view":_game.camera_rig.save_activity_view(),"fov":camera.fov,"current":camera.is_current(),
			"distance_to_player":camera.global_position.distance_to(_game.player.global_position)},
		"driver":{"distance_suspended":driver.distance_suspended,"externally_ticked":driver.externally_ticked,
			"manual_update_interval":driver.manual_update_interval,"can_process":driver.can_process(),"state":str(driver.current_state),
			"action_active":driver.action_active,"action_elapsed":driver.action_elapsed,"active_action_clip":str(driver.active_action_clip),
			"action_duration":driver.action_duration,"current_playback_scale":driver.current_playback_scale,
			"runtime_animation_graph":graph_clock,"source_library_player_clock":library_clock},
		"note":"Visibility/frustum are renderer eligibility diagnostics, not a pixel visibility or visual acceptance claim; body/head points are labelled approximate proxies."}

func _wait_for_arena_ready(coordinator: Variant, transition_count: int, failures_before: int, epoch: int, started: int) -> bool:
	var deadline: int = started+RuntimePacks.PREPARATION_TIMEOUT_MSEC
	var resolution := ""
	var ready := false
	while resolution.is_empty():
		var world: Dictionary = _game.world_transition.snapshot()
		var activation: Dictionary = coordinator.last_activation
		var published: bool = str(_game.current_zone_id)=="wychwood" and not _game.zone_transition_pending \
			and str(activation.get("state",""))=="playable" and str(world.active_zone_id)=="wychwood"
		var owns: bool = _game.zone_runtime_coordinator==coordinator and int(coordinator.transition_count)==transition_count \
			and str(activation.get("zone",""))=="wychwood" and (int(world.epoch)==epoch or published)
		# Publication clears the travel target and later background prefetch may
		# advance its epoch; the actual coordinator/count still owns that arrival.
		if not owns:
			resolution = "ownership_lost"
		elif published and is_instance_valid(_game.zone_root) and is_instance_valid(_game.player) \
			and bool(activation.get("support_ready",false)) and bool(_game.player.can_control):
			ready = true
			resolution = "playable"
		elif int(coordinator.failure_count)>failures_before or not str(world.failure).is_empty():
			resolution = "explicit_failure"
		elif Time.get_ticks_msec()>=deadline:
			resolution = "deadline"
		if resolution.is_empty(): await _tree.process_frame
	_preparation_receipt = {"budget_clock":"monotonic_wall","budget_msec":RuntimePacks.PREPARATION_TIMEOUT_MSEC,
		"started_msec":started,"deadline_msec":deadline,"elapsed_msec":Time.get_ticks_msec()-started,"resolution":resolution,"ready":ready,
		"expected_transition_count":transition_count,"expected_epoch":epoch,"final_transition_count":coordinator.transition_count,
		"failure_count_before":failures_before,"failure_count_after":coordinator.failure_count,"last_failure":coordinator.last_failure.duplicate(true),
		"final_activation":coordinator.last_activation.duplicate(true),"final_world_transition":_game.world_transition.snapshot(),
		"policy":"Coordinator/count ownership first; supported readiness wins at boundary; explicit failure before 120-second deadline; no runtime deadlines changed."}
	return ready

func _snapshot(actor: Node3D) -> Dictionary:
	return {"actor":actor,"position":actor.global_position,"yaw":actor.rotation.y,"home":actor.home_position,"active":actor.encounter_active}

func _progression_snapshot() -> Dictionary:
	var state: Dictionary = _game.quests.save_state()
	return {"active":state.active,"completed_objectives":state.completed_objectives,"completed":state.completed,"unlocked":state.unlocked}

func _fixture_exclusions() -> Array[RID]:
	var result: Array[RID] = super._fixture_exclusions()
	if is_instance_valid(_owned_bog) and not result.has(_owned_bog.get_rid()): result.append(_owned_bog.get_rid())
	return result

func _generic_anchor_preflight(label: String) -> void:
	var space: PhysicsDirectSpaceState3D = _game.zone_root.get_world_3d().direct_space_state
	var geometry := SupportGeometry.new()
	var excluded: Array[RID] = [_game.player.get_rid()]
	for offset: Vector3 in [Vector3.ZERO,Vector3(0,0,-4),Vector3(3,0,-3),Vector3(-3,0,-3),Vector3(0,0,-7),Vector3(4,0,0),Vector3(-4,0,0)]:
		var requested: Vector3 = Saga.BOG_CENTER+offset
		var ray := PhysicsRayQueryParameters3D.create(requested+Vector3.UP*2,requested-Vector3.UP*2,1,excluded)
		var raw := space.intersect_ray(ray)
		var support: Vector3 = geometry.support_point(space,requested,excluded,1.5)
		var record := {"phase":label,"requested":_v(requested),"support_finite":support.is_finite(),"raw_ray_hit":not raw.is_empty(),
			"original_source_selector_excludes":"player RID only; exactly the palette selector's generic preflight"}
		if not raw.is_empty():
			record.merge({"raw_point":_v(raw.position),"raw_normal":_v(raw.normal),"raw_collider":str(raw.collider.get_path()),
				"normal_y_pass":raw.normal.y>=0.7,"height_delta_pass":absf(float(raw.position.y)-requested.y)<=1.5})
		if support.is_finite():
			var bank: int = _game.spatial_service.bank_for(support)
			var validated: Vector3 = _game.spatial_service.validate_position(support,0.5,bank)
			record.merge({"support":_v(support),"bank":bank,"validated":_v(validated),
				"projection_distance_pass":validated.distance_squared_to(support)<=0.25,
				"river_pass":not _game.spatial_service.is_river_excluded(support,0.5),
				"authored_exclusion_pass":not _game.spatial_service._inside_entries(support,_game.spatial_service.exclusions,0.5),
				"generic_capsule_clear":not _game.spatial_service.is_position_occupied(support,0.26,1.65),
				"generic_walkable":_game.spatial_service.is_walkable_position(support,0.5,bank)})
		_generic_probes.append(record)

func _select_corridor(actor: Node3D, distance: float) -> Dictionary:
	var body := _fixture_collision(actor)
	var player_body := _fixture_collision(_game.player)
	if body==null or player_body==null: return {}
	var start_floor := _fixture_floor(Saga.BOG_CENTER)
	if start_floor.is_empty():
		_setup_probes.append({"phase":_phase,"accepted":false,"reason":"No actual floor at exact Saga BOG_CENTER"})
		return {}
	var body_height := float(body.shape.height)
	var player_height := float(player_body.shape.height)
	var actor_root: Vector3 = start_floor.position+Vector3.UP*(body_height*0.5-body.position.y+0.015)
	for degrees: float in [0.0,15.0,-15.0,30.0,-30.0]:
		var radial := Vector3.BACK.rotated(Vector3.UP,deg_to_rad(degrees))
		var candidate: Vector3 = Saga.BOG_CENTER+radial*distance
		var player_floor := _fixture_floor(candidate)
		var record := {"phase":_phase,"actor":"bog_wretch","candidate":_v(candidate),"accepted":false,"authored_actor_anchor":_v(Saga.BOG_CENTER),
			"collision_height":body_height,"collision_radius":body.shape.radius,"collision_layer":actor.collision_layer,"leash_radius":actor.leash_radius}
		if player_floor.is_empty():
			record.reason = "missing actual player floor"
			_setup_probes.append(record)
			continue
		var player_root: Vector3 = player_floor.position+Vector3.UP*(player_height*0.5-player_body.position.y+0.015)
		var radius: float = actor.tactics.engagement_radius(actor.preferred_distance,actor.attack_range,true,0.0,0.0,actor.enemy_navigation_view.READY_APPROACH_MARGIN)
		var side: float = float(actor.flank_sign)
		if actor.encounter_slot>0: side = -1.0 if actor.encounter_slot%2==0 else 1.0
		var goal: Vector3 = player_root+(-radial).rotated(Vector3.UP,deg_to_rad(float(actor.approach_angle_degrees)*side))*radius
		var goal_floor := _fixture_floor(goal)
		var floor_safe := not goal_floor.is_empty()
		var count := maxi(2,ceili(actor_root.distance_to(goal)/0.30))
		for index in range(count+1):
			var floor_hit := _fixture_floor(actor_root.lerp(goal,float(index)/count))
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
		var projected := Vector2(validated.x-goal.x,validated.z-goal.z).length()>0.01
		var endpoint_ok := not route.is_empty() and Vector2(route.back().x-goal.x,route.back().z-goal.z).length()<=0.01
		record.merge({"actor_root":_v(actor_root),"player_root":_v(player_root),"raw_goal":_v(goal),"validated_goal":_v(validated),
			"actor_sweep":sweep,"player_occupancy":player_clear,"authored_segment_clear":authored_clear,"route_points":route.size(),
			"goal_not_projected":not projected,"route_endpoint_matches":endpoint_ok,"player_within_authored_leash":distance<float(actor.leash_radius)})
		record.accepted = bool(sweep.clear) and bool(player_clear.clear) and authored_clear and not projected and endpoint_ok and distance<float(actor.leash_radius)
		_setup_probes.append(record)
		if record.accepted: return {"player_root":player_root,"actor_root":actor_root}
	return {}
