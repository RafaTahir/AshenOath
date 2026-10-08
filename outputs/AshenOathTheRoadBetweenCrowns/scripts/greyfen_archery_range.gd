extends Node3D

const Interactable = preload("res://scripts/interactable.gd")
const RANGE_NAME := "GreyfenArcheryRange"
const START := Vector3(6.8, 0, 12.7)
const FIRING_RECT := Rect2(5.7, 12.05, 2.4, 1.6)
const TARGET_LAYER := 128
const CHALLENGES := {
	"accuracy":{"name":"Rook's steady hand", "person":"rook", "shots":8, "seconds":60.0, "goal":24, "item":"travel_bread", "invite":"Rook's mark: twenty-four in eight arrows. He has written 'steady hand' twice and crossed out 'luck'.", "win":"Rook's mark beaten. He has left a note: Fine. The target must like you.", "loss":"Rook's mark stands. His next note reads: Best of as many as it takes. No stakes."},
	"timing":{"name":"Tor's pendulum", "person":"tor", "shots":8, "seconds":45.0, "goal":20, "item":"redroot_potion", "invite":"Tor's mark: twenty on a target moving to a fixed rhythm. Eight arrows in forty-five seconds. Don't argue with the swing.", "win":"Tor's mark beaten: You waited for the work instead of chasing it.", "loss":"Tor's mark stands: Watch a complete swing before your next arrow."},
	"distance":{"name":"Elna's long measure", "person":"elna", "shots":6, "seconds":60.0, "goal":18, "item":"bitterleaf_tonic", "invite":"Elna's mark: eighteen in six arrows. Two shots at each of three distances. The last rings count exactly as much as the first.", "win":"Elna's mark beaten: There. Far away doesn't mean beyond you.", "loss":"Elna's mark stands: Nothing lost but six practice arrows. They're made for losing."}
}
var game
var running := false
var mode := "practice"
var elapsed := 0.0
var score := 0
var shots := 0
var pending_shots := 0
var finishing := false
var equipment_before: Dictionary = {}
var camera_before: Dictionary = {}
var targets: Node3D
var ring_target: AnimatableBody3D
var shots_root: Node3D
var overlay: CanvasLayer
var readout: Label
var reticle: Label

static func install(host) -> void:
	if str(host.current_zone_id) != "greyfen" or host.zone_root.get_node_or_null(RANGE_NAME) != null:
		return
	var range_node = load("res://scripts/greyfen_archery_range.gd").new()
	range_node.name = RANGE_NAME
	range_node.game = host
	host.zone_root.add_child(range_node)
	range_node._build()

static func stop_activity(host) -> void:
	if host != null and is_instance_valid(host.zone_root):
		var range_node: Node = host.zone_root.get_node_or_null(RANGE_NAME)
		if range_node != null:
			range_node.cancel()

static func choose(host, action: Dictionary) -> void:
	host._resume_game()
	if str(host.current_zone_id) != "greyfen" or not is_instance_valid(host.zone_root):
		return
	var range_node: Node = host.zone_root.get_node_or_null(RANGE_NAME)
	if range_node != null:
		range_node.start(str(action.get("range_mode", "")))

func _build() -> void:
	var area = Interactable.new()
	area.setup("lr_archery", "story_activity", "Greyfen archery range")
	area.position = START
	area.build_collision(1.0)
	game.zone_root.add_child(area)
	area.add_to_group("story_activity")
	game._connect_interactable(area)
	var line := MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.06, 0.018, 1.45)
	line.mesh = line_mesh
	line.material_override = _material(Color(0.65, 0.62, 0.44))
	line.position = START + Vector3(0.75, 0.025, 0)
	add_child(line)
	# The short southern strip stays below the cemetery wall, inside the fence.
	# Targets collide with shots only; they cannot obstruct the player's routes.
	targets = Node3D.new()
	targets.name = "RangeTargets"
	add_child(targets)
	_target(Vector3(12.6, 1.25, 12.7), 0)
	var backstop := StaticBody3D.new()
	backstop.position = Vector3(13.25, 1.2, 12.7)
	backstop.collision_layer = TARGET_LAYER
	backstop.collision_mask = 0
	targets.add_child(backstop)
	var mesh := MeshInstance3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(0.12, 2.4, 1.7)
	mesh.mesh = board
	mesh.material_override = _material(Color(0.22, 0.25, 0.19))
	backstop.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = board.size
	shape.shape = box
	backstop.add_child(shape)
	shots_root = Node3D.new()
	shots_root.name = "TrainingShots"
	add_child(shots_root)
	overlay = CanvasLayer.new()
	overlay.layer = 18
	add_child(overlay)
	readout = Label.new()
	readout.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	readout.offset_left = -260
	readout.offset_right = 260
	readout.offset_top = -135
	readout.offset_bottom = -82
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.add_theme_font_size_override("font_size", 18)
	readout.add_theme_color_override("font_shadow_color", Color.BLACK)
	readout.add_theme_constant_override("shadow_offset_x", 1)
	readout.add_theme_constant_override("shadow_offset_y", 1)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(readout)
	reticle = Label.new()
	reticle.text = "+"
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left = -8
	reticle.offset_top = -12
	reticle.offset_right = 8
	reticle.offset_bottom = 12
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(reticle)
	overlay.hide()

func _target(point: Vector3, index: int) -> void:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	ring_target = body
	body.name = "RingTarget" + str(index)
	body.position = point
	body.collision_layer = TARGET_LAYER
	body.collision_mask = 0
	body.set_meta("range_owner", get_instance_id())
	body.set_meta("range_index", index)
	targets.add_child(body)
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.6
	cylinder.height = 0.1
	collision.shape = cylinder
	collision.rotation.z = PI * 0.5
	body.add_child(collision)
	for ring: int in range(3):
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = [0.6, 0.38, 0.15][ring]
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.04
		mesh.radial_segments = 32
		disc.mesh = mesh
		disc.rotation.z = PI * 0.5
		disc.position.x = -0.02 - ring * 0.025
		disc.material_override = _material([Color(0.65, 0.62, 0.44), Color(0.25, 0.40, 0.39), Color(0.62, 0.18, 0.14)][ring])
		body.add_child(disc)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material

func open_menu() -> void:
	if running:
		cancel()
	var best := int(game.story_state.get_flag("lr_range_best_practice", 0))
	game.get_tree().paused = true
	game.audio.set_game_paused(true)
	var pages: Array = [{"speaker":"The range", "speaker_id":"narrator", "text":"Eight training arrows. Outer ring 1, middle 3, centre 5. Your own ammunition stays in your pack. Personal best: %d." % best}]
	var actions: Array = [{"type":"range_choice", "label":"Untimed practice", "range_mode":"practice"}, {"type":"range_choice", "label":"Forty-five seconds", "range_mode":"timed"}]
	for id: String in CHALLENGES:
		var entry: Dictionary = CHALLENGES[id]
		var completed := bool(game.story_state.get_flag("lr_range_complete_" + id, false))
		var reward: String = "Supply already claimed; rematches are for the score." if bool(game.story_state.get_flag("lr_range_reward_" + id, false)) else "First win: one " + game.inventory.get_item_name(str(entry.item)) + "."
		pages.append({"speaker":"Posted challenge", "speaker_id":"narrator", "text":str(entry.invite) + "\n" + reward + " Best: %d." % int(game.story_state.get_flag("lr_range_best_" + id, 0))})
		actions.append({"type":"range_choice", "label":("Rematch: " if completed else "Try: ") + str(entry.name), "range_mode":id})
	actions.append({"type":"range_choice", "label":"Not today", "range_mode":"decline"})
	game.hud.show_dialogue({"name":"Greyfen range", "pages":pages, "actions":actions})

func _safe_to_start() -> bool:
	return game != null and is_instance_valid(game.player) and get_parent() == game.zone_root and str(game.current_zone_id) == "greyfen" and not game._journey_load_pending() and not game.zone_transition_pending and not game.story_action_in_progress and str(game.pending_ending) == "" and not game._story_has_active_combat() and game.player.health_component.health > 0.0 and game.player.is_on_floor()

func start(requested_mode: String) -> void:
	if requested_mode == "decline":
		game.hud.toast("The marks will keep. There are no stakes and no debt.")
		return
	if (requested_mode not in ["practice", "timed"] and not CHALLENGES.has(requested_mode)) or not _safe_to_start() or not FIRING_RECT.has_point(Vector2(game.player.global_position.x, game.player.global_position.z)):
		game.hud.toast("Stand by the range marker on the southern strip before starting.")
		return
	cancel()
	mode = requested_mode
	equipment_before = game.player.save_equipment_state()
	camera_before = game.camera_rig.save_activity_view()
	game.player.cancel_buffered_input("range_start")
	game.player.training_range = weakref(self)
	game.player._request_equipment("bow", game.player.get_selected_blade_id(), true)
	running = true
	elapsed = 0.0
	score = 0
	shots = 0
	pending_shots = 0
	finishing = false
	_update_target_motion()
	game.camera_rig.clear_target_lock()
	overlay.show()
	_update_readout()

func training_ready() -> bool:
	return running and not finishing and pending_shots == 0 and shots < _shot_limit() and _safe_to_start() and FIRING_RECT.has_point(Vector2(game.player.global_position.x, game.player.global_position.z))

func _shot_limit() -> int:
	return int(CHALLENGES[mode].shots) if CHALLENGES.has(mode) else 8

func _time_limit() -> float:
	return float(CHALLENGES[mode].seconds) if CHALLENGES.has(mode) else 45.0 if mode == "timed" else 0.0

func _update_target_motion() -> void:
	var distance: float = [10.0, 11.3, 12.6][mini(2, shots / 2)] if mode == "distance" else 12.6
	# Hold a distance until its in-flight shot resolves. Timing keeps the same
	# deterministic rail motion; a hit is still a physical swept collision.
	if mode != "distance" or pending_shots == 0:
		ring_target.position = Vector3(distance, 1.25, 12.7 + (sin(elapsed * 1.4) * 0.28 if mode == "timing" else 0.0))

func fire(request: Dictionary) -> void:
	if not training_ready() or int(request.get("training_owner", 0)) != get_instance_id():
		return
	shots += 1
	pending_shots += 1
	var projectile := TrainingArrow.new()
	projectile.activity = self
	projectile.position = request.origin
	projectile.direction = request.direction
	projectile.speed = lerpf(20.0, 34.0, float(request.get("draw_ratio", 0.0)))
	shots_root.add_child(projectile)
	projectile.top_level = true
	projectile.global_position = request.origin
	if shots >= _shot_limit():
		finishing = true
	_update_readout()

func shot_finished(collider: Object, point: Vector3) -> void:
	if not running:
		return
	pending_shots = maxi(0, pending_shots - 1)
	if is_instance_valid(collider) and int(collider.get_meta("range_owner", 0)) == get_instance_id():
		var center: Vector3 = (collider as Node3D).global_position
		var radius := Vector2(point.y - center.y, point.z - center.z).length()
		var points := 5 if radius <= 0.15 else 3 if radius <= 0.38 else 1
		score += points
		game.audio.play_event("light_hit", 0.02)
		game.hud.toast("Ring hit: +%d" % points, 1.0)
	_update_readout()

func _physics_process(delta: float) -> void:
	if not running:
		return
	if not _safe_to_start() or not FIRING_RECT.has_point(Vector2(game.player.global_position.x, game.player.global_position.z)) or not game.input_router.is_gameplay_context() or game.player.hurt_react_time > 0.0:
		cancel()
		return
	if not game.player.equipment_loadout.is_transitioning() and game.player.weapon_mode != "bow":
		cancel()
		return
	if not game.player.equipment_loadout.is_transitioning():
		elapsed += delta
	_update_target_motion()
	if _time_limit() > 0.0 and elapsed >= _time_limit():
		finishing = true
	if finishing and pending_shots == 0:
		_finish()
	else:
		_update_readout()

func _update_readout() -> void:
	var goal := " / %d" % int(CHALLENGES[mode].goal) if CHALLENGES.has(mode) else ""
	readout.text = "Range  %d%s points  |  %d / %d arrows%s" % [score, goal, shots, _shot_limit(), "  |  %ds" % maxi(0, ceili(_time_limit() - elapsed)) if _time_limit() > 0.0 else ""]

func _finish() -> void:
	var result := score
	var key := "lr_range_best_" + mode
	game.story_state.begin_change()
	if result > int(game.story_state.get_flag(key, 0)):
		game.story_state.set_flag(key, result)
	var words := "Range complete: %d points. Your equipment is restored." % result
	if CHALLENGES.has(mode):
		var entry: Dictionary = CHALLENGES[mode]
		var won := result >= int(entry.goal)
		words = str(entry.win if won else entry.loss) + " Score: %d." % result
		if won:
			game.story_state.set_flag("lr_range_complete_" + mode, true)
			var reward_key := "lr_range_reward_" + mode
			if not bool(game.story_state.get_flag(reward_key, false)):
				game.story_state.set_flag(reward_key, true)
				game.inventory.add_item(str(entry.item), 1)
				words += " Received " + game.inventory.get_item_name(str(entry.item)) + "."
			game.story_state.record_relationship_event({"id":"lr." + str(entry.person) + ".archery", "actor":entry.person, "kind":"friendship", "text":"Kael beat the posted " + str(entry.name) + " mark in Greyfen's free contest.", "acknowledgement":"You beat my mark. Rematch whenever you like; the supplies were for the first win, not a living."})
	game.story_state.end_change()
	cancel()
	game.hud.toast(words, 5.0)
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")

func cancel() -> void:
	if not running:
		return
	running = false
	if is_instance_valid(game) and is_instance_valid(game.player):
		game.player.training_range = null
		game.player.load_equipment_state(equipment_before)
	if is_instance_valid(game) and is_instance_valid(game.camera_rig):
		game.camera_rig.restore_activity_view(camera_before)
	if is_instance_valid(shots_root):
		for arrow in shots_root.get_children():
			arrow.queue_free()
	pending_shots = 0
	if is_instance_valid(ring_target):
		ring_target.position = Vector3(12.6, 1.25, 12.7)
	if is_instance_valid(overlay):
		overlay.hide()
	equipment_before.clear()
	camera_before.clear()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		cancel()

class TrainingArrow extends MeshInstance3D:
	var activity
	var direction := Vector3.RIGHT
	var speed := 30.0
	var age := 0.0

	func _ready() -> void:
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.009
		shaft.bottom_radius = 0.009
		shaft.height = 0.55
		shaft.radial_segments = 6
		mesh = shaft
		material_override = activity._material(Color(0.63, 0.49, 0.31))
		quaternion = Quaternion(Vector3.UP, direction.normalized())

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(activity) or not activity.running:
			queue_free()
			return
		age += delta
		var next := global_position + direction * speed * delta
		var query := PhysicsRayQueryParameters3D.create(global_position, next, 1 | TARGET_LAYER)
		query.exclude = [activity.game.player.get_rid()]
		query.collide_with_areas = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			activity.shot_finished(hit.collider, hit.position)
			queue_free()
		elif age >= 2.0:
			activity.shot_finished(null, next)
			queue_free()
		else:
			global_position = next
