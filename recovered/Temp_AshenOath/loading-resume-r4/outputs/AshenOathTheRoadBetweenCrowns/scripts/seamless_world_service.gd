extends Node
class_name SeamlessWorldService

const WorldSectorManifest = preload("res://scripts/world_sector_manifest.gd")
const APPROACH_RADIUS := 18.0
const COMMIT_RADIUS := 9.0
const FIRST_CONTROL_GRACE := 2.0
const BUILD_SLICE_USEC := 1500

signal boundary_transition_requested(source_zone: String, target_zone: String, edge_id: String)
signal sector_activated(zone_id: String)
signal sector_failed(zone_id: String, reason: String)

var host: Node
var streaming_service: Node
var current_sector := ""
var previous_sector := ""
var pending_transition: Dictionary = {}
var discovered_sectors: Dictionary = {}
var active_sector_ids: Array[String] = []
var transition_count := 0
var failed_transition_count := 0
var last_transition: Dictionary = {}
var last_world_position := Vector3.ZERO
var cooldown := 0.0
var _arrival_edge := ""
var _neighbor_scope: ZoneBuildContext
var _neighbor_view: SubViewport
var _neighbor_builder: RefCounted
var _neighbor_step := 0
var _neighbor_state := "idle"
var _neighbor_quality := ""
var _neighbor_signature := 0
var _neighbor_epoch := 0
var _story_epoch := 0
var _neighbor_failure := ""
var _added_nodes: Array[WeakRef] = []
var _poll := 0.0
var _retry_after := 0
var _foreground := false
var _active_view: SubViewport
var _cached_root: Node3D
var _cached_epoch := -1
var _cached_quality := ""
var _cached_valid := false
var _selected_connection: Dictionary = {}
var _crossing: Dictionary = {}
var _preview_root: Node3D
var _playable_seconds := 0.0
var _build_cooldown := 0.0
var _last_step_usec := 0
var _selection_reason := ""

func configure(runtime_host: Node, stream_service: Node) -> void:
	host = runtime_host
	streaming_service = stream_service
	process_mode = Node.PROCESS_MODE_ALWAYS
	if host.runtime_packs != null:
		host.runtime_packs.background_work_allowed = _background_work_allowed
	if not get_tree().node_added.is_connected(_construction_node_added):
		get_tree().node_added.connect(_construction_node_added)
	if not host.story_state.changed.is_connected(_sources_changed):
		host.story_state.changed.connect(_sources_changed)
	if not host.quests.changed.is_connected(_sources_changed):
		host.quests.changed.connect(_sources_changed)

func _sources_changed() -> void:
	_story_epoch += 1

func _background_work_allowed() -> bool:
	return is_instance_valid(host) and not host.resource_shutdown_prepared \
		and host.game_started and _playable_seconds >= FIRST_CONTROL_GRACE \
		and not get_tree().paused and not host._journey_load_pending() \
		and is_instance_valid(host.player) and host.player.can_control \
		and not host.player.bow_aiming and not host._story_has_active_combat() \
		and not host.opening_checkpoint_pending and not host.zone_transition_pending

func _construction_node_added(node: Node) -> void:
	if _neighbor_scope != null and is_instance_valid(_neighbor_scope.owned_root) and _neighbor_scope.owned_root.is_ancestor_of(node):
		_added_nodes.append(weakref(node))

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not host.game_started or host.resource_shutdown_prepared:
		cancel_preparation(); return
	_sync_resident_camera()
	if _foreground: return
	if _neighbor_scope != null and (not is_instance_valid(_neighbor_scope.owned_root) or _neighbor_quality != str(host.settings.settings.get("quality_preset","balanced"))): cancel_preparation()
	if get_tree().paused or host._journey_load_pending() or not is_instance_valid(host.player) or not host.player.can_control or host._story_has_active_combat(): return
	if host.opening_checkpoint_pending or host.opening_detail_pending or host.zone_transition_pending: return
	if host.player.bow_aiming: return
	_playable_seconds += delta
	_build_cooldown = maxf(0.0, _build_cooldown - delta)
	if _playable_seconds < FIRST_CONTROL_GRACE: return
	_poll += delta
	if _poll < 0.06: return
	_poll = 0.0
	_selected_connection = _preparation_connection()
	if _selected_connection.is_empty(): return
	var target := str(_selected_connection.target)
	if _neighbor_scope != null and _neighbor_scope.zone_id != target: cancel_preparation()
	# Cold activation starts just before the common plane. Retain the source
	# half while it still supports Kael, even if a state change invalidated it.
	if contains_resident_passage(host.player.global_position) and not WorldSectorManifest.connector_contains(str(host.current_zone_id),host.player.global_position): return
	if _valid_cached_destination(target):
		if _connection_distance(_selected_connection) < APPROACH_RADIUS: _show_neighbor(_selected_connection)
		return
	if _neighbor_state == "ready":
		if not _neighbor_dependencies_current(): cancel_preparation()
		elif _connection_distance(_selected_connection) < APPROACH_RADIUS: _show_neighbor(_selected_connection)
		return
	if _neighbor_scope != null and not _neighbor_dependencies_current():
		cancel_preparation(); return
	if _neighbor_scope == null:
		if Time.get_ticks_msec() < _retry_after: return
		if host.runtime_packs != null:
			var extras: Array[String] = host._zone_encounter_packs(target)
			# Share the ordinary hash-validated downloads without giving speculative
			# travel the priority of an explicit Continue or journey request.
			for pack_id: String in host.runtime_packs.required_zone_packs(target,extras):
				host.runtime_packs.request_pack(pack_id,500)
			if not host.runtime_packs.zone_packs_ready(target,extras): return
		if streaming_service != null:
			streaming_service.request_zone(target)
			if not streaming_service.is_ready(target): return
		_begin_neighbor(target); return
	if _build_cooldown > 0.0: return
	var slice_started := Time.get_ticks_usec()
	while _neighbor_scope != null and _neighbor_state == "building":
		_advance_preparation()
		if Time.get_ticks_usec() - slice_started >= BUILD_SLICE_USEC:
			break
	# A Godot scene publication is atomic. Repay an over-budget step with quiet
	# frames instead of stacking expensive steps on an already slow frame.
	var spent := float(Time.get_ticks_usec() - slice_started) / 1000000.0
	_build_cooldown = minf(0.25, spent * 4.0)
	if delta > 1.0 / 30.0: _build_cooldown = maxf(_build_cooldown,0.10)
	if _neighbor_scope != null and _neighbor_state == "building":
		# Continue on the next frame, not after another 60-ms routing poll.
		_poll = 0.06

func _nearest_connection() -> Dictionary:
	if not is_instance_valid(host.player): return {}
	var best: Dictionary = {}
	var distance := APPROACH_RADIUS
	for edge: Dictionary in WorldSectorManifest.connections(str(host.current_zone_id)):
		if not WorldSectorManifest.edge_available(edge,host.quests,host.story_state): continue
		var proximity := _connection_distance(edge)
		if proximity < distance:
			distance = proximity; best = edge
	return best

func _connection_distance(edge: Dictionary) -> float:
	var points := WorldSectorManifest.connector_points(edge)
	var point := Vector2(host.player.position.x,host.player.position.z)
	var proximity := INF
	for i in range(points.size()-1):
		proximity = minf(proximity,point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(points[i].x,points[i].z),Vector2(points[i+1].x,points[i+1].z))))
	return proximity

func _preparation_connection() -> Dictionary:
	var source := str(host.current_zone_id)
	var near := _nearest_connection()
	var retained: Dictionary = {}
	if _neighbor_scope != null:
		retained = WorldSectorManifest.connection_between(source,_neighbor_scope.zone_id)
	elif not _selected_connection.is_empty() and str(_selected_connection.get("source","")) == source:
		retained = _selected_connection
	if not retained.is_empty() and not WorldSectorManifest.edge_available(retained,host.quests,host.story_state): retained = {}
	if not retained.is_empty() and str(retained.target) == previous_sector and _connection_distance(retained) > APPROACH_RADIUS:
		retained = {}
	# Explicitly approaching a different road wins, but wandering between the
	# village services must not continually destroy a useful partial world.
	if not near.is_empty() and _connection_distance(near) < COMMIT_RADIUS:
		if retained.is_empty() or str(near.target) == str(retained.target) or _connection_distance(near)+4.0 < _connection_distance(retained):
			_selection_reason = "approached_road"
			return near
	if not retained.is_empty():
		_selection_reason = "retained_preparation"
		return retained
	var destination := ""
	if host.quest_presentation != null:
		destination = str(host.quest_presentation.get_objective_view_model().get("destination_zone",""))
	var objective_edge := WorldSectorManifest.connection_between(source,destination)
	if not objective_edge.is_empty() and WorldSectorManifest.edge_available(objective_edge,host.quests,host.story_state):
		_selection_reason = "current_objective"
		return objective_edge
	# The opening promise begins inside Greyfen; prepare its next road while
	# Kael talks and explores instead of waiting for the forest threshold.
	if source == "greyfen" and not host.quests.is_completed("main_road_of_crows"):
		_selection_reason = "opening_road"
		return WorldSectorManifest.connection_between(source,"wychwood")
	if not near.is_empty():
		_selection_reason = "nearest_available_road"
		return near
	var best: Dictionary = {}
	var distance := INF
	for edge: Dictionary in WorldSectorManifest.connections(source):
		if str(edge.target) == previous_sector or not WorldSectorManifest.edge_available(edge,host.quests,host.story_state): continue
		var proximity := _connection_distance(edge)
		if proximity < distance:
			best = edge; distance = proximity
	_selection_reason = "next_available_road"
	return best

func _show_neighbor(edge: Dictionary) -> void:
	var target := str(edge.target)
	if _neighbor_scope != null: publish_prepared(target)
	var root: Node3D = host.route_zone_cache.get(target)
	if not is_instance_valid(root): return
	if is_instance_valid(_preview_root) and _preview_root != root:
		host.zone_residency.end_preview(_preview_root)
		_preview_root.visible = false; _preview_root.position = Vector3(0,-1000,0)
	var placement := WorldSectorManifest.crossing_transform(edge).affine_inverse()
	if root.transform != placement: root.transform = placement
	root.visible = true
	host.zone_residency.begin_preview(root)
	# A validated resident destination may be entered. Keeping this leaf shut
	# until _crossing exists deadlocks warm travel: collision prevents Kael
	# reaching the plane which creates _crossing in the first place.
	preload("res://scripts/connected_route_geometry.gd").open_gate(host.zone_root,target,true)
	preload("res://scripts/connected_route_geometry.gd").open_gate(root,str(edge.source),true)
	_preview_root = root

func prepare_crossing_view() -> void:
	if _crossing.is_empty(): return
	_show_neighbor(WorldSectorManifest.connection_between(str(_crossing.source),str(_crossing.target)))

func crossing_for(zone_id: String) -> Dictionary:
	return _crossing if str(_crossing.get("target","")) == zone_id else {}

func contains_resident_passage(position: Vector3) -> bool:
	if not is_instance_valid(_preview_root) or _preview_root.is_queued_for_deletion() or not _preview_root.visible: return false
	return WorldSectorManifest.connector_contains(str(_preview_root.get_meta("zone_resource_id","")),_preview_root.to_local(position))

func complete_crossing(previous_root: Node3D) -> void:
	_preview_root = null
	if not _crossing.is_empty():
		# Cold fallback construction has no prepared preview to open these.
		# Never leave an arriving capsule inside the reverse readiness leaf.
		preload("res://scripts/connected_route_geometry.gd").open_gate(host.zone_root,str(_crossing.source),true)
	if not _crossing.is_empty() and is_instance_valid(previous_root):
		previous_root.transform = _crossing.transform
		previous_root.visible = true
		host.zone_residency.begin_preview(previous_root)
		preload("res://scripts/connected_route_geometry.gd").open_gate(previous_root,str(_crossing.target),true)
		_preview_root = previous_root
	_crossing = {}

func _advance_preparation() -> void:
	_added_nodes.clear()
	var started := Time.get_ticks_usec()
	var successful := _neighbor_scope.run_step(_build_neighbor_step)
	for reference: WeakRef in _added_nodes:
		var node: Node = reference.get_ref()
		if is_instance_valid(node): host.zone_residency.suspend_node(_neighbor_scope.owned_root,node)
	_added_nodes.clear()
	_last_step_usec = Time.get_ticks_usec()-started
	if successful:
		_neighbor_step += 1
		_neighbor_signature = host._zone_state_signature(_neighbor_scope.zone_id)
		_neighbor_epoch = _story_epoch
	elif _neighbor_failure.is_empty():
		_neighbor_failure = "Construction step %d did not complete for %s." % [_neighbor_step, _neighbor_scope.zone_id]
	if not _neighbor_failure.is_empty():
		var error := _neighbor_failure
		cancel_preparation(); _neighbor_failure = error; _retry_after = Time.get_ticks_msec()+30000
		push_warning("Prepared neighbor failed; ordinary travel remains available: " + error)

func _neighbor_dependencies_current() -> bool:
	if _neighbor_scope == null: return false
	if _neighbor_scope.cancelled or _neighbor_scope.generation != host.journey_arrival_generation:
		return false
	if _neighbor_epoch == _story_epoch: return true
	# A partial build's recorded reads grow after every successful step. Only
	# already-consumed state can invalidate it; later steps read current state.
	if _neighbor_step > 0 and _neighbor_signature != host._zone_state_signature(_neighbor_scope.zone_id): return false
	_neighbor_epoch = _story_epoch
	return true

func has_prepared(zone_id: String) -> bool:
	if _valid_cached_destination(zone_id): return true
	return _neighbor_scope != null and is_instance_valid(_neighbor_scope.owned_root) and _neighbor_scope.zone_id == zone_id and _neighbor_state == "ready" and _neighbor_quality == str(host.settings.settings.get("quality_preset","balanced")) and _neighbor_signature == host._zone_state_signature(zone_id)

func _valid_cached_destination(zone_id: String, refresh: bool = false) -> bool:
	var root: Node3D = host.route_zone_cache.get(zone_id)
	if not is_instance_valid(root): return false
	var quality := str(host.settings.settings.get("quality_preset","balanced"))
	if refresh or root != _cached_root or _cached_epoch != _story_epoch or _cached_quality != quality:
		_cached_root = root; _cached_epoch = _story_epoch; _cached_quality = quality
		_cached_valid = int(host.route_zone_signatures.get(zone_id,-1)) == host._zone_state_signature(zone_id)
	return _cached_valid

func finish_preparation(zone_id: String, keep_waiting: Callable) -> bool:
	if has_prepared(zone_id): return true
	if _neighbor_scope != null and (_neighbor_scope.zone_id != zone_id or _neighbor_quality != str(host.settings.settings.get("quality_preset","balanced")) or not _neighbor_dependencies_current()): cancel_preparation()
	if _neighbor_scope == null: _begin_neighbor(zone_id)
	if _neighbor_scope == null: return false
	_foreground = true
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec() < deadline and keep_waiting.call():
		# Present progress before construction, without discarding an in-flight
		# valid context and rebuilding it merely because the player reached the exit.
		await get_tree().process_frame
		if not keep_waiting.call() or _neighbor_scope == null: break
		if not _neighbor_dependencies_current() or _neighbor_quality != str(host.settings.settings.get("quality_preset","balanced")):
			_neighbor_failure = "The destination changed during preparation."; break
		_advance_preparation()
		if _neighbor_scope == null: break
		if _neighbor_state == "ready":
			_foreground = false; return true
		var total: int = _construction_steps()+9
		host.hud.update_journey_load_progress(zone_id,float(_neighbor_step)/float(total),"Preparing the complete destination...")
	_foreground = false
	if _neighbor_failure.is_empty():
		_neighbor_failure = "Preparation cancelled." if not keep_waiting.call() else "Destination preparation exceeded its bounded deadline."
	cancel_preparation()
	return false

func _begin_neighbor(target: String) -> void:
	var paths: Dictionary = preload("res://scripts/zone_composition_router.gd").CORE_BUILDER_PATHS
	var builder_path := str(paths.get(target,preload("res://scripts/zone_composition_router.gd").CAMPAIGN_BUILDER_PATH))
	var builder_script := load(builder_path) as Script
	if builder_script == null or not builder_script.can_instantiate():
		_neighbor_failure = "The destination builder could not be loaded: " + target
		_retry_after = Time.get_ticks_msec()+30000
		return
	if is_instance_valid(_preview_root) and _preview_root != host.zone_root:
		preload("res://scripts/connected_route_geometry.gd").close_gate(host.zone_root,str(_preview_root.get_meta("zone_resource_id","")),host.player.global_position)
		_preview_root = null
	host._trim_route_zone_cache([])
	_neighbor_view = SubViewport.new(); _neighbor_view.name = "PreparedNeighborWorld"
	_neighbor_view.size = Vector2i(2,2); _neighbor_view.own_world_3d = true
	_neighbor_view.gui_disable_input = true
	_neighbor_view.physics_object_picking = false
	_neighbor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_neighbor_view)
	var root := Node3D.new(); root.name = target; root.process_mode = Node.PROCESS_MODE_DISABLED
	root.set_meta("zone_resource_owner","preparing")
	_neighbor_view.add_child(root)
	var spatial: Node3D = host.ZoneSpatialService.new()
	spatial.name = "PreparedSpatialService"; root.add_child(spatial)
	spatial.configure(target,host._river_center(target),host._zone_half_extents(target))
	_neighbor_scope = ZoneBuildContext.new(host,target,"opening_boot" if target == "greyfen" else "full")
	_neighbor_scope.own(root,spatial)
	_neighbor_scope.generation = host.journey_arrival_generation
	_neighbor_builder = builder_script.new()
	_neighbor_quality = str(host.settings.settings.get("quality_preset","balanced"))
	_neighbor_epoch = _story_epoch; _neighbor_step = 0; _neighbor_state = "building"; _neighbor_failure = ""

func _construction_steps() -> int:
	if _neighbor_scope.zone_id == "greyfen": return host.OPENING_DETAIL_STAGES.size()+1
	if _neighbor_builder.has_method("step_count"): return _neighbor_builder.step_count(_neighbor_scope.zone_id)
	return 1

func _build_neighbor_step(context: ZoneBuildContext) -> bool:
	var greyfen := context.zone_id == "greyfen"
	var steps := _construction_steps()
	if _neighbor_step == 0:
		var requested_layers: Array[String] = ["gameplay"]
		if not greyfen: requested_layers.append("decoration")
		var layers: Dictionary = host.ZoneSceneCatalog.attach(context.zone_id,context.zone_root,requested_layers)
		if not bool(layers.ok): _neighbor_failure = str(layers.errors); return false
	if _neighbor_step < steps:
		if greyfen:
			if _neighbor_step == 0: _neighbor_builder.build(context)
			else:
				context.build_profile = "opening_detail"
				_neighbor_builder.build_detail_stage(context,str(host.OPENING_DETAIL_STAGES[_neighbor_step-1]))
		elif _neighbor_builder.has_method("step_count"):
			if not _neighbor_builder.build_step(context, _neighbor_step): return false
		else: _neighbor_builder.build(context)
	elif _neighbor_step < steps+7:
		context.construction_host().flush_environment_batch_step(_neighbor_step-steps)
	elif _neighbor_step == steps+7:
		var builder := context.construction_host()
		builder._install_world_prop_controller(context.zone_id)
		builder._add_visual_100_layer(context.zone_id)
		builder._apply_first_route_materials(context.zone_root)
	elif _neighbor_step == steps+8:
		context.owned_fields.spatial_service.build_navigation(context.zone_root)
		host._validate_zone_render_resources(context.zone_root)
		var result := context.validate()
		if not bool(result.ok): _neighbor_failure = str(result.errors); return false
		for enemy: Node in context.owned_fields.active_enemies:
			if not is_instance_valid(enemy.visual_root):
				_neighbor_failure = "Missing required body: " + str(enemy.enemy_id); return false
		context.zone_root.set_meta("opening_detail_complete",true)
		context.zone_root.set_meta("prepared_neighbor_complete",true)
		context.zone_root.set_meta("prepared_arrival_pending",true)
		context.zone_root.set_meta("runtime_light_count",context.owned_fields.runtime_light_count)
		_neighbor_state = "ready"; _neighbor_signature = host._zone_state_signature(context.zone_id)
	return true

func publish_prepared(zone_id: String) -> bool:
	if _neighbor_scope == null: return false
	if not _neighbor_failure.is_empty() or _neighbor_state != "ready" or _neighbor_scope.zone_id != zone_id or _neighbor_signature != host._zone_state_signature(zone_id):
		cancel_preparation(); return false
	var root := _neighbor_scope.owned_root
	var spatial: Node = _neighbor_scope.owned_fields.spatial_service
	var enemies: Array = _neighbor_scope.owned_fields.active_enemies
	host.zone_residency.suspend_runtime(root)
	host._cache_route_zone(zone_id,root,enemies,_neighbor_signature)
	host._cache_route_spatial_service(zone_id,spatial)
	# Switching the viewport's world delivers world notifications without
	# _exit_tree(), preserving controller connections and the navigation owner.
	# The root is already hidden and displaced before joining the active world.
	_neighbor_view.set_meta("prepared_zone_view",true)
	# Godot 4.6.3 releases own_world before detaching the viewport's scenario.
	# Keep it alive until the world notifications and renderer handoff finish.
	var retiring_world: World3D = _neighbor_view.find_world_3d()
	_neighbor_view.own_world_3d = false
	retiring_world = null
	var camera := Camera3D.new(); camera.name = "ResidentCamera"
	# This query-only camera copies the live view every render tick; a second
	# physics interpolation schedule would smooth the copied pose twice.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_neighbor_view.add_child(camera); camera.current = true
	_neighbor_scope = null; _neighbor_builder = null
	_neighbor_view = null; _neighbor_state = "idle"
	return true

func _sync_resident_camera() -> void:
	if is_instance_valid(_preview_root): _sync_owner_camera(_preview_root)
	else: _preview_root = null
	if is_instance_valid(host) and is_instance_valid(host.zone_root): _sync_owner_camera(host.zone_root)

func _sync_owner_camera(root: Node3D) -> void:
	if not is_instance_valid(host) or not is_instance_valid(root) or root.is_queued_for_deletion(): return
	var parent: Node = root.get_parent()
	if parent == null: return
	_active_view = parent as SubViewport if parent.has_meta("prepared_zone_view") else null
	if not is_instance_valid(_active_view): return
	var source: Camera3D = host.get_viewport().get_camera_3d()
	var camera := _active_view.get_node("ResidentCamera") as Camera3D
	if not is_instance_valid(source): return
	# No second render pass: facial visibility queries still need the actual
	# camera frame and viewport dimensions when their root lives in this owner.
	_active_view.size = Vector2i(host.get_viewport().get_visible_rect().size)
	camera.global_transform = source.global_transform
	camera.projection = source.projection; camera.fov = source.fov
	camera.size = source.size; camera.near = source.near; camera.far = source.far
	camera.keep_aspect = source.keep_aspect; camera.frustum_offset = source.frustum_offset
	camera.h_offset = source.h_offset; camera.v_offset = source.v_offset

func cancel_preparation() -> void:
	if _neighbor_scope != null:
		_neighbor_scope.cancel()
	if is_instance_valid(_neighbor_view): _neighbor_view.queue_free()
	_neighbor_view = null; _neighbor_scope = null; _neighbor_builder = null
	_neighbor_state = "idle"; _neighbor_step = 0; _added_nodes.clear()

func preparation_snapshot() -> Dictionary:
	var result := _neighbor_scope.step_result(_neighbor_state) if _neighbor_scope != null else {"state":_neighbor_state,"zone":"","generation":0,"next_step":_neighbor_step,"error":_neighbor_failure}
	result.merge({"step":_neighbor_step,"failure":_neighbor_failure,"complete":_neighbor_state == "ready",
		"selected_destination":str(_selected_connection.get("target","")),"selection_reason":_selection_reason,
		"last_step_usec":_last_step_usec,"background_cooldown":_build_cooldown},true)
	return result

func _exit_tree() -> void:
	cancel_preparation()
	if is_instance_valid(host) and host.runtime_packs != null and host.runtime_packs.background_work_allowed == _background_work_allowed:
		host.runtime_packs.background_work_allowed = Callable()
	if get_tree().node_added.is_connected(_construction_node_added): get_tree().node_added.disconnect(_construction_node_added)

func open_edges_for(zone_id: String) -> Dictionary:
	var edges := WorldSectorManifest.open_edges(zone_id)
	for edge: Dictionary in WorldSectorManifest.connections(zone_id): edges[str(edge.id)] = edge
	return edges

func is_exterior_route(source_zone: String, target_zone: String) -> bool:
	return WorldSectorManifest.is_exterior(source_zone) \
		and WorldSectorManifest.is_exterior(target_zone) \
		and not WorldSectorManifest.edge_between(source_zone, target_zone).is_empty()

func is_interior_route(source_zone: String, target_zone: String) -> bool:
	var source := WorldSectorManifest.canonical(source_zone)
	var target := WorldSectorManifest.canonical(target_zone)
	return not is_exterior_route(source, target) \
		and target in WorldSectorManifest.neighbors(source) \
		and (not WorldSectorManifest.is_exterior(source) or not WorldSectorManifest.is_exterior(target))

func should_suppress_exterior_gate(source_zone: String, target_zone: String) -> bool:
	return not WorldSectorManifest.connection_between(source_zone,target_zone).is_empty()

func should_use_physical_door(source_zone: String, target_zone: String) -> bool:
	return is_interior_route(source_zone, target_zone)

func update_player(actor: Node3D, zone_id: String, delta: float) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	cooldown = maxf(cooldown - delta, 0.0)
	if not pending_transition.is_empty():
		return true
	var source := WorldSectorManifest.canonical(zone_id)
	if current_sector != source:
		on_zone_activated(source, actor.global_position)
	if cooldown <= 0.0:
		for connection: Dictionary in WorldSectorManifest.connections(source):
			if not WorldSectorManifest.edge_available(connection,host.quests,host.story_state): continue
			var frame := WorldSectorManifest.crossing_frame(connection)
			var point := frame.affine_inverse()*actor.global_position
			var threshold := 0.0 if has_prepared(str(connection.target)) else -1.25
			if point.z < threshold or point.z > 3.0 or absf(point.x) > float(connection.half_width): continue
			var normal := WorldSectorManifest.direction(str(connection.id))
			if actor.velocity.dot(normal) <= 0.05: continue
			var transform := WorldSectorManifest.crossing_transform(connection)
			_crossing = {"source":source,"target":str(connection.target),"transform":transform,"position":transform*actor.global_position,"velocity":transform.basis*actor.velocity,"basis":transform.basis*actor.global_basis}
			pending_transition = {"source":source,"target":str(connection.target),"edge":str(connection.id),"physical":true}
			if host.request_seamless_boundary_transition(str(connection.target),_crossing.position,str(connection.id)):
				transition_count += 1; return true
			_crossing = {}; pending_transition = {}
	if cooldown > 0.0 or not WorldSectorManifest.is_exterior(source):
		return false
	var bounds := _zone_bounds(source)
	var edge := WorldSectorManifest.edge_for_position(source, actor.global_position, bounds, 0.85)
	if not edge.is_empty() and not WorldSectorManifest.connection_between(source,str(edge.target)).is_empty(): return false
	# An older save may already be inside an exit. Require leaving that entry
	# trigger before it can fire, rather than bouncing back after the cooldown.
	if not _arrival_edge.is_empty():
		if str(edge.get("id", "")) == _arrival_edge:
			return false
		_arrival_edge = ""
	if edge.is_empty():
		return false
	# Automatic boundary entry must obey the same earned opening as the
	# authored gate; merely having a manifest edge cannot bypass that decision.
	if not WorldSectorManifest.edge_available(edge,host.quests if host != null else null,host.story_state if host != null else null):
		return false
	var target := WorldSectorManifest.canonical(str(edge.get("target", "")))
	if target == "" or host == null or not host.has_method("request_seamless_boundary_transition"):
		return false
	var raw_arrival: Array = edge.get("arrival", [0.0, 0.9, 12.0])
	var arrival := Vector3(float(raw_arrival[0]), float(raw_arrival[1]), float(raw_arrival[2]))
	if streaming_service != null and streaming_service.has_method("request_zone"):
		streaming_service.request_zone(target)
	pending_transition = {
		"source": source,
		"target": target,
		"edge": str(edge.get("id", "")),
		"arrival": arrival,
		"requested_at_usec": Time.get_ticks_usec(),
	}
	var accepted: bool = host.request_seamless_boundary_transition(target, arrival, str(edge.get("id", "")))
	if not accepted:
		pending_transition.clear()
		return false
	# The host can complete a synchronous local transition. Do not leave a
	# stale pending lock after the new sector has already been activated.
	if current_sector == target:
		pending_transition.clear()
	transition_count += 1
	last_transition = pending_transition.duplicate(true)
	boundary_transition_requested.emit(source, target, str(edge.get("id", "")))
	return true

func on_zone_activated(zone_id: String, local_position: Vector3 = Vector3.ZERO) -> void:
	_sync_resident_camera()
	var normalized := WorldSectorManifest.canonical(zone_id)
	if current_sector != "" and current_sector != normalized and host != null and bool(host.get("game_started")) and host.get("progression") != null:
		host.progression.record_saga_departure(current_sector, host.quests)
	previous_sector = current_sector if current_sector != normalized else previous_sector
	current_sector = normalized
	_selected_connection = {}
	_playable_seconds = 0.0
	_arrival_edge = str(WorldSectorManifest.edge_for_position(normalized, local_position,
		_zone_bounds(normalized), 0.85).get("id", ""))
	last_world_position = WorldSectorManifest.local_to_world(normalized, local_position)
	if normalized not in discovered_sectors:
		discovered_sectors[normalized] = true
	if normalized not in active_sector_ids:
		active_sector_ids.append(normalized)
	active_sector_ids = _kept_sector_ids(normalized)
	pending_transition.clear()
	cooldown = 0.25
	last_transition["state"] = "active"
	last_transition["activated_at_usec"] = Time.get_ticks_usec()
	# The background selector owns one useful neighbor after control settles.
	# Do not import every adjacent region synchronously at an arrival.
	if streaming_service != null:
		streaming_service.retire_unneeded_zones(active_sector_ids)
	sector_activated.emit(normalized)

func on_zone_failed(zone_id: String, reason: String) -> void:
	_crossing = {}
	failed_transition_count += 1
	pending_transition.clear()
	last_transition["state"] = "failed"
	last_transition["reason"] = reason
	sector_failed.emit(WorldSectorManifest.canonical(zone_id), reason)

func world_position_for_player(actor: Node3D, zone_id: String = "") -> Vector3:
	var source := WorldSectorManifest.canonical(zone_id if zone_id != "" else current_sector)
	if actor == null or not is_instance_valid(actor):
		return last_world_position
	last_world_position = WorldSectorManifest.local_to_world(source, actor.global_position)
	return last_world_position

func local_position_for(zone_id: String, world_position: Vector3) -> Vector3:
	return WorldSectorManifest.world_to_local(zone_id, world_position)

func save_state() -> Dictionary:
	return {
		"current_sector": current_sector,
		"previous_sector": previous_sector,
		"discovered_sectors": discovered_sectors.duplicate(true),
		"last_world_position": [last_world_position.x, last_world_position.y, last_world_position.z],
	}

func load_state(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	current_sector = WorldSectorManifest.canonical(str(data.get("current_sector", current_sector)))
	previous_sector = WorldSectorManifest.canonical(str(data.get("previous_sector", previous_sector)))
	discovered_sectors = data.get("discovered_sectors", {}).duplicate(true) if typeof(data.get("discovered_sectors", {})) == TYPE_DICTIONARY else {}
	var raw_position: Array = data.get("last_world_position", [])
	if raw_position.size() >= 3:
		last_world_position = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))

func snapshot() -> Dictionary:
	return {
		"current_sector": current_sector,
		"previous_sector": previous_sector,
		"pending_transition": pending_transition.duplicate(true),
		"active_sector_ids": active_sector_ids.duplicate(),
		"discovered_count": discovered_sectors.size(),
		"transition_count": transition_count,
		"failed_transition_count": failed_transition_count,
		"last_world_position": [last_world_position.x, last_world_position.y, last_world_position.z],
	}

func _zone_bounds(zone_id: String) -> Vector2:
	if host != null and host.has_method("get_zone_half_extents"):
		return host.get_zone_half_extents(zone_id)
	return WorldSectorManifest.bounds(zone_id)

func _kept_sector_ids(zone_id: String) -> Array[String]:
	var kept: Array[String] = [zone_id]
	for neighbor in WorldSectorManifest.neighbors(zone_id):
		if neighbor not in kept:
			kept.append(neighbor)
	return kept
