extends Node
const LivingModel = preload("res://scripts/models/living_cast_model.gd")
var model: LivingModel = LivingModel.new()
signal awareness_changed(actor_id: String, reaction: String)
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")
const ConsequenceRoutines = preload("res://scripts/village_consequence_routines.gd")
const Presence = preload("res://scripts/character_presence.gd")
const CastProfile = preload("res://scripts/story_cast_profile.gd")
const WorldScenes = preload("res://scripts/story_world_scenes.gd")
const RoutineDirector = preload("res://scripts/systems/npc_routine_director.gd")
const MotionStep = preload("res://scripts/systems/character_motion_step.gd")
const WALK_ACCELERATION := 1.65
const WALK_BRAKING := 2.8
const ARRIVAL_DISTANCE := 0.065
const ROUTE_TURN_RATE := 2.65
const ATTENTION_TURN_RATE := 1.65
const AMBIENT_LINES = LivingModel.AMBIENT_LINES
const POST_REPORT_LINES = LivingModel.POST_REPORT_LINES
const ROUTINE_PROFILES = LivingModel.ROUTINE_PROFILES
const OCCUPATION_LINES = LivingModel.OCCUPATION_LINES
var host: Node
var player: Node3D
var actors: Array = []
var line_cooldown := 5.0
var quality := "balanced"
const Rng = preload("res://scripts/core/seeded_rng.gd")
var rng: Rng:
	get: return model.rng
var asset_helper
var far_tick_accumulator := 0.0
var simulation_tick_accumulator := 0.0
var spatial_service
var story_signature := ""
var last_story_line := ""
var story_dirty := true
var story_source: Node
var activity_reservations: Dictionary:
	get: return model.activity_reservations
var social_cooldown := 9.0
var regional_only := false
var routine_phase := ""
var routine_minute := -1
var cast_revision := 0
var social_scene: Dictionary = {}
var world_scene_clock := 0.0
var gathering_staged: bool:
	get: return model.gathering_staged
var world_retry_after: Dictionary = {}
var opening_scene: Dictionary = {}
var work_contact_effects: Array[Dictionary] = []
const CROWD_IDENTITIES := [
	"generic_villager_01", "generic_villager_02", "farmer_toma", "widow_elna",
	"mira_herbalist", "rook_smuggler", "blacksmith_tor", "generic_villager_03"
]
const CROWD_VISUAL_ROLES := [
	"villager_human", "villager_female_human", "villager_worker_human", "villager_hooded_human"
]
var _crowd_index = preload("res://scripts/actor_spatial_index.gd").new()
var living_cast_station_view = preload("res://scripts/views/living_cast_station_view.gd").new(self)
var living_cast_work_contact_view = preload("res://scripts/views/living_cast_work_contact_view.gd").new(self)
var living_cast_locomotion_view = preload("res://scripts/views/living_cast_locomotion_view.gd").new(self)
var living_cast_routine_view = preload("res://scripts/views/living_cast_routine_view.gd").new(self)
var living_cast_dialogue_barks_view = preload("res://scripts/views/living_cast_dialogue_barks_view.gd").new(self)
var living_cast_awareness_view = preload("res://scripts/views/living_cast_awareness_view.gd").new(self)
var living_cast_scene_view = preload("res://scripts/views/living_cast_scene_view.gd").new(self)
var living_cast_attention_view = preload("res://scripts/views/living_cast_attention_view.gd").new(self)
var living_cast_population_view = preload("res://scripts/views/living_cast_population_view.gd").new(self)
func _simulation_hz() -> float:
	return 15.0 if quality == "quality" else 8.0

func configure(game: Node, quality_preset: String, only_registered: bool = false) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if story_source != null and is_instance_valid(story_source) and story_source.changed.is_connected(_on_story_changed):
		story_source.changed.disconnect(_on_story_changed)
	host = game
	regional_only = only_registered
	story_source = game.story_state
	if story_source != null:
		story_source.changed.connect(_on_story_changed)
	story_dirty = true
	player = game.player
	quality = quality_preset
	if game.quests != null and not game.quests.changed.is_connected(_on_story_changed):
		game.quests.changed.connect(_on_story_changed)
	if game.day_night != null:
		routine_phase = str(game.day_night.current_phase)
		if not game.day_night.phase_changed.is_connected(_on_phase_changed):
			game.day_night.phase_changed.connect(_on_phase_changed)
	if game.audio != null and not game.audio.perception_cue.is_connected(_on_perception_cue):
		game.audio.perception_cue.connect(_on_perception_cue)
	if actors.is_empty(): model.reset(44017)
	if not model.awareness_changed.is_connected(awareness_changed.emit): model.awareness_changed.connect(awareness_changed.emit)
	asset_helper = game.asset_helper
	set_spatial_service(game.spatial_service)
	if not regional_only and not bool(get_meta("staged_population", false)):
		_build_population()
	if not regional_only:
		_enroll_named_npcs()
	_sync_story_state(true)

func enroll_region() -> void: living_cast_population_view.enroll_region()
func set_spatial_service(service) -> void:
	spatial_service = service
	for entry in actors:
		_configure_agent(entry)
		_precompute_routes(entry)

func actor_count() -> int:
	return actors.size()

func contact_candidates(position: Vector3, radius: float) -> Array:
	var result: Array = []
	for entry: Dictionary in _crowd_index.nearby(position, radius):
		var actor: Node3D = entry.node
		if not is_instance_valid(actor) or not actor.is_visible_in_tree() or Presence.protected(actor) or actor.has_method("apply_damage"): continue
		if str(entry.id) in ["white_hart", "white_hart_avatar", "halvern", "halvern_boss"]: continue
		actor.set_meta("civilian_contact", _receive_contact.bind(entry))
		result.append(actor)
	return result

func enroll_contact_actor(actor: Node3D) -> void:
	if actor.has_method("apply_damage") or str(actor.name) in ["white_hart", "white_hart_avatar", "halvern", "halvern_boss"]: return
	var person := actor.get_node_or_null("Person") as Node3D
	if person != null and not person.is_visible_in_tree(): return
	var entry := _world_actor(str(actor.name))
	if not entry.is_empty() and entry.node == actor:
		_crowd_index.update(actor,entry)

func _receive_contact(contact: Dictionary, entry: Dictionary) -> void:
	if not is_instance_valid(entry.node) or Presence.protected(entry.node) or get_tree().paused: return
	_end_social_exchange()
	var owns_motion: bool = str(entry.node.get_meta("locomotion_owner", "")) in ["", "greyfen_life"]
	_release_activity(entry, owns_motion)
	if owns_motion:
		_start_reaction(entry, "anger" if str(CastProfile.presence_profile(str(entry.id)).get("danger_response", "")) == "guard" else "fear", player.global_position, 3.0, player)
	entry.notice_cooldown = 8.0
	if owns_motion and is_instance_valid(entry.driver): entry.driver.trigger_action("hurt", 1.0, 0.06, true, 0.32)
	if owns_motion and is_instance_valid(entry.get("face")): entry.face.set_expression(str(entry.reaction))
	var key := preload("res://scripts/story_honor.gd").actor_key(str(entry.id))
	var words := "Keep that blade away from me!" if not str(contact.get("source_tag", "")).begins_with("arrow") else "You shot me! Put that bow down!"
	if str(contact.get("source_tag", "")) == "ash_bomb": words = "Keep your explosives away from people!"
	host.hud.toast("%s: %s" % [str(entry.profile.get("occupation", "Villager")).capitalize(), words], 4.0)
	host.story_state.record_relationship_event({"id":"lr." + key + ".weapon_contact","actor":key,"kind":"boundary","text":"Kael struck this person with a weapon.","acknowledgement":"You struck me. Keep your weapon lowered while we speak. I have not forgotten it."})
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")

func routine_ids() -> Array:
	return actors.map(func(entry): return str(entry.id))

func _physics_process(delta: float) -> void:
	delta = MotionStep.simulation_delta(delta)
	if not is_instance_valid(host) or not is_instance_valid(player):
		return
	if get_parent() != host.zone_root or not bool(host.game_started):
		finish_opening_scene("interrupted")
		_end_social_exchange()
		return
	if get_tree().paused:
		_end_social_exchange()
		return
	model.advance(delta)
	_tick_work_contact_effects(delta)
	if not opening_scene.is_empty():
		_tick_opening_scene(delta)
		return
	simulation_tick_accumulator += delta
	var decision_tick: bool = simulation_tick_accumulator >= 1.0 / _simulation_hz()
	if decision_tick:
		simulation_tick_accumulator = 0.0
		var minute := floori(_routine_minutes())
		if minute != routine_minute:
			routine_minute = minute
			story_dirty = true
	line_cooldown = max(line_cooldown - delta, 0.0)
	social_cooldown = maxf(social_cooldown - delta, 0.0)
	if decision_tick and story_dirty:
		_sync_story_state(false)
	world_scene_clock -= delta
	if world_scene_clock <= 0.0:
		world_scene_clock = 1.0
		_update_gathering_routines()
		_try_world_scene()
	_tick_social_exchange(delta)
	var now := model.milliseconds()
	var decision_period := maxi(1, ceili(1000.0 / _simulation_hz()))
	for entry in actors:
		if is_instance_valid(entry.node):
			_crowd_index.update(entry.node, entry)
	for entry in actors:
		var actor_node: Node3D = entry.node
		if not is_instance_valid(actor_node):
			continue
		var due := int(entry.get("decision_due_msec", now))
		if now >= due:
			entry.decision_due_msec = due + (floori(float(now - due) / decision_period) + 1) * decision_period
			if not is_instance_valid(entry.driver) or not entry.driver.is_valid():
				var hydrated_driver: Node = actor_node.find_child("CharacterAnimationDriver", true, false)
				if is_instance_valid(hydrated_driver) and hydrated_driver.is_valid():
					entry.driver = hydrated_driver
					_connect_activity_contact(entry)
			var render_distance: float = 8.0 if quality == "potato" else (18.0 if quality == "quality" else 16.0)
			var was_distant: bool = bool(entry.get("distance_suspended", false))
			var distance_limit: float = render_distance - 0.8 if was_distant else render_distance + 0.8
			var distance_to_player: float = actor_node.global_position.distance_to(player.global_position)
			var camera := get_viewport().get_camera_3d()
			var in_view := actor_node.is_visible_in_tree() and camera != null and camera.is_position_in_frustum(actor_node.global_position + Vector3.UP)
			var distant: bool = distance_to_player > distance_limit and not in_view and not entry.has("table_restore")
			if not entry.has("face") or not is_instance_valid(entry.face):
				entry.face = actor_node.find_child("CharacterFaceDriver", true, false)
			if is_instance_valid(entry.face):
				entry.face.set_distance_suspended(distant or distance_to_player > 9.0)
			if is_instance_valid(entry.driver) and entry.driver.is_valid():
				entry.driver.character_root.set_meta("cast_viewer", player)
			_update_reaction(entry, float(decision_period) / 1000.0)
			var driver: Node = entry.driver
			if distant != was_distant:
				entry.erase("carry_route_scope")
				if distant: _release_awake_seat(entry)
				if driver != null and driver.has_method("set_distance_suspended"):
					driver.set_distance_suspended(distant)
				entry.distance_suspended = distant
				entry.motion_speed = 0.0
			if not distant and driver != null and driver.has_method("set_update_rate_hz"):
				var animation_hz: float = 30.0 if distance_to_player < 7.0 else (10.0 if distance_to_player > render_distance else (20.0 if quality == "quality" else 15.0))
				if not is_equal_approx(float(entry.get("animation_hz", 0.0)), animation_hz):
					driver.set_update_rate_hz(animation_hz)
					entry.animation_hz = animation_hz
		if not bool(entry.get("distance_suspended", false)):
			_update_actor(entry, minf(delta, 0.05))
			_crowd_index.update(actor_node, entry)

func build_population_member(index: int) -> void:
	_build_population(index, 1)
	_sync_story_state(true)

func begin_opening_scene() -> bool: return living_cast_attention_view.begin_opening_scene()
func _tick_opening_scene(delta: float) -> void: living_cast_attention_view._tick_opening_scene(delta)
func _release_opening_performer() -> void: living_cast_attention_view._release_opening_performer()
func finish_opening_scene(reason: String = "skipped") -> void: living_cast_attention_view.finish_opening_scene(reason)
func _build_population(first: Variant = 0, count: Variant = -1) -> void: living_cast_population_view._build_population(first, count)
func _enroll_named_npcs() -> void: living_cast_population_view._enroll_named_npcs()
func _update_actor(entry: Dictionary, delta: float) -> void: living_cast_locomotion_view._update_actor(entry, delta)
func _crowd_pace(entry: Dictionary, direction: Vector3, delta: float) -> float: return living_cast_locomotion_view._crowd_pace(entry, direction, delta)
func _clear_detour_segment(start: Vector3, destination: Vector3) -> bool: return living_cast_locomotion_view._clear_detour_segment(start, destination)
func _player_clear_step(start: Vector3, direction: Vector3, step: float) -> float: return living_cast_locomotion_view._player_clear_step(start, direction, step)
func _player_shares_height(position: Vector3) -> bool: return living_cast_locomotion_view._player_shares_height(position)
func _brake_actor(entry: Dictionary, delta: float) -> void: living_cast_locomotion_view._brake_actor(entry, delta)
func _move_actor(entry: Dictionary, direction: Vector3, speed: float, delta: float, remaining_distance: float = INF) -> void: living_cast_locomotion_view._move_actor(entry, direction, speed, delta, remaining_distance)
func _walk_scripted_step(entry: Dictionary, point: Vector3, speed_limit: float, turn_threshold: float, arrival_radius: float, delta: float) -> void: living_cast_locomotion_view._walk_scripted_step(entry, point, speed_limit, turn_threshold, arrival_radius, delta)
func _make_entry(id: String, node: Node3D, path: Array, speed: float, driver: Node, named: bool) -> Dictionary: return living_cast_population_view._make_entry(id, node, path, speed, driver, named)
func _tick_greeting(entry: Dictionary, delta: float) -> bool: return living_cast_dialogue_barks_view._tick_greeting(entry, delta)
func _cancel_greeting(entry: Dictionary, release_pose: bool = true) -> void: living_cast_dialogue_barks_view._cancel_greeting(entry, release_pose)
func _begin_activity(entry: Dictionary) -> void: living_cast_station_view._begin_activity(entry)
func _update_activity(entry: Dictionary, delta: float) -> void: living_cast_station_view._update_activity(entry, delta)
func _end_activity(entry: Dictionary) -> void: living_cast_station_view._end_activity(entry)
func _release_activity(entry: Dictionary, release_pose: bool = true) -> void: living_cast_station_view._release_activity(entry, release_pose)
func _bind_workstation(profile: Dictionary, path: Array) -> void: living_cast_station_view._bind_workstation(profile, path)
func _bind_rest_anchor(profile: Dictionary, path: Array) -> void: living_cast_routine_view._bind_rest_anchor(profile, path)
func _supported_rest(entry: Dictionary) -> bool: return living_cast_routine_view._supported_rest(entry)
func _player_near_rest_seat(rest: Dictionary) -> bool: return living_cast_routine_view._player_near_rest_seat(rest)
func _awake_rest_support(entry: Dictionary) -> Dictionary: return living_cast_routine_view._awake_rest_support(entry)
func _release_awake_seat(entry: Dictionary) -> void: living_cast_routine_view._release_awake_seat(entry)
func _set_activity_attention(entry: Dictionary, active: bool) -> void: living_cast_station_view._set_activity_attention(entry, active)
func _connect_activity_contact(entry: Dictionary) -> void: living_cast_station_view._connect_activity_contact(entry)
func story_workstation_for(driver: Node, identity: String) -> Dictionary: return living_cast_station_view.story_workstation_for(driver, identity)
func _on_activity_contact(event: String, point: Vector3, source: WeakRef) -> void: living_cast_work_contact_view._on_activity_contact(event, point, source)
func _begin_satchel_cinch(actor: Node3D) -> bool: return living_cast_work_contact_view._begin_satchel_cinch(actor)
func _begin_station_contact(actor: Node3D, identity: String) -> bool: return living_cast_work_contact_view._begin_station_contact(actor, identity)
func _station_contact_morph(part: Node3D) -> Dictionary: return living_cast_work_contact_view._station_contact_morph(part)
func _set_work_contact_morph(node: Node3D, effect: Dictionary, tension: float) -> bool: return living_cast_work_contact_view._set_work_contact_morph(node, effect, tension)
func _restore_work_contact_effect(effect: Dictionary, node: Node3D) -> void: living_cast_work_contact_view._restore_work_contact_effect(effect, node)
func _tick_work_contact_effects(delta: float) -> void: living_cast_work_contact_view._tick_work_contact_effects(delta)
func _clear_work_contact_effects(actor: Node3D) -> void: living_cast_work_contact_view._clear_work_contact_effects(actor)
func _apply_pending_routine(entry: Dictionary) -> void: living_cast_routine_view._apply_pending_routine(entry)
func _routine_route(entry: Dictionary, destination: Vector3) -> Array[Vector3]: return living_cast_routine_view._routine_route(entry, destination)
func _set_activity_pose(entry: Dictionary, active: bool) -> void: living_cast_station_view._set_activity_pose(entry, active)
func _activity_anchor(entry: Dictionary) -> Vector3: return living_cast_station_view._activity_anchor(entry)
func _on_story_changed() -> void:
	cast_revision += 1
	story_dirty = true

func _on_phase_changed(phase: String) -> void:
	routine_phase = phase
	story_dirty = true

func _routine_minutes() -> float:
	return float(host.day_night.get_time()) if is_instance_valid(host) and is_instance_valid(host.day_night) else 990.0

func _sync_story_state(force: bool) -> void: living_cast_routine_view._sync_story_state(force)
func _line_for_actor(entry: Dictionary) -> String: return living_cast_dialogue_barks_view._line_for_actor(entry)
func _update_reaction(entry: Dictionary, delta: float) -> void: living_cast_awareness_view._update_reaction(entry, delta)
func _reaction_priority(kind: String) -> int: return living_cast_awareness_view._reaction_priority(kind)
func _start_reaction(entry: Dictionary, kind: String, position: Vector3, duration: float, focus: Node3D = null) -> bool: return living_cast_awareness_view._start_reaction(entry, kind, position, duration, focus)
func _finish_reaction(entry: Dictionary) -> void: living_cast_awareness_view._finish_reaction(entry)
func _seek_safety(entry: Dictionary, threat: Vector3, delta: float) -> bool: return living_cast_awareness_view._seek_safety(entry, threat, delta)
func _try_social_exchange(entry: Dictionary) -> void: living_cast_dialogue_barks_view._try_social_exchange(entry)
func _social_actor_available(entry: Dictionary) -> bool: return living_cast_dialogue_barks_view._social_actor_available(entry)
func _social_pair(first: Dictionary, second: Dictionary, turns: Array) -> void: living_cast_dialogue_barks_view._social_pair(first, second, turns)
func _tick_social_exchange(delta: float) -> void: living_cast_dialogue_barks_view._tick_social_exchange(delta)
func _end_social_exchange() -> void: living_cast_dialogue_barks_view._end_social_exchange()
func _world_actor(id: String) -> Dictionary: return living_cast_dialogue_barks_view._world_actor(id)
func has_minor_friction(actor: Node3D) -> bool: return living_cast_dialogue_barks_view.has_minor_friction(actor)
func repair_minor_friction(actor: Node3D) -> bool: return living_cast_dialogue_barks_view.repair_minor_friction(actor)
func joinable_world_conversation(actor: Node3D) -> Dictionary: return living_cast_dialogue_barks_view.joinable_world_conversation(actor)
func join_world_conversation(actor: Node3D, scene: Dictionary) -> void: living_cast_dialogue_barks_view.join_world_conversation(actor, scene)
func play_optional_exchange(actor: Node3D, turns: Array, id: String) -> bool: return living_cast_dialogue_barks_view.play_optional_exchange(actor, turns, id)
func request_world_scene(id: String) -> bool: return living_cast_dialogue_barks_view.request_world_scene(id)
func _try_world_scene() -> void: living_cast_scene_view._try_world_scene()
func _start_world_scene(scene: Dictionary, selected: Array[Dictionary]) -> void: living_cast_scene_view._start_world_scene(scene, selected)
func _tick_world_scene(delta: float) -> void: living_cast_scene_view._tick_world_scene(delta)
func _begin_scene_attention(entry: Dictionary, raw: Variant) -> void: living_cast_attention_view._begin_scene_attention(entry, raw)
func _apply_scene_attention(entry: Dictionary, focus: Node3D, delta: float) -> void: living_cast_attention_view._apply_scene_attention(entry, focus, delta)
func _remember_world_scene_progress() -> void: living_cast_scene_view._remember_world_scene_progress()
func _story_workstation_valid(record: Dictionary) -> bool: return living_cast_attention_view._story_workstation_valid(record)
func _release_story_workstation(record: Dictionary) -> void: living_cast_attention_view._release_story_workstation(record)
func _story_workstation_aligned(record: Dictionary) -> bool: return living_cast_attention_view._story_workstation_aligned(record)
func _story_workstation_action(record: Dictionary) -> bool: return living_cast_attention_view._story_workstation_action(record)
func _world_walk_to(entry: Dictionary, target: Vector3, delta: float, arrival_radius: float = 0.2) -> bool: return living_cast_attention_view._world_walk_to(entry, target, delta, arrival_radius)
func _update_gathering_routines() -> void: living_cast_scene_view._update_gathering_routines()
func request_table_visit(id: String, point: Vector3, approach: Vector3 = Vector3.INF) -> bool: return living_cast_scene_view.request_table_visit(id, point, approach)
func _on_perception_cue(position: Vector3, radius: float, danger: bool) -> void: living_cast_awareness_view._on_perception_cue(position, radius, danger)
func _exit_tree() -> void:
	finish_opening_scene("interrupted")
	_end_social_exchange()
	for entry: Dictionary in actors:
		_release_activity(entry)
	model.activity_reservations.clear()
	if is_instance_valid(story_source) and story_source.changed.is_connected(_on_story_changed):
		story_source.changed.disconnect(_on_story_changed)
	if is_instance_valid(host):
		if is_instance_valid(host.quests) and host.quests.changed.is_connected(_on_story_changed):
			host.quests.changed.disconnect(_on_story_changed)
		if is_instance_valid(host.day_night) and host.day_night.phase_changed.is_connected(_on_phase_changed):
			host.day_night.phase_changed.disconnect(_on_phase_changed)
		if is_instance_valid(host.audio) and host.audio.perception_cue.is_connected(_on_perception_cue):
			host.audio.perception_cue.disconnect(_on_perception_cue)

func get_routine_snapshot() -> Array:
	var snapshot: Array = []
	for entry in actors:
		snapshot.append({
			"id": str(entry.id), "named": bool(entry.named),
			"occupation": str(entry.profile.get("occupation", "")),
			"activity": str(entry.profile.get("activity", "")),
			"intent": str(entry.profile.get("intent", "")), "window": str(entry.profile.get("intent_key", "")),
			"state": str(entry.life_state), "story_reaction": str(entry.story_reaction),
			"activity_cycles": int(entry.activity_cycles),
			"position": entry.node.global_position if is_instance_valid(entry.node) else Vector3.ZERO
		})
	return snapshot

func _configure_agent(entry: Dictionary) -> void: living_cast_routine_view._configure_agent(entry)
func _precompute_routes(entry: Dictionary) -> void: living_cast_routine_view._precompute_routes(entry)
func _set_agent_target(entry: Dictionary) -> void: living_cast_routine_view._set_agent_target(entry)
func _c11_carry_scope_live(entry: Dictionary) -> bool: return living_cast_routine_view._c11_carry_scope_live(entry)
func _reviewed_c11_carry_leg(entry: Dictionary) -> String: return living_cast_routine_view._reviewed_c11_carry_leg(entry)
func _set_motion(entry: Dictionary, speed: float, direction: Vector3 = Vector3.ZERO) -> void: living_cast_routine_view._set_motion(entry, speed, direction)
func _face(node: Node3D, target: Vector3, delta: float, walking: bool = false) -> void: living_cast_locomotion_view._face(node, target, delta, walking)
func _wanted_yaw(node: Node3D, direction: Vector3) -> float: return living_cast_locomotion_view._wanted_yaw(node, direction)
func _make_skeletal_villager(parent: Node3D, role_id: String, index: int, scale_value: float) -> Variant: return living_cast_population_view._make_skeletal_villager(parent, role_id, index, scale_value)
func read_tag(node: Object, key: StringName, fallback: Variant = null) -> Variant: return node.get_meta(key, fallback) if is_instance_valid(node) else fallback
func write_tag(node: Object, key: StringName, value: Variant) -> void:
	if is_instance_valid(node): node.set_meta(key,value)
func supports(node: Object, method: StringName) -> bool: return is_instance_valid(node) and node.has_method(method)
func station_actor(station: String) -> Node3D:
	var owner: String = model.reservation_owner(station)
	for entry: Dictionary in actors:
		if str(entry.id) == owner and is_instance_valid(entry.node): return entry.node
	if owner != "": model.release_station(station,owner)
	return null
func reserve_station(station: String, actor: Node3D) -> bool:
	for entry: Dictionary in actors:
		if entry.node == actor: return model.reserve_station(station,str(entry.id))
	return false
func release_station(station: String) -> void:
	model.release_station(station,model.reservation_owner(station))
