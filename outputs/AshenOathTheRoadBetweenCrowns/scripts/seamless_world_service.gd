extends Node
class_name SeamlessWorldService

const WorldSectorManifest = preload("res://scripts/world_sector_manifest.gd")
const APPROACH_RADIUS := 18.0
const COMMIT_RADIUS := 9.0
const FIRST_CONTROL_GRACE := 2.0
const BUILD_SLICE_USEC := 1500
const BASE_SLICE_USEC := 500
const PRIORITY_INTERVAL := 0.10
const SWITCH_ADVANTAGE := 4.0
const SWITCH_DWELL := 0.50
const ROAD_INTENT_RADIUS := 8.0
const AUTOMATIC_ROAD_RETRIES := 2

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
var _challenger := ""
var _challenger_elapsed := 0.0
var _jobs: Dictionary = {}
var _cache_order: Array[String] = []
var _cache_cursor := 0
var _cache_elapsed := 0.0
var _road_notice_after := 0
var _frame_usec := 0
var _frame_ms := 0.0
var _unit_overruns := 0
var _render_nodes: Array[WeakRef] = []
var _render_camera: Camera3D
var _render_current: GeometryInstance3D
var _render_layers := 0
var _render_frame := -1
var _render_drawn_frame := -1
var _render_done := false
var _render_requested_usec := 0
var _last_render_delay_usec := 0
var _render_groups: Dictionary = {}
var _entry_render_started := false
var _render_started_ms := 0
var _layer_cursor := 0
var _repeat_step := false
var _configuration_ready := false
var _neighbor_encounter_packs: Array[String] = []
var _neighbor_journey_id := ""
var _road_travel: Dictionary = {}
var _road_travel_serial := 0
var _road_commit_queued := false
const PREPARATION_RENDER_LAYER := 1 << 19

func configure(runtime_host: Node, stream_service: Node) -> void:
	host = runtime_host
	streaming_service = stream_service
	for id: String in WorldSectorManifest.all_ids():
		_jobs[id] = {"state":"queued","error":""}
	process_mode = Node.PROCESS_MODE_ALWAYS
	if host.runtime_packs != null:
		host.runtime_packs.background_work_allowed = _background_work_allowed
	if not get_tree().node_added.is_connected(_construction_node_added):
		get_tree().node_added.connect(_construction_node_added)
	if not host.story_state.changed.is_connected(_sources_changed):
		host.story_state.changed.connect(_sources_changed)
	if not host.quests.changed.is_connected(_sources_changed):
		host.quests.changed.connect(_sources_changed)
	if not RenderingServer.frame_post_draw.is_connected(_render_finished):
		RenderingServer.frame_post_draw.connect(_render_finished)

func _sources_changed() -> void:
	_story_epoch += 1
	_cache_order.clear()

func _background_work_allowed() -> bool:
	return is_instance_valid(host) and not host.resource_shutdown_prepared \
		and host.game_started and _playable_seconds >= FIRST_CONTROL_GRACE \
		and not get_tree().paused and not host._journey_load_pending() \
		and is_instance_valid(host.player) and host.player.can_control \
		and not host.player.bow_aiming and not host._story_has_active_combat() \
		and not host.zone_transition_pending

func _construction_node_added(node: Node) -> void:
	if _neighbor_scope != null and is_instance_valid(_neighbor_scope.owned_root) and _neighbor_scope.owned_root.is_ancestor_of(node):
		_added_nodes.append(weakref(node))
		if node is GeometryInstance3D: _render_nodes.append(weakref(node))

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	_frame_ms = float(now-_frame_usec)/1000.0 if _frame_usec > 0 else delta*1000.0
	_frame_usec = now
	if not is_instance_valid(host) or not host.game_started or host.resource_shutdown_prepared:
		cancel_preparation(); return
	_sync_resident_camera()
	if host._journey_load_pending():
		_clear_road_travel()
		return
	if _foreground: return
	if _neighbor_scope != null and (not is_instance_valid(_neighbor_scope.owned_root) or _neighbor_quality != str(host.settings.settings.get("quality_preset","balanced"))): cancel_preparation()
	if get_tree().paused or host._journey_load_pending() or not is_instance_valid(host.player) or not host.player.can_control or host._story_has_active_combat(): return
	if host.opening_detail_pending or host.zone_transition_pending: return
	if host.player.bow_aiming: return
	if _road_travel_current() and has_prepared(str(_road_travel.target)) and not _road_commit_queued:
		_road_commit_queued = true
		_commit_road_travel.call_deferred(_road_travel_serial)
	_playable_seconds += delta
	_build_cooldown = maxf(0.0, _build_cooldown - delta)
	if _playable_seconds < FIRST_CONTROL_GRACE: return
	_poll += delta
	_cache_elapsed += delta
	if _poll >= PRIORITY_INTERVAL:
		_poll = 0.0
		_selected_connection = _preparation_connection()
		_refresh_road_status()
		if _cache_order.is_empty(): _refresh_cache_order()
		if _cache_elapsed >= 0.50:
			_cache_elapsed = 0.0
			_cache_next_destination()
	if _selected_connection.is_empty(): return
	var target := str(_selected_connection.target)
	if _neighbor_scope != null and _neighbor_scope.zone_id != target:
		cancel_preparation()
		# Renderer-safe retirement owns the slot until it has released the root.
		return
	# Cold activation starts just before the common plane. Retain the source
	# half while it still supports Kael, even if a state change invalidated it.
	if contains_resident_passage(host.player.global_position) and not WorldSectorManifest.connector_contains(str(host.current_zone_id),host.player.global_position,0.0,host.story_state): return
	# A retained root does not imply that all of its current pack requirements
	# are mounted. Request them before the cached-root fast path, just as for a
	# cold destination, or has_prepared() can hold the return forever.
	if _neighbor_scope == null:
		var job: Dictionary = _jobs.get(target,{})
		if str(job.get("state","")) == "failed":
			if int(job.get("automatic_retries",0)) >= AUTOMATIC_ROAD_RETRIES or Time.get_ticks_msec() < int(job.get("retry_after",0)): return
			request_road(target,true,true)
		if host.runtime_packs != null:
			var extras: Array[String] = host._zone_encounter_packs(target)
			for pack_id: String in host.runtime_packs.required_zone_packs(target,extras):
				host.runtime_packs.request_pack(pack_id,500)
			var failures: Array[String] = host.runtime_packs.zone_pack_failures(target,extras)
			if not failures.is_empty():
				_record_job(target,"failed",", ".join(failures))
				return
			if not host.runtime_packs.zone_packs_ready(target,extras):
				_record_job(target,"resources")
				return
	if _valid_cached_destination(target):
		if _connection_distance(_selected_connection) < APPROACH_RADIUS: _show_neighbor(_selected_connection)
		return
	if host.zone_residency.pending_zone_retirements > 0: return
	if _neighbor_state == "ready":
		if not _neighbor_dependencies_current(): cancel_preparation()
		elif _connection_distance(_selected_connection) < APPROACH_RADIUS: _show_neighbor(_selected_connection)
		return
	if _neighbor_scope != null and not _neighbor_dependencies_current():
		cancel_preparation(); return
	if _neighbor_scope == null:
		if streaming_service != null:
			streaming_service.set_focus_destination(target)
			streaming_service.request_zone(target)
			if streaming_service.get_state(target) == "failed":
				_record_job(target,"failed","Destination resources could not be prepared."); return
			if not streaming_service.is_ready(target): return
		_begin_neighbor(target); return
	if _build_cooldown > 0.0: return
	if _neighbor_state == "render_pending":
		_advance_render_preparation()
		return
	var slice_started := Time.get_ticks_usec()
	var allowance := BASE_SLICE_USEC if _frame_ms >= 28.0 else mini(BUILD_SLICE_USEC,int((30.0-_frame_ms)*250.0))
	while _neighbor_scope != null and _neighbor_state == "building":
		_advance_preparation()
		if Time.get_ticks_usec() - slice_started >= allowance:
			break
	# A Godot scene publication is atomic. Repay an over-budget step with quiet
	# frames instead of stacking expensive steps on an already slow frame.
	var spent := float(Time.get_ticks_usec() - slice_started) / 1000000.0
	_build_cooldown = minf(0.25, spent * 4.0)
	if delta > 1.0 / 30.0: _build_cooldown = maxf(_build_cooldown,0.10)
	if _last_step_usec > BUILD_SLICE_USEC: _unit_overruns += 1

func _record_job(target: String, state: String, error: String = "") -> void:
	var job: Dictionary = _jobs.get(target,{})
	job.merge({"state":state,"error":error,"quality":str(host.settings.settings.get("quality_preset","balanced")),
		"generation":host.journey_arrival_generation,"journey_id":str(host.save_manager.journey_id)},true)
	if state == "failed" and str(job.get("last_error","")) != error:
		job["retry_after"] = Time.get_ticks_msec()+30000
		job["last_error"] = error
	_jobs[target] = job

func _refresh_cache_order() -> void:
	_cache_order.clear(); _cache_cursor = 0
	var visited: Dictionary = {str(host.current_zone_id):true}
	var frontier: Array[String] = [str(host.current_zone_id)]
	while not frontier.is_empty():
		var source: String = frontier.pop_front()
		for target: String in WorldSectorManifest.available_neighbors(source,host.quests,host.story_state):
			if visited.has(target): continue
			visited[target] = true
			_cache_order.append(target); frontier.append(target)
			if not _jobs.has(target): _record_job(target,"queued")

func _cache_next_destination() -> void:
	if host.runtime_packs == null or _cache_order.is_empty(): return
	var target := _cache_order[_cache_cursor % _cache_order.size()]
	_cache_cursor = (_cache_cursor+1) % _cache_order.size()
	var cached := true
	for id: String in host.runtime_packs.required_zone_packs(target,host._zone_encounter_packs(target)):
		host.runtime_packs.request_cached_pack(id,1500)
		if not host.runtime_packs.is_cached(id): cached = false
	if target != str(_selected_connection.get("target","")):
		_record_job(target,"cached" if cached else "downloading")
	var priorities: Array[String] = []
	if not _selected_connection.is_empty():
		priorities = host.runtime_packs.required_zone_packs(str(_selected_connection.target),host._zone_encounter_packs(str(_selected_connection.target)))
	host.runtime_packs.set_background_priorities(priorities)

func request_road(target: String, retry: bool = false, automatic_retry: bool = false) -> bool:
	var edge := WorldSectorManifest.connection_between(str(host.current_zone_id),target)
	if edge.is_empty() or not WorldSectorManifest.edge_available(edge,host.quests,host.story_state): return false
	_selected_connection = edge
	_selection_reason = "deliberate_road"
	_challenger = ""; _challenger_elapsed = 0.0
	if retry:
		var previous_job: Dictionary = _jobs.get(target,{})
		_jobs[target] = {"state":"queued","error":"","automatic_retries":int(previous_job.get("automatic_retries",0))+1 if automatic_retry else 0}
		if streaming_service != null and streaming_service.get_state(target) == "failed": streaming_service.cancel_request(target)
		if host.runtime_packs != null:
			for id: String in host.runtime_packs.required_zone_packs(target,host._zone_encounter_packs(target)):
				if host.runtime_packs.get_state(id) in ["failed","cancelled"]:
					host.runtime_packs.requests.erase(id)
					host.runtime_packs.request_pack(id,500)
	if not has_prepared(target) and Time.get_ticks_msec() >= _road_notice_after:
		var error := str((_jobs.get(target,{}) as Dictionary).get("error",""))
		host.hud.post_notice("Preparing the road to %s. You can keep exploring." % host._zone_display_name(target) if error.is_empty() else "Road preparation failed. Use the road to retry.","travel",2.5,"road_preparation")
		_road_notice_after = Time.get_ticks_msec()+3000
	return has_prepared(target)

func request_road_travel(target: String, arrival: Vector3) -> bool:
	var edge := WorldSectorManifest.connection_between(str(host.current_zone_id),target)
	if edge.is_empty() or not WorldSectorManifest.edge_available(edge,host.quests,host.story_state):
		host.hud.toast("That road is not open yet.")
		return false
	if not host.game_started or not is_instance_valid(host.player) or host._journey_load_pending(): return false
	_road_travel_serial += 1
	_road_commit_queued = false
	_road_travel = {"source":str(host.current_zone_id),"target":str(edge.target),"arrival":arrival,
		"anchor":host.player.global_position,"journey_id":str(host.save_manager.journey_id),
		"quality":str(host.settings.settings.get("quality_preset","balanced"))}
	request_road(str(edge.target),str((_jobs.get(str(edge.target),{}) as Dictionary).get("state","")) == "failed")
	return true

func _clear_road_travel() -> void:
	if _road_travel.is_empty(): return
	_road_travel.clear()
	_road_travel_serial += 1
	_road_commit_queued = false

func _road_travel_current() -> bool:
	if _road_travel.is_empty(): return false
	var valid: bool = host.game_started and not host.resource_shutdown_prepared \
		and is_instance_valid(host.player) and host.player.health_component.health > 0.0 \
		and str(_road_travel.source) == str(host.current_zone_id) \
		and str(_road_travel.journey_id) == str(host.save_manager.journey_id) \
		and str(_road_travel.quality) == str(host.settings.settings.get("quality_preset","balanced"))
	if valid:
		valid = host.player.global_position.distance_squared_to(_road_travel.anchor) <= ROAD_INTENT_RADIUS*ROAD_INTENT_RADIUS \
			and WorldSectorManifest.edge_available(WorldSectorManifest.connection_between(str(_road_travel.source),str(_road_travel.target)),host.quests,host.story_state)
	if not valid: _clear_road_travel()
	return valid

func _commit_road_travel(serial: int) -> void:
	if serial != _road_travel_serial: return
	_road_commit_queued = false
	if not _road_travel_current() or get_tree().paused or host._journey_load_pending(): return
	if not host.player.can_control or host.player.bow_aiming or host._story_has_active_combat(): return
	var target := str(_road_travel.target)
	if not has_prepared(target): return
	var arrival: Vector3 = _road_travel.arrival
	_clear_road_travel()
	host._request_zone_load(target,arrival)

func _refresh_road_status() -> void:
	if not is_instance_valid(host.zone_root): return
	for edge: Dictionary in WorldSectorManifest.connections(str(host.current_zone_id),host.story_state):
		var status: Node = host.zone_root.get_node_or_null("ConnectedRoads/RoadTo_"+str(edge.target)+"/TravelGate/RoadPreparation")
		var available := WorldSectorManifest.edge_available(edge,host.quests,host.story_state)
		var ready := available and has_prepared(str(edge.target))
		if is_instance_valid(status):
			status.set_interaction_enabled(available and not ready)
			var job: Dictionary = _jobs.get(str(edge.target),{})
			status.state_label = "Retry road" if str(job.get("state","")) == "failed" else "Prepare road"
		if not ready:
			preload("res://scripts/connected_route_geometry.gd").close_gate(host.zone_root,str(edge.target),host.player.global_position)
		var entrance: Node = host.zone_root.find_child("gate_"+str(edge.target),true,false)
		if is_instance_valid(entrance) and bool(entrance.get_meta("interactive_road_entrance",false)):
			var job: Dictionary = _jobs.get(str(edge.target),{})
			var label := "Road closed" if not available else ("Retry travel" if str(job.get("state","")) == "failed" else ("Preparing" if str(_road_travel.get("target","")) == str(edge.target) and not ready else ""))
			if entrance.state_label != label:
				entrance.state_label = label
				host.interaction_focus_dirty = true

func _nearest_connection() -> Dictionary:
	if not is_instance_valid(host.player): return {}
	var best: Dictionary = {}
	var distance := APPROACH_RADIUS
	for edge: Dictionary in WorldSectorManifest.connections(str(host.current_zone_id),host.story_state):
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
	if _road_travel_current():
		_selection_reason = "explicit_travel"
		return WorldSectorManifest.connection_between(source,str(_road_travel.target))
	var retained: Dictionary = {}
	if _neighbor_scope != null:
		retained = WorldSectorManifest.connection_between(source,_neighbor_scope.zone_id)
	elif not _selected_connection.is_empty() and str(_selected_connection.get("source","")) == source:
		retained = _selected_connection
	if not retained.is_empty() and not WorldSectorManifest.edge_available(retained,host.quests,host.story_state): retained = {}
	var destination := ""
	if host.quest_presentation != null:
		destination = str(host.quest_presentation.get_objective_view_model().get("destination_zone",""))
	var best: Dictionary = {}
	var score := INF
	for edge: Dictionary in WorldSectorManifest.connections(source,host.story_state):
		if not WorldSectorManifest.edge_available(edge,host.quests,host.story_state): continue
		var points := WorldSectorManifest.connector_points(edge)
		var toward: Vector3 = (points[0]-host.player.position).normalized()
		var approach := maxf(0.0,host.player.velocity.dot(toward))
		var value := _connection_distance(edge)-minf(4.0,approach)
		if str(edge.target) == destination: value -= 2.0
		if value < score: best = edge; score = value
	if best.is_empty(): return retained
	if retained.is_empty() or str(retained.target) == str(best.target):
		_challenger = ""; _challenger_elapsed = 0.0
		_selection_reason = "proximity_and_heading"
		return best
	var advantage := _connection_distance(retained)-_connection_distance(best)
	if _connection_distance(best) < COMMIT_RADIUS or advantage >= SWITCH_ADVANTAGE:
		if _challenger != str(best.target): _challenger = str(best.target); _challenger_elapsed = 0.0
		_challenger_elapsed += PRIORITY_INTERVAL
		if _connection_distance(best) < COMMIT_RADIUS or _challenger_elapsed >= SWITCH_DWELL:
			_selection_reason = "approached_road"; return best
	else:
		_challenger = ""; _challenger_elapsed = 0.0
	_selection_reason = "retained_preparation"
	return retained

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
	return WorldSectorManifest.connector_contains(str(_preview_root.get_meta("zone_resource_id","")),_preview_root.to_local(position),0.0,host.story_state)

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
	var layers: Array[String] = ["gameplay", "decoration"]
	if _neighbor_scope.zone_id == "greyfen": layers = ["gameplay"]
	var attach_layer := _layer_cursor < layers.size()
	var configure_runtime := not _configuration_ready
	_repeat_step = false
	var successful := _neighbor_scope.run_step(func(context: ZoneBuildContext) -> bool:
		if configure_runtime:
			if host._zone_requires_campaign_pack(context.zone_id): host.runtime_services.configure_campaign()
			return true
		if attach_layer:
			var one_layer: Array[String] = [layers[_layer_cursor]]
			var result: Dictionary = host.ZoneSceneCatalog.attach(context.zone_id,context.zone_root,one_layer)
			if not bool(result.ok): _neighbor_failure = str(result.errors)
			return bool(result.ok)
		return _build_neighbor_step(context))
	for reference: WeakRef in _added_nodes:
		var node: Node = reference.get_ref()
		if is_instance_valid(node): host.zone_residency.suspend_node(_neighbor_scope.owned_root,node)
	_added_nodes.clear()
	_last_step_usec = Time.get_ticks_usec()-started
	if successful:
		if configure_runtime: _configuration_ready = true
		elif attach_layer: _layer_cursor += 1
		elif not _repeat_step: _neighbor_step += 1
		_neighbor_signature = host._zone_state_signature(_neighbor_scope.zone_id)
		_neighbor_epoch = _story_epoch
		_record_job(_neighbor_scope.zone_id,_neighbor_state)
	elif _neighbor_failure.is_empty():
		_neighbor_failure = "Construction step %d did not complete for %s." % [_neighbor_step, _neighbor_scope.zone_id]
	if not _neighbor_failure.is_empty():
		var error := _neighbor_failure
		var target := _neighbor_scope.zone_id
		cancel_preparation(); _neighbor_failure = error; _retry_after = Time.get_ticks_msec()+30000
		_record_job(target,"failed",error)
		push_warning("Prepared road failed; the source remains playable: " + error)

func _neighbor_dependencies_current() -> bool:
	if _neighbor_scope == null: return false
	if _neighbor_encounter_packs != host._zone_encounter_packs(_neighbor_scope.zone_id): return false
	if _neighbor_scope.cancelled or _neighbor_journey_id != str(host.save_manager.journey_id):
		return false
	if _neighbor_epoch == _story_epoch: return true
	# A partial build's recorded reads grow after every successful step. Only
	# already-consumed state can invalidate it; later steps read current state.
	if _neighbor_scope.cursor > 0 and _neighbor_signature != host._zone_state_signature(_neighbor_scope.zone_id): return false
	_neighbor_epoch = _story_epoch
	return true

func has_prepared(zone_id: String) -> bool:
	if host.runtime_packs != null and not host.runtime_packs.zone_packs_ready(zone_id,host._zone_encounter_packs(zone_id)): return false
	if _valid_cached_destination(zone_id): return true
	return _neighbor_scope != null and is_instance_valid(_neighbor_scope.owned_root) and _neighbor_scope.zone_id == zone_id and _neighbor_state == "ready" and _neighbor_quality == str(host.settings.settings.get("quality_preset","balanced")) and _neighbor_signature == host._zone_state_signature(zone_id) and _neighbor_encounter_packs == host._zone_encounter_packs(zone_id)

func _valid_cached_destination(zone_id: String, refresh: bool = false) -> bool:
	var root: Node3D = host.route_zone_cache.get(zone_id)
	if not is_instance_valid(root): return false
	if root.has_meta("prepared_journey_id") and str(root.get_meta("prepared_journey_id")) != str(host.save_manager.journey_id): return false
	if root.has_meta("prepared_encounter_packs") and root.get_meta("prepared_encounter_packs") != host._zone_encounter_packs(zone_id): return false
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
		if _neighbor_state == "render_pending": _advance_render_preparation()
		else: _advance_preparation()
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
	var builder_path := preload("res://scripts/zone_composition_router.gd").builder_path(target)
	var builder_script := load(builder_path) as Script
	if builder_script == null or not builder_script.can_instantiate():
		_neighbor_failure = "The destination builder could not be loaded: " + target
		_retry_after = Time.get_ticks_msec()+30000
		_record_job(target,"failed",_neighbor_failure)
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
	_neighbor_view.set_meta("prepared_zone_view",true)
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
	_neighbor_encounter_packs = host._zone_encounter_packs(target)
	_neighbor_journey_id = str(host.save_manager.journey_id)
	_neighbor_epoch = _story_epoch; _neighbor_step = 0; _neighbor_state = "building"; _neighbor_failure = ""
	_layer_cursor = 0; _render_nodes.clear(); _render_done = false; _configuration_ready = false
	_render_groups.clear(); _entry_render_started = false; _render_started_ms = 0
	_record_job(target,"constructing")

func _construction_steps() -> int:
	if _neighbor_scope.zone_id == "greyfen": return host.OPENING_DETAIL_STAGES.size()+6
	if _neighbor_builder.has_method("step_count"): return _neighbor_builder.step_count(_neighbor_scope.zone_id)
	return 1

func _build_neighbor_step(context: ZoneBuildContext) -> bool:
	var greyfen := context.zone_id == "greyfen"
	var steps := _construction_steps()
	if _neighbor_step < steps:
		if greyfen:
			if _neighbor_step < 6:
				return _neighbor_builder.build_opening_step(context,_neighbor_step)
			else:
				context.build_profile = "opening_detail"
				_neighbor_builder.build_detail_stage(context,str(host.OPENING_DETAIL_STAGES[_neighbor_step-6]))
		elif _neighbor_builder.has_method("step_count"):
			if not _neighbor_builder.build_step(context, _neighbor_step): return false
		else: _neighbor_builder.build(context)
	elif _neighbor_step == steps:
		_repeat_step = not context.construction_host().flush_environment_next_unit()
	elif _neighbor_step == steps+1:
		var builder := context.construction_host()
		builder._install_world_prop_controller(context.zone_id)
	elif _neighbor_step == steps+2:
		var builder := context.construction_host()
		builder._add_visual_100_layer(context.zone_id)
	elif _neighbor_step == steps+3:
		var builder := context.construction_host()
		builder._apply_first_route_materials(context.zone_root)
	elif _neighbor_step == steps+4:
		context.owned_fields.spatial_service.build_navigation(context.zone_root)
	elif _neighbor_step >= steps+5 and _neighbor_step <= steps+7:
		host.audio.prepare_streamed_destination(context.zone_id,_neighbor_step-steps-5,host.story_state)
	elif _neighbor_step == steps+8:
		var result := context.validate()
		if not bool(result.ok): _neighbor_failure = str(result.errors); return false
		for enemy: Node in context.owned_fields.active_enemies:
			if not is_instance_valid(enemy.visual_root):
				_neighbor_failure = "Missing required body: " + str(enemy.enemy_id); return false
		context.zone_root.set_meta("opening_detail_complete",true)
		context.zone_root.set_meta("prepared_neighbor_complete",true)
		context.zone_root.set_meta("prepared_arrival_pending",true)
		context.zone_root.set_meta("prepared_audio_complete",true)
		context.zone_root.set_meta("prepared_encounter_packs",_neighbor_encounter_packs.duplicate())
		context.zone_root.set_meta("prepared_journey_id",_neighbor_journey_id)
		context.zone_root.set_meta("runtime_light_count",context.owned_fields.runtime_light_count)
		_neighbor_state = "render_pending"; _neighbor_signature = host._zone_state_signature(context.zone_id)
	return true

func _render_finished() -> void:
	if _render_frame >= 0 and not _render_done:
		_render_done = true
		_last_render_delay_usec = Time.get_ticks_usec()-_render_requested_usec
		# Do not charge the active world's normal frame time to each warm-up draw.
		var extra := maxf(0.0,float(_last_render_delay_usec)-_frame_ms*1000.0)
		if extra > 4000:
			_build_cooldown = maxf(_build_cooldown,minf(0.10,extra/500000.0))

func _entry_camera_transform() -> Transform3D:
	var reverse := WorldSectorManifest.connection_between(_neighbor_scope.zone_id,str(host.current_zone_id))
	if reverse.is_empty(): return Transform3D(Basis.IDENTITY,Vector3(0,2.5,10))
	var frame := WorldSectorManifest.crossing_frame(reverse)
	var outward := WorldSectorManifest.direction(str(reverse.id))
	var eye := frame.origin+outward*3.0+Vector3.UP*2.5
	return Transform3D(Basis.IDENTITY,eye).looking_at(frame.origin-outward*6.0+Vector3.UP,Vector3.UP)

func _render_group_key(visual: GeometryInstance3D) -> String:
	var mesh: Mesh
	var key: Array = [visual.get_class(),visual.material_override.get_rid() if visual.material_override != null else RID()]
	if visual is MeshInstance3D:
		mesh = visual.mesh
		key.append(visual.skin != null)
		if mesh != null:
			for surface in mesh.get_surface_count():
				var material: Material = visual.get_active_material(surface)
				key.append(material.get_rid() if material != null else RID())
	elif visual is MultiMeshInstance3D and visual.multimesh != null:
		mesh = visual.multimesh.mesh
		key.append(visual.multimesh.use_colors)
		key.append(visual.multimesh.use_custom_data)
	if mesh != null: key.append(mesh.get_rid())
	else: key.append(visual.get_instance_id())
	return str(hash(key))

func _advance_render_preparation() -> void:
	if not is_instance_valid(_neighbor_view) or _neighbor_scope == null: return
	if _render_started_ms == 0: _render_started_ms = Time.get_ticks_msec()
	if _render_frame >= 0 and not _render_done:
		if Engine.get_frames_drawn() > _render_drawn_frame: _render_done = true
		else: return
	if is_instance_valid(_render_current): _render_current.layers = _render_layers
	_render_current = null; _render_frame = -1; _render_done = false
	if not is_instance_valid(_render_camera):
		_render_camera = Camera3D.new(); _render_camera.name = "NeighborPreparationCamera"
		_render_camera.cull_mask = PREPARATION_RENDER_LAYER
		_neighbor_view.add_child(_render_camera); _render_camera.current = true
		_neighbor_view.size = Vector2i(64,64)
		preload("res://scripts/connected_route_geometry.gd").open_gate(_neighbor_scope.zone_root,str(host.current_zone_id),true)
		_render_camera.global_transform = _entry_camera_transform()
		_render_camera.far = 90.0
	var started := Time.get_ticks_usec()
	while not _render_nodes.is_empty():
		var reference: WeakRef = _render_nodes.pop_back()
		var visual := reference.get_ref() as GeometryInstance3D
		if is_instance_valid(visual) and not visual.is_queued_for_deletion():
			host._validate_zone_render_resources(visual,false)
		if not is_instance_valid(visual) or visual.is_queued_for_deletion() or not visual.is_visible_in_tree():
			if Time.get_ticks_usec()-started >= BASE_SLICE_USEC: return
			continue
		if visual is MeshInstance3D and visual.mesh == null: continue
		if visual is MultiMeshInstance3D and (visual.multimesh == null or visual.multimesh.mesh == null): continue
		_render_camera.global_transform = _entry_camera_transform()
		var bounds := visual.global_transform * visual.get_aabb()
		var in_entry_view := _render_camera.is_position_in_frustum(bounds.get_center())
		if not in_entry_view:
			for corner in 8:
				if _render_camera.is_position_in_frustum(bounds.get_endpoint(corner)):
					in_entry_view = true; break
		var key := _render_group_key(visual)
		if not in_entry_view or _render_groups.has(key):
			if Time.get_ticks_usec()-started >= BASE_SLICE_USEC: return
			continue
		_render_groups[key] = true
		_render_current = visual; _render_layers = visual.layers
		visual.layers = PREPARATION_RENDER_LAYER
		var local_bounds := visual.get_aabb()
		var center := visual.global_transform * local_bounds.get_center()
		_render_camera.global_position = center+Vector3(0,0,maxf(2.0,local_bounds.size.length()*1.4))
		_render_camera.look_at(center,Vector3.UP)
		_neighbor_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		_render_frame = Engine.get_process_frames()
		_render_drawn_frame = Engine.get_frames_drawn()
		_render_requested_usec = Time.get_ticks_usec()
		return
	if not _entry_render_started:
		# Draw the actual entry view once, not every object in the whole region.
		# All world content already exists; this changes only preparation work.
		_entry_render_started = true
		_render_camera.global_transform = _entry_camera_transform()
		_render_camera.cull_mask = (1 << 20)-1
		_neighbor_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		_render_frame = Engine.get_process_frames(); _render_requested_usec = Time.get_ticks_usec()
		_render_drawn_frame = Engine.get_frames_drawn()
		return
	_neighbor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_render_camera.queue_free(); _render_camera = null
	_neighbor_state = "ready"
	_neighbor_scope.zone_root.set_meta("prepared_render_complete",true)
	_record_job(_neighbor_scope.zone_id,"ready")

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
	if is_instance_valid(_neighbor_view): _neighbor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(_render_current): _render_current.layers = _render_layers
	_render_current = null; _render_camera = null; _render_frame = -1; _render_nodes.clear()
	if _neighbor_scope != null:
		if is_instance_valid(host): _record_job(_neighbor_scope.zone_id,"cached")
		if is_instance_valid(host) and is_instance_valid(host.audio): host.audio.release_streamed_destination(_neighbor_scope.zone_id)
		if is_instance_valid(_neighbor_scope.owned_root):
			if is_instance_valid(host) and is_inside_tree(): host.zone_residency._retire_zone_root(_neighbor_scope.owned_root)
			elif is_instance_valid(_neighbor_view): _neighbor_view.queue_free()
		_neighbor_scope.cancel()
	_neighbor_view = null; _neighbor_scope = null; _neighbor_builder = null
	_neighbor_state = "idle"; _neighbor_step = 0; _added_nodes.clear()

func preparation_snapshot() -> Dictionary:
	var result := _neighbor_scope.step_result(_neighbor_state) if _neighbor_scope != null else {"state":_neighbor_state,"zone":"","generation":0,"next_step":_neighbor_step,"error":_neighbor_failure}
	result.merge({"step":_neighbor_step,"failure":_neighbor_failure,"complete":_neighbor_state == "ready",
		"selected_destination":str(_selected_connection.get("target","")),"selection_reason":_selection_reason,
		"last_step_usec":_last_step_usec,"background_cooldown":_build_cooldown,
		"frame_ms":_frame_ms,"unit_overruns":_unit_overruns,"jobs":_jobs.duplicate(true),
		"render_groups_remaining":_render_nodes.size(),"last_render_delay_usec":_last_render_delay_usec,
		"render_unique_groups":_render_groups.size(),"entry_render_started":_entry_render_started},true)
	result["requested_travel"] = str(_road_travel.get("target",""))
	return result

func _exit_tree() -> void:
	_clear_road_travel()
	cancel_preparation()
	if is_instance_valid(host) and host.runtime_packs != null and host.runtime_packs.background_work_allowed == _background_work_allowed:
		host.runtime_packs.background_work_allowed = Callable()
	if get_tree().node_added.is_connected(_construction_node_added): get_tree().node_added.disconnect(_construction_node_added)
	if RenderingServer.frame_post_draw.is_connected(_render_finished): RenderingServer.frame_post_draw.disconnect(_render_finished)

func open_edges_for(zone_id: String) -> Dictionary:
	var edges := WorldSectorManifest.open_edges(zone_id,host.story_state)
	for edge: Dictionary in WorldSectorManifest.connections(zone_id,host.story_state): edges[str(edge.id)] = edge
	return edges

func is_exterior_route(source_zone: String, target_zone: String) -> bool:
	return WorldSectorManifest.is_exterior(source_zone) \
		and WorldSectorManifest.is_exterior(target_zone) \
		and not WorldSectorManifest.edge_between(source_zone, target_zone).is_empty()

func is_interior_route(source_zone: String, target_zone: String) -> bool:
	var source := WorldSectorManifest.canonical(source_zone)
	var target := WorldSectorManifest.canonical(target_zone)
	return not is_exterior_route(source, target) \
		and target in WorldSectorManifest.neighbors(source,host.story_state) \
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
		for connection: Dictionary in WorldSectorManifest.connections(source,host.story_state):
			var frame := WorldSectorManifest.crossing_frame(connection)
			var point := frame.affine_inverse()*actor.global_position
			var available := WorldSectorManifest.edge_available(connection,host.quests,host.story_state)
			var prepared := available and has_prepared(str(connection.target))
			var threshold := 0.0 if prepared else -1.25
			if point.z < threshold or point.z > 3.0 or absf(point.x) > float(connection.half_width): continue
			var normal := WorldSectorManifest.direction(str(connection.id))
			if actor.velocity.dot(normal) <= 0.05: continue
			if not prepared:
				if available: request_road(str(connection.target))
				# Hold only the unsupported plane; movement along and away from the
				# road remains owned by the ordinary player controller.
				if point.z > -0.30:
					point.z = -0.30; actor.global_position = frame*point
					actor.velocity -= normal*maxf(0.0,actor.velocity.dot(normal))
				continue
			var transform := WorldSectorManifest.crossing_transform(connection)
			var arrival := WorldSectorManifest.crossing_arrival_transform(transform, normal, point.z)
			_crossing = {"source":source,"target":str(connection.target),"transform":transform,"view_transform":arrival,"position":arrival*actor.global_position,"velocity":arrival.basis*actor.velocity,"basis":arrival.basis*actor.global_basis}
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
	_clear_road_travel()
	_sync_resident_camera()
	var normalized := WorldSectorManifest.canonical(zone_id)
	if current_sector != "" and current_sector != normalized and host != null and bool(host.get("game_started")) and host.get("progression") != null:
		host.progression.record_saga_departure(current_sector, host.quests)
	previous_sector = current_sector if current_sector != normalized else previous_sector
	current_sector = normalized
	_selected_connection = {}
	_cache_order.clear(); _challenger = ""; _challenger_elapsed = 0.0
	if is_instance_valid(host.audio): host.audio.release_streamed_destination(normalized)
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
	for neighbor in WorldSectorManifest.neighbors(zone_id,host.story_state):
		if neighbor not in kept:
			kept.append(neighbor)
	return kept
