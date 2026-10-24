extends Node
class_name SeamlessWorldService

const WorldSectorManifest = preload("res://scripts/world_sector_manifest.gd")

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

func configure(runtime_host: Node, stream_service: Node) -> void:
	host = runtime_host
	streaming_service = stream_service
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().node_added.is_connected(_construction_node_added):
		get_tree().node_added.connect(_construction_node_added)
	if not host.story_state.changed.is_connected(_sources_changed):
		host.story_state.changed.connect(_sources_changed)
	if not host.quests.changed.is_connected(_sources_changed):
		host.quests.changed.connect(_sources_changed)

func _sources_changed() -> void:
	_story_epoch += 1

func _construction_node_added(node: Node) -> void:
	if host != null and host.neighbor_building and _neighbor_scope != null and is_instance_valid(_neighbor_scope.owned_root) and _neighbor_scope.owned_root.is_ancestor_of(node):
		_added_nodes.append(weakref(node))

func _process(delta: float) -> void:
	_sync_resident_camera()
	if _foreground: return
	if not is_instance_valid(host) or not host.game_started or host.resource_shutdown_prepared:
		cancel_preparation(); return
	if _neighbor_scope != null and (not is_instance_valid(_neighbor_scope.owned_root) or _neighbor_quality != str(host.settings.settings.get("quality_preset","balanced"))): cancel_preparation()
	var target := "wychwood" if str(host.current_zone_id) == "greyfen" else ("greyfen" if str(host.current_zone_id) == "wychwood" else "")
	if target.is_empty(): cancel_preparation(); return
	if _neighbor_scope != null and _neighbor_scope.zone_id != target: cancel_preparation()
	if get_tree().paused or host._journey_load_pending() or not is_instance_valid(host.player) or not host.player.can_control or host._story_has_active_combat(): return
	if host.opening_checkpoint_pending or host.opening_detail_pending or host.zone_transition_pending: return
	if host.player.velocity.length_squared() > 0.25 or host.player.bow_aiming: return
	_poll += delta
	if _poll < 0.06: return
	_poll = 0.0
	if _valid_cached_destination(target): return
	if _neighbor_state == "ready":
		if _neighbor_epoch != _story_epoch: cancel_preparation()
		return
	if _neighbor_scope != null and _neighbor_epoch != _story_epoch:
		cancel_preparation(); return
	if _neighbor_scope == null:
		var approach := -5.0 if target == "wychwood" else 5.0
		if (target == "wychwood" and host.player.position.z > approach) or (target == "greyfen" and host.player.position.z < approach) or Time.get_ticks_msec() < _retry_after: return
		if host.runtime_packs != null:
			host.runtime_packs.request_zone_packs(target)
			if not host.runtime_packs.zone_packs_ready(target): return
		if streaming_service != null:
			streaming_service.request_zone(target)
			if not streaming_service.is_ready(target): return
		_begin_neighbor(target); return
	_advance_preparation()

func _advance_preparation() -> void:
	_added_nodes.clear()
	_neighbor_scope.run_step(_build_neighbor_step)
	for reference: WeakRef in _added_nodes:
		var node: Node = reference.get_ref()
		if is_instance_valid(node): host.zone_residency.suspend_node(_neighbor_scope.owned_root,node)
	_added_nodes.clear()
	_neighbor_step += 1
	if not _neighbor_failure.is_empty():
		var error := _neighbor_failure
		cancel_preparation(); _neighbor_failure = error; _retry_after = Time.get_ticks_msec()+30000
		push_warning("Prepared neighbor failed; ordinary travel remains available: " + error)

func has_prepared(zone_id: String) -> bool:
	if _valid_cached_destination(zone_id): return true
	return _neighbor_scope != null and is_instance_valid(_neighbor_scope.owned_root) and _neighbor_scope.zone_id == zone_id and _neighbor_state == "ready" and _neighbor_quality == str(host.settings.settings.get("quality_preset","balanced")) and _neighbor_signature == host._zone_state_signature(zone_id)

func _valid_cached_destination(zone_id: String) -> bool:
	var root: Node3D = host.route_zone_cache.get(zone_id)
	if not is_instance_valid(root): return false
	var quality := str(host.settings.settings.get("quality_preset","balanced"))
	if root != _cached_root or _cached_epoch != _story_epoch or _cached_quality != quality:
		_cached_root = root; _cached_epoch = _story_epoch; _cached_quality = quality
		_cached_valid = int(host.route_zone_signatures.get(zone_id,-1)) == host._zone_state_signature(zone_id)
	return _cached_valid

func finish_preparation(zone_id: String, keep_waiting: Callable) -> bool:
	if has_prepared(zone_id): return true
	if _neighbor_scope != null and (_neighbor_scope.zone_id != zone_id or _neighbor_quality != str(host.settings.settings.get("quality_preset","balanced")) or _neighbor_epoch != _story_epoch): cancel_preparation()
	if _neighbor_scope == null: _begin_neighbor(zone_id)
	if _neighbor_scope == null: return false
	_foreground = true
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec() < deadline and keep_waiting.call():
		# Present progress before construction, without discarding an in-flight
		# valid context and rebuilding it merely because the player reached the exit.
		await get_tree().process_frame
		if not keep_waiting.call() or _neighbor_scope == null: break
		if _neighbor_epoch != _story_epoch or _neighbor_quality != str(host.settings.settings.get("quality_preset","balanced")):
			_neighbor_failure = "The destination changed during preparation."; break
		_advance_preparation()
		if _neighbor_scope == null: break
		if _neighbor_state == "ready":
			_foreground = false; return true
		var total: int = host.OPENING_DETAIL_STAGES.size()+3 if zone_id == "greyfen" else int(_neighbor_builder.BUILD_STEPS)+2
		host.hud.update_journey_load_progress(zone_id,float(_neighbor_step)/float(total),"Preparing the complete destination...")
	_foreground = false
	cancel_preparation()
	return false

func _begin_neighbor(target: String) -> void:
	var paths: Dictionary = preload("res://scripts/zone_composition_router.gd").CORE_BUILDER_PATHS
	var builder_script := load(str(paths.get(target,""))) as Script
	if builder_script == null or not builder_script.can_instantiate():
		_neighbor_failure = "The destination builder could not be loaded: " + target
		_retry_after = Time.get_ticks_msec()+30000
		return
	host._trim_route_zone_cache([])
	_neighbor_view = SubViewport.new(); _neighbor_view.name = "PreparedNeighborWorld"
	_neighbor_view.size = Vector2i(2,2); _neighbor_view.own_world_3d = true
	_neighbor_view.gui_disable_input = true
	_neighbor_view.physics_object_picking = false
	_neighbor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_neighbor_view)
	var root := Node3D.new(); root.name = target; root.process_mode = Node.PROCESS_MODE_DISABLED
	_neighbor_view.add_child(root)
	var spatial: Node3D = host.ZoneSpatialService.new()
	spatial.name = "PreparedSpatialService"; root.add_child(spatial)
	spatial.configure(target,host._river_center(target),host._zone_half_extents(target))
	_neighbor_scope = ZoneBuildContext.new(host,target,"opening_boot" if target == "greyfen" else "full")
	_neighbor_scope.own(root,spatial)
	_neighbor_builder = builder_script.new()
	_neighbor_quality = str(host.settings.settings.get("quality_preset","balanced"))
	_neighbor_epoch = _story_epoch; _neighbor_step = 0; _neighbor_state = "building"; _neighbor_failure = ""

func _build_neighbor_step(context: ZoneBuildContext) -> void:
	var greyfen := context.zone_id == "greyfen"
	var steps: int = host.OPENING_DETAIL_STAGES.size()+1 if greyfen else int(_neighbor_builder.BUILD_STEPS)
	if _neighbor_step == 0:
		var layers: Dictionary = host.ZoneSceneCatalog.attach(context.zone_id,context.zone_root,["gameplay"] if greyfen else ["gameplay","decoration"])
		if not bool(layers.ok): _neighbor_failure = str(layers.errors); return
	if _neighbor_step < steps:
		if greyfen:
			if _neighbor_step == 0: _neighbor_builder.build(context)
			else:
				context.build_profile = "opening_detail"
				_neighbor_builder.build_detail_stage(context,str(host.OPENING_DETAIL_STAGES[_neighbor_step-1]))
		else: _neighbor_builder.build_step(context,_neighbor_step)
	elif _neighbor_step == steps:
		host._flush_environment_batches()
		host._install_world_prop_controller(context.zone_id)
		host._add_visual_100_layer(context.zone_id)
		host._apply_first_route_materials(context.zone_root)
	elif _neighbor_step == steps+1:
		context.owned_fields.spatial_service.build_navigation(context.zone_root)
		host._validate_zone_render_resources(context.zone_root)
		var result := context.validate()
		if not bool(result.ok): _neighbor_failure = str(result.errors); return
		for enemy: Node in host.active_enemies:
			if not is_instance_valid(enemy.visual_root):
				_neighbor_failure = "Missing required body: " + str(enemy.enemy_id); return
		context.zone_root.set_meta("opening_detail_complete",true)
		context.zone_root.set_meta("prepared_neighbor_complete",true)
		context.zone_root.set_meta("runtime_light_count",host.runtime_light_count)
		_neighbor_state = "ready"; _neighbor_signature = host._zone_state_signature(context.zone_id)

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
	_neighbor_view.own_world_3d = false
	var camera := Camera3D.new(); camera.name = "ResidentCamera"
	_neighbor_view.add_child(camera); camera.current = true
	_neighbor_scope = null; _neighbor_builder = null
	_neighbor_view = null; _neighbor_state = "idle"
	return true

func _sync_resident_camera() -> void:
	if not is_instance_valid(host) or not is_instance_valid(host.zone_root): return
	var parent: Node = host.zone_root.get_parent()
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
	if is_instance_valid(_neighbor_view): _neighbor_view.queue_free()
	_neighbor_view = null; _neighbor_scope = null; _neighbor_builder = null
	_neighbor_state = "idle"; _neighbor_step = 0; _added_nodes.clear()

func preparation_snapshot() -> Dictionary:
	return {"state":_neighbor_state,"zone":_neighbor_scope.zone_id if _neighbor_scope != null else "","step":_neighbor_step,"failure":_neighbor_failure,"complete":_neighbor_state == "ready"}

func _exit_tree() -> void:
	cancel_preparation()
	if get_tree().node_added.is_connected(_construction_node_added): get_tree().node_added.disconnect(_construction_node_added)

func open_edges_for(zone_id: String) -> Dictionary:
	return WorldSectorManifest.open_edges(zone_id)

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
	return is_exterior_route(source_zone, target_zone)

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
	if cooldown > 0.0 or not WorldSectorManifest.is_exterior(source):
		return false
	var bounds := _zone_bounds(source)
	var edge := WorldSectorManifest.edge_for_position(source, actor.global_position, bounds, 0.85)
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
	if not WorldSectorManifest.edge_available(edge,host.quests if host != null else null):
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
	var defer_neighbor_prewarm: bool = host != null and host.has_method("should_defer_neighbor_prewarm") and host.should_defer_neighbor_prewarm()
	# Greyfen is also activated during the menu prewarm/New Game handoff. Do not
	# start adjacent scene imports from that synchronous activation path; the
	# host schedules the same work after the opening checkpoint window.
	if streaming_service != null and normalized != "greyfen" and not defer_neighbor_prewarm:
		for neighbor in WorldSectorManifest.neighbors(normalized):
			if streaming_service.has_method("request_zone"):
				streaming_service.request_zone(neighbor)
		if streaming_service.has_method("retire_unneeded_zones"):
			streaming_service.retire_unneeded_zones(active_sector_ids)
	sector_activated.emit(normalized)

func on_zone_failed(zone_id: String, reason: String) -> void:
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
