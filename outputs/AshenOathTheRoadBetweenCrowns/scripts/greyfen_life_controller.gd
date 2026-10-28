extends Node

signal awareness_changed(actor_id: String, reaction: String)

const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")
const ConsequenceRoutines = preload("res://scripts/village_consequence_routines.gd")
const Presence = preload("res://scripts/character_presence.gd")
const CastProfile = preload("res://scripts/story_cast_profile.gd")
const WorldScenes = preload("res://scripts/story_world_scenes.gd")

const WALK_ACCELERATION := 1.65
const WALK_BRAKING := 2.8
const ARRIVAL_DISTANCE := 0.065
const ROUTE_TURN_RATE := 2.65
const ATTENTION_TURN_RATE := 1.65

const AMBIENT_LINES := {
	"greyfen_road_quiet":"Road's quiet today. That's worse.",
	"greyfen_bell_dawn":"Bell rang before dawn. Nobody touched it.",
	"greyfen_shrine_voice":"Keep your voice low near the shrine.",
	"greyfen_anwen_sleep":"Anwen has not slept.",
	"greyfen_crows_fat":"Crows came back fat.",
	"greyfen_woods_stare":"Don't stare at the woods. It stares back.",
	"greyfen_forge_night":"Tor worked the forge through the night.",
	"greyfen_well_iron":"Water tastes of iron again.",
	"greyfen_cart_light":"Bram always brought the empty baskets back. Not this time.",
	"greyfen_roots_bitter":"Mira says the roots are bitter this year.",
	"greyfen_north_smoke":"No smoke from the north road.",
	"greyfen_keep_working":"We keep working. What else is there?"
}

const POST_REPORT_LINES := {
	"private": ["Anwen took the evidence inside. The village is pretending not to listen.", "Nobody asks what Kael told her. They watch the cemetery road instead."],
	"public": ["The notice board has new names on it. People read them and keep their hands busy.", "The bell changed the way Greyfen walks. No one crosses the square alone."],
	"retained": ["Someone kept a piece of the road's story. The crows know which piece.", "The evidence is not all in Anwen's hands. That makes every quiet conversation sharper."]
}

const ROUTINE_PROFILES := {
	"walker_well": {"occupation": "well keeper", "activity": "well", "activity_seconds": 2.8, "line": "greyfen_well_iron"},
	"walker_board": {"occupation": "notice reader", "activity": "notice_board", "activity_seconds": 2.4, "line": "greyfen_road_quiet"},
	"shrine_pilgrim": {"occupation": "shrine pilgrim", "activity": "shrine", "activity_seconds": 3.4, "line": "greyfen_shrine_voice"},
	"forge_helper": {"occupation": "forge helper", "activity": "forge", "activity_seconds": 3.1, "line": "greyfen_forge_night"},
	"herb_helper": {"occupation": "herb gatherer", "activity": "herb_stall", "activity_seconds": 2.6, "line": "greyfen_roots_bitter"},
	"worried_villager": {"occupation": "road lookout", "activity": "lookout", "activity_seconds": 2.0, "line": "greyfen_north_smoke"},
	"young_villager": {"occupation": "market runner", "activity": "market", "activity_seconds": 1.8, "line": "greyfen_cart_light"},
	"water_carrier": {"occupation": "water carrier", "activity": "well", "activity_seconds": 2.4, "line": "greyfen_well_iron"},
	"quality_sweeper": {"occupation": "street sweeper", "activity": "market", "activity_seconds": 2.2, "line": "greyfen_keep_working"},
	"quality_mourner": {"occupation": "mourner", "activity": "shrine", "activity_seconds": 3.0, "line": "greyfen_anwen_sleep"},
	"blacksmith_tor": {"occupation": "blacksmith", "activity": "forge", "activity_seconds": 3.6, "line": "greyfen_forge_night"},
	"mira": {"occupation": "herbalist", "activity": "herb_stall", "activity_seconds": 3.0, "line": "greyfen_roots_bitter"},
	"rook": {"occupation": "road watcher", "activity": "notice_board", "activity_seconds": 2.2, "line": "greyfen_crows_fat"}
}

const OCCUPATION_LINES := {
	"walker_well": "Sella left her washing on the line. I brought it in before the rain.",
	"walker_board": "Bram lent me his cart every harvest. Never asked for a coin.",
	"shrine_pilgrim": "Oren carved that wooden crow himself. Anwen kept telling him to mind his fingers.",
	"forge_helper": "Tor repaired Bram's axle yesterday. He still has the payment laid aside."
}

var host: Node
var player: Node3D
var actors: Array = []
var line_cooldown := 5.0
var quality := "balanced"
var rng := RandomNumberGenerator.new()
var asset_helper
var far_tick_accumulator := 0.0
var simulation_tick_accumulator := 0.0
var spatial_service
var story_signature := ""
var last_story_line := ""
var story_dirty := true
var story_source: Node
var activity_reservations: Dictionary = {}
var social_cooldown := 9.0
var regional_only := false
var routine_phase := ""
var cast_revision := 0
var social_scene: Dictionary = {}
var world_scene_clock := 0.0
var gathering_staged := false
var world_retry_after: Dictionary = {}
var opening_scene: Dictionary = {}

const CROWD_IDENTITIES := [
	"generic_villager_01", "generic_villager_02", "farmer_toma", "widow_elna",
	"mira_herbalist", "rook_smuggler", "blacksmith_tor", "generic_villager_03"
]
const CROWD_VISUAL_ROLES := [
	"villager_human", "villager_female_human", "villager_worker_human", "villager_hooded_human"
]

func _simulation_hz() -> float:
	# Story, distance and hydration decisions are cheap background ticks. Visible
	# bodies move each frame independently of this decision frequency.
	return 15.0 if quality == "quality" else 8.0

func configure(game: Node, quality_preset: String, only_registered: bool = false) -> void:
	# Pause cancels presentation immediately, without simulating routine movement.
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
	rng.seed = 44017
	# Share the game's imported-resource and retargeted-animation cache. A
	# controller-local helper repeated that work when the first villager spawned.
	asset_helper = game.asset_helper
	set_spatial_service(game.spatial_service)
	if not regional_only and not bool(get_meta("staged_population", false)):
		_build_population()
	if not regional_only:
		_enroll_named_npcs()
	_sync_story_state(true)

func enroll_region() -> void:
	var zone_id := str(host.current_zone_id)
	var definitions: Dictionary = CastProfile.life_data().get("zones", {}).get(zone_id, {}).duplicate()
	if str(preload("res://scripts/saga_catalog.gd").person_location("saga_maren", host.quests).zone) == zone_id:
		definitions["saga_maren"] = {"profile":"maren"}
	for id: String in definitions:
		var existing: Dictionary = {}
		for candidate: Dictionary in actors:
			if str(candidate.id) == id:
				existing = candidate
				break
		if bool(existing.get("regional", false)):
			continue
		var definition: Dictionary = definitions[id]
		var node := host.zone_root.find_child(str(definition.get("actor", id)), true, false) as Node3D
		if not is_instance_valid(node) or not node.visible:
			continue
		var owned := str(node.get_meta("locomotion_owner", ""))
		if owned != "" and owned != "greyfen_life":
			continue
		var body := node.get_node_or_null("Person") as Node3D
		if body != null and not body.visible:
			continue
		var driver := node.find_child("CharacterAnimationDriver", true, false)
		if driver == null:
			continue
		var routine := CastProfile.routine(id, zone_id, host.story_state, host.quests, routine_phase)
		var path: Array = []
		for point: Vector3 in routine.path:
			path.append(host.validate_walkable_position(point))
		_bind_workstation(routine, path)
		var entry := _make_entry(id, node, path, 0.62, driver, true) if existing.is_empty() else existing
		entry["regional"] = true
		entry["routine_zone"] = zone_id
		entry["profile"] = routine
		entry["path"] = path
		# Promotion replaces the village schedule and anything queued to restore
		# it. A later safe-point update must not reinstall its nonregional profile.
		entry["pending_routine"] = {}
		for restore_key: String in ["table_restore", "gathering_restore"]:
			if entry.has(restore_key):
				var restoration: Dictionary = entry[restore_key]
				restoration["profile"] = routine.duplicate(true)
				restoration["path"] = path.duplicate()
				restoration["line"] = str(routine.line)
		entry["consequence_line"] = str(routine.line)
		entry["target"] = 0
		entry["alias_anchor"] = host.zone_root.find_child(id, true, false) if definition.has("actor") else null
		var ambient := node.find_child("NpcAmbient", true, false)
		if ambient != null:
			ambient.process_mode = Node.PROCESS_MODE_DISABLED
		if existing.is_empty():
			actors.append(entry)
		_configure_agent(entry)
		driver.set_distance_suspended(false)
		_connect_activity_contact(entry)
	story_dirty = true

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
	host.hud.toast("%s: %s" % [str(entry.profile.get("occupation", "Villager")).capitalize(), words], 4.0)
	host.story_state.record_relationship_event({"id":"lr." + key + ".weapon_contact","actor":key,"kind":"boundary","text":"Kael struck this person with a weapon.","acknowledgement":"You struck me. Keep your weapon lowered while we speak. I have not forgotten it."})
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")

func routine_ids() -> Array:
	return actors.map(func(entry): return str(entry.id))

var _crowd_index = preload("res://scripts/actor_spatial_index.gd").new()

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(player):
		return
	if get_parent() != host.zone_root or not bool(host.game_started):
		finish_opening_scene("interrupted")
		_end_social_exchange()
		return
	if get_tree().paused:
		_end_social_exchange()
		return
	if not opening_scene.is_empty():
		_tick_opening_scene(delta)
		return
	simulation_tick_accumulator += delta
	var decision_tick: bool = simulation_tick_accumulator >= 1.0 / _simulation_hz()
	if decision_tick:
		simulation_tick_accumulator = 0.0
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
	var now := Time.get_ticks_msec()
	var decision_period := maxi(1, ceili(1000.0 / _simulation_hz()))
	# One registration pass observes routine relocations before local queries.
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
			if entry.driver == null:
				var hydrated_driver: Node = actor_node.find_child("CharacterAnimationDriver", true, false)
				if hydrated_driver != null:
					entry.driver = hydrated_driver
			var render_distance: float = 8.0 if quality == "potato" else (18.0 if quality == "quality" else 16.0)
			var was_distant: bool = bool(entry.get("distance_suspended", false))
			var distance_limit: float = render_distance - 0.8 if was_distant else render_distance + 0.8
			var distance_to_player: float = actor_node.global_position.distance_to(player.global_position)
			var distant: bool = distance_to_player > distance_limit
			if not entry.has("face") or not is_instance_valid(entry.face):
				entry.face = actor_node.find_child("CharacterFaceDriver", true, false)
			if is_instance_valid(entry.face):
				entry.face.set_distance_suspended(distant)
			if entry.driver != null:
				entry.driver.character_root.set_meta("cast_viewer", player)
			_update_reaction(entry, float(decision_period) / 1000.0)
			var driver: Node = entry.driver
			if distant != was_distant:
				# Keep distant people in the world; only their animation/simulation
				# budget sleeps. Walking across a distance boundary must not erase them.
				if driver != null and driver.has_method("set_distance_suspended"):
					driver.set_distance_suspended(distant)
				entry.distance_suspended = distant
				entry.motion_speed = 0.0
			if not distant and driver != null and driver.has_method("set_update_rate_hz"):
				var animation_hz: float = 30.0 if distance_to_player < 7.0 else (20.0 if quality == "quality" else 15.0)
				if not is_equal_approx(float(entry.get("animation_hz", 0.0)), animation_hz):
					driver.set_update_rate_hz(animation_hz)
					entry.animation_hz = animation_hz
		if not bool(entry.get("distance_suspended", false)):
			# A stalled render frame must not launch a villager across an anchor.
			_update_actor(entry, minf(delta, 0.05))
			_crowd_index.update(actor_node, entry)

func build_population_member(index: int) -> void:
	_build_population(index, 1)
	_sync_story_state(true)

func begin_opening_scene() -> bool:
	if not opening_scene.is_empty() or str(host.current_zone_id) != "greyfen" or get_tree().paused: return false
	_end_social_exchange()
	opening_scene = {"index":0,"remaining":0.0,"actor":null,"entry":{},"activity":"","station":{},"control":player.can_control}
	host.zone_root.set_meta("opening_scene_active", true)
	host.hud.clear_journey_transients(false)
	host.input_router.begin_context("dialogue")
	player.can_control = false
	host.hud.show_opening_scene_skip(finish_opening_scene.bind("skipped"))
	host.audio.set_ambient_conversation(true)
	return true

func _tick_opening_scene(delta: float) -> void:
	if host.resource_shutdown_prepared or host.zone_transition_pending or host._journey_load_pending():
		finish_opening_scene("interrupted")
		return
	if float(opening_scene.remaining) > 0.0:
		opening_scene.remaining = maxf(0.0, float(opening_scene.remaining) - delta)
		return
	_release_opening_performer()
	var beats: Array[Dictionary] = preload("res://scripts/story_scene_direction.gd").opening_arrival()
	if int(opening_scene.index) >= beats.size():
		finish_opening_scene("completed")
		return
	var beat: Dictionary = beats[int(opening_scene.index)]
	opening_scene.index = int(opening_scene.index) + 1
	var entry := _world_actor(str(beat.actor))
	if entry.is_empty() or not is_instance_valid(entry.node) or not entry.node.is_visible_in_tree():
		# Missing participants never become disembodied live speakers.
		return
	if not Presence.claim(entry.node, "work", get_instance_id()): return
	opening_scene.actor = entry.node
	opening_scene.entry = entry
	var modifier: Node = entry.driver.life_modifier if is_instance_valid(entry.driver) else null
	opening_scene.activity = str(modifier.activity) if is_instance_valid(modifier) else ""
	opening_scene.station = modifier.station.duplicate(true) if is_instance_valid(modifier) else {}
	entry.node.set_meta("cast_work_cancel", finish_opening_scene.bind("interrupted"))
	_release_activity(entry)
	if is_instance_valid(entry.driver):
		entry.driver.set_distance_suspended(false)
		entry.driver.set_life_activity(str(beat.activity))
		var station: Dictionary = entry.profile.get("workstation", {})
		if not station.is_empty() and entry.node.global_position.distance_to(station.get("stand", entry.node.global_position)) < 1.3:
			entry.driver.set_life_workstation(station)
	if host.camera_rig != null: host.camera_rig.frame_story_action(entry.node)
	opening_scene.remaining = float(beat.seconds)
	host.hud.show_ambient_subtitle(get_instance_id(), str(beat.speaker), str(beat.text), float(beat.seconds))
	host.audio.play_nearby_speech(str(beat.actor), str(beat.text), entry.node)

func _release_opening_performer() -> void:
	if opening_scene.is_empty(): return
	var actor: Node3D = opening_scene.get("actor")
	if not is_instance_valid(actor): return
	var entry: Dictionary = opening_scene.entry
	if not entry.is_empty() and is_instance_valid(entry.driver):
		entry.driver.set_life_activity(str(opening_scene.activity))
		entry.driver.set_life_workstation(opening_scene.station)
	Presence.release(actor, "work", get_instance_id())
	opening_scene.actor = null

func finish_opening_scene(reason: String = "skipped") -> void:
	if opening_scene.is_empty(): return
	_release_opening_performer()
	var control := bool(opening_scene.control)
	opening_scene.clear()
	if not is_instance_valid(host): return
	if is_instance_valid(get_parent()): get_parent().set_meta("opening_scene_active", false)
	if is_instance_valid(host.hud):
		host.hud.clear_ambient_subtitle(get_instance_id())
		host.hud.hide_opening_scene_skip()
	if is_instance_valid(host.camera_rig): host.camera_rig.release_dialogue_frame()
	if is_instance_valid(host.audio): host.audio.set_ambient_conversation(false)
	if is_instance_valid(player) and not player.transition_locked:
		player.can_control = control and player.health_component.health > 0.0
	if host.resource_shutdown_prepared or not host.is_inside_tree(): return
	host.story_state.set_flag("opening_arrival_presentation", reason)
	if not get_tree().paused and not host._journey_load_pending() and not host.zone_transition_pending and not host.zone_load_request_pending and get_parent() == host.zone_root:
		host.input_router.begin_context("gameplay")
		host._show_current_objective_guidance(7.0)
		host.hud.toast("Anwen needs the northern road investigated. Maren's relief work can wait until you choose to help.", 7.0)
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")

func _build_population(first := 0, count := -1) -> void:
	var population := 4 if quality == "potato" else (10 if quality == "quality" else 4)
	var definitions := [
		{"id":"walker_well","path":[Vector3(-12,0,8),Vector3(-5,0,5),Vector3(-8,0,-1)],"speed":1.05},
		{"id":"walker_board","path":[Vector3(-11,0,-4),Vector3(-4,0,7),Vector3(1,0,8)],"speed":0.92},
		{"id":"shrine_pilgrim","path":[Vector3(-4,0,-9),Vector3(2,0,-8),Vector3(4.6,0,-6.6)],"speed":0.72},
		{"id":"forge_helper","path":[Vector3(8,0,1.5),Vector3(10.5,0,1),Vector3(9.5,0,-1)],"speed":0.82},
		{"id":"herb_helper","path":[Vector3(-9,0,-4),Vector3(-7,0,-2),Vector3(-10,0,1)],"speed":0.78},
		{"id":"worried_villager","path":[Vector3(4,0,10),Vector3(1,0,5),Vector3(3,0,1)],"speed":0.68},
		{"id":"young_villager","path":[Vector3(-12,0,5),Vector3(-8,0,3),Vector3(-10,0,0)],"speed":1.32,"scale":0.82},
		{"id":"water_carrier","path":[Vector3(-14,0,-2),Vector3(-9,0,-1),Vector3(-6,0,3)],"speed":0.86},
		{"id":"quality_sweeper","path":[Vector3(6,0,8),Vector3(4,0,5),Vector3(7,0,2)],"speed":0.62},
		{"id":"quality_mourner","path":[Vector3(10,0,11),Vector3(12,0,9),Vector3(10,0,7)],"speed":0.58}
	]
	var end := population if count < 0 else mini(population, first + count)
	for i in range(first, end):
		var actor_started := Time.get_ticks_usec()
		var definition: Dictionary = definitions[i]
		if host.zone_root.find_child("Routine_%s" % definition.id, true, false) != null:
			continue
		definition.path = host.river_safe_path(definition.path,0.9)
		var actor := Node3D.new()
		actor.name = "Routine_%s" % definition.id
		actor.position = host.validate_walkable_position(definition.path[0])
		host.zone_root.add_child(actor)
		var spawn_started := Time.get_ticks_usec()
		var driver = _make_skeletal_villager(actor, str(definition.id), i, float(definition.get("scale",1.0)))
		var spawn_ms := float(Time.get_ticks_usec() - spawn_started) / 1000.0
		var entry := _make_entry(definition.id, actor, definition.path, definition.speed, driver, false)
		actors.append(entry)
		_configure_agent(entry)
		if OS.get_environment("ASHEN_PROFILE_GREYFEN_ACTORS") == "1":
			print("GREYFEN_ACTOR_PROFILE id=%s spawn_ms=%.2f setup_ms=%.2f total_ms=%.2f" % [
				definition.id, spawn_ms,
				float(Time.get_ticks_usec() - spawn_started) / 1000.0 - spawn_ms,
				float(Time.get_ticks_usec() - actor_started) / 1000.0,
			])

func _enroll_named_npcs() -> void:
	var named := {
		"blacksmith_tor":{"path":[Vector3(9.5,0,3),Vector3(10.4,0,4.7),Vector3(8.7,0,4.4)],"speed":0.55},
		"mira":{"path":[Vector3(-6.8,0,-2.3),Vector3(-8.5,0,-1.2),Vector3(-7.7,0,-4.1)],"speed":0.52},
		"rook":{"path":[Vector3(-7.8,0,8.5),Vector3(-6.2,0,6.8),Vector3(-3.8,0,8.6)],"speed":0.62}
	}
	for id in named:
		if actors.any(func(entry): return str(entry.id) == str(id)):
			continue
		named[id].path = host.river_safe_path(named[id].path,0.9)
		var node = host.zone_root.find_child(id,true,false)
		if node == null: continue
		var ambient = node.find_child("NpcAmbient",true,false)
		if ambient != null: ambient.process_mode = Node.PROCESS_MODE_DISABLED
		var entry := _make_entry(id, node, named[id].path, named[id].speed, node.find_child("CharacterAnimationDriver",true,false), true)
		actors.append(entry)
		_configure_agent(entry)
		if entry.driver != null and entry.driver.has_method("set_update_rate_hz"):
			entry.driver.set_update_rate_hz(30.0)

func _update_actor(entry: Dictionary, delta: float) -> void:
	var node: Node3D = entry.node
	if not is_instance_valid(node): return
	if entry.has("table_restore"):
		entry.table_seconds = float(entry.get("table_seconds",120.0)) - delta
		if float(entry.table_seconds) <= 0.0 or player.global_position.distance_to(entry.get("table_point",node.global_position)) > 9.0:
			entry.pending_routine = entry.table_restore
			entry.erase("table_restore")
			_release_activity(entry)
			_apply_pending_routine(entry)
	if str(node.get_meta("locomotion_owner", "")) not in ["", "greyfen_life"]:
		_release_activity(entry, false)
		return
	if not node.is_visible_in_tree() or node.get_node_or_null("Person") != null and not node.get_node("Person").visible:
		_release_activity(entry)
		return
	entry.bark_cooldown = maxf(float(entry.get("bark_cooldown", 0.0)) - delta, 0.0)
	if Presence.protected(node):
		_release_activity(entry, false)
		entry.social_time = 0.0
		Presence.release(node, "social", get_instance_id())
		entry.motion_speed = 0.0
		entry.travel_direction = Vector3.ZERO
		return
	if float(entry.get("reaction_time", 0.0)) > 0.0:
		_release_activity(entry)
		var threat: Vector3 = entry.get("threat_position", player.global_position)
		if _seek_safety(entry, threat, delta):
			return
		if float(entry.motion_speed) > 0.05:
			_brake_actor(entry, delta)
		if float(entry.motion_speed) <= 0.05:
			_face(node, threat, delta)
			if entry.driver != null:
				entry.driver.set_life_activity("fear" if str(entry.get("reaction", "")) == "fear" else "watch")
		return
	entry.social_time = maxf(float(entry.get("social_time", 0.0)) - delta, 0.0)
	if float(entry.social_time) > 0.0:
		return
	if node.has_meta("cast_social_owner"):
		Presence.release(node, "social", get_instance_id())
		if is_instance_valid(entry.get("face")):
			entry.face.set_focus_target(null)
	# Major encounters temporarily own their arena. The game restores this
	# marker after the encounter so named villagers do not walk through a boss
	# fight or re-enter its collision space while the player is engaged.
	if bool(node.get_meta("bell_eater_evacuated", false)):
		entry.motion_speed = 0.0
		_set_motion(entry, 0.0)
		return
	if not bool(entry.get("activity_active", false)) and float(entry.get("motion_speed", 0.0)) < 0.05:
		_apply_pending_routine(entry)
	var distance_to_player := node.global_position.distance_to(player.global_position)
	if distance_to_player > 3.4:
		entry.greeted_on_approach = false
		entry.attention_used = false
		entry.attention_remaining = 0.0
	var approaching: bool = distance_to_player < 1.65 or (distance_to_player < 2.4 and player.velocity.length() < 0.35)
	if approaching and not bool(entry.get("attention_used", false)):
		entry.attention_used = true
		entry.attention_remaining = 1.2
		entry.attention_workstation = bool(entry.get("activity_active", false))
	if float(entry.get("attention_remaining", 0.0)) > 0.0:
		# A brief acknowledgement pauses the current beat; lingering nearby
		# must not discard its progress or continually restart the interruption.
		entry.attention_remaining = maxf(float(entry.attention_remaining) - delta, 0.0)
		_brake_actor(entry, delta)
		if float(entry.motion_speed) < 0.05:
			_face(node, player.global_position, delta)
		if social_scene.is_empty() and host.hud.ambient_subtitle_available(get_instance_id()) and line_cooldown <= 0.0 and (not bool(entry.named) or bool(entry.get("regional", false))) and not bool(entry.get("greeted_on_approach", false)) and float(entry.bark_cooldown) <= 0.0 and float(entry.motion_speed) < 0.05:
			line_cooldown = 15.0
			entry.bark_cooldown = 75.0
			entry.greeted_on_approach = true
			var remark := _line_for_actor(entry)
			var speech_duration := 0.0
			if host.audio != null:
				speech_duration = float(host.audio.play_nearby_speech(str(entry.id), remark, node))
			line_cooldown = maxf(line_cooldown, speech_duration + 4.0)
			if social_scene.is_empty():
				host.hud.show_ambient_subtitle(get_instance_id(), str(entry.profile.get("occupation", "Villager")).capitalize(), remark, maxf(5.5, speech_duration + 0.3))
		return
	if bool(entry.get("attention_workstation", false)):
		entry.attention_workstation = false
		if bool(entry.get("activity_active", false)) and is_instance_valid(entry.driver):
			entry.driver.set_life_workstation(entry.profile.get("workstation", {}))
	if bool(entry.get("activity_active", false)):
		_update_activity(entry, delta)
		return
	if float(entry.pause) > 0.0:
		entry.pause = float(entry.pause) - delta
		_brake_actor(entry, delta)
		return
	if entry.path.is_empty():
		_brake_actor(entry, delta)
		return
	entry.target = int(entry.target) % entry.path.size()
	if entry.route.is_empty():
		var final_target: Vector3 = host.validate_walkable_position(entry.path[int(entry.target)])
		# Attention, crowd yielding and dialogue can stop someone away from the
		# prior anchor. Start the next leg from their actual feet every time.
		entry.route = spatial_service.build_route(node.global_position, final_target, 0.72) if spatial_service != null else [final_target]
		entry.route_index = 1 if entry.route.size() > 1 else 0
		_set_agent_target(entry)
	if entry.route.is_empty():
		_brake_actor(entry, delta)
		return
	var target: Vector3 = entry.route[int(entry.route_index)]
	var offset := target - node.global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance < 0.38 and int(entry.route_index) + 1 < entry.route.size():
		var onward: Vector3 = entry.route[int(entry.route_index) + 1] - node.global_position
		onward.y = 0.0
		if onward.length_squared() > 0.01 and offset.normalized().dot(onward.normalized()) > 0.75:
			entry.route_index = int(entry.route_index) + 1
			return
	if distance <= ARRIVAL_DISTANCE + 0.015 and float(entry.motion_speed) < 0.12:
		entry.motion_speed = 0.0
		_set_motion(entry, 0.0)
		entry.route_index = int(entry.route_index) + 1
		if int(entry.route_index) < entry.route.size():
			_set_agent_target(entry)
			return
		entry.route = []
		entry.arrived_target = int(entry.target)
		entry.target = (int(entry.target) + 1) % entry.path.size()
		_begin_activity(entry)
		return
	var direction: Vector3 = offset.normalized()
	var wanted_yaw: float = _wanted_yaw(node, direction)
	var turn_error: float = absf(wrapf(wanted_yaw - node.rotation.y, -PI, PI))
	# Arrive and plant the feet before a sharp corner. Translating sideways
	# while spinning through a half-turn would defeat the facing improvement.
	if turn_error > deg_to_rad(65.0) and float(entry.motion_speed) > 0.05:
		_brake_actor(entry, delta)
		return
	_face(node, node.global_position + direction, delta, true)
	turn_error = absf(wrapf(wanted_yaw - node.rotation.y, -PI, PI))
	var turn_pace: float = clampf((deg_to_rad(65.0) - turn_error) / deg_to_rad(48.0), 0.0, 1.0)
	var arrival_pace: float = sqrt(2.0 * WALK_BRAKING * maxf(distance - ARRIVAL_DISTANCE, 0.0))
	var desired_speed: float = minf(float(entry.speed) * turn_pace, arrival_pace)
	desired_speed *= _crowd_pace(entry, direction, delta)
	var current_speed: float = float(entry.motion_speed)
	var rate: float = WALK_ACCELERATION if desired_speed > current_speed else WALK_BRAKING
	entry.motion_speed = move_toward(current_speed, desired_speed, rate * delta)
	# Translation follows the chest. Turn first, then walk into the curve;
	# don't slide diagonally toward a waypoint while the body is still turning.
	var heading: Vector3 = entry.driver.get_visible_forward() if is_instance_valid(entry.driver) else -node.global_basis.z
	heading.y = 0.0
	heading = heading.normalized()
	entry.travel_direction = heading
	_move_actor(entry, heading, float(entry.motion_speed), delta, maxf(distance - ARRIVAL_DISTANCE, 0.0))

func _crowd_pace(entry: Dictionary, direction: Vector3, delta: float) -> float:
	var pace := 1.0
	var obstruction: Node3D
	var obstruction_distance := INF
	for other: Dictionary in _crowd_index.nearby(entry.node.global_position, 1.62):
		if other == entry or not is_instance_valid(other.node): continue
		if not other.node.is_visible_in_tree(): continue
		var person := other.node.get_node_or_null("Person") as Node3D
		if person != null and not person.is_visible_in_tree(): continue
		var offset: Vector3 = other.node.global_position - entry.node.global_position
		offset.y = 0.0
		var ahead := offset.dot(direction)
		if ahead <= 0.0 or ahead > 1.5: continue
		var lateral := (offset - direction * ahead).length()
		if lateral < 0.60:
			pace = minf(pace, smoothstep(0.60, 1.5, ahead))
			if ahead < obstruction_distance and (str(entry.id) > str(other.id) or bool(other.get("activity_active", false)) or float(other.get("pause", 0.0)) > 0.0):
				obstruction = other.node
				obstruction_distance = ahead
	# Attention and physical clearance are separate. A player beside a worker
	# can remain nearby; one standing in the route still receives right of way.
	if _player_shares_height(entry.node.global_position):
		var offset: Vector3 = player.global_position - entry.node.global_position
		offset.y = 0.0
		var ahead := offset.dot(direction)
		var lateral := (offset - direction * ahead).length()
		if ahead > 0.0 and ahead < 1.65 and lateral < 0.72:
			pace = minf(pace, smoothstep(0.82, 1.65, ahead))
			if ahead < obstruction_distance:
				obstruction = player
	entry.yield_time = float(entry.get("yield_time", 0.0)) + delta if pace < 0.15 else 0.0
	if float(entry.yield_time) > 1.2 and is_instance_valid(obstruction) and spatial_service != null and not entry.route.is_empty():
		entry.yield_time = -1.5
		var side := direction.cross(Vector3.UP).normalized()
		var reconnect: Vector3 = entry.route[int(entry.route_index)]
		for sign_value: float in [1.0, -1.0]:
			var step_aside: Vector3 = entry.node.global_position + side * sign_value * 0.95
			var pass_point: Vector3 = obstruction.global_position + side * sign_value * 0.95 + direction * 0.85
			pass_point.y = entry.node.global_position.y
			if _clear_detour_segment(entry.node.global_position, step_aside) and _clear_detour_segment(step_aside, pass_point) and _clear_detour_segment(pass_point, reconnect):
				entry.route.insert(int(entry.route_index), pass_point)
				entry.route.insert(int(entry.route_index), step_aside)
				break
	return pace

func _clear_detour_segment(start: Vector3, destination: Vector3) -> bool:
	var offset := destination - start
	offset.y = 0.0
	var distance := offset.length()
	return _player_clear_step(start, offset.normalized(), distance) >= distance and spatial_service.validate_runtime_segment(start, destination, 0.58)

func _player_clear_step(start: Vector3, direction: Vector3, step: float) -> float:
	# The shared spatial service excludes the player from its physics probes.
	# Clip this swept step analytically, including braking and scripted walking.
	if not _player_shares_height(start): return step
	var offset := start - player.global_position
	offset.y = 0.0
	var planar := Vector3(direction.x, 0.0, direction.z)
	var length_squared := planar.length_squared()
	if length_squared < 0.000001: return step
	var approach := offset.dot(planar)
	var clearance := offset.length_squared() - 0.72 * 0.72
	# If the player entered someone's space, allow the actor to walk out;
	# never push or teleport either body to repair an existing overlap.
	if clearance <= 0.0:
		return step if approach >= 0.0 else 0.0
	if approach >= 0.0: return step
	var discriminant := approach * approach - length_squared * clearance
	if discriminant <= 0.0: return step
	var contact_step := (-approach - sqrt(discriminant)) / length_squared
	return minf(step, maxf(contact_step - 0.005, 0.0))

func _player_shares_height(position: Vector3) -> bool:
	if not is_instance_valid(player): return false
	var spec: Dictionary = player.get_meta("character_role_spec", {})
	# Roots can represent feet or the player's capsule center. Keep one adult
	# body height plus root tolerance, but ignore clearly separate floors.
	var height := maxf(1.72, float(spec.get("height", 1.72))) + 0.3
	return absf(position.y - player.global_position.y) <= height

func _brake_actor(entry: Dictionary, delta: float) -> void:
	entry.motion_speed = move_toward(float(entry.get("motion_speed", 0.0)), 0.0, WALK_BRAKING * delta)
	var direction: Vector3 = entry.get("travel_direction", Vector3.ZERO)
	_move_actor(entry, direction, float(entry.motion_speed), delta)

func _move_actor(entry: Dictionary, direction: Vector3, speed: float, delta: float, remaining_distance: float = INF) -> void:
	var node: Node3D = entry.node
	var start: Vector3 = node.global_position
	var step: float = _player_clear_step(start, direction, minf(speed * delta, remaining_distance))
	if direction.length_squared() < 0.001 or step <= 0.00001:
		entry.motion_speed = 0.0
		_set_motion(entry, 0.0)
		return
	var destination: Vector3 = start + direction * step
	if spatial_service != null and not spatial_service.validate_runtime_segment(start, destination, 0.58):
		entry.route = []
		entry.pause = 0.5
		entry.motion_speed = 0.0
		_set_motion(entry, 0.0)
		return
	node.global_position = destination
	var alias: Node3D = entry.get("alias_anchor")
	if is_instance_valid(alias):
		alias.global_position = node.global_position
	var achieved_velocity: Vector3 = (node.global_position - start) / maxf(delta, 0.001)
	achieved_velocity.y = 0.0
	_set_motion(entry, achieved_velocity.length(), achieved_velocity.normalized())

func _make_entry(id: String, node: Node3D, path: Array, speed: float, driver: Node, named: bool) -> Dictionary:
	var profile: Dictionary = ROUTINE_PROFILES.get(id, {"occupation": "villager", "activity": "idle", "activity_seconds": 2.0, "line": "greyfen_keep_working"})
	var entry := {
		"id": id, "node": node, "path": path, "target": 1, "speed": speed,
		"base_path": path.duplicate(), "pending_routine": {},
		"pause": rng.randf_range(0.0, 0.25), "driver": driver, "named": named,
		"phase": rng.randf() * TAU, "base_y": node.position.y, "route": [],
		"route_index": 0, "profile": profile.duplicate(true), "activity_active": false,
		"activity_elapsed": 0.0, "activity_cycles": 0, "life_state": "walking",
		"story_reaction": "baseline", "motion_speed": 0.0, "travel_direction": Vector3.ZERO
	}
	var period := maxi(1, ceili(1000.0 / _simulation_hz()))
	entry["decision_due_msec"] = Time.get_ticks_msec() + absi(id.hash()) % period
	node.set_meta("locomotion_owner", "greyfen_life")
	node.set_meta("life_ticket", "LIFE-001")
	node.set_meta("life_routine", id)
	node.set_meta("life_occupation", str(profile.get("occupation", "villager")))
	node.set_meta("life_state", "walking")
	node.set_meta("life_story_reaction", "baseline")
	node.set_meta("cast_presence_profile", CastProfile.presence_profile(id))
	node.set_meta("cast_eye_height", Presence.eye_height(node))
	if is_instance_valid(driver):
		var visible: Vector3 = driver.get_visible_forward()
		var local := node.global_basis.inverse()*visible
		node.set_meta("cast_forward_axis", local.normalized())
		node.set_meta("cast_forward_offset", atan2(-local.x,-local.z))
	return entry

func _begin_activity(entry: Dictionary) -> void:
	var node: Node3D = entry.node
	var profile: Dictionary = entry.profile
	if bool(entry.get("regional", false)):
		var index := int(entry.get("arrived_target", 0))
		entry.profile.activity = str(entry.profile.activities[mini(index, entry.profile.activities.size()-1)])
	var anchor := _activity_anchor(entry)
	if anchor != Vector3.ZERO and node.global_position.distance_squared_to(anchor) > 1.44:
		entry.pause = 0.6
		return
	var station := str(Vector3(snappedf(anchor.x, 0.5), 0, snappedf(anchor.z, 0.5)))
	var occupant: Node3D = activity_reservations.get(station)
	if is_instance_valid(occupant) and occupant != node:
		entry.pause = 1.2
		return
	activity_reservations[station] = node
	entry.station = station
	entry.activity_active = true
	entry.motion_speed = 0.0
	entry.travel_direction = Vector3.ZERO
	entry.activity_elapsed = 0.0
	entry.activity_cycles = int(entry.activity_cycles) + 1
	entry.life_state = "working:%s" % str(profile.get("activity", "idle"))
	node.set_meta("life_state", entry.life_state)
	_set_activity_pose(entry, true)
	if is_instance_valid(entry.driver):
		entry.driver.set_life_workstation(entry.profile.get("workstation", {}))

func _update_activity(entry: Dictionary, delta: float) -> void:
	var node: Node3D = entry.node
	var profile: Dictionary = entry.profile
	entry.activity_elapsed = float(entry.activity_elapsed) + delta
	var anchor := _activity_anchor(entry)
	var station: Dictionary = entry.profile.get("workstation", {})
	if str(profile.get("activity", "")) == str(station.get("activity", "")):
		anchor = station.get("point", anchor)
	if anchor != Vector3.ZERO:
		_face(node, anchor, delta)
	_set_activity_pose(entry, true)
	if float(entry.activity_elapsed) >= float(profile.get("activity_seconds", 2.0)):
		_end_activity(entry)
		entry.pause = rng.randf_range(0.65, 1.55)

func _end_activity(entry: Dictionary) -> void:
	_release_activity(entry)
	entry.activity_active = false
	entry.life_state = "walking"
	entry.route = []
	entry.route_index = 0
	entry.node.set_meta("life_state", "walking")
	_set_activity_pose(entry, false)
	_apply_pending_routine(entry)

func _release_activity(entry: Dictionary, release_pose: bool = true) -> void:
	var was_active := bool(entry.get("activity_active", false))
	var station := str(entry.get("station", ""))
	if station != "" and activity_reservations.get(station) == entry.node:
		activity_reservations.erase(station)
	entry.station = ""
	entry.activity_active = false
	if not release_pose:
		return
	if was_active:
		_set_activity_pose(entry, false)
	if was_active and entry.driver != null and entry.driver.has_method("clear_life_activity"):
		entry.driver.clear_life_activity()
	if is_instance_valid(entry.driver) and entry.driver.has_method("set_carried_activity"):
		entry.driver.set_carried_activity("")
	if is_instance_valid(entry.driver):
		entry.driver.set_life_workstation({})

func _bind_workstation(profile: Dictionary, path: Array) -> void:
	profile["workstation"] = {}
	var definition: Dictionary = profile.get("station", {})
	if definition.is_empty():
		return
	var station: Node3D
	if definition.has("node"):
		station = host.zone_root.find_child(str(definition.node), true, false) as Node3D
	else:
		for candidate in host.zone_root.find_children("RegionalWork", "Node3D", true, false):
			if str(candidate.get_meta("quest", "")) == str(definition.get("quest", "")):
				station = candidate as Node3D
				break
	if not is_instance_valid(station):
		return
	var standing: Vector3 = station.to_global(definition.stand)
	var safe: Vector3 = host.validate_walkable_position(standing)
	if safe.distance_squared_to(standing) > 0.04:
		return
	for index in path.size():
		if str(profile.activities[index]) != str(definition.activity) or path[index].distance_squared_to(standing) > 9.0:
			continue
		var resolved := definition.duplicate()
		for key: String in ["point", "left", "right"]:
			resolved[key] = station.to_global(definition[key])
		profile.workstation = resolved
		path[index] = safe

func _connect_activity_contact(entry: Dictionary) -> void:
	if not is_instance_valid(entry.driver):
		return
	var callback := _on_activity_contact.bind(weakref(entry.node))
	if not entry.driver.activity_contact.is_connected(callback):
		entry.driver.activity_contact.connect(callback)

func _on_activity_contact(event: String, point: Vector3, source: WeakRef) -> void:
	var actor := source.get_ref() as Node3D
	if not is_instance_valid(host) or not is_instance_valid(actor) or not bool(host.game_started) or get_tree().paused or Presence.protected(actor):
		return
	if is_instance_valid(host.audio) and is_instance_valid(player):
		host.audio.play_spatial_event(event, point, player.global_position, 11.0, 0.25, 0.025)

func _apply_pending_routine(entry: Dictionary) -> void:
	var pending: Dictionary = entry.get("pending_routine", {})
	if pending.is_empty(): return
	if entry.has("table_restore") and not bool(pending.get("table_visit",false)):
		entry.table_restore = pending.duplicate(true)
		entry.table_restore["spatial_override"] = true
		entry.pending_routine = {}
		return
	if gathering_staged and entry.has("gathering_restore") and not bool(pending.get("gathering", false)):
		entry.gathering_restore = pending.duplicate(true)
		entry.pending_routine = {}
		return
	entry.pending_routine = {}
	entry.profile = pending.profile
	entry.consequence_line = str(pending.get("line", ""))
	entry.node.set_meta("life_occupation", str(entry.profile.get("occupation", "villager")))
	if bool(entry.named) and not bool(entry.get("regional", false)) and not bool(pending.get("spatial_override",false)) and not bool(pending.get("gathering",false)): return
	var next_path: Array = pending.path
	if next_path == entry.path: return
	entry.path = next_path.duplicate() if bool(entry.get("regional", false)) else host.river_safe_path(next_path, 0.9)
	entry.target = 0
	if not bool(entry.get("regional", false)):
		_precompute_routes(entry)
	# The first leg begins where the person actually stopped, not where the
	# new loop's last anchor happens to be. No teleport or stale route splice.
	var destination: Vector3 = host.validate_walkable_position(entry.path[0])
	entry.route = spatial_service.build_route(entry.node.global_position, destination, 0.72) if spatial_service != null else [destination]
	entry.route_index = 1 if entry.route.size() > 1 else 0

func _set_activity_pose(entry: Dictionary, active: bool) -> void:
	var driver = entry.driver
	if driver == null:
		return
	var activity := str(entry.profile.get("activity", "idle"))
	if driver.has_method("set_life_activity"):
		driver.set_life_activity(activity if active else "")
		return
	if active:
		if activity == "notice_board" or activity == "lookout" or bool(entry.get("quiet_after_report", false)):
			if driver.has_method("set_working"):
				driver.set_working(false)
			if driver.has_method("set_dialogue_pose"):
				driver.set_dialogue_pose(true)
		else:
			if driver.has_method("set_dialogue_pose"):
				driver.set_dialogue_pose(false)
			if driver.has_method("set_working"):
				driver.set_working(true)
	else:
		if driver.has_method("set_working"):
			driver.set_working(false)
		if driver.has_method("set_dialogue_pose"):
			driver.set_dialogue_pose(false)

func _activity_anchor(entry: Dictionary) -> Vector3:
	if bool(entry.get("regional", false)) and not entry.path.is_empty():
		return entry.path[clampi(int(entry.get("arrived_target", 0)), 0, entry.path.size()-1)]
	if bool(entry.named) and not entry.path.is_empty():
		return entry.path.back()
	var activity := str(entry.profile.get("activity", ""))
	if activity == "notice_board" and host != null and is_instance_valid(host.zone_root):
		var board := host.zone_root.find_child("notice_board", true, false) as Node3D
		if board != null:
			return board.global_position + Vector3(0, 0, -1.2)
	var anchors := {
		"well": Vector3(-8.0, 0.0, -1.0),
		"kitchen": Vector3(-4.4, 0.0, 0.9),
		"drain": Vector3(2.8, 0.0, 7.1),
		"relief": Vector3(-9.0, 0.0, 3.5),
		"notice_board": Vector3(4.4, 0.0, 10.9),
		"shrine": Vector3(5.8, 0.0, -7.0),
		"forge": Vector3(9.0, 0.0, -1.0),
		"herb_stall": Vector3(-7.0, 0.0, -2.0),
		"lookout": Vector3(1.5, 0.0, 5.0),
		"market": Vector3(-6.3, 0.0, 8.5)
	}
	return anchors.get(activity, Vector3.ZERO)

func _on_story_changed() -> void:
	cast_revision += 1
	story_dirty = true

func _on_phase_changed(phase: String) -> void:
	routine_phase = phase
	story_dirty = true

func _sync_story_state(force: bool) -> void:
	if host == null:
		return
	story_dirty = false
	var state = host.get("story_state")
	var report := str(state.get_flag("evidence_report", "")) if state != null and state.has_method("get_flag") else ""
	var bell := bool(state.get_flag("cemetery_bell_rung", false)) if state != null and state.has_method("get_flag") else false
	var signature := "%s|%s|%s|%s|%s" % [report, str(bell), ConsequenceRoutines.signature(state), routine_phase, cast_revision]
	if not force and signature == story_signature:
		return
	story_signature = signature
	var reaction := "baseline"
	if report != "":
		reaction = "reported_%s" % report
	if bell:
		reaction += "_bell_rung"
	for entry in actors:
		if bool(entry.get("regional", false)):
			var routine := CastProfile.routine(str(entry.id), str(entry.routine_zone), state, host.quests, routine_phase)
			var path: Array = []
			for point: Vector3 in routine.path:
				path.append(host.validate_walkable_position(point))
			_bind_workstation(routine, path)
			entry.pending_routine = {"profile":routine, "path":path, "line":routine.line}
			continue
		entry.story_reaction = reaction
		# Named characters retain their reserved routes. Ambient workers change
		# assignments only after planting their feet or finishing an activity.
		entry.quiet_after_report = (report == "public" and str(entry.id) in ["forge_helper", "blacksmith_tor"]) \
			or (report == "private" and str(entry.id) == "shrine_pilgrim")
		var base_profile: Dictionary = ROUTINE_PROFILES.get(str(entry.id), entry.profile)
		var next_profile := base_profile.duplicate(true)
		if report != "":
			next_profile.activity_seconds = float(base_profile.get("activity_seconds", 2.0)) * 1.8
		var outcome := ConsequenceRoutines.for_actor(str(entry.id), state)
		for key in ["activity", "occupation", "activity_seconds"]:
			if outcome.has(key): next_profile[key] = outcome[key]
		entry.pending_routine = {"profile":next_profile, "path":outcome.get("path", entry.base_path).duplicate(), "line":outcome.get("line", "")}
		var node: Node3D = entry.node
		if is_instance_valid(node):
			node.set_meta("life_story_reaction", reaction)
			if bool(entry.get("activity_active", false)):
				_set_activity_pose(entry, true)

func _line_for_actor(entry: Dictionary) -> String:
	var standing: Dictionary = host.story_state.honor_view(str(entry.id))
	if bool(standing.grievance) or str(standing.band) in ["Distrusted", "Respected"]:
		return str(standing.reaction)
	if bool(entry.get("regional", false)):
		var identity := str(entry.profile.get("identity", ""))
		var acknowledgement := str(host.story_state.consume_relationship_greeting(identity))
		if acknowledgement != "":
			return acknowledgement
	var consequence_line := str(entry.get("consequence_line", ""))
	if consequence_line != "": return consequence_line
	var reaction := str(entry.get("story_reaction", "baseline"))
	# Only public testimony becomes village knowledge. Private report choices
	# are not ambient gossip; personal acknowledgements use witnessed memories.
	for report in ["public"]:
		if reaction.begins_with("reported_" + report):
			var lines: Array = POST_REPORT_LINES[report]
			return str(lines[int(entry.get("activity_cycles", 0)) % lines.size()])
	return str(OCCUPATION_LINES.get(str(entry.id), AMBIENT_LINES.get(str(entry.profile.get("line", "")), AMBIENT_LINES.greyfen_keep_working)))

func _update_reaction(entry: Dictionary, delta: float) -> void:
	entry.reaction_time = maxf(float(entry.get("reaction_time", 0.0)) - delta, 0.0)
	entry.sound_attention_cooldown = maxf(float(entry.get("sound_attention_cooldown", 0.0)) - delta, 0.0)
	entry.notice_cooldown = maxf(float(entry.get("notice_cooldown", 0.0)) - delta, 0.0)
	entry.sense_clock = float(entry.get("sense_clock", 0.0)) - delta
	if bool(entry.get("distance_suspended", false)) or Presence.protected(entry.node) or str(entry.node.get_meta("locomotion_owner", "")) not in ["", "greyfen_life"]:
		return
	if float(entry.reaction_time) <= 0.0 and bool(entry.get("reaction_active", false)):
		_finish_reaction(entry)
	if float(entry.sense_clock) > 0.0:
		return
	entry.sense_clock = 0.35
	var face: Node = entry.get("face")
	var threat := ""
	var threat_position: Vector3 = player.global_position
	var threat_actor: Node3D = player
	if Presence.can_see(entry.node, player, 5.0):
		threat = Presence.player_threat(player)
	for enemy: Node3D in host.encounter_spatial_index.nearby(entry.node.global_position, 7.0):
		if is_instance_valid(enemy) and not bool(enemy.get("dead")) and bool(enemy.get("encounter_active")) and Presence.can_see(entry.node, enemy, 7.0):
			threat = "danger"
			threat_position = enemy.global_position
			threat_actor = enemy
			break
	if threat != "":
		var response := str(CastProfile.presence_profile(str(entry.id)).get("danger_response", "shelter"))
		var accepted := _start_reaction(entry, ("anger" if response == "guard" else "fear") if threat == "danger" else "suspicion", threat_position, 2.5, threat_actor)
		if accepted and float(entry.notice_cooldown) <= 0.0 and line_cooldown <= 0.0:
			entry.notice_cooldown = 24.0
			line_cooldown = 8.0
			var warning := "Give us room. People are still working here." if threat == "armed" else "Behind the wall. Leave the road clear!"
			host.hud.toast("%s: %s" % [str(entry.profile.occupation).capitalize(), warning], 3.5)
	elif float(entry.reaction_time) <= 0.0:
		if float(entry.get("social_time", 0.0)) > 0.0:
			return
		if is_instance_valid(face):
			var cast := CastProfile.presence_profile(str(entry.id))
			face.set_expression(CastProfile.expression_for(cast, host.story_state))
			face.set_focus_target(player if entry.node.global_position.distance_squared_to(player.global_position) < 16.0 else null)
	_try_social_exchange(entry)

func _reaction_priority(kind: String) -> int:
	match kind:
		"attention": return 1
		"suspicion": return 2
		"fear", "anger": return 3
	return 0

func _start_reaction(entry: Dictionary, kind: String, position: Vector3, duration: float, focus: Node3D = null) -> bool:
	var active := float(entry.get("reaction_time", 0.0)) > 0.0
	if active and _reaction_priority(kind) < _reaction_priority(str(entry.get("reaction", ""))):
		return false
	var changed := not active or str(entry.get("reaction", "")) != kind
	if changed:
		entry.route = []
		entry.safety_route = []
	elif (entry.get("safety_threat_position", entry.get("threat_position", position)) as Vector3).distance_squared_to(position) > 1.0:
		entry.safety_route = []
	entry.reaction = kind
	entry.reaction_active = true
	entry.reaction_time = maxf(float(entry.get("reaction_time", 0.0)), duration)
	entry.threat_position = position
	if is_instance_valid(entry.get("face")):
		entry.face.set_focus_target(focus)
		entry.face.set_expression("concern" if kind == "attention" else kind)
	if changed:
		awareness_changed.emit(str(entry.id), kind)
	return true

func _finish_reaction(entry: Dictionary) -> void:
	# Rejoin the authored route from the actual feet, even without a face driver.
	entry.reaction_active = false
	entry.reaction = ""
	entry.route = []
	entry.safety_route = []
	if not bool(entry.get("activity_active", false)):
		_set_activity_pose(entry, false)
	awareness_changed.emit(str(entry.id), "")

func _seek_safety(entry: Dictionary, threat: Vector3, delta: float) -> bool:
	if (bool(entry.named) and not bool(entry.get("regional", false))) or str(entry.get("reaction", "")) != "fear" or spatial_service == null:
		return false
	var route: Array = entry.get("safety_route", [])
	if route.is_empty():
		var candidate: Vector3 = entry.node.global_position
		var best := candidate.distance_squared_to(threat)
		for point: Vector3 in entry.path:
			if point.distance_squared_to(threat) > best + 1.0:
				candidate = point
				best = point.distance_squared_to(threat)
		if candidate == entry.node.global_position:
			return false
		route.assign(spatial_service.build_route(entry.node.global_position, candidate, 0.72))
		entry.safety_route = route
		entry.safety_threat_position = threat
		entry.safety_index = 1 if route.size() > 1 else 0
	if route.is_empty():
		return false
	var index := int(entry.get("safety_index", 0))
	var offset: Vector3 = route[index] - entry.node.global_position
	offset.y = 0.0
	if offset.length() < 0.12:
		if index + 1 >= route.size():
			return false
		entry.safety_index = index + 1
		return true
	var direction := offset.normalized()
	_face(entry.node, route[index], delta, true)
	var facing_error := absf(wrapf(_wanted_yaw(entry.node, direction) - entry.node.rotation.y, -PI, PI))
	if facing_error > 0.70:
		_brake_actor(entry, delta)
		return true
	entry.motion_speed = move_toward(float(entry.motion_speed), minf(float(entry.speed) * 1.15, 1.25), WALK_ACCELERATION * delta)
	_move_actor(entry, direction, float(entry.motion_speed), delta, offset.length())
	return true

func _try_social_exchange(entry: Dictionary) -> void:
	# The former repeatable exchanges are reauthored in the finite scene catalog.
	pass

func _social_actor_available(entry: Dictionary) -> bool:
	if not is_instance_valid(entry.node) or not entry.node.is_visible_in_tree() or Presence.protected(entry.node):
		return false
	if float(entry.get("reaction_time", 0.0)) > 0.0 or float(entry.get("motion_speed", 0.0)) > 0.05:
		return false
	var body := entry.node.get_node_or_null("Person") as Node3D
	return body == null or body.visible

func _social_pair(first: Dictionary, second: Dictionary, turns: Array) -> void:
	if turns.is_empty() or not Presence.claim(first.node, "social", get_instance_id()):
		return
	if not Presence.claim(second.node, "social", get_instance_id()):
		Presence.release(first.node, "social", get_instance_id())
		return
	social_cooldown = 65.0
	line_cooldown = 12.0
	var saved: Array[Dictionary] = []
	for entry: Dictionary in [first, second]:
		entry.node.set_meta("cast_social_cancel", _end_social_exchange)
		_release_activity(entry)
		entry.social_time = 30.0
		entry.motion_speed = 0.0
		var face: Node = entry.get("face")
		saved.append({"entry":entry, "focus":face.focus_target if is_instance_valid(face) else null, "expression":str(face.expression) if is_instance_valid(face) else "neutral"})
		if is_instance_valid(entry.driver):
			entry.driver.set_dialogue_pose(true)
		if is_instance_valid(face):
			face.set_conversation_active(true)
	social_scene = {"actors":saved, "turns":turns, "index":0, "remaining":0.0, "elapsed":0.0}

func _tick_social_exchange(delta: float) -> void:
	if social_scene.is_empty():
		return
	if social_scene.has("world"):
		_tick_world_scene(delta)
		return
	social_scene.elapsed = float(social_scene.elapsed) + delta
	var saved: Array = social_scene.actors
	for record: Dictionary in saved:
		var entry: Dictionary = record.entry
		if not _social_actor_available(entry) or entry.node.global_position.distance_squared_to(player.global_position) > 81.0 or entry.node.global_position.distance_squared_to(player.global_position) < 4.41 or float(social_scene.elapsed) > 29.0:
			_end_social_exchange()
			return
	if saved[0].entry.node.global_position.distance_squared_to(saved[1].entry.node.global_position) > 16.0:
		_end_social_exchange()
		return
	for index in saved.size():
		_face(saved[index].entry.node, saved[1-index].entry.node.global_position, delta)
	social_scene.remaining = float(social_scene.remaining) - delta
	if float(social_scene.remaining) > 0.0:
		return
	var index := int(social_scene.index)
	var turns: Array = social_scene.turns
	if index >= turns.size():
		_end_social_exchange()
		return
	var turn: Dictionary = turns[index]
	var words := str(turn.get("text", ""))
	var speaker := str(turn.get("speaker", ""))
	var duration := clampf(float(words.split(" ", false).size()) * 0.28 + 1.0, 2.5, 7.0)
	for record: Dictionary in saved:
		var entry: Dictionary = record.entry
		var speaking := str(entry.id) == speaker
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
		if speaking and is_instance_valid(host.audio):
			duration = maxf(duration, float(host.audio.play_nearby_speech(str(entry.id), words, entry.node)) + 0.25)
	host.hud.toast("%s: %s" % [str(turn.get("name", speaker)), words], duration)
	social_scene.index = index + 1
	social_scene.remaining = minf(duration + 0.25, 12.0)

func _end_social_exchange() -> void:
	if social_scene.is_empty():
		return
	if is_instance_valid(host.hud):
		host.hud.clear_ambient_subtitle(get_instance_id())
	if is_instance_valid(host.audio):
		host.audio.set_ambient_conversation(false)
	for record: Dictionary in social_scene.actors:
		var entry: Dictionary = record.entry
		if not is_instance_valid(entry.node):
			continue
		Presence.release(entry.node, "social", get_instance_id())
		if is_instance_valid(host) and is_instance_valid(host.audio):
			host.audio.stop_nearby_speech(entry.node)
		entry.social_time = 0.0
		entry.route = []
		entry.motion_speed = 0.0
		entry.pause = 0.8
		if Presence.has_protected_owner(entry.node):
			continue
		if is_instance_valid(entry.driver):
			entry.driver.stop_story_gesture()
			entry.driver.set_dialogue_pose(false)
			entry.driver.clear_life_activity()
		if is_instance_valid(entry.get("face")):
			entry.face.set_conversation_active(false)
			entry.face.set_speech_amount(0.0)
			entry.face.set_focus_target(record.focus if is_instance_valid(record.focus) else null)
			entry.face.set_expression(str(record.expression))
	social_scene = {}

func _world_actor(id: String) -> Dictionary:
	for entry: Dictionary in actors:
		if str(entry.id) == id and is_instance_valid(entry.node):
			return entry
	if id == "player": return {}
	var names: Array = ["edric_campaign", "edric_castle"] if id == "edric" else [id]
	for actor_name: String in names:
		var node := host.zone_root.find_child(actor_name, true, false) as Node3D
		if not is_instance_valid(node) or not node.is_visible_in_tree() or str(node.get_meta("locomotion_owner", "")) not in ["", "greyfen_life"]: continue
		var driver := node.find_child("CharacterAnimationDriver", true, false)
		if driver == null: continue
		var entry := _make_entry(id, node, [node.global_position], 0.62, driver, true)
		var ambient := node.find_child("NpcAmbient", true, false)
		if ambient != null: ambient.process_mode = Node.PROCESS_MODE_DISABLED
		entry.profile = {"occupation":id.capitalize(), "activity":"idle", "activity_seconds":8.0, "line":""}
		actors.append(entry)
		_configure_agent(entry)
		return entry
	return {}

func _try_world_scene() -> void:
	if not bool(player.can_control): return
	if not social_scene.is_empty() or social_cooldown > 0.0 or not host.hud.ambient_subtitle_available(get_instance_id()) or host._story_has_active_combat() or host.zone_transition_pending or Presence.player_threat(player) != "": return
	var heard: Dictionary = host.story_state.get_flag("world_scenes_heard", {})
	for scene: Dictionary in WorldScenes.data().get("scenes", []):
		if Time.get_ticks_msec() < int(world_retry_after.get(str(scene.id), 0)): continue
		if bool(heard.get(str(scene.id), false)) or not WorldScenes.eligible(scene, host): continue
		var selected: Array[Dictionary] = []
		var near := false
		var ready := true
		for id: String in scene.actors:
			if id == "player": continue
			var entry := _world_actor(id)
			if entry.is_empty() or Presence.protected(entry.node) or not entry.node.is_visible_in_tree() or float(entry.get("reaction_time", 0.0)) > 0.0:
				ready = false
				break
			var distance: float = entry.node.global_position.distance_to(player.global_position)
			near = near or (distance < 5.5 and Presence.can_see(entry.node, player, 6.0))
			if distance > 24.0: ready = false
			selected.append(entry)
		if scene.has("near"):
			var point: Array = scene.near
			near = player.global_position.distance_to(Vector3(point[0],point[1],point[2])) < 4.0
		if not ready or not near: continue
		_start_world_scene(scene, selected)
		return

func _start_world_scene(scene: Dictionary, selected: Array[Dictionary]) -> void:
	var saved: Array[Dictionary] = []
	for entry: Dictionary in selected:
		if not Presence.claim(entry.node, "social", get_instance_id()):
			for claimed: Dictionary in saved: Presence.release(claimed.entry.node, "social", get_instance_id())
			return
		var face: Node = entry.get("face")
		saved.append({"entry":entry, "focus":face.focus_target if is_instance_valid(face) else null, "expression":str(face.expression) if is_instance_valid(face) else "neutral"})
		entry.node.set_meta("cast_social_cancel", _end_social_exchange)
		_release_activity(entry)
		entry.social_time = 2.0
		entry.motion_speed = 0.0
		entry.route = []
	var progress: Dictionary = host.story_state.get_flag("world_scene_progress", {})
	var turns: Array = WorldScenes.turns(scene, host)
	var signature := JSON.stringify(turns).sha256_text()
	var checkpoint: Variant = progress.get(str(scene.id), {})
	var matching := checkpoint is Dictionary and str(checkpoint.get("signature", "")) == signature
	var index := clampi(int(checkpoint.get("index", 0)), 0, turns.size()) if matching else 0
	var walk_index := clampi(int(checkpoint.get("walk_index", 0)), 0, scene.get("walk", []).size()) if matching else 0
	social_scene = {"world":scene, "actors":saved, "turns":turns, "signature":signature, "index":index, "remaining":0.0, "speaking":false, "walk_index":walk_index, "staged":false, "waiting":0.0}
	social_cooldown = 8.0

func _tick_world_scene(delta: float) -> void:
	var scene: Dictionary = social_scene.world
	if not bool(player.can_control):
		_end_social_exchange()
		return
	if float(social_scene.waiting) > 20.0:
		world_retry_after[str(scene.id)] = Time.get_ticks_msec() + 30000
		_end_social_exchange()
		return
	if not WorldScenes.eligible(scene, host) or host._story_has_active_combat() or host.zone_transition_pending or not host.hud.ambient_subtitle_available(get_instance_id()) or Presence.player_threat(player) != "":
		_end_social_exchange()
		return
	for record: Dictionary in social_scene.actors:
		var entry: Dictionary = record.entry
		if not is_instance_valid(entry.node) or not entry.node.is_visible_in_tree() or Presence.protected(entry.node) or float(entry.get("reaction_time", 0.0)) > 0:
			_end_social_exchange()
			return
		entry.social_time = 2.0
		# Separation waits at the last completed beat, never leashes the player.
		if entry.node.global_position.distance_to(player.global_position) > (26.0 if not bool(social_scene.staged) else 9.0):
			_end_social_exchange()
			return
	if not bool(social_scene.staged):
		social_scene.waiting = float(social_scene.waiting) + delta
		var arrived := true
		for record: Dictionary in social_scene.actors:
			var entry: Dictionary = record.entry
			var raw: Array = scene.get("stage", {}).get(str(entry.id), [])
			if raw.size() == 3:
				arrived = _world_walk_to(entry, Vector3(raw[0],raw[1],raw[2]), minf(delta,0.05)) and arrived
		if not arrived: return
		social_scene.staged = true
		social_scene.waiting = 0.0
	# Walk only while the player is nearby. Finish each safe route before speaking.
	if scene.has("walk") and int(social_scene.index) == 1 and not bool(social_scene.speaking):
		var route: Array = scene.walk
		var step := int(social_scene.walk_index)
		if step < route.size() and not social_scene.actors.is_empty():
			social_scene.waiting = float(social_scene.waiting) + delta
			var entry: Dictionary = social_scene.actors[0].entry
			if entry.node.global_position.distance_to(player.global_position) > 5.5:
				_set_motion(entry, 0.0)
				return
			var raw: Array = route[step]
			if _world_walk_to(entry, Vector3(raw[0],raw[1],raw[2]), minf(delta,0.05)):
				social_scene.walk_index = step + 1
				social_scene.waiting = 0.0
				_remember_world_scene_progress()
			return
	if float(social_scene.remaining) > 0.0:
		var current: Array = social_scene.turns[int(social_scene.index)]
		var speaker: Node3D = player
		for record: Dictionary in social_scene.actors:
			if str(record.entry.id) == str(current[0]): speaker = record.entry.node
		for record: Dictionary in social_scene.actors:
			var actor: Node3D = record.entry.node
			var focus: Node3D = speaker if actor != speaker else player
			if actor == speaker and str(scene.kind) == "exchange":
				for listener: Dictionary in social_scene.actors:
					if listener.entry.node != actor:
						focus = listener.entry.node
						break
			_face(actor, focus.global_position, delta)
			if is_instance_valid(record.entry.get("face")): record.entry.face.set_focus_target(focus)
		social_scene.remaining = maxf(0.0, float(social_scene.remaining) - delta)
		return
	if bool(social_scene.speaking):
		social_scene.index = int(social_scene.index) + 1
		social_scene.speaking = false
		_remember_world_scene_progress()
		if scene.has("walk") and int(social_scene.index) == 1:
			return
	if int(social_scene.index) >= social_scene.turns.size():
		var heard: Dictionary = host.story_state.get_flag("world_scenes_heard", {}).duplicate()
		heard[str(scene.id)] = true
		host.story_state.set_flag("world_scenes_heard", heard)
		host.story_save_pending = true
		host.call_deferred("_persist_story_action")
		_end_social_exchange()
		social_cooldown = 12.0
		return
	var turn: Array = social_scene.turns[int(social_scene.index)]
	var duration := clampf(str(turn[2]).split(" ", false).size() * 0.32 + 1.5, 3.0, 11.0)
	for record: Dictionary in social_scene.actors:
		var entry: Dictionary = record.entry
		_set_motion(entry, 0.0)
		_face(entry.node, player.global_position, delta)
		var speaking := str(entry.id) == str(turn[0])
		if is_instance_valid(entry.driver):
			entry.driver.set_life_activity(str(scene.get("action", "idle")))
			var station: Dictionary = entry.profile.get("workstation", {})
			if not station.is_empty() and entry.node.global_position.distance_to(station.get("stand", entry.node.global_position)) < 1.3:
				entry.driver.set_life_workstation(station)
			if speaking: entry.driver.play_story_gesture("explain")
		if is_instance_valid(entry.get("face")):
			entry.face.set_conversation_active(true)
			entry.face.set_focus_target(player)
			entry.face.set_expression(CastProfile.expression_for(CastProfile.presence_profile(str(entry.id)), host.story_state))
			entry.face.set_speech_amount(0.0)
			entry.face.play_story_gesture("explain" if speaking else "acknowledge")
		if speaking:
			duration = maxf(duration, float(host.audio.play_nearby_speech(str(entry.id), str(turn[2]), entry.node)) + 0.3)
	host.audio.set_ambient_conversation(true)
	host.hud.show_ambient_subtitle(get_instance_id(), str(turn[1]), str(turn[2]), duration)
	social_scene.remaining = duration
	social_scene.speaking = true

func _remember_world_scene_progress() -> void:
	var progress: Dictionary = host.story_state.get_flag("world_scene_progress", {}).duplicate()
	progress[str(social_scene.world.id)] = {"index":int(social_scene.index), "walk_index":int(social_scene.walk_index), "signature":str(social_scene.signature)}
	host.story_state.set_flag("world_scene_progress", progress)
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")

func _world_walk_to(entry: Dictionary, target: Vector3, delta: float) -> bool:
	var offset: Vector3 = target - entry.node.global_position
	offset.y = 0
	if offset.length() < 0.2:
		entry.route = []
		entry.motion_speed = 0.0
		_set_motion(entry, 0.0)
		return true
	if entry.route.is_empty():
		if Time.get_ticks_msec() < int(entry.get("world_route_due", 0)): return false
		entry.world_route_due = Time.get_ticks_msec() + 750
		entry.route = spatial_service.build_route(entry.node.global_position, target, 0.72) if spatial_service != null else []
		entry.route_index = 1 if entry.route.size() > 1 else 0
	if entry.route.is_empty(): return false
	var point: Vector3 = entry.route[int(entry.route_index)]
	offset = point - entry.node.global_position
	offset.y = 0
	if offset.length() < 0.2:
		entry.route_index = int(entry.route_index) + 1
		if int(entry.route_index) >= entry.route.size(): entry.route = []
		return false
	_face(entry.node, point, delta, true)
	var facing := absf(wrapf(_wanted_yaw(entry.node, offset) - entry.node.rotation.y, -PI, PI))
	if facing > 0.5:
		_brake_actor(entry, delta)
		return false
	entry.motion_speed = move_toward(float(entry.motion_speed), minf(0.7, sqrt(2.0 * WALK_BRAKING * offset.length())), delta * WALK_ACCELERATION)
	_move_actor(entry, offset.normalized(), float(entry.motion_speed), delta, offset.length())
	return false

func _update_gathering_routines() -> void:
	if host.current_zone_id != "greyfen": return
	var active := preload("res://scripts/greyfen_gathering.gd").active(host)
	if active == gathering_staged: return
	gathering_staged = active
	var positions := {"rook":Vector3(-5.6,0,10.2), "blacksmith_tor":Vector3(-4.4,0,10.4), "sister_anwen":Vector3(-4.2,0,11.7), "mira":Vector3(-6.7,0,11.7), "saga_nessa":Vector3(-6.8,0,10.2)}
	for id: String in positions:
		var entry := _world_actor(id)
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
		_release_activity(entry)
		entry.route = []
		_apply_pending_routine(entry)

func request_table_visit(id: String, point: Vector3) -> bool:
	var entry := _world_actor(id)
	if entry.is_empty() or Presence.protected(entry.node) or not entry.node.is_visible_in_tree() or host._story_has_active_combat(): return false
	if entry.node.global_position.distance_to(point) <= 1.35:
		entry.pause = maxf(float(entry.pause),2.0)
		return true
	if not entry.has("table_restore"):
		entry.table_restore = {"profile":entry.profile.duplicate(true),"path":entry.path.duplicate(),"spatial_override":true}
		entry.table_point = point
		entry.table_seconds = 120.0
		var profile: Dictionary = entry.profile.duplicate(true)
		profile["activity"] = "rest"
		profile["activities"] = ["rest"]
		profile["workstation"] = {}
		entry.pending_routine = {"profile":profile,"path":[point],"table_visit":true,"spatial_override":true}
		_release_activity(entry)
		_apply_pending_routine(entry)
	return false

func _on_perception_cue(position: Vector3, radius: float, danger: bool) -> void:
	if not is_instance_valid(host) or not bool(host.game_started) or get_tree().paused:
		return
	for entry: Dictionary in _crowd_index.nearby(position, radius):
		if not is_instance_valid(entry.node) or Presence.protected(entry.node) or not entry.node.is_visible_in_tree():
			continue
		if str(entry.node.get_meta("locomotion_owner", "")) not in ["", "greyfen_life"]:
			continue
		if not danger and float(entry.get("sound_attention_cooldown", 0.0)) > 0.0:
			continue
		var guard := str(CastProfile.presence_profile(str(entry.id)).get("danger_response", "")) == "guard"
		if _start_reaction(entry, ("anger" if guard else "fear") if danger else "attention", position, 2.5):
			if not danger:
				entry.sound_attention_cooldown = 6.0

func _exit_tree() -> void:
	finish_opening_scene("interrupted")
	_end_social_exchange()
	for entry: Dictionary in actors:
		_release_activity(entry)
	activity_reservations.clear()
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
			"state": str(entry.life_state), "story_reaction": str(entry.story_reaction),
			"activity_cycles": int(entry.activity_cycles),
			"position": entry.node.global_position if is_instance_valid(entry.node) else Vector3.ZERO
		})
	return snapshot

func _configure_agent(entry: Dictionary) -> void:
	var actor: Node3D = entry.node
	if not is_instance_valid(actor):
		return
	var agent: NavigationAgent3D = entry.get("agent")
	if agent == null:
		agent = NavigationAgent3D.new()
		agent.name = "NavigationAgent3D"
		agent.path_desired_distance = 0.25
		agent.target_desired_distance = 0.22
		agent.radius = 0.38
		agent.height = 1.72
		actor.add_child(agent)
		entry.agent = agent
	# ZoneSpatialService has already produced a deterministic, bridge-safe route.
	# Retain the agent contract for inspection without running a second solver.
	agent.process_mode = Node.PROCESS_MODE_DISABLED
	var map_rid: RID = spatial_service.get_navigation_map() if spatial_service != null else RID()
	if map_rid.is_valid():
		agent.set_navigation_map(map_rid)
	entry.route = []
	entry.route_index = 0

func _precompute_routes(entry: Dictionary) -> void:
	if spatial_service == null or entry.path.is_empty():
		return
	var routes: Dictionary = {}
	for destination_index in range(entry.path.size()):
		var source_index := wrapi(destination_index - 1, 0, entry.path.size())
		var source: Vector3 = host.validate_walkable_position(entry.path[source_index])
		var destination: Vector3 = host.validate_walkable_position(entry.path[destination_index])
		routes[destination_index] = spatial_service.build_route(source, destination, 0.72)
	entry.routes = routes

func _set_agent_target(entry: Dictionary) -> void:
	pass

func _set_motion(entry: Dictionary, speed: float, direction: Vector3 = Vector3.ZERO) -> void:
	var driver = entry.driver
	if driver != null and driver.has_method("set_locomotion"):
		if driver.has_method("set_working"):
			driver.set_working(false)
		if driver.has_method("set_dialogue_pose"):
			driver.set_dialogue_pose(false)
		# Report the distance actually covered. The shared driver owns gait and
		# cadence in metres per second, including the slow named work routines.
		var player_nearby: bool = is_instance_valid(player) and entry.node.global_position.distance_to(player.global_position) < 2.1
		if speed <= 0.01 and str(entry.id) == "forge_helper" and not bool(entry.get("quiet_after_report", false)) and not player_nearby and driver.has_method("set_working"):
			driver.set_working(true)
		else:
			if driver.has_method("set_working"):
				driver.set_working(false)
			if driver.has_method("set_locomotion_motion"):
				driver.set_locomotion_motion(direction * speed, true)
			else:
				driver.set_locomotion(clampf(speed / 2.0,0.0,0.70),direction,true)
		if bool(entry.get("regional", false)):
			driver.set_carried_activity("carry" if speed > 0.05 and int(entry.target) == 1 and routine_phase != "night" else "")
	entry.phase = float(entry.phase) + get_process_delta_time() * (0.8 + speed * 1.7)

func _face(node: Node3D, target: Vector3, delta: float, walking: bool = false) -> void:
	var offset := target - node.global_position
	offset.y = 0.0
	if offset.length() < 0.05: return
	var wanted := _wanted_yaw(node, offset)
	var turn_error: float = wrapf(wanted - node.rotation.y, -PI, PI)
	var turn_limit: float = (ROUTE_TURN_RATE if walking else ATTENTION_TURN_RATE) * delta
	node.rotation.y += clampf(turn_error, -turn_limit, turn_limit)

func _wanted_yaw(node: Node3D, direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)-float(node.get_meta("cast_forward_offset", 0.0))

func _make_skeletal_villager(parent: Node3D, role_id: String, index: int, scale_value: float):
	var role := str(CROWD_VISUAL_ROLES[index % CROWD_VISUAL_ROLES.size()])
	# The imported role is already normalized to its CharacterRoleSpec height.
	# Apply only a bounded adult variation; the old 0.82 young scale produced
	# visibly tiny actors and multiplied normalization a second time.
	var target_scale := clampf(scale_value, 0.96, 1.04) * (0.99 + 0.01 * float(index % 2))
	if host != null and host.has_method("should_defer_character_role") \
			and bool(host.should_defer_character_role(role, role_id)):
		var marker := Node3D.new()
		marker.name = "DeferredCharacterVisual_%s" % role_id
		marker.set_meta("deferred_visual_role", role)
		marker.set_meta("deferred_visual_category", "characters")
		marker.set_meta("deferred_visual_actor_id", CROWD_IDENTITIES[index % CROWD_IDENTITIES.size()])
		marker.set_meta("deferred_visual_scale", Vector3.ONE * target_scale)
		parent.set_meta("character_variant_seed", "%s:%d" % [role_id, index])
		parent.set_meta("greyfen_routine_id", role_id)
		parent.add_child(marker)
		return null
	var visual_started := Time.get_ticks_usec()
	var mapped = asset_helper.spawn_visual_role(role, "characters", "%s:%d" % [role_id, index])
	var load_ms := float(Time.get_ticks_usec() - visual_started) / 1000.0
	if mapped == null or mapped.name.ends_with("_placeholder"):
		push_error("Rigged villager asset unavailable for %s" % role_id)
		return null
	mapped.name = "%s_rigged_human" % role_id
	asset_helper.apply_normalized_scale(mapped, target_scale)
	mapped.set_meta("char_002_body_role", role)
	mapped.set_meta("char_002_identity", role_id)
	# Routine identity owns the visible occupation recipe. The old rotating
	# generic aliases made well keepers, pilgrims, and forge workers render as
	# unrelated clone recipes despite having distinct schedules.
	mapped.set_meta("char_009_identity", role_id)
	mapped.set_meta("char_009_variant_index", index)
	mapped.set_meta("character_variant_seed", "%s:%d" % [role_id, index])
	parent.add_child(mapped)
	var presentation_started := Time.get_ticks_usec()
	# Apply presentation to the imported actor itself. Applying it to the zone
	# parent leaves the routine without its native face driver and makes the
	# visual acceptance gate report a false faceless crowd failure.
	CharacterPresentation.apply_npc(mapped, role_id, false)
	var presentation_ms := float(Time.get_ticks_usec() - presentation_started) / 1000.0
	var driver = CharacterAnimationDriver.new()
	driver.name = "CharacterAnimationDriver"
	mapped.add_child(driver)
	var family := str(mapped.get_meta("character_animation_family", "")).to_lower()
	var clips := {"idle":"Idle", "walk":"Walk", "run":"Run", "hit":"RecieveHit", "death":"Death"}
	if family.contains("cleric"):
		clips["work"] = "Idle_Weapon"
	elif family.contains("rogue"):
		clips["work"] = "Idle"
	elif family.contains("monk"):
		clips["work"] = "Idle"
	driver.configure(mapped, clips)
	load("res://scripts/grounded_feet_modifier.gd").install_npc(mapped, driver)
	driver.set_update_rate_hz(30.0)
	if OS.get_environment("ASHEN_PROFILE_GREYFEN_ACTORS") == "1":
		print("GREYFEN_VISUAL_PROFILE id=%s role=%s asset_ms=%.2f presentation_ms=%.2f driver_ms=%.2f" % [
			role_id, role, load_ms, presentation_ms,
			float(Time.get_ticks_usec() - presentation_started) / 1000.0 - presentation_ms,
		])
	return driver
