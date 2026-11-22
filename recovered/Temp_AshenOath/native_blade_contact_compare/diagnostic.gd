extends SceneTree

const Player = preload("res://scripts/player_controller.gd")
const Router = preload("res://scripts/input_router.gd")
const Camera = preload("res://scripts/camera_controller.gd")
const Combat = preload("res://scripts/combat_manager.gd")
const Health = preload("res://scripts/health_component.gd")
const STEP := 1.0 / 60.0

class Target extends CharacterBody3D:
	var dead := false
	var display_name := "M19 capsule diagnostic"
	var tag := "beast"
	var health_component: Node
	func is_encounter_active() -> bool:
		return true
	func apply_damage(amount: float, _source: String = "") -> void:
		health_component.damage(amount)

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

var player: Node3D
var router: Node
var rig: Node3D
var enemy: Target
var combat: Node
var graph_script: Script
var graph_path := ""
var output := ""
var current_contacts: Array = []
var error_log := ErrorLog.new()
var cases: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.add_logger(error_log)
	var args := OS.get_cmdline_user_args()
	graph_path = args[args.find("--graph") + 1]
	output = args[args.find("--output") + 1]
	graph_script = load(graph_path)
	var floor := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(24, 0.4, 24)
	ground_shape.shape = ground_box
	floor.add_child(ground_shape)
	floor.position = Vector3(3, -0.2, -5.3)
	root.add_child(floor)
	router = Router.new()
	root.add_child(router)
	router.set_physics_process(false)
	player = Player.new()
	player.name = "ActualNativeP01BladeDiagnostic"
	root.add_child(player) # Actual production _ready builds prepared rig + gear.
	player.set_physics_process(false)
	player.set_process(false)
	player.input_source = router
	if not player.has_required_body() or player.animation_driver == null or not player.animation_driver.is_valid() or player.blade_base_marker == null:
		push_error("Required native prepared P01/rig/modeled blade did not configure")
		quit(2)
		return
	rig = Camera.new()
	root.add_child(rig)
	rig.setup(player, router)
	rig.set_process(false)
	rig.set_physics_process(false)
	player.camera_controller = rig
	enemy = Target.new()
	enemy.health_component = Health.new()
	enemy.add_child(enemy.health_component)
	enemy.health_component.configure(75.0)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.65
	collision.shape = capsule
	collision.position.y = 1.65 * 0.5 + 0.34 * 0.18
	enemy.add_child(collision)
	root.add_child(enemy)
	rig.set_enemy_candidates([enemy])
	combat = Combat.new()
	root.add_child(combat)
	player.blade_contact_requested.connect(_on_contact)
	router.input_context_changed.connect(func(_context: String): player.cancel_buffered_input("context_change"))
	router.transient_input_reset.connect(func(reason: String): player.cancel_buffered_input(reason))
	for heading: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
		for locked: bool in [false, true]:
			await _case(heading, locked)
	await _browser_sequence()
	var body: Node3D = player._mapped_body
	var receipt := {"status":"RECORDED", "graph_path":graph_path, "graph_sha256":FileAccess.get_sha256(graph_path),
		"actual_player_source":str(body.get_meta("prepared_actor_source", body.get_meta("runtime_asset_path", ""))),
		"prepared_actor_resource":str(body.get_meta("prepared_actor_resource", "")),
		"actual_textured_body":player.has_required_body(), "skeleton_bones":player.animation_driver.skeleton.get_bone_count(),
		"sword_source":player.MODELED_SWORD_PATH, "blade_marker_parent":str(player.blade_base_marker.get_parent().get_path()),
		"attack_clip":str(player.animation_driver.get_clip_for_state("attack_light")),
		"capsule":{"height":1.65,"radius":0.34,"center_y":collision.position.y}, "cases":cases,
		"errors":error_log.errors, "limits":"Actual prepared P01 and modeled weapon/markers; synthetic keyboard input; synthetic M19 capsule only; no world/other actor model or user save. No gameplay acceptance implied."}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t",true)+"\n")
	print("NATIVE BLADE CONTACT DIAGNOSTIC: RECORDED cases=", cases.size(), " errors=",error_log.errors.size(), " output=",output)
	OS.remove_logger(error_log)
	quit(0 if error_log.errors.is_empty() else 1)

func _replace_graph() -> void:
	var driver: Node = player.animation_driver
	if driver.animation_graph != null and is_instance_valid(driver.animation_graph.tree):
		driver.animation_graph.tree.active = false
		driver.animation_graph.tree.free()
	var clips := {}
	for logical: String in driver.resolved_clip_map:
		if driver.resolved_clip_map[logical] != StringName():
			clips[logical] = driver.resolved_clip_map[logical]
	var directions := {"walk_back":driver._playback_direction_for_state("walk_back") > 0.0,
		"run_back":driver._playback_direction_for_state("run_back") > 0.0}
	driver.animation_graph = graph_script.new()
	assert(driver.animation_graph.configure(driver, driver.animation_player, clips, directions, driver.locomotion_height_scale))
	driver.current_state = ""
	driver.set_external_tick(true)
	driver._reconcile_clock()
	driver._play_state("idle", 0.0)

func _reset(heading: float, initial_facing: float) -> void:
	rig.clear_target_lock()
	router.reset_transient_input("diagnostic_reset")
	router.set_gameplay_context()
	player.reset_for_journey_restore()
	player.equipment_loadout.set_sword_drawn(true)
	player.position = Vector3(3, 0, -5.3)
	player.rotation.y = initial_facing
	player.can_control = true
	player.set_transition_locked(false)
	player.velocity = Vector3.ZERO
	enemy.position = player.position - Basis(Vector3.UP, heading).z * 1.6
	enemy.health_component.configure(75.0)
	rig.yaw = initial_facing
	rig.reset_follow()
	_replace_graph()
	for _index in 20:
		await _tick()

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _mouse(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tick() -> void:
	await physics_frame
	router._physics_process(STEP)
	rig._physics_process(STEP)
	player._physics_process(STEP)
	rig._process(STEP)

func _lock() -> bool:
	_key(KEY_T, true)
	await _tick()
	_key(KEY_T, false)
	for _index in 120:
		await _tick()
		var offset: Vector3 = enemy.position - player.position
		if rig.get_locked_combat_target() == enemy and absf(angle_difference(rig.yaw, atan2(-offset.x,-offset.z))) < 0.01:
			return true
	return false

func _case(heading: float, locked: bool) -> void:
	await _reset(heading, heading)
	var lock_ok: bool = await _lock() if locked else true
	var record := {"name":"heading_%d_%s" % [roundi(rad_to_deg(heading)), "locked" if locked else "unlocked"],
		"target_heading":heading, "locked":locked, "lock_established":lock_ok, "strikes":[]}
	for _index in 2:
		record.strikes.append(await _strike())
	cases.append(record)

func _browser_sequence() -> void:
	await _reset(-PI * 0.5, 0.0)
	var record := {"name":"browser_initial_north_then_locked_east", "target_heading":-PI * 0.5,
		"locked":false, "lock_established":false, "strikes":[]}
	record.strikes.append(await _strike())
	record.lock_established = await _lock()
	record.strikes.append(await _strike())
	cases.append(record)

func _strike() -> Dictionary:
	while player.attack_cooldown > 0.0:
		await _tick()
	current_contacts = []
	var health_before: float = enemy.health_component.health
	var sequence: int = player.attack_sequence_id
	var frames := []
	_mouse(true)
	await _tick()
	_mouse(false)
	frames.append(_frame())
	for _index in 29:
		await _tick()
		frames.append(_frame())
	return {"accepted":player.attack_sequence_id == sequence + 1, "health_before":health_before,
		"health_after":enemy.health_component.health, "damage":health_before - enemy.health_component.health,
		"contacts":current_contacts.duplicate(true), "frames":frames}

func _frame() -> Dictionary:
	var driver: Node = player.animation_driver
	var graph: RefCounted = driver.animation_graph
	var segment: Dictionary = player.get_blade_world_segment()
	return {"player":_v(player.global_position), "enemy":_v(enemy.global_position), "facing_yaw":player.rotation.y,
		"camera_yaw":rig.yaw, "locked":rig.get_locked_combat_target() == enemy,
		"base":_v(segment.base), "tip":_v(segment.tip), "cooldown":player.attack_cooldown,
		"attack_anim_time":player.attack_anim_time, "pending_damage":player.pending_attack_damage,
		"action_elapsed":driver.action_elapsed, "state":driver.current_state, "graph_active":graph.active_state,
		"graph_requested":graph.requested, "playback_node":str(graph.playback.get_current_node()),
		"playback_position":graph.playback.get_current_play_position(), "playback_rate":driver.current_playback_scale,
		"blade_ready":player.is_blade_ready()}

func _on_contact(contact: Dictionary) -> void:
	var minimum := INF
	var line := false
	for height: float in [0.35,0.72,1.08,1.42]:
		var body: Vector3 = enemy.global_position + Vector3.UP * height
		var point: Vector3 = combat._closest_sweep_point(body, contact.previous_base, contact.previous_tip, contact.base, contact.tip)
		var distance: float = body.distance_to(point)
		if distance < minimum:
			minimum = distance
			line = combat._has_contact_line(player, enemy, point)
	var result: Dictionary = combat.resolve_player_blade_contact(player, [enemy], contact, "")
	player.confirm_blade_contact(int(contact.attack_id), bool(result.get("hit",false)))
	current_contacts.append({"phase":contact.contact_phase, "damage":contact.damage, "reach":contact.reach,
		"base":_v(contact.base), "tip":_v(contact.tip), "previous_base":_v(contact.previous_base),
		"previous_tip":_v(contact.previous_tip), "minimum_capsule_sample_distance":minimum, "line_clear":line,
		"result_hit":bool(result.get("hit",false)), "result_reason":str(result.get("reason", "")),
		"health":enemy.health_component.health, "frame":_frame()})

func _v(value: Vector3) -> Array:
	return [value.x,value.y,value.z]
