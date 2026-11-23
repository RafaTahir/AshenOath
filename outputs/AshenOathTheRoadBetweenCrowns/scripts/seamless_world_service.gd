extends Node
class_name SeamlessWorldService

const WorldSectorManifest = preload("res://scripts/world_sector_manifest.gd")
const APPROACH_RADIUS := 18.0
const PREVIEW_RELEASE_RADIUS := 22.0
const COMMIT_RADIUS := 9.0
const FIRST_CONTROL_GRACE := 2.0
const BUILD_SLICE_USEC := 1500
const BASE_SLICE_USEC := 500
const PRIORITY_INTERVAL := 0.10
const SWITCH_ADVANTAGE := 4.0
const SWITCH_DWELL := 0.50
const ROAD_INTENT_RADIUS := 8.0
const AUTOMATIC_ROAD_RETRIES := 2
const PREPARATION_DRAW_TIMEOUT_USEC := 5000000
const REQUIRE_PREPARED_ROADS := false

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
var _transition_epoch: int = -1
var _story_epoch := 0
var _neighbor_failure := ""
var _added_nodes: Array[WeakRef] = []
var _poll := 0.0
var _foreground := false
var _first_route_preparation := false
var _cached_root: Node3D
var _cached_epoch := -1
var _cached_quality := ""
var _cached_valid := false
var _selected_connection: Dictionary = {}
var _crossing: Dictionary = {}
var _preview_root: Node3D
var _preview_road: Dictionary = {}
var _playable_seconds := 0.0
var _build_cooldown := 0.0
var _last_step_usec := 0
var _selection_reason := ""
var _challenger := ""
var _challenger_elapsed := 0.0
var _jobs: Dictionary = {}
var _cache_elapsed := 0.0
var _road_notice_after := 0
var _frame_usec := 0
var _frame_ms := 0.0
var _unit_overruns := 0
var _slowest_unit_usec := 0
var _slowest_unit := ""
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
var _render_entry_planes: Array[Plane] = []
var _render_resource_pass: Dictionary = {}
var _entry_render_started := false
var _layer_cursor := 0
var _repeat_step := false
var _configuration_ready := false
var _story_activity_phase := 0
var _neighbor_encounter_packs: Array[String] = []
var _neighbor_journey_id := ""
var _road_travel: Dictionary = {}
var _road_travel_serial := 0
var _road_commit_queued := false
var _road_resource_key: Array = []
const EntryView = preload("res://scripts/views/neighbor_entry_view.gd")
const PREPARATION_RENDER_LAYER := 1 << 19

func configure(runtime_host: Node, stream_service: Node) -> void:
	host = runtime_host
	streaming_service = stream_service
	_first_route_preparation = not OS.has_feature("web") and OS.get_cmdline_user_args().has("--prepare-first-route")
	if OS.has_feature("web"):
		_first_route_preparation = bool(JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('prepared-road') === '1'", true))
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

func uses_prepared_roads() -> bool:
	return REQUIRE_PREPARED_ROADS

func preparing_zone_id() -> String:
	return _neighbor_scope.zone_id if _neighbor_scope != null and not _neighbor_scope.cancelled else ""

func _prepares_first_route(edge: Dictionary) -> bool:
	if not _first_route_preparation or edge.is_empty(): return false
	return (edge.source == "greyfen" and edge.target == "wychwood") or (edge.source == "wychwood" and edge.target == "greyfen")

func requires_prepared_road(edge: Dictionary) -> bool:
	return not edge.is_empty() and (uses_prepared_roads() or _prepares_first_route(edge))

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
	if host._journey_load_pending():
		_clear_road_travel()
		if _neighbor_scope != null: cancel_preparation()
		else: _release_road_resources()
		return
	if _foreground: return
	if _neighbor_scope != null and (not host.world_transition.accepts(_transition_epoch) or not is_instance_valid(_neighbor_scope.owned_root) or _neighbor_quality != str(host.settings.settings.get("quality_preset","balanced"))): cancel_preparation()
	if get_tree().paused or host._journey_load_pending() or not is_instance_valid(host.player) or not host.player.can_control or host._story_has_active_combat(): return
	if host.opening_detail_pending or host.zone_transition_pending or host.player.bow_aiming: return
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
		_update_preview_residency()
		if _cache_elapsed >= 0.50:
			_cache_elapsed = 0.0
			_cache_next_destination()
	if not requires_prepared_road(_selected_connection):
		if _neighbor_scope != null: cancel_preparation()
		else: _release_road_resources()
		return
	var target := str(_selected_connection.target)
	if _neighbor_scope != null and _neighbor_scope.zone_id != target:
		cancel_preparation()
		# Renderer-safe retirement owns the slot until it has released the root.
		return
	if not _road_resource_key.is_empty() and _road_resource_key[0] != target:
		_release_road_resources()
	if _preview_support_in_use(): return
	if _neighbor_scope == null:
		var job := _road_job(target)
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
		if _neighbor_scope == null: _release_road_resources()
		if _connection_distance(_selected_connection) < APPROACH_RADIUS: _show_neighbor(_selected_connection)
		return
	if _neighbor_state == "support_pending" or host.zone_residency.pending_zone_retirements > 0: return
	if _neighbor_state == "ready":
		if not _neighbor_dependencies_current(): cancel_preparation()
		elif _connection_distance(_selected_connection) < APPROACH_RADIUS: _show_neighbor(_selected_connection)
		return
	if _neighbor_scope != null and not _neighbor_dependencies_current():
		cancel_preparation(); return
	if _neighbor_scope == null:
		if not _prepare_road_resources(target): return
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
	var spent := float(Time.get_ticks_usec() - slice_started) / 1000000.0
	_build_cooldown = minf(0.25, spent * 4.0)
	if delta > 1.0 / 30.0: _build_cooldown = maxf(_build_cooldown,0.10)
	if _last_step_usec > BUILD_SLICE_USEC: _unit_overruns += 1

func _prepare_road_resources(target: String) -> bool:
	if not is_instance_valid(streaming_service): return true
	streaming_service.set_focus_destination(target)
	var key := [target, _story_epoch, host.journey_arrival_generation, str(host.save_manager.journey_id),
		str(host.settings.settings.get("quality_preset", "balanced"))]
	if _road_resource_key != key or streaming_service.get_state(target) == "":
		_road_resource_key = key
		var paths := preload("res://scripts/core/route_destination_resources.gd").paths(host, target)
		streaming_service.request_zone(target, "", paths, true)
	if streaming_service.get_state(target) == "failed":
		_record_job(target, "failed", streaming_service.get_last_error(target))
		return false
	return streaming_service.is_ready(target)

func _release_road_resources() -> void:
	if _road_resource_key.is_empty(): return
	if is_instance_valid(streaming_service):
		streaming_service.release_prepared_road(str(_road_resource_key[0]))
	_road_resource_key.clear()

func _road_job(target: String) -> Dictionary:
	var job: Dictionary = _jobs.get(target,{})
	if int(job.get("generation", -1)) != host.journey_arrival_generation or str(job.get("journey_id", "")) != str(host.save_manager.journey_id):
		return {}
	if str(job.get("source", "")) != str(host.current_zone_id) or str(job.get("quality", "")) != str(host.settings.settings.get("quality_preset", "balanced")):
		return {}
	return job

func _record_job(target: String, state: String, error: String = "") -> void:
	var job := _road_job(target)
	job.merge({"state":state,"error":error,"quality":str(host.settings.settings.get("quality_preset","balanced")),
		"generation":host.journey_arrival_generation,"journey_id":str(host.save_manager.journey_id),"source":str(host.current_zone_id)},true)
	if state == "failed" and str(job.get("last_error","")) != error:
		job["retry_after"] = Time.get_ticks_msec()+30000
		job["last_error"] = error
	_jobs[target] = job

func _cache_next_destination() -> void:
	if host.runtime_packs == null or _selected_connection.is_empty(): return
	var target := str(_selected_connection.target)
	var packs: Array[String] = host.runtime_packs.required_zone_packs(target,host._zone_encounter_packs(target))
	for id: String in packs: host.runtime_packs.request_cached_pack(id,1500)
	if requires_prepared_road(_selected_connection): host.runtime_packs.set_background_priorities(packs)

func request_road(target: String, retry: bool = false, automatic_retry: bool = false) -> bool:
	var edge := WorldSectorManifest.connection_between(str(host.current_zone_id),target)
	if edge.is_empty() or not WorldSectorManifest.edge_available(edge,host.quests,host.story_state): return false
	_selected_connection = edge
	_selection_reason = "deliberate_road"
	_challenger = ""; _challenger_elapsed = 0.0
	if retry:
		var retries := int(_road_job(target).get("automatic_retries",0)) + 1 if automatic_retry else 0
		_jobs.erase(target)
		_record_job(target, "queued")
		_jobs[target]["automatic_retries"] = retries
		if streaming_service != null and streaming_service.get_state(target) == "failed": streaming_service.cancel_request(target)
		if host.runtime_packs != null:
			for id: String in host.runtime_packs.required_zone_packs(target,host._zone_encounter_packs(target)):
				if host.runtime_packs.get_state(id) in ["failed","cancelled"]:
					host.runtime_packs.requests.erase(id)
					host.runtime_packs.request_pack(id,500)
	if not has_prepared(target) and Time.get_ticks_msec() >= _road_notice_after:
		var error := str(_road_job(target).get("error",""))
		host.hud.post_notice("Preparing the road to %s. You can keep exploring." % host._zone_display_name(target) if error.is_empty() else "Road preparation failed. Use the road to retry.","travel",2.5,"road_preparation")
		_road_notice_after = Time.get_ticks_msec()+3000
	return has_prepared(target)

func request_road_travel(target: String, arrival: Vector3) -> bool:
	var edge := WorldSectorManifest.connection_between(str(host.current_zone_id),target)
	if edge.is_empty() or not WorldSectorManifest.edge_available(edge,host.quests,host.story_state):
		host.hud.toast("That road is not open yet.")
		return false
	if not host.game_started or not is_instance_valid(host.player) or host._journey_load_pending(): return false
	if not requires_prepared_road(edge):
		_clear_road_travel()
		cancel_preparation()
		host._systems["zone_lifecycle"]._request_zone_load(str(edge.target),arrival if arrival != Vector3.ZERO else _road_arrival(edge))
		return true
	_road_travel_serial += 1
	_road_commit_queued = false
	_road_travel = {"source":str(host.current_zone_id),"target":str(edge.target),"arrival":arrival,
		"anchor":host.player.global_position,"journey_id":str(host.save_manager.journey_id),
		"quality":str(host.settings.settings.get("quality_preset","balanced"))}
	request_road(str(edge.target),str(_road_job(str(edge.target)).get("state","")) == "failed")
	return true

func _road_arrival(edge: Dictionary) -> Vector3:
	var marker := preload("res://scripts/connected_route_geometry.gd").entrance_for(host.zone_root, str(edge.target))
	var authored: Variant = marker.get_meta("spawn_pos", Vector3.ZERO) if is_instance_valid(marker) else null
	return preload("res://scripts/core/route_destination_resources.gd").arrival_point(edge, authored)

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
	host._systems["zone_lifecycle"]._request_zone_load(target,arrival)

func _refresh_road_status() -> void:
	if not is_instance_valid(host.zone_root): return
	var return_road := str(_preview_road.get("source", "")) if _preview_support_in_use() else ""
	for edge: Dictionary in WorldSectorManifest.connections(str(host.current_zone_id),host.story_state):
		var job := _road_job(str(edge.target))
		var status: Node = host.zone_root.get_node_or_null("ConnectedRoads/RoadTo_"+str(edge.target)+"/TravelGate/RoadPreparation")
		var available := WorldSectorManifest.edge_available(edge,host.quests,host.story_state)
		var ready := available and (not requires_prepared_road(edge) or has_prepared(str(edge.target)))
		if is_instance_valid(status):
			status.set_interaction_enabled(available and not ready)
			status.state_label = "Retry road" if str(job.get("state","")) == "failed" else "Prepare road"
		if not ready and str(edge.target) != return_road:
			preload("res://scripts/connected_route_geometry.gd").close_gate(host.zone_root,str(edge.target),host.player.global_position)
		else:
			preload("res://scripts/connected_route_geometry.gd").open_gate(host.zone_root,str(edge.target),true)
		var entrance := preload("res://scripts/connected_route_geometry.gd").entrance_for(host.zone_root, str(edge.target))
		if is_instance_valid(entrance) and bool(entrance.get_meta("interactive_road_entrance",false)):
			var label := "Road closed" if not available else ("Retry travel" if str(job.get("state","")) == "failed" else ("Preparing" if str(_road_travel.get("target","")) == str(edge.target) and not ready else ""))
			if entrance.state_label != label:
				entrance.state_label = label
				host.interaction_focus_dirty = true

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
	if edge.is_empty(): return
	var target := str(edge.target)
	var root: Node3D = host.route_zone_cache.get(target)
	if not is_instance_valid(root): return
	if _place_cached_preview(root, target, str(edge.source), WorldSectorManifest.crossing_transform(edge).affine_inverse()):
		preload("res://scripts/connected_route_geometry.gd").open_gate(host.zone_root,target,true)

func _place_cached_preview(root: Node3D, cached_zone: String, source_zone: String, placement: Transform3D) -> bool:
	if not is_instance_valid(root) or root.is_queued_for_deletion() or host.route_zone_cache.get(cached_zone) != root:
		return false
	if _preview_root == root and _preview_road.get("target", "") == source_zone and root.visible:
		return false
	var reciprocal := WorldSectorManifest.connection_between(cached_zone, source_zone)
	if reciprocal.is_empty(): return false
	_hide_cached_preview()
	if not host.zone_residency.begin_preview(root, source_zone): return false
	root.transform = placement
	root.visible = true
	preload("res://scripts/connected_route_geometry.gd").open_gate(root, source_zone, true)
	_preview_root = root
	_preview_road = reciprocal
	return true

func _hide_cached_preview() -> void:
	if is_instance_valid(host) and is_instance_valid(_preview_root) and _preview_root != host.zone_root:
		host.zone_residency.hide_cached_preview(_preview_root)
	_preview_root = null
	_preview_road = {}

func _update_preview_residency() -> void:
	if not is_instance_valid(_preview_root) or _preview_root.is_queued_for_deletion():
		_preview_root = null
		_preview_road = {}
		return
	# Keep the way back open while the capsule still relies on this road.
	if _preview_support_in_use(): return
	var target := str(_preview_road.get("source", ""))
	var approach := WorldSectorManifest.connection_between(str(host.current_zone_id), target)
	if str(_selected_connection.get("target", "")) != target or not _valid_cached_destination(target) \
			or approach.is_empty() or not WorldSectorManifest.edge_available(approach, host.quests, host.story_state) \
			or _connection_distance(approach) > PREVIEW_RELEASE_RADIUS:
		_hide_cached_preview()

func prepare_crossing_view() -> void:
	if _crossing.is_empty(): return
	_show_neighbor(WorldSectorManifest.connection_between(str(_crossing.source),str(_crossing.target)))

func crossing_for(zone_id: String) -> Dictionary:
	return _crossing if str(_crossing.get("target","")) == zone_id else {}

func contains_resident_passage(position: Vector3) -> bool:
	if not is_instance_valid(_preview_root) or _preview_root.is_queued_for_deletion() or not _preview_root.visible or _preview_road.is_empty(): return false
	var local := _preview_root.to_local(position)
	return Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), WorldSectorManifest.connector_polygon(_preview_road))

func _preview_support_in_use() -> bool:
	if not is_instance_valid(host) or not is_instance_valid(host.player): return false
	var position: Vector3 = host.player.global_position
	return contains_resident_passage(position) \
		and not WorldSectorManifest.connector_contains(str(host.current_zone_id), position, 0.0, host.story_state)

func complete_crossing(previous_root: Node3D) -> void:
	_hide_cached_preview()
	if not _crossing.is_empty():
		# Cold fallback construction has no prepared preview to open these.
		# Never leave an arriving capsule inside the reverse readiness leaf.
		preload("res://scripts/connected_route_geometry.gd").open_gate(host.zone_root,str(_crossing.source),true)
		_place_cached_preview(previous_root, str(_crossing.source), str(_crossing.target), _crossing.transform)
	_crossing = {}

func _advance_preparation() -> void:
	_added_nodes.clear()
	var started := Time.get_ticks_usec()
	var layers: Array[String] = preload("res://scripts/core/route_destination_resources.gd").layers(_neighbor_scope.zone_id)
	var attach_layer := _layer_cursor < layers.size()
	var configure_runtime := not _configuration_ready
	var unit_name := "build_%d" % _neighbor_step
	if _neighbor_step == _construction_steps()+1:
		unit_name = ["story_activities", "saga_activities", "everyday_activities", "greyfen_activities", "world_props"][_story_activity_phase]
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
	if _last_step_usec > _slowest_unit_usec:
		_slowest_unit_usec = _last_step_usec
		_slowest_unit = "runtime_configuration" if configure_runtime else ("scene_" + layers[_layer_cursor] if attach_layer else unit_name)
	if successful:
		if configure_runtime: _configuration_ready = true
		elif attach_layer: _layer_cursor += 1
		elif not _repeat_step: _neighbor_step += 1
		_neighbor_signature = host._zone_state_signature(_neighbor_scope.zone_id)
		_neighbor_epoch = _story_epoch
		_record_job(_neighbor_scope.zone_id,_neighbor_state)
	elif _neighbor_failure.is_empty():
		_neighbor_failure = "Construction step %d did not complete for %s." % [_neighbor_step, _neighbor_scope.zone_id]
	if not _neighbor_failure.is_empty(): _fail_neighbor(_neighbor_failure)

func _fail_neighbor(error: String) -> void:
	var target := _neighbor_scope.zone_id
	cancel_preparation()
	_neighbor_failure = error
	_record_job(target,"failed",error)
	push_warning("Prepared road failed; the source remains playable: " + error)

func _neighbor_dependencies_current() -> bool:
	if _neighbor_scope == null: return false
	if _neighbor_encounter_packs != host._zone_encounter_packs(_neighbor_scope.zone_id): return false
	if _neighbor_scope.cancelled or _neighbor_journey_id != str(host.save_manager.journey_id):
		return false
	if _neighbor_epoch == _story_epoch: return true
	if _neighbor_scope.cursor > 0 and _neighbor_signature != host._zone_state_signature(_neighbor_scope.zone_id): return false
	_neighbor_epoch = _story_epoch
	return true

func has_prepared(zone_id: String, allow_cached: bool = true) -> bool:
	if host.runtime_packs != null and not host.runtime_packs.zone_packs_ready(zone_id,host._zone_encounter_packs(zone_id)): return false
	if allow_cached and _valid_cached_destination(zone_id): return true
	if _neighbor_scope == null or _neighbor_scope.zone_id != zone_id or _neighbor_state != "ready": return false
	return is_instance_valid(_neighbor_view) and is_instance_valid(_neighbor_scope.owned_root) and _neighbor_quality == str(host.settings.settings.get("quality_preset","balanced")) and _neighbor_signature == host._zone_state_signature(zone_id) and _neighbor_dependencies_current()

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

func _begin_neighbor(target: String) -> void:
	_transition_epoch = host.world_transition.transition_epoch if host.world_transition.state == host.world_transition.State.COMMITTING_TRAVEL and host.world_transition.target_zone_id == target else host.world_transition.prepare_adjacent(target)
	if _transition_epoch < 0: return
	if host.runtime_packs != null:
		for pack: String in host.runtime_packs.required_zone_packs(target, host._zone_encounter_packs(target)):
			if host.runtime_packs.is_ready(pack): host.world_transition.pack_mounted(pack, _transition_epoch)
	var builder_path := preload("res://scripts/zone_composition_router.gd").builder_path(target)
	var builder_script := load(builder_path) as Script
	if builder_script == null or not builder_script.can_instantiate():
		_neighbor_failure = "The destination builder could not be loaded: " + target
		_record_job(target,"failed",_neighbor_failure)
		host.world_transition.fail(_transition_epoch, _neighbor_failure)
		return
	if is_instance_valid(_preview_root) and _preview_root != host.zone_root:
		preload("res://scripts/connected_route_geometry.gd").close_gate(host.zone_root,str(_preview_root.get_meta("zone_resource_id","")),host.player.global_position)
		_hide_cached_preview()
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
	_slowest_unit_usec = 0; _slowest_unit = ""; _unit_overruns = 0
	_layer_cursor = 0; _render_nodes.clear(); _render_done = false; _configuration_ready = false
	_story_activity_phase = 0; _render_groups.clear(); _entry_render_started = false
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
		context.construction_host()._install_world_prop_controller(context.zone_id, _story_activity_phase)
		_repeat_step = _story_activity_phase < host.StoryWorldDirector.PRESENTATION_PHASE
		_story_activity_phase += 1
	elif _neighbor_step == steps+2:
		var builder := context.construction_host()
		builder._add_visual_100_layer(context.zone_id)
	elif _neighbor_step == steps+3:
		var builder := context.construction_host()
		builder._apply_first_route_materials(context.zone_root)
	elif _neighbor_step == steps+4:
		var region: NavigationRegion3D = context.scope.spatial_service.build_navigation(context.zone_root)
		if not is_instance_valid(region) or region.navigation_mesh == null or region.navigation_mesh.get_polygon_count() == 0:
			_neighbor_failure = "The destination has no valid navigation for " + context.zone_id
			return false
	elif _neighbor_step >= steps+5 and _neighbor_step <= steps+7:
		host.audio.prepare_streamed_destination(context.zone_id,_neighbor_step-steps-5,host.story_state)
	elif _neighbor_step == steps+8:
		var result := context.validate()
		if not bool(result.ok): _neighbor_failure = str(result.errors); return false
		for enemy: Node in context.scope.active_enemies:
			if not is_instance_valid(enemy.visual_root):
				_neighbor_failure = "Missing required body: " + str(enemy.enemy_id); return false
		context.zone_root.set_meta("opening_detail_complete",true)
		context.zone_root.set_meta("prepared_neighbor_complete",true)
		context.zone_root.set_meta("prepared_arrival_pending",true)
		context.zone_root.set_meta("prepared_audio_complete",true)
		context.zone_root.set_meta("prepared_encounter_packs",_neighbor_encounter_packs.duplicate())
		context.zone_root.set_meta("prepared_journey_id",_neighbor_journey_id)
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

func _advance_render_preparation() -> void:
	if not is_instance_valid(_neighbor_view) or _neighbor_scope == null: return
	if _render_frame >= 0 and not _render_done:
		if Engine.get_frames_drawn() > _render_drawn_frame: _render_done = true
		else:
			if Time.get_ticks_usec()-_render_requested_usec >= PREPARATION_DRAW_TIMEOUT_USEC:
				_fail_neighbor("The destination entry view could not be drawn.")
			return
	if is_instance_valid(_render_current): _render_current.layers = _render_layers
	_render_current = null; _render_frame = -1; _render_done = false
	var presentation: Node = host._systems["world"]
	if not is_instance_valid(_render_camera):
		_render_camera = Camera3D.new(); _render_camera.name = "NeighborPreparationCamera"
		_render_camera.cull_mask = PREPARATION_RENDER_LAYER
		_neighbor_view.add_child(_render_camera); _render_camera.current = true
		_neighbor_view.size = Vector2i(64,64)
		preload("res://scripts/connected_route_geometry.gd").open_gate(_neighbor_scope.zone_root,str(host.current_zone_id),true)
		_render_camera.far = 90.0
		_render_camera.global_transform = EntryView.camera_transform(_neighbor_scope.zone_id, str(host.current_zone_id))
		var source_view: Viewport = host.get_viewport()
		var source_camera := source_view.get_camera_3d()
		if is_instance_valid(source_camera):
			var viewport_size := source_view.get_visible_rect().size
			var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
			_neighbor_view.size = Vector2i(maxi(2, roundi(64.0 * aspect)), 64)
			_render_camera.keep_aspect = source_camera.keep_aspect
			_render_camera.fov = source_camera.fov
			_render_camera.near = source_camera.near
			_render_camera.far = source_camera.far
		_render_entry_planes = _render_camera.get_frustum()
		_render_resource_pass = presentation.begin_render_resource_pass()
	var started := Time.get_ticks_usec()
	while not _render_nodes.is_empty() and Time.get_ticks_usec() - started < BASE_SLICE_USEC:
		var reference: WeakRef = _render_nodes.pop_back()
		var visual := reference.get_ref() as GeometryInstance3D
		if not is_instance_valid(visual) or visual.is_queued_for_deletion(): continue
		presentation.prepare_render_resource(visual, _render_resource_pass)
		if not visual.is_visible_in_tree(): continue
		if visual is MeshInstance3D and visual.mesh == null: continue
		if visual is MultiMeshInstance3D and (visual.multimesh == null or visual.multimesh.mesh == null): continue
		var bounds := visual.global_transform * visual.get_aabb()
		if not EntryView.intersects(bounds, _render_entry_planes): continue
		var key := EntryView.render_group_key(visual)
		if _render_groups.has(key): continue
		_render_groups[key] = true
		_render_current = visual; _render_layers = visual.layers
		visual.layers = PREPARATION_RENDER_LAYER
		# Warm this group in the entry camera's actual frustum so LOD and
		# visibility ranges match the view the player is approaching.
		_entry_render_started = true
		_neighbor_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		_render_frame = Engine.get_process_frames()
		_render_drawn_frame = Engine.get_frames_drawn()
		_render_requested_usec = Time.get_ticks_usec()
		return
	if not _render_nodes.is_empty(): return
	if not _entry_render_started:
		_fail_neighbor("No renderable geometry was found in the destination entry view.")
		return
	# The entry camera has drawn one representative of each visible render
	# group. Let the active viewport own the combined scene draw after commit.
	_neighbor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_render_camera.queue_free(); _render_camera = null
	var roads := _neighbor_scope.zone_root.get_node_or_null("ConnectedRoads")
	if roads == null:
		_fail_neighbor("The destination has no reciprocal road collision.")
		return
	# Only the road colliders participate in the isolated physics space.
	roads.process_mode = Node.PROCESS_MODE_PAUSABLE
	_neighbor_state = "support_pending"
	presentation.finish_render_resource_pass(_neighbor_scope.zone_root, _render_resource_pass)
	_render_resource_pass.clear()
	_render_entry_planes.clear()

func _physics_process(_delta: float) -> void:
	if _foreground or _neighbor_state != "support_pending" or not _background_work_allowed(): return
	if not _neighbor_dependencies_current() or not host.world_transition.accepts(_transition_epoch, _neighbor_scope.zone_id):
		cancel_preparation(); return
	var reverse := WorldSectorManifest.connection_between(_neighbor_scope.zone_id, str(host.current_zone_id))
	var root := _neighbor_scope.zone_root
	var roads := root.get_node_or_null("ConnectedRoads") if is_instance_valid(root) else null
	if reverse.is_empty() or not is_instance_valid(roads) or not is_instance_valid(_neighbor_view):
		_fail_neighbor("The destination road changed before its collision could be confirmed.")
		return
	var frame := WorldSectorManifest.crossing_frame(reverse)
	var space := _neighbor_view.find_world_3d().direct_space_state
	var margin := maxf(0.0, float(reverse.half_width)-0.45)
	for side in [-margin, 0.0, margin]:
		var point := frame*Vector3(side,0.0,-0.45)
		if SpatialSurfaceContract.support_hit(space,point+Vector3.UP*6.0,point-Vector3.UP*12.0,[],roads).is_empty():
			_fail_neighbor("The reciprocal road has unsupported ground at %s." % point)
			return
	roads.process_mode = Node.PROCESS_MODE_INHERIT
	if not host.world_transition.mark_prepared(_neighbor_scope.zone_id, _transition_epoch):
		cancel_preparation(); return
	_neighbor_state = "ready"
	_neighbor_scope.zone_root.set_meta("prepared_render_complete",true)
	_record_job(_neighbor_scope.zone_id,"ready")

func publish_prepared(zone_id: String, epoch: int) -> bool:
	if host.world_transition.state != host.world_transition.State.COMMITTING_TRAVEL or not host.world_transition.accepts(epoch, zone_id): return false
	if _neighbor_scope == null: return false
	if not has_prepared(zone_id, false) or not _neighbor_failure.is_empty():
		cancel_preparation(); return false
	var root := _neighbor_scope.owned_root
	var spatial: Node = _neighbor_scope.scope.spatial_service
	var enemies: Array = _neighbor_scope.scope.active_enemies
	host._cache_route_zone(zone_id,root,enemies,_neighbor_signature)
	host._cache_route_spatial_service(zone_id,spatial)
	var retiring_world: World3D = _neighbor_view.find_world_3d()
	_neighbor_view.own_world_3d = false
	retiring_world = null
	_neighbor_scope = null; _neighbor_builder = null
	_neighbor_view = null; _neighbor_state = "idle"
	_release_road_resources()
	return true

func cancel_preparation() -> void:
	if is_instance_valid(host) and host.world_transition.state == host.world_transition.State.PRELOADING_ADJACENT: host.world_transition.cancel(_transition_epoch)
	if is_instance_valid(_neighbor_view): _neighbor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(_render_current): _render_current.layers = _render_layers
	_render_current = null; _render_camera = null; _render_frame = -1; _render_nodes.clear()
	_render_resource_pass.clear()
	_render_entry_planes.clear()
	var had_destination := _neighbor_scope != null
	if _neighbor_scope != null:
		if is_instance_valid(host): _record_job(_neighbor_scope.zone_id,"cached")
		if is_instance_valid(host) and is_instance_valid(host.audio): host.audio.release_streamed_destination(_neighbor_scope.zone_id)
		if is_instance_valid(_neighbor_scope.owned_root):
			if is_instance_valid(host) and is_inside_tree(): host.zone_residency._retire_zone_root(_neighbor_scope.owned_root)
			elif is_instance_valid(_neighbor_view): _neighbor_view.queue_free()
		_neighbor_scope.cancel()
	_neighbor_view = null; _neighbor_scope = null; _neighbor_builder = null
	_neighbor_state = "idle"; _neighbor_step = 0; _added_nodes.clear()
	_release_road_resources()
	if had_destination and is_instance_valid(host) and not host.resource_shutdown_prepared:
		host._systems["zone_lifecycle"].call_deferred("_retain_zone_resource_scopes")

func preparation_snapshot() -> Dictionary:
	var result := _neighbor_scope.step_result(_neighbor_state) if _neighbor_scope != null else {"state":_neighbor_state,"zone":"","generation":0,"next_step":_neighbor_step,"error":_neighbor_failure}
	result.merge({"step":_neighbor_step,"failure":_neighbor_failure,"complete":_neighbor_state == "ready",
		"selected_destination":str(_selected_connection.get("target","")),"selection_reason":_selection_reason,
		"last_step_usec":_last_step_usec,"background_cooldown":_build_cooldown,
		"slowest_unit":_slowest_unit,"slowest_unit_usec":_slowest_unit_usec,
		"frame_ms":_frame_ms,"unit_overruns":_unit_overruns,"jobs":_jobs.duplicate(true),
		"render_groups_remaining":_render_nodes.size(),"last_render_delay_usec":_last_render_delay_usec,
		"render_unique_groups":_render_groups.size(),"entry_render_started":_entry_render_started},true)
	result["requested_travel"] = str(_road_travel.get("target",""))
	result["travel_mode"] = "prepared_road" if uses_prepared_roads() else ("first_route_preparation" if _first_route_preparation else "direct")
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
			var requires_preparation := requires_prepared_road(connection)
			var prepared := available and (not requires_preparation or has_prepared(str(connection.target)))
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
			if not requires_preparation:
				_crossing.clear()
				pending_transition = {"source":source,"target":str(connection.target),"edge":str(connection.id),"physical":true}
				if host.request_seamless_boundary_transition(str(connection.target),_road_arrival(connection),str(connection.id)):
					transition_count += 1
					return true
				pending_transition.clear()
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
	if not _arrival_edge.is_empty():
		if str(edge.get("id", "")) == _arrival_edge:
			return false
		_arrival_edge = ""
	if edge.is_empty():
		return false
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
	if current_sector == target:
		pending_transition.clear()
	transition_count += 1
	last_transition = pending_transition.duplicate(true)
	boundary_transition_requested.emit(source, target, str(edge.get("id", "")))
	return true

func on_zone_activated(zone_id: String, local_position: Vector3 = Vector3.ZERO) -> void:
	_clear_road_travel()
	_release_road_resources()
	var normalized := WorldSectorManifest.canonical(zone_id)
	if current_sector != "" and current_sector != normalized and host != null and bool(host.get("game_started")) and host.get("progression") != null:
		host.progression.record_saga_departure(current_sector, host.quests)
	previous_sector = current_sector if current_sector != normalized else previous_sector
	current_sector = normalized
	_selected_connection = {}
	_challenger = ""; _challenger_elapsed = 0.0
	if is_instance_valid(host.audio): host.audio.release_streamed_destination(normalized)
	_playable_seconds = 0.0
	_arrival_edge = str(WorldSectorManifest.edge_for_position(normalized, local_position,
		_zone_bounds(normalized), 0.85).get("id", ""))
	last_world_position = WorldSectorManifest.local_to_world(normalized, local_position)
	if normalized not in discovered_sectors:
		discovered_sectors[normalized] = true
	if normalized not in active_sector_ids:
		active_sector_ids.append(normalized)
	active_sector_ids = preload("res://scripts/core/route_destination_resources.gd").kept_sector_ids(normalized, host.story_state)
	pending_transition.clear()
	cooldown = 0.25
	last_transition["state"] = "active"
	last_transition["activated_at_usec"] = Time.get_ticks_usec()
	if streaming_service != null:
		streaming_service.retire_unneeded_zones(active_sector_ids)
	sector_activated.emit(normalized)

func on_zone_failed(zone_id: String, reason: String) -> void:
	if host.world_transition.target_zone_id == zone_id: host.world_transition.fail(host.world_transition.transition_epoch, reason)
	_crossing = {}
	if not _preview_support_in_use(): _hide_cached_preview()
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

