extends CharacterBody3D

const ID := "bracken"
const QUEST := "side_bracken_rescue"
const RESCUE_POSITION := Vector3(-3.3, 0.02, -12.1)
const BODY := preload("res://assets/companions/bracken.scn")
const Interactable = preload("res://scripts/interactable.gd")
const Surface = preload("res://scripts/spatial_surface_contract.gd")
const CompanionPose = preload("res://scripts/companion_pose.gd")
const CLEARANCE := 0.55
const SCENT_TRAILS := {
	"wychwood": {
		"corpse": "Bracken noses the wheel ruts, then waits facing the broken cart.",
		"oren_token": "Bracken pauses at the edge of the path. His nose follows a small scrape through the leaves.",
		"tracks": "Bracken follows the disturbed earth with his nose, then looks back at you."
	}
}

var game: Node
var interaction: Area3D
var visual: Node3D
var animation_player: AnimationPlayer
var clips: Dictionary = {}
var tether: MeshInstance3D
var zone_id := ""
var command := "wait"
var adopted := false
var placement_pending := true
var arrival_out_of_view := false
var last_safe_position := RESCUE_POSITION
var route: Array[Vector3] = []
var route_refresh := 0.0
var steering_refresh := 0.0
var steering := Vector3.ZERO
var stuck_time := 0.0
var recovery_cooldown := 0.0
var placement_retry := 0.0
var care_pose: SkeletonModifier3D
var care_kind := ""
var care_elapsed := 0.0
var care_duration := 0.0
var care_approach_time := 0.0
var care_started := false
var care_player_start := Vector3.ZERO
var danger_refresh := 0.0
var threats: Array[Node3D] = []
var danger_witnessed := false
var quiet_time := 0.0
var sheltering := false
var shelter_target := Vector3.INF
var shelter_refresh := 0.0
var route_target := Vector3.INF
var scent_targets: Array[WeakRef] = []
var scent_target: WeakRef
var scent_scan := 0.0
var scent_cooldown := 0.0
var scent_remaining := 0.0
var trial_direction := Vector3.INF
var trial_cue_clock := 0.0

func set_trial_direction(point: Vector3) -> void:
	_cancel_scent()
	trial_direction = point
	trial_cue_clock = 0.0
	if care_pose != null:
		care_pose.pose("sniff", 1.4)

func clear_trial_direction() -> void:
	trial_direction = Vector3.INF
	if care_pose != null and care_kind == "":
		care_pose.clear()

func _trial_cue(delta: float) -> bool:
	var prior_clock := trial_cue_clock
	trial_cue_clock = fmod(trial_cue_clock + delta, 5.0)
	if trial_cue_clock < prior_clock and care_pose != null:
		care_pose.pose("sniff", 1.4)
	if trial_cue_clock >= 1.4:
		if care_pose != null:
			care_pose.clear()
		return false
	var direction := trial_direction - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 5.0 * delta))
	return true

static func install(host: Node, zone_root: Node3D, active_zone: String, unseen_arrival: bool = false) -> void:
	if zone_root != host.zone_root:
		return
	var recruited: bool = str(host.story_state.get_flag("bracken_home", "")) == "adopted"
	host.input_router.companion_available = recruited
	var strap := _rescue_tether(zone_root, active_zone)
	if strap != null:
		strap.visible = not bool(host.story_state.get_flag("bracken_rescued", false))
	var travel := saved_travel(host)
	var companion := zone_root.get_node_or_null("Bracken")
	var belongs_here: bool = (recruited and (str(travel.command) == "follow" or str(travel.zone) == active_zone)) or (not recruited and active_zone == "greyfen")
	if not belongs_here:
		if companion != null:
			zone_root.remove_child(companion)
			companion.queue_free()
		return
	if companion == null:
		companion = load("res://scripts/companion_controller.gd").new()
		companion.name = "Bracken"
		companion.game = host
		companion.zone_id = active_zone
		companion.arrival_out_of_view = unseen_arrival
		zone_root.add_child(companion)
	companion.tether = strap
	companion.refresh_presence()

static func saved_travel(host: Node) -> Dictionary:
	var raw: Variant = host.story_state.get_flag("bracken_travel", {})
	var data: Dictionary = raw if raw is Dictionary else {}
	var position := RESCUE_POSITION
	var coordinates: Variant = data.get("position", [])
	if coordinates is Array and coordinates.size() == 3:
		var valid := true
		for value: Variant in coordinates:
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or absf(float(value)) > 1000.0:
				valid = false
		if valid:
			position = Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
	return {"command": "wait" if str(data.get("command", "follow")) == "wait" else "follow", "zone": host.save_manager._normalize_zone(str(data.get("zone", "greyfen"))), "position": position}

static func capture(host: Node) -> void:
	if not is_instance_valid(host.zone_root):
		return
	var companion: Node = host.zone_root.get_node_or_null("Bracken")
	if companion != null:
		companion.capture_state()

static func depart(host: Node) -> void:
	if not is_instance_valid(host.zone_root):
		return
	# Loading another earned save has already restored its story state. Never
	# overwrite that state with the actor from the journey being left.
	if host.pending_player_restore.is_empty():
		capture(host)
	var companion: Node = host.zone_root.get_node_or_null("Bracken")
	if companion != null:
		companion.cancel_care()
		host.zone_root.remove_child(companion)
		companion.queue_free()

static func issue_command(host: Node, request: String) -> bool:
	if request not in ["follow", "wait", "recall"] or str(host.story_state.get_flag("bracken_home", "")) != "adopted":
		return false
	if not host.game_started or host._journey_load_pending() or host.zone_transition_pending or not host.pending_player_restore.is_empty():
		return false
	preload("res://scripts/bracken_field_trial.gd").stop_activity(host)
	capture(host)
	var present: Node = host.zone_root.get_node_or_null("Bracken")
	if present != null:
		present.cancel_care()
	var data := saved_travel(host)
	var point: Vector3 = data.position
	data.command = "wait" if request == "wait" else "follow"
	data.position = [point.x, point.y, point.z]
	host.story_state.set_flag("bracken_travel", data)
	install(host, host.zone_root, host.current_zone_id, true)
	host.hud.toast("Bracken will wait in " + str(data.zone).replace("_", " ").capitalize() + "." if request == "wait" else "Bracken will follow the safe road to you.")
	host.save_manager.autosave(host)
	return true

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 0.7
	shape.shape = capsule
	shape.position.y = 0.35
	add_child(shape)
	visual = BODY.instantiate()
	visual.name = "Visual"
	visual.rotation.y = PI
	add_child(visual)
	clips = visual.get_meta("animation_clips", {})
	animation_player = visual.find_child("AnimationPlayer", true, false)
	animation_player.play(str(clips.idle))
	var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons := visual.find_children("*", "Skeleton3D", true, false)
		skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if skeleton != null:
		care_pose = CompanionPose.new()
		care_pose.name = "BrackenCarePose"
		care_pose.configure(skeleton)
		skeleton.add_child(care_pose)
	interaction = Interactable.new()
	interaction.setup(ID, "dialogue", "Approach Bracken")
	interaction.display_name = "Bracken"
	interaction.dialogue_id = "bracken_rescue"
	interaction.set_meta("dialogue_focus_height", 0.55)
	interaction.build_collision(1.15)
	add_child(interaction)
	hide()
	refresh_presence()

func _physics_process(delta: float) -> void:
	if game == null or get_parent() != game.zone_root or zone_id != str(game.current_zone_id) or not game.game_started or game.zone_transition_pending or game._journey_load_pending() or not is_instance_valid(game.player):
		return
	if placement_pending:
		placement_retry -= delta
		if placement_retry > 0.0:
			return
		placement_retry = 0.25
		if not _place_on_arrival():
			return
	if not game.input_router.is_gameplay_context():
		cancel_care()
		_cancel_scent()
		velocity = Vector3.ZERO
		_set_animation(0.0)
		return
	var previous := global_position
	var wanted := Vector3.ZERO
	_update_danger(delta)
	if care_kind != "":
		wanted = _care_velocity(delta)
	elif sheltering:
		wanted = _shelter_velocity(delta)
	elif adopted and trial_direction.is_finite():
		if not _trial_cue(delta):
			wanted = _follow_velocity(delta)
	elif adopted and command == "follow":
		if not _scent_reaction(delta):
			wanted = _follow_velocity(delta)
	velocity.x = move_toward(velocity.x, wanted.x, 9.0 * delta)
	velocity.z = move_toward(velocity.z, wanted.z, 9.0 * delta)
	# Validate the real next step as well as the planned route; move_and_slide
	# remains authoritative for physical contacts, never direct position spacing.
	var step := global_position + Vector3(velocity.x, 0.0, velocity.z) * delta
	if not _step_clear(global_position, step):
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	var motion := global_position - previous
	motion.y = 0.0
	var speed := motion.length() / maxf(delta, 0.001)
	if speed > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-motion.x, -motion.z), minf(1.0, 9.0 * delta))
	_set_animation(speed)
	if is_on_floor() and not game.spatial_service.is_river_excluded(global_position, CLEARANCE):
		last_safe_position = global_position
	stuck_time = stuck_time + delta if adopted and command == "follow" and not sheltering and care_kind == "" and _flat_distance(global_position, game.player.global_position) > 3.5 and speed < 0.08 else 0.0
	recovery_cooldown = maxf(0.0, recovery_cooldown - delta)
	if adopted and command == "follow" and not trial_direction.is_finite() and not sheltering and care_kind == "" and recovery_cooldown <= 0.0 and (stuck_time > 5.0 or global_position.y < -3.0):
		_recover_out_of_view()

func refresh_presence() -> void:
	if interaction == null or game == null:
		return
	var rescued: bool = bool(game.story_state.get_flag("bracken_rescued", false))
	adopted = str(game.story_state.get_flag("bracken_home", "")) == "adopted"
	command = str(saved_travel(game).command) if adopted else "wait"
	if command == "wait":
		velocity = Vector3.ZERO
	game.input_router.companion_available = adopted
	interaction.state_label = ("Waiting" if command == "wait" else "Walking with Kael") if adopted else ("Safe beside the north road" if rescued else "Caught by a travelling strap")
	route.clear()
	route_refresh = 0.0
	if tether != null:
		tether.visible = not rescued
	game.interaction_focus_dirty = true
	_refresh_scent_targets()

func capture_state() -> void:
	if not adopted or placement_pending or get_parent() != game.zone_root:
		return
	var position := last_safe_position
	var data := {"command": command, "zone": zone_id, "position": [position.x, position.y, position.z]}
	if game.story_state.get_flag("bracken_travel", {}) != data:
		game.story_state.set_flag("bracken_travel", data)

func _place_on_arrival() -> bool:
	if not is_instance_valid(game.spatial_service):
		return false
	var travel := saved_travel(game)
	var desired: Vector3 = travel.position if adopted else RESCUE_POSITION
	var point: Variant = null
	if not adopted or str(travel.zone) == zone_id:
		var safe: Vector3 = game.spatial_service.validate_position(desired, CLEARANCE, game.spatial_service.bank_for(desired))
		point = _supported_anchor(safe)
		if point == null:
			point = _supported_anchor(game.spatial_service.nearest_safe(desired, game.spatial_service.bank_for(desired)))
	else:
		point = _arrival_behind_player(arrival_out_of_view)
	if point == null or (arrival_out_of_view and not _outside_camera(point)):
		return false
	global_position = point
	last_safe_position = point
	velocity = Vector3.ZERO
	placement_pending = false
	show()
	game._connect_interactable(interaction)
	capture_state()
	_record_arrival()
	return true

func _record_arrival() -> void:
	var changed := false
	if bool(game.story_state.get_flag("bracken_rescued", false)):
		changed = game.story_state.remember_companion_event("rescue", "greyfen")
	if adopted and zone_id != "greyfen" and not bool(game.story_state.get_flag("bracken_left_home", false)):
		game.story_state.set_flag("bracken_left_home", true)
		changed = true
	if adopted and zone_id == "greyfen" and bool(game.story_state.get_flag("bracken_left_home", false)):
		if game.story_state.remember_companion_event("return_home", zone_id):
			game.hud.toast("Bracken recognizes Greyfen's road. This time, you have come back together.")
			changed = true
	if changed:
		_save_bond()

func _save_bond() -> void:
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")

func _arrival_behind_player(unseen: bool) -> Variant:
	var player := game.player as Node3D
	var behind: Vector3 = player.global_basis.z.normalized()
	behind.y = 0.0
	var bank: int = game.spatial_service.bank_for(player.global_position)
	for distance: float in [2.3, 3.4, 4.8]:
		for angle: float in [0.0, -0.65, 0.65, -1.2, 1.2]:
			var candidate: Vector3 = player.global_position + behind.rotated(Vector3.UP, angle) * distance
			if game.spatial_service.bank_for(candidate) != bank:
				continue
			var point: Variant = _supported_anchor(candidate)
			if point == null or not game.spatial_service.validate_runtime_segment(player.global_position, point, CLEARANCE, self):
				continue
			if not unseen or _outside_camera(point):
				return point
	return null

func _supported_anchor(candidate: Vector3) -> Variant:
	var service: Node = game.spatial_service
	if not service.is_walkable_position(candidate, CLEARANCE, service.bank_for(candidate)):
		return null
	var excluded: Array[RID] = [get_rid(), game.player.get_rid()]
	var hit: Dictionary = Surface.support_hit(get_world_3d().direct_space_state, candidate + Vector3.UP * 1.5, candidate - Vector3.UP * 2.5, excluded)
	if hit.is_empty():
		return null
	var point: Vector3 = hit.position + Vector3.UP * 0.015
	if service.is_position_occupied(point, 0.27, 0.8) or service.is_river_excluded(point, CLEARANCE):
		return null
	return point

func _follow_velocity(delta: float) -> Vector3:
	var player := game.player as Node3D
	var separation := player.global_position.distance_to(global_position)
	if separation < 1.65:
		return Vector3.ZERO
	var target: Vector3 = player.global_position + player.global_basis.z * 2.0 + player.global_basis.x * 0.85
	if game.spatial_service.is_on_bridge(player.global_position, CLEARANCE):
		target.x = 0.0
	if not game.spatial_service.is_walkable_position(target, CLEARANCE, game.spatial_service.bank_for(player.global_position)):
		target = player.global_position
	return _route_velocity(target, clampf((separation - 1.6), 0.0, 3.8), delta)

func _route_velocity(target: Vector3, speed: float, delta: float, player_clearance: float = 1.25) -> Vector3:
	route_refresh -= delta
	if route_refresh <= 0.0 or route_target.distance_squared_to(target) > 0.36:
		route_refresh = 0.65
		route_target = target
		route = game.spatial_service.build_route(global_position, target, CLEARANCE)
		if not route.is_empty():
			route.remove_at(0)
	while not route.is_empty() and _flat_distance(global_position, route[0]) < 0.35:
		route.remove_at(0)
	if route.is_empty():
		return Vector3.ZERO
	var direction := route[0] - global_position
	direction.y = 0.0
	direction = direction.normalized()
	steering_refresh -= delta
	if steering_refresh <= 0.0:
		steering_refresh = 0.10
		steering = Vector3.ZERO
		for angle: float in [0.0, 0.5, -0.5, 0.95, -0.95, 1.4, -1.4]:
			var candidate_direction := direction.rotated(Vector3.UP, angle)
			var end := global_position + candidate_direction * 0.75
			if _flat_distance(end, game.player.global_position) < player_clearance or not _step_clear(global_position, end):
				continue
			steering = candidate_direction
			break
	return steering * speed

func _update_danger(delta: float) -> void:
	if not adopted:
		return
	danger_refresh -= delta
	if danger_refresh <= 0.0:
		danger_refresh = 0.4
		threats.clear()
		for enemy: Node in game.active_enemies:
			if not is_instance_valid(enemy) or bool(enemy.dead) or not bool(enemy.encounter_active) or bool(enemy.get_meta("story_surrender_protected", false)):
				continue
			if enemy.global_position.distance_squared_to(game.player.global_position) < 225.0:
				threats.append(enemy)
	var heavy := threats.size() >= 2
	for enemy: Node3D in threats:
		if is_instance_valid(enemy) and (bool(enemy.get("is_boss")) or enemy.global_position.distance_squared_to(global_position) < 25.0):
			heavy = true
	if not threats.is_empty():
		danger_witnessed = true
		quiet_time = 0.0
		cancel_care()
		_cancel_scent()
		if heavy and not sheltering:
			sheltering = true
			shelter_refresh = 0.0
			shelter_target = Vector3.INF
			interaction.state_label = "Seeking shelter"
	else:
		quiet_time += delta
		if quiet_time >= 3.0:
			if sheltering:
				sheltering = false
				shelter_target = Vector3.INF
				refresh_presence()
			if danger_witnessed and float(game.player.health_component.health) > 0.0:
				danger_witnessed = false
				if game.story_state.remember_companion_event("survived_danger", zone_id):
					game.hud.toast("The danger passes. Bracken finds your step again.")
					_save_bond()

func _shelter_velocity(delta: float) -> Vector3:
	shelter_refresh -= delta
	if shelter_refresh <= 0.0:
		shelter_refresh = 1.5
		var away := Vector3.ZERO
		for enemy: Node3D in threats:
			if is_instance_valid(enemy):
				away += (global_position - enemy.global_position).normalized()
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = game.player.global_basis.z
		var best := _threat_clearance(global_position)
		for angle: float in [0.0, -0.65, 0.65, -1.3, 1.3]:
			for distance: float in [2.5, 4.0, 6.0]:
				var point: Variant = _supported_anchor(global_position + away.normalized().rotated(Vector3.UP, angle) * distance)
				if point == null or game.spatial_service.bank_for(point) != game.spatial_service.bank_for(global_position):
					continue
				if not game.spatial_service.validate_runtime_segment(global_position, point, CLEARANCE, self):
					continue
				var clearance := _threat_clearance(point)
				if clearance > best + 1.0 and _flat_distance(point, game.player.global_position) < 16.0:
					best = clearance
					shelter_target = point
	if shelter_target == Vector3.INF or _flat_distance(global_position, shelter_target) < 0.5:
		return Vector3.ZERO
	return _route_velocity(shelter_target, 3.2, delta)

func _threat_clearance(point: Vector3) -> float:
	var distance := 99.0
	for enemy: Node3D in threats:
		if is_instance_valid(enemy):
			distance = minf(distance, _flat_distance(point, enemy.global_position))
	return distance

func begin_care(kind: String) -> bool:
	if care_kind != "" or kind not in ["pet", "feed", "rest"]:
		return false
	if kind == "feed" and not game.inventory.can_consume("travel_bread"):
		game.hud.toast("No travel bread left. Mira stocks it; Bracken needs no feeding to stay with you.")
		return false
	care_kind = kind
	_cancel_scent()
	care_elapsed = 0.0
	care_approach_time = 0.0
	care_started = false
	care_duration = 5.0 if kind == "rest" else 2.4
	care_player_start = game.player.global_position
	route_refresh = 0.0
	game.player._request_equipment(game.player.weapon_mode, game.player.get_selected_blade_id(), false)
	return true

func _care_velocity(delta: float) -> Vector3:
	var player: Node3D = game.player
	if not threats.is_empty() or float(player.health_component.health) <= 0.0 or _flat_distance(player.global_position, care_player_start) > 0.35 or float(player.hurt_react_time) > 0.0 or float(player.attack_anim_time) > 0.0 or str(player.beam_cast_state) != "":
		cancel_care()
		return Vector3.ZERO
	if player.equipment_loadout.is_drawn() and (not player.equipment_loadout.is_transitioning() or str(player.equipment_loadout.transition) != "sheath" or care_started):
		cancel_care()
		return Vector3.ZERO
	if not care_started:
		care_approach_time += delta
		if care_approach_time > 5.0:
			cancel_care()
			game.hud.toast("Bracken cannot find a clear step here. Try a little farther from the road's edge.")
			return Vector3.ZERO
		if player.equipment_loadout.is_transitioning():
			return Vector3.ZERO
		if care_kind != "rest" and _flat_distance(global_position, player.global_position) > 1.20:
			var toward: Vector3 = (global_position - player.global_position).normalized()
			var destination: Vector3 = player.global_position + toward * 0.82
			return _route_velocity(destination, 1.2, delta, 0.70)
		care_started = true
		var facing: Vector3 = player.global_position - global_position
		rotation.y = atan2(-facing.x, -facing.z)
		if care_pose != null:
			care_pose.pose(care_kind, care_duration)
		player.begin_companion_gesture(self, care_kind, care_duration)
		game.hud.toast("Kael breaks off a share of bread." if care_kind == "feed" else ("For a little while, neither of you asks anything of the other." if care_kind == "rest" else "Bracken leans into the offered hand."))
	care_elapsed += delta
	if care_elapsed >= care_duration:
		var finished := care_kind
		cancel_care()
		if finished == "feed" and not game.inventory.consume("travel_bread"):
			return Vector3.ZERO
		if finished == "rest" and game.story_state.has_heard_testimony():
			game.story_state.remember_companion_event("rest_after_testimony", zone_id)
		game.hud.toast(game.story_state.companion_response())
		_save_bond()
	return Vector3.ZERO

func care_contact_point(kind: String) -> Vector3:
	if care_pose != null and int(care_pose.head) >= 0:
		var rig := care_pose.get_skeleton()
		if rig != null:
			return rig.global_transform * rig.get_bone_global_pose(int(care_pose.head)).origin + Vector3.UP * (0.05 if kind == "pet" else -0.03)
	return global_position + Vector3.UP * 0.64 - global_basis.z * 0.32

func cancel_care() -> void:
	if care_kind == "":
		return
	care_kind = ""
	care_started = false
	if care_pose != null:
		care_pose.clear()
	if game != null and is_instance_valid(game.player):
		game.player.end_companion_gesture()
	route_refresh = 0.0
	velocity.x = 0.0
	velocity.z = 0.0

func _exit_tree() -> void:
	cancel_care()

func _refresh_scent_targets() -> void:
	scent_targets.clear()
	_cancel_scent()
	if not adopted or command != "follow":
		return
	for id: String in SCENT_TRAILS.get(zone_id, {}):
		var area: Node = game.zone_root.find_child(id, true, false)
		if area is Area3D:
			scent_targets.append(weakref(area))

func _scent_available(area: Node) -> bool:
	if not is_instance_valid(area) or area.is_queued_for_deletion() or not game.zone_root.is_ancestor_of(area):
		return false
	if not area.is_interaction_enabled() or str(area.interaction_type) != "clue" or str(area.quest_id) != "main_road_of_crows":
		return false
	return game.quests.is_active(str(area.quest_id)) and not game.quests.is_objective_done(str(area.quest_id), str(area.objective_id))

func _scent_reaction(delta: float) -> bool:
	scent_cooldown = maxf(0.0, scent_cooldown - delta)
	if not threats.is_empty() or float(game.player.velocity.length()) > 4.2:
		_cancel_scent()
		return false
	if scent_remaining > 0.0:
		var area: Node3D = scent_target.get_ref() if scent_target != null else null
		if not _scent_available(area) or _flat_distance(game.player.global_position, global_position) > 6.0:
			_cancel_scent()
			return false
		scent_remaining -= delta
		var direction := area.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * 5.0, 1.0))
		if scent_remaining <= 0.0:
			_cancel_scent()
		return true
	scent_scan -= delta
	if scent_scan > 0.0 or scent_cooldown > 0.0:
		return false
	scent_scan = 0.8
	var raw_seen: Variant = game.story_state.get_flag("bracken_scent_seen", {})
	var seen: Dictionary = raw_seen.duplicate(true) if raw_seen is Dictionary else {}
	for candidate: WeakRef in scent_targets:
		var area: Node3D = candidate.get_ref()
		if not _scent_available(area) or seen.has(str(area.interaction_id)):
			continue
		if _flat_distance(area.global_position, global_position) > 5.5 or _flat_distance(area.global_position, game.player.global_position) > 7.0:
			continue
		if game.spatial_service.bank_for(area.global_position) != game.spatial_service.bank_for(global_position):
			continue
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, area.global_position + Vector3.UP * 0.5, 1, [get_rid(), game.player.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		scent_target = candidate
		scent_remaining = 2.8
		scent_cooldown = 18.0
		velocity.x = 0.0
		velocity.z = 0.0
		if care_pose != null:
			care_pose.pose("sniff", scent_remaining)
		game.hud.toast(str(SCENT_TRAILS[zone_id][str(area.interaction_id)]), 4.0)
		# This records only a reaction already shown. It never collects the clue,
		# earns evidence, reveals a quest target or substitutes for player input.
		seen[str(area.interaction_id)] = true
		game.story_state.set_flag("bracken_scent_seen", seen)
		_save_bond()
		return true
	return false

func _cancel_scent() -> void:
	if scent_remaining > 0.0 and care_pose != null:
		care_pose.clear()
	scent_remaining = 0.0
	scent_target = null

func _step_clear(start: Vector3, end: Vector3) -> bool:
	if not is_instance_valid(game.spatial_service) or not game.spatial_service.validate_runtime_segment(start, end, CLEARANCE, self):
		return false
	var excluded: Array[RID] = [get_rid(), game.player.get_rid()]
	var hit: Dictionary = Surface.support_hit(get_world_3d().direct_space_state, end + Vector3.UP * 0.55, end - Vector3.UP * 0.7, excluded)
	return not hit.is_empty() and absf(float(hit.position.y) - start.y) < 0.38

func _recover_out_of_view() -> void:
	recovery_cooldown = 2.0
	if not _outside_camera(global_position):
		return
	var point: Variant = _arrival_behind_player(true)
	if point == null or game.spatial_service.bank_for(point) != game.spatial_service.bank_for(last_safe_position):
		return
	global_position = point
	last_safe_position = point
	velocity = Vector3.ZERO
	stuck_time = 0.0
	route.clear()
	route_refresh = 0.0

func _outside_camera(point: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	for x: float in [-0.65, 0.0, 0.65]:
		for z: float in [-0.85, 0.0, 0.85]:
			for y: float in [0.0, 0.8]:
				if camera.is_position_in_frustum(point + Vector3(x, y, z)):
					return false
	return true

func _set_animation(speed: float) -> void:
	var clip: String = str(clips.walk if speed > 0.08 else clips.idle)
	if str(animation_player.current_animation) != clip:
		animation_player.play(clip, 0.16)
	animation_player.speed_scale = clampf(speed / 1.7, 0.55, 2.0) if speed > 0.08 else 1.0

func _flat_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length()

static func choice_available(host: Node, action: Dictionary) -> bool:
	# Dialogue closes and releases proximity focus before dispatching its action.
	# Bind the actual staged actor, then recheck it against the live zone.
	var actor_id: int = int(action.get("companion_actor_instance", 0))
	var actor: Node = instance_from_id(actor_id) if actor_id > 0 else null
	if not is_instance_valid(actor) or not actor is Area3D:
		return false
	if actor.is_queued_for_deletion() or not actor.is_visible_in_tree() or not is_instance_valid(host.zone_root) or not host.zone_root.is_ancestor_of(actor) or str(actor.get("interaction_id")) != ID:
		return false
	if not is_instance_valid(host.player) or host.player.global_position.distance_to(actor.global_position) > 3.6:
		return false
	if host._story_has_active_combat():
		return false
	var state = host.story_state
	var step := str(action.get("companion_action", ""))
	if step in ["pet", "feed", "rest"]:
		var body: Node = actor.get_parent()
		return str(state.get_flag("bracken_home", "")) == "adopted" and body.care_kind == "" and not body.placement_pending and not body.sheltering
	if str(host.current_zone_id) != "greyfen":
		return false
	match str(action.get("companion_action", "")):
		"calm": return not bool(state.get_flag("bracken_calmed", false))
		"release": return bool(state.get_flag("bracken_calmed", false)) and not bool(state.get_flag("bracken_rescued", false))
		"adopt": return bool(state.get_flag("bracken_rescued", false)) and str(state.get_flag("bracken_home", "")) != "adopted"
		"leave": return bool(state.get_flag("bracken_rescued", false)) and str(state.get_flag("bracken_home", "")) == ""
	return false

static func apply_choice(host: Node, action: Dictionary) -> bool:
	if not choice_available(host, action):
		return false
	var state = host.story_state
	var step: String = str(action.get("companion_action", ""))
	if step in ["pet", "feed", "rest"]:
		var area: Node = instance_from_id(int(action.get("companion_actor_instance", 0)))
		return area.get_parent().begin_care(step)
	state.set_flag("bracken_companion_id", ID)
	if step == "calm":
		if not host.quests.is_active(QUEST) and not host.quests.is_completed(QUEST):
			host.quests.start_quest(QUEST)
		state.set_flag("bracken_calmed", true)
		host.quests.complete_objective(QUEST, "calm_hound")
		host.hud.toast("He stops pulling. The old strap is caught, not his leg.")
	elif step == "release":
		state.set_flag("bracken_rescued", true)
		state.remember_companion_event("rescue", "greyfen")
		host.quests.complete_objective(QUEST, "release_strap")
		host.hud.toast("The strap falls away. The hound steps clear and waits.")
	else:
		state.set_flag("bracken_home", "adopted" if step == "adopt" else "safe")
		state.set_flag("bracken_home_zone", "greyfen")
		host.quests.complete_choice(QUEST, "companion_choice")
		host.hud.toast("Bracken accepts your hand. He can rest safely at Greyfen." if step == "adopt" else "Bracken stays safe by Greyfen. You can return to him later.")
	return true

static func _rescue_tether(parent: Node3D, active_zone: String) -> MeshInstance3D:
	# A ground prop, not anatomy attached to an unvalidated bone. The loose
	# strap disappears on release; the discarded loops remain by the road.
	if active_zone != "greyfen":
		return null
	var props := parent.get_node_or_null("BrackenRescueProps") as Node3D
	if props != null:
		return props.get_node_or_null("CaughtStrap") as MeshInstance3D
	props = Node3D.new()
	props.name = "BrackenRescueProps"
	props.position = RESCUE_POSITION
	parent.add_child(props)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.16, 0.10)
	material.roughness = 0.95
	var vertices := PackedVector3Array()
	for center: Vector3 in [Vector3(-0.57, 0.035, 0.1), Vector3(-0.65, 0.045, 0.4)]:
		for i in range(18):
			var angle: float = TAU * float(i) / 18.0
			var next: float = TAU * float(i + 1) / 18.0
			var a := center + Vector3(cos(angle) * 0.31, 0, sin(angle) * 0.22)
			var b := center + Vector3(cos(next) * 0.31, 0, sin(next) * 0.22)
			var inner_a := center + (a - center) * 0.77
			var inner_b := center + (b - center) * 0.77
			vertices.append_array(PackedVector3Array([a, inner_a, b, b, inner_a, inner_b]))
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var harness := MeshInstance3D.new()
	harness.name = "DiscardedTravellingHarness"
	harness.mesh = mesh
	harness.material_override = material
	props.add_child(harness)
	var caught_strap := MeshInstance3D.new()
	caught_strap.name = "CaughtStrap"
	var strap := BoxMesh.new()
	strap.size = Vector3(0.035, 0.025, 0.50)
	caught_strap.mesh = strap
	caught_strap.material_override = material
	caught_strap.position = Vector3(-0.23, 0.12, 0.38)
	caught_strap.rotation_degrees = Vector3(-24, -50, 0)
	props.add_child(caught_strap)
	return caught_strap
